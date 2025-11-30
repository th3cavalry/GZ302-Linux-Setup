
# GZ302-Linux-Setup: Copilot Agent Instructions

This repository provides modular Linux setup scripts for the ASUS ROG Flow Z13 (GZ302) laptop (AMD Ryzen AI MAX+ 395, Radeon 8060S). Scripts automate hardware fixes, power/display management, and optional modules for gaming, AI, virtualization, and more. All code is Bash-first, hardware-specific, and distribution-agnostic (Arch, Debian/Ubuntu, Fedora, OpenSUSE).

**Reference this file for all agent work.**


## Big Picture Architecture

- **Core script:** `gz302-main.sh` (hardware fixes, power/display management, distribution detection)
- **Optional modules:** `gz302-gaming.sh`, `gz302-llm.sh`, `gz302-hypervisor.sh`, `gz302-snapshots.sh`, `gz302-secureboot.sh` (downloaded on demand)
- **GUI utility:** `tray-icon/` (system tray for power profile switching)
- **Legacy:** `Old/` (archived monolithic scripts, Python conversion docs)
- **Documentation:** `README.md`, `CONTRIBUTING.md`, `Info/` (kernel, changelog, research)


## Critical Workflows

- **Validation:**
    - Bash syntax: `bash -n gz302-main.sh` and all modules
    - Lint: `shellcheck gz302-main.sh` (zero warnings required)
    - Version: Line 7 in `gz302-main.sh` (`# Version: X.Y.Z`)
    - Download test: Validate GitHub raw URLs for modules
- **Distribution support:** All scripts must work for Arch, Debian/Ubuntu, Fedora, OpenSUSE (use detection logic in `gz302-main.sh`)
- **Module install:** Only download modules when requested; never bundle optional code in core script
- **Power/display management:** Use `pwrcfg` and `rrcfg` commands for profile switching; passwordless sudo is configured via `tray-icon/install-policy.sh`
- **Package management:** Use distro-specific commands (`pacman`, `yay`, `apt`, `dnf`, `zypper`) and helper functions (see script examples)



## Project-Specific Conventions

- **Bash scripts:** Always start with `set -euo pipefail`. Quote all variables and command substitutions. Use `local` for function scope. Output via `info`, `success`, `warning`, `error` helpers.
- **Function naming:** Use descriptive, underscore-separated names (e.g., `install_arch_packages_with_yay`).
- **Testing:** All scripts must pass `bash -n` and `shellcheck` with zero warnings before commit. Test on all supported distros (VMs/containers OK).
- **Versioning:**
    - Always increment the version in `gz302-main.sh` (line 7) when making any change (PATCH for bugfixes, MINOR for features, MAJOR for breaking changes).
    - Update the version in this file's header and in commit messages as well.
    - Example: `sed -i 's/Version: 1.2.1/Version: 1.2.2/' gz302-main.sh`
    - **All module scripts must match the main script version (currently 1.2.1)**
- **Documentation:** Update `README.md` and this file for any user-facing change. Follow markdown style and keep technical accuracy.
- Always check git status before and after operations


## Integration Points & External Dependencies

- **ASUS packages:** asusctl, power-profiles-daemon, switcheroo-control (installed per distro)
- **Kernel requirements:** 6.14+ (minimum), 6.17+ (recommended) for AMD XDNA NPU, Strix Halo, Wi-Fi stability
- **Custom commands:** `pwrcfg`, `rrcfg` (installed by main script)
- **Systemd services:** Created for power/refresh management
- **Optional modules:** Downloaded from GitHub raw URLs; never bundled in main script


## Examples & Key Files

- **Power profile switch:** `pwrcfg gaming` (auto-adjusts refresh rate)
- **Refresh rate switch:** `rrcfg gaming` (manual override)
- **Passwordless sudo:** `cd tray-icon && sudo ./install-policy.sh`
- **Distribution detection:** See `detect_distribution()` in `gz302-main.sh`
- **Legacy scripts:** See `Old/ARCHIVED.md` for migration notes
- **Documentation:** `README.md`, `CONTRIBUTING.md`, `Info/CHANGELOG.md`, `Info/kernel_changelog.md`


## Quick Reference: Validation & Build

```bash
# Validate main script
bash -n gz302-main.sh
shellcheck gz302-main.sh
grep "Version:" gz302-main.sh | head -1
# Validate all modules
bash -n gz302-*.sh
# Check script sizes
wc -l gz302-*.sh
```


## Troubleshooting & Safety

- **Never run scripts on development machines** (system-level changes)
- **Always validate syntax before commit**
- **Always increment version in main script**
- **Always test modules and download URLs**
- **Target hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS64/XS32)


---

**Last updated:** November 2025 (v2.2.8)

**Current Version:** 2.2.8 (synced across all module scripts)

### Bug Fixes
1. **Identify bug location**: Main script or specific module
2. **Fix in appropriate script**
3. **Update version**: Increment PATCH digit in gz302-main.sh
4. **Test fixes**: Syntax validation
5. **Update documentation**: If user-facing

### Package Management Commands by Distribution
- **Arch/Manjaro**: `pacman -S package` or `yay -S package` (AUR) - Use install_arch_packages_with_yay() helper
- **Ubuntu/Debian**: `apt install package` - May need multiverse/universe repos
- **Fedora**: `dnf install package` - May need RPM Fusion repos
- **OpenSUSE**: `zypper install package` - May need Packman repo

### Common Script Functions to Test
- **Distribution detection**: `detect_distribution()` function in gz302-main.sh
- **Hardware fixes**: `/etc/modprobe.d/` configuration creation (mt7925e, amdgpu, hid_asus)
- **Service management**: Systemd service and timer creation (gz302-tdp-*, gz302-refresh-*)
- **User environment**: Functions that run commands as non-root user (get_real_user)
- **Module downloads**: Download and execution of optional modules
- **Gaming software**: Repository setup varies by distro (in gz302-gaming.sh)
- **LLM/AI software**: Ollama installation, PyTorch with ROCm (in gz302-llm.sh)

## GZ302EA-XS99 Hardware Specifications

### Processor
- **Model**: AMD Ryzen AI MAX+ 395 (Strix Halo)
- **Cores**: 16 cores, 32 threads
- **Clock**: 3.0GHz base, up to 5.1GHz boost
- **Cache**: 80MB
- **NPU**: AMD XDNA™ up to 50TOPS

### Graphics
- **GPU**: AMD Radeon 8060S (integrated)
- **Architecture**: RDNA 3.5
- **Type**: 100% AMD system - NO discrete GPU, NO NVIDIA components

### Connectivity
- **Wi-Fi**: MediaTek MT7925 (kernel module: mt7925e)

### Key Configuration Details
- **Kernel parameter**: amd_pstate=guided (for Strix Halo)
- **GPU parameter**: amdgpu.ppfeaturemask=0xffffffff
- **Wi-Fi fix**: options mt7925e disable_aspm=1
- **No GPU switching needed**: Single integrated GPU only

## Troubleshooting Common Issues

### Script Syntax Errors
- **Use shellcheck**: Identifies most syntax and logic issues in bash
- **Check variable quoting**: Many warnings relate to unquoted variables
- **Validate function definitions**: Ensure proper bash function syntax
- **Test conditionals**: Verify if/then/else blocks are properly closed

### Version Updates
- **Check main script**: `grep "Version:" gz302-main.sh | head -1`
- **Update version**: Edit line 7 of gz302-main.sh
- **Update this file**: Change version number in header
- **Verify after commit**: Version should be consistent across documentation

### Module Architecture
- **Compare main vs modules**: Understand separation between core (main) and optional (modules)
- **Check all distributions**: Verify feature works on Arch, Debian, Fedora, OpenSUSE
- **Test module downloads**: Ensure modules download correctly from GitHub
- **Test optional components**: Gaming, LLM/AI, hypervisors, snapshots, secure boot

### Hardware-Specific Problems
- **Target hardware only**: Scripts designed specifically for GZ302EA-XS99 laptop
- **Distribution compatibility**: Verify package names across distributions
- **Kernel module loading**: Check if required modules are available
- **ASUS software dependencies**: Verify asusctl, power-profiles-daemon, switcheroo-control availability
- **No NVIDIA support needed**: System is 100% AMD (Radeon 8060S integrated GPU)

## Performance Expectations

### Script Execution Times (On Target Hardware)
- **Syntax validation**: <1 second per script - NEVER CANCEL, timeout 30 seconds
- **Full main script execution**: 5-15 minutes for core hardware fixes and TDP/refresh setup
- **Optional modules**: 5-40 minutes depending on selections (gaming, LLM, etc.)
- **Package installations**: Varies by distribution and network speed - NEVER CANCEL, timeout 30+ minutes per module

### Custom GZ302 Commands (Created by Scripts)
After script execution, these commands become available on target systems:
- **Power management**: `pwrcfg [profile|status|config|auto|list]` - Controls power settings (7 profiles: 10W-90W with SPL/sPPT/fPPT)
- **Refresh management**: `rrcfg [profile|status|config|auto|list|vrr|monitor]` - Controls display refresh rates (7 profiles: 30Hz-180Hz)
- **Gaming tools** (if gz302-gaming.sh installed): `gamemoded -s`, `mangohud your_game`
- **ASUS controls**: `systemctl status asusctl power-profiles-daemon switcheroo-control`

### Build and Test Commands
```bash
# Validate main script (takes <5 seconds total)
cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup
bash -n gz302-main.sh

# Run comprehensive linting (takes <5 seconds total)  
shellcheck gz302-main.sh

# Verify version
grep "Version:" gz302-main.sh | head -1

# Verify script sizes
wc -l gz302-*.sh

# Validate all modules
bash -n gz302-gaming.sh gz302-llm.sh gz302-hypervisor.sh gz302-snapshots.sh gz302-secureboot.sh
```

## Quick Reference Commands

### Immediate Validation (Run these before any changes)
```bash
# Complete validation suite (takes <5 seconds total)
cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup
bash -n gz302-main.sh              # Main script syntax - NEVER CANCEL, timeout 30s
shellcheck gz302-main.sh            # Linting check - NEVER CANCEL, timeout 30s  
wc -l gz302-*.sh                    # Verify sizes (~2200 main, ~200 gaming, ~180 llm, etc.)
```

### Version Management
```bash
# Check current version
grep "Version:" gz302-main.sh | head -1

# Update version (example for patch increment)
sed -i 's/Version: 0.1.0-pre-release/Version: 0.1.1/' gz302-main.sh
```

### Common File Locations Referenced by Scripts
- **Hardware configurations**: `/etc/modprobe.d/` (mt7925e.conf for Wi-Fi, amdgpu-gz302.conf for GPU, hid-asus.conf for HID)
- **Kernel parameters**: `/etc/default/grub` or `/etc/kernel/cmdline` (amd_pstate=guided, amdgpu.ppfeaturemask=0xffffffff)
- **Custom commands**: `/usr/local/bin/gz302-*` (gz302-tdp, gz302-refresh)
- **Systemd services**: `/etc/systemd/system/gz302-*` (Auto-TDP and refresh services)
- **Config directories**: `/etc/gz302-tdp/`, `/etc/gz302-refresh/`

### Development Safety Reminders
- **NEVER run setup scripts on development machines** - They modify system configurations permanently
- **ALWAYS test syntax before committing**: Use `bash -n` on all modified scripts
- **ALWAYS update version**: Increment in gz302-main.sh when making changes
- **ALWAYS validate modules**: If modules changed, test their syntax too
- **ALWAYS validate download URLs**: `curl -I URL` before adding new download commands
- **Target hardware specific**: Scripts are designed exclusively for ASUS ROG Flow Z13 (GZ302EA-XS99)
- **Modular architecture**: Main script handles core, optional modules handle extras

## Key Implementation Details

### AUR Package Installation (Arch)
Use the `install_arch_packages_with_yay()` helper function that:
1. Tries pacman first for official repos
2. Falls back to yay/paru for AUR packages
3. Auto-installs yay if needed
4. Runs as non-root user (proper context)

### Error Handling
- **Bash**: trap for ERR signal with cleanup_on_error function
- **Python**: signal handlers (SIGINT, SIGTERM) with cleanup in setup_error_handling method

### Distribution-Specific Package Installation
- **Gaming** (gz302-gaming.sh): Each distro has repository setup (multiverse/universe, RPM Fusion, Packman) before package installation
- **LLM/AI** (gz302-llm.sh): Ollama via curl script, PyTorch with ROCm 5.7, transformers/accelerate
- **ASUS packages** (gz302-main.sh): asusctl, power-profiles-daemon, switcheroo-control installed based on distro availability
- **All features**: Implemented for all 4 distribution families with equal priority

### Modular Download System
- **Main script**: Downloads optional modules from GitHub raw URLs on user request
- **Module execution**: Downloaded to /tmp, executed with distribution parameter, then cleaned up
- **Module base URL**: `https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/`
- **Modules available**: gz302-gaming.sh, gz302-llm.sh, gz302-hypervisor.sh, gz302-snapshots.sh, gz302-secureboot.sh