# GZ302 Tray Icon

A system tray icon for convenient power profile management on the ASUS ROG Flow Z13 (GZ302).

## Overview

This is a standalone GUI utility that provides quick access to `pwrcfg` power profiles through a system tray icon. Instead of using terminal commands, users can right-click the tray icon and select their desired power profile.

## Status

🚧 **Active Development** - Basic functionality implemented, testing in progress.

## Features

- ✅ System tray icon with power profile menu
- ✅ Right-click menu to switch between power profiles:
  - Emergency (10W)
  - Battery (18W)
  - Efficient (30W)
  - Balanced (40W)
  - Performance (55W)
  - Gaming (70W)
  - Maximum (90W)
- ✅ Uses polkit (pkexec) for authentication - no need for sudo!
- ✅ Real-time status updates
- 🚧 Visual indicators for AC/Battery status (planned)
- 🚧 Custom icons for power profiles (planned)

## Technology Stack

- **Python 3** - Main programming language
- **PyQt6** - GUI framework for system tray
- **Polkit** - Privilege escalation without sudo

## Installation

### Prerequisites

1. GZ302 Linux Setup main scripts must be installed with `pwrcfg` available
2. Python 3.8 or higher
3. Polkit installed (usually pre-installed on most distributions)

### Step 1: Install Python Dependencies

```bash
# Using pip
pip install -r requirements.txt

# Or using your distribution's package manager
# Arch/Manjaro
sudo pacman -S python-pyqt6

# Ubuntu/Debian
sudo apt install python3-pyqt6

# Fedora
sudo dnf install python3-pyqt6

# OpenSUSE
sudo zypper install python3-qt6
```

### Step 2: Install Polkit Policy (Required for password-less operation)

```bash
cd tray-icon
sudo ./install-policy.sh
```

This installs a polkit policy that allows `pwrcfg` to be executed with elevated privileges without requiring sudo password each time.

### Step 3: Run the Tray Icon

```bash
cd tray-icon/src
python3 gz302_tray.py
```

Or make it executable and run directly:
```bash
chmod +x src/gz302_tray.py
./src/gz302_tray.py
```

## Usage

1. Launch the tray icon application
2. Look for the computer icon in your system tray
3. Right-click the icon to see the menu
4. Select a power profile to switch
5. Authentication dialog will appear the first time (polkit)
6. Subsequent changes may not require re-authentication (depends on polkit timeout)

## Autostart (Optional)

To run the tray icon automatically on login, create a desktop entry:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/gz302-tray.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for GZ302
Exec=/path/to/GZ302-Linux-Setup/tray-icon/src/gz302_tray.py
Icon=battery
Terminal=false
Categories=Utility;System;
EOF
```

Replace `/path/to/` with the actual path to your GZ302-Linux-Setup repository.

## Requirements

- GZ302 Linux Setup main scripts installed
- `pwrcfg` command available in PATH
- System tray support (most desktop environments)

## Contributing

This is a sub-project of the main GZ302-Linux-Setup repository. Contributions are welcome!

## License

Same as parent project (GZ302-Linux-Setup).

---

**Note**: This is an optional companion utility. The main GZ302 setup scripts work perfectly via terminal commands and do not require this tray icon.
