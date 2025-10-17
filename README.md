# GZ302 Linux Setup

**Modular Linux setup scripts specifically designed for the ASUS ROG Flow Z13 (GZ302) laptop.** Transform your GZ302 into a perfectly optimized Linux powerhouse with automated hardware fixes, intelligent power management, and optional downloadable modules for gaming, AI development, virtualization, and more.

**Supported Models**:
- **GZ302EA-XS99** - 128GB RAM variant
- **GZ302EA-XS64** - 64GB RAM variant
- **GZ302EA-XS32** - 32GB RAM variant

> **🚀 Version 1.0.4 - Stable Release!** Complete hardware support with kernel 6.14+ compatibility, modern `pwrcfg` and `rrcfg` power/display management, and SPL/sPPT/fPPT architecture. Includes fixes for touchpad detection and suspend/resume gestures. Adds optional sudoers NOPASSWD for `pwrcfg`, improved kernel validation, and bug fixes for auto-config and script reruns. **Required: Linux kernel 6.14+ minimum (6.17+ strongly recommended) for AMD XDNA NPU, Strix Halo optimizations, and WiFi stability.**

## ✨ Key Features

### 🔧 **Core Hardware Support** (Always Installed)
- **Automated MediaTek MT7925e Wi-Fi fixes** - Eliminates disconnection issues
- **Complete ASUS touchpad integration** - Full gesture and precision support  
- **Optimized AMD Ryzen AI MAX+ 395 performance** - Unlocks full processor potential
- **Advanced thermal management** - Sustained performance without throttling
- **Power control system (pwrcfg)** - 7 power profiles with SPL/sPPT/fPPT (10W-90W)
- **Display management (rrcfg)** - 7 refresh rate profiles (30Hz-180Hz, auto-sync with power)

### 📦 **Optional Modular Software** (Download On Demand)
Download and install only what you need:

- **🎮 Gaming Module** - Steam, Lutris, MangoHUD, GameMode, Wine
- **🤖 AI/LLM Module** - Ollama, ROCm, PyTorch, Transformers
- **💻 Hypervisor Module** - KVM/QEMU or VirtualBox
- **📸 Snapshots Module** - Automatic system backups with Snapper
- **🔒 Secure Boot Module** - Boot integrity and security tools

### 🎯 **GUI Tools**
- **🖱️ [Tray Icon](tray-icon/)** - System tray utility for quick power profile switching. Now supports password-less sudo for `pwrcfg`, AC/Battery indicators, and autostart.

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
5. Optionally configure password-less `pwrcfg` (no sudo required)

## 🔑 Using `pwrcfg` Without Sudo

After installation, you can enable password-less power profile switching:

**Option 1: During main script installation**
- The setup script will prompt you to enable password-less `pwrcfg`
- Answer 'y' when asked: "Enable password-less pwrcfg (no sudo required) for all users?"

**Option 2: After installation**
```bash
cd tray-icon
sudo ./install-policy.sh
```

Once configured, you can switch power profiles without typing `sudo`:
```bash
pwrcfg battery      # Switch to battery profile
pwrcfg gaming       # Switch to gaming profile
pwrcfg status       # Check current profile
```

**How it works:** `pwrcfg` automatically elevates itself using `sudo -n` when needed. With the sudoers rule installed, no password prompt appears—just instant profile switching.

## 📋 Supported Distributions

All distributions receive identical treatment with equal priority:

- **Arch-based:** Arch Linux, EndeavourOS, Manjaro
- **Debian-based:** Ubuntu, Pop!_OS, Linux Mint  
- **RPM-based:** Fedora, Nobara
- **OpenSUSE:** Tumbleweed and Leap

## 🔧 What Gets Installed (Core Script)

### Hardware Fixes (Always Applied)
Based on latest research from GZ302 community and comprehensive testing:
- **Kernel parameters**: AMD P-State driver (`amd_pstate=guided`) - optimal for Strix Halo (confirmed by benchmarks)
- **GPU optimization**: AMD Radeon 8060S integrated graphics (RDNA 3.5) - full feature mask enabled, ROCm-compatible
- **Wi-Fi stability**: MediaTek MT7925 conditional fixes - automatic ASPM workaround for kernels < 6.15, native support for 6.15+
- **ASUS HID**: Keyboard and touchpad module configuration with mature gesture support
- **Folio Resume Fix**: Automatic reload of HID and USB rebind for folio keyboard/touchpad after suspend/resume (see Issue #83)

**Note:** If your folio keyboard/touchpad does not work after sleep, the setup now includes a resume service that reloads the HID module and attempts to rebind the folio USB device. If you have a custom folio or different vendor/product IDs, update `gz302-folio-resume.sh` accordingly.

**Research Sources**: Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs forums, asus-linux.org, Strix Halo HomeLab, Ubuntu 25.10 benchmarks, Phoronix community

**Kernel Requirements**: 
- **Minimum**: Linux kernel 6.14+ (REQUIRED - AMD XDNA NPU driver, MT7925 WiFi integration, P-State driver)
- **Recommended**: Linux kernel 6.17+ (latest stable) for enhanced Strix Halo performance and GPU scheduling
- **See**: `Info/kernel_changelog.md` for detailed kernel version comparison and GZ302-specific improvements
- **Benefits of 6.14+**: AMD XDNA NPU support, basic MT7925 WiFi stability, AMD P-State dynamic core ranking
- **Benefits of 6.15+**: Cleaner shader support for RDNA 3.5, extended XDNA optimizations
- **Benefits of 6.16+**: Enhanced KVM virtualization, improved GPU context switching, better I/O operations
- **Benefits of 6.17+**: Fine-tuned AI task management, optimized WiFi performance, enhanced GPU scheduling

### ASUS-Specific Packages (Distribution-dependent)
Automated installation from official sources:
- **Arch Linux**: asusctl from G14 repository (https://arch.asus-linux.org) or AUR fallback
- **Ubuntu/Debian**: asusctl from PPA (ppa:mitchellaugustin/asusctl) with rog-control-center
- **Fedora**: asusctl from COPR repository (lukenukem/asus-linux)
- **OpenSUSE**: asusctl from OBS repository (hardware:asus)
- **power-profiles-daemon**: System power management integration
- **switcheroo-control**: Display management

**Features**: Keyboard backlight control, custom fan curves, power profiles, battery charge limits


### Advanced Control Options
- **ec_su_axb35 kernel module** (optional, manual installation): Advanced fan speed and power mode control for Strix Halo
  - Direct fan RPM control with custom curves
  - Power mode switching (balanced 85W, performance 100W, turbo 120W)
  - APU temperature monitoring
  - See: https://github.com/cmetz/ec-su_axb35-linux

### About linux-g14 Kernel (Arch Linux)
The `linux-g14` custom kernel is **optional** for GZ302 users:
- **Not required** with mainline kernel 6.15+ - core hardware support is excellent
- **Still beneficial** for advanced ASUS ROG features: custom fan curves, LED management, enhanced GPU switching
- **Recommendation**: Use mainline kernel 6.17+ for stability, or linux-g14 if you need advanced ROG-specific features
- The G14 repository provides asusctl regardless of which kernel you use
- See: https://asus-linux.org for more information on linux-g14 benefits

### Management Tools (Always Installed)
- **Power Management** (`pwrcfg` command)
  - 7 power profiles with SPL/sPPT/fPPT architecture
  - Emergency: 10/12/12W @ 30Hz - Emergency battery extension
  - Battery: 18/20/20W @ 30Hz - Maximum battery life
  - Efficient: 30/35/35W @ 60Hz - Efficient with good performance
  - Balanced: 40/45/45W @ 90Hz - Balanced performance/efficiency (default)
  - Performance: 55/60/60W @ 120Hz - High performance (AC recommended)
  - Gaming: 70/80/80W @ 180Hz - Gaming optimized (AC required)
  - Maximum: 90/90/90W @ 180Hz - Absolute maximum (AC only)
  - Automatic AC/battery switching
  - Real-time power monitoring
  - Auto-adjusts refresh rate with power profile
  
- **Refresh Rate Control** (`rrcfg` command)
  - 7 refresh rate profiles matched to power profiles (30Hz-180Hz)
  - Automatically syncs when pwrcfg changes power profiles
  - Manual override available for custom configurations
  - VRR/FreeSync support with configurable ranges
  - Multi-monitor independent control
  - Game-specific profiles
  - **Note**: Automatic AC/battery switching is configured via `pwrcfg config` (not `rrcfg`)

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

### Using Power Management
```bash
# Set power profile (automatically adjusts refresh rate)
sudo pwrcfg gaming

# Check current status
sudo pwrcfg status

# List all available profiles
sudo pwrcfg list

# Configure automatic AC/battery switching
sudo pwrcfg config
```

### Using Refresh Rate Control
```bash
# Manually set refresh rate (independent of power profile)
sudo rrcfg gaming

# Check current refresh rate
sudo rrcfg status

# List available profiles
sudo rrcfg list

# Enable VRR/FreeSync
sudo rrcfg vrr on

# Configure game-specific profiles
sudo rrcfg game add steam gaming
```

### Quick Reference
```bash
# View current power and refresh settings
sudo pwrcfg status
sudo rrcfg status

# Enable automatic AC/battery switching (controls both power AND refresh)
sudo pwrcfg config

# List available profiles
pwrcfg list
rrcfg list
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

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development guidelines, testing procedures, and code style requirements.

## 📜 License

This project is provided as-is for the GZ302 community.

## 🙏 Credits

- Author: th3cavalry using GitHub Copilot
- Hardware research: Shahzebqazi's Asus-Z13-Flow-2025-PCMR
- Community testing and feedback

## 📖 Additional Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines and contribution process
- [CHANGELOG.md](Info/CHANGELOG.md) - Version history and release notes
- [Old/ARCHIVED.md](Old/ARCHIVED.md) - Information about legacy scripts (v4.3.1)
- [tray-icon/](tray-icon/) - GUI system tray utility (work in progress)

---

**Last Updated:** October 2024
