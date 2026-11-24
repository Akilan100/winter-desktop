@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  Winter Desktop - Windows 11
echo ==========================================

if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" "winter_desktop.py" %*
) else (
    python "winter_desktop.py" %*
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Winter Desktop stopped with exit code %ERRORLEVEL%.
    pause
)
endlocal
