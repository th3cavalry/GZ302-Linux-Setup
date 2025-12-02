#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 2.3.9
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Ollama, ROCm, PyTorch, MIOpen, bitsandbytes, Transformers
# Configures kernel parameters optimized for LLM workloads on Strix Halo
#
# Updated November 2025:
# - Use ROCm 6.x wheels (ROCm 5.7 deprecated, no Python 3.12+ support)
# - Fixed venv permission issues
# - Updated bitsandbytes installation (uses standard pip package now)
# - Prefer Python 3.11/3.12 for best ROCm wheel compatibility
#
# This script is designed to be called by gz302-main.sh
# ==============================================================================

set -euo pipefail

# --- Script directory detection ---
resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="${dir}/${source}"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_dir)}"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -L "${GITHUB_RAW_URL}/gz302-utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/gz302-utils.sh" -O "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download gz302-utils.sh"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-utils.sh"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: Failed to download gz302-utils.sh"
        exit 1
    fi
fi

# Configure LLM-optimized kernel parameters
configure_llm_kernel_params() {
    info "Configuring kernel parameters optimized for LLM workloads on Strix Halo..."

    # Parameters for LLM workloads on AMD Strix Halo:
    # - iommu=pt: Sets IOMMU to passthrough mode for lower latency GPU memory access (safer than off)
    # - amdgpu.gttsize=131072: Sets GTT size to 128MB for larger unified memory pools
    local params=("iommu=pt" "amdgpu.gttsize=131072")

    local bootloader
    bootloader=$(detect_bootloader)

    case "$bootloader" in
        "grub")
            for param in "${params[@]}"; do
                ensure_grub_kernel_param "$param" || true
            done
            # Regenerate GRUB config
            if [[ -f "/boot/grub/grub.cfg" ]]; then
                grub-mkconfig -o /boot/grub/grub.cfg
            elif command -v update-grub >/dev/null 2>&1; then
                update-grub
            fi
            success "Added kernel parameters to GRUB configuration"
            ;;
        "systemd-boot")
            # Try /etc/kernel/cmdline first
            if [[ -f /etc/kernel/cmdline ]]; then
                for param in "${params[@]}"; do
                    ensure_kcmdline_param "$param" || true
                done
                # Rebuild boot entries (simplified check, main script has more robust logic but this is optional module)
                if command -v bootctl >/dev/null 2>&1; then
                    bootctl update || true
                fi
                success "Added kernel parameters to systemd-boot configuration"
            else
                # Fallback to loader entries
                local loader_changed=false
                shopt -s nullglob
                for entry in /boot/loader/entries/*.conf; do
                    for param in "${params[@]}"; do
                        ensure_loader_entry_param "$entry" "$param" && loader_changed=true || true
                    done
                done
                shopt -u nullglob
                if [[ "$loader_changed" == true ]]; then
                    success "Added kernel parameters to systemd-boot entries"
                fi
            fi
            ;;
        "refind")
            for param in "${params[@]}"; do
                ensure_refind_kernel_param "$param" || true
            done
            success "Added kernel parameters to rEFInd configuration"
            ;;
        "syslinux"|"extlinux")
            for param in "${params[@]}"; do
                ensure_syslinux_kernel_param "$param" || true
            done
            success "Added kernel parameters to syslinux configuration"
            ;;
        "unknown")
            warning "Unable to detect boot loader. Kernel parameters not configured."
            warning "Please manually add the following to your kernel command line:"
            warning "  ${params[*]}"
            ;;
        *)
            warning "Unsupported boot loader: $bootloader. Kernel parameters not configured."
            ;;
    esac

    echo
    info "LLM Kernel Parameters:"
    info "  • iommu=pt - Sets IOMMU to passthrough for lower latency"
    info "  • amdgpu.gttsize=131072 - 128MB GTT for unified memory"
    echo
    info "A reboot is required for kernel parameter changes to take effect."
    echo
}

# Check if ROCm is already installed
check_rocm_installed() {
    if pacman -Q rocm-hip-runtime rocblas miopen-hip >/dev/null 2>&1; then
        info "ROCm packages are already installed"
        return 0
    else
        return 1
    fi
}

# Check if ROCm is already installed (OpenSUSE)
check_rocm_installed_opensuse() {
    if zypper se -i rocm-opencl rocblas miopen-hip 2>/dev/null | grep -q "installed"; then
        info "ROCm packages are already installed"
        return 0
    else
        return 1
    fi
}

# Check if ROCm is already installed (Fedora/RPM)
check_rocm_installed_fedora() {
    if rpm -q rocm-opencl rocblas miopen-hip >/dev/null 2>&1; then
        info "ROCm packages are already installed"
        return 0
    else
        return 1
    fi
}

# Check if ROCm is already installed (Debian)
check_rocm_installed_debian() {
    if dpkg -l | grep -q "rocm-opencl-runtime\|rocblas\|miopen-hip"; then
        info "ROCm packages are already installed"
        return 0
    else
        return 1
    fi
}

# Setup ROCm repository for Debian/Debian Trixie
setup_rocm_repo_debian() {
    # Check if ROCm repository is already configured
    if [[ -f /etc/apt/sources.list.d/rocm.list ]]; then
        info "ROCm repository already configured"
        return 0
    fi
    
    info "Setting up AMD ROCm repository for Debian..."
    
    # Create keyrings directory if it doesn't exist
    mkdir -p /etc/apt/keyrings
    chmod 0755 /etc/apt/keyrings
    
    # Download and add ROCm GPG key
    info "Adding ROCm GPG key..."
    if ! wget -q https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor -o /etc/apt/keyrings/rocm.gpg; then
        warning "Failed to add ROCm GPG key"
        return 1
    fi
    
    # Detect Debian version/codename for repository setup
    local debian_codename
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        debian_codename="${VERSION_CODENAME:-unknown}"
    else
        debian_codename="unknown"
    fi
    
    # ROCm 6.2 is the latest stable with good Debian support
    # For Debian Trixie, we use the repository as-is
    info "Configuring ROCm 6.2 repository for Debian $debian_codename..."
    
    # Add ROCm apt repository
    # Note: AMD provides repos for specific Debian versions, but Ubuntu repos often work for Debian
    cat > /etc/apt/sources.list.d/rocm.list << 'EOF'
# AMD ROCm repository
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.2.4 jammy main
EOF
    
    # Update apt cache with new repository
    info "Updating package cache..."
    local apt_log
    apt_log=$(mktemp)
    if ! apt update 2>&1 | tee "$apt_log"; then
        warning "apt update encountered errors with ROCm repository"
        info "ROCm packages may not be available from AMD repos for this Debian version"
        info "Will attempt to use packages from default Debian repositories"
        rm -f "$apt_log"
        # Don't fail - try to continue with Debian's own ROCm packages
        return 0
    fi
    rm -f "$apt_log"
    
    success "ROCm repository configured successfully"
    return 0
}

# Check if Python package is installed in a venv
check_venv_package() {
    local venv_path="$1"
    local package_name="$2"
    if [[ -f "$venv_path/bin/python" ]]; then
        "$venv_path/bin/python" -c "import importlib; importlib.import_module('$package_name')" >/dev/null 2>&1
        return $?
    else
        return 1
    fi
}

# Check if Python package is installed in system Python (for --user installs on Debian/Fedora/OpenSUSE)
check_system_python_package() {
    local package_name="$1"
    if python3 -c "import importlib; importlib.import_module('$package_name')" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if Ollama is already installed
check_ollama_installed() {
    if command -v ollama >/dev/null 2>&1; then
        info "Ollama is already installed"
        return 0
    else
        return 1
    fi
}

# Check if llama.cpp is already installed
check_llamacpp_installed() {
    if [[ -x "/usr/local/bin/llama-server" ]] && [[ -x "/usr/local/bin/llama-cli" ]]; then
        info "llama.cpp is already installed"
        return 0
    else
        return 1
    fi
}

# Setup Open WebUI using Docker
# Open WebUI can work with various backends, not just Ollama
setup_openwebui_docker() {
    local user="$1"
    local distro="$2"
    
    info "Setting up Open WebUI with Docker..."
    
    # Install Docker if not present
    if ! command -v docker >/dev/null 2>&1; then
        info "Installing Docker..."
        case "$distro" in
            "arch")
                pacman -S --noconfirm --needed docker || warning "Failed to install docker via pacman"
                systemctl enable --now docker
                usermod -aG docker "$user"
                ;;
            "debian")
                # Install docker from official script
                curl -fsSL https://get.docker.com | sh || warning "Failed to install docker"
                usermod -aG docker "$user"
                ;;
            "fedora")
                dnf install -y docker || warning "Failed to install docker via dnf"
                systemctl enable --now docker
                usermod -aG docker "$user"
                ;;
            "opensuse")
                zypper install -y docker || warning "Failed to install docker via zypper"
                systemctl enable --now docker
                usermod -aG docker "$user"
                ;;
        esac
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        warning "Docker not available, cannot install Open WebUI. Please install Docker first."
        return
    fi

    # Ensure docker service is running
    if ! systemctl is-active --quiet docker; then
        systemctl start docker
    fi
    
    # Pull and run Open WebUI container
    # Maps host port 3000 to container port 8080
    # Uses host.docker.internal to access llama-server on host:8080
    info "Pulling and starting Open WebUI container..."
    
    # Stop existing container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^open-webui$"; then
        info "Stopping and removing existing open-webui container..."
        docker stop open-webui >/dev/null 2>&1 || true
        docker rm open-webui >/dev/null 2>&1 || true
    fi

    # Run container
    # -d: Detached mode
    # -p 3000:8080: Map host port 3000 to container port 8080
    # --add-host=host.docker.internal:host-gateway: Allow access to host services
    # -v open-webui:/app/backend/data: Persist data
    # --name open-webui: Container name
    # --restart always: Auto-restart on boot
    # -e OPENAI_API_BASE_URL=...: Point to llama-server on host
    docker run -d \
        -p 3000:8080 \
        --add-host=host.docker.internal:host-gateway \
        -v open-webui:/app/backend/data \
        --name open-webui \
        --restart always \
        -e OPENAI_API_BASE_URL=http://host.docker.internal:8080/v1 \
        -e OPENAI_API_KEY=sk-no-key-required \
        ghcr.io/open-webui/open-webui:main
    
    success "Open WebUI installed and started via Docker"
    info "Open WebUI is running on http://localhost:3000"
    info "It is configured to connect to llama-server at http://localhost:8080"
}

# Ask user which LLM backends to install
ask_backend_choice() {
    # interactive only when running in a TTY
    if [[ ! -t 0 ]]; then
        info "Non-interactive mode: installing both ollama and llama.cpp"
        echo "3" > /tmp/.gz302-backend-choice
        return
    fi
    
    echo
    echo "Choose LLM backends to install (both optimized for Strix Halo/gfx1151):"
    echo "  1) ollama only       - Model management backend (requires Open WebUI frontend)"
    echo "  2) llama.cpp only    - Fast inference with built-in webui (port 8080, flash attention enabled)"
    echo "  3) both              - Install both backends (recommended)"
    read -r -p "Install backends (1-3): " choice
    
    case "$choice" in
        1|2|3)
            echo "$choice" > /tmp/.gz302-backend-choice
            ;;
        *)
            warning "Invalid choice. Installing both by default."
            echo "3" > /tmp/.gz302-backend-choice
            ;;
    esac
}

# Ask user which frontends to install
ask_frontend_choice() {
    # interactive only when running in a TTY
    if [[ ! -t 0 ]]; then
        info "Skipping interactive frontend selection (non-interactive mode)."
        echo "" > /tmp/.gz302-frontend-choice
        return
    fi
    
    echo
    echo "Optional LLM frontends (choose one or more, or skip):"
    echo "  1) text-generation-webui - Feature-rich UI for local text LLMs (oobabooga)"
    echo "  2) ComfyUI              - Node-based UI ideal for image generation workflows"
    echo "  3) llama.cpp webui      - Lightweight built-in web interface (requires llama.cpp backend)"
    echo "  4) Open WebUI           - Modern web interface for various LLM backends"
    echo "  (Leave empty to skip frontends)"
    read -r -p "Install frontends (e.g. '1,3' or '1 2 3' or Enter=none): " choice
    
    # normalize and parse choice
    choice="${choice,,}"    # lowercase
    choice="${choice// /,}"  # replace spaces with commas
    choice="${choice//,/,}"  # clean up multiple commas
    
    if [[ -z "$choice" ]]; then
        echo "" > /tmp/.gz302-frontend-choice
    else
        echo "$choice" > /tmp/.gz302-frontend-choice
    fi
}

# --- CachyOS Detection ---
# CachyOS provides optimized packages for LLM/AI workloads via their repositories
# These include ollama-rocm, python-pytorch-opt-rocm with znver4 optimizations
is_cachyos() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        [[ "$ID" == "cachyos" ]]
    else
        return 1
    fi
}

# Print CachyOS LLM optimization info
print_cachyos_llm_info() {
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "CachyOS Detected - Using Optimized LLM Packages"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info ""
    info "CachyOS provides performance-optimized AI/ML packages:"
    info "  • ollama-rocm: Ollama with ROCm support for AMD GPUs"
    info "  • python-pytorch-opt-rocm: PyTorch with ROCm + AVX2 optimizations"
    info "  • Packages compiled with znver4 optimizations (5-20% faster)"
    info "  • LTO/PGO optimizations for AI workloads"
    info ""
    info "For manual installation:"
    info "  sudo pacman -S ollama-rocm python-pytorch-opt-rocm"
    info "  yay -S open-webui  # Optional web interface"
    info ""
    info "Reference: https://wiki.cachyos.org/"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info ""
}

# --- LLM/AI Software Installation Functions ---
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Detect CachyOS for optimized package installation
    local is_cachyos_system=false
    if is_cachyos; then
        is_cachyos_system=true
        print_cachyos_llm_info
    fi
    
    # Ask user what backends they want
    ask_backend_choice
    local backend_choice
    backend_choice=$(cat /tmp/.gz302-backend-choice)
    rm -f /tmp/.gz302-backend-choice
    
    # Install ollama if requested
    if [[ "$backend_choice" == "1" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_ollama_installed; then
            info "Installing Ollama..."
            # CachyOS: Use ollama-rocm for AMD GPU acceleration
            # Standard Arch: Use regular ollama package
            if [[ "$is_cachyos_system" == true ]]; then
                info "Using CachyOS optimized ollama-rocm package..."
                pacman -S --noconfirm --needed ollama-rocm
            else
                pacman -S --noconfirm --needed ollama
            fi
            systemctl enable --now ollama
        fi
        
        # Setup Open WebUI with uv (can work with various backends)
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "arch"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            info "Installing llama.cpp with ROCm support for Strix Halo..."
            
            # Install build dependencies and ROCm development tools BEFORE building
            # rocm-hip-sdk provides hipcc compiler and HIP development headers
            info "Installing build dependencies and ROCm development tools..."
            pacman -S --noconfirm --needed \
                git cmake make gcc pkgconf \
                rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas
            
            # Verify hipcc is available after installation
            if ! command -v hipcc >/dev/null 2>&1; then
                warning "hipcc not found in PATH after ROCm installation"
                warning "HIP compilation may fall back to CPU-only mode"
            fi
            
            # Build and install llama.cpp with ROCm support
            info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
            local llama_build_dir="/tmp/llama.cpp-build-$$"
            
            git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
            cd "$llama_build_dir"
            
            # Set ROCm environment for HIP compilation
            # HIPCXX and HIP_PATH are required for HIP detection in llama.cpp
            # HIP_DEVICE_LIB_PATH and CMAKE_CXX_FLAGS needed for including HIP headers
            export HIPCXX="/opt/rocm/lib/llvm/bin/clang"
            export HIP_PATH="/opt/rocm"
            export HIP_DEVICE_LIB_PATH="/opt/rocm/amdgcn/bitcode"
            
            # Build with HIP support targeting gfx1151 (Strix Halo/Radeon 8060S)
            mkdir build
            cd build
            cmake .. \
                -DGGML_HIP=ON \
                -DGPU_TARGETS=gfx1151 \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_CXX_FLAGS="-I/opt/rocm/include"
            
            local nproc_count
            nproc_count="$(nproc)"
            cmake --build . --config Release -j"${nproc_count}"
            
            # Install llama.cpp binaries to standard /usr/local prefix
            cmake --install .
            
            # Create systemd service for llama-server with Strix Halo optimizations
            # Critical for Strix Halo: -fa 1 (flash attention) and --no-mmap are REQUIRED
            # Flash attention enables fast inference; without it, performance collapses
            # --no-mmap prevents memory-mapping issues with Strix Halo's unified memory aperture
            # -ngl 999 forces all layers to GPU for maximum performance
            cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server (Strix Halo optimized)
After=network.target
Documentation=https://github.com/ggerganov/llama.cpp

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 -m /var/lib/gz302-llm/model.gguf --n-gpu-layers 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
            
            systemctl daemon-reload
            systemctl enable llama-server.service
            
            # Clean up build directory
            cd /
            rm -rf "$llama_build_dir"
            
            success "llama.cpp installed successfully with ROCm support for gfx1151"
            info "llama-cli and llama-server are available in /usr/local/bin"
            info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
            info "llama-server service enabled for autostart at boot"
        else
            info "llama.cpp is already installed - skipping compilation"
            # Ensure service is enabled for autoboot
            if systemctl is-enabled llama-server.service >/dev/null 2>&1; then
                info "llama-server service is already enabled for autostart"
            else
                info "Enabling llama-server service for autostart"
                systemctl enable llama-server.service
            fi
        fi
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm for AMD GPU acceleration
        info "Installing ROCm for AMD GPU acceleration..."
        if ! check_rocm_installed; then
            pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime rocblas miopen-hip
        fi
        
        # MIOpen precompiled kernels (gfx1151 for Radeon 8060S)
        # Note: As of Nov 2025, precompiled kernels for gfx1151 may not be available in repositories
        # The script checks for availability; if not found, MIOpen will JIT compile kernels on first use
        info "Checking for MIOpen precompiled kernels for gfx1151 (Radeon 8060S)..."
        if pacman -Ss miopen-hip 2>/dev/null | grep -q gfx1151; then
            info "Found gfx1151 kernel packages, installing..."
            pacman -S --noconfirm --needed miopen-hip-gfx1151kdb || warning "MIOpen gfx1151 kernel package installation failed, will JIT compile on first use"
        else
            info "MIOpen precompiled kernels for gfx1151 not available in repositories (expected as of Nov 2025)."
            info "MIOpen will JIT compile optimized kernels on first use (may take 5-15 minutes)."
        fi
        
        # Install Python and AI libraries
        # Note: ROCm 6.x wheels require Python 3.10-3.12 (no Python 3.13 support yet)
        # CachyOS users: python-pytorch-opt-rocm provides znver4-optimized PyTorch with ROCm
        info "Installing Python AI libraries..."
        
        # For CachyOS: Use system packages which are znver4-optimized
        if [[ "$is_cachyos_system" == true ]]; then
            info "Installing CachyOS optimized PyTorch packages (znver4 + ROCm)..."
            pacman -S --noconfirm --needed python-pytorch-opt-rocm python-pip || {
                warning "CachyOS python-pytorch-opt-rocm not available, falling back to pip wheels"
            }
            # Also install transformers/accelerate from pip for latest versions
            pip install --user transformers accelerate bitsandbytes 2>/dev/null || true
            
            success "CachyOS optimized AI packages installed"
            info "PyTorch is available system-wide with ROCm + AVX2 optimizations"
        else
            # Standard Arch: Use virtualenv with pip wheels
            pacman -S --noconfirm --needed python-pip python-virtualenv

            local primary_user
            primary_user=$(get_real_user)
            local venv_dir
            venv_dir="/var/lib/gz302-llm"
        
        # Determine best Python version for ROCm compatibility (prefer 3.11 or 3.12)
        local python_cmd="python3"
        if command -v python3.11 >/dev/null 2>&1; then
            python_cmd="python3.11"
            info "Using Python 3.11 for best ROCm wheel compatibility"
        elif command -v python3.12 >/dev/null 2>&1; then
            python_cmd="python3.12"
            info "Using Python 3.12 for ROCm wheel compatibility"
        elif command -v python3.10 >/dev/null 2>&1; then
            python_cmd="python3.10"
            info "Using Python 3.10 for ROCm wheel compatibility"
        else
            # Check if system Python is 3.13+ (no ROCm wheel support)
            local py_minor
            py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || echo "11")
            # Validate py_minor is numeric before comparison
            if [[ "$py_minor" =~ ^[0-9]+$ ]] && [[ "$py_minor" -ge 13 ]]; then
                warning "System Python is 3.$py_minor which has limited ROCm wheel support."
                warning "Consider installing python3.11 or python3.12 for better compatibility."
                warning "The conda/miniforge fallback will be attempted automatically if pip install fails."
            fi
        fi
        
        if [[ "$primary_user" != "root" ]]; then
            # Check if venv already exists
            if [[ -d "$venv_dir" ]] && [[ -f "$venv_dir/bin/python" ]]; then
                info "Python virtual environment already exists at $venv_dir"
                # Fix ownership in case of permission issues from previous runs
                chown -R "$primary_user:$primary_user" "$venv_dir" 2>/dev/null || true
            else
                # Create venv directory with correct ownership
                mkdir -p "$venv_dir"
                chown "$primary_user:$primary_user" "$venv_dir"
                
                # Create venv as the target user to ensure correct permissions
                sudo -u "$primary_user" "$python_cmd" -m venv "$venv_dir"
                info "Created Python virtual environment at $venv_dir"
            fi
            
            # Upgrade pip (run as venv owner)
            sudo -u "$primary_user" "$venv_dir/bin/pip" install --upgrade pip

            info "Installing PyTorch (ROCm 6.2 wheels) into the venv..."
            # ROCm 6.2 wheels support Python 3.10-3.12 and work with gfx1151 (Strix Halo)
            # Note: If rocm6.2 fails, try rocm6.1 as fallback
            if ! check_venv_package "$venv_dir" "torch"; then
                # Try ROCm 6.2 first (best compatibility with Strix Halo gfx1151)
                if ! sudo -u "$primary_user" "$venv_dir/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2; then
                    warning "PyTorch ROCm 6.2 installation failed. Trying ROCm 6.1..."
                    if ! sudo -u "$primary_user" "$venv_dir/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1; then
                        warning "PyTorch (ROCm 6.x) installation failed. Will try conda/miniforge fallback."
                        warning "Common causes: no compatible wheel for Python version or platform mismatch."
                    fi
                fi
            else
                info "PyTorch is already installed in venv"
            fi

            # Install transformers and accelerate regardless of torch outcome
            if ! check_venv_package "$venv_dir" "transformers"; then
                sudo -u "$primary_user" "$venv_dir/bin/pip" install transformers accelerate || warning "Failed to install transformers/accelerate inside venv"
            else
                info "transformers and accelerate are already installed in venv"
            fi

            # Install bitsandbytes for ROCm (quantization support)
            # As of November 2025, bitsandbytes has official ROCm support via standard pip
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! check_venv_package "$venv_dir" "bitsandbytes"; then
                # Standard pip install now supports ROCm (as of bitsandbytes 0.44+)
                if ! sudo -u "$primary_user" "$venv_dir/bin/pip" install bitsandbytes; then
                    warning "bitsandbytes installation failed. This is optional for quantization."
                    warning "For gfx1151 (Strix Halo), you may need to build from source."
                    warning "See: https://github.com/bitsandbytes-foundation/bitsandbytes"
                fi
            else
                info "bitsandbytes is already installed in venv"
            fi

            # Verify torch can be imported; only create marker if import fails at the end
            if sudo -u "$primary_user" "$venv_dir/bin/python" -c "import importlib; importlib.import_module('torch')" >/dev/null 2>&1; then
                info "PyTorch import succeeded inside the venv"
                # remove any stale failure marker
                mkdir -p "$venv_dir/.gz302" 2>/dev/null || true
                if [[ -f "$venv_dir/.gz302/torch_install_failed" ]]; then
                    rm -f "$venv_dir/.gz302/torch_install_failed" || true
                fi
            else
                warning "PyTorch could not be imported after installation attempts in the venv. Attempting conda/miniforge fallback for better binary compatibility (recommended for ROCm)."
                # Attempt a conda/miniforge fallback in the user's home to provide a reliable binary environment
                mkdir -p "$venv_dir/.gz302" || true

                # Detect existing conda
                conda_cmd=""
                if sudo -u "$primary_user" bash -lc "command -v conda >/dev/null 2>&1"; then
                    conda_cmd="$(sudo -u "$primary_user" bash -lc 'command -v conda')"
                elif [[ -x "/home/$primary_user/miniforge3/bin/conda" ]]; then
                    conda_cmd="/home/$primary_user/miniforge3/bin/conda"
                fi

                # Install Miniforge non-interactively if missing
                if [[ -z "$conda_cmd" ]]; then
                    info "Miniforge not found for $primary_user; installing Miniforge3 into /home/$primary_user/miniforge3"
                    sudo -u "$primary_user" bash -lc '\
                        set -euo pipefail; \
                        tmp="/tmp/miniforge_install_$$.sh"; \
                        curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o "$tmp"; \
                        bash "$tmp" -b -p "$HOME/miniforge3"; \
                        rm -f "$tmp"'
                    conda_cmd="/home/$primary_user/miniforge3/bin/conda"
                fi

                if [[ -n "$conda_cmd" && -x "$conda_cmd" ]]; then
                    # Use Python 3.11 in conda for best ROCm 6.x compatibility
                    info "Creating conda environment 'gz302-llm' (python 3.11) and trying PyTorch (ROCm 6.2) there"
                    sudo -u "$primary_user" "$conda_cmd" create -y -n gz302-llm python=3.11 pip || warning "Failed to create conda env gz302-llm"

                    # Use conda run to execute pip installs inside the env (no activation required)
                    # Try ROCm 6.2 first for best gfx1151 support
                    if ! sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2; then
                        warning "PyTorch ROCm 6.2 installation into conda env failed, trying ROCm 6.1..."
                        sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1 || warning "PyTorch installation into conda env gz302-llm failed"
                    fi
                    sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir transformers accelerate || warning "Failed to install transformers/accelerate inside conda env"
                    
                    # Install bitsandbytes for ROCm in conda env
                    info "Installing bitsandbytes for ROCm in conda environment..."
                    sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir bitsandbytes || warning "bitsandbytes installation failed in conda env (optional for quantization)"

                    # Verify torch import inside conda env
                    if sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm python -c "import importlib; importlib.import_module('torch')" >/dev/null 2>&1; then
                        info "PyTorch import succeeded inside conda env 'gz302-llm'"
                        # remove any stale failure marker
                        if [[ -f "$venv_dir/.gz302/torch_install_failed" ]]; then
                            rm -f "$venv_dir/.gz302/torch_install_failed" || true
                        fi
                        # write a small helper file noting conda env success
                        echo "conda_env:gz302-llm" > "$venv_dir/.gz302/torch_install_success" || true
                    else
                        warning "PyTorch still could not be imported after conda fallback. See https://pytorch.org for platform-specific instructions."
                        touch "$venv_dir/.gz302/torch_install_failed"
                    fi
                else
                    warning "No conda/miniforge available and automatic install failed; leaving venv-only installation state."
                    touch "$venv_dir/.gz302/torch_install_failed"
                fi
            fi

            # Cleanup: purge pip cache inside venv
            # Note: pip cache is automatically managed by pip in ~/.cache/pip/
            if [[ -x "$venv_dir/bin/pip" ]]; then
                sudo -u "$primary_user" "$venv_dir/bin/pip" cache purge || true
                info "Purged pip cache inside venv"
            fi

            info "To use AI libraries, activate the environment: source $venv_dir/bin/activate"
        fi
        fi  # End of CachyOS else block (standard Arch path)
    fi
    
    # Ask user which frontends to install (after backends are set up)
    ask_frontend_choice
    local frontend_choice
    frontend_choice=$(cat /tmp/.gz302-frontend-choice)
    rm -f /tmp/.gz302-frontend-choice
    
    # If user selected frontends, install them
    if [[ -n "$frontend_choice" ]]; then
        local primary_user
        primary_user=$(get_real_user)
        
        # Parse the comma-separated frontend choices
        IFS=',' read -r -a frontend_items <<< "$frontend_choice"
        for frontend in "${frontend_items[@]}"; do
            frontend="${frontend// /}"  # remove spaces
            case "$frontend" in
                1|text-generation-webui|textgen|text)
                    info "Installing text-generation-webui..."
                    local dst="/home/$primary_user/.local/share/text-generation-webui"
                    if [[ -d "$dst/.git" ]]; then
                        info "text-generation-webui already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/oobabooga/text-generation-webui "$dst" || warning "Failed to clone text-generation-webui"
                        info "Cloned text-generation-webui to $dst"
                        info "To finish install: cd $dst && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt"
                    fi
                    ;;
                2|comfyui|comfy)
                    info "Installing ComfyUI..."
                    local dst="/home/$primary_user/.local/share/comfyui"
                    if [[ -d "$dst/.git" ]]; then
                        info "ComfyUI already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/comfyanonymous/ComfyUI "$dst" || warning "Failed to clone ComfyUI"
                        info "Cloned ComfyUI to $dst"
                        info "See $dst/README.md for install instructions (venv or comfy-cli)"
                    fi
                    ;;
                3|llamacpp|llama-cpp|webui|"llama.cpp webui"|llamaccppwebui)
                    info "llama.cpp webui is built-in (port 8080) when llama.cpp backend is running"
                    if [[ "$backend_choice" != "2" ]] && [[ "$backend_choice" != "3" ]]; then
                        warning "llama.cpp webui requires llama.cpp backend. Install llama.cpp backend to use this webui."
                    fi
                    ;;
                4|openwebui|open-web-ui)
                    setup_openwebui_docker "$primary_user" "arch"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
    fi
    
    success "LLM/AI software installation completed"
}

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    
    # Ask user what backends they want
    ask_backend_choice
    local backend_choice
    backend_choice=$(cat /tmp/.gz302-backend-choice)
    rm -f /tmp/.gz302-backend-choice
    
    # Install ollama if requested
    if [[ "$backend_choice" == "1" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
        systemctl enable --now ollama
        
        # Setup Open WebUI with uv (can work with various backends)
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "debian"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies and ROCm development tools BEFORE building
        apt update
        apt install -y git cmake make g++ pkg-config
        
        # ROCm for Debian: Install from AMD ROCm repository
        info "Installing ROCm SDK for HIP compilation..."
        apt install -y rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas || \
            warning "Some ROCm packages may not be available; trying with hipblas-dev"
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Set ROCm environment for HIP compilation
        # HIPCXX and HIP_PATH are required for HIP detection in llama.cpp
        # HIP_DEVICE_LIB_PATH and CMAKE_CXX_FLAGS needed for including HIP headers
        export HIPCXX="/opt/rocm/lib/llvm/bin/clang"
        export HIP_PATH="/opt/rocm"
        export HIP_DEVICE_LIB_PATH="/opt/rocm/amdgcn/bitcode"
        
        # Build with HIP support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIP=ON \
            -DGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS="-I/opt/rocm/include"
        
        local nproc_count
        nproc_count="$(nproc)"
        cmake --build . --config Release -j"${nproc_count}"
        
        # Install llama.cpp binaries
        cmake --install .
        
        # Create systemd service for llama-server with Strix Halo optimizations
        # Critical for Strix Halo: -fa 1 (flash attention) and --no-mmap are REQUIRED
        # Flash attention enables fast inference; without it, performance collapses
        # --no-mmap prevents memory-mapping issues with Strix Halo's unified memory aperture
        # -ngl 999 forces all layers to GPU for maximum performance
        cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server (Strix Halo optimized)
After=network.target
Documentation=https://github.com/ggerganov/llama.cpp

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 -m /var/lib/gz302-llm/model.gguf --n-gpu-layers 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nogroup
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable llama-server.service
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "llama-server service enabled for autostart at boot"
    else
        info "llama.cpp is already installed - skipping compilation"
        # Ensure service is enabled for autoboot
        if systemctl is-enabled llama-server.service >/dev/null 2>&1; then
            info "llama-server service is already enabled for autostart"
        else
            info "Enabling llama-server service for autostart"
            systemctl enable llama-server.service
        fi
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        
        # Setup ROCm repository if not already installed
        if ! check_rocm_installed_debian; then
            # First, try to setup AMD's official ROCm repository
            setup_rocm_repo_debian || warning "Failed to setup AMD ROCm repository, will try Debian default repos"
            
            # Try to install ROCm packages (from AMD repo if added, otherwise from Debian repos)
            local rocm_log
            rocm_log=$(mktemp)
            if ! apt install -y rocm-opencl-runtime rocblas miopen-hip 2>&1 | tee "$rocm_log"; then
                warning "ROCm packages not available from repositories"
                if grep -qi "unable to locate package" "$rocm_log"; then
                    info "Note: Debian Trixie may have ROCm packages in testing/unstable repos"
                fi
                info "Manual installation: https://rocm.docs.amd.com/projects/install-on-linux/en/latest/install/install-methods/package-manager/package-manager-debian.html"
            fi
            rm -f "$rocm_log"
        fi
        
        # Install MIOpen precompiled kernels if available
        # Note: As of Nov 2025, precompiled kernels for gfx1151 may not be available
        info "Checking for MIOpen precompiled kernels for gfx1151 (Radeon 8060S)..."
        if apt-cache search miopen-hip 2>/dev/null | grep -q gfx1151; then
            info "Found gfx1151 kernel packages, installing..."
            apt install -y miopen-hip-gfx1151kdb || warning "MIOpen gfx1151 kernel package installation failed"
        else
            info "MIOpen precompiled kernels for gfx1151 not available in repositories (expected as of Nov 2025)."
            info "MIOpen will JIT compile optimized kernels on first use (may take 5-15 minutes)."
        fi
        
        # Install Python and AI libraries
        # Note: ROCm 6.x wheels require Python 3.10-3.12 (no Python 3.13 support yet)
        info "Installing Python AI libraries..."
        apt install -y python3-pip python3-venv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            # Install PyTorch with ROCm 6.2 wheels (supports Python 3.10-3.12)
            if ! check_system_python_package "torch"; then
                if ! sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2; then
                    warning "PyTorch ROCm 6.2 installation failed. Trying ROCm 6.1..."
                    sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1 || warning "PyTorch installation failed"
                fi
            else
                info "PyTorch is already installed in system Python"
            fi
            
            # Install transformers and accelerate
            if ! check_system_python_package "transformers"; then
                sudo -u "$primary_user" pip3 install --user transformers accelerate
            else
                info "transformers and accelerate are already installed in system Python"
            fi
            
            # Install bitsandbytes for ROCm (now has official support via standard pip)
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! check_system_python_package "bitsandbytes"; then
                sudo -u "$primary_user" pip3 install --user bitsandbytes || warning "bitsandbytes installation failed (optional for quantization)"
            else
                info "bitsandbytes is already installed in system Python"
            fi
        fi
    fi
    
    # Ask user which frontends to install (after backends are set up)
    ask_frontend_choice
    local frontend_choice
    frontend_choice=$(cat /tmp/.gz302-frontend-choice)
    rm -f /tmp/.gz302-frontend-choice
    
    # If user selected frontends, install them
    if [[ -n "$frontend_choice" ]]; then
        local primary_user
        primary_user=$(get_real_user)
        
        # Parse the comma-separated frontend choices
        IFS=',' read -r -a frontend_items <<< "$frontend_choice"
        for frontend in "${frontend_items[@]}"; do
            frontend="${frontend// /}"  # remove spaces
            case "$frontend" in
                1|text-generation-webui|textgen|text)
                    info "Installing text-generation-webui..."
                    local dst="/home/$primary_user/.local/share/text-generation-webui"
                    if [[ -d "$dst/.git" ]]; then
                        info "text-generation-webui already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/oobabooga/text-generation-webui "$dst" || warning "Failed to clone text-generation-webui"
                        info "Cloned text-generation-webui to $dst"
                        info "To finish install: cd $dst && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt"
                    fi
                    ;;
                2|comfyui|comfy)
                    info "Installing ComfyUI..."
                    local dst="/home/$primary_user/.local/share/comfyui"
                    if [[ -d "$dst/.git" ]]; then
                        info "ComfyUI already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/comfyanonymous/ComfyUI "$dst" || warning "Failed to clone ComfyUI"
                        info "Cloned ComfyUI to $dst"
                        info "See $dst/README.md for install instructions (venv or comfy-cli)"
                    fi
                    ;;
                3|llamacpp|llama-cpp|webui|"llama.cpp webui"|llamaccppwebui)
                    info "llama.cpp webui is built-in (port 8080) when llama.cpp backend is running"
                    if [[ "$backend_choice" != "2" ]] && [[ "$backend_choice" != "3" ]]; then
                        warning "llama.cpp webui requires llama.cpp backend. Install llama.cpp backend to use this webui."
                    fi
                    ;;
                4|openwebui|open-web-ui)
                    setup_openwebui_docker "$primary_user" "debian"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
    fi
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Ask user what backends they want
    ask_backend_choice
    local backend_choice
    backend_choice=$(cat /tmp/.gz302-backend-choice)
    rm -f /tmp/.gz302-backend-choice
    
    # Install ollama if requested
    if [[ "$backend_choice" == "1" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
        systemctl enable --now ollama
        
        # Setup Open WebUI with uv (can work with various backends)
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "fedora"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies and ROCm development tools BEFORE building
        dnf install -y git cmake make gcc-c++ pkgconfig
        
        # ROCm for Fedora: Install from AMD ROCm repository
        info "Installing ROCm SDK for HIP compilation..."
        dnf install -y rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas || \
            warning "Some ROCm packages may not be available; trying with essential packages"
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Set ROCm environment for HIP compilation
        # HIPCXX and HIP_PATH are required for HIP detection in llama.cpp
        # HIP_DEVICE_LIB_PATH and CMAKE_CXX_FLAGS needed for including HIP headers
        export HIPCXX="/opt/rocm/lib/llvm/bin/clang"
        export HIP_PATH="/opt/rocm"
        export HIP_DEVICE_LIB_PATH="/opt/rocm/amdgcn/bitcode"
        
        # Build with HIP support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIP=ON \
            -DGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS="-I/opt/rocm/include"
        
        local nproc_count
        nproc_count="$(nproc)"
        cmake --build . --config Release -j"${nproc_count}"
        
        # Install llama.cpp binaries
        cmake --install .
        
        # Create systemd service for llama-server with Strix Halo optimizations
        # Critical for Strix Halo: -fa 1 (flash attention) and --no-mmap are REQUIRED
        # Flash attention enables fast inference; without it, performance collapses
        # --no-mmap prevents memory-mapping issues with Strix Halo's unified memory aperture
        # -ngl 999 forces all layers to GPU for maximum performance
        cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server (Strix Halo optimized)
After=network.target
Documentation=https://github.com/ggerganov/llama.cpp

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 -m /var/lib/gz302-llm/model.gguf --n-gpu-layers 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable llama-server.service
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "llama-server service enabled for autostart at boot"
    else
        info "llama.cpp is already installed - skipping compilation"
        # Ensure service is enabled for autoboot
        if systemctl is-enabled llama-server.service >/dev/null 2>&1; then
            info "llama-server service is already enabled for autostart"
        else
            info "Enabling llama-server service for autostart"
            systemctl enable llama-server.service
        fi
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        # ROCm packages may be available via EPEL or custom repos
        if ! check_rocm_installed_fedora; then
            dnf install -y rocm-opencl rocblas miopen-hip || warning "ROCm packages not available in default repositories. Consider adding AMD ROCm repository."
        fi
        
        # Install Python and AI libraries
        # Note: ROCm 6.x wheels require Python 3.10-3.12 (no Python 3.13 support yet)
        info "Installing Python AI libraries..."
        dnf install -y python3-pip python3-virtualenv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            # Install PyTorch with ROCm 6.2 wheels (supports Python 3.10-3.12)
            if ! check_system_python_package "torch"; then
                if ! sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2; then
                    warning "PyTorch ROCm 6.2 installation failed. Trying ROCm 6.1..."
                    sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1 || warning "PyTorch installation failed"
                fi
            else
                info "PyTorch is already installed in system Python"
            fi
            
            # Install transformers and accelerate
            if ! check_system_python_package "transformers"; then
                sudo -u "$primary_user" pip3 install --user transformers accelerate
            else
                info "transformers and accelerate are already installed in system Python"
            fi
            
            # Install bitsandbytes for ROCm (now has official support via standard pip)
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! check_system_python_package "bitsandbytes"; then
                sudo -u "$primary_user" pip3 install --user bitsandbytes || warning "bitsandbytes installation failed (optional for quantization)"
            else
                info "bitsandbytes is already installed in system Python"
            fi
        fi
    fi
    
    # Ask user which frontends to install (after backends are set up) - Fedora
    ask_frontend_choice
    local frontend_choice
    frontend_choice=$(cat /tmp/.gz302-frontend-choice)
    rm -f /tmp/.gz302-frontend-choice
    
    # If user selected frontends, install them
    if [[ -n "$frontend_choice" ]]; then
        local primary_user
        primary_user=$(get_real_user)
        
        # Parse the comma-separated frontend choices
        IFS=',' read -r -a frontend_items <<< "$frontend_choice"
        for frontend in "${frontend_items[@]}"; do
            frontend="${frontend// /}"  # remove spaces
            case "$frontend" in
                1|text-generation-webui|textgen|text)
                    info "Installing text-generation-webui..."
                    local dst="/home/$primary_user/.local/share/text-generation-webui"
                    if [[ -d "$dst/.git" ]]; then
                        info "text-generation-webui already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/oobabooga/text-generation-webui "$dst" || warning "Failed to clone text-generation-webui"
                        info "Cloned text-generation-webui to $dst"
                        info "To finish install: cd $dst && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt"
                    fi
                    ;;
                2|comfyui|comfy)
                    info "Installing ComfyUI..."
                    local dst="/home/$primary_user/.local/share/comfyui"
                    if [[ -d "$dst/.git" ]]; then
                        info "ComfyUI already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/comfyanonymous/ComfyUI "$dst" || warning "Failed to clone ComfyUI"
                        info "Cloned ComfyUI to $dst"
                        info "See $dst/README.md for install instructions (venv or comfy-cli)"
                    fi
                    ;;
                3|llamacpp|llama-cpp|webui|"llama.cpp webui"|llamaccppwebui)
                    info "llama.cpp webui is built-in (port 8080) when llama.cpp backend is running"
                    if [[ "$backend_choice" != "2" ]] && [[ "$backend_choice" != "3" ]]; then
                        warning "llama.cpp webui requires llama.cpp backend. Install llama.cpp backend to use this webui."
                    fi
                    ;;
                4|openwebui|open-web-ui)
                    setup_openwebui_docker "$primary_user" "fedora"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
    fi
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Ask user what backends they want
    ask_backend_choice
    local backend_choice
    backend_choice=$(cat /tmp/.gz302-backend-choice)
    rm -f /tmp/.gz302-backend-choice
    
    # Install ollama if requested
    if [[ "$backend_choice" == "1" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
        systemctl enable --now ollama
        
        # Setup Open WebUI with uv (can work with various backends)
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "opensuse"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies and ROCm development tools BEFORE building
        zypper install -y git cmake make gcc-c++ pkg-config
        
        # ROCm for OpenSUSE: Install from AMD ROCm repository (if available)
        info "Installing ROCm SDK for HIP compilation..."
        zypper install -y rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas || \
            warning "Some ROCm packages may not be available; trying with essential packages"
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Set ROCm environment for HIP compilation
        # HIPCXX and HIP_PATH are required for HIP detection in llama.cpp
        # HIP_DEVICE_LIB_PATH and CMAKE_CXX_FLAGS needed for including HIP headers
        export HIPCXX="/opt/rocm/lib/llvm/bin/clang"
        export HIP_PATH="/opt/rocm"
        export HIP_DEVICE_LIB_PATH="/opt/rocm/amdgcn/bitcode"
        
        # Build with HIP support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIP=ON \
            -DGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS="-I/opt/rocm/include"
        
        local nproc_count
        nproc_count="$(nproc)"
        cmake --build . --config Release -j"${nproc_count}"
        
        # Install llama.cpp binaries
        cmake --install .
        
        # Create systemd service for llama-server with Strix Halo optimizations
        # Critical for Strix Halo: -fa 1 (flash attention) and --no-mmap are REQUIRED
        # Flash attention enables fast inference; without it, performance collapses
        # --no-mmap prevents memory-mapping issues with Strix Halo's unified memory aperture
        # -ngl 999 forces all layers to GPU for maximum performance
        cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server (Strix Halo optimized)
After=network.target
Documentation=https://github.com/ggerganov/llama.cpp

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 -m /var/lib/gz302-llm/model.gguf --n-gpu-layers 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable llama-server.service
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "llama-server service enabled for autostart at boot"
    else
        info "llama.cpp is already installed - skipping compilation"
        # Ensure service is enabled for autoboot
        if systemctl is-enabled llama-server.service >/dev/null 2>&1; then
            info "llama-server service is already enabled for autostart"
        else
            info "Enabling llama-server service for autostart"
            systemctl enable llama-server.service
        fi
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        # ROCm packages may be available via OBS repositories
        if ! check_rocm_installed_opensuse; then
            zypper install -y rocm-opencl rocblas miopen-hip || warning "ROCm packages not available in default repositories. Consider adding AMD ROCm repository."
        fi
        
        # Install Python and AI libraries
        # Note: ROCm 6.x wheels require Python 3.10-3.12 (no Python 3.13 support yet)
        info "Installing Python AI libraries..."
        zypper install -y python3-pip python3-virtualenv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            # Install PyTorch with ROCm 6.2 wheels (supports Python 3.10-3.12)
            if ! check_system_python_package "torch"; then
                if ! sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2; then
                    warning "PyTorch ROCm 6.2 installation failed. Trying ROCm 6.1..."
                    sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1 || warning "PyTorch installation failed"
                fi
            else
                info "PyTorch is already installed in system Python"
            fi
            
            # Install transformers and accelerate
            if ! check_system_python_package "transformers"; then
                sudo -u "$primary_user" pip3 install --user transformers accelerate
            else
                info "transformers and accelerate are already installed in system Python"
            fi
            
            # Install bitsandbytes for ROCm (now has official support via standard pip)
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! check_system_python_package "bitsandbytes"; then
                sudo -u "$primary_user" pip3 install --user bitsandbytes || warning "bitsandbytes installation failed (optional for quantization)"
            else
                info "bitsandbytes is already installed in system Python"
            fi
        fi
    fi
    
    # Ask user which frontends to install (after backends are set up) - OpenSUSE
    ask_frontend_choice
    local frontend_choice
    frontend_choice=$(cat /tmp/.gz302-frontend-choice)
    rm -f /tmp/.gz302-frontend-choice
    
    # If user selected frontends, install them
    if [[ -n "$frontend_choice" ]]; then
        local primary_user
        primary_user=$(get_real_user)
        
        # Parse the comma-separated frontend choices
        IFS=',' read -r -a frontend_items <<< "$frontend_choice"
        for frontend in "${frontend_items[@]}"; do
            frontend="${frontend// /}"  # remove spaces
            case "$frontend" in
                1|text-generation-webui|textgen|text)
                    info "Installing text-generation-webui..."
                    local dst="/home/$primary_user/.local/share/text-generation-webui"
                    if [[ -d "$dst/.git" ]]; then
                        info "text-generation-webui already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/oobabooga/text-generation-webui "$dst" || warning "Failed to clone text-generation-webui"
                        info "Cloned text-generation-webui to $dst"
                        info "To finish install: cd $dst && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt"
                    fi
                    ;;
                2|comfyui|comfy)
                    info "Installing ComfyUI..."
                    local dst="/home/$primary_user/.local/share/comfyui"
                    if [[ -d "$dst/.git" ]]; then
                        info "ComfyUI already cloned"
                    else
                        sudo -u "$primary_user" git clone https://github.com/comfyanonymous/ComfyUI "$dst" || warning "Failed to clone ComfyUI"
                        info "Cloned ComfyUI to $dst"
                        info "See $dst/README.md for install instructions (venv or comfy-cli)"
                    fi
                    ;;
                3|llamacpp|llama-cpp|webui|"llama.cpp webui"|llamaccppwebui)
                    info "llama.cpp webui is built-in (port 8080) when llama.cpp backend is running"
                    if [[ "$backend_choice" != "2" ]] && [[ "$backend_choice" != "3" ]]; then
                        warning "llama.cpp webui requires llama.cpp backend. Install llama.cpp backend to use this webui."
                    fi
                    ;;
                4|openwebui|open-web-ui)
                    setup_openwebui_docker "$primary_user" "opensuse"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
    fi
    
    success "LLM/AI software installation completed"
}

# --- Path Migration for Backward Compatibility ---
# Migrates old LLM paths from pre-1.3.0 versions to FHS-compliant paths
migrate_llm_paths() {
    local old_venv_dir
    old_venv_dir="${HOME}/.local/share/gz302-llm"
    local new_venv_dir="/var/lib/gz302-llm"
    
    # Check if old venv exists but new one doesn't
    if [[ -d "$old_venv_dir" ]] && [[ ! -d "$new_venv_dir" ]]; then
        info "Migrating LLM venv from user home to system location..."
        info "Source: $old_venv_dir"
        info "Target: $new_venv_dir"
        
        # Create new directory with proper permissions
        sudo mkdir -p "$new_venv_dir"
        
        # Copy old venv to new location
        if sudo cp -r "$old_venv_dir"/* "$new_venv_dir/" 2>/dev/null; then
            sudo chmod 755 "$new_venv_dir"
            sudo chmod -R 755 "$new_venv_dir/bin" 2>/dev/null || true
            sudo chmod -R 644 "$new_venv_dir"/* 2>/dev/null || true
            
            # Remove old venv
            rm -rf "$old_venv_dir"
            
            # Remove old directory if parent is now empty
            if [[ -d "${old_venv_dir%/*}" ]] && ! ls -A "${old_venv_dir%/*}" >/dev/null 2>&1; then
                rmdir "${old_venv_dir%/*}" 2>/dev/null || true
            fi
            
            success "Migrated LLM venv to $new_venv_dir"
            echo
        else
            warning "Failed to migrate LLM venv, but will continue with new location"
        fi
    fi
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
    
    # Migrate old LLM paths from pre-1.3.0 versions to FHS-compliant paths
    migrate_llm_paths
    
    # Configure kernel parameters optimized for LLM workloads
    configure_llm_kernel_params
    
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
