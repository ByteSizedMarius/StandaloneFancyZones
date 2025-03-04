param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

# Check if file exists
if (-not (Test-Path -Path $Path)) {
    Write-Error File not found: $Path
    exit 1
}

$namesList = @()
$basePath = $null
$filteredList = @()
$relativeList = @()
$csvContent = Get-Content -Path $Path -Raw

# Split into lines and skip header
$lines = $csvContent -split "`r?`n" | Select-Object -Skip 1

# Process each line to extract names
foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    
    # Extract name (first field before first comma)
    $name = ($line -split ',')[0]
    
    # Remove any quotes if present
    $name = $name -replace '"', ''
    
    # Add to list
    $namesList += $name
}

# Find exe to extract base path
# We only care about dependencies in the base path, not system files
$targetFile = $namesList | Where-Object { $_ -like "*PowerToys.FancyZonesEditor.exe" } | Select-Object -First 1

if ($targetFile) {
    # Extract the base path (directory containing the target file)
    $basePath = [System.IO.Path]::GetDirectoryName($targetFile)
    Write-Host Base path found: $basePath
    
    # Filter for files that are in the base path AND have an extension (removing directories)
    $filteredList = $namesList | Where-Object { 
        $_ -like "$basePath\*" -and 
        [System.IO.Path]::HasExtension($_) 
    }
    
    # Create relative paths by removing the base path
    $basePathWithSlash = "$basePath\"
    $relativeList = $filteredList | ForEach-Object {
        $_.Substring($basePathWithSlash.Length)
    }
    
    # Save to file in current directory
    $outputFile = ".\UnfilteredDependencies.txt"
    $relativeList | Out-File -FilePath $outputFile
    Write-Host "Relative paths saved to $outputFile"
} else {
    Write-Error "Could not find PowerToys.FancyZonesEditor.exe in the list"
}