#!/bin/bash

# ==============================================================================
# Comprehensive Ubuntu Setup Script for ASUS ROG Flow Z13 (2025, GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.5
#
# This script automates the post-installation setup for Ubuntu on the
# ASUS ROG Flow Z13 (GZ302) with an AMD Ryzen AI 395+ processor.
# It applies critical hardware fixes, installs gaming software,
# and configures a high-performance gaming environment.
#
# PRE-REQUISITES:
# 1. A base installation of Ubuntu (20.04 LTS or newer).
# 2. An active internet connection.
# 3. A user with sudo privileges.
#
# USAGE:
# 1. Download the script:
#    curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/ubuntu_setup.sh
# 2. Make it executable:
#    chmod +x ubuntu_setup.sh
# 3. Run with sudo:
#    sudo ./ubuntu_setup.sh
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
    
    # Update package lists
    apt update
    
    # Upgrade system
    apt upgrade -y
    
    # Install essential build tools and dependencies
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    
    success "System updated and base dependencies installed."
}

# 2. Add gaming and hardware repositories
setup_repositories() {
    info "Setting up gaming and hardware repositories..."
    
    # Add multiverse repository for additional packages
    add-apt-repository -y multiverse
    
    # Add universe repository if not already enabled
    add-apt-repository -y universe
    
    # Update package lists
    apt update
    
    success "Gaming and hardware repositories configured."
}

# 3. Install hardware support packages
install_hardware_support() {
    info "Installing hardware support packages for AMD and ASUS devices..."
    
    # Install AMD GPU drivers and utilities
    apt install -y mesa-utils mesa-vulkan-drivers vulkan-tools \
        libvulkan1 libvulkan-dev vainfo libva-dev libva-drm2 \
        libva-glx2 libva-wayland2 libva2 radeontop
    
    # Install firmware and microcode
    apt install -y linux-firmware amd64-microcode
    
    # Install power management tools
    apt install -y powertop tlp tlp-rdw
    
    # Install hardware monitoring tools
    apt install -y lm-sensors fancontrol
    
    success "Hardware support packages installed."
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

# 5. Install and configure the gaming software stack
install_gaming_stack() {
    info "Installing and configuring the gaming software stack..."
    info "This will install Steam, Lutris, gaming tools, and compatibility layers..."

    # 5a. Enable 32-bit architecture for Steam
    info "Enabling 32-bit architecture support for Steam..."
    dpkg --add-architecture i386
    apt update

    # 5b. Install Steam
    info "Installing Steam from official repository..."
    
    # Add Steam repository
    curl -fsSL https://repo.steampowered.com/steam/archive/precise/steam.gpg | apt-key add -
    echo "deb [arch=amd64,i386] https://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list
    apt update
    
    # Accept Steam license automatically
    echo steam steam/question select "I AGREE" | debconf-set-selections
    echo steam steam/license note '' | debconf-set-selections
    
    apt install -y steam-installer

    # 5c. Install Lutris
    info "Installing Lutris game manager..."
    apt install -y lutris

    # 5d. Install gaming libraries and tools
    info "Installing gaming libraries and performance tools..."
    apt install -y gamemode libgamemode0 libgamemode-dev \
        vulkan-utils mesa-vulkan-drivers vulkan-validationlayers \
        libd3dadapter9-mesa libd3dadapter9-mesa-dev \
        wine winetricks
    
    # Install additional 32-bit libraries for Steam
    apt install -y libc6:i386 libegl1:i386 libgbm1:i386 libgl1-mesa-dri:i386 \
        libgl1:i386 libglapi-mesa:i386 libglx-mesa0:i386 libglx0:i386 \
        libvulkan1:i386

    success "Core gaming applications and libraries installed."

    # 5e. Install MangoHUD for performance monitoring
    info "Installing MangoHUD for performance monitoring..."
    apt install -y mangohud

    # 5f. Install ProtonUp-Qt via Flatpak (most reliable method for Ubuntu)
    info "Installing ProtonUp-Qt for Proton version management..."
    if ! command -v flatpak &> /dev/null; then
        apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        sudo -u "$PRIMARY_USER" flatpak install -y flathub net.davidotek.pupgui2
        success "ProtonUp-Qt installed via Flatpak."
    else
        warning "Could not determine non-root user. ProtonUp-Qt installation skipped."
    fi

    # 5g. Install Proton-GE
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

    # 6d. Configure CPU governor for performance
    info "Installing and configuring CPU frequency scaling..."
    apt install -y cpufrequtils
    
    cat > /etc/default/cpufrequtils <<EOF
GOVERNOR="performance"
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
    
    # Add ROCm repository
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
    echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.7/ jammy main" > /etc/apt/sources.list.d/rocm.list
    
    apt update
    
    # Install ROCm packages
    apt install -y rocm-dev rocm-libs rocm-utils
    
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
    apt install -y python3-pip python3-venv
    
    # Install PyTorch with ROCm support
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
    
    success "PyTorch with ROCm support installed successfully."
}

# Install Hugging Face Transformers
install_transformers() {
    info "Installing Hugging Face Transformers library..."
    
    # Install pip if not present
    apt install -y python3-pip python3-venv
    
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

# --- Main Execution Logic ---
main() {
    check_root

    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Ubuntu Setup Script"
    echo "  Version 1.3 - Gaming Performance Optimization"
    echo "============================================================"
    echo
    
    info "Starting comprehensive setup process..."
    info "This script will configure your Ubuntu system for optimal ROG Flow Z13 performance"
    info "Estimated time: 10-30 minutes depending on internet speed"
    
    # Ask user for installation preferences
    ask_installation_options
    
    info "Step 1/8: Updating system and installing base dependencies..."
    update_system
    
    info "Step 2/8: Setting up gaming and hardware repositories..."
    setup_repositories
    
    info "Step 3/8: Installing hardware support packages..."
    install_hardware_support
    
    info "Step 4/8: Applying hardware-specific fixes..."
    apply_hardware_fixes
    
    # Conditional gaming installation
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        info "Step 5/8: Installing gaming software stack..."
        install_gaming_stack
        
        info "Step 6/8: Applying performance optimizations..."
        apply_performance_tweaks
    else
        info "Step 5/8: Skipping gaming software installation as requested..."
        info "Step 6/8: Applying basic performance optimizations..."
        apply_performance_tweaks
    fi
    
    # Conditional LLM installation
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        info "Step 7/8: Installing LLM/AI software stack..."
        install_llm_stack
    else
        info "Step 7/8: Skipping LLM/AI software installation as requested..."
    fi
    
    info "Step 8/8: Enabling services and finalizing setup..."
    enable_services

    echo
    success "============================================================"
    success "Ubuntu setup complete for ASUS ROG Flow Z13 (GZ302)!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    
    # Show gaming tools if installed
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        success "Installed gaming tools:"
        success "- Steam with Proton support"
        success "- Lutris for game management"
        success "- ProtonUp-Qt for Proton version management (Flatpak)"
        success "- MangoHUD for performance monitoring"
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
    
    success "Hardware fixes applied:"
    success "- MediaTek MT7925 Wi-Fi stability improvements"
    success "- Touchpad detection and sensitivity fixes"
    success "- AMD GPU driver optimizations"
    success "- Audio device compatibility fixes"
    success "- Thermal throttling and power management"
    success ""
    success "Performance optimizations applied:"
    success "- Gaming-optimized kernel parameters"
    success "- CPU performance governor configuration"
    success "- I/O scheduler optimizations for SSDs/NVMe"
    success "- Network latency optimizations"
    success "- Memory management tweaks"
    success "- Hardware video acceleration"
    success "- System limits increased for gaming"
    success ""
    success "You can now enjoy Ubuntu optimized for your"
    success "ASUS ROG Flow Z13 (GZ302)!"
    success "============================================================"
    echo
}

# --- Run the script ---
main "$@"