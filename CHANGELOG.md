# Changelog

All notable changes to the GZ302 Linux Setup project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3-pre-release] - 2025-10

### Changed - Major 2025 Linux Support Update
- Updated kernel requirements to 6.14+ minimum (6.15+ strongly recommended)
- Updated to reflect kernel 6.14 release (March 2025) and 6.15 release (May 2025)
- Enhanced documentation with current Linux kernel support status
- Modernized all kernel version references throughout repository

### Added
- Kernel version checking function with automatic detection and user warnings
- Conditional MediaTek MT7925 WiFi workarounds based on kernel version
  - Kernels < 6.15: Automatic ASPM workaround applied
  - Kernels 6.15+: Native WiFi stability, no workaround needed
- Comprehensive linux-g14 kernel documentation and recommendations
  - Documented that linux-g14 is optional with mainline 6.14+
  - Added guidance on when to use mainline vs linux-g14
- Kernel 6.14 benefits documentation:
  - AMD XDNA NPU driver support
  - MediaTek MT7925 WiFi 7 MLO support
  - Enhanced AMDGPU power management
- Kernel 6.15 benefits documentation:
  - Enhanced AMD Strix Halo AI inference performance
  - Improved Radeon 8060S graphics performance
  - Native MT7925 WiFi stability improvements

### Research Updates
- Linux kernel 6.14 released March 2025 with XDNA driver and WiFi 7 support
- Linux kernel 6.15 released May 2025 with significant Strix Halo improvements
- Phoronix benchmarks showing performance gains in 6.15 and 6.16
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
- Kernel 6.14+ MediaTek MT7925 WiFi improvement notes

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
