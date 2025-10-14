# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script

**Version: 1.4.0**

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

### 1. Kernel Updates
- Ensures kernel is at least version 6.15 or newer (required for optimal Radeon 8060S support)
- Updates kernel and headers via distro packages if needed
- Works with mainline kernels from all distributions

### 2. Graphics Support
- Configures AMDGPU drivers with optimal settings
- Installs and updates Mesa drivers (24.1+ required, 25.0+ recommended)
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

The script runs fully automatically and installs all necessary components:

```bash
sudo ./gz302-setup.sh [OPTIONS]

Options:
  --help          Show help message
```

The script will:
1. Detect your Linux distribution
2. Update kernel to latest version if needed
3. Configure all hardware components
4. Set up ASUS-specific tools
5. Optimize power management
6. Configure your bootloader (GRUB or systemd-boot)
7. Automatically reboot when complete

## Post-Installation

After the automatic reboot:

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

3. **(Optional) Set up power management:**
   ```bash
   # Configure power profiles for AC/battery
   sudo pwrcfg config
   
   # Enable automatic switching
   sudo pwrcfg auto on
   
   # Or manually control power profiles
   sudo pwrcfg turbo       # High performance
   sudo pwrcfg powersave   # Battery saving
   pwrcfg status           # Check current status
   
   # Control refresh rate
   rrcfg 120               # High refresh (120Hz)
   rrcfg 60                # Low refresh (60Hz)
   ```

4. **Useful Commands:**
   ```bash
   # Check graphics info
   glxinfo | grep "OpenGL renderer"
   vulkaninfo | grep "deviceName"
   
   # Check ASUS controls
   asusctl --help
   supergfxctl --status
   
   # Check power management
   tlp-stat
   
   # Power configuration tools
   pwrcfg --help
   rrcfg --help
   
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

The repository includes comprehensive power management tools (`pwrcfg` and `rrcfg`) that provide fine-grained control over performance and power consumption.

#### Power Configuration Tool: `pwrcfg`

`pwrcfg` provides 6 power profiles with TDP (Thermal Design Power) control, ranging from maximum performance to extreme battery saving.

**Available Profiles:**

| Profile | TDP | CPU Governor | CPU Boost | Use Case |
|---------|-----|--------------|-----------|----------|
| **max** | 120W | performance | enabled | Maximum performance, rendering |
| **turbo** | 100W | performance | enabled | Gaming, heavy workloads |
| **performance** | 80W | performance | enabled | Standard work, productivity |
| **balanced** | 60W | schedutil | enabled | General use, web browsing |
| **powersave** | 35W | powersave | disabled | Battery life, light tasks |
| **extreme** | 20W | powersave | disabled | Extreme battery saving |

**Quick Usage:**

```bash
# Set a power profile
sudo pwrcfg turbo          # High performance gaming
sudo pwrcfg powersave      # Extend battery life

# View current status
pwrcfg status

# List all profiles
pwrcfg list
```

#### Automatic Power Profile Switching

Configure automatic profile switching based on AC/battery status:

```bash
# Interactive configuration
sudo pwrcfg config

# Example configuration:
#   AC Profile: turbo
#   Battery Profile: powersave
#   Link refresh rate to profile: yes

# Enable automatic switching
sudo pwrcfg auto on

# Disable automatic switching
sudo pwrcfg auto off
```

When enabled, the system automatically:
- Switches to your chosen **AC profile** (e.g., turbo) when plugged in
- Switches to your chosen **battery profile** (e.g., powersave) when unplugged
- Optionally adjusts refresh rate to match the profile

#### Refresh Rate Control: `rrcfg`

`rrcfg` provides simple refresh rate management with support for any rate your display supports.

**Quick Usage:**

```bash
# Set refresh rate
rrcfg 120                  # High refresh (120Hz)
rrcfg 90                   # Balanced (90Hz)
rrcfg 60                   # Battery saving (60Hz)
rrcfg 40                   # Extreme battery saving (40Hz)

# Auto-match current power profile
rrcfg auto

# Check current refresh rate
rrcfg status

# List available rates for your display
rrcfg list
```

**Common Refresh Rates:**
- **40Hz**: Extreme power saving (~20% battery savings)
- **60Hz**: Standard, good battery life
- **90Hz**: Balanced smoothness and efficiency
- **120Hz**: High performance, smooth scrolling
- **165Hz/180Hz**: Maximum (if supported by your display)

#### What Each Profile Does

**Maximum Performance (max):**
- TDP: 120W
- CPU: Performance governor, boost enabled
- GPU: High power mode
- Refresh: 120Hz (if linked)
- **Best for**: 3D rendering, video editing, maximum FPS gaming

**Turbo Mode (turbo):**
- TDP: 100W
- CPU: Performance governor, boost enabled
- GPU: High power mode
- Refresh: 120Hz (if linked)
- **Best for**: Gaming, compilation, heavy multitasking

**Performance Mode (performance):**
- TDP: 80W
- CPU: Performance governor, boost enabled
- GPU: Auto power management
- Refresh: 120Hz (if linked)
- **Best for**: Productivity, development, standard workloads

**Balanced Mode (balanced):**
- TDP: 60W
- CPU: Schedutil (adaptive) governor, boost enabled
- GPU: Auto power management
- Refresh: 90Hz (if linked)
- **Best for**: Web browsing, office work, general computing

**Powersave Mode (powersave):**
- TDP: 35W
- CPU: Powersave governor, boost disabled
- GPU: Low power mode
- Refresh: 60Hz (if linked)
- **Best for**: Light tasks, reading, note-taking, battery life

**Extreme Battery Saving (extreme):**
- TDP: 20W
- CPU: Powersave governor, boost disabled
- GPU: Low power mode
- Refresh: 60Hz (if linked)
- **Best for**: Minimal power consumption, emergency battery extension

#### TDP Control Features

The `pwrcfg` tool attempts to control TDP through multiple methods:

1. **RyzenAdj** (if installed): Direct TDP control for AMD Ryzen processors
2. **Platform Profile**: Uses `/sys/firmware/acpi/platform_profile`
3. **AMD P-State EPP**: Energy Performance Preference control
4. **CPU Governor**: Frequency scaling management

For full TDP control on AMD Strix Halo, install `ryzenadj`:
```bash
# Arch Linux
yay -S ryzenadj

# Ubuntu/Debian
# Build from source: https://github.com/FlyGoat/RyzenAdj

# Enable on boot (after install)
sudo pwrcfg auto on
```

#### Advanced Customization

**Custom AC/Battery Profiles:**
```bash
# Configure interactively
sudo pwrcfg config

# This lets you choose:
# - Which profile for AC power
# - Which profile for battery
# - Whether to link refresh rate
```

**Manual TDP Override** (requires ryzenadj):
```bash
# Set custom TDP (example: 70W)
sudo ryzenadj --stapm-limit=70000 --fast-limit=70000 --slow-limit=70000
```

**Separate Refresh Rate Control:**
```bash
# Unlink refresh rate from power profile
# Edit /etc/gz302/pwrcfg.conf
LINK_REFRESH="no"

# Then control refresh rate independently
rrcfg 120
```

#### Integration with Existing Tools

The power management tools work alongside existing utilities:

**Compatible with TLP:**
- TLP handles background optimizations
- `pwrcfg` handles active profile switching
- No conflicts between systems

**Works with asusctl:**
- Uses asusctl profiles when available
- Gracefully degrades if not installed
- Complements ASUS-specific features

#### Installation to System

To install the commands system-wide:

```bash
# Copy to system directories (done automatically on first use with sudo)
sudo cp pwrcfg /usr/local/bin/
sudo cp rrcfg /usr/local/bin/
sudo chmod +x /usr/local/bin/pwrcfg /usr/local/bin/rrcfg

# Now you can use from anywhere
pwrcfg status
rrcfg 120
```

#### Traditional TLP Configuration

You can also manually edit TLP configuration:

```bash
# Edit TLP configuration
sudo nano /etc/tlp.conf

# Restart TLP
sudo systemctl restart tlp
```

## Known Issues

1. **Fingerprint Reader**: Not yet supported in Linux (as of kernel 6.17)
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
**Version**: 1.4.0
