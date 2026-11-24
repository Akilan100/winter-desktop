# Winter Desktop (Linux Hyprland & Windows 11)

A native 144Hz VSync multi-season atmospheric desktop overlay for **Linux (Wayland / Hyprland)** and **Windows 11**, inspired by KoiArt desktop experiences.

---

## 🌟 Features

- **True 144Hz VSync Smoothness**: Driven by QtQuick `FrameAnimation` locked to your monitor's display refresh rate (144Hz / 165Hz / 240Hz).
- **4 Multi-Weather Seasonal Modes**:
  - **❄ Snow (`Mode 0`)**: Realistic powder snowflakes, crystal stars (`❄`), and Catmull-Rom cubic Bézier snow dunes.
  - **🍁 Autumn Leaves (`Mode 1`)**: Tumbling maple and oak leaves (`🍁`, `🍂`, `🍃`) in seasonal autumn hues with aerodynamic wind-sway.
  - **🌧 Rain (`Mode 2`)**: High-velocity slanted rain streaks with aerodynamic tilt and surface sheen.
  - **🌸 Cherry Blossom (`Mode 3`)**: Soft pink sakura petals (`🌸`) with gentle rotational drift.
- **Interactive Snow Physics**:
  - **Right-Click Snowball Rolling**: Right-click, hold, and drag across any accumulated snow patch to roll a snowball that grows up to 40px with realistic physical rotation.
  - **Snowman Stacking & Dress-Up**: Stack 3 snowballs to build an interactive snowman with hats, carrot noses, scarves, sticks, and an accessory drawer.
  - **Manual-Controlled Bulldozer**: Yellow snowplow with manual controls (Drive Left/Right, Pause, Honk, Blade Lift, Dismiss).
  - **Ballistic Window Physics**: Dragging or throwing windows sheds airborne snow chunks that arc and land on neighboring windows or the ground.
  - **Santa Sleigh**: Santa and reindeer flyby across the sky.
- **Zero Autostart / Zero Background Footprint**: Completely terminates all overlay processes when toggled off. Never runs in the background or installs autostart services without your explicit trigger.

---

## 🪟 Windows 11 Setup & Usage

### Method 1: One-Click PowerShell Setup (Recommended)
1. Clone or download the repository:
   ```powershell
   git clone https://github.com/Akilan100/winter-desktop.git
   cd winter-desktop\windows
   ```
2. Run the installer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
3. A desktop shortcut **Winter Desktop** will be created. Double-click it or run `.\winter-desktop.bat`.

### Shortcut Key (Windows 11)
- **`Win + Alt + W`**: Toggle the overlay on / off anytime.
- **System Tray Icon**: Right-click the tray icon to switch weather modes, adjust intensity, or cleanly exit.

### Building Standalone Windows Executable (.exe)
```powershell
cd winter-desktop\windows
powershell -ExecutionPolicy Bypass -File .\package.ps1
# Output located at: dist\WinterDesktop.exe
```

---

## 🐧 Linux (Hyprland + Quickshell) Setup & Usage

### Shortcut Key (Linux)
- **`SUPER + ALT + W`**: Toggle the overlay on / off.

### CLI Controls
```bash
# Toggle overlay
winter-desktop toggle

# Switch weather modes (0: Snow, 1: Leaves, 2: Rain, 3: Blossom)
winter-desktop snow-mode 1

# Adjust precipitation intensity (25, 50, 75, 100)
winter-desktop snow-intensity 75

# Clear accumulated snow
winter-desktop clear-snow
```

---

## ⚙️ Architecture

```
winter-desktop/
├── overlay/                 # Cross-platform QtQuick 144Hz simulation components
│   ├── SnowfallLayer.qml    # 144Hz weather particle simulation (Snow, Leaves, Rain, Blossom)
│   ├── SnowDriftLayer.qml   # Catmull-Rom cubic Bézier snow dune waves
│   ├── SnowballItem.qml     # Interactive snowball rolling, physics & throwing
│   ├── SnowmanItem.qml      # 3-tier snowman rendering & accessories
│   ├── SnowplowItem.qml     # Yellow bulldozer with manual control bar
│   ├── SantaItem.qml        # Santa sleigh flyby
│   ├── WinterDock.qml       # Top control dock
│   └── shell.qml            # Wayland layer-shell window (Linux)
├── windows/                 # Windows 11 native integration
│   ├── winter_desktop.py    # Windows 11 DWM transparent window, WinEvent window tracker & tray
│   ├── install.ps1          # One-click Windows 11 installer & shortcut creator
│   ├── winter-desktop.bat   # Windows batch launcher
│   ├── winter-desktop.vbs   # Silent launcher
│   ├── package.ps1          # Standalone PyInstaller build script
│   └── overlay/
│       ├── windows_shell.qml # Windows 11 top-level overlay window
│       └── WindowsStateStore.qml # Windows state management & persistence
└── .github/workflows/
    └── windows-release.yml  # GitHub Actions CI for automated Windows 11 binary builds
```

---

## 📄 License
MIT License.
