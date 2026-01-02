# GZ302 Toolkit

**Performance optimization and convenience toolkit for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into an optimized Linux powerhouse with kernel-aware hardware fixes, intelligent power management, and optional gaming/AI modules.

> **🚀 Version 4.0.0 (Jan 2026)**
> **New Command Center Installer:** One-click setup for Power, RGB, Display, and GUI tools.
> **Refactored Repository:** Organized into `modules/`, `scripts/`, and `gz302-lib/` for clarity.
> **Library-First Architecture:** Modular, testable, maintainable codebase.
> **Kernel-Aware Fixes:** Automatically detects kernel version (6.14-6.18+) and applies only necessary fixes.
> **Obsolescence Cleanup:** Removes outdated workarounds when running on kernel 6.17+ with native support.
> **Kernel Requirement:** Linux 6.14+ required (6.17+ recommended) for full native hardware support.

---

## ⚡ Quick Start

### 1. Command Center Installer (Recommended)

The easiest way to get the full user-facing toolset (Power, RGB, Display, GUI) without the kernel/hardware fixes.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/install-command-center.sh -o install-command-center.sh
chmod +x install-command-center.sh
sudo ./install-command-center.sh
```

**What it installs:**
- **Power Controls (`pwrcfg`)**: TDP and Power Profile management.
- **Display Controls (`rrcfg`)**: Refresh Rate and VRR management.
- **RGB Controls (`gz302-rgb`)**: Keyboard and Lightbar control.
- **Command Center GUI**: System tray application for all the above.

### 2. Full Setup (Hardware Fixes + Tools)

For a fresh installation, this script applies essential kernel/hardware fixes and then installs the tools.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
```

### 3. Minimal Setup (Hardware Fixes Only)

For users who want **only the essential hardware fixes** to make Linux run properly.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh
sudo ./gz302-minimal.sh
```

**Kernel-Aware Intelligence:**
- **Kernel < 6.17:** Applies WiFi workarounds, touchpad fixes, and tablet mode support.
- **Kernel >= 6.17:** Minimal fixes only (most hardware now native) + cleans up obsolete workarounds.
- **All Kernels:** Essential AMD Strix Halo optimizations and kernel parameters.

---

## 🎛️ Control Center: Usage Guide

### 1. GZ302 Control Center (System Tray)

The easiest way to manage your device with a simple tray indicator.

- **Right-click** the tray icon to switch profiles.
- **Visuals:** Checkmarks indicate active profiles; Tooltips show battery % and power draw.
- **Keyboard:** Adjust brightness (0-3) and RGB effects directly from the menu.
- **RGB Controls:** Unified menu for keyboard and rear window lighting.

### 2. Command Line Tools

You can control everything via terminal. If you enabled "password-less sudo" during setup, you do not need to type sudo.

**Power Management (`pwrcfg`)**
```bash
pwrcfg gaming       # Switch to Gaming profile (High Wattage)
pwrcfg battery      # Switch to Battery profile (Low Wattage)
pwrcfg status       # Show current watts, temp, and limits
pwrcfg config       # Enable auto-switching when plugging/unplugging AC
```

**Refresh Rate (`rrcfg`)**
```bash
rrcfg gaming        # Set screen to 180Hz
rrcfg powersave     # Set screen to 30Hz
rrcfg vrr on        # Enable Variable Refresh Rate (FreeSync)
```

**RGB Control (`gz302-rgb`)**
```bash
gz302-rgb static ff0000     # Set keyboard to Red
gz302-rgb breathing 00ff00  # Green breathing animation
gz302-rgb brightness 50     # Set brightness to 50%
```

*Note: RGB settings persist across reboots automatically.*

---

## 📦 Optional Modules

The main script will ask if you want to install these optional modules.

| Module | Description |
|---|---|
| 🎮 **Gaming** | Steam, Lutris, MangoHUD, GameMode, Wine, Discord |
| 🤖 **AI / LLM** | Ollama, LM Studio, llama.cpp, vLLM backends + frontends |
| 💻 **Hypervisor** | KVM/QEMU stack (recommended) or VirtualBox |

---

## 🔄 Repository Evolution: From Hardware Enablement to Optimization Toolkit

**Early 2025 (Kernel 6.14-6.16):** This repository was **essential** - the GZ302 was largely unusable on Linux without extensive workarounds for WiFi, touchpad, tablet mode, and graphics stability.

**Late 2025 (Kernel 6.17+):** The Linux kernel now provides **native GZ302 support**. Most hardware "fixes" are obsolete and can actually harm performance if applied. This repository has evolved into an **optimization and convenience toolkit**.

### What This Means For You

| Your Kernel | Repository Role | What You Need |
|-------------|-----------------|---------------|
| **< 6.14** | ❌ Unsupported | Upgrade kernel first |
| **6.14-6.16** | ✅ Essential | Full hardware workarounds required |
| **6.17-6.18** | ⚠️ Optimization | Minimal fixes + convenience tools |
| **6.19+** | 🎨 Toolkit | Convenience & performance tuning only |

**The scripts automatically detect your kernel version and adapt accordingly.**

---

## 💻 Supported Hardware

| Model | Variant | RAM | Status |
|---|---|---|---|
| GZ302EA-XS99 | Top Spec | 128GB | ✅ Fully Supported |
| GZ302EA-XS64 | Mid Spec | 64GB | ✅ Fully Supported |
| GZ302EA-XS32 | Base Spec | 32GB | ✅ Fully Supported |

---

## 🛠️ Troubleshooting & Advanced

### Uninstallation

To safely remove all components:
```bash
cd Uninstall && sudo ./gz302-uninstall.sh
```

### Advanced Control Options

- **ec_su_axb35 kernel module** (optional, manual): Advanced fan speed and power mode control for Strix Halo.
  - See: https://github.com/cmetz/ec-su_axb35-linux

- **Linux-G14 Kernel** (Arch only): Enhanced ROG laptop support with kernel-level RGB LED control.
  - See: https://asus-linux.org

---

## 📚 Additional Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines and contribution process.
- [Info/CHANGELOG.md](Info/CHANGELOG.md) - Version history and release notes.
- [Info/kernel_changelog.md](Info/kernel_changelog.md) - Detailed kernel version features (6.14-6.18).
- [Info/DISTRIBUTION_KERNEL_STATUS.md](Info/DISTRIBUTION_KERNEL_STATUS.md) - Current kernel versions by distribution.
- [gz302-lib/README.md](gz302-lib/README.md) - V4 library architecture documentation.
- [tray-icon/](tray-icon/) - GZ302 Control Center documentation.

---

## 🏗️ Repository Structure

```
GZ302-Linux-Setup/
├── gz302-main.sh              # Full setup script (Hardware Fixes + Tools)
├── gz302-minimal.sh           # Minimal setup script (Hardware Fixes only)
├── install-command-center.sh  # Command Center installer (Tools only)
├── modules/                   # Optional feature modules
│   ├── gz302-gaming.sh
│   ├── gz302-llm.sh
│   └── gz302-hypervisor.sh
├── scripts/                   # Standalone helper tools
│   ├── gz302-rgb.sh
│   ├── gz302-rgb-install.sh
│   └── ...
├── gz302-lib/                 # Shared libraries
│   ├── utils.sh
│   ├── power-manager.sh
│   ├── display-manager.sh
│   └── ...
├── tray-icon/                 # Command Center GUI
└── Info/                      # Documentation
```

---

## 🤝 Contributing

Open source and community driven.

- **Author:** th3cavalry
- **Research:** Shahzebqazi's Asus-Z13-Flow-PCMR
- **License:** MIT

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

---

**Last Updated:** January 2026 (v4.0.0)
