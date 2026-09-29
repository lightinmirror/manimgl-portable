@echo off
rem manimgl portable -- render the demo scene, then open the output folder
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" -RunDemo
pause
