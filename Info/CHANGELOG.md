# Changelog

All notable changes to the GZ302 Linux Setup project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Issue #82**: Added missing `reload-hid_asus.service` to fix touchpad detection issues on Arch Linux
- **Documentation**: Updated memory instructions version from 0.1.x to 0.2.0-RC1
- **Critical Bug**: Removed conflicting `rrcfg auto` functionality that caused race conditions with `pwrcfg`
  - Eliminated duplicate auto-switching between pwrcfg and rrcfg
  - Removed rrcfg-auto.service and rrcfg-monitor.service to prevent conflicts
  - Simplified refresh rate management to be controlled solely by pwrcfg
  - Fixed configuration confusion where users had separate AC/Battery profiles for power and refresh

### Added
- **Touchpad Detection**: Restored systemd service for reliable HID module loading
- **Service Integration**: Automatic enabling of reload-hid_asus.service during hardware setup

### Changed
- **Refresh Rate Management**: `rrcfg` is now manual-only, automatic switching is handled by `pwrcfg config`
- **Documentation**: Updated README.md to clarify that pwrcfg controls both power and refresh rate auto-switching
- **Simplified Architecture**: Reduced gz302-main.sh from 2734 to 2568 lines by removing redundant auto-switching code

## [0.2.0-pre-release] - 2025-10-15

### BREAKING CHANGES
- **Command Names Changed**: `gz302-tdp` → `pwrcfg`, `gz302-refresh` → `rrcfg`
- **Config Directories Changed**: `/etc/gz302-tdp` → `/etc/pwrcfg`, `/etc/gz302-refresh` → `/etc/rrcfg`
- **Power Profile Names Changed**: Simplified naming (emergency, battery, efficient, balanced, performance, gaming, maximum)
- **Minimum Kernel Version**: Changed from 6.15+ to 6.14+ (now REQUIRED, blocks installation on older kernels)

### Added
- **Info Folder Structure**: Created `Info/` directory for all research and documentation
- **Kernel Changelog**: New `Info/kernel_changelog.md` with GZ302-specific kernel improvements (6.14-6.17)
- **SPL/sPPT/fPPT Power Architecture**: Advanced power management with Sustained/Slow/Fast power limits
- **Automatic Refresh Rate Sync**: Power profile changes automatically adjust display refresh rate
- **Enhanced Power Profiles**: 7 profiles with detailed power specifications:
  - Emergency: 10/12/12W @ 30Hz
  - Battery: 18/20/20W @ 30Hz
  - Efficient: 30/35/35W @ 60Hz
  - Balanced: 40/45/45W @ 90Hz
  - Performance: 55/60/60W @ 120Hz
  - Gaming: 70/80/80W @ 180Hz
  - Maximum: 90/90/90W @ 180Hz

### Changed
- **Kernel Support**: Now requires 6.14+ minimum (AMD XDNA NPU driver integration)
- **WiFi Fixes**: Updated threshold from < 6.15 to < 6.16 for ASPM workaround
- **Documentation Organization**: Moved CHANGELOG.md and RESEARCH_SUMMARY.md to Info/ folder
- **Version Numbering**: Incremented MINOR version (0.1.3 → 0.2.0) for breaking changes
- **README.md**: Complete rewrite with new command names and power profile details

### Research Updates
- Comprehensive kernel changelog research for versions 6.14-6.17
- AMD Strix Halo improvements documented across kernel versions
- AMD Radeon 8060S (RDNA 3.5) enhancements tracked
- MediaTek MT7925 WiFi driver evolution documented
- All kernel research consolidated in Info/kernel_changelog.md

### Technical Improvements
- Kernel version check now blocks installation on < 6.14 (was warning-only)
- Power profiles use proper SPL/sPPT/fPPT ryzenadj parameters
- Systemd services renamed for consistency (pwrcfg-auto, pwrcfg-monitor, rrcfg-auto, rrcfg-monitor)
- Improved user messaging with detailed power profile information
- Better integration between power management and display refresh rate

## [0.1.3-pre-release] - 2025-10

### Changed - Kernel Support Update
- Updated kernel requirements to 6.15+ minimum (6.17+ strongly recommended)
- Updated to reflect kernel 6.17 release (September 2025) as latest stable
- Updated to reflect kernel 6.18 RC1 availability (October 2025)
- Enhanced documentation with current Linux kernel support status
- Modernized all kernel version references throughout repository

### Added
- Kernel version checking function with automatic detection and user warnings
- Conditional MediaTek MT7925 WiFi workarounds based on kernel version
  - Kernels < 6.15: Automatic ASPM workaround applied
  - Kernels 6.15+: Native WiFi stability, no workaround needed
- Comprehensive linux-g14 kernel documentation and recommendations
  - Documented that linux-g14 is optional with mainline 6.15+
  - Added guidance on when to use mainline vs linux-g14
- Kernel 6.15+ benefits documentation:
  - Native MT7925 WiFi stability (no ASPM workaround required)
  - Enhanced AMD Strix Halo AI inference performance
  - Improved Radeon 8060S graphics performance
- Kernel 6.17 benefits documentation:
  - Further AMD Strix Halo performance improvements
  - Enhanced integrated GPU scheduling and memory management
  - Improved MediaTek MT7925 WiFi performance

### Research Updates
- Linux kernel 6.17 (latest stable) released September 2025
- Linux kernel 6.18 RC1 released October 2025, final expected November/December 2025
- Phoronix benchmarks showing Strix Halo performance improvements in 6.17
- Updated asus-linux.org research on linux-g14 necessity

### Technical Improvements
- Script automatically detects kernel version and applies appropriate workarounds
- User-friendly kernel version warnings with detailed feature explanations
- Conditional hardware fix application based on detected kernel capabilities

## [0.1.2-pre-release] - 2024-10

### Changed
- Updated to version 0.1.2-pre-release based on extensive research
- Enhanced hardware fixes with latest community findings and kernel requirements
- Improved asusctl installation across all distributions with automated repository setup
- Updated kernel parameter comments with Ubuntu 25.10 benchmark confirmation
- Enhanced Wi-Fi configuration comments with EndeavourOS forum findings
- Updated AMD GPU configuration with ROCm compatibility notes
- Improved touchpad configuration with kernel 6.11+ gesture support notes

### Added
- Kernel version recommendations: 6.11+ minimum, 6.12+/6.13+ preferred for Strix Halo
- Arch Linux: G14 repository (https://arch.asus-linux.org) as primary asusctl source with AUR fallback
- Ubuntu/Debian: Mitchell Austin's PPA (ppa:mitchellaugustin/asusctl) with automated installation
- Fedora: COPR repository (lukenukem/asus-linux) with automated dnf copr enable
- OpenSUSE: OBS repository (hardware:asus) with automated zypper installation
- Note about ec_su_axb35 kernel module for advanced Strix Halo fan/power control
- References to Strix Halo HomeLab and Phoronix community research
- Kernel 6.15+ native MediaTek MT7925 WiFi stability notes

### Research Sources
- Shahzebqazi/Asus-Z13-Flow-2025-PCMR GitHub repository
- Level1Techs forums (Flow Z13 setup threads)
- asus-linux.org official documentation
- Strix Halo HomeLab (strixhalo-homelab.d7.wtf)
- Ubuntu 25.10 Strix Halo benchmarks
- Phoronix forums and community discussions
- EndeavourOS forums for MT7925 WiFi fixes

## [0.1.1-pre-release] - 2024-10

### Changed
- Version increment from 0.1.0 to 0.1.1
- Minor fixes and improvements

## [0.1.0-pre-release] - 2024-10

### Added
- Complete modular architecture redesign
- Core hardware fixes in gz302-main.sh (~2,200 lines)
- Gaming module (gz302-gaming.sh) - ~200 lines
- AI/LLM module (gz302-llm.sh) - ~180 lines  
- Hypervisor module (gz302-hypervisor.sh) - ~110 lines
- Snapshots module (gz302-snapshots.sh) - ~90 lines
- Secure boot module (gz302-secureboot.sh) - ~80 lines
- TDP management system with 7 profiles (10W to 65W)
- Refresh rate control with 6 profiles (30Hz to 180Hz)
- Support for all 4 distribution families with equal priority

### Hardware Support
- MediaTek MT7925e Wi-Fi fixes (ASPM disable, power save off)
- ASUS touchpad detection and functionality
- AMD Ryzen AI MAX+ 395 (Strix Halo) optimizations
- AMD Radeon 8060S integrated GPU configuration
- Thermal management and power profiles

### Distribution Support
- Arch-based: Arch Linux, EndeavourOS, Manjaro
- Debian-based: Ubuntu, Pop!_OS, Linux Mint
- RPM-based: Fedora, Nobara
- OpenSUSE: Tumbleweed and Leap

### Removed
- Monolithic script approach (moved to Old/ directory)
- Python implementation (moved to Old/ directory)
- All software installation from main script (now in modules)

### Technical Details
- Bash-only implementation (no Python dependency)
- Lightweight main script focused on hardware fixes
- On-demand module downloads from GitHub
- Improved error handling with trap
- Network connectivity validation
- Automatic distribution detection

## [4.3.1] - 2024-09 (Legacy Version)

This was the last version before the modular redesign. Files archived in Old/ directory.

### Features (Legacy)
- Monolithic bash script (~3,200 lines)
- Python alternative implementation
- Combined hardware fixes and software installation
- Support for 4 distribution families

---

## Version Number Format

- **MAJOR.MINOR.PATCH** (e.g., 0.1.1)
- **MAJOR**: Breaking changes or major architectural updates
- **MINOR**: New features, new hardware support, new modules
- **PATCH**: Bug fixes, documentation updates, minor improvements

## Pre-release Notation

- Versions with `-pre-release` suffix indicate active development
- Features are stable but may change before full release
- Full release (0.2.0) planned after community testing

---

**Repository**: https://github.com/th3cavalry/GZ302-Linux-Setup  
**Author**: th3cavalry using GitHub Copilot  
**Hardware Research**: Shahzebqazi's Asus-Z13-Flow-2025-PCMR
