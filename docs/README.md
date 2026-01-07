# GZ302 Documentation Hub

**Last Updated:** January 2026  
**Hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS64/XS32)  
**CPU:** AMD Ryzen AI MAX+ 395 (Strix Halo)  
**GPU:** AMD Radeon 8060S (RDNA 3.5, integrated)

---

## 📚 Quick Navigation

| Document | Purpose | Audience |
|----------|---------|----------|
| [Hardware Overview](#hardware-overview) | Device specifications and capabilities | All users |
| [Kernel Compatibility](#kernel-compatibility) | Which kernel version to use | All users |
| [Installation Guide](#installation-guide) | How to install the toolkit | New users |
| [Hardware Components](#hardware-components) | Component-specific documentation | Troubleshooters |
| [Testing & Development](#testing--development) | Testing procedures and contributing | Developers |

---

## Hardware Overview

### Device Specifications

**Model:** ASUS ROG Flow Z13 (2025) - GZ302EA  
**CPU:** AMD Ryzen AI MAX+ 395 (Strix Halo)
- 16 cores / 32 threads
- Zen 5 architecture
- Up to 5.1 GHz boost
- 80MB total cache

**GPU:** AMD Radeon 8060S (Integrated)
- RDNA 3.5 architecture
- 40 Compute Units (2560 stream processors)
- Up to 3.0 GHz
- Shared system memory

**Memory:** 32GB / 64GB / 128GB LPDDR5X-7500  
**Display:** 13.4" 2880x1800 @ 180Hz, VRR support  
**WiFi:** MediaTek MT7925 (WiFi 7 / 802.11be)  
**Audio:** Cirrus Logic CS35L41 (Smart Amp)

### Key Features
- Detachable keyboard (tablet mode support)
- Rear RGB lightbar
- Keyboard RGB backlight
- USB4 ports with DisplayPort Alt Mode
- 100% AMD system (no discrete GPU)

---

## Kernel Compatibility

### Quick Reference

| Kernel Version | Status | Hardware Support | Recommendation |
|---------------|--------|------------------|----------------|
| < 6.14 | ❌ Unsupported | None | Upgrade required |
| 6.14 - 6.16 | ⚠️ Requires fixes | Partial | Use this toolkit |
| 6.17 - 6.18 | ✅ Production ready | Native | Minimal fixes needed |
| 6.19+ | ✅ Optimal | Full native | Optimization only |

### Component Support by Kernel

#### WiFi (MediaTek MT7925)
- **Kernel < 6.17:** Requires `disable_aspm=1` workaround
- **Kernel 6.17+:** Native MLO support, no workaround needed

#### Input Devices (Touchpad, Keyboard, Tablet Mode)
- **Kernel < 6.17:** Requires HID forcing and tablet mode daemon
- **Kernel 6.17+:** Native asus-wmi tablet mode support

#### GPU (AMD Radeon 8060S)
- **All kernels:** Generally works, may need display parameters
- **Critical parameters:**
  - `amdgpu.sg_display=0` - Fixes flickering/white screens
  - `amdgpu.dcdebugmask=0x410` - Mitigates pageflip timeout
  - `amdgpu.ppfeaturemask=0xffffffff` - Enables all PowerPlay features

#### Audio (CS35L41 Smart Amp)
- **All kernels:** Requires SOF (Sound Open Firmware)
- **Status:** Upstream quirk still missing (as of Jan 2026)

### Recommended Kernel Parameters

```bash
# Required for all kernel versions
amd_pstate=guided
amdgpu.ppfeaturemask=0xffffffff
amdgpu.sg_display=0
amdgpu.dcdebugmask=0x410
mem_sleep_default=deep
acpi_osi="Windows 2022"
```

---

## Installation Guide

### Prerequisites
- Linux kernel 6.14+ (6.17+ strongly recommended)
- Root/sudo access
- Internet connection
- One of these distributions:
  - Arch Linux, EndeavourOS, Manjaro, CachyOS
  - Ubuntu, Pop!_OS, Linux Mint
  - Fedora, Nobara
  - OpenSUSE Tumbleweed, Leap

### Installation Modes

#### Full Installation (Recommended)
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh --full
```
**Installs:**
- Hardware fixes (kernel patches, WiFi, GPU, audio)
- Power management (pwrcfg, rrcfg)
- RGB control (gz302-rgb)
- Command Center GUI (system tray)

#### Command Center Only
```bash
sudo ./install.sh --cc
```
**Best for:** Users with kernel 6.17+ who don't need hardware fixes  
**Installs:** Power tools + RGB + GUI only

#### Minimal (Hardware Fixes Only)
```bash
sudo ./install.sh --minimal
```
**Best for:** Servers, headless systems, purists  
**Installs:** Kernel patches and hardware fixes only (no GUI)

---

## Hardware Components

### WiFi (MediaTek MT7925)

**Device ID:** 14c3:0616  
**Features:** WiFi 7 (802.11be), Multi-Link Operation (MLO)

#### Configuration (Kernel < 6.17)
```bash
# /etc/modprobe.d/mt7925.conf
options mt7925e disable_aspm=1
```

#### Configuration (Kernel 6.17+)
No configuration needed - native support is stable.

#### Disable Power Saving
```bash
# /etc/NetworkManager/conf.d/wifi-powersave.conf
[connection]
wifi.powersave = 2
```

---

### GPU (AMD Radeon 8060S)

**Device ID:** 1002:1900  
**Architecture:** RDNA 3.5 (GFX1151)  
**Compute Units:** 40 CUs (2560 stream processors)

#### Known Issues & Solutions

| Issue | Solution | Status |
|-------|----------|--------|
| Pageflip timeout / frozen display | `amdgpu.dcdebugmask=0x410` | Mitigated in 6.17+ |
| Screen flickering | `amdgpu.sg_display=0` | Fixed |
| Wayland KWin freeze | Use X11 or kernel 6.18+ | Improving |

#### ROCm Support
- **Compute Target:** gfx1151 (Strix Halo)
- **ROCm Version:** 6.0+ recommended
- **Environment Variable:** `HSA_OVERRIDE_GFX_VERSION=11.0.0`

---

### Audio (Cirrus Logic CS35L41)

**Amplifiers:** 2x CS35L41 (Smart Amp)  
**Firmware:** Requires SOF (Sound Open Firmware)

#### Installation
SOF firmware is installed automatically by the toolkit.

**Manual installation:**
```bash
# Arch Linux
sudo pacman -S sof-firmware

# Ubuntu/Debian
sudo apt install firmware-sof-signed

# Fedora
sudo dnf install sof-firmware
```

---

### Input Devices

#### Touchpad
- **Type:** I2C HID (ELAN)
- **Kernel < 6.17:** May require forcing via `i2c-dev`
- **Kernel 6.17+:** Native detection

#### Keyboard
- **Type:** USB HID
- **RGB Control:** Custom driver (gz302-rgb)
- **Detection:** Generally works on all kernels

#### Tablet Mode Switch
- **Kernel < 6.17:** Requires custom daemon
- **Kernel 6.17+:** Native asus-wmi support

---

### RGB Control

#### Keyboard RGB
- **Device:** USB HID (vendor-specific protocol)
- **Control:** `gz302-rgb` command-line tool
- **Modes:** Static, breathing, rainbow, reactive
- **Persistence:** Settings saved to `/etc/gz302/rgb-keyboard.conf`

#### Rear Window Lightbar
- **Device:** USB HID (vendor-specific protocol)
- **Control:** `gz302-rgb-window` Python script
- **Zones:** 4 independent zones
- **Persistence:** Settings saved to `/etc/gz302/rgb-window.conf`

**Example usage:**
```bash
# Keyboard - static red
gz302-rgb static ff0000

# Lightbar - zone 1 blue
gz302-rgb-window --lightbar 1 --color 0000ff
```

---

## Power Management

### TDP Profiles (via ryzenadj)

| Profile | TDP | Refresh Rate | Use Case |
|---------|-----|--------------|----------|
| emergency | 10W | 30Hz | Critical battery |
| battery | 18W | 30Hz | Extended battery life |
| efficient | 30W | 60Hz | Normal office work |
| balanced | 40W | 90Hz | General use |
| performance | 55W | 120Hz | Heavy workloads |
| gaming | 70W | 180Hz | Gaming |
| maximum | 90W | 180Hz | Maximum performance |

### Command-Line Tools

```bash
# Check current power profile
pwrcfg status

# Set power profile
pwrcfg gaming

# Auto-switch based on AC/battery
pwrcfg auto

# Check refresh rate
rrcfg status

# Set refresh rate
rrcfg 120

# Enable VRR (Variable Refresh Rate)
rrcfg vrr
```

---

## Testing & Development

### Syntax Validation
```bash
# Validate all scripts
bash -n install.sh
for lib in gz302-lib/*.sh; do bash -n "$lib"; done
```

### ShellCheck Linting
```bash
shellcheck install.sh
shellcheck gz302-lib/*.sh
```

### Testing Checklist

#### Hardware Detection
- [ ] WiFi controller detected (`lspci | grep MT7925`)
- [ ] GPU detected (`lspci | grep Radeon`)
- [ ] Audio amplifiers detected (`dmesg | grep CS35L41`)
- [ ] HID devices detected (`lsusb | grep ASUS`)

#### Functionality Tests
- [ ] WiFi connects and remains stable
- [ ] Display works without flickering
- [ ] Audio playback works
- [ ] Touchpad and keyboard responsive
- [ ] Tablet mode switch detected
- [ ] RGB control works
- [ ] Power profiles apply correctly
- [ ] Refresh rate changes work

#### System Tests
- [ ] Suspend/resume works
- [ ] AC plug/unplug transitions smoothly
- [ ] Display output to external monitor
- [ ] Multi-monitor setup works

---

## Distribution-Specific Notes

### Arch Linux
- Use `linux` or `linux-zen` kernel
- Install from official repos
- AUR packages available for optional modules

### Ubuntu 24.04 LTS
- Use HWE kernel for 6.14+
- Install command: `sudo apt install linux-generic-hwe-24.04`
- SOF firmware in universe repository

### Fedora 40+
- Kernel 6.14+ in default repos
- Enable RPM Fusion for additional packages
- SOF firmware included by default

### OpenSUSE Tumbleweed
- Rolling release with latest kernels
- All dependencies in official repos
- Use `zypper` for package management

---

## Common Issues & Solutions

### Issue: WiFi Disconnects Frequently
**Solution:**
1. Check kernel version: `uname -r`
2. If < 6.17: Apply ASPM workaround (`disable_aspm=1`)
3. Disable power saving: Set `wifi.powersave = 2` in NetworkManager

### Issue: Display Freezes on Login
**Solution:**
1. Add kernel parameter: `amdgpu.dcdebugmask=0x410`
2. Consider using X11 instead of Wayland
3. Upgrade to kernel 6.18+ for better stability

### Issue: No Audio Output
**Solution:**
1. Install SOF firmware: `sudo pacman -S sof-firmware`
2. Reboot system
3. Check ALSA devices: `aplay -l`

### Issue: Touchpad Not Detected
**Solution:**
1. Check kernel version
2. If < 6.17: Apply input forcing workaround
3. Verify I2C modules loaded: `lsmod | grep i2c`

### Issue: Power Profile Not Persisting
**Solution:**
1. Check ryzenadj installed: `which ryzenadj`
2. Verify service running: `systemctl status pwrcfg-monitor.service`
3. Check logs: `journalctl -u pwrcfg-monitor.service`

---

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the root directory.

---

## Additional Resources

- **Official Repository:** https://github.com/th3cavalry/GZ302-Linux-Setup
- **ASUS Linux Community:** https://asus-linux.org
- **AMD GPU Documentation:** https://wiki.archlinux.org/title/AMDGPU
- **Kernel Documentation:** https://www.kernel.org/doc/html/latest/

---

**License:** MIT  
**Maintained by:** th3cavalry  
**Community:** ASUS Linux enthusiasts, Strix Halo early adopters
