#!/bin/bash

# ==============================================================================
# GZ302 Hypervisor Software Module
# Version: 2.3.14
#
# This module installs hypervisor software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Full KVM/QEMU stack, VirtualBox
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
    local total_steps=5
    
    print_section "KVM/QEMU Virtualization Stack"
    info "Setting up full QEMU/KVM virtualization for ${distro^}..."
    
    # Step 1: Check virtualization support
    print_step 1 $total_steps "Checking virtualization support..."
    check_virtualization_support || warning "Continuing despite virtualization check failure"
    completed_item "Hardware virtualization check complete"
    
    case "$distro" in
        "arch")
            # Step 2: Install packages
            print_step 2 $total_steps "Installing QEMU/KVM packages..."
            echo -ne "${C_DIM}"
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
                qemu-img \
                qemu-system-x86 \
                vde2 \
                2>&1 | grep -v "^::" | grep -v "looking for conflicting" | grep -v "checking available" || true
            echo -ne "${C_NC}"
            completed_item "Core QEMU/KVM packages installed"
            
            # Try nftables
            if ! pacman -Q nftables >/dev/null 2>&1; then
                echo -ne "${C_DIM}"
                if pacman -S --noconfirm nftables 2>&1 | grep -v "^::" || true; then
                    echo -ne "${C_NC}"
                    completed_item "nftables firewall installed"
                else
                    echo -ne "${C_NC}"
                    warning "nftables installation failed - using fallback"
                fi
            fi
            
            # Step 3: Load kernel modules
            print_step 3 $total_steps "Loading KVM kernel modules..."
            modprobe kvm || warning "Failed to load kvm module"
            modprobe kvm_amd || modprobe kvm_intel || warning "Failed to load CPU-specific KVM module"
            completed_item "KVM kernel modules loaded"
            
            # Step 4: Enable services
            print_step 4 $total_steps "Enabling virtualization services..."
            systemctl enable --now libvirtd.service >/dev/null 2>&1 || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd.service >/dev/null 2>&1 || true
            completed_item "libvirtd and virtlogd services enabled"
            
            # Step 5: Configure permissions and network
            print_step 5 $total_steps "Configuring permissions and networking..."
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            configure_libvirt_network
            completed_item "User permissions and NAT network configured"
            ;;
            
        "ubuntu")
            # Step 2: Install packages
            print_step 2 $total_steps "Updating package lists and installing..."
            echo -ne "${C_DIM}"
            apt-get update 2>&1 | tail -5 || true
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
                2>&1 | grep -E "^(Setting up|Processing|Unpacking)" | head -10 || true
            echo -ne "${C_NC}"
            completed_item "QEMU/KVM packages installed"
            
            # Step 3: Enable services
            print_step 3 $total_steps "Enabling virtualization services..."
            systemctl enable --now libvirtd >/dev/null 2>&1 || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd >/dev/null 2>&1 || true
            completed_item "libvirtd and virtlogd services enabled"
            
            # Step 4: Load kernel modules (no-op on Ubuntu - auto-loaded)
            print_step 4 $total_steps "Verifying kernel modules..."
            if lsmod | grep -q kvm; then
                completed_item "KVM kernel modules verified"
            else
                warning "KVM modules not loaded - may need reboot"
            fi
            
            # Step 5: Configure permissions
            print_step 5 $total_steps "Configuring permissions and networking..."
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            configure_libvirt_network
            completed_item "User permissions and NAT network configured"
            ;;
            
        "fedora")
            # Step 2: Install virtualization group
            print_step 2 $total_steps "Installing virtualization packages..."
            echo -ne "${C_DIM}"
            dnf group install -y "Virtualization" 2>&1 | grep -E "^(Installing|Upgrading|Complete)" | head -10 || true
            dnf install -y \
                virt-manager \
                virt-viewer \
                libguestfs-tools \
                guestfs-tools \
                2>&1 | grep -E "^(Installing|Complete)" | head -5 || true
            echo -ne "${C_NC}"
            completed_item "Virtualization packages installed"
            
            # Step 3: Enable services
            print_step 3 $total_steps "Enabling virtualization services..."
            systemctl enable --now libvirtd >/dev/null 2>&1 || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd >/dev/null 2>&1 || true
            completed_item "libvirtd and virtlogd services enabled"
            
            # Step 4: Verify kernel modules
            print_step 4 $total_steps "Verifying kernel modules..."
            if lsmod | grep -q kvm; then
                completed_item "KVM kernel modules verified"
            else
                warning "KVM modules not loaded - may need reboot"
            fi
            
            # Step 5: Configure permissions
            print_step 5 $total_steps "Configuring permissions and networking..."
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            configure_libvirt_network
            completed_item "User permissions and NAT network configured"
            ;;
            
        "opensuse")
            # Step 2: Install patterns and packages
            print_step 2 $total_steps "Installing virtualization patterns and packages..."
            echo -ne "${C_DIM}"
            zypper install -y -t pattern kvm_server kvm_tools 2>&1 | grep -E "^(Installing|done)" | head -10 || true
            zypper install -y \
                virt-manager \
                virt-viewer \
                qemu-tools \
                libguestfs0 \
                guestfs-tools \
                2>&1 | grep -E "^(Installing|done)" | head -5 || true
            echo -ne "${C_NC}"
            completed_item "Virtualization packages installed"
            
            # Step 3: Enable services
            print_step 3 $total_steps "Enabling virtualization services..."
            systemctl enable --now libvirtd >/dev/null 2>&1 || warning "Failed to enable libvirtd"
            systemctl enable --now virtlogd >/dev/null 2>&1 || true
            completed_item "libvirtd and virtlogd services enabled"
            
            # Step 4: Verify kernel modules
            print_step 4 $total_steps "Verifying kernel modules..."
            if lsmod | grep -q kvm; then
                completed_item "KVM kernel modules verified"
            else
                warning "KVM modules not loaded - may need reboot"
            fi
            
            # Step 5: Configure permissions
            print_step 5 $total_steps "Configuring permissions and networking..."
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                configure_libvirt_permissions "$primary_user"
            fi
            configure_libvirt_network
            completed_item "User permissions and NAT network configured"
            ;;
    esac
    
    # Verification summary
    print_subsection "Installation Verification"
    if command -v virsh >/dev/null 2>&1; then
        completed_item "virsh command available"
        
        if virsh -c qemu:///system list >/dev/null 2>&1; then
            completed_item "libvirt connection successful"
        else
            warning "libvirt connection test failed - you may need to reboot"
        fi
    else
        failed_item "virsh command not found - installation may be incomplete"
    fi
    
    # Summary display
    print_subsection "Installed Components"
    print_keyval "QEMU Stack" "Full system emulation"
    print_keyval "libvirt" "Virtualization management"
    print_keyval "virt-manager" "GUI for VM management"
    print_keyval "OVMF/UEFI" "Firmware for VMs"
    print_keyval "Network" "NAT (192.168.122.0/24)"
    
    print_box "KVM/QEMU Virtualization Ready"
    
    print_tip "Log out and back in for group permissions, then run: virt-manager"
}

install_virtualbox() {
    local distro="$1"
    local total_steps=3
    
    print_section "VirtualBox Installation"
    
    local primary_user
    primary_user=$(get_real_user)
    
    case "$distro" in
        "arch")
            # Step 1: Install packages
            print_step 1 $total_steps "Installing VirtualBox packages..."
            echo -ne "${C_DIM}"
            pacman -S --noconfirm --needed \
                virtualbox \
                virtualbox-host-modules-arch \
                virtualbox-guest-iso \
                2>&1 | grep -v "^::" | grep -v "looking for conflicting" || true
            echo -ne "${C_NC}"
            completed_item "VirtualBox packages installed"
            
            # Step 2: Load kernel module
            print_step 2 $total_steps "Loading VirtualBox kernel module..."
            modprobe vboxdrv 2>/dev/null || warning "Failed to load vboxdrv module"
            completed_item "Kernel module loaded"
            
            # Step 3: Configure user permissions
            print_step 3 $total_steps "Configuring user permissions..."
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" 2>/dev/null || warning "Failed to add user to vboxusers group"
            fi
            completed_item "User added to vboxusers group"
            ;;
            
        "ubuntu")
            # Step 1: Install packages
            print_step 1 $total_steps "Installing VirtualBox packages..."
            echo -ne "${C_DIM}"
            apt-get update 2>&1 | tail -3 || true
            apt-get install -y \
                virtualbox \
                virtualbox-ext-pack \
                virtualbox-guest-additions-iso \
                2>&1 | grep -E "^(Setting up|Unpacking)" | head -5 || true
            echo -ne "${C_NC}"
            completed_item "VirtualBox packages installed"
            
            # Step 2: Verify kernel module
            print_step 2 $total_steps "Verifying kernel module..."
            if lsmod | grep -q vboxdrv; then
                completed_item "VirtualBox kernel module loaded"
            else
                warning "vboxdrv module not loaded - may need reboot"
            fi
            
            # Step 3: Configure user permissions
            print_step 3 $total_steps "Configuring user permissions..."
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" 2>/dev/null || warning "Failed to add user to vboxusers group"
            fi
            completed_item "User added to vboxusers group"
            ;;
            
        "fedora")
            # Step 1: Install packages
            print_step 1 $total_steps "Installing VirtualBox packages..."
            echo -ne "${C_DIM}"
            dnf install -y \
                VirtualBox \
                kernel-devel \
                kernel-headers \
                2>&1 | grep -E "^(Installing|Complete)" | head -5 || true
            echo -ne "${C_NC}"
            completed_item "VirtualBox packages installed"
            
            # Step 2: Build kernel modules
            print_step 2 $total_steps "Building VirtualBox kernel modules..."
            /usr/lib/virtualbox/vboxdrv.sh setup 2>/dev/null || warning "VirtualBox kernel module setup failed"
            completed_item "Kernel modules built"
            
            # Step 3: Configure user permissions
            print_step 3 $total_steps "Configuring user permissions..."
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" 2>/dev/null || warning "Failed to add user to vboxusers group"
            fi
            completed_item "User added to vboxusers group"
            ;;
            
        "opensuse")
            # Step 1: Install packages
            print_step 1 $total_steps "Installing VirtualBox packages..."
            echo -ne "${C_DIM}"
            zypper install -y \
                virtualbox \
                virtualbox-host-source \
                2>&1 | grep -E "^(Installing|done)" | head -5 || true
            echo -ne "${C_NC}"
            completed_item "VirtualBox packages installed"
            
            # Step 2: Verify installation
            print_step 2 $total_steps "Verifying installation..."
            if lsmod | grep -q vboxdrv; then
                completed_item "VirtualBox kernel module loaded"
            else
                warning "vboxdrv module not loaded - may need reboot"
            fi
            
            # Step 3: Configure user permissions
            print_step 3 $total_steps "Configuring user permissions..."
            if [[ "$primary_user" != "root" ]]; then
                usermod -aG vboxusers "$primary_user" 2>/dev/null || warning "Failed to add user to vboxusers group"
            fi
            completed_item "User added to vboxusers group"
            ;;
    esac
    
    # Verification
    print_subsection "Installation Verification"
    if command -v VBoxManage >/dev/null 2>&1; then
        local vbox_version
        vbox_version=$(VBoxManage --version 2>/dev/null || echo "unknown")
        completed_item "VirtualBox installed (v${vbox_version})"
    else
        failed_item "VirtualBox installation verification failed"
    fi
    
    # Summary
    print_subsection "Installed Components"
    print_keyval "VirtualBox" "Hypervisor"
    print_keyval "Guest ISO" "Guest additions"
    print_keyval "User Group" "vboxusers"
    
    print_box "VirtualBox Ready"
    
    print_tip "Log out and back in for group permissions, then run: virtualbox"
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
    
    print_box "GZ302 Hypervisor Software Installation"
    
    echo
    info "This module installs virtualization software for running virtual machines."
    echo
    
    print_subsection "Available Hypervisors"
    echo
    printf "  %s1)%s KVM/QEMU (Full Stack) - %sRecommended for Linux%s\n" "${C_BOLD_CYAN}" "${C_NC}" "${C_GREEN}" "${C_NC}"
    printf "     %s• Native Linux virtualization (best performance)%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• Full QEMU system emulation%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• virt-manager GUI and virsh CLI%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• UEFI/OVMF firmware support%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• Default NAT networking pre-configured%s\n" "${C_DIM}" "${C_NC}"
    echo
    printf "  %s2)%s VirtualBox - Alternative option\n" "${C_BOLD_CYAN}" "${C_NC}"
    printf "     %s• Cross-platform compatibility%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• User-friendly GUI%s\n" "${C_DIM}" "${C_NC}"
    printf "     %s• Good for development/testing%s\n" "${C_DIM}" "${C_NC}"
    echo
    printf "  %s3)%s Skip hypervisor installation\n" "${C_BOLD_CYAN}" "${C_NC}"
    echo
    
    # Non-interactive fallback
    if [[ ! -t 0 ]] && [[ ! -t 1 ]]; then
        warning "Non-interactive mode detected - installing KVM/QEMU (recommended)"
        install_kvm_qemu "$distro"
        return 0
    fi
    
    local choice=""
    # Read from /dev/tty to ensure we get user input even when stdin is redirected
    printf "%sChoose a hypervisor to install (1-3):%s " "${C_BOLD_CYAN}" "${C_NC}"
    if [[ -r /dev/tty ]]; then
        read -r choice < /dev/tty
    else
        read -r choice
    fi
    
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
    
    print_box "Hypervisor Module Complete"
}

main "$@"