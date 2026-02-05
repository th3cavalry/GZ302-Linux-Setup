# GZ302 Kernel Support Guide

**Target Hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS98/XS96) with AMD Ryzen AI MAX+ 395  
**Last Updated:** January 2026  
**Kernel Range:** 6.14 - 6.18+

---

## Quick Reference

### Check Your Kernel
```bash
uname -r  # Example: 6.17.7-arch1-1
```

### Support Level by Version

| Kernel | Status | Required Fixes |
|--------|--------|----------------|
| < 6.14 | ❌ Unsupported | Upgrade required |
| 6.14-6.15 | ⚠️ Early | All hardware fixes needed |
| 6.16 | ⚠️ Maturing | Most fixes needed |
| 6.17+ | ✅ Production | Audio quirk only + optimizations |

---

## Component Compatibility Matrix

### Hardware Fixes

| Component | 6.14-6.15 | 6.16 | 6.17+ | Notes |
|-----------|-----------|------|-------|-------|
| WiFi (MT7925) | ✅ Required | ✅ Required | ❌ Native | ASPM workaround obsolete |
| Tablet Mode | ✅ Required | ✅ Required | ❌ Native | SW_TABLET_MODE in kernel |
| Input/Touchpad | ✅ Required | ⚠️ Optional | ❌ Native | hid_asus reliable |
| Audio (CS35L41) | ✅ Required | ✅ Required | ✅ Required | Quirk not upstream yet |
| GPU Stability | ✅ Required | ❌ Native | ❌ Native | Stable in 6.16+ |

### Userspace Tools (All Kernels)

| Tool | Purpose | Necessity |
|------|---------|-----------|
| pwrcfg | TDP profile management | Optional (convenience) |
| rrcfg | Display refresh control | Optional (convenience) |
| gz302-rgb | Keyboard backlight | Optional (convenience) |

---

## Distribution Status

| Distribution | Kernel | GZ302 Ready |
|--------------|--------|-------------|
| **Arch Linux** | 6.17+ | ✅ Excellent |
| **CachyOS** | 6.18+ | ✅ Excellent |
| **Fedora 43** | 6.17+ | ✅ Excellent |
| **OpenSUSE TW** | 6.17+ | ✅ Excellent |
| **Ubuntu 24.04** | 6.14 | ⚠️ Upgrade to HWE |
| **Ubuntu 25.10** | 6.17 | ✅ Excellent |

### Ubuntu Kernel Upgrade
```bash
sudo apt-get update
sudo apt-get install linux-generic-hwe-24.04  # Gets 6.17+
```

---

## Kernel 6.17+ Configuration

### Required Kernel Parameters
```
amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff
```

### AI/LLM Workloads (Optional)
```
amdgpu.gttsize=131072 amd_iommu=off
```

### What Works Natively
- ✅ WiFi with power saving
- ✅ Tablet mode detection
- ✅ Touchpad/keyboard
- ✅ GPU stability
- ✅ Accelerometer orientation

### What Still Needs Fixes
- ⚠️ Audio (CS35L41 quirk)

---

## Migration from Pre-6.17

If you installed GZ302 setup before kernel 6.17, remove obsolete components:

```bash
# Check kernel version
uname -r

# If >= 6.17, clean up:
sudo rm -f /etc/modprobe.d/mt7925.conf
sudo systemctl disable --now gz302-tablet.service 2>/dev/null
sudo sed -i '/enable_touchpad=1/d' /etc/modprobe.d/hid-asus.conf

# Reload modules
sudo modprobe -r mt7925e && sudo modprobe mt7925e
sudo modprobe -r hid_asus && sudo modprobe hid_asus
```

---

## Troubleshooting

| Symptom | Kernel < 6.17 | Kernel 6.17+ |
|---------|---------------|--------------|
| WiFi drops | Apply ASPM workaround | Update linux-firmware |
| No rotation | Install tablet daemon | Check DE support |
| No touchpad | Apply input forcing | Reload hid_asus |
| No audio | Apply audio quirk | Apply audio quirk |
| GPU crashes | Apply GTT fix | Should be stable |

---

## Hardware Feature Support by Kernel

| Feature | 6.14 | 6.15 | 6.16 | 6.17+ |
|---------|------|------|------|-------|
| AMD XDNA NPU | Basic | Extended | Enhanced | Optimized |
| AMD P-State | ✅ | ✅ | ✅ | ✅ |
| MT7925 WiFi | ⚠️ Workaround | Native | Native | Optimized |
| Radeon 8060S | Basic | Enhanced | Better | Optimized |
| Power Mgmt | ✅ | ✅ | ✅ | ✅ Fine-grain |

---

## References

- [Kernel.org Releases](https://www.kernel.org/releases.html)
- [ASUS Linux Community](https://asus-linux.org)
- [GZ302 Repository](https://github.com/th3cavalry/GZ302-Linux-Setup)
