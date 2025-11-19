#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 2.0.1
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: llama.cpp, ROCm, PyTorch, MIOpen, bitsandbytes, Transformers
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

# Ask user if they want to add ROCm repository
ask_add_rocm_repo() {
    local distro="$1"
    
    # Skip prompt if not running in a TTY
    if [[ ! -t 0 ]]; then
        info "Non-interactive mode: skipping ROCm repository prompt"
        return 1
    fi
    
    echo
    echo "ROCm packages may not be available in default repositories."
    echo "Would you like to add the official AMD ROCm repository?"
    echo "This will enable better GPU acceleration support for LLM inference."
    read -r -p "Add ROCm repository? [Y/n]: " response
    
    response="${response,,}" # to lowercase
    if [[ -z "$response" || "$response" == "y" || "$response" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Add ROCm repository for Arch Linux
add_rocm_repo_arch() {
    info "ROCm packages are available in Arch official repositories"
    info "No additional repository configuration needed"
}

# Add ROCm repository for Debian/Ubuntu
add_rocm_repo_debian() {
    info "Adding AMD ROCm repository for Debian/Ubuntu..."
    
    # Add AMD GPG key
    mkdir -p /etc/apt/keyrings
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor > /etc/apt/keyrings/rocm.gpg
    
    # Detect Ubuntu/Debian
    local os_name
    os_name=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    
    # Add ROCm repository
    if [[ "$os_name" == "ubuntu" ]]; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.2 jammy main" > /etc/apt/sources.list.d/rocm.list
    elif [[ "$os_name" == "debian" ]]; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.2 ubuntu main" > /etc/apt/sources.list.d/rocm.list
    fi
    
    apt update
    success "AMD ROCm repository added successfully"
}

# Add ROCm repository for Fedora
add_rocm_repo_fedora() {
    info "Adding AMD ROCm repository for Fedora..."
    
    cat > /etc/yum.repos.d/rocm.repo <<'EOF'
[ROCm]
name=ROCm
baseurl=https://repo.radeon.com/rocm/rhel9/6.2/main
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF
    
    dnf makecache
    success "AMD ROCm repository added successfully"
}

# Add ROCm repository for OpenSUSE
add_rocm_repo_opensuse() {
    info "Adding AMD ROCm repository for OpenSUSE..."
    
    zypper addrepo -f https://repo.radeon.com/rocm/zyp/6.2/main rocm
    zypper --gpg-auto-import-keys refresh
    success "AMD ROCm repository added successfully"
}

# --- LLM/AI Software Installation Functions ---
install_arch_llm_software() {
    info "Installing LLM/AI software for Arch-based system..."
    
    # Install llama.cpp with ROCm support
    info "Installing llama.cpp with ROCm support for Strix Halo..."
    
    # Install build dependencies
    pacman -S --noconfirm --needed git cmake make gcc pkgconf
    
    # Install ROCm for AMD GPU acceleration (required for llama.cpp)
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Check if ROCm packages are available and offer to add repo if needed
    if ! pacman -Si rocm-opencl-runtime >/dev/null 2>&1; then
        warning "ROCm packages not found in default repositories"
        if ask_add_rocm_repo "arch"; then
            add_rocm_repo_arch
        else
            warning "Proceeding without ROCm repository. GPU acceleration may not be available."
        fi
    fi
    
    # Always attempt to install ROCm packages
    pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime rocblas miopen-hip hip-runtime-amd rocm-smi-lib || \
        warning "Some ROCm packages failed to install. llama.cpp will build with limited GPU support."
    
    # Build and install llama.cpp with ROCm support
    info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
    local llama_build_dir="/tmp/llama.cpp-build-$$"
    local llama_install_dir="/opt/llama.cpp"
    
    git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
    cd "$llama_build_dir"
    
    # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
    mkdir build
    cd build
    cmake .. \
        -DGGML_HIPBLAS=ON \
        -DAMDGPU_TARGETS=gfx1151 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$llama_install_dir"
    
    local nproc_count
    nproc_count="$(nproc)"
    cmake --build . --config Release -j"${nproc_count}"
    
    # Install llama.cpp binaries
    mkdir -p "$llama_install_dir"
    cmake --install .
    
    # Create symbolic links in /usr/local/bin for easy access
    ln -sf "$llama_install_dir/bin/llama-cli" /usr/local/bin/llama-cli
    ln -sf "$llama_install_dir/bin/llama-server" /usr/local/bin/llama-server
    ln -sf "$llama_install_dir/bin/llama-quantize" /usr/local/bin/llama-quantize
    
    # Create systemd service for llama-server
    cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # Clean up build directory
    cd /
    rm -rf "$llama_build_dir"
    
    success "llama.cpp installed successfully with ROCm support for gfx1151"
    info "llama-cli and llama-server are available in /usr/local/bin"
    info "To start llama-server: sudo systemctl enable --now llama-server"
    
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
        # Offer optional frontends (LocalAI, text-generation-webui, ComfyUI, Flowise, SwarmUI, InvokeAI)
        install_frontends_interactive "$primary_user"

    success "LLM/AI software installation completed"
}

    # --- Frontend installers (opt-in, lightweight/idempotent) ---
    ensure_user_dirs() {
        local user="$1"
        sudo -u "$user" mkdir -p "/home/$user/.local/share/gz302/frontends" || true
    }

    install_localai_docker() {
        local user="$1"
        info "(frontend) Setting up LocalAI (docker) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/localai"
                mkdir -p "$dst" || true
        cat > "$dst/docker-compose.yml" <<'EOF'
version: '3.8'
services:
    localai:
        image: localai/localai:latest
        container_name: localai
        ports:
            - "8080:8080"
        restart: unless-stopped
        volumes:
            - ./models:/app/models
EOF

        if command -v docker >/dev/null 2>&1; then
            info "Starting LocalAI (docker) using docker-compose"
            docker compose -f "$dst/docker-compose.yml" up -d || docker-compose -f "$dst/docker-compose.yml" up -d || warning "Failed to start LocalAI via docker-compose"
            info "LocalAI docker compose created at $dst/docker-compose.yml (port 8080)"
        else
            warning "Docker not found — created docker-compose at $dst/docker-compose.yml. Install docker and run: docker compose -f $dst/docker-compose.yml up -d"
        fi
    }

    install_textgen_webui() {
        local user="$1"
        info "(frontend) Installing text-generation-webui (clone only) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/text-generation-webui"
        if [[ -d "$dst/.git" ]]; then
            info "text-generation-webui already cloned at $dst"
            return
        fi
        sudo -u "$user" git clone https://github.com/oobabooga/text-generation-webui "$dst" || warning "Failed to clone text-generation-webui"
        info "Cloned text-generation-webui to $dst. To finish install: cd $dst && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt"
    }

    install_comfyui() {
        local user="$1"
        info "(frontend) Installing ComfyUI (clone only) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/ComfyUI"
        if [[ -d "$dst/.git" ]]; then
            info "ComfyUI already cloned at $dst"
            return
        fi
        sudo -u "$user" git clone https://github.com/comfyanonymous/ComfyUI "$dst" || warning "Failed to clone ComfyUI"
        info "Cloned ComfyUI to $dst. See $dst/README.md for install instructions (venv or comfy-cli)."
    }

    install_flowise() {
        local user="$1"
        info "(frontend) Installing Flowise (docker recommended) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/flowise"
        mkdir -p "$dst" || true
        # Provide docker-compose pointer
    cat > "$dst/README.txt" <<EOF
Flowise installer placeholder. Recommended: use the project's docker-compose (see https://github.com/FlowiseAI/Flowise).
To run with docker-compose: clone the project and run 'docker compose up -d' or use the provided docker folder in upstream repo.
EOF
        info "Created helper README at $dst/README.txt — prefer Docker install from upstream."
    }

    install_swarmui() {
        local user="$1"
        info "(frontend) Installing SwarmUI (clone only) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/SwarmUI"
        if [[ -d "$dst/.git" ]]; then
            info "SwarmUI already cloned at $dst"
            return
        fi
        sudo -u "$user" git clone https://github.com/mcmonkeyprojects/SwarmUI "$dst" || warning "Failed to clone SwarmUI"
        info "Cloned SwarmUI to $dst. Run $dst/launch-linux.sh to install and launch."
    }

    install_invokeai() {
        local user="$1"
        info "(frontend) Installing InvokeAI (clone only) for $user"
        ensure_user_dirs "$user"
        local dst="/home/$user/.local/share/gz302/frontends/InvokeAI"
        if [[ -d "$dst/.git" ]]; then
            info "InvokeAI already cloned at $dst"
            return
        fi
        sudo -u "$user" git clone https://github.com/invoke-ai/InvokeAI "$dst" || warning "Failed to clone InvokeAI"
        info "Cloned InvokeAI to $dst. See $dst/README.md for launcher and install instructions."
    }

    install_frontends_interactive() {
        local user="$1"
        # interactive only when running in a TTY
        if [[ ! -t 0 ]]; then
            info "Skipping interactive frontend installs (no TTY)."
            return
        fi
        echo
        echo "Optional frontends can be installed now. Choose one or more by number or name (comma-separated), or enter 'all' to install all, or press Enter to skip:" 
        echo "  1) localai        - LocalAI (docker compose)"
        echo "  2) textgen        - text-generation-webui (clone + instructions)"
        echo "  3) comfyui        - ComfyUI (clone + instructions)"
        echo "  4) flowise        - Flowise (docker recommended; README placeholder will be created)"
        echo "  5) swarmui        - SwarmUI (clone + launch script)"
        echo "  6) invokeai       - InvokeAI (clone + instructions)"
        read -r -p "Install (e.g. '1,3' or 'localai,comfyui' or 'all')? [Enter=none]: " choice

        # normalize and parse choice
        choice="${choice,,}"    # lowercase
        choice="${choice// /}"  # remove spaces
        if [[ -z "$choice" || "$choice" == "n" || "$choice" == "none" ]]; then
            info "Skipping frontend installs."
            return
        fi
        if [[ "$choice" == "all" || "$choice" == "a" ]]; then
            choices=(localai textgen comfyui flowise swarmui invokeai)
        else
            IFS=',' read -r -a raw <<< "$choice"
            choices=()
            for token in "${raw[@]}"; do
                case "$token" in
                    1|localai|local)
                        choices+=(localai)
                        ;;
                    2|textgen|text-generation-webui|text-generation|text)
                        choices+=(textgen)
                        ;;
                    3|comfyui|comfy)
                        choices+=(comfyui)
                        ;;
                    4|flowise|flow)
                        choices+=(flowise)
                        ;;
                    5|swarmui|swarm)
                        choices+=(swarmui)
                        ;;
                    6|invokeai|invoke)
                        choices+=(invokeai)
                        ;;
                    *)
                        warning "Unknown frontend token: $token (skipping)"
                        ;;
                esac
            done
        fi

        # Deduplicate and run selected installers
        declare -A seen
        for f in "${choices[@]:-}"; do
            if [[ -n "${seen[$f]:-}" ]]; then
                continue
            fi
            seen[$f]=1
            case "$f" in
                localai)
                    install_localai_docker "$user"
                    ;;
                textgen)
                    install_textgen_webui "$user"
                    ;;
                comfyui)
                    install_comfyui "$user"
                    ;;
                flowise)
                    install_flowise "$user"
                    ;;
                swarmui)
                    install_swarmui "$user"
                    ;;
                invokeai)
                    install_invokeai "$user"
                    ;;
                *)
                    warning "Unhandled frontend choice: $f"
                    ;;
            esac
        done
    }

install_debian_llm_software() {
    info "Installing LLM/AI software for Debian-based system..."
    
    # Install llama.cpp with ROCm support
    info "Installing llama.cpp with ROCm support for Strix Halo..."
    
    # Install build dependencies
    apt update
    apt install -y git cmake make g++ pkg-config
    
    # Install ROCm for AMD GPU acceleration (required for llama.cpp)
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Check if ROCm packages are available and offer to add repo if needed
    if ! apt-cache show rocm-opencl-runtime >/dev/null 2>&1; then
        warning "ROCm packages not found in default repositories"
        if ask_add_rocm_repo "debian"; then
            add_rocm_repo_debian
        else
            warning "Proceeding without ROCm repository. GPU acceleration may not be available."
        fi
    fi
    
    # Always attempt to install ROCm packages
    apt install -y rocm-opencl-runtime rocblas miopen-hip hip-runtime-amd rocm-smi-lib || \
        warning "Some ROCm packages failed to install. llama.cpp will build with limited GPU support."
    
    # Build and install llama.cpp with ROCm support
    info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
    local llama_build_dir="/tmp/llama.cpp-build-$$"
    local llama_install_dir="/opt/llama.cpp"
    
    git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
    cd "$llama_build_dir"
    
    # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
    mkdir build
    cd build
    cmake .. \
        -DGGML_HIPBLAS=ON \
        -DAMDGPU_TARGETS=gfx1151 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$llama_install_dir"
    
    local nproc_count; nproc_count="$(nproc)"; cmake --build . --config Release -j"${nproc_count}"
    
    # Install llama.cpp binaries
    mkdir -p "$llama_install_dir"
    cmake --install .
    
    # Create symbolic links in /usr/local/bin for easy access
    ln -sf "$llama_install_dir/bin/llama-cli" /usr/local/bin/llama-cli
    ln -sf "$llama_install_dir/bin/llama-server" /usr/local/bin/llama-server
    ln -sf "$llama_install_dir/bin/llama-quantize" /usr/local/bin/llama-quantize
    
    # Create systemd service for llama-server
    cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080
Restart=on-failure
RestartSec=5
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # Clean up build directory
    cd /
    rm -rf "$llama_build_dir"
    
    success "llama.cpp installed successfully with ROCm support for gfx1151"
    info "llama-cli and llama-server are available in /usr/local/bin"
    info "To start llama-server: sudo systemctl enable --now llama-server"
    
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
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Install llama.cpp with ROCm support
    info "Installing llama.cpp with ROCm support for Strix Halo..."
    
    # Install build dependencies
    dnf install -y git cmake make gcc-c++ pkgconfig
    
    # Install ROCm for AMD GPU acceleration (required for llama.cpp)
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Check if ROCm packages are available and offer to add repo if needed
    if ! dnf list rocm-opencl >/dev/null 2>&1; then
        warning "ROCm packages not found in default repositories"
        if ask_add_rocm_repo "fedora"; then
            add_rocm_repo_fedora
        else
            warning "Proceeding without ROCm repository. GPU acceleration may not be available."
        fi
    fi
    
    # Always attempt to install ROCm packages
    dnf install -y rocm-opencl rocblas miopen-hip hip-runtime-amd rocm-smi-lib || \
        warning "Some ROCm packages failed to install. llama.cpp will build with limited GPU support."
    
    # Build and install llama.cpp with ROCm support
    info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
    local llama_build_dir="/tmp/llama.cpp-build-$$"
    local llama_install_dir="/opt/llama.cpp"
    
    git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
    cd "$llama_build_dir"
    
    # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
    mkdir build
    cd build
    cmake .. \
        -DGGML_HIPBLAS=ON \
        -DAMDGPU_TARGETS=gfx1151 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$llama_install_dir"
    
    local nproc_count; nproc_count="$(nproc)"; cmake --build . --config Release -j"${nproc_count}"
    
    # Install llama.cpp binaries
    mkdir -p "$llama_install_dir"
    cmake --install .
    
    # Create symbolic links in /usr/local/bin for easy access
    ln -sf "$llama_install_dir/bin/llama-cli" /usr/local/bin/llama-cli
    ln -sf "$llama_install_dir/bin/llama-server" /usr/local/bin/llama-server
    ln -sf "$llama_install_dir/bin/llama-quantize" /usr/local/bin/llama-quantize
    
    # Create systemd service for llama-server
    cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # Clean up build directory
    cd /
    rm -rf "$llama_build_dir"
    
    success "llama.cpp installed successfully with ROCm support for gfx1151"
    info "llama-cli and llama-server are available in /usr/local/bin"
    info "To start llama-server: sudo systemctl enable --now llama-server"
    
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
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Install llama.cpp with ROCm support
    info "Installing llama.cpp with ROCm support for Strix Halo..."
    
    # Install build dependencies
    zypper install -y git cmake make gcc-c++ pkg-config
    
    # Install ROCm for AMD GPU acceleration (required for llama.cpp)
    info "Installing ROCm for AMD GPU acceleration..."
    
    # Check if ROCm packages are available and offer to add repo if needed
    if ! zypper search -i rocm-opencl >/dev/null 2>&1; then
        warning "ROCm packages not found in default repositories"
        if ask_add_rocm_repo "opensuse"; then
            add_rocm_repo_opensuse
        else
            warning "Proceeding without ROCm repository. GPU acceleration may not be available."
        fi
    fi
    
    # Always attempt to install ROCm packages
    zypper install -y rocm-opencl rocblas miopen-hip hip-runtime-amd rocm-smi-lib || \
        warning "Some ROCm packages failed to install. llama.cpp will build with limited GPU support."
    
    # Build and install llama.cpp with ROCm support
    info "Building llama.cpp with ROCm/HIP support for gfx1151 (Radeon 8060S)..."
    local llama_build_dir="/tmp/llama.cpp-build-$$"
    local llama_install_dir="/opt/llama.cpp"
    
    git clone https://github.com/ggerganov/llama.cpp.git "$llama_build_dir"
    cd "$llama_build_dir"
    
    # Build with ROCm support targeting gfx1151 (Strix Halo/Radeon 8060S)
    mkdir build
    cd build
    cmake .. \
        -DGGML_HIPBLAS=ON \
        -DAMDGPU_TARGETS=gfx1151 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$llama_install_dir"
    
    local nproc_count; nproc_count="$(nproc)"; cmake --build . --config Release -j"${nproc_count}"
    
    # Install llama.cpp binaries
    mkdir -p "$llama_install_dir"
    cmake --install .
    
    # Create symbolic links in /usr/local/bin for easy access
    ln -sf "$llama_install_dir/bin/llama-cli" /usr/local/bin/llama-cli
    ln -sf "$llama_install_dir/bin/llama-server" /usr/local/bin/llama-server
    ln -sf "$llama_install_dir/bin/llama-quantize" /usr/local/bin/llama-quantize
    
    # Create systemd service for llama-server
    cat > /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # Clean up build directory
    cd /
    rm -rf "$llama_build_dir"
    
    success "llama.cpp installed successfully with ROCm support for gfx1151"
    info "llama-cli and llama-server are available in /usr/local/bin"
    info "To start llama-server: sudo systemctl enable --now llama-server"
    
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
