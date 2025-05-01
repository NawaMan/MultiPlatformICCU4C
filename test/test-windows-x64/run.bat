@echo off
setlocal enabledelayedexpansion

set BITNESS=64

echo === Building ICU4C test for Windows (%BITNESS%-bit) ===

:: Get script directory and root directory
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%..\..\"
cd /d "%ROOT_DIR%"

:: Set default versions
set "ICU_VERSION=77.1"
set "MSVC_VERSION=14.3"

:: Source versions if not already set
if exist versions.env (
    echo Reading versions from versions.env
    for /f "tokens=1,* delims==" %%a in (versions.env) do (
        set line=%%a
        if "!line:~0,1!" NEQ "#" (
            if "%%a"=="ICU_VERSION" set "ICU_VERSION=%%b"
            if "%%a"=="CLANG_VERSION" set "MSVC_VERSION=%%b"
        )
    )
)

echo Using versions: ICU=%ICU_VERSION%, MSVC=%MSVC_VERSION%

:: Check if the ICU package exists
set "ICU_PACKAGE=%ROOT_DIR%dist\icu4c-%ICU_VERSION%_windows-x86-%BITNESS%_msvc-%MSVC_VERSION%.zip"

:: Also check for alternative package name format
if not exist "%ICU_PACKAGE%" (
    set "ALT_ICU_PACKAGE=%ROOT_DIR%dist\icu4c-%ICU_VERSION%_windows-x86-%BITNESS%_*.zip"
    for %%F in (%ALT_ICU_PACKAGE%) do (
        set "ICU_PACKAGE=%%F"
        echo Found alternative ICU package: %%F
    )
)

if not exist "%ICU_PACKAGE%" (
    echo ICU package not found: %ICU_PACKAGE%
    echo Checking for downloaded artifacts...

    :: Look for any Windows 64-bit ICU package in the dist directory
    set "FOUND=false"
    for %%F in (%ROOT_DIR%dist\*windows*64*.zip) do (
        set "ICU_PACKAGE=%%F"
        set "FOUND=true"
        echo Found ICU package: %%F
    )

    if "%FOUND%"=="false" (
        echo No ICU package found in dist directory.
        echo Please ensure the Windows build job completed successfully.
        exit /b 1
    )
)

echo === Running ICU4C tests ===
echo ICU Package: %ICU_PACKAGE%

:: Ensure shared test files are available
set "SHARED_TEST_CPP=%SCRIPT_DIR%..\test.cpp"
set "SHARED_CMAKE=%SCRIPT_DIR%..\CMakeLists.txt"

if not exist "%SHARED_TEST_CPP%" (
    echo Error: Shared test.cpp not found at %SHARED_TEST_CPP%
    exit /b 1
)

if not exist "%SHARED_CMAKE%" (
    echo Error: Shared CMakeLists.txt not found at %SHARED_CMAKE%
    exit /b 1
)

:: Run the PowerShell test script
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-test.ps1" -ICUPackage "%ICU_PACKAGE%" -SharedTestCpp "%SHARED_TEST_CPP%" -SharedCMake "%SHARED_CMAKE%"

if %ERRORLEVEL% neq 0 (
    echo Tests failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo ✅ Tests completed successfully!
exit /b 0
