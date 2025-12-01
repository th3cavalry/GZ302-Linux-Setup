#!/bin/bash

# ==============================================================================
# GZ302 Gaming Software Module
# Version: 2.3.3
#
# This module installs gaming software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Steam, Lutris, MangoHUD, GameMode, Wine, and performance tools
#
# This script is designed to be called by gz302-main.sh
# ==============================================================================

set -euo pipefail

# --- Script directory detection ---
resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="${dir}/${source}"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_dir)}"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -L "${GITHUB_RAW_URL}/gz302-utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/gz302-utils.sh" -O "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download gz302-utils.sh"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-utils.sh"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: Failed to download gz302-utils.sh"
        exit 1
    fi
fi

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
