Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptRoot = $PSScriptRoot
$projectRoot = Split-Path -Path $scriptRoot -Parent
$configRoot = Join-Path $projectRoot "Config"
$generatedRoot = Join-Path $projectRoot "Generated"
$generatorPath = Join-Path $scriptRoot "Generate-KFZedSpawner.ps1"
$currentIniPath = Join-Path $configRoot "KFZedSpawner.ini"
$generatedIniPath = Join-Path $generatedRoot "KFZedSpawner.ini"
$zedListPath = Join-Path $configRoot "List of zeds.txt"
$groupsPath = Join-Path $configRoot "Zed probability groups.ini"
$waveScalingPath = Join-Path $configRoot "Wave scaling.ini"
$safetyNetPath = Join-Path $configRoot "Safety net.ini"
$spawnBurstsPath = Join-Path $configRoot "Spawn bursts.ini"
$difficultyScalerPath = Join-Path $configRoot "Difficulty scaler.ini"
$presetPath = Join-Path $configRoot "Tool preset.json"

function Open-TextFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        [System.Windows.Forms.MessageBox]::Show("File not found:`r`n$Path", "Zed Spawner Tool", "OK", "Warning") | Out-Null
        return
    }

    Start-Process -FilePath "notepad.exe" -ArgumentList @($Path)
}

function Quote-Argument {
    param([object]$Value)

    $text = [string]$Value
    if ($text -notmatch '[\s"]') {
        return $text
    }

    return '"' + $text.Replace('"', '\"') + '"'
}

function Add-NumberRow {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Panel,
        [int]$Row,
        [string]$Label,
        [int]$Value,
        [int]$Minimum = 0,
        [int]$Maximum = 999,
        [string]$Tip = ""
    )

    $labelControl = New-Object System.Windows.Forms.Label
    $labelControl.Text = $Label
    $labelControl.AutoSize = $true
    $labelControl.Anchor = "Left"
    $labelControl.Margin = New-Object System.Windows.Forms.Padding(4, 7, 8, 0)
    $Panel.Controls.Add($labelControl, 0, $Row)

    $input = New-Object System.Windows.Forms.NumericUpDown
    $input.Minimum = $Minimum
    $input.Maximum = $Maximum
    $input.Value = $Value
    $input.Width = 82
    $input.Anchor = "Left"
    $input.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 3)
    $Panel.Controls.Add($input, 1, $Row)

    if ($Tip) {
        $toolTip = New-Object System.Windows.Forms.ToolTip
        $toolTip.SetToolTip($labelControl, $Tip)
        $toolTip.SetToolTip($input, $Tip)
    }

    return $input
}

function Add-RangeRow {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Panel,
        [int]$Row,
        [string]$Label,
        [int]$MinValue,
        [int]$MaxValue,
        [int]$Minimum = 1,
        [int]$Maximum = 100,
        [string]$Tip = ""
    )

    $labelControl = New-Object System.Windows.Forms.Label
    $labelControl.Text = $Label
    $labelControl.AutoSize = $true
    $labelControl.Anchor = "Left"
    $labelControl.Margin = New-Object System.Windows.Forms.Padding(4, 7, 8, 0)
    $Panel.Controls.Add($labelControl, 0, $Row)

    $minInput = New-Object System.Windows.Forms.NumericUpDown
    $minInput.Minimum = $Minimum
    $minInput.Maximum = $Maximum
    $minInput.Value = $MinValue
    $minInput.Width = 62
    $minInput.Anchor = "Left"
    $minInput.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 3)
    $Panel.Controls.Add($minInput, 1, $Row)

    $maxInput = New-Object System.Windows.Forms.NumericUpDown
    $maxInput.Minimum = $Minimum
    $maxInput.Maximum = $Maximum
    $maxInput.Value = $MaxValue
    $maxInput.Width = 62
    $maxInput.Anchor = "Left"
    $maxInput.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 3)
    $Panel.Controls.Add($maxInput, 2, $Row)

    if ($Tip) {
        $toolTip = New-Object System.Windows.Forms.ToolTip
        $toolTip.SetToolTip($labelControl, $Tip)
        $toolTip.SetToolTip($minInput, "$Tip Minimum.")
        $toolTip.SetToolTip($maxInput, "$Tip Maximum.")
    }

    return [pscustomobject]@{
        Min = $minInput
        Max = $maxInput
    }
}

function New-SettingsGroup {
    param(
        [string]$Title,
        [int]$Rows,
        [int]$ValueColumns = 1
    )

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $Title
    $group.Dock = "Fill"
    $group.Padding = New-Object System.Windows.Forms.Padding(10)
    $group.MinimumSize = New-Object System.Drawing.Size(0, 235)

    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.Dock = "Fill"
    $table.ColumnCount = 1 + $ValueColumns
    $table.RowCount = $Rows
    $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    for ($i = 0; $i -lt $ValueColumns; $i++) {
        $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 76))) | Out-Null
    }
    for ($i = 0; $i -lt $Rows; $i++) {
        $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    }

    $group.Controls.Add($table)
    return [pscustomobject]@{
        Group = $group
        Table = $table
    }
}

function Get-ZedGroupMap {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    $currentGroup = ""
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^\[(?<group>[^\]]+)\]$") {
            $currentGroup = $Matches["group"]
            continue
        }

        if ($currentGroup -and $line -match "\.") {
            $map[$line] = $currentGroup
        }
    }

    return $map
}

function Add-GeneratedPreviewScan {
    param(
        [string]$IniPath,
        [System.Windows.Forms.TextBox]$LogBox
    )

    if (-not (Test-Path -LiteralPath $IniPath)) {
        $LogBox.AppendText("`r`nPreview scan skipped. File not found: $IniPath`r`n")
        return
    }

    $groupMap = Get-ZedGroupMap -Path $groupsPath
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($match in Select-String -LiteralPath $IniPath -Pattern '^Spawn=') {
        $line = $match.Line
        if ($line -notmatch 'Wave=(?<wave>\d+),ZedClass="(?<zed>[^"]+)".*Probability=(?<probability>\d+),SpawnCountBase=(?<spawnCount>\d+),SingleSpawnLimit=(?<singleLimit>\d+)') {
            continue
        }

        $zed = $Matches["zed"]
        $group = "Ungrouped"
        if ($groupMap.ContainsKey($zed)) {
            $group = $groupMap[$zed]
        }

        $rows.Add([pscustomobject]@{
            Wave = [int]$Matches["wave"]
            Group = $group
            Zed = $zed
            Probability = [int]$Matches["probability"]
            SpawnCountBase = [int]$Matches["spawnCount"]
            SingleSpawnLimit = [int]$Matches["singleLimit"]
        })
    }

    if ($rows.Count -eq 0) {
        $LogBox.AppendText("`r`nPreview scan found no Spawn lines.`r`n")
        return
    }

    $LogBox.AppendText("`r`n--- Preview Scan ---`r`n")
    $LogBox.AppendText("Spawn lines scanned: $($rows.Count)`r`n")
    $waveCounts = @($rows | Group-Object Wave)
    $classesPerWave = @($waveCounts | ForEach-Object { $_.Count })
    $minClasses = ($classesPerWave | Measure-Object -Minimum).Minimum
    $maxClasses = ($classesPerWave | Measure-Object -Maximum).Maximum
    $LogBox.AppendText("Classes per regular wave: $minClasses-$maxClasses`r`n")
    $LogBox.AppendText("`r`nFirst wave per group:`r`n")

    $groupOrder = @("VeryLikely", "AboveAvarage", "Somewhatinthemiddle", "Unlikely", "VeryUnlikely", "Haveyouseenhim", "Ungrouped")
    foreach ($group in $groupOrder) {
        $groupRows = @($rows | Where-Object { $_.Group -eq $group })
        if ($groupRows.Count -eq 0) {
            continue
        }

        $firstWave = ($groupRows.Wave | Measure-Object -Minimum).Minimum
        $lastWave = ($groupRows.Wave | Measure-Object -Maximum).Maximum
        $minProbability = ($groupRows.Probability | Measure-Object -Minimum).Minimum
        $maxProbability = ($groupRows.Probability | Measure-Object -Maximum).Maximum
        $LogBox.AppendText(("  {0,-22} wave {1,2}-{2,-2}  prob {3,2}-{4,-2}  lines {5}`r`n" -f $group, $firstWave, $lastWave, $minProbability, $maxProbability, $groupRows.Count))
    }

    $LogBox.AppendText("`r`nBridge phase group counts:`r`n")
    $ranges = @("1-4", "6-9", "11-14", "16-19", "21-24", "26-29", "31-34", "36-39", "41-44", "46-49")
    foreach ($range in $ranges) {
        $parts = $range -split "-"
        $start = [int]$parts[0]
        $end = [int]$parts[1]
        $subset = @($rows | Where-Object { $_.Wave -ge $start -and $_.Wave -le $end })
        if ($subset.Count -eq 0) {
            continue
        }

        $pieces = New-Object System.Collections.Generic.List[string]
        foreach ($group in $groupOrder) {
            $count = @($subset | Where-Object { $_.Group -eq $group }).Count
            if ($count -gt 0) {
                $pieces.Add("$group=$count")
            }
        }

        $LogBox.AppendText(("  Wave {0,-5} {1}`r`n" -f $range, ($pieces -join ", ")))
    }

    $burstRows = @($rows | Where-Object { $_.SpawnCountBase -gt 1 -or $_.SingleSpawnLimit -gt 1 })
    $LogBox.AppendText("`r`nBurst scan:`r`n")
    $LogBox.AppendText("  Burst lines: $($burstRows.Count)`r`n")
    if ($burstRows.Count -gt 0) {
        $maxSpawnCountBase = ($rows.SpawnCountBase | Measure-Object -Maximum).Maximum
        $maxSingleSpawnLimit = ($rows.SingleSpawnLimit | Measure-Object -Maximum).Maximum
        $LogBox.AppendText("  Max SpawnCountBase: $maxSpawnCountBase`r`n")
        $LogBox.AppendText("  Max SingleSpawnLimit: $maxSingleSpawnLimit`r`n")
    }

    $earlyHard = @($rows | Where-Object { $_.Wave -le 6 -and $_.Group -in @("Unlikely", "VeryUnlikely", "Haveyouseenhim") })
    $LogBox.AppendText("`r`nSafety check:`r`n")
    $LogBox.AppendText("  Hard groups on waves 1-6: $($earlyHard.Count)`r`n")
}

function Run-Generator {
    param(
        [hashtable]$Settings,
        [bool]$InPlace,
        [bool]$Append,
        [System.Windows.Forms.TextBox]$LogBox
    )

    if (-not (Test-Path -LiteralPath $generatorPath)) {
        throw "Generator script not found: $generatorPath"
    }

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $generatorPath,
        "-StartWave", $Settings.StartWave,
        "-MaxWave", $Settings.MaxWave,
        "-RelativeStart", $Settings.RelativeStart,
        "-Delay", $Settings.Delay,
        "-SpawnCountBase", $Settings.SpawnCountBase,
        "-SpawnCountBaseMax", $Settings.SpawnCountBaseMax,
        "-SingleSpawnLimit", $Settings.SingleSpawnLimit,
        "-SingleSpawnLimitMax", $Settings.SingleSpawnLimitMax,
        "-MaxClassesPerWave", $Settings.MaxClassesPerWave,
        "-RareRelativeStart", $Settings.RareRelativeStart,
        "-RareDelay", $Settings.RareDelay,
        "-RareSpawnCountBase", $Settings.RareSpawnCountBase,
        "-RareSpawnCountBaseMax", $Settings.RareSpawnCountBaseMax,
        "-RareSingleSpawnLimit", $Settings.RareSingleSpawnLimit,
        "-RareSingleSpawnLimitMax", $Settings.RareSingleSpawnLimitMax,
        "-RareProbability", $Settings.RareProbability,
        "-RareProbabilityMax", $Settings.RareProbabilityMax,
        "-VeryLikelyProbability", $Settings.VeryLikelyProbability,
        "-VeryLikelyProbabilityMax", $Settings.VeryLikelyProbabilityMax,
        "-AboveAvarageProbability", $Settings.AboveAvarageProbability,
        "-AboveAvarageProbabilityMax", $Settings.AboveAvarageProbabilityMax,
        "-SomewhatinthemiddleProbability", $Settings.SomewhatinthemiddleProbability,
        "-SomewhatinthemiddleProbabilityMax", $Settings.SomewhatinthemiddleProbabilityMax,
        "-UnlikelyProbability", $Settings.UnlikelyProbability,
        "-UnlikelyProbabilityMax", $Settings.UnlikelyProbabilityMax,
        "-VeryUnlikelyProbability", $Settings.VeryUnlikelyProbability,
        "-VeryUnlikelyProbabilityMax", $Settings.VeryUnlikelyProbabilityMax,
        "-HaveyouseenhimProbability", $Settings.HaveyouseenhimProbability,
        "-HaveyouseenhimProbabilityMax", $Settings.HaveyouseenhimProbabilityMax,
        "-WaveScalingPath", $waveScalingPath,
        "-SafetyNetPath", $safetyNetPath,
        "-SpawnBurstsPath", $spawnBurstsPath,
        "-DifficultyScalerPath", $difficultyScalerPath,
        "-IgnoreProbabilityComments"
    )

    if ($InPlace) {
        $arguments += "-InPlace"
    }

    if ($Append) {
        $arguments += "-Append"
    }

    $LogBox.Clear()
    $LogBox.AppendText("Running generator...`r`n")
    $LogBox.AppendText("WaveRange=$($Settings.StartWave)-$($Settings.MaxWave)`r`n")
    $LogBox.AppendText("Normal: RelativeStart=$($Settings.RelativeStart), Delay=$($Settings.Delay), SpawnCountBase=$($Settings.SpawnCountBase)-$($Settings.SpawnCountBaseMax), SingleSpawnLimit=$($Settings.SingleSpawnLimit)-$($Settings.SingleSpawnLimitMax), MaxClassesPerWave=$($Settings.MaxClassesPerWave)`r`n")
    $LogBox.AppendText("Rare: RelativeStart=$($Settings.RareRelativeStart), Delay=$($Settings.RareDelay), SpawnCountBase=$($Settings.RareSpawnCountBase)-$($Settings.RareSpawnCountBaseMax), SingleSpawnLimit=$($Settings.RareSingleSpawnLimit)-$($Settings.RareSingleSpawnLimitMax), Probability=$($Settings.RareProbability)-$($Settings.RareProbabilityMax)`r`n")
    $LogBox.AppendText("Wave scaling: enabled from $waveScalingPath`r`n")
    $LogBox.AppendText("Safety net: enabled from $safetyNetPath`r`n")
    $LogBox.AppendText("Spawn bursts: enabled from $spawnBurstsPath`r`n")
    $LogBox.AppendText("Difficulty scaler: enabled from $difficultyScalerPath`r`n")
    $modeText = if ($Append) { "Generate .ini" } elseif ($InPlace) { "Overwrite KFZedSpawner.ini with backup" } else { "Rebuild preview file" }
    $LogBox.AppendText("Mode=$modeText`r`n`r`n")

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = (($arguments | ForEach-Object { Quote-Argument $_ }) -join " ")
    $processInfo.WorkingDirectory = $projectRoot
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout) {
        $LogBox.AppendText($stdout.Replace("`n", "`r`n"))
    }

    if ($stderr) {
        $LogBox.AppendText("`r`nERROR:`r`n")
        $LogBox.AppendText($stderr.Replace("`n", "`r`n"))
    }

    if ($process.ExitCode -eq 0) {
        $scanPath = if ($InPlace) { Join-Path $configRoot "Original .ini\KFZedSpawner.ini" } else { $generatedIniPath }
        Add-GeneratedPreviewScan -IniPath $scanPath -LogBox $LogBox
        $LogBox.AppendText("`r`nDone.`r`n")
    }
    else {
        $LogBox.AppendText("`r`nGenerator failed with exit code $($process.ExitCode).`r`n")
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "KF Zed Spawner Tool"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1020, 840)
$form.MinimumSize = New-Object System.Drawing.Size(960, 780)

$mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
$mainPanel.Dock = "Fill"
$mainPanel.ColumnCount = 1
$mainPanel.RowCount = 5
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(12)
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 285))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$form.Controls.Add($mainPanel)

$title = New-Object System.Windows.Forms.Label
$title.Text = "KF Zed Spawner Tool"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
$mainPanel.Controls.Add($title, 0, 0)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Dock = "Fill"
$buttonPanel.AutoSize = $true
$buttonPanel.WrapContents = $true
$buttonPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
$mainPanel.Controls.Add($buttonPanel, 0, 1)

$previewButton = New-Object System.Windows.Forms.Button
$previewButton.Text = "Generate Preview"
$previewButton.Width = 130
$previewButton.Height = 30
$previewButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($previewButton)

$overwriteButton = New-Object System.Windows.Forms.Button
$overwriteButton.Text = "Overwrite INI"
$overwriteButton.Width = 110
$overwriteButton.Height = 30
$overwriteButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 16, 6)
$buttonPanel.Controls.Add($overwriteButton)

$appendButton = New-Object System.Windows.Forms.Button
$appendButton.Text = "Generate .ini"
$appendButton.Width = 105
$appendButton.Height = 30
$appendButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 16, 6)
$buttonPanel.Controls.Add($appendButton)

$openCurrentButton = New-Object System.Windows.Forms.Button
$openCurrentButton.Text = "Open Current INI"
$openCurrentButton.Width = 125
$openCurrentButton.Height = 30
$openCurrentButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openCurrentButton)

$openGeneratedButton = New-Object System.Windows.Forms.Button
$openGeneratedButton.Text = "Open Preview"
$openGeneratedButton.Width = 105
$openGeneratedButton.Height = 30
$openGeneratedButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openGeneratedButton)

$openListButton = New-Object System.Windows.Forms.Button
$openListButton.Text = "Open Zed List"
$openListButton.Width = 110
$openListButton.Height = 30
$openListButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openListButton)

$openGroupsButton = New-Object System.Windows.Forms.Button
$openGroupsButton.Text = "Open Groups"
$openGroupsButton.Width = 105
$openGroupsButton.Height = 30
$openGroupsButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openGroupsButton)

$openScalingButton = New-Object System.Windows.Forms.Button
$openScalingButton.Text = "Open Scaling"
$openScalingButton.Width = 110
$openScalingButton.Height = 30
$openScalingButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openScalingButton)

$openSafetyButton = New-Object System.Windows.Forms.Button
$openSafetyButton.Text = "Open Safety"
$openSafetyButton.Width = 105
$openSafetyButton.Height = 30
$openSafetyButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openSafetyButton)

$openBurstsButton = New-Object System.Windows.Forms.Button
$openBurstsButton.Text = "Open Bursts"
$openBurstsButton.Width = 105
$openBurstsButton.Height = 30
$openBurstsButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openBurstsButton)

$openDifficultyButton = New-Object System.Windows.Forms.Button
$openDifficultyButton.Text = "Open Difficulty"
$openDifficultyButton.Width = 120
$openDifficultyButton.Height = 30
$openDifficultyButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 6)
$buttonPanel.Controls.Add($openDifficultyButton)

$settingsGrid = New-Object System.Windows.Forms.TableLayoutPanel
$settingsGrid.Dock = "Fill"
$settingsGrid.AutoSize = $false
$settingsGrid.Height = 278
$settingsGrid.ColumnCount = 3
$settingsGrid.RowCount = 1
$settingsGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.3))) | Out-Null
$settingsGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.3))) | Out-Null
$settingsGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.4))) | Out-Null
$settingsGrid.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
$mainPanel.Controls.Add($settingsGrid, 0, 2)

$normalGroup = New-SettingsGroup -Title "Normal Spawn Entry" -Rows 7 -ValueColumns 2
$rareGroup = New-SettingsGroup -Title "Rare Spawn Entry" -Rows 5 -ValueColumns 2
$probabilityOuterPanel = New-Object System.Windows.Forms.TableLayoutPanel
$probabilityOuterPanel.Dock = "Fill"
$probabilityOuterPanel.RowCount = 2
$probabilityOuterPanel.ColumnCount = 1
$probabilityOuterPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$probabilityOuterPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

$presetPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$presetPanel.Dock = "Fill"
$presetPanel.AutoSize = $true
$presetPanel.FlowDirection = "RightToLeft"
$presetPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)

$setPresetButton = New-Object System.Windows.Forms.Button
$setPresetButton.Text = "Set Preset"
$setPresetButton.Width = 105
$setPresetButton.Height = 30
$setPresetButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
$presetPanel.Controls.Add($setPresetButton)

$probabilityOuterPanel.Controls.Add($presetPanel, 0, 0)

$probabilityGroup = New-SettingsGroup -Title "Probability Buckets Min / Max" -Rows 6 -ValueColumns 2
$probabilityOuterPanel.Controls.Add($probabilityGroup.Group, 0, 1)

$settingsGrid.Controls.Add($normalGroup.Group, 0, 0)
$settingsGrid.Controls.Add($rareGroup.Group, 1, 0)
$settingsGrid.Controls.Add($probabilityOuterPanel, 2, 0)

$startWaveInput = Add-NumberRow -Panel $normalGroup.Table -Row 0 -Label "StartWave" -Value 1 -Minimum 1 -Maximum 999 -Tip "First wave for this generated set."
$maxWaveInput = Add-NumberRow -Panel $normalGroup.Table -Row 1 -Label "EndWave" -Value 49 -Minimum 1 -Maximum 999 -Tip "Last wave for this generated set. Every fifth wave is skipped as a boss wave."
$relativeStartInput = Add-NumberRow -Panel $normalGroup.Table -Row 2 -Label "RelativeStart" -Value 2 -Minimum 0 -Maximum 100 -Tip "Spawn after this percentage of wave zeds are killed. Use 0 to start after Delay."
$delayInput = Add-NumberRow -Panel $normalGroup.Table -Row 3 -Label "Delay" -Value 1 -Minimum 0 -Maximum 999 -Tip "Seconds between spawns."
$spawnCountInput = Add-RangeRow -Panel $normalGroup.Table -Row 4 -Label "SpawnCountBase" -MinValue 1 -MaxValue 2 -Minimum 1 -Maximum 999 -Tip "Base number spawned on the first cycle with one player."
$singleLimitInput = Add-RangeRow -Panel $normalGroup.Table -Row 5 -Label "SingleSpawnLimit" -MinValue 1 -MaxValue 2 -Minimum 1 -Maximum 999 -Tip "Maximum zeds for one spawn."
$maxClassesInput = Add-NumberRow -Panel $normalGroup.Table -Row 6 -Label "MaxClassesPerWave" -Value 0 -Minimum 0 -Maximum 999 -Tip "Maximum zed classes written per wave. Use 0 to write all available classes."

$rareRelativeStartInput = Add-NumberRow -Panel $rareGroup.Table -Row 0 -Label "RelativeStart" -Value 2 -Minimum 0 -Maximum 100 -Tip "Rare zed RelativeStart."
$rareDelayInput = Add-NumberRow -Panel $rareGroup.Table -Row 1 -Label "Delay" -Value 2 -Minimum 0 -Maximum 999 -Tip "Rare zed delay."
$rareSpawnCountInput = Add-RangeRow -Panel $rareGroup.Table -Row 2 -Label "SpawnCountBase" -MinValue 1 -MaxValue 1 -Minimum 1 -Maximum 999 -Tip "Rare zed base spawn count."
$rareSingleLimitInput = Add-RangeRow -Panel $rareGroup.Table -Row 3 -Label "SingleSpawnLimit" -MinValue 1 -MaxValue 1 -Minimum 1 -Maximum 999 -Tip "Rare zed single spawn limit."
$rareProbabilityInput = Add-RangeRow -Panel $rareGroup.Table -Row 4 -Label "Probability" -MinValue 5 -MaxValue 5 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in the Rare section."

$veryLikelyInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 0 -Label "VeryLikely" -MinValue 35 -MaxValue 55 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [VeryLikely]."
$aboveAvarageInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 1 -Label "AboveAvarage" -MinValue 30 -MaxValue 48 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [AboveAvarage]."
$middleInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 2 -Label "Somewhatinthemiddle" -MinValue 22 -MaxValue 38 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [Somewhatinthemiddle]."
$unlikelyInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 3 -Label "Unlikely" -MinValue 16 -MaxValue 30 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [Unlikely]."
$veryUnlikelyInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 4 -Label "VeryUnlikely" -MinValue 8 -MaxValue 18 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [VeryUnlikely]."
$seenHimInput = Add-RangeRow -Panel $probabilityGroup.Table -Row 5 -Label "Haveyouseenhim" -MinValue 5 -MaxValue 12 -Minimum 1 -Maximum 100 -Tip "Probability range for zeds in [Haveyouseenhim]."

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "Vertical"
$logBox.Dock = "Fill"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$logBox.Text = "Generate Preview rebuilds the generated INI. Generate .ini adds the current wave range and parameters as a new block. Wave scaling, safety net, spawn bursts, and difficulty scaler are enabled from Config."
$mainPanel.Controls.Add($logBox, 0, 3)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = $projectRoot
$statusLabel.AutoSize = $true
$statusLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$mainPanel.Controls.Add($statusLabel, 0, 4)

function Get-WindowSettings {
    return @{
        StartWave = [int]$startWaveInput.Value
        MaxWave = [int]$maxWaveInput.Value
        RelativeStart = [int]$relativeStartInput.Value
        Delay = [int]$delayInput.Value
        SpawnCountBase = [int]$spawnCountInput.Min.Value
        SpawnCountBaseMax = [int]$spawnCountInput.Max.Value
        SingleSpawnLimit = [int]$singleLimitInput.Min.Value
        SingleSpawnLimitMax = [int]$singleLimitInput.Max.Value
        MaxClassesPerWave = [int]$maxClassesInput.Value
        RareRelativeStart = [int]$rareRelativeStartInput.Value
        RareDelay = [int]$rareDelayInput.Value
        RareSpawnCountBase = [int]$rareSpawnCountInput.Min.Value
        RareSpawnCountBaseMax = [int]$rareSpawnCountInput.Max.Value
        RareSingleSpawnLimit = [int]$rareSingleLimitInput.Min.Value
        RareSingleSpawnLimitMax = [int]$rareSingleLimitInput.Max.Value
        RareProbability = [int]$rareProbabilityInput.Min.Value
        RareProbabilityMax = [int]$rareProbabilityInput.Max.Value
        VeryLikelyProbability = [int]$veryLikelyInput.Min.Value
        VeryLikelyProbabilityMax = [int]$veryLikelyInput.Max.Value
        AboveAvarageProbability = [int]$aboveAvarageInput.Min.Value
        AboveAvarageProbabilityMax = [int]$aboveAvarageInput.Max.Value
        SomewhatinthemiddleProbability = [int]$middleInput.Min.Value
        SomewhatinthemiddleProbabilityMax = [int]$middleInput.Max.Value
        UnlikelyProbability = [int]$unlikelyInput.Min.Value
        UnlikelyProbabilityMax = [int]$unlikelyInput.Max.Value
        VeryUnlikelyProbability = [int]$veryUnlikelyInput.Min.Value
        VeryUnlikelyProbabilityMax = [int]$veryUnlikelyInput.Max.Value
        HaveyouseenhimProbability = [int]$seenHimInput.Min.Value
        HaveyouseenhimProbabilityMax = [int]$seenHimInput.Max.Value
    }
}

function Set-NumericValue {
    param(
        [System.Windows.Forms.NumericUpDown]$Control,
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    $number = [decimal]$Value
    if ($number -lt $Control.Minimum) {
        $number = $Control.Minimum
    }
    elseif ($number -gt $Control.Maximum) {
        $number = $Control.Maximum
    }

    $Control.Value = $number
}

function Get-SettingValue {
    param(
        [object]$Settings,
        [string]$Name
    )

    if ($null -eq $Settings) {
        return $null
    }

    $property = $Settings.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Apply-WindowSettings {
    param([object]$Settings)

    Set-NumericValue -Control $startWaveInput -Value (Get-SettingValue -Settings $Settings -Name "StartWave")
    Set-NumericValue -Control $maxWaveInput -Value (Get-SettingValue -Settings $Settings -Name "MaxWave")
    Set-NumericValue -Control $relativeStartInput -Value (Get-SettingValue -Settings $Settings -Name "RelativeStart")
    Set-NumericValue -Control $delayInput -Value (Get-SettingValue -Settings $Settings -Name "Delay")
    Set-NumericValue -Control $spawnCountInput.Min -Value (Get-SettingValue -Settings $Settings -Name "SpawnCountBase")
    $spawnCountMax = Get-SettingValue -Settings $Settings -Name "SpawnCountBaseMax"
    if ($null -eq $spawnCountMax) {
        $spawnCountMax = Get-SettingValue -Settings $Settings -Name "SpawnCountBase"
    }
    Set-NumericValue -Control $spawnCountInput.Max -Value $spawnCountMax
    Set-NumericValue -Control $singleLimitInput.Min -Value (Get-SettingValue -Settings $Settings -Name "SingleSpawnLimit")
    $singleLimitMax = Get-SettingValue -Settings $Settings -Name "SingleSpawnLimitMax"
    if ($null -eq $singleLimitMax) {
        $singleLimitMax = Get-SettingValue -Settings $Settings -Name "SingleSpawnLimit"
    }
    Set-NumericValue -Control $singleLimitInput.Max -Value $singleLimitMax
    Set-NumericValue -Control $maxClassesInput -Value (Get-SettingValue -Settings $Settings -Name "MaxClassesPerWave")
    Set-NumericValue -Control $rareRelativeStartInput -Value (Get-SettingValue -Settings $Settings -Name "RareRelativeStart")
    Set-NumericValue -Control $rareDelayInput -Value (Get-SettingValue -Settings $Settings -Name "RareDelay")
    Set-NumericValue -Control $rareSpawnCountInput.Min -Value (Get-SettingValue -Settings $Settings -Name "RareSpawnCountBase")
    $rareSpawnCountMax = Get-SettingValue -Settings $Settings -Name "RareSpawnCountBaseMax"
    if ($null -eq $rareSpawnCountMax) {
        $rareSpawnCountMax = Get-SettingValue -Settings $Settings -Name "RareSpawnCountBase"
    }
    Set-NumericValue -Control $rareSpawnCountInput.Max -Value $rareSpawnCountMax
    Set-NumericValue -Control $rareSingleLimitInput.Min -Value (Get-SettingValue -Settings $Settings -Name "RareSingleSpawnLimit")
    $rareSingleLimitMax = Get-SettingValue -Settings $Settings -Name "RareSingleSpawnLimitMax"
    if ($null -eq $rareSingleLimitMax) {
        $rareSingleLimitMax = Get-SettingValue -Settings $Settings -Name "RareSingleSpawnLimit"
    }
    Set-NumericValue -Control $rareSingleLimitInput.Max -Value $rareSingleLimitMax
    Set-NumericValue -Control $rareProbabilityInput.Min -Value (Get-SettingValue -Settings $Settings -Name "RareProbability")
    Set-NumericValue -Control $rareProbabilityInput.Max -Value (Get-SettingValue -Settings $Settings -Name "RareProbabilityMax")

    Set-NumericValue -Control $veryLikelyInput.Min -Value (Get-SettingValue -Settings $Settings -Name "VeryLikelyProbability")
    Set-NumericValue -Control $veryLikelyInput.Max -Value (Get-SettingValue -Settings $Settings -Name "VeryLikelyProbabilityMax")
    Set-NumericValue -Control $aboveAvarageInput.Min -Value (Get-SettingValue -Settings $Settings -Name "AboveAvarageProbability")
    Set-NumericValue -Control $aboveAvarageInput.Max -Value (Get-SettingValue -Settings $Settings -Name "AboveAvarageProbabilityMax")
    Set-NumericValue -Control $middleInput.Min -Value (Get-SettingValue -Settings $Settings -Name "SomewhatinthemiddleProbability")
    Set-NumericValue -Control $middleInput.Max -Value (Get-SettingValue -Settings $Settings -Name "SomewhatinthemiddleProbabilityMax")
    Set-NumericValue -Control $unlikelyInput.Min -Value (Get-SettingValue -Settings $Settings -Name "UnlikelyProbability")
    Set-NumericValue -Control $unlikelyInput.Max -Value (Get-SettingValue -Settings $Settings -Name "UnlikelyProbabilityMax")
    Set-NumericValue -Control $veryUnlikelyInput.Min -Value (Get-SettingValue -Settings $Settings -Name "VeryUnlikelyProbability")
    Set-NumericValue -Control $veryUnlikelyInput.Max -Value (Get-SettingValue -Settings $Settings -Name "VeryUnlikelyProbabilityMax")
    Set-NumericValue -Control $seenHimInput.Min -Value (Get-SettingValue -Settings $Settings -Name "HaveyouseenhimProbability")
    Set-NumericValue -Control $seenHimInput.Max -Value (Get-SettingValue -Settings $Settings -Name "HaveyouseenhimProbabilityMax")
}

function Save-WindowPreset {
    param([System.Windows.Forms.TextBox]$LogBox)

    if (-not (Test-Path -LiteralPath $configRoot)) {
        New-Item -Path $configRoot -ItemType Directory -Force | Out-Null
    }

    $settings = Get-WindowSettings
    $settings |
        ConvertTo-Json |
        Set-Content -LiteralPath $presetPath -Encoding ASCII

    $LogBox.AppendText("`r`nSaved preset: $presetPath`r`n")
}

if (Test-Path -LiteralPath $presetPath) {
    try {
        $savedSettings = Get-Content -LiteralPath $presetPath -Raw | ConvertFrom-Json
        Apply-WindowSettings -Settings $savedSettings
        $logBox.Text = "Loaded preset from $presetPath. Generate Preview rebuilds the generated INI. Generate .ini adds the current wave range and parameters as a new block. Wave scaling, safety net, spawn bursts, and difficulty scaler are enabled."
    }
    catch {
        $logBox.Text = "Could not load preset: $($_.Exception.Message)"
    }
}

$previewButton.Add_Click({
    try {
        Run-Generator -Settings (Get-WindowSettings) -InPlace $false -Append $false -LogBox $logBox
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Generator error", "OK", "Error") | Out-Null
    }
})

$appendButton.Add_Click({
    try {
        Run-Generator -Settings (Get-WindowSettings) -InPlace $false -Append $true -LogBox $logBox
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Generator error", "OK", "Error") | Out-Null
    }
})

$setPresetButton.Add_Click({
    try {
        Save-WindowPreset -LogBox $logBox
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Preset error", "OK", "Error") | Out-Null
    }
})

$overwriteButton.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will overwrite KFZedSpawner.ini and create KFZedSpawner.ini.bak first.",
        "Overwrite INI?",
        "OKCancel",
        "Warning"
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    try {
        Run-Generator -Settings (Get-WindowSettings) -InPlace $true -Append $false -LogBox $logBox
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Generator error", "OK", "Error") | Out-Null
    }
})

$openCurrentButton.Add_Click({ Open-TextFile -Path $currentIniPath })
$openGeneratedButton.Add_Click({ Open-TextFile -Path $generatedIniPath })
$openListButton.Add_Click({ Open-TextFile -Path $zedListPath })
$openGroupsButton.Add_Click({ Open-TextFile -Path $groupsPath })
$openScalingButton.Add_Click({ Open-TextFile -Path $waveScalingPath })
$openSafetyButton.Add_Click({ Open-TextFile -Path $safetyNetPath })
$openBurstsButton.Add_Click({ Open-TextFile -Path $spawnBurstsPath })
$openDifficultyButton.Add_Click({ Open-TextFile -Path $difficultyScalerPath })

[void]$form.ShowDialog()
