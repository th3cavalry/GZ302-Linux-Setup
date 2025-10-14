# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/th3cavalry/GZ302-Linux-Setup/releases/tag/v1.0.0
