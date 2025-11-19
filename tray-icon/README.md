# GZ302 Tray Icon

System tray GUI for quick power profile switching.

## Features

- Right-click menu for 7 power profiles (10W - 90W)
- Visual indicators for active profile and AC/battery status
- Password-less operation (after setup)
- Keyboard backlight and RGB controls
- Auto-start support

## Installation

**Quick install:**
```bash
cd tray-icon && sudo ./install-tray.sh
```

**Manual install:**

1. Install dependencies:
   ```bash
   # Arch/Manjaro
   sudo pacman -S python-pyqt6
   
   # Ubuntu/Debian
   sudo apt install python3-pyqt6
   
   # Fedora
   sudo dnf install python3-pyqt6
   
   # OpenSUSE
   sudo zypper install python3-qt6 python3-psutil
   ```

2. Configure password-less sudo (recommended):
   ```bash
   sudo ./install-policy.sh
   ```

3. Run:
   ```bash
   python3 src/gz302_tray.py
   ```

## Usage

Right-click system tray icon → Select power profile → Done

**Requirements:** Python 3.8+, PyQt6, system tray support

**Note:** Optional utility. Main scripts work via terminal without GUI.
