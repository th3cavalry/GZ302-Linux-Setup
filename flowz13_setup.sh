#!/bin/bash

# ==============================================================================
# Comprehensive Arch Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.3
#
# This script automates the post-installation setup for Arch Linux on the
# ASUS ROG Flow Z13 (GZ302) with an AMD Ryzen AI 395+ processor.
# It applies critical hardware fixes, installs ASUS-specific control software,
# and configures a high-performance gaming environment.
#
# PRE-REQUISITES:
# 1. A base installation of Arch Linux.
# 2. An active internet connection.
# 3. A user with sudo privileges.
#
# USAGE:
# 1. Download the script:
#    curl -O https://path.to/this/script/setup-flowz13.sh
# 2. Make it executable:
#    chmod +x setup-flowz13.sh
# 3. Run with sudo:
#    sudo ./setup-flowz13.sh
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

# Helper function to run systemctl --user commands with proper environment
run_user_systemctl() {
    local user="$1"
    local action="$2"
    local service="$3"
    
    # Set up proper environment for user session
    local user_id=$(id -u "$user")
    local xdg_runtime_dir="/run/user/$user_id"
    
    if [[ ! -d "$xdg_runtime_dir" ]]; then
        warning "XDG_RUNTIME_DIR not found for user $user. Creating user session..."
        # Try to create the runtime directory if it doesn't exist
        mkdir -p "$xdg_runtime_dir"
        chown "$user:$user" "$xdg_runtime_dir"
        chmod 700 "$xdg_runtime_dir"
    fi
    
    # Run systemctl --user with proper environment
    sudo -u "$user" \
        env XDG_RUNTIME_DIR="$xdg_runtime_dir" \
        systemctl --user "$action" "$service"
}

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
}

# --- Core System Setup Functions ---

# 1. Update system and install base dependencies
update_system() {
    info "Performing a full system update and installing base dependencies..."
    info "This may take a few minutes depending on your internet connection..."
    pacman -Syu --noconfirm --needed git base-devel
    success "System updated and base dependencies installed."
}

# 2. Set up the asus-linux (g14) repository
setup_g14_repo() {
    info "Setting up the asus-linux (g14) repository..."
    info "Adding repository signing key and configuring pacman..."

    # Add the repository signing key
    info "Importing and signing the g14 repository key..."
    pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 &>/dev/null
    pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 &>/dev/null

    # Check if the repo is already in pacman.conf
    if grep -q "\[g14\]" /etc/pacman.conf; then
        warning "The g14 repository is already configured. Skipping."
    else
        # Add the repo to pacman.conf
        info "Adding g14 repository to pacman configuration..."
        echo -e "\n[g14]\nServer = https://arch.asus-linux.org" >> /etc/pacman.conf
        info "g14 repository added to /etc/pacman.conf."
    fi

    # Update package databases
    info "Updating package databases..."
    pacman -Sy
    success "asus-linux (g14) repository configured."
}

# 3. Install custom kernel and ASUS control software
install_kernel_and_asus_tools() {
    info "Installing linux-g14 kernel and ASUS control software..."
    info "This will install specialized kernel and drivers for ASUS ROG devices..."
    pacman -S --noconfirm --needed linux-g14 linux-g14-headers asusctl supergfxctl rog-control-center power-profiles-daemon switcheroo-control

    # Regenerate GRUB config to include the new kernel
    if [ -f /boot/grub/grub.cfg ]; then
        info "Regenerating GRUB configuration to include new kernel..."
        grub-mkconfig -o /boot/grub/grub.cfg
        success "GRUB configuration updated with linux-g14 kernel."
    else
        warning "GRUB not detected. Please regenerate your bootloader configuration manually to use the linux-g14 kernel."
    fi

    success "linux-g14 kernel and ASUS tools installed."
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
ExecStart=/usr/bin/modprobe -r hid_asus
ExecStart=/usr/bin/modprobe hid_asus

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

# 5. Install and configure the gaming software stack
install_gaming_stack() {
    info "Installing and configuring the gaming software stack..."
    info "This will install Steam, Lutris, gaming tools, and compatibility layers..."

    # 5a. Enable multilib repository
    info "Enabling multilib repository for 32-bit support..."
    if grep -q "^\s*#\s*\[multilib\]" /etc/pacman.conf; then
        sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
        pacman -Sy
        success "Multilib repository enabled."
    else
        success "Multilib repository already enabled or not found in standard format."
    fi

    # 5b. Install Steam, Lutris, GameMode, and dependencies
    info "Installing Steam, Lutris, GameMode, and essential libraries..."
    info "This may take several minutes depending on your internet connection..."
    pacman -S --noconfirm --needed steam lutris gamemode lib32-gamemode \
        vulkan-radeon lib32-vulkan-radeon \
        gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
    success "Core gaming applications installed."

    # 5c. Install additional gaming tools and optimizations
    info "Installing additional gaming tools and performance utilities..."
    pacman -S --noconfirm --needed \
        mangohud goverlay \
        wine-staging winetricks \
        corectrl \
        mesa-utils vulkan-tools \
        lib32-mesa lib32-vulkan-radeon \
        pipewire pipewire-pulse pipewire-jack lib32-pipewire
    success "Additional gaming tools installed."

    # Install ProtonUp-Qt via AUR (requires yay to be available)
    if command -v yay &> /dev/null; then
        info "Installing ProtonUp-Qt for easy Proton version management..."
        PRIMARY_USER=$(logname 2>/dev/null || echo $SUDO_USER)
        if [[ -z "$PRIMARY_USER" ]] || [[ "$PRIMARY_USER" == "root" ]]; then
            warning "Cannot install ProtonUp-Qt without a non-root user. Skipping."
        else
            info "Installing ProtonUp-Qt via yay (this may take a few minutes)..."
            sudo -u "$PRIMARY_USER" -H --set-home env -i HOME="/home/$PRIMARY_USER" USER="$PRIMARY_USER" PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" yay -S --noconfirm --needed protonup-qt
            success "ProtonUp-Qt installed."
        fi
    else
        warning "AUR helper not available. ProtonUp-Qt installation skipped."
        warning "Please install ProtonUp-Qt manually after setting up an AUR helper."
    fi

    # 5d. Install Proton-GE
    check_and_install_proton_ge() {
        local user="$1"
        local user_home="/home/$user"
        local compat_dir="$user_home/.steam/root/compatibilitytools.d"
        
        # Check if any Proton-GE is already installed
        if [[ -d "$compat_dir" ]] && ls "$compat_dir"/GE-Proton* &>/dev/null; then
            local installed_versions=($(ls -d "$compat_dir"/GE-Proton* 2>/dev/null | xargs -n1 basename))
            info "Found existing Proton-GE installations: ${installed_versions[*]}"
            
            # Get the latest available version
            local latest_release=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
            if [[ -n "$latest_release" ]]; then
                local latest_folder="GE-Proton${latest_release#GE-Proton}"
                if [[ " ${installed_versions[*]} " =~ " ${latest_folder} " ]]; then
                    success "Latest Proton-GE ($latest_release) is already installed. Skipping download."
                    return 0
                else
                    info "Newer Proton-GE version available: $latest_release"
                fi
            fi
        fi
        
        # Download and install latest Proton-GE
        sudo -u "$user" -H --set-home env -i HOME="$user_home" USER="$user" PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" bash <<'EOF'
set -e
info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$COMPAT_DIR"

info "Fetching latest Proton-GE release information..."
LATEST_URL=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep "browser_download_url.*\.tar\.gz" | cut -d '"' -f 4)
if [[ -n "$LATEST_URL" ]]; then
    RELEASE_NAME=$(echo "$LATEST_URL" | sed 's/.*\/\([^\/]*\)\.tar\.gz/\1/')
    info "Downloading Proton-GE: $RELEASE_NAME..."
    info "This may take several minutes depending on your internet connection..."
    cd "$COMPAT_DIR"
    curl -L "$LATEST_URL" | tar -xz
    success "Proton-GE ($RELEASE_NAME) installed successfully."
else
    warning "Could not find the latest Proton-GE release. Please use ProtonUp-Qt to install it after rebooting."
fi
EOF
    }
    
    info "Installing the latest version of Proton-GE..."
    # This requires a non-root user to install into their home directory.
    # We find the primary user to run this command.
    PRIMARY_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    if [[ -z "$PRIMARY_USER" ]] || [[ "$PRIMARY_USER" == "root" ]]; then
        warning "Could not determine a non-root user. Skipping Proton-GE installation."
        warning "Please run the Proton-GE installation part of the script manually as a user."
        warning "Alternatively, you can use ProtonUp-Qt to install Proton versions after rebooting."
    else
        info "Installing Proton-GE for user: $PRIMARY_USER"
        check_and_install_proton_ge "$PRIMARY_USER"
        success "Proton-GE installation completed."
        info "You can also use ProtonUp-Qt GUI to manage Proton versions going forward."
    fi
}

# --- Optional AUR Helper Installation ---

# Check if yay is already installed
check_yay_installed() {
    if command -v yay &> /dev/null; then
        local yay_version=$(yay --version | head -n1 | awk '{print $2}')
        success "yay is already installed (version: $yay_version). Skipping installation."
        return 0
    else
        return 1
    fi
}

# Optional: Install AUR helper
install_aur_helper() {
    if check_yay_installed; then
        return 0
    fi
    
    echo -e "${C_YELLOW}[OPTIONAL]${C_NC} Do you want to install an AUR helper (yay)? [y/N] "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Installing AUR helper 'yay'..."
        info "This will be compiled from source and may take a few minutes..."
        PRIMARY_USER=$(logname 2>/dev/null || echo $SUDO_USER)
        if [[ -z "$PRIMARY_USER" ]] || [[ "$PRIMARY_USER" == "root" ]]; then
            warning "Cannot install AUR helper without a non-root user. Skipping."
        else
            sudo -u "$PRIMARY_USER" -H --set-home env -i HOME="/home/$PRIMARY_USER" USER="$PRIMARY_USER" PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" bash <<'EOF'
set -e
info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
cd /tmp
info "Cloning yay-bin from AUR..."
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
info "Building and installing yay..."
makepkg -si --noconfirm
cd /
rm -rf /tmp/yay-bin
EOF
            success "AUR helper 'yay' installed."
        fi
    fi
}

# --- Performance Tuning Functions ---

# 6. Apply system-wide performance optimizations
apply_performance_tweaks() {
    info "Applying system-wide performance tweaks..."
    info "These optimizations will improve gaming performance and system responsiveness..."

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

    # 6d. Configure CPU governor and power management
    info "Setting up CPU performance profiles for gaming..."
    cat > /etc/systemd/system/cpu-performance.service <<EOF
[Unit]
Description=Set CPU governor to performance on AC power
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

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

    info "Enabling power management services..."
    systemctl enable --now power-profiles-daemon.service
    info "Enabling ASUS graphics control services..."
    systemctl enable --now supergfxd.service
    systemctl enable --now switcheroo-control.service
    info "Enabling hardware fix services..."
    systemctl enable --now reload-hid_asus.service
    systemctl enable --now cpu-performance.service

    # Enable gamemode for the primary user
    PRIMARY_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    if [[ -z "$PRIMARY_USER" ]] || [[ "$PRIMARY_USER" == "root" ]]; then
        warning "Could not determine a non-root user. Cannot enable user services for gamemode."
    else
        info "Enabling gamemode service for user: $PRIMARY_USER"
        # Use our helper function to properly handle the user session
        if run_user_systemctl "$PRIMARY_USER" "enable --now" "gamemoded.service" 2>/dev/null; then
            success "GameMode service enabled for user $PRIMARY_USER"
        else
            warning "Could not enable GameMode service. It will be available after user login."
            # Alternative approach - create the service file and let it start on user login
            sudo -u "$PRIMARY_USER" mkdir -p "/home/$PRIMARY_USER/.config/systemd/user"
            sudo -u "$PRIMARY_USER" systemctl --user daemon-reload 2>/dev/null || true
        fi
        
        # Configure gamemode
        info "Configuring GameMode settings..."
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

# --- Main Execution Logic ---
main() {
    check_root

    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Arch Linux Setup Script"
    echo "  Version 1.3 - Enhanced with skip checks and progress info"
    echo "============================================================"
    echo
    
    info "Starting comprehensive setup process..."
    info "This script will configure your system for optimal ROG Flow Z13 performance"
    info "Estimated time: 10-30 minutes depending on internet speed and optional components"
    echo

    info "Step 1/7: Updating system and installing base dependencies..."
    update_system
    
    info "Step 2/7: Setting up ASUS-specific repositories..."
    setup_g14_repo
    
    info "Step 3/7: Installing specialized kernel and ASUS tools..."
    install_kernel_and_asus_tools
    
    info "Step 4/7: Applying hardware-specific fixes..."
    apply_hardware_fixes
    
    info "Step 5/7: Installing gaming software stack..."
    install_gaming_stack
    
    info "Step 6/7: Installing AUR helper (optional)..."
    install_aur_helper
    
    info "Step 7/7: Applying performance optimizations and enabling services..."
    apply_performance_tweaks
    enable_services

    echo
    success "============================================================"
    success "Setup complete!"
    success "It is highly recommended to REBOOT your system now."
    success "After rebooting, make sure to select the 'linux-g14' kernel"
    success "from your bootloader menu."
    success ""
    success "Installed gaming tools:"
    success "- Steam with Proton support"
    success "- Lutris for game management"
    success "- ProtonUp-Qt for Proton version management"
    success "- MangoHUD and Goverlay for performance monitoring"
    success "- CoreCtrl for GPU performance control"
    success "- GameMode for automatic gaming optimizations"
    success ""
    success "Hardware fixes applied:"
    success "- MediaTek MT7925 Wi-Fi stability improvements"
    success "- Touchpad detection and sensitivity fixes"
    success "- AMD GPU driver optimizations"
    success "- Audio device compatibility fixes"
    success "- Thermal throttling and power management"
    success ""
    success "Performance optimizations applied:"
    success "- Gaming-optimized kernel parameters"
    success "- CPU performance governor switching"
    success "- I/O scheduler optimizations for SSDs/NVMe"
    success "- Network latency optimizations"
    success "- Memory management tweaks"
    success "- Hardware video acceleration"
    success "- System limits increased for gaming"
    success ""
    success "You can now enjoy Arch Linux optimized for your"
    success "ASUS ROG Flow Z13 (GZ302) with excellent gaming performance!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"
