# Package Winter Desktop as a standalone Windows executable (.exe)
# Run: powershell -ExecutionPolicy Bypass -File .\package.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building Winter Desktop Standalone Exe  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$python = "python"
if (Test-Path ".venv\Scripts\python.exe") {
    $python = ".venv\Scripts\python.exe"
}

Write-Host "Installing PyInstaller..." -ForegroundColor Cyan
& $python -m pip install pyinstaller PySide6

$overlaySource = Join-Path (Split-Path -Parent $scriptDir) "overlay"
$winOverlaySource = Join-Path $scriptDir "overlay"

Write-Host "Building executable..." -ForegroundColor Cyan
& $python -m PyInstaller `
    --name "WinterDesktop" `
    --windowed `
    --noconsole `
    --onefile `
    --add-data "$($overlaySource);overlay" `
    --add-data "$($winOverlaySource);windows/overlay" `
    --clean `
    winter_desktop.py

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Build Finished! Executable located at:   " -ForegroundColor Green
Write-Host " dist\WinterDesktop.exe                   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
