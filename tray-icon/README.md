# GZ302 Command Center

A system tray application for convenient power profile management on the ASUS ROG Flow Z13 (GZ302).

## Overview

This is a standalone GUI utility that provides quick access to `pwrcfg` power profiles through a system tray application. Instead of using terminal commands, users can right-click the tray icon and select their desired power profile.

## Status

🚧 **Active Development** - Basic functionality implemented, testing in progress.

## Features

- ✅ System tray application with power profile menu
- ✅ Right-click menu to switch between power profiles:
  - Emergency (10W)
  - Battery (18W)
  - Efficient (30W)
  - Balanced (40W)
  - Performance (55W)
  - Gaming (70W)
  - Maximum (90W)
- ✅ Password-less sudo configuration - no authentication prompts!
- ✅ Real-time status updates
- ✅ Visual indicators for AC/Battery status (tray tooltip and icon)
- 🚧 Custom icons for power profiles (planned)

## Technology Stack

- **Python 3** - Main programming language
- **PyQt6** - GUI framework for system tray application
- **Sudoers** - Privilege escalation without password

## Installation

### Prerequisites

1. GZ302 Linux Setup main scripts must be installed with `pwrcfg` available
2. Python 3.8 or higher
3. Sudo access (for one-time setup)

### Step 1: Install Python Dependencies

```bash
# Using pip
pip install -r requirements.txt

# Or using your distribution's package manager
# Arch/Manjaro (SVG support required for tray icons)
sudo pacman -S python-pyqt6 python-pyqt6-svg

# Ubuntu/Debian (SVG support required for tray icons)
sudo apt install python3-pyqt6 python3-pyqt6.qtsvg

# Fedora (SVG support required for tray icons)
sudo dnf install python3-pyqt6 python3-qt6-qtsvg

# OpenSUSE (SVG support required for tray icons)
sudo zypper install python3-qt6 python3-qt6-svg python3-psutil
```

### Step 2: Configure Sudoers (Recommended for no-prompt operation)

```bash
cd tray-icon
sudo ./install-policy.sh
```

This configures sudoers to allow `pwrcfg` to self-elevate without a password. The tray calls `pwrcfg` directly—no sudo needed.

### Step 3: Run the Command Center

```bash
cd tray-icon/src
python3 gz302_tray.py
```

Or make it executable and run directly:
```bash
chmod +x src/gz302_tray.py
./src/gz302_tray.py
```

### Optional: Install Desktop Launcher + Autostart

```bash
cd tray-icon
./install-tray.sh
```

This creates a launcher in `~/.local/share/applications` and an autostart entry in `~/.config/autostart`.

## Usage

1. Launch the Command Center application
2. Look for the computer icon in your system tray
3. Right-click the icon to see the menu
4. Select a power profile to switch
5. No password prompts (after sudoers is configured) - changes happen instantly!
6. Battery/AC status is shown in the tooltip; the icon updates when on AC vs Battery

## Troubleshooting

### Blank or Missing Icon
If the tray icon is missing or appears as a blank space:

- **GNOME Users**: You **must** install the "AppIndicator and KStatusNotifierItem Support" extension. GNOME does not support system tray icons natively.
- **Missing SVG Support**: Ensure you have the SVG library for PyQt6 installed (see [Step 1](#step-1-install-python-dependencies)). Without it, the application cannot render the `.svg` icons and they will appear blank.

### Refresh Rate Changes Fail
If changing the refresh rate from the menu doesn't work:
- Ensure `rrcfg` is installed.
- Ensure you have run `sudo ./install-policy.sh` in the `tray-icon` directory to allow password-less execution.

## Enable Autostart

You can enable autostart from the tray menu (Enable Autostart) or manually:

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
