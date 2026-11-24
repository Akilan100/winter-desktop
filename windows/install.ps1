# Winter Desktop - Windows 11 Installation & Setup Script
# Run with PowerShell: powershell -ExecutionPolicy Bypass -File .\install.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Winter Desktop - Windows 11 Setup       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Check Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $pythonCmd) {
    Write-Host "[ERROR] Python 3.9+ is not found in PATH." -ForegroundColor Red
    Write-Host "Please install Python from https://www.python.org/downloads/ (check 'Add python.exe to PATH')" -ForegroundColor Yellow
    Exit 1
}

Write-Host "[1/4] Found Python: $($pythonCmd.Source)" -ForegroundColor Green

# 2. Create Virtual Environment
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvDir = Join-Path $scriptDir ".venv"

if (-not (Test-Path $venvDir)) {
    Write-Host "[2/4] Creating virtual environment in $venvDir..." -ForegroundColor Cyan
    & $pythonCmd.Source -m venv $venvDir
} else {
    Write-Host "[2/4] Using existing virtual environment." -ForegroundColor Green
}

$venvPython = Join-Path $venvDir "Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    $venvPython = $pythonCmd.Source
}

# 3. Install PySide6
Write-Host "[3/4] Installing PySide6 (Qt 6 runtime)..." -ForegroundColor Cyan
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install PySide6

# 4. Create Desktop Shortcut
Write-Host "[4/4] Creating Desktop & Start Menu Shortcuts..." -ForegroundColor Cyan
$wsh = New-Object -ComObject WScript.Shell
$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)
$shortcutPath = Join-Path $desktopPath "Winter Desktop.lnk"

$vbsLauncher = Join-Path $scriptDir "winter-desktop.vbs"
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$vbsLauncher`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.Description = "Winter Desktop - 144Hz Multi-Season Desktop Atmosphere"
$shortcut.Save()

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Installation Complete!                   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "To launch Winter Desktop:"
Write-Host "  1. Double click the 'Winter Desktop' icon on your Desktop."
Write-Host "  2. Or run: .\winter-desktop.bat"
Write-Host "Toggle on/off anytime using: Win + Alt + W"
