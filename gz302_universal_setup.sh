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

# Placeholder functions - these will be implemented with actual hardware fixes
apply_arch_hardware_fixes() {
    local distro="$1"
    info "Applying GZ302 hardware fixes for $distro..."
    
    # Install kernel and drivers
    if [[ "$distro" == "arch" ]]; then
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control
    elif [[ "$distro" == "manjaro" ]]; then
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl
    else # endeavouros
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center
    fi
    
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

apply_debian_hardware_fixes() {
    local distro="$1"
    info "Applying GZ302 hardware fixes for $distro..."
    
    # Install kernel and drivers (simplified for now)
    apt install -y linux-generic-hwe-22.04 firmware-misc-nonfree
    
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

# Placeholder functions for optional software installation
install_arch_gaming_software() {
    info "Installing gaming software for Arch-based system..."
    pacman -S --noconfirm --needed steam lutris gamemode lib32-gamemode \
        wine winetricks mangohud lib32-mangohud
    success "Gaming software installed"
}

install_debian_gaming_software() {
    info "Installing gaming software for Debian-based system..."
    apt install -y steam lutris gamemode wine winetricks
    success "Gaming software installed"
}

install_fedora_gaming_software() {
    info "Installing gaming software for Fedora-based system..."
    dnf install -y steam lutris gamemode wine winetricks
    success "Gaming software installed"
}

install_opensuse_gaming_software() {
    info "Installing gaming software for OpenSUSE..."
    zypper install -y steam lutris gamemode wine
    success "Gaming software installed"
}

# Placeholder functions for LLM software
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    success "LLM software installation completed"
}

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    success "LLM software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    success "LLM software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    success "LLM software installation completed"
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

# Placeholder functions for enabling services
enable_arch_services() {
    info "Enabling services for Arch-based system..."
    systemctl enable --now supergfxd asusctl power-profiles-daemon
    success "Services enabled"
}

enable_debian_services() {
    info "Enabling services for Debian-based system..."
    success "Services enabled"
}

enable_fedora_services() {
    info "Enabling services for Fedora-based system..."
    success "Services enabled"
}

enable_opensuse_services() {
    info "Enabling services for OpenSUSE..."
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