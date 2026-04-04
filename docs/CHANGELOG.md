# Changelog

All notable changes to GZ302-Linux-Setup will be documented in this file.

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

