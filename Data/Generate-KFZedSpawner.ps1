param(
    [int]$StartWave = 1,
    [int]$MaxWave = 49,
    [int]$RelativeStart = 2,
    [int]$Delay = 2,
    [int]$SpawnCountBase = 1,
    [int]$SingleSpawnLimit = 1,
    [int]$MaxClassesPerWave = 0,
    [int]$RareRelativeStart = 2,
    [int]$RareDelay = 2,
    [int]$RareSpawnCountBase = 1,
    [int]$RareSingleSpawnLimit = 1,
    [int]$RareProbability = 5,
    [int]$RareProbabilityMax = 5,
    [int]$VeryLikelyProbability = 30,
    [int]$VeryLikelyProbabilityMax = 30,
    [int]$AboveAvarageProbability = 25,
    [int]$AboveAvarageProbabilityMax = 25,
    [int]$SomewhatinthemiddleProbability = 12,
    [int]$SomewhatinthemiddleProbabilityMax = 12,
    [int]$UnlikelyProbability = 10,
    [int]$UnlikelyProbabilityMax = 10,
    [int]$VeryUnlikelyProbability = 7,
    [int]$VeryUnlikelyProbabilityMax = 7,
    [int]$HaveyouseenhimProbability = 5,
    [int]$HaveyouseenhimProbabilityMax = 5,
    [switch]$IgnoreProbabilityComments,
    [string]$ZedListPath = "..\Config\List of zeds.txt",
    [string]$ProbabilityGroupsPath = "..\Config\Zed probability groups.ini",
    [string]$WaveScalingPath = "..\Config\Wave scaling.ini",
    [string]$SafetyNetPath = "..\Config\Safety net.ini",
    [string]$SpawnBurstsPath = "..\Config\Spawn bursts.ini",
    [string]$TemplateIniPath = "..\Config\Original .ini\KFZedSpawner.ini",
    [string]$OutputPath = "..\Generated\KFZedSpawner.ini",
    [switch]$Append,
    [switch]$InPlace,
    [switch]$DisableWaveScaling,
    [switch]$DisableSafetyNet,
    [switch]$DisableSpawnBursts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DefaultSpawn = [ordered]@{
    RelativeStart = $RelativeStart
    Delay = $Delay
    SpawnCountBase = $SpawnCountBase
    SingleSpawnLimit = $SingleSpawnLimit
}

$RareSpawn = [ordered]@{
    RelativeStart = $RareRelativeStart
    Delay = $RareDelay
    SpawnCountBase = $RareSpawnCountBase
    SingleSpawnLimit = $RareSingleSpawnLimit
}

$RareProbabilityRange = [pscustomobject]@{
    Min = $RareProbability
    Max = $RareProbabilityMax
}

$DefaultProbabilities = @{
    VeryLikely = [pscustomobject]@{ Min = $VeryLikelyProbability; Max = $VeryLikelyProbabilityMax }
    AboveAvarage = [pscustomobject]@{ Min = $AboveAvarageProbability; Max = $AboveAvarageProbabilityMax }
    Somewhatinthemiddle = [pscustomobject]@{ Min = $SomewhatinthemiddleProbability; Max = $SomewhatinthemiddleProbabilityMax }
    Unlikely = [pscustomobject]@{ Min = $UnlikelyProbability; Max = $UnlikelyProbabilityMax }
    VeryUnlikely = [pscustomobject]@{ Min = $VeryUnlikelyProbability; Max = $VeryUnlikelyProbabilityMax }
    Haveyouseenhim = [pscustomobject]@{ Min = $HaveyouseenhimProbability; Max = $HaveyouseenhimProbabilityMax }
}

$DefaultWaveScaling = @{
    VeryLikely = [pscustomobject]@{ UnlockWave = 1; FullWave = 1; FadeStartWave = 16; FadeEndWave = 49; LateMultiplier = 35 }
    AboveAvarage = [pscustomobject]@{ UnlockWave = 3; FullWave = 8; FadeStartWave = 26; FadeEndWave = 49; LateMultiplier = 55 }
    Somewhatinthemiddle = [pscustomobject]@{ UnlockWave = 7; FullWave = 16; FadeStartWave = 0; FadeEndWave = 0; LateMultiplier = 100 }
    Unlikely = [pscustomobject]@{ UnlockWave = 13; FullWave = 28; FadeStartWave = 0; FadeEndWave = 0; LateMultiplier = 100 }
    VeryUnlikely = [pscustomobject]@{ UnlockWave = 22; FullWave = 40; FadeStartWave = 0; FadeEndWave = 0; LateMultiplier = 100 }
    Haveyouseenhim = [pscustomobject]@{ UnlockWave = 31; FullWave = 49; FadeStartWave = 0; FadeEndWave = 0; LateMultiplier = 100 }
}

$GroupRank = @{
    VeryLikely = 1
    AboveAvarage = 2
    Somewhatinthemiddle = 3
    Unlikely = 4
    VeryUnlikely = 5
    Haveyouseenhim = 6
}

function Resolve-FromScriptRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath $Path))
}

function Is-BossWave {
    param([int]$Wave)

    return $Wave -gt 0 -and $Wave % 5 -eq 0
}

function Add-Unique {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Value
    )

    if ($Value -and -not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function Read-ZedList {
    param([string]$Path)

    $sections = [ordered]@{}
    $sections["Main"] = New-Object System.Collections.Generic.List[string]
    $currentSection = "Main"

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line) {
            continue
        }

        if ($line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^(Rare|Bosses)$") {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = New-Object System.Collections.Generic.List[string]
            }
            continue
        }

        if ($line -eq "List") {
            $currentSection = "Main"
            continue
        }

        if ($line -match "^Wave(?<start>\d+)-(?<end>\d+)$") {
            $currentSection = $line
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = New-Object System.Collections.Generic.List[string]
            }
            continue
        }

        if ($line -notmatch "\.") {
            continue
        }

        Add-Unique -List $sections[$currentSection] -Value $line
    }

    return $sections
}

function Read-ProbabilityGroups {
    param([string]$Path)

    $probabilities = @{}
    foreach ($key in $DefaultProbabilities.Keys) {
        $probabilities[$key] = $DefaultProbabilities[$key]
    }

    $zedProbabilities = @{}
    $zedGroups = @{}
    $currentGroup = $null

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line) {
            continue
        }

        if (-not $IgnoreProbabilityComments -and $line -match "^[;#]\s*(?<key>[A-Za-z]+)\s*=\s*(?<min>\d+)(?:\s*-\s*(?<max>\d+))?\s*$") {
            $min = [int]$Matches["min"]
            $max = $min
            if ($Matches.ContainsKey("max") -and $Matches["max"]) {
                $max = [int]$Matches["max"]
            }
            $probabilities[$Matches["key"]] = [pscustomobject]@{ Min = $min; Max = $max }
            continue
        }

        if ($line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^\[(?<group>[^\]]+)\]$") {
            $currentGroup = $Matches["group"]
            if (-not $probabilities.ContainsKey($currentGroup)) {
                Write-Warning "Unknown probability group '$currentGroup'. Entries will use the default middle probability unless the group has a value."
            }
            continue
        }

        if ($null -eq $currentGroup) {
            continue
        }

        if ($probabilities.ContainsKey($currentGroup)) {
            $zedProbabilities[$line] = $probabilities[$currentGroup]
            $zedGroups[$line] = $currentGroup
        }
    }

    return [pscustomobject]@{
        Groups = $probabilities
        Zeds = $zedProbabilities
        ZedGroups = $zedGroups
    }
}

function Read-WaveScaling {
    param([string]$Path)

    $scaling = @{}
    foreach ($key in $DefaultWaveScaling.Keys) {
        $rule = $DefaultWaveScaling[$key]
        $scaling[$key] = [pscustomobject]@{
            UnlockWave = [int]$rule.UnlockWave
            FullWave = [int]$rule.FullWave
            FadeStartWave = [int]$rule.FadeStartWave
            FadeEndWave = [int]$rule.FadeEndWave
            LateMultiplier = [int]$rule.LateMultiplier
        }
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return $scaling
    }

    $currentGroup = $null
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^\[(?<group>[^\]]+)\]$") {
            $currentGroup = $Matches["group"]
            if (-not $scaling.ContainsKey($currentGroup)) {
                $scaling[$currentGroup] = [pscustomobject]@{
                    UnlockWave = 1
                    FullWave = 1
                    FadeStartWave = 0
                    FadeEndWave = 0
                    LateMultiplier = 100
                }
            }
            continue
        }

        if ($null -eq $currentGroup -or $line -notmatch "^(?<key>[A-Za-z]+)\s*=\s*(?<value>-?\d+)\s*$") {
            continue
        }

        $key = $Matches["key"]
        $value = [int]$Matches["value"]
        if ($scaling[$currentGroup].PSObject.Properties[$key]) {
            $scaling[$currentGroup].$key = $value
        }
    }

    return $scaling
}

function Read-SafetyNet {
    param([string]$Path)

    $phases = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path)) {
        return $phases
    }

    $currentPhase = $null
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^\[Wave(?<start>\d+)-(?<end>\d+)\]$") {
            $currentPhase = [pscustomobject]@{
                StartWave = [int]$Matches["start"]
                EndWave = [int]$Matches["end"]
                MaxGroup = "Haveyouseenhim"
                Multipliers = @{}
            }
            $phases.Add($currentPhase)
            continue
        }

        if ($null -eq $currentPhase -or $line -notmatch "^(?<key>[A-Za-z]+)\s*=\s*(?<value>[A-Za-z0-9]+)\s*$") {
            continue
        }

        $key = $Matches["key"]
        $value = $Matches["value"]
        if ($key -eq "MaxGroup") {
            $currentPhase.MaxGroup = $value
        }
        elseif ($key -match "^(?<group>.+)Multiplier$") {
            $currentPhase.Multipliers[$Matches["group"]] = [int]$value
        }
    }

    return $phases
}

function Read-SpawnBursts {
    param([string]$Path)

    $phases = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path)) {
        return $phases
    }

    $currentPhase = $null
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (-not $line -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match "^\[Wave(?<start>\d+)-(?<end>\d+)\]$") {
            $currentPhase = [pscustomobject]@{
                StartWave = [int]$Matches["start"]
                EndWave = [int]$Matches["end"]
                Chance = 0
                SpawnCountBaseBonus = 0
                SingleSpawnLimitBonus = 0
                MaxSpawnCountBase = 999
                MaxSingleSpawnLimit = 999
            }
            $phases.Add($currentPhase)
            continue
        }

        if ($null -eq $currentPhase -or $line -notmatch "^(?<key>[A-Za-z]+)\s*=\s*(?<value>-?\d+)\s*$") {
            continue
        }

        $key = $Matches["key"]
        $value = [int]$Matches["value"]
        if ($currentPhase.PSObject.Properties[$key]) {
            $currentPhase.$key = $value
        }
    }

    return $phases
}

function Get-SafetyNetPhase {
    param(
        [int]$Wave,
        [System.Collections.Generic.List[object]]$Phases
    )

    foreach ($phase in $Phases) {
        if ($Wave -ge [int]$phase.StartWave -and $Wave -le [int]$phase.EndWave) {
            return $phase
        }
    }

    return $null
}

function Get-WavePhase {
    param(
        [int]$Wave,
        [System.Collections.Generic.List[object]]$Phases
    )

    foreach ($phase in $Phases) {
        if ($Wave -ge [int]$phase.StartWave -and $Wave -le [int]$phase.EndWave) {
            return $phase
        }
    }

    return $null
}

function Get-ProbabilityValue {
    param([object]$Range)

    $min = [int]$Range.Min
    $max = [int]$Range.Max

    if ($min -gt $max) {
        $oldMin = $min
        $min = $max
        $max = $oldMin
    }

    if ($min -eq $max) {
        return $min
    }

    return Get-Random -Minimum $min -Maximum ($max + 1)
}

function Get-ZedGroup {
    param(
        [string]$ZedClass,
        [object]$ProbabilityConfig,
        [string]$FallbackGroup = "Somewhatinthemiddle"
    )

    if ($ProbabilityConfig.ZedGroups.ContainsKey($ZedClass)) {
        return $ProbabilityConfig.ZedGroups[$ZedClass]
    }

    return $FallbackGroup
}

function Get-ScaledProbability {
    param(
        [int]$Wave,
        [string]$Group,
        [int]$BaseProbability,
        [hashtable]$WaveScaling
    )

    if ($DisableWaveScaling -or -not $WaveScaling.ContainsKey($Group)) {
        return $BaseProbability
    }

    $rule = $WaveScaling[$Group]
    $unlockWave = [int]$rule.UnlockWave
    $fullWave = [int]$rule.FullWave
    $fadeStartWave = [int]$rule.FadeStartWave
    $fadeEndWave = [int]$rule.FadeEndWave
    $lateMultiplier = [double]$rule.LateMultiplier / 100.0

    if ($Wave -lt $unlockWave) {
        return $null
    }

    if ($lateMultiplier -lt 0.01) {
        $lateMultiplier = 0.01
    }

    $factor = 1.0
    if ($fullWave -gt $unlockWave -and $Wave -lt $fullWave) {
        $progress = ([double]($Wave - $unlockWave)) / ([double]($fullWave - $unlockWave))
        $factor = 0.25 + (0.75 * $progress)
    }

    if ($fadeStartWave -gt 0 -and $fadeEndWave -gt $fadeStartWave -and $Wave -gt $fadeStartWave) {
        if ($Wave -ge $fadeEndWave) {
            $factor *= $lateMultiplier
        }
        else {
            $fadeProgress = ([double]($Wave - $fadeStartWave)) / ([double]($fadeEndWave - $fadeStartWave))
            $fadeFactor = (1.0 - $fadeProgress) + ($lateMultiplier * $fadeProgress)
            $factor *= $fadeFactor
        }
    }

    return [Math]::Max(1, [Math]::Min(100, [int][Math]::Round($BaseProbability * $factor)))
}

function Get-SafetyNetProbability {
    param(
        [int]$Wave,
        [string]$Group,
        [int]$Probability,
        [System.Collections.Generic.List[object]]$SafetyNet
    )

    if ($DisableSafetyNet) {
        return $Probability
    }

    $phase = Get-SafetyNetPhase -Wave $Wave -Phases $SafetyNet
    if ($null -eq $phase) {
        return $Probability
    }

    $maxGroup = [string]$phase.MaxGroup
    if ($GroupRank.ContainsKey($Group) -and $GroupRank.ContainsKey($maxGroup)) {
        if ([int]$GroupRank[$Group] -gt [int]$GroupRank[$maxGroup]) {
            return $null
        }
    }

    if ($phase.Multipliers.ContainsKey($Group)) {
        $multiplier = [double]$phase.Multipliers[$Group] / 100.0
        if ($multiplier -le 0) {
            return $null
        }

        return [Math]::Max(1, [Math]::Min(100, [int][Math]::Round($Probability * $multiplier)))
    }

    return $Probability
}

function Format-ProbabilityRange {
    param([object]$Range)

    $min = [int]$Range.Min
    $max = [int]$Range.Max

    if ($min -eq $max) {
        return [string]$min
    }

    return "$min-$max"
}

function New-SpawnLine {
    param(
        [int]$Wave,
        [string]$ZedClass,
        [int]$Probability,
        [object]$SpawnSettings = $DefaultSpawn
    )

    return 'Spawn=(Wave={0},ZedClass="{1}",RelativeStart={2},Delay={3},Probability={4},SpawnCountBase={5},SingleSpawnLimit={6})' -f `
        $Wave,
        $ZedClass,
        $SpawnSettings.RelativeStart,
        $SpawnSettings.Delay,
        $Probability,
        $SpawnSettings.SpawnCountBase,
        $SpawnSettings.SingleSpawnLimit
}

function Get-SpawnLineWave {
    param([string]$SpawnLine)

    if ($SpawnLine -match "Wave=(\d+),") {
        return [int]$Matches[1]
    }

    return [int]::MaxValue
}

function Get-BurstLineCount {
    param([System.Collections.Generic.List[string]]$Lines)

    $count = 0
    foreach ($line in $Lines) {
        if ($line -match "SpawnCountBase=(?<spawnCount>\d+),SingleSpawnLimit=(?<singleLimit>\d+)") {
            if ([int]$Matches["spawnCount"] -gt $SpawnCountBase -or [int]$Matches["singleLimit"] -gt $SingleSpawnLimit) {
                $count += 1
            }
        }
    }

    return $count
}

function Limit-SpawnLinesPerWave {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [int]$Limit
    )

    if ($Limit -le 0) {
        return [pscustomobject]@{
            Lines = $Lines
            Skipped = 0
        }
    }

    $limitedLines = New-Object System.Collections.Generic.List[string]
    $skipped = 0

    $groups = $Lines | Group-Object { Get-SpawnLineWave -SpawnLine $_ }
    foreach ($group in ($groups | Sort-Object { [int]$_.Name })) {
        $waveLines = @($group.Group)
        if ($waveLines.Count -le $Limit) {
            foreach ($line in $waveLines) {
                $limitedLines.Add($line)
            }
            continue
        }

        $picked = @($waveLines | Get-Random -Count $Limit)
        foreach ($line in $picked) {
            $limitedLines.Add($line)
        }
        $skipped += ($waveLines.Count - $picked.Count)
    }

    return [pscustomobject]@{
        Lines = $limitedLines
        Skipped = $skipped
    }
}

function Get-BurstSpawnSettings {
    param(
        [int]$Wave,
        [object]$BaseSettings,
        [System.Collections.Generic.List[object]]$SpawnBursts
    )

    if ($DisableSpawnBursts) {
        return $BaseSettings
    }

    $phase = Get-WavePhase -Wave $Wave -Phases $SpawnBursts
    if ($null -eq $phase -or [int]$phase.Chance -le 0) {
        return $BaseSettings
    }

    $chance = [Math]::Min(100, [Math]::Max(0, [int]$phase.Chance))
    $roll = Get-Random -Minimum 1 -Maximum 101
    if ($roll -gt $chance) {
        return $BaseSettings
    }

    $spawnCountBase = [int]$BaseSettings.SpawnCountBase + [int]$phase.SpawnCountBaseBonus
    $singleSpawnLimit = [int]$BaseSettings.SingleSpawnLimit + [int]$phase.SingleSpawnLimitBonus

    $spawnCountBase = [Math]::Min([int]$phase.MaxSpawnCountBase, [Math]::Max(1, $spawnCountBase))
    $singleSpawnLimit = [Math]::Min([int]$phase.MaxSingleSpawnLimit, [Math]::Max(1, $singleSpawnLimit))

    return [pscustomobject]@{
        RelativeStart = [int]$BaseSettings.RelativeStart
        Delay = [int]$BaseSettings.Delay
        SpawnCountBase = $spawnCountBase
        SingleSpawnLimit = $singleSpawnLimit
    }
}

function Get-TemplatePrefix {
    param([string]$Path)

    $template = Get-Content -LiteralPath $Path -Raw
    $marker = "[ZedSpawner.SpawnAtPlayerStart]"
    $index = $template.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)

    if ($index -lt 0) {
        return $template.TrimEnd() + "`r`n`r`n"
    }

    return $template.Substring(0, $index).TrimEnd() + "`r`n`r`n"
}

$zedListFullPath = Resolve-FromScriptRoot $ZedListPath
$probabilityGroupsFullPath = Resolve-FromScriptRoot $ProbabilityGroupsPath
$waveScalingFullPath = Resolve-FromScriptRoot $WaveScalingPath
$safetyNetFullPath = Resolve-FromScriptRoot $SafetyNetPath
$spawnBurstsFullPath = Resolve-FromScriptRoot $SpawnBurstsPath
$templateIniFullPath = Resolve-FromScriptRoot $TemplateIniPath
$outputFullPath = Resolve-FromScriptRoot $OutputPath

if ($InPlace) {
    $outputFullPath = $templateIniFullPath
}

$outputDirectory = Split-Path -Path $outputFullPath -Parent
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
}

if ($StartWave -lt 1) {
    throw "StartWave must be 1 or higher."
}

if ($MaxWave -lt $StartWave) {
    throw "MaxWave must be greater than or equal to StartWave."
}

$sections = Read-ZedList -Path $zedListFullPath
$probabilityConfig = Read-ProbabilityGroups -Path $probabilityGroupsFullPath
$waveScaling = Read-WaveScaling -Path $waveScalingFullPath
$safetyNet = Read-SafetyNet -Path $safetyNetFullPath
$spawnBursts = Read-SpawnBursts -Path $spawnBurstsFullPath
$fallbackProbabilityRange = $probabilityConfig.Groups.Somewhatinthemiddle
$rareProbabilityRange = $RareProbabilityRange

$spawnLines = New-Object System.Collections.Generic.List[string]
$usedNormalZeds = New-Object System.Collections.Generic.HashSet[string]
$skippedBossWaves = New-Object System.Collections.Generic.HashSet[int]
$lockedByScaling = @{}
$caughtBySafetyNet = @{}
$classLimitSkipped = 0
$hasWaveSections = $false

function Add-ScaledSpawnLine {
    param(
        [int]$Wave,
        [string]$ZedClass,
        [object]$ProbabilityRange,
        [string]$Group,
        [object]$SpawnSettings
    )

    $baseProbability = Get-ProbabilityValue -Range $ProbabilityRange
    $probability = Get-ScaledProbability -Wave $Wave -Group $Group -BaseProbability $baseProbability -WaveScaling $waveScaling
    if ($null -eq $probability) {
        if (-not $lockedByScaling.ContainsKey($Group)) {
            $lockedByScaling[$Group] = 0
        }
        $lockedByScaling[$Group] += 1
        return
    }

    $probability = Get-SafetyNetProbability -Wave $Wave -Group $Group -Probability $probability -SafetyNet $safetyNet
    if ($null -eq $probability) {
        if (-not $caughtBySafetyNet.ContainsKey($Group)) {
            $caughtBySafetyNet[$Group] = 0
        }
        $caughtBySafetyNet[$Group] += 1
        return
    }

    $finalSpawnSettings = Get-BurstSpawnSettings -Wave $Wave -BaseSettings $SpawnSettings -SpawnBursts $spawnBursts
    $spawnLines.Add((New-SpawnLine -Wave $Wave -ZedClass $ZedClass -Probability $probability -SpawnSettings $finalSpawnSettings))
}

foreach ($sectionName in $sections.Keys) {
    if ($sectionName -notmatch "^Wave(?<start>\d+)-(?<end>\d+)$") {
        continue
    }

    $hasWaveSections = $true
    $startWave = [int]$Matches["start"]
    $endWave = [int]$Matches["end"]

    foreach ($wave in $startWave..$endWave) {
        if ($wave -lt $StartWave) {
            continue
        }

        if ($wave -gt $MaxWave) {
            continue
        }

        if (Is-BossWave $wave) {
            [void]$skippedBossWaves.Add($wave)
            continue
        }

        foreach ($zed in $sections[$sectionName]) {
            [void]$usedNormalZeds.Add($zed)
            $probabilityRange = $fallbackProbabilityRange
            if ($probabilityConfig.Zeds.ContainsKey($zed)) {
                $probabilityRange = $probabilityConfig.Zeds[$zed]
            }
            $group = Get-ZedGroup -ZedClass $zed -ProbabilityConfig $probabilityConfig

            Add-ScaledSpawnLine -Wave $wave -ZedClass $zed -ProbabilityRange $probabilityRange -Group $group -SpawnSettings $DefaultSpawn
        }
    }
}

if (-not $hasWaveSections -and $sections.Contains("Main")) {
    foreach ($wave in $StartWave..$MaxWave) {
        if (Is-BossWave $wave) {
            [void]$skippedBossWaves.Add($wave)
            continue
        }

        foreach ($zed in $sections["Main"]) {
            [void]$usedNormalZeds.Add($zed)
            $probabilityRange = $fallbackProbabilityRange
            if ($probabilityConfig.Zeds.ContainsKey($zed)) {
                $probabilityRange = $probabilityConfig.Zeds[$zed]
            }
            $group = Get-ZedGroup -ZedClass $zed -ProbabilityConfig $probabilityConfig

            Add-ScaledSpawnLine -Wave $wave -ZedClass $zed -ProbabilityRange $probabilityRange -Group $group -SpawnSettings $DefaultSpawn
        }
    }
}

if ($sections.Contains("Rare")) {
    foreach ($wave in $StartWave..$MaxWave) {
        if (Is-BossWave $wave) {
            [void]$skippedBossWaves.Add($wave)
            continue
        }

        foreach ($zed in $sections["Rare"]) {
            Add-ScaledSpawnLine -Wave $wave -ZedClass $zed -ProbabilityRange $rareProbabilityRange -Group "Haveyouseenhim" -SpawnSettings $RareSpawn
        }
    }
}

$limitResult = Limit-SpawnLinesPerWave -Lines $spawnLines -Limit $MaxClassesPerWave
$spawnLines = $limitResult.Lines
$classLimitSkipped = [int]$limitResult.Skipped
$burstSpawnLines = Get-BurstLineCount -Lines $spawnLines

$prefix = Get-TemplatePrefix -Path $templateIniFullPath
$blockLines = New-Object System.Collections.Generic.List[string]
$blockLines.Add("")
$blockLines.Add("; --- Generated set: waves $StartWave-$MaxWave ---")
$blockLines.Add("; Boss waves skipped: every 5th wave")
$blockLines.Add("; Normal RelativeStart=$($DefaultSpawn.RelativeStart), Delay=$($DefaultSpawn.Delay), SpawnCountBase=$($DefaultSpawn.SpawnCountBase), SingleSpawnLimit=$($DefaultSpawn.SingleSpawnLimit), MaxClassesPerWave=$MaxClassesPerWave")
$blockLines.Add("; Rare RelativeStart=$($RareSpawn.RelativeStart), Delay=$($RareSpawn.Delay), SpawnCountBase=$($RareSpawn.SpawnCountBase), SingleSpawnLimit=$($RareSpawn.SingleSpawnLimit), BaseProbability=$(Format-ProbabilityRange -Range $rareProbabilityRange)")
$blockLines.Add("; Wave scaling: $(if ($DisableWaveScaling) { 'disabled' } else { 'enabled from Config\Wave scaling.ini' })")
$blockLines.Add("; Safety net: $(if ($DisableSafetyNet) { 'disabled' } else { 'enabled from Config\Safety net.ini' })")
$blockLines.Add("; Spawn bursts: $(if ($DisableSpawnBursts) { 'disabled' } else { 'enabled from Config\Spawn bursts.ini' })")
$orderedSpawnLines = @($spawnLines | Sort-Object {
    Get-SpawnLineWave -SpawnLine $_
})
foreach ($spawnLine in $orderedSpawnLines) {
    $blockLines.Add($spawnLine)
}

if ($Append -and (Test-Path -LiteralPath $outputFullPath)) {
    $existingText = (Get-Content -LiteralPath $outputFullPath -Raw).TrimEnd()
    $outputText = $existingText + "`r`n" + (($blockLines -join "`r`n").TrimStart()) + "`r`n"
}
else {
    $contentLines = New-Object System.Collections.Generic.List[string]
    $contentLines.Add($prefix.TrimEnd())
    $contentLines.Add("")
    $contentLines.Add("[ZedSpawner.SpawnAtPlayerStart]")
    $contentLines.Add("")
    $contentLines.Add("[ZedSpawner.SpawnListSpecialWaves]")
    $contentLines.Add("")
    $contentLines.Add("[ZedSpawner.SpawnListRegular]")
    $contentLines.Add("; Generated by Generate-KFZedSpawner.ps1")
    $contentLines.Add("; Use Generate .ini from the window to stack multiple wave ranges with different parameters.")
    $contentLines.AddRange($blockLines)
    $outputText = ($contentLines -join "`r`n") + "`r`n"
}

if ($InPlace -and (Test-Path -LiteralPath $templateIniFullPath)) {
    $backupPath = "$templateIniFullPath.bak"
    Copy-Item -LiteralPath $templateIniFullPath -Destination $backupPath -Force
    Write-Host "Backup written: $backupPath"
}

Set-Content -LiteralPath $outputFullPath -Value $outputText -Encoding ASCII

$unknownZeds = @($usedNormalZeds |
    Where-Object { -not $probabilityConfig.Zeds.ContainsKey($_) } |
    Sort-Object)

Write-Host "Generated: $outputFullPath"
Write-Host "Mode: $(if ($Append) { 'Append set' } else { 'Rebuild file' })"
Write-Host "Wave range: $StartWave-$MaxWave"
Write-Host "Spawn lines: $($spawnLines.Count)"
Write-Host "Boss waves skipped: $((($skippedBossWaves | Sort-Object) -join ', '))"
Write-Host "Normal settings: RelativeStart=$($DefaultSpawn.RelativeStart), Delay=$($DefaultSpawn.Delay), SpawnCountBase=$($DefaultSpawn.SpawnCountBase), SingleSpawnLimit=$($DefaultSpawn.SingleSpawnLimit), MaxClassesPerWave=$MaxClassesPerWave"
Write-Host "Rare settings: RelativeStart=$($RareSpawn.RelativeStart), Delay=$($RareSpawn.Delay), BaseProbability=$(Format-ProbabilityRange -Range $rareProbabilityRange), SpawnCountBase=$($RareSpawn.SpawnCountBase), SingleSpawnLimit=$($RareSpawn.SingleSpawnLimit)"
Write-Host "Wave scaling: $(if ($DisableWaveScaling) { 'disabled' } else { 'enabled' })"
Write-Host "Safety net: $(if ($DisableSafetyNet) { 'disabled' } else { 'enabled' })"
Write-Host "Spawn bursts: $(if ($DisableSpawnBursts) { 'disabled' } else { "enabled ($burstSpawnLines burst lines)" })"
Write-Host "Class limit per wave: $(if ($MaxClassesPerWave -le 0) { 'disabled' } else { "$MaxClassesPerWave classes max ($classLimitSkipped skipped)" })"
if (-not $DisableWaveScaling -and $lockedByScaling.Count -gt 0) {
    Write-Host "Spawn entries skipped before unlock waves:"
    foreach ($group in ($lockedByScaling.Keys | Sort-Object)) {
        Write-Host "  $group`: $($lockedByScaling[$group])"
    }
}
if (-not $DisableSafetyNet -and $caughtBySafetyNet.Count -gt 0) {
    Write-Host "Spawn entries caught by safety net:"
    foreach ($group in ($caughtBySafetyNet.Keys | Sort-Object)) {
        Write-Host "  $group`: $($caughtBySafetyNet[$group])"
    }
}
Write-Host "Normal zeds without probability group: $($unknownZeds.Count)"

if ($unknownZeds.Count -gt 0) {
    Write-Host "These used the Somewhatinthemiddle probability ($(Format-ProbabilityRange -Range $fallbackProbabilityRange)):"
    $unknownZeds | ForEach-Object { Write-Host "  $_" }
}
