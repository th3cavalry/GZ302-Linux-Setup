#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 0.1.2-pre-release
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Ollama, ROCm, PyTorch, Transformers
# Optimized for AMD Radeon 8060S (RDNA 3.5) integrated GPU
#
# This script is designed to be called by gz302-main.sh
# ==============================================================================

set -euo pipefail

# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

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

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# --- LLM/AI Software Installation Functions ---
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    pacman -S --noconfirm --needed ollama
    if systemctl enable --now ollama 2>/dev/null; then
        if systemctl is-active --quiet ollama; then
            success "Ollama service is active and running"
        else
            warning "Ollama enabled but not running, will start on next boot"
        fi
    else
        warning "Failed to enable Ollama service"
    fi
    
    # Install ROCm for AMD GPU acceleration (optimized for Radeon 8060S)
    info "Installing ROCm for AMD GPU acceleration..."
    pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime rocm-smi-lib
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    pacman -S --noconfirm --needed python-pip python-virtualenv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        info "Installing PyTorch with ROCm support for user $primary_user..."
        # Use latest stable ROCm version compatible with RDNA 3.5
        # ROCm 6.0+ recommended for best RDNA 3.5 support
        sudo -u "$primary_user" pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
        sudo -u "$primary_user" pip install --user transformers accelerate bitsandbytes
        success "PyTorch with ROCm 6.0 support installed"
    fi
    
    success "LLM/AI software installation completed"
}

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    if systemctl enable --now ollama 2>/dev/null; then
        if systemctl is-active --quiet ollama; then
            success "Ollama service is active and running"
        else
            warning "Ollama enabled but not running, will start on next boot"
        fi
    else
        warning "Failed to enable Ollama service"
    fi
    
    # Install ROCm (if available) - note: limited support on Debian/Ubuntu
    info "Installing ROCm for AMD GPU acceleration..."
    if apt install -y rocm-opencl-runtime 2>/dev/null; then
        success "ROCm installed from repositories"
    else
        warning "ROCm not available in repositories"
        info "For better AI/ML performance, consider using Arch or Fedora"
        info "Alternatively, follow AMD's ROCm installation guide for Ubuntu"
    fi
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    apt install -y python3-pip python3-venv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        info "Installing PyTorch with ROCm support for user $primary_user..."
        # Use ROCm 6.0 if available, fallback to CPU-only if ROCm not installed
        if command -v rocminfo >/dev/null 2>&1; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
        else
            warning "ROCm not detected, installing CPU-only PyTorch"
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio
        fi
        sudo -u "$primary_user" pip3 install --user transformers accelerate bitsandbytes
    fi
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    if systemctl enable --now ollama 2>/dev/null; then
        if systemctl is-active --quiet ollama; then
            success "Ollama service is active and running"
        else
            warning "Ollama enabled but not running, will start on next boot"
        fi
    else
        warning "Failed to enable Ollama service"
    fi
    
    # Install ROCm for Fedora (limited official support, use community repos)
    info "Installing ROCm for AMD GPU acceleration..."
    warning "ROCm on Fedora requires additional setup"
    info "Consider using AMD's official ROCm documentation for Fedora installation"
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    dnf install -y python3-pip python3-virtualenv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        info "Installing PyTorch with ROCm support for user $primary_user..."
        # Check if ROCm is available
        if command -v rocminfo >/dev/null 2>&1; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
        else
            warning "ROCm not detected, installing CPU-only PyTorch"
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio
        fi
        sudo -u "$primary_user" pip3 install --user transformers accelerate bitsandbytes
    fi
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    if systemctl enable --now ollama 2>/dev/null; then
        if systemctl is-active --quiet ollama; then
            success "Ollama service is active and running"
        else
            warning "Ollama enabled but not running, will start on next boot"
        fi
    else
        warning "Failed to enable Ollama service"
    fi
    
    # Install ROCm (limited support on OpenSUSE)
    info "Installing ROCm for AMD GPU acceleration..."
    warning "ROCm on OpenSUSE requires additional setup"
    info "Consider following AMD's ROCm installation guide for SUSE"
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    zypper install -y python3-pip python3-virtualenv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        info "Installing PyTorch with ROCm support for user $primary_user..."
        # Check if ROCm is available
        if command -v rocminfo >/dev/null 2>&1; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
        else
            warning "ROCm not detected, installing CPU-only PyTorch"
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio
        fi
        sudo -u "$primary_user" pip3 install --user transformers accelerate bitsandbytes
    fi
    
    success "LLM/AI software installation completed"
}

# --- Main Execution ---
main() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
    
    local distro="${1:-}"
    
    if [[ -z "$distro" ]]; then
        error "Distribution not specified. This script should be called by gz302-main.sh"
    fi
    
    echo
    echo "============================================================"
    echo "  GZ302 LLM/AI Software Installation"
    echo "============================================================"
    echo
    
    case "$distro" in
        "arch")
            install_arch_llm_software
            ;;
        "ubuntu")
            install_debian_llm_software
            ;;
        "fedora")
            install_fedora_llm_software
            ;;
        "opensuse")
            install_opensuse_llm_software
            ;;
        *)
            error "Unsupported distribution: $distro"
            ;;
    esac
    
    echo
    success "LLM/AI software installation complete!"
    echo
}

main "$@"
