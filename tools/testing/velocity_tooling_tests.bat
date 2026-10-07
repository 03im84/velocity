@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0velocity_tooling_tests.ps1"
exit /b %ERRORLEVEL%
