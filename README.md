# GZ302 Linux Setup

**The ultimate modular Linux suite for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into an optimized Linux powerhouse with automated hardware fixes, intelligent power management, and optional gaming/AI modules.

> **🚀 Version 2.0.0 Update (Nov 2025)**
> **KDE & HandHeld Daemon Sync:** Power profiles now automatically sync with KDE system tray and HHD.
> **Kernel Requirement:** Linux 6.14+ required (6.17+ recommended) for AMD XDNA NPU and Strix Halo optimizations.

---

## ⚡ Quick Start

**One-line installation for all supported distros (Arch, Debian/Ubuntu, Fedora, OpenSUSE):**

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
```

The script will automatically:
- Detect your distro
- Apply core hardware fixes (WiFi, Touchpad, GPU)
- Install Power (pwrcfg) and Refresh Rate (rrcfg) tools
- Ask if you want to install optional modules (Gaming, AI, RGB, etc.)

## 💻 Supported Hardware

| Model | Variant | RAM | Status |
|---|---|---|---|
| GZ302EA-XS99 | Top Spec | 128GB | ✅ Fully Supported |
| GZ302EA-XS64 | Mid Spec | 64GB | ✅ Fully Supported |
| GZ302EA-XS32 | Base Spec | 32GB | ✅ Fully Supported |

## ✨ Features & Modules

This setup is modular. The core script installs essential fixes; everything else is optional.

### 🔧 Core System (Always Installed)

- **WiFi Fixes:** Automated MediaTek MT7925e patches for stability
- **Input:** Complete ASUS touchpad gestures and keyboard integration
- **Performance:** Optimized AMD Ryzen AI MAX+ 395 scheduling
- **Power Management:** 7 custom power profiles (10W - 90W)
- **Display:** 7 refresh rate profiles (30Hz - 180Hz) that auto-sync with power
- **Keyboard Control:** Brightness control (0-3 levels) and RGB lighting

### 📦 Optional Modules (Select during install)

| Module | Description |
|---|---|
| 🎮 Gaming | Steam, Lutris, MangoHUD, GameMode, Wine |
| 🤖 AI / LLM | llama.cpp, ROCm, PyTorch, bitsandbytes, Transformers |
| 🌈 RGB | Advanced keyboard lighting control (Static, Breathing, Rainbow) |
| 💻 Hypervisor | KVM/QEMU stack (recommended) or VirtualBox |
| 📸 Snapshots | Automatic system backups via Snapper/Btrfs |
| 🔒 Secure Boot | Boot integrity and kernel signing tools |

## 🎛️ Control Center: Usage Guide

### 1. System Tray Icon (GUI)

The easiest way to manage your device.

- **Right-click** the tray icon to switch profiles
- **Visuals:** Checkmarks indicate active profiles; Tooltips show battery % and power draw
- **Keyboard:** Adjust brightness (0-3) and RGB effects directly from the menu

**Install Tray Icon manually:**
```bash
cd tray-icon && sudo ./install-tray.sh
```

### 2. Command Line Tools

You can control everything via terminal. If you enabled "password-less sudo" during setup, you do not need to type sudo.

**Power Management (pwrcfg)**
```bash
pwrcfg gaming       # Switch to Gaming profile (High Wattage)
pwrcfg battery      # Switch to Battery profile (Low Wattage)
pwrcfg status       # Show current watts, temp, and limits
pwrcfg config       # Enable auto-switching when plugging/unplugging AC
```

**Refresh Rate (rrcfg)**
```bash
rrcfg gaming        # Set screen to 180Hz
rrcfg powersave     # Set screen to 30Hz
rrcfg vrr on        # Enable Variable Refresh Rate (FreeSync)
```

**RGB Control (gz302-rgb)**
```bash
gz302-rgb static ff0000     # Set keyboard to Red
gz302-rgb breathing 00ff00  # Green breathing animation
gz302-rgb brightness 50     # Set brightness to 50%
```

*Note: RGB settings persist across reboots automatically.*

## 📊 Technical Specifications

### Power Profiles (TDP)

| Profile | TDP | Target Use Case |
|---|---|---|
| Emergency | 10W | Critical battery preservation (30Hz) |
| Battery | 18W | Maximum battery life |
| Efficient | 30W | Light tasks with good performance |
| Balanced | 40W | General computing (Default) |
| Performance | 55W | Heavy workloads (AC Recommended) |
| Gaming | 70W | Optimized for gaming (AC Required) |
| Maximum | 90W | Absolute peak performance (AC Only) |

### Kernel Requirements

- **Minimum:** Linux 6.14+ (Required for NPU & WiFi)
- **Recommended:** Linux 6.17+ (Best for Strix Halo performance)
- See `Info/DISTRIBUTION_KERNEL_STATUS.md` for distro-specific details

### Hardware Specifications

- **Processor:** AMD Ryzen AI MAX+ 395 (Strix Halo) - 16 cores, 32 threads
- **Graphics:** AMD Radeon 8060S (RDNA 3.5 integrated) - 100% AMD, NO discrete GPU
- **WiFi:** MediaTek MT7925 (kernel module: mt7925e)
- **NPU:** AMD XDNA™ up to 50TOPS

## 🛠️ Troubleshooting & Advanced

### Password Prompts

If `pwrcfg` asks for a password, the sudoers file is missing. Run:
```bash
cd tray-icon && sudo ./install-policy.sh
```

### Folio Keyboard Issues

If your keyboard disconnects after sleep, run the specific fix:
```bash
cd Optional && sudo ./gz302-folio-fix.sh
```

### Uninstallation

To safely remove all components:
```bash
cd Uninstall && sudo ./gz302-uninstall.sh
```

### Advanced Control Options

- **ec_su_axb35 kernel module** (optional, manual): Advanced fan speed and power mode control for Strix Halo
  - See: https://github.com/cmetz/ec-su_axb35-linux

- **Linux-G14 Kernel** (optional, Arch only): Enhanced ROG laptop support with kernel-level RGB LED control
  - See: `Optional/gz302-g14-kernel.sh` and https://asus-linux.org

## 📚 Additional Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines and contribution process
- [CHANGELOG.md](Info/CHANGELOG.md) - Version history and release notes
- [Info/kernel_changelog.md](Info/kernel_changelog.md) - Detailed kernel version features (6.14-6.18)
- [Info/DISTRIBUTION_KERNEL_STATUS.md](Info/DISTRIBUTION_KERNEL_STATUS.md) - Current kernel versions by distribution
- [tray-icon/](tray-icon/) - GUI system tray utility documentation

## 🤝 Contributing

Open source and community driven.

- **Author:** th3cavalry
- **Research:** Shahzebqazi's Asus-Z13-Flow-PCMR
- **License:** MIT

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

---

**Last Updated:** November 2025 (v2.0.0)
