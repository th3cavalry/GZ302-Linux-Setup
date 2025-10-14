# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script

**Version: 1.3.0**

Comprehensive post-installation setup script for the Asus ROG Flow Z13 2025 models (GZ302EA) with AMD Strix Halo processor and integrated Radeon 8060S GPU.

## Supported Models

This script supports all three variants of the Asus ROG Flow Z13 2025:
- **GZ302EA-XS99** - 128GB RAM model
- **GZ302EA-XS64** - 64GB RAM model  
- **GZ302EA-XS32** - 32GB RAM model

## Supported Linux Distributions

The script automatically detects and supports the following distributions:
- **Arch-based**: Arch Linux, Manjaro, EndeavourOS, Garuda Linux
- **Debian-based**: Ubuntu, Linux Mint, Pop!_OS, Debian, Elementary OS, Zorin OS
- **Fedora-based**: Fedora, Nobara
- **openSUSE**: openSUSE Leap, openSUSE Tumbleweed
- **Other**: Gentoo, Void Linux

## What This Script Does

The script automatically installs and configures everything needed for the Asus ROG Flow Z13 2025 on Linux:

### 1. Kernel (Optional linux-g14 Variant on Arch)
- **Modern kernels (>= 6.6) typically provide adequate hardware support** for the GZ302EA in 2025
- On Arch Linux with kernel < 6.6, the script can install the linux-g14 kernel for enhanced ROG laptop support
- The g14 kernel is now **optional** and can be controlled via command-line flags
- Other distributions use their native kernel packages
- Use `--kernel g14` to force installation of g14 kernel for ROG-specific optimizations

### 2. Graphics Support
- Configures AMDGPU drivers with optimal settings
- Installs and updates Mesa drivers (25.0+)
- Sets up Vulkan and OpenGL support

### 3. WiFi & Bluetooth (MediaTek MT7925)
- Updates linux-firmware to latest version
- Ensures MT7925 drivers are properly loaded
- Configures Bluetooth firmware

### 4. ASUS-Specific Tools
- Installs `asusctl` for ASUS laptop control from official Asus Linux repositories
- Installs `supergfxctl` for graphics switching from official repositories
- Configures ROG-specific features
- Uses official repositories for easy updates via package manager

### 5. Power Management
- Configurable power management: choose between **TLP** (default) or **power-profiles-daemon**
- **Important:** TLP and power-profiles-daemon cannot run simultaneously (they conflict)
- Use `--power tlp` for advanced battery optimization (recommended for laptops)
- Use `--power ppd` for simpler power profile management
- Sets up AMD P-State driver
- Configures CPU frequency scaling

### 6. Suspend/Resume Fixes
- Configures S3 sleep support
- Applies ACPI fixes for proper suspend/resume

### 7. Audio Configuration
- Ensures proper ALSA/PulseAudio/PipeWire setup
- Applies SOF (Sound Open Firmware) configurations

### 8. Display & Touchscreen
- Configures high-DPI display settings
- Ensures touchscreen and stylus support

### 9. Bootloader Configuration
- Supports both GRUB and systemd-boot
- Automatically detects and configures your bootloader
- Adds optimal kernel parameters

## Prerequisites

- Fresh Linux installation (any supported distribution)
- Internet connection
- Root/sudo access
- Backup of your system (recommended)

## Installation

### Quick Start

```bash
# Download the script
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh

# Make it executable
chmod +x gz302-setup.sh

# Run the script (it will automatically install everything)
sudo ./gz302-setup.sh
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/th3cavalry/GZ302-Linux-Setup.git
cd GZ302-Linux-Setup

# Make the script executable
chmod +x gz302-setup.sh

# Run the script (it will automatically install everything)
sudo ./gz302-setup.sh
```

## Usage

The script supports various command-line options for customization:

```bash
sudo ./gz302-setup.sh [OPTIONS]

Options:
  --help                Show this help message
  --kernel MODE         Kernel installation mode (default: auto)
                        - auto: Install g14 kernel only if Arch + kernel < 6.6
                        - g14: Force install g14 kernel
                        - native: Use native/distribution kernel only
  --no-kernel           Shortcut for --kernel native
  --power BACKEND       Power management backend (default: tlp)
                        - tlp: Install and enable TLP
                        - ppd: Use power-profiles-daemon
  --no-reboot           Don't reboot automatically (prompt user instead)
  --dry-run             Show planned actions without making changes
  --log FILE            Log file location (default: /var/log/gz302-setup.log)
```

### Usage Examples

**Default installation (auto-detect kernel need, use TLP, prompt for reboot):**
```bash
sudo ./gz302-setup.sh
```

**Use native kernel with power-profiles-daemon:**
```bash
sudo ./gz302-setup.sh --no-kernel --power ppd
```

**Force g14 kernel installation:**
```bash
sudo ./gz302-setup.sh --kernel g14
```

**Dry run to see what would be done:**
```bash
sudo ./gz302-setup.sh --dry-run
```

**Custom log file and no automatic reboot:**
```bash
sudo ./gz302-setup.sh --log /tmp/setup.log --no-reboot
```

The script will:
1. Detect your Linux distribution
2. Optionally install the g14 kernel (if needed/requested)
3. Configure all hardware components
4. Set up ASUS-specific tools (asusctl, supergfxctl)
5. Configure power management (TLP or power-profiles-daemon)
6. Configure your bootloader (GRUB or systemd-boot)
7. Prompt to reboot when complete (unless --no-reboot is used)

## Post-Installation

After setup completion (and reboot if you chose to reboot):

1. **Verify the installation** using the verification script:
   ```bash
   ./verify-setup.sh
   ```

2. **Test the following:**
   - WiFi and Bluetooth connectivity
   - Graphics performance (run `glxinfo | grep "OpenGL renderer"`)
   - Suspend and resume
   - Audio output and input
   - Touchscreen and stylus
   - Battery life and power management

3. **Useful Commands:**
   ```bash
   # Check graphics info
   glxinfo | grep "OpenGL renderer"
   vulkaninfo | grep "deviceName"
   
   # Check ASUS controls
   asusctl --help
   supergfxctl --status
   
   # Check power management (TLP)
   tlp-stat
   
   # Or check power management (power-profiles-daemon)
   powerprofilesctl status
   
   # Check kernel version
   uname -r
   ```

## Troubleshooting

### WiFi Not Working
```bash
# Update firmware manually
sudo update-linux-firmware
# Or for specific distros:
sudo pacman -S linux-firmware  # Arch
sudo apt install linux-firmware  # Debian/Ubuntu
```

### Suspend/Resume Issues
- The script applies S3 sleep fixes automatically
- If issues persist, check BIOS settings for sleep mode configuration
- Ensure secure boot is disabled if using custom DSDT patches

### Graphics Performance Issues
```bash
# Verify AMDGPU is loaded
lsmod | grep amdgpu

# Check for errors
dmesg | grep -i amdgpu

# Reinstall Mesa (Arch example)
sudo pacman -S mesa vulkan-radeon
```

### Audio Issues
```bash
# Restart audio service
systemctl --user restart pipewire  # or pulseaudio

# Check audio devices
aplay -l
```

## Advanced Configuration

### Custom Kernel Parameters

The script adds kernel parameters to `/etc/default/grub`. You can customize these:

```bash
sudo nano /etc/default/grub
# Edit GRUB_CMDLINE_LINUX_DEFAULT
sudo update-grub  # or grub-mkconfig -o /boot/grub/grub.cfg
```

### ASUS Control Customization

```bash
# Set performance profile
asusctl profile -P Performance

# Configure keyboard backlight
asusctl led-mode static -c ff0000

# Graphics mode switching
supergfxctl -m Integrated  # or Hybrid, Dedicated
```

### Power Management Tuning

**If using TLP:**
```bash
# Edit TLP configuration
sudo nano /etc/tlp.conf

# Or edit GZ302-specific config
sudo nano /etc/tlp.d/00-gz302.conf

# Restart TLP
sudo systemctl restart tlp
```

**If using power-profiles-daemon:**
```bash
# List available profiles
powerprofilesctl list

# Set profile
powerprofilesctl set performance  # or balanced, power-saver
```

**Important Note on Power Management:**
TLP and power-profiles-daemon are mutually exclusive and will conflict if both are running. The script handles this automatically based on your `--power` choice. If you switch between them later, make sure to disable one before enabling the other:

```bash
# To switch from power-profiles-daemon to TLP:
sudo systemctl stop power-profiles-daemon
sudo systemctl mask power-profiles-daemon
sudo systemctl enable --now tlp

# To switch from TLP to power-profiles-daemon:
sudo systemctl stop tlp
sudo systemctl mask tlp
sudo systemctl unmask power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
```

## Known Issues

1. **Fingerprint Reader**: Not yet supported in Linux (driver support may arrive in future kernel versions)
2. **RGB Keyboard**: Limited support - basic functionality available via asusctl
3. **Windows Hello Camera**: IR camera not supported
4. **Thunderbolt 4**: May require additional configuration on some distros

**Note:** This script is designed specifically for the **Asus ROG Flow Z13 2025 (GZ302EA)** models. While it may share some components with Zephyrus G14 laptops (hence the g14 kernel option), it is tailored for the Flow Z13 tablet form factor and GZ302EA hardware.

## Contributing

Issues, suggestions, and pull requests are welcome! Please check the [GitHub repository](https://github.com/th3cavalry/GZ302-Linux-Setup).

## Resources

- [Asus Linux Project](https://asus-linux.org/)
- [Level1Techs Forum - Flow Z13 Setup](https://forum.level1techs.com/t/flow-z13-asus-setup-on-linux-may-2025-wip/229551)
- [Phoronix - AMD Radeon 8060S Linux Performance](https://www.phoronix.com/review/amd-radeon-8060s-linux)
- [MediaTek MT7925 Driver Documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)

## License

MIT License - See LICENSE file for details

## Disclaimer

This script modifies system configurations. While tested, use at your own risk. Always backup your system before running system modification scripts.

---

**Last Updated**: October 14, 2025  
**Version**: 1.3.0
