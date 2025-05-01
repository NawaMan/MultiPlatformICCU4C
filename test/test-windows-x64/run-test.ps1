param (
    [string]$ICUPackage,
    [string]$SharedTestCpp,
    [string]$SharedCMake
)

# Stop on first error
$ErrorActionPreference = "Stop"

# Set variables
$BITNESS = 64
$CPP_VERSION = 23

Write-Host "Running ICU4C tests on Windows x64..."

# Create test directory
$TestDir = Join-Path $env:TEMP "icu4c-test"
if (Test-Path $TestDir) {
    Remove-Item -Recurse -Force $TestDir
}
New-Item -ItemType Directory -Path $TestDir | Out-Null

# Extract the ICU package
Write-Host "Extracting ICU package: $ICUPackage"
$ICUDir = Join-Path $TestDir "icu"
New-Item -ItemType Directory -Path $ICUDir | Out-Null

# Check if the ICU package exists
if (-not (Test-Path $ICUPackage)) {
    Write-Host "Error: ICU package not found at $ICUPackage"
    Write-Host "Looking for alternative packages..."
    
    # Try to find any ICU package in the dist directory
    $ParentDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $DistDir = Join-Path $ParentDir "dist"
    $AlternativePackages = Get-ChildItem -Path $DistDir -Filter "*windows*64*.zip"
    
    if ($AlternativePackages.Count -gt 0) {
        $ICUPackage = $AlternativePackages[0].FullName
        Write-Host "Found alternative package: $ICUPackage"
    } else {
        Write-Host "No ICU packages found in $DistDir"
        exit 1
    }
}

# Use PowerShell to extract the ZIP file
Write-Host "Extracting: $ICUPackage to $ICUDir"
try {
    Expand-Archive -Path $ICUPackage -DestinationPath $ICUDir -Force
} catch {
    Write-Host "Error extracting ZIP file: $_"
    exit 1
}

# Display the package structure
Write-Host "ICU package contents:"
Get-ChildItem -Path $ICUDir | Format-Table -AutoSize

# Check if include directory exists
$IncludeDir = Join-Path $ICUDir "include\unicode"
if (Test-Path $IncludeDir) {
    Write-Host "ICU include directory found!"
    Get-ChildItem -Path $IncludeDir -File | Select-Object -First 10 | Format-Table -AutoSize
} else {
    Write-Host "ICU include directory not found. Creating from source..."
    
    # Create include directory structure
    New-Item -ItemType Directory -Path $IncludeDir -Force | Out-Null
    
    # Copy header files from common, i18n, and io directories
    $CommonDir = Join-Path $ICUDir "common"
    if (Test-Path $CommonDir) {
        Write-Host "Copying headers from common directory..."
        Get-ChildItem -Path $CommonDir -Filter "*.h" -Recurse | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $IncludeDir
        }
    }
    
    $I18nDir = Join-Path $ICUDir "i18n"
    if (Test-Path $I18nDir) {
        Write-Host "Copying headers from i18n directory..."
        Get-ChildItem -Path $I18nDir -Filter "*.h" -Recurse | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $IncludeDir
        }
    }
    
    $IoDir = Join-Path $ICUDir "io"
    if (Test-Path $IoDir) {
        Write-Host "Copying headers from io directory..."
        Get-ChildItem -Path $IoDir -Filter "*.h" -Recurse | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $IncludeDir
        }
    }
    
    Write-Host "Headers copied to include/unicode/"
    Get-ChildItem -Path $IncludeDir -File | Select-Object -First 10 | Format-Table -AutoSize
}

# Check for ICU data files
Write-Host "Checking for ICU data file..."

# Get ICU version from the package name
$ICUVersionMatch = [regex]::Match($ICUPackage, "icu4c-(\d+\.\d+)")
$ICUVersion = $ICUVersionMatch.Groups[1].Value
if ([string]::IsNullOrEmpty($ICUVersion)) {
    $ICUVersion = "77.1"  # Default if not found
}
$ICUMajorVersion = $ICUVersion.Split('.')[0]

# Check for the ICU data file in the known location
$DataFile = Join-Path $ICUDir "share\icu\$ICUVersion\icudt${ICUMajorVersion}l.dat"
$ICUDataDir = Join-Path $TestDir "icu_data"

if (Test-Path $DataFile) {
    Write-Host "Found ICU data file: $DataFile"
    
    # Create a directory for the data file and set up environment variable
    New-Item -ItemType Directory -Path $ICUDataDir -Force | Out-Null
    Copy-Item -Path $DataFile -Destination $ICUDataDir
    $env:ICU_DATA = $ICUDataDir
    
    # Verify the data file is accessible
    Write-Host "Verifying ICU data file access:"
    Get-ChildItem -Path $ICUDataDir | Format-Table -AutoSize
} else {
    Write-Host "ICU data file not found at $DataFile"
    Write-Host "Searching for data file in other locations..."
    
    # Search for data file in other common locations
    $DataFilePatterns = @(
        "share\icu\*\icudt*l.dat",
        "share\icu\icudt*l.dat",
        "data\icudt*l.dat",
        "icudt*l.dat"
    )
    
    $DataFileFound = $false
    foreach ($Pattern in $DataFilePatterns) {
        $FoundFiles = Get-ChildItem -Path $ICUDir -Filter $Pattern -Recurse -ErrorAction SilentlyContinue
        if ($FoundFiles.Count -gt 0) {
            $DataFile = $FoundFiles[0].FullName
            Write-Host "Found ICU data file: $DataFile"
            
            # Create a directory for the data file and set up environment variable
            New-Item -ItemType Directory -Path $ICUDataDir -Force | Out-Null
            Copy-Item -Path $DataFile -Destination $ICUDataDir
            $env:ICU_DATA = $ICUDataDir
            
            # Verify the data file is accessible
            Write-Host "Verifying ICU data file access:"
            Get-ChildItem -Path $ICUDataDir | Format-Table -AutoSize
            
            $DataFileFound = $true
            break
        }
    }
    
    if (-not $DataFileFound) {
        Write-Host "ERROR: Could not find ICU data file in any location"
        exit 1
    }
}

# Create build directory
$BuildDir = Join-Path $TestDir "build"
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Set-Location -Path $BuildDir

# Copy test files
Copy-Item -Path $SharedTestCpp -Destination (Join-Path $TestDir "test.cpp")
Copy-Item -Path $SharedCMake -Destination (Join-Path $TestDir "CMakeLists.txt.common")

# Copy platform-specific CMakeLists.txt
$PlatformCMake = Join-Path $PSScriptRoot "CMakeLists.txt"
Copy-Item -Path $PlatformCMake -Destination (Join-Path $TestDir "CMakeLists.txt")

# Set environment variables
$env:ICU_ROOT = $ICUDir

# Create a custom CMake toolchain file
$ToolchainFile = Join-Path $TestDir "icu_toolchain.cmake"

# Convert ICU directory path to CMake format (forward slashes)
$ICUDirCMake = $ICUDir.Replace('\', '/')

# Create the toolchain file content
$ToolchainContent = @"
# Use MSVC compiler
set(CMAKE_CXX_COMPILER "cl.exe")
set(CMAKE_C_COMPILER "cl.exe")

# Set compiler flags
set(CMAKE_CXX_FLAGS "\${CMAKE_CXX_FLAGS} /std:c++$CPP_VERSION /EHsc /D_CRT_SECURE_NO_WARNINGS /DNOMINMAX")
set(CMAKE_C_FLAGS "\${CMAKE_C_FLAGS} /D_CRT_SECURE_NO_WARNINGS /DNOMINMAX")

# Force static linking for ICU
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)

# Define ICU linking helper function
function(target_link_icu TARGET)
  target_compile_definitions(\${TARGET} PRIVATE U_STATIC_IMPLEMENTATION)
  # Link ICU libraries in the correct order
  target_link_libraries(\${TARGET}
"@

# Check which ICU libraries exist and add them to the toolchain file
$LibsToCheck = @(
    "sicudt.lib", 
    "sicuin.lib", 
    "sicuuc.lib", 
    "sicuio.lib",
    "icudt.lib",
    "icuin.lib",
    "icuuc.lib",
    "icuio.lib"
)

$LibsFound = @()
foreach ($Lib in $LibsToCheck) {
    $LibPath = Join-Path $ICUDir "lib\$Lib"
    if (Test-Path $LibPath) {
        $LibPathCMake = $LibPath.Replace('\', '/')
        $LibsFound += "    `"$LibPathCMake`""
    }
}

# If no libraries found, try to find them in alternative locations
if ($LibsFound.Count -eq 0) {
    Write-Host "No standard ICU libraries found, searching for alternatives..."
    $LibFiles = Get-ChildItem -Path (Join-Path $ICUDir "lib") -Filter "*.lib" -ErrorAction SilentlyContinue
    foreach ($LibFile in $LibFiles) {
        $LibPathCMake = $LibFile.FullName.Replace('\', '/')
        $LibsFound += "    `"$LibPathCMake`""
    }
}

# Add the libraries to the toolchain file
$ToolchainContent += $LibsFound -join "`n"
$ToolchainContent += @"

    advapi32.lib)
endfunction()
"@

# Write the toolchain file
$ToolchainContent | Out-File -FilePath $ToolchainFile -Encoding utf8

# Display the toolchain file for debugging
Write-Host "Created toolchain file:"
Get-Content $ToolchainFile | ForEach-Object { Write-Host $_ }

# Configure and build the test program
Write-Host "Configuring with CMake..."
try {
    & cmake -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE="$ToolchainFile" -DENABLE_ICU_EXAMPLES=ON -DICU_DATA_DIR="$ICUDataDir" $TestDir
} catch {
    Write-Host "Error during CMake configuration: $_"
    exit 1
}

Write-Host "Building test program..."
try {
    & cmake --build . --config Release
} catch {
    Write-Host "Error during build: $_"
    exit 1
}

# Run the test program
Write-Host "Running ICU test program:"
$TestExe = Join-Path $BuildDir "Release\icu_test.exe"
if (Test-Path $TestExe) {
    Set-Location -Path (Join-Path $BuildDir "Release")
    $env:ICU_DATA = $ICUDataDir
    & $TestExe
} else {
    Write-Host "Test executable not found at $TestExe"
    Write-Host "Looking for test executable in build directory..."
    $TestExes = Get-ChildItem -Path $BuildDir -Filter "icu_test.exe" -Recurse -ErrorAction SilentlyContinue
    if ($TestExes.Count -gt 0) {
        $TestExe = $TestExes[0].FullName
        Write-Host "Found test executable at $TestExe"
        Set-Location -Path (Split-Path -Parent $TestExe)
        $env:ICU_DATA = $ICUDataDir
        & $TestExe
    } else {
        Write-Host "No test executable found"
        exit 1
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Test failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Test completed successfully!"
exit 0
