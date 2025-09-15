#!/bin/bash

# ==============================================================================
# Fedora Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Simple setup script that fixes hardware issues and installs gaming/AI software.
# Works with Fedora 37 or newer.
#
# How to use:
# 1. Download: curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/fedora_setup.sh -o setup.sh
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
    dnf upgrade -y --refresh
    dnf install -y curl wget git gcc gcc-c++ make kernel-headers kernel-devel \
        dnf-plugins-core rpmfusion-free-release rpmfusion-nonfree-release
    dnf update -y
    success "System updated."
}

# Setup gaming repositories
setup_repositories() {
    info "Setting up RPM Fusion repositories..."
    # Install Flatpak for additional applications
    dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    dnf update -y
    success "Repositories configured."
}

# Install hardware support
install_hardware_support() {
    info "Installing hardware support..."
    dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
        libva libva-utils libvdpau-va-gl mesa-libGL mesa-libEGL \
        kernel-modules-extra linux-firmware \
        powertop tlp tlp-rdw lm_sensors acpid thermald
    success "Hardware support installed."
}

# Ask user what to install
ask_installation_options() {
    echo ""
    info "What would you like to install?"
    echo "1. Gaming Software - Steam, game launchers, performance tools"
    echo "2. AI Software - Tools for running AI models locally"  
    echo ""
    read -p "Install gaming software? (y/n): " install_gaming
    read -p "Install AI software? (y/n): " install_llm
    echo ""
}

# Install gaming software
install_gaming_stack() {
    info "Installing gaming software..."
    
    # Install Steam and gaming packages
    dnf install -y steam lutris gamemode wine winetricks \
        mesa-vulkan-drivers vulkan-tools mangohud goverlay \
        pipewire pipewire-pulse pipewire-alsa pipewire-jack-audio-connection-kit \
        alsa-plugins-pulseaudio
    
    # Install ProtonUp-Qt via Flatpak
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
            dnf config-manager --add-repo https://repo.radeon.com/rocm/rhel9/rocm.repo || true
            dnf install -y rocm-dev rocm-runtime rocm-utils || true
            if [ -n "${SUDO_USER:-}" ]; then
                usermod -a -G render "$SUDO_USER"
            fi
            ;;
    esac
    
    case $choice in
        3|4)
            info "Installing PyTorch..."
            dnf install -y python3-pip python3-devel
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
    echo "  Fedora Setup for ASUS ROG Flow Z13 (GZ302)"
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
    success "Fedora setup complete for ASUS ROG Flow Z13!"
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