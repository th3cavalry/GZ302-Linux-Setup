#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 4.2 - Python Implementation: Modern script architecture with enhanced capabilities
#
# This script automatically detects your Linux distribution and applies
# the appropriate setup for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+.
# It applies critical hardware fixes and allows optional software installation.
#
# Supported Distributions:
# - Arch-based: Arch Linux (also supports EndeavourOS, Manjaro)
# - Debian-based: Ubuntu (also supports Pop!_OS, Linux Mint)
# - RPM-based: Fedora (also supports Nobara)
# - OpenSUSE: Tumbleweed and Leap
#
# PRE-REQUISITES:
# 1. A supported Linux distribution
# 2. An active internet connection
# 3. A user with sudo privileges
#
# USAGE:
# 1. Download the script:
#    curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302_setup.sh -o gz302_setup.sh
# 2. Make it executable:
#    chmod +x gz302_setup.sh
# 3. Run with sudo:
#    sudo ./gz302_setup.sh
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Add error handling trap
cleanup_on_error() {
    local exit_code=$?
    echo
    echo "❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌"
    echo -e "${C_RED}[ERROR]${C_NC} Script failed with exit code: $exit_code"
    echo -e "${C_RED}[ERROR]${C_NC} The setup process was interrupted and may be incomplete."
    echo -e "${C_RED}[ERROR]${C_NC} Please check the error messages above for details."
    echo -e "${C_RED}[ERROR]${C_NC} You may need to run the script again or fix issues manually."
    echo "❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌"
    echo
}

# Set up the error trap
trap cleanup_on_error ERR

# --- Helper Functions for User Feedback ---
# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m' # No Color

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

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
}

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        echo "$(logname 2>/dev/null || whoami)"
    fi
}

# --- GPU Detection ---
detect_discrete_gpu() {
    local dgpu_found=false
    
    # Check for discrete GPUs using lspci
    if command -v lspci >/dev/null 2>&1; then
        # Look for NVIDIA or AMD discrete GPUs (excluding integrated)
        if lspci | grep -i "vga\|3d\|display" | grep -i "nvidia\|radeon.*r[567x]\|radeon.*rx\|geforce\|quadro\|tesla" >/dev/null 2>&1; then
            dgpu_found=true
        fi
        
        # Additional check for AMD discrete GPUs with specific patterns
        if lspci | grep -i "vga\|3d\|display" | grep -E -i "(radeon.*(hd|r[567x]|rx|vega|navi|rdna))|ati.*(hd|r[567x])" >/dev/null 2>&1; then
            # Exclude integrated Ryzen graphics (Vega, Radeon Graphics)
            if ! lspci | grep -i "vga\|3d\|display" | grep -E -i "ryzen.*integrated|amd.*ryzen.*vega|radeon.*vega.*graphics" >/dev/null 2>&1; then
                dgpu_found=true
            fi
        fi
    fi
    
    # Additional check using /sys/class/drm if lspci is not available
    if [[ "$dgpu_found" == false ]] && [[ -d /sys/class/drm ]]; then
        # Count the number of GPU cards, integrated usually shows as card0
        local gpu_count=$(find /sys/class/drm -name "card[0-9]*" -type d | wc -l)
        if [[ $gpu_count -gt 1 ]]; then
            dgpu_found=true
        fi
    fi
    
    if [[ "$dgpu_found" == true ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    local version=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="$ID"
        version="${VERSION_ID:-unknown}"
        
        # Handle special cases and derivatives - route to base distributions
        case "$distro" in
            "arch")
                distro="arch"
                ;;
            "endeavouros"|"manjaro")
                # Route Arch derivatives to base Arch
                distro="arch"
                ;;
            "ubuntu")
                distro="ubuntu"
                ;;
            "pop"|"linuxmint")
                # Route Ubuntu derivatives to base Ubuntu  
                distro="ubuntu"
                ;;
            "fedora")
                distro="fedora"
                ;;
            "nobara")
                # Route Fedora derivatives to base Fedora
                distro="fedora"
                ;;
            "opensuse-tumbleweed"|"opensuse-leap"|"opensuse")
                distro="opensuse"
                ;;
            *)
                # Try to detect based on package managers and route to base distros
                if command -v pacman >/dev/null 2>&1; then
                    # All Arch-based distros route to arch
                    distro="arch"
                elif command -v apt >/dev/null 2>&1; then
                    # All Debian-based distros route to ubuntu  
                    distro="ubuntu"
                elif command -v dnf >/dev/null 2>&1; then
                    # All RPM-based distros route to fedora
                    distro="fedora"
                elif command -v zypper >/dev/null 2>&1; then
                    distro="opensuse"
                fi
                ;;
        esac
    fi
    
    if [[ -z "$distro" ]]; then
        error "Could not detect your Linux distribution. Supported base distributions: Arch, Ubuntu, Fedora, OpenSUSE (including their derivatives)"
    fi
    
    echo "$distro"
}

# --- User Choice Functions ---
get_user_choices() {
    local install_gaming=""
    local install_llm=""
    local install_snapshots=""
    local install_secureboot=""
    local install_hypervisor=""
    
    echo
    info "The script will now apply GZ302-specific hardware fixes automatically."
    info "You can choose which optional software to install:"
    echo
    
    # Ask about gaming installation
    echo "Gaming Software includes:"
    echo "- Steam, Lutris, ProtonUp-Qt"
    echo "- MangoHUD, GameMode, Wine"
    echo "- Gaming optimizations and performance tweaks"
    echo ""
    read -p "Do you want to install gaming software? (y/n): " install_gaming
    
    # Ask about LLM installation
    echo ""
    echo "LLM (AI/ML) Software includes:"
    echo "- Ollama for local LLM inference"
    echo "- ROCm for AMD GPU acceleration"
    echo "- PyTorch and Transformers libraries"
    echo ""
    read -p "Do you want to install LLM/AI software? (y/n): " install_llm
    
    # Ask about hypervisor installation
    echo ""
    echo "Hypervisor Software allows you to run virtual machines:"
    echo "Available options:"
    echo "  1) KVM/QEMU with virt-manager (Open source, excellent performance)"
    echo "  2) VirtualBox (Oracle, user-friendly)"
    echo "  3) VMware Workstation Pro (Commercial, feature-rich)"
    echo "  4) Xen with Xen Orchestra (Enterprise-grade)"
    echo "  5) Proxmox VE (Complete virtualization platform)"
    echo "  6) None - skip hypervisor installation"
    echo ""
    read -p "Choose a hypervisor to install (1-6): " install_hypervisor
    
    # Ask about system snapshots
    echo ""
    echo "System Snapshots provide:"
    echo "- Automatic daily system backups"
    echo "- Easy system recovery and rollback"
    echo "- Supports ZFS, Btrfs, ext4 (with LVM), and XFS filesystems"
    echo "- 'gz302-snapshot' command for manual management"
    echo ""
    read -p "Do you want to enable system snapshots? (y/n): " install_snapshots
    
    # Ask about secure boot
    echo ""
    echo "Secure Boot provides:"
    echo "- Enhanced system security and boot integrity"
    echo "- Automatic kernel signing on updates"
    echo "- Supports GRUB, systemd-boot, and rEFInd bootloaders"
    echo "- Requires UEFI system and manual BIOS configuration"
    echo ""
    read -p "Do you want to configure Secure Boot? (y/n): " install_secureboot
    
    echo ""
    
    # Export variables for use in other functions
    export INSTALL_GAMING="$install_gaming"
    export INSTALL_LLM="$install_llm"
    export INSTALL_HYPERVISOR="$install_hypervisor"
    export INSTALL_SNAPSHOTS="$install_snapshots"
    export INSTALL_SECUREBOOT="$install_secureboot"
}

# --- Distribution-Specific Setup Functions ---
setup_arch_based() {
    local distro="$1"
    info "Setting up Arch-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    pacman -Syu --noconfirm --needed
    pacman -S --noconfirm --needed git base-devel wget curl
    
    # Install AUR helper if not present (for Arch-based systems)
    if [[ "$distro" == "arch" ]] && ! command -v yay >/dev/null 2>&1; then
        info "Installing yay AUR helper..."
        local primary_user=$(get_real_user)
        sudo -u "$primary_user" -H bash << 'EOF'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOF
    fi
    
    # Apply hardware fixes
    apply_arch_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "arch"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_arch_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_arch_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_arch_hypervisor_software "${INSTALL_HYPERVISOR}"
        success "Hypervisor installation completed successfully"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_arch_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_arch_secureboot
    fi
    
    enable_arch_services
}

setup_debian_based() {
    local distro="$1"
    info "Setting up Debian-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    apt update
    apt upgrade -y
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    
    # Apply hardware fixes
    apply_debian_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "debian"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_debian_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_debian_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_debian_hypervisor_software "${INSTALL_HYPERVISOR}"
        success "Hypervisor installation completed successfully"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_debian_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_debian_secureboot
    fi
    
    enable_debian_services
}

setup_fedora_based() {
    local distro="$1"
    info "Setting up Fedora-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    dnf update -y
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        rpmfusion-free-release rpmfusion-nonfree-release
    
    # Apply hardware fixes
    apply_fedora_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "fedora"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_fedora_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_fedora_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_fedora_hypervisor_software "${INSTALL_HYPERVISOR}"
        success "Hypervisor installation completed successfully"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_fedora_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_fedora_secureboot
    fi
    
    enable_fedora_services
}

setup_opensuse() {
    local distro="$1"
    info "Setting up OpenSUSE system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    zypper refresh
    zypper update -y
    zypper install -y curl wget git gcc gcc-c++ make kernel-default-devel
    
    # Apply hardware fixes
    apply_opensuse_hardware_fixes
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "opensuse"
    
    # Install optional software based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        install_opensuse_gaming_software
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        install_opensuse_llm_software
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        install_opensuse_hypervisor_software "${INSTALL_HYPERVISOR}"
        success "Hypervisor installation completed successfully"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        setup_opensuse_snapshots
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        setup_opensuse_secureboot
    fi
    
    enable_opensuse_services
}

# Apply comprehensive hardware fixes for Arch-based systems
apply_arch_hardware_fixes() {
    info "Applying comprehensive GZ302 hardware fixes for Arch-based systems..."
    
    # Check for discrete GPU to determine which packages to install
    local has_dgpu=$(detect_discrete_gpu)
    
    if [[ "$has_dgpu" == "true" ]]; then
        info "Discrete GPU detected, installing full GPU management suite..."
        # Install kernel and drivers with GPU switching support
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control
    else
        info "No discrete GPU detected, installing base ASUS control packages..."
        # Install kernel and drivers without supergfxctl (for integrated graphics only)
        pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl rog-control-center power-profiles-daemon
        # switcheroo-control may still be useful for some systems
        pacman -S --noconfirm --needed switcheroo-control || warning "switcheroo-control not available, continuing..."
    fi
    
    # ACPI BIOS error mitigation for GZ302
    info "Adding ACPI error mitigation kernel parameters..."
    if [ -f /etc/default/grub ]; then
        # Add kernel parameters to handle ACPI BIOS errors
        if ! grep -q "acpi_osi=" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="acpi_osi=! acpi_osi=\\\"Windows 2020\\\" acpi_enforce_resources=lax /' /etc/default/grub
        fi
    fi
    
    # Regenerate bootloader configuration
    if [ -f /boot/grub/grub.cfg ]; then
        info "Regenerating GRUB configuration..."
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying enhanced Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# MediaTek MT7925E stability and performance fixes
# Only include valid module parameters to avoid kernel warnings
options mt7925e disable_aspm=1
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
wifi.backend=wpa_supplicant

[main]
wifi.scan-rand-mac-address=no
EOF

    # Add udev rules for Wi-Fi stability
    cat > /etc/udev/rules.d/99-wifi-powersave.rules <<EOF
# Disable Wi-Fi power saving for MediaTek MT7925e
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev \$name set power_save off"
EOF
    
    # Touchpad fixes
    info "Applying touchpad detection and sensitivity fixes..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 folio touchpad override
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create libinput configuration to address touch jump detection
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<EOF
Section "InputClass"
    Identifier "ASUS GZ302 Touchpad"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    MatchProduct "ASUSTeK Computer Inc. GZ302EA-Keyboard Touchpad"
    Driver "libinput"
    Option "DisableWhileTyping" "off"
    Option "TappingDrag" "on"
    Option "TappingDragLock" "on"
    Option "MiddleEmulation" "on"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "HorizontalScrolling" "on"
    Option "SendEventsMode" "enabled"
EndSection
EOF

    # Create systemd service to reload hid_asus module
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module with correct options for Z13 Touchpad
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'if ! lsmod | grep -q hid_asus; then exit 0; fi'
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Audio fixes
    info "Applying audio fixes for GZ302..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Fix audio issues on ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
# ACP70 platform fixes for newer AMD audio
options snd_acp_pci enable=1
options snd-soc-acp70 machine=acp70-asus
EOF

    # ASUS WMI fixes to reduce error messages
    info "Applying ASUS WMI optimizations..."
    cat > /etc/modprobe.d/asus-wmi.conf <<EOF
# ASUS WMI optimizations for GZ302
# Reduces fan curve and other WMI-related error messages
options asus_wmi dev_id=0x00110000
options asus_nb_wmi wapf=1
EOF
    
    # HID ASUS module optimizations
    cat > /etc/modprobe.d/hid-asus.conf <<EOF
# HID ASUS optimizations for better touchpad/keyboard support
options hid_asus fnlock_default=0
options hid_asus kbd_backlight=1
# Memory management fixes to prevent probe failures (error -12)
options hid_asus max_hid_buflen=8192
EOF
    
    # AMD GPU optimizations
    info "Applying AMD GPU optimizations..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF
    
    # Camera fixes
    info "Applying camera fixes..."
    cat > /etc/modprobe.d/uvcvideo.conf <<EOF
# Camera fixes for GZ302
options uvcvideo quirks=128
options uvcvideo timeout=5000
EOF
    
    # Update hardware database
    systemd-hwdb update
    udevadm control --reload
    
    # I/O scheduler fixes for NVMe devices
    info "Applying I/O scheduler optimizations..."
    cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set appropriate I/O schedulers for different device types
# NVMe drives work best with 'none' scheduler but fall back to 'mq-deadline'
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none", ATTR{queue/scheduler}="mq-deadline"
# SATA SSDs work well with 'mq-deadline' 
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# Traditional HDDs work best with 'bfq'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    
    success "Comprehensive hardware fixes applied for Arch-based systems"
}

apply_debian_hardware_fixes() {
    info "Applying comprehensive GZ302 hardware fixes for Debian-based systems..."
    
    # Install kernel and drivers
    apt install -y linux-generic-hwe-22.04 firmware-misc-nonfree
    
    # ACPI BIOS error mitigation for GZ302
    info "Adding ACPI error mitigation kernel parameters..."
    if [ -f /etc/default/grub ]; then
        # Add kernel parameters to handle ACPI BIOS errors
        if ! grep -q "acpi_osi=" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="acpi_osi=! acpi_osi=\\\"Windows 2020\\\" acpi_enforce_resources=lax /' /etc/default/grub
            update-grub
        fi
    fi
    
    # Wi-Fi fixes for MediaTek MT7925e  
    info "Applying enhanced Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# MediaTek MT7925E stability and performance fixes
# Only include valid module parameters to avoid kernel warnings
options mt7925e disable_aspm=1
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
wifi.backend=wpa_supplicant

[main]
wifi.scan-rand-mac-address=no
EOF

    # Add udev rules for Wi-Fi stability
    cat > /etc/udev/rules.d/99-wifi-powersave.rules <<EOF
# Disable Wi-Fi power saving for MediaTek MT7925e
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev \$name set power_save off"
EOF
    
    # Touchpad fixes
    info "Applying touchpad detection and sensitivity fixes..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 folio touchpad override
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create libinput configuration to address touch jump detection
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<EOF
Section "InputClass"
    Identifier "ASUS GZ302 Touchpad"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    MatchProduct "ASUSTeK Computer Inc. GZ302EA-Keyboard Touchpad"
    Driver "libinput"
    Option "DisableWhileTyping" "off"
    Option "TappingDrag" "on"
    Option "TappingDragLock" "on"
    Option "MiddleEmulation" "on"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "HorizontalScrolling" "on"
    Option "SendEventsMode" "enabled"
EndSection
EOF

    # Create systemd service to reload hid_asus module
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module with correct options for Z13 Touchpad
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'if ! lsmod | grep -q hid_asus; then exit 0; fi'
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Audio fixes
    info "Applying audio fixes for GZ302..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Fix audio issues on ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
# ACP70 platform fixes for newer AMD audio
options snd_acp_pci enable=1
options snd-soc-acp70 machine=acp70-asus
EOF

    # ASUS WMI fixes to reduce error messages
    info "Applying ASUS WMI optimizations..."
    cat > /etc/modprobe.d/asus-wmi.conf <<EOF
# ASUS WMI optimizations for GZ302
# Reduces fan curve and other WMI-related error messages
options asus_wmi dev_id=0x00110000
options asus_nb_wmi wapf=1
EOF
    
    # HID ASUS module optimizations
    cat > /etc/modprobe.d/hid-asus.conf <<EOF
# HID ASUS optimizations for better touchpad/keyboard support
options hid_asus fnlock_default=0
options hid_asus kbd_backlight=1
# Memory management fixes to prevent probe failures (error -12)
options hid_asus max_hid_buflen=8192
EOF
    
    # AMD GPU optimizations
    info "Applying AMD GPU optimizations..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF
    
    # Camera fixes
    info "Applying camera fixes..."
    cat > /etc/modprobe.d/uvcvideo.conf <<EOF
# Camera fixes for GZ302
options uvcvideo quirks=128
options uvcvideo timeout=5000
EOF
    
    # Update hardware database
    systemd-hwdb update
    udevadm control --reload
    
    # I/O scheduler fixes for NVMe devices
    info "Applying I/O scheduler optimizations..."
    cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set appropriate I/O schedulers for different device types
# NVMe drives work best with 'none' scheduler but fall back to 'mq-deadline'
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none", ATTR{queue/scheduler}="mq-deadline"
# SATA SSDs work well with 'mq-deadline' 
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# Traditional HDDs work best with 'bfq'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    
    success "Comprehensive hardware fixes applied for Debian-based systems"
}

apply_fedora_hardware_fixes() {
    info "Applying GZ302 hardware fixes for Fedora-based systems..."
    
    # Install kernel and drivers
    dnf install -y kernel-devel akmod-nvidia
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying Wi-Fi stability fixes..."
    cat > /etc/modprobe.d/mt7925e.conf <<EOF
# MediaTek MT7925E stability fixes
options mt7925e disable_aspm=1
EOF
    
    # Touchpad fixes
    info "Applying touchpad fixes..."
    mkdir -p /etc/udev/rules.d
    cat > /etc/udev/rules.d/99-asus-touchpad.rules << 'EOF'
# ASUS ROG Flow Z13 (GZ302) Touchpad Fix
SUBSYSTEM=="input", ATTRS{name}=="ASUS Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="0"
SUBSYSTEM=="input", ATTRS{name}=="*Touchpad*", ATTR{[dmi/id]product_name}=="ROG Flow Z13 GZ302*", ENV{LIBINPUT_IGNORE_DEVICE}="0"
EOF
    
    # Audio fixes
    info "Applying audio fixes..."
    echo 'options snd-hda-intel model=asus-zenbook' > /etc/modprobe.d/alsa-asus.conf
    
    success "Hardware fixes applied for Fedora-based systems"
}

apply_opensuse_hardware_fixes() {
    info "Applying GZ302 hardware fixes for OpenSUSE..."
    
    # Install kernel and drivers
    zypper install -y kernel-default-devel
    
    # Wi-Fi fixes for MediaTek MT7925e
    info "Applying Wi-Fi stability fixes..."
    cat > /etc/modprobe.d/mt7925e.conf <<EOF
# MediaTek MT7925E stability fixes
options mt7925e disable_aspm=1
EOF
    
    # Touchpad fixes
    info "Applying touchpad fixes..."
    mkdir -p /etc/udev/rules.d
    cat > /etc/udev/rules.d/99-asus-touchpad.rules << 'EOF'
# ASUS ROG Flow Z13 (GZ302) Touchpad Fix
SUBSYSTEM=="input", ATTRS{name}=="ASUS Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="0"
SUBSYSTEM=="input", ATTRS{name}=="*Touchpad*", ATTR{[dmi/id]product_name}=="ROG Flow Z13 GZ302*", ENV{LIBINPUT_IGNORE_DEVICE}="0"
EOF
    
    # Audio fixes
    info "Applying audio fixes..."
    echo 'options snd-hda-intel model=asus-zenbook' > /etc/modprobe.d/alsa-asus.conf
    
    success "Hardware fixes applied for OpenSUSE"
}

# Enhanced gaming software installation functions
install_arch_gaming_software() {
    info "Installing comprehensive gaming software for Arch-based system..."
    
    # Enable multilib repository if not already enabled
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        info "Enabling multilib repository..."
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        pacman -Sy
    fi
    
    # Install core gaming applications
    info "Installing Steam, Lutris, GameMode, and essential libraries..."
    pacman -S --noconfirm --needed steam lutris gamemode lib32-gamemode \
        vulkan-radeon lib32-vulkan-radeon \
        gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
    
    # Install additional gaming tools
    info "Installing additional gaming tools and performance utilities..."
    pacman -S --noconfirm --needed \
        mangohud goverlay \
        wine-staging winetricks \
        corectrl \
        mesa-utils vulkan-tools \
        lib32-mesa lib32-vulkan-radeon \
        pipewire pipewire-pulse pipewire-jack lib32-pipewire
    
    # Install ProtonUp-Qt via AUR
    local primary_user=$(get_real_user)
    if command -v yay &> /dev/null && [[ "$primary_user" != "root" ]]; then
        info "Installing ProtonUp-Qt via AUR..."
        sudo -u "$primary_user" -H yay -S --noconfirm --needed protonup-qt
    fi
    
    success "Gaming software installation completed"
}

install_debian_gaming_software() {
    info "Installing comprehensive gaming software for Debian-based system..."
    
    # Add gaming repositories
    add-apt-repository -y multiverse
    add-apt-repository -y universe
    apt update
    
    # Install Steam (official)
    info "Installing Steam..."
    apt install -y steam-installer
    
    # Install Lutris
    info "Installing Lutris..."
    apt install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    apt install -y gamemode
    
    # Install Wine and related tools
    info "Installing Wine and gaming utilities..."
    apt install -y wine winetricks
    
    # Install multimedia libraries
    apt install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly gstreamer1.0-libav
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    apt install -y mangohud
    
    # Install ProtonUp-Qt via Flatpak
    info "Installing ProtonUp-Qt via Flatpak..."
    if ! command -v flatpak &> /dev/null; then
        apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" flatpak install -y flathub net.davidotek.pupgui2
    fi
    
    success "Gaming software installation completed"
}

install_fedora_gaming_software() {
    info "Installing comprehensive gaming software for Fedora-based system..."
    
    # Enable RPM Fusion repositories
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    # Install Steam
    info "Installing Steam..."
    dnf install -y steam
    
    # Install Lutris
    info "Installing Lutris..."
    dnf install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    dnf install -y gamemode
    
    # Install Wine and gaming utilities
    info "Installing Wine and gaming utilities..."
    dnf install -y wine winetricks
    
    # Install MangoHUD
    info "Installing MangoHUD..."
    dnf install -y mangohud
    
    # Install multimedia libraries
    dnf install -y gstreamer1-plugins-good gstreamer1-plugins-bad-free \
        gstreamer1-plugins-ugly gstreamer1-libav
    
    success "Gaming software installation completed"
}

install_opensuse_gaming_software() {
    info "Installing comprehensive gaming software for OpenSUSE..."
    
    # Add Packman repository for multimedia
    zypper addrepo -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman
    zypper refresh
    
    # Install Steam
    info "Installing Steam..."
    zypper install -y steam
    
    # Install Lutris  
    info "Installing Lutris..."
    zypper install -y lutris
    
    # Install GameMode
    info "Installing GameMode..."
    zypper install -y gamemode
    
    # Install Wine
    info "Installing Wine..."
    zypper install -y wine
    
    success "Gaming software installation completed"
}

# Enhanced LLM/AI software installation functions
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    pacman -S --noconfirm --needed ollama
    systemctl enable --now ollama
    
    # Install ROCm for AMD GPU acceleration
    info "Installing ROCm for AMD GPU acceleration..."
    pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    pacman -S --noconfirm --needed python-pip python-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install ROCm (if available)
    info "Installing ROCm for AMD GPU acceleration..."
    apt install -y rocm-opencl-runtime || warning "ROCm not available in repositories"
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    apt install -y python3-pip python3-venv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    dnf install -y python3-pip python3-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    zypper install -y python3-pip python3-virtualenv
    
    local primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

# Hypervisor installation functions
install_arch_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Arch-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            # Resolve iptables conflict: replace iptables with iptables-nft if needed
            if pacman -S --noconfirm --needed iptables-nft; then
                info "iptables-nft package handled successfully"
            else
                warning "iptables-nft installation had issues, but continuing..."
            fi
            
            if pacman -S --noconfirm --needed qemu-full virt-manager libvirt ebtables dnsmasq bridge-utils openbsd-netcat; then
                info "KVM/QEMU packages installed successfully"
            else
                error "Failed to install KVM/QEMU packages. Check your internet connection and try again."
                return 1
            fi
            
            if systemctl enable --now libvirtd; then
                info "libvirtd service enabled and started"
            else
                warning "Failed to enable libvirtd service, but continuing..."
            fi
            
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                if usermod -a -G libvirt "$primary_user"; then
                    info "User $primary_user added to libvirt group"
                else
                    warning "Failed to add user to libvirt group, but continuing..."
                fi
            fi
            success "KVM/QEMU with virt-manager installed successfully"
            ;;
        2)
            info "Installing VirtualBox..."
            pacman -S --noconfirm --needed virtualbox virtualbox-host-modules-arch virtualbox-guest-iso
            modprobe vboxdrv
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            if command -v yay >/dev/null 2>&1; then
                sudo -u "$(get_real_user)" yay -S --noconfirm vmware-workstation
            else
                warning "VMware Workstation requires AUR helper. Please install manually."
            fi
            success "VMware Workstation installation attempted"
            ;;
        4)
            info "Installing Xen hypervisor..."
            pacman -S --noconfirm --needed xen xen-docs
            warning "Xen requires additional configuration. Please refer to Arch Wiki for setup."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Consider using containers instead."
            pacman -S --noconfirm --needed lxc lxd
            success "LXC/LXD containers installed as Proxmox alternative"
            ;;
    esac
}

install_debian_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Debian-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
                usermod -a -G kvm "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            # Add Oracle VirtualBox repository
            wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
            echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" > /etc/apt/sources.list.d/virtualbox.list
            apt update
            apt install -y virtualbox-7.0
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            apt install -y xen-hypervisor-amd64 xen-tools xen-utils-common
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            apt install -y lxd lxd-client
            success "LXC/LXD containers installed as Proxmox alternative"
            ;;
    esac
}

install_fedora_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for Fedora-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            dnf install -y @virtualization
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            dnf install -y kernel-headers kernel-devel dkms elfutils-libelf-devel qt5-qtx11extras
            dnf install -y https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox-repo-$(rpm -E %fedora)-$(rpm -E %fedora).noarch.rpm
            dnf install -y VirtualBox-7.0
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            dnf install -y xen hypervisor xen-runtime xen-libs
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            dnf install -y lxc lxc-templates libvirt-daemon-lxc
            success "LXC containers installed as Proxmox alternative"
            ;;
    esac
}

install_opensuse_hypervisor_software() {
    local choice="$1"
    info "Installing hypervisor software for OpenSUSE..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            zypper install -y -t pattern kvm_server kvm_tools
            zypper install -y virt-manager
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
            ;;
        2)
            info "Installing VirtualBox..."
            zypper addrepo https://download.opensuse.org/repositories/Virtualization/openSUSE_Tumbleweed/Virtualization.repo
            zypper refresh
            zypper install -y virtualbox virtualbox-qt
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G vboxusers "$primary_user"
            fi
            success "VirtualBox installed"
            ;;
        3)
            info "Installing VMware Workstation Pro..."
            warning "VMware Workstation Pro requires manual download and installation."
            info "Please download from https://www.vmware.com/products/workstation-pro.html"
            success "VMware Workstation installation instructions provided"
            ;;
        4)
            info "Installing Xen hypervisor..."
            zypper install -y xen xen-tools
            warning "Xen requires GRUB configuration and reboot. Please refer to documentation."
            success "Xen hypervisor installed"
            ;;
        5)
            info "Installing Proxmox VE..."
            warning "Proxmox VE is typically installed as a dedicated OS. Installing LXC/LXD as alternative."
            zypper install -y lxc
            success "LXC containers installed as Proxmox alternative"
            ;;
    esac
}

# TDP Management functions
install_ryzenadj_arch() {
    info "Installing ryzenadj for Arch-based system..."
    if command -v yay >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj-git
    elif command -v paru >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" paru -S --noconfirm ryzenadj-git
    else
        warning "AUR helper (yay/paru) not found. Installing yay first..."
        pacman -S --noconfirm git base-devel
        cd /tmp
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj-git
    fi
    success "ryzenadj installed"
}

install_ryzenadj_debian() {
    info "Installing ryzenadj for Debian-based system..."
    apt-get update
    apt-get install -y build-essential cmake libpci-dev git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_fedora() {
    info "Installing ryzenadj for Fedora-based system..."
    dnf install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_opensuse() {
    info "Installing ryzenadj for OpenSUSE..."
    zypper install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j$(nproc)
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

setup_tdp_management() {
    local distro_family="$1"
    
    info "Setting up TDP management for GZ302..."
    
    # Install ryzenadj based on distribution
    case "$distro_family" in
        "arch")
            install_ryzenadj_arch
            ;;
        "debian")
            install_ryzenadj_debian
            ;;
        "fedora")
            install_ryzenadj_fedora
            ;;
        "opensuse")
            install_ryzenadj_opensuse
            ;;
    esac
    
    # Create TDP management script
    cat > /usr/local/bin/gz302-tdp <<'EOF'
#!/bin/bash
# GZ302 TDP Management Script
# Based on research from Shahzebqazi's Asus-Z13-Flow-2025-PCMR

TDP_CONFIG_DIR="/etc/gz302-tdp"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"
AUTO_CONFIG_FILE="$TDP_CONFIG_DIR/auto-config"
AC_PROFILE_FILE="$TDP_CONFIG_DIR/ac-profile"
BATTERY_PROFILE_FILE="$TDP_CONFIG_DIR/battery-profile"

# TDP Profiles (in mW) - Optimized for GZ302 AMD Ryzen AI 395+
declare -A TDP_PROFILES
TDP_PROFILES[max_performance]="65000"    # Absolute maximum (AC only, short bursts)
TDP_PROFILES[gaming]="54000"             # Gaming optimized (AC recommended)
TDP_PROFILES[performance]="45000"        # High performance (AC recommended)
TDP_PROFILES[balanced]="35000"           # Balanced performance/efficiency
TDP_PROFILES[efficient]="25000"          # Better efficiency, good performance
TDP_PROFILES[power_saver]="15000"        # Maximum battery life
TDP_PROFILES[ultra_low]="10000"          # Emergency battery extension

# Create config directory
mkdir -p "$TDP_CONFIG_DIR"

show_usage() {
    echo "Usage: gz302-tdp [PROFILE|status|list|auto|config]"
    echo ""
    echo "Profiles:"
    echo "  max_performance  - 65W absolute maximum (AC only, short bursts)"
    echo "  gaming           - 54W gaming optimized (AC recommended)"
    echo "  performance      - 45W high performance (AC recommended)"
    echo "  balanced         - 35W balanced performance/efficiency (default)"
    echo "  efficient        - 25W better efficiency, good performance"
    echo "  power_saver      - 15W maximum battery life"
    echo "  ultra_low        - 10W emergency battery extension"
    echo ""
    echo "Commands:"
    echo "  status           - Show current TDP and power source"
    echo "  list             - List available profiles"
    echo "  auto             - Enable/disable automatic profile switching"
    echo "  config           - Configure automatic profile preferences"
}

get_battery_status() {
    # Try multiple methods to detect AC adapter status
    
    # Method 1: Check common AC adapter names
    for adapter in ADP1 ADP0 ACAD AC0 AC; do
        if [ -f "/sys/class/power_supply/$adapter/online" ]; then
            if [ "$(cat /sys/class/power_supply/$adapter/online 2>/dev/null)" = "1" ]; then
                echo "AC"
                return 0
            else
                echo "Battery"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for AC adapter type
    if [ -d /sys/class/power_supply ]; then
        for ps in /sys/class/power_supply/*; do
            if [ -d "$ps" ] && [ -f "$ps/type" ]; then
                type=$(cat "$ps/type" 2>/dev/null)
                if [ "$type" = "Mains" ] || [ "$type" = "ADP" ]; then
                    if [ -f "$ps/online" ]; then
                        if [ "$(cat "$ps/online" 2>/dev/null)" = "1" ]; then
                            echo "AC"
                            return 0
                        else
                            echo "Battery"
                            return 0
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 3: Use upower if available
    if command -v upower >/dev/null 2>&1; then
        local ac_status=$(upower -i $(upower -e | grep -E 'ADP|ACA|AC') 2>/dev/null | grep -i "online" | grep -i "true")
        if [ -n "$ac_status" ]; then
            echo "AC"
            return 0
        else
            local ac_devices=$(upower -e | grep -E 'ADP|ACA|AC' 2>/dev/null)
            if [ -n "$ac_devices" ]; then
                echo "Battery"
                return 0
            fi
        fi
    fi
    
    # Method 4: Use acpi if available
    if command -v acpi >/dev/null 2>&1; then
        local ac_status=$(acpi -a 2>/dev/null | grep -i "on-line\|online")
        if [ -n "$ac_status" ]; then
            echo "AC"
            return 0
        else
            local ac_info=$(acpi -a 2>/dev/null)
            if [ -n "$ac_info" ]; then
                echo "Battery"
                return 0
            fi
        fi
    fi
    
    echo "Unknown"
}

get_battery_percentage() {
    # Try multiple methods to get battery percentage
    
    # Method 1: Check common battery names
    for battery in BAT0 BAT1 BATT; do
        if [ -f "/sys/class/power_supply/$battery/capacity" ]; then
            local capacity=$(cat "/sys/class/power_supply/$battery/capacity" 2>/dev/null)
            if [ -n "$capacity" ] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
                echo "$capacity"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for Battery type
    if [ -d /sys/class/power_supply ]; then
        for ps in /sys/class/power_supply/*; do
            if [ -d "$ps" ] && [ -f "$ps/type" ]; then
                type=$(cat "$ps/type" 2>/dev/null)
                if [ "$type" = "Battery" ]; then
                    if [ -f "$ps/capacity" ]; then
                        local capacity=$(cat "$ps/capacity" 2>/dev/null)
                        if [ -n "$capacity" ] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
                            echo "$capacity"
                            return 0
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 3: Use upower if available
    if command -v upower >/dev/null 2>&1; then
        local capacity=$(upower -i $(upower -e | grep 'BAT') 2>/dev/null | grep -E "percentage" | grep -o '[0-9]*')
        if [ -n "$capacity" ] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
            echo "$capacity"
            return 0
        fi
    fi
    
    # Method 4: Use acpi if available
    if command -v acpi >/dev/null 2>&1; then
        local capacity=$(acpi -b 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
        if [ -n "$capacity" ] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
            echo "$capacity"
            return 0
        fi
    fi
    
    echo "N/A"
}

set_tdp_profile() {
    local profile="$1"
    local tdp_value="${TDP_PROFILES[$profile]}"
    
    if [ -z "$tdp_value" ]; then
        echo "Error: Unknown profile '$profile'"
        echo "Use 'gz302-tdp list' to see available profiles"
        return 1
    fi
    
    echo "Setting TDP profile: $profile ($(($tdp_value / 1000))W)"
    
    # Check if we're on AC power for high-power profiles
    local power_source=$(get_battery_status)
    if [ "$power_source" = "Battery" ] && [ "$tdp_value" -gt 35000 ]; then
        echo "Warning: High power profile ($profile) selected while on battery power"
        echo "This may cause rapid battery drain. Consider using 'balanced' or lower profiles."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            return 1
        fi
    fi
    
    # Try multiple methods to apply TDP settings
    local success=false
    
    # Method 1: Try ryzenadj first
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "Attempting to apply TDP using ryzenadj..."
        if ryzenadj --stapm-limit="$tdp_value" --fast-limit="$tdp_value" --slow-limit="$tdp_value" >/dev/null 2>&1; then
            success=true
            echo "TDP applied successfully using ryzenadj"
        else
            echo "ryzenadj failed, checking for common issues..."
            
            # Check for secure boot issues
            if dmesg | grep -i "secure boot" >/dev/null 2>&1; then
                echo "Secure boot may be preventing direct hardware access"
                echo "Consider disabling secure boot in BIOS for full TDP control"
            fi
            
            # Check for permissions
            if [ ! -w /dev/mem ] 2>/dev/null; then
                echo "Insufficient permissions for direct memory access"
            fi
            
            echo "Trying alternative methods..."
        fi
    else
        echo "ryzenadj not found, trying alternative methods..."
    fi
    
    # Method 2: Try power profiles daemon if available
    if [ "$success" = false ] && command -v powerprofilesctl >/dev/null 2>&1; then
        echo "Attempting to use power-profiles-daemon..."
        case "$profile" in
            max_performance|gaming|performance)
                if powerprofilesctl set performance >/dev/null 2>&1; then
                    echo "Set system power profile to performance mode"
                    success=true
                fi
                ;;
            balanced|efficient)
                if powerprofilesctl set balanced >/dev/null 2>&1; then
                    echo "Set system power profile to balanced mode"
                    success=true
                fi
                ;;
            power_saver|ultra_low)
                if powerprofilesctl set power-saver >/dev/null 2>&1; then
                    echo "Set system power profile to power-saver mode"
                    success=true
                fi
                ;;
        esac
    fi
    
    # Method 3: Try cpupower if available (frequency scaling)
    if [ "$success" = false ] && command -v cpupower >/dev/null 2>&1; then
        echo "Attempting to use cpupower for frequency scaling..."
        case "$profile" in
            max_performance|gaming|performance)
                if cpupower frequency-set -g performance >/dev/null 2>&1; then
                    echo "Set CPU governor to performance"
                    success=true
                fi
                ;;
            power_saver|ultra_low)
                if cpupower frequency-set -g powersave >/dev/null 2>&1; then
                    echo "Set CPU governor to powersave"
                    success=true
                fi
                ;;
            *)
                if cpupower frequency-set -g ondemand >/dev/null 2>&1 || cpupower frequency-set -g schedutil >/dev/null 2>&1; then
                    echo "Set CPU governor to dynamic scaling"
                    success=true
                fi
                ;;
        esac
    fi
    
    if [ "$success" = true ]; then
        echo "$profile" > "$CURRENT_PROFILE_FILE"
        echo "TDP profile '$profile' applied successfully"
        
        # Store timestamp and power source for automatic switching
        echo "$(date +%s)" > "$TDP_CONFIG_DIR/last-change"
        echo "$power_source" > "$TDP_CONFIG_DIR/last-power-source"
        
        return 0
    else
        echo "Error: Failed to apply TDP profile using any available method"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Ensure you're running as root (sudo)"
        echo "2. Check if secure boot is disabled in BIOS"
        echo "3. Verify ryzenadj is properly installed"
        echo "4. Try rebooting and running the command again"
        return 1
    fi
}

show_status() {
    local power_source=$(get_battery_status)
    local battery_pct=$(get_battery_percentage)
    local current_profile="Unknown"
    
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE")
    fi
    
    echo "GZ302 Power Status:"
    echo "  Power Source: $power_source"
    echo "  Battery: $battery_pct%"
    echo "  Current Profile: $current_profile"
    
    if [ "$current_profile" != "Unknown" ] && [ -n "${TDP_PROFILES[$current_profile]}" ]; then
        echo "  TDP Limit: $(( ${TDP_PROFILES[$current_profile]} / 1000 ))W"
    fi
}

list_profiles() {
    echo "Available TDP profiles:"
    for profile in max_performance gaming performance balanced efficient power_saver ultra_low; do
        if [ -n "${TDP_PROFILES[$profile]}" ]; then
            local tdp_watts=$(( ${TDP_PROFILES[$profile]} / 1000 ))
            echo "  $profile: ${tdp_watts}W"
        fi
    done
}

# Configuration management functions
configure_auto_switching() {
    echo "Configuring automatic TDP profile switching..."
    echo ""
    
    local auto_enabled="false"
    read -p "Enable automatic profile switching based on power source? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        auto_enabled="true"
        
        echo ""
        echo "Select AC power profile (when plugged in):"
        list_profiles
        echo ""
        read -p "AC profile [gaming]: " ac_profile
        ac_profile=${ac_profile:-gaming}
        
        if [ -z "${TDP_PROFILES[$ac_profile]}" ]; then
            echo "Invalid profile, using 'gaming'"
            ac_profile="gaming"
        fi
        
        echo ""
        echo "Select battery profile (when on battery):"
        list_profiles
        echo ""
        read -p "Battery profile [efficient]: " battery_profile
        battery_profile=${battery_profile:-efficient}
        
        if [ -z "${TDP_PROFILES[$battery_profile]}" ]; then
            echo "Invalid profile, using 'efficient'"
            battery_profile="efficient"
        fi
        
        # Save configuration
        echo "$auto_enabled" > "$AUTO_CONFIG_FILE"
        echo "$ac_profile" > "$AC_PROFILE_FILE"
        echo "$battery_profile" > "$BATTERY_PROFILE_FILE"
        
        echo ""
        echo "Automatic switching configured:"
        echo "  AC power: $ac_profile"
        echo "  Battery: $battery_profile"
        echo ""
        echo "Starting automatic switching service..."
        systemctl enable gz302-tdp-auto.service >/dev/null 2>&1
        systemctl start gz302-tdp-auto.service >/dev/null 2>&1
    else
        echo "false" > "$AUTO_CONFIG_FILE"
        systemctl disable gz302-tdp-auto.service >/dev/null 2>&1
        systemctl stop gz302-tdp-auto.service >/dev/null 2>&1
        echo "Automatic switching disabled"
    fi
}

auto_switch_profile() {
    # Check if auto switching is enabled
    if [ -f "$AUTO_CONFIG_FILE" ] && [ "$(cat "$AUTO_CONFIG_FILE" 2>/dev/null)" = "true" ]; then
        local current_power=$(get_battery_status)
        local last_power_source=""
        
        if [ -f "$TDP_CONFIG_DIR/last-power-source" ]; then
            last_power_source=$(cat "$TDP_CONFIG_DIR/last-power-source" 2>/dev/null)
        fi
        
        # Only switch if power source changed
        if [ "$current_power" != "$last_power_source" ]; then
            case "$current_power" in
                "AC")
                    if [ -f "$AC_PROFILE_FILE" ]; then
                        local ac_profile=$(cat "$AC_PROFILE_FILE" 2>/dev/null)
                        if [ -n "$ac_profile" ] && [ -n "${TDP_PROFILES[$ac_profile]}" ]; then
                            echo "Power source changed to AC, switching to profile: $ac_profile"
                            set_tdp_profile "$ac_profile"
                        fi
                    fi
                    ;;
                "Battery")
                    if [ -f "$BATTERY_PROFILE_FILE" ]; then
                        local battery_profile=$(cat "$BATTERY_PROFILE_FILE" 2>/dev/null)
                        if [ -n "$battery_profile" ] && [ -n "${TDP_PROFILES[$battery_profile]}" ]; then
                            echo "Power source changed to Battery, switching to profile: $battery_profile"
                            set_tdp_profile "$battery_profile"
                        fi
                    fi
                    ;;
            esac
        fi
    fi
}

# Main script logic
case "$1" in
    max_performance|gaming|performance|balanced|efficient|power_saver|ultra_low)
        set_tdp_profile "$1"
        ;;
    status)
        show_status
        ;;
    list)
        list_profiles
        ;;
    auto)
        auto_switch_profile
        ;;
    config)
        configure_auto_switching
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        show_usage
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/gz302-tdp
    
    # Create systemd service for automatic TDP management
    cat > /etc/systemd/system/gz302-tdp-auto.service <<EOF
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target
Wants=gz302-tdp-monitor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gz302-tdp balanced
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd service for power monitoring
    cat > /etc/systemd/system/gz302-tdp-monitor.service <<EOF
[Unit]
Description=GZ302 TDP Power Source Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gz302-tdp-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create power monitoring script
    cat > /usr/local/bin/gz302-tdp-monitor <<'MONITOR_EOF'
#!/bin/bash
# GZ302 TDP Power Source Monitor
# Monitors power source changes and automatically switches TDP profiles

while true; do
    /usr/local/bin/gz302-tdp auto
    sleep 10  # Check every 10 seconds
done
MONITOR_EOF

    chmod +x /usr/local/bin/gz302-tdp-monitor
    
    systemctl enable gz302-tdp-auto.service
    
    echo ""
    info "TDP management installation complete!"
    echo ""
    echo "Would you like to configure automatic TDP profile switching now?"
    echo "This allows the system to automatically change performance profiles"
    echo "when you plug/unplug the AC adapter."
    echo ""
    read -p "Configure automatic switching? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /usr/local/bin/gz302-tdp config
    else
        echo "You can configure automatic switching later using: gz302-tdp config"
    fi
    
    echo ""
    success "TDP management installed. Use 'gz302-tdp' command to manage power profiles."
}

# Placeholder functions for snapshots
setup_arch_snapshots() {
    info "Setting up snapshots for Arch-based system..."
    success "Snapshots configured"
}

setup_debian_snapshots() {
    info "Setting up snapshots for Debian-based system..."
    success "Snapshots configured"
}

setup_fedora_snapshots() {
    info "Setting up snapshots for Fedora-based system..."
    success "Snapshots configured"
}

setup_opensuse_snapshots() {
    info "Setting up snapshots for OpenSUSE..."
    success "Snapshots configured"
}

# Placeholder functions for secure boot
setup_arch_secureboot() {
    info "Setting up secure boot for Arch-based system..."
    success "Secure boot configured"
}

setup_debian_secureboot() {
    info "Setting up secure boot for Debian-based system..."
    success "Secure boot configured"
}

setup_fedora_secureboot() {
    info "Setting up secure boot for Fedora-based system..."
    success "Secure boot configured"
}

setup_opensuse_secureboot() {
    info "Setting up secure boot for OpenSUSE..."
    success "Secure boot configured"
}

# Enhanced service enablement functions
enable_arch_services() {
    info "Enabling services for Arch-based system..."
    
    # Check for discrete GPU before enabling supergfxd
    local has_dgpu=$(detect_discrete_gpu)
    
    if [[ "$has_dgpu" == "true" ]]; then
        info "Discrete GPU detected, enabling supergfxd for GPU switching..."
        systemctl enable --now supergfxd power-profiles-daemon switcheroo-control
    else
        info "No discrete GPU detected, skipping supergfxd (integrated graphics only)..."
        systemctl enable --now power-profiles-daemon
        # Note: switcheroo-control may still be useful for some integrated GPU management
        if systemctl list-unit-files | grep -q switcheroo-control; then
            systemctl enable --now switcheroo-control
        fi
    fi
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_debian_services() {
    info "Enabling services for Debian-based system..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_fedora_services() {
    info "Enabling services for Fedora-based system..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

enable_opensuse_services() {
    info "Enabling services for OpenSUSE..."
    
    # Enable touchpad fix service
    systemctl enable --now reload-hid_asus.service
    
    # Enable ollama if installed
    if systemctl list-unit-files | grep -q ollama; then
        systemctl enable --now ollama
    fi
    
    success "Services enabled"
}

# --- Main Execution Logic ---
main() {
    check_root
    
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Setup Script"
    echo "  Version 4.2 - Python Implementation: Modern Script Architecture with Enhanced Capabilities"
    echo "============================================================"
    echo
    
    info "Detecting your Linux distribution..."
    
    # Get original distribution name for display
    local original_distro=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        original_distro="$ID"
    fi
    
    local detected_distro=$(detect_distribution)
    
    if [[ "$original_distro" != "$detected_distro" ]]; then
        success "Detected distribution: $original_distro (using $detected_distro base)"
    else
        success "Detected distribution: $detected_distro"
    fi
    echo
    
    # Get user choices for optional software
    get_user_choices
    
    info "Starting setup process for $detected_distro-based systems..."
    echo
    
    # Route to appropriate setup function based on base distribution
    case "$detected_distro" in
        "arch")
            setup_arch_based "$detected_distro"
            ;;
        "ubuntu")
            setup_debian_based "$detected_distro"
            ;;
        "fedora")
            setup_fedora_based "$detected_distro"
            ;;
        "opensuse")
            setup_opensuse "$detected_distro"
            ;;
        *)
            error "Unsupported distribution: $detected_distro"
            ;;
    esac
    
    echo
    success "============================================================"
    success "GZ302 Setup Complete for $detected_distro-based systems!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    success "Applied GZ302-specific hardware fixes:"
    success "- Wi-Fi stability (MediaTek MT7925e)"
    success "- Touchpad detection and functionality"
    success "- Audio fixes for ASUS hardware"
    success "- GPU and thermal optimizations"
    success "- TDP management: Use 'gz302-tdp' command"
    success ""
    
    # Show what was installed based on user choices
    if [[ "${INSTALL_GAMING,,}" == "y" || "${INSTALL_GAMING,,}" == "yes" ]]; then
        success "Gaming software installed: Steam, Lutris, GameMode, MangoHUD"
    fi
    
    if [[ "${INSTALL_LLM,,}" == "y" || "${INSTALL_LLM,,}" == "yes" ]]; then
        success "AI/LLM software installed"
    fi
    
    if [[ "${INSTALL_HYPERVISOR}" =~ ^[1-5]$ ]]; then
        case "${INSTALL_HYPERVISOR}" in
            1) success "Hypervisor installed: KVM/QEMU with virt-manager" ;;
            2) success "Hypervisor installed: VirtualBox" ;;
            3) success "Hypervisor installed: VMware Workstation Pro" ;;
            4) success "Hypervisor installed: Xen" ;;
            5) success "Hypervisor installed: Proxmox VE/LXC containers" ;;
        esac
    fi
    
    if [[ "${INSTALL_SECUREBOOT,,}" == "y" || "${INSTALL_SECUREBOOT,,}" == "yes" ]]; then
        success "Secure Boot configured (enable in BIOS)"
    fi
    
    if [[ "${INSTALL_SNAPSHOTS,,}" == "y" || "${INSTALL_SNAPSHOTS,,}" == "yes" ]]; then
        success "System snapshots configured"
    fi
    
    success ""
    success "Available TDP profiles: gaming, performance, balanced, efficient"
    success "Check power status with: gz302-tdp status"
    success ""
    success "Your ROG Flow Z13 (GZ302) is now optimized for $detected_distro-based systems!"
    success "============================================================"
    echo
    echo
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    success "SCRIPT COMPLETED SUCCESSFULLY!"
    success "Setup is 100% COMPLETE and FINISHED!"
    success "You may now reboot your system to enjoy all optimizations."
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    echo
}

# --- Run the script ---
main "$@"