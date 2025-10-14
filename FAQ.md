# Frequently Asked Questions (FAQ)

Common questions about the GZ302EA Linux Setup and the Asus ROG Flow Z13 2025 on Linux.

## Table of Contents

- [General Questions](#general-questions)
- [Installation Questions](#installation-questions)
- [Hardware Compatibility](#hardware-compatibility)
- [Performance Questions](#performance-questions)
- [Troubleshooting](#troubleshooting)

## General Questions

### Q: What is the GZ302EA?

**A:** The GZ302EA is the model number for the Asus ROG Flow Z13 2025, a gaming tablet/laptop hybrid featuring:
- AMD Strix Halo processor
- Integrated AMD Radeon 8060S GPU
- MediaTek MT7925 WiFi 7 and Bluetooth
- Available in 32GB, 64GB, and 128GB RAM configurations
- High-refresh touchscreen display

### Q: Does Linux work on the GZ302EA?

**A:** Yes! With the right configuration and recent kernel (6.14+), Linux works well on the GZ302EA. This script automates the setup process to ensure optimal compatibility.

### Q: Which Linux distribution should I use?

**A:** The script supports many distributions. Recommended options:
- **Arch Linux / Manjaro** - Cutting-edge packages, great hardware support
- **Ubuntu 25.04+** - User-friendly, good compatibility  
- **Fedora 42+** - Modern packages, excellent hardware support
- **Pop!_OS** - Gaming-optimized Ubuntu derivative

Choose based on your experience level and preferences.

### Q: Is this safe to use?

**A:** The script is open source and you can review all code before running. It:
- Only modifies necessary configuration files
- Creates backups before changes
- Uses official repositories when possible
- Follows best practices

As with any system modification script, we recommend:
1. Backup your data first
2. Review the script code
3. Test in a VM if possible
4. Start with `--minimal` mode

## Installation Questions

### Q: Do I need to run the script as root?

**A:** Yes, the script requires root privileges (`sudo`) because it:
- Installs system packages
- Modifies kernel parameters
- Configures system services
- Updates firmware

### Q: Can I run the script multiple times?

**A:** Yes! The script is designed to be idempotent - you can run it multiple times safely. It will:
- Skip already-configured items
- Update packages to latest versions
- Reapply configurations if needed

### Q: What's the difference between auto, minimal, and full modes?

**A:**
- **Interactive mode** (default): Asks before each major step
- **Auto mode** (`--auto`): Minimal prompts, uses sensible defaults
- **Minimal mode** (`--minimal`): Only essential fixes, skips optional tools
- **Full mode** (`--full`): Installs everything including optional components

### Q: How long does the installation take?

**A:** Typically 10-30 minutes depending on:
- Your internet connection speed
- Your distribution
- Which mode you choose
- Whether kernel updates are needed

### Q: Do I need to reboot after installation?

**A:** Yes, a reboot is required for:
- New kernel parameters to take effect
- Driver updates to load
- Firmware updates to activate
- System services to start properly

### Q: Can I undo the changes?

**A:** The script creates backups of modified files (check `/etc/*.backup.*`). To undo:
1. Restore backed-up configuration files
2. Remove installed packages (if desired)
3. Update GRUB to remove kernel parameters
4. Reboot

However, we recommend testing in a VM first rather than relying on undo functionality.

## Hardware Compatibility

### Q: Will all hardware work?

**A:** Most hardware works with kernel 6.14+:

**Working:**
- ✅ CPU (AMD Strix Halo)
- ✅ GPU (Radeon 8060S) 
- ✅ WiFi (MediaTek MT7925)
- ✅ Bluetooth
- ✅ Audio
- ✅ Touchscreen
- ✅ Keyboard and trackpad
- ✅ USB-C / Thunderbolt
- ✅ Battery and charging
- ✅ Display (including high refresh rate)

**Limited Support:**
- ⚠️ RGB Keyboard (basic control via asusctl)
- ⚠️ Stylus (works but may need calibration)

**Not Working:**
- ❌ Fingerprint reader (no Linux driver yet)
- ❌ Windows Hello IR camera

### Q: Does WiFi 7 work?

**A:** The MediaTek MT7925 WiFi 7 chip is supported in kernel 6.7+, though WiFi 7 features require:
- Kernel 6.14+ for best support
- Updated linux-firmware
- WiFi 7 capable router

The chip will work with WiFi 5/6 networks with full compatibility.

### Q: Does the touchscreen work?

**A:** Yes, the touchscreen works with standard libinput drivers included in most distributions.

### Q: Does suspend/resume work?

**A:** Yes, the script configures suspend/resume. S3 deep sleep works on most systems. If you experience issues, see the troubleshooting guide.

### Q: What about the XG Mobile eGPU?

**A:** The XG Mobile connector should work as it's Thunderbolt-based. Specific eGPU management may require:
- Additional drivers for the external GPU
- Configuration via supergfxctl
- Testing (community feedback welcome!)

## Performance Questions

### Q: How's gaming performance on Linux?

**A:** The Radeon 8060S performs well on Linux with:
- Mesa 25.0+ drivers
- Vulkan support
- Steam Proton for Windows games
- Native Linux games

Performance is generally comparable to Windows, sometimes better with Vulkan.

### Q: How's battery life?

**A:** Battery life on Linux can be excellent with proper configuration:
- TLP power management (installed by script)
- AMD P-State driver (configured by script)
- Proper display brightness management

Expect 4-6 hours of light use, 2-3 hours gaming (similar to Windows).

### Q: Can I control fan speed?

**A:** Yes, via asusctl:
```bash
asusctl profile -P Performance  # High fan speed
asusctl profile -P Balanced     # Moderate fan speed
asusctl profile -P Quiet        # Low fan speed
```

### Q: Does the high refresh rate display work?

**A:** Yes! The display works at its native refresh rate. You can configure it:
- In your desktop environment's display settings
- Using the refresh rate tool: `rrcfg 120` or `rrcfg 60`
- Via xrandr (X11): `xrandr --output eDP-1 --rate 120`
- Via wlr-randr (Wayland)

### Q: How do I manage power profiles and battery life?

**A:** The repository includes `pwrcfg` and `rrcfg` commands for comprehensive power management with 6 power profiles:

**Quick Start:**
```bash
# Configure automatic AC/battery switching
sudo pwrcfg config

# Enable automatic switching
sudo pwrcfg auto on
```

**Manual Control:**
```bash
# Power profiles (6 levels)
sudo pwrcfg max         # Maximum performance (120W TDP)
sudo pwrcfg turbo       # High performance (100W TDP)
sudo pwrcfg performance # Standard performance (80W TDP)
sudo pwrcfg balanced    # Balanced (60W TDP)
sudo pwrcfg powersave   # Battery saving (35W TDP)
sudo pwrcfg extreme     # Extreme battery saving (20W TDP)

# Check current status
pwrcfg status
```

**Refresh Rate Control:**
```bash
# Set any refresh rate your display supports
rrcfg 120               # High refresh (smooth)
rrcfg 90                # Balanced
rrcfg 60                # Battery saving
rrcfg 40                # Extreme power saving

# Auto-match current power profile
rrcfg auto
```

**Power Profiles Explained:**
- **max**: 120W TDP - Maximum performance for rendering/compilation
- **turbo**: 100W TDP - High performance for gaming
- **performance**: 80W TDP - Standard work and productivity
- **balanced**: 60W TDP - General use, web browsing
- **powersave**: 35W TDP - Battery life optimization
- **extreme**: 20W TDP - Minimal power consumption

The automatic mode will switch between your chosen AC and battery profiles automatically. You can also set them manually anytime with `sudo pwrcfg <profile>`.

## Troubleshooting

### Q: The script failed. What should I do?

**A:**
1. Check the error message
2. Look for solutions in TROUBLESHOOTING.md
3. Run with verbose output to see details
4. Check logs: `journalctl -b` and `dmesg`
5. Report the issue on GitHub with full error details

### Q: WiFi isn't working after installation

**A:** Try these steps in order:
```bash
# 1. Update firmware
sudo pacman -S linux-firmware  # or apt/dnf equivalent

# 2. Reload driver
sudo modprobe -r mt7921e && sudo modprobe mt7921e

# 3. Restart NetworkManager
sudo systemctl restart NetworkManager

# 4. Check if blocked
sudo rfkill list
sudo rfkill unblock wifi
```

See TROUBLESHOOTING.md for more details.

### Q: Graphics performance is poor

**A:** Check these:
```bash
# Verify AMDGPU is loaded
lsmod | grep amdgpu

# Check Mesa version (need 25.0+)
glxinfo | grep "OpenGL version"

# Set performance mode
echo performance | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
```

### Q: Audio isn't working

**A:**
```bash
# Restart audio service
systemctl --user restart pipewire pipewire-pulse

# Check devices
aplay -l

# Unmute
amixer sset Master unmute
```

### Q: System won't suspend

**A:**
```bash
# Check sleep modes
cat /sys/power/mem_sleep

# Try s2idle
echo s2idle | sudo tee /sys/power/mem_sleep

# Check for blockers
systemctl status sleep.target
```

### Q: How do I get help?

**A:**
1. Read the README.md
2. Check TROUBLESHOOTING.md
3. Review QUICK-REFERENCE.md
4. Search existing GitHub issues
5. Create a new issue with:
   - Your distribution and version
   - Kernel version (`uname -r`)
   - Error messages/logs
   - Steps to reproduce

## Distribution-Specific Questions

### Q: I'm on Ubuntu. Should I use a PPA for newer kernels?

**A:** For Ubuntu, you can use:
- Ubuntu Mainline Kernel PPA for latest kernels
- Kisak Mesa PPA for newer Mesa drivers

However, use with caution as PPAs can cause conflicts.

### Q: I'm on Arch. Do I need an AUR helper?

**A:** The script works best with an AUR helper (yay or paru) for installing asusctl/supergfxctl. If you don't have one, the script will attempt to install manually.

### Q: Does this work on Debian stable?

**A:** Debian Stable has older packages. You may need:
- Backports repository for newer kernel
- Manual driver installation
- Consider Debian Testing/Sid or another distro

## Contributing

### Q: Can I contribute to this project?

**A:** Absolutely! We welcome:
- Bug reports
- Documentation improvements
- Distribution support additions
- Code improvements
- Testing feedback

See CONTRIBUTING.md for guidelines.

### Q: I found a bug. How do I report it?

**A:** Create a GitHub issue with:
1. Clear description of the bug
2. Steps to reproduce
3. Your system information
4. Relevant logs
5. Expected vs actual behavior

### Q: Can I add support for my distribution?

**A:** Yes! See CONTRIBUTING.md section on adding distribution support. We especially welcome:
- Less common distributions
- Different package managers
- Alternative init systems

## Future Plans

### Q: Will fingerprint reader support be added?

**A:** When Linux kernel support is available, we'll add it. Currently no driver exists.

### Q: Are there plans for a GUI version?

**A:** It's on the roadmap! Contributions welcome.

### Q: Will you support other ROG Flow models?

**A:** Potentially! If there's interest and the models are similar enough, we could expand support.

---

**Have a question not answered here?** 

Open an issue on GitHub or check the other documentation files:
- README.md - Installation and overview
- TROUBLESHOOTING.md - Problem solutions  
- QUICK-REFERENCE.md - Command reference
- CONTRIBUTING.md - Contribution guidelines
