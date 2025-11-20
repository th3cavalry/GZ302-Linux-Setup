#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 2.2.0
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Ollama, ROCm, PyTorch, MIOpen, bitsandbytes, Transformers
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
    if [[ -x "/usr/local/bin/llama-server" ]] && systemctl is-enabled llama-server.service >/dev/null 2>&1; then
        info "llama.cpp is already installed"
        return 0
    else
        return 1
    fi
}

# Setup Python 3.11 virtual environment for Open WebUI using uv
# Open WebUI can work with various backends, not just Ollama
setup_openwebui_with_uv() {
    local user="$1"
    local distro="$2"
    local openwebui_dir="/home/$user/open-webui"
    
    if [[ -d "$openwebui_dir" ]] && [[ -f "$openwebui_dir/.venv/bin/open-webui" ]]; then
        info "Open WebUI is already installed at $openwebui_dir"
        return
    fi
    
    info "Setting up Open WebUI with uv..."
    
    # Install uv if not present
    if ! command -v uv >/dev/null 2>&1; then
        info "Installing uv package manager..."
        case "$distro" in
            "arch")
                pacman -S --noconfirm --needed uv || warning "Failed to install uv via pacman"
                ;;
            "debian")
                # Install uv from official script
                curl -LsSf https://astral.sh/uv/install.sh | sh || warning "Failed to install uv"
                ;;
            "fedora")
                dnf install -y uv || warning "Failed to install uv via dnf"
                ;;
            "opensuse")
                zypper install -y uv || warning "Failed to install uv via zypper"
                ;;
        esac
    fi
    
    if ! command -v uv >/dev/null 2>&1; then
        warning "uv not available, falling back to pip installation"
        # Fallback to old method
        setup_python311_venv_for_openwebui "$user" "$distro"
        return
    fi
    
    # Create directory for Open WebUI
    sudo -u "$user" mkdir -p "$openwebui_dir"
    cd "$openwebui_dir"
    
    # Initialize a managed environment with Python 3.11 explicitly
    info "Creating uv virtual environment with Python 3.11..."
    sudo -u "$user" uv venv --python 3.11 || error "Failed to create uv venv with Python 3.11"
    
    # Activate and install Open WebUI
    info "Installing Open WebUI with uv..."
    sudo -u "$user" uv pip install open-webui || warning "Open WebUI installation failed"
    
    success "Open WebUI installed at $openwebui_dir"
    info "To run Open WebUI: cd $openwebui_dir && source .venv/bin/activate && open-webui serve"
}

# Legacy function for backward compatibility
setup_python311_venv_for_openwebui() {
    local user="$1"
    local distro="$2"
    local venv_dir="/home/$user/.gz302-open-webui-venv"
    
    if [[ -d "$venv_dir" ]]; then
        info "Python 3.11 venv for Open WebUI already exists at $venv_dir"
        return
    fi
    
    info "Setting up Python 3.11 virtual environment for Open WebUI..."
    
    # First, check if python3.11 is available
    local python311_cmd=""
    if command -v python3.11 >/dev/null 2>&1; then
        python311_cmd="python3.11"
    elif command -v python311 >/dev/null 2>&1; then
        python311_cmd="python311"
    else
        # Try to install Python 3.11 based on distro
        info "Python 3.11 not found. Attempting distro-specific installation..."
        case "$distro" in
            "arch")
                pacman -S --noconfirm --needed python3.11 || warning "Failed to install Python 3.11 via pacman"
                python311_cmd="python3.11"
                ;;
            "debian")
                # Ubuntu 22.04+ has python3.11 in universe; 24.04+ in main
                apt update
                apt install -y python3.11 python3.11-venv || warning "Failed to install Python 3.11 via apt"
                python311_cmd="python3.11"
                ;;
            "fedora")
                dnf install -y python3.11 || warning "Failed to install Python 3.11 via dnf"
                python311_cmd="python3.11"
                ;;
            "opensuse")
                zypper install -y python311 || warning "Failed to install Python 3.11 via zypper"
                python311_cmd="python3.11"
                ;;
        esac
    fi
    
    if ! command -v "$python311_cmd" >/dev/null 2>&1; then
        warning "Python 3.11 not available after installation attempt. Falling back to system python (Open WebUI may fail)."
        python311_cmd="python3"
    fi
    
    # Create venv with Python 3.11
    info "Creating Python 3.11 virtual environment..."
    sudo -u "$user" "$python311_cmd" -m venv "$venv_dir" || error "Failed to create Python 3.11 venv"
    
    # Upgrade pip and install Open WebUI
    sudo -u "$user" "$venv_dir/bin/pip" install --upgrade pip
    info "Installing Open WebUI into Python 3.11 venv..."
    sudo -u "$user" "$venv_dir/bin/pip" install open-webui || warning "Open WebUI installation failed"
    
    success "Python 3.11 venv for Open WebUI created at $venv_dir"
    info "To run Open WebUI: source $venv_dir/bin/activate && open-webui serve"
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

# --- LLM/AI Software Installation Functions ---
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Ask user what backends they want
    ask_backend_choice
    local backend_choice
    backend_choice=$(cat /tmp/.gz302-backend-choice)
    rm -f /tmp/.gz302-backend-choice
    
    # Install ollama if requested
    if [[ "$backend_choice" == "1" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_ollama_installed; then
            info "Installing Ollama..."
            pacman -S --noconfirm --needed ollama
            systemctl enable --now ollama
        fi
        
        # Setup Open WebUI with uv (can work with various backends)
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_with_uv "$primary_user" "arch"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            info "Installing llama.cpp with ROCm support for Strix Halo..."
            
            # Install build dependencies
            pacman -S --noconfirm --needed git cmake make gcc pkgconf
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIPBLAS=ON \
            -DAMDGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release
        
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
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 --ngl 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "To start llama-server: sudo systemctl enable --now llama-server"
        fi
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm for AMD GPU acceleration
        info "Installing ROCm for AMD GPU acceleration..."
        pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime rocblas miopen-hip
        
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
        info "Installing Python AI libraries (using virtualenv)..."
        pacman -S --noconfirm --needed python-pip python-virtualenv

        local primary_user
        primary_user=$(get_real_user)
        local venv_dir
        venv_dir="/home/$primary_user/.gz302-llm-venv"
        if [[ "$primary_user" != "root" ]]; then
            sudo -u "$primary_user" python -m venv "$venv_dir"
            info "Created Python virtual environment at $venv_dir"
            sudo -u "$primary_user" "$venv_dir/bin/pip" install --upgrade pip

            info "Installing PyTorch (ROCm wheels) into the venv..."
            # Try installing PyTorch; if this fails here it may succeed later via other means
            if ! sudo -u "$primary_user" "$venv_dir/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7; then
                warning "PyTorch (ROCm) initial installation attempt failed. Will verify after other installs before marking as failed."
                warning "Common causes: no compatible wheel for system Python (e.g. Python 3.12/3.13) or platform mismatch."
            fi

            # Install transformers and accelerate regardless of torch outcome
            sudo -u "$primary_user" "$venv_dir/bin/pip" install transformers accelerate || warning "Failed to install transformers/accelerate inside venv"

            # Install bitsandbytes for ROCm (quantization support)
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            # Try to install bitsandbytes with ROCm support
            # Note: ROCm support for gfx1151 is in preview; may need custom build
            if ! sudo -u "$primary_user" "$venv_dir/bin/pip" install bitsandbytes; then
                warning "Standard bitsandbytes installation failed. Trying ROCm-specific wheel..."
                # Try ROCm-specific development wheel if available
                sudo -u "$primary_user" "$venv_dir/bin/pip" install --no-deps --force-reinstall \
                    'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl' \
                    || warning "ROCm bitsandbytes wheel installation failed. You may need to build from source for gfx1151 support."
            fi

            # Verify torch can be imported; only create marker if import fails at the end
            if sudo -u "$primary_user" "$venv_dir/bin/python" -c "import importlib; importlib.import_module('torch')" >/dev/null 2>&1; then
                info "PyTorch import succeeded inside the venv"
                # remove any stale failure marker
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
                    info "Creating conda environment 'gz302-llm' (python 3.10) and trying PyTorch (ROCm) there"
                    sudo -u "$primary_user" "$conda_cmd" create -y -n gz302-llm python=3.10 pip || warning "Failed to create conda env gz302-llm"

                    # Use conda run to execute pip installs inside the env (no activation required)
                    if ! sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7; then
                        warning "PyTorch installation into conda env gz302-llm failed"
                    fi
                    sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir transformers accelerate || warning "Failed to install transformers/accelerate inside conda env"
                    
                    # Install bitsandbytes for ROCm in conda env
                    info "Installing bitsandbytes for ROCm in conda environment..."
                    if ! sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-cache-dir bitsandbytes; then
                        warning "Standard bitsandbytes installation failed in conda. Trying ROCm-specific wheel..."
                        sudo -u "$primary_user" "$conda_cmd" run -n gz302-llm pip install --no-deps --force-reinstall --no-cache-dir \
                            'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl' \
                            || warning "ROCm bitsandbytes wheel installation failed in conda env."
                    fi

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

            # Cleanup: remove any temporary pip TMPDIR we may have used and purge pip cache inside venv
            if [[ -d "/home/$primary_user/.cache/pip-tmp" ]]; then
                sudo -u "$primary_user" rm -rf "/home/$primary_user/.cache/pip-tmp" || true
                info "Removed temporary pip TMPDIR /home/$primary_user/.cache/pip-tmp"
            fi
            if [[ -x "$venv_dir/bin/pip" ]]; then
                sudo -u "$primary_user" "$venv_dir/bin/pip" cache purge || true
                info "Purged pip cache inside venv"
            fi

            info "To use AI libraries, activate the environment: source $venv_dir/bin/activate"
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/text-generation-webui"
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/ComfyUI"
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
                    setup_openwebui_with_uv "$primary_user" "arch"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
    fi
    
    success "LLM/AI software installation completed"
}

    # --- Frontend installers (opt-in, lightweight/idempotent) ---
    ensure_user_dirs() {
        local user="$1"
        sudo -u "$user" mkdir -p "/home/$user/.local/share/gz302/frontends" || true
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
        setup_openwebui_with_uv "$primary_user" "debian"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies
        apt update
        apt install -y git cmake make g++ pkg-config
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIPBLAS=ON \
            -DAMDGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release
        
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
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 --ngl 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nogroup
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "To start llama-server: sudo systemctl enable --now llama-server"
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        # Try to install ROCm packages if available
        apt install -y rocm-opencl-runtime rocblas miopen-hip || warning "ROCm packages not available in default repositories. Consider adding AMD ROCm repository."
        
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
        info "Installing Python AI libraries..."
        apt install -y python3-pip python3-venv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
            sudo -u "$primary_user" pip3 install --user transformers accelerate
            
            # Install bitsandbytes for ROCm
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! sudo -u "$primary_user" pip3 install --user bitsandbytes; then
                warning "Standard bitsandbytes installation failed. Trying ROCm-specific wheel..."
                sudo -u "$primary_user" pip3 install --user --no-deps --force-reinstall \
                    'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl' \
                    || warning "ROCm bitsandbytes wheel installation failed."
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/text-generation-webui"
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/ComfyUI"
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
                    setup_openwebui_with_uv "$primary_user" "debian"
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
        setup_openwebui_with_uv "$primary_user" "fedora"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies
        dnf install -y git cmake make gcc-c++ pkgconfig
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIPBLAS=ON \
            -DAMDGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release
        
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
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 --ngl 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "To start llama-server: sudo systemctl enable --now llama-server"
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        # ROCm packages may be available via EPEL or custom repos
        dnf install -y rocm-opencl rocblas miopen-hip || warning "ROCm packages not available in default repositories. Consider adding AMD ROCm repository."
        
        # Install Python and AI libraries
        info "Installing Python AI libraries..."
        dnf install -y python3-pip python3-virtualenv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
            sudo -u "$primary_user" pip3 install --user transformers accelerate
            
            # Install bitsandbytes for ROCm
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! sudo -u "$primary_user" pip3 install --user bitsandbytes; then
                warning "Standard bitsandbytes installation failed. Trying ROCm-specific wheel..."
                sudo -u "$primary_user" pip3 install --user --no-deps --force-reinstall \
                    'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl' \
                    || warning "ROCm bitsandbytes wheel installation failed."
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/text-generation-webui"
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/ComfyUI"
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
                    setup_openwebui_with_uv "$primary_user" "fedora"
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
        setup_openwebui_with_uv "$primary_user" "opensuse"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        info "Installing llama.cpp with ROCm support for Strix Halo..."
        
        # Install build dependencies
        zypper install -y git cmake make gcc-c++ pkg-config
        
        # Build and install llama.cpp with ROCm support
        info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
        local llama_build_dir="/tmp/llama.cpp-build-$$"
        
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
        cd "$llama_build_dir"
        
        # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
        mkdir build
        cd build
        cmake .. \
            -DGGML_HIPBLAS=ON \
            -DAMDGPU_TARGETS=gfx1151 \
            -DCMAKE_BUILD_TYPE=Release
        
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
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 --ngl 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        
        # Clean up build directory
        cd /
        rm -rf "$llama_build_dir"
        
        success "llama.cpp installed successfully with ROCm support for gfx1151"
        info "llama-cli and llama-server are available in /usr/local/bin"
        info "Systemd service configured with flash attention (-fa 1) and no-mmap (--no-mmap) for optimal Strix Halo performance"
        info "To start llama-server: sudo systemctl enable --now llama-server"
    fi
    
    # Install ROCm and Python AI libraries only if llama.cpp backend is selected
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        # Install ROCm (if available)
        info "Installing ROCm for AMD GPU acceleration..."
        # ROCm packages may be available via OBS repositories
        zypper install -y rocm-opencl rocblas miopen-hip || warning "ROCm packages not available in default repositories. Consider adding AMD ROCm repository."
        
        # Install Python and AI libraries
        info "Installing Python AI libraries..."
        zypper install -y python3-pip python3-virtualenv
        
        local primary_user
        primary_user=$(get_real_user)
        if [[ "$primary_user" != "root" ]]; then
            sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
            sudo -u "$primary_user" pip3 install --user transformers accelerate
            
            # Install bitsandbytes for ROCm
            info "Installing bitsandbytes for ROCm (8-bit quantization)..."
            if ! sudo -u "$primary_user" pip3 install --user bitsandbytes; then
                warning "Standard bitsandbytes installation failed. Trying ROCm-specific wheel..."
                sudo -u "$primary_user" pip3 install --user --no-deps --force-reinstall \
                    'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl' \
                    || warning "ROCm bitsandbytes wheel installation failed."
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/text-generation-webui"
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
                    ensure_user_dirs "$primary_user"
                    local dst="/home/$primary_user/.local/share/gz302/frontends/ComfyUI"
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
                    setup_openwebui_with_uv "$primary_user" "opensuse"
                    ;;
                *)
                    warning "Unknown frontend: $frontend"
                    ;;
            esac
        done
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
