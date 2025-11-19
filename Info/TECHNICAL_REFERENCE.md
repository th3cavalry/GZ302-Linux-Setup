# GZ302 Technical Reference

Quick reference for technical details and kernel requirements.

## Hardware Specifications

**ASUS ROG Flow Z13 (GZ302EA)**
- CPU: AMD Ryzen AI MAX+ 395 (Strix Halo) - 16C/32T, 3.0-5.1 GHz
- GPU: AMD Radeon 8060S (RDNA 3.5 integrated, 100% AMD)
- NPU: AMD XDNA up to 50 TOPS
- WiFi: MediaTek MT7925 (mt7925e module)
- Display: 13" touchscreen, 180Hz max
- Memory: 32GB / 64GB / 128GB variants

## Kernel Requirements

**Minimum:** Linux 6.14+
- XDNA NPU driver support
- Native MT7925 WiFi stability
- Basic Strix Halo optimizations

**Recommended:** Linux 6.17+
- Enhanced GPU scheduling
- Improved power management
- Better WiFi throughput

**Development:** Linux 6.18+ (Dec 2025)
- AMD Secure AVIC
- Further power optimizations

## Distribution Kernel Status (Nov 2025)

| Distribution | Kernel | Support |
|--------------|--------|---------|
| Arch Linux | 6.17.7 | ✅ Excellent |
| Fedora 42 | 6.17.7 | ✅ Excellent |
| OpenSUSE Tumbleweed | 6.17.7 | ✅ Excellent |
| Ubuntu 25.10 | 6.11.0 (HWE: 6.14+) | ⚠️ Upgrade Recommended |

## Kernel Parameters

Required for optimal performance:
```
amd_pstate=guided
amdgpu.ppfeaturemask=0xffffffff
```

Optional (if WiFi issues on kernel < 6.15):
```
mt7925e.disable_aspm=1
```

## Power Profiles

| Profile | TDP | SPL | sPPT | fPPT | Use Case |
|---------|-----|-----|------|------|----------|
| Emergency | 10W | 10W | 10W | 10W | Critical battery |
| Battery | 18W | 18W | 18W | 25W | Max battery life |
| Efficient | 30W | 30W | 35W | 40W | Light tasks |
| Balanced | 40W | 40W | 48W | 54W | General use (default) |
| Performance | 55W | 55W | 65W | 75W | Heavy workloads |
| Gaming | 70W | 70W | 85W | 90W | Gaming |
| Maximum | 90W | 90W | 105W | 120W | Peak performance |

SPL = Sustained Power Limit, sPPT = Slow Package Power Tracking, fPPT = Fast Package Power Tracking

## Refresh Rate Profiles

Auto-synced with power profiles:
- Emergency: 30Hz
- Battery/Efficient: 60Hz
- Balanced: 120Hz
- Performance/Gaming/Maximum: 180Hz

Manual override: `rrcfg <profile>` or `rrcfg <30|60|90|120|144|165|180>`

## Module Dependencies

**Gaming Module:**
- Steam, Lutris, MangoHUD, GameMode
- Wine/Proton, vkBasalt
- Distribution-specific gaming repos

**AI/LLM Module:**
- llama.cpp (with ROCm/HIP, gfx1151)
- PyTorch with ROCm 5.7
- transformers, accelerate, bitsandbytes

**RGB Module:**
- libusb-1.0
- Compiled C binary for keyboard control

**Hypervisor Module:**
- KVM/QEMU (recommended) or VirtualBox
- virt-manager, libvirt

**Snapshots Module:**
- Snapper with Btrfs/ext4
- grub-btrfs (Arch) or related tools

**Secure Boot Module:**
- sbctl (Arch) or shim-signed (Debian/Ubuntu)
- mokutil, keyutils

## Advanced Configuration

### Optional: ec_su_axb35 Kernel Module
Advanced fan and power mode control for Strix Halo.
See: https://github.com/cmetz/ec-su_axb35-linux

### Optional: Linux-G14 Kernel (Arch)
ASUS-optimized kernel with enhanced ROG support.
Install via: `Optional/gz302-g14-kernel.sh`

## Known Issues

**Ubuntu 25.10 (Oracular):**
- asusctl PPA unavailable (404 for "questing" codename)
- Workaround: Manual battery charge limit or wait for PPA update

**Folio Keyboard:**
- May disconnect after sleep on some systems
- Fix: `Optional/gz302-folio-fix.sh`

## Troubleshooting Commands

```bash
# Check kernel version
uname -r

# Check AMD P-State status
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check GPU features
cat /sys/class/drm/card*/device/pp_features

# Check WiFi module
lsmod | grep mt7925

# Check power draw
cat /sys/class/power_supply/BAT*/power_now

# Check current TDP (if ryzenadj installed)
ryzenadj -i
```

---

**Last Updated:** November 2025
**Version:** 2.0.0
