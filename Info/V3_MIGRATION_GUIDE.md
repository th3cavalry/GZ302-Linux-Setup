# Migration Guide: v2.x → v3.0.0

## Overview

Version 3.0.0 represents a major architectural shift in the GZ302 project. This guide helps users understand the changes and migrate from v2.x installations.

**TL;DR:** If you're running kernel 6.17+, re-run the scripts to clean up obsolete workarounds and improve performance.

---

## What Changed?

### Philosophy Shift

**Before (v2.x):**
- "GZ302 Linux Setup" - Hardware enablement tool
- Focus: Make Linux work on GZ302
- Necessity: High (device unusable without)
- Approach: Apply all fixes unconditionally

**After (v3.0.0):**
- "GZ302 Toolkit" - Optimization and convenience toolkit
- Focus: Optimize GZ302 for Linux
- Necessity: Low (device works natively on kernel 6.17+)
- Approach: Kernel-aware, apply only necessary fixes

### Technical Changes

#### 1. Kernel-Aware Installation

Scripts now detect your kernel version and behave differently:

| Kernel Version | v2.x Behavior | v3.0.0 Behavior |
|----------------|---------------|-----------------|
| < 6.14 | Applied fixes (broken) | Refuses to run (upgrade kernel) |
| 6.14-6.16 | Applied all fixes | Applies all necessary fixes |
| 6.17+ | Applied all fixes (harmful) | Minimal fixes + cleanup |

#### 2. Automatic Cleanup

New in v3.0.0: Scripts remove obsolete components when run on kernel 6.17+:

**Removed Components:**
- WiFi ASPM workaround (`/etc/modprobe.d/mt7925.conf` with `disable_aspm=1`)
- Tablet mode daemon (`/etc/systemd/system/gz302-tablet.service`)
- Touchpad forcing option (`enable_touchpad=1` in hid-asus)
- Touchpad reload service (`/etc/systemd/system/reload-hid_asus.service`)

**Why Remove?**
- WiFi workaround degrades battery life on 6.17+
- Tablet daemon conflicts with native asus-wmi driver
- Touchpad forcing no longer needed (native enumeration reliable)

**Kept Components:**
- Audio quirks (CS35L41 still needs fixes)
- Kernel parameters (amd_pstate, amdgpu)
- Userspace tools (pwrcfg, rrcfg, RGB)
- AI/LLM optimizations (performance tuning)

---

## Do I Need to Migrate?

### Check Your Kernel Version

```bash
uname -r
# Example: 6.17.4-arch1-1
```

### Decision Matrix

| Situation | Action Required | Priority |
|-----------|----------------|----------|
| Kernel < 6.14 | Upgrade kernel to 6.14+ | **Critical** |
| Kernel 6.14-6.16, never used v2.x | Fresh install with v3.0.0 | Normal |
| Kernel 6.14-6.16, using v2.x | Re-run to update (no cleanup) | Low |
| Kernel 6.17+, never used v2.x | Fresh install with v3.0.0 | Normal |
| Kernel 6.17+, using v2.x | **Re-run to cleanup obsolete fixes** | **High** |

---

## Migration Steps

### For Kernel 6.17+ Users (Recommended)

If you installed v2.x on an older kernel and have since upgraded to 6.17+:

#### Step 1: Backup Current Config (Optional)

```bash
# Backup current modprobe configs
sudo cp -r /etc/modprobe.d /etc/modprobe.d.backup-v2

# Backup systemd services
sudo cp -r /etc/systemd/system/gz302-* /tmp/gz302-services-backup/ 2>/dev/null || true
```

#### Step 2: Re-run the Minimal Script

```bash
# Download v3.0.0
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh

# Run (will auto-cleanup obsolete fixes)
sudo ./gz302-minimal.sh
```

**What happens:**
1. Script detects kernel 6.17+
2. Runs `cleanup_obsolete_fixes()` automatically
3. Removes obsolete WiFi/touchpad/tablet mode workarounds
4. Applies minimal necessary configuration
5. Provides summary of what was cleaned

#### Step 3: Reboot

```bash
sudo reboot
```

#### Step 4: Verify Improvements

After reboot, verify everything works:

**WiFi Test:**
```bash
# Test latency (should be low and stable)
ping -c 120 8.8.8.8 | grep "min/avg/max"

# Expected: rtt min/avg/max/mdev = 8.x/12.x/25.x/3.x ms
# (Low jitter indicates native ASPM is working)
```

**Tablet Mode Test:**
```bash
# Detach keyboard and check if screen rotates automatically
# Should work seamlessly in GNOME 49+ or KDE Plasma 6
```

**Touchpad Test:**
```bash
# Check touchpad is detected
xinput list | grep -i touchpad

# Should show touchpad without needing reload service
```

**Battery Life:**
WiFi power management should improve battery life by 10-20% compared to v2.x workaround.

---

### For Kernel 6.14-6.16 Users

If you're still on kernel 6.14-6.16:

#### Option 1: Upgrade to 6.17+ (Recommended)

Check if your distribution has kernel 6.17+:

```bash
# Arch
sudo pacman -Syu linux

# Fedora
sudo dnf update kernel

# Ubuntu (may need HWE kernel)
sudo apt update && sudo apt upgrade

# OpenSUSE Tumbleweed
sudo zypper dup
```

Then follow the "Kernel 6.17+ Users" steps above.

#### Option 2: Stay on Current Kernel

If you must stay on 6.14-6.16:

```bash
# Download v3.0.0
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh

# Run (will apply full workarounds for < 6.17)
sudo ./gz302-minimal.sh
```

**What happens:**
1. Script detects kernel < 6.17
2. Applies WiFi ASPM workaround
3. Applies touchpad fixes
4. Installs tablet mode daemon (if using full script)
5. No cleanup performed (workarounds still needed)

---

## Breaking Changes

### 1. WiFi Configuration

**v2.x:**
```bash
# /etc/modprobe.d/mt7925.conf
options mt7925e disable_aspm=1
```
Always applied, regardless of kernel version.

**v3.0.0:**
```bash
# Kernel < 6.17
options mt7925e disable_aspm=1

# Kernel >= 6.17
# (File exists but workaround removed)
```
Conditionally applied based on kernel version. On 6.17+, the workaround is actively removed if present.

### 2. Tablet Mode Handling

**v2.x:**
```bash
# Always installed userspace daemon
/etc/systemd/system/gz302-tablet.service
```

**v3.0.0:**
```bash
# Kernel < 6.17: Daemon installed
# Kernel >= 6.17: Daemon removed (conflicts with asus-wmi)
```

### 3. Touchpad Detection

**v2.x:**
```bash
# Always forced
options hid_asus enable_touchpad=1
```

**v3.0.0:**
```bash
# Kernel < 6.17: Forced
# Kernel >= 6.17: Option removed (not needed)
```

---

## FAQ

### Q: I'm on kernel 6.17+. Do I need this repository at all?

**A:** It depends on your use case:

**Still Valuable:**
- Audio quirks (CS35L41 fix still required)
- Power management tools (pwrcfg, rrcfg)
- RGB keyboard control
- AI/LLM optimizations
- Convenience features

**Not Needed:**
- Basic hardware enablement (kernel handles it natively)

### Q: Will v3.0.0 break my system if I'm on kernel 6.14-6.16?

**A:** No. The script detects your kernel and applies the same fixes as v2.x for older kernels. No changes in behavior for < 6.17.

### Q: What if I don't want automatic cleanup?

**A:** The cleanup only runs on kernel 6.17+. If you want to keep obsolete workarounds (not recommended), you can:
1. Manually edit the script and comment out `cleanup_obsolete_fixes()`
2. Or, stay on v2.x (not recommended - you're missing optimizations)

But **we strongly recommend allowing the cleanup** as obsolete workarounds:
- Harm battery life (WiFi)
- Cause conflicts (tablet mode)
- Provide no benefit on modern kernels

### Q: I upgraded from kernel 6.16 to 6.17 but didn't re-run the script. Should I?

**A:** Yes! Re-run `gz302-minimal.sh` to:
1. Remove obsolete WiFi workaround (improve battery)
2. Remove tablet mode daemon (prevent conflicts)
3. Get optimal configuration for 6.17

### Q: Can I run v3.0.0 on a fresh install?

**A:** Absolutely! v3.0.0 is designed for fresh installs and automatically adapts to your kernel version. Just run:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh
sudo ./gz302-minimal.sh
```

### Q: Where can I learn more about what's obsolete?

**A:** See the comprehensive documentation:
- `Info/OBSOLESCENCE.md` - Component-by-component analysis
- `Info/KERNEL_COMPATIBILITY.md` - Quick reference guide
- `Info/CHANGELOG.md` - v3.0.0 release notes

---

## Troubleshooting

### Issue: WiFi slower after migration

**Cause:** linux-firmware package may be outdated.

**Solution:**
```bash
# Arch
sudo pacman -S linux-firmware

# Ubuntu
sudo apt update && sudo apt install --reinstall linux-firmware

# Fedora
sudo dnf update linux-firmware

# OpenSUSE
sudo zypper install --force linux-firmware
```

Verify firmware date:
```bash
modinfo mt7925e | grep firmware
# Should show files from September 2025 or later
```

### Issue: Screen doesn't rotate after tablet mode daemon removal

**Cause:** Desktop environment may not support SW_TABLET_MODE yet.

**Solution:**
```bash
# Check if kernel sends events
sudo evtest | grep -i tablet
# Detach keyboard - should see SW_TABLET_MODE events

# If no events: kernel support missing (shouldn't happen on 6.17+)
# If events but no rotation: update desktop environment
#   - GNOME 49+ required
#   - KDE Plasma 6 required
```

### Issue: Touchpad not detected after migration

**Cause:** Rare case where native enumeration fails.

**Solution:**
```bash
# Manually reload module
sudo modprobe -r hid_asus && sudo modprobe hid_asus

# Check detection
xinput list | grep -i touchpad

# If still not detected: report issue with kernel version and logs
```

---

## Rollback to v2.x (Not Recommended)

If you need to rollback for any reason:

```bash
# Download v2.3.15 (last v2.x release)
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/v2.3.15/gz302-minimal.sh -o gz302-minimal-v2.sh
chmod +x gz302-minimal-v2.sh
sudo ./gz302-minimal-v2.sh
```

**Warning:** v2.x applies outdated workarounds that harm performance on kernel 6.17+. Only rollback if you have a specific reason.

---

## Support & Feedback

- **Documentation:** See `Info/` directory for detailed analysis
- **Issues:** Report problems via GitHub Issues
- **Discussions:** Use GitHub Discussions for questions
- **Contributing:** See `CONTRIBUTING.md` for contribution guidelines

---

## Acknowledgments

This major version release was informed by:
- Comprehensive kernel research (6.14-6.18)
- Community feedback from early adopters
- Upstream kernel development (asus-wmi, mt7925e, amdgpu)
- Analysis of obsolescence patterns in Linux hardware support

Thank you to all contributors and users who helped identify what's needed and what's obsolete!

---

**Version:** 3.0.0  
**Date:** December 8, 2025  
**Author:** th3cavalry  
**License:** MIT
