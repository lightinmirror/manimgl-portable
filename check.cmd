@echo off
cd /d "%~dp0"
echo ============================================
echo   manimgl portable - DIAGNOSTIC
echo ============================================
echo.

echo [1] files present?  (expect 49.2 / 6.3 / 77.1 MB)
for %%F in (tectonic dvisvgm ffmpeg) do (
    if exist "manim-env\Scripts\%%F.exe" (
        for %%S in ("manim-env\Scripts\%%F.exe") do echo   OK      %%F.exe   %%~zS bytes
    ) else (
        echo   MISSING %%F.exe     ^<== deleted by antivirus?
    )
)
echo.

echo [2] actually runnable?  (a file blocked by AV fails here)
manim-env\Scripts\tectonic.exe --version >nul 2>&1
if errorlevel 1 (echo   FAIL    tectonic.exe) else (echo   OK      tectonic.exe)
manim-env\Scripts\dvisvgm.exe --version >nul 2>&1
if errorlevel 1 (echo   FAIL    dvisvgm.exe) else (echo   OK      dvisvgm.exe)
manim-env\Scripts\ffmpeg.exe -version >nul 2>&1
if errorlevel 1 (echo   FAIL    ffmpeg.exe) else (echo   OK      ffmpeg.exe)
echo.

echo [3] TeX resource cache
if exist "%LOCALAPPDATA%\TectonicProject\Tectonic\cache\bundles" (
    echo   OK      cache installed
) else (
    echo   MISSING cache not installed ^(first compile needs network^)
)
echo.

echo [4] python / manimlib
manim-env\Scripts\python.exe -c "import manimlib,sys;print('  OK      manimlib   exe=',sys.executable)" 2>nul
if errorlevel 1 echo   FAIL    cannot import manimlib
echo.

echo ============================================
echo   Please screenshot this whole window
echo ============================================
pause
