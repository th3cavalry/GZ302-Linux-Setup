#!/bin/bash

# ==============================================================================
# GZ302 Secure Boot Module
# Version: 2.3.2
#
# This module configures Secure Boot for the ASUS ROG Flow Z13 (GZ302)
# Includes: Automatic kernel signing and bootloader setup
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
