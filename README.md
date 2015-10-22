# rom-cleanup.swift
A Swift script for cleaning up ROMs.

This script navigates its current directory and all subdirectories looking for ROMs. When it finds a verified good ROM in the region specified, it will copy it to a new directory with a name like `NES (U) [!]`. If the region can't be determined, the ROM will be copied into a new directory with a name like `NEW (Unkown region) [!]`. This happens for multi-region ROMs like `Excitebike (JU) [!].nes` or `Kid Icarus (UE) [!].nes`.

When the ROM is copied, the name will be cleaned up by removing the known codes like region `(U)` and Verified Good Dump `[!]`. For more information on these codes, [check out this explanation provided by 64bitorless](https://64bitorless.wordpress.com/rom-suffix-explanations/)


### Usage
1. Place `rom-cleanup.swift` in the directory where all your ROMs are located.
2. `cd` to said directory
3. `swift rom-cleanup.swift`

### // TODO:
* don't require changing the script, add variables to the execution
 * allow region to be passed as a variable, else process all
 * allow ROM type to be passed as a variable, else process all
* add more documentation in the script
* clean up the script
* improve performance
