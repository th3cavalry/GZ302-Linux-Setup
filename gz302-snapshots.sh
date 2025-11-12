#!/bin/bash

# ==============================================================================
# GZ302 System Snapshots Module
# Version: 1.1.1
#
# This module sets up system snapshots for the ASUS ROG Flow Z13 (GZ302)
# Includes: Snapper, LVM snapshots, Btrfs
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
        snapper create-config /
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
