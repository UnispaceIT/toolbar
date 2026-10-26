@echo off
rem Double-click installer for testing outside Company Portal. Runs package\install.ps1.
title Unispace Toolbar Install
echo Installing the Unispace toolbar for pyRevit...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package\install.ps1"

echo.
if %errorlevel%==0 (
    echo Done. Close Revit if it is open, then start it again to see the Unispace tab.
) else (
    echo Something went wrong. The log file will open now - please send it back.
    start "" notepad "%LOCALAPPDATA%\Unispace\Logs\toolbar-install.log"
)
echo.
pause
