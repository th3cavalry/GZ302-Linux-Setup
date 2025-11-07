#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 0.2.1
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Ollama, ROCm, PyTorch, Transformers
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
    systemctl enable --now ollama
    
    # Install ROCm for AMD GPU acceleration
    info "Installing ROCm for AMD GPU acceleration..."
    pacman -S --noconfirm --needed rocm-opencl-runtime rocm-hip-runtime
    
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
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install ROCm (if available)
    info "Installing ROCm for AMD GPU acceleration..."
    apt install -y rocm-opencl-runtime || warning "ROCm not available in repositories"
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    apt install -y python3-pip python3-venv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_fedora_llm_software() {
    info "Installing LLM/AI software for Fedora-based system..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    dnf install -y python3-pip python3-virtualenv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
    fi
    
    success "LLM/AI software installation completed"
}

install_opensuse_llm_software() {
    info "Installing LLM/AI software for OpenSUSE..."
    
    # Install Ollama
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    systemctl enable --now ollama
    
    # Install Python and AI libraries
    info "Installing Python AI libraries..."
    zypper install -y python3-pip python3-virtualenv
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        sudo -u "$primary_user" pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        sudo -u "$primary_user" pip3 install --user transformers accelerate
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
