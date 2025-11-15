#!/bin/bash

# ==============================================================================
# GZ302 Keyboard RGB Control Module
#
# Author: th3cavalry using Copilot
# Version: 1.1.0
#
# This module compiles and installs a minimal, GZ302-specific RGB keyboard CLI.
# The GZ302EA keyboard communicates via USB (0x0b05:0x1a30) and supports:
# - Static RGB colors (hex values)
# - Color animations (breathing, cycling, rainbow)
# - Brightness control (0-3 levels)
#
# Implementation: Derived from rogauracore (MIT License)
# Original: https://github.com/Syndelis/rogauracore
# GZ302 Optimizations:
#   - Removed multi-model support (GZ302 only)
#   - Minimal binary size: 17KB vs 58KB original
#   - Clean C implementation with full MIT license attribution
#
# REQUIRES: Linux kernel 6.14+, libusb development libraries, gcc
#
# USAGE:
#   sudo ./gz302-rgb.sh [distro]
# ==============================================================================

set -euo pipefail

# --- Script Configuration ---
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_PATH="/usr/local/bin/gz302-rgb"

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
        ID_LIKE=""
        ID=""
        . /etc/os-release
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

# --- Check if gz302-rgb is already installed ---
check_rgb_installed() {
    if [[ -f "$BINARY_PATH" ]]; then
        return 0
    else
        return 1
    fi
}

# --- Install build dependencies and compile for Arch ---
install_rgb_arch() {
    info "Installing build dependencies for Arch Linux..."
    pacman -S --noconfirm libusb base-devel pkg-config

    info "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0)
    
    info "Installing compiled binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    
    success "GZ302 RGB keyboard CLI compiled and installed"
}

# --- Install build dependencies and compile for Debian/Ubuntu ---
install_rgb_debian() {
    info "Installing build dependencies for Debian/Ubuntu..."
    apt-get update
    apt-get install -y libusb-1.0-0 libusb-1.0-0-dev build-essential pkg-config

    info "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    make -f Makefile.rgb clean 2>/dev/null || true
    make -f Makefile.rgb
    
    info "Installing compiled binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    
    success "GZ302 RGB keyboard CLI compiled and installed"
}

# --- Install build dependencies and compile for Fedora ---
install_rgb_fedora() {
    info "Installing build dependencies for Fedora..."
    dnf install -y libusb libusb-devel gcc pkg-config

    info "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0)
    
    info "Installing compiled binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    
    success "GZ302 RGB keyboard CLI compiled and installed"
}

# --- Install build dependencies and compile for OpenSUSE ---
install_rgb_opensuse() {
    info "Installing build dependencies for OpenSUSE..."
    zypper install -y libusb-1_0-0 libusb-1_0-devel gcc pkg-config

    info "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0)
    
    info "Installing compiled binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    
    success "GZ302 RGB keyboard CLI compiled and installed"
}

# --- Main installation logic ---
main() {
    echo
    echo "============================================================"
    echo "  GZ302 Keyboard RGB Control Module"
    echo "  Version 1.1.0 (Custom GZ302-Optimized)"
    echo "============================================================"
    echo
    
    # Check if already installed
    if check_rgb_installed; then
        success "gz302-rgb is already installed at $BINARY_PATH"
        echo
        info "You can now use gz302-rgb for keyboard RGB control:"
        echo "  sudo gz302-rgb single_static FF0000  # Red"
        echo "  sudo gz302-rgb single_static 00FF00  # Green"
        echo "  sudo gz302-rgb single_static 0000FF  # Blue"
        echo "  sudo gz302-rgb rainbow_cycle 2       # Rainbow animation"
        echo "  sudo gz302-rgb brightness 3          # Max brightness"
        echo
        return 0
    fi
    
    # Detect distribution
    distro="${1:-$(detect_distribution)}"
    
    case "$distro" in
        arch)
            install_rgb_arch
            ;;
        debian)
            install_rgb_debian
            ;;
        fedora)
            install_rgb_fedora
            ;;
        opensuse)
            install_rgb_opensuse
            ;;
        *)
            error "Unsupported distribution: $distro"
            ;;
    esac
    
    echo
    echo "============================================================"
    echo "  gz302-rgb Installation Complete!"
    echo "============================================================"
    echo
    success "Keyboard RGB control is now available!"
    echo
    info "Available commands:"
    echo "  Static Colors (hex codes):"
    echo "    sudo gz302-rgb single_static <HEX>       # e.g., FF0000 for red"
    echo "    sudo gz302-rgb red|green|blue|cyan|magenta|yellow|white|black"
    echo
    echo "  Animations:"
    echo "    sudo gz302-rgb single_breathing <HEX1> <HEX2> <SPEED>"
    echo "    sudo gz302-rgb single_colorcycle <SPEED> (speed 1-3)"
    echo "    sudo gz302-rgb rainbow_cycle <SPEED>     (speed 1-3)"
    echo
    echo "  Control:"
    echo "    sudo gz302-rgb brightness <0-3>          (0=off, 3=max)"
    echo
    info "Binary size: Only 17KB (70% smaller than full rogauracore)"
    echo
    success "GZ302 Keyboard RGB (USB 0x0b05:0x1a30) is now fully supported!"
    echo
    warning "Note: This is a custom implementation derived from rogauracore"
    echo "  Original: https://github.com/Syndelis/rogauracore"
    echo "  License: MIT (see gz302-rgb-cli.c for attribution)"
    echo
}

# --- Run installation ---
main "$@"
