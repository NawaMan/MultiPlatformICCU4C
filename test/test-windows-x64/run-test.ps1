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

# Use PowerShell to extract the ZIP file
Expand-Archive -Path $ICUPackage -DestinationPath $ICUDir

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
    Write-Host "ERROR: ICU data file not found at $DataFile"
    Write-Host "Contents of share\icu\$ICUVersion\ (if it exists):"
    if (Test-Path (Join-Path $ICUDir "share\icu\$ICUVersion")) {
        Get-ChildItem -Path (Join-Path $ICUDir "share\icu\$ICUVersion") | Format-Table -AutoSize
    } else {
        Write-Host "Directory does not exist"
    }
    exit 1
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
@"
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
    "$ICUDir/lib/sicudt.lib"
    "$ICUDir/lib/sicuin.lib"
    "$ICUDir/lib/sicuuc.lib"
    "$ICUDir/lib/sicuio.lib"
    advapi32.lib)
endfunction()
"@ | Out-File -FilePath $ToolchainFile -Encoding utf8

# Configure and build the test program
Write-Host "Configuring with CMake..."
cmake -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE="$ToolchainFile" -DENABLE_ICU_EXAMPLES=ON -DICU_DATA_DIR="$ICUDataDir" $TestDir

Write-Host "Building test program..."
cmake --build . --config Release

# Run the test program
Write-Host "Running ICU test program:"
Set-Location -Path (Join-Path $BuildDir "Release")
$env:ICU_DATA = $ICUDataDir
.\icu_test.exe

if ($LASTEXITCODE -ne 0) {
    Write-Host "Test failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Test completed successfully!"
exit 0
