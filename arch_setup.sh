#!/bin/bash

# ==============================================================================
# Comprehensive Arch Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.5
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
    # Enhanced fixes based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
    info "Applying Wi-Fi stability fixes for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# Disable ASPM for the MediaTek MT7925E to improve stability
options mt7925e disable_aspm=1
# Additional stability parameters
options mt7925e power_save=0
# Enhanced stability fixes from research
options mt7925e swcrypto=0
options mt7925e amsdu=0
options mt7925e disable_11ax=0
options mt7925e disable_radar_background=1
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
# Additional NetworkManager optimizations
wifi.backend=wpa_supplicant

[main]
# Reduce scan frequency for stability
wifi.scan-rand-mac-address=no
EOF

    # Add additional udev rules for Wi-Fi stability
    cat > /etc/udev/rules.d/99-wifi-powersave.rules <<EOF
# Disable Wi-Fi power saving for MediaTek MT7925e
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev \$name set power_save off"
EOF

    success "Enhanced Wi-Fi fixes for MediaTek MT7925 applied."

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

# --- TDP Management Functions ---
# Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR

# Install TDP management tools and configure profiles
install_tdp_management() {
    info "Installing TDP management for GZ302..."
    
    # Install ryzenadj for AMD TDP control
    sudo -u "$PRIMARY_USER" yay -S --noconfirm ryzenadj-git
    
    # Create TDP management script
    cat > /usr/local/bin/gz302-tdp <<'EOF'
#!/bin/bash
# GZ302 TDP Management Script
# Based on research from Shahzebqazi's Asus-Z13-Flow-2025-PCMR

TDP_CONFIG_DIR="/etc/gz302-tdp"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"

# TDP Profiles (in mW)
declare -A TDP_PROFILES
TDP_PROFILES[gaming]="54000"      # Maximum performance for gaming
TDP_PROFILES[performance]="45000" # High performance
TDP_PROFILES[balanced]="35000"    # Balanced performance/efficiency
TDP_PROFILES[efficient]="15000"   # Maximum efficiency

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

# --- Universal Secure Boot Functions ---
# Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
# Enhanced to support multiple bootloaders: GRUB, systemd-boot, rEFInd

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

# Configure secure boot for post-install
configure_universal_secure_boot() {
    local bootloader=$(detect_bootloader)
    info "Configuring Secure Boot for GZ302 with $bootloader bootloader..."
    
    # Install sbctl for secure boot management
    pacman -S --noconfirm --needed sbctl
    
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
    
    # Sign the kernel
    sbctl sign -s /boot/vmlinuz-linux-g14
    
    case "$bootloader" in
        grub)
            info "Configuring Secure Boot for GRUB..."
            # Sign GRUB bootloader files
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            sbctl sign -s /boot/EFI/*/grubx64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/*/grub.efi 2>/dev/null || true
            
            # Create GRUB-specific hook
            mkdir -p /etc/pacman.d/hooks
            cat > /etc/pacman.d/hooks/95-secureboot-grub.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-g14
Target = grub

[Action]
Description = Signing kernel and GRUB for Secure Boot
When = PostTransaction
Exec = /usr/bin/sbctl sign -s /boot/vmlinuz-linux-g14
Exec = /usr/bin/sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
Depends = sbctl
EOF
            ;;
        systemd-boot)
            info "Configuring Secure Boot for systemd-boot..."
            # Sign systemd-boot files
            sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            
            # Create systemd-boot specific hook
            mkdir -p /etc/pacman.d/hooks
            cat > /etc/pacman.d/hooks/95-secureboot-systemd.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-g14
Target = systemd

[Action]
Description = Signing kernel and systemd-boot for Secure Boot
When = PostTransaction
Exec = /usr/bin/sbctl sign -s /boot/vmlinuz-linux-g14
Exec = /usr/bin/sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
Depends = sbctl
EOF
            ;;
        refind)
            info "Configuring Secure Boot for rEFInd..."
            # Sign rEFInd files
            sbctl sign -s /boot/EFI/refind/refind_x64.efi 2>/dev/null || true
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            
            # Create rEFInd specific hook
            mkdir -p /etc/pacman.d/hooks
            cat > /etc/pacman.d/hooks/95-secureboot-refind.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-g14
Target = refind

[Action]
Description = Signing kernel and rEFInd for Secure Boot
When = PostTransaction
Exec = /usr/bin/sbctl sign -s /boot/vmlinuz-linux-g14
Exec = /usr/bin/sbctl sign -s /boot/EFI/refind/refind_x64.efi
Depends = sbctl
EOF
            ;;
        unknown)
            warning "Could not detect bootloader type. Creating generic Secure Boot configuration..."
            # Try to sign common bootloader files
            sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
            sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi 2>/dev/null || true
            
            # Create generic hook
            mkdir -p /etc/pacman.d/hooks
            cat > /etc/pacman.d/hooks/95-secureboot-generic.hook <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-g14

[Action]
Description = Signing kernel for Secure Boot
When = PostTransaction
Exec = /usr/bin/sbctl sign -s /boot/vmlinuz-linux-g14
Depends = sbctl
EOF
            ;;
    esac
    
    success "Secure Boot configured for $bootloader. Reboot and enable Secure Boot in BIOS/UEFI settings."
    info "Use 'sbctl status' to check Secure Boot status after enabling in BIOS."
}

# --- Universal Snapshot Functions ---
# Based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
# Enhanced to support multiple filesystems: ZFS, Btrfs, ext4, XFS

# Detect root filesystem type
detect_root_filesystem() {
    local root_device=$(findmnt -n -o SOURCE /)
    local fs_type=$(findmnt -n -o FSTYPE /)
    
    echo "Root filesystem: $fs_type on $root_device" >&2
    echo "$fs_type"
}

# Install and configure universal snapshots for system recovery
install_universal_snapshots() {
    local fs_type=$(detect_root_filesystem)
    info "Installing snapshot management for $fs_type filesystem..."
    
    case "$fs_type" in
        zfs)
            info "Detected ZFS filesystem. Installing ZFS snapshot utilities..."
            pacman -S --noconfirm --needed zfs-utils
            ;;
        btrfs)
            info "Detected Btrfs filesystem. Installing Btrfs snapshot utilities..."
            pacman -S --noconfirm --needed btrfs-progs snapper
            ;;
        ext4|ext3|ext2)
            info "Detected ext filesystem. Installing LVM snapshot utilities..."
            pacman -S --noconfirm --needed lvm2
            ;;
        xfs)
            info "Detected XFS filesystem. Installing XFS utilities..."
            pacman -S --noconfirm --needed xfsprogs
            ;;
        *)
            warning "Filesystem $fs_type not supported for automatic snapshots."
            warning "Supported filesystems: ZFS, Btrfs, ext2/3/4 (with LVM), XFS"
            return 1
            ;;
    esac
    
    # Create universal snapshot management script
    cat > /usr/local/bin/gz302-snapshot <<'EOF'
#!/bin/bash
# GZ302 Universal Snapshot Management
# Supports ZFS, Btrfs, ext4 (with LVM), and XFS filesystems
# Based on research from Shahzebqazi's Asus-Z13-Flow-2025-PCMR

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

# --- LLM Installation Functions ---

# User choice function for installation options
ask_installation_options() {
    echo ""
    info "Installation Configuration:"
    echo "This script can install gaming software, LLM frameworks, and system security/backup features."
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

# Install ROCm for AMD GPU acceleration (Arch)
# Install ROCm for AMD GPU acceleration (Arch)
# Enhanced based on research from: https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR
install_rocm() {
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Install ROCm packages from AUR with enhanced configuration
    sudo -u "$PRIMARY_USER" yay -S --noconfirm rocm-dev rocm-opencl-runtime hip-runtime-amd rocm-cmake rocblas miopen-hip
    
    # Add user to render and video groups for GPU access
    if [ -n "$PRIMARY_USER" ]; then
        usermod -a -G render,video "$PRIMARY_USER"
        info "User $PRIMARY_USER added to render and video groups for GPU access."
    fi
    
    # Configure ROCm environment variables
    cat >> /etc/environment <<EOF

# ROCm Configuration for GZ302 - Enhanced
ROC_ENABLE_PRE_VEGA=1
HSA_OVERRIDE_GFX_VERSION=11.0.0
ROCM_PATH=/opt/rocm
HIP_VISIBLE_DEVICES=0
HCC_AMDGPU_TARGET=gfx1100
EOF

    # Create ROCm library configuration
    mkdir -p /etc/ld.so.conf.d/
    echo "/opt/rocm/lib" > /etc/ld.so.conf.d/rocm.conf
    echo "/opt/rocm/lib64" >> /etc/ld.so.conf.d/rocm.conf
    ldconfig
    
    success "Enhanced ROCm installed successfully. Reboot required for full functionality."
}

# Install PyTorch with ROCm support
install_pytorch_rocm() {
    info "Installing PyTorch with ROCm support..."
    
    # Install pip if not present
    pacman -S --noconfirm python-pip
    
    # Install PyTorch with ROCm support
    sudo -u "$PRIMARY_USER" pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
    
    success "PyTorch with ROCm support installed successfully."
}

# Install Hugging Face Transformers
install_transformers() {
    info "Installing Hugging Face Transformers library..."
    
    # Install pip if not present
    pacman -S --noconfirm python-pip
    
    # Install transformers and related packages
    sudo -u "$PRIMARY_USER" pip install transformers accelerate datasets tokenizers
    
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

# --- Hypervisor Installation Functions ---

# Install hypervisor stack based on user choice
install_hypervisor_stack() {
    local choice="$1"
    info "Installing hypervisor software for Arch-based system..."
    
    case "$choice" in
        1)
            info "Installing KVM/QEMU with virt-manager..."
            # Resolve iptables conflict: replace iptables with iptables-nft if needed
            yes | pacman -S --needed iptables-nft
            pacman -S --noconfirm --needed qemu-full virt-manager libvirt ebtables dnsmasq bridge-utils openbsd-netcat
            systemctl enable --now libvirtd
            local primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                usermod -a -G libvirt "$primary_user"
            fi
            success "KVM/QEMU with virt-manager installed"
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
    info "Estimated time: 15-40 minutes depending on internet speed and optional components"
    
    # Ask user for installation preferences
    ask_installation_options
    
    info "Step 1/10: Updating system and installing base dependencies..."
    update_system
    
    info "Step 2/10: Setting up ASUS-specific repositories..."
    setup_g14_repo
    
    info "Step 3/10: Installing specialized kernel and ASUS tools..."
    install_kernel_and_asus_tools
    
    info "Step 4/10: Applying hardware-specific fixes..."
    apply_hardware_fixes
    
    info "Step 5/10: Installing TDP management and system tools..."
    install_tdp_management
    
    # Conditional gaming installation
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        info "Step 6/10: Installing gaming software stack..."
        install_gaming_stack
        
        info "Step 7/10: Installing AUR helper..."
        install_aur_helper
    else
        info "Step 6/10: Skipping gaming software installation as requested..."
        info "Step 7/10: Installing AUR helper..."
        install_aur_helper
    fi
    
    # Conditional LLM installation
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        info "Step 8/10: Installing LLM/AI software stack..."
        install_llm_stack
    else
        info "Step 8/10: Skipping LLM/AI software installation as requested..."
    fi
    
    # Conditional hypervisor installation
    if [[ "${install_hypervisor}" =~ ^[1-5]$ ]]; then
        info "Step 9/11: Installing hypervisor software..."
        install_hypervisor_stack "${install_hypervisor}"
    else
        info "Step 9/11: Skipping hypervisor installation as requested..."
    fi
    
    info "Step 10/11: Configuring optional system features..."
    
    # Conditional secure boot installation
    if [[ "${install_secureboot,,}" == "y" || "${install_secureboot,,}" == "yes" ]]; then
        info "Configuring Secure Boot..."
        configure_universal_secure_boot
    else
        info "Skipping Secure Boot configuration as requested..."
    fi
    
    # Conditional snapshots installation
    if [[ "${install_snapshots,,}" == "y" || "${install_snapshots,,}" == "yes" ]]; then
        info "Configuring system snapshots..."
        install_universal_snapshots
    else
        info "Skipping system snapshots configuration as requested..."
    fi
    
    info "Step 11/11: Applying performance optimizations and enabling services..."
    apply_performance_tweaks
    enable_services

    echo
    success "============================================================"
    success "GZ302 Linux Setup Complete! (Version 1.5)"
    success "It is highly recommended to REBOOT your system now."
    success "After rebooting, make sure to select the 'linux-g14' kernel"
    success "from your bootloader menu."
    success ""
    success "New in Version 1.5:"
    success "- Enhanced camera support for GZ302"
    success "- TDP management: Use 'gz302-tdp' command"
    success "- Universal Secure Boot configuration with bootloader detection"
    success "- Universal snapshots: Use 'gz302-snapshot' command (supports ZFS, Btrfs, ext4, XFS)"
    success "- Improved Wi-Fi stability for MediaTek MT7925e"
    success "- Enhanced ROCm configuration for AI/ML workloads"
    success ""
    success "Available TDP profiles: gaming, performance, balanced, efficient"
    success "Check power status with: gz302-tdp status"
    success ""
    
    # Show gaming tools if installed
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        success "Installed gaming tools:"
        success "- Steam with Proton support"
        success "- Lutris for game management"
        success "- ProtonUp-Qt for Proton version management"
        success "- MangoHUD and Goverlay for performance monitoring"
        success "- CoreCtrl for GPU performance control"
        success "- GameMode for automatic gaming optimizations"
        success ""
    fi
    
    # Show LLM tools if installed
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        success "Installed LLM/AI tools:"
        success "- Ollama for local LLM inference (if selected)"
        success "- ROCm for AMD GPU acceleration (if selected)"
        success "- PyTorch with ROCm support (if selected)"
        success "- Hugging Face Transformers (if selected)"
        success ""
    fi
    
    # Show hypervisor if installed
    if [[ "${install_hypervisor}" =~ ^[1-5]$ ]]; then
        success "Installed hypervisor:"
        case "${install_hypervisor}" in
            1) success "- KVM/QEMU with virt-manager for virtualization" ;;
            2) success "- VirtualBox for virtualization" ;;
            3) success "- VMware Workstation Pro for virtualization" ;;
            4) success "- Xen hypervisor (requires configuration)" ;;
            5) success "- LXC/LXD containers as Proxmox alternative" ;;
        esac
        success ""
    fi
    
    # Show secure boot status if installed
    if [[ "${install_secureboot,,}" == "y" || "${install_secureboot,,}" == "yes" ]]; then
        success "Secure Boot configured:"
        success "- Bootloader and kernel signing enabled"
        success "- Automatic signing on updates"
        success "- Use 'sbctl status' to check status after enabling in BIOS"
        success ""
    fi
    
    # Show snapshot status if installed
    if [[ "${install_snapshots,,}" == "y" || "${install_snapshots,,}" == "yes" ]]; then
        local fs_type=$(detect_root_filesystem)
        success "System snapshots configured for $fs_type:"
        success "- Daily automatic snapshots enabled"
        success "- Manual management with 'gz302-snapshot' command"
        success "- Supports create, list, cleanup, and restore operations"
        success ""
    fi
    
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
    success "ASUS ROG Flow Z13 (GZ302)!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"
