@echo off

REM ── Auto-elevate to Administrator ──────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Hidden"
    exit /b
)
REM ────────────────────────────────────────────────────────────────────────────

REM Change to script directory
cd /d "%~dp0"

REM Check if virtual environment exists
if not exist "venv\" (
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate

REM Check if requirements are installed
pip show PySide6 >nul 2>&1
if errorlevel 1 (
    pip install -r requirements.txt
)

REM Run with pythonw.exe (no console window)
if exist "venv\Scripts\pythonw.exe" (
    start "" venv\Scripts\pythonw.exe main.py
) else (
    start "" pythonw main.py
)
