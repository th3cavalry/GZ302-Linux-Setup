#!/bin/bash

# ==============================================================================
# "Golden Path" Installation Script for Arch Linux
# Version: 1.0.0
#
# Automated setup for automotive-llm environment on ASUS ROG Flow Z13 (GZ302)
# with AMD Radeon 8060S (gfx1151) and ROCm 7.1+ support
#
# This script represents the single best-known path to success for setting up
# a complete AI/ML development environment with PyTorch, ROCm, and bitsandbytes
# on Arch Linux.
#
# IMPORTANT: This script is designed for first-time setup and is NOT idempotent.
#            It requires a reboot after Phase 2 (ROCm installation).
#
# Usage:
#   1. Save this script as setup-arch-automotive-llm.sh
#   2. Make it executable: chmod +x setup-arch-automotive-llm.sh
#   3. Run it (first time): bash ./setup-arch-automotive-llm.sh
#   4. Reboot when prompted
#   5. Run it (second time): bash ./setup-arch-automotive-llm.sh
#
# The script will automatically detect if ROCm is installed and skip to the
# appropriate phase after reboot.
# ==============================================================================

set -e  # Exit immediately if any command fails

# --- Color codes for output ---
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

# ---
# Phase 1: System Prerequisites (Pacman)
# ---
phase1_system_prerequisites() {
    echo
    echo "============================================================"
    echo "  Phase 1: Installing Base Dependencies (pacman)"
    echo "============================================================"
    echo

    info "Updating system packages..."
    sudo pacman -Syu --noconfirm

    info "Installing base development tools..."
    sudo pacman -S --noconfirm --needed base-devel cmake git

    # Install an AUR helper (e.g., yay) if not already present
    # This is needed for the 'ollama-rocm-git' package
    if ! command -v yay &> /dev/null; then
        echo
        info "AUR Helper (yay) not found. Installing..."
        sudo pacman -S --noconfirm --needed go
        
        # Clone yay in a temporary directory
        local temp_dir="/tmp/yay-install-$$"
        mkdir -p "$temp_dir"
        git clone https://aur.archlinux.org/yay.git "$temp_dir"
        
        # Build and install yay
        (cd "$temp_dir" && makepkg -si --noconfirm)
        
        # Clean up
        cd /
        rm -rf "$temp_dir"
        
        success "AUR Helper (yay) installed successfully"
    else
        success "AUR Helper (yay) already installed"
    fi
}

# ---
# Phase 2: Install ROCm 7.1 Stack (Pacman)
# ---
phase2_install_rocm() {
    echo
    echo "============================================================"
    echo "  Phase 2: Installing ROCm 7.1 Stack (pacman)"
    echo "============================================================"
    echo

    info "Installing core ROCm SDK and libraries..."
    # This installs the core ROCm SDK and libraries.
    # Arch repos are usually very up-to-date.
    sudo pacman -S --noconfirm --needed rocm-hip-sdk rocm-opencl-sdk rocminfo

    echo
    info "Adding user to 'render' and 'video' groups..."
    sudo usermod -a -G render,video "$LOGNAME"

    echo
    success "ROCm installation complete"
    echo
    echo "============================================================"
    echo "  REBOOT REQUIRED"
    echo "============================================================"
    echo
    warning "A REBOOT IS REQUIRED for the group membership to take effect."
    warning "Please reboot your system now and then re-run this script."
    echo
    info "To re-run after reboot: bash $0"
    echo
    info "The script will detect that ROCm is installed and skip to Phase 3."
    echo
    
    # This check ensures the script isn't re-run in the same session
    # and forces the user to reboot.
    if ! rocminfo &> /dev/null; then
        exit 0
    fi
}

# ---
# Phase 3: Verify ROCm & Install Python Environment (uv)
# ---
phase3_verify_rocm_setup_python() {
    echo
    echo "============================================================"
    echo "  Phase 3: Verifying ROCm and Setting up Python"
    echo "============================================================"
    echo

    # Verification (This part runs after reboot)
    info "Verifying ROCm Installation..."
    if ! rocminfo | grep -q "gfx1151"; then
        error "rocminfo does not show 'gfx1151'. ROCm is not detecting your GPU."
    fi
    success "ROCm detected gfx1151 GPU"

    echo
    info "Verifying VRAM (Kernel Fix check)..."
    # This grep command is fragile, but it's a good sanity check
    if command -v rocm-smi &> /dev/null; then
        local vram_output
        vram_output=$(rocm-smi --showmeminfo vram 2>/dev/null | grep 'Total' || echo "")
        if [[ -n "$vram_output" ]]; then
            local vram_mb
            vram_mb=$(echo "$vram_output" | awk '{print $2}' | sed 's/M//' | head -1)
            if [[ -n "$vram_mb" && "$vram_mb" -lt 32000 ]]; then
                warning "rocm-smi reports less than 32GB VRAM ($vram_mb MB)."
                warning "This may indicate the 15.5GB VRAM bug. Ensure your kernel is 6.16.9+ with 'uname -r'."
            else
                success "VRAM detection looks good ($vram_mb MB)"
            fi
        else
            warning "Could not parse VRAM from rocm-smi. Continuing anyway..."
        fi
    else
        warning "rocm-smi not found. Skipping VRAM check."
    fi
    
    echo
    info "ROCm stack detected and verified. Proceeding with Python setup..."

    # Install uv (modern Python package installer) and Python
    info "Installing uv and Python..."
    sudo pacman -S --noconfirm --needed python python-pip

    # Install uv via pip if not already available in pacman
    if ! command -v uv &> /dev/null; then
        if pacman -Si uv &> /dev/null; then
            sudo pacman -S --noconfirm --needed uv
        else
            info "Installing uv via pip..."
            sudo pip install uv --break-system-packages 2>/dev/null || sudo pip install uv
        fi
    fi

    # Create project directory and virtual environment
    local project_dir="$HOME/automotive-llm"
    info "Creating project directory at $project_dir..."
    mkdir -p "$project_dir"
    cd "$project_dir"
    
    info "Creating Python virtual environment..."
    uv venv
    
    success "Python Virtual Environment created at $project_dir/.venv"
    echo
    info "To activate: source $project_dir/.venv/bin/activate"
}

# ---
# Phase 4: Install PyTorch Nightly & Hugging Face Libraries (uv)
# ---
phase4_install_pytorch() {
    echo
    echo "============================================================"
    echo "  Phase 4: Installing PyTorch Nightly for ROCm 7.x"
    echo "============================================================"
    echo

    local project_dir="$HOME/automotive-llm"
    cd "$project_dir"
    
    # Activate virtual environment
    # shellcheck disable=SC1091
    source .venv/bin/activate

    # This is a critical step. We install the pre-compiled nightly wheel
    # that is built for the rocm7.0 target.
    info "Installing PyTorch nightly with ROCm 7.0 support..."
    uv pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm7.0/

    echo
    info "Installing Hugging Face PEFT/TRL libraries..."
    uv pip install transformers peft trl datasets

    echo
    info "Verifying PyTorch can see the GPU..."
    if ! python -c "import torch; exit(0) if torch.cuda.is_available() else exit(1)"; then
        error "PyTorch cannot detect the ROCm device. 'torch.cuda.is_available()' is False."
    fi
    
    success "PyTorch GPU detection successful"
    
    # Show GPU info
    info "GPU Info:"
    python -c "import torch; print(f'  Device: {torch.cuda.get_device_name(0)}'); print(f'  CUDA Available: {torch.cuda.is_available()}'); print(f'  Device Count: {torch.cuda.device_count()}')" || true
}

# ---
# Phase 5: Compile and Install bitsandbytes-rocm (The Hard Part)
# ---
phase5_compile_bitsandbytes() {
    echo
    echo "============================================================"
    echo "  Phase 5: Compiling bitsandbytes-rocm for gfx1151"
    echo "============================================================"
    echo
    
    warning "This is the most fragile step and may fail if dependencies are mismatched."
    echo

    local project_dir="$HOME/automotive-llm"
    cd "$project_dir"
    
    # Activate virtual environment
    # shellcheck disable=SC1091
    source .venv/bin/activate

    # Clone the official AMD fork
    local bnb_dir="$project_dir/bitsandbytes"
    if [[ -d "$bnb_dir" ]]; then
        info "bitsandbytes directory already exists. Removing and re-cloning..."
        rm -rf "$bnb_dir"
    fi
    
    info "Cloning bitsandbytes ROCm fork..."
    git clone https://github.com/ROCm/bitsandbytes.git "$bnb_dir"
    cd "$bnb_dir"

    # Run cmake with the specific backend (hip) and architecture (gfx1151)
    # This is the command that fails if PyTorch and ROCm are mismatched.
    info "Running cmake for HIP backend with gfx1151 architecture..."
    cmake -DCOMPUTE_BACKEND=hip -DBNB_ROCM_ARCH="gfx1151" -S .

    # Compile using all available processor cores
    info "Compiling bitsandbytes (this may take several minutes)..."
    make -j"$(nproc)"

    # Install the compiled package into our virtual environment
    info "Installing compiled bitsandbytes into virtual environment..."
    uv pip install .

    success "bitsandbytes compilation and installation complete"
    
    # Move back to project directory
    cd "$project_dir"
}

# ---
# Phase 6: Install Ollama (For Inference)
# ---
phase6_install_ollama() {
    echo
    echo "============================================================"
    echo "  Phase 6: Installing Ollama (Inference Server)"
    echo "============================================================"
    echo

    # On Arch, the AUR package is the recommended path
    info "Installing Ollama from AUR..."
    yay -S --noconfirm --needed ollama-rocm-git

    # Enable and start the Ollama service
    info "Enabling and starting Ollama service..."
    sudo systemctl enable ollama
    sudo systemctl start ollama

    success "Ollama installation complete"
    
    # Verify Ollama is running
    if systemctl is-active --quiet ollama; then
        success "Ollama service is running"
    else
        warning "Ollama service is not running. Try: sudo systemctl start ollama"
    fi
}

# ---
# Main Execution
# ---
main() {
    echo
    echo "============================================================"
    echo "  GZ302 Automotive-LLM Setup Script for Arch Linux"
    echo "  Version: 1.0.0"
    echo "============================================================"
    echo
    
    info "This script will set up a complete AI/ML development environment"
    info "with ROCm 7.1+, PyTorch nightly, and bitsandbytes for gfx1151"
    echo
    
    # Check if we're on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only. Detected: $(grep '^ID=' /etc/os-release | cut -d= -f2)"
    fi

    # Check if rocminfo is available and can detect GPU
    if command -v rocminfo &> /dev/null && rocminfo | grep -q "gfx1151"; then
        info "ROCm is already installed and GPU is detected."
        info "Skipping Phase 1 and Phase 2..."
        
        # Run phases 3-6
        phase3_verify_rocm_setup_python
        phase4_install_pytorch
        phase5_compile_bitsandbytes
        phase6_install_ollama
    else
        # ROCm not installed or GPU not detected
        if command -v rocminfo &> /dev/null; then
            warning "rocminfo is installed but GPU (gfx1151) is not detected."
            warning "This may indicate a driver issue or missing reboot."
            echo
            read -r -p "Do you want to continue with ROCm installation anyway? [y/N]: " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                error "Installation cancelled by user."
            fi
        fi
        
        # Run phases 1-2 (will exit after phase 2 with reboot message)
        phase1_system_prerequisites
        phase2_install_rocm
        
        # If we got here, rocminfo failed but we're still in the same session
        # This means user needs to reboot
        echo
        warning "Please reboot and re-run this script to continue with Phase 3-6"
        exit 0
    fi

    # Final summary
    echo
    echo "============================================================"
    echo "  Arch Linux Setup Script Finished!"
    echo "============================================================"
    echo
    success "Your environment is ready in '$HOME/automotive-llm/'"
    echo
    info "Next steps:"
    echo "  1. Activate the environment:"
    echo "     cd ~/automotive-llm"
    echo "     source .venv/bin/activate"
    echo
    echo "  2. Test inference with Ollama:"
    echo "     ollama run llama3.2"
    echo
    echo "  3. Start developing your automotive-llm project!"
    echo
    info "Documentation:"
    echo "  - PyTorch ROCm: https://pytorch.org/get-started/locally/"
    echo "  - bitsandbytes: https://github.com/ROCm/bitsandbytes"
    echo "  - Ollama: https://ollama.ai"
    echo
}

# Run main function
main "$@"
