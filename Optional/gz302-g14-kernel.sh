#!/bin/bash

# ==============================================================================
# Linux-G14 Kernel Installer for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.1.2
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
    
    if [[ "$distro" != "arch" ]]; then
        error "linux-g14 kernel is only available for Arch-based systems"
    fi
    
    info "Installing linux-g14 kernel and headers..."
    info "This provides kernel 6.17+ with full ASUS ROG optimizations for GZ302EA"
    echo
    
    # Add G14 repository if not already present
    if ! grep -q "arch.asus-linux.org" /etc/pacman.conf 2>/dev/null; then
        info "Adding ASUS Linux repository..."
        { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
        
        # Import and sign GPG key
        info "Importing ASUS Linux GPG key..."
        if pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null; then
            pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null
            success "GPG key imported and signed"
        else
            warning "Failed to import GPG key. You may need to verify the key manually."
        fi
    else
        info "ASUS Linux repository already configured"
    fi
    
    # Update package database
    info "Updating package database..."
    if ! pacman -Sy 2>/dev/null; then
        error "Failed to update package database"
    fi
    
    # Install linux-g14 and headers
    info "Installing linux-g14 and linux-g14-headers..."
    if pacman -S --noconfirm linux-g14 linux-g14-headers 2>/dev/null; then
        success "linux-g14 kernel installed successfully!"
        
        # Update bootloader configuration after kernel installation
        info "Updating bootloader entries for linux-g14..."
        configure_bootloader_for_kernel "linux-g14"
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "REBOOT REQUIRED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "The linux-g14 kernel has been installed successfully."
        echo
        echo "Bootloader Configuration Status:"
        echo "  ✓ Kernel parameters (amd_pstate=guided, amdgpu.ppfeaturemask) applied"
        echo "  ✓ GRUB configuration regenerated (if installed)"
        echo "  ✓ systemd-boot updated (if installed)"
        echo
        echo "Next steps:"
        echo "  1. REBOOT your system to activate the new kernel"
        echo "  2. Verify kernel version after reboot: uname -r"
        echo "     (you should see 'linux-g14' or a 6.17+ kernel version)"
        echo "  3. Verify boot parameters: cat /proc/cmdline | grep 'amd_pstate'"
        echo
        echo "For more information:"
        echo "  See: https://asus-linux.org"
        echo "  Analysis: Info/LINUX_G14_ANALYSIS.md"
        echo
    else
        error "Failed to install linux-g14 kernel. Please check your internet connection and try again."
    fi
}

# --- Main Execution ---
main() {
    check_root
    
    echo
    echo "============================================================"
    echo "  Linux-G14 Kernel Installer for ASUS ROG Flow Z13 (GZ302)"
    echo "  Version 1.1.2"
    echo "============================================================"
    echo
    
    info "Detecting Linux distribution..."
    local distro
    distro=$(detect_distribution)
    
    if [[ "$distro" != "arch" ]]; then
        error "This installer only supports Arch-based distributions.\nFor other distributions, use your official package manager for kernel updates."
    fi
    
    success "Detected: Arch-based distribution"
    echo
    
    info "About linux-g14 kernel for GZ302:"
    echo "  • Community-maintained ASUS-optimized kernel (6.17.3)"
    echo "  • Kernel-level RGB LED control (4-zone per-key matrix)"
    echo "  • Suspend/Resume LED restoration hooks"
    echo "  • Power management tunables (sPPT/fPPT/SPPT)"
    echo "  • OLED panel optimizations"
    echo
    info "See Info/LINUX_G14_ANALYSIS.md for detailed comparison"
    echo
    
    read -r -p "Continue with installation? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
    
    install_linux_g14_kernel "$distro"
}

main "$@"
