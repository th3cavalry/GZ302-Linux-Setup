# Troubleshooting Guide

This guide covers common issues and their solutions for the Asus ROG Flow Z13 2025 (GZ302EA) running Linux.

## Table of Contents

- [WiFi Issues](#wifi-issues)
- [Bluetooth Issues](#bluetooth-issues)
- [Graphics Issues](#graphics-issues)
- [Suspend/Resume Problems](#suspendresume-problems)
- [Audio Issues](#audio-issues)
- [Touchscreen/Stylus Issues](#touchscreenstylus-issues)
- [Performance Issues](#performance-issues)
- [Boot Issues](#boot-issues)

---

## WiFi Issues

### WiFi Not Detected

**Symptoms:** WiFi adapter not showing up in network manager

**Solutions:**

1. **Check if firmware is loaded:**
   ```bash
   dmesg | grep mt7921
   lspci | grep -i network
   ```

2. **Update linux-firmware:**
   ```bash
   # Arch
   sudo pacman -S linux-firmware
   
   # Debian/Ubuntu
   sudo apt update && sudo apt install linux-firmware
   
   # Fedora
   sudo dnf install linux-firmware
   ```

3. **Reload the WiFi module:**
   ```bash
   sudo modprobe -r mt7921e
   sudo modprobe mt7921e
   ```

4. **Check if the module is blacklisted:**
   ```bash
   grep -r "blacklist mt7921" /etc/modprobe.d/
   # If found, remove the blacklist entry
   ```

### WiFi Keeps Disconnecting

**Solutions:**

1. **Disable power saving for WiFi:**
   ```bash
   sudo iw dev wlan0 set power_save off
   ```

2. **Make it permanent:**
   ```bash
   sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf <<EOF
   [connection]
   wifi.powersave = 2
   EOF
   
   sudo systemctl restart NetworkManager
   ```

3. **Disable ASPM for MT7921:**
   ```bash
   echo "options mt7921e disable_aspm=1" | sudo tee /etc/modprobe.d/mt7921.conf
   sudo update-initramfs -u  # Debian/Ubuntu
   sudo mkinitcpio -P        # Arch
   ```

### Slow WiFi Speed

**Solutions:**

1. **Check connection:**
   ```bash
   iwconfig wlan0
   ```

2. **Force 5GHz if available:**
   Edit your WiFi connection and select 5GHz band only

3. **Update to latest kernel:**
   Kernel 6.14+ has improved MT7925 performance

---

## Bluetooth Issues

### Bluetooth Not Working

**Solutions:**

1. **Check Bluetooth service:**
   ```bash
   sudo systemctl status bluetooth
   sudo systemctl enable --now bluetooth
   ```

2. **Check if firmware is loaded:**
   ```bash
   dmesg | grep -i bluetooth
   journalctl -u bluetooth
   ```

3. **Reload Bluetooth module:**
   ```bash
   sudo modprobe -r btusb
   sudo modprobe btusb
   ```

4. **Reset Bluetooth:**
   ```bash
   sudo rfkill unblock bluetooth
   bluetoothctl power on
   ```

### Bluetooth Audio Stuttering

**Solutions:**

1. **Disable WiFi power save** (WiFi and BT share the same chip)
2. **Use higher quality codec:**
   ```bash
   # For PipeWire, edit ~/.config/pipewire/media-session.d/bluez-monitor.conf
   # Set codec to AAC or aptX if supported
   ```

---

## Graphics Issues

### Poor Graphics Performance

**Solutions:**

1. **Verify AMDGPU is loaded:**
   ```bash
   lsmod | grep amdgpu
   glxinfo | grep "OpenGL renderer"
   ```

2. **Check for errors:**
   ```bash
   dmesg | grep -i amdgpu
   ```

3. **Install Mesa 25.0+:**
   ```bash
   # Arch
   sudo pacman -S mesa vulkan-radeon
   
   # Ubuntu (may need PPA for latest)
   sudo add-apt-repository ppa:kisak/kisak-mesa
   sudo apt update && sudo apt upgrade
   
   # Fedora
   sudo dnf install mesa-dri-drivers mesa-vulkan-drivers
   ```

4. **Enable performance governor:**
   ```bash
   echo performance | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
   ```

### Screen Tearing

**Solutions:**

1. **For X11, enable TearFree:**
   ```bash
   sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf <<EOF
   Section "Device"
       Identifier "AMD"
       Driver "amdgpu"
       Option "TearFree" "true"
   EndSection
   EOF
   ```

2. **Use Wayland instead of X11** (better vsync support)

### Display Not Detected

**Solutions:**

1. **Check connected displays:**
   ```bash
   xrandr --listproviders
   ```

2. **Reload display manager:**
   ```bash
   sudo systemctl restart gdm  # or sddm, lightdm, etc.
   ```

---

## Suspend/Resume Problems

### System Won't Suspend

**Solutions:**

1. **Check sleep modes:**
   ```bash
   cat /sys/power/mem_sleep
   # Should show: s2idle [deep]
   ```

2. **Enable deep sleep:**
   ```bash
   echo deep | sudo tee /sys/power/mem_sleep
   ```

3. **Make it permanent:**
   ```bash
   sudo tee /etc/tmpfiles.d/suspend-mode.conf <<EOF
   w /sys/power/mem_sleep - - - - deep
   EOF
   ```

4. **Check for blocking processes:**
   ```bash
   systemctl status sleep.target suspend.target
   ```

### System Won't Resume

**Solutions:**

1. **Check kernel logs after crash:**
   ```bash
   journalctl -b -1  # Previous boot
   ```

2. **Try s2idle instead of deep:**
   ```bash
   echo s2idle | sudo tee /sys/power/mem_sleep
   ```

3. **Disable problematic modules before suspend:**
   Create `/usr/lib/systemd/system-sleep/modules.sh`:
   ```bash
   #!/bin/bash
   case $1 in
       pre)
           modprobe -r mt7921e
           ;;
       post)
           modprobe mt7921e
           ;;
   esac
   ```
   Make it executable: `sudo chmod +x /usr/lib/systemd/system-sleep/modules.sh`

### Screen Stays Black After Resume

**Solutions:**

1. **Add kernel parameter:**
   Add to GRUB_CMDLINE_LINUX_DEFAULT in `/etc/default/grub`:
   ```
   amdgpu.dc=1
   ```
   Then update GRUB and reboot

2. **Restart display manager on resume:**
   Add to the systemd sleep hook mentioned above

---

## Audio Issues

### No Sound Output

**Solutions:**

1. **Check if card is detected:**
   ```bash
   aplay -l
   pactl list sinks
   ```

2. **Unmute and increase volume:**
   ```bash
   amixer sset Master unmute
   amixer sset Master 80%
   ```

3. **Restart audio service:**
   ```bash
   # PipeWire
   systemctl --user restart pipewire pipewire-pulse wireplumber
   
   # PulseAudio
   pulseaudio -k
   pulseaudio --start
   ```

4. **Install SOF firmware:**
   ```bash
   # Arch
   sudo pacman -S sof-firmware
   
   # Debian/Ubuntu
   sudo apt install firmware-sof-signed
   
   # Fedora
   sudo dnf install sof-firmware
   ```

### Crackling/Popping Audio

**Solutions:**

1. **Edit PipeWire/PulseAudio config:**
   For PipeWire, create `~/.config/pipewire/pipewire.conf.d/10-fix-crackling.conf`:
   ```
   context.properties = {
       default.clock.rate = 48000
       default.clock.quantum = 2048
       default.clock.min-quantum = 1024
   }
   ```

2. **Disable power saving:**
   ```bash
   echo 0 | sudo tee /sys/module/snd_hda_intel/parameters/power_save
   ```

### Microphone Not Working

**Solutions:**

1. **Check input devices:**
   ```bash
   arecord -l
   pactl list sources
   ```

2. **Test microphone:**
   ```bash
   arecord -f cd test.wav
   # Press Ctrl+C to stop, then:
   aplay test.wav
   ```

3. **Unmute microphone:**
   ```bash
   amixer sset Capture cap
   amixer sset Capture 80%
   ```

---

## Touchscreen/Stylus Issues

### Touchscreen Not Responding

**Solutions:**

1. **Check if detected:**
   ```bash
   xinput list
   libinput list-devices
   ```

2. **Install required packages:**
   ```bash
   # Arch
   sudo pacman -S xf86-input-libinput xf86-input-wacom
   
   # Debian/Ubuntu
   sudo apt install xserver-xorg-input-libinput xserver-xorg-input-wacom
   ```

3. **Restart X server or Wayland compositor**

### Stylus Not Working

**Solutions:**

1. **Install Wacom drivers:**
   ```bash
   sudo pacman -S xf86-input-wacom  # Arch
   sudo apt install xserver-xorg-input-wacom  # Debian/Ubuntu
   ```

2. **Check device:**
   ```bash
   xsetwacom --list devices
   ```

---

## Performance Issues

### System Feels Slow

**Solutions:**

1. **Check CPU governor:**
   ```bash
   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```

2. **Set to performance mode:**
   ```bash
   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```

3. **Use asusctl to set profile:**
   ```bash
   asusctl profile -P Performance
   ```

4. **Check for CPU throttling:**
   ```bash
   sudo turbostat --interval 1
   ```

### Poor Battery Life

**Solutions:**

1. **Install and configure TLP:**
   ```bash
   sudo systemctl enable --now tlp
   ```

2. **Check battery stats:**
   ```bash
   tlp-stat -b
   ```

3. **Use balanced or power-save profile:**
   ```bash
   asusctl profile -P Balanced
   ```

4. **Monitor power usage:**
   ```bash
   sudo powertop
   ```

---

## Boot Issues

### Kernel Panic on Boot

**Solutions:**

1. **Boot with older kernel** (if available in bootloader)

2. **Remove problematic kernel parameters:**
   Edit GRUB at boot (press 'e') and remove recently added parameters

3. **Boot in recovery mode** and:
   ```bash
   sudo apt/dnf/pacman remove linux-headers
   sudo apt/dnf/pacman install linux-headers
   sudo update-grub
   ```

### GRUB Not Showing

**Solutions:**

1. **Boot from live USB**

2. **Reinstall GRUB:**
   ```bash
   sudo mount /dev/sdXY /mnt  # Replace with your root partition
   sudo mount /dev/sdXZ /mnt/boot/efi  # Replace with your EFI partition
   sudo arch-chroot /mnt  # or appropriate chroot method
   grub-install /dev/sdX
   update-grub
   ```

---

## Getting More Help

If you're still experiencing issues:

1. **Check kernel logs:**
   ```bash
   dmesg | less
   journalctl -b | less
   ```

2. **Enable debug output:**
   Add `debug` to kernel parameters temporarily

3. **Visit community forums:**
   - [Asus Linux Project](https://asus-linux.org/)
   - [Level1Techs Forum](https://forum.level1techs.com/)
   - Your distribution's forum

4. **File an issue:**
   [GitHub Issues](https://github.com/th3cavalry/GZ302-Linux-Setup/issues)

---

**Remember to always backup your data before making system changes!**
