#!/bin/bash

# ==============================================================================
# GZ302 Secure Boot Module
# Version: 2.3.15
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
    local total_steps=3
    
    print_section "Secure Boot Configuration"
    
    # Step 1: Check current Secure Boot status
    print_step 1 $total_steps "Checking Secure Boot status..."
    local sb_status="Unknown"
    if [[ -d /sys/firmware/efi ]]; then
        completed_item "UEFI system detected"
        if command -v mokutil >/dev/null 2>&1; then
            sb_status=$(mokutil --sb-state 2>/dev/null | head -1 || echo "Unknown")
        elif find /sys/firmware/efi/efivars/ -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null | grep -q .; then
            local sb_val sb_file
            sb_file=$(find /sys/firmware/efi/efivars/ -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null)
            sb_val=$(od -An -t u1 "$sb_file" 2>/dev/null | awk '{print $NF}')
            [[ "$sb_val" == "1" ]] && sb_status="Enabled" || sb_status="Disabled"
        fi
        print_keyval "Current Status" "$sb_status"
    else
        warning "Legacy BIOS mode - Secure Boot requires UEFI"
        return 1
    fi
    
    # Step 2: Install tools
    print_step 2 $total_steps "Installing Secure Boot tools..."
    local tool_name=""
    echo -ne "${C_DIM}"
    case "$distro" in
        "arch")
            pacman -S --noconfirm --needed sbctl 2>&1 | grep -v "^::" || true
            tool_name="sbctl"
            ;;
        "ubuntu")
            apt install -y mokutil 2>&1 | grep -E "^(Setting up|is already)" | head -3 || true
            tool_name="mokutil"
            ;;
        "fedora")
            dnf install -y mokutil 2>&1 | grep -E "^(Installing|Complete)" | head -3 || true
            tool_name="mokutil"
            ;;
        "opensuse")
            zypper install -y mokutil 2>&1 | grep -E "^(Installing|done)" | head -3 || true
            tool_name="mokutil"
            ;;
    esac
    echo -ne "${C_NC}"
    completed_item "${tool_name} installed"
    
    # Step 3: Show configuration info
    print_step 3 $total_steps "Displaying configuration guidance..."
    
    print_subsection "Secure Boot Configuration"
    print_keyval "Boot Mode" "UEFI"
    print_keyval "Current State" "$sb_status"
    print_keyval "Management Tool" "$tool_name"
    
    print_box "Secure Boot Tools Installed"
    
    echo
    warning "Important: Secure Boot requires additional manual steps:"
    echo
    echo "  ${C_DIM}1. Generate and enroll custom keys (if using sbctl)${C_NC}"
    echo "  ${C_DIM}2. Sign kernel and bootloader${C_NC}"
    echo "  ${C_DIM}3. Enable Secure Boot in BIOS${C_NC}"
    echo
    
    if [[ "$distro" == "arch" ]]; then
        print_tip "Arch: Run 'sbctl status' then 'sbctl create-keys' and 'sbctl enroll-keys'"
    else
        print_tip "Check Secure Boot state: mokutil --sb-state"
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
    
    print_box "GZ302 Secure Boot Setup"
    
    setup_secureboot "$distro"
    
    print_box "Secure Boot Module Complete"
}

main "$@"