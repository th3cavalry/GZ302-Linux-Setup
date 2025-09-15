# GZ302-Multi-Distro-Setup

Complete Linux installation and setup scripts optimized for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+ processor, supporting multiple popular gaming distributions.

## Overview

This repository provides setup scripts for **10 popular Linux gaming distributions** on the ASUS ROG Flow Z13 (GZ302):

### Distribution Scripts Available:

1. **`flowz13_setup.sh`** - Arch Linux post-installation setup and optimizations
2. **`ubuntu_setup.sh`** - Ubuntu gaming setup with LLM support
3. **`fedora_setup.sh`** - Fedora gaming setup with RPM Fusion and LLM support
4. **`popos_setup.sh`** - Pop!_OS enhanced gaming configuration with LLM support
5. **`manjaro_setup.sh`** - Manjaro with AUR gaming packages and LLM support
6. **`opensuse_setup.sh`** - OpenSUSE (Tumbleweed/Leap) gaming setup
7. **`endeavouros_setup.sh`** - EndeavourOS user-friendly Arch setup
8. **`nobara_setup.sh`** - Nobara gaming-focused enhancements
9. **`linuxmint_setup.sh`** - Linux Mint stable gaming platform

Each script is tailored to the specific distribution's package management and repository system while providing the same core hardware fixes, gaming optimizations, and optional LLM/AI framework installation.

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
- **User Choice**: Optional gaming installation with user prompts

### LLM/AI Support (New in v1.3)
- **Ollama**: Local LLM inference for running models like Llama2, Code Llama, etc.
- **ROCm**: AMD GPU acceleration for machine learning workloads
- **PyTorch with ROCm**: Deep learning framework with AMD GPU support
- **Transformers**: Hugging Face transformers library for NLP tasks
- **User Choice**: Optional LLM/AI installation with user prompts
- **Flexible Selection**: Choose which LLM frameworks to install

## Quick Start

### Choose Your Distribution

Select the setup script for your Linux distribution:

#### Arch Linux (Post-Installation Setup)
```bash
# If you already have Arch Linux installed
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/flowz13_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Ubuntu/Ubuntu-based Distributions
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/ubuntu_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Fedora
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/fedora_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Pop!_OS
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/popos_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Manjaro
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/manjaro_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### OpenSUSE (Tumbleweed/Leap)
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/opensuse_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### EndeavourOS
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/endeavouros_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Nobara Linux
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/nobara_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Linux Mint
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/linuxmint_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

After running any script, **reboot your system** to apply all changes.

## Installation Options (New in v1.3)

All scripts now include user prompts for optional installations:

### Gaming Software
When you run any setup script, you'll be prompted whether to install gaming software including:
- Steam with Proton support
- Lutris for game management
- ProtonUp-Qt for Proton version management
- MangoHUD for performance monitoring
- GameMode for automatic optimizations

### LLM/AI Software
You'll also be prompted whether to install LLM/AI frameworks including:
- **Ollama**: For running local language models (Llama2, Code Llama, etc.)
- **ROCm**: AMD GPU acceleration for ML workloads
- **PyTorch with ROCm**: Deep learning with AMD GPU support
- **Transformers**: Hugging Face library for NLP tasks

You can choose to install all, some, or none of these optional components.

## What Gets Installed

All distribution scripts provide the same core components, adapted to each distribution's package management:

### Gaming Software
- **Steam**: With multilib/32-bit support and Proton
- **Lutris**: Game launcher and manager
- **ProtonUp-Qt**: GUI tool for managing Proton versions (Flatpak/AUR/native packages)
- **MangoHUD**: Performance overlay for games
- **Goverlay**: GUI for MangoHUD configuration (where available)
- **GameMode**: Automatic system optimizations during gaming
- **Wine**: Windows compatibility layer
- **Winetricks**: Wine configuration utility

### Hardware Support (All Distributions)
- **AMD GPU Drivers**: Mesa, Vulkan, VA-API, VDPAU acceleration
- **Audio Support**: Full audio device compatibility fixes
- **Wi-Fi Fixes**: MediaTek MT7925 stability improvements
- **Touchpad Support**: Proper multi-touch detection and sensitivity
- **Power Management**: TLP/distribution-specific power optimization
- **Thermal Management**: Proper throttling and cooling policies

### Distribution-Specific Enhancements

#### Arch Linux
- **linux-g14 kernel**: Better hardware support for ASUS devices
- **ASUS Linux tools**: asusctl, supergfxctl, rog-control-center
- **AUR packages**: Direct access to AUR gaming packages

#### Ubuntu/Debian-based (Ubuntu, Pop!_OS, Linux Mint)
- **Multiverse repositories**: Additional multimedia and gaming packages
- **Steam repository**: Official Steam packages
- **Flatpak support**: Alternative package installation method
- **Hardware acceleration**: VA-API and VDPAU for AMD GPUs

#### Fedora/Red Hat-based (Fedora, Nobara)
- **RPM Fusion**: Free and non-free multimedia packages
- **Native gaming packages**: Steam, Lutris from official repos
- **Enhanced codec support**: Full multimedia codec stack

#### SUSE-based (OpenSUSE)
- **Packman repository**: Multimedia codecs and enhanced packages
- **Games repository**: Additional gaming packages
- **Both Tumbleweed and Leap support**: Automatic version detection

#### Arch-based (Manjaro, EndeavourOS)
- **AUR helper**: yay for easy AUR package management
- **Gaming-focused AUR packages**: ProtonUp-Qt, Goverlay, latest tools
- **Optimized mirror selection**: Better download speeds

### Performance Optimizations (All Distributions)
- **Kernel Parameters**: Gaming-optimized sysctl settings (vm.max_map_count, etc.)
- **I/O Schedulers**: Optimized for SSD/NVMe performance
- **CPU Governor**: Performance profiles for gaming
- **Memory Management**: Reduced swappiness and optimized cache
- **Network Tuning**: Reduced latency for online gaming
- **System Limits**: Increased limits for gaming compatibility

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
