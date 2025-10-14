#!/bin/bash

#############################################################################
# Asus ROG Flow Z13 2025 (GZ302EA) Linux Setup Script
# Version: 1.4.0
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
VERSION="1.4.0"

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
print_step() { echo -e "${GREEN}==>${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

check_root() { if [ "$EUID" -ne 0 ]; then print_error "This script must be run as root (use sudo)"; exit 1; fi; }

#############################################################################
# Distro Detection
#############################################################################
detect_distro() {
    print_step "Detecting Linux distribution..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        case $ID in
            arch|manjaro|endeavouros|garuda) DISTRO_FAMILY="arch"; PACKAGE_MANAGER="pacman" ;;
            ubuntu|debian|mint|pop|elementary|zorin|linuxmint) DISTRO_FAMILY="debian"; PACKAGE_MANAGER="apt" ;;
            fedora|nobara) DISTRO_FAMILY="fedora"; PACKAGE_MANAGER="dnf" ;;
            opensuse-leap|opensuse-tumbleweed|opensuse) DISTRO_FAMILY="opensuse"; PACKAGE_MANAGER="zypper" ;;
            gentoo) DISTRO_FAMILY="gentoo"; PACKAGE_MANAGER="emerge" ;;
            void) DISTRO_FAMILY="void"; PACKAGE_MANAGER="xbps-install" ;;
            *)
                print_warning "Unknown distribution: $ID"
                print_warning "Attempting to detect package manager..."
                if command -v pacman &>/dev/null; then DISTRO_FAMILY="arch"; PACKAGE_MANAGER="pacman";
                elif command -v apt &>/dev/null; then DISTRO_FAMILY="debian"; PACKAGE_MANAGER="apt";
                elif command -v dnf &>/dev/null; then DISTRO_FAMILY="fedora"; PACKAGE_MANAGER="dnf";
                elif command -v zypper &>/dev/null; then DISTRO_FAMILY="opensuse"; PACKAGE_MANAGER="zypper";
                else print_error "Could not detect supported package manager"; exit 1; fi ;;
        esac
    else
        print_error "/etc/os-release not found"; exit 1
    fi
    print_info "Detected: $DISTRO ($DISTRO_FAMILY) using $PACKAGE_MANAGER"
}

#############################################################################
# System Updates
#############################################################################
update_system() {
    print_step "Updating system packages..."
    case $DISTRO_FAMILY in
        arch) pacman -Syu --noconfirm ;; 
        debian) apt update && apt upgrade -y ;; 
        fedora) dnf upgrade -y ;; 
        opensuse) zypper refresh && zypper update -y ;; 
        gentoo) emerge --sync && emerge -uDN @world ;; 
        void) xbps-install -Su ;; 
    esac
    print_success "System updated"
}

#############################################################################
# Kernel Handling
#############################################################################
check_kernel_version() {
    print_step "Checking kernel version..."
    local kfull=$(uname -r)
    local kbase=$(echo "$kfull" | cut -d. -f1,2)
    local kmajor=$(echo $kbase | cut -d. -f1)
    local kminor=$(echo $kbase | cut -d. -f2)
    print_info "Current kernel: $kfull"
    
    # Update kernel if older than 6.15 (required for Radeon 8060S optimal support)
    if [ "$kmajor" -lt 6 ] || { [ "$kmajor" -eq 6 ] && [ "$kminor" -lt 15 ]; }; then
        print_warning "Kernel < 6.15 detected. Updating to latest distro kernel for optimal Radeon 8060S support."
        update_kernel_generic
    else
        print_success "Kernel is modern (>=6.15)."
    fi
}

update_kernel_generic() {
    print_step "Updating kernel via distro packages..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm linux linux-headers ;; 
        debian) apt install -y linux-image-generic linux-headers-generic ;; 
        fedora) dnf install -y kernel kernel-devel kernel-headers ;; 
        opensuse) zypper install -y kernel-default kernel-default-devel ;; 
        gentoo) emerge -uD @world ;; 
        void) xbps-install -y linux ;; 
    esac
    print_success "Distro kernel ensured"
}

#############################################################################
# Firmware Updates
#############################################################################
update_firmware() {
    print_step "Updating system firmware (linux-firmware)..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm linux-firmware linux-firmware-whence amd-ucode sof-firmware alsa-firmware ;; 
        debian)
            apt install -y linux-firmware || true
            apt install -y amd64-microcode sof-firmware alsa-firmware || true
            if apt-cache search firmware-linux-nonfree | grep -q firmware-linux-nonfree; then
                apt install -y firmware-linux-nonfree
            fi ;; 
        fedora) dnf install -y linux-firmware amd-ucode-firmware sof-firmware alsa-firmware ;; 
        opensuse) zypper install -y kernel-firmware ucode-amd sof-firmware alsa-firmware ;; 
        void) xbps-install -y linux-firmware void-repo-nonfree && xbps-install -y amd-ucode ;; 
    esac
    print_success "Firmware updated (includes MediaTek MT7925 WiFi/BT, AMD microcode, and audio firmware)"
}

#############################################################################
# Graphics Setup (AMDGPU, Mesa, Vulkan)
#############################################################################
setup_graphics() {
    print_step "Setting up graphics (Mesa / Vulkan)..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader mesa-utils vulkan-tools xf86-video-amdgpu ;; 
        debian) apt install -y mesa-vulkan-drivers mesa-utils vulkan-tools libvulkan1 mesa-va-drivers mesa-vdpau-drivers xserver-xorg-video-amdgpu && (dpkg --add-architecture i386 2>/dev/null || true; apt update || true; apt install -y mesa-vulkan-drivers:i386 libvulkan1:i386 || true) ;; 
        fedora) dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools mesa-libGL mesa-libEGL libva-mesa-driver mesa-vdpau-drivers xorg-x11-drv-amdgpu ;; 
        opensuse) zypper install -y Mesa-dri Mesa-vulkan-dri vulkan-tools Mesa-libGL1 Mesa-libEGL1 xf86-video-amdgpu ;; 
    esac
    print_info "Configuring AMDGPU module options for Radeon 8060S..."
    cat > /etc/modprobe.d/amdgpu.conf <<EOF
# AMDGPU configuration for GZ302EA with Radeon 8060S
options amdgpu dc=1
options amdgpu dpm=1
options amdgpu audio=1
options amdgpu gpu_recovery=1
options amdgpu runpm=1
EOF
    print_success "Graphics drivers configured"
}

#############################################################################
# Bootloader Configuration (GRUB and systemd-boot)
#############################################################################
configure_bootloader() {
    print_step "Configuring bootloader parameters..."
    local new_params="iommu=pt amd_pstate=active"
    if [ -f /etc/default/grub ]; then
        configure_grub "$new_params"
    elif [ -d /boot/loader/entries ] || [ -f /boot/efi/loader/loader.conf ] || [ -f /efi/loader/loader.conf ]; then
        configure_systemd_boot "$new_params"
    else
        print_warning "No supported bootloader detected (GRUB or systemd-boot). Add manually: $new_params"
    fi
}

configure_grub() {
    local new_params="$1"
    print_info "Detected GRUB bootloader"
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
        if ! grep -q "amd_pstate=active" /etc/default/grub; then
            sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params /" /etc/default/grub
            print_info "Added kernel parameters: $new_params"
        else
            print_info "Kernel parameters already present"
        fi
    fi
    print_info "Updating GRUB..."
    if command -v update-grub &>/dev/null; then update-grub;
    elif command -v grub-mkconfig &>/dev/null; then grub-mkconfig -o /boot/grub/grub.cfg;
    elif command -v grub2-mkconfig &>/dev/null; then grub2-mkconfig -o /boot/grub2/grub.cfg;
    else print_warning "Could not find GRUB update command"; fi
    print_success "GRUB configured"
}

configure_systemd_boot() {
    local new_params="$1"
    print_info "Detected systemd-boot"
    local entries_dir=""
    if [ -d /boot/loader/entries ]; then entries_dir="/boot/loader/entries";
    elif [ -d /boot/efi/loader/entries ]; then entries_dir="/boot/efi/loader/entries";
    elif [ -d /efi/loader/entries ]; then entries_dir="/efi/loader/entries"; else
        print_error "Cannot find systemd-boot entries directory"; return 1; fi
    local updated=false
    for entry in "$entries_dir"/*.conf; do
        [ -f "$entry" ] || continue
        cp "$entry" "$entry.backup.$(date +%Y%m%d_%H%M%S)"
        if ! grep -q "amd_pstate=active" "$entry"; then
            if grep -q "^options" "$entry"; then
                sed -i "s/^options /options $new_params /" "$entry"
                print_info "Updated $(basename "$entry")"
                updated=true
            fi
        else
            print_info "$(basename "$entry") already has parameters"
        fi
    done
    if [ "$updated" = true ]; then
        print_success "systemd-boot entries updated with: $new_params"
    else
        print_info "No entry updates needed"
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
            if ! grep -q "[g14]" /etc/pacman.conf; then
                print_info "Adding [g14] repo to pacman.conf"
                cat >> /etc/pacman.conf <<EOF

[g14]
Server = https://asus-linux.org/packages/$arch
EOF
            fi
            pacman -Sy --noconfirm asusctl supergfxctl ;; 
        debian)
            mkdir -p /usr/local/share/keyrings
            curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1d4f9ce6e1492b69c43e95a3d60afa41a606bc01" | \
                gpg --batch --yes --dearmor --output "/usr/local/share/keyrings/asusctl-ma-keyring.gpg"
            local ubuntu_version="noble"
            if [ -f /etc/lsb-release ]; then . /etc/lsb-release; case "$DISTRIB_RELEASE" in 24.10) ubuntu_version="oracular";; 24.04) ubuntu_version="noble";; 23.10) ubuntu_version="mantic";; 23.04) ubuntu_version="lunar";; 22.04) ubuntu_version="jammy";; esac; fi
            echo "deb [signed-by=/usr/local/share/keyrings/asusctl-ma-keyring.gpg] https://ppa.launchpadcontent.net/mitchellaugustin/asusctl/ubuntu $ubuntu_version main" > /etc/apt/sources.list.d/asusctl.list
            apt update && apt install -y asusctl supergfxctl
            systemctl daemon-reload
            systemctl restart asusd 2>/dev/null || true ;; 
        fedora)
            dnf copr enable -y lukenukem/asus-linux
            dnf update --refresh -y
            dnf install -y asusctl supergfxctl ;; 
        opensuse)
            local opensuse_version="openSUSE_Tumbleweed"
            if grep -q "Leap" /etc/os-release; then opensuse_version="openSUSE_Leap_15.5"; fi
            zypper addrepo -f "https://download.opensuse.org/repositories/home:luke_nukem:asus-linux/$opensuse_version/" asus-linux
            zypper --gpg-auto-import-keys refresh
            zypper install -y asusctl supergfxctl ;; 
        *) print_warning "ASUS tools installation not supported for this distro"; return ;; 
    esac
    print_info "Enabling ASUS services..."
    systemctl enable --now asusd.service 2>/dev/null || true
    systemctl enable --now supergfxd.service 2>/dev/null || true
    print_success "ASUS tools installed"
}

#############################################################################
# Power Management (TLP only)
#############################################################################
setup_power_management() {
    print_step "Setting up power management (TLP) ..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm tlp tlp-rdw ;; 
        debian) apt install -y tlp tlp-rdw ;; 
        fedora) dnf install -y tlp tlp-rdw ;; 
        opensuse) zypper install -y tlp tlp-rdw ;; 
    esac
    systemctl mask power-profiles-daemon.service 2>/dev/null || true
    print_info "Configuring TLP..."
    cat > /etc/tlp.d/00-gz302.conf <<EOF
# TLP configuration for Asus ROG Flow Z13 2025 (GZ302EA)
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave
USB_AUTOSUSPEND=1
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
EOF
    systemctl enable tlp.service
    systemctl start tlp.service 2>/dev/null || true
    print_success "Power management configured (TLP)"
}

#############################################################################
# Audio Configuration
#############################################################################
setup_audio() {
    print_step "Configuring audio (SOF firmware)..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm sof-firmware alsa-ucm-conf pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber ;; 
        debian) apt install -y firmware-sof-signed alsa-ucm-conf pipewire pipewire-alsa pipewire-pulse wireplumber ;; 
        fedora) dnf install -y sof-firmware alsa-sof-firmware alsa-ucm pipewire pipewire-alsa pipewire-pulseaudio wireplumber ;; 
        opensuse) zypper install -y sof-firmware alsa-ucm-conf pipewire pipewire-alsa pipewire-pulseaudio wireplumber ;; 
    esac
    print_success "Audio configuration complete"
}

#############################################################################
# Display & Input
#############################################################################
setup_display_input() {
    print_step "Configuring display and input..."
    case $DISTRO_FAMILY in
        arch) pacman -S --noconfirm xf86-input-libinput xf86-input-wacom ;; 
        debian) apt install -y xserver-xorg-input-libinput xserver-xorg-input-wacom ;; 
        fedora) dnf install -y xorg-x11-drv-libinput xorg-x11-drv-wacom ;; 
        opensuse) zypper install -y xf86-input-libinput xf86-input-wacom ;; 
    esac
    print_success "Display and input ready"
}

#############################################################################
# Suspend/Resume
#############################################################################
configure_suspend() {
    print_step "Configuring suspend/resume..."
    mkdir -p /usr/lib/systemd/system-sleep
    cat > /usr/lib/systemd/system-sleep/gz302-suspend.sh <<'EOF'
#!/bin/bash
case $1 in
  pre)
    sync
    ;;
  post)
    if ! nmcli radio wifi | grep -q enabled; then
      modprobe -r mt7921e 2>/dev/null || true
      modprobe mt7921e 2>/dev/null || true
    fi
    ;;
esac
EOF
    chmod +x /usr/lib/systemd/system-sleep/gz302-suspend.sh
    if [ -f /sys/power/mem_sleep ]; then
        if grep -q "[deep]" /sys/power/mem_sleep; then
            print_info "Deep sleep already active"
        elif grep -q "deep" /sys/power/mem_sleep; then
            echo deep > /sys/power/mem_sleep 2>/dev/null || true
            cat > /etc/tmpfiles.d/suspend-mode.conf <<EOF
w /sys/power/mem_sleep - - - - deep
EOF
            print_info "Deep sleep (S3) requested"
        else
            print_warning "Deep sleep not available"
        fi
    fi
    print_success "Suspend/resume configured"
}

#############################################################################
# WiFi / Bluetooth Optimization
#############################################################################
optimize_wifi_bluetooth() {
    print_step "Optimizing WiFi & Bluetooth (MT7925)..."
    cat > /etc/modprobe.d/mt7921.conf <<EOF
# MediaTek MT7925 optimizations for kernel 6.7+
options mt7921e disable_aspm=1
options mt7921e disable_clkreq=1
EOF
    # Configure NetworkManager for better WiFi stability
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
EOF
    systemctl enable bluetooth.service 2>/dev/null || true
    systemctl start bluetooth.service 2>/dev/null || true
    print_success "WiFi/Bluetooth optimizations applied"
}

#############################################################################
# System Tweaks
#############################################################################
apply_system_tweaks() {
    print_step "Applying system tweaks..."
    cat > /etc/sysctl.d/99-gz302.conf <<EOF
# System tweaks for GZ302EA
fs.inotify.max_user_watches=524288
vm.swappiness=10
EOF
    sysctl --system >/dev/null 2>&1 || true
    print_success "System tweaks applied"
}

#############################################################################
# Summary
#############################################################################
print_summary() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "What was done:"
    echo "  ✓ Kernel checked and updated if needed"
    echo "  ✓ System packages updated"
    echo "  ✓ Firmware (linux-firmware) ensured"
    echo "  ✓ Graphics stack (Mesa/Vulkan) configured"
    echo "  ✓ Bootloader parameters applied"
    echo "  ✓ ASUS tools (asusctl, supergfxctl) installed"
    echo "  ✓ Power management via TLP"
    echo "  ✓ Audio (SOF / PipeWire) configured"
    echo "  ✓ Suspend/resume tweaks"
    echo "  ✓ WiFi/Bluetooth optimizations"
    echo "  ✓ System sysctl tweaks"
    echo ""
    echo "Post-install checks:"
    echo "  • WiFi & Bluetooth: nmcli, bluetoothctl"
    echo "  • Graphics: glxinfo | grep 'OpenGL renderer'"
    echo "  • Power: tlp-stat"
    echo "  • Suspend: systemctl suspend (resume test)"
    echo ""
    echo "Reboot is recommended to use any new kernel."
    echo ""
}

#############################################################################
# Main
#############################################################################
main() {
    print_header
    for arg in "$@"; do
        case $arg in
            --help)
                echo "Usage: $0"
                echo "This script automatically installs and configures your GZ302EA system."
                exit 0 ;; 
            *) print_warning "Unknown option: $arg"; echo "Use --help for usage"; exit 1 ;; 
        esac
    done
    check_root
    detect_distro
    echo ""
    print_warning "This script will automatically install and configure your system." \
    && print_warning "Backup is recommended before proceeding." \
    && print_warning "Detected distribution: $DISTRO ($DISTRO_FAMILY)"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..." _
    echo ""
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
    print_summary
    print_info "Rebooting in 10 seconds... Press Ctrl+C to abort"
    sleep 10
    reboot
}

main "$@"