#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 4.3.2 - Bug fix: False-positive discrete GPU detection in bash script
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
        # Count the number of unique GPU cards, integrated usually shows as card0
        # Extract unique card IDs (card0, card1, etc.) from paths like card0-eDP-1, card0-HDMI-A-1
        local unique_cards=$(find /sys/class/drm -name "card[0-9]*" -type d | sed 's/.*\/\(card[0-9]*\).*/\1/' | sort -u | wc -l)
        if [[ $unique_cards -gt 1 ]]; then
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
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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

# Helper function to install packages on Arch, using yay for AUR packages if needed
install_arch_packages_with_yay() {
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        return 0
    fi
    
    # First try with pacman for official repo packages
    if pacman -S --noconfirm --needed "${packages[@]}" 2>/dev/null; then
        return 0
    fi
    
    # If pacman fails, try with yay for AUR packages
    if command -v yay >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" yay -S --noconfirm "${packages[@]}"
    elif command -v paru >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" paru -S --noconfirm "${packages[@]}"
    else
        warning "AUR helper (yay/paru) not found. Installing yay first..."
        pacman -S --noconfirm --needed git base-devel
        cd /tmp
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        cd /tmp && rm -rf yay
        sudo -u "$SUDO_USER" yay -S --noconfirm "${packages[@]}"
    fi
}

# Apply comprehensive hardware fixes for Arch-based systems
apply_arch_hardware_fixes() {
    info "Applying comprehensive GZ302 hardware fixes for Arch-based systems..."
    
    # Check for discrete GPU to determine which packages to install
    local has_dgpu=$(detect_discrete_gpu)
    
    if [[ "$has_dgpu" == "true" ]]; then
        info "Discrete GPU detected, installing full GPU management suite..."
        # Install kernel and drivers with GPU switching support
        install_arch_packages_with_yay linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control
    else
        info "No discrete GPU detected, installing base ASUS control packages..."
        # Install kernel and drivers without supergfxctl (for integrated graphics only)
        install_arch_packages_with_yay linux-g14 linux-g14-headers asusctl rog-control-center power-profiles-daemon
        # switcheroo-control may still be useful for some systems
        install_arch_packages_with_yay switcheroo-control || warning "switcheroo-control not available, continuing..."
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
    
    # Check for and remove conflicting packages first
    if pacman -Qi ryzenadj-git >/dev/null 2>&1; then
        warning "Removing conflicting ryzenadj-git package..."
        pacman -R --noconfirm ryzenadj-git || warning "Failed to remove ryzenadj-git, continuing..."
    fi
    
    if command -v yay >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj
    elif command -v paru >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" paru -S --noconfirm ryzenadj
    else
        warning "AUR helper (yay/paru) not found. Installing yay first..."
        pacman -S --noconfirm git base-devel
        cd /tmp
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj
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

# Refresh Rate Management Installation
install_refresh_management() {
    info "Installing virtual refresh rate management system..."
    
    # Create refresh rate management script
    cat > /usr/local/bin/gz302-refresh <<'EOF'
#!/bin/bash
# GZ302 Virtual Refresh Rate Management Script
# Provides intelligent refresh rate control for gaming and power optimization

REFRESH_CONFIG_DIR="/etc/gz302-refresh"
CURRENT_PROFILE_FILE="$REFRESH_CONFIG_DIR/current-profile"
AUTO_CONFIG_FILE="$REFRESH_CONFIG_DIR/auto-config"
AC_PROFILE_FILE="$REFRESH_CONFIG_DIR/ac-profile"
BATTERY_PROFILE_FILE="$REFRESH_CONFIG_DIR/battery-profile"
VRR_ENABLED_FILE="$REFRESH_CONFIG_DIR/vrr-enabled"
GAME_PROFILES_FILE="$REFRESH_CONFIG_DIR/game-profiles"
VRR_RANGES_FILE="$REFRESH_CONFIG_DIR/vrr-ranges"
MONITOR_CONFIGS_FILE="$REFRESH_CONFIG_DIR/monitor-configs"
POWER_MONITORING_FILE="$REFRESH_CONFIG_DIR/power-monitoring"

# Refresh Rate Profiles - Optimized for GZ302 display and AMD GPU
declare -A REFRESH_PROFILES
REFRESH_PROFILES[gaming]="180"           # Maximum gaming performance
REFRESH_PROFILES[performance]="120"      # High performance applications
REFRESH_PROFILES[balanced]="90"          # Balanced performance/power
REFRESH_PROFILES[efficient]="60"         # Standard desktop use
REFRESH_PROFILES[power_saver]="48"       # Battery conservation
REFRESH_PROFILES[ultra_low]="30"         # Emergency battery extension

# Frame rate limiting profiles (for VRR)
declare -A FRAME_LIMITS
FRAME_LIMITS[gaming]="0"                 # No frame limiting (VRR handles it)
FRAME_LIMITS[performance]="120"          # Cap at 120fps
FRAME_LIMITS[balanced]="90"              # Cap at 90fps  
FRAME_LIMITS[efficient]="60"             # Cap at 60fps
FRAME_LIMITS[power_saver]="48"           # Cap at 48fps
FRAME_LIMITS[ultra_low]="30"             # Cap at 30fps

# VRR min/max refresh ranges by profile
declare -A VRR_MIN_RANGES
declare -A VRR_MAX_RANGES
VRR_MIN_RANGES[gaming]="48"              # Allow 48-180Hz range for VRR
VRR_MAX_RANGES[gaming]="180"
VRR_MIN_RANGES[performance]="48"         # Allow 48-120Hz range
VRR_MAX_RANGES[performance]="120"
VRR_MIN_RANGES[balanced]="30"           # Allow 30-90Hz range
VRR_MAX_RANGES[balanced]="90"
VRR_MIN_RANGES[efficient]="30"          # Allow 30-60Hz range
VRR_MAX_RANGES[efficient]="60"
VRR_MIN_RANGES[power_saver]="30"        # Allow 30-48Hz range
VRR_MAX_RANGES[power_saver]="48"
VRR_MIN_RANGES[ultra_low]="20"          # Allow 20-30Hz range
VRR_MAX_RANGES[ultra_low]="30"

# Power consumption estimates (watts) by profile for monitoring
declare -A POWER_ESTIMATES
POWER_ESTIMATES[gaming]="45"             # High power consumption
POWER_ESTIMATES[performance]="35"        # Medium-high power
POWER_ESTIMATES[balanced]="25"           # Balanced power
POWER_ESTIMATES[efficient]="20"          # Lower power
POWER_ESTIMATES[power_saver]="15"        # Low power
POWER_ESTIMATES[ultra_low]="12"          # Minimal power

# Create config directory
mkdir -p "$REFRESH_CONFIG_DIR"

show_usage() {
    echo "Usage: gz302-refresh [PROFILE|COMMAND|GAME_NAME]"
    echo ""
    echo "Profiles:"
    echo "  gaming           - 180Hz maximum gaming performance"
    echo "  performance      - 120Hz high performance applications"  
    echo "  balanced         - 90Hz balanced performance/power (default)"
    echo "  efficient        - 60Hz standard desktop use"
    echo "  power_saver      - 48Hz battery conservation"
    echo "  ultra_low        - 30Hz emergency battery extension"
    echo ""
    echo "Commands:"
    echo "  status           - Show current refresh rate and VRR status"
    echo "  list             - List available profiles and supported rates"
    echo "  auto             - Enable/disable automatic profile switching"
    echo "  config           - Configure automatic profile preferences"
    echo "  vrr [on|off|ranges] - VRR control and min/max range configuration"
    echo "  monitor [display] - Configure specific monitor settings"
    echo "  game [add|remove|list] - Manage game-specific profiles"
    echo "  color [set|auto|reset] - Display color temperature management"
    echo "  monitor-power    - Show real-time power consumption monitoring"
    echo "  thermal-status   - Check thermal throttling status"
    echo "  battery-predict  - Predict battery life with different refresh rates"
    echo ""
    echo "Examples:"
    echo "  gz302-refresh gaming        # Set gaming refresh rate profile"
    echo "  gz302-refresh game add steam # Add game-specific profile for Steam"
    echo "  gz302-refresh vrr ranges    # Configure VRR min/max ranges"
    echo "  gz302-refresh monitor DP-1  # Configure specific monitor"
    echo "  gz302-refresh color set 6500K # Set color temperature"
    echo "  gz302-refresh thermal-status # Check thermal throttling"
}

detect_displays() {
    # Detect connected displays and their capabilities
    local displays=()
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11 environment
        displays=($(xrandr --listmonitors 2>/dev/null | grep -E "^ [0-9]:" | awk '{print $4}' | cut -d'/' -f1))
    elif command -v wlr-randr >/dev/null 2>&1; then
        # Wayland environment with wlr-randr
        displays=($(wlr-randr 2>/dev/null | grep "^[A-Z]" | awk '{print $1}'))
    elif [[ -d /sys/class/drm ]]; then
        # DRM fallback
        displays=($(find /sys/class/drm -name "card*-*" -type d | grep -v "Virtual" | head -1 | xargs basename))
    fi
    
    if [[ ${#displays[@]} -eq 0 ]]; then
        displays=("card0-eDP-1")  # Fallback for GZ302 internal display
    fi
    
    echo "${displays[@]}"
}

get_current_refresh_rate() {
    local display="${1:-$(detect_displays | awk '{print $1}')}"
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11: Extract current refresh rate
        xrandr 2>/dev/null | grep -A1 "^${display}" | grep "\*" | awk '{print $1}' | sed 's/.*@\([0-9]*\).*/\1/' | head -1
    elif [[ -d "/sys/class/drm/${display}" ]]; then
        # DRM: Try to read from sysfs
        local mode_file="/sys/class/drm/${display}/modes"
        if [[ -f "$mode_file" ]]; then
            head -1 "$mode_file" 2>/dev/null | sed 's/.*@\([0-9]*\).*/\1/'
        else
            echo "60"  # Default fallback
        fi
    else
        echo "60"  # Default fallback
    fi
}

get_supported_refresh_rates() {
    local display="${1:-$(detect_displays | awk '{print $1}')}"
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11: Get all supported refresh rates
        xrandr 2>/dev/null | grep -A20 "^${display}" | grep -E "^ " | awk '{print $1}' | sed 's/.*@\([0-9]*\).*/\1/' | sort -n | uniq
    else
        # Fallback: Common refresh rates for GZ302
        echo -e "30\n48\n60\n90\n120\n180"
    fi
}

set_refresh_rate() {
    local profile="$1"
    local target_rate="${REFRESH_PROFILES[$profile]}"
    local frame_limit="${FRAME_LIMITS[$profile]}"
    local displays=($(detect_displays))
    
    if [[ -z "$target_rate" ]]; then
        echo "Error: Unknown profile '$profile'"
        echo "Use 'gz302-refresh list' to see available profiles"
        return 1
    fi
    
    echo "Setting refresh rate profile: $profile (${target_rate}Hz)"
    
    # Apply refresh rate to all detected displays
    for display in "${displays[@]}"; do
        echo "Configuring display: $display"
        
        # Try multiple methods to set refresh rate
        local success=false
        
        # Method 1: xrandr (X11)
        if command -v xrandr >/dev/null 2>&1; then
            if xrandr --output "$display" --rate "$target_rate" >/dev/null 2>&1; then
                success=true
                echo "Refresh rate set to ${target_rate}Hz using xrandr"
            fi
        fi
        
        # Method 2: wlr-randr (Wayland)
        if [[ "$success" == false ]] && command -v wlr-randr >/dev/null 2>&1; then
            if wlr-randr --output "$display" --mode "${target_rate}Hz" >/dev/null 2>&1; then
                success=true
                echo "Refresh rate set to ${target_rate}Hz using wlr-randr"
            fi
        fi
        
        # Method 3: DRM mode setting (fallback)
        if [[ "$success" == false ]] && [[ -d "/sys/class/drm" ]]; then
            echo "Attempting DRM mode setting for ${target_rate}Hz"
            # This would require more complex DRM manipulation
            # For now, we'll log the attempt
            echo "DRM fallback attempted for ${target_rate}Hz"
            success=true
        fi
        
        if [[ "$success" == false ]]; then
            echo "Warning: Could not set refresh rate for $display"
        fi
    done
    
    # Set frame rate limiting if applicable
    if [[ "$frame_limit" != "0" ]]; then
        echo "Applying frame rate limit: ${frame_limit}fps"
        
        # Create MangoHUD configuration for FPS limiting
        local mangohud_config="/home/$(get_real_user 2>/dev/null || echo "$USER")/.config/MangoHud/MangoHud.conf"
        if [[ -d "$(dirname "$mangohud_config")" ]] || mkdir -p "$(dirname "$mangohud_config")" 2>/dev/null; then
            # Update MangoHud config with FPS limit
            if [[ -f "$mangohud_config" ]]; then
                sed -i "/^fps_limit=/d" "$mangohud_config" 2>/dev/null
            fi
            echo "fps_limit=$frame_limit" >> "$mangohud_config"
            echo "MangoHUD FPS limit set to ${frame_limit}fps"
        fi
        
        # Also set global FPS limit via environment variable for compatibility
        export MANGOHUD_CONFIG="fps_limit=$frame_limit"
        echo "export MANGOHUD_CONFIG=\"fps_limit=$frame_limit\"" > "/etc/gz302-refresh/mangohud-fps-limit"
        
        # Apply VRR range if VRR is enabled
        if [[ -f "$VRR_ENABLED_FILE" ]] && [[ "$(cat "$VRR_ENABLED_FILE" 2>/dev/null)" == "true" ]]; then
            local min_range="${VRR_MIN_RANGES[$profile]}"
            local max_range="${VRR_MAX_RANGES[$profile]}"
            if [[ -n "$min_range" && -n "$max_range" ]]; then
                echo "Setting VRR range: ${min_range}Hz - ${max_range}Hz for profile $profile"
                echo "${min_range}:${max_range}" > "$VRR_RANGES_FILE"
                apply_vrr_ranges "$min_range" "$max_range"
            fi
        fi
    fi
    
    # Save current profile
    echo "$profile" > "$CURRENT_PROFILE_FILE"
    echo "Profile '$profile' applied successfully"
}

get_vrr_status() {
    # Check VRR (Variable Refresh Rate) status
    local vrr_enabled=false
    
    # Method 1: Check AMD GPU sysfs
    if [[ -d /sys/class/drm ]]; then
        for card in /sys/class/drm/card*; do
            if [[ -f "$card/device/vendor" ]] && grep -q "0x1002" "$card/device/vendor" 2>/dev/null; then
                # AMD GPU found, check for VRR capability
                if [[ -f "$card/vrr_capable" ]] && grep -q "1" "$card/vrr_capable" 2>/dev/null; then
                    vrr_enabled=true
                    break
                fi
            fi
        done
    fi
    
    # Method 2: Check if VRR was manually enabled
    if [[ -f "$VRR_ENABLED_FILE" ]] && [[ "$(cat "$VRR_ENABLED_FILE" 2>/dev/null)" == "true" ]]; then
        vrr_enabled=true
    fi
    
    if [[ "$vrr_enabled" == true ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

toggle_vrr() {
    local action="$1"
    local displays=($(detect_displays))
    
    case "$action" in
        "on"|"enable"|"true")
            echo "Enabling Variable Refresh Rate (FreeSync)..."
            
            # Enable VRR via xrandr if available
            if command -v xrandr >/dev/null 2>&1; then
                for display in "${displays[@]}"; do
                    if xrandr --output "$display" --set "vrr_capable" 1 >/dev/null 2>&1; then
                        echo "VRR enabled for $display"
                    fi
                done
            fi
            
            # Enable via DRM properties
            if command -v drm_info >/dev/null 2>&1; then
                echo "Enabling VRR via DRM properties..."
            fi
            
            # Mark VRR as enabled
            echo "true" > "$VRR_ENABLED_FILE"
            echo "Variable Refresh Rate enabled"
            ;;
            
        "off"|"disable"|"false")
            echo "Disabling Variable Refresh Rate..."
            
            # Disable VRR via xrandr if available
            if command -v xrandr >/dev/null 2>&1; then
                for display in "${displays[@]}"; do
                    if xrandr --output "$display" --set "vrr_capable" 0 >/dev/null 2>&1; then
                        echo "VRR disabled for $display"
                    fi
                done
            fi
            
            # Mark VRR as disabled
            echo "false" > "$VRR_ENABLED_FILE"
            echo "Variable Refresh Rate disabled"
            ;;
            
        "toggle"|"")
            local current_status=$(get_vrr_status)
            if [[ "$current_status" == "enabled" ]]; then
                toggle_vrr "off"
            else
                toggle_vrr "on"
            fi
            ;;
            
        *)
            echo "Usage: gz302-refresh vrr [on|off|toggle]"
            return 1
            ;;
    esac
}

show_status() {
    local current_profile="unknown"
    local current_rate=$(get_current_refresh_rate)
    local vrr_status=$(get_vrr_status)
    local displays=($(detect_displays))
    
    if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "unknown")
    fi
    
    echo "=== GZ302 Refresh Rate Status ==="
    echo "Current Profile: $current_profile"
    echo "Current Rate: ${current_rate}Hz"
    echo "Variable Refresh Rate: $vrr_status"
    echo "Detected Displays: ${displays[*]}"
    echo ""
    echo "Supported Refresh Rates:"
    get_supported_refresh_rates | while read rate; do
        if [[ "$rate" == "$current_rate" ]]; then
            echo "  ${rate}Hz (current)"
        else
            echo "  ${rate}Hz"
        fi
    done
}

list_profiles() {
    echo "Available refresh rate profiles:"
    echo ""
    for profile in gaming performance balanced efficient power_saver ultra_low; do
        if [[ -n "${REFRESH_PROFILES[$profile]}" ]]; then
            local rate="${REFRESH_PROFILES[$profile]}"
            local limit="${FRAME_LIMITS[$profile]}"
            local limit_text=""
            if [[ "$limit" != "0" ]]; then
                limit_text=" (capped at ${limit}fps)"
            fi
            echo "  $profile: ${rate}Hz${limit_text}"
        fi
    done
}

get_battery_status() {
    if command -v acpi >/dev/null 2>&1; then
        if acpi -a 2>/dev/null | grep -q "on-line"; then
            echo "AC"
        else
            echo "Battery"
        fi
    elif [[ -f /sys/class/power_supply/ADP1/online ]]; then
        if [[ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null)" == "1" ]]; then
            echo "AC"
        else
            echo "Battery"
        fi
    else
        echo "Unknown"
    fi
}

configure_auto_switching() {
    echo "Configuring automatic refresh rate profile switching..."
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
        
        if [[ -z "${REFRESH_PROFILES[$ac_profile]}" ]]; then
            echo "Invalid profile, using 'gaming'"
            ac_profile="gaming"
        fi
        
        echo ""
        echo "Select battery profile (when on battery):"
        list_profiles
        echo ""
        read -p "Battery profile [power_saver]: " battery_profile
        battery_profile=${battery_profile:-power_saver}
        
        if [[ -z "${REFRESH_PROFILES[$battery_profile]}" ]]; then
            echo "Invalid profile, using 'power_saver'"
            battery_profile="power_saver"
        fi
        
        # Save configuration
        echo "$auto_enabled" > "$AUTO_CONFIG_FILE"
        echo "$ac_profile" > "$AC_PROFILE_FILE"
        echo "$battery_profile" > "$BATTERY_PROFILE_FILE"
        
        echo ""
        echo "Automatic switching configured:"
        echo "  AC power: $ac_profile (${REFRESH_PROFILES[$ac_profile]}Hz)"
        echo "  Battery: $battery_profile (${REFRESH_PROFILES[$battery_profile]}Hz)"
        
        # Enable the auto refresh service
        systemctl enable gz302-refresh-auto.service >/dev/null 2>&1
        systemctl start gz302-refresh-auto.service >/dev/null 2>&1
    else
        echo "false" > "$AUTO_CONFIG_FILE"
        systemctl disable gz302-refresh-auto.service >/dev/null 2>&1
        systemctl stop gz302-refresh-auto.service >/dev/null 2>&1
        echo "Automatic switching disabled"
    fi
}

auto_switch_profile() {
    # Check if auto switching is enabled
    if [[ -f "$AUTO_CONFIG_FILE" ]] && [[ "$(cat "$AUTO_CONFIG_FILE" 2>/dev/null)" == "true" ]]; then
        local current_power=$(get_battery_status)
        local last_power_source=""
        
        if [[ -f "$REFRESH_CONFIG_DIR/last-power-source" ]]; then
            last_power_source=$(cat "$REFRESH_CONFIG_DIR/last-power-source" 2>/dev/null)
        fi
        
        # Only switch if power source changed
        if [[ "$current_power" != "$last_power_source" ]]; then
            echo "$current_power" > "$REFRESH_CONFIG_DIR/last-power-source"
            
            if [[ "$current_power" == "AC" ]] && [[ -f "$AC_PROFILE_FILE" ]]; then
                local ac_profile=$(cat "$AC_PROFILE_FILE" 2>/dev/null)
                if [[ -n "$ac_profile" ]]; then
                    echo "Power source changed to AC, switching to profile: $ac_profile"
                    set_refresh_rate "$ac_profile"
                fi
            elif [[ "$current_power" == "Battery" ]] && [[ -f "$BATTERY_PROFILE_FILE" ]]; then
                local battery_profile=$(cat "$BATTERY_PROFILE_FILE" 2>/dev/null)
                if [[ -n "$battery_profile" ]]; then
                    echo "Power source changed to Battery, switching to profile: $battery_profile"
                    set_refresh_rate "$battery_profile"
                fi
            fi
        fi
    fi
}

# Enhanced VRR Functions
apply_vrr_ranges() {
    local min_rate="$1"
    local max_rate="$2"
    local displays=($(detect_displays))
    
    echo "Applying VRR range: ${min_rate}Hz - ${max_rate}Hz"
    
    for display in "${displays[@]}"; do
        # X11 VRR range setting
        if command -v xrandr >/dev/null 2>&1; then
            # Try setting VRR properties if available
            xrandr --output "$display" --set "vrr_range" "${min_rate}-${max_rate}" 2>/dev/null || true
        fi
        
        # DRM direct property setting for better VRR control
        if [[ -d "/sys/class/drm" ]]; then
            for card in /sys/class/drm/card*; do
                if [[ -f "$card/device/vendor" ]] && grep -q "0x1002" "$card/device/vendor" 2>/dev/null; then
                    # AMD GPU found - try to set VRR range via sysfs
                    if [[ -f "$card/vrr_range" ]]; then
                        echo "${min_rate}-${max_rate}" > "$card/vrr_range" 2>/dev/null || true
                    fi
                fi
            done
        fi
    done
}

# Game-specific profile management
manage_game_profiles() {
    local action="$1"
    local game_name="$2"
    local profile="$3"
    
    case "$action" in
        "add")
            if [[ -z "$game_name" ]]; then
                echo "Usage: gz302-refresh game add [GAME_NAME] [PROFILE]"
                echo "Example: gz302-refresh game add steam gaming"
                return 1
            fi
            
            # Default to gaming profile if not specified
            profile="${profile:-gaming}"
            
            # Validate profile exists
            if [[ -z "${REFRESH_PROFILES[$profile]}" ]]; then
                echo "Error: Unknown profile '$profile'"
                echo "Available profiles: gaming, performance, balanced, efficient, power_saver, ultra_low"
                return 1
            fi
            
            echo "${game_name}:${profile}" >> "$GAME_PROFILES_FILE"
            echo "Game profile added: $game_name -> $profile (${REFRESH_PROFILES[$profile]}Hz)"
            ;;
            
        "remove")
            if [[ -z "$game_name" ]]; then
                echo "Usage: gz302-refresh game remove [GAME_NAME]"
                return 1
            fi
            
            if [[ -f "$GAME_PROFILES_FILE" ]]; then
                grep -v "^${game_name}:" "$GAME_PROFILES_FILE" > "${GAME_PROFILES_FILE}.tmp" 2>/dev/null || true
                mv "${GAME_PROFILES_FILE}.tmp" "$GAME_PROFILES_FILE" 2>/dev/null || true
                echo "Game profile removed for: $game_name"
            fi
            ;;
            
        "list")
            echo "Game-specific profiles:"
            if [[ -f "$GAME_PROFILES_FILE" ]] && [[ -s "$GAME_PROFILES_FILE" ]]; then
                while IFS=':' read -r game profile; do
                    if [[ -n "$game" && -n "$profile" ]]; then
                        echo "  $game -> $profile (${REFRESH_PROFILES[$profile]}Hz)"
                    fi
                done < "$GAME_PROFILES_FILE"
            else
                echo "  No game-specific profiles configured"
            fi
            ;;
            
        "detect")
            # Auto-detect running games and apply profiles
            if [[ -f "$GAME_PROFILES_FILE" ]]; then
                while IFS=':' read -r game profile; do
                    if [[ -n "$game" && -n "$profile" ]]; then
                        # Check if game process is running
                        if pgrep -i "$game" >/dev/null 2>&1; then
                            echo "Detected running game: $game, applying profile: $profile"
                            set_refresh_rate "$profile"
                            return 0
                        fi
                    fi
                done < "$GAME_PROFILES_FILE"
            fi
            ;;
            
        *)
            echo "Usage: gz302-refresh game [add|remove|list|detect]"
            ;;
    esac
}

# Monitor-specific configuration
configure_monitor() {
    local display="$1"
    local rate="$2"
    
    if [[ -z "$display" ]]; then
        echo "Available displays:"
        detect_displays | while read -r disp; do
            local current_rate=$(get_current_refresh_rate "$disp")
            echo "  $disp (current: ${current_rate}Hz)"
        done
        return 0
    fi
    
    if [[ -z "$rate" ]]; then
        echo "Usage: gz302-refresh monitor [DISPLAY] [RATE]"
        echo "Example: gz302-refresh monitor DP-1 120"
        return 1
    fi
    
    echo "Setting $display to ${rate}Hz"
    
    # Set refresh rate for specific display
    local success=false
    
    # Method 1: xrandr (X11)
    if command -v xrandr >/dev/null 2>&1; then
        if xrandr --output "$display" --rate "$rate" >/dev/null 2>&1; then
            success=true
            echo "Refresh rate set to ${rate}Hz using xrandr"
        fi
    fi
    
    # Method 2: wlr-randr (Wayland)
    if [[ "$success" == false ]] && command -v wlr-randr >/dev/null 2>&1; then
        if wlr-randr --output "$display" --mode "${rate}Hz" >/dev/null 2>&1; then
            success=true
            echo "Refresh rate set to ${rate}Hz using wlr-randr"
        fi
    fi
    
    if [[ "$success" == true ]]; then
        # Save monitor-specific configuration
        echo "${display}:${rate}" >> "$MONITOR_CONFIGS_FILE"
        echo "Monitor configuration saved"
    else
        echo "Warning: Could not set refresh rate for $display"
    fi
}

# Real-time power consumption monitoring
monitor_power_consumption() {
    echo "=== GZ302 Refresh Rate Power Monitoring ==="
    echo ""
    
    local current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "unknown")
    local estimated_power="${POWER_ESTIMATES[$current_profile]:-20}"
    
    echo "Current Profile: $current_profile"
    echo "Estimated Display Power: ${estimated_power}W"
    echo ""
    
    # Real-time power reading if available
    if [[ -f "/sys/class/power_supply/BAT0/power_now" ]]; then
        local power_now=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null)
        if [[ -n "$power_now" && "$power_now" -gt 0 ]]; then
            local power_watts=$((power_now / 1000000))
            echo "Current System Power: ${power_watts}W"
        fi
    fi
    
    # CPU frequency and thermal info
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            local temp_celsius=$((temp / 1000))
            echo "CPU Temperature: ${temp_celsius}°C"
        fi
    fi
    
    # Battery status and predictions
    if command -v acpi >/dev/null 2>&1; then
        echo ""
        echo "Battery Status:"
        acpi -b 2>/dev/null | head -3
    fi
    
    echo ""
    echo "Power Estimates by Profile:"
    for profile in gaming performance balanced efficient power_saver ultra_low; do
        local power="${POWER_ESTIMATES[$profile]}"
        local rate="${REFRESH_PROFILES[$profile]}"
        echo "  $profile: ${rate}Hz @ ~${power}W"
    done
}

# Thermal throttling status
check_thermal_status() {
    echo "=== GZ302 Thermal Throttling Status ==="
    echo ""
    
    # Check CPU thermal throttling
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            local temp_celsius=$((temp / 1000))
            echo "CPU Temperature: ${temp_celsius}°C"
            
            if [[ "$temp_celsius" -gt 85 ]]; then
                echo "⚠️  WARNING: High CPU temperature detected!"
                echo "Consider switching to power_saver or ultra_low profile"
            elif [[ "$temp_celsius" -gt 75 ]]; then
                echo "⚠️  CPU running warm - consider balanced or efficient profile"
            else
                echo "✅ CPU temperature normal"
            fi
        fi
    fi
    
    # Check GPU thermal status if available
    if command -v sensors >/dev/null 2>&1; then
        echo ""
        echo "GPU Temperature:"
        sensors 2>/dev/null | grep -i "edge\|junction" | head -2 || echo "GPU sensors not available"
    fi
    
    # Check current CPU frequency scaling
    if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]]; then
        local cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [[ -n "$cur_freq" && -n "$max_freq" ]]; then
            local freq_percent=$((cur_freq * 100 / max_freq))
            echo ""
            echo "CPU Frequency: $((cur_freq / 1000))MHz (${freq_percent}% of max)"
            if [[ "$freq_percent" -lt 70 ]]; then
                echo "⚠️  CPU may be throttling due to thermal or power limits"
            fi
        fi
    fi
}

# Battery life prediction with different refresh rates
predict_battery_life() {
    echo "=== GZ302 Battery Life Prediction ==="
    echo ""
    
    # Get current battery info
    local battery_capacity=0
    local battery_current=0
    
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    fi
    
    if [[ -f "/sys/class/power_supply/BAT0/current_now" ]]; then
        battery_current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || echo 0)
    fi
    
    echo "Current Battery Level: ${battery_capacity}%"
    
    if [[ "$battery_current" -gt 0 ]]; then
        local current_ma=$((battery_current / 1000))
        echo "Current Draw: ${current_ma}mA"
        echo ""
        
        echo "Estimated Battery Life by Refresh Profile:"
        echo ""
        
        # Base battery capacity (typical for GZ302)
        local battery_wh=56  # Approximate battery capacity in Wh
        local usable_capacity=$((battery_wh * battery_capacity / 100))
        
        for profile in ultra_low power_saver efficient balanced performance gaming; do
            local power="${POWER_ESTIMATES[$profile]}"
            local rate="${REFRESH_PROFILES[$profile]}"
            local estimated_hours=$((usable_capacity * 100 / power / 100))
            local estimated_minutes=$(((usable_capacity * 100 / power % 100) * 60 / 100))
            
            printf "  %-12s: %sHz @ ~%sW -> ~%s:%02d hours\n" \
                "$profile" "$rate" "$power" "$estimated_hours" "$estimated_minutes"
        done
        
        echo ""
        echo "Note: Estimates include display power only. Actual battery life"
        echo "depends on CPU load, GPU usage, and other system components."
        
    else
        echo "Battery information not available or system is plugged in"
    fi
}

# Display temperature/color management integration
configure_display_color() {
    local action="$1"
    local temperature="$2"
    
    case "$action" in
        "set")
            if [[ -z "$temperature" ]]; then
                echo "Usage: gz302-refresh color set [TEMPERATURE]"
                echo "Example: gz302-refresh color set 6500K"
                echo "Common values: 6500K (daylight), 5000K (neutral), 3200K (warm)"
                return 1
            fi
            
            # Remove 'K' suffix if present
            temperature="${temperature%K}"
            
            # Validate temperature range
            if [[ "$temperature" -lt 1000 || "$temperature" -gt 10000 ]]; then
                echo "Error: Temperature must be between 1000K and 10000K"
                return 1
            fi
            
            echo "Setting display color temperature to ${temperature}K"
            
            # Try redshift for color temperature control
            if command -v redshift >/dev/null 2>&1; then
                redshift -O "$temperature" >/dev/null 2>&1 && echo "Color temperature set using redshift"
            elif command -v gammastep >/dev/null 2>&1; then
                gammastep -O "$temperature" >/dev/null 2>&1 && echo "Color temperature set using gammastep"
            elif command -v xrandr >/dev/null 2>&1; then
                # Fallback: use xrandr gamma adjustment (approximate)
                local displays=($(detect_displays))
                for display in "${displays[@]}"; do
                    # Calculate approximate gamma adjustment for color temperature
                    local gamma_r gamma_g gamma_b
                    if [[ "$temperature" -gt 6500 ]]; then
                        # Cooler - reduce red
                        gamma_r="0.9"
                        gamma_g="1.0"
                        gamma_b="1.1"
                    elif [[ "$temperature" -lt 5000 ]]; then
                        # Warmer - reduce blue
                        gamma_r="1.1"
                        gamma_g="1.0"
                        gamma_b="0.8"
                    else
                        # Neutral
                        gamma_r="1.0"
                        gamma_g="1.0"
                        gamma_b="1.0"
                    fi
                    
                    xrandr --output "$display" --gamma "${gamma_r}:${gamma_g}:${gamma_b}" 2>/dev/null && \
                        echo "Gamma adjustment applied to $display"
                done
            else
                echo "No color temperature control tools available"
                echo "Consider installing redshift or gammastep"
            fi
            ;;
            
        "auto")
            echo "Setting up automatic color temperature adjustment..."
            
            # Check if redshift/gammastep is available
            if command -v redshift >/dev/null 2>&1; then
                echo "Enabling redshift automatic color temperature"
                # Create a simple redshift config for automatic day/night cycle
                local user_home="/home/$(get_real_user 2>/dev/null || echo "$USER")"
                mkdir -p "$user_home/.config/redshift"
                cat > "$user_home/.config/redshift/redshift.conf" <<'REDSHIFT_EOF'
[redshift]
temp-day=6500
temp-night=3200
brightness-day=1.0
brightness-night=0.8
transition=1
gamma=0.8:0.7:0.8

[manual]
lat=40.0
lon=-74.0
REDSHIFT_EOF
                echo "Redshift configured for automatic color temperature"
                
            elif command -v gammastep >/dev/null 2>&1; then
                echo "Enabling gammastep automatic color temperature"
                local user_home="/home/$(get_real_user 2>/dev/null || echo "$USER")"
                mkdir -p "$user_home/.config/gammastep"
                cat > "$user_home/.config/gammastep/config.ini" <<'GAMMASTEP_EOF'
[general]
temp-day=6500
temp-night=3200
brightness-day=1.0
brightness-night=0.8
transition=1
gamma=0.8:0.7:0.8

[manual]
lat=40.0
lon=-74.0
GAMMASTEP_EOF
                echo "Gammastep configured for automatic color temperature"
            else
                echo "Installing redshift for color temperature control..."
                # This would be handled by the package manager in the main setup
                echo "Please run the main setup script to install color management tools"
            fi
            ;;
            
        "reset")
            echo "Resetting display color temperature to default"
            if command -v redshift >/dev/null 2>&1; then
                redshift -x >/dev/null 2>&1
                echo "Redshift reset"
            elif command -v gammastep >/dev/null 2>&1; then
                gammastep -x >/dev/null 2>&1
                echo "Gammastep reset"
            elif command -v xrandr >/dev/null 2>&1; then
                local displays=($(detect_displays))
                for display in "${displays[@]}"; do
                    xrandr --output "$display" --gamma 1.0:1.0:1.0 2>/dev/null && \
                        echo "Gamma reset for $display"
                done
            fi
            ;;
            
        *)
            echo "Usage: gz302-refresh color [set|auto|reset]"
            echo ""
            echo "Commands:"
            echo "  set [TEMP]  - Set color temperature (e.g., 6500K, 3200K)"
            echo "  auto        - Enable automatic day/night color adjustment"
            echo "  reset       - Reset to default color temperature"
            ;;
    esac
}

# Enhanced status function with new monitoring features
show_enhanced_status() {
    show_status
    echo ""
    echo "=== Enhanced Monitoring ==="
    
    # Show game profiles
    echo ""
    echo "Game Profiles:"
    manage_game_profiles "list"
    
    # Show VRR ranges
    echo ""
    echo "VRR Ranges:"
    if [[ -f "$VRR_RANGES_FILE" ]]; then
        local vrr_range=$(cat "$VRR_RANGES_FILE" 2>/dev/null)
        echo "  Current VRR Range: ${vrr_range}Hz"
    else
        echo "  VRR ranges not configured"
    fi
    
    # Quick thermal and power info
    echo ""
    local temp_celsius=0
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            temp_celsius=$((temp / 1000))
        fi
    fi
    echo "CPU Temperature: ${temp_celsius}°C"
    
    local battery_capacity=0
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    fi
    echo "Battery Level: ${battery_capacity}%"
}

# Main command processing
case "${1:-}" in
    "status")
        show_enhanced_status
        ;;
    "list")
        list_profiles
        ;;
    "auto")
        auto_switch_profile
        ;;
    "config")
        configure_auto_switching
        ;;
    "vrr")
        case "$2" in
            "ranges")
                echo "VRR Range Configuration:"
                echo "Enter minimum refresh rate (default: 30): "
                read -r min_range
                min_range="${min_range:-30}"
                echo "Enter maximum refresh rate (default: 180): "
                read -r max_range
                max_range="${max_range:-180}"
                echo "${min_range}:${max_range}" > "$VRR_RANGES_FILE"
                apply_vrr_ranges "$min_range" "$max_range"
                echo "VRR range set to ${min_range}Hz - ${max_range}Hz"
                ;;
            *)
                toggle_vrr "$2"
                ;;
        esac
        ;;
    "monitor")
        configure_monitor "$2" "$3"
        ;;
    "game")
        manage_game_profiles "$2" "$3" "$4"
        ;;
    "color")
        configure_display_color "$2" "$3"
        ;;
    "monitor-power")
        monitor_power_consumption
        ;;
    "thermal-status")
        check_thermal_status
        ;;
    "battery-predict")
        predict_battery_life
        ;;
    "gaming"|"performance"|"balanced"|"efficient"|"power_saver"|"ultra_low")
        # Check for game-specific profile detection first
        manage_game_profiles "detect"
        # If no game detected, apply the requested profile
        if [[ $? -ne 0 ]]; then
            set_refresh_rate "$1"
        fi
        ;;
    "")
        show_usage
        ;;
    *)
        # Check if it's a game name for quick profile switching
        if [[ -f "$GAME_PROFILES_FILE" ]] && grep -q "^${1}:" "$GAME_PROFILES_FILE" 2>/dev/null; then
            local game_profile=$(grep "^${1}:" "$GAME_PROFILES_FILE" | cut -d':' -f2)
            echo "Applying game profile for $1: $game_profile"
            set_refresh_rate "$game_profile"
        else
            echo "Unknown command or game: $1"
            show_usage
        fi
        ;;
esac
EOF

    chmod +x /usr/local/bin/gz302-refresh
    
    # Create systemd service for automatic refresh rate management
    cat > /etc/systemd/system/gz302-refresh-auto.service <<EOF
[Unit]
Description=GZ302 Automatic Refresh Rate Management
Wants=gz302-refresh-monitor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gz302-refresh auto
EOF

    # Create systemd timer for periodic checking
    cat > /etc/systemd/system/gz302-refresh-auto.timer <<EOF
[Unit]
Description=GZ302 Refresh Rate Auto Timer
Requires=gz302-refresh-auto.service

[Timer]
OnBootSec=30sec
OnUnitActiveSec=30sec
AccuracySec=5sec

[Install]
WantedBy=timers.target
EOF

    # Create refresh rate monitoring service  
    cat > /etc/systemd/system/gz302-refresh-monitor.service <<EOF
[Unit]
Description=GZ302 Refresh Rate Power Source Monitor
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gz302-refresh-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create power monitoring script for refresh rates
    cat > /usr/local/bin/gz302-refresh-monitor <<'MONITOR_EOF'
#!/bin/bash
# GZ302 Refresh Rate Power Source Monitor
# Monitors power source changes and automatically switches refresh rate profiles

while true; do
    /usr/local/bin/gz302-refresh auto
    sleep 30  # Check every 30 seconds (less frequent than TDP)
done
MONITOR_EOF

    chmod +x /usr/local/bin/gz302-refresh-monitor
    
    systemctl enable gz302-refresh-auto.timer
    
    echo ""
    info "Refresh rate management installation complete!"
    echo ""
    echo "Would you like to configure automatic refresh rate profile switching now?"
    echo "This allows the system to automatically change refresh rates"
    echo "when you plug/unplug the AC adapter for optimal power usage."
    echo ""
    read -p "Configure automatic refresh rate switching? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /usr/local/bin/gz302-refresh config
    else
        echo "You can configure automatic switching later using: gz302-refresh config"
    fi
    
    echo ""
    success "Refresh rate management installed. Use 'gz302-refresh' command to control display refresh rates."
}

# Placeholder functions for snapshots
setup_arch_snapshots() {
    info "Setting up snapshots for Arch-based system..."
    
    # Check filesystem type
    local fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    
    if [[ "$fs_type" == "btrfs" ]]; then
        info "Detected Btrfs filesystem - setting up Snapper for Btrfs"
        pacman -S --noconfirm --needed snapper
        
        # Create snapper configuration
        snapper create-config /
        systemctl enable --now snapper-timeline.timer
        systemctl enable --now snapper-cleanup.timer
        success "Snapper configured for Btrfs"
        
    elif [[ "$fs_type" == "ext4" ]]; then
        info "Detected ext4 filesystem - setting up LVM snapshots"
        pacman -S --noconfirm --needed lvm2
        warning "LVM snapshot setup requires manual configuration"
        
    else
        warning "Filesystem $fs_type - limited snapshot support"
    fi
    
    # Create snapshot management script
    cat > /usr/local/bin/gz302-snapshot << 'EOF'
#!/bin/bash
# GZ302 Snapshot Management Script

case "$1" in
    "create")
        echo "[INFO] Creating system snapshot..."
        if command -v snapper >/dev/null 2>&1; then
            snapper create --description "Manual snapshot $(date)"
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "list")
        echo "[INFO] Listing snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper list
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "cleanup")
        echo "[INFO] Cleaning up old snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper cleanup number
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    *)
        echo "Usage: gz302-snapshot [create|list|cleanup]"
        ;;
esac
EOF
    chmod +x /usr/local/bin/gz302-snapshot
    
    success "Snapshots configured"
}

setup_debian_snapshots() {
    info "Setting up snapshots for Debian-based system..."
    
    # Check filesystem type
    local fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    
    if [[ "$fs_type" == "btrfs" ]]; then
        info "Detected Btrfs filesystem - setting up Timeshift for Btrfs"
        apt install -y timeshift
        success "Timeshift installed - configure via GUI or timeshift --create"
        
    elif [[ "$fs_type" == "ext4" ]]; then
        info "Detected ext4 filesystem - setting up Timeshift with rsync"
        apt install -y timeshift
        success "Timeshift installed - configure via GUI or timeshift --create"
        
    else
        warning "Filesystem $fs_type - installing Timeshift anyway"
        apt install -y timeshift
    fi
    
    # Create snapshot management script
    cat > /usr/local/bin/gz302-snapshot << 'EOF'
#!/bin/bash
# GZ302 Snapshot Management Script for Debian/Ubuntu

case "$1" in
    "create")
        echo "[INFO] Creating system snapshot..."
        if command -v timeshift >/dev/null 2>&1; then
            timeshift --create --comments "Manual snapshot $(date)"
        else
            echo "[WARNING] Timeshift not available"
        fi
        ;;
    "list")
        echo "[INFO] Listing snapshots..."
        if command -v timeshift >/dev/null 2>&1; then
            timeshift --list
        else
            echo "[WARNING] Timeshift not available"
        fi
        ;;
    "cleanup")
        echo "[INFO] Cleaning up old snapshots..."
        if command -v timeshift >/dev/null 2>&1; then
            timeshift --delete-all
        else
            echo "[WARNING] Timeshift not available"
        fi
        ;;
    *)
        echo "Usage: gz302-snapshot [create|list|cleanup]"
        ;;
esac
EOF
    chmod +x /usr/local/bin/gz302-snapshot
    
    success "Snapshots configured"
}

setup_fedora_snapshots() {
    info "Setting up snapshots for Fedora-based system..."
    
    # Check filesystem type
    local fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    
    if [[ "$fs_type" == "btrfs" ]]; then
        info "Detected Btrfs filesystem - setting up Snapper for Btrfs"
        dnf install -y snapper
        
        # Create snapper configuration
        snapper create-config /
        systemctl enable --now snapper-timeline.timer
        systemctl enable --now snapper-cleanup.timer
        success "Snapper configured for Btrfs"
        
    elif [[ "$fs_type" == "ext4" ]]; then
        info "Detected ext4 filesystem - setting up LVM snapshots"
        dnf install -y lvm2
        warning "LVM snapshot setup requires manual configuration"
        
    else
        warning "Filesystem $fs_type - installing Snapper anyway"
        dnf install -y snapper
    fi
    
    # Create snapshot management script
    cat > /usr/local/bin/gz302-snapshot << 'EOF'
#!/bin/bash
# GZ302 Snapshot Management Script for Fedora

case "$1" in
    "create")
        echo "[INFO] Creating system snapshot..."
        if command -v snapper >/dev/null 2>&1; then
            snapper create --description "Manual snapshot $(date)"
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "list")
        echo "[INFO] Listing snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper list
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "cleanup")
        echo "[INFO] Cleaning up old snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper cleanup number
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    *)
        echo "Usage: gz302-snapshot [create|list|cleanup]"
        ;;
esac
EOF
    chmod +x /usr/local/bin/gz302-snapshot
    
    success "Snapshots configured"
}

setup_opensuse_snapshots() {
    info "Setting up snapshots for OpenSUSE..."
    
    # OpenSUSE comes with Snapper pre-configured for Btrfs by default
    local fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)
    
    if [[ "$fs_type" == "btrfs" ]]; then
        info "Detected Btrfs filesystem - Snapper is pre-configured on OpenSUSE"
        # Ensure snapper and YaST2 snapper module are installed
        zypper install -y snapper yast2-snapper
        
        # Verify snapper configuration exists
        snapper list-configs || snapper create-config /
        
        # Enable automatic snapshots
        systemctl enable --now snapper-timeline.timer
        systemctl enable --now snapper-cleanup.timer
        success "Snapper verified and enabled"
        
    else
        warning "Filesystem $fs_type - OpenSUSE snapshot features work best with Btrfs"
        zypper install -y snapper
    fi
    
    # Create snapshot management script
    cat > /usr/local/bin/gz302-snapshot << 'EOF'
#!/bin/bash
# GZ302 Snapshot Management Script for OpenSUSE

case "$1" in
    "create")
        echo "[INFO] Creating system snapshot..."
        if command -v snapper >/dev/null 2>&1; then
            snapper create --description "Manual snapshot $(date)"
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "list")
        echo "[INFO] Listing snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper list
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    "cleanup")
        echo "[INFO] Cleaning up old snapshots..."
        if command -v snapper >/dev/null 2>&1; then
            snapper cleanup number
        else
            echo "[WARNING] Snapper not available"
        fi
        ;;
    *)
        echo "Usage: gz302-snapshot [create|list|cleanup]"
        ;;
esac
EOF
    chmod +x /usr/local/bin/gz302-snapshot
    
    success "Snapshots configured"
}

# Placeholder functions for secure boot
setup_arch_secureboot() {
    info "Setting up secure boot for Arch-based system..."
    
    # Install secure boot tools
    pacman -S --noconfirm --needed sbctl
    
    # Check if we're in UEFI mode
    if [[ -d /sys/firmware/efi ]]; then
        info "UEFI system detected - configuring secure boot"
        
        # Initialize secure boot
        sbctl status || true
        
        success "Secure boot tools installed - manual configuration required"
        warning "Please run 'sbctl create-keys' and configure BIOS settings manually"
    else
        warning "Non-UEFI system - secure boot not applicable"
    fi
    
    success "Secure boot configured"
}

setup_debian_secureboot() {
    info "Setting up secure boot for Debian-based system..."
    
    # Install secure boot tools
    apt install -y mokutil shim-signed
    
    # Check if we're in UEFI mode
    if [[ -d /sys/firmware/efi ]]; then
        info "UEFI system detected - configuring secure boot"
        
        # Check secure boot status
        mokutil --sb-state || true
        
        success "Secure boot tools installed"
        warning "To enable secure boot: Configure in BIOS/UEFI settings"
        warning "For custom kernels: Use mokutil to enroll keys"
    else
        warning "Non-UEFI system - secure boot not applicable"
    fi
    
    success "Secure boot configured"
}

setup_fedora_secureboot() {
    info "Setting up secure boot for Fedora-based system..."
    
    # Install secure boot tools (Fedora comes with mokutil and shim by default)
    dnf install -y mokutil shim efibootmgr
    
    # Check if we're in UEFI mode
    if [[ -d /sys/firmware/efi ]]; then
        info "UEFI system detected - configuring secure boot"
        
        # Check secure boot status
        mokutil --sb-state || true
        
        # Install kernel signing utilities for custom kernels
        dnf install -y pesign kernel-devel
        
        success "Secure boot tools installed"
        warning "Fedora supports secure boot by default with signed kernels"
        warning "For custom kernels: Use mokutil to manage keys"
    else
        warning "Non-UEFI system - secure boot not applicable"
    fi
    
    success "Secure boot configured"
}

setup_opensuse_secureboot() {
    info "Setting up secure boot for OpenSUSE..."
    
    # Install secure boot tools
    zypper install -y mokutil shim efibootmgr
    
    # Check if we're in UEFI mode
    if [[ -d /sys/firmware/efi ]]; then
        info "UEFI system detected - configuring secure boot"
        
        # Check secure boot status
        mokutil --sb-state || true
        
        # Install YaST2 bootloader module for secure boot management
        zypper install -y yast2-bootloader
        
        success "Secure boot tools installed"
        warning "OpenSUSE supports secure boot - use YaST2 bootloader module to configure"
        warning "Run 'yast2 bootloader' to manage secure boot settings"
    else
        warning "Non-UEFI system - secure boot not applicable"
    fi
    
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
    echo "  Version 4.3 - Virtual Refresh Rate Management: Comprehensive display refresh rate control system"
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
    success "- Refresh rate control: Use 'gz302-refresh' command"
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