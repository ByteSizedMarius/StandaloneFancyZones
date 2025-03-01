[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PowerToysRepoPath
)

# Function to check if path exists and is a directory
function Test-ValidDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$ErrorMessage = "Directory does not exist: $Path"
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Error $ErrorMessage
        return $false
    }
    return $true
}

# Function to create shortcut
function New-Shortcut {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        
        [Parameter(Mandatory = $true)]
        [string]$ShortcutPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.Arguments = $Arguments
        $Shortcut.Description = $Description
        $Shortcut.WorkingDirectory = Split-Path -Path $TargetPath -Parent
        $Shortcut.Save()
        Write-Output "Created shortcut: $ShortcutPath"
        return $true
    } catch {
        Write-Error "Failed to create shortcut: $_"
        return $false
    }
}

# Define paths
$currentDir = $PSScriptRoot
$dependenciesFilePath = Join-Path -Path $currentDir -ChildPath "FancyZonesDependencies.txt"
$deploymentDir = Join-Path -Path $currentDir -ChildPath "deployment"
$deploymentSrcDir = Join-Path -Path $deploymentDir -ChildPath "src"
$repoReleaseDir = Join-Path -Path $PowerToysRepoPath -ChildPath "x64\Release"
$fancyZonesConfigDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\PowerToys\FancyZones"

# Check if dependencies file exists
if (-not (Test-Path -Path $dependenciesFilePath -PathType Leaf)) {
    Write-Error "Dependencies file not found: $dependenciesFilePath"
    exit
}

# Check if PowerToys repo directory is valid
if (-not (Test-ValidDirectory -Path $PowerToysRepoPath -ErrorMessage "PowerToys repository directory not found: $PowerToysRepoPath")) {
    exit
}

# Check if Release directory exists
if (-not (Test-ValidDirectory -Path $repoReleaseDir -ErrorMessage "Release directory not found: $repoReleaseDir")) {
    exit
}

# Create deployment and src directories if they don't exist
if (-not (Test-Path -Path $deploymentDir -PathType Container)) {
    Write-Information "Creating deployment directory at: $deploymentDir"
    New-Item -Path $deploymentDir -ItemType Directory | Out-Null
}

if (-not (Test-Path -Path $deploymentSrcDir -PathType Container)) {
    Write-Information "Creating deployment source directory at: $deploymentSrcDir"
    New-Item -Path $deploymentSrcDir -ItemType Directory | Out-Null
}

# Read dependencies file
try {
    $dependencies = Get-Content -Path $dependenciesFilePath -ErrorAction Stop
} catch {
    Write-Error "Failed to read dependencies file: $_"
    exit
}

# Copy dependencies to src directory
foreach ($dependency in $dependencies) {
    $dependency = $dependency.Trim()
    if ([string]::IsNullOrWhiteSpace($dependency)) {
        continue
    }
    
    $sourcePath = Join-Path -Path $repoReleaseDir -ChildPath $dependency
    $destinationPath = Join-Path -Path $deploymentSrcDir -ChildPath $dependency
    
    # Create destination directory structure if it doesn't exist
    $destinationDirectory = Split-Path -Path $destinationPath -Parent
    if (-not (Test-Path -Path $destinationDirectory -PathType Container)) {
        try {
            New-Item -Path $destinationDirectory -ItemType Directory -Force | Out-Null
            Write-Output "Created directory: $destinationDirectory"
        } catch {
            Write-Error "Failed to create directory $destinationDirectory`: $_"
            continue
        }
    }
    
    if (Test-Path -Path $sourcePath -PathType Leaf) {
        try {
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force
            Write-Output "Copied $dependency"
        } catch {
            Write-Error "Failed to copy $dependency`: $_"
        }
    } else {
        Write-Warning "Dependency not found: $sourcePath"
    }
}

# Copy FancyZones executables to src directory
$fancyZonesExes = @("PowerToys.FancyZones.exe", "PowerToys.FancyZonesEditor.exe")
foreach ($exe in $fancyZonesExes) {
    $sourcePath = Join-Path -Path $repoReleaseDir -ChildPath $exe
    $destinationPath = Join-Path -Path $deploymentSrcDir -ChildPath $exe
    
    if (Test-Path -Path $sourcePath -PathType Leaf) {
        try {
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force
            Write-Output "Copied $exe"
        } catch {
            Write-Error "Failed to copy $exe`: $_"
        }
    } else {
        Write-Error "Required executable not found: $sourcePath"
    }
}

# Copy RefreshConfiguration.ps1 from current directory to deployment
$scriptName = "RefreshConfiguration.ps1"
$scriptPath = Join-Path -Path $currentDir -ChildPath $scriptName
$scriptDestination = Join-Path -Path $deploymentSrcDir -ChildPath $scriptName

if (Test-Path -Path $scriptPath -PathType Leaf) {
    try {
        Copy-Item -Path $scriptPath -Destination $scriptDestination -Force
        Write-Output "Copied $scriptName to deployment directory"
    } catch {
        Write-Error "Failed to copy $scriptName`: $_"
    }
} else {
    Write-Error "Script not found: $scriptPath"
}

Write-Output "Source files deployment completed successfully to: $deploymentSrcDir"

# Create restart script in the src directory
$restartScriptContent = @"
# PowerToys.FancyZones Restart Script
Get-Process | Where-Object { `$_.ProcessName -eq "PowerToys.FancyZones" } | Stop-Process -Force
Start-Process "`$PSScriptRoot\PowerToys.FancyZones.exe"
"@

$restartScriptPath = Join-Path -Path $deploymentSrcDir -ChildPath "Restart-FancyZones.ps1"
$restartScriptContent | Out-File -FilePath $restartScriptPath -Encoding UTF8
Write-Output "Created restart script: $restartScriptPath"

# Create stop script in the src directory
$stopScriptContent = @"
# PowerToys.FancyZones Stop Script
Get-Process | Where-Object { `$_.ProcessName -eq "PowerToys.FancyZones" } | Stop-Process -Force
"@
$stopScriptPath = Join-Path -Path $deploymentSrcDir -ChildPath "Stop-FancyZones.ps1"
$stopScriptContent | Out-File -FilePath $stopScriptPath -Encoding UTF8
Write-Output "Created stop script: $stopScriptPath"

# Create shortcuts in the deployment directory
# 1. Main executable shortcuts
foreach ($exe in $fancyZonesExes) {
    $exePath = Join-Path -Path $deploymentSrcDir -ChildPath $exe
    $shortcutPath = Join-Path -Path $deploymentDir -ChildPath "$exe.lnk"
    $powerShellPath = (Get-Command powershell).Source
    
    if (Test-Path -Path $exePath -PathType Leaf) {
        if ($exe -eq "PowerToys.FancyZones.exe") {
            # Direct shortcut for FancyZones.exe
            $description = "Run $exe"
            New-Shortcut -TargetPath $exePath -ShortcutPath $shortcutPath -Description $description
        } else {
            # For FancyZonesEditor.exe, create a shortcut that runs the editor and then restarts FancyZones
            $description = "Run $exe and restart FancyZones"
            $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {Start-Process -FilePath '$exePath' -Wait; & '$restartScriptPath'}`""
            New-Shortcut -TargetPath $powerShellPath -ShortcutPath $shortcutPath -Arguments $arguments -Description $description
        }
    } else {
        Write-Error "Cannot create shortcut: Target file not found: $exePath"
    }
}

# Create shortcut for RefreshConfiguration.ps1
$refreshScriptPath = Join-Path -Path $deploymentSrcDir -ChildPath "RefreshConfiguration.ps1"
$refreshShortcutPath = Join-Path -Path $deploymentDir -ChildPath "RefreshConfiguration.lnk"
$refreshDescription = "Refresh FancyZones configuration and restart"
$refreshArguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {& '$refreshScriptPath'; & '$restartScriptPath'}`""
New-Shortcut -TargetPath $powerShellPath -ShortcutPath $refreshShortcutPath -Arguments $refreshArguments -Description $refreshDescription
Write-Output "Created refresh configuration shortcut: $refreshShortcutPath"

# 2. Restart FancyZones shortcut
$powerShellPath = (Get-Command powershell).Source
$restartShortcutPath = Join-Path -Path $deploymentDir -ChildPath "Restart-FancyZones.lnk"
$restartArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$restartScriptPath`""
New-Shortcut -TargetPath $powerShellPath -ShortcutPath $restartShortcutPath -Arguments $restartArguments -Description "Restart FancyZones"

# 3. Stop FancyZones shortcut
$stopShortcutPath = Join-Path -Path $deploymentDir -ChildPath "Stop-FancyZones.lnk"
$stopArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$stopScriptPath`""
New-Shortcut -TargetPath $powerShellPath -ShortcutPath $stopShortcutPath -Arguments $stopArguments -Description "Stop FancyZones"

Write-Output "Shortcuts created in: $deploymentDir"
Write-Output "Deployment completed successfully!"