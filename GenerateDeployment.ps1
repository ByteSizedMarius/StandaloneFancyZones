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
$restartScriptContent = @'
# PowerToys.FancyZones Restart Script
Write-Host "Stopping any running FancyZones processes..." -ForegroundColor Cyan
Get-Process | Where-Object { $_.ProcessName -eq "PowerToys.FancyZones" } | Stop-Process -Force

Write-Host "Starting FancyZones..." -ForegroundColor Cyan
Start-Process "$PSScriptRoot\PowerToys.FancyZones.exe"
Write-Host "FancyZones started successfully." -ForegroundColor Green
'@

$restartScriptPath = Join-Path -Path $deploymentSrcDir -ChildPath "Restart-FancyZones.ps1"
$restartScriptContent | Out-File -FilePath $restartScriptPath -Encoding UTF8
Write-Output "Created restart script: $restartScriptPath"

# Create stop script in the src directory
$stopScriptContent = @'
# PowerToys.FancyZones Stop Script
Write-Host "Stopping any running FancyZones processes..." -ForegroundColor Cyan
Get-Process | Where-Object { $_.ProcessName -eq "PowerToys.FancyZones" } | Stop-Process -Force
Write-Host "FancyZones stopped successfully." -ForegroundColor Green
'@

$stopScriptPath = Join-Path -Path $deploymentSrcDir -ChildPath "Stop-FancyZones.ps1"
$stopScriptContent | Out-File -FilePath $stopScriptPath -Encoding UTF8
Write-Output "Created stop script: $stopScriptPath"

# Create wrapper scripts in the deployment directory
# 1. Script to run FancyZones.exe
$runFancyZonesContent = @'
# Run FancyZones
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent -Path $scriptPath
$exePath = Join-Path -Path $scriptDir -ChildPath "src\PowerToys.FancyZones.exe"

Write-Host "Starting FancyZones from: $exePath" -ForegroundColor Cyan
Start-Process -FilePath $exePath
Write-Host "FancyZones started successfully." -ForegroundColor Green
'@

$runFancyZonesPath = Join-Path -Path $deploymentDir -ChildPath "Run-FancyZones.ps1"
$runFancyZonesContent | Out-File -FilePath $runFancyZonesPath -Encoding UTF8
Write-Output "Created Run-FancyZones script: $runFancyZonesPath"

# 2. Script to run FancyZonesEditor.exe and restart FancyZones
$runEditorContent = @'
# Run FancyZones Editor and restart FancyZones
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent -Path $scriptPath
$editorPath = Join-Path -Path $scriptDir -ChildPath "src\PowerToys.FancyZonesEditor.exe"
$restartPath = Join-Path -Path $scriptDir -ChildPath "src\Restart-FancyZones.ps1"

Write-Host "Starting FancyZones Editor from: $editorPath" -ForegroundColor Cyan
Start-Process -FilePath $editorPath -Wait
Write-Host "FancyZones Editor closed. Restarting FancyZones..." -ForegroundColor Cyan

# Restart FancyZones after editor is closed
& $restartPath
'@

$runEditorPath = Join-Path -Path $deploymentDir -ChildPath "Run-FancyZonesEditor.ps1"
$runEditorContent | Out-File -FilePath $runEditorPath -Encoding UTF8
Write-Output "Created Run-FancyZonesEditor script: $runEditorPath"

# 3. Script to refresh configuration and restart FancyZones
$refreshConfigContent = @'
# Refresh FancyZones configuration and restart
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent -Path $scriptPath
$refreshPath = Join-Path -Path $scriptDir -ChildPath "src\RefreshConfiguration.ps1"
$restartPath = Join-Path -Path $scriptDir -ChildPath "src\Restart-FancyZones.ps1"

Write-Host "Refreshing FancyZones configuration..." -ForegroundColor Cyan
& $refreshPath

Write-Host "Configuration refreshed. Restarting FancyZones..." -ForegroundColor Cyan
& $restartPath
'@

$refreshConfigPath = Join-Path -Path $deploymentDir -ChildPath "Refresh-FancyZonesConfig.ps1"
$refreshConfigContent | Out-File -FilePath $refreshConfigPath -Encoding UTF8
Write-Output "Created Refresh-FancyZonesConfig script: $refreshConfigPath"

# 4. Script to stop FancyZones
$stopFancyZonesContent = @'
# Stop FancyZones
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent -Path $scriptPath
$stopPath = Join-Path -Path $scriptDir -ChildPath "src\Stop-FancyZones.ps1"

Write-Host "Stopping FancyZones..." -ForegroundColor Cyan
& $stopPath
'@

$stopFancyZonesPath = Join-Path -Path $deploymentDir -ChildPath "Stop-FancyZones.ps1"
$stopFancyZonesContent | Out-File -FilePath $stopFancyZonesPath -Encoding UTF8
Write-Output "Created Stop-FancyZones script: $stopFancyZonesPath"

Write-Output "Wrapper scripts created in: $deploymentDir"
Write-Output "Deployment completed successfully!"