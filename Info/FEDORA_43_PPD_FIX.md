# Fedora 43 Power Profile Daemon Fix

## Problem

Fedora 43 switched from `power-profiles-daemon` to `tuned-ppd` as the default power profile management daemon. When the GZ302 installation script tried to install `power-profiles-daemon`, it caused a package conflict:

```
Problem: problem with installed package
  - installed package tuned-ppd-2.26.0-2.fc43.noarch conflicts with ppd-service provided by power-profiles-daemon-0.30-1.fc43.x86_64 from fedora
  - package power-profiles-daemon-0.30-1.fc43.x86_64 from fedora conflicts with ppd-service provided by tuned-ppd-2.26.0-2.fc43.noarch from fedora
  - conflicting requests
```

## Solution

The fix implements intelligent detection and handling of both power profile daemon implementations:

### 1. Detection Logic (install-command-center.sh, line ~154)

```bash
# Fedora 43+ uses tuned-ppd instead of power-profiles-daemon
# tuned-ppd provides the same ppd-service and powerprofilesctl interface
if rpm -q tuned-ppd >/dev/null 2>&1; then
    echo "tuned-ppd already installed (Fedora 43+ default)"
    echo "tuned-ppd provides compatible power profile management"
else
    # Fedora < 43 or if tuned-ppd was removed
    if dnf install -y power-profiles-daemon 2>/dev/null; then
        echo "power-profiles-daemon installed"
    else
        # Try tuned-ppd as fallback
        echo "Installing tuned-ppd (compatible replacement)..."
        dnf install -y tuned-ppd || echo "Warning: Failed to install power profile daemon"
    fi
fi
```

### 2. Service Enablement (install-command-center.sh, line ~197)

```bash
# Enable PPD service (power-profiles-daemon or tuned-ppd)
# Try power-profiles-daemon first (traditional PPD)
if systemctl enable --now power-profiles-daemon 2>/dev/null; then
    echo "power-profiles-daemon service enabled"
elif systemctl enable --now tuned 2>/dev/null; then
    # Fedora 43+ with tuned-ppd: enable tuned service
    echo "tuned service enabled (provides power profile management via tuned-ppd)"
else
    echo "Warning: Failed to enable power profile daemon service"
fi
```

## Compatibility

Both `power-profiles-daemon` and `tuned-ppd` provide:

1. **D-Bus API**: Same interface for power profile management
2. **powerprofilesctl**: Command-line tool for profile switching
3. **ppd-service**: Virtual package name (conflicts prevented by detection)

The GZ302 power-manager library uses `powerprofilesctl`, which works with both implementations without code changes.

## Testing

Run the test script to validate the fix:

```bash
./test-fedora-ppd-fix.sh
```

This checks:
- Package detection logic
- powerprofilesctl availability
- Service enablement logic
- Conflict resolution strategy

## Implementation Details

### Files Modified
- `install-command-center.sh` - Main installation logic
- `VERSION` - Bumped to 4.0.2
- `Info/CHANGELOG.md` - Documented the fix

### Backward Compatibility
- **Fedora < 43**: Still installs `power-profiles-daemon` as before
- **Fedora 43+**: Uses pre-installed `tuned-ppd` (no conflict)
- **All versions**: Falls back gracefully if primary method fails

### Power Manager Library
No changes needed! The `gz302-lib/power-manager.sh` already uses:
- `powerprofilesctl` command (line 94)
- Compatible profile mapping (line 304)

Both implementations support the same profiles:
- Performance
- Balanced  
- Power Saver

## References

- [Fedora Change Proposal](https://fedoraproject.org/wiki/Changes/TunedAsTheDefaultPowerProfileManagementDaemon)
- [Phoronix Article](https://www.phoronix.com/news/Fedora-41-Goes-Tuned-PPD)
- [tuned-ppd Package](https://packages.fedoraproject.org/pkgs/tuned/tuned-ppd/)

## Summary

This fix ensures the installation script works seamlessly on both:
- Older Fedora versions (< 43) with `power-profiles-daemon`
- Fedora 43+ with `tuned-ppd`

The solution prevents package conflicts while maintaining full power management functionality across all Fedora versions.
