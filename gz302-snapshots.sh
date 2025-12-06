#!/bin/bash

# ==============================================================================
# GZ302 System Snapshots Module
# Version: 2.3.15
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
    local total_steps=3
    
    print_section "System Snapshots Setup"
    
    # Step 1: Detect filesystem
    print_step 1 $total_steps "Detecting filesystem type..."
    local fs_type
    fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    print_keyval "Root Filesystem" "$fs_type"
    completed_item "Filesystem detected: $fs_type"
    
    if [[ "$fs_type" == "btrfs" ]]; then
        # Step 2: Install Snapper
        print_step 2 $total_steps "Installing Snapper for Btrfs snapshots..."
        echo -ne "${C_DIM}"
        case "$distro" in
            "arch")
                pacman -S --noconfirm --needed snapper 2>&1 | grep -v "^::" || true
                ;;
            "ubuntu")
                apt install -y snapper 2>&1 | grep -E "^(Setting up|is already)" | head -3 || true
                ;;
            "fedora")
                dnf install -y snapper 2>&1 | grep -E "^(Installing|Complete)" | head -3 || true
                ;;
            "opensuse")
                zypper install -y snapper 2>&1 | grep -E "^(Installing|done)" | head -3 || true
                ;;
        esac
        echo -ne "${C_NC}"
        completed_item "Snapper installed"
        
        # Step 3: Configure Snapper
        print_step 3 $total_steps "Configuring Snapper for root filesystem..."
        if ! snapper list-configs 2>/dev/null | grep -q "root"; then
            snapper create-config / 2>/dev/null || warning "Snapper config creation failed"
            completed_item "Snapper configuration created for root"
        else
            info "Snapper configuration for root already exists"
        fi
        
        systemctl enable --now snapper-timeline.timer >/dev/null 2>&1 || true
        systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 || true
        completed_item "Snapper timers enabled"
        
        # Summary
        print_subsection "Btrfs Snapshot Configuration"
        print_keyval "Filesystem" "Btrfs"
        print_keyval "Tool" "Snapper"
        print_keyval "Timeline" "Enabled (hourly)"
        print_keyval "Cleanup" "Automatic"
        
        print_box "Btrfs Snapshots Configured"
        print_tip "Create a manual snapshot: snapper create -d 'description'"
        
    elif [[ "$fs_type" == "ext4" ]]; then
        # Step 2: Check for LVM
        print_step 2 $total_steps "Checking for LVM support..."
        if command -v lvs >/dev/null 2>&1; then
            local lvm_vols
            lvm_vols=$(lvs --noheadings 2>/dev/null | wc -l || echo "0")
            print_keyval "LVM Volumes" "$lvm_vols detected"
            if [[ "$lvm_vols" -gt 0 ]]; then
                completed_item "LVM detected - snapshots supported"
                
                # Step 3: Show LVM info
                print_step 3 $total_steps "Displaying LVM configuration..."
                print_subsection "LVM Snapshot Configuration"
                print_keyval "Filesystem" "ext4 on LVM"
                print_keyval "Tool" "lvcreate/lvremove"
                print_keyval "Status" "Manual setup required"
                
                print_box "LVM Snapshots Available"
                print_tip "Create LVM snapshot: lvcreate -L 10G -s -n snap_name /dev/vg/lv"
            else
                warning "No LVM volumes found - snapshots require LVM or Btrfs"
            fi
        else
            warning "LVM not available - snapshots require LVM or Btrfs"
        fi
        
    else
        # Step 2/3: Limited support
        print_step 2 $total_steps "Checking snapshot options for $fs_type..."
        warning "Filesystem $fs_type has limited snapshot support"
        
        print_subsection "Snapshot Limitations"
        print_keyval "Filesystem" "$fs_type"
        print_keyval "Native Snapshots" "Not supported"
        print_keyval "Alternative" "Consider disk imaging tools"
        
        print_tip "For snapshots, consider: Btrfs, LVM, or tools like Timeshift"
    fi
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
    
    print_box "GZ302 System Snapshots Setup"
    
    setup_snapshots "$distro"
    
    print_box "Snapshot Module Complete"
}

main "$@"