# GZ302-Arch-Setup

Complete Arch Linux installation and setup scripts optimized for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+ processor.

## Overview

This repository provides two scripts for setting up Arch Linux on the ASUS ROG Flow Z13 (GZ302):

1. **`install-arch-gz302.sh`** - Complete Arch Linux installation from scratch
2. **`flowz13_setup.sh`** - Post-installation hardware fixes and gaming optimizations

## Features

### Hardware Support
- **Wi-Fi Stability**: Fixes for MediaTek MT7925 wireless adapter
- **Touchpad**: Proper detection and sensitivity configuration
- **Audio**: Complete audio device compatibility
- **AMD GPU**: Optimized driver configuration for integrated graphics
- **Thermal Management**: Proper throttling and power management
- **ASUS Controls**: Full integration with ASUS hardware controls

### Gaming Performance
- **Steam & Lutris**: Complete gaming platform setup
- **ProtonUp-Qt**: Easy Proton version management
- **MangoHUD & Goverlay**: Performance monitoring tools
- **GameMode**: Automatic gaming optimizations
- **CoreCtrl**: GPU performance control
- **System Optimizations**: Kernel parameters, I/O schedulers, and memory management
- **Smart Skip Logic**: Automatically detects and skips already-installed components (yay, Proton-GE)
- **Progress Reporting**: Detailed step-by-step progress with time estimates

## Quick Start

### Option 1: Complete Fresh Installation

If you want to install Arch Linux from scratch:

1. Boot from Arch Linux USB
2. Connect to internet (ethernet or Wi-Fi via `iwctl`)
3. Download and run the installation script:
   ```bash
   curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/install-arch-gz302.sh -o install.sh
   chmod +x install.sh
   ./install.sh
   ```
4. Follow the interactive prompts
5. Reboot and log in
6. The post-installation script will be ready in your home directory

### Option 2: Post-Installation Setup Only

If you already have Arch Linux installed:

1. Download and run the setup script:
   ```bash
   curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/flowz13_setup.sh -o setup.sh
   chmod +x setup.sh
   sudo ./setup.sh
   ```
2. Reboot to apply all changes

## What Gets Installed

### System Components
- **linux-g14 kernel**: Better hardware support for ASUS devices
- **ASUS Linux tools**: asusctl, supergfxctl, rog-control-center
- **Power management**: power-profiles-daemon, switcheroo-control

### Gaming Software
- **Steam**: With multilib support and Proton
- **Lutris**: Game launcher and manager
- **ProtonUp-Qt**: GUI tool for managing Proton versions
- **MangoHUD**: Performance overlay for games
- **Goverlay**: GUI for MangoHUD configuration
- **CoreCtrl**: AMD GPU control and overclocking
- **GameMode**: Automatic system optimizations during gaming

### Performance Optimizations
- **Kernel Parameters**: Gaming-optimized sysctl settings
- **I/O Schedulers**: Optimized for SSD/NVMe performance
- **CPU Governor**: Performance profiles for gaming
- **Memory Management**: Reduced swappiness and optimized cache
- **Network Tuning**: Reduced latency for online gaming
- **GPU Acceleration**: Hardware-accelerated video decoding

## Hardware-Specific Fixes

### Wi-Fi (MediaTek MT7925)
- Disabled ASPM for stability
- Power saving disabled
- MAC randomization disabled
- Additional stability parameters

### Touchpad
- Proper multi-touch detection
- Sensitivity adjustments
- HID driver reloading service

### Audio
- All audio devices properly detected
- ALSA configuration for best compatibility
- Model-specific driver parameters

### AMD GPU
- GPU recovery enabled
- Power management optimized
- All performance features enabled
- Hardware acceleration configured

## Troubleshooting

### Common Issues

**Wi-Fi not working after installation:**
- Reboot to apply kernel module changes
- Check if NetworkManager is running: `systemctl status NetworkManager`

**Touchpad not detected:**
- The reload-hid_asus service will fix this automatically after reboot
- Manual fix: `sudo modprobe -r hid_asus && sudo modprobe hid_asus`

**Games not running smoothly:**
- Ensure you're using the linux-g14 kernel
- Check if GameMode is active: `gamemoded -s`
- Use MangoHUD to monitor performance: `mangohud your_game`

**ASUS controls not working:**
- Verify services are running: `systemctl status supergfxd asusctl`
- Try restarting: `sudo systemctl restart supergfxd`

**"running makepkg as root is not allowed" error:**
- This has been fixed in the latest version of the script
- The script now properly cleans the environment when switching to non-root user
- If you encounter this with an older version, update to the latest script

**"Failed to connect to user scope bus via local transport" error:**
- This DBUS error has been fixed in version 1.3 of the script
- The script now properly sets XDG_RUNTIME_DIR and handles user session environment
- User services (like GameMode) will be enabled with proper DBUS session handling

**Script seems to hang or doesn't show progress:**
- Version 1.3 includes comprehensive progress reporting
- You'll see step-by-step progress (Step X/7) and detailed explanations
- Time estimates are provided for longer operations

### Getting Help

If you encounter issues:

1. Check the system logs: `journalctl -b`
2. Verify all services are running properly
3. Open an issue in this repository with:
   - Your hardware model (confirm it's GZ302)
   - Error messages or logs
   - Steps to reproduce the problem

## Contributing

Contributions are welcome! Please:

1. Test your changes on actual GZ302 hardware
2. Document any new fixes or optimizations
3. Update the README if adding new features
4. Follow the existing code style and structure

## Credits

This setup is based on the excellent work of:
- [asus-linux.org](https://asus-linux.org) community
- ASUS Linux drivers and tools developers
- Arch Linux community and documentation

## License

This project is open source and available under the MIT License.
