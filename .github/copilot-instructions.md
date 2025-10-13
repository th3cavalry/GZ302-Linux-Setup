# GZ302 Linux Setup Scripts

Hardware-specific Linux setup scripts for the ASUS ROG Flow Z13 (GZ302EA-XS99) laptop with AMD Ryzen AI MAX+ 395 processor. These scripts automate critical hardware fixes and optional software installation for multiple Linux distributions.

**Current Version: 0.1.1-pre-release** - Modular architecture with bash-only implementation.

**ALWAYS reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Prerequisites and Requirements
- **CRITICAL**: Scripts require `sudo` privileges and an active internet connection
- **Required tools**: curl, bash, standard Linux utilities (grep, awk, cut, etc.)
- **Target hardware**: ASUS ROG Flow Z13 (GZ302EA-XS99) with AMD Ryzen AI MAX+ 395 processor and AMD Radeon 8060S integrated GPU
- **Supported distributions**: Arch Linux, Debian/Ubuntu, Fedora, OpenSUSE (and their derivatives)

### Current Repository Structure
```
.
├── README.md                      # User documentation
├── .gitignore                     # Excludes build artifacts
├── gz302-main.sh                  # Main script (~2,360 lines) - hardware fixes, TDP, refresh rate
├── gz302-gaming.sh                # Gaming module (~230 lines) - optional download
├── gz302-llm.sh                   # AI/LLM module (~180 lines) - optional download
├── gz302-hypervisor.sh            # Hypervisor module (~130 lines) - optional download
├── gz302-snapshots.sh             # Snapshots module (~105 lines) - optional download
├── gz302-secureboot.sh            # Secure boot module (~95 lines) - optional download
└── Old/                           # Archived files from previous versions
    ├── gz302_setup.sh             # Old monolithic bash script
    ├── gz302_setup.py             # Old Python implementation
    ├── requirements.txt           # Old Python dependencies
    ├── PYTHON_CONVERSION.md       # Old feature parity docs
    └── VERSION_INCREMENT_GUIDE.md # Old version management guide
```

### Script Validation and Testing
- **Bash syntax**: `bash -n gz302-main.sh` - takes <1 second. NEVER CANCEL.
- **Linting validation**: `shellcheck gz302-main.sh` - takes <1 second. NEVER CANCEL. Expect warnings but no critical errors.
- **Module syntax**: `bash -n gz302-gaming.sh gz302-llm.sh gz302-hypervisor.sh gz302-snapshots.sh gz302-secureboot.sh` - validates all modules
- **Download test**: All scripts available via curl from GitHub raw URLs

### Script Execution (DO NOT RUN ON DEVELOPMENT SYSTEMS)
**WARNING**: These scripts make system-level changes and should ONLY be run on target GZ302EA-XS99 hardware.

For testing purposes on development systems:
- **Syntax check only**: `bash -n gz302-main.sh` or `bash -n gz302-*.sh`
- **View script structure**: `head -50 script_name` to see headers and documentation
- **Check for specific functions**: `grep -n "function_name" gz302-*.sh`

### Expected Script Behavior
- **Automatic distribution detection**: Identifies distribution via `/etc/os-release`
- **Hardware fixes applied automatically**: Wi-Fi (MT7925e), GPU (AMD Radeon 8060S), HID, kernel parameters
- **ASUS package installation**: asusctl, power-profiles-daemon, switcheroo-control
- **TDP & Refresh management**: Installed automatically with 7 TDP profiles and 6 refresh rate profiles
- **Optional module prompts**: User selects which modules to download and install (gaming, LLM, hypervisor, snapshots, secure boot)
- **Modular downloads**: Optional modules downloaded from GitHub on demand

## Version Management (Version 0.1.0-pre-release)

### Version Increment System
- **Third digit (PATCH)**: Bug fixes (0.1.0 → 0.1.1)
- **Second digit (MINOR)**: New features (0.1.0 → 0.2.0)
- **First digit (MAJOR)**: Breaking changes (0.9.0 → 1.0.0)

### Version Location
**Version location:**
- Main script: Line 7: `# Version: X.Y.Z`

**Verification:**
```bash
grep "Version:" gz302-main.sh | head -1
```

### Version Update Process
When incrementing version:
1. Update version number in gz302-main.sh (line 7)
2. Commit with message format: `Version X.Y.Z - Brief description`
3. Update this file's header with new version

## Current Implementation Status (Version 0.1.0-pre-release)

### Hardware Support (✅ Complete)
- GZ302EA-XS99 specific hardware fixes
- AMD Ryzen AI MAX+ 395 (Strix Halo) processor support
- AMD Radeon 8060S integrated GPU configuration
- MediaTek MT7925 Wi-Fi fixes (mt7925e module)
- Kernel parameters: amd_pstate=guided, amdgpu.ppfeaturemask=0xffffffff
- ASUS HID configuration

### Core Features (✅ Complete)
- Distribution detection for all 4 families (Arch, Debian, Fedora, OpenSUSE)
- TDP management (7 profiles, systemd services, auto-switching)
- Refresh rate management (6 profiles, VRR support)
- ASUS package installation (asusctl, power-profiles-daemon, switcheroo-control)
- Error handling and cleanup

### Optional Modules (✅ Available)
- **gz302-gaming.sh**: Steam, Lutris, MangoHUD, GameMode, Wine (all 4 distributions)
- **gz302-llm.sh**: Ollama, ROCm, PyTorch, Transformers (all 4 distributions)
- **gz302-hypervisor.sh**: KVM/QEMU, VirtualBox support
- **gz302-snapshots.sh**: Snapper, LVM snapshot management
- **gz302-secureboot.sh**: Boot integrity tools

## Distribution Support (Equal Priority)

All 4 distributions receive identical treatment:

| Distribution | Gaming | LLM/AI | Hardware | TDP | Refresh |
|--------------|--------|--------|----------|-----|---------|
| Arch/EndeavourOS/Manjaro | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ubuntu/Pop!_OS/Mint | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fedora/Nobara | ✅ | ✅ | ✅ | ✅ | ✅ |
| OpenSUSE TW/Leap | ✅ | ✅ | ✅ | ✅ | ✅ |

## Validation Scenarios

### After Making Script Changes
1. **Syntax validation**: Run `bash -n gz302-main.sh` - NEVER CANCEL, timeout 30 seconds
2. **Shellcheck validation**: Run `shellcheck gz302-main.sh` - NEVER CANCEL, timeout 30 seconds  
3. **Version check**: Verify version in gz302-main.sh line 7
4. **Module validation**: If modules changed, run `bash -n gz302-*.sh` for all affected modules
5. **Test download path**: Verify GitHub raw URLs work correctly

### Testing Script Modifications
- **NEVER execute scripts on development systems** - they make permanent system changes
- **Use syntax checking**: `bash -n` for all bash scripts
- **Use shellcheck**: Expect warnings (SC2155, SC2162, SC2086) but no critical errors
- **Test specific functions**: Extract and test individual functions in isolation when possible
- **Verify URL accessibility**: Test any new download URLs with `curl -I URL`
- **Check custom commands**: Validate any gz302-tdp or gz302-refresh command definitions
- **Validate systemd services**: Ensure service files have correct syntax and paths

## Common Development Tasks

### Script Modification Workflow
1. **Check current version**: Verify version in gz302-main.sh line 7
2. **Make changes**: Apply to main script or appropriate module
3. **Update version**: Increment appropriately (PATCH for fixes, MINOR for features, MAJOR for breaking changes)
4. **Validate syntax**: `bash -n` on changed scripts
5. **Run shellcheck**: For all modified bash scripts
6. **Update documentation**: Modify README.md if user-facing changes
7. **Test module downloads**: If module changed, verify download URL works

### Adding New Features
1. **Determine scope**: Main script (hardware/TDP/refresh) or new/existing module (optional software)
2. **Implement in appropriate script**: gz302-main.sh or gz302-[module].sh
3. **Test implementation**: Syntax check and shellcheck
4. **Update version**: Increment MINOR digit in gz302-main.sh
5. **Update documentation**: README.md and this file if needed
6. **Verify distribution support**: Ensure all 4 distros are supported

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
- **Power management**: `gz302-tdp [profile|status|config|auto|list]` - Controls TDP settings (7 profiles: 10W-65W)
- **Refresh management**: `gz302-refresh [profile|status|config|auto|list|vrr|monitor]` - Controls display refresh rates (6 profiles: 30Hz-180Hz)
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