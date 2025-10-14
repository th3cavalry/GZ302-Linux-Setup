# Changelog

All notable changes to the GZ302 Linux Setup project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Fixed all shellcheck warnings across all scripts
- Removed duplicate `get_real_user()` function definitions in gz302-main.sh
- Improved code quality with proper quoting and variable declarations

### Added
- CONTRIBUTING.md with development guidelines
- CHANGELOG.md for tracking version history

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
