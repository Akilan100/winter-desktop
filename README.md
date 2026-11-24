# Winter Desktop (Linux Hyprland & Windows 11)

A native 144Hz VSync multi-season atmospheric desktop overlay for **Linux (Wayland / Hyprland)** and **Windows 11**, inspired by KoiArt desktop experiences.

---

## 🪟 How to Install on Windows 11 (Quick & Easy)

Send your friend the GitHub link: **https://github.com/Akilan100/winter-desktop**

They have two very easy ways to run it:

### 🌟 Method 1: The Easiest Way (Double-Click Setup)
1. On the GitHub page, click the green **Code** button and click **Download ZIP**.
2. Right-click the downloaded zip file and choose **Extract All...**
3. Open the extracted folder and double-click:
   ```text
   install.bat
   ```
4. It will automatically set up everything and create a **Winter Desktop** shortcut on their desktop!
5. Double-click the desktop shortcut or `winter-desktop.bat` to run.

---

### 🚀 Method 2: Prebuilt Standalone App (.exe - No Python Needed)
1. Go to the **Releases** section:  
   **https://github.com/Akilan100/winter-desktop/releases/latest**
2. Download **`WinterDesktop-windows-x64.zip`**.
3. Extract the zip and double-click:
   ```text
   WinterDesktop.exe
   ```
   *(No setup, no commands, no installation needed!)*

---

### 🎮 Windows 11 Controls & Shortcuts

| Action | How to do it |
| :--- | :--- |
| **Toggle On / Off** | Press **`Win + Alt + W`** anytime |
| **Roll Snowball** | **Right-click, hold, and drag** along the bottom snow or window titlebars |
| **Build Snowman** | Drag and stack 3 snowballs together |
| **Yellow Bulldozer** | Click the bulldozer icon on the top dock to drive or clear snow |
| **Switch Season** | Right-click the **System Tray icon** (near clock) $\rightarrow$ pick **Snow**, **Autumn Leaves**, **Rain**, or **Blossom** |
| **Close Completely** | Right-click the **System Tray icon** $\rightarrow$ click **Exit** (leaves 0 background footprint) |

---

## 🌟 Features

- **True 144Hz VSync Smoothness**: Driven by QtQuick `FrameAnimation` locked to display refresh rate.
- **4 Seasonal Modes**:
  - **❄ Snow (`Mode 0`)**: Realistic powder snowflakes, crystal stars (`❄`), and Catmull-Rom cubic Bézier snow dunes.
  - **🍁 Autumn Leaves (`Mode 1`)**: Tumbling maple and oak leaves (`🍁`, `🍂`, `🍃`) in autumn hues with natural wind-sway.
  - **🌧 Rain (`Mode 2`)**: Slanted raindrops with surface sheen and aerodynamic wind tilt.
  - **🌸 Cherry Blossom (`Mode 3`)**: Soft pink sakura petals (`🌸`) with gentle rotational drift.
- **Interactive Snow Physics**:
  - **Snowball Rolling & Throwing**: Ball grows with realistic rotation; can be thrown across the screen.
  - **Snowman Customization**: Hat, carrot nose, scarf, sunglasses, twig arms with dress-up drawer.
  - **Bulldozer / Snowplow**: Manual controls (Drive Left/Right, Pause, Honk, Blade Lift, Dismiss).
  - **Ballistic Window Physics**: Moving or throwing windows sheds airborne snow chunks to neighboring windows.
- **Zero Autostart / Zero Background Footprint**: Completely terminates when toggled off.

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

## ⚙️ Repository Structure

```
winter-desktop/
├── install.bat              # 1-click double-click setup for Windows 11
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
│   ├── winter_desktop.py    # Windows 11 DWM transparent window & tray
│   ├── install.bat          # Double-click setup
│   ├── install.ps1          # PowerShell setup script
│   ├── winter-desktop.bat   # Windows batch launcher
│   ├── winter-desktop.vbs   # Silent background launcher
│   ├── package.ps1          # Standalone PyInstaller build script
│   └── overlay/
│       ├── windows_shell.qml # Windows 11 top-level overlay window
│       └── WindowsStateStore.qml # Windows state management & persistence
└── .github/workflows/
    └── windows-release.yml  # Automated Windows 11 binary build & release
```

---

## 📄 License
MIT License.
