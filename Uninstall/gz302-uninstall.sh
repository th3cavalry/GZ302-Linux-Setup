#!/bin/bash

# ==============================================================================
# Uninstall Script for ASUS ROG Flow Z13 (GZ302) Setup
#
# Author: th3cavalry using Copilot
# Version: 2.3.13
#
# This script detects and removes components installed by gz302-main.sh
# and optional scripts (gz302-folio-fix.sh, gz302-g14-kernel.sh).
#
# USAGE:
# 1. Make executable: chmod +x gz302-uninstall.sh
# 2. Run with sudo: sudo ./gz302-uninstall.sh
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BOLD_CYAN='\033[1;36m'
C_DIM='\033[2m'
C_NC='\033[0m'

# --- Symbols ---
SYMBOL_CHECK='✓'
SYMBOL_CROSS='✗'

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

# --- Visual formatting functions ---
print_box() {
    local text="$1"
    local padding=4
    local text_len=${#text}
    local total_width=$((text_len + padding * 2))
    
    echo
    echo -e "${C_GREEN}╔$(printf '═%.0s' $(seq 1 $total_width))╗${C_NC}"
    echo -e "${C_GREEN}║${C_NC}$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $padding))${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}╚$(printf '═%.0s' $(seq 1 $total_width))╝${C_NC}"
    echo
}

print_section() {
    echo
    echo -e "${C_BOLD_CYAN}━━━ $1 ━━━${C_NC}"
}

print_step() {
    local step="$1"
    local total="$2"
    local desc="$3"
    echo -e "${C_BOLD_CYAN}[$step/$total]${C_NC} $desc"
}

print_keyval() {
    printf "  ${C_DIM}%-25s${C_NC} %s\n" "$1:" "$2"
}

completed_item() {
    echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} $1"
}

failed_item() {
    echo -e "  ${C_RED}${SYMBOL_CROSS}${C_NC} $1"
}

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-uninstall.sh"
    fi
}

detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        
        if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
            distro="arch"
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "pop" || "$ID" == "linuxmint" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* ]]; then
            distro="ubuntu"
        elif [[ "$ID" == "fedora" || "$ID_LIKE" == *"fedora"* ]]; then
            distro="fedora"
        elif [[ "$ID" == "opensuse-tumbleweed" || "$ID" == "opensuse-leap" || "$ID" == "opensuse" || "$ID_LIKE" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    echo "$distro"
}

# --- Detection functions ---
detect_hardware_fixes() {
    local found=0
    
    [[ -f /etc/modprobe.d/mt7925.conf ]] && found=1
    [[ -f /etc/modprobe.d/amdgpu.conf ]] && found=1
    [[ -f /etc/modprobe.d/hid-asus.conf ]] && found=1
    
    return $((1 - found))
}

detect_tdp_management() {
    local found=0
    
    [[ -f /usr/local/bin/pwrcfg ]] && found=1
    [[ -f /usr/local/bin/pwrcfg-monitor ]] && found=1
    [[ -f /etc/systemd/system/pwrcfg-auto.service ]] && found=1
    [[ -f /etc/systemd/system/pwrcfg-monitor.service ]] && found=1
    
    return $((1 - found))
}

detect_refresh_management() {
    local found=0
    
    [[ -f /usr/local/bin/rrcfg ]] && found=1
    
    return $((1 - found))
}

detect_folio_fix() {
    local found=0
    
    [[ -f /usr/local/bin/gz302-folio-resume.sh ]] && found=1
    [[ -f /etc/systemd/system/reload-hid_asus-resume.service ]] && found=1
    
    return $((1 - found))
}

detect_g14_kernel() {
    local found=0
    
    if command -v pacman >/dev/null 2>&1; then
        if pacman -Q linux-g14 >/dev/null 2>&1; then
            found=1
        fi
    fi
    
    return $((1 - found))
}

# --- Uninstall functions ---
uninstall_hardware_fixes() {
    print_section "Removing Hardware Configuration"
    
    rm -f /etc/modprobe.d/mt7925.conf && completed_item "WiFi config removed" || true
    rm -f /etc/modprobe.d/amdgpu.conf && completed_item "GPU config removed" || true
    rm -f /etc/modprobe.d/hid-asus.conf && completed_item "HID config removed" || true
    
    # Remove HID reload service
    if systemctl is-enabled reload-hid_asus.service >/dev/null 2>&1; then
        systemctl disable reload-hid_asus.service 2>/dev/null || true
    fi
    systemctl stop reload-hid_asus.service 2>/dev/null || true
    rm -f /etc/systemd/system/reload-hid_asus.service
    completed_item "HID reload service removed"
    
    # Remove keyboard backlight restore script
    rm -f /usr/lib/systemd/system-sleep/gz302-kbd-backlight
    rm -rf /var/lib/gz302
    
    systemctl daemon-reload >/dev/null 2>&1
    
    warning "Reboot required to fully remove kernel module configurations"
}

uninstall_tdp_management() {
    print_section "Removing TDP/Power Management"
    
    # Stop and disable services
    if systemctl is-active pwrcfg-monitor.service >/dev/null 2>&1; then
        systemctl stop pwrcfg-monitor.service 2>/dev/null || true
    fi
    if systemctl is-enabled pwrcfg-monitor.service >/dev/null 2>&1; then
        systemctl disable pwrcfg-monitor.service 2>/dev/null || true
    fi
    if systemctl is-enabled pwrcfg-auto.service >/dev/null 2>&1; then
        systemctl disable pwrcfg-auto.service 2>/dev/null || true
    fi
    completed_item "Services stopped and disabled"
    
    # Remove files
    rm -f /usr/local/bin/pwrcfg && completed_item "pwrcfg command removed" || true
    rm -f /usr/local/bin/pwrcfg-monitor && completed_item "pwrcfg-monitor removed" || true
    rm -f /etc/systemd/system/pwrcfg-auto.service
    rm -f /etc/systemd/system/pwrcfg-monitor.service
    rm -rf /etc/gz302-tdp && completed_item "TDP config directory removed" || true
    
    # Remove sudoers rule if present
    rm -f /etc/sudoers.d/pwrcfg
    
    systemctl daemon-reload >/dev/null 2>&1
}

uninstall_refresh_management() {
    print_section "Removing Refresh Rate Management"
    
    rm -f /usr/local/bin/rrcfg && completed_item "rrcfg command removed" || true
    rm -rf /etc/gz302-refresh && completed_item "Refresh config removed" || true
}

uninstall_folio_fix() {
    print_section "Removing Folio Resume Fix"
    
    # Stop and disable service
    if systemctl is-enabled reload-hid_asus-resume.service >/dev/null 2>&1; then
        systemctl disable reload-hid_asus-resume.service 2>/dev/null || true
    fi
    systemctl stop reload-hid_asus-resume.service 2>/dev/null || true
    
    # Remove files
    rm -f /usr/local/bin/gz302-folio-resume.sh
    rm -f /etc/systemd/system/reload-hid_asus-resume.service
    
    systemctl daemon-reload >/dev/null 2>&1
    
    completed_item "Folio resume fix removed"
}

uninstall_g14_kernel() {
    info "Removing linux-g14 kernel..."
    
    local distro
    distro=$(detect_distribution)
    
    if [[ "$distro" != "arch" ]]; then
        warning "linux-g14 kernel is Arch-specific. Skipping."
        return 0
    fi
    
    if ! command -v pacman >/dev/null 2>&1; then
        warning "pacman not found. Cannot remove linux-g14 kernel."
        return 0
    fi
    
    # Check if linux-g14 is installed
    if ! pacman -Q linux-g14 >/dev/null 2>&1; then
        warning "linux-g14 kernel is not installed. Skipping."
        return 0
    fi
    
    echo
    warning "Removing the linux-g14 kernel will require a reboot to another kernel."
    echo "Available kernels on your system:"
    pacman -Q | grep "^linux " || true
    echo
    read -r -p "Are you sure you want to remove linux-g14? (y/N): " response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Skipping linux-g14 kernel removal"
        return 0
    fi
    
    # Remove kernel and headers
    if pacman -R --noconfirm linux-g14 linux-g14-headers 2>/dev/null; then
        success "linux-g14 kernel removed"
        
        # Update bootloader
        if command -v grub-mkconfig >/dev/null 2>&1; then
            info "Updating GRUB..."
            grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
        fi
        if command -v bootctl >/dev/null 2>&1; then
            info "Updating systemd-boot..."
            bootctl update 2>/dev/null || true
        fi
        
        warning "REBOOT REQUIRED - Select a different kernel from the boot menu"
    else
        warning "Failed to remove linux-g14 kernel"
    fi
}

# --- Main execution ---
main() {
    check_root
    
    print_box "GZ302 Setup Uninstaller"
    
    print_section "Scanning for Installed Components"
    
    # Detect what's installed
    local components=()
    local component_funcs=()
    
    if detect_hardware_fixes; then
        components+=("Hardware fixes (kernel modules, modprobe configs)")
        component_funcs+=("uninstall_hardware_fixes")
        completed_item "Hardware fixes detected"
    fi
    
    if detect_tdp_management; then
        components+=("TDP/Power management (pwrcfg, services)")
        component_funcs+=("uninstall_tdp_management")
        completed_item "TDP management detected"
    fi
    
    if detect_refresh_management; then
        components+=("Refresh rate management (rrcfg)")
        component_funcs+=("uninstall_refresh_management")
        completed_item "Refresh management detected"
    fi
    
    if detect_folio_fix; then
        components+=("Folio resume fix (Optional)")
        component_funcs+=("uninstall_folio_fix")
        completed_item "Folio fix detected"
    fi
    
    if detect_g14_kernel; then
        components+=("Linux-G14 kernel (Optional, Arch only)")
        component_funcs+=("uninstall_g14_kernel")
        completed_item "G14 kernel detected"
    fi
    
    # Check if anything is installed
    if [[ ${#components[@]} -eq 0 ]]; then
        echo
        info "No GZ302 setup components detected on this system."
        info "Nothing to uninstall."
        exit 0
    fi
    
    # Display detected components
    print_section "Detected Components"
    for i in "${!components[@]}"; do
        echo -e "  ${C_BOLD_CYAN}$((i+1))${C_NC}) ${components[$i]}"
    done
    echo
    
    # Get user selection
    echo -e "${C_BOLD_CYAN}Select components to uninstall:${C_NC}"
    echo -e "  ${C_DIM}Enter comma-separated numbers (e.g., 1,2,3) or 'all'${C_NC}"
    read -r -p "> " selection
    
    # Parse selection
    local to_uninstall=()
    if [[ "$selection" == "all" ]]; then
        to_uninstall=("${component_funcs[@]}")
    else
        IFS=',' read -ra CHOICES <<< "$selection"
        for choice in "${CHOICES[@]}"; do
            choice=$(echo "$choice" | tr -d ' ')
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#components[@]} ]]; then
                to_uninstall+=("${component_funcs[$((choice-1))]}")
            else
                warning "Invalid choice: $choice (skipping)"
            fi
        done
    fi
    
    # Confirm
    if [[ ${#to_uninstall[@]} -eq 0 ]]; then
        info "No components selected for removal."
        exit 0
    fi
    
    print_section "Components to Remove"
    for func in "${to_uninstall[@]}"; do
        for i in "${!component_funcs[@]}"; do
            if [[ "${component_funcs[$i]}" == "$func" ]]; then
                echo -e "  ${C_RED}•${C_NC} ${components[$i]}"
            fi
        done
    done
    echo
    
    read -r -p "$(echo -e "${C_YELLOW}Continue with uninstallation? (y/N):${C_NC} ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Uninstallation cancelled"
        exit 0
    fi
    
    # Perform uninstallation
    for func in "${to_uninstall[@]}"; do
        $func
    done
    
    # Summary
    print_box "Uninstallation Complete"
    
    print_keyval "Components removed" "${#to_uninstall[@]}"
    echo
    warning "Some changes may require a reboot to take full effect"
    echo
}

main "$@"