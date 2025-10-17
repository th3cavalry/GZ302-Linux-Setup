# GZ302 Tray Icon (Work in Progress)

A system tray icon for convenient power profile management on the ASUS ROG Flow Z13 (GZ302).

## Overview

This is a standalone GUI utility that provides quick access to `pwrcfg` power profiles through a system tray icon. Instead of using terminal commands, users can right-click the tray icon and select their desired power profile.

## Status

🚧 **Work in Progress** - This project is currently under development.

## Planned Features

- System tray icon showing current power profile
- Right-click menu to switch between power profiles:
  - Emergency (10W)
  - Battery (18W)
  - Efficient (30W)
  - Balanced (40W)
  - Performance (55W)
  - Gaming (70W)
  - Maximum (90W)
- Visual indicators for AC/Battery status
- Automatic profile switching configuration
- Real-time power monitoring display

## Technology Stack

To be determined - considering:
- Python with PyQt5/PyQt6
- Python with GTK
- Electron-based application
- Native system tray implementations

## Installation

Not yet available.

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
