@echo off
setlocal EnableDelayedExpansion
title MangoDefend - Build Standalone EXE

echo.
echo ============================================
echo   MangoDefend - Standalone EXE Builder
echo ============================================
echo.

cd /d "%~dp0"

if not exist "main.py" (
    echo ERROR: Run this script from the desktop_app folder.
    pause & exit /b 1
)

REM ── Locate Python (prefer .venv) ─────────────────────────────────────────
set PYTHON=
if exist ".venv\Scripts\python.exe"  set PYTHON=.venv\Scripts\python.exe
if exist "venv\Scripts\python.exe"   set PYTHON=venv\Scripts\python.exe

if "%PYTHON%"=="" (
    where python >nul 2>&1
    if !errorlevel! == 0 (set PYTHON=python) else (
        echo ERROR: No Python found. Activate your venv first.
        pause & exit /b 1
    )
)
echo [i] Using Python: %PYTHON%

REM ── Step 1: Generate icon.ico from PNG ───────────────────────────────────
echo.
echo [1/5] Generating icon.ico...
%PYTHON% -c "from PIL import Image; img=Image.open('assets/mango_icon.png').convert('RGBA'); sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)]; imgs=[img.resize(s,Image.LANCZOS) for s in sizes]; imgs[0].save('assets/icon.ico',format='ICO',sizes=sizes,append_images=imgs[1:]); print('  icon.ico ready')"
if errorlevel 1 echo WARNING: Could not create icon.ico - continuing without icon

REM ── Step 2: Install / upgrade PyInstaller ────────────────────────────────
echo.
echo [2/5] Installing PyInstaller...
%PYTHON% -m pip install --quiet --upgrade pyinstaller
if errorlevel 1 (echo ERROR: pip failed & pause & exit /b 1)

REM ── Step 3: Clean previous build ─────────────────────────────────────────
echo.
echo [3/5] Cleaning previous build...
if exist "build" rmdir /s /q build
if exist "dist"  rmdir /s /q dist

REM ── Step 4: Build ─────────────────────────────────────────────────────────
echo.
echo [4/5] Building standalone EXE (this takes a few minutes)...
echo.
%PYTHON% -m PyInstaller --clean --noconfirm MangoDefend.spec

if errorlevel 1 (
    echo.
    echo ============================================
    echo   BUILD FAILED
    echo ============================================
    echo Check the output above for errors.
    pause
    exit /b 1
)

REM ── Step 5: Report ────────────────────────────────────────────────────────
echo.
echo [5/5] Checking output...
if exist "dist\MangoDefend.exe" (
    for %%F in ("dist\MangoDefend.exe") do set SIZE=%%~zF
    set /a SIZEMB=!SIZE! / 1048576
    echo.
    echo ============================================
    echo   BUILD SUCCESSFUL
    echo ============================================
    echo   Output : dist\MangoDefend.exe
    echo   Size   : !SIZEMB! MB
    echo ============================================
    echo.
    echo Distribusi: cukup copy dist\MangoDefend.exe ke komputer lain.
    echo Tidak perlu install Python, pip, atau dependency apapun.
) else (
    echo ERROR: dist\MangoDefend.exe not found!
    pause & exit /b 1
)

echo.
pause
