# Changelog

All notable changes to the GZ302 Linux Setup project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.10] - 2025-12-02

### Added
- **Limine bootloader support** (Fixes #134): Automatic kernel parameter configuration for Limine bootloader
  - Added `ensure_limine_kernel_param()` helper function to `gz302-utils.sh`
  - Added Limine detection in `detect_bootloader()` function
  - Kernel parameters (amd_pstate, amdgpu options, sleep settings) now auto-configured for Limine
  - Automatic regeneration via `limine-mkinitcpio` or `limine-mkconfig` when changes are made
  - Popular on CachyOS and other Arch-based distributions
  - Added Limine support to `gz302-llm.sh` kernel parameter configuration

### Changed
- **Open WebUI installation**: Now a user choice (frontend option 4), not auto-installed with Ollama
  - Open WebUI can work independently with various backends (Ollama, llama.cpp, OpenAI API)
  - Auto-detects available backends (Ollama on :11434, llama.cpp on :8080) when installing
  - Users can configure additional backends in Open WebUI Settings after installation
- **Improved `setup_openwebui_docker()`**: Smarter backend detection and configuration
- **Documentation**: Added comprehensive Open WebUI Docker installation guide to `Info/AI_ML_PACKAGES.md`
  - Docker run examples for different configurations
  - Docker Compose setup with AMD GPU (ROCm) support
  - Management commands (update, logs, Watchtower)
- **Version sync**: Updated gz302-utils.sh, gz302-llm.sh, and gz302-gaming.sh versions to match main script (2.3.10)

### Fixed
- **Limine regex edge cases**: Improved `ensure_limine_kernel_param()` to handle various config formats
- **Gaming module jack2/pipewire-jack conflict** (Fixes #?): Automatically removes conflicting jack2 package
  - wine-staging depends on jack interface, but pipewire-jack provides it
  - Script now removes jack2 if present before installing pipewire-jack
  - Prevents "conflicting dependencies" error during gaming module installation

## [2.3.9] - 2025-12-02

### Added
- **CachyOS LLM/AI flow optimizations**: Added CachyOS-specific installation and package selection for LLM/AI workflows
  - Uses `ollama-rocm` where available for prebuilt ROCm Ollama packages
  - Uses `python-pytorch-opt-rocm` for znver4-optimized PyTorch on CachyOS
  - Added README and Info/AI_ML_PACKAGES.md documentation describing CachyOS steps
  - Added `is_cachyos()` detection routine and improved LLM module behavior for CachyOS in `gz302-llm.sh`

### Changed
- **LLM Installer behavior**: Arch-based installer now prefers CachyOS optimized packages when detected and falls back to venv/pip/conda if needed

# Previous release
## [2.3.8] - 2025-12-02

### Added
- **CachyOS-specific optimizations**: Automatic detection and tailored recommendations for CachyOS users
  - Information about BORE scheduler benefits (better gaming/interactive performance)
  - Guidance on x86-64-v3/v4 optimized packages (5-20% performance boost)
  - LTO/PGO optimization awareness
  - Kernel selection recommendations (linux-cachyos-bore, linux-cachyos-rt-bore, linux-cachyos-lts)
- **Distribution-specific optimization info**: New `provide_distro_optimization_info()` function provides:
  - AMD P-State mode recommendations (guided vs active)
  - Performance tuning guidance for all distributions
  - Trade-off explanations between power efficiency and predictable performance
- **ROCm repository setup for Debian/Debian Trixie**: Automatic AMD ROCm repository configuration
  - `setup_rocm_repo_debian()` function adds AMD's official ROCm 6.2 repository
  - Fallback to Debian's own ROCm packages if AMD repos unavailable
  - Better error handling and logging for repository setup

### Changed
- **Debian Trixie compatibility**: Removed `software-properties-common` dependency
  - Package no longer available in Debian 13 (Trixie/testing)
  - Updated warning messages to reflect Debian Trixie changes
  - Build from source now primary method for asusctl on Debian Trixie
- **Improved error handling**: 
  - Use apt exit codes instead of grep for error detection
  - Temporary log files for better diagnostics
  - More robust shell command examples with proper error handling

### Fixed
- **Debian Trixie package installation**: Script now works on Debian 13/testing
- **ROCm installation on Debian**: Clearer messaging and better fallback handling
- **Code quality**: Addressed code review feedback for more robust error detection

### Technical Details
Research-backed optimizations from:
- CachyOS wiki and documentation (performance benchmarks showing 5-20% improvement)
- Phoronix benchmarks of CachyOS vs standard Arch on Strix Halo hardware
- AMD P-State driver documentation and community testing
- Debian Trixie package repository changes and ROCm availability
- AMD ROCm official documentation for Debian installation

## [2.3.0] - 2025-11-30

### Changed
- **Kernel requirements updated**: Minimum kernel lowered from 6.14 to **6.12** (Strix Halo baseline support with RDNA 3.5 GPU)
- **Kernel version messaging improved**: Clearer information about 6.12 (minimum), 6.17+ (recommended), and 6.20+ (optimal with latest fixes)
- **Switched to amdgpu.dcdebugmask=0x10**: Changed from 0x410 to 0x10 as default DC debug parameter; 0x410 available as variant for troubleshooting
- **Sudoers configuration automatic**: Password-less sudo for pwrcfg, rrcfg, and gz302-rgb now applied automatically without user prompt
- **GPU firmware verification**: Added runtime checks for RDNA 3.5 firmware files (gc_11_5_1_pfp.bin, dcn_3_5_1_dmcub.bin, etc.)

### Added
- **Enhanced GPU detection**: GPU firmware validation and detailed module configuration comments for Strix Halo-specific settings
- **Comprehensive kernel documentation**: Inline comments referencing DC fixes, pageflip timeout resolution, and Wayland stability improvements from kernel 6.12-6.20+
- **Display Core (DC) parameter documentation**: Comments explaining dcdebugmask options (0x10 baseline, 0x12 optimization, 0x410 custom variant)

### Fixed
- **Wayland freeze mitigation**: Updated Display Core debug parameters based on latest community findings (kernel 6.17+ includes native pageflip fixes)
- **MediaTek MT7925 WiFi**: Confirmed ASPM workaround still needed for kernels < 6.17; unnecessary for 6.17+

### Technical Details
Based on extensive research of kernel changelogs, asus-linux.org community, Reddit forums (r/linux, r/archlinux, r/linuxgaming), and GitHub issue trackers for GZ302/Strix Halo/RDNA 3.5 hardware. v2.3.0 incorporates:
- Latest Strix Halo (Zen 5) power management insights
- RDNA 3.5 GPU driver improvements from kernel 6.20+
- Wayland/KWin freezing diagnostic history and resolution paths
- Display Core (DC) stability fixes from latest linux-firmware
- User-reported fixes and workarounds from community forums


### Added
- Kernel parameter helper to safely append missing options to `GRUB_CMDLINE_LINUX_DEFAULT` and regenerate GRUB once per change.
- Systemd-boot support: automatically appends parameters to `/etc/kernel/cmdline` (when present) or directly patches `/boot/loader/entries/*.conf` `options` lines (fallback) and rebuilds boot entries (`mkinitcpio -P` on Arch, `dracut --regenerate-all -f` on Fedora/OpenSUSE, `update-initramfs -u -k all` on Ubuntu when applicable). Also runs `bootctl update`.
- Display stability parameters extracted from field fixes:
  - `amdgpu.sg_display=0` (Wayland/KWin pageflip mitigation)
  - `amdgpu.dcdebugmask=0x410` (prevents intermittent freezes on GZ302)
- Power management defaults:
  - `mem_sleep_default=deep`
  - `acpi_osi="Windows 2022"`
- Touchpad stability quirk: `/etc/modprobe.d/i2c-hid-acpi-gz302.conf` with `options i2c_hid_acpi quirks=0x01` (avoids blacklisting `hid_asus`).
- Audio: Detect Cirrus Logic CS35L41 and apply HDA patch configuration automatically.

### Changed
- Refactored kernel parameter insertion to be idempotent and additive rather than a single conditional block.

### Notes
- Changes are conservative and only apply when the respective files exist (`/etc/default/grub`), maintaining cross-distro compatibility.
- For systemd-boot, changes apply only when `/etc/kernel/cmdline` exists; rebuild commands are selected per distribution and are best-effort.
- These updates were extracted from targeted community fixes and adapted to the project’s multi-distro, hardware-specific architecture.

## [2.0.4] - 2025-12-18

### Added
- **Automatic Path Migration for Backward Compatibility**: Scripts now detect and automatically migrate old paths from pre-2.0.0 versions to FHS-compliant standard paths
  - `gz302-main.sh`: Detects `/etc/pwrcfg`, `/etc/rrcfg`, `/etc/gz302-rgb` and migrates to `/etc/gz302/{pwrcfg,rrcfg}`
  - `gz302-llm.sh`: Detects `~/.local/share/gz302-llm` and migrates to `/var/lib/gz302-llm` (system-wide venv location)
  - `gz302-rgb-restore.sh`: Detects `/etc/gz302-rgb/last-setting.conf` and migrates to `/etc/gz302/last-setting.conf`
  - Migration runs automatically on script execution with no user intervention required
  - Safe and idempotent - can be run multiple times without issues
  - Preserves all configuration and venv contents during migration
  - Cleans up old directories after successful migration

### Changed
- Version bumped: 2.0.3 → 2.0.4 (PATCH version for backward-compatibility migration feature)
- All three scripts now include migration functions called early in execution flow

### Fixed
- Users running older script versions will now have their configurations automatically migrated to new FHS-compliant paths
- No manual user intervention required for path updates

## [2.0.0] - 2025-11-18

### Changed
- **Version Bump**: Major version bump to 2.0.0 reflecting project maturity and stability
- All module scripts now synchronized to version 2.0.0 for consistency
- Documentation cleanup and standardization across all files

### Documentation
- Cleaned up and standardized formatting across all documentation files
- Improved consistency with README cleanup from previous release
- Enhanced readability and navigation of documentation

## [1.4.2] - 2025-11-17

### Fixed
- **KDE/HHD Power Profile Synchronization**: `pwrcfg` now syncs with power-profiles-daemon after applying TDP changes
  - Previously, `pwrcfg` only used power-profiles-daemon as a fallback when ryzenadj failed
  - Now `pwrcfg` updates power-profiles-daemon alongside ryzenadj to keep KDE and HHD in sync
  - KDE's battery icon (leaf/rocket) and HHD's TDP display now reflect changes made via system tray
  - Fan speeds and power indicators now update correctly when changing profiles via tray icon
  - Fixes issue where users couldn't tell if tray icon profile changes were working

### Changed
- `set_tdp_profile()` function now always syncs with power-profiles-daemon after successful ryzenadj execution
- Power profile mapping: maximum/gaming/performance → performance, balanced/efficient → balanced, battery/emergency → power-saver
- Version bumped: 1.4.1 → 1.4.2 (PATCH version for power profile sync bug fix)

## [1.4.1] - 2025-11-17

### Added
- **Visual Feedback in System Tray Menu**: Checkmarks (✓) now indicate currently active power profile
  - Active profile is marked with ✓, inactive profiles have 3-space indent for alignment
  - Battery charge limit menu (80%/100%) also shows checkmarks for active setting
  - Menu automatically rebuilds when profile changes (manual or external)
- **Enhanced Profile Change Notifications**: More detailed feedback when switching profiles
  - Notifications now display actual power values (SPL, sPPT, fPPT) and target refresh rate
  - Notification duration increased from 3s to 4s for better readability
  - Users can now clearly see the power profile change took effect

### Fixed
- Addressed user feedback that power profile changes via system tray were unclear/invisible
  - Issue particularly noticeable when KDE and HHD sync with power profiles
  - Users can now immediately see which profile is active in the menu
  - Real-time visual confirmation that profile change succeeded

### Changed
- `create_menu()` method now adds visual indicators (✓) to active items
- `change_profile()` parses pwrcfg output to show detailed power information in notifications
- `update_current_profile()` detects profile changes and rebuilds menu automatically
- Added `self.current_profile` attribute to track active power profile
- Added `get_current_charge_limit()` helper method for charge limit menu
- Version bumped: 1.4.0 → 1.4.1 (PATCH version for UI/visibility improvements)

## [1.4.0] - 2025-11-16

### Added
- **RGB Keyboard Persistence on Boot**: Automatically restore last used RGB setting after system reboot
  - New `save_rgb_setting()` function in `gz302-rgb-cli.c` to persist RGB commands to `/etc/gz302-rgb/last-setting.conf`
  - New `gz302-rgb-restore.sh` script to restore RGB settings during system boot
  - New `gz302-rgb-restore.service` systemd unit file for automatic boot-time restoration
  - Tray icon now saves RGB settings for color and animation changes via `save_rgb_setting()` method
  - Config file format: `COMMAND`, `ARG*`, `ARGC` for reliable argument reconstruction

### Fixed
- Tray icon animation settings (breathing, color cycle, rainbow) now persist across reboots via `save_rgb_setting()` integration

### Changed
- Version bumped: 1.3.2 → 1.4.0 (MINOR version for RGB persistence feature)
- All module scripts now at version 1.4.0 for consistency

## [1.3.1] - 2025-11-15

### Added
- **Custom GZ302-specific RGB CLI** (`gz302-rgb-cli.c`): 318-line C implementation optimized for the GZ302
  - 70% smaller binary size (17KB vs 58KB) compared to rogauracore
  - MIT licensed with full copyright attribution
  - Supports static colors, breathing/color-cycle/rainbow animations, and brightness control
  - Compiled automatically by `gz302-rgb.sh` module
- **System Tray RGB Integration**: Keyboard RGB controls now available in system tray icon
  - New "Keyboard RGB" submenu with static color presets (Red, Green, Blue, Yellow, Cyan, Magenta, White, Black)
  - Animation controls with adjustable speed (Breathing, Color Cycle, Rainbow)
  - Custom hex color input dialog
  - Auto-detects gz302-rgb binary availability
  - Seamless integration with power profile switching

### Fixed
- Replaced external rogauracore dependency with built-in custom CLI
- Removed multi-model support complexity, streamlined for GZ302 hardware only
- Improved binary size and installation performance across all distributions

### Changed
- `gz302-rgb.sh` module redesigned: now compiles custom binary instead of downloading external tools
- Tray icon now provides centralized control for both brightness and RGB colors
- Version bumped: 1.2.1 → 1.3.1 (MINOR version for new RGB features and custom CLI architecture)

## [1.2.1] - 2025-11-15

### Added
- New `kbrgb` CLI template script with palette presets, custom hex colors, brightness control, and RGB effects.
- Persistent RGB state tracking under `~/.config/gz302` so tray icon and CLI share the last selected color/effect.

### Fixed
- Restored `install_kbrgb_control` functionality by shipping the missing template file, preventing "install_kbrgb_control: command not found" errors.
- Updated documentation and module headers so every script reports version 1.2.1 consistently.

### Changed
- README and contributor instructions now reflect version 1.2.1 and clarify the asusctl dependency for RGB controls.

## [1.1.0] - 2025-11-12

### Added
- **Full QEMU/KVM Stack Installation** - Comprehensive virtualization support
  - Complete QEMU system with all necessary components (qemu-full, qemu-system, qemu-utils)
  - libvirt daemon configuration and management
  - virt-manager GUI and virsh CLI tools
  - UEFI/OVMF firmware for modern guest OS support
  - Automatic default NAT network setup (virbr0, 192.168.122.0/24)
  - Virtualization hardware support verification (checks for AMD-V/Intel VT-x)
  - User permission configuration (libvirt, kvm, libvirt-qemu groups)
  - Guest tools and utilities (guestfs-tools, libguestfs-tools)
  - Bridge networking utilities (bridge-utils, dnsmasq, netcat)
- Enhanced VirtualBox installation with proper kernel module configuration
- Virtualization support detection and BIOS enablement checks
- Comprehensive installation feedback with next steps and usage instructions
- Non-interactive mode support for automated deployments

### Fixed
- **Critical: Duplicate Function** - Removed duplicate `get_battery_status()` function (was defined at lines 1078 and 1986 in gz302-main.sh)
- **Code Quality: Unreachable Code** - Fixed all shellcheck SC2317 warnings by removing unreachable `return 1` statements after `error()` calls
- **Consistency: Error Handling** - Standardized error handling across all modules (error() function now exits directly)
- Improved `get_real_user()` function consistency across all module scripts

### Improved
- **Performance: Code Efficiency** - Reduced redundant operations and improved overall script performance
- **UX: Error Messages** - More informative error messages with troubleshooting guidance
- **Documentation: Inline Comments** - Enhanced inline documentation for complex sections
- **Architecture: Module Organization** - Better separation of concerns in hypervisor module
- Optimized network checks to avoid redundant operations
- Better validation and error recovery in package installations

### Changed
- Hypervisor module version bumped from 0.2.0-RC1 to 0.3.0
- Main script version bumped from 1.0.9 to 1.1.0
- Updated README with comprehensive hypervisor feature documentation
- Enhanced module descriptions with detailed feature lists

### Security
- Improved input validation in all user-facing prompts
- Better handling of sudo/privilege escalation

## [1.0.5] - 2025-10-17

### Fixed
- Line 66 runtime error: restored logging helpers at top of script and removed orphaned block
- Keyboard backlight not restoring after resume: add system-sleep hook to save/restore brightness

### Changed
- Folio resume prompt UX: single-key Y/N with 30s timeout; defaults to No when non-interactive

### Notes
- Syntax and lint checks added to workflow when editing main script

## [1.0.1] - 2025-10-16

### Fixed
- **Issue #83**: Folio keyboard/touchpad not working after suspend/resume. Added optional resume service that reloads HID and attempts USB rebind for folio device. See `gz302-folio-resume.sh` for details and update vendor/product IDs if needed.

### Changed
- **Folio Resume Fix**: Now optional - user is prompted during installation (only install if experiencing the issue)
- **Systemd Resume Service**: When enabled, calls folio resume script for full HID and USB rebind after sleep
- **Documentation**: Updated README.md with folio resume workaround and instructions

### Added
- **Tray Icon Subproject**: Created `tray-icon/` directory for future GUI utility (work in progress)

## [1.0.0] - 2025-10-16

### 🎉 Stable Release
First stable release with complete hardware support, modern power management, and all critical issues resolved.

### Fixed
- **Issue #82**: Added missing `reload-hid_asus.service` to fix touchpad detection issues on Arch Linux
- **Issue #82 (suspend/resume)**: Added `reload-hid_asus-resume.service` to fix touchpad gestures after wake from sleep
  - Single-finger movement now works correctly after suspend/resume
  - Module reloads automatically 2 seconds after waking from suspend/hibernate
  - Fixes issue where only two-finger movement worked after resume
- **Critical Bug**: Removed conflicting `rrcfg auto` functionality that caused race conditions with `pwrcfg`
  - Eliminated duplicate auto-switching between pwrcfg and rrcfg
  - Removed rrcfg-auto.service and rrcfg-monitor.service to prevent conflicts
  - Simplified refresh rate management to be controlled solely by pwrcfg
  - Fixed configuration confusion where users had separate AC/Battery profiles for power and refresh

### Added
- **Touchpad Detection**: Restored systemd service for reliable HID module loading at boot
- **Touchpad Resume Fix**: New systemd service reloads HID module after suspend/resume for gesture support
- **Service Integration**: Automatic enabling of both reload-hid_asus services during hardware setup

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
