# Changelog for Version 1.3.0

## Release Date
October 14, 2025

## Summary
Major modernization release that improves safety, flexibility, and user control. Makes the linux-g14 kernel optional, adds power management choice, implements idempotent operations, and removes legacy hardware options.

## Breaking Changes
- **G14 kernel is now optional**: On Arch Linux with kernel >= 6.6, the script no longer automatically installs linux-g14 kernel. Use `--kernel g14` to force installation if desired.
- **Power management choice required**: Script now defaults to TLP but can be switched to power-profiles-daemon via `--power ppd` flag. The two cannot run simultaneously.

## New Features

### CLI Options
- `--help` - Comprehensive help text with examples
- `--kernel MODE` - Control kernel installation (auto/g14/native)
- `--no-kernel` - Shortcut to skip g14 kernel installation
- `--power BACKEND` - Choose between TLP or power-profiles-daemon
- `--no-reboot` - Don't reboot automatically, prompt user instead
- `--dry-run` - Preview all actions without making changes
- `--log FILE` - Custom log file location (default: /var/log/gz302-setup.log)

### Improved Safety
- Added `set -euo pipefail` for safer script execution
- Idempotent kernel parameter management (prevents duplicates)
- SUDO_USER validation for AUR builds with graceful fallback
- Optional reboot with user confirmation instead of forced 10-second countdown
- Comprehensive logging to file

### Power Management
- Configurable choice between TLP and power-profiles-daemon
- Automatic conflict resolution (disables one when enabling the other)
- Clear documentation of the conflict in README

### Kernel Management
- Smart auto-detection: only installs g14 kernel on Arch with kernel < 6.6
- Modern kernels (>= 6.6) recognized as adequate for GZ302EA hardware
- User can force g14 installation or skip it entirely
- Better fallback handling for failed AUR builds

## Removed/Deprecated

### Legacy Hardware Options
- Removed `amdgpu.si_support=1` kernel parameter (not needed for Strix Halo)
- Removed `amdgpu.cik_support=1` kernel parameter (not needed for Strix Halo)
- Removed legacy AMDGPU modprobe options (si_support, cik_support)
- Kept only relevant modern options: `dpm=1` and `audio=1`

### Simplified Kernel Parameters
- New parameter set: `iommu=pt amd_pstate=active`
- Removed legacy GPU compatibility parameters
- More focused, minimal configuration

## Improvements

### Script Structure
- All installation functions now respect dry-run mode
- Better error handling and user feedback
- Dynamic summary based on actual actions taken
- Consistent function naming and organization

### Documentation
- README updated to version 1.3.0
- Renamed "G14 Kernel Installation" to "Kernel (Optional linux-g14 Variant on Arch)"
- Added comprehensive usage examples
- Documented TLP vs power-profiles-daemon conflict
- Clarified GZ302EA vs G14 distinction
- Updated post-installation steps
- Added power management switching instructions

### Testing
- Added TESTING.md with comprehensive test procedures
- Added automated integration test script (test-integration.sh)
- Shellcheck compliance (no critical errors)
- Verified idempotent operations

## Bug Fixes
- Fixed version mismatch between header (1.0.0) and VERSION variable (1.2.0)
- Fixed potential duplicate kernel parameters on multiple runs
- Fixed simultaneous TLP and power-profiles-daemon enablement
- Fixed missing quotes in date command substitution
- Fixed read command without -r flag

## Technical Details

### Idempotent Operations
The script now includes a helper function `add_kernel_params_idempotent()` that:
- Parses existing kernel parameters
- Only adds parameters that don't already exist
- Prevents duplicates when script is run multiple times
- Works with both GRUB and systemd-boot

### Power Management Conflict Resolution
When installing TLP:
- Stops, disables, and masks power-profiles-daemon
- Installs and enables TLP service
- Creates GZ302-specific TLP configuration

When using power-profiles-daemon:
- Stops, disables, and masks TLP (if installed)
- Unmasks and enables power-profiles-daemon
- Skips TLP installation entirely

### Logging System
- Redirects stdout and stderr to log file using `exec > >(tee -a "$LOG_FILE") 2>&1`
- Maintains console output while logging to file
- Default location: /var/log/gz302-setup.log
- Customizable via `--log` flag
- Disabled in dry-run mode

## Migration Guide

### For Users with Existing Installations
If you previously ran version 1.2.0 or earlier:

1. The script is now idempotent and safe to re-run
2. Choose your power management backend:
   - Keep TLP (default): `sudo ./gz302-setup.sh --power tlp`
   - Switch to PPD: `sudo ./gz302-setup.sh --power ppd`
3. Legacy kernel parameters will remain but won't cause issues
4. To clean up legacy parameters manually:
   - Edit `/etc/default/grub` and remove `amdgpu.si_support=1 amdgpu.cik_support=1`
   - Run `sudo update-grub` or equivalent
   - Edit `/etc/modprobe.d/amdgpu.conf` and remove si_support/cik_support lines

### For New Users
Simply run with your preferred options:
```bash
# Recommended default
sudo ./gz302-setup.sh

# Custom configuration
sudo ./gz302-setup.sh --kernel native --power ppd --no-reboot
```

## Testing Results
All automated tests passing:
- ✅ Syntax validation (bash -n)
- ✅ Help text display
- ✅ Version consistency across files
- ✅ Legacy options removed
- ✅ All CLI flags functional
- ✅ README updated
- ✅ Idempotent function verified
- ✅ Shellcheck compliance
- ✅ Power conflict resolution

## Contributors
- Script modernization and improvements
- Documentation updates
- Testing framework

## References
- Issue: Modernize and harden the gz302-setup.sh script
- PR: [Branch: copilot/modernize-gz302-setup-script]
- Based on community feedback and modern kernel capabilities
- Aligned with Asus Linux project best practices
