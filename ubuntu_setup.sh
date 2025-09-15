#!/bin/bash

# ==============================================================================
# Ubuntu Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Simple setup script that fixes hardware issues and installs gaming/AI software.
# Works with Ubuntu 20.04 LTS or newer.
#
# How to use:
# 1. Download: curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/ubuntu_setup.sh -o setup.sh
# 2. Make executable: chmod +x setup.sh  
# 3. Run: sudo ./setup.sh
# ==============================================================================

set -euo pipefail # Stop if anything goes wrong

# Colors for messages
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

info() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}[WARNING]${C_NC} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_NC} $1"; exit 1; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo ./setup.sh"
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

# Download and load common hardware fixes
load_common_fixes() {
    info "Downloading common hardware fixes..."
    curl -fsSL https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/common-hardware-fixes.sh -o /tmp/common-fixes.sh
    source /tmp/common-fixes.sh
}

# Update system and install basic tools
update_system() {
    info "Updating system and installing basic tools..."
    apt update && apt upgrade -y
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    success "System updated."
}

# Setup gaming repositories
setup_repositories() {
    info "Setting up repositories..."
    add-apt-repository -y multiverse universe
    apt update
    success "Repositories configured."
}

# Install hardware support
install_hardware_support() {
    info "Installing hardware support..."
    apt install -y mesa-utils mesa-vulkan-drivers vulkan-tools \
        libvulkan1 libvulkan-dev vainfo libva-dev libva-drm2 \
        libva-glx2 libva-wayland2 libva2 radeontop \
        linux-firmware amd64-microcode powertop tlp tlp-rdw \
        lm-sensors fancontrol
    success "Hardware support installed."
}

# Ask user what to install
ask_installation_options() {
    echo ""
    info "What would you like to install?"
    echo "1. Gaming Software - Steam, game launchers, performance tools"
    echo "2. AI Software - Tools for running AI models locally"  
    echo "3. System Snapshots - Automatic backups for easy recovery"
    echo "4. Secure Boot - Enhanced security features"
    echo ""
    read -p "Install gaming software? (y/n): " install_gaming
    read -p "Install AI software? (y/n): " install_llm
    read -p "Enable system snapshots? (y/n): " install_snapshots
    read -p "Configure secure boot? (y/n): " install_secureboot
    echo ""
}

# Install gaming software
install_gaming_stack() {
    info "Installing gaming software..."
    
    # Enable 32-bit support
    dpkg --add-architecture i386
    apt update
    
    # Add Steam repository
    curl -fsSL https://repo.steampowered.com/steam/archive/precise/steam.gpg | apt-key add -
    echo "deb [arch=amd64,i386] https://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list
    apt update
    
    # Install gaming packages
    echo steam steam/question select "I AGREE" | debconf-set-selections
    echo steam steam/license note '' | debconf-set-selections
    
    apt install -y steam-installer lutris gamemode libgamemode0 libgamemode-dev \
        vulkan-utils mesa-vulkan-drivers vulkan-validationlayers \
        wine winetricks mangohud flatpak \
        libc6:i386 libegl1:i386 libgbm1:i386 libgl1-mesa-dri:i386 \
        libgl1:i386 libglapi-mesa:i386 libglx-mesa0:i386 libglx0:i386 \
        libvulkan1:i386

    # Install ProtonUp-Qt via Flatpak
    if ! command -v flatpak &> /dev/null; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        sudo -u "$PRIMARY_USER" flatpak install -y flathub net.davidotek.pupgui2 || true
    fi

    success "Gaming software installed."
}

# Install AI/LLM software (simplified)
install_llm_stack() {
    info "Installing AI/LLM software..."
    
    echo "Which AI tools would you like?"
    echo "1. Ollama (local AI models)"
    echo "2. ROCm (AMD GPU acceleration)" 
    echo "3. PyTorch"
    echo "4. All of the above"
    echo "5. Skip"
    read -p "Choose (1-5): " choice
    
    case $choice in
        1|4)
            info "Installing Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh
            systemctl enable --now ollama.service || true
            ;;
    esac
    
    case $choice in
        2|4)
            info "Installing ROCm..."
            wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
            echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.7/ jammy main" > /etc/apt/sources.list.d/rocm.list
            apt update && apt install -y rocm-dev rocm-libs rocm-utils || true
            if [ -n "${SUDO_USER:-}" ]; then
                usermod -a -G render "$SUDO_USER"
            fi
            ;;
    esac
    
    case $choice in
        3|4)
            info "Installing PyTorch..."
            apt install -y python3-pip python3-venv
            pip3 install torch torchvision torchaudio transformers || true
            ;;
    esac
    
    success "AI software installation completed."
}

# Enable services
enable_services() {
    info "Enabling system services..."
    systemctl enable --now tlp.service
    systemctl enable --now reload-hid_asus.service
    
    # Configure gamemode for the user
    PRIMARY_USER=$(get_real_user)
    if [[ "$PRIMARY_USER" != "root" ]]; then
        usermod -a -G gamemode "$PRIMARY_USER"
        sudo -u "$PRIMARY_USER" mkdir -p "/home/$PRIMARY_USER/.config/gamemode"
        sudo -u "$PRIMARY_USER" cat > "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini" <<EOF
[general]
renice=10
desiredgov=performance

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
EOF
        chown "$PRIMARY_USER:$PRIMARY_USER" "/home/$PRIMARY_USER/.config/gamemode/gamemode.ini"
    fi
    success "Services enabled."
}

# Main script
main() {
    check_root

    echo "============================================================"
    echo "  Ubuntu Setup for ASUS ROG Flow Z13 (GZ302)"
    echo "  Simple hardware fixes and gaming setup"
    echo "============================================================"
    
    info "This will fix hardware issues and optionally install gaming/AI software"
    
    ask_installation_options
    
    info "Step 1/6: Updating system..."
    update_system
    
    info "Step 2/6: Setting up repositories..."
    setup_repositories
    
    info "Step 3/6: Installing hardware support..."
    install_hardware_support
    
    info "Step 4/6: Applying hardware fixes..."
    load_common_fixes
    apply_common_hardware_fixes
    apply_common_performance_tweaks
    
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        info "Step 5/6: Installing gaming software..."
        install_gaming_stack
    else
        info "Step 5/6: Skipping gaming software..."
    fi
    
    if [[ "${install_llm,,}" == "y" || "${install_llm,,}" == "yes" ]]; then
        info "Installing AI software..."
        install_llm_stack
    else
        info "Skipping AI software..."
    fi
    
    info "Step 6/6: Enabling services..."
    enable_services
    enable_common_services

    echo
    success "============================================================"
    success "Ubuntu setup complete for ASUS ROG Flow Z13!"
    success "Please REBOOT your computer to apply all changes."
    success ""
    
    if [[ "${install_gaming,,}" == "y" || "${install_gaming,,}" == "yes" ]]; then
        success "Gaming tools installed: Steam, Lutris, MangoHUD, GameMode"
    fi
    
    success "Hardware fixes applied:"
    success "- Wi-Fi stability improvements"
    success "- Touchpad detection fixes"
    success "- Audio compatibility fixes"
    success "- Graphics optimizations"
    success "- Performance tweaks"
    success "============================================================"
    echo
}

# Run the script
main "$@"