"""
Winter Desktop for Windows 11
Native 144Hz VSync Multi-Season Desktop Overlay
"""

import sys
import os
import json
import time
import threading
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QObject, Signal, Slot, QTimer, QUrl, QPoint
    from PySide6.QtGui import QGuiApplication, QColor, QIcon, QAction
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
except ImportError:
    print("Error: PySide6 is required. Install it using:")
    print("    pip install PySide6")
    sys.exit(1)

from typing import Any
import ctypes
try:
    from ctypes import wintypes
except ImportError:
    wintypes = None  # type: ignore

IS_WINDOWS = sys.platform == "win32"

user32: Any = None
dwmapi: Any = None
kernel32: Any = None

if IS_WINDOWS:
    user32 = ctypes.windll.user32  # type: ignore
    dwmapi = ctypes.windll.dwmapi  # type: ignore
    kernel32 = ctypes.windll.kernel32  # type: ignore

    # Win32 Constants
    WS_EX_LAYERED = 0x00080000
    WS_EX_TRANSPARENT = 0x00000020
    WS_EX_TOOLWINDOW = 0x00000080
    WS_EX_NOACTIVATE = 0x08000000
    GWL_EXSTYLE = -20
    HWND_TOPMOST = -1
    SWP_NOMOVE = 0x0002
    SWP_NOSIZE = 0x0001
    SWP_NOACTIVATE = 0x0010
    EVENT_OBJECT_LOCATIONCHANGE = 0x800B
    EVENT_SYSTEM_FOREGROUND = 0x0003
    WINEVENT_OUTOFCONTEXT = 0
    MOD_ALT = 0x0001
    MOD_WIN = 0x0008
    WM_HOTKEY = 0x0312
    HOTKEY_ID_TOGGLE = 1001

    class MARGINS(ctypes.Structure):
        _fields_ = [
            ("cxLeftWidth", ctypes.c_int),
            ("cxRightWidth", ctypes.c_int),
            ("cyTopHeight", ctypes.c_int),
            ("cyBottomHeight", ctypes.c_int),
        ]
else:
    user32 = None  # type: ignore
    dwmapi = None  # type: ignore
    kernel32 = None  # type: ignore
    WS_EX_LAYERED = 0
    WS_EX_TRANSPARENT = 0
    WS_EX_TOOLWINDOW = 0
    WS_EX_NOACTIVATE = 0
    GWL_EXSTYLE = 0
    HWND_TOPMOST = 0
    SWP_NOMOVE = 0
    SWP_NOSIZE = 0
    SWP_NOACTIVATE = 0
    EVENT_OBJECT_LOCATIONCHANGE = 0
    EVENT_SYSTEM_FOREGROUND = 0
    WINEVENT_OUTOFCONTEXT = 0
    MOD_ALT = 0
    MOD_WIN = 0
    WM_HOTKEY = 0
    HOTKEY_ID_TOGGLE = 0
    MARGINS = None  # type: ignore


class Backend(QObject):
    windowSnapshotReceived = Signal(str)
    modeChanged = Signal(int)
    intensityChanged = Signal(int)

    def __init__(self, state_dir: Path):
        super().__init__()
        self.state_dir = state_dir
        self.state_file = state_dir / "state.json"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.current_mode = 0
        self.current_intensity = 75

    @Slot(str)
    def saveState(self, json_str: str):
        try:
            with open(self.state_file, "w", encoding="utf-8") as f:
                f.write(json_str)
        except Exception as e:
            print(f"Failed to save state: {e}", file=sys.stderr)

    @Slot(result=str)
    def loadState(self) -> str:
        if self.state_file.exists():
            try:
                with open(self.state_file, "r", encoding="utf-8") as f:
                    return f.read()
            except Exception as e:
                print(f"Failed to read state: {e}", file=sys.stderr)
        return ""

    @Slot(int)
    def setMode(self, mode: int):
        self.current_mode = max(0, min(3, mode))
        self.modeChanged.emit(self.current_mode)

    @Slot(int)
    def setIntensity(self, intensity: int):
        self.current_intensity = max(25, min(100, intensity))
        self.intensityChanged.emit(self.current_intensity)

    @Slot()
    def clearSnow(self):
        pass

    @Slot()
    def quitApp(self):
        QApplication.quit()


class WindowTracker(QObject):
    snapshotReady = Signal(str)

    def __init__(self):
        super().__init__()
        self.running = True
        self.prev_rects = []

    def poll_windows(self):
        if not IS_WINDOWS:
            return

        rects = []
        shell_hwnd = user32.GetShellWindow()

        def enum_cb(hwnd, lparam):
            if hwnd == shell_hwnd or not user32.IsWindowVisible(hwnd) or user32.IsIconic(hwnd):
                return True

            r = wintypes.RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(r))
            w = r.right - r.left
            h = r.bottom - r.top

            if w > 80 and h > 80:
                cls_buf = ctypes.create_unicode_buffer(128)
                user32.GetClassNameW(hwnd, cls_buf, 128)
                cls_name = cls_buf.value

                # Filter out system backdrop / utility surfaces
                if cls_name not in ("Progman", "WorkerW", "Shell_TrayWnd", "Windows.UI.Core.CoreWindow"):
                    rects.append({
                        "addr": str(hwnd),
                        "cls": cls_name,
                        "x": r.left,
                        "y": r.top,
                        "w": w,
                        "h": h
                    })
            return True

        WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
        user32.EnumWindows(WNDENUMPROC(enum_cb), 0)

        # Check fullscreen foreground window
        fg_hwnd = user32.GetForegroundWindow()
        is_fs = False
        if fg_hwnd:
            r = wintypes.RECT()
            user32.GetWindowRect(fg_hwnd, ctypes.byref(r))
            sw = user32.GetSystemMetrics(0)
            sh = user32.GetSystemMetrics(1)
            if r.left <= 0 and r.top <= 0 and r.right >= sw and r.bottom >= sh:
                cls_buf = ctypes.create_unicode_buffer(128)
                user32.GetClassNameW(fg_hwnd, cls_buf, 128)
                if cls_buf.value not in ("Progman", "WorkerW"):
                    is_fs = True

        payload = {"rects": rects[:6], "fs": is_fs}
        self.snapshotReady.emit(json.dumps(payload))


def setup_win32_window(hwnd: int):
    if not IS_WINDOWS or not hwnd:
        return

    # 1. Enable DWM glass / full-window transparency
    margins = MARGINS(-1, -1, -1, -1)
    dwmapi.DwmExtendFrameIntoClientArea(hwnd, ctypes.byref(margins))

    # 2. Set Extended Styles: TopMost, ToolWindow (no Alt+Tab clutter)
    style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    style |= WS_EX_TOOLWINDOW | WS_EX_LAYERED
    user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)

    # 3. Position topmost without stealing focus
    user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)


def setup_global_hotkey(hwnd: int) -> bool:
    if not IS_WINDOWS or not hwnd:
        return False
    # Register Win + Alt + W
    return bool(user32.RegisterHotKey(hwnd, HOTKEY_ID_TOGGLE, MOD_WIN | MOD_ALT, ord("W")))


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Winter Desktop")
    app.setOrganizationName("KoiArt")

    state_dir = Path(os.environ.get("APPDATA", Path.home())) / "WinterDesktop"
    backend = Backend(state_dir)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)

    overlay_dir = Path(__file__).resolve().parent / "overlay"
    engine.addImportPath(str(overlay_dir))
    engine.addImportPath(str(overlay_dir.parent.parent / "overlay"))

    qml_file = overlay_dir / "windows_shell.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to load QML overlay.", file=sys.stderr)
        sys.exit(1)

    window = engine.rootObjects()[0]
    hwnd = int(window.winId()) if hasattr(window, "winId") else 0

    if IS_WINDOWS and hwnd:
        setup_win32_window(hwnd)
        setup_global_hotkey(hwnd)

    # Window tracking timer (16ms = ~60Hz window position polling for smooth window-top snow)
    tracker = WindowTracker()
    tracker.snapshotReady.connect(backend.windowSnapshotReceived)

    track_timer = QTimer()
    track_timer.setInterval(20)
    track_timer.timeout.connect(tracker.poll_windows)
    track_timer.start()

    # System Tray Integration
    tray_icon = QSystemTrayIcon(app)
    # Default system icon fallback
    tray_icon.setIcon(app.style().standardIcon(QApplication.style().StandardPixmap.SP_DesktopIcon))

    tray_menu = QMenu()
    toggle_act = QAction("Toggle Overlay (Win+Alt+W)", tray_menu)
    toggle_act.triggered.connect(lambda: window.setVisible(not window.isVisible()))
    tray_menu.addAction(toggle_act)

    tray_menu.addSeparator()
    modes_menu = tray_menu.addMenu("Weather Mode")
    m0 = modes_menu.addAction("❄ Snow")
    m0.triggered.connect(lambda: backend.setMode(0))
    m1 = modes_menu.addAction("🍁 Autumn Leaves")
    m1.triggered.connect(lambda: backend.setMode(1))
    m2 = modes_menu.addAction("🌧 Rain")
    m2.triggered.connect(lambda: backend.setMode(2))
    m3 = modes_menu.addAction("🌸 Cherry Blossom")
    m3.triggered.connect(lambda: backend.setMode(3))

    tray_menu.addSeparator()
    exit_act = QAction("Exit", tray_menu)
    exit_act.triggered.connect(app.quit)
    tray_menu.addAction(exit_act)

    tray_icon.setContextMenu(tray_menu)
    tray_icon.show()

    ret = app.exec()

    # Clean exit: unregister hotkeys and exit
    if IS_WINDOWS and hwnd:
        user32.UnregisterHotKey(hwnd, HOTKEY_ID_TOGGLE)

    sys.exit(ret)


if __name__ == "__main__":
    main()
