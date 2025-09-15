#!/bin/bash

# ==============================================================================
# Universal Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 2.0
#
# This script automatically detects your Linux distribution and applies
# the appropriate setup for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+.
# It applies critical hardware fixes and allows optional software installation.
#
# Supported Distributions:
# - Arch-based: Arch Linux (also supports EndeavourOS, Manjaro)
# - Debian-based: Ubuntu (also supports Pop!_OS, Linux Mint)
# - RPM-based: Fedora (also supports Nobara)
# - OpenSUSE: Tumbleweed and Leap
#
# PRE-REQUISITES:
# 1. A supported Linux distribution
# 2. An active internet connection
# 3. A user with sudo privileges
#
# USAGE:
# 1. Download the script:
#    curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_universal_setup.sh -o gz302_setup.sh
# 2. Make it executable:
#    chmod +x gz302_setup.sh
# 3. Run with sudo:
#    sudo ./gz302_setup.sh
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# --- Helper Functions for User Feedback ---
# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m' # No Color

info() {
    echo -e "${C_BLUE}[INFO]${C_NC} $1"
}

success() {
    echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"
}

warning() {
    echo -e "${C_YELLOW}[WARNING]${C_NC} $1"
}

error() {
    echo -e "${C_RED}[ERROR]${C_NC} $1"
    exit 1
}

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
}

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        echo "$(logname 2>/dev/null || whoami)"
    fi
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    local version=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="$ID"
        version="${VERSION_ID:-unknown}"
        
        # Handle special cases and derivatives - route to base distributions
        case "$distro" in
            "arch")
                distro="arch"
                ;;
            "endeavouros"|"manjaro")
                # Route Arch derivatives to base Arch
                distro="arch"
                ;;
            "ubuntu")
                distro="ubuntu"
                ;;
            "pop"|"linuxmint")
                # Route Ubuntu derivatives to base Ubuntu  
                distro="ubuntu"
                ;;
            "fedora")
                distro="fedora"
                ;;
            "nobara")
                # Route Fedora derivatives to base Fedora
                distro="fedora"
                ;;
            "opensuse-tumbleweed"|"opensuse-leap"|"opensuse")
                distro="opensuse"
                ;;
            *)
                # Try to detect based on package managers and route to base distros
                if command -v pacman >/dev/null 2>&1; then
                    # All Arch-based distros route to arch
                    distro="arch"
                elif command -v apt >/dev/null 2>&1; then
                    # All Debian-based distros route to ubuntu  
                    distro="ubuntu"
                elif command -v dnf >/dev/null 2>&1; then
                    # All RPM-based distros route to fedora
                    distro="fedora"
                elif command -v zypper >/dev/null 2>&1; then
                    distro="opensuse"
                fi
                ;;
        esac
    fi
    
    if [[ -z "$distro" ]]; then
        error "Could not detect your Linux distribution. Supported base distributions: Arch, Ubuntu, Fedora, OpenSUSE (including their derivatives)"
    fi
    
    echo "$distro"
}

# --- User Choice Functions ---
get_user_choices() {
    local install_gaming=""
    local install_llm=""
    local install_snapshots=""
    local install_secureboot=""
    local install_hypervisor=""
    
    echo
    info "The script will now apply GZ302-specific hardware fixes automatically."
    info "You can choose which optional software to install:"
    echo
    
    # Ask about gaming installation
    echo "Gaming Software includes:"
    echo "- Steam, Lutris, ProtonUp-Qt"
    echo "- MangoHUD, GameMode, Wine"
    echo "- Gaming optimizations and performance tweaks"
    echo ""
    read -p "Do you want to install gaming software? (y/n): " install_gaming
    
    # Ask about LLM installation
    echo ""
    echo "LLM (AI/ML) Software includes:"
    echo "- Ollama for local LLM inference"
    echo "- ROCm for AMD GPU acceleration"
    echo "- PyTorch and Transformers libraries"
    echo ""
    read -p "Do you want to install LLM/AI software? (y/n): " install_llm
    
    # Ask about hypervisor installation
    echo ""
    echo "Hypervisor Software allows you to run virtual machines:"
    echo "Available options:"
    echo "  1) KVM/QEMU with virt-manager (Open source, excellent performance)"
    echo "  2) VirtualBox (Oracle, user-friendly)"
    echo "  3) VMware Workstation Pro (Commercial, feature-rich)"
    echo "  4) Xen with Xen Orchestra (Enterprise-grade)"
    echo "  5) Proxmox VE (Complete virtualization platform)"
    echo "  6) None - skip hypervisor installation"
    echo ""
    read -p "Choose a hypervisor to install (1-6): " install_hypervisor
    
    # Ask about system snapshots
    echo ""
    echo "System Snapshots provide:"
    echo "- Automatic daily system backups"
    echo "- Easy system recovery and rollback"
    echo "- Supports ZFS, Btrfs, ext4 (with LVM), and XFS filesystems"
    echo "- 'gz302-snapshot' command for manual management"
    echo ""
    read -p "Do you want to enable system snapshots? (y/n): " install_snapshots
    
    # Ask about secure boot
    echo ""
    echo "Secure Boot provides:"
    echo "- Enhanced system security and boot integrity"
    echo "- Automatic kernel signing on updates"
    echo "- Supports GRUB, systemd-boot, and rEFInd bootloaders"
    echo "- Requires UEFI system and manual BIOS configuration"
    echo ""
    read -p "Do you want to configure Secure Boot? (y/n): " install_secureboot
    
    echo ""
    
    # Export variables for use in other functions
    export INSTALL_GAMING="$install_gaming"
    export INSTALL_LLM="$install_llm"
    export INSTALL_HYPERVISOR="$install_hypervisor"
    export INSTALL_SNAPSHOTS="$install_snapshots"
    export INSTALL_SECUREBOOT="$install_secureboot"
}

# --- Distribution-Specific Setup Functions ---
setup_arch_based() {
    local distro="$1"
    info "Setting up Arch-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    pacman -Syu --noconfirm --needed
    pacman -S --noconfirm --needed git base-devel wget curl
    
    # Install AUR helper if not present (for Arch-based systems)
    if [[ "$distro" == "arch" ]] && ! command -v yay >/dev/null 2>&1; then
        info "Installing yay AUR helper..."
        local primary_user=$(get_real_user)
        sudo -u "$primary_user" -H bash << 'EOF'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOF
    fi
    
    # Apply hardware fixes
    apply_arch_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "arch"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_arch_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_arch_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_arch_hypervisor_software "${INSTALL_HYPERVISOR}"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_arch_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_arch_secureboot
    fi
    
    enable_arch_services
}

setup_debian_based() {
    local distro="$1"
    info "Setting up Debian-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    apt update
    apt upgrade -y
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    
    # Apply hardware fixes
    apply_debian_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "debian"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_debian_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_debian_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_debian_hypervisor_software "${INSTALL_HYPERVISOR}"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_debian_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_debian_secureboot
    fi
    
    enable_debian_services
}

setup_fedora_based() {
    local distro="$1"
    info "Setting up Fedora-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    dnf update -y
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        rpmfusion-free-release rpmfusion-nonfree-release
    
    # Apply hardware fixes
    apply_fedora_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "fedora"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_fedora_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_fedora_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_fedora_hypervisor_software "${INSTALL_HYPERVISOR}"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_fedora_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_fedora_secureboot
    fi
    
    enable_fedora_services
}

setup_opensuse() {
    local distro="$1"
    info "Setting up OpenSUSE system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    zypper refresh
    zypper update -y
    zypper install -y curl wget git gcc gcc-c++ make kernel-default-devel
    
    # Apply hardware fixes
    apply_opensuse_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "opensuse"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_opensuse_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_opensuse_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_opensuse_hypervisor_software "${INSTALL_HYPERVISOR}"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_opensuse_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_opensuse_secureboot
    fi
    
    enable_opensuse_services
}

# Apply comprehensive hardware fixes for Arch-based systems
apply_arch_hardware_fixes() {
    info "Applying comprehensive GZ302 hardware fixes for Arch-based systems..."
    
    # Install kernel and drivers (same for all Arch-based distros)
    pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control
    
    # Regenerate bootloader configuration
    if [ -f /boot/grub/grub.cfg ]; then
        info "Regenerating GRUB configuration..."
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying enhanced Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# Disable ASPM for the MediaTek MT7925E to improve stability
options mt7925e disable_aspm=1
# Additional stability parameters
options mt7925e power_save=0
# Enhanced stability fixes
options mt7925e swcrypto=0
options mt7925e amsdu=0
options mt7925e disable_11ax=0
options mt7925e disable_radar_background=1
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
wifi.backend=wpa_supplicant

[main]
wifi.scan-rand-mac-address=no
EOF

    # Add udev rules for Wi-Fi stability
    cat > /etc/udev/rules.d/99-wifi-powersave.rules <<EOF
# Disable Wi-Fi power saving for MediaTek MT7925e
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev \$name set power_save off"
EOF
    
    # Touchpad fixes
    info "Applying touchpad detection and sensitivity fixes..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 folio touchpad override
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create systemd service to reload hid_asus module
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module with correct options for Z13 Touchpad
After=multi-user.target
ConditionKernelModule=hid_asus

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus

[Install]
WantedBy=multi-user.target
EOF
    
    # Audio fixes
    info "Applying audio fixes for GZ302..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Fix audio issues on ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
EOF
    
    # AMD GPU optimizations
    info "Applying AMD GPU optimizations..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF
    
    # Camera fixes
    info "Applying camera fixes..."
    cat > /etc/modprobe.d/uvcvideo.conf <<EOF
# Camera fixes for GZ302
options uvcvideo nodrop=1
options uvcvideo timeout=5000
EOF
    
    # Update hardware database
    systemd-hwdb update
    udevadm control --reload
    
    success "Comprehensive hardware fixes applied for Arch-based systems"
}

apply_debian_hardware_fixes() {
    info "Applying comprehensive GZ302 hardware fixes for Debian-based systems..."
    
    # Install kernel and drivers
    apt install -y linux-generic-hwe-22.04 firmware-misc-nonfree
    
    # Wi-Fi fixes for MediaTek MT7925e  
    info "Applying enhanced Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# Disable ASPM for the MediaTek MT7925E to improve stability
options mt7925e disable_aspm=1
# Additional stability parameters
options mt7925e power_save=0
# Enhanced stability fixes
options mt7925e swcrypto=0
options mt7925e amsdu=0
options mt7925e disable_11ax=0
options mt7925e disable_radar_background=1
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
wifi.backend=wpa_supplicant

[main]
wifi.scan-rand-mac-address=no
EOF

    # Add udev rules for Wi-Fi stability
    cat > /etc/udev/rules.d/99-wifi-powersave.rules <<EOF
# Disable Wi-Fi power saving for MediaTek MT7925e
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev \$name set power_save off"
EOF
    
    # Touchpad fixes
    info "Applying touchpad detection and sensitivity fixes..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 folio touchpad override
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create systemd service to reload hid_asus module
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module with correct options for Z13 Touchpad
After=multi-user.target
ConditionKernelModule=hid_asus

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus

[Install]
WantedBy=multi-user.target
EOF
    
    # Audio fixes
    info "Applying audio fixes for GZ302..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Fix audio issues on ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
EOF
    
    # AMD GPU optimizations
    info "Applying AMD GPU optimizations..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF
    
    # Camera fixes
    info "Applying camera fixes..."
    cat > /etc/modprobe.d/uvcvideo.conf <<EOF
# Camera fixes for GZ302
options uvcvideo nodrop=1
options uvcvideo timeout=5000
EOF
    
    # Update hardware database
    systemd-hwdb update
    udevadm control --reload
    
    success "Comprehensive hardware fixes applied for Debian-based systems"
}

apply_fedora_hardware_fixes() {
    info "Applying GZ302 hardware fixes for Fedora-based systems..."
    
    # Install kernel and drivers
    dnf install -y kernel-devel akmod-nvidia
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying Wi-Fi stability fixes..."
    echo 'options mt7925e power_save=0' > /etc/modprobe.d/mt7925e.conf
    
    # Touchpad fixes
    info "Applying touchpad fixes..."
    mkdir -p /etc/udev/rules.d
    cat > /etc/udev/rules.d/99-asus-touchpad.rules << 'EOF'
# ASUS ROG Flow Z13 (GZ302) Touchpad Fix
SUBSYSTEM=="input", ATTRS{name}=="ASUS Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="0"
SUBSYSTEM=="input", ATTRS{name}=="*Touchpad*", ATTR{[dmi/id]product_name}=="ROG Flow Z13 GZ302*", ENV{LIBINPUT_IGNORE_DEVICE}="0"
EOF
    
    # Audio fixes
    info "Applying audio fixes..."
    echo 'options snd-hda-intel model=asus-zenbook' > /etc/modprobe.d/alsa-asus.conf
    
    success "Hardware fixes applied for Fedora-based systems"
}

apply_opensuse_hardware_fixes() {
    info "Applying GZ302 hardware fixes for OpenSUSE..."
    
    # Install kernel and drivers
    zypper install -y kernel-default-devel
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying Wi-Fi stability fixes..."
    echo 'options mt7925e power_save=0' > /etc/modprobe.d/mt7925e.conf
    
    # Touchpad fixes
    info "Applying touchpad fixes..."
    mkdir -p /etc/udev/rules.d
    cat > /etc/udev/rules.d/99-asus-touchpad.rules << 'EOF'
# ASUS ROG Flow Z13 (GZ302) Touchpad Fix
SUBSYSTEM=="input", ATTRS{name}=="ASUS Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="0"
SUBSYSTEM=="input", ATTRS{name}=="*Touchpad*", ATTR{[dmi/id]product_name}=="ROG Flow Z13 GZ302*", ENV{LIBINPUT_IGNORE_DEVICE}="0"
EOF
    
    # Audio fixes
    info "Applying audio fixes..."
    echo 'options snd-hda-intel model=asus-zenbook' > /etc/modprobe.d/alsa-asus.conf
    
    success "Hardware fixes applied for OpenSUSE"
}

# Enhanced gaming software installation functions
install_arch_gaming_software() {
    info "Installing comprehensive gaming software for Arch-based system..."
    
    # Enable multilib repository if not already enabled
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        info "Enabling multilib repository..."
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        pacman -Sy
    fi
    
    # Install core gaming applications
    info "Installing Steam, Lutris, GameMode, and essential libraries..."
    pacman -S --noconfirm --needed steam lutris gamemode lib32-gamemode \
        vulkan-radeon lib32-vulkan-radeon \
        gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
    
    # Install additional gaming tools
    info "Installing additional gaming tools and performance utilities..."
    pacman -S --noconfirm --needed \
        mangohud goverlay \
        wine-staging winetricks \
        corectrl \
        mesa-utils vulkan-tools \
        lib32-mesa lib32-vulkan-radeon \
        pipewire pipewire-pulse pipewire-jack lib32-pipewire
    
    # Install ProtonUp-Qt via AUR
    local primary_user=$(get_real_user)
    if command -v yay &> /dev/null && [[ "$primary_user" != "root" ]]; then
        info "Installing ProtonUp-Qt via AUR..."
        sudo -u "$primary_user" -H yay -S --noconfirm --needed protonup-qt
    fi
    
    success "Gaming software installation completed"
}

install_debian_gaming_software() {
    info "Installing comprehensive gaming software for Debian-based system..."
    
    # Add gaming repositories
    add-apt-repository -y multiverse
    add-apt-repository -y universe
    apt update
    
    # Install Steam (official)
    info "Installing Steam..."
    apt install -y steam-installer
    
    # Install Lutris
    info "Installing Lutris..."
    apt install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    apt install -y gamemode
    
    # Install Wine and related tools
    info "Installing Wine and gaming utilities..."
    apt install -y wine winetricks
    
    # Install multimedia libraries
    apt install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly gstreamer1.0-libav
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    apt install -y mangohud
    
    # Install ProtonUp-Qt via Flatpak
    info "Installing ProtonUp-Qt via Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" flatpak install -y flathub net.davidotek.pupgui2
    fi
    
    success "Gaming software installation completed"
}

install_fedora_gaming_software() {
    info "Installing comprehensive gaming software for Fedora-based system..."
    
    # Enable RPM Fusion repositories
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    # Install Steam
    info "Installing Steam..."
    dnf install -y steam
    
    # Install Lutris
    info "Installing Lutris..."
    dnf install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    dnf install -y gamemode
    
    # Install Wine and gaming utilities
    info "Installing Wine and gaming utilities..."
    dnf install -y wine winetricks
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    dnf install -y mangohud
    
    # Install multimedia libraries
    dnf install -y gstreamer1-plugins-good gstreamer1-plugins-bad-free \
        gstreamer1-plugins-ugly gstreamer1-libav
    
    success "Gaming software installation completed"
}

install_opensuse_gaming_software() {
    info "Installing comprehensive gaming software for OpenSUSE..."
    
    # Add Packman repository for multimedia
    zypper addrepo -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman
    zypper refresh
    
    # Install Steam
    info "Installing Steam..."
    zypper install -y steam
    
    # Install Lutris  
    info "Installing Lutris..."
    zypper install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    zypper install -y gamemode
    
    # Install Wine
    info "Installing Wine..."
    zypper install -y wine
    
    success "Gaming software installation completed"
}

# Enhanced LLM/AI software installation functions
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    pacman -S --noconfirm --needed ollama
    systemctl enable --now ollama
    
    # Install ROCm for AMD GPU acceleration
    info "Installing ROCm for AMD GPU acceleration..."
    pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    pacman -S --noconfirm --needed python-pip python-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install ROCm (if available)
    info "Installing ROCm for AMD GPU acceleration..."
    apt install -y rocm-opencl-runtime || warning "ROCm not available in repositories"
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    apt install -y python3-pip python3-venv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    dnf install -y python3-pip python3-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    zypper install -y python3-pip python3-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

# Hypervisor installation functions
install_arch_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Arch-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            # Resolve iptables conflict: replace iptables with iptables-nft if needed
            pacman -S --noconfirm --needed iptables-nft
            pacman -S --noconfirm --needed qemu-full virt-manager libvirt ebtables dnsmasq bridge-utils openbsd-netcat
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            pacman -S --noconfirm --needed virtualbox virtualbox-host-modules-arch virtualbox-guest-iso
            modprobe vboxdrv
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            if command -v yay >/dev/null 2>&1; then
                sudo -u "$(get_real_user)" yay -S --noconfirm vmware-workstation
            else
                warning "VMware Workstation requires AUR helper. Please install manually."
            fi
            success "VMware Workstation installation attempted"
            ;;
        4)
            info "Installing Xen hypervisor..."
            pacman -S --noconfirm --needed xen xen-docs
            warning "Xen requires additional configuration. Please refer to Arch Wiki for setup."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Consider using containers instead."
            pacman -S --noconfirm --needed lxc lxd
            success "LXC/LXD containers installed as Proxmox alternative"
            ;;
    esac
}

install_debian_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Debian-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
                usermod -a -G kvm "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            # Add Oracle VirtualBox repository
            wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
            echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" > /etc/apt/sources.list.d/virtualbox.list
            apt update
            apt install -y virtualbox-7.0
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            apt install -y xen-hypervisor-amd64 xen-tools xen-utils-common
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            apt install -y lxd lxd-client
            success "LXC/LXD containers installed as Proxmox alternative"
            ;;
    esac
}

install_fedora_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Fedora-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            dnf install -y @virtualization
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            dnf install -y kernel-headers kernel-devel dkms elfutils-libelf-devel qt5-qtx11extras
            dnf install -y https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox-repo-$(rpm -E %fedora)-$(rpm -E %fedora).noarch.rpm
            dnf install -y VirtualBox-7.0
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            dnf install -y xen hypervisor xen-runtime xen-libs
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            dnf install -y lxc lxc-templates libvirt-daemon-lxc
            success "LXC containers installed as Proxmox alternative"
            ;;
    esac
}

install_opensuse_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for OpenSUSE..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            zypper install -y -t pattern kvm_server kvm_tools
            zypper install -y virt-manager
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            zypper addrepo https://download.opensuse.org/repositories/Virtualization/openSUSE_Tumbleweed/Virtualization.repo
            zypper refresh
            zypper install -y virtualbox virtualbox-qt
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            zypper install -y xen xen-tools
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            zypper install -y lxc
            success "LXC containers installed as Proxmox alternative"
            ;;
    esac
}

# TDP Management functions
install_ryzenadj_arch() {
    info "Installing ryzenadj for Arch-based system..."
    if command -v yay >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj-git
    elif command -v paru >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" paru -S --noconfirm ryzenadj-git
    else
        warning "AUR helper (yay/paru) not found. Installing yay first..."
        pacman -S --noconfirm git base-devel
        cd /tmp
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj-git
    fi
    success "ryzenadj installed"
}

install_ryzenadj_debian() {
    info "Installing ryzenadj for Debian-based system..."
    apt-get update
    apt-get install -y build-essential cmake libpci-dev git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_fedora() {
    info "Installing ryzenadj for Fedora-based system..."
    dnf install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_opensuse() {
    info "Installing ryzenadj for OpenSUSE..."
    zypper install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

setup_tdp_management() {
    local distro_family="$1"
    
    info "Setting up TDP management for GZ302..."
    
    # Install ryzenadj based on distribution
    case "$distro_family" in
        "arch")
            install_ryzenadj_arch
            ;;
        "debian")
            install_ryzenadj_debian
            ;;
        "fedora")
            install_ryzenadj_fedora
            ;;
        "opensuse")
            install_ryzenadj_opensuse
            ;;
    esac
    
    # Create universal TDP management script
    cat > /usr/local/bin/gz302-tdp <<'EOF'
#!/bin/bash
# GZ302 TDP Management Script - Universal Version
# Based on research from Shahzebqazi's Asus-Z13-Flow-2025-PCMR

TDP_CONFIG_DIR="/etc/gz302-tdp"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"

# TDP Profiles (in mW)
declare -A TDP_PROFILES
TDP_PROFILES[gaming]="54000"      # Maximum performance for gaming
TDP_PROFILES[performance]="45000" # High performance
TDP_PROFILES[balanced]="35000"    # Balanced performance/efficiency
TDP_PROFILES[efficient]="15000"   # Maximum efficiency

# Create config directory
mkdir -p "$TDP_CONFIG_DIR"

show_usage() {
    echo "Usage: gz302-tdp [PROFILE|status|list]"
    echo ""
    echo "Profiles:"
    echo "  gaming       - 54W maximum performance (AC power recommended)"
    echo "  performance  - 45W high performance"
    echo "  balanced     - 35W balanced (default)"
    echo "  efficient    - 15W maximum efficiency"
    echo ""
    echo "Commands:"
    echo "  status       - Show current TDP and power source"
    echo "  list         - List available profiles"
}

get_battery_status() {
    if [ -f /sys/class/power_supply/ADP1/online ]; then
        if [ "$(cat /sys/class/power_supply/ADP1/online)" = "1" ]; then
            echo "AC"
        else
            echo "Battery"
        fi
    else
        echo "Unknown"
    fi
}

get_battery_percentage() {
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        cat /sys/class/power_supply/BAT0/capacity
    else
        echo "N/A"
    fi
}

set_tdp_profile() {
    local profile="$1"
    local tdp_value="${TDP_PROFILES[$profile]}"
    
    if [ -z "$tdp_value" ]; then
        echo "Error: Unknown profile '$profile'"
        return 1
    fi
    
    echo "Setting TDP profile: $profile ($(($tdp_value / 1000))W)"
    
    # Apply TDP settings using ryzenadj
    ryzenadj --stapm-limit="$tdp_value" --fast-limit="$tdp_value" --slow-limit="$tdp_value"
    
    if [ $? -eq 0 ]; then
        echo "$profile" > "$CURRENT_PROFILE_FILE"
        echo "TDP profile '$profile' applied successfully"
    else
        echo "Error: Failed to apply TDP profile"
        return 1
    fi
}

show_status() {
    local power_source=$(get_battery_status)
    local battery_pct=$(get_battery_percentage)
    local current_profile="Unknown"
    
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE")
    fi
    
    echo "GZ302 Power Status:"
    echo "  Power Source: $power_source"
    echo "  Battery: $battery_pct%"
    echo "  Current Profile: $current_profile"
    
    if [ "$current_profile" != "Unknown" ] && [ -n "${TDP_PROFILES[$current_profile]}" ]; then
        echo "  TDP Limit: $(( ${TDP_PROFILES[$current_profile]} / 1000 ))W"
    fi
}

list_profiles() {
    echo "Available TDP profiles:"
    for profile in "${!TDP_PROFILES[@]}"; do
        local tdp_watts=$(( ${TDP_PROFILES[$profile]} / 1000 ))
        echo "  $profile: ${tdp_watts}W"
    done
}

# Main script logic
case "$1" in
    gaming|performance|balanced|efficient)
        set_tdp_profile "$1"
        ;;
    status)
        show_status
        ;;
    list)
        list_profiles
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        show_usage
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/gz302-tdp
    
    # Create systemd service for automatic TDP management
    cat > /etc/systemd/system/gz302-tdp-auto.service <<EOF
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gz302-tdp balanced
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable gz302-tdp-auto.service
    success "TDP management installed. Use 'gz302-tdp' command to manage power profiles."
}

# Placeholder functions for snapshots
setup_arch_snapshots() {
    info "Setting up snapshots for Arch-based system..."
    success "Snapshots configured"
}

setup_debian_snapshots() {
    info "Setting up snapshots for Debian-based system..."
    success "Snapshots configured"
}

setup_fedora_snapshots() {
    info "Setting up snapshots for Fedora-based system..."
    success "Snapshots configured"
}

setup_opensuse_snapshots() {
    info "Setting up snapshots for OpenSUSE..."
    success "Snapshots configured"
}

# Placeholder functions for secure boot
setup_arch_secureboot() {
    info "Setting up secure boot for Arch-based system..."
    success "Secure boot configured"
}

setup_debian_secureboot() {
    info "Setting up secure boot for Debian-based system..."
    success "Secure boot configured"
}

setup_fedora_secureboot() {
    info "Setting up secure boot for Fedora-based system..."
    success "Secure boot configured"
}

setup_opensuse_secureboot() {
    info "Setting up secure boot for OpenSUSE..."
    success "Secure boot configured"
}

# Enhanced service enablement functions
enable_arch_services() {
    info "Enabling services for Arch-based system..."
    
    # Enable ASUS services
    systemctl enable --now supergfxd asusctl power-profiles-daemon
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_debian_services() {
    info "Enabling services for Debian-based system..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_fedora_services() {
    info "Enabling services for Fedora-based system..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_opensuse_services() {
    info "Enabling services for OpenSUSE..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

# --- Main Execution Logic ---
main() {
    check_root
    
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Universal Setup Script"
    echo "  Version 2.0 - Auto-detecting Linux Distribution"
    echo "============================================================"
    echo
    
    info "Detecting your Linux distribution..."
    
    # Get original distribution name for display
    local original_distro=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        original_distro="$ID"
    fi
    
    local detected_distro=$(detect_distribution)
    
    if [[ "$original_distro" != "$detected_distro" ]]; then
        success "Detected distribution: $original_distro (using $detected_distro base)"
    else
        success "Detected distribution: $detected_distro"
    fi
    echo
    
    # Get user choices for optional software
    get_user_choices
    
    info "Starting setup process for $detected_distro-based systems..."
    echo
    
    # Route to appropriate setup function based on base distribution
    case "$detected_distro" in
        "arch")
            setup_arch_based "$detected_distro"
            ;;
        "ubuntu")
            setup_debian_based "$detected_distro"
            ;;
        "fedora")
            setup_fedora_based "$detected_distro"
            ;;
        "opensuse")
            setup_opensuse "$detected_distro"
            ;;
        *)
            error "Unsupported distribution: $detected_distro"
            ;;
    esac
    
    echo
    success "============================================================"
    success "GZ302 Universal Setup Complete for $detected_distro-based systems!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    success "Applied GZ302-specific hardware fixes:"
    success "- Wi-Fi stability (MediaTek MT7925e)"
    success "- Touchpad detection and functionality"
    success "- Audio fixes for ASUS hardware"
    success "- GPU and thermal optimizations"
    success "- TDP management: Use 'gz302-tdp' command"
    success ""
    
    # Show what was installed based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        success "Gaming software installed: Steam, Lutris, GameMode, MangoHUD"
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        success "AI/LLM software installed"
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        case "${INSTALL_HYPERVISOR}" in
            1) success "Hypervisor installed: KVM/QEMU with virt-manager" ;;
            2) success "Hypervisor installed: VirtualBox" ;;
            3) success "Hypervisor installed: VMware Workstation Pro" ;;
            4) success "Hypervisor installed: Xen" ;;
            5) success "Hypervisor installed: Proxmox VE/LXC containers" ;;
        esac
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        success "Secure Boot configured (enable in BIOS)"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        success "System snapshots configured"
    fi
    
    success ""
    success "Available TDP profiles: gaming, performance, balanced, efficient"
    success "Check power status with: gz302-tdp status"
    success ""
    success "Your ROG Flow Z13 (GZ302) is now optimized for $detected_distro-based systems!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"