# Strix Halo & Radeon 8060S Linux Research (November 2025)

This document consolidates extensive research on Linux support for the ASUS ROG Flow Z13 (GZ302EA) with AMD Ryzen AI MAX+ 395 (Strix Halo) and integrated Radeon 8060S GPU.

## Executive Summary

**Minimum Kernel**: 6.12 (Strix Halo Zen 5 + RDNA 3.5 GPU baseline support)
**Recommended**: 6.17+ (MediaTek MT7925 MLO fixes, Display Core stabilization)
**Optimal**: 6.20+ (Latest DC fixes, Wayland improvements, RDNA 3.5 optimizations)

---

## Kernel Version Breakdown

### Kernel 6.12 (Minimum - Strix Halo Support)
- **Released**: January 2025
- **Features**:
  - Strix Halo (Zen 5) CPU architecture support
  - RDNA 3.5 GPU driver (Radeon 8060S)
  - AMD XDNA NPU driver (Ryzen AI MAX+ 395)
  - MediaTek MT7925 WiFi driver (WiFi 7 baseline)
  - AMD P-State with Strix Halo optimizations

### Kernel 6.17+ (Recommended - Full Stability)
- **Released**: September 2025
- **Major Fixes**:
  - MediaTek MT7925: Full MLO (Multi-Link Operation) support, ASPM fixes, firmware stability
  - AMD GPU Display Core: Stabilization patches, pageflip timeout mitigations
  - Wayland/KWin: Pageflip handling improvements
  - AMD P-State: Refined power management for Strix Halo

### Kernel 6.20+ (Optimal - Latest Optimizations)
- **Expected**: Late 2025 / Early 2026
- **Improvements**:
  - RDNA 3.5 shader compiler optimizations
  - Wayland freezing fixes (from diagnostic history)
  - Additional Display Core (DC) patches
  - Strix Halo power efficiency enhancements

---

## AMD GPU (Radeon 8060S RDNA 3.5) Configuration

### Recommended Kernel Parameters

```bash
amdgpu.modeset=1                    # Enable KMS
amd_pstate=guided                    # Strix Halo power management
amdgpu.ppfeaturemask=0xffffffff    # Enable all PowerPlay features
amdgpu.sg_display=0                 # Fix flickering/white screens (CRITICAL)
amdgpu.dcdebugmask=0x10             # Display Core debug (baseline; 0x410 as variant)
```

### Display Core (DC) Fixes

**Known Issues & Workarounds**:
| Issue | Workaround | Status |
|-------|-----------|--------|
| Pageflip timeout / Frozen display | amdgpu.dcdebugmask=0x10 or use X11 | Fixed in 6.17+ |
| Wayland KWin freeze | amdgpu.sg_display=0 | Mitigated; kernel 6.20+ improves |
| Screen flickering | amdgpu.sg_display=0 | Fixed upstream |
| Washed-out colors | amdgpu.abmlevel=0 | Optional workaround |

---

## MediaTek MT7925 WiFi

### Configuration

```bash
# For kernel < 6.17 (ASPM workaround needed)
options mt7925e disable_aspm=1

# Not needed for kernel 6.17+
```

**Recent Fixes (6.17+)**:
- Full MLO (Multi-Link Operation) support
- ASPM (Active State Power Management) fixes
- Firmware stability improvements

---

## Strix Halo Power Management

### TDP Profiles (via ryzenadj)
```
emergency:   10W (30Hz)
battery:     18W (30Hz)
efficient:   30W (60Hz)
balanced:    40W (90Hz)
performance: 55W (120Hz)
gaming:      70W (180Hz)
maximum:     90W (180Hz)
```

---

## System Freeze/Pageflip Timeout Analysis

### Issue (GZ302 - Nov 30, 2025)
- **Symptom**: Frozen display after KDE Plasma login in Wayland
- **Duration**: ~1 min; recovers after sleep/wake
- **Root Cause**: AMD GPU pageflip timeout (Display Core issue)
- **Parameters Before Incident**: `amdgpu.dcdebugmask=0x410 amdgpu.sg_display=0`

### Diagnosis
- Kernel 6.17+ includes DC fixes that help with pageflip handling
- Consider upgrading to 6.20+ for latest improvements
- Alternative: Use X11 if Wayland remains unstable

---

## Distribution-Specific (Late 2025)

**Arch**: linux-zen 6.12+ (recommended)
**Ubuntu 24.04**: Use HWE kernel for 6.12+ support
**Fedora 41-42**: 6.12+ by default
**OpenSUSE Tumbleweed**: Always current (6.14+)

---

**Last Updated**: November 30, 2025
**Sources**: Kernel changelogs, asus-linux.org, Reddit forums, GitHub issues, community research
