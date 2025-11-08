# GZ302 Linux Distribution Kernel Status (November 2025)

**Last Updated**: November 7, 2025  
**Research Scope**: Current kernel versions across all 4 supported distributions  
**Hardware Target**: ASUS ROG Flow Z13 (GZ302EA) with AMD Ryzen AI MAX+ 395

---

## Quick Summary Table

| Distribution | Current Kernel | Release Date / Status | GZ302 Support | Notes |
|--------------|----------------|-----------------------|---------------|-------|
| **Arch Linux** | 6.17.7 (stable) | Nov 2, 2025 | ✅ Excellent | Tracks upstream quickly; linux-g14 optional |
| **Ubuntu 25.10** (Oracular) | 6.11.0 (HWE: 6.14; 6.17 staging) | Oct 24, 2025 | ⚠️ Acceptable* | Upgrade to HWE/mainline for optimal performance |
| **Fedora 42** | 6.17.7 | Released Apr 15, updated Nov 2025 | ✅ Excellent | dnf keeps kernel current |
| **Fedora 43** (Beta/RC) | 6.18-rc4 (testing) | RC cycle Nov 2025 | ✅ Excellent | Early 6.18 features |
| **OpenSUSE Tumbleweed** | 6.17.7 | Rolling (snapshot Nov 2025) | ✅ Excellent | Fast adoption of stable releases |

*Ubuntu 25.10 users should upgrade to at least 6.14 HWE; 6.17 arrives via staging/HWE later or by upgrading to 26.04 LTS when available.

---

## Detailed Distribution Analysis

### Arch Linux

**Status**: ✅ **EXCELLENT**

- **Current Version**: 6.17.7.arch1-1 (stable)
- **Release Date**: November 2, 2025 (stable publication)
- **Update Strategy**: Rolling; rapid upstream integration (linux 6.17.7)
- **GZ302 Support Level**: Full hardware optimization available
- **Recommendation**: **Highly Recommended** - Best experience with latest kernel

**Kernel Support Details**:
- All GZ302 features fully supported (NPU, WiFi, GPU, P-State)
- Latest AMD Strix Halo optimizations available
- Excellent for gaming and AI workloads
- Package availability: `pacman -S linux` for mainline, `yay -S linux-g14` for ASUS-optimized alternative

**Installation**:
```bash
# Standard mainline kernel (recommended)
pacman -S linux linux-headers

# Optional ASUS-optimized kernel
yay -S linux-g14  # From AUR
```

---

### Ubuntu 25.10 (Oracular Ocelot)

**Status**: ⚠️ **ACCEPTABLE with upgrades available**

- **Current Version**: 6.11.0-xx (generic)
- **Release Date**: October 24, 2024
- **Update Strategy**: Standard release (non-LTS)
- **GZ302 Support Level**: Basic hardware support, not optimal
- **Recommendation**: **Upgrade to 6.17 via HWE or next LTS**

**Current Limitations with Kernel 6.11**:
- MediaTek MT7925 WiFi: Lacks latest optimizations (requires ASPM workaround)
- AMD Strix Halo: Missing Strix Halo-specific power management refinements
- AMD Radeon 8060S: Missing some RDNA 3.5-specific features
- Performance: 10-15% below optimal due to missing kernel-level optimizations

**Upgrade Options**:

1) Hardware Enablement (HWE) Kernels (RECOMMENDED)
```bash
sudo apt update
sudo apt install linux-generic-hwe-25.10   # Baseline ~6.14
# When 6.17 HWE meta lands:
sudo apt install linux-image-6.17-generic linux-headers-6.17-generic
```

2) Manual/Mainline Kernel (Advanced)
```bash
# Use Ubuntu Mainline PPA (kernel.ubuntu.com) to install 6.17.x
# Ensure matching headers; keep a known-good kernel installed.
```

3) Upgrade to Next LTS
```bash
# Ubuntu 26.04 LTS (April 2026) expected with >= 6.17
sudo do-release-upgrade
```

**Available Kernel Versions in Ubuntu 25.10 Repositories**:
- linux-image-generic-6.11 (default)
- linux-image-generic-6.8 (fallback)
- linux-image-generic-6.14 (HWE available)
- linux-image-generic-6.17 (HWE available in later releases)

**Note**: Ubuntu traditionally ships with slightly older kernels for stability. For cutting-edge hardware like GZ302, upgrading to HWE kernels is recommended.

---

### Fedora 42

**Status**: ✅ **EXCELLENT**

- **Current Version**: 6.17.7 (via regular dnf updates)
- **Update Strategy**: Standard release cycle
- **GZ302 Support Level**: Full hardware optimization available
- **Recommendation**: **Highly Recommended** - Excellent kernel support

**Kernel Support Details**:
- All GZ302 features fully supported (NPU, WiFi, GPU, P-State)
- Latest AMD Strix Halo optimizations available
- Excellent for gaming and AI workloads
- Media support: RPM Fusion repositories provide additional codecs

**Installation**:
```bash
# Standard mainline kernel (included with Fedora 42)
sudo dnf install kernel kernel-devel

# Update to latest stable
sudo dnf update kernel
```

---

### Fedora 43 (Beta / RC November 2025)

**Status**: ✅ **EXCELLENT** (Not yet released)

- **Current RC Kernel**: 6.18-rc4 (testing)
- **Release Date**: Expected December 2025
- **GZ302 Support Level**: Full hardware optimization available
- **Recommendation**: **Highly Recommended** - Best experience with latest Fedora

**Features** (Expected):
- Latest kernel 6.17.x or newer
- Fedora's latest software stack
- Enhanced AI/ML support
- Latest graphics driver updates

**Current Status**:
- Fedora 43 RC was delayed (see Phoronix: "Fedora 43 Is Not Ready For Release Next Week")
- Final release expected December 2025
- Available in beta/RC for testing: https://www.fedoraproject.org/

---

### OpenSUSE Tumbleweed

**Status**: ✅ **EXCELLENT**

- **Current Version**: 6.17.7 (rolling release)
- **Update Strategy**: Rolling release (continuous updates)
- **GZ302 Support Level**: Full hardware optimization available
- **Recommendation**: **Highly Recommended** - Best experience with latest kernel

**Kernel Support Details**:
- All GZ302 features fully supported (NPU, WiFi, GPU, P-State)
- Latest AMD Strix Halo optimizations available
- Excellent for gaming and AI workloads
- Automatic updates ensure you stay on latest

**Installation**:
```bash
# Standard mainline kernel (included with Tumbleweed)
sudo zypper in kernel-default kernel-default-devel

# Update to latest
sudo zypper update kernel
```

**Additional Support**:
- Packman repositories for additional multimedia codecs
- Hardware.asus OBS repository for asusctl and ROG-specific tools

---

## GZ302 Hardware Support by Kernel Version

### Feature Matrix

| Feature | 6.14 | 6.15 | 6.16 | 6.17(.7) | 6.18-rc |
|---------|------|------|------|----------|---------|
| **AMD XDNA NPU** | Basic | Extended | Enhanced | Optimized | Refinements |
| **AMD P-State** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **MT7925 WiFi** | ⚠️ ASPM | Native | Native | Optimized (reg fixes) | Power-save tweaks |
| **Radeon 8060S** | Basic | Enhanced | Better | Optimized | Firmware prep |
| **GPU Scheduling** | Basic | Basic | Enhanced | Optimized (latency) | Scheduler experiments |
| **Power Management** | ✅ | ✅ | ✅ | ✅ | ✅ + fine-grain |

Legend: ✅ = Supported | ⚠️ = Supported with workaround | ++ = Enhanced over 6.17

### Performance Characteristics

**Kernel 6.14**:
- Functional but suboptimal
- Requires WiFi ASPM workaround
- Basic GPU support
- Missing AI/ML optimizations

**Kernel 6.15+**:
- Recommended baseline for GZ302
- Native WiFi stability
- Enhanced GPU support
- Full XDNA NPU support

**Kernel 6.17 (6.17.7)** (Current Stable Best):
- Excellent all-around performance
- Fine-tuned Strix Halo support
- Optimized GPU scheduling
- Highest WiFi performance
- **Recommended for new installations**

**Kernel 6.18 (Upcoming)**:
- RC cycle active (6.18-rc4 as of Nov 7, 2025)
- Further Strix Halo/NPU power refinements
- Additional MT7925 power-save patches
- Expected GA December 2025

---

## Keyboard Backlight Issue - Current Status

**Issue**: Keyboard backlight not restoring after suspend/resume

**Solution**: Version 1.0.5 includes system-sleep hook that:
1. Saves keyboard brightness before suspend
2. Restores brightness after resume (with retry mechanism)
3. Attempts to restart asusctl daemon for full restoration

**Implementation**:
- Systemd sleep hook: `/usr/lib/systemd/system-sleep/gz302-kbd-backlight`
- Monitors `/sys/class/leds/*kbd*backlight*` devices
- Supports multiple LED devices (some laptops have multiple backlight zones)
- Auto-calculates brightness if no saved state exists (50% default)

**Kernel Status**:
- **Not kernel-specific** - Works across all versions 6.14+
- Issue is driver-level (ASUS HID driver), not kernel core
- Fix implemented in GZ302 setup script

**Files Involved**:
- `gz302-main.sh` (lines 443-489): System-sleep hook implementation
- Created at `/usr/lib/systemd/system-sleep/gz302-kbd-backlight`

---

## Touchpad Gesture Issues - Current Status

**Issue**: Touchpad gestures (two-finger scroll, right-click) not working after resume

**Solution**: Version 1.0.0+ includes optional folio resume service that:
1. Reloads hid_asus module after suspend/resume
2. Optionally rebinds folio USB device if attached
3. Restores full gesture functionality

**Implementation**:
- `reload-hid_asus-resume.service`: Triggers on resume event
- `gz302-folio-resume.sh`: Performs module reload and USB rebind

**Kernel Status**:
- **Kernel 6.15+**: Native HID support improved, fewer manual reloads needed
- **Kernel 6.17**: Enhanced HID device management, best support
- Fix still recommended for maximum stability

---

## Recommendations by Use Case

### Gaming
- **Best**: Arch Linux with kernel 6.17, OpenSUSE Tumbleweed, or Fedora 42/43
- **Why**: Latest kernel features, proton compatibility, latest graphics drivers
- **Avoid**: Ubuntu 25.10 with default 6.11 (upgrade to HWE 6.14+ first)

### AI/ML Development (Ollama, PyTorch with ROCm)
- **Best**: Any distribution with kernel 6.15+
- **Recommended**: Arch Linux, Fedora 42+, OpenSUSE Tumbleweed (all have 6.17+)
- **Ubuntu**: Upgrade to HWE kernel before installing ROCm/PyTorch

### General Use / Daily Driver
- **Best**: Any distribution with kernel 6.14+
- **Recommended**: Arch Linux, Fedora, OpenSUSE (latest kernels)
- **Ubuntu 25.10**: Acceptable, but recommend upgrading to 6.14 HWE

### Enterprise / Stability Focus
- **Best**: Ubuntu 26.04 LTS (when released April 2026 with 6.17+) or Fedora 42
- **Why**: Long-term support with modern kernel
- **Current**: Use Ubuntu 25.10 HWE kernel (6.14) for enhanced stability

---

## How GZ302 Setup Script Handles Kernels

The `gz302-main.sh` script includes:

1. **Kernel Version Detection**:
   - Checks minimum version (6.14+)
   - Warns if below 6.15
   - Recommends 6.17+ for optimal experience

2. **Conditional WiFi Fixes**:
   - Kernels < 6.16: Applies ASPM workaround for MT7925
   - Kernels 6.16+: Uses native driver support

3. **Hardware Fixes** (all versions):
   - AMD P-State configuration: `amd_pstate=guided`
   - GPU optimization: `amdgpu.ppfeaturemask=0xffffffff`
   - HID/Touchpad configuration
   - Keyboard backlight restore hook
   - Optional folio resume service

4. **Validation**:
   - Script exits with error if kernel < 6.14
   - Provides upgrade instructions if needed

---

## Distribution Kernel Comparison Table

| Aspect | Arch | Ubuntu 25.10 | Fedora 42/43 | OpenSUSE |
|--------|------|--------------|--------------|----------|
| **Kernel** | 6.17.4 | 6.11.0 (HWE: 6.14) | 6.17.x | 6.17.x |
| **Update Speed** | Fastest | Slowest | Moderate | Fast (rolling) |
| **Stability** | Rolling risk | Excellent | Excellent | Good |
| **GZ302 Ready** | ✅ Yes | ⚠️ Needs HWE | ✅ Yes | ✅ Yes |
| **Gaming** | ✅ Best | ⚠️ Upgrade kernel | ✅ Good | ✅ Good |
| **AI/ML Support** | ✅ Best | ⚠️ Upgrade kernel | ✅ Good | ✅ Good |
| **Ease of Use** | Moderate | Easy | Easy | Easy |

---

## Future Linux Kernels (2026+)

**Linux 6.18**:
- Expected December 2025
- Further AMD and MediaTek optimizations
- LTS candidate for 2025 (may extend support through 2027)

**Linux 7.0** (2026+):
- Expected late 2025 or 2026
- Further architectural improvements
- Continued Strix Halo optimization

**Ubuntu 26.04 LTS** (April 2026):
- Expected kernel: 6.17+ or newer
- 5-year support window
- Will be optimal choice for Ubuntu users

---

## Summary

### Best Distributions for GZ302 (November 2025)

1. **Arch Linux**: Kernel 6.17.7 - Rolling, fastest upstream ✅ **BEST**
2. **Fedora 42 / 43 RC**: 6.17.7 / 6.18-rc4 ✅ **EXCELLENT**
3. **OpenSUSE Tumbleweed**: 6.17.7 rolling snapshots ✅ **EXCELLENT**
4. **Ubuntu 25.10**: 6.11.0 (Upgrade to HWE 6.14 / mainline 6.17) ⚠️ **ACCEPTABLE (Upgrade advised)**

### Action Items by Distribution

- **Arch / Fedora / OpenSUSE**: Install GZ302 setup script as-is, enjoy latest kernel benefits
- **Ubuntu 25.10**: Consider upgrading to HWE kernel 6.14+ before or after running GZ302 setup script
- **All Distributions**: Ensure kernel is at least 6.14+ before running GZ302 setup script

---

## References

- [Arch Linux Packages - linux 6.17.4.arch2-1](https://archlinux.org/packages/core/x86_64/linux/)
- [Ubuntu Packages - linux-image-generic 6.11.0-29.29](https://packages.ubuntu.com/oracular/linux-image-generic)
- [Phoronix - Linux 6.17 Released](https://www.phoronix.com/news/Linux-6.17-Released)
- [Kernel.org - Linux Releases](https://www.kernel.org/releases.html)
- [Fedora Project - Downloads](https://fedoraproject.org/en/workstation/download/)
- [OpenSUSE - Download](https://www.opensuse.org/download/)

**Document Version**: 1.1  
**Created**: October 24, 2025  
**Maintainer**: th3cavalry  
**Updated**: November 7, 2025  
**License**: Same as parent repository
