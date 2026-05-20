KF Zed Spawner Tool by Zerolitter
===================

Small helper tool for generating a KFZedSpawner.ini from a zed class list.

The goal is to avoid manually writing hundreds or thousands of Spawn=(...) lines.


Folders
-------

Config/
    Original .ini/KFZedSpawner.ini
    List of zeds.txt
    Regularzeds.txt
    Zed probability groups.ini
    Wave scaling.ini
    Safety net.ini
    Spawn bursts.ini
    Tool preset.json

Data/
    Generate-KFZedSpawner.ps1
    Start-ZedSpawnerTool.ps1

Generated/
    KFZedSpawner.ini

Start Tool.cmd


Start The Tool
--------------

Double-click:

    Start Tool.cmd

This launcher is portable. It uses relative paths, so it should still work after downloading or moving the folder.

The local KF Zed Spawner Tool.lnk shortcut is only for this machine and is not needed.



Main Files
----------

Config\List of zeds.txt

Contains the zed classes. Basic sections:

    Rare
    ZEDSx.Golden_Clot

    List
    SomePackage.SomeZedClass

    Bosses
    SomePackage.SomeBossClass


Config\Regularzeds.txt

Contains the vanilla KFGameContent zeds, one class per line.


Config\Zed probability groups.ini

Controls how likely each zed is. Move zeds between buckets to rebalance them.
The buckets are used as an easy-to-hard/common-to-rare scale.

    [VeryLikely]

    [AboveAvarage]

    [Somewhatinthemiddle]

    [Unlikely]

    [VeryUnlikely]

    [Haveyouseenhim]


Config\Wave scaling.ini

Controls when each bucket is allowed to appear.
This prevents rare or very hard zeds from leaking into wave 1 just because their probability is low.

Each bucket has:

    UnlockWave
    FullWave
    FadeStartWave
    FadeEndWave
    LateMultiplier

Before UnlockWave, that bucket is not written into the generated INI.
Between UnlockWave and FullWave, the bucket ramps from low probability to the normal probability from the tool window.
Easy buckets can fade down later with LateMultiplier.

Default idea:

    VeryLikely starts at wave 1.
    AboveAvarage starts at wave 3.
    Somewhatinthemiddle starts at wave 7.
    Unlikely starts at wave 13.
    VeryUnlikely starts at wave 22.
    Haveyouseenhim starts at wave 31.


Config\Safety net.ini

Adds boss-milestone guardrails on top of Wave scaling.
Lower groups can still appear in later phases, but harder groups are capped or softened until the safety net loosens.

Each wave range can use:

    MaxGroup
    SomeGroupMultiplier

Example:

    [Wave11-14]
    MaxGroup=Unlikely
    UnlikelyMultiplier=35

That means waves 11-14 can include easy groups, middle groups, and Unlikely, but not VeryUnlikely or Haveyouseenhim.
Unlikely zeds are also reduced to 35 percent of their already-scaled probability.


Config\Spawn bursts.ini

Creates occasional hurdles by raising SpawnCountBase and SingleSpawnLimit on some generated spawn lines.
Most lines stay at the window values. A few become pack spikes.

Each wave range can use:

    Chance
    SpawnCountBaseBonus
    SingleSpawnLimitBonus
    MaxSpawnCountBase
    MaxSingleSpawnLimit

Example:

    [Wave26-29]
    Chance=19
    SpawnCountBaseBonus=1
    SingleSpawnLimitBonus=2
    MaxSpawnCountBase=2
    MaxSingleSpawnLimit=3

That means each spawn line in waves 26-29 has a 19 percent chance to become a bigger pack, clamped at SpawnCountBase 2 and SingleSpawnLimit 3.


Generated\KFZedSpawner.ini

This is the generated file to use on the server. The name casing matters on Linux.


Buttons
-------

Generate Preview

    Rebuilds Generated\KFZedSpawner.ini from scratch with the current settings.

Generate .ini

    Adds the current wave range and settings as a new generated block.
    Use this when you want different settings for different wave ranges.

Overwrite INI

    Writes into Config\KFZedSpawner.ini and creates a .bak backup first.

Set Preset

    Saves the current window values to Config\Tool preset.json.
    The tool loads these values next time it opens.

Open Scaling

    Opens Config\Wave scaling.ini.

Open Safety

    Opens Config\Safety net.ini.

Open Bursts

    Opens Config\Spawn bursts.ini.


Wave Ranges
-----------

Use:

    StartWave
    EndWave
    MaxClassesPerWave

Boss waves are skipped automatically every 5 waves:

    5, 10, 15, 20, 25, ...

Example workflow:

    StartWave=1
    EndWave=14
    Generate Preview

    Change parameters
    StartWave=16
    EndWave=29
    Generate .ini

The generated file will keep both blocks.

MaxClassesPerWave controls how many zed classes can be written for each regular wave.

    0 = write all available classes
    20 = randomly keep up to 20 classes per wave

The limit is applied after probability groups, wave scaling, safety net, and spawn bursts are calculated.


Probability Min / Max
---------------------

Each probability bucket has two boxes:

    Min / Max

If both values are the same, the probability is fixed.

If the values are different, the generator randomly picks a value between them for each spawn line.

Example:

    VeryLikely 25 / 40

This can generate probabilities from 25 through 40.

Rare Spawn Entry also has its own Probability Min / Max row.
This controls only the zeds in the Rare section of Config\List of zeds.txt.
It is separate from the Haveyouseenhim bucket.


Spawn Sections
--------------

Generated spawn lines are written under:

    [ZedSpawner.SpawnListRegular]

The generated file also keeps:

    [ZedSpawner.SpawnAtPlayerStart]

    [ZedSpawner.SpawnListSpecialWaves]


Notes
-----

- Keep class names exact.
- Linux servers are case-sensitive, so use KFZedSpawner.ini.
- Boss generation is not implemented yet. You’ll have to handle that part yourself :)
- Rare zeds use the Rare Spawn Entry probability range.
