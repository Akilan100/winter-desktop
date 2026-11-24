@echo off
setlocal
cd /d "%~dp0"
echo ==========================================
echo  Winter Desktop - Windows 11 Easy Setup
echo ==========================================
powershell -ExecutionPolicy Bypass -File "%~dp0windows\install.ps1"
pause
