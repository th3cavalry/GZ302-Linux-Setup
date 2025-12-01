#!/bin/bash

# ==============================================================================
# GZ302 System Snapshots Module
# Version: 2.3.3
#
# This module sets up system snapshots for the ASUS ROG Flow Z13 (GZ302)
# Includes: Snapper, LVM snapshots, Btrfs
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

# --- Snapshot Setup ---
setup_snapshots() {
    local distro="$1"
    info "Setting up system snapshots..."
    
    # Detect filesystem type
    local fs_type
    fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    
    if [[ "$fs_type" == "btrfs" ]]; then
        info "Detected Btrfs filesystem - setting up Snapper..."
        
        case "$distro" in
            "arch")
                pacman -S --noconfirm --needed snapper
                ;;
            "ubuntu")
                apt install -y snapper
                ;;
            "fedora")
                dnf install -y snapper
                ;;
            "opensuse")
                zypper install -y snapper
                ;;
        esac
        
        # Create snapper configuration
        if ! snapper list-configs | grep -q "root"; then
            snapper create-config /
            success "Snapper configuration created for root"
        else
            info "Snapper configuration for root already exists"
        fi
        
        systemctl enable --now snapper-timeline.timer
        systemctl enable --now snapper-cleanup.timer
        success "Snapper configured for Btrfs"
        
    elif [[ "$fs_type" == "ext4" ]]; then
        info "Detected ext4 filesystem - LVM snapshots recommended..."
        warning "LVM snapshot setup requires manual configuration"
        
    else
        warning "Filesystem $fs_type - limited snapshot support available"
    fi
    
    success "Snapshot setup complete"
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
    echo "  GZ302 System Snapshots Setup"
    echo "============================================================"
    echo
    
    setup_snapshots "$distro"
    
    echo
    success "Snapshot module complete!"
    echo
}

main "$@"
