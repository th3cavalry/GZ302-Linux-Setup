# GZ302 Linux Toolkit

![Version](https://img.shields.io/badge/version-5.0.2-blue?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Kernel-6.14%2B-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Device-ASUS%20ROG%20Flow%20Z13-red?style=for-the-badge)

**Linux optimization suite for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.**

Hardware fixes, power/TDP management, RGB lighting, fan curves, battery limiting, and a system tray GUI — powered by [z13ctl](https://github.com/dahui/z13ctl).

---

## Installation

One script handles everything. Pick which sections to install interactively:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh -o gz302-setup.sh
chmod +x gz302-setup.sh
sudo ./gz302-setup.sh
```

The installer prompts for four sections:

| Section | What it does |
| :--- | :--- |
| **1. Hardware Fixes** | WiFi (MT7925), GPU (Radeon 8060S), Input, Audio (SOF/CS35L41), OLED PSR-SU fix, Suspend fix |
| **2. z13ctl** | RGB lighting, power profiles, TDP, fan curves, battery charge limit, undervolt, sleep recovery |
| **3. Display & Tools** | Refresh rate control (rrcfg), system tray app |
| **4. Optional Modules** | Gaming (Steam, Lutris, MangoHUD), AI/LLM (Ollama, ROCm), Hypervisor (KVM/QEMU) |

### CLI Flags

```bash
sudo ./gz302-setup.sh -y              # Accept all defaults (non-interactive)
sudo ./gz302-setup.sh --fixes-only    # Hardware fixes only
sudo ./gz302-setup.sh --no-z13ctl     # Skip z13ctl installation
sudo ./gz302-setup.sh --help          # Show all options
```

---

## Quick Start (after installation)

```bash
# RGB lighting
z13ctl apply --color cyan --brightness high
z13ctl apply --mode rainbow --speed normal
z13ctl off

# Power profiles
z13ctl profile --set balanced
z13ctl tdp --set 50

# Battery
z13ctl batterylimit --set 80

# Fan curves (8-point, temp:pwm pairs)
z13ctl fancurve --set "48:2,53:22,57:30,60:43,63:56,65:68,70:89,76:102"

# Status
z13ctl status
```

### Backward-Compatible Wrappers

The installer creates `pwrcfg` and `gz302-rgb` wrappers that map to z13ctl:

| Command | Maps to |
| :--- | :--- |
| `pwrcfg balanced` | `z13ctl profile --set balanced` |
| `pwrcfg tdp --set 50` | `z13ctl tdp --set 50` |
| `gz302-rgb static red` | `z13ctl apply --mode static --color red` |
| `gz302-rgb rainbow` | `z13ctl apply --mode rainbow` |

---

## System Tray App

After installation, look for **"GZ302 Control Center"** in your system tray.

- **Right-click:** Quick profile switching (Quiet, Balanced, Performance)
- **Middle-click:** Toggle RGB on/off
- **Hover:** Real-time power and battery status

---

## Kernel Compatibility

The scripts automatically detect your kernel and adapt:

| Kernel | Status |
| :--- | :--- |
| **< 6.14** | Unsupported — please upgrade |
| **6.14 – 6.16** | Applies workarounds for WiFi (MT7925), Touchpad, Tablet mode |
| **6.17+** | Native support — cleans up obsolete fixes, focuses on tuning |

---

## Display Fixes

### OLED Display Artifacts

**Issue:** Purple/green color artifacts during scrolling, intermittent corruption during idle, or color-shift fringing on the built-in OLED panel (not external monitors).
**Cause:** Multiple DC power-save features active on the internal eDP panel: PSR, PSR-SU, Panel Replay (DCN 3.5 / Strix Halo), IPS (Idle Power Save), DRAM stutter, and scatter-gather display on APU. ABM (Adaptive Backlight Management) also causes colour-shift artifacts on OLED.
**Fix:** `amdgpu.dcdebugmask=0xe12` + modprobe options `abmlevel=0` and `sg_display=0` — applied automatically by the installer.

---

## Repository Structure

```
GZ302-Linux-Setup/
├── gz302-setup.sh             # Unified installer (single entry point)
├── gz302-lib/                 # Core libraries (manager-based)
│   ├── utils.sh               # Shared utilities, logging, backups
│   ├── kernel-compat.sh       # Kernel version detection
│   ├── wifi-manager.sh        # MediaTek MT7925 configuration
│   ├── gpu-manager.sh         # AMD Radeon 8060S / amdgpu
│   ├── audio-manager.sh       # SOF firmware, CS35L41 amp
│   ├── input-manager.sh       # Keyboard, touchpad, tablet mode
│   ├── display-fix.sh         # OLED PSR-SU fix
│   ├── display-manager.sh     # Refresh rate profiles, VRR
│   ├── distro-manager.sh      # Distribution-specific orchestration
│   └── state-manager.sh       # Persistent state tracking
├── modules/                   # Optional feature packs
│   ├── gz302-gaming.sh        # Steam, Lutris, MangoHUD, GameMode
│   ├── gz302-llm.sh           # Ollama, ROCm, PyTorch
│   └── gz302-hypervisor.sh    # KVM/QEMU, libvirt
├── scripts/                   # System scripts
│   ├── fix-suspend.sh         # Suspend/resume fix
│   └── uninstall/             # Cleanup utility
├── tray-icon/                 # PyQt6 system tray application
│   └── src/
│       ├── gz302_tray.py
│       └── modules/           # power, RGB, config, notifications
└── docs/                      # Hardware research, changelog
```

---

## Credits

- **[z13ctl](https://github.com/dahui/z13ctl)** by Jeff Hagadorn — RGB lighting, power profiles, TDP, fan curves, battery limit, and daemon. The hardware control backend that makes this all possible.
- **[g-helper](https://github.com/seerge/g-helper)** by seerge — Protocol reverse-engineering reference for ASUS HID devices.
- **[Strix-Halo-Control](https://github.com/TechnoDaimon/Strix-Halo-Control)** by TechnoDaimon — GTK4 GUI inspiration for z13ctl integration.

---

## Uninstall

```bash
sudo bash scripts/uninstall/gz302-uninstall.sh
```

This removes all GZ302 tools, z13ctl daemon/config, systemd services, udev rules, and configuration files.

---

## Contributing & Support

- **Documentation:** See the [docs/](docs/) directory for hardware research and testing guides.
- **Issues:** Report bugs on the [Issues page](https://github.com/th3cavalry/GZ302-Linux-Setup/issues).
- **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md).

**License:** MIT
**Maintained by:** th3cavalry

