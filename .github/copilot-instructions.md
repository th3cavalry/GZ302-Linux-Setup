# GZ302 Linux Setup Scripts

Hardware-specific Linux setup scripts for the ASUS ROG Flow Z13 (GZ302) laptop with AMD Ryzen AI 395+ processor. These scripts automate critical hardware fixes and optional software installation for multiple Linux distributions.

**ALWAYS reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Prerequisites and Requirements
- **CRITICAL**: Scripts require `sudo` privileges and an active internet connection
- **Required tools**: curl, bash, standard Linux utilities (grep, awk, cut, etc.)
- **Target hardware**: ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+ processor
- **Supported distributions**: Arch Linux, Ubuntu, Fedora, OpenSUSE (and their derivatives)

### Script Validation and Testing
- **Syntax validation**: `bash -n *.sh` - takes <1 second. NEVER CANCEL.
- **Linting validation**: `shellcheck *.sh` - takes <1 second. NEVER CANCEL. Expect warnings but no critical errors.
- **Download test**: `curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_universal_setup.sh -o test_script.sh` - takes 1-2 seconds. NEVER CANCEL.
- **Script size verification**: `wc -l *.sh` should show approximately 6600 total lines across 5 scripts

### Script Execution (DO NOT RUN ON DEVELOPMENT SYSTEMS)
**WARNING**: These scripts make system-level changes and should ONLY be run on target GZ302 hardware.

For testing purposes on development systems:
- **Syntax check only**: `bash -n script_name.sh`
- **View script structure**: `head -50 script_name.sh` to see headers and documentation
- **Check for specific functions**: `grep -n "function_name" *.sh`

### Expected Script Behavior
- **Universal script detection**: Automatically identifies distribution via `/etc/os-release`
- **Interactive prompts**: Scripts ask for optional software installation (gaming, AI, hypervisors, snapshots, secure boot)
- **Hardware fixes applied automatically**: Wi-Fi, touchpad, audio, camera, GPU, power management
- **User confirmation required**: Each optional component asks y/n before installation

## Validation Scenarios

### After Making Script Changes
1. **Syntax validation**: Run `bash -n modified_script.sh` - NEVER CANCEL, timeout 30 seconds
2. **Shellcheck validation**: Run `shellcheck modified_script.sh` - NEVER CANCEL, timeout 30 seconds  
3. **Check script dependencies**: Verify any new commands are available in target distributions
4. **Validate script logic**: Ensure distribution detection logic remains intact
5. **Test download path**: Verify GitHub raw URLs work correctly

### Testing Script Modifications
- **NEVER execute scripts on development systems** - they make permanent system changes
- **Use syntax checking**: `bash -n script.sh` to validate bash syntax
- **Use shellcheck**: Expect warnings (SC2155, SC2162, SC2086) but no critical errors
- **Test specific functions**: Extract and test individual functions in isolation when possible
- **Verify URL accessibility**: Test any new download URLs with `curl -I URL`
- **Check custom commands**: Validate any gz302-tdp or gz302-snapshot command definitions
- **Validate systemd services**: Ensure service files have correct syntax and paths

## Repository Structure

### Key Files
```
.
├── README.md                    # User documentation and usage instructions
├── .gitignore                   # Excludes temporary and build files
├── gz302_universal_setup.sh     # Auto-detecting universal setup script (1515 lines)
├── arch_setup.sh               # Arch Linux specific setup (1699 lines)
├── ubuntu_setup.sh             # Ubuntu/Debian specific setup (1486 lines)
├── fedora_setup.sh             # Fedora/RPM specific setup (1343 lines)
└── opensuse_setup.sh           # OpenSUSE specific setup (557 lines)
```

### Script Architecture
- **Universal script**: Detects distribution and calls appropriate base script logic
- **Distribution-specific scripts**: Handle package manager differences (pacman, apt, dnf, zypper)
- **Common functionality**: Hardware fixes, ASUS software installation, gaming tools, AI frameworks
- **Modular design**: Optional components can be enabled/disabled via user prompts

## Common Development Tasks

### Script Modification Workflow
1. **Backup current version**: `cp script.sh script.sh.bak`
2. **Make minimal changes**: Focus on specific functionality
3. **Validate syntax**: `bash -n script.sh`
4. **Run shellcheck**: `shellcheck script.sh`
5. **Test specific sections**: Extract functions for isolated testing
6. **Update documentation**: Modify README.md if user-facing changes

### Adding New Hardware Support
- **Research hardware requirements**: Check vendor documentation and Linux forums
- **Add detection logic**: Update distribution detection if needed
- **Create configuration files**: Add to appropriate `/etc/modprobe.d/` or similar
- **Test on target hardware**: Scripts must be validated on actual GZ302 hardware
- **Update documentation**: Add to README.md hardware support section

### Package Management Commands by Distribution
- **Arch/Manjaro**: `pacman -S package` or `yay -S package` (AUR)
- **Ubuntu/Debian**: `apt install package` or `snap install package`
- **Fedora**: `dnf install package` or `flatpak install package`
- **OpenSUSE**: `zypper install package`

### Common Script Functions to Test
- **Distribution detection**: `detect_distribution()` function in universal script
- **Hardware fixes**: Look for `/etc/modprobe.d/` configuration creation
- **Service management**: Systemd service and timer creation
- **User environment**: Functions that run commands as non-root user
- **Optional component installation**: Gaming, AI, hypervisor installation functions

## Troubleshooting Common Issues

### Script Syntax Errors
- **Use shellcheck**: Identifies most syntax and logic issues
- **Check variable quoting**: Many warnings relate to unquoted variables
- **Validate function definitions**: Ensure proper bash function syntax
- **Test conditionals**: Verify `if/then/else/fi` blocks are properly closed

### Download and Connectivity Issues
- **Test URLs**: `curl -I URL` to verify accessibility
- **Check GitHub raw URLs**: Must use `raw.githubusercontent.com` format
- **Verify file sizes**: Compare downloaded file size with repository file
- **Test with different networks**: Some corporate firewalls block GitHub raw content

### Hardware-Specific Problems
- **Target hardware only**: Scripts designed specifically for GZ302 laptop
- **Distribution compatibility**: Verify package names across distributions
- **Kernel module loading**: Check if required modules are available
- **ASUS software dependencies**: Verify asusctl and supergfxd availability

### Common User Issues (From README.md)
When users report problems, guide them to these troubleshooting steps:

#### Wi-Fi Issues
- **First step**: Restart the computer (fixes most issues)
- **Check NetworkManager**: `systemctl status NetworkManager`
- **Manual reset**: User can run `sudo modprobe -r hid_asus && sudo modprobe hid_asus`

#### Touchpad Problems
- **First step**: Restart the computer
- **Manual fix**: `sudo modprobe -r hid_asus && sudo modprobe hid_asus`

#### Gaming Performance Issues
- **Check kernel**: Verify correct kernel selected at boot
- **GameMode status**: `gamemoded -s` to check if GameMode is working
- **Performance overlay**: `mangohud your_game` to monitor performance

#### ASUS Controls Not Working
- **Service status**: `systemctl status supergfxd asusctl`
- **Restart services**: `sudo systemctl restart supergfxd`
- **Check logs**: `journalctl -b` for error messages

## Performance Expectations

### Script Execution Times (On Target Hardware)
- **Syntax validation**: <1 second per script - NEVER CANCEL, timeout 30 seconds
- **Shellcheck validation**: <1 second for all scripts - NEVER CANCEL, timeout 30 seconds
- **Download operations**: 1-2 seconds per script - NEVER CANCEL, timeout 60 seconds
- **Full script execution**: 10-45 minutes depending on optional components - NEVER CANCEL, timeout 60+ minutes
- **Package installations**: Varies by distribution and network speed - NEVER CANCEL, timeout 30+ minutes per package set

### Custom GZ302 Commands (Created by Scripts)
After script execution, these commands become available on target systems:
- **Power management**: `gz302-tdp gaming|balanced|efficient|status` - Controls TDP settings
- **System snapshots**: `gz302-snapshot create|list|cleanup|restore` - Manages filesystem snapshots
- **Gaming tools**: `gamemoded -s` - Check GameMode status
- **Performance monitoring**: `mangohud your_game` - Display performance overlay
- **ASUS controls**: `systemctl status supergfxd asusctl` - Check ASUS service status

### Build and Test Commands
```bash
# Validate all scripts (takes <5 seconds total)
bash -n *.sh

# Run comprehensive linting (takes <5 seconds total)  
shellcheck *.sh

# Test download functionality (takes 1-2 seconds)
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_universal_setup.sh -o test.sh

# Verify script sizes and structure
wc -l *.sh
ls -la *.sh
```

## CI/CD Considerations

### No Traditional Build Pipeline
- **Scripts are executed directly**: No compilation or build steps required
- **Validation via linting**: Primary quality check is shellcheck and syntax validation
- **Target system testing**: Real validation requires execution on GZ302 hardware
- **Documentation updates**: README.md should be updated for user-facing changes

### Quality Assurance
- **Syntax validation required**: All scripts must pass `bash -n` validation
- **Shellcheck compliance**: Address critical errors, warnings are acceptable
- **Distribution testing**: Verify package names and commands across all supported distributions
- **Hardware compatibility**: Changes must maintain GZ302-specific hardware support

Always run the validation commands above before committing changes to ensure script integrity and prevent syntax errors that could break user systems.

## Quick Reference Commands

### Immediate Validation (Run these before any changes)
```bash
# Complete validation suite (takes <5 seconds total)
cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup
bash -n *.sh                    # Syntax check - NEVER CANCEL, timeout 30s
shellcheck *.sh                 # Linting check - NEVER CANCEL, timeout 30s  
wc -l *.sh                      # Verify sizes (should total ~6600 lines)
ls -la *.sh                     # Confirm all 5 scripts present
```

### Repository Status Check
```bash
# Repository overview
ls -la                          # Should show 5 .sh files, README.md, .gitignore
cat README.md | head -20        # Check current documentation version  
find . -name "*.sh" | wc -l     # Should return 5
```

### Common File Locations Referenced by Scripts
- **Hardware configurations**: `/etc/modprobe.d/` (Wi-Fi, audio, GPU, camera fixes)
- **Custom commands**: `/usr/local/bin/gz302-*` (TDP and snapshot tools)
- **Systemd services**: `/etc/systemd/system/gz302-*` (Auto-TDP and snapshot timers)
- **User configs**: `/home/$USER/.config/gamemode/gamemode.ini` (Gaming optimization)

### Development Safety Reminders
- **NEVER run setup scripts on development machines** - They modify system configurations permanently
- **ALWAYS test syntax before committing**: `bash -n script.sh`
- **ALWAYS run shellcheck**: Expect warnings (SC2155, SC2162, SC2086) but no critical errors
- **ALWAYS validate download URLs**: `curl -I URL` before adding new download commands
- **Target hardware specific**: Scripts are designed exclusively for ASUS ROG Flow Z13 (GZ302)