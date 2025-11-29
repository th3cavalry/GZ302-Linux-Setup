#!/bin/bash

# ==============================================================================
# GZ302 Gaming Software Module
# Version: 2.2.0
#
# This module installs gaming software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Steam, Lutris, MangoHUD, GameMode, Wine, and performance tools
#
# This script is designed to be called by gz302-main.sh
# ==============================================================================

set -euo pipefail

# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

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

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# --- Gaming Software Installation Functions ---
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
    local primary_user
    primary_user=$(get_real_user)
    if command -v yay &> /dev/null && [[ "$primary_user" != "root" ]]; then
        info "Installing ProtonUp-Qt via AUR..."
        sudo -u "$primary_user" -H yay -S --noconfirm --needed protonup-qt
    fi
    
    success "Gaming software installation completed"
}

install_debian_gaming_software() {
    info "Installing comprehensive gaming software for Debian-based system..."
    
    # Add gaming repositories
    info "Adding multiverse and universe repositories..."
    add-apt-repository -y multiverse
    add-apt-repository -y universe
    apt update
    
    # Install Steam
    info "Installing Steam..."
    apt install -y steam
    
    # Install Lutris
    info "Installing Lutris..."
    apt install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    apt install -y gamemode
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    apt install -y mangohud
    
    # Install Wine
    info "Installing Wine..."
    dpkg --add-architecture i386
    apt update
    apt install -y wine64 wine32 winetricks
    
    # Install additional gaming utilities
    apt install -y \
        vulkan-tools mesa-vulkan-drivers mesa-utils \
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav
    
    success "Gaming software installation completed"
}

install_fedora_gaming_software() {
    info "Installing comprehensive gaming software for Fedora-based system..."
    
    # Enable RPM Fusion repositories
    info "Enabling RPM Fusion repositories..."
    dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    
    # Install Steam
    info "Installing Steam..."
    dnf install -y steam
    
    # Install Lutris
    info "Installing Lutris..."
    dnf install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    dnf install -y gamemode
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    dnf install -y mangohud
    
    # Install Wine
    info "Installing Wine..."
    dnf install -y wine winetricks
    
    # Install multimedia codecs and libraries
    dnf install -y \
        gstreamer1-plugins-base gstreamer1-plugins-good \
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

# --- Main Execution ---
main() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
    
    local distro="${1:-}"
    
    if [[ -z "$distro" ]]; then
        error "Distribution not specified. This script should be called by gz302-main.sh"
    fi
    
    echo
    echo "============================================================"
    echo "  GZ302 Gaming Software Installation"
    echo "============================================================"
    echo
    
    case "$distro" in
        "arch")
            install_arch_gaming_software
            ;;
        "ubuntu")
            install_debian_gaming_software
            ;;
        "fedora")
            install_fedora_gaming_software
            ;;
        "opensuse")
            install_opensuse_gaming_software
            ;;
        *)
            error "Unsupported distribution: $distro"
            ;;
    esac
    
    echo
    success "Gaming software installation complete!"
    echo
}

main "$@"
