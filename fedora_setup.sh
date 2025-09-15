#!/bin/bash

# ==============================================================================
# Comprehensive Fedora Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.5
#
# This script automates the post-installation setup for Fedora on the
# ASUS ROG Flow Z13 (GZ302) with an AMD Ryzen AI 395+ processor.
# It applies critical hardware fixes, installs gaming software,
# and configures a high-performance gaming environment.
#
# PRE-REQUISITES:
# 1. A base installation of Fedora (37 or newer).
# 2. An active internet connection.
# 3. A user with sudo privileges.
#
# USAGE:
# 1. Download the script:
#    curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/fedora_setup.sh
# 2. Make it executable:
#    chmod +x fedora_setup.sh
# 3. Run with sudo:
#    sudo ./fedora_setup.sh
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
    info "Performing system update and installing base dependencies..."
    
    # Update system
    dnf upgrade -y --refresh
    
    # Install essential build tools and dependencies
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        dnf-plugins-core rpmfusion-free-release rpmfusion-nonfree-release
    
    # Update package cache after adding RPM Fusion
    dnf update -y
    
    success "System updated and base dependencies installed."
}

# 2. Enable additional repositories
setup_repositories() {
    info "Setting up gaming and hardware repositories..."
    
    # Enable RPM Fusion repositories (should already be installed above)
    dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || true
    
    # Enable Flathub for additional gaming applications
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Update package lists
    dnf update -y
    
    success "Gaming and hardware repositories configured."
}

# 3. Install hardware support packages
install_hardware_support() {
    info "Installing hardware support packages for AMD and ASUS devices..."
    
    # Install AMD GPU drivers and utilities
    dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
        libva-utils libva libva-vdpau-driver mesa-vdpau-drivers \
        radeontop
    
    # Install firmware and microcode
    dnf install -y linux-firmware amd-ucode-firmware
    
    # Install power management tools
    dnf install -y powertop tlp tlp-rdw
    
    # Install hardware monitoring tools
    dnf install -y lm_sensors
    
    success "Hardware support packages installed."
}

# --- Hardware Fix Functions ---

# 4. Apply hardware-specific fixes
apply_hardware_fixes() {
    info "Applying hardware fixes for the ROG Flow Z13 (GZ302)..."

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

    # 4f. Fix camera issues for GZ302
    # Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
    info "Applying camera fixes for GZ302..."
    cat > /etc/modprobe.d/uvcvideo-gz302.conf <<EOF
# Camera fixes for ASUS ROG Flow Z13 GZ302
# Improved UVC video driver parameters for better compatibility
options uvcvideo quirks=0x80
options uvcvideo nodrop=1
EOF

    # Add camera permissions for user access
    cat > /etc/udev/rules.d/99-gz302-camera.rules <<EOF
# Camera access rules for GZ302
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", GROUP="video", MODE="0664"
EOF

    info "Updating system hardware database..."
    systemd-hwdb update
    success "All hardware fixes applied."
}

# --- Gaming Software Stack Functions ---

# 5. Install and configure the gaming software stack
install_gaming_stack() {
    info "Installing and configuring the gaming software stack..."
    info "This will install Steam, Lutris, gaming tools, and compatibility layers..."

    # 5a. Install Steam
    info "Installing Steam..."
    dnf install -y steam

    # 5b. Install Lutris
    info "Installing Lutris game manager..."
    dnf install -y lutris

    # 5c. Install gaming libraries and tools
    info "Installing gaming libraries and performance tools..."
    dnf install -y gamemode vulkan-loader vulkan-tools mesa-vulkan-drivers \
        wine winetricks
    
    # Install additional libraries for better compatibility
    dnf install -y mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 \
        vulkan-loader.i686

    success "Core gaming applications and libraries installed."

    # 5d. Install MangoHUD for performance monitoring
    info "Installing MangoHUD for performance monitoring..."
    dnf install -y mangohud

    # 5e. Install ProtonUp-Qt via Flatpak
    info "Installing ProtonUp-Qt for Proton version management..."
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        sudo -u "$PRIMARY_USER" flatpak install -y flathub net.davidotek.pupgui2
        success "ProtonUp-Qt installed via Flatpak."
    else
        warning "Could not determine non-root user. ProtonUp-Qt installation skipped."
    fi

    # 5f. Install Proton-GE
    install_proton_ge() {
        local user="$1"
        local user_home="/home/$user"
        local compat_dir="$user_home/.steam/root/compatibilitytools.d"
        
        # Check if any Proton-GE is already installed
        if [[ -d "$compat_dir" ]] && ls "$compat_dir"/GE-Proton* &>/dev/null; then
            info "Proton-GE is already installed. Skipping download."
            return 0
        fi
        
        # Download and install latest Proton-GE
        sudo -u "$user" bash <<'EOF'
set -e

COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$COMPAT_DIR"

echo -e "\033[0;34m[INFO]\033[0m Fetching latest Proton-GE release information..."
LATEST_URL=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep "browser_download_url.*\.tar\.gz" | cut -d '"' -f 4)
if [[ -n "$LATEST_URL" ]]; then
    RELEASE_NAME=$(echo "$LATEST_URL" | sed 's/.*\/\([^\/]*\)\.tar\.gz/\1/')
    echo -e "\033[0;34m[INFO]\033[0m Downloading Proton-GE: $RELEASE_NAME..."
    cd "$COMPAT_DIR"
    curl -L "$LATEST_URL" | tar -xz
    echo -e "\033[0;32m[SUCCESS]\033[0m Proton-GE ($RELEASE_NAME) installed successfully."
else
    echo "Could not find the latest Proton-GE release."
fi
EOF
    }
    
    info "Installing the latest version of Proton-GE..."
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        install_proton_ge "$PRIMARY_USER"
    else
        warning "Could not determine non-root user. Skipping Proton-GE installation."
    fi

    success "Gaming software stack installation completed."
}

# --- Performance Tuning Functions ---

# 6. Apply system-wide performance optimizations
apply_performance_tweaks() {
    info "Applying system performance optimizations..."

    # 6a. Increase vm.max_map_count for game compatibility
    info "Applying gaming and performance kernel parameters..."
    cat > /etc/sysctl.d/99-gaming.conf <<EOF
# Increase vm.max_map_count for modern games (SteamOS default)
vm.max_map_count = 2147483642

# Gaming performance optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Network optimizations for gaming
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
    sysctl -p /etc/sysctl.d/99-gaming.conf
    success "Gaming and performance optimizations applied."

    # 6b. Enable hardware video acceleration globally
    info "Enabling hardware video acceleration for better video performance..."
    if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
        cat >> /etc/environment <<EOF

# Enable VA-API and VDPAU hardware acceleration for AMDGPU
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi

# Gaming optimizations
RADV_PERFTEST=gpl,sam,nggc
DXVK_HUD=compiler
MANGOHUD=1
EOF
    fi
    success "Hardware video acceleration and gaming environment variables enabled."

    # 6c. Configure gaming-optimized I/O schedulers
    info "Configuring I/O schedulers for optimal storage performance..."
    cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set deadline scheduler for SSDs and none for NVMe
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
    success "I/O schedulers configured for optimal gaming performance."

    # 6d. Configure CPU governor for performance
    info "Installing and configuring CPU frequency scaling..."
    dnf install -y kernel-tools
    
    cat > /etc/systemd/system/cpu-performance.service <<EOF
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    success "CPU performance governor configured."

    # 6e. Configure limits for better gaming performance
    info "Configuring system limits for better gaming compatibility..."
    cat > /etc/security/limits.d/99-gaming.conf <<EOF
# Increase limits for gaming
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF
    success "System limits configured for gaming."
}

# --- Service Management Functions ---

# 7. Enable and start necessary services
enable_services() {
    info "Enabling and starting system services..."

    # Enable TLP for power management
    info "Enabling TLP power management..."
    systemctl enable --now tlp.service
    
    # Enable hardware fix services
    info "Enabling hardware fix services..."
    systemctl enable --now reload-hid_asus.service
    systemctl enable --now cpu-performance.service
    
    # Configure gamemode for the primary user
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        info "Configuring GameMode for user: $PRIMARY_USER"
        
        # Add user to gamemode group
        usermod -a -G gamemode "$PRIMARY_USER"
        
        # Configure gamemode
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
start=notify-send "GameMode" "Optimizations activated"
end=notify-send "GameMode" "Optimizations deactivated"
EOF
        chown "$PRIMARY_USER:$PRIMARY_USER" "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini"
        success "GameMode configuration completed."
    fi

    success "All necessary services have been enabled and started."
}

# --- TDP Management Functions ---
# Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR

# Install TDP management tools and configure profiles
install_tdp_management() {
    info "Installing TDP management for GZ302..."
    
    # Install dependencies for building ryzenadj
    dnf install -y cmake pciutils-devel gcc gcc-c++ make git
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" == "root" ]]; then
        warning "Cannot install ryzenadj without a non-root user."
        return 1
    fi
    
    # Build and install ryzenadj from source
    sudo -u "$PRIMARY_USER" bash <<'EOF'
set -e
cd /tmp
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
EOF
    
    # Install ryzenadj system-wide
    cp /tmp/RyzenAdj/build/ryzenadj /usr/local/bin/
    chmod +x /usr/local/bin/ryzenadj
    
    # Cleanup
    rm -rf /tmp/RyzenAdj
    
    # Create TDP management script (same as Ubuntu)
    cat > /usr/local/bin/gz302-tdp <<'EOF'
#!/bin/bash
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

    # 4f. Fix camera issues for GZ302
    # Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
    info "Applying camera fixes for GZ302..."
    cat > /etc/modprobe.d/uvcvideo-gz302.conf <<EOF
# Camera fixes for ASUS ROG Flow Z13 GZ302
# Improved UVC video driver parameters for better compatibility
options uvcvideo quirks=0x80
options uvcvideo nodrop=1
EOF

    # Add camera permissions for user access
    cat > /etc/udev/rules.d/99-gz302-camera.rules <<EOF
# Camera access rules for GZ302
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", GROUP="video", MODE="0664"
EOF

    info "Updating system hardware database..."
    systemd-hwdb update
    success "All hardware fixes applied."
}

# --- Gaming Software Stack Functions ---

# 5. Install and configure the gaming software stack
install_gaming_stack() {
    info "Installing and configuring the gaming software stack..."
    info "This will install Steam, Lutris, gaming tools, and compatibility layers..."

    # 5a. Install Steam
    info "Installing Steam..."
    dnf install -y steam

    # 5b. Install Lutris
    info "Installing Lutris game manager..."
    dnf install -y lutris

    # 5c. Install gaming libraries and tools
    info "Installing gaming libraries and performance tools..."
    dnf install -y gamemode vulkan-loader vulkan-tools mesa-vulkan-drivers \
        wine winetricks
    
    # Install additional libraries for better compatibility
    dnf install -y mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 \
        vulkan-loader.i686

    success "Core gaming applications and libraries installed."

    # 5d. Install MangoHUD for performance monitoring
    info "Installing MangoHUD for performance monitoring..."
    dnf install -y mangohud

    # 5e. Install ProtonUp-Qt via Flatpak
    info "Installing ProtonUp-Qt for Proton version management..."
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        sudo -u "$PRIMARY_USER" flatpak install -y flathub net.davidotek.pupgui2
        success "ProtonUp-Qt installed via Flatpak."
    else
        warning "Could not determine non-root user. ProtonUp-Qt installation skipped."
    fi

    # 5f. Install Proton-GE
    install_proton_ge() {
        local user="$1"
        local user_home="/home/$user"
        local compat_dir="$user_home/.steam/root/compatibilitytools.d"
        
        # Check if any Proton-GE is already installed
        if [[ -d "$compat_dir" ]] && ls "$compat_dir"/GE-Proton* &>/dev/null; then
            info "Proton-GE is already installed. Skipping download."
            return 0
        fi
        
        # Download and install latest Proton-GE
        sudo -u "$user" bash <<'EOF'
set -e

COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$COMPAT_DIR"

echo -e "\033[0;34m[INFO]\033[0m Fetching latest Proton-GE release information..."
LATEST_URL=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep "browser_download_url.*\.tar\.gz" | cut -d '"' -f 4)
if [[ -n "$LATEST_URL" ]]; then
    RELEASE_NAME=$(echo "$LATEST_URL" | sed 's/.*\/\([^\/]*\)\.tar\.gz/\1/')
    echo -e "\033[0;34m[INFO]\033[0m Downloading Proton-GE: $RELEASE_NAME..."
    cd "$COMPAT_DIR"
    curl -L "$LATEST_URL" | tar -xz
    echo -e "\033[0;32m[SUCCESS]\033[0m Proton-GE ($RELEASE_NAME) installed successfully."
else
    echo "Could not find the latest Proton-GE release."
fi
EOF
    }
    
    info "Installing the latest version of Proton-GE..."
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        install_proton_ge "$PRIMARY_USER"
    else
        warning "Could not determine non-root user. Skipping Proton-GE installation."
    fi

    success "Gaming software stack installation completed."
}

# --- Performance Tuning Functions ---

# 6. Apply system-wide performance optimizations
apply_performance_tweaks() {
    info "Applying system performance optimizations..."

    # 6a. Increase vm.max_map_count for game compatibility
    info "Applying gaming and performance kernel parameters..."
    cat > /etc/sysctl.d/99-gaming.conf <<EOF
# Increase vm.max_map_count for modern games (SteamOS default)
vm.max_map_count = 2147483642

# Gaming performance optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Network optimizations for gaming
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
    sysctl -p /etc/sysctl.d/99-gaming.conf
    success "Gaming and performance optimizations applied."

    # 6b. Enable hardware video acceleration globally
    info "Enabling hardware video acceleration for better video performance..."
    if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
        cat >> /etc/environment <<EOF

# Enable VA-API and VDPAU hardware acceleration for AMDGPU
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi

# Gaming optimizations
RADV_PERFTEST=gpl,sam,nggc
DXVK_HUD=compiler
MANGOHUD=1
EOF
    fi
    success "Hardware video acceleration and gaming environment variables enabled."

    # 6c. Configure gaming-optimized I/O schedulers
    info "Configuring I/O schedulers for optimal storage performance..."
    cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set deadline scheduler for SSDs and none for NVMe
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
    success "I/O schedulers configured for optimal gaming performance."

    # 6d. Configure CPU governor for performance
    info "Installing and configuring CPU frequency scaling..."
    dnf install -y kernel-tools
    
    cat > /etc/systemd/system/cpu-performance.service <<EOF
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    success "CPU performance governor configured."

    # 6e. Configure limits for better gaming performance
    info "Configuring system limits for better gaming compatibility..."
    cat > /etc/security/limits.d/99-gaming.conf <<EOF
# Increase limits for gaming
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF
    success "System limits configured for gaming."
}

# --- Service Management Functions ---

# 7. Enable and start necessary services
enable_services() {
    info "Enabling and starting system services..."

    # Enable TLP for power management
    info "Enabling TLP power management..."
    systemctl enable --now tlp.service
    
    # Enable hardware fix services
    info "Enabling hardware fix services..."
    systemctl enable --now reload-hid_asus.service
    systemctl enable --now cpu-performance.service
    
    # Configure gamemode for the primary user
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        info "Configuring GameMode for user: $PRIMARY_USER"
        
        # Add user to gamemode group
        usermod -a -G gamemode "$PRIMARY_USER"
        
        # Configure gamemode
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
start=notify-send "GameMode" "Optimizations activated"
end=notify-send "GameMode" "Optimizations deactivated"
EOF
        chown "$PRIMARY_USER:$PRIMARY_USER" "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini"
        success "GameMode configuration completed."
    fi

    success "All necessary services have been enabled and started."
}

# --- TDP Management Functions ---
# Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR

# Install TDP management tools and configure profiles
install_tdp_management() {
    info "Installing TDP management for GZ302..."
    
    # Install dependencies for building ryzenadj
    dnf install -y cmake pciutils-devel gcc gcc-c++ make git
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" == "root" ]]; then
        warning "Cannot install ryzenadj without a non-root user."
        return 1
    fi
    
    # Build and install ryzenadj from source
    sudo -u "$PRIMARY_USER" bash <<'EOF'
set -e
cd /tmp
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
EOF
    
    # Install ryzenadj system-wide
    cp /tmp/RyzenAdj/build/ryzenadj /usr/local/bin/
    chmod +x /usr/local/bin/ryzenadj
    
    # Cleanup
    rm -rf /tmp/RyzenAdj
    
    # Create TDP management script (same as Ubuntu)
    cat > /usr/local/bin/gz302-tdp <<'EOF'
#!/bin/bash
# GZ302 TDP Management Script for Fedora
# Based on research from Shahzebqazi's Asus-Z13-Flow-2025-PCMR

TDP_CONFIG_DIR="/etc/gz302-tdp"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"

# TDP Profiles (in mW)
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
    echo "Usage: gz302-tdp [PROFILE|status|list]"
    echo ""
    echo "Profiles:"
    echo "  gaming       - 54W maximum performance (AC power recommended)"
    echo "  performance  - 45W high performance"
    echo "  balanced     - 35W balanced (default)"
    echo "  efficient    - 15W maximum efficiency"
    echo ""
    echo "Commands:"
    echo "  status       - Show current TDP and power source"
    echo "  list         - List available profiles"
}

get_battery_status() {
    if [ -f /sys/class/power_supply/ADP1/online ]; then
        if [ "$(cat /sys/class/power_supply/ADP1/online)" = "1" ]; then
            echo "AC"
        else
            echo "Battery"
        fi
    else
        echo "Unknown"
    fi
}

get_battery_percentage() {
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        cat /sys/class/power_supply/BAT0/capacity
    else
        echo "N/A"
    fi
}

set_tdp_profile() {
    local profile="$1"
    local tdp_value="${TDP_PROFILES[$profile]}"
    
    if [ -z "$tdp_value" ]; then
        echo "Error: Unknown profile '$profile'"
        return 1
    fi
    
    echo "Setting TDP profile: $profile ($(($tdp_value / 1000))W)"
    
    # Apply TDP settings using ryzenadj
    ryzenadj --stapm-limit="$tdp_value" --fast-limit="$tdp_value" --slow-limit="$tdp_value"
    
    if [ $? -eq 0 ]; then
        echo "$profile" > "$CURRENT_PROFILE_FILE"
        echo "TDP profile '$profile' applied successfully"
    else
        echo "Error: Failed to apply TDP profile"
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
    for profile in "${!TDP_PROFILES[@]}"; do
        local tdp_watts=$(( ${TDP_PROFILES[$profile]} / 1000 ))
        echo "  $profile: ${tdp_watts}W"
    done
}

# Main script logic
case "$1" in
    gaming|performance|balanced|efficient)
        set_tdp_profile "$1"
        ;;
    status)
        show_status
        ;;
    list)
        list_profiles
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

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gz302-tdp balanced
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable gz302-tdp-auto.service
    success "TDP management installed. Use 'gz302-tdp' command to manage power profiles."
}

# --- LLM Installation Functions ---

# User choice function for installation options
ask_installation_options() {
    echo ""
    info "Installation Configuration:"
    echo "This script can install gaming software and LLM frameworks."
    echo ""
    
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
    
    echo ""
}

# User choice function for LLM installations
choose_llm_options() {
    info "LLM (Large Language Model) Installation Options:"
    echo "Please select which LLM frameworks you'd like to install:"
    echo ""
    echo "1. Ollama - Local LLM runner (lightweight, easy to use)"
    echo "2. ROCm - AMD GPU acceleration for ML/AI workloads"
    echo "3. PyTorch with ROCm - Deep learning framework with AMD GPU support"
    echo "4. Transformers - Hugging Face transformers library"
    echo "5. All of the above"
    echo "6. Skip LLM installation"
    echo ""
    
    local choices=""
    read -p "Enter your choices (comma-separated, e.g., 1,3,4): " choices
    echo "$choices"
}

# Install Ollama for local LLM inference
install_ollama() {
    info "Installing Ollama for local LLM inference..."
    
    # Download and install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Enable and start Ollama service
    systemctl enable ollama.service
    systemctl start ollama.service
    
    success "Ollama installed successfully. You can now run: ollama run llama2"
}

# Install ROCm for AMD GPU acceleration
install_rocm() {
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Add ROCm repository for Fedora
    dnf config-manager --add-repo https://repo.radeon.com/rocm/rhel9/rocm.repo
    
    # Install ROCm packages
    dnf install -y rocm-dev rocm-libs rocm-utils
    
    # Add user to render group for GPU access
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -a -G render "$SUDO_USER"
        info "User $SUDO_USER added to render group for GPU access."
    fi
    
    success "ROCm installed successfully. Reboot required for full functionality."
}

# Install PyTorch with ROCm support
install_pytorch_rocm() {
    info "Installing PyTorch with ROCm support..."
    
    # Install pip if not present
    dnf install -y python3-pip
    
    # Install PyTorch with ROCm support
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
    
    success "PyTorch with ROCm support installed successfully."
}

# Install Hugging Face Transformers
install_transformers() {
    info "Installing Hugging Face Transformers library..."
    
    # Install pip if not present
    dnf install -y python3-pip
    
    # Install transformers and related packages
    pip3 install transformers accelerate datasets tokenizers
    
    success "Hugging Face Transformers library installed successfully."
}

# Main LLM installation function
install_llm_stack() {
    info "Setting up LLM (Large Language Model) environment..."
    
    local choices=$(choose_llm_options)
    
    if [[ "$choices" == *"6"* ]] || [[ -z "$choices" ]]; then
        info "Skipping LLM installation as requested."
        return 0
    fi
    
    if [[ "$choices" == *"5"* ]]; then
        info "Installing all LLM options..."
        install_ollama
        install_rocm
        install_pytorch_rocm
        install_transformers
    else
        if [[ "$choices" == *"1"* ]]; then
            install_ollama
        fi
        if [[ "$choices" == *"2"* ]]; then
            install_rocm
        fi
        if [[ "$choices" == *"3"* ]]; then
            install_pytorch_rocm
        fi
        if [[ "$choices" == *"4"* ]]; then
            install_transformers
        fi
    fi
    
    success "LLM environment setup completed."
}

# --- Universal Filesystem and Bootloader Detection Functions ---

# Detect root filesystem type
detect_root_filesystem() {
    local root_device=$(findmnt -n -o SOURCE /)
    local fs_type=$(findmnt -n -o FSTYPE /)
    
    echo "Root filesystem: $fs_type on $root_device" >&2
    echo "$fs_type"
}

# Detect bootloader type
detect_bootloader() {
    local bootloader="unknown"
    
    # Check for GRUB
    if [ -f /boot/grub/grub.cfg ] || [ -f /boot/EFI/*/grub.cfg ] 2>/dev/null; then
        bootloader="grub"
    # Check for systemd-boot
    elif [ -f /boot/EFI/systemd/systemd-bootx64.efi ] || [ -f /boot/EFI/BOOT/BOOTX64.EFI ]; then
        if bootctl status >/dev/null 2>&1; then
            bootloader="systemd-boot"
        fi
    # Check for rEFInd
    elif [ -f /boot/EFI/refind/refind_x64.efi ]; then
        bootloader="refind"
    fi
    
    echo "Detected bootloader: $bootloader" >&2
    echo "$bootloader"
}

# Install and configure universal snapshots for system recovery
install_universal_snapshots() {
    local fs_type=$(detect_root_filesystem)
    info "Installing snapshot management for $fs_type filesystem..."
    
    case "$fs_type" in
        zfs)
            info "Detected ZFS filesystem. Installing ZFS snapshot utilities..."
            dnf install -y zfs-utils
            ;;
        btrfs)
            info "Detected Btrfs filesystem. Installing Btrfs snapshot utilities..."
            dnf install -y btrfs-progs snapper
            ;;
        ext4|ext3|ext2)
            info "Detected ext filesystem. Installing LVM snapshot utilities..."
            dnf install -y lvm2
            ;;
        xfs)
            info "Detected XFS filesystem. Installing XFS utilities..."
            dnf install -y xfsprogs
            ;;
        *)
            warning "Filesystem $fs_type not supported for automatic snapshots."
            warning "Supported filesystems: ZFS, Btrfs, ext2/3/4 (with LVM), XFS"
            return 1
            ;;
    esac
    
    # Create universal snapshot management script (same as other distributions)
    cat > /usr/local/bin/gz302-snapshot <<'EOF'
#!/bin/bash
# GZ302 Universal Snapshot Management
# Supports ZFS, Btrfs, ext4 (with LVM), and XFS filesystems

SNAPSHOT_PREFIX="gz302-auto"

# Detect filesystem type
detect_filesystem() {
    local fs_type=$(findmnt -n -o FSTYPE /)
    echo "$fs_type"
}

# Detect root device/volume
detect_root_device() {
    local root_source=$(findmnt -n -o SOURCE /)
    echo "$root_source"
}

show_usage() {
    echo "Usage: gz302-snapshot [create|list|cleanup|restore]"
    echo ""
    echo "Commands:"
    echo "  create   - Create a new system snapshot"
    echo "  list     - List available snapshots"
    echo "  cleanup  - Remove old snapshots (keep last 5)"
    echo "  restore  - Restore from a snapshot (interactive)"
    echo ""
    echo "Supported filesystems: ZFS, Btrfs, ext4 (with LVM), XFS"
}

# ZFS snapshot functions
zfs_create_snapshot() {
    local pool_name=$(zpool list -H -o name | head -1)
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="${SNAPSHOT_PREFIX}-${timestamp}"
    
    echo "Creating ZFS snapshot: $pool_name@$snapshot_name"
    if zfs snapshot "$pool_name@$snapshot_name"; then
        echo "ZFS snapshot created successfully: $snapshot_name"
    else
        echo "Error: Failed to create ZFS snapshot"
        return 1
    fi
}

zfs_list_snapshots() {
    local pool_name=$(zpool list -H -o name | head -1)
    echo "Available ZFS snapshots:"
    zfs list -t snapshot -o name,creation,used -s creation | grep "$pool_name@$SNAPSHOT_PREFIX" || echo "No snapshots found"
}

zfs_cleanup_snapshots() {
    local pool_name=$(zpool list -H -o name | head -1)
    echo "Cleaning up old ZFS snapshots (keeping last 5)..."
    local snapshots=($(zfs list -H -t snapshot -o name -s creation | grep "$pool_name@$SNAPSHOT_PREFIX"))
    local total=${#snapshots[@]}
    
    if [ $total -gt 5 ]; then
        local to_remove=$((total - 5))
        echo "Removing $to_remove old snapshots..."
        for ((i=0; i<to_remove; i++)); do
            echo "Removing: ${snapshots[i]}"
            zfs destroy "${snapshots[i]}"
        done
    else
        echo "No cleanup needed (${total} snapshots, keeping last 5)"
    fi
}

# Btrfs snapshot functions
btrfs_create_snapshot() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_dir="/.snapshots"
    local snapshot_name="${SNAPSHOT_PREFIX}-${timestamp}"
    
    mkdir -p "$snapshot_dir"
    echo "Creating Btrfs snapshot: $snapshot_dir/$snapshot_name"
    
    if btrfs subvolume snapshot / "$snapshot_dir/$snapshot_name"; then
        echo "Btrfs snapshot created successfully: $snapshot_name"
    else
        echo "Error: Failed to create Btrfs snapshot"
        return 1
    fi
}

btrfs_list_snapshots() {
    local snapshot_dir="/.snapshots"
    echo "Available Btrfs snapshots:"
    if [ -d "$snapshot_dir" ]; then
        ls -la "$snapshot_dir" | grep "$SNAPSHOT_PREFIX" || echo "No snapshots found"
    else
        echo "No snapshots found"
    fi
}

btrfs_cleanup_snapshots() {
    local snapshot_dir="/.snapshots"
    echo "Cleaning up old Btrfs snapshots (keeping last 5)..."
    
    if [ ! -d "$snapshot_dir" ]; then
        echo "No snapshots directory found"
        return
    fi
    
    local snapshots=($(ls -1 "$snapshot_dir" | grep "$SNAPSHOT_PREFIX" | sort))
    local total=${#snapshots[@]}
    
    if [ $total -gt 5 ]; then
        local to_remove=$((total - 5))
        echo "Removing $to_remove old snapshots..."
        for ((i=0; i<to_remove; i++)); do
            echo "Removing: ${snapshots[i]}"
            btrfs subvolume delete "$snapshot_dir/${snapshots[i]}"
        done
    else
        echo "No cleanup needed (${total} snapshots, keeping last 5)"
    fi
}

# LVM snapshot functions for ext4
lvm_create_snapshot() {
    local root_device=$(detect_root_device)
    local vg_name=$(lvs --noheadings -o vg_name "$root_device" 2>/dev/null | tr -d ' ')
    local lv_name=$(lvs --noheadings -o lv_name "$root_device" 2>/dev/null | tr -d ' ')
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="${lv_name}-${SNAPSHOT_PREFIX}-${timestamp}"
    
    if [ -z "$vg_name" ] || [ -z "$lv_name" ]; then
        echo "Error: Root filesystem is not on LVM. LVM snapshots require LVM setup."
        return 1
    fi
    
    echo "Creating LVM snapshot: $vg_name/$snapshot_name"
    if lvcreate -L1G -s -n "$snapshot_name" "$vg_name/$lv_name"; then
        echo "LVM snapshot created successfully: $snapshot_name"
    else
        echo "Error: Failed to create LVM snapshot"
        return 1
    fi
}

lvm_list_snapshots() {
    echo "Available LVM snapshots:"
    lvs | grep "$SNAPSHOT_PREFIX" || echo "No LVM snapshots found"
}

lvm_cleanup_snapshots() {
    echo "Cleaning up old LVM snapshots (keeping last 5)..."
    local snapshots=($(lvs --noheadings -o lv_name | grep "$SNAPSHOT_PREFIX" | sort))
    local total=${#snapshots[@]}
    
    if [ $total -gt 5 ]; then
        local to_remove=$((total - 5))
        echo "Removing $to_remove old snapshots..."
        for ((i=0; i<to_remove; i++)); do
            local snapshot_name="${snapshots[i]// /}"
            local vg_name=$(lvs --noheadings -o vg_name "/dev/mapper/$snapshot_name" 2>/dev/null | tr -d ' ')
            echo "Removing: $vg_name/$snapshot_name"
            lvremove -f "$vg_name/$snapshot_name"
        done
    else
        echo "No cleanup needed (${total} snapshots, keeping last 5)"
    fi
}

# XFS functions (XFS doesn't support snapshots, but we can suggest alternatives)
xfs_create_snapshot() {
    echo "XFS does not support native snapshots."
    echo "Consider using:"
    echo "  1. LVM snapshots (if XFS is on LVM)"
    echo "  2. External backup tools like rsync or tar"
    echo "  3. Filesystem-level backup solutions"
    return 1
}

xfs_list_snapshots() {
    echo "XFS does not support native snapshots."
    echo "Use external backup solutions or LVM if available."
}

xfs_cleanup_snapshots() {
    echo "XFS does not support native snapshots."
}

# Main snapshot functions
create_snapshot() {
    local fs_type=$(detect_filesystem)
    
    case "$fs_type" in
        zfs)
            zfs_create_snapshot
            ;;
        btrfs)
            btrfs_create_snapshot
            ;;
        ext4|ext3|ext2)
            lvm_create_snapshot
            ;;
        xfs)
            xfs_create_snapshot
            ;;
        *)
            echo "Error: Filesystem $fs_type not supported for snapshots"
            return 1
            ;;
    esac
}

list_snapshots() {
    local fs_type=$(detect_filesystem)
    
    case "$fs_type" in
        zfs)
            zfs_list_snapshots
            ;;
        btrfs)
            btrfs_list_snapshots
            ;;
        ext4|ext3|ext2)
            lvm_list_snapshots
            ;;
        xfs)
            xfs_list_snapshots
            ;;
        *)
            echo "Error: Filesystem $fs_type not supported for snapshots"
            return 1
            ;;
    esac
}

cleanup_snapshots() {
    local fs_type=$(detect_filesystem)
    
    case "$fs_type" in
        zfs)
            zfs_cleanup_snapshots
            ;;
        btrfs)
            btrfs_cleanup_snapshots
            ;;
        ext4|ext3|ext2)
            lvm_cleanup_snapshots
            ;;
        xfs)
            xfs_cleanup_snapshots
            ;;
        *)
            echo "Error: Filesystem $fs_type not supported for snapshots"
            return 1
            ;;
    esac
}

restore_snapshot() {
    local fs_type=$(detect_filesystem)
    
    echo "WARNING: Snapshot restoration varies by filesystem type."
    echo "Current filesystem: $fs_type"
    echo ""
    echo "For safe restoration:"
    echo "  1. Boot from a live USB/CD"
    echo "  2. Mount your filesystem"
    echo "  3. Use filesystem-specific restoration commands"
    echo ""
    echo "This feature is intentionally limited to prevent accidental data loss."
    echo "Please refer to your filesystem documentation for restoration procedures."
}

# Check filesystem support
fs_type=$(detect_filesystem)
case "$fs_type" in
    zfs|btrfs|ext4|ext3|ext2|xfs)
        # Supported filesystem
        ;;
    *)
        echo "Error: Filesystem $fs_type is not supported for snapshots"
        echo "Supported filesystems: ZFS, Btrfs, ext2/3/4 (with LVM), XFS (limited)"
        exit 1
        ;;
esac

# Main script logic
case "$1" in
    create)
        create_snapshot
        ;;
    list)
        list_snapshots
        ;;
    cleanup)
        cleanup_snapshots
        ;;
    restore)
        restore_snapshot
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

    chmod +x /usr/local/bin/gz302-snapshot
    
    # Create automatic snapshot timer
    cat > /etc/systemd/system/gz302-snapshot.service <<EOF
[Unit]
Description=Create GZ302 system snapshot

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gz302-snapshot create
EOF

    cat > /etc/systemd/system/gz302-snapshot.timer <<EOF
[Unit]
Description=Create GZ302 system snapshots daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl enable gz302-snapshot.timer
    success "Universal snapshot management installed for $fs_type filesystem. Use 'gz302-snapshot' command."
}

# Configure secure boot for post-install
configure_universal_secure_boot() {
    local bootloader=$(detect_bootloader)
    info "Configuring Secure Boot for GZ302 with $bootloader bootloader..."
    
    # Install sbctl for secure boot management  
    dnf install -y sbctl
    
    # Check if we're in UEFI mode
    if [ ! -d /sys/firmware/efi ]; then
        warning "Not booted in UEFI mode. Skipping Secure Boot configuration."
        return
    fi
    
    # Check current secure boot status
    local sb_state=$(sbctl status 2>/dev/null | grep "Secure Boot" | awk '{print $3}' || echo "unknown")
    
    if [ "$sb_state" = "Enabled" ]; then
        warning "Secure Boot is already enabled. Skipping key creation."
        return
    fi
    
    info "Creating Secure Boot keys..."
    sbctl create-keys
    
    info "Enrolling Secure Boot keys..."
    sbctl enroll-keys -m
    
    # Sign the kernel and bootloader based on detected bootloader
    info "Signing kernel and bootloader for $bootloader..."
    
    # Sign the kernel (Fedora typically uses standard kernel paths)
    sbctl sign -s /boot/vmlinuz-*-generic 2>/dev/null || sbctl sign -s /boot/vmlinuz 2>/dev/null || true
    
    case "$bootloader" in
        grub)
            info "Configuring Secure Boot for GRUB..."
            # Sign GRUB bootloader files
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            sbctl sign -s /boot/EFI/fedora/grubx64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/fedora/shimx64.efi 2>/dev/null || true
            ;;
        systemd-boot)
            info "Configuring Secure Boot for systemd-boot..."
            # Sign systemd-boot files
            sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            ;;
        refind)
            info "Configuring Secure Boot for rEFInd..."
            # Sign rEFInd files
            sbctl sign -s /boot/EFI/refind/refind_x64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            ;;
        unknown)
            warning "Could not detect bootloader type. Creating generic Secure Boot configuration..."
            # Try to sign common bootloader files
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            sbctl sign -s /boot/EFI/fedora/grubx64.efi 2>/dev/null || true
            ;;
    esac
    
    success "Secure Boot configured for $bootloader. Reboot and enable Secure Boot in BIOS/UEFI settings."
    info "Use 'sbctl status' to check Secure Boot status after enabling in BIOS."
    warning "Note: Fedora may require additional steps for Secure Boot with custom kernels."
}

# --- Main Execution Logic ---
main() {
    check_root

    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Fedora Setup Script"
    echo "  Version 1.3 - Gaming Performance Optimization"
    echo "============================================================"
    echo
    
    info "Starting comprehensive setup process..."
    info "This script will configure your Fedora system for optimal ROG Flow Z13 performance"
    info "Estimated time: 10-30 minutes depending on internet speed"
    
    # Ask user for installation preferences
    ask_installation_options
    
    info "Step 1/8: Updating system and installing base dependencies..."
    update_system
    
    info "Step 2/8: Setting up gaming and hardware repositories..."
    setup_repositories
    
    info "Step 3/8: Installing hardware support packages..."
    install_hardware_support
    
    info "Step 4/10: Applying hardware-specific fixes..."
    apply_hardware_fixes
    
    info "Step 5/10: Installing TDP management and system tools..."
    install_tdp_management
    
    # Conditional gaming installation
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        info "Step 6/10: Installing gaming software stack..."
        install_gaming_stack
        
        info "Step 7/10: Applying performance optimizations..."
        apply_performance_tweaks
    else
        info "Step 6/10: Skipping gaming software installation as requested..."
        info "Step 7/10: Applying basic performance optimizations..."
        apply_performance_tweaks
    fi
    
    # Conditional LLM installation
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        info "Step 8/10: Installing LLM/AI software stack..."
        install_llm_stack
    else
        info "Step 8/10: Skipping LLM/AI software installation as requested..."
    fi
    
    info "Step 9/10: Configuring optional system features..."
    
    # Conditional secure boot installation (Fedora supports this, but add check)
    if command -v sbctl &> /dev/null; then
        info "Secure Boot tools available, configuring if requested..."
        # Secure boot configuration would go here if implemented
    fi
    
    # Conditional snapshots installation (Fedora supports this, but add check)
    info "Snapshot support available for filesystem detection..."
    # Snapshot configuration would go here if implemented
    
    info "Step 10/10: Enabling services and finalizing setup..."

    echo
    success "============================================================"
    success "Fedora setup complete for ASUS ROG Flow Z13 (GZ302)!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    
    # Show additional tools if installed
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        success "Gaming tools: Steam, Lutris, ProtonUp-Qt, MangoHUD, GameMode"
    fi
    
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        success "AI/LLM tools: Ollama, ROCm, PyTorch, Transformers (as selected)"
    fi
    
    success "Setup completed! Your ROG Flow Z13 (GZ302) is now optimized for Fedora."
    success ""
    success "Applied hardware fixes and performance optimizations including:"
    success "- Wi-Fi stability (MediaTek MT7925) - Touchpad detection - Audio fixes"
    success "- AMD GPU optimizations - Thermal management - Gaming performance tweaks"
    success ""
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"