# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script

**Version: 1.0.0**

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

The script implements various fixes and optimizations for the Asus ROG Flow Z13 2025 on Linux:

### 1. Kernel Updates
- Ensures you're running a kernel >= 6.14 for optimal hardware support
- Adds necessary kernel parameters for AMD Strix Halo and Radeon 8060S

### 2. Graphics Support
- Configures AMDGPU drivers with optimal settings
- Installs and updates Mesa drivers (25.0+)
- Sets up Vulkan and OpenGL support

### 3. WiFi & Bluetooth (MediaTek MT7925)
- Updates linux-firmware to latest version
- Ensures MT7925 drivers are properly loaded
- Configures Bluetooth firmware

### 4. ASUS-Specific Tools
- Installs `asusctl` for ASUS laptop control
- Installs `supergfxctl` for graphics switching
- Configures ROG-specific features

### 5. Power Management
- Installs and configures TLP for battery optimization
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

# Run the script
sudo ./gz302-setup.sh
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/th3cavalry/GZ302-Linux-Setup.git
cd GZ302-Linux-Setup

# Make the script executable
chmod +x gz302-setup.sh

# Run the script
sudo ./gz302-setup.sh
```

## Usage

The script is interactive and will guide you through the setup process:

```bash
sudo ./gz302-setup.sh [OPTIONS]

Options:
  --auto          Run in automatic mode (uses defaults, minimal prompts)
  --minimal       Install only essential fixes (no optional components)
  --full          Install everything including optional components
  --skip-kernel   Skip kernel updates/checks
  --help          Show help message
```

### Examples

```bash
# Interactive mode (recommended for first-time users)
sudo ./gz302-setup.sh

# Automatic mode with all features
sudo ./gz302-setup.sh --auto --full

# Minimal installation
sudo ./gz302-setup.sh --minimal
```

## Post-Installation

After running the script:

1. **Reboot your system** to apply all changes
2. Test the following:
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
   
   # Check power management
   tlp-stat
   
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

```bash
# Edit TLP configuration
sudo nano /etc/tlp.conf

# Restart TLP
sudo systemctl restart tlp
```

## Known Issues

1. **Fingerprint Reader**: Not yet supported in Linux (as of kernel 6.14)
2. **RGB Keyboard**: Limited support - basic functionality available via asusctl
3. **Windows Hello Camera**: IR camera not supported
4. **Thunderbolt 4**: May require additional configuration on some distros

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
**Version**: 1.0.0
