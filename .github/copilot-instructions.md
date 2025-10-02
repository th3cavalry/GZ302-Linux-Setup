# GZ302 Linux Setup Scripts

Hardware-specific Linux setup scripts for the ASUS ROG Flow Z13 (GZ302) laptop with AMD Ryzen AI 395+ processor. These scripts automate critical hardware fixes and optional software installation for multiple Linux distributions.

**Current Version: 4.3.1** - Complete feature parity between Python and Bash implementations with equal support for all distributions.

**ALWAYS reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Prerequisites and Requirements
- **CRITICAL**: Scripts require `sudo` privileges and an active internet connection
- **Required tools**: curl, bash/python3, standard Linux utilities (grep, awk, cut, etc.)
- **Target hardware**: ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+ processor
- **Supported distributions**: Arch Linux, Debian/Ubuntu, Fedora, OpenSUSE (and their derivatives)

### Current Repository Structure
```
.
├── README.md                      # User documentation
├── VERSION_INCREMENT_GUIDE.md     # Version management system
├── PYTHON_CONVERSION.md           # Feature parity documentation
├── .gitignore                     # Excludes build artifacts
├── gz302_setup.sh                 # Bash implementation (~3,260 lines)
├── gz302_setup.py                 # Python implementation (~2,900 lines)
├── gz302_setup_enhanced.py        # Alternative Python implementation
└── requirements.txt               # Python dependencies (stdlib only)
```

### Script Validation and Testing
- **Python syntax**: `python3 -m py_compile gz302_setup.py` - takes <1 second. NEVER CANCEL.
- **Bash syntax**: `bash -n gz302_setup.sh` - takes <1 second. NEVER CANCEL.
- **Linting validation**: `shellcheck gz302_setup.sh` - takes <1 second. NEVER CANCEL. Expect warnings but no critical errors.
- **Download test**: Both scripts available via curl from GitHub raw URLs

### Script Execution (DO NOT RUN ON DEVELOPMENT SYSTEMS)
**WARNING**: These scripts make system-level changes and should ONLY be run on target GZ302 hardware.

For testing purposes on development systems:
- **Syntax check only**: `bash -n gz302_setup.sh` or `python3 -m py_compile gz302_setup.py`
- **View script structure**: `head -50 script_name` to see headers and documentation
- **Check for specific functions**: `grep -n "function_name" gz302_setup.*`

### Expected Script Behavior
- **Automatic distribution detection**: Identifies distribution via `/etc/os-release`
- **Interactive prompts**: Scripts ask for optional software installation (gaming, AI, hypervisors, snapshots, secure boot)
- **Hardware fixes applied automatically**: Wi-Fi, touchpad, audio, camera, GPU, power management
- **TDP & Refresh management**: Installed automatically with 7 TDP profiles and 6 refresh rate profiles
- **User confirmation required**: Each optional component asks y/n before installation

## Version Management (Version 4.3.1)

### Version Increment System
- **Third digit (PATCH)**: Bug fixes (4.3.1 → 4.3.2)
- **Second digit (MINOR)**: New features (4.3.1 → 4.4.0)
- **First digit (MAJOR)**: Breaking changes (4.9.9 → 5.0.0)

### Version Sync Requirement
**CRITICAL**: Both `gz302_setup.sh` and `gz302_setup.py` MUST have the same version number.

**Version locations:**
- Bash: Line 7: `# Version: X.Y.Z`
- Python: Line 7: `Version: X.Y.Z`

**Verification:**
```bash
grep "Version:" gz302_setup.sh | head -1
grep "Version:" gz302_setup.py | head -1
```

See `VERSION_INCREMENT_GUIDE.md` for detailed instructions.

## Feature Parity Status (Version 4.3.1)

### Complete Parity (✅)
- Distribution detection for all 4 families
- Hardware fixes (Wi-Fi, touchpad, audio, camera, GPU, storage)
- TDP management (7 profiles, systemd services, auto-switching)
- Refresh rate management (6 profiles, VRR support)
- Error handling (signal handlers in both scripts)
- Gaming software (all 4 distributions with full repo setup)
- LLM/AI software (all 4 distributions with Ollama, PyTorch, ROCm)

### Placeholder Status (⚠️)
- Hypervisor installation (basic implementations, can be expanded)
- System snapshots (basic implementations, can be expanded)
- Secure boot (basic implementations, can be expanded)

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
1. **Syntax validation**: Run `bash -n gz302_setup.sh` AND `python3 -m py_compile gz302_setup.py` - NEVER CANCEL, timeout 30 seconds
2. **Shellcheck validation**: Run `shellcheck gz302_setup.sh` - NEVER CANCEL, timeout 30 seconds  
3. **Version sync check**: Verify both scripts have same version number
4. **Feature parity check**: Ensure changes are applied to BOTH scripts when applicable
5. **Test download path**: Verify GitHub raw URLs work correctly

### Testing Script Modifications
- **NEVER execute scripts on development systems** - they make permanent system changes
- **Use syntax checking**: `bash -n` for bash, `python3 -m py_compile` for Python
- **Use shellcheck**: Expect warnings (SC2155, SC2162, SC2086) but no critical errors
- **Test specific functions**: Extract and test individual functions in isolation when possible
- **Verify URL accessibility**: Test any new download URLs with `curl -I URL`
- **Check custom commands**: Validate any gz302-tdp or gz302-refresh command definitions
- **Validate systemd services**: Ensure service files have correct syntax and paths

## Common Development Tasks

### Script Modification Workflow
1. **Check current version**: Verify version in both scripts
2. **Make changes**: Apply to both scripts when adding features/fixing bugs
3. **Update version**: Increment appropriately (see VERSION_INCREMENT_GUIDE.md)
4. **Validate syntax**: Both bash and Python
5. **Run shellcheck**: For bash script
6. **Update documentation**: Modify README.md, PYTHON_CONVERSION.md if needed
7. **Verify parity**: Ensure both scripts still have identical functionality

### Adding New Features
1. **Implement in bash first** (if complex bash logic)
2. **Port to Python** with equivalent functionality
3. **Test both implementations**
4. **Update version** (increment MINOR digit)
5. **Update all documentation**
6. **Verify distribution parity** (ensure all distros get the feature)

### Bug Fixes
1. **Identify bug in both scripts** (if applicable)
2. **Fix in both scripts**
3. **Update version** (increment PATCH digit)
4. **Test fixes**
5. **Update documentation** if user-facing

### Package Management Commands by Distribution
- **Arch/Manjaro**: `pacman -S package` or `yay -S package` (AUR) - Use install_arch_packages_with_yay() helper
- **Ubuntu/Debian**: `apt install package` - May need multiverse/universe repos
- **Fedora**: `dnf install package` - May need RPM Fusion repos
- **OpenSUSE**: `zypper install package` - May need Packman repo

### Common Script Functions to Test
- **Distribution detection**: `detect_distribution()` function
- **Hardware fixes**: `/etc/modprobe.d/` configuration creation
- **Service management**: Systemd service and timer creation (gz302-tdp-*, gz302-refresh-*)
- **User environment**: Functions that run commands as non-root user (get_real_user)
- **Gaming software**: Repository setup varies by distro
- **LLM/AI software**: Ollama installation, PyTorch with ROCm

## Troubleshooting Common Issues

### Script Syntax Errors
- **Use shellcheck**: Identifies most syntax and logic issues in bash
- **Use py_compile**: Validates Python syntax
- **Check variable quoting**: Many warnings relate to unquoted variables
- **Validate function definitions**: Ensure proper bash/Python function syntax
- **Test conditionals**: Verify if/then/else blocks are properly closed

### Version Mismatch
- **Check both scripts**: `grep "Version:" gz302_setup.sh gz302_setup.py`
- **Update both**: Use sed or manual editing to sync versions
- **Verify after commit**: Both must always match

### Feature Parity Issues
- **Compare implementations**: Use diff or manual inspection
- **Check all distributions**: Verify feature works on Arch, Debian, Fedora, OpenSUSE
- **Test optional components**: Gaming, LLM/AI, hypervisors

### Hardware-Specific Problems
- **Target hardware only**: Scripts designed specifically for GZ302 laptop
- **Distribution compatibility**: Verify package names across distributions
- **Kernel module loading**: Check if required modules are available
- **ASUS software dependencies**: Verify asusctl and supergfxd availability

## Performance Expectations

### Script Execution Times (On Target Hardware)
- **Syntax validation**: <1 second per script - NEVER CANCEL, timeout 30 seconds
- **Full script execution**: 10-45 minutes depending on optional components - NEVER CANCEL, timeout 60+ minutes
- **Package installations**: Varies by distribution and network speed - NEVER CANCEL, timeout 30+ minutes per package set

### Custom GZ302 Commands (Created by Scripts)
After script execution, these commands become available on target systems:
- **Power management**: `gz302-tdp [profile|status|config|auto|list]` - Controls TDP settings (7 profiles)
- **Refresh management**: `gz302-refresh [profile|status|config|auto|list|vrr|monitor]` - Controls display refresh rates (6 profiles)
- **Gaming tools**: `gamemoded -s` - Check GameMode status
- **Performance monitoring**: `mangohud your_game` - Display performance overlay
- **ASUS controls**: `systemctl status supergfxd asusctl` - Check ASUS service status

### Build and Test Commands
```bash
# Validate all scripts (takes <5 seconds total)
cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup
bash -n gz302_setup.sh
python3 -m py_compile gz302_setup.py

# Run comprehensive linting (takes <5 seconds total)  
shellcheck gz302_setup.sh

# Verify version sync
grep "Version:" gz302_setup.sh gz302_setup.py

# Verify script sizes
wc -l gz302_setup.sh gz302_setup.py
```

## Quick Reference Commands

### Immediate Validation (Run these before any changes)
```bash
# Complete validation suite (takes <5 seconds total)
cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup
bash -n gz302_setup.sh              # Bash syntax - NEVER CANCEL, timeout 30s
python3 -m py_compile gz302_setup.py # Python syntax - NEVER CANCEL, timeout 30s
shellcheck gz302_setup.sh            # Linting check - NEVER CANCEL, timeout 30s  
wc -l gz302_setup.sh gz302_setup.py  # Verify sizes (~3260 bash, ~2900 python)
```

### Version Management
```bash
# Check current versions (must match)
grep "Version:" gz302_setup.sh | head -1
grep "Version:" gz302_setup.py | head -1

# Update version (example for patch increment)
sed -i 's/Version: 4.3.1/Version: 4.3.2/' gz302_setup.sh gz302_setup.py
```

### Common File Locations Referenced by Scripts
- **Hardware configurations**: `/etc/modprobe.d/` (Wi-Fi, audio, GPU, camera fixes)
- **Custom commands**: `/usr/local/bin/gz302-*` (TDP and refresh tools)
- **Systemd services**: `/etc/systemd/system/gz302-*` (Auto-TDP and refresh services)
- **Config directories**: `/etc/gz302-tdp/`, `/etc/gz302-refresh/`

### Development Safety Reminders
- **NEVER run setup scripts on development machines** - They modify system configurations permanently
- **ALWAYS test syntax before committing**: Both bash and Python
- **ALWAYS sync versions**: Both scripts must have identical version numbers
- **ALWAYS maintain feature parity**: Changes should be applied to both scripts when applicable
- **ALWAYS validate download URLs**: `curl -I URL` before adding new download commands
- **Target hardware specific**: Scripts are designed exclusively for ASUS ROG Flow Z13 (GZ302)

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
- **Gaming**: Each distro has repository setup (multiverse/universe, RPM Fusion, Packman) before package installation
- **LLM/AI**: Ollama via curl script, PyTorch with ROCm 5.7, transformers/accelerate
- **All features**: Implemented for all 4 distribution families with equal priority