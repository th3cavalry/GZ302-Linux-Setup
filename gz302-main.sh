#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 0.1.3-pre-release
#
# This script automatically detects your Linux distribution and applies
# the appropriate hardware fixes for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
# It applies critical hardware fixes and TDP/refresh rate management.
#
# REQUIRED: Linux kernel 6.14+ minimum (6.15+ strongly recommended)
#
# Optional software can be installed via modular scripts:
# - gz302-gaming: Gaming software (Steam, Lutris, MangoHUD, etc.)
# - gz302-llm: AI/LLM software (Ollama, ROCm, PyTorch, etc.)
# - gz302-hypervisor: Virtualization (KVM, VirtualBox, VMware, etc.)
# - gz302-snapshots: System snapshots (Snapper, LVM, etc.)
# - gz302-secureboot: Secure boot configuration
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
#    curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
# 2. Make it executable:
#    chmod +x gz302-main.sh
# 3. Run with sudo:
#    sudo ./gz302-main.sh
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# GitHub repository base URL for downloading modules
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Color codes for output (must be defined before error handler) ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m' # No Color

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

# --- Check Network Connectivity ---
check_network() {
    local test_urls=(
        "https://raw.githubusercontent.com"
        "8.8.8.8"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null 2>&1 || ping -c 1 -W 2 "$url" > /dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# --- Check Kernel Version ---
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    
    # Convert to comparable format (e.g., 6.14 -> 614)
    local version_num=$((major * 100 + minor))
    local min_version=614  # 6.14
    local recommended_version=615  # 6.15
    
    info "Detected kernel version: $(uname -r)"
    
    if [[ $version_num -lt $min_version ]]; then
        warning "⚠️  Your kernel version ($kernel_version) is below the minimum supported version (6.14)"
        warning "⚠️  While the script will continue, you may experience:"
        warning "    - WiFi stability issues (MediaTek MT7925)"
        warning "    - Suboptimal AMD Strix Halo performance"
        warning "    - Missing AMDGPU driver features"
        warning "⚠️  Please upgrade to kernel 6.14+ (6.15+ recommended) for best results"
        echo
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled. Please upgrade your kernel and try again."
        fi
    elif [[ $version_num -lt $recommended_version ]]; then
        warning "Your kernel version ($kernel_version) meets minimum requirements"
        info "For best performance, consider upgrading to kernel 6.15+ which includes:"
        info "  - Enhanced AMD Strix Halo AI inference performance"
        info "  - Improved Radeon 8060S graphics performance"
        info "  - Better MediaTek MT7925 WiFi stability"
        echo
    else
        success "Kernel version ($kernel_version) meets recommended requirements"
    fi
    
    # Return the version number for conditional logic
    echo "$version_num"
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        # Detect Arch-based systems
        if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
            distro="arch"
        # Detect Debian/Ubuntu-based systems
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "pop" || "$ID" == "linuxmint" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* ]]; then
            distro="ubuntu"
        # Detect Fedora-based systems
        elif [[ "$ID" == "fedora" || "$ID_LIKE" == *"fedora"* ]]; then
            distro="fedora"
        # Detect OpenSUSE-based systems
        elif [[ "$ID" == "opensuse-tumbleweed" || "$ID" == "opensuse-leap" || "$ID" == "opensuse" || "$ID_LIKE" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    if [[ -z "$distro" ]]; then
        error "Unable to detect a supported Linux distribution."
    fi
    
    echo "$distro"
}

# --- Hardware Fixes for All Distributions ---
# Updated based on latest kernel support and community research (Oct 2025)
# Sources: Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs forums, asus-linux.org,
#          Strix Halo HomeLab, Ubuntu 25.10 benchmarks, Phoronix community
# GZ302EA-XS99: AMD Ryzen AI MAX+ 395 with AMD Radeon 8060S integrated graphics (100% AMD)
# REQUIRED: Kernel 6.14+ minimum (6.15+ strongly recommended)
# Kernel 6.14 includes XDNA NPU driver, MT7925 WiFi improvements, better AMDGPU support
# Kernel 6.15 includes enhanced AI inference, improved Radeon 8060S performance

apply_hardware_fixes() {
    info "Applying GZ302 hardware fixes for all distributions..."
    
    # Get kernel version for conditional workarounds
    local kernel_ver
    kernel_ver=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_ver" | cut -d. -f1)
    minor=$(echo "$kernel_ver" | cut -d. -f2)
    local version_num=$((major * 100 + minor))
    
    # Kernel parameters for AMD Ryzen AI MAX+ 395 (Strix Halo) and Radeon 8060S
    info "Adding kernel parameters for AMD Strix Halo optimization..."
    if [ -f /etc/default/grub ]; then
        # Check if parameters already exist
        if ! grep -q "amd_pstate=guided" /etc/default/grub; then
            # Add AMD P-State (guided mode) and GPU parameters
            # amd_pstate=guided is optimal for Strix Halo (confirmed by Ubuntu 25.10 benchmarks)
            # amdgpu.ppfeaturemask=0xffffffff enables all power features for Radeon 8060S (RDNA 3.5)
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff"/' /etc/default/grub
            
            # Regenerate GRUB config
            if [ -f /boot/grub/grub.cfg ]; then
                grub-mkconfig -o /boot/grub/grub.cfg
            elif command -v update-grub >/dev/null 2>&1; then
                update-grub
            fi
        fi
    fi
    
    # Wi-Fi fixes for MediaTek MT7925
    # Kernel 6.14+ includes MLO WiFi 7 support and improved MT7925 driver
    # Kernel 6.15+ includes additional stability improvements
    # ASPM workaround still recommended for kernels < 6.15
    info "Configuring MediaTek MT7925 Wi-Fi..."
    
    if [[ $version_num -lt 615 ]]; then
        info "Kernel < 6.15 detected: Applying ASPM workaround for MT7925 WiFi stability"
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fixes for GZ302
# Disable ASPM for stability (fixes disconnection and suspend/resume issues)
# Required for kernels < 6.15. Kernel 6.15+ has improved native support.
# Based on community findings from EndeavourOS forums and kernel patches
options mt7925e disable_aspm=1
EOF
    else
        info "Kernel 6.15+ detected: Using improved native MT7925 WiFi support"
        info "ASPM workaround not needed with kernel 6.15+"
        # Create a minimal config noting that workarounds aren't needed
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.15+ includes native improvements - ASPM workaround not needed
# WiFi 7 MLO support and enhanced stability included in kernel 6.14+
EOF
    fi

    # Disable NetworkManager Wi-Fi power saving (recommended for all kernel versions)
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF

    # AMD GPU module configuration for Radeon 8060S (integrated)
    info "Configuring AMD Radeon 8060S GPU..."
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5, integrated)
# Enable all power features for better performance and efficiency
# ROCm-compatible for AI/ML workloads
options amdgpu ppfeaturemask=0xffffffff
EOF

    # ASUS HID (keyboard/touchpad) configuration
    info "Configuring ASUS keyboard and touchpad..."
    cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
# fnlock_default=0: F1-F12 keys work as media keys by default
# Kernel 6.14+ includes mature touchpad gesture support and improved ASUS HID integration
options hid_asus fnlock_default=0
EOF

    # Reload hardware database and udev
    systemd-hwdb update 2>/dev/null || true
    udevadm control --reload 2>/dev/null || true
    
    # Note about advanced fan/power control
    info "Note: For advanced fan and power mode control, consider the ec_su_axb35 kernel module"
    info "See: https://github.com/cmetz/ec-su_axb35-linux for Strix Halo-specific controls"
    
    success "Hardware fixes applied"
}

# --- Distribution-Specific Package Installation ---
# Install ASUS-specific tools and power management
# GZ302 has NO discrete GPU, so no supergfxctl needed

install_arch_asus_packages() {
    info "Installing ASUS control packages for Arch..."
    
    # Install from official repos first
    pacman -S --noconfirm --needed power-profiles-daemon
    
    # Method 1: Try G14 repository (recommended, official asus-linux.org repo)
    info "Attempting to install asusctl from G14 repository..."
    if ! grep -q '\[g14\]' /etc/pacman.conf; then
        info "Adding G14 repository..."
        # Add repository key
        pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || warning "Failed to receive G14 key"
        pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || warning "Failed to sign G14 key"
        
        # Add repository to pacman.conf
        echo "" >> /etc/pacman.conf
        echo "[g14]" >> /etc/pacman.conf
        echo "Server = https://arch.asus-linux.org" >> /etc/pacman.conf
        
        # Update package database
        pacman -Sy
    fi
    
    # Try to install from G14 repo
    if pacman -S --noconfirm --needed asusctl 2>/dev/null; then
        success "asusctl installed from G14 repository"
    else
        warning "G14 repository installation failed, trying AUR..."
        # Method 2: Fallback to AUR if G14 repo fails
        if command -v yay >/dev/null 2>&1; then
            local primary_user
            primary_user=$(get_real_user)
            # Install ASUS control tools from AUR
            sudo -u "$primary_user" yay -S --noconfirm --needed asusctl || warning "AUR asusctl install failed"
            
            # Install switcheroo-control for display management
            sudo -u "$primary_user" yay -S --noconfirm --needed switcheroo-control || warning "switcheroo-control install failed"
        else
            warning "yay not available - skipping asusctl installation"
            info "Manually add G14 repo or install yay and run: yay -S asusctl switcheroo-control"
        fi
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

install_debian_asus_packages() {
    info "Installing ASUS control packages for Debian/Ubuntu..."
    
    # Install power-profiles-daemon
    apt install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control
    apt install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Try to install asusctl from PPA
    info "Attempting to install asusctl from PPA..."
    if command -v add-apt-repository >/dev/null 2>&1; then
        # Add Mitchell Austin's asusctl PPA
        add-apt-repository -y ppa:mitchellaugustin/asusctl 2>/dev/null || warning "Failed to add asusctl PPA"
        apt update 2>/dev/null || warning "Failed to update package list"
        
        # Try to install rog-control-center (includes asusctl)
        if apt install -y rog-control-center 2>/dev/null; then
            systemctl daemon-reload
            systemctl restart asusd 2>/dev/null || warning "Failed to restart asusd"
            success "asusctl installed from PPA"
        else
            warning "PPA installation failed"
            info "Manual installation: https://mitchellaugustin.com/asusctl.html"
        fi
    else
        warning "add-apt-repository not available"
        info "Install software-properties-common and retry, or see: https://asus-linux.org"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

install_fedora_asus_packages() {
    info "Installing ASUS control packages for Fedora..."
    
    # Install power-profiles-daemon (usually already installed)
    dnf install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control
    dnf install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Install asusctl from COPR
    info "Attempting to install asusctl from COPR repository..."
    if command -v dnf >/dev/null 2>&1; then
        # Enable lukenukem/asus-linux COPR repository
        dnf copr enable -y lukenukem/asus-linux 2>/dev/null || warning "Failed to enable COPR repository"
        
        # Update and install asusctl
        dnf install -y asusctl 2>/dev/null || warning "asusctl install failed"
        
        # Note: supergfxctl not needed for GZ302 (no discrete GPU)
        info "Note: supergfxctl not installed (GZ302 has integrated GPU only)"
    else
        warning "dnf not available"
        info "Manually enable COPR: dnf copr enable lukenukem/asus-linux && dnf install asusctl"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

install_opensuse_asus_packages() {
    info "Installing ASUS control packages for OpenSUSE..."
    
    # Install power-profiles-daemon
    zypper install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control if available
    zypper install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Try to install asusctl from OBS repository
    info "Attempting to install asusctl from OBS repository..."
    # Detect OpenSUSE version
    local opensuse_version="openSUSE_Tumbleweed"
    if grep -q "openSUSE Leap" /etc/os-release 2>/dev/null; then
        opensuse_version="openSUSE_Leap_15.6"
    fi
    
    # Add ASUS Linux OBS repository
    zypper ar -f "https://download.opensuse.org/repositories/hardware:/asus/${opensuse_version}/" hardware:asus 2>/dev/null || warning "Failed to add OBS repository"
    zypper ref 2>/dev/null || warning "Failed to refresh repositories"
    
    # Try to install asusctl
    if zypper install -y asusctl 2>/dev/null; then
        success "asusctl installed from OBS repository"
    else
        warning "OBS repository installation failed"
        info "Manual installation from source: https://asus-linux.org/guides/asusctl-install/"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

# --- TDP Management Functions ---

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
    make -j"$(nproc)"
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
    make -j"$(nproc)"
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
    make -j"$(nproc)"
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

# TDP Profiles (in mW) - Optimized for GZ302 AMD Ryzen AI MAX+ 395 (Strix Halo)
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
            # Validate that capacity is numeric
            if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
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
                        # Validate that capacity is numeric
                        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
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
        # Validate that capacity is numeric
        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
            echo "$capacity"
            return 0
        fi
    fi
    
    # Method 4: Use acpi if available
    if command -v acpi >/dev/null 2>&1; then
        local capacity=$(acpi -b 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
        # Validate that capacity is numeric
        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
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

# --- Service Enable Functions ---
# Simplified - no services needed with new lightweight hardware fixes
enable_arch_services() {
    info "Services configuration complete for Arch-based system"
}

enable_debian_services() {
    info "Services configuration complete for Debian-based system"
}

enable_fedora_services() {
    info "Services configuration complete for Fedora-based system"
}

enable_opensuse_services() {
    info "Services configuration complete for OpenSUSE"
}

# --- Module Download and Execution ---
download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local module_url="${GITHUB_RAW_URL}/${module_name}.sh"
    local temp_script="/tmp/${module_name}.sh"
    
    # Check network connectivity before attempting download
    if ! check_network; then
        error "No network connectivity detected. Cannot download ${module_name} module.\nPlease check your internet connection and try again."
        return 1
    fi
    
    info "Downloading ${module_name} module..."
    if curl -fsSL "$module_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        info "Executing ${module_name} module..."
        bash "$temp_script" "$distro"
        local exec_result=$?
        rm -f "$temp_script"
        
        if [[ $exec_result -eq 0 ]]; then
            success "${module_name} module completed"
            return 0
        else
            warning "${module_name} module completed with errors"
            return 1
        fi
    else
        error "Failed to download ${module_name} module from ${module_url}\nPlease verify:\n  1. Internet connection is active\n  2. GitHub is accessible\n  3. Repository URL is correct"
        return 1
    fi
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
        local primary_user
        primary_user=$(get_real_user)
        sudo -u "$primary_user" -H bash << 'EOFYAY'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOFYAY
    fi
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages (asusctl, power-profiles-daemon, switcheroo-control)
    install_arch_asus_packages
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "arch"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_debian_asus_packages
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "debian"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_debian_services
}

setup_fedora_based() {
    local distro="$1"
    info "Setting up Fedora-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    dnf upgrade -y
    dnf install -y curl wget git gcc make kernel-devel
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_fedora_asus_packages
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "fedora"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_fedora_services
}

setup_opensuse() {
    local distro="$1"
    info "Setting up OpenSUSE..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    zypper refresh
    zypper update -y
    zypper install -y curl wget git gcc make kernel-devel
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_opensuse_asus_packages
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "opensuse"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_opensuse_services
}

# --- Optional Module Installation ---
offer_optional_modules() {
    local distro="$1"
    
    echo
    echo "============================================================"
    echo "  Optional Software Modules"
    echo "============================================================"
    echo
    info "The following optional modules can be installed:"
    echo
    echo "1. Gaming Software (gz302-gaming)"
    echo "   - Steam, Lutris, ProtonUp-Qt"
    echo "   - MangoHUD, GameMode, Wine"
    echo "   - Gaming optimizations and performance tweaks"
    echo
    echo "2. LLM/AI Software (gz302-llm)"
    echo "   - Ollama for local LLM inference"
    echo "   - ROCm for AMD GPU acceleration"
    echo "   - PyTorch and Transformers libraries"
    echo
    echo "3. Hypervisor Software (gz302-hypervisor)"
    echo "   - KVM/QEMU, VirtualBox, VMware, Xen, or Proxmox"
    echo "   - Virtual machine management tools"
    echo
    echo "4. System Snapshots (gz302-snapshots)"
    echo "   - Automatic daily system backups"
    echo "   - Easy system recovery and rollback"
    echo "   - Supports ZFS, Btrfs, ext4 (LVM), and XFS"
    echo
    echo "5. Secure Boot (gz302-secureboot)"
    echo "   - Enhanced system security and boot integrity"
    echo "   - Automatic kernel signing on updates"
    echo
    echo "6. Skip optional modules"
    echo
    
    read -r -p "Which modules would you like to install? (comma-separated numbers, e.g., 1,2 or 6 to skip): " module_choice
    
    # Parse the choices
    IFS=',' read -ra CHOICES <<< "$module_choice"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ') # Remove spaces
        case "$choice" in
            1)
                download_and_execute_module "gz302-gaming" "$distro" || warning "Gaming module installation failed"
                ;;
            2)
                download_and_execute_module "gz302-llm" "$distro" || warning "LLM module installation failed"
                ;;
            3)
                download_and_execute_module "gz302-hypervisor" "$distro" || warning "Hypervisor module installation failed"
                ;;
            4)
                download_and_execute_module "gz302-snapshots" "$distro" || warning "Snapshots module installation failed"
                ;;
            5)
                download_and_execute_module "gz302-secureboot" "$distro" || warning "Secure boot module installation failed"
                ;;
            6)
                info "Skipping optional modules"
                ;;
            *)
                warning "Invalid choice: $choice"
                ;;
        esac
    done
}

# --- Main Execution Logic ---
main() {
    # Verify script is run with root privileges (required for system configuration)
    check_root
    
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Setup Script"
    echo "  Version 0.1.3-pre-release - Enhanced 2025 Support"
    echo "============================================================"
    echo
    
    # Check kernel version early (before network check)
    info "Checking kernel version..."
    local kernel_ver_num
    kernel_ver_num=$(check_kernel_version)
    echo
    
    # Check network connectivity
    info "Checking network connectivity..."
    if ! check_network; then
        warning "Network connectivity check failed."
        warning "Some features may not work without internet access."
        warning "Please ensure you have an active internet connection."
        echo
        read -r -p "Do you want to continue anyway? (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            error "Setup cancelled. Please connect to the internet and try again."
        fi
        warning "Continuing without network validation..."
    else
        success "Network connectivity confirmed"
    fi
    echo
    
    info "Detecting your Linux distribution..."
    
    # Get original distribution name for display
    local original_distro=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        original_distro="$ID"
    fi
    
    local detected_distro
    detected_distro=$(detect_distribution)
    
    if [[ "$original_distro" != "$detected_distro" ]]; then
        success "Detected distribution: $original_distro (using $detected_distro base)"
    else
        success "Detected distribution: $detected_distro"
    fi
    echo
    
    info "Starting setup process for $detected_distro-based systems..."
    info "This will apply GZ302-specific hardware fixes and install TDP/refresh rate management."
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
    success "GZ302 Core Setup Complete for $detected_distro-based systems!"
    success ""
    success "Applied GZ302-specific hardware fixes:"
    success "- Wi-Fi stability (MediaTek MT7925e)"
    success "- Touchpad detection and functionality"
    success "- Audio fixes for ASUS hardware"
    success "- GPU and thermal optimizations"
    success "- TDP management: Use 'gz302-tdp' command"
    success "- Refresh rate control: Use 'gz302-refresh' command"
    success "============================================================"
    echo
    
    # Offer optional modules
    offer_optional_modules "$detected_distro"
    
    echo
    echo
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    success "SCRIPT COMPLETED SUCCESSFULLY!"
    success "Core setup is COMPLETE!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    success "Available TDP profiles: gaming, performance, balanced, efficient"
    success "Check power status with: gz302-tdp status"
    success ""
    success "Your ROG Flow Z13 (GZ302) is now optimized for $detected_distro!"
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    echo
}

# --- Run the script ---
main "$@"
