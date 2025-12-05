#!/bin/bash

# ==============================================================================
# Linux-G14 Kernel Installer for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 2.3.13
#
# This script installs the linux-g14 custom kernel for ASUS ROG devices.
# The linux-g14 kernel is community-maintained and includes ASUS-specific
# optimizations including RGB LED control, suspend/resume hooks, and power
# management tunables.
#
# SUPPORTED: Arch Linux and Arch-based distributions only
#
# USAGE:
# 1. Make executable: chmod +x gz302-g14-kernel.sh
# 2. Run with sudo: sudo ./gz302-g14-kernel.sh
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
    printf "  ${C_DIM}%-20s${C_NC} %s\n" "$1:" "$2"
}

completed_item() {
    echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} $1"
}

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-g14-kernel.sh"
    fi
}

detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        
        # Detect Arch-based systems (including CachyOS)
        if [[ "$ID" == "arch" || "$ID" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; then
            distro="arch"
        fi
    fi
    
    echo "$distro"
}

configure_bootloader_for_kernel() {
    local kernel_name="$1"  # e.g., "linux" or "linux-g14"
    
    # Detect and update GRUB if present
    if [ -f /etc/default/grub ] || command -v grub-mkconfig >/dev/null 2>&1; then
        info "Updating GRUB bootloader configuration for ${kernel_name}..."
        if command -v grub-mkconfig >/dev/null 2>&1; then
            if [ -f /boot/grub/grub.cfg ]; then
                if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
                    success "GRUB configuration updated"
                else
                    warning "Failed to regenerate GRUB config"
                fi
            elif command -v update-grub >/dev/null 2>&1; then
                if update-grub 2>/dev/null; then
                    success "GRUB configuration updated (Ubuntu/Debian)"
                else
                    warning "Failed to update GRUB"
                fi
            fi
        fi
    fi
    
    # Detect and update systemd-boot if present
    if command -v bootctl >/dev/null 2>&1; then
        info "Updating systemd-boot configuration for ${kernel_name}..."
        
        # Check if systemd-boot is installed
        if bootctl status >/dev/null 2>&1; then
            # Verify boot entries directory exists
            if [ -d /boot/loader/entries ] || [ -d /efi/loader/entries ]; then
                # Update systemd-boot (graceful update to prevent boot issues)
                if bootctl update 2>/dev/null; then
                    success "systemd-boot updated"
                else
                    warning "Failed to update systemd-boot"
                fi
            fi
        fi
    fi
    
    # Log the kernel parameters that were applied
    if [ -f /proc/cmdline ]; then
        info "Current kernel command line:"
        if grep -q "amd_pstate=" /proc/cmdline; then
            info "$(grep -o 'amd_pstate=[^ ]*' /proc/cmdline)"
        else
            info "amd_pstate parameter not yet applied (reboot required)"
        fi
        if grep -q "amdgpu.ppfeaturemask=" /proc/cmdline; then
            info "$(grep -o 'amdgpu.ppfeaturemask=[^ ]*' /proc/cmdline)"
        else
            info "amdgpu.ppfeaturemask parameter not yet applied (reboot required)"
        fi
    fi
}

install_linux_g14_kernel() {
    local distro="$1"
    local total_steps=4
    
    if [[ "$distro" != "arch" ]]; then
        error "linux-g14 kernel is only available for Arch-based systems"
    fi
    
    print_section "Linux-G14 Kernel Installation"
    info "Installing kernel 6.17+ with full ASUS ROG optimizations"
    
    # Step 1: Add G14 repository
    print_step 1 $total_steps "Configuring ASUS Linux repository..."
    if ! grep -q "arch.asus-linux.org" /etc/pacman.conf 2>/dev/null; then
        { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
        completed_item "Repository added to pacman.conf"
        
        # Import and sign GPG key
        echo -ne "${C_DIM}"
        if pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null; then
            pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null
            echo -ne "${C_NC}"
            completed_item "GPG key imported and signed"
        else
            echo -ne "${C_NC}"
            warning "Failed to import GPG key - manual verification may be needed"
        fi
    else
        completed_item "Repository already configured"
    fi
    
    # Step 2: Update package database
    print_step 2 $total_steps "Updating package database..."
    echo -ne "${C_DIM}"
    if ! pacman -Sy 2>&1 | tail -5; then
        echo -ne "${C_NC}"
        error "Failed to update package database"
    fi
    echo -ne "${C_NC}"
    completed_item "Package database updated"
    
    # Step 3: Install kernel
    print_step 3 $total_steps "Installing linux-g14 kernel and headers..."
    echo -ne "${C_DIM}"
    if pacman -S --noconfirm linux-g14 linux-g14-headers 2>&1 | grep -E "^(downloading|installing|upgrading)" | head -10; then
        echo -ne "${C_NC}"
        completed_item "Kernel and headers installed"
    else
        echo -ne "${C_NC}"
        error "Failed to install linux-g14 kernel"
    fi
    
    # Step 4: Update bootloader
    print_step 4 $total_steps "Updating bootloader configuration..."
    configure_bootloader_for_kernel "linux-g14"
    completed_item "Bootloader updated"
    
    # Summary
    print_section "Installation Summary"
    print_keyval "Kernel" "linux-g14 (6.17+)"
    print_keyval "Headers" "linux-g14-headers"
    print_keyval "Repository" "arch.asus-linux.org"
    
    print_box "Linux-G14 Kernel Installed"
    
    warning "REBOOT REQUIRED to activate the new kernel"
    echo
    echo "  ${C_DIM}After reboot, verify:${C_NC}"
    echo "    uname -r              ${C_DIM}# Should show linux-g14 version${C_NC}"
    echo "    cat /proc/cmdline     ${C_DIM}# Verify amd_pstate=guided${C_NC}"
    echo
    echo "  ${C_DIM}Documentation: Info/LINUX_G14_ANALYSIS.md${C_NC}"
    echo "  ${C_DIM}Project: https://asus-linux.org${C_NC}"
    echo
}

# --- Main Execution ---
main() {
    check_root
    
    print_box "Linux-G14 Kernel Installer"
    
    info "Detecting Linux distribution..."
    local distro
    distro=$(detect_distribution)
    
    if [[ "$distro" != "arch" ]]; then
        error "This installer only supports Arch-based distributions.\nFor other distributions, use your official package manager for kernel updates."
    fi
    
    print_keyval "Distribution" "Arch-based"
    completed_item "Distribution supported"
    
    print_section "About linux-g14 kernel"
    echo "  ${C_DIM}• Community-maintained ASUS-optimized kernel (6.17.3)${C_NC}"
    echo "  ${C_DIM}• Kernel-level RGB LED control (4-zone per-key matrix)${C_NC}"
    echo "  ${C_DIM}• Suspend/Resume LED restoration hooks${C_NC}"
    echo "  ${C_DIM}• Power management tunables (sPPT/fPPT/SPPT)${C_NC}"
    echo "  ${C_DIM}• OLED panel optimizations${C_NC}"
    echo
    echo -e "  ${C_DIM}See Info/LINUX_G14_ANALYSIS.md for detailed comparison${C_NC}"
    echo
    
    read -r -p "$(echo -e "${C_BOLD_CYAN}Continue with installation? (y/N):${C_NC} ")" response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
    
    install_linux_g14_kernel "$distro"
}

main "$@"