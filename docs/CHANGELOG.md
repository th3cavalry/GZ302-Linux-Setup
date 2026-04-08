# Changelog

All notable changes to GZ302-Linux-Setup will be documented in this file.

## [5.0.3] - 2026-04

### Fixed
- **Tray Icon (Wayland/KDE):** Resolved "Failed to create grabbing popup" error by using `menu.exec()` and standardizing parentage. Tray icon now correctly appears and functions on KDE Plasma 6.
- **Power Profile Sync:** Implemented hardware-to-app profile validation. The tray app now correctly detects and resyncs if the physical profile (e.g., Balanced) differs from the cached UI state.
- **Backend Permissions:** Added `sudo -n` fallback for TDP and RGB commands to ensure reliability when the user-level daemon lacks direct hardware access.
- **App Menu Cleanup:** Enhanced installer to aggressively remove legacy desktop entries, fixing the "double listing" issue in application menus.
- **Asset Discovery:** Standardized absolute path resolution for SVG icons to prevent missing icons when launched from different contexts.

### Changed
- Standardized all component versions to **5.0.3** for better release tracking.
- Updated `install-tray.sh` to remove conflicting launchers from both `/usr/share/applications` and `~/.local/share/applications`.

## [5.0.2] - 2025-04

### Fixed
- **OLED flickering — Panel Replay** (`DC_DISABLE_REPLAY = 0x400`): Panel Replay was explicitly enabled for DCN 3.5 (Strix Halo) by the amdgpu driver and was never disabled by previous releases. This is the primary cause of persistent flickering on the internal OLED panel.
- **OLED flickering — DRAM stutter** (`DC_DISABLE_STUTTER = 0x002`): On APU with unified memory, DRAM self-refresh causes display memory access latency spikes visible as brief flicker.
- **APU scatter-gather display** (`amdgpu.sg_display=0`): Kernel explicitly documents this option for APU flickering under memory pressure (Strix Halo is an APU with unified memory).
- **Adaptive Backlight Management** (`amdgpu.abmlevel=0`): ABM now set via modprobe option (persistent across boots) rather than only at runtime.

### Changed
- `dcdebugmask` mask updated from `0xa10` to `0xe12`:
  - `0x002` = `DC_DISABLE_STUTTER` (new)
  - `0x010` = `DC_DISABLE_PSR` (PSR v1 + PSR-SU)
  - `0x200` = `DC_DISABLE_PSR_SU` (belt-and-suspenders)
  - `0x400` = `DC_DISABLE_REPLAY` (Panel Replay — new, critical)
  - `0x800` = `DC_DISABLE_IPS` (all Idle Power States)
- `/etc/modprobe.d/amdgpu.conf` now includes `abmlevel=0` and `sg_display=0` in addition to `ppfeaturemask=0xffff7fff`
- All `# Version:` headers bumped to 5.0.2 across all scripts

## [5.0.1] - 2025-04

### Fixed
- **OLED display artifacts** (initial fix): `amdgpu.dcdebugmask=0xa10` targeting PSR, PSR-SU, and IPS; `abmlevel=0` for OLED ABM. Panel Replay not yet addressed (see 5.0.2).

### Changed
- `gz302-lib/display-fix.sh` updated for all bootloaders (GRUB, systemd-boot, loader entries, Limine, rEFInd)
- `gz302-lib/gpu-manager.sh` added `abmlevel=0` to modprobe config

## [5.0.0] - 2025-04

### Added
- **z13ctl integration**: RGB, power profiles, TDP, fan curves, and battery limit now powered by [z13ctl](https://github.com/dahui/z13ctl)
- `pwrcfg`, `gz302-rgb`, `rrcfg` wrapper commands for backward compatibility
- PyQt6 system tray (`tray-icon/`) for power profile switching
- `gz302-lib/` library-first v5 architecture with all hardware as standalone sourced modules
- `gz302-lib/kernel-compat.sh` for kernel version–aware workarounds (6.14–6.17+)
- `gz302-lib/state-manager.sh` with atomic file writes and checkpoint system
- `gz302-lib/display-fix.sh` for OLED PSR/dcdebugmask fixes
- Optional modules (`modules/`) downloaded on demand: gaming, LLM, hypervisor
- Multi-distro support: Arch, Debian/Ubuntu, Fedora, OpenSUSE

### Changed
- Unified installer (`gz302-setup.sh`) replaces previous multi-script approach
- All hardware control via z13ctl (RGB, power, TDP, fan, battery)
- FHS-compliant config paths under `/etc/gz302/`, state under `/var/lib/gz302/`

## [4.2.1] - 2025-04-27

### Added
- **OLED PSR-SU fix library** (`gz302-lib/display-fix.sh`): Fixes scrolling artifacts (purple/green glitches, QR-code patterns) on the OLED panel by disabling PSR-SU via `amdgpu.dcdebugmask=0x200`
- PSR-SU fix integrated into `apply_hardware_fixes()` as step 7 — automatically detects and applies on first run
- Safe mask merging: existing `dcdebugmask` values are OR'd (not overwritten) to preserve other debug flags
- Supports GRUB, systemd-boot (`/etc/kernel/cmdline`), and loader entries
- Runtime PSR-SU disable via `amdgpu_dm_debug_mask` debugfs node

### Changed
- **PyTorch ROCm URL** updated from `rocm6.2` to `rocm7.2` (current stable)
- **LM Studio download** changed from hardcoded v0.3.6 AppImage to dynamic `https://lmstudio.ai/download/linux` redirect
- **RGB config permissions** tightened from 777/666 to 775/664 with `chgrp users` (OWASP compliance)
- **SOF firmware installation** deduplicated — `install_sof_firmware()` in main script now delegates to `audio-manager.sh` library (was 60 lines inline)
- Version banner in `main()` now reads from `VERSION` file instead of hardcoded "v2.3.13"
- All version strings synchronized to 4.2.1 across all files

### Fixed
- `dcdebugmask` value corrected from `0x20` (wrong bit) to `0x200` (`DC_DISABLE_PSR_SU`)
- Duplicate `provide_distro_optimization_info` call removed from `setup_debian_based()`
- Duplicate "GPU and thermal optimizations" completion line removed
- Step numbering corrected in all 4 distro setup functions (was "Step X of 7" with only 3-4 steps)
- `gz302-minimal.sh` self-references corrected from `gz302-minimal-v4.sh` to `gz302-minimal.sh`

### Removed
- 4 empty `enable_*_services()` stub functions and their call sites
- Legacy TODO/delegation comments from `apply_hardware_fixes()`
- Dead code and excessive blank lines throughout

## [4.2.0] - 2025-04

### Added
- Library-first architecture (`gz302-lib/`) for all hardware managers
- State management system with checkpoints and backups
- Kernel compatibility layer (`kernel-compat.sh`)
- Multi-distro support (Arch, Debian, Fedora, OpenSUSE)

## [4.0.0] - 2025

### Changed
- Major refactor from monolithic script to modular library architecture
- Optional modules (gaming, LLM, hypervisor) downloaded on demand
- RGB control split into keyboard (C binary) and lightbar (Python)

