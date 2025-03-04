param(
    [Parameter(Mandatory=$true)]
    [string]$DllPath,
    
    [Parameter(Mandatory=$false)]
    [string]$DependencyFile = ".\UnfilteredDependencies.txt"
)

# Check if dependency file exists
if (-not (Test-Path -Path $DependencyFile)) {
    Write-Error "Dependency file not found: $DependencyFile"
    exit 1
}

# Check if DLL path exists
if (-not (Test-Path -Path $DllPath)) {
    Write-Error "DLL path not found: $DllPath"
    exit 1
}

$dependencies = Get-Content -Path $DependencyFile
$existCount = 0
$missingCount = 0
$existingFiles = @()

# Check if each file exists in the DLL path
Write-Host "Checking for files in $DllPath..."
foreach ($file in $dependencies) {
    if ([string]::IsNullOrWhiteSpace($file)) {
        continue
    }
    $fullPath = Join-Path -Path $DllPath -ChildPath $file
    if (Test-Path -Path $fullPath) {
        $existCount++
        $existingFiles += $file
    } else {
        $missingCount++
    }
}

Write-Host "`nSummary:"
Write-Host "- Total dependencies: $($existCount + $missingCount)"
Write-Host "- Found: $existCount" -ForegroundColor Green
Write-Host "- Missing: $missingCount" -ForegroundColor Red

# Export existing files list
if ($existCount -gt 0) {
    $existingFiles | Out-File -FilePath ".\NewDependencies.txt"
    Write-Host "`nDependencies saved to .\NewDependencies.txt"
}