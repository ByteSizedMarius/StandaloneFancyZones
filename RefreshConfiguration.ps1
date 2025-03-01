# Define current directory
$currentDir = $PSScriptRoot

# Check possible locations for FancyZones.exe
$possibleLocations = @(
    # Current directory might be parent of deployment
    (Join-Path -Path $currentDir -ChildPath "deployment\src\PowerToys.FancyZones.exe"),
    # Current directory might be src directory
    (Join-Path -Path $currentDir -ChildPath "PowerToys.FancyZones.exe")
)

# Find FancyZones executable
$fancyZonesExePath = $null
foreach ($location in $possibleLocations) {
    if (Test-Path -Path $location -PathType Leaf) {
        $fancyZonesExePath = $location
        $deploymentSrcDir = Split-Path -Path $fancyZonesExePath -Parent
        Write-Output "Found FancyZones executable at: $fancyZonesExePath"
        break
    }
}

# Exit if FancyZones executable not found
if (-not $fancyZonesExePath) {
    Write-Error "FancyZones executable (PowerToys.FancyZones.exe) not found in any of the expected locations."
    Write-Error "Please ensure you are running this script from either the parent directory of 'deployment' or from within the 'src' directory."
    exit
}

# Define FancyZones configuration directory
$fancyZonesConfigDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\PowerToys\FancyZones"

# Check if FancyZones configuration directory exists
if (Test-Path -Path $fancyZonesConfigDir -PathType Container) {
    Write-Warning "FancyZones configuration directory exists at: $fancyZonesConfigDir"
    Write-Warning "Continuing will try to refresh existing monitor settings. You may want to backup your configuration first."
    Write-Host "Press Enter to continue and refresh configuration, or Ctrl+C to cancel..." -ForegroundColor Yellow
    Read-Host | Out-Null
    Write-Host "Continuing with configuration refresh..." -ForegroundColor Green
}

# Execute FancyZones to generate/refresh editor params
if (Test-Path -Path $fancyZonesConfigDir -PathType Container) {
    $actionDescription = "Refreshing"
} else {
    $actionDescription = "Generating"
}
Write-Output "$actionDescription FancyZones editor parameters..."
try {
    Start-Process -FilePath $fancyZonesExePath -ArgumentList "--generate-editor-params" -Wait -NoNewWindow
    Write-Output "FancyZones editor parameters $($actionDescription.ToLower()) successfully."
} catch {
    Write-Error "Failed to execute PowerToys.FancyZones.exe: $_"
    exit
}

# Check if FancyZones config directory exists after execution
if (-not (Test-Path -Path $fancyZonesConfigDir -PathType Container)) {
    Write-Error "FancyZones configuration directory was not found at: $fancyZonesConfigDir"
    Write-Error "The application may have failed to initialize properly."
    exit
} else {
    if (Test-Path -Path "$fancyZonesConfigDir\*" -PathType Leaf) {
        $dirAction = "updated"
    } else {
        $dirAction = "created"
    }
    Write-Output "FancyZones configuration directory successfully $dirAction at: $fancyZonesConfigDir"
}

# Define JSON content for settings files
$LogSettings = @"
{"logLevel":"warn"}
"@

$Settings = @"
{"properties":{"fancyzones_shiftDrag":{"value":true},"fancyzones_mouseSwitch":{"value":false},"fancyzones_mouseMiddleClickSpanningMultipleZones":{"value":false},"fancyzones_overrideSnapHotkeys":{"value":false},"fancyzones_moveWindowAcrossMonitors":{"value":false},"fancyzones_moveWindowsBasedOnPosition":{"value":false},"fancyzones_overlappingZonesAlgorithm":{"value":0},"fancyzones_displayOrWorkAreaChange_moveWindows":{"value":true},"fancyzones_zoneSetChange_moveWindows":{"value":false},"fancyzones_appLastZone_moveWindows":{"value":false},"fancyzones_openWindowOnActiveMonitor":{"value":false},"fancyzones_restoreSize":{"value":false},"fancyzones_quickLayoutSwitch":{"value":false},"fancyzones_flashZonesOnQuickSwitch":{"value":true},"use_cursorpos_editor_startupscreen":{"value":true},"fancyzones_show_on_all_monitors":{"value":false},"fancyzones_span_zones_across_monitors":{"value":false},"fancyzones_makeDraggedWindowTransparent":{"value":false},"fancyzones_allowPopupWindowSnap":{"value":false},"fancyzones_allowChildWindowSnap":{"value":true},"fancyzones_disableRoundCornersOnSnap":{"value":false},"fancyzones_zoneHighlightColor":{"value":"#0078D7"},"fancyzones_highlight_opacity":{"value":50},"fancyzones_editor_hotkey":{"value":{"win":true,"ctrl":false,"alt":false,"shift":true,"code":192,"key":""}},"fancyzones_windowSwitching":{"value":false},"fancyzones_nextTab_hotkey":{"value":{"win":true,"ctrl":false,"alt":false,"shift":false,"code":34,"key":""}},"fancyzones_prevTab_hotkey":{"value":{"win":true,"ctrl":false,"alt":false,"shift":false,"code":33,"key":""}},"fancyzones_excluded_apps":{"value":""},"fancyzones_zoneBorderColor":{"value":"#FFFFFF"},"fancyzones_zoneColor":{"value":"#F5FCFF"},"fancyzones_zoneNumberColor":{"value":"#000000"},"fancyzones_systemTheme":{"value":true},"fancyzones_showZoneNumber":{"value":true}},"name":"FancyZones","version":"1.0"}
"@

# Create settings files
try {
    $logSettingsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\PowerToys\log_settings.json"
    $fancyZonesSettingsPath = Join-Path -Path $fancyZonesConfigDir -ChildPath "settings.json"
    
    Set-Content -Path $logSettingsPath -Value $LogSettings
    Set-Content -Path $fancyZonesSettingsPath -Value $Settings
    
    Write-Output "Settings files created successfully:"
    Write-Output "  - Log settings: $logSettingsPath"
    Write-Output "  - FancyZones settings: $fancyZonesSettingsPath"
} catch {
    Write-Error "Failed to create settings files: $_"
    exit
}

Write-Output "Completed successfully."