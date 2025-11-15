#!/bin/bash

# ==============================================================================
# GZ302 Keyboard RGB Control Module
#
# Author: th3cavalry using Copilot
# Version: 1.0.0
#
# This module installs rogauracore with GZ302 support for full keyboard RGB control.
# The GZ302EA keyboard communicates via USB (0x0b05:0x1a30) and supports:
# - Static RGB colors
# - Color animations (breathing, cycling, rainbow)
# - Brightness control (0-3 levels)
#
# REQUIRES: Linux kernel 6.14+, libusb development libraries
#
# USAGE:
#   sudo ./gz302-rgb.sh [distro]
# ==============================================================================

set -euo pipefail

# --- Script Configuration ---
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Color codes ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

# --- Logging functions ---
error() {
    echo -e "${C_RED}ERROR:${C_NC} $1" >&2
    exit 1
}

info() {
    echo -e "${C_BLUE}INFO:${C_NC} $1"
}

success() {
    echo -e "${C_GREEN}SUCCESS:${C_NC} $1"
}

warning() {
    echo -e "${C_YELLOW}WARNING:${C_NC} $1"
}

# --- Detect distribution ---
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        # Source the OS release file but handle undefined variables
        ID_LIKE=""
        ID=""
        . /etc/os-release
        # Check ID_LIKE first (for derivatives), then fall back to ID
        if [[ "${ID_LIKE:-}" =~ arch ]] || [[ "${ID:-}" == "arch" ]]; then
            echo "arch"
        elif [[ "${ID_LIKE:-}" =~ debian ]] || [[ "${ID:-}" == "debian" ]]; then
            echo "debian"
        elif [[ "${ID_LIKE:-}" =~ fedora ]] || [[ "${ID:-}" == "fedora" ]]; then
            echo "fedora"
        elif [[ "${ID_LIKE:-}" =~ suse ]] || [[ "${ID:-}" =~ opensuse ]]; then
            echo "opensuse"
        elif [[ "${ID:-}" == "ubuntu" ]]; then
            echo "debian"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# --- Check if rogauracore is already installed ---
check_rogauracore_installed() {
    if command -v rogauracore >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# --- Install rogauracore for Arch ---
install_rogauracore_arch() {
    info "Installing rogauracore dependencies for Arch Linux..."
    pacman -S --noconfirm libusb base-devel git
    
    info "Cloning rogauracore with GZ302 support..."
    cd /tmp
    rm -rf rogauracore
    git clone https://github.com/wroberts/rogauracore.git
    cd rogauracore
    
    info "Checking out GZ302 support branch..."
    git remote add syndelis https://github.com/Syndelis/rogauracore.git 2>/dev/null || true
    git fetch syndelis flow-z13 2>/dev/null || true
    git checkout syndelis/flow-z13 2>/dev/null || {
        warning "Could not checkout GZ302 branch, using master (may not have GZ302 support yet)"
    }
    
    info "Building rogauracore from source..."
    autoreconf -i
    ./configure
    make
    
    info "Installing rogauracore..."
    make install
    ldconfig
    
    success "rogauracore installed from source"
}

# --- Install rogauracore for Debian/Ubuntu ---
install_rogauracore_debian() {
    info "Installing rogauracore dependencies for Debian/Ubuntu..."
    apt-get update
    apt-get install -y libusb-1.0-0 libusb-1.0-0-dev build-essential autoconf git
    
    info "Cloning rogauracore with GZ302 support..."
    cd /tmp
    rm -rf rogauracore
    git clone https://github.com/wroberts/rogauracore.git
    cd rogauracore
    
    info "Checking out GZ302 support branch..."
    git remote add syndelis https://github.com/Syndelis/rogauracore.git 2>/dev/null || true
    git fetch syndelis flow-z13 2>/dev/null || true
    git checkout syndelis/flow-z13 2>/dev/null || {
        warning "Could not checkout GZ302 branch, using master (may not have GZ302 support yet)"
    }
    
    info "Building rogauracore from source..."
    autoreconf -i
    ./configure
    make
    
    info "Installing rogauracore..."
    make install
    ldconfig
    
    success "rogauracore installed from source"
}

# --- Install rogauracore for Fedora ---
install_rogauracore_fedora() {
    info "Installing rogauracore dependencies for Fedora..."
    dnf install -y libusb libusb-devel gcc gcc-c++ make autoconf automake git
    
    info "Cloning rogauracore with GZ302 support..."
    cd /tmp
    rm -rf rogauracore
    git clone https://github.com/wroberts/rogauracore.git
    cd rogauracore
    
    info "Checking out GZ302 support branch..."
    git remote add syndelis https://github.com/Syndelis/rogauracore.git 2>/dev/null || true
    git fetch syndelis flow-z13 2>/dev/null || true
    git checkout syndelis/flow-z13 2>/dev/null || {
        warning "Could not checkout GZ302 branch, using master (may not have GZ302 support yet)"
    }
    
    info "Building rogauracore from source..."
    autoreconf -i
    ./configure
    make
    
    info "Installing rogauracore..."
    make install
    ldconfig
    
    success "rogauracore installed from source"
}

# --- Install rogauracore for OpenSUSE ---
install_rogauracore_opensuse() {
    info "Installing rogauracore dependencies for OpenSUSE..."
    zypper install -y libusb-1_0-0 libusb-1_0-devel gcc gcc-c++ make autoconf automake git
    
    info "Cloning rogauracore with GZ302 support..."
    cd /tmp
    rm -rf rogauracore
    git clone https://github.com/wroberts/rogauracore.git
    cd rogauracore
    
    info "Checking out GZ302 support branch..."
    git remote add syndelis https://github.com/Syndelis/rogauracore.git 2>/dev/null || true
    git fetch syndelis flow-z13 2>/dev/null || true
    git checkout syndelis/flow-z13 2>/dev/null || {
        warning "Could not checkout GZ302 branch, using master (may not have GZ302 support yet)"
    }
    
    info "Building rogauracore from source..."
    autoreconf -i
    ./configure
    make
    
    info "Installing rogauracore..."
    make install
    ldconfig
    
    success "rogauracore installed from source"
}

# --- Main installation logic ---
main() {
    echo
    echo "============================================================"
    echo "  GZ302 Keyboard RGB Control Module"
    echo "  Version 1.0.0"
    echo "============================================================"
    echo
    
    # Check if already installed
    if check_rogauracore_installed; then
        success "rogauracore is already installed"
        rogauracore --help >/dev/null 2>&1 || true
        echo
        info "You can now use rogauracore for keyboard RGB control:"
        echo "  sudo rogauracore single_static FF0000  # Red"
        echo "  sudo rogauracore single_static 00FF00  # Green"
        echo "  sudo rogauracore single_static 0000FF  # Blue"
        echo "  sudo rogauracore rainbow_cycle         # Rainbow animation"
        echo "  sudo rogauracore brightness 3          # Max brightness"
        echo "  sudo rogauracore initialize_keyboard   # Wake keyboard"
        echo
        return 0
    fi
    
    # Detect distribution
    distro="${1:-$(detect_distribution)}"
    
    case "$distro" in
        arch)
            install_rogauracore_arch
            ;;
        debian)
            install_rogauracore_debian
            ;;
        fedora)
            install_rogauracore_fedora
            ;;
        opensuse)
            install_rogauracore_opensuse
            ;;
        *)
            error "Unsupported distribution: $distro"
            ;;
    esac
    
    echo
    echo "============================================================"
    echo "  rogauracore Installation Complete!"
    echo "============================================================"
    echo
    success "Keyboard RGB control is now available!"
    echo
    info "Available commands:"
    echo "  Static Colors (hex codes):"
    echo "    sudo rogauracore single_static <HEX>     # e.g., FF0000 for red"
    echo "    sudo rogauracore multi_static <HEX1> <HEX2> ..."
    echo "    sudo rogauracore red|green|blue|yellow|cyan|magenta|white|black"
    echo
    echo "  Animations:"
    echo "    sudo rogauracore single_breathing <HEX>"
    echo "    sudo rogauracore single_colorcycle <SPEED>"
    echo "    sudo rogauracore multi_breathing <HEX1> <HEX2> ..."
    echo "    sudo rogauracore rainbow_cycle"
    echo "    sudo rogauracore rainbow"
    echo
    echo "  Control:"
    echo "    sudo rogauracore brightness <0-3>        # 0=off, 3=max"
    echo "    sudo rogauracore initialize_keyboard     # Wake keyboard"
    echo
    info "GZ302 Keyboard RGB (USB 0x0b05:0x1a30) is now fully supported!"
    echo
    warning "Note: If keyboard backlight stops responding, run:"
    echo "  sudo systemctl restart upower.service"
    echo
}

# --- Run installation ---
main "$@"
