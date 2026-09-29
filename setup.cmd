@echo off
rem manimgl portable -- double-click to install / self-check
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1"
echo.
pause
