#!/bin/bash

#############################################################################
# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script
# Version: 1.3.0
# 
# Comprehensive post-installation setup for GZ302EA models:
# - GZ302EA-XS99 (128GB)
# - GZ302EA-XS64 (64GB)
# - GZ302EA-XS32 (32GB)
#
# Supports: Arch, Debian/Ubuntu, Fedora, openSUSE, and other major distros
#############################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.3.0"

# Configuration flags (set by command-line arguments)
KERNEL_MODE="auto"          # auto, native, or g14
POWER_BACKEND="tlp"         # tlp or ppd (power-profiles-daemon)
NO_REBOOT=false
DRY_RUN=false
LOG_FILE="/var/log/gz302-setup.log"

# Distro detection
DISTRO=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""

# Track what was actually done
INSTALLED_G14_KERNEL=false
INSTALLED_POWER_MGMT=""

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

# Setup logging (call after argument parsing)
setup_logging() {
    if [ "$DRY_RUN" = false ]; then
        # Create log directory if needed
        mkdir -p "$(dirname "$LOG_FILE")"
        # Redirect stdout and stderr to log file and console
        exec > >(tee -a "$LOG_FILE") 2>&1
        echo "=== GZ302 Setup Script v$VERSION - $(date) ===" >> "$LOG_FILE"
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

show_help() {
    cat <<EOF
Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script v$VERSION

Usage: $0 [OPTIONS]

Options:
  --help                Show this help message
  --kernel MODE         Kernel installation mode (default: auto)
                        - auto: Install g14 kernel only if Arch + kernel < 6.6
                        - g14: Force install g14 kernel
                        - native: Use native/distribution kernel only
  --no-kernel           Shortcut for --kernel native
  --power BACKEND       Power management backend (default: tlp)
                        - tlp: Install and enable TLP
                        - ppd: Use power-profiles-daemon
  --no-reboot           Don't reboot after installation (prompt user)
  --dry-run             Show planned actions without making changes
  --log FILE            Log file location (default: /var/log/gz302-setup.log)

Examples:
  # Default: Auto-detect kernel need, use TLP, reboot after
  sudo $0

  # Force native kernel and use power-profiles-daemon
  sudo $0 --no-kernel --power ppd

  # Install g14 kernel and see what would happen (dry-run)
  sudo $0 --kernel g14 --dry-run

  # Custom log location and no automatic reboot
  sudo $0 --log /tmp/setup.log --no-reboot

Note: On modern kernels (>= 6.6), the linux-g14 kernel is typically not required
for basic hardware support. It may still offer ROG-specific optimizations.

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                ;;
            --kernel)
                shift
                if [[ $# -eq 0 ]]; then
                    print_error "--kernel requires an argument (auto, g14, or native)"
                    exit 1
                fi
                case $1 in
                    auto|g14|native)
                        KERNEL_MODE="$1"
                        ;;
                    *)
                        print_error "Invalid kernel mode: $1 (must be auto, g14, or native)"
                        exit 1
                        ;;
                esac
                shift
                ;;
            --no-kernel)
                KERNEL_MODE="native"
                shift
                ;;
            --power)
                shift
                if [[ $# -eq 0 ]]; then
                    print_error "--power requires an argument (tlp or ppd)"
                    exit 1
                fi
                case $1 in
                    tlp|ppd)
                        POWER_BACKEND="$1"
                        ;;
                    *)
                        print_error "Invalid power backend: $1 (must be tlp or ppd)"
                        exit 1
                        ;;
                esac
                shift
                ;;
            --no-reboot)
                NO_REBOOT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --log)
                shift
                if [[ $# -eq 0 ]]; then
                    print_error "--log requires a file path"
                    exit 1
                fi
                LOG_FILE="$1"
                shift
                ;;
            *)
                print_warning "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would update system packages using $PACKAGE_MANAGER"
        return
    fi
    
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
    
    # Determine if g14 kernel should be installed
    local should_install_g14=false
    
    case $KERNEL_MODE in
        native)
            print_info "Kernel mode: native (skipping g14 kernel installation)"
            ;;
        g14)
            print_info "Kernel mode: g14 (forcing g14 kernel installation)"
            should_install_g14=true
            ;;
        auto)
            print_info "Kernel mode: auto (checking if g14 kernel is needed)"
            # Only install g14 on Arch with kernel < 6.6
            if [ "$DISTRO_FAMILY" = "arch" ]; then
                if [ "$kernel_major" -lt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -lt 6 ]); then
                    print_warning "Kernel version < 6.6 detected on Arch. G14 kernel recommended for hardware support."
                    should_install_g14=true
                else
                    print_success "Kernel version >= 6.6. Native kernel provides adequate support."
                    print_info "Note: G14 kernel can still be installed with --kernel g14 for ROG-specific optimizations."
                fi
            else
                print_info "Non-Arch distribution detected. Using native kernel."
            fi
            ;;
    esac
    
    if [ "$should_install_g14" = true ]; then
        install_g14_kernel
    fi
}

install_g14_kernel() {
    print_step "Installing g14 kernel and headers..."
    
    # Validate SUDO_USER for AUR builds
    if [ "$DISTRO_FAMILY" = "arch" ] && [ -z "${SUDO_USER:-}" ]; then
        print_warning "SUDO_USER not set. Script may have been run directly as root."
        print_warning "AUR packages cannot be built as root. Falling back to native kernel."
        print_info "To install g14 kernel, run this script with sudo from a regular user account."
        return
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install g14 kernel for $DISTRO_FAMILY"
        INSTALLED_G14_KERNEL=true
        return
    fi
    
    case $DISTRO_FAMILY in
        arch)
            print_info "Installing linux-g14 kernel from AUR..."
            # Check if yay or paru is available for AUR
            if command -v yay &> /dev/null; then
                sudo -u ${SUDO_USER} yay -S --noconfirm linux-g14 linux-g14-headers
                INSTALLED_G14_KERNEL=true
            elif command -v paru &> /dev/null; then
                sudo -u ${SUDO_USER} paru -S --noconfirm linux-g14 linux-g14-headers
                INSTALLED_G14_KERNEL=true
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
                INSTALLED_G14_KERNEL=true
            fi
            print_success "G14 kernel installation complete. Reboot required."
            ;;
        debian|ubuntu)
            print_info "For Debian/Ubuntu, g14 kernel is not available as a package."
            print_info "Installing latest available kernel..."
            apt install -y linux-image-generic linux-headers-generic
            print_warning "For ROG-specific optimizations, consider using Arch Linux with g14 kernel."
            ;;
        fedora)
            print_info "Installing latest kernel with development headers..."
            dnf install -y kernel kernel-devel kernel-headers
            print_info "G14 kernel is primarily available for Arch. Using native kernel."
            ;;
        opensuse)
            print_info "Installing latest kernel..."
            zypper install -y kernel-default kernel-default-devel
            print_info "G14 kernel is primarily available for Arch. Using native kernel."
            ;;
    esac
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would update linux-firmware package"
        return
    fi
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install Mesa and Vulkan drivers for $DISTRO_FAMILY"
        print_info "[DRY RUN] Would configure AMDGPU module with audio=1"
        return
    fi
    
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
    
    # Configure AMDGPU module options (only relevant modern options)
    print_info "Configuring AMDGPU module options..."
    cat > /etc/modprobe.d/amdgpu.conf <<EOF
# AMDGPU configuration for AMD Strix Halo (Radeon 8060S)
# Note: Legacy si_support and cik_support options removed (not needed for modern GPUs)
options amdgpu dpm=1
options amdgpu audio=1
EOF
    
    print_success "Graphics drivers configured"
}

#############################################################################
# Bootloader Configuration (GRUB and systemd-boot)
#############################################################################

# Helper function to add kernel parameters idempotently
add_kernel_params_idempotent() {
    local existing_params="$1"
    local new_params="$2"
    
    # Split new_params into array
    local params_to_add=()
    for param in $new_params; do
        # Check if parameter already exists
        if ! echo "$existing_params" | grep -q "\b$param\b"; then
            params_to_add+=("$param")
        fi
    done
    
    # Return the combined result
    if [ ${#params_to_add[@]} -gt 0 ]; then
        echo "$existing_params ${params_to_add[*]}"
    else
        echo "$existing_params"
    fi
}

configure_bootloader() {
    print_step "Configuring bootloader parameters..."
    
    # Kernel parameters for AMD Strix Halo and GZ302EA
    # Removed legacy amdgpu.si_support and amdgpu.cik_support (not needed for modern GPUs)
    local new_params="iommu=pt amd_pstate=active"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would add kernel parameters: $new_params"
        return
    fi
    
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
    cp /etc/default/grub "/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Get current parameters
    local current_params=""
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
        current_params=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')
    fi
    
    # Add parameters idempotently
    local updated_params=$(add_kernel_params_idempotent "$current_params" "$new_params")
    
    if [ "$current_params" != "$updated_params" ]; then
        # Update GRUB config with new parameters
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_params\"|" /etc/default/grub
        print_info "Added kernel parameters: $new_params"
    else
        print_info "Kernel parameters already configured"
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
            
            # Get current options line
            local current_opts=""
            if grep -q "^options " "$entry"; then
                current_opts=$(grep "^options " "$entry" | sed 's/^options //')
            fi
            
            # Add parameters idempotently
            local updated_opts=$(add_kernel_params_idempotent "$current_opts" "$new_params")
            
            if [ "$current_opts" != "$updated_opts" ]; then
                sed -i "s|^options .*|options $updated_opts|" "$entry"
                print_info "Updated $(basename $entry)"
                updated=true
            else
                print_info "$(basename $entry) already has kernel parameters"
            fi
        fi
    done
    
    if [ "$updated" = true ]; then
        print_success "systemd-boot entries updated with kernel parameters: $new_params"
    else
        print_info "No updates needed"
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install asusctl and supergfxctl for $DISTRO_FAMILY"
        return
    fi
    
    case $DISTRO_FAMILY in
        arch)
            print_info "Adding Asus Linux repository..."
            # Add the g14 repository to pacman.conf if not already present
            if ! grep -q "\[g14\]" /etc/pacman.conf; then
                print_info "Adding [g14] repository to /etc/pacman.conf"
                cat >> /etc/pacman.conf <<EOF

[g14]
Server = https://asus-linux.org/packages/\$arch
EOF
                # TODO: Import and verify GPG key for g14 repository for added security
            else
                print_info "[g14] repository already configured"
            fi
            
            # Update package database and install
            print_info "Installing asusctl and supergfxctl from official repository..."
            pacman -Sy --noconfirm asusctl supergfxctl
            ;;
        debian)
            print_info "Adding Asus Linux PPA for Debian/Ubuntu..."
            
            # Create keyrings directory
            mkdir -p /usr/local/share/keyrings
            
            # Add GPG key
            print_info "Adding GPG key..."
            curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1d4f9ce6e1492b69c43e95a3d60afa41a606bc01" | \
                gpg --batch --yes --dearmor --output "/usr/local/share/keyrings/asusctl-ma-keyring.gpg"
            
            # Detect Ubuntu version for correct repository
            local ubuntu_version=""
            if [ -f /etc/lsb-release ]; then
                . /etc/lsb-release
                case "$DISTRIB_RELEASE" in
                    24.10) ubuntu_version="oracular" ;;
                    24.04) ubuntu_version="noble" ;;
                    23.10) ubuntu_version="mantic" ;;
                    23.04) ubuntu_version="lunar" ;;
                    22.04) ubuntu_version="jammy" ;;
                    *) ubuntu_version="noble" ;;  # Default to latest LTS
                esac
            else
                ubuntu_version="noble"  # Default to Ubuntu 24.04
            fi
            
            print_info "Using repository for Ubuntu $ubuntu_version"
            
            # Add repository
            echo "deb [signed-by=/usr/local/share/keyrings/asusctl-ma-keyring.gpg] https://ppa.launchpadcontent.net/mitchellaugustin/asusctl/ubuntu $ubuntu_version main" | \
                tee /etc/apt/sources.list.d/asusctl.list
            
            # Update and install
            print_info "Installing asusctl and supergfxctl..."
            apt update
            apt install -y asusctl supergfxctl
            
            # Reload daemon and restart service
            systemctl daemon-reload
            systemctl restart asusd 2>/dev/null || true
            ;;
        fedora)
            print_info "Adding Asus Linux Copr repository..."
            dnf copr enable -y lukenukem/asus-linux
            
            print_info "Installing asusctl and supergfxctl..."
            dnf update --refresh -y
            dnf install -y asusctl supergfxctl
            ;;
        opensuse)
            print_info "Adding Asus Linux OBS repository..."
            
            # Detect openSUSE version
            local opensuse_version="openSUSE_Tumbleweed"
            if grep -q "Leap" /etc/os-release; then
                opensuse_version="openSUSE_Leap_15.5"
            fi
            
            print_info "Using repository for $opensuse_version"
            
            zypper addrepo -f "https://download.opensuse.org/repositories/home:luke_nukem:asus-linux/$opensuse_version/" asus-linux
            zypper --gpg-auto-import-keys refresh
            
            print_info "Installing asusctl and supergfxctl..."
            zypper install -y asusctl supergfxctl
            ;;
        *)
            print_warning "ASUS tools installation not supported for this distro"
            print_info "Please visit https://asus-linux.org for manual installation"
            return
            ;;
    esac
    
    # Enable and start services (but handle power-profiles-daemon separately)
    print_info "Enabling ASUS services..."
    systemctl enable --now asusd.service 2>/dev/null || true
    systemctl enable --now supergfxd.service 2>/dev/null || true
    
    # Note: power-profiles-daemon will be handled in setup_power_management based on user choice
    
    print_success "ASUS tools installed from official repositories"
}

#############################################################################
# Power Management (TLP or power-profiles-daemon)
#############################################################################

setup_power_management() {
    print_step "Setting up power management ($POWER_BACKEND)..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would configure power management with $POWER_BACKEND"
        return
    fi
    
    if [ "$POWER_BACKEND" = "tlp" ]; then
        print_info "Installing and configuring TLP..."
        
        # Ensure power-profiles-daemon is disabled/masked to avoid conflicts
        print_info "Disabling power-profiles-daemon to avoid conflicts with TLP..."
        systemctl stop power-profiles-daemon.service 2>/dev/null || true
        systemctl disable power-profiles-daemon.service 2>/dev/null || true
        systemctl mask power-profiles-daemon.service 2>/dev/null || true
        
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
        
        INSTALLED_POWER_MGMT="TLP"
        print_success "TLP power management configured"
        
    elif [ "$POWER_BACKEND" = "ppd" ]; then
        print_info "Using power-profiles-daemon..."
        
        # Ensure TLP is disabled if installed
        if systemctl list-unit-files | grep -q tlp.service; then
            print_info "Disabling TLP to avoid conflicts with power-profiles-daemon..."
            systemctl stop tlp.service 2>/dev/null || true
            systemctl disable tlp.service 2>/dev/null || true
            systemctl mask tlp.service 2>/dev/null || true
        fi
        
        # power-profiles-daemon should already be installed by the distro or asusctl dependencies
        # Just ensure it's enabled
        systemctl unmask power-profiles-daemon.service 2>/dev/null || true
        systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
        
        INSTALLED_POWER_MGMT="power-profiles-daemon"
        print_success "power-profiles-daemon configured"
    fi
}

#############################################################################
# Audio Configuration
#############################################################################

setup_audio() {
    print_step "Configuring audio (SOF firmware)..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install audio packages (SOF firmware, PipeWire/PulseAudio)"
        return
    fi
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install display/input packages (libinput, wacom)"
        return
    fi
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would create systemd sleep hooks and configure S3 sleep mode"
        return
    fi
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would create MT7921 modprobe config and enable bluetooth service"
        return
    fi
    
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
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would apply sysctl tweaks (inotify, swappiness)"
        return
    fi
    
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
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}  Dry Run Complete!${NC}"
    else
        echo -e "${GREEN}  Installation Complete!${NC}"
    fi
    echo -e "${GREEN}================================================${NC}"
    echo ""
    
    if [ "$DRY_RUN" = false ] && [ "$NO_REBOOT" = false ]; then
        echo -e "${YELLOW}IMPORTANT: System will reboot to apply all changes.${NC}"
        echo ""
    fi
    
    echo "What was installed/configured:"
    echo "  ✓ System packages updated"
    
    # Kernel installation status
    if [ "$INSTALLED_G14_KERNEL" = true ]; then
        echo "  ✓ G14 kernel and headers installed"
    else
        echo "  ✓ Using native kernel (g14 kernel not installed)"
    fi
    
    echo "  ✓ Firmware updated (MediaTek MT7925 WiFi/BT)"
    echo "  ✓ AMD Radeon 8060S graphics drivers (Mesa, Vulkan)"
    echo "  ✓ Bootloader configured with kernel parameters (iommu=pt, amd_pstate=active)"
    echo "  ✓ ASUS tools (asusctl, supergfxctl)"
    
    # Power management status
    if [ -n "$INSTALLED_POWER_MGMT" ]; then
        echo "  ✓ Power management ($INSTALLED_POWER_MGMT)"
    else
        echo "  ✓ Power management (${POWER_BACKEND})"
    fi
    
    echo "  ✓ Audio drivers (SOF firmware, PipeWire)"
    echo "  ✓ Suspend/resume optimization"
    echo "  ✓ Display and touchscreen support"
    echo ""
    
    if [ "$DRY_RUN" = false ]; then
        echo "After reboot, test the following:"
        echo "  • WiFi and Bluetooth connectivity"
        echo "  • Graphics: glxinfo | grep 'OpenGL renderer'"
        echo "  • ASUS controls: asusctl --help"
        if [ "$POWER_BACKEND" = "tlp" ]; then
            echo "  • Power management: tlp-stat"
        else
            echo "  • Power management: powerprofilesctl status"
        fi
        echo "  • Suspend/resume functionality"
        echo ""
        echo "For troubleshooting, see: https://github.com/th3cavalry/GZ302-Linux-Setup"
        echo ""
        
        if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/var/log/gz302-setup.log" ]; then
            echo "Log file: $LOG_FILE"
            echo ""
        fi
    fi
}

#############################################################################
# Main Installation Flow
#############################################################################

main() {
    # Parse command-line arguments FIRST (before printing header)
    parse_arguments "$@"
    
    print_header
    
    # Verify running as root
    check_root
    
    # Setup logging (after parsing args, before other operations)
    setup_logging
    
    # Detect distribution
    detect_distro
    
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made to the system"
        echo ""
    fi
    
    print_info "Configuration:"
    print_info "  Kernel mode: $KERNEL_MODE"
    print_info "  Power backend: $POWER_BACKEND"
    print_info "  Auto-reboot: $([ "$NO_REBOOT" = true ] && echo "disabled" || echo "enabled")"
    if [ "$DRY_RUN" = false ]; then
        print_info "  Log file: $LOG_FILE"
    fi
    echo ""
    
    if [ "$DRY_RUN" = false ]; then
        print_warning "This script will install and configure your system."
        print_warning "It is recommended to backup your system before proceeding."
        print_warning "Detected distribution: $DISTRO ($DISTRO_FAMILY)"
        echo ""
        
        read -r -p "Press Enter to continue or Ctrl+C to cancel..."
        echo ""
    fi
    
    # Main installation steps
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
    
    # Handle reboot
    if [ "$DRY_RUN" = false ]; then
        if [ "$NO_REBOOT" = true ]; then
            echo ""
            print_warning "Reboot disabled. Please reboot manually to apply all changes."
            print_info "Run: sudo reboot"
        else
            echo ""
            read -p "Reboot now to apply changes? [Y/n] " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                print_info "Rebooting in 5 seconds..."
                sleep 5
                reboot
            else
                print_info "Reboot cancelled. Please reboot manually when ready."
            fi
        fi
    fi
}

# Run main function
main "$@"
