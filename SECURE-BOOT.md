# Secure Boot Setup Guide for ASUS ROG Flow Z13 2025 (GZ302EA)

This guide provides comprehensive instructions for setting up Secure Boot on the ASUS ROG Flow Z13 2025 with AMD Strix Halo and Radeon 8060S, optimized for Linux installations.

> **Note**: This guide is based on best practices from the [Level1Techs Arch + SecureBoot guide](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652) for similar hardware (HP G1A with Ryzen AI Max and Radeon 8060S).

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [BIOS/UEFI Configuration](#biosuefi-configuration)
- [Arch Linux Installation with Secure Boot](#arch-linux-installation-with-secure-boot)
- [Ubuntu/Debian with Secure Boot](#ubuntudebian-with-secure-boot)
- [Fedora with Secure Boot](#fedora-with-secure-boot)
- [Verifying Secure Boot Status](#verifying-secure-boot-status)
- [Troubleshooting](#troubleshooting)

## Overview

Secure Boot is a UEFI firmware security feature that ensures only trusted software can boot on your system. For Linux users, Secure Boot requires signing your bootloader and kernel with keys that are enrolled in your system's firmware.

### Why Enable Secure Boot?

- **Enhanced Security**: Prevents unauthorized bootloaders and kernels from running
- **Compliance**: Required for some corporate/enterprise environments
- **Protection**: Guards against bootkits and rootkits
- **Future-Proofing**: Increasingly becoming a standard requirement

### Hardware Compatibility

The ASUS ROG Flow Z13 2025 (GZ302EA) features:
- **AMD Strix Halo** processor (Ryzen AI Max architecture)
- **Radeon 8060S** integrated GPU
- **UEFI firmware** with full Secure Boot support
- **TPM 2.0** module

This hardware fully supports Secure Boot with proper configuration.

## Prerequisites

Before beginning, ensure you have:

1. **Fresh installation media** (USB drive, minimum 8GB)
2. **Backup** of any important data
3. **Internet connection** during installation
4. **BIOS password** (optional, but recommended for security)
5. **Basic Linux knowledge** (familiarity with command line)

### Required Tools

Different distributions require different tools:

- **Arch Linux**: `sbctl`, `systemd-boot` or `GRUB`, `efibootmgr`
- **Ubuntu/Debian**: Pre-configured with `shim` and signed kernels
- **Fedora**: Pre-configured with `shim` and signed kernels

## BIOS/UEFI Configuration

### Accessing BIOS

1. **Power off** the device completely
2. **Press F2** or **Del** key repeatedly during boot
3. Navigate to the **Security** or **Boot** tab

### Recommended BIOS Settings

Configure the following settings for optimal Secure Boot operation:

#### Security Settings

- **Secure Boot**: `Enabled` (initially set to `Setup Mode`)
- **Secure Boot Mode**: `Custom` or `Other OS` (not `Windows UEFI`)
- **TPM Device**: `Firmware TPM` or `Enabled`
- **BIOS Password**: `Set` (recommended for additional security)

#### Boot Settings

- **Boot Mode**: `UEFI` (not Legacy or CSM)
- **CSM Support**: `Disabled`
- **Fast Boot**: `Disabled` (initially, can enable later)
- **Boot Device Control**: `UEFI Driver First`

#### Save and Exit

- Save changes and reboot to installation media

## Arch Linux Installation with Secure Boot

Arch Linux provides the most control over Secure Boot configuration using `sbctl`.

### Step 1: Boot Installation Media

Boot from your Arch Linux USB installer.

### Step 2: Complete Base Installation

Follow the standard Arch installation process up to bootloader configuration:

```bash
# Standard Arch installation steps
# 1. Partition disks (use GPT, not MBR)
# 2. Format partitions
# 3. Mount file systems
# 4. Install base system
pacstrap /mnt base linux linux-firmware

# 5. Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Chroot into new system
arch-chroot /mnt
```

### Step 3: Install Required Packages

```bash
# Essential packages for Secure Boot
pacman -S sbctl systemd-boot efibootmgr

# Additional recommended packages
pacman -S amd-ucode mesa vulkan-radeon linux-headers base-devel git
```

### Step 4: Configure systemd-boot

```bash
# Install systemd-boot to EFI partition
bootctl --path=/boot install

# Create loader configuration
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF
```

### Step 5: Create Boot Entry

```bash
# Get your root partition UUID
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)  # Adjust partition as needed

# Create boot entry
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet splash amd_pstate=active iommu=pt
EOF
```

### Step 6: Setup Secure Boot with sbctl

```bash
# Check Secure Boot status
sbctl status

# Create and enroll Secure Boot keys
sbctl create-keys
sbctl enroll-keys --microsoft

# Sign bootloader and kernel
sbctl sign --save /boot/EFI/systemd/systemd-bootx64.efi
sbctl sign --save /boot/EFI/BOOT/BOOTX64.EFI
sbctl sign --save /boot/vmlinuz-linux

# Verify signatures
sbctl verify
```

### Step 7: Setup Automatic Signing

To ensure kernel updates are automatically signed:

```bash
# Enable sbctl pacman hook
systemctl enable sbctl.service

# Create pacman hook for automatic signing
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/99-secureboot.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts
Target = linux-zen
Target = systemd

[Action]
Description = Signing kernel and bootloader for Secure Boot
When = PostTransaction
Exec = /usr/bin/sbctl sign-all
Depends = sbctl
EOF
```

### Step 8: Enable Secure Boot in BIOS

```bash
# Exit chroot and reboot
exit
reboot

# In BIOS:
# 1. Navigate to Security settings
# 2. Set Secure Boot to "Enabled"
# 3. Save and exit
```

### Step 9: Verify Secure Boot

After rebooting into your new system:

```bash
# Check Secure Boot status
sbctl status

# Should show:
# Installed:     ✓ sbctl is installed
# Setup Mode:    ✓ Disabled
# Secure Boot:   ✓ Enabled
```

## Ubuntu/Debian with Secure Boot

Ubuntu and Debian come with pre-signed kernels and use `shim` for Secure Boot, making the process simpler.

### Installation Process

1. **Download** Ubuntu 24.04 LTS or later (or Debian 12+)
2. **Create bootable USB** with Ventoy or Rufus
3. **Boot from USB** (Secure Boot can be enabled in BIOS)
4. **Follow standard installation** - installer handles Secure Boot automatically

### Using Custom Kernels

If you need to sign custom kernels or modules:

```bash
# Install mokutil for key management
sudo apt install mokutil sbsigntool

# Generate signing keys
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv \
  -outform DER -out MOK.der -days 36500 -subj "/CN=My Signing Key/"

# Enroll the key
sudo mokutil --import MOK.der

# Reboot and complete MOK enrollment in blue screen
sudo reboot

# Sign kernel modules (example: NVIDIA driver)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
  sha256 ./MOK.priv ./MOK.der /path/to/module.ko
```

### Post-Installation Setup

After installation, run the setup script:

```bash
# Download and run the GZ302 setup script
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh
chmod +x gz302-setup.sh
sudo ./gz302-setup.sh
```

## Fedora with Secure Boot

Fedora has excellent Secure Boot support out of the box.

### Installation Process

1. **Download** Fedora Workstation 40+ or Fedora Silverblue
2. **Create bootable USB** with Fedora Media Writer
3. **Boot from USB** (Secure Boot should work automatically)
4. **Follow standard installation** - Secure Boot is enabled by default

### Verifying and Managing Secure Boot

```bash
# Check Secure Boot status
mokutil --sb-state

# Should show: SecureBoot enabled

# List enrolled keys
mokutil --list-enrolled

# For custom kernels, enroll your own key
sudo mokutil --import /path/to/your/key.der
```

### Post-Installation

```bash
# Download and run the setup script
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh
chmod +x gz302-setup.sh
sudo ./gz302-setup.sh
```

## Verifying Secure Boot Status

### From Within Linux

```bash
# Method 1: Using bootctl (systemd-based systems)
bootctl status | grep "Secure Boot"

# Method 2: Check EFI variables
cat /sys/firmware/efi/efivars/SecureBoot-* | od -An -t u1

# Method 3: Using mokutil (Ubuntu/Fedora)
mokutil --sb-state

# Method 4: Using sbctl (Arch with sbctl)
sbctl status
```

### Expected Output

- **Secure Boot enabled**: System is properly configured
- **Secure Boot disabled**: Need to enable in BIOS
- **Setup Mode enabled**: Keys not properly enrolled

## Troubleshooting

### Common Issues and Solutions

#### Issue: System Won't Boot After Enabling Secure Boot

**Solution**:
1. Boot into BIOS (F2 or Del during startup)
2. Temporarily disable Secure Boot
3. Boot into Linux
4. Re-verify all signatures: `sbctl verify`
5. Re-sign any missing files: `sbctl sign --save /path/to/file`
6. Re-enable Secure Boot

#### Issue: "Verification Failed" Error on Boot

**Cause**: Bootloader or kernel not properly signed

**Solution**:
```bash
# Boot with Secure Boot disabled
# Then re-sign everything:
sudo sbctl sign --save /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign --save /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign --save /boot/vmlinuz-linux
sudo sbctl verify
```

#### Issue: Custom Kernel Modules Won't Load

**Cause**: Unsigned kernel modules

**Solution (Arch)**:
```bash
# Sign the module
sudo sbctl sign --save /usr/lib/modules/$(uname -r)/kernel/path/to/module.ko

# Or use DKMS with automatic signing
sudo dkms autoinstall
```

**Solution (Ubuntu/Debian)**:
```bash
# Sign with your MOK key
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
  sha256 /path/to/MOK.priv /path/to/MOK.der /path/to/module.ko
```

#### Issue: Dual Boot with Windows Broken

**Solution**:
1. Keep Microsoft keys enrolled: `sbctl enroll-keys --microsoft`
2. Ensure Windows Boot Manager is in EFI boot order
3. Update bootloader to include Windows entry

```bash
# For systemd-boot, create Windows entry
cat > /boot/loader/entries/windows.conf <<EOF
title   Windows
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF
```

#### Issue: TPM Errors or Warnings

**Solution**:
1. Enable TPM in BIOS (set to "Firmware TPM")
2. Clear TPM if needed: BIOS → Security → TPM → Clear
3. Re-enroll Secure Boot keys after TPM clear

### Additional Resources

#### Arch Linux
- [Arch Wiki - Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
- [sbctl GitHub Repository](https://github.com/Foxboron/sbctl)

#### Ubuntu/Debian
- [Ubuntu SecureBoot Documentation](https://wiki.ubuntu.com/UEFI/SecureBoot)
- [Debian SecureBoot Wiki](https://wiki.debian.org/SecureBoot)

#### Fedora
- [Fedora SecureBoot Documentation](https://docs.fedoraproject.org/en-US/fedora/latest/install-guide/install/Booting_the_Installation/)

#### Hardware-Specific
- [Level1Techs - Ultimate Arch + SecureBoot Guide (HP G1A)](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652)
- [ASUS Linux Project](https://asus-linux.org/)

## Advanced Configuration

### Unified Kernel Images (UKI)

For maximum security, use Unified Kernel Images which combine kernel, initramfs, and cmdline into a single signed EFI binary:

```bash
# Install required tools
pacman -S mkinitcpio

# Configure mkinitcpio for UKI
cat >> /etc/mkinitcpio.d/linux.preset <<EOF
# UKI generation
PRESETS=('default' 'fallback')

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode=(/boot/*-ucode.img)

default_uki="/boot/EFI/Linux/arch-linux.efi"
default_options="--splash=/usr/share/systemd/bootctl/splash-arch.bmp"

fallback_uki="/boot/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
EOF

# Generate UKI
mkinitcpio -P

# Sign the UKI
sbctl sign --save /boot/EFI/Linux/arch-linux.efi
sbctl sign --save /boot/EFI/Linux/arch-linux-fallback.efi
```

### Custom Kernel Parameters for GZ302EA

Optimal kernel parameters for the ASUS ROG Flow Z13 2025:

```
# /boot/loader/entries/arch.conf
options root=UUID=xxx rw quiet splash \
  amd_pstate=active \
  iommu=pt \
  amdgpu.dc=1 \
  amdgpu.gpu_recovery=1 \
  amdgpu.ppfeaturemask=0xffffffff \
  split_lock_detect=off
```

### Hardware-Specific Optimizations

```bash
# Enable AMD P-State driver (better power management)
echo "amd_pstate" > /etc/modules-load.d/amd-pstate.conf

# Optimize for Strix Halo architecture
cat > /etc/modprobe.d/amdgpu.conf <<EOF
options amdgpu dc=1
options amdgpu gpu_recovery=1
EOF

# Optimize for MediaTek MT7925 WiFi
cat > /etc/modprobe.d/mt7921e.conf <<EOF
options mt7921e disable_aspm=N
EOF
```

## Security Best Practices

1. **Set a BIOS password** to prevent Secure Boot from being disabled
2. **Regularly update firmware** via ASUS/MyASUS updates
3. **Keep signing keys secure** - back them up to encrypted storage
4. **Use full disk encryption** (LUKS) in addition to Secure Boot
5. **Verify signatures** after kernel/bootloader updates
6. **Monitor boot logs** for any verification warnings

## Conclusion

Secure Boot on the ASUS ROG Flow Z13 2025 provides an additional layer of security without sacrificing performance or functionality. With proper configuration, you can enjoy a fully secure Linux system while taking advantage of the powerful AMD Strix Halo and Radeon 8060S hardware.

For additional support:
- ASUS Linux Community: https://asus-linux.org/
- Level1Techs Forum: https://forum.level1techs.com/
- GitHub Issues: https://github.com/th3cavalry/GZ302-Linux-Setup/issues

---

**Last Updated**: October 14, 2025  
**Tested with**: Arch Linux (kernel 6.15+), Ubuntu 24.04, Fedora 40
