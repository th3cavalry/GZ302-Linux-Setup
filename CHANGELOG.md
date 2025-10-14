# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2025-10-14

### Changed
- **BREAKING**: Removed linux-g14 kernel installation and all related functionality
- Script now uses mainline distro kernels exclusively
- Simplified kernel handling - only updates kernel if version is older than 6.6
- Removed `--use-g14` and `--no-g14` command-line flags

### Removed
- `install_g14_kernel()` function
- G14 kernel-specific logic and decision making
- AUR helper installation for linux-g14 packages
- Manual git clone and makepkg workflow for linux-g14
- G14_INSTALLED and USE_G14 variables

### Improved
- Cleaner, more maintainable codebase
- Faster installation process
- Better compatibility across all distributions
- Simplified user experience with no kernel-related decisions needed

## [1.2.0] - 2025-10-14

### Changed
- **BREAKING**: ASUS tools now installed from official Asus Linux repositories
- Arch Linux: Uses official [g14] repository instead of AUR
- Debian/Ubuntu: Uses official PPA from Mitchell Austin with GPG key verification
- Fedora: Uses official Copr repository (lukenukem/asus-linux)
- openSUSE: Uses official OBS repository with version detection
- Removed source compilation fallback - all installations use official packages

### Added
- Automatic Ubuntu version detection for correct PPA selection
- Automatic openSUSE version detection (Tumbleweed vs Leap)
- GPG key verification for Debian/Ubuntu installations
- asusd service enablement alongside supergfxd

### Improved
- ASUS tools now receive automatic updates through package manager
- More reliable installation process using official repositories
- Better version compatibility handling for different distributions

## [1.1.0] - 2025-10-14

### Changed
- **BREAKING**: Removed installation modes (--auto, --minimal, --full flags)
- Script now runs fully automatically with all features installed by default
- Automatic reboot after installation (10-second countdown with option to cancel)
- Simplified user interaction - only requires Enter to continue or Ctrl+C to cancel

### Added
- **G14 kernel support**: Automatically installs linux-g14 kernel and headers on Arch-based systems
- **systemd-boot support**: Now supports both GRUB and systemd-boot bootloaders
- Automatic bootloader detection and configuration
- Enhanced kernel installation with ROG-specific optimizations

### Removed
- Interactive prompts for individual components
- --auto, --minimal, --full command-line flags
- --skip-kernel flag (kernel is always installed/updated)
- Manual reboot prompt (now automatic)

## [1.0.0] - 2025-10-14

### Added
- Initial release of GZ302EA Linux setup script
- Comprehensive post-installation script for Asus ROG Flow Z13 2025
- Support for all three models: GZ302EA-XS99 (128GB), GZ302EA-XS64 (64GB), GZ302EA-XS32 (32GB)
- Multi-distribution support:
  - Arch-based: Arch Linux, Manjaro, EndeavourOS, Garuda Linux
  - Debian-based: Ubuntu, Linux Mint, Pop!_OS, Debian, Elementary OS, Zorin OS
  - Fedora-based: Fedora, Nobara
  - openSUSE: Leap and Tumbleweed
  - Other: Gentoo, Void Linux
- Automatic distribution detection and package manager selection
- Kernel version checking and update functionality
- AMD Radeon 8060S graphics driver setup (Mesa 25.0+, Vulkan)
- MediaTek MT7925 WiFi/Bluetooth firmware and driver configuration
- ASUS-specific tools installation (asusctl, supergfxctl)
- Power management optimization with TLP
- Audio configuration with SOF firmware
- Suspend/resume fixes with S3 sleep support
- Display and touchscreen support
- GRUB bootloader configuration with optimal kernel parameters
- Interactive, automatic, and minimal installation modes
- Comprehensive README with installation instructions
- Detailed troubleshooting guide
- Contributing guidelines
- MIT License

### Features
- Color-coded terminal output for better readability
- User confirmation prompts with auto-mode support
- Automatic backup of configuration files before modification
- Post-installation summary and testing instructions
- Modular function-based architecture for easy maintenance
- Error handling with informative messages

### Documentation
- README.md with complete usage instructions
- TROUBLESHOOTING.md with solutions for common issues
- CONTRIBUTING.md with guidelines for contributors
- Inline code comments for maintainability
- Example commands and configurations

## [Unreleased]

### Planned
- Additional distribution support
- Automated testing framework
- GUI installation option
- Custom kernel build scripts
- DSDT patching automation
- Fingerprint reader support (when available in kernel)
- Enhanced RGB keyboard controls
- Performance benchmarking tools
- Backup and restore functionality

---

[1.2.0]: https://github.com/th3cavalry/GZ302-Linux-Setup/releases/tag/v1.2.0
[1.1.0]: https://github.com/th3cavalry/GZ302-Linux-Setup/releases/tag/v1.1.0
[1.0.0]: https://github.com/th3cavalry/GZ302-Linux-Setup/releases/tag/v1.0.0
