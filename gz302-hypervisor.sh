#!/bin/bash

# ==============================================================================
# GZ302 Hypervisor Software Module
#
# This module installs hypervisor software for the ASUS ROG Flow Z13 (GZ302)
# Includes: KVM/QEMU, VirtualBox, VMware, Xen, Proxmox
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

# --- Hypervisor Installation ---
install_kvm_qemu() {
    local distro="$1"
    info "Installing KVM/QEMU with virt-manager..."
    
    case "$distro" in
        "arch")
            pacman -S --noconfirm --needed qemu virt-manager libvirt edk2-ovmf dnsmasq
            systemctl enable --now libvirtd
            ;;
        "ubuntu")
            apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
            systemctl enable --now libvirtd
            ;;
        "fedora")
            dnf install -y @virtualization
            systemctl enable --now libvirtd
            ;;
        "opensuse")
            zypper install -y -t pattern kvm_server kvm_tools
            systemctl enable --now libvirtd
            ;;
    esac
    
    success "KVM/QEMU installed successfully"
}

install_virtualbox() {
    local distro="$1"
    info "Installing VirtualBox..."
    
    case "$distro" in
        "arch")
            pacman -S --noconfirm --needed virtualbox virtualbox-host-modules-arch
            ;;
        "ubuntu")
            apt install -y virtualbox virtualbox-ext-pack
            ;;
        "fedora")
            dnf install -y VirtualBox kernel-devel
            ;;
        "opensuse")
            zypper install -y virtualbox
            ;;
    esac
    
    success "VirtualBox installed successfully"
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
    echo "  GZ302 Hypervisor Software Installation"
    echo "============================================================"
    echo
    echo "Available hypervisors:"
    echo "  1) KVM/QEMU with virt-manager (Recommended)"
    echo "  2) VirtualBox"
    echo "  3) Skip"
    echo
    
    read -p "Choose a hypervisor to install (1-3): " choice
    
    case "$choice" in
        1)
            install_kvm_qemu "$distro"
            ;;
        2)
            install_virtualbox "$distro"
            ;;
        3)
            info "Skipping hypervisor installation"
            ;;
        *)
            warning "Invalid choice, skipping hypervisor installation"
            ;;
    esac
    
    echo
    success "Hypervisor module complete!"
    echo
}

main "$@"
