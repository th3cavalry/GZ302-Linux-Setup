# Quick Reference Card - GZ302EA Linux

Essential commands and quick fixes for Asus ROG Flow Z13 2025 (GZ302EA) on Linux.

## Installation

```bash
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh
chmod +x gz302-setup.sh
sudo ./gz302-setup.sh
```

## Essential Commands

### System Information
```bash
# Check kernel version
uname -r

# Check GPU info
glxinfo | grep "OpenGL renderer"
vulkaninfo | grep "deviceName"

# Check WiFi/BT chip
lspci | grep -i network
lsusb | grep -i bluetooth
```

### ASUS Tools
```bash
# Check asusctl status
asusctl -h

# Set performance profile
asusctl profile -P Performance    # or Balanced, Quiet

# Check GPU mode
supergfxctl --status

# Switch GPU mode
supergfxctl -m Integrated         # or Hybrid
```

### Power Management
```bash
# Check TLP status
tlp-stat

# Battery info
tlp-stat -b

# Check power consumption
sudo powertop
```

### Graphics
```bash
# Force performance mode
echo performance | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level

# Check GPU status
cat /sys/class/drm/card0/device/power_dpm_state
```

### WiFi Quick Fixes
```bash
# Restart WiFi
sudo systemctl restart NetworkManager

# Reload WiFi driver
sudo modprobe -r mt7921e && sudo modprobe mt7921e

# Disable power save
sudo iw dev wlan0 set power_save off
```

### Bluetooth Quick Fixes
```bash
# Restart Bluetooth
sudo systemctl restart bluetooth

# Unblock Bluetooth
sudo rfkill unblock bluetooth

# Reset Bluetooth
bluetoothctl power off
bluetoothctl power on
```

### Audio Quick Fixes
```bash
# Restart audio (PipeWire)
systemctl --user restart pipewire pipewire-pulse wireplumber

# Restart audio (PulseAudio)
pulseaudio -k && pulseaudio --start

# Unmute all
amixer sset Master unmute
amixer sset Capture unmute
```

### Suspend/Resume
```bash
# Check sleep mode
cat /sys/power/mem_sleep

# Set to deep sleep (S3)
echo deep | sudo tee /sys/power/mem_sleep

# Test suspend
systemctl suspend
```

## Kernel Parameters

Add to `/etc/default/grub` in `GRUB_CMDLINE_LINUX_DEFAULT`:

```
iommu=pt amd_pstate=active amdgpu.si_support=1 amdgpu.cik_support=1
```

Then run: `sudo update-grub` (or `sudo grub-mkconfig -o /boot/grub/grub.cfg`)

## Important Files

### Configurations
```
/etc/default/grub                    # Boot parameters
/etc/modprobe.d/amdgpu.conf          # GPU settings
/etc/modprobe.d/mt7921.conf          # WiFi settings
/etc/tlp.d/00-gz302.conf             # Power management
```

### Logs
```bash
# System logs
journalctl -b                        # Current boot
journalctl -b -1                     # Previous boot

# Kernel messages
dmesg | less
dmesg | grep -i error

# GPU logs
dmesg | grep -i amdgpu

# WiFi logs
dmesg | grep -i mt7921
```

## Power Configuration Tool: pwrcfg

Simple power management with 6 profiles and TDP control:

```bash
# Set power profile
sudo pwrcfg turbo       # High performance (100W TDP)
sudo pwrcfg performance # Standard (80W TDP)
sudo pwrcfg balanced    # Balanced (60W TDP)
sudo pwrcfg powersave   # Battery saving (35W TDP)
sudo pwrcfg extreme     # Extreme battery (20W TDP)
sudo pwrcfg max         # Maximum (120W TDP)

# Configure automatic AC/battery switching
sudo pwrcfg config      # Interactive setup
sudo pwrcfg auto on     # Enable auto-switching
sudo pwrcfg auto off    # Disable auto-switching

# Check status
pwrcfg status           # Show current settings
pwrcfg list             # List all profiles
```

## Refresh Rate Control: rrcfg

Simple refresh rate management:

```bash
# Set refresh rate
rrcfg 120              # High refresh (120Hz)
rrcfg 90               # Balanced (90Hz)
rrcfg 60               # Battery saving (60Hz)
rrcfg 40               # Extreme power saving (40Hz)

# Auto-match power profile
rrcfg auto

# Check status
rrcfg status           # Show current rate
rrcfg list             # List available rates
```

## Power & Display Quick Combos

```bash
# Maximum performance
sudo pwrcfg max && rrcfg 120

# Gaming mode
sudo pwrcfg turbo && rrcfg 120

# Battery life
sudo pwrcfg powersave && rrcfg 60

# Extreme battery saving
sudo pwrcfg extreme && rrcfg 40
```

## Performance Profiles

### Maximum Performance
```bash
asusctl profile -P Performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Battery Saving
```bash
asusctl profile -P Quiet
echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Balanced
```bash
asusctl profile -P Balanced
```

## Common Issues - One-Line Fixes

### WiFi Not Working
```bash
sudo modprobe -r mt7921e && sudo modprobe mt7921e && sudo systemctl restart NetworkManager
```

### Audio Not Working
```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### Graphics Glitches
```bash
sudo systemctl restart gdm  # or sddm/lightdm
```

### Poor Battery Life
```bash
sudo systemctl enable --now tlp && asusctl profile -P Quiet
```

## Useful Monitoring Commands

```bash
# CPU usage and frequency
watch -n 1 'grep MHz /proc/cpuinfo'

# GPU monitoring
watch -n 1 'cat /sys/class/drm/card0/device/gpu_busy_percent'

# Temperature monitoring
watch -n 1 'sensors'

# Network speed
speedtest-cli

# Disk I/O
iotop

# System resources
htop
```

## Package Installation Quick Reference

### Arch Linux
```bash
sudo pacman -S package-name
```

### Ubuntu/Debian
```bash
sudo apt install package-name
```

### Fedora
```bash
sudo dnf install package-name
```

### openSUSE
```bash
sudo zypper install package-name
```

## Emergency Boot Parameters

If system won't boot, at GRUB press 'e' and add:

```
nomodeset                    # Disable graphics driver
amdgpu.dc=0                  # Disable display core
acpi=off                     # Disable ACPI (last resort)
```

## Update Commands

### System Updates
```bash
# Arch
sudo pacman -Syu

# Ubuntu/Debian
sudo apt update && sudo apt upgrade

# Fedora
sudo dnf upgrade

# openSUSE
sudo zypper update
```

### Firmware Updates
```bash
# Arch
sudo pacman -S linux-firmware

# Ubuntu/Debian
sudo apt install linux-firmware

# Fedora
sudo dnf install linux-firmware
```

## Secure Boot

### Check Secure Boot Status
```bash
# Using bootctl (systemd)
bootctl status | grep "Secure Boot"

# Using mokutil (Ubuntu/Fedora)
mokutil --sb-state

# Using sbctl (Arch)
sbctl status

# Via EFI variables
od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null
```

### Arch Linux - Setup Secure Boot
```bash
# Install sbctl
sudo pacman -S sbctl

# Create and enroll keys
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft

# Sign bootloader and kernel
sudo sbctl sign --save /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign --save /boot/vmlinuz-linux

# Verify signatures
sudo sbctl verify
```

### Ubuntu/Debian - MOK Key Management
```bash
# Check enrolled keys
mokutil --list-enrolled

# Import custom key
sudo mokutil --import /path/to/key.der

# Reboot to enroll key (blue MOK screen)
```

### Verify Signed Kernel
```bash
# Arch with sbctl
sudo sbctl verify

# Check with sbverify
sbverify --list /boot/vmlinuz-linux
```

**Full Guide:** See [SECURE-BOOT.md](https://github.com/th3cavalry/GZ302-Linux-Setup/blob/main/SECURE-BOOT.md)

## Resources

- Main Repo: https://github.com/th3cavalry/GZ302-Linux-Setup
- ASUS Linux: https://asus-linux.org/
- Troubleshooting: See TROUBLESHOOTING.md in repo

---

**Tip:** Bookmark this page for quick reference!

**Remember:** Always backup before making system changes.
