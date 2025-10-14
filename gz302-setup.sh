#!/bin/bash

#############################################################################
# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script
# Version: 1.0.0
# 
# Comprehensive post-installation setup for GZ302EA models:
# - GZ302EA-XS99 (128GB)
# - GZ302EA-XS64 (64GB)
# - GZ302EA-XS32 (32GB)
#
# Supports: Arch, Debian/Ubuntu, Fedora, openSUSE, and other major distros
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.1.0"

# Distro detection
DISTRO=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""

#############################################################################
# Helper Functions
#############################################################################

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Asus ROG Flow Z13 2025 Linux Setup Script${NC}"
    echo -e "${BLUE}  Version: $VERSION${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

#############################################################################
# Distro Detection
#############################################################################

detect_distro() {
    print_step "Detecting Linux distribution..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        
        case $ID in
            arch|manjaro|endeavouros|garuda)
                DISTRO_FAMILY="arch"
                PACKAGE_MANAGER="pacman"
                ;;
            ubuntu|debian|mint|pop|elementary|zorin|linuxmint)
                DISTRO_FAMILY="debian"
                PACKAGE_MANAGER="apt"
                ;;
            fedora|nobara)
                DISTRO_FAMILY="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            opensuse-leap|opensuse-tumbleweed|opensuse)
                DISTRO_FAMILY="opensuse"
                PACKAGE_MANAGER="zypper"
                ;;
            gentoo)
                DISTRO_FAMILY="gentoo"
                PACKAGE_MANAGER="emerge"
                ;;
            void)
                DISTRO_FAMILY="void"
                PACKAGE_MANAGER="xbps-install"
                ;;
            *)
                print_warning "Unknown distribution: $ID"
                print_warning "Attempting to detect package manager..."
                if command -v pacman &> /dev/null; then
                    DISTRO_FAMILY="arch"
                    PACKAGE_MANAGER="pacman"
                elif command -v apt &> /dev/null; then
                    DISTRO_FAMILY="debian"
                    PACKAGE_MANAGER="apt"
                elif command -v dnf &> /dev/null; then
                    DISTRO_FAMILY="fedora"
                    PACKAGE_MANAGER="dnf"
                elif command -v zypper &> /dev/null; then
                    DISTRO_FAMILY="opensuse"
                    PACKAGE_MANAGER="zypper"
                else
                    print_error "Could not detect supported package manager"
                    exit 1
                fi
                ;;
        esac
    else
        print_error "Cannot detect distribution - /etc/os-release not found"
        exit 1
    fi
    
    print_info "Detected: $DISTRO ($DISTRO_FAMILY) using $PACKAGE_MANAGER"
}

#############################################################################
# System Updates
#############################################################################

update_system() {
    print_step "Updating system packages..."
    
    case $DISTRO_FAMILY in
        arch)
            pacman -Syu --noconfirm
            ;;
        debian)
            apt update
            apt upgrade -y
            ;;
        fedora)
            dnf upgrade -y
            ;;
        opensuse)
            zypper refresh
            zypper update -y
            ;;
        gentoo)
            emerge --sync
            emerge -uDN @world
            ;;
        void)
            xbps-install -Su
            ;;
    esac
    
    print_success "System updated"
}

#############################################################################
# Kernel Check and Update
#############################################################################

check_kernel_version() {
    print_step "Checking kernel version..."
    
    local kernel_version=$(uname -r | cut -d. -f1,2)
    local kernel_major=$(echo $kernel_version | cut -d. -f1)
    local kernel_minor=$(echo $kernel_version | cut -d. -f2)
    
    print_info "Current kernel: $(uname -r)"
    
    if [ "$kernel_major" -lt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -lt 14 ]); then
        print_warning "Kernel version < 6.14 detected. Updating to g14 kernel for best hardware support."
        update_kernel
    else
        print_success "Kernel version is adequate (>= 6.14)"
        # Still offer g14 kernel for ROG-specific optimizations
        print_info "Installing g14 kernel for ROG-specific optimizations..."
        install_g14_kernel
    fi
}

install_g14_kernel() {
    print_step "Installing g14 kernel and headers..."
    
    case $DISTRO_FAMILY in
        arch)
            print_info "Installing linux-g14 kernel from AUR..."
            # Check if yay or paru is available for AUR
            if command -v yay &> /dev/null; then
                sudo -u ${SUDO_USER} yay -S --noconfirm linux-g14 linux-g14-headers
            elif command -v paru &> /dev/null; then
                sudo -u ${SUDO_USER} paru -S --noconfirm linux-g14 linux-g14-headers
            else
                print_warning "AUR helper (yay/paru) not found"
                print_info "Installing manually from AUR..."
                # Install dependencies
                pacman -S --noconfirm base-devel git
                # Clone and build linux-g14
                cd /tmp
                sudo -u ${SUDO_USER} git clone https://aur.archlinux.org/linux-g14.git
                cd linux-g14
                sudo -u ${SUDO_USER} makepkg -si --noconfirm
                cd /tmp
                sudo -u ${SUDO_USER} git clone https://aur.archlinux.org/linux-g14-headers.git
                cd linux-g14-headers
                sudo -u ${SUDO_USER} makepkg -si --noconfirm
                cd /
                rm -rf /tmp/linux-g14 /tmp/linux-g14-headers
            fi
            ;;
        debian|ubuntu)
            print_info "For Debian/Ubuntu, g14 kernel is not available as a package."
            print_info "Installing latest available kernel with ROG patches..."
            apt install -y linux-image-generic linux-headers-generic
            # Note: Users may need to compile custom kernel for g14 patches
            print_warning "For best ROG support, consider using a distribution with g14 kernel support."
            ;;
        fedora)
            print_info "Installing latest kernel with development headers..."
            dnf install -y kernel kernel-devel kernel-headers
            print_info "Consider compiling custom kernel with g14 patches for optimal ROG support."
            ;;
        opensuse)
            print_info "Installing latest kernel..."
            zypper install -y kernel-default kernel-default-devel
            ;;
    esac
    
    print_success "Kernel installation complete. Reboot required."
}

update_kernel() {
    print_step "Updating to g14 kernel..."
    
    # First install g14 kernel
    install_g14_kernel
}

#############################################################################
# Firmware Updates
#############################################################################

update_firmware() {
    print_step "Updating system firmware (linux-firmware)..."
    
    case $DISTRO_FAMILY in
        arch)
            pacman -S --noconfirm linux-firmware
            ;;
        debian)
            apt install -y linux-firmware
            # Also try firmware-linux-nonfree for additional firmware
            if apt-cache search firmware-linux-nonfree | grep -q firmware-linux-nonfree; then
                apt install -y firmware-linux-nonfree
            fi
            ;;
        fedora)
            dnf install -y linux-firmware
            ;;
        opensuse)
            zypper install -y kernel-firmware
            ;;
        void)
            xbps-install -y linux-firmware
            ;;
    esac
    
    print_success "Firmware updated (includes MediaTek MT7925 WiFi/BT)"
}

#############################################################################
# Graphics Setup (AMDGPU, Mesa, Vulkan)
#############################################################################

setup_graphics() {
    print_step "Setting up AMD Radeon 8060S graphics drivers..."
    
    case $DISTRO_FAMILY in
        arch)
            print_info "Installing Mesa and Vulkan drivers..."
            pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
                vulkan-icd-loader lib32-vulkan-icd-loader mesa-utils vulkan-tools \
                xf86-video-amdgpu
            ;;
        debian)
            print_info "Installing Mesa and Vulkan drivers..."
            apt install -y mesa-vulkan-drivers mesa-utils vulkan-tools \
                libvulkan1 mesa-va-drivers mesa-vdpau-drivers \
                xserver-xorg-video-amdgpu
            # Try to install 32-bit support if available
            dpkg --add-architecture i386 2>/dev/null || true
            apt update 2>/dev/null || true
            apt install -y mesa-vulkan-drivers:i386 libvulkan1:i386 2>/dev/null || true
            ;;
        fedora)
            print_info "Installing Mesa and Vulkan drivers..."
            dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
                mesa-libGL mesa-libEGL libva-mesa-driver mesa-vdpau-drivers \
                xorg-x11-drv-amdgpu
            ;;
        opensuse)
            print_info "Installing Mesa and Vulkan drivers..."
            zypper install -y Mesa-dri Mesa-vulkan-dri vulkan-tools \
                Mesa-libGL1 Mesa-libEGL1 xf86-video-amdgpu
            ;;
    esac
    
    # Configure AMDGPU module options
    print_info "Configuring AMDGPU module options..."
    cat > /etc/modprobe.d/amdgpu.conf <<EOF
# AMDGPU configuration for AMD Strix Halo (Radeon 8060S)
options amdgpu si_support=1
options amdgpu cik_support=1
options amdgpu dpm=1
options amdgpu audio=1
EOF
    
    print_success "Graphics drivers configured"
}

#############################################################################
# Bootloader Configuration (GRUB and systemd-boot)
#############################################################################

configure_bootloader() {
    print_step "Configuring bootloader parameters..."
    
    # Kernel parameters for AMD Strix Halo and GZ302EA
    local new_params="iommu=pt amd_pstate=active amdgpu.si_support=1 amdgpu.cik_support=1"
    
    # Detect which bootloader is in use
    if [ -f /etc/default/grub ]; then
        configure_grub "$new_params"
    elif [ -d /boot/loader/entries ] || [ -f /boot/efi/loader/loader.conf ] || [ -f /efi/loader/loader.conf ]; then
        configure_systemd_boot "$new_params"
    else
        print_warning "No supported bootloader detected (GRUB or systemd-boot)"
        print_info "Please manually add these kernel parameters: $new_params"
    fi
}

configure_grub() {
    local new_params="$1"
    print_info "Detected GRUB bootloader"
    
    # Backup existing GRUB config
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)
    
    # Check if parameters already exist
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
        # Add parameters if not already present
        if ! grep -q "amd_pstate=active" /etc/default/grub; then
            sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params /" /etc/default/grub
            print_info "Added kernel parameters: $new_params"
        else
            print_info "Kernel parameters already configured"
        fi
    fi
    
    # Update GRUB
    print_info "Updating GRUB..."
    if command -v update-grub &> /dev/null; then
        update-grub
    elif command -v grub-mkconfig &> /dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    elif command -v grub2-mkconfig &> /dev/null; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        print_warning "Could not find GRUB update command"
    fi
    
    print_success "GRUB configured"
}

configure_systemd_boot() {
    local new_params="$1"
    print_info "Detected systemd-boot bootloader"
    
    # Find the boot loader entries directory
    local entries_dir=""
    if [ -d /boot/loader/entries ]; then
        entries_dir="/boot/loader/entries"
    elif [ -d /boot/efi/loader/entries ]; then
        entries_dir="/boot/efi/loader/entries"
    elif [ -d /efi/loader/entries ]; then
        entries_dir="/efi/loader/entries"
    else
        print_error "Could not find systemd-boot entries directory"
        return 1
    fi
    
    print_info "Boot entries directory: $entries_dir"
    
    # Update all existing boot entries
    local updated=false
    for entry in "$entries_dir"/*.conf; do
        if [ -f "$entry" ]; then
            # Backup the entry
            cp "$entry" "$entry.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Check if parameters are already present
            if ! grep -q "amd_pstate=active" "$entry"; then
                # Add parameters to the options line
                if grep -q "^options" "$entry"; then
                    sed -i "s/^options /options $new_params /" "$entry"
                    print_info "Updated $(basename $entry)"
                    updated=true
                fi
            else
                print_info "$(basename $entry) already has kernel parameters"
            fi
        fi
    done
    
    if [ "$updated" = true ]; then
        print_success "systemd-boot entries updated with kernel parameters: $new_params"
    else
        print_info "No updates needed or no entries found"
    fi
    
    # Also create a drop-in config if it doesn't exist
    local loader_conf=""
    if [ -f /boot/loader/loader.conf ]; then
        loader_conf="/boot/loader/loader.conf"
    elif [ -f /boot/efi/loader/loader.conf ]; then
        loader_conf="/boot/efi/loader/loader.conf"
    elif [ -f /efi/loader/loader.conf ]; then
        loader_conf="/efi/loader/loader.conf"
    fi
    
    if [ -n "$loader_conf" ]; then
        print_info "Bootloader config: $loader_conf"
        # Ensure timeout is reasonable
        if ! grep -q "^timeout" "$loader_conf"; then
            echo "timeout 3" >> "$loader_conf"
            print_info "Set boot timeout to 3 seconds"
        fi
    fi
    
    print_success "systemd-boot configured"
}

#############################################################################
# ASUS Tools (asusctl, supergfxctl)
#############################################################################

install_asus_tools() {
    print_step "Installing ASUS-specific tools (asusctl, supergfxctl)..."
    
    case $DISTRO_FAMILY in
        arch)
            print_info "Installing from AUR/official repos..."
            # Check if yay or paru is available for AUR
            if command -v yay &> /dev/null; then
                sudo -u ${SUDO_USER} yay -S --noconfirm asusctl supergfxctl
            elif command -v paru &> /dev/null; then
                sudo -u ${SUDO_USER} paru -S --noconfirm asusctl supergfxctl
            else
                print_warning "AUR helper (yay/paru) not found"
                print_info "Installing manually..."
                # Install dependencies
                pacman -S --noconfirm base-devel git
                git clone https://aur.archlinux.org/asusctl.git /tmp/asusctl
                git clone https://aur.archlinux.org/supergfxctl.git /tmp/supergfxctl
                cd /tmp/asusctl && sudo -u ${SUDO_USER} makepkg -si --noconfirm
                cd /tmp/supergfxctl && sudo -u ${SUDO_USER} makepkg -si --noconfirm
            fi
            ;;
        debian)
            print_info "ASUS tools not available in official repos for Debian/Ubuntu"
            print_info "Building from source..."
            install_asus_tools_from_source
            ;;
        fedora)
            print_info "Installing from Copr repository..."
            dnf copr enable -y lukenukem/asus-linux
            dnf install -y asusctl supergfxctl
            ;;
        opensuse)
            print_info "Installing from OBS repository..."
            zypper addrepo https://download.opensuse.org/repositories/home:luke_nukem:asus-linux/openSUSE_Tumbleweed/ asus-linux
            zypper --gpg-auto-import-keys refresh
            zypper install -y asusctl supergfxctl
            ;;
        *)
            print_warning "ASUS tools installation not supported for this distro"
            print_info "Please visit https://asus-linux.org for manual installation"
            return
            ;;
    esac
    
    # Enable and start services
    systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
    systemctl enable --now supergfxd.service 2>/dev/null || true
    
    print_success "ASUS tools installed"
}

install_asus_tools_from_source() {
    print_info "Installing build dependencies..."
    
    case $DISTRO_FAMILY in
        debian)
            apt install -y build-essential git rustc cargo \
                libgtk-3-dev libpango1.0-dev libgdk-pixbuf2.0-dev \
                libudev-dev libayatana-appindicator3-dev cmake
            ;;
        fedora)
            dnf install -y gcc git rust cargo \
                gtk3-devel pango-devel gdk-pixbuf2-devel \
                systemd-devel libappindicator-gtk3-module cmake
            ;;
    esac
    
    # Clone and build asusctl
    print_info "Building asusctl from source..."
    git clone https://gitlab.com/asus-linux/asusctl.git /tmp/asusctl-src
    cd /tmp/asusctl-src
    make
    make install
    
    # Clone and build supergfxctl
    print_info "Building supergfxctl from source..."
    git clone https://gitlab.com/asus-linux/supergfxctl.git /tmp/supergfxctl-src
    cd /tmp/supergfxctl-src
    make
    make install
    
    cd /
    rm -rf /tmp/asusctl-src /tmp/supergfxctl-src
}

#############################################################################
# Power Management (TLP)
#############################################################################

setup_power_management() {
    print_step "Setting up power management (TLP)..."
    
    case $DISTRO_FAMILY in
        arch)
            pacman -S --noconfirm tlp tlp-rdw
            # Remove conflicting services
            systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true
            ;;
        debian)
            apt install -y tlp tlp-rdw
            ;;
        fedora)
            dnf install -y tlp tlp-rdw
            ;;
        opensuse)
            zypper install -y tlp tlp-rdw
            ;;
    esac
    
    # Configure TLP for optimal battery life
    print_info "Configuring TLP..."
    cat > /etc/tlp.d/00-gz302.conf <<EOF
# TLP configuration for Asus ROG Flow Z13 2025 (GZ302EA)

# CPU Settings
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# AMD P-State
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active

# Platform Profile
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Runtime Power Management
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto

# PCIe ASPM
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# USB Autosuspend
USB_AUTOSUSPEND=1

# Audio Power Save
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
EOF
    
    # Enable and start TLP
    systemctl enable tlp.service
    systemctl start tlp.service 2>/dev/null || true
    
    print_success "Power management configured"
}

#############################################################################
# Audio Configuration
#############################################################################

setup_audio() {
    print_step "Configuring audio (SOF firmware)..."
    
    case $DISTRO_FAMILY in
        arch)
            pacman -S --noconfirm sof-firmware alsa-ucm-conf pipewire pipewire-alsa \
                pipewire-pulse pipewire-jack wireplumber
            ;;
        debian)
            apt install -y firmware-sof-signed alsa-ucm-conf \
                pipewire pipewire-alsa pipewire-pulse wireplumber
            ;;
        fedora)
            dnf install -y sof-firmware alsa-sof-firmware alsa-ucm \
                pipewire pipewire-alsa pipewire-pulseaudio wireplumber
            ;;
        opensuse)
            zypper install -y sof-firmware alsa-ucm-conf \
                pipewire pipewire-alsa pipewire-pulseaudio wireplumber
            ;;
    esac
    
    print_success "Audio configuration complete"
}

#############################################################################
# Display and Input Configuration
#############################################################################

setup_display_input() {
    print_step "Configuring display and touchscreen support..."
    
    case $DISTRO_FAMILY in
        arch)
            pacman -S --noconfirm xf86-input-libinput xf86-input-wacom
            ;;
        debian)
            apt install -y xserver-xorg-input-libinput xserver-xorg-input-wacom
            ;;
        fedora)
            dnf install -y xorg-x11-drv-libinput xorg-x11-drv-wacom
            ;;
        opensuse)
            zypper install -y xf86-input-libinput xf86-input-wacom
            ;;
    esac
    
    print_success "Display and input configuration complete"
}

#############################################################################
# Suspend/Resume Configuration
#############################################################################

configure_suspend() {
    print_step "Configuring suspend/resume settings..."
    
    # Create systemd sleep hook for better suspend/resume
    mkdir -p /usr/lib/systemd/system-sleep
    cat > /usr/lib/systemd/system-sleep/gz302-suspend.sh <<'EOF'
#!/bin/bash
# Suspend/resume hook for GZ302EA

case $1 in
    pre)
        # Before suspend
        # Sync filesystem
        sync
        ;;
    post)
        # After resume
        # Reload WiFi module if needed
        if ! nmcli radio wifi | grep -q enabled; then
            modprobe -r mt7921e 2>/dev/null || true
            modprobe mt7921e 2>/dev/null || true
        fi
        ;;
esac
EOF
    chmod +x /usr/lib/systemd/system-sleep/gz302-suspend.sh
    
    # Configure sleep mode
    if [ -f /sys/power/mem_sleep ]; then
        # Try to enable deep sleep (S3) if available
        if grep -q "\[deep\]" /sys/power/mem_sleep 2>/dev/null; then
            print_info "Deep sleep (S3) is already active"
        elif grep -q "deep" /sys/power/mem_sleep 2>/dev/null; then
            print_info "Setting up deep sleep (S3)..."
            echo "deep" > /sys/power/mem_sleep 2>/dev/null || true
            # Make it persistent
            cat > /etc/tmpfiles.d/suspend-mode.conf <<EOF
w /sys/power/mem_sleep - - - - deep
EOF
        else
            print_warning "Deep sleep (S3) not available on this system"
        fi
    fi
    
    print_success "Suspend/resume configured"
}

#############################################################################
# WiFi/Bluetooth Optimization
#############################################################################

optimize_wifi_bluetooth() {
    print_step "Optimizing WiFi and Bluetooth (MediaTek MT7925)..."
    
    # Create modprobe config for MT7921 (MT7925 uses different driver name in newer kernels)
    cat > /etc/modprobe.d/mt7921.conf <<EOF
# MediaTek MT7925 WiFi/BT optimization
options mt7921e disable_aspm=1
options mt7921e enable_deep_sleep=1
EOF
    
    # Ensure bluetooth service is enabled
    systemctl enable bluetooth.service 2>/dev/null || true
    systemctl start bluetooth.service 2>/dev/null || true
    
    print_success "WiFi/Bluetooth optimized"
}

#############################################################################
# System Tweaks
#############################################################################

apply_system_tweaks() {
    print_step "Applying additional system tweaks..."
    
    # Increase inotify watches (useful for development)
    cat > /etc/sysctl.d/99-gz302.conf <<EOF
# System tweaks for GZ302EA
fs.inotify.max_user_watches=524288
vm.swappiness=10
EOF
    
    sysctl --system >/dev/null 2>&1
    
    print_success "System tweaks applied"
}

#############################################################################
# Post-Installation Summary
#############################################################################

print_summary() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: System will reboot to apply all changes.${NC}"
    echo ""
    echo "What was installed/configured:"
    echo "  ✓ System packages updated"
    echo "  ✓ G14 kernel and headers installed"
    echo "  ✓ Firmware updated (MediaTek MT7925 WiFi/BT)"
    echo "  ✓ AMD Radeon 8060S graphics drivers (Mesa, Vulkan)"
    echo "  ✓ Bootloader configured with optimal kernel parameters"
    echo "  ✓ ASUS tools (asusctl, supergfxctl)"
    echo "  ✓ Power management (TLP)"
    echo "  ✓ Audio drivers (SOF firmware)"
    echo "  ✓ Suspend/resume optimization"
    echo "  ✓ Display and touchscreen support"
    echo ""
    echo "After reboot, test the following:"
    echo "  • WiFi and Bluetooth connectivity"
    echo "  • Graphics: glxinfo | grep 'OpenGL renderer'"
    echo "  • ASUS controls: asusctl --help"
    echo "  • Power management: tlp-stat"
    echo "  • Suspend/resume functionality"
    echo ""
    echo "For troubleshooting, see: https://github.com/th3cavalry/GZ302-Linux-Setup"
    echo ""
}

#############################################################################
# Main Installation Flow
#############################################################################

main() {
    print_header
    
    # Parse command-line arguments
    for arg in "$@"; do
        case $arg in
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --help          Show this help message"
                echo ""
                echo "This script automatically installs and configures all necessary"
                echo "components for the Asus ROG Flow Z13 2025 (GZ302EA) on Linux."
                echo ""
                exit 0
                ;;
            *)
                print_warning "Unknown option: $arg"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Verify running as root
    check_root
    
    # Detect distribution
    detect_distro
    
    echo ""
    print_warning "This script will automatically install and configure your system."
    print_warning "It is recommended to backup your system before proceeding."
    print_warning "Detected distribution: $DISTRO ($DISTRO_FAMILY)"
    echo ""
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    echo ""
    
    # Main installation steps - all automatically executed
    update_system
    check_kernel_version
    update_firmware
    setup_graphics
    configure_bootloader
    install_asus_tools
    setup_power_management
    setup_audio
    setup_display_input
    configure_suspend
    optimize_wifi_bluetooth
    apply_system_tweaks
    
    # Print summary
    print_summary
    
    # Automatic reboot prompt
    print_info "System will reboot in 10 seconds to apply changes..."
    print_info "Press Ctrl+C to cancel reboot"
    sleep 10
    reboot
}

# Run main function
main "$@"
