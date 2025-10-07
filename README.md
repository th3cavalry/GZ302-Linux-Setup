# GZ302 Linux Setup

**Modular Linux setup scripts specifically designed for the ASUS ROG Flow Z13 (GZ302) laptop.** Transform your GZ302 into a perfectly optimized Linux powerhouse with automated hardware fixes, intelligent power management, and optional downloadable modules for gaming, AI development, virtualization, and more.

> **🚀 Version 0.1.0-pre-release - Modular Architecture!** New modular design with a lightweight main script that applies core hardware fixes and downloads optional software modules on demand. Simplified maintenance with bash-only implementation. All distributions have equal priority with identical feature sets.

## ✨ Key Features

### 🔧 **Core Hardware Support** (Always Installed)
- **Automated MediaTek MT7925e Wi-Fi fixes** - Eliminates disconnection issues
- **Complete ASUS touchpad integration** - Full gesture and precision support  
- **Optimized AMD Ryzen AI 395+ performance** - Unlocks full processor potential
- **Advanced thermal management** - Sustained performance without throttling
- **TDP control system** - 7-tier TDP profiles from 10W to 65W
- **Display management** - 6-tier refresh rate profiles from 30Hz to 180Hz

### 📦 **Optional Modular Software** (Download On Demand)
Download and install only what you need:

- **🎮 Gaming Module** - Steam, Lutris, MangoHUD, GameMode, Wine
- **🤖 AI/LLM Module** - Ollama, ROCm, PyTorch, Transformers
- **💻 Hypervisor Module** - KVM/QEMU or VirtualBox
- **📸 Snapshots Module** - Automatic system backups with Snapper
- **🔒 Secure Boot Module** - Boot integrity and security tools

## 🚀 Installation

**Quick Start:**
```bash
# Download and run the main setup script
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
```

The main script will:
1. Detect your Linux distribution automatically
2. Apply all GZ302 hardware fixes
3. Install TDP and refresh rate management
4. Offer optional software modules for download

## 📋 Supported Distributions

All distributions receive identical treatment with equal priority:

- **Arch-based:** Arch Linux, EndeavourOS, Manjaro
- **Debian-based:** Ubuntu, Pop!_OS, Linux Mint  
- **RPM-based:** Fedora, Nobara
- **OpenSUSE:** Tumbleweed and Leap

## 🔧 What Gets Installed (Core Script)

### Hardware Fixes (Always Applied)
Based on latest kernel support and community research:
- **Kernel parameters**: AMD P-State driver (`amd_pstate=active`) for better power management
- **GPU optimization**: Full AMD GPU feature mask for Radeon 890M (RDNA 3.5)
- **Wi-Fi stability**: MediaTek MT7925e fixes (disable ASPM, power save off)
- **ASUS HID**: Keyboard and touchpad module configuration
- **System updates**: Kernel and development tools for your distribution

All fixes are distribution-agnostic and work on kernel 6.8+.

### Management Tools (Always Installed)
- **TDP Management** (`gz302-tdp` command)
  - 7 power profiles: emergency, battery, efficient, balanced, performance, gaming, maximum
  - Automatic AC/battery switching
  - Real-time power monitoring
  
- **Refresh Rate Control** (`gz302-refresh` command)
  - 6 refresh rate profiles: powersave, battery, balanced, smooth, performance, gaming
  - VRR/FreeSync support
  - Multi-monitor independent control

## 📦 Optional Modules

### Gaming Module (`gz302-gaming`)
- Steam with Proton compatibility
- Lutris for GOG, Epic, and other platforms
- MangoHUD for performance overlays
- GameMode for automatic optimizations
- Wine for Windows application support

### AI/LLM Module (`gz302-llm`)
- Ollama for local LLM inference (Llama, Mistral, CodeLlama)
- ROCm for AMD GPU acceleration
- PyTorch with ROCm support
- Transformers and Accelerate libraries

### Hypervisor Module (`gz302-hypervisor`)
- KVM/QEMU with virt-manager (recommended)
- VirtualBox (alternative option)

### Snapshots Module (`gz302-snapshots`)
- Automatic system snapshots
- Btrfs/Snapper integration
- LVM snapshot support

### Secure Boot Module (`gz302-secureboot`)
- Boot integrity tools
- Automatic kernel signing setup

## 🎯 Usage Examples

### Using TDP Management
```bash
# Set TDP profile
sudo gz302-tdp gaming

# Check current status
gz302-tdp status

# Enable automatic AC/battery switching
sudo gz302-tdp auto enable

# List available profiles
gz302-tdp list
```

### Using Refresh Rate Management
```bash
# Set refresh rate profile
sudo gz302-refresh gaming

# Check current status
gz302-refresh status

# Enable VRR/FreeSync
sudo gz302-refresh vrr enable

# Monitor display power
gz302-refresh monitor
```

## �� Architecture

### Modular Design
The new architecture separates concerns:

- **gz302-main.sh** - Core hardware fixes and management tools (always runs)
- **gz302-gaming.sh** - Gaming software (optional, downloaded on demand)
- **gz302-llm.sh** - AI/ML software (optional, downloaded on demand)
- **gz302-hypervisor.sh** - Virtualization (optional, downloaded on demand)
- **gz302-snapshots.sh** - System backups (optional, downloaded on demand)
- **gz302-secureboot.sh** - Secure boot (optional, downloaded on demand)

### Benefits
- **Smaller downloads** - Only get what you need
- **Faster setup** - Core hardware fixes complete in minutes
- **Easy maintenance** - Update individual modules independently
- **Flexibility** - Install optional software at any time

## 📚 Documentation

### TDP Profiles
| Profile | TDP | Use Case |
|---------|-----|----------|
| emergency | 10W | Critical battery preservation |
| battery | 15W | Extended battery life |
| efficient | 20W | Light tasks, good battery |
| balanced | 30W | General computing |
| performance | 45W | Heavy workloads |
| gaming | 54W | Gaming and intensive tasks |
| maximum | 65W | Maximum performance |

### Refresh Rate Profiles
| Profile | Refresh Rate | Use Case |
|---------|--------------|----------|
| powersave | 30Hz | Maximum battery saving |
| battery | 60Hz | Good balance |
| balanced | 90Hz | Smooth general use |
| smooth | 120Hz | Enhanced smoothness |
| performance | 165Hz | High refresh gaming |
| gaming | 180Hz | Maximum gaming performance |

## ⚠️ Important Notes

- **Root privileges required** - Scripts must be run with `sudo`
- **Internet connection needed** - For downloading packages and modules
- **Reboot recommended** - After hardware fixes are applied
- **Backup your data** - Always recommended before system modifications

## 🤝 Contributing

This is an open-source project. Contributions are welcome! Please ensure:
- Bash scripts follow existing style
- All 4 distributions are equally supported
- Changes are tested on target hardware

## 📜 License

This project is provided as-is for the GZ302 community.

## 🙏 Credits

- Author: th3cavalry using GitHub Copilot
- Hardware research: Shahzebqazi's Asus-Z13-Flow-2025-PCMR
- Community testing and feedback

---

**Version:** 0.1.0-pre-release  
**Last Updated:** October 2024
