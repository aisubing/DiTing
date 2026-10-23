@echo off
setlocal EnableDelayedExpansion
title DITING Flutter APK Build and Install Tool

:: APK build / install script.
::
:: Must go through `flutter build apk`; calling gradlew directly would produce an
:: APK with no Dart code inside. Release uses the keystore from
:: android/key.properties; "Debug (Release Key)" adds -PsignDebugWithRelease=true
:: so the debug build can upgrade-install a release build.
::
:: NOTE: this file is intentionally pure ASCII. cmd.exe parses batch files with the
:: OEM code page, so UTF-8 Chinese text here breaks the parser. Chinese docs live
:: in android/SIGNING.md.

cd /d "%~dp0"

if not exist "pubspec.yaml" goto ERR_NO_FLUTTER
where flutter >nul 2>&1
if errorlevel 1 goto ERR_NO_FLUTTER_BIN

:: Version name comes from pubspec.yaml so the archive name always matches.
set "APP_VERSION_NAME=unknown"
for /f "tokens=2 delims=: " %%A in ('findstr /b "version:" pubspec.yaml') do set "APP_VERSION_NAME=%%A"
for /f "tokens=1 delims=+" %%B in ("!APP_VERSION_NAME!") do set "APP_VERSION_NAME=%%B"

:: Step 1: Select build type
:CHOOSE_BUILD_TYPE
cls
echo ================================================================
echo             DITING Flutter APK Build and Install Tool
echo ================================================================
echo.
echo   [1] Debug                (Development build, fast, Release key)
echo   [2] Release              (Release build, R8, arm64-only, Release key)
echo   [3] Debug (Flutter Key)  (Debug build, debug key)
echo   [4] Split per ABI        (Release, one APK per ABI, smaller)
echo   [5] Clean                (flutter clean + gradlew clean)
echo   [0] Exit
echo.
set "BUILD_CHOICE="
set /p "BUILD_CHOICE=Enter choice [1/2/3/4/5/0] (default: 1): "

if "%BUILD_CHOICE%"=="" set "BUILD_CHOICE=1"
if "%BUILD_CHOICE%"=="1" goto SET_DEBUG_RELEASEKEY
if /i "%BUILD_CHOICE%"=="d" goto SET_DEBUG_RELEASEKEY
if "%BUILD_CHOICE%"=="2" goto SET_RELEASE
if /i "%BUILD_CHOICE%"=="r" goto SET_RELEASE
if "%BUILD_CHOICE%"=="3" goto SET_DEBUG
if "%BUILD_CHOICE%"=="4" goto SET_SPLIT
if "%BUILD_CHOICE%"=="5" goto DO_CLEAN
if /i "%BUILD_CHOICE%"=="clean" goto DO_CLEAN
if "%BUILD_CHOICE%"=="0" goto EXIT_SCRIPT
if /i "%BUILD_CHOICE%"=="q" goto EXIT_SCRIPT

echo.
echo [WARN] Invalid choice: "%BUILD_CHOICE%", please try again.
timeout /t 2 >nul
goto CHOOSE_BUILD_TYPE

:DO_CLEAN
echo.
echo ================================================================
echo [INFO] Cleaning: flutter clean + gradlew clean
echo ================================================================
echo.
call flutter clean
call android\gradlew.bat -p android clean
echo.
echo [SUCCESS] Clean finished.
pause
goto CHOOSE_BUILD_TYPE

:SET_DEBUG_RELEASEKEY
set "BUILD_TYPE=debug"
set "BUILD_TYPE_NAME=Debug (Release Key)"
set "FLUTTER_ARGS=build apk --debug -PsignDebugWithRelease=true"
set "APK_DIR=build\app\outputs\flutter-apk"
set "APK_NAME=app-debug.apk"
goto START_BUILD

:SET_DEBUG
set "BUILD_TYPE=debug"
set "BUILD_TYPE_NAME=Debug (Debug Key)"
set "FLUTTER_ARGS=build apk --debug"
set "APK_DIR=build\app\outputs\flutter-apk"
set "APK_NAME=app-debug.apk"
goto START_BUILD

:SET_RELEASE
set "BUILD_TYPE=release"
set "BUILD_TYPE_NAME=Release"
set "FLUTTER_ARGS=build apk --release"
set "APK_DIR=build\app\outputs\flutter-apk"
set "APK_NAME=app-release.apk"
goto START_BUILD

:SET_SPLIT
set "BUILD_TYPE=release"
set "BUILD_TYPE_NAME=Release (per-ABI)"
set "FLUTTER_ARGS=build apk --release --split-per-abi"
set "APK_DIR=build\app\outputs\flutter-apk"
set "APK_NAME=app-arm64-v8a-release.apk"
goto START_BUILD

:: Step 2: Build
:START_BUILD
echo.
echo ================================================================
echo [INFO] Building: %BUILD_TYPE_NAME%
echo [INFO] flutter %FLUTTER_ARGS%
echo ================================================================
echo.

call flutter %FLUTTER_ARGS%
if errorlevel 1 goto ERR_BUILD_FAILED

set "FOUND_APK=%CD%\%APK_DIR%\%APK_NAME%"
if not exist "%FOUND_APK%" goto ERR_NO_APK

echo.
echo ================================================================
echo [SUCCESS] %BUILD_TYPE_NAME% build completed!
echo [INFO] APK: %FOUND_APK%
for %%F in ("%FOUND_APK%") do echo [INFO] Size: %%~zF bytes
rem Versioned archive from copy*ApkWithVersion in android/app/build.gradle.kts
rem (not produced for --split-per-abi).
if not "%BUILD_TYPE_NAME%"=="Release (per-ABI)" (
    set "VERSIONED_APK=%CD%\build\app\outputs\apk\versioned\%BUILD_TYPE%\DITING-%BUILD_TYPE%-v%APP_VERSION_NAME%.apk"
    if exist "!VERSIONED_APK!" echo [INFO] Versioned APK: !VERSIONED_APK!
)
echo ================================================================
echo.

:: Print the signer fingerprint.
set "BUILD_TOOLS=%LOCALAPPDATA%\Android\Sdk\build-tools"
if exist "%BUILD_TOOLS%" (
    for /f "delims=" %%D in ('dir /b /o:-n "%BUILD_TOOLS%" 2^>nul') do (
        if exist "%BUILD_TOOLS%\%%D\apksigner.bat" (
            echo [INFO] Signer certificate:
            call "%BUILD_TOOLS%\%%D\apksigner.bat" verify --print-certs "%FOUND_APK%" 2>nul | findstr /i "Signer #1 certificate DN"
            goto SIGNED_SHOWN
        )
    )
)
:SIGNED_SHOWN

:: Step 3: Ask to install
:ASK_INSTALL
echo Install the APK onto a device?
echo   [Y] Yes - detect/connect ADB device and install (default)
echo   [N] No  - keep the build output and exit
echo.
set "INSTALL_CHOICE="
set /p "INSTALL_CHOICE=Enter choice [Y/N] (default: Y): "

if "%INSTALL_CHOICE%"=="" set "INSTALL_CHOICE=Y"
if /i "%INSTALL_CHOICE%"=="y" goto PREPARE_ADB
if /i "%INSTALL_CHOICE%"=="yes" goto PREPARE_ADB
if "%INSTALL_CHOICE%"=="1" goto PREPARE_ADB
if /i "%INSTALL_CHOICE%"=="n" goto NO_INSTALL
if /i "%INSTALL_CHOICE%"=="no" goto NO_INSTALL
if "%INSTALL_CHOICE%"=="0" goto NO_INSTALL

echo.
echo [WARN] Invalid choice: "%INSTALL_CHOICE%", please try again.
echo.
goto ASK_INSTALL

:NO_INSTALL
echo.
echo [INFO] Installation skipped. APK kept at:
echo        %FOUND_APK%
goto SUCCESS_EXIT

:: Step 4: ADB environment check and device detection
:PREPARE_ADB
echo.
echo ================================================================
echo [INFO] Checking ADB environment...
echo ================================================================
echo.

where adb >nul 2>&1
if errorlevel 1 goto ERR_NO_ADB

:CHECK_DEVICES
echo [INFO] Scanning for connected ADB devices...
set "DEVICE_COUNT=0"
set "TARGET_DEVICE="

for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
    if "%%B"=="device" (
        set /a DEVICE_COUNT+=1
        set "DEVICE_!DEVICE_COUNT!=%%A"
        set "TARGET_DEVICE=%%A"
    )
)

if %DEVICE_COUNT% EQU 0 goto PROMPT_CONNECT_ADB
if %DEVICE_COUNT% EQU 1 goto SINGLE_DEVICE_FOUND
goto MULTI_DEVICES_FOUND

:MULTI_DEVICES_FOUND
echo [INFO] Multiple ready devices detected. Select target device:
for /L %%i in (1,1,%DEVICE_COUNT%) do (
    call echo   [%%i] %%DEVICE_%%i%%
)
echo.
set "DEV_SEL="
set /p "DEV_SEL=Enter device number [1-%DEVICE_COUNT%] (default: 1): "
if "!DEV_SEL!"=="" set "DEV_SEL=1"

call set "SELECTED_DEV=%%DEVICE_!DEV_SEL!%%"
if "!SELECTED_DEV!"=="" (
    echo.
    echo [WARN] Invalid device number: "!DEV_SEL!", please try again.
    echo.
    goto CHECK_DEVICES
)
set "TARGET_DEVICE=!SELECTED_DEV!"
echo [INFO] Target device selected: !TARGET_DEVICE!
goto DO_INSTALL

:SINGLE_DEVICE_FOUND
echo [INFO] Target device detected: !TARGET_DEVICE!
goto DO_INSTALL

:: Step 5: Connect manual ADB device (IP:Port)
:PROMPT_CONNECT_ADB
if "!EMPTY_RETRIES!"=="" set "EMPTY_RETRIES=0"
echo [WARN] No ready ADB device currently detected.
echo.
echo ================================================================
echo Please enter the target ADB device IP and port (e.g. 192.168.1.1:6688)
echo Or enter 'Q' to cancel and exit:
echo ================================================================
set "ADB_ADDRESS="
set /p "ADB_ADDRESS=ADB Device Address [IP:PORT / Q]: "

if "%ADB_ADDRESS%"=="" (
    set /a EMPTY_RETRIES+=1
    echo.
    echo [WARN] Input cannot be empty, please try again.
    echo.
    REM Without a console (CI, pipe, redirected file) `set /p` returns an empty
    REM value forever, so bail out instead of looping.
    if !EMPTY_RETRIES! GEQ 3 goto ERR_NO_INPUT
    goto PROMPT_CONNECT_ADB
)
if /i "%ADB_ADDRESS%"=="q" goto EXIT_SCRIPT
if /i "%ADB_ADDRESS%"=="exit" goto EXIT_SCRIPT

echo.
echo [INFO] Connecting to %ADB_ADDRESS% ...
adb connect %ADB_ADDRESS%

timeout /t 2 >nul

set "CONNECT_SUCCESS=0"
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
    if "%%A"=="%ADB_ADDRESS%" (
        if "%%B"=="device" (
            set "CONNECT_SUCCESS=1"
            set "TARGET_DEVICE=%%A"
        )
    )
)

if "!CONNECT_SUCCESS!"=="0" (
    for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
        if "%%B"=="device" (
            set "CONNECT_SUCCESS=1"
            set "TARGET_DEVICE=%%A"
        )
    )
)

if "!CONNECT_SUCCESS!"=="0" goto ERR_ADB_CONNECT_FAILED

echo.
echo [SUCCESS] Successfully connected to device: !TARGET_DEVICE!
goto DO_INSTALL

:: Step 6: Install
:DO_INSTALL
echo.
echo ================================================================
echo [INFO] Installing %BUILD_TYPE_NAME% onto device [!TARGET_DEVICE!] ...
echo [INFO] APK file: %FOUND_APK%
echo ================================================================
echo.

adb -s !TARGET_DEVICE! install -r "%FOUND_APK%"
if errorlevel 1 goto ERR_INSTALL_FAILED

echo.
echo ================================================================
echo [SUCCESS] %BUILD_TYPE_NAME% APK installed successfully!
echo ================================================================
goto SUCCESS_EXIT

:: Error handlers
:ERR_NO_FLUTTER
echo.
echo ================================================================
echo [ERROR] Not a Flutter project root (pubspec.yaml not found)!
echo Cause:  This script must run from DITING-Flutter\
echo Action: Place it next to pubspec.yaml and run it there.
echo ================================================================
goto ERROR_EXIT

:ERR_NO_FLUTTER_BIN
echo.
echo ================================================================
echo [ERROR] 'flutter' command not found in system PATH!
echo Cause:  Flutter SDK bin directory is not on PATH.
echo Action: Add your Flutter SDK bin directory to PATH and retry.
echo ================================================================
goto ERROR_EXIT

:ERR_BUILD_FAILED
echo.
echo ================================================================
echo [ERROR] Build failed!
echo Cause:  flutter build apk returned a non-zero exit code.
echo Troubleshooting:
echo   1. Run 'dart analyze lib test' and 'flutter test' first
echo   2. Check signing config: android/key.properties
echo   3. Gradle cache may be broken - try option [5] Clean
echo ================================================================
goto ERROR_EXIT

:ERR_NO_APK
echo.
echo ================================================================
echo [ERROR] Build finished but no APK found at: %FOUND_APK%
echo Action: Check the flutter build output path was not changed.
echo ================================================================
goto ERROR_EXIT

:ERR_NO_INPUT
echo.
echo ================================================================
echo [ERROR] No ADB device and no usable stdin!
echo Cause:  The APK was built, but there is no connected device and this
echo         script is not running with an interactive console (stdin is
echo         redirected, piped, or closed), so the address prompt cannot
echo         read anything.
echo Action: Connect a device via USB / wireless debugging, then install
echo         the APK manually:
echo           adb install -r "%FOUND_APK%"
echo ================================================================
goto ERROR_EXIT

:ERR_NO_ADB
echo.
echo ================================================================
echo [ERROR] 'adb' command not found in system PATH!
echo Cause:  Android Debug Bridge is not installed or not in PATH.
echo Action: Install Android SDK Platform-Tools and add it to PATH.
echo ================================================================
goto ERROR_EXIT

:ERR_ADB_CONNECT_FAILED
echo.
echo ================================================================
echo [ERROR] Failed to connect to ADB device or device is not ready!
echo Cause:  Unable to establish connection to %ADB_ADDRESS%.
echo Troubleshooting steps:
echo   1. Verify the target IP address and port number.
echo   2. Ensure the Android device and PC are on the same local network.
echo   3. Ensure 'Wireless Debugging' is enabled in Developer Options.
echo   4. Check device screen for the 'Allow wireless debugging' prompt.
echo ================================================================
echo.
echo Retry connection?
echo   [1] Re-enter IP:Port (default)
echo   [0] Exit script
set "RETRY_CHOICE="
set /p "RETRY_CHOICE=Enter choice [1/0] (default: 1): "
if "!RETRY_CHOICE!"=="" set "RETRY_CHOICE=1"
if "!RETRY_CHOICE!"=="1" (
    echo.
    goto PROMPT_CONNECT_ADB
)
goto ERROR_EXIT

:ERR_INSTALL_FAILED
echo.
echo ================================================================
echo [ERROR] APK installation failed!
echo Cause:  'adb install' returned an error.
echo Common troubleshooting steps:
echo   1. Insufficient device storage space.
echo   2. Signature mismatch with existing app (uninstall it first).
echo   3. Device system policy blocked installation.
echo ================================================================
goto ERROR_EXIT

:: Exit handlers
:SUCCESS_EXIT
echo.
echo ================================================================
echo [INFO] Done. Press any key to exit...
echo ================================================================
pause >nul
exit /b 0

:ERROR_EXIT
echo.
echo ================================================================
echo [INFO] Aborted due to errors. Press any key to exit...
echo ================================================================
pause >nul
exit /b 1

:EXIT_SCRIPT
echo.
echo [INFO] Cancelled by user. Exiting...
exit /b 0
