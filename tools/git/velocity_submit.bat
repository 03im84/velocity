@echo off
setlocal

set "SCRIPT_DIRECTORY=%~dp0"

if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIRECTORY%velocity_submit.ps1"
) else if /I "%~2"=="install" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIRECTORY%velocity_submit.ps1" -Package "%~1" -Install
) else if /I "%~2"=="submit" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIRECTORY%velocity_submit.ps1" -Package "%~1" -Submit
) else if /I "%~2"=="validate" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIRECTORY%velocity_submit.ps1" -Package "%~1" -ValidatePackage
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIRECTORY%velocity_submit.ps1" -Package "%~1"
)

set "EXIT_CODE=%ERRORLEVEL%"

echo.
pause

exit /b %EXIT_CODE%
