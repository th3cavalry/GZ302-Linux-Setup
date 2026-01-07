# GZ302 Testing Guide

**Date:** December 9, 2025  
**Version:** 4.0.0-dev  
**Status:** Testing Framework

---

## Overview

This guide provides comprehensive testing procedures for the GZ302-Linux-Setup project, covering both v3.0.0 (production) and v4.0.0 (development) scripts and libraries.

---

## Test Environments

### Supported Test Platforms

1. **Real Hardware (Preferred)**
   - ASUS ROG Flow Z13 (GZ302EA)
   - Various kernel versions (6.14, 6.16, 6.17, 6.18+)
   - All supported distributions

2. **Virtual Machines (Functional Testing)**
   - VirtualBox / VMware / QEMU/KVM
   - Limited hardware emulation
   - Good for basic script validation

3. **Containers (Unit Testing)**
   - Docker / Podman
   - Library function testing
   - Syntax and shellcheck validation

### Kernel Version Matrix

| Kernel | WiFi Workaround | Input Workaround | Status |
|--------|-----------------|------------------|--------|
| < 6.14 | Required | Required | Unsupported |
| 6.14-6.16 | Required | Required | Supported |
| 6.17+ | Not needed | Not needed | Recommended |

---

## Quick Validation

### Syntax Validation

```bash
# Validate all scripts
for script in gz302-*.sh; do
    bash -n "$script" && echo "✓ $script" || echo "✗ $script FAILED"
done

# Validate all libraries
for lib in gz302-lib/*.sh; do
    bash -n "$lib" && echo "✓ $lib" || echo "✗ $lib FAILED"
done
```

### Shellcheck Validation

```bash
# Check all scripts
shellcheck gz302-*.sh

# Check all libraries
shellcheck gz302-lib/*.sh

# Expected: Zero warnings for production code
```

### Version Consistency

```bash
# Check version numbers match
grep "^# Version:" gz302-*.sh gz302-lib/*.sh
# All should show consistent version (3.0.0 or 4.0.0-dev)
```

---

## Library Testing

### Unit Tests (Individual Functions)

```bash
#!/bin/bash
# test-libraries.sh

source gz302-lib/kernel-compat.sh

echo "=== Testing kernel-compat.sh ==="

# Test 1: Version detection
version=$(kernel_get_version_num)
echo "Kernel version number: $version"
[[ $version -gt 600 ]] && echo "✓ Version detection works" || echo "✗ FAILED"

# Test 2: Minimum check
if kernel_meets_minimum; then
    echo "✓ Kernel meets minimum"
else
    echo "✗ Kernel below minimum"
fi

# Test 3: Status function
echo "Kernel status:"
kernel_get_status

echo
echo "=== Testing wifi-manager.sh ==="

source gz302-lib/wifi-manager.sh

# Test 4: Hardware detection
if wifi_detect_hardware >/dev/null 2>&1; then
    echo "✓ WiFi hardware detected"
else
    echo "⚠ WiFi hardware not detected (normal in VM)"
fi

# Test 5: State functions
if wifi_aspm_workaround_applied; then
    echo "ASPM workaround currently applied"
else
    echo "ASPM workaround not applied"
fi

# Add more tests...
```

### Integration Tests (Library Combinations)

```bash
#!/bin/bash
# test-integration.sh

echo "=== Library Integration Test ==="

# Load all libraries
for lib in gz302-lib/*.sh; do
    source "$lib" && echo "✓ Loaded $(basename $lib)" || echo "✗ FAILED $(basename $lib)"
done

# Test state management
state_init && echo "✓ State initialized" || echo "✗ State init failed"

# Test kernel compatibility
kernel_ver=$(kernel_get_version_num)
echo "Detected kernel: $kernel_ver"

# Test conditional logic
if kernel_requires_wifi_workaround; then
    echo "WiFi workaround required (kernel < 6.17)"
else
    echo "WiFi workaround not required (kernel >= 6.17)"
fi

echo "Integration test complete"
```

---

## Script Testing

### v4.0.0 Minimal Script

```bash
# Test 1: Syntax
bash -n gz302-minimal-v4.sh && echo "✓ Syntax OK"

# Test 2: Help mode (no root needed)
./gz302-minimal-v4.sh --help

# Test 3: Status mode (requires root)
sudo ./gz302-minimal-v4.sh --status

# Test 4: Dry-run (check what would be done)
# Note: Script doesn't have dry-run yet, use status mode

# Test 5: Actual run (first time)
sudo ./gz302-minimal-v4.sh

# Test 6: Idempotency (second run should be faster)
time sudo ./gz302-minimal-v4.sh
# Should complete in ~5 seconds (vs ~30 seconds first run)

# Test 7: Force mode
sudo ./gz302-minimal-v4.sh --force
# Should re-apply everything
```

### v4.0.0 Main Script

```bash
# Test 1: Syntax
bash -n gz302-main-v4.sh && echo "✓ Syntax OK"

# Test 2: Status mode
sudo ./gz302-main-v4.sh --status

# Test 3: Actual run
sudo ./gz302-main-v4.sh

# Note: v4.0.0-dev main script is incomplete
# Use v3.0.0 for full functionality testing
```

### v3.0.0 Scripts (Regression Testing)

```bash
# Ensure v3 still works
sudo ./gz302-main.sh
sudo ./gz302-minimal.sh

# v3 and v4 should not interfere
```

---

## Hardware Testing

### WiFi Testing

```bash
# Check WiFi hardware
lspci | grep -i "network\|wifi"

# Check WiFi module
lsmod | grep mt7925

# Check WiFi interface
ip link show

# Test connectivity
ping -c 4 8.8.8.8

# Check for errors
dmesg | grep -i "mt7925\|wifi" | tail -20

# Library status
sudo ./gz302-minimal-v4.sh --status | grep -A 10 "WiFi"
```

### GPU Testing

```bash
# Check GPU hardware
lspci | grep -i "vga\|display"

# Check GPU module
lsmod | grep amdgpu

# Check firmware
ls /lib/firmware/amdgpu/gc_11_5*

# Test GPU
glxinfo | grep -i "renderer\|version"

# Library status
sudo ./gz302-minimal-v4.sh --status | grep -A 10 "GPU"
```

### Input Device Testing

```bash
# Check touchpad
libinput list-devices | grep -i touchpad

# Check keyboard
libinput list-devices | grep -i keyboard

# Test touchpad gestures
# Try swiping, pinching, etc.

# Library status
sudo ./gz302-minimal-v4.sh --status | grep -A 10 "Input"
```

### Audio Testing

```bash
# Check audio cards
cat /proc/asound/cards

# Check for CS35L41
dmesg | grep -i cs35l41

# Test audio
speaker-test -c 2 -t wav

# Library status
sudo ./gz302-minimal-v4.sh --status | grep -A 10 "Audio"
```

---

## State Management Testing

### State Tracking

```bash
# Initialize state
sudo bash -c 'source gz302-lib/state-manager.sh && state_init'

# Mark something as applied
sudo bash -c 'source gz302-lib/state-manager.sh && state_mark_applied "test" "component" "metadata"'

# Check if applied
sudo bash -c 'source gz302-lib/state-manager.sh && state_is_applied "test" "component" && echo "Applied" || echo "Not applied"'

# List state
ls -la /var/lib/gz302/state/

# View state file
cat /var/lib/gz302/state/test.state

# Check backups
ls -la /var/backups/gz302/

# Check logs
tail /var/log/gz302/state.log
```

### Idempotency Testing

```bash
# Run script twice, measure time difference
echo "First run:"
time sudo ./gz302-minimal-v4.sh

echo "Second run (should be much faster):"
time sudo ./gz302-minimal-v4.sh

# First run: ~30 seconds
# Second run: ~5 seconds (6x faster)
```

---

## Performance Testing

### Execution Time

```bash
# Measure script execution time
time sudo ./gz302-minimal-v4.sh

# Expected times:
# - First run: 20-40 seconds
# - Second run: 3-7 seconds
# - Status mode: 1-3 seconds
```

### Resource Usage

```bash
# Monitor during execution
watch -n 1 'ps aux | grep gz302'

# Check memory usage
/usr/bin/time -v sudo ./gz302-minimal-v4.sh 2>&1 | grep -i "maximum resident"

# Typical: < 50MB RAM usage
```

---

## Distribution Testing

### Test Matrix

| Distribution | Arch | Ubuntu | Fedora | OpenSUSE |
|--------------|------|--------|--------|----------|
| **v3.0.0 main** | ✅ | ✅ | ✅ | ✅ |
| **v3.0.0 minimal** | ✅ | ✅ | ✅ | ✅ |
| **v4.0.0 minimal** | ⏳ | ⏳ | ⏳ | ⏳ |
| **v4.0.0 main** | ⏳ | ⏳ | ⏳ | ⏳ |

### Per-Distribution Tests

```bash
# Arch-based
sudo ./gz302-minimal-v4.sh  # Should detect "arch"

# Ubuntu-based
sudo ./gz302-minimal-v4.sh  # Should detect "ubuntu"

# Fedora-based
sudo ./gz302-minimal-v4.sh  # Should detect "fedora"

# OpenSUSE-based
sudo ./gz302-minimal-v4.sh  # Should detect "opensuse"

# Check detection
sudo ./gz302-minimal-v4.sh --status | grep "Detected"
```

---

## Regression Testing

### Ensure v3 Still Works

```bash
# v3.0.0 scripts should be unaffected by v4 development
sudo ./gz302-main.sh
sudo ./gz302-minimal.sh

# Check TDP control (v3 only)
pwrcfg list
pwrcfg balanced

# Check refresh rate (v3 only)
rrcfg list
rrcfg balanced
```

### Backward Compatibility

```bash
# v4 should not break v3 configurations
sudo ./gz302-main.sh       # Apply v3
sudo ./gz302-minimal-v4.sh # Apply v4
sudo ./gz302-main.sh       # Re-apply v3

# All should work without conflicts
```

---

## Automated Testing

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test GZ302 Scripts

on: [push, pull_request]

jobs:
  syntax-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Syntax validation
        run: |
          for script in gz302-*.sh; do
            bash -n "$script"
          done
          
      - name: Library syntax
        run: |
          for lib in gz302-lib/*.sh; do
            bash -n "$lib"
          done

  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck
        
      - name: Run shellcheck
        run: |
          shellcheck gz302-*.sh
          shellcheck gz302-lib/*.sh

  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check version consistency
        run: |
          grep "^# Version:" gz302-*.sh gz302-lib/*.sh
```

---

## Test Reporting

### Test Report Template

```markdown
## Test Report

**Date:** YYYY-MM-DD
**Tester:** Name
**System:** GZ302EA-XS99
**Kernel:** 6.17.4
**Distribution:** Arch Linux

### Tests Performed

1. **Syntax Validation**
   - gz302-main-v4.sh: ✅ Pass
   - gz302-minimal-v4.sh: ✅ Pass
   - All libraries: ✅ Pass

2. **Shellcheck**
   - All scripts: ✅ Pass (0 warnings)

3. **Functional Tests**
   - Installation: ✅ Pass
   - Idempotency: ✅ Pass (5s second run)
   - Status mode: ✅ Pass
   - Hardware detection: ✅ Pass

4. **Hardware Verification**
   - WiFi: ✅ Working
   - GPU: ✅ Working
   - Input: ✅ Working
   - Audio: ✅ Working

5. **Issues Found**
   - None

### Recommendations
- Ready for release

### Attachments
- Screenshots
- Log files
- Performance metrics
```

---

## Troubleshooting Tests

### Common Issues

**Issue: Script hangs**
```bash
# Kill and check logs
sudo pkill -f gz302
tail /var/log/gz302/state.log
```

**Issue: Permission denied**
```bash
# Ensure running as root
sudo ./gz302-minimal-v4.sh
```

**Issue: Libraries not found**
```bash
# Check library directory
ls -la gz302-lib/

# Manual download
mkdir -p gz302-lib
cd gz302-lib
for lib in kernel-compat state-manager wifi-manager gpu-manager input-manager audio-manager; do
    curl -O "https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/${lib}.sh"
done
chmod +x *.sh
```

---

## Summary

**Testing Checklist:**
- [ ] Syntax validation (all scripts)
- [ ] Shellcheck (zero warnings)
- [ ] Library unit tests
- [ ] Script integration tests
- [ ] Hardware verification
- [ ] State management
- [ ] Idempotency
- [ ] Performance benchmarks
- [ ] Multi-distribution tests
- [ ] Regression tests (v3)
- [ ] Documentation review

**Test Coverage:**
- ✅ v3.0.0: Fully tested, production-ready
- ✅ v4.0.0 libraries: Validated, functional
- ✅ v4.0.0 minimal: Complete, tested
- ⏳ v4.0.0 main: In development, partial

---

**Document Version:** 1.0  
**Last Updated:** December 9, 2025  
**Status:** Living document, updated with test results
