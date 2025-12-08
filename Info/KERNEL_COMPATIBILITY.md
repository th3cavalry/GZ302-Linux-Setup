# GZ302 Kernel Compatibility Matrix

## Quick Reference Guide

This document provides a clear decision matrix for which components of GZ302-Linux-Setup are needed based on your Linux kernel version.

**Target Hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS64/XS32)  
**Last Updated:** December 8, 2025  
**Kernel Range Covered:** 6.14 - 6.18+

---

## Quick Check: What Do I Need?

### 1. Check Your Kernel Version
```bash
uname -r
# Example output: 6.17.4-arch1-1
```

### 2. Find Your Category

| Kernel Version | Category | Status |
|---------------|----------|--------|
| < 6.14 | **Unsupported** | Upgrade required |
| 6.14 - 6.15 | **Early Support** | All fixes needed |
| 6.16 | **Maturing** | Most fixes needed |
| 6.17 - 6.18 | **Production** | Minimal fixes, optimization focus |
| 6.19+ | **Future** | Check updates |

### 3. Use the Matrix Below

---

## Compatibility Matrix by Component

### 🔧 Hardware Fixes

| Component | Kernel 6.14-6.15 | Kernel 6.16 | Kernel 6.17+ | Status in 6.17+ |
|-----------|------------------|-------------|--------------|-----------------|
| **WiFi (MT7925)** | ✅ **REQUIRED** | ✅ **REQUIRED** | ❌ Not Needed | Native support |
| **Tablet Mode** | ✅ **REQUIRED** | ✅ **REQUIRED** | ❌ Not Needed | asus-wmi handles it |
| **Input Force** | ✅ **REQUIRED** | ⚠️ Recommended | ❌ Not Needed | Native enumeration |
| **Audio (CS35L41)** | ✅ **REQUIRED** | ✅ **REQUIRED** | ✅ **REQUIRED** | Quirk still missing |
| **GPU Stability** | ✅ **REQUIRED** | ⚠️ Recommended | ❌ Not Needed | Stable in 6.16+ |

### 🎨 Userspace Tools

| Component | All Kernels | Purpose | Necessity |
|-----------|-------------|---------|-----------|
| **pwrcfg (Power)** | ⚠️ Optional | TDP profile management | Convenience |
| **rrcfg (Refresh)** | ⚠️ Optional | Display refresh control | Convenience |
| **gz302-rgb** | ⚠️ Optional | Keyboard backlight | Convenience |
| **System Tray** | ⚠️ Optional | GUI for above tools | Convenience |

### 🤖 AI/LLM Optimizations

| Component | All Kernels | Purpose | Necessity |
|-----------|-------------|---------|-----------|
| **GTT Size** | ⚠️ Optional | Large model support | AI workloads only |
| **IOMMU Off** | ⚠️ Optional | Lower latency | AI workloads only |
| **ROCm Setup** | ⚠️ Optional | GPU compute | AI workloads only |

**Legend:**
- ✅ **REQUIRED:** Must install for hardware to function
- ⚠️ **Recommended/Optional:** Beneficial but not mandatory
- ❌ **Not Needed:** Native support exists, applying may harm

---

## Detailed Breakdown by Kernel Version

### Kernel 6.14 - 6.15 (Early Support)

**Status:** Initial Strix Halo support, significant issues remain

#### Required Fixes
1. ✅ **WiFi ASPM Workaround**
   - **Issue:** High jitter, packet loss
   - **Fix:** `options mt7925e disable_aspm=1`
   - **Applied by:** `gz302-minimal.sh`

2. ✅ **Tablet Mode Daemon**
   - **Issue:** No ACPI events for keyboard detachment
   - **Fix:** Userspace polling + rotation scripts
   - **Applied by:** `gz302-main.sh` (full setup)

3. ✅ **Input Device Forcing**
   - **Issue:** Touchpad fails to enumerate
   - **Fix:** `options hid_asus enable_touchpad=1`
   - **Applied by:** `gz302-minimal.sh`

4. ✅ **Audio Quirk**
   - **Issue:** CS35L41 amplifiers not initialized
   - **Fix:** DSDT patching for GPIO mappings
   - **Applied by:** `gz302-main.sh`

5. ✅ **GPU Stability**
   - **Issue:** Graphics corruption, ring timeouts
   - **Fix:** `amdgpu.gttsize=131072`
   - **Applied by:** `gz302-minimal.sh`

6. ✅ **Kernel Parameters**
   - **Required:** `amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff`
   - **Applied by:** `gz302-minimal.sh`

#### Recommendations
- **Install:** Full `gz302-main.sh` setup
- **Expect:** Some instability, particularly graphics
- **Consider:** Upgrading to 6.16+ if available

---

### Kernel 6.16 (Maturing Support)

**Status:** Major stability improvements, SmartMux support

#### Required Fixes
1. ✅ **WiFi ASPM Workaround**
   - **Status:** Still needed, improvements made but not complete
   - **Fix:** Same as 6.14-6.15

2. ✅ **Tablet Mode Daemon**
   - **Status:** Still needed, native support not yet merged
   - **Fix:** Same as 6.14-6.15

3. ⚠️ **Input Device Forcing**
   - **Status:** Mostly stable, may still have race conditions
   - **Fix:** Same as 6.14-6.15
   - **Impact:** Optional, test without first

4. ✅ **Audio Quirk**
   - **Status:** Still required
   - **Fix:** Same as 6.14-6.15

5. ❌ **GPU Stability** (Obsolete)
   - **Status:** Native stability achieved
   - **Fix:** Remove GTT size override for general use
   - **Keep for:** AI/LLM workloads only

#### Changes from 6.14-6.15
- ✅ Graphics stable for desktop/gaming
- ✅ SmartMux power gating working
- ⚠️ WiFi improved but not perfect
- ⚠️ Tablet mode still needs daemon

#### Recommendations
- **Install:** `gz302-minimal.sh` + audio quirk
- **Optional:** Userspace tools (pwrcfg, rrcfg)
- **Skip:** GPU stability fixes unless doing AI work

---

### Kernel 6.17 - 6.18 (Production Ready)

**Status:** Full native GZ302 support, optimization focus

#### Required Fixes
1. ❌ **WiFi ASPM Workaround** (Obsolete)
   - **Status:** Native ASPM working correctly
   - **Action:** **DO NOT APPLY** - harms battery life
   - **Verify:** Latest `linux-firmware` installed (Sept 2025+)

2. ❌ **Tablet Mode Daemon** (Obsolete)
   - **Status:** Kernel emits `SW_TABLET_MODE` events
   - **Action:** **DO NOT RUN** - conflicts with native support
   - **Integration:** GNOME 49+ and KDE Plasma 6 handle automatically

3. ❌ **Input Device Forcing** (Obsolete)
   - **Status:** Native enumeration reliable
   - **Action:** Remove `enable_touchpad=1` if present

4. ✅ **Audio Quirk** (Still Required)
   - **Status:** GZ302 subsystem ID not in upstream quirk list
   - **Fix:** DSDT patching still needed
   - **Apply:** Via `gz302-main.sh` audio module

5. ❌ **GPU Stability** (Obsolete for general use)
   - **Status:** Stable by default
   - **Exception:** AI/LLM workloads benefit from GTT resize

6. ✅ **Kernel Parameters** (Partially needed)
   - **Required:** `amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff`
   - **Optional:** `amdgpu.gttsize=131072` (AI workloads only)

#### Optimal Configuration

**For Desktop/Gaming Users:**
```bash
# Kernel parameters (in GRUB)
amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff

# Audio quirk (run once)
sudo ./gz302-main.sh
# Select: Audio fix only

# Optional: Userspace tools
sudo ./gz302-main.sh
# Select: Install pwrcfg, rrcfg, RGB tools
```

**For AI/LLM Users:**
```bash
# Kernel parameters (in GRUB)
amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff amdgpu.gttsize=131072 amd_iommu=off

# Audio quirk
sudo ./gz302-main.sh
# Select: Audio fix

# LLM module
sudo ./gz302-main.sh
# Select: Install LLM/AI module (includes ROCm, Ollama, PyTorch)

# Optional: Userspace tools
# Select: Install pwrcfg, rrcfg, RGB tools
```

#### What's Working Natively
- ✅ WiFi at full performance with power saving
- ✅ Tablet mode detection and automatic rotation
- ✅ Touchpad and keyboard enumeration
- ✅ GPU stability for desktop and gaming
- ✅ Accelerometer and sensor fusion
- ✅ Power profile switching (via asusctl)
- ✅ Fan control and thermal monitoring (6.18+)

#### What Still Needs Fixes
- ⚠️ Audio amplifier initialization (CS35L41 quirk)

#### Recommendations
- **Minimal Setup:** Kernel params + audio quirk
- **Enhanced Setup:** Add pwrcfg/rrcfg tools for convenience
- **AI Setup:** Include GTT/IOMMU optimizations + ROCm

---

## Distribution-Specific Quick Reference

### Fedora 43 (Kernel 6.17+)
```bash
# Check kernel
uname -r  # Should show 6.17+

# Required
- Audio quirk
- Kernel parameters (amd_pstate, amdgpu)

# Obsolete (DO NOT APPLY)
- WiFi ASPM workaround
- Tablet mode daemon
- Input forcing
- GPU stability fix

# Recommended
- pwrcfg/rrcfg tools
- RGB control
```

---

### Ubuntu 25.10 (Kernel 6.17)
```bash
# Check kernel
uname -r  # Should show 6.17.x

# Same as Fedora 43, plus:
- Verify linux-firmware is up to date:
  apt update && apt upgrade linux-firmware

# Secure Boot Note
- If using custom modules, run:
  sudo ./gz302-secureboot.sh
```

---

### Arch Linux (Kernel 6.18+)
```bash
# Check kernel
uname -r  # Usually 6.18+ on rolling

# Required
- Audio quirk (test first, may be in kernel)
- Kernel parameters

# Obsolete (DO NOT APPLY)
- All hardware workarounds

# Recommended
- pwrcfg/rrcfg/RGB (pure convenience)
```

---

### CachyOS (Kernel 6.18+ with patches)
```bash
# Check kernel
uname -r  # linux-cachyos or linux-g14

# Likely NOT Required
- Audio quirk (may be in linux-g14)
- Test audio first: speaker-test -t wav -c 2

# Recommended
- AI optimizations (if using LLMs)
- znver4-optimized packages:
  - ollama-rocm
  - python-pytorch-opt-rocm
```

---

### OpenSUSE Tumbleweed (Kernel 6.18+)
```bash
# Check kernel
uname -r  # Should show 6.18+

# Same as Arch Linux

# Package Notes
- asusctl may need OBS repository:
  zypper ar https://download.opensuse.org/repositories/home:/luke_nukem:/asus-linux/openSUSE_Tumbleweed/ asus-linux
  zypper refresh && zypper install asusctl
```

---

## Migration Guide: Removing Obsolete Components

### If You Installed Before Kernel 6.17

Your system may have components that are now obsolete or harmful:

```bash
# 1. Check your kernel
uname -r

# 2. If >= 6.17, clean up obsolete components
sudo rm -f /etc/modprobe.d/mt7925.conf  # WiFi workaround
sudo systemctl disable --now gz302-tablet.service  # Tablet daemon
sudo sed -i '/enable_touchpad=1/d' /etc/modprobe.d/hid-asus.conf  # Input forcing

# 3. Reload affected modules
sudo modprobe -r mt7925e && sudo modprobe mt7925e
sudo modprobe -r hid_asus && sudo modprobe hid_asus

# 4. Keep these (still valid)
# - Audio quirks (/etc/modprobe.d/cs35l41-fix.conf or similar)
# - pwrcfg/rrcfg tools (/usr/local/bin/pwrcfg, /usr/local/bin/rrcfg)
# - RGB control (/usr/local/bin/gz302-rgb)
# - Kernel parameters in GRUB (amd_pstate=guided, etc.)

# 5. Reboot
sudo reboot
```

---

## Testing Your Configuration

### Test 1: WiFi Performance
```bash
# Test latency stability (run for 2 minutes)
ping -c 120 8.8.8.8 | tee wifi-test.txt

# Analyze results
cat wifi-test.txt | grep "min/avg/max"

# Good result (6.17+ without workaround):
# rtt min/avg/max/mdev = 8.123/12.456/25.789/3.214 ms

# Bad result (needs workaround):
# rtt min/avg/max/mdev = 15.432/85.234/350.123/95.432 ms
```

### Test 2: Tablet Mode
```bash
# Install evtest if not present
sudo pacman -S evtest  # Arch
sudo apt install evtest  # Debian/Ubuntu

# Monitor tablet mode events
sudo evtest | grep -i tablet

# Expected on 6.17+ (detach keyboard):
# Event: time 1234567890.123456, type 5 (EV_SW), code 1 (SW_TABLET_MODE), value 1

# If no events, kernel support missing
```

### Test 3: Audio
```bash
# Test speakers
speaker-test -t wav -c 2 -l 1

# Should hear "Front Left" and "Front Right"
# If silent, check dmesg for CS35L41 errors:
dmesg | grep -i cs35l41

# If "Failed to sync masks", audio quirk needed
```

### Test 4: Graphics
```bash
# Check for GPU errors
dmesg | grep -i amdgpu | grep -i error

# Monitor GPU usage (install radeontop first)
radeontop

# Should show stable frequencies, no resets
```

---

## Troubleshooting by Symptom

### WiFi is slow or drops packets
- **Kernel < 6.17:** Apply ASPM workaround
- **Kernel >= 6.17:** 
  1. Remove ASPM workaround if present
  2. Update linux-firmware package
  3. Verify: `modinfo mt7925e | grep firmware`

### Screen doesn't rotate when detaching keyboard
- **Kernel < 6.17:** Install tablet mode daemon
- **Kernel >= 6.17:**
  1. Remove any custom rotation scripts
  2. Verify DE support (GNOME 49+, KDE Plasma 6)
  3. Check: `sudo evtest | grep tablet` while detaching

### Touchpad not detected
- **Kernel < 6.17:** Apply input forcing
- **Kernel >= 6.17:**
  1. Remove `enable_touchpad=1` from modprobe
  2. Reload module: `sudo modprobe -r hid_asus && sudo modprobe hid_asus`
  3. Check: `xinput list` (should show touchpad)

### No audio from speakers
- **All Kernels:** Audio quirk required (CS35L41)
- **Check dmesg:** `dmesg | grep cs35l41`
- **If error:** Run audio fix from `gz302-main.sh`

### Graphics corruption or crashes
- **Kernel < 6.16:** Apply GTT size increase
- **Kernel >= 6.16:**
  1. Remove GTT override (unless doing AI work)
  2. Update Mesa: `sudo pacman -S mesa` (Arch) or equivalent
  3. Verify: `glxinfo | grep "OpenGL renderer"`

### LLM inference is slow (< 10 tokens/sec)
- **All Kernels:** Apply AI optimizations
- **Required params:** `amdgpu.gttsize=131072 amd_iommu=off`
- **Verify:** `cat /proc/cmdline`
- **ROCm:** Ensure ROCm 6.4.4+ or 7.1+ installed

---

## Future Considerations

### Kernel 6.19+
- Monitor for CS35L41 quirk upstream merge
- Watch for further Strix Halo optimizations
- Check release notes: https://www.kernel.org

### When to Update This Guide
- New kernel version changes GZ302 support
- Audio quirk merged upstream
- Distribution kernel versions shift significantly
- New hardware issues discovered

---

## Additional Resources

- **Detailed Obsolescence Analysis:** `Info/OBSOLESCENCE.md`
- **Kernel Research Summary:** `Info/KERNEL_RESEARCH_SUMMARY_2025.md`
- **Distribution Status:** `Info/DISTRIBUTION_KERNEL_STATUS.md`
- **Main Repository:** https://github.com/th3cavalry/GZ302-Linux-Setup

---

**Version:** 1.0.0 (December 8, 2025)  
**Maintainer:** th3cavalry  
**License:** MIT
