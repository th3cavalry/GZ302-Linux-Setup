# GZ302 Linux Setup

**Modular Linux setup scripts specifically designed for the ASUS ROG Flow Z13 (GZ302) laptop.** Transform your GZ302 into a perfectly optimized Linux powerhouse with automated hardware fixes, intelligent power management, and optional downloadable modules for gaming, AI development, virtualization, and more.

**Supported Models**:
- **GZ302EA-XS99** - 128GB RAM variant
- **GZ302EA-XS64** - 64GB RAM variant
- **GZ302EA-XS32** - 32GB RAM variant

> **🚀 Version 1.2.1 - Tray Icon Integration (November 2025)!** Keyboard backlight and RGB color control now unified in the system tray icon for seamless GUI control. Physical FN+F11 button support for brightness cycling. **Required: Linux kernel 6.14+ minimum (6.17+ strongly recommended) for AMD XDNA NPU, Strix Halo optimizations, and WiFi stability.**

## ✨ Key Features

### 🔧 **Core Hardware Support** (Always Installed)
- **Automated MediaTek MT7925e Wi-Fi fixes** - Eliminates disconnection issues
- **Complete ASUS touchpad integration** - Full gesture and precision support  
- **Optimized AMD Ryzen AI MAX+ 395 performance** - Unlocks full processor potential
- **Advanced thermal management** - Sustained performance without throttling
- **Power control system (pwrcfg)** - 7 power profiles with SPL/sPPT/fPPT (10W-90W)
- **Display management (rrcfg)** - 7 refresh rate profiles (30Hz-180Hz, auto-sync with power)
- **Keyboard backlight control** - Brightness control (0-3 levels) via system tray icon

### 📦 **Optional Modular Software** (Download On Demand)
Download and install only what you need:

- **🎮 Gaming Module** - Steam, Lutris, MangoHUD, GameMode, Wine
- **🤖 AI/LLM Module** - Ollama, ROCm, PyTorch, MIOpen, bitsandbytes, Transformers
- **💻 Hypervisor Module** - KVM/QEMU or VirtualBox
- **📸 Snapshots Module** - Automatic system backups with Snapper
- **🔒 Secure Boot Module** - Boot integrity and security tools

### 🎯 **GUI Tools**
- **🖱️ [Tray Icon](tray-icon/)** - System tray utility for quick power profile switching and keyboard RGB/brightness control. Supports password-less sudo for `pwrcfg`, AC/Battery indicators, and autostart.

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
# Switch to battery profile
pwrcfg battery
# Switch to gaming profile
pwrcfg gaming
# Check current profile
pwrcfg status
# List all available profiles
pwrcfg list
# Configure automatic AC/battery switching
pwrcfg config
```

**How it works:** `pwrcfg` automatically elevates itself using `sudo -n` when needed. With the sudoers rule installed, no password prompt appears—just instant profile switching. If password-less sudo is not configured, use `sudo pwrcfg ...` instead.

## 🌈 Keyboard Backlight Control

### Important: GZ302 Hardware Limitations

The ASUS ROG Flow Z13 (GZ302) **only supports keyboard backlight brightness control** (levels 0-3). RGB color and effect controls are **not available** on this model due to hardware limitations (missing Aura LED interface on the keyboard).

- ✅ **Brightness**: Off, Level 1, Level 2, Level 3 (fully supported)
- ❌ **RGB Colors**: Not supported by GZ302 hardware
- ❌ **Effects**: Not supported by GZ302 hardware

### Tray Icon Control (Recommended)

The GZ302 system tray icon provides the easiest way to control keyboard brightness:

**Menu Structure:**
```
Keyboard Backlight
└── Brightness (Off, Level 1, Level 2, Level 3)
```

Simply right-click the tray icon → **Keyboard Backlight** → Choose your brightness level.

**Installation:**
```bash
cd tray-icon
sudo ./install-tray.sh
```

The tray icon will appear in your system tray after installation and will start automatically on login.

### Physical FN+F11 Button Support

The keyboard backlight listener daemon (`gz302-kbd-backlight-listener`) monitors ASUS function key events and automatically cycles keyboard backlight brightness when you press **FN+F11**.

**Features:**
- ✅ **Physical Button Support**: Press FN+F11 to cycle brightness levels
- ✅ **Auto Cycling**: 0 (Off) → 1 → 2 → 3 → 0 (repeats)
- ✅ **Systemd Integration**: Runs as background service
- ✅ **Syslog Logging**: All events logged to systemd journal

**Usage:**
```bash
# Press FN+F11 to cycle: Off → Level 1 → Level 2 → Level 3 → Off (repeats)

# Check service status
systemctl status gz302-kbd-backlight-listener

# View real-time logs
journalctl -u gz302-kbd-backlight-listener -f

# Enable/Disable the service
sudo systemctl enable gz302-kbd-backlight-listener
sudo systemctl start gz302-kbd-backlight-listener
```

### Technical Details

**Brightness Control:**
Brightness changes use `/sys/class/leds/*::kbd_backlight/brightness` and may prompt for sudo if passwordless access is not configured. See the [ArchWiki keyboard backlight guide](https://wiki.archlinux.org/title/Keyboard_backlight) for details.
sudo ./gz302-main.sh

# For Arch-based systems
sudo pacman -S asusctl

# For Debian/Ubuntu
sudo add-apt-repository ppa:asus-linux/ppa
sudo apt update && sudo apt install asusctl

# For Fedora
sudo dnf install asusctl
```

**Colors not changing:**
```bash
# Check asusctl service
sudo systemctl status asusd

# Restart asusctl service
sudo systemctl restart asusd

# Check hardware support
asusctl led-mode

# Try setting color directly
sudo asusctl led-mode static -c ff0000
```

### Rear Window RGB LEDs

**Status:** Rear window RGB LED control is **NOT supported on Linux** for the GZ302.

**Research Findings:**
- Limited Linux support - only ON/OFF toggle may be available on some models
- Full color control requires Windows + Armoury Crate
- The rear window LEDs use a separate controller with incomplete Linux kernel drivers
- Community issue tracking: [GitLab #681](https://gitlab.com/asus-linux/asusctl/-/issues/681)
- Phoronix article: [ASUS Z13 RGB improvements](https://www.phoronix.com/news/ASUS-Z13-ROG-Ally-RGB)

**Contributing:** If you have hardware expertise, see [asusctl GitLab](https://gitlab.com/asus-linux/asusctl) and [ASUS Linux Community](https://asus-linux.org)

## 📋 Supported Distributions

All distributions receive identical treatment with equal priority:

- **Arch-based:** Arch Linux, CachyOS, EndeavourOS, Manjaro
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

**Research Sources**: Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs forums, asus-linux.org, Strix Halo HomeLab, Ubuntu 25.10 benchmarks, Phoronix community

**Kernel Requirements**: 
- **Minimum**: Linux kernel 6.14+ (REQUIRED - AMD XDNA NPU driver, MT7925 WiFi integration, P-State driver)
- **Recommended**: Linux kernel 6.17+ (latest stable) for enhanced Strix Halo performance and GPU scheduling
- **Documentation**:
  - `Info/kernel_changelog.md` - Detailed kernel version features (6.14-6.18)
  - `Info/DISTRIBUTION_KERNEL_STATUS.md` - **NEW** Current kernel versions by distribution (Arch, Ubuntu, Fedora, OpenSUSE)
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
- ROCm for AMD GPU acceleration (gfx1151 support)
- PyTorch with ROCm backend
- MIOpen deep learning primitives library
- bitsandbytes for 8-bit quantization
- Transformers and Accelerate libraries
- Optional AI frontends (LocalAI, ComfyUI, text-generation-webui, etc.)

### Hypervisor Module (`gz302-hypervisor`)
- **Full KVM/QEMU Stack** (Recommended)
  - Complete QEMU virtualization system with hardware acceleration
  - libvirt daemon for VM management
  - virt-manager GUI and virsh CLI tools
  - UEFI/OVMF firmware support for modern guest OSes
  - Automatic default NAT network configuration
  - User permission configuration (libvirt, kvm groups)
  - Virtualization support verification
  - Guest tools and utilities (guestfs-tools, libguestfs)
- **VirtualBox** (Alternative)
  - Cross-platform hypervisor
  - User-friendly GUI interface
  - Kernel module configuration
  - Extension pack and guest additions

### Snapshots Module (`gz302-snapshots`)
- Automatic system snapshots
- Btrfs/Snapper integration
- LVM snapshot support

### Secure Boot Module (`gz302-secureboot`)
- Boot integrity tools
- Automatic kernel signing setup

## 📁 Optional Scripts (Advanced Use Cases)

The `Optional/` folder contains standalone scripts for specific use cases that are not needed by most users:

### Folio Resume Fix (`Optional/gz302-folio-fix.sh`)
**Use case:** If your folio keyboard/touchpad stops working after suspend/resume and requires physical reconnection.

- Automatically reloads HID and USB rebind for folio keyboard/touchpad after suspend/resume
- Creates systemd service for automatic recovery
- Configurable vendor/product IDs for custom folios

**Installation:**
```bash
cd Optional
sudo ./gz302-folio-fix.sh
```

**Note:** Most users do NOT need this fix. Only install if you experience folio keyboard/touchpad issues after sleep.

### Linux-G14 Kernel (`Optional/gz302-g14-kernel.sh`)
**Use case:** Advanced users who want kernel-level RGB LED control and ASUS-specific optimizations (Arch Linux only).

The `linux-g14` custom kernel is a community-maintained, ASUS-optimized kernel variant (6.17.3) with enhanced ROG laptop support.

**GZ302-Specific Features:**
- ✅ **Keyboard RGB LED Control** - Enhanced kernel-level control (4-zone per-key matrix)
- ✅ **Suspend/Resume LED Restoration** - Kernel hooks to prevent keyboard LED blackout after sleep
- ✅ **Power Management Tunables** - Strix Halo-compatible APU limits (sPPT/fPPT/SPPT)
- ✅ **OLED Panel Optimizations** - Panel overdrive, HD/UHD mode switching, auto-brightness

**Installation (Arch Linux only):**
```bash
cd Optional
sudo ./gz302-g14-kernel.sh
```

**Recommendation:**
- **For most users**: Use **mainline kernel 6.17+** - excellent Strix Halo support, community-tested, upstream security updates
- **For advanced users**: Use **linux-g14** - if you want kernel-level LED/power management features (trade-off: smaller testing community, slightly older patch set)

See: https://asus-linux.org and https://gitlab.com/asus-linux/linux-g14 and `Info/LINUX_G14_ANALYSIS.md`

## 🎯 Usage Examples

### Using Power Management
```bash
# Set power profile (automatically adjusts refresh rate)
pwrcfg gaming
# Check current status
pwrcfg status
# List all available profiles
pwrcfg list
# Configure automatic AC/battery switching
pwrcfg config
```

### Using Refresh Rate Control
```bash
# Manually set refresh rate (independent of power profile)
rrcfg gaming
# Check current refresh rate
rrcfg status
# List available profiles
rrcfg list
# Enable VRR/FreeSync
rrcfg vrr on
# Configure game-specific profiles
rrcfg game add steam gaming
```

### Quick Reference
```bash
# View current power and refresh settings
pwrcfg status
rrcfg status
# Enable automatic AC/battery switching (controls both power AND refresh)
pwrcfg config
# List available profiles
pwrcfg list
rrcfg list
```
## 🛠️ Troubleshooting FAQ

**Q: I get a password prompt when running `pwrcfg` or `rrcfg`.**
A: Make sure you enabled password-less sudo during setup, or run `sudo ./install-policy.sh` from the `tray-icon` directory. If you still get a prompt, check `/etc/sudoers.d/gz302-pwrcfg` exists and is valid.

**Q: `pwrcfg` says it can't elevate privileges.**
A: The sudoers rule may be missing or misconfigured. Run `sudo visudo -c -f /etc/sudoers.d/gz302-pwrcfg` to check for errors. Re-run the main setup script or `install-policy.sh` to fix.

**Q: My profile changes don't take effect.**
A: Make sure you are running the latest version of the script and that your user is in the correct group (if required by your distro).

**Q: How do I revert to requiring a password for `pwrcfg`?**
A: Remove `/etc/sudoers.d/gz302-pwrcfg` and reboot.

**Q: Can I use `pwrcfg`/`rrcfg` with custom profiles?**
A: Yes! See the advanced usage section in the documentation for details.

## 🗂️ Repository Organization

### Uninstall/ - Removal Tools

The `Uninstall/` folder contains scripts to safely remove GZ302 setup components:

**gz302-uninstall.sh** - Comprehensive uninstall utility
- Detects all installed components automatically
- Interactive selection (choose what to remove)
- Supports: Hardware fixes, TDP management, Refresh control, Folio fix, G14 kernel
- Safe removal with confirmation prompts

**Usage:**
```bash
cd Uninstall
sudo ./gz302-uninstall.sh
```

## 📚 Architecture

### Modular Design
The architecture separates concerns for easy maintenance and flexible installation:

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
- [tray-icon/](tray-icon/) - GUI system tray utility (work in progress)

---

**Last Updated:** November 2025 (v1.1.0)
