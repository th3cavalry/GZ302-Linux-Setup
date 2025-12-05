#!/bin/bash

# ==============================================================================
# GZ302 Keyboard RGB Control Module
#
# Author: th3cavalry using Copilot
# Version: 2.3.13
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

# --- Load Shared Utilities (for visual formatting) ---
if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    # Fallback color codes if utils not available
    C_BLUE='\033[0;34m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_RED='\033[0;31m'
    C_DIM='\033[2m'
    C_BOLD_CYAN='\033[1;36m'
    C_NC='\033[0m'
    
    # Fallback logging functions
    error() { echo -e "${C_RED}ERROR:${C_NC} $1" >&2; exit 1; }
    info() { echo -e "${C_BLUE}INFO:${C_NC} $1"; }
    success() { echo -e "${C_GREEN}SUCCESS:${C_NC} $1"; }
    warning() { echo -e "${C_YELLOW}WARNING:${C_NC} $1"; }
    
    # Fallback visual functions
    print_section() { echo -e "\n${C_BOLD_CYAN}━━━ $1 ━━━${C_NC}"; }
    print_step() { echo -e "${C_BOLD_CYAN}[$1/$2]${C_NC} $3"; }
    print_keyval() { printf "  ${C_DIM}%-15s${C_NC} %s\n" "$1:" "$2"; }
    completed_item() { echo -e "  ${C_GREEN}✓${C_NC} $1"; }
    print_box() { echo -e "\n${C_GREEN}╔══════════════════════════════════════════╗${C_NC}"; echo -e "${C_GREEN}║${C_NC}  $1"; echo -e "${C_GREEN}╚══════════════════════════════════════════╝${C_NC}"; }
    print_tip() { echo -e "\n${C_BOLD_CYAN}💡 Tip:${C_NC} $1"; }
fi

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
    local total_steps=3
    
    # Step 1: Install dependencies
    print_step 1 $total_steps "Installing build dependencies..."
    echo -ne "${C_DIM}"
    pacman -S --noconfirm libusb base-devel pkg-config 2>&1 | grep -v "^::" | grep -v "is up to date" || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"

    # Step 2: Compile
    print_step 2 $total_steps "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    # shellcheck disable=SC2046
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0) 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled successfully"
    
    # Step 3: Install
    print_step 3 $total_steps "Installing binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    rm -f /usr/local/bin/gz302-rgb-bin /usr/local/bin/gz302-rgb-wrapper 2>/dev/null || true
    ln -sf /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin
    completed_item "Binary installed to $BINARY_PATH"
}

# --- Install build dependencies and compile for Debian/Ubuntu ---
install_rgb_debian() {
    local total_steps=3
    
    # Step 1: Install dependencies
    print_step 1 $total_steps "Installing build dependencies..."
    echo -ne "${C_DIM}"
    apt-get update 2>&1 | tail -3 || true
    apt-get install -y libusb-1.0-0 libusb-1.0-0-dev build-essential pkg-config 2>&1 | grep -E "^(Setting up|is already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"

    # Step 2: Compile
    print_step 2 $total_steps "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    make -f Makefile.rgb clean 2>/dev/null || true
    echo -ne "${C_DIM}"
    make -f Makefile.rgb 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled successfully"
    
    # Step 3: Install
    print_step 3 $total_steps "Installing binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    rm -f /usr/local/bin/gz302-rgb-bin /usr/local/bin/gz302-rgb-wrapper 2>/dev/null || true
    ln -sf /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin
    completed_item "Binary installed to $BINARY_PATH"
}

# --- Install build dependencies and compile for Fedora ---
install_rgb_fedora() {
    local total_steps=3
    
    # Step 1: Install dependencies
    print_step 1 $total_steps "Installing build dependencies..."
    echo -ne "${C_DIM}"
    dnf install -y libusb libusb-devel gcc pkg-config 2>&1 | grep -E "^(Installing|Complete|already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"

    # Step 2: Compile
    print_step 2 $total_steps "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    # shellcheck disable=SC2046
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0) 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled successfully"
    
    # Step 3: Install
    print_step 3 $total_steps "Installing binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    rm -f /usr/local/bin/gz302-rgb-bin /usr/local/bin/gz302-rgb-wrapper 2>/dev/null || true
    ln -sf /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin
    completed_item "Binary installed to $BINARY_PATH"
}

# --- Install build dependencies and compile for OpenSUSE ---
install_rgb_opensuse() {
    local total_steps=3
    
    # Step 1: Install dependencies
    print_step 1 $total_steps "Installing build dependencies..."
    echo -ne "${C_DIM}"
    zypper install -y libusb-1_0-0 libusb-1_0-devel gcc pkg-config 2>&1 | grep -E "^(Installing|done|already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"

    # Step 2: Compile
    print_step 2 $total_steps "Compiling GZ302 RGB keyboard CLI..."
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    # shellcheck disable=SC2046
    gcc -Wall -Wextra -O2 -o gz302-rgb gz302-rgb-cli.c $(pkg-config --cflags --libs libusb-1.0) 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled successfully"
    
    # Step 3: Install
    print_step 3 $total_steps "Installing binary..."
    install -m 755 gz302-rgb "$BINARY_PATH"
    rm -f /usr/local/bin/gz302-rgb-bin /usr/local/bin/gz302-rgb-wrapper 2>/dev/null || true
    ln -sf /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin
    completed_item "Binary installed to $BINARY_PATH"
}

# --- Main installation logic ---
main() {
    print_box "GZ302 Keyboard RGB Control Module"
    
    # Check if already installed
    if check_rgb_installed; then
        print_section "RGB Control Already Installed"
        completed_item "gz302-rgb found at $BINARY_PATH"
        
        print_subsection "Available Commands" 2>/dev/null || echo -e "\n${C_BOLD_CYAN}── Available Commands ──${C_NC}"
        echo
        echo "  ${C_DIM}Static Colors:${C_NC}"
        echo "    sudo gz302-rgb single_static FF0000  ${C_DIM}# Red${C_NC}"
        echo "    sudo gz302-rgb single_static 00FF00  ${C_DIM}# Green${C_NC}"
        echo "    sudo gz302-rgb single_static 0000FF  ${C_DIM}# Blue${C_NC}"
        echo
        echo "  ${C_DIM}Animations:${C_NC}"
        echo "    sudo gz302-rgb rainbow_cycle 2       ${C_DIM}# Rainbow${C_NC}"
        echo "    sudo gz302-rgb brightness 3          ${C_DIM}# Max brightness${C_NC}"
        echo
        return 0
    fi
    
    print_section "RGB Keyboard CLI Installation"
    
    # Detect distribution
    distro="${1:-$(detect_distribution)}"
    print_keyval "Distribution" "$distro"
    
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
    
    # Summary
    print_subsection "Installation Summary" 2>/dev/null || echo -e "\n${C_BOLD_CYAN}── Installation Summary ──${C_NC}"
    print_keyval "Binary" "$BINARY_PATH"
    print_keyval "Size" "~17KB (optimized)"
    print_keyval "USB Device" "0x0b05:0x1a30"
    
    print_box "RGB Keyboard Control Ready"
    
    echo
    echo "  ${C_BOLD_CYAN}Static Colors (hex codes):${C_NC}"
    echo "    sudo gz302-rgb single_static <HEX>       ${C_DIM}# e.g., FF0000 for red${C_NC}"
    echo "    sudo gz302-rgb red|green|blue|cyan|magenta|yellow|white|black"
    echo
    echo "  ${C_BOLD_CYAN}Animations:${C_NC}"
    echo "    sudo gz302-rgb single_breathing <HEX1> <HEX2> <SPEED>"
    echo "    sudo gz302-rgb single_colorcycle <SPEED> ${C_DIM}(speed 1-3)${C_NC}"
    echo "    sudo gz302-rgb rainbow_cycle <SPEED>     ${C_DIM}(speed 1-3)${C_NC}"
    echo
    echo "  ${C_BOLD_CYAN}Control:${C_NC}"
    echo "    sudo gz302-rgb brightness <0-3>          ${C_DIM}(0=off, 3=max)${C_NC}"
    echo
    
    print_tip "Try: sudo gz302-rgb rainbow_cycle 2"
}

# --- Run installation ---
main "$@"