# GZ302 Linux Setup

Easy setup scripts for your ASUS ROG Flow Z13 (GZ302) laptop. Makes Linux work perfectly with your hardware and games!

## 🚀 NEW: Universal Setup Script

**For the easiest experience, use our new universal script that automatically detects your Linux distribution:**

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_universal_setup.sh -o gz302_setup.sh
chmod +x gz302_setup.sh
sudo ./gz302_setup.sh
```

The universal script supports:
- **Arch-based**: Arch Linux, EndeavourOS, Manjaro
- **Debian-based**: Ubuntu, Pop!_OS, Linux Mint  
- **Fedora-based**: Fedora, Nobara
- **OpenSUSE**: Tumbleweed and Leap

## Individual Distribution Scripts

If you prefer distribution-specific scripts, you can still use these:

- **`arch_setup.sh`** - Arch Linux
- **`ubuntu_setup.sh`** - Ubuntu
- **`fedora_setup.sh`** - Fedora  
- **`popos_setup.sh`** - Pop!_OS
- **`manjaro_setup.sh`** - Manjaro
- **`opensuse_setup.sh`** - OpenSUSE
- **`endeavouros_setup.sh`** - EndeavourOS
- **`nobara_setup.sh`** - Nobara
- **`linuxmint_setup.sh`** - Linux Mint

All scripts fix the same hardware issues and can install gaming tools and AI software if you want.

## What Gets Fixed

### Hardware Problems
- **Wi-Fi Issues** - Stops Wi-Fi from disconnecting 
- **Touchpad Problems** - Makes touchpad work properly
- **Audio Issues** - Fixes sound problems
- **Camera Issues** - Gets camera working
- **GPU Problems** - Optimizes graphics performance
- **Power Management** - Better battery life and performance

### What Can Be Installed (Your Choice)
- **Gaming Software** - Steam, game launchers, performance tools
- **AI Software** - Tools for running AI models locally
- **Hypervisor Software** - Virtual machine platforms (KVM/QEMU, VirtualBox, VMware, Xen, Proxmox)
- **System Snapshots** - Automatic backups for easy recovery
- **Secure Boot** - Enhanced security features

## How To Use

**Important:** Always restart your computer after running any script!

### Option 1: Universal Script (Recommended)

The universal script automatically detects your Linux distribution and applies the appropriate setup:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_universal_setup.sh -o gz302_setup.sh
chmod +x gz302_setup.sh
sudo ./gz302_setup.sh
```

### Option 2: Distribution-Specific Scripts

If you prefer to use a distribution-specific script, find your Linux version below:

#### Arch Linux
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/arch_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Ubuntu
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/ubuntu_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Fedora
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/fedora_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Pop!_OS
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/popos_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Manjaro
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/manjaro_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### OpenSUSE
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/opensuse_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### EndeavourOS
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/endeavouros_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Nobara Linux
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/nobara_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Linux Mint
```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/linuxmint_setup.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### Step 2: What The Script Will Ask You

Both the universal script and individual scripts will ask if you want to install extra software:

1. **Gaming Software?** (Steam, game tools, performance monitoring)
2. **AI Software?** (Tools for running AI models on your laptop)  
3. **Hypervisor Software?** (Choose from KVM/QEMU, VirtualBox, VMware, Xen, or Proxmox)
4. **System Snapshots?** (Automatic backups for easy recovery)
5. **Secure Boot?** (Extra security features)

Just answer yes (y) or no (n) for each one! For hypervisors, choose from the numbered options (1-6).

**GZ302-specific hardware fixes are applied automatically** - no user input required.

## Useful Commands (After Setup)

### Power Management
```bash
gz302-tdp gaming      # Maximum performance
gz302-tdp balanced    # Normal use (default)
gz302-tdp efficient   # Save battery
gz302-tdp status      # Check current settings
```

### System Snapshots
```bash
gz302-snapshot create  # Make a backup
gz302-snapshot list    # See all backups
gz302-snapshot cleanup # Remove old backups
```

## Problems? Here's How To Fix Them

### Wi-Fi Not Working
- Restart your computer (this usually fixes it)
- Check if NetworkManager is running: `systemctl status NetworkManager`

### Touchpad Not Working  
- Restart your computer first
- If still broken: `sudo modprobe -r hid_asus && sudo modprobe hid_asus`

### Games Running Slowly
- Make sure you picked the right kernel when booting up
- Check if GameMode is working: `gamemoded -s`
- Use MangoHUD to see performance: `mangohud your_game`

### ASUS Controls Not Working
- Check if services are running: `systemctl status supergfxd asusctl`
- Try restarting them: `sudo systemctl restart supergfxd`

## Need Help?

If something goes wrong:

1. Check error messages: `journalctl -b`
2. Create an issue on GitHub with:
   - What went wrong
   - Error messages you saw
   - Your laptop model (make sure it's GZ302)

## Thanks To

This project builds on great work from:
- [asus-linux.org](https://asus-linux.org) community
- Shahzebqazi's Asus-Z13-Flow-2025-PCMR repository  
- Level1Techs Forum Community
- Arch Linux community

## License

This project is open source under the MIT License.
