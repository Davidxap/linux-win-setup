@echo off
REM Launcher for setup-windows.ps1 — keeps the window open on error.
REM Double-click this file, or run it from an Administrator console.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
echo.
echo Press Enter to close this window...
pause >nul