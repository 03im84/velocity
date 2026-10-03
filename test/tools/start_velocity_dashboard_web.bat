@echo off
setlocal

cd /d "%~dp0\..\.."

where pythonw.exe >nul 2>&1
if not errorlevel 1 (
    start "" pythonw.exe "test\tools\velocity_dashboard_web.py"
    exit /b 0
)

where python.exe >nul 2>&1
if not errorlevel 1 (
    start "" python.exe "test\tools\velocity_dashboard_web.py"
    exit /b 0
)

where py.exe >nul 2>&1
if not errorlevel 1 (
    start "" py.exe -3 "test\tools\velocity_dashboard_web.py"
    exit /b 0
)

echo.
echo Python was not found.
echo Install Python or add it to PATH.
echo.
pause
exit /b 1
