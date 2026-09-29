@echo off
rem manimgl portable -- render the full feature showcase (~25 s) and open videos
cd /d "%~dp0"

echo ============================================
echo   manimgl-portable 功能巡礼
echo ============================================
echo.
echo 正在渲染（约半分钟，第一次会慢一些）...
echo.

"%~dp0manim-env\Scripts\python.exe" -m manimlib "%~dp0showcase.py" Showcase -w -m

echo.
if exist "%~dp0videos\Showcase.mp4" (
    echo [OK] videos\Showcase.mp4
    start "" "%~dp0videos"
) else (
    echo [FAIL] no Showcase.mp4 -- please send the error above
)
echo.
pause
