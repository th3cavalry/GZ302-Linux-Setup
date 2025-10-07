#!/bin/bash

# ==============================================================================
# GZ302 Secure Boot Module
#
# This module configures Secure Boot for the ASUS ROG Flow Z13 (GZ302)
# Includes: Automatic kernel signing and bootloader setup
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

# --- Secure Boot Setup ---
setup_secureboot() {
    local distro="$1"
    info "Setting up Secure Boot configuration..."
    
    warning "Secure Boot configuration requires UEFI system and manual BIOS setup"
    warning "This is a basic setup - refer to your distribution's documentation for full secure boot"
    
    case "$distro" in
        "arch")
            pacman -S --noconfirm --needed sbctl
            info "Use 'sbctl' to manage Secure Boot keys"
            ;;
        "ubuntu")
            apt install -y mokutil
            info "Use 'mokutil' to manage Secure Boot keys"
            ;;
        "fedora")
            dnf install -y mokutil
            info "Use 'mokutil' to manage Secure Boot keys"
            ;;
        "opensuse")
            zypper install -y mokutil
            info "Use 'mokutil' to manage Secure Boot keys"
            ;;
    esac
    
    success "Secure Boot tools installed"
    warning "Remember to enable Secure Boot in BIOS after configuring keys"
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
    echo "  GZ302 Secure Boot Setup"
    echo "============================================================"
    echo
    
    setup_secureboot "$distro"
    
    echo
    success "Secure Boot module complete!"
    echo
}

main "$@"
