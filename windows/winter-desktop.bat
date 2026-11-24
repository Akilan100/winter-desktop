@echo off
setlocal
cd /d "%~dp0"

if exist ".venv\Scripts\python.exe" (
    start "" ".venv\Scripts\python.exe" "winter_desktop.py" %*
) else (
    start "" python "winter_desktop.py" %*
)
endlocal
