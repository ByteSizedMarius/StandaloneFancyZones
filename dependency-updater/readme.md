# Regenerating dependencies
- May be required when updating
- Adapted to use release directory (result of recompilation) instead of MSI
- Basic rundown
	- Find dependencies using procmon during all possible usage scenarios of FancyZones
	- Filter for dependencies actually part of the deployment (not win32 ones)
	- Filter for dependencies actually present in the release

> Mainly based on [github.com/rolandas-rimkus](https://github.com/rolandas-rimkus/FancyZones/blob/main/README.md)

1. Run `temp\ProcessMonitor\Procmon64.exe`
2. Run `PowerToys.FancyZonesEditor.exe`
	- Create a new layout, edit some of the settings and enable it
3. Run `PowerToys.FancyZones.exe`
4. Drag windows to the created layout to test that Fancy Zones works as expected
5. Filter down the events to only include events from `PowerToys.FancyZones.exe` and `PowerToys.FancyZonesEditor.exe`
6. Export the results as csv using `Tools` > `File Summary` > `By Folder` > `Save`
7. Call `Convert-Procmon.ps1 -Path ./path/to/csv.csv`
8. Call `Test-DependencyExistence.ps1 -DllPath "/path/to/PowerToys/Repo/x64/Release"
9. The result `NewDependencies.txt` is the new `FancyZonesDependencies.txt`
10. Regenerate the deployment