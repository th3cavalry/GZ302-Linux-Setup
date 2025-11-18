#!/bin/bash

# ==============================================================================
# GZ302 Hypervisor Software Module
# Version: 2.0.0
#
# This module installs hypervisor software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Full KVM/QEMU stack, VirtualBox
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

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo "${SUDO_USER}"
    elif command -v logname >/dev/null 2>&1; then
        logname 2>/dev/null || whoami
    else
        whoami
    fi
}

# Check if virtualization is enabled in BIOS
check_virtualization_support() {
    info "Checking for virtualization support..."
    
    # Check if CPU supports virtualization
    if grep -qE 'vmx|svm' /proc/cpuinfo; then
        success "CPU virtualization support detected"
        
        # Check if it's enabled (KVM modules loaded or can be loaded)
        if lsmod | grep -q kvm; then
            success "KVM modules already loaded"
            return 0
        elif modprobe -n kvm_amd 2>/dev/null || modprobe -n kvm_intel 2>/dev/null; then
            info "KVM modules can be loaded"
            return 0
        else
            warning "Virtualization may not be enabled in BIOS"
            echo "Please ensure virtualization (AMD-V/SVM) is enabled in BIOS settings"
            return 1
        fi
    else
        error "CPU does not support virtualization (AMD-V/Intel VT-x not found)"
    fi
}

# Configure user permissions for libvirt
configure_libvirt_permissions() {
    local user="$1"
    
    info "Configuring libvirt permissions for user: $user"
    
    # Add user to libvirt and kvm groups
    if getent group libvirt >/dev/null 2>&1; then
        usermod -aG libvirt "$user" 2>/dev/null || warning "Failed to add $user to libvirt group"
        success "User $user added to libvirt group"
    fi
    
    if getent group kvm >/dev/null 2>&1; then
        usermod -aG kvm "$user" 2>/dev/null || warning "Failed to add $user to kvm group"
        success "User $user added to kvm group"
    fi
    
    # For some distributions, also add to libvirt-qemu group
    if getent group libvirt-qemu >/dev/null 2>&1; then
        usermod -aG libvirt-qemu "$user" 2>/dev/null || true
    fi
}

# Configure default network for libvirt
configure_libvirt_network() {
    info "Configuring libvirt default network..."
    
    # Wait for libvirtd to be ready
    local retries=0
    while ! virsh -c qemu:///system list >/dev/null 2>&1 && [ $retries -lt 10 ]; do
        sleep 1
        ((retries++))
    done
    
    # Define and start default network if not exists
    if ! virsh -c qemu:///system net-list --all | grep -q "default"; then
        info "Creating default network..."
        virsh -c qemu:///system net-define /dev/stdin <<EOF
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    fi
    
    # Start and autostart the network
    virsh -c qemu:///system net-start default 2>/dev/null || true
    virsh -c qemu:///system net-autostart default 2>/dev/null || true
    
    success "Default network configured"
}

# Install full KVM/QEMU stack with all necessary components
install_kvm_qemu() {
    local distro="$1"
    info "Installing full KVM/QEMU virtualization stack..."
    
    # Check virtualization support first
    check_virtualization_support || warning "Continuing with installation despite virtualization check failure"
    
    case "$distro" in
        "arch")
            info "Installing QEMU/KVM packages for Arch Linux..."
            # Core QEMU and KVM packages
            pacman -S --noconfirm --needed \
                qemu-full \
                libvirt \
                virt-manager \
                virt-viewer \
                edk2-ovmf \
                dnsmasq \
                bridge-utils \
                openbsd-netcat \
                dmidecode \
                iptables-nft \
                qemu-img \
                qemu-system-x86 \
                vde2 \
                || warning "Some packages may have failed to install"
            
            # Enable necessary kernel modules
            info "Loading KVM kernel modules..."
            modprobe kvm || warning "Failed to load kvm module"
            modprobe kvm_amd || modprobe kvm_intel || warning "Failed to load CPU-specific KVM module"
            
            # Enable and start libvirtd
            systemctl enable --now libvirtd.service || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd.service || true
            
            # Configure permissions
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            
            # Configure default network
            configure_libvirt_network
            
            success "Full KVM/QEMU stack installed for Arch Linux"
            ;;
            
        "ubuntu")
            info "Installing QEMU/KVM packages for Ubuntu/Debian..."
            # Update package list
            apt-get update || warning "Failed to update package list"
            
            # Core QEMU and KVM packages
            apt-get install -y \
                qemu-kvm \
                qemu-system \
                qemu-utils \
                libvirt-daemon-system \
                libvirt-daemon \
                libvirt-clients \
                bridge-utils \
                virt-manager \
                virt-viewer \
                ovmf \
                dnsmasq \
                netcat-openbsd \
                guestfs-tools \
                libguestfs-tools \
                || warning "Some packages may have failed to install"
            
            # Enable and start libvirtd
            systemctl enable --now libvirtd || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd || true
            
            # Configure permissions
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            
            # Configure default network
            configure_libvirt_network
            
            success "Full KVM/QEMU stack installed for Ubuntu/Debian"
            ;;
            
        "fedora")
            info "Installing QEMU/KVM packages for Fedora..."
            # Use virtualization group which includes all necessary packages
            dnf group install -y "Virtualization" || warning "Virtualization group install failed"
            
            # Install additional useful tools
            dnf install -y \
                virt-manager \
                virt-viewer \
                libguestfs-tools \
                guestfs-tools \
                || warning "Some packages may have failed to install"
            
            # Enable and start libvirtd
            systemctl enable --now libvirtd || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd || true
            
            # Configure permissions
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            
            # Configure default network
            configure_libvirt_network
            
            success "Full KVM/QEMU stack installed for Fedora"
            ;;
            
        "opensuse")
            info "Installing QEMU/KVM packages for OpenSUSE..."
            # Use patterns for comprehensive installation
            zypper install -y -t pattern kvm_server kvm_tools || warning "Pattern install failed"
            
            # Install additional packages
            zypper install -y \
                virt-manager \
                virt-viewer \
                qemu-tools \
                libguestfs0 \
                guestfs-tools \
                || warning "Some packages may have failed to install"
            
            # Enable and start libvirtd
            systemctl enable --now libvirtd || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd || true
            
            # Configure permissions
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            
            # Configure default network
            configure_libvirt_network
            
            success "Full KVM/QEMU stack installed for OpenSUSE"
            ;;
    esac
    
    # Verify installation
    info "Verifying KVM/QEMU installation..."
    if command -v virsh >/dev/null 2>&1; then
        success "virsh command available"
        
        # Test connection
        if virsh -c qemu:///system list >/dev/null 2>&1; then
            success "libvirt connection successful"
        else
            warning "libvirt connection test failed - you may need to reboot"
        fi
    else
        warning "virsh command not found - installation may be incomplete"
    fi
    
    echo
    info "KVM/QEMU Installation Summary:"
    info "  • Full QEMU virtualization stack installed"
    info "  • libvirt daemon configured and running"
    info "  • virt-manager (GUI) installed"
    info "  • UEFI/OVMF firmware installed"
    info "  • Default NAT network configured"
    info "  • User permissions configured"
    echo
    info "Next steps:"
    info "  1. Log out and log back in for group permissions to take effect"
    info "  2. Launch virt-manager to create VMs: virt-manager"
    info "  3. Or use virsh command line: virsh list --all"
    echo
}

install_virtualbox() {
    local distro="$1"
    info "Installing VirtualBox..."
    
    local primary_user
    primary_user=$(get_real_user)
    
    case "$distro" in
        "arch")
            info "Installing VirtualBox for Arch Linux..."
            pacman -S --noconfirm --needed \
                virtualbox \
                virtualbox-host-modules-arch \
                virtualbox-guest-iso \
                || warning "Some VirtualBox packages failed to install"
            
            # Load vboxdrv kernel module
            modprobe vboxdrv || warning "Failed to load vboxdrv module"
            
            # Add user to vboxusers group
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" || warning "Failed to add user to vboxusers group"
            fi
            
            success "VirtualBox installed for Arch Linux"
            ;;
            
        "ubuntu")
            info "Installing VirtualBox for Ubuntu/Debian..."
            apt-get update || warning "Failed to update package list"
            apt-get install -y \
                virtualbox \
                virtualbox-ext-pack \
                virtualbox-guest-additions-iso \
                || warning "Some VirtualBox packages failed to install"
            
            # Add user to vboxusers group
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" || warning "Failed to add user to vboxusers group"
            fi
            
            success "VirtualBox installed for Ubuntu/Debian"
            ;;
            
        "fedora")
            info "Installing VirtualBox for Fedora..."
            dnf install -y \
                VirtualBox \
                kernel-devel \
                kernel-headers \
                || warning "Some VirtualBox packages failed to install"
            
            # Rebuild VirtualBox kernel modules
            /usr/lib/virtualbox/vboxdrv.sh setup || warning "VirtualBox kernel module setup failed"
            
            # Add user to vboxusers group
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" || warning "Failed to add user to vboxusers group"
            fi
            
            success "VirtualBox installed for Fedora"
            ;;
            
        "opensuse")
            info "Installing VirtualBox for OpenSUSE..."
            zypper install -y \
                virtualbox \
                virtualbox-host-source \
                || warning "Some VirtualBox packages failed to install"
            
            # Add user to vboxusers group
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" || warning "Failed to add user to vboxusers group"
            fi
            
            success "VirtualBox installed for OpenSUSE"
            ;;
    esac
    
    # Verify installation
    if command -v VBoxManage >/dev/null 2>&1; then
        success "VirtualBox command line tools available"
        local vbox_version
        vbox_version=$(VBoxManage --version 2>/dev/null || echo "unknown")
        info "VirtualBox version: $vbox_version"
    else
        warning "VirtualBox installation verification failed"
    fi
    
    echo
    info "VirtualBox Installation Summary:"
    info "  • VirtualBox hypervisor installed"
    info "  • Guest additions ISO installed"
    info "  • User added to vboxusers group"
    echo
    info "Next steps:"
    info "  1. Log out and log back in for group permissions to take effect"
    info "  2. Launch VirtualBox: virtualbox"
    echo
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
    echo "This module installs virtualization software for running virtual machines."
    echo
    echo "Available hypervisors:"
    echo "  1) KVM/QEMU (Full Stack) - Recommended for Linux"
    echo "     • Native Linux virtualization (best performance)"
    echo "     • Full QEMU system emulation"
    echo "     • virt-manager GUI and virsh CLI"
    echo "     • UEFI/OVMF firmware support"
    echo "     • Default NAT networking pre-configured"
    echo
    echo "  2) VirtualBox - Alternative option"
    echo "     • Cross-platform compatibility"
    echo "     • User-friendly GUI"
    echo "     • Good for development/testing"
    echo
    echo "  3) Skip hypervisor installation"
    echo
    
    # Non-interactive fallback
    if [[ ! -t 0 ]]; then
        warning "Non-interactive mode detected - installing KVM/QEMU (recommended)"
        install_kvm_qemu "$distro"
        return 0
    fi
    
    read -r -p "Choose a hypervisor to install (1-3): " choice
    
    case "$choice" in
        1)
            install_kvm_qemu "$distro"
            ;;
        2)
            install_virtualbox "$distro"
            ;;
        3|"")
            info "Skipping hypervisor installation"
            ;;
        *)
            warning "Invalid choice '$choice', skipping hypervisor installation"
            ;;
    esac
    
    echo
    success "Hypervisor module complete!"
    echo
}

main "$@"
