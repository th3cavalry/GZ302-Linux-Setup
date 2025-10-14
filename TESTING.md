# Testing Documentation for GZ302 Setup Script v1.3.0

This document describes the testing performed on the modernized setup script.

## Automated Tests Performed

### 1. Syntax Validation
```bash
bash -n gz302-setup.sh
# Result: PASSED - No syntax errors
```

### 2. Help Text Display
```bash
./gz302-setup.sh --help
# Result: PASSED - Displays comprehensive help with all options
```

### 3. Argument Parsing Tests
Tested various argument combinations:
- `--kernel g14 --power ppd` → Correctly sets KERNEL_MODE=g14, POWER_BACKEND=ppd
- `--no-kernel --dry-run --no-reboot` → Correctly sets KERNEL_MODE=native, DRY_RUN=true, NO_REBOOT=true
- `--log /tmp/test.log` → Correctly sets custom log file path
- Invalid arguments → Correctly rejects with error message

### 4. Idempotent Kernel Parameter Function
The `add_kernel_params_idempotent()` function was tested with:
- Empty existing params → Adds all new params
- Some params exist → Only adds missing params
- All params exist → No duplicates added
- Run twice → Second run makes no changes (idempotent)

**Result:** PASSED - Function correctly prevents duplicate kernel parameters

### 5. Shellcheck Linting
```bash
shellcheck -e SC2312 -e SC2086 gz302-setup.sh
```
**Result:** Minor warnings only (no critical errors)
- Fixed SC2046: Quoted date command substitution
- Fixed SC2162: Added -r flag to read command
- Remaining warnings are informational or style-related

## Manual Testing Required

The following tests require actual execution on target systems:

### Dry Run Mode
```bash
sudo ./gz302-setup.sh --dry-run
```
**Expected:** Shows all planned actions without making any changes

### Kernel Installation Logic
- On Arch with kernel < 6.6 and `--kernel auto`: Should install g14 kernel
- On Arch with kernel >= 6.6 and `--kernel auto`: Should use native kernel
- With `--kernel g14`: Should force g14 installation
- With `--no-kernel`: Should skip g14 installation

### Power Management Conflict Resolution
- With `--power tlp`: Should install TLP and disable/mask power-profiles-daemon
- With `--power ppd`: Should enable power-profiles-daemon and disable/mask TLP

### Idempotency
Running the script twice with the same options should:
- Not duplicate kernel parameters in GRUB/systemd-boot
- Not duplicate g14 repository in pacman.conf
- Not create duplicate modprobe configs
- Complete successfully on second run

### Reboot Behavior
- Default: Should prompt "Reboot now? [Y/n]"
- With `--no-reboot`: Should not reboot, display manual reboot message

### SUDO_USER Validation
- Run with `sudo` from user account: Should work normally for AUR builds
- Run directly as root: Should detect missing SUDO_USER and skip AUR packages

## Test Matrix

| Test Case | Expected Result | Status |
|-----------|----------------|---------|
| Syntax check | No errors | ✅ PASSED |
| Help display | Shows all options | ✅ PASSED |
| Argument parsing | Correctly sets all flags | ✅ PASSED |
| Idempotent params | No duplicates | ✅ PASSED |
| Shellcheck | No critical errors | ✅ PASSED |
| Dry run mode | No system changes | ⏳ Manual test required |
| Kernel auto-detect | Correct kernel choice | ⏳ Manual test required |
| Power backend choice | Correct service enabled | ⏳ Manual test required |
| Run twice (idempotent) | No errors, no duplicates | ⏳ Manual test required |
| Reboot options | Correct behavior | ⏳ Manual test required |

## Known Limitations

1. Full integration testing requires:
   - Root/sudo access
   - Supported Linux distribution (Arch, Debian/Ubuntu, Fedora, openSUSE)
   - Network connection for package downloads
   - Actual GZ302EA hardware for complete validation

2. The script cannot be fully tested in CI/CD without:
   - Mock package managers
   - Simulated system files (/etc/default/grub, /etc/pacman.conf, etc.)
   - Root permissions in container

## Testing Recommendations

For maintainers testing on actual systems:

1. **Always start with dry-run:**
   ```bash
   sudo ./gz302-setup.sh --dry-run
   ```

2. **Test on a VM or backup system first**

3. **Verify idempotency:**
   ```bash
   sudo ./gz302-setup.sh --no-reboot
   # Check system state
   sudo ./gz302-setup.sh --no-reboot
   # Verify no duplicates in configs
   ```

4. **Test different option combinations:**
   ```bash
   # Native kernel + TLP
   sudo ./gz302-setup.sh --no-kernel --power tlp
   
   # G14 kernel + power-profiles-daemon
   sudo ./gz302-setup.sh --kernel g14 --power ppd
   ```

5. **Check log files:**
   ```bash
   sudo tail -f /var/log/gz302-setup.log
   ```

## Regression Testing

After any script modifications, re-run:
1. Syntax validation: `bash -n gz302-setup.sh`
2. Help text: `./gz302-setup.sh --help`
3. Dry run: `sudo ./gz302-setup.sh --dry-run`
4. Shellcheck: `shellcheck gz302-setup.sh`
