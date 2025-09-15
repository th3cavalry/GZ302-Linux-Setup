#!/bin/bash

# ==============================================================================
# Comprehensive Nobara Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.5
#
# This script automates the post-installation setup for Nobara on the
# ASUS ROG Flow Z13 (GZ302) with an AMD Ryzen AI 395+ processor.
# It applies critical hardware fixes, enhances gaming software,
# and configures optimal gaming performance.
#
# PRE-REQUISITES:
# 1. A base installation of Nobara Linux (39 or newer).
# 2. An active internet connection.
# 3. A user with sudo privileges.
#
# USAGE:
# 1. Download the script:
#    curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/nobara_setup.sh
# 2. Make it executable:
#    chmod +x nobara_setup.sh
# 3. Run with sudo:
#    sudo ./nobara_setup.sh
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

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

# --- Core System Setup Functions ---

# 1. Update system and install base dependencies
update_system() {
    info "Performing a full system update and installing base dependencies..."
    info "This may take a few minutes depending on your internet connection..."
    
    # Update system
    dnf upgrade -y --refresh
    
    # Install essential build tools and dependencies
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        dnf-plugins-core
    
    success "System updated and base dependencies installed."
}

# 2. Verify Nobara gaming repositories
setup_repositories() {
    info "Verifying Nobara gaming repositories..."
    info "Nobara comes with gaming repos pre-configured, ensuring they're optimal..."
    
    # Nobara should already have all necessary gaming repositories
    # Just ensure they're updated and working
    dnf update -y
    
    # Verify Flathub is enabled (should be by default in Nobara)
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    
    success "Gaming repositories verified and updated."
}

# 3. Install additional hardware support packages
install_hardware_support() {
    info "Installing additional hardware support packages for AMD and ASUS devices..."
    
    # Nobara already has excellent AMD support, adding extras for GZ302
    dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
        libva-utils libva libva-vdpau-driver mesa-vdpau-drivers \
        radeontop
    
    # Install firmware and microcode (should already be present)
    dnf install -y linux-firmware amd-ucode-firmware
    
    # Install power management tools
    dnf install -y powertop tlp tlp-rdw
    
    # Install hardware monitoring tools
    dnf install -y lm_sensors
    
    success "Additional hardware support packages installed."
}

# --- Hardware Fix Functions ---

# 4. Apply hardware-specific fixes
apply_hardware_fixes() {
    info "Applying hardware-specific fixes for the ROG Flow Z13..."
    info "These fixes address known issues with Wi-Fi, touchpad, audio, and graphics..."

    # 4a. Fix Wi-Fi instability (MediaTek MT7925)
    info "Applying Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# Disable ASPM for the MediaTek MT7925E to improve stability
options mt7925e disable_aspm=1
# Additional stability parameters
options mt7925e power_save=0
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
EOF
    success "Wi-Fi fixes for MediaTek MT7925 applied."

    # 4b. Fix touchpad detection and sensitivity
    info "Applying touchpad detection and sensitivity fixes..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 folio touchpad override
# Forces the device to be recognized as a multi-touch touchpad
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create systemd service to reload hid_asus module post-boot
    info "Creating touchpad fix service..."
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module with correct options for Z13 Touchpad
After=multi-user.target
ConditionKernelModule=hid_asus

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus

[Install]
WantedBy=multi-user.target
EOF

    # 4c. Fix audio issues and enable all audio devices
    info "Applying audio fixes for GZ302..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Fix audio issues on ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
EOF

    # 4d. Fix AMD GPU driver issues
    info "Applying AMD GPU optimizations..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF

    # 4e. Fix thermal throttling and power management
    info "Applying thermal and power management fixes..."
    cat > /etc/udev/rules.d/50-gz302-thermal.rules <<EOF
# Thermal management for GZ302
SUBSYSTEM=="thermal", KERNEL=="thermal_zone*", ATTR{type}=="x86_pkg_temp", ATTR{policy}="step_wise"
SUBSYSTEM=="thermal", KERNEL=="thermal_zone*", ATTR{type}=="acpi", ATTR{policy}="step_wise"
EOF

    info "Updating system hardware database..."
    systemd-hwdb update
    success "All hardware fixes applied."
}

# --- Gaming Software Stack Functions ---

# 5. Enhance the existing gaming software stack
enhance_gaming_stack() {
    info "Enhancing Nobara's existing gaming software stack..."
    info "Nobara comes with excellent gaming support, adding GZ302-specific optimizations..."

    # 5a. Ensure all gaming packages are up to date
    info "Updating gaming packages..."
    dnf update -y steam lutris gamemode vulkan-loader vulkan-tools \
        mesa-vulkan-drivers wine winetricks

    # 5b. Install additional gaming tools that might not be present
    info "Installing additional gaming libraries and performance tools..."
    dnf install -y mangohud
    
    # Install additional libraries for better compatibility
    dnf install -y mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 \
        vulkan-loader.i686

    success "Gaming packages updated and enhanced."

    # 5c. Ensure ProtonUp-Qt is available (Nobara might already have it)
    info "Verifying ProtonUp-Qt availability..."
    if ! command -v protonup-qt &> /dev/null; then
        info "Installing ProtonUp-Qt via Flatpak..."
        PRIMARY_USER=$(get_real_user)
        if [[ "$PRIMARY_USER" != "root" ]]; then
            sudo -u "$PRIMARY_USER" flatpak install -y flathub net.davidotek.pupgui2
            success "ProtonUp-Qt installed via Flatpak."
        else
            warning "Could not determine non-root user. ProtonUp-Qt installation skipped."
        fi
    else
        success "ProtonUp-Qt is already available."
    fi

    # 5d. Ensure latest Proton-GE is installed
    install_proton_ge() {
        local user="$1"
        local user_home="/home/$user"
        local compat_dir="$user_home/.steam/root/compatibilitytools.d"
        
        # Check if any Proton-GE is already installed
        if [[ -d "$compat_dir" ]] && ls "$compat_dir"/GE-Proton* &>/dev/null; then
            info "Proton-GE is already installed. Checking for updates..."
            local installed_versions=($(ls -d "$compat_dir"/GE-Proton* 2>/dev/null | xargs -n1 basename))
            local latest_release=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
            if [[ -n "$latest_release" ]]; then
                local latest_folder="GE-Proton${latest_release#GE-Proton}"
                if [[ " ${installed_versions[*]} " =~ " ${latest_folder} " ]]; then
                    success "Latest Proton-GE ($latest_release) is already installed."
                    return 0
                fi
            fi
        fi
        
        # Download and install latest Proton-GE
        sudo -u "$user" bash <<'EOF'
set -e
info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$COMPAT_DIR"

info "Fetching latest Proton-GE release information..."
LATEST_URL=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep "browser_download_url.*\.tar\.gz" | cut -d '"' -f 4)
if [[ -n "$LATEST_URL" ]]; then
    RELEASE_NAME=$(echo "$LATEST_URL" | sed 's/.*\/\([^\/]*\)\.tar\.gz/\1/')
    info "Downloading Proton-GE: $RELEASE_NAME..."
    cd "$COMPAT_DIR"
    curl -L "$LATEST_URL" | tar -xz
    success "Proton-GE ($RELEASE_NAME) installed successfully."
else
    echo "Could not find the latest Proton-GE release."
fi
EOF
    }
    
    info "Ensuring latest Proton-GE is installed..."
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        install_proton_ge "$PRIMARY_USER"
    else
        warning "Could not determine non-root user. Skipping Proton-GE installation."
    fi

    success "Gaming software stack enhancement completed."
}

# --- Performance Tuning Functions ---

# 6. Apply additional performance optimizations
apply_performance_tweaks() {
    info "Applying additional performance tweaks for GZ302..."
    info "Nobara already has gaming optimizations, adding device-specific ones..."

    # 6a. Apply GZ302-specific kernel parameters
    info "Applying GZ302-specific gaming and performance kernel parameters..."
    cat > /etc/sysctl.d/99-gaming-gz302.conf <<EOF
# Increase vm.max_map_count for modern games (may already be set in Nobara)
vm.max_map_count = 2147483642

# GZ302-specific gaming performance optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Network optimizations for gaming (enhanced for GZ302)
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 1048576 2097152
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mtu_probing = 1

# Reduce latency and improve responsiveness
kernel.sched_autogroup_enabled = 0
EOF
    sysctl -p /etc/sysctl.d/99-gaming-gz302.conf
    success "GZ302-specific performance optimizations applied."

    # 6b. Enhance hardware video acceleration
    info "Enhancing hardware video acceleration for GZ302..."
    if ! grep -q "GZ302 optimizations" /etc/environment; then
        cat >> /etc/environment <<EOF

# GZ302 optimizations for AMDGPU
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi

# Enhanced gaming optimizations for GZ302
RADV_PERFTEST=gpl,sam,nggc
DXVK_HUD=compiler
MANGOHUD=1
EOF
    fi
    success "Hardware video acceleration enhanced for GZ302."

    # 6c. Configure GZ302-specific I/O schedulers
    info "Configuring I/O schedulers optimized for GZ302 storage..."
    cat > /etc/udev/rules.d/60-ioschedulers-gz302.rules <<EOF
# Set optimal schedulers for GZ302 storage devices
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
    success "I/O schedulers optimized for GZ302."

    # 6d. Configure limits for enhanced gaming performance
    info "Configuring enhanced system limits for GZ302 gaming..."
    cat > /etc/security/limits.d/99-gaming-gz302.conf <<EOF
# Enhanced limits for gaming on GZ302
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF
    success "System limits enhanced for GZ302 gaming."
}

# --- Service Management Functions ---

# 7. Enable and configure services
enable_services() {
    info "Enabling and configuring system services for GZ302..."

    # Enable TLP for power management (might conflict with existing power management)
    info "Configuring power management for gaming..."
    if systemctl is-enabled power-profiles-daemon &>/dev/null; then
        info "Using existing power-profiles-daemon..."
    else
        systemctl enable --now tlp.service
        info "TLP power management enabled."
    fi
    
    # Enable hardware fix services
    info "Enabling GZ302-specific hardware fix services..."
    systemctl enable --now reload-hid_asus.service
    
    # Configure gamemode for the primary user
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        info "Configuring enhanced GameMode for user: $PRIMARY_USER"
        
        # Add user to gamemode group (may already be done by Nobara)
        usermod -a -G gamemode "$PRIMARY_USER" || true
        
        # Configure gamemode with GZ302-specific settings
        sudo -u "$PRIMARY_USER" mkdir -p "/home/$PRIMARY_USER/.config/gamemode"
        sudo -u "$PRIMARY_USER" cat > "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini" <<EOF
[general]
renice=10
desiredgov=performance
igpu_desiredgov=performance
igpu_power_threshold=0.3

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[custom]
start=notify-send "GameMode" "GZ302 optimizations activated"
end=notify-send "GameMode" "GZ302 optimizations deactivated"
EOF
        chown "$PRIMARY_USER:$PRIMARY_USER" "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini"
        success "Enhanced GameMode configuration completed for GZ302."
    fi

    success "All necessary services have been enabled and configured."
}

# --- Main Execution Logic ---
main() {
    check_root

    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Nobara Enhancement Script"
    echo "  Version 1.3 - GZ302-Specific Gaming Optimizations"
    echo "============================================================"
    echo
    
    info "Starting GZ302-specific enhancement process for Nobara..."
    info "This script will apply hardware fixes and GZ302 optimizations to Nobara's gaming setup"
    info "Estimated time: 5-15 minutes depending on internet speed"
    echo

    info "Step 1/7: Updating system and base dependencies..."
    update_system
    
    info "Step 2/7: Verifying gaming repositories..."
    setup_repositories
    
    info "Step 3/7: Installing additional hardware support..."
    install_hardware_support
    
    info "Step 4/7: Applying GZ302 hardware fixes..."
    apply_hardware_fixes
    
    info "Step 5/7: Enhancing gaming software stack..."
    enhance_gaming_stack
    
    info "Step 6/7: Applying GZ302-specific performance optimizations..."
    apply_performance_tweaks
    
    info "Step 7/7: Configuring services for optimal GZ302 performance..."
    enable_services

    echo
    success "============================================================"
    success "Nobara enhancement complete for ASUS ROG Flow Z13 (GZ302)!"
    success "It is recommended to REBOOT your system now."
    success ""
    success "Nobara's gaming features enhanced with:"
    success "- GZ302-specific hardware fixes and optimizations"
    success "- Enhanced Steam and Proton configuration"
    success "- Latest Proton-GE installation"
    success "- MangoHUD performance monitoring"
    success "- Enhanced GameMode configuration"
    success "- GZ302-optimized power management"
    success ""
    success "Hardware fixes applied:"
    success "- MediaTek MT7925 Wi-Fi stability improvements"
    success "- Touchpad detection and sensitivity fixes"
    success "- AMD GPU driver optimizations"
    success "- Audio device compatibility fixes"
    success "- Thermal throttling and power management"
    success ""
    success "Performance optimizations applied:"
    success "- GZ302-specific kernel parameters"
    success "- Enhanced I/O scheduler configuration"
    success "- Network latency optimizations"
    success "- Memory management tweaks"
    success "- Hardware video acceleration"
    success "- Enhanced system limits for gaming"
    success ""
    success "You can now enjoy Nobara optimized specifically for your"
    success "ASUS ROG Flow Z13 (GZ302) with enhanced gaming performance!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"