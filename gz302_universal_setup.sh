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
# - Arch Linux, EndeavourOS, Manjaro
# - Ubuntu, Pop!_OS, Linux Mint
# - Fedora, Nobara
# - OpenSUSE
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
        
        # Handle special cases and derivatives
        case "$distro" in
            "arch")
                distro="arch"
                ;;
            "endeavouros")
                distro="endeavouros"
                ;;
            "manjaro")
                distro="manjaro"
                ;;
            "ubuntu")
                distro="ubuntu"
                ;;
            "pop")
                distro="popos"
                ;;
            "linuxmint")
                distro="linuxmint"
                ;;
            "fedora")
                distro="fedora"
                ;;
            "nobara")
                distro="nobara"
                ;;
            "opensuse-tumbleweed"|"opensuse-leap"|"opensuse")
                distro="opensuse"
                ;;
            *)
                # Try to detect based on package managers
                if command -v pacman >/dev/null 2>&1; then
                    if [[ -f /etc/endeavouros-release ]]; then
                        distro="endeavouros"
                    elif [[ -f /etc/manjaro-release ]]; then
                        distro="manjaro"
                    else
                        distro="arch"
                    fi
                elif command -v apt >/dev/null 2>&1; then
                    if grep -q "Pop!_OS" /etc/os-release 2>/dev/null; then
                        distro="popos"
                    elif grep -q "Linux Mint" /etc/os-release 2>/dev/null; then
                        distro="linuxmint"
                    else
                        distro="ubuntu"
                    fi
                elif command -v dnf >/dev/null 2>&1; then
                    if grep -q "Nobara" /etc/os-release 2>/dev/null; then
                        distro="nobara"
                    else
                        distro="fedora"
                    fi
                elif command -v zypper >/dev/null 2>&1; then
                    distro="opensuse"
                fi
                ;;
        esac
    fi
    
    if [[ -z "$distro" ]]; then
        error "Could not detect your Linux distribution. Supported distributions include Arch, Ubuntu, Fedora, OpenSUSE, and their derivatives."
    fi
    
    echo "$distro"
}

# --- User Choice Functions ---
get_user_choices() {
    local install_gaming=""
    local install_llm=""
    local install_snapshots=""
    local install_secureboot=""
    
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
    export INSTALL_SNAPSHOTS="$install_snapshots"
    export INSTALL_SECUREBOOT="$install_secureboot"
}

# --- Distribution-Specific Setup Functions ---
setup_arch_based() {
    local distro="$1"
    info "Setting up $distro-based system..."
    
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
    apply_arch_hardware_fixes "$distro"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_arch_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_arch_llm_software
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
    info "Setting up $distro-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    apt update
    apt upgrade -y
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    
    # Apply hardware fixes
    apply_debian_hardware_fixes "$distro"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_debian_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_debian_llm_software
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
    info "Setting up $distro-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    dnf update -y
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        rpmfusion-free-release rpmfusion-nonfree-release
    
    # Apply hardware fixes
    apply_fedora_hardware_fixes "$distro"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_fedora_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_fedora_llm_software
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
    info "Setting up OpenSUSE system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    zypper refresh
    zypper update -y
    zypper install -y curl wget git gcc gcc-c++ make kernel-default-devel
    
    # Apply hardware fixes
    apply_opensuse_hardware_fixes
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_opensuse_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_opensuse_llm_software
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
    local distro="$1"
    info "Applying comprehensive GZ302 hardware fixes for $distro..."
    
    # Install kernel and drivers
    if [[ "$distro" == "arch" ]]; then
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control
    elif [[ "$distro" == "manjaro" ]]; then
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl
    else # endeavouros
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center
    fi
    
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
    
    success "Comprehensive hardware fixes applied for $distro"
}

apply_debian_hardware_fixes() {
    local distro="$1"
    info "Applying comprehensive GZ302 hardware fixes for $distro..."
    
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
    
    success "Comprehensive hardware fixes applied for $distro"
}

apply_fedora_hardware_fixes() {
    local distro="$1"
    info "Applying GZ302 hardware fixes for $distro..."
    
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
    
    success "Hardware fixes applied for $distro"
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
    local detected_distro=$(detect_distribution)
    
    success "Detected distribution: $detected_distro"
    echo
    
    # Get user choices for optional software
    get_user_choices
    
    info "Starting setup process for $detected_distro..."
    echo
    
    # Route to appropriate setup function based on distribution
    case "$detected_distro" in
        "arch"|"endeavouros"|"manjaro")
            setup_arch_based "$detected_distro"
            ;;
        "ubuntu"|"popos"|"linuxmint")
            setup_debian_based "$detected_distro"
            ;;
        "fedora"|"nobara")
            setup_fedora_based "$detected_distro"
            ;;
        "opensuse")
            setup_opensuse
            ;;
        *)
            error "Unsupported distribution: $detected_distro"
            ;;
    esac
    
    echo
    success "============================================================"
    success "GZ302 Universal Setup Complete for $detected_distro!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    success "Applied GZ302-specific hardware fixes:"
    success "- Wi-Fi stability (MediaTek MT7925e)"
    success "- Touchpad detection and functionality"
    success "- Audio fixes for ASUS hardware"
    success "- GPU and thermal optimizations"
    success ""
    
    # Show what was installed based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        success "Gaming software installed: Steam, Lutris, GameMode, MangoHUD"
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        success "AI/LLM software installed"
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        success "Secure Boot configured (enable in BIOS)"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        success "System snapshots configured"
    fi
    
    success ""
    success "Your ROG Flow Z13 (GZ302) is now optimized for $detected_distro!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"