#!/bin/bash

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 4.0.0
#
# This module installs LLM backends for the ASUS ROG Flow Z13 (GZ302)
# Uses official installation methods - no custom builds
#
# Backends: Ollama, LM Studio, llama.cpp, vLLM
# Frontends: Open WebUI, SillyTavern, Text Generation WebUI, LibreChat
# Libraries: PyTorch, Transformers, bitsandbytes, etc.
#
# Hardware: AMD Radeon 8060S (gfx1151/RDNA 3.5 Strix Halo)
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
if [[ -f "${SCRIPT_DIR}/../gz302-lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/../gz302-lib/utils.sh"
elif [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    mkdir -p "$(dirname "${SCRIPT_DIR}/gz302-utils.sh")" || { echo "Error: Failed to create directory"; exit 1; }
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh" || { echo "Error: curl failed"; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -O "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download utils."
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-utils.sh"
        source "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: Failed to download gz302-utils.sh"
        exit 1
    fi
fi


# --- Configuration ---
LLM_VERSION="4.0.0"
OLLAMA_ENV_FILE="/etc/systemd/system/ollama.service.d/gz302.conf"
LMSTUDIO_APPIMAGE="${HOME}/Applications/LMStudio.AppImage"
VLLM_VENV="/opt/gz302-vllm"

# --- AMD Strix Halo GPU Configuration ---

configure_amd_gpu_env() {
    local env_file="/etc/profile.d/gz302-rocm.sh"
    
    info "Configuring AMD ROCm environment for Strix Halo (gfx1151)..."
    
    cat > "$env_file" << 'EOF'
# GZ302 ROCm Configuration for AMD Radeon 8060S (Strix Halo gfx1151)
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HIP_VISIBLE_DEVICES=0
export GPU_MAX_HW_QUEUES=8
export AMD_SERIALIZE_KERNEL=0
export AMD_SERIALIZE_COPY=0
EOF
    
    chmod 644 "$env_file"
    # shellcheck disable=SC1090
    source "$env_file"
    success "AMD ROCm environment configured"
}

# =============================================================================
# BACKEND INSTALLATIONS
# =============================================================================

install_ollama() {
    print_section "Installing Ollama"
    
    if command -v ollama &>/dev/null; then
        info "Ollama already installed: $(ollama --version 2>/dev/null || echo 'unknown')"
        return 0
    fi
    
    info "Running official Ollama install script..."
    curl -fsSL https://ollama.com/install.sh | sh
    
    info "Configuring Ollama for AMD Strix Halo GPU..."
    mkdir -p "$(dirname "$OLLAMA_ENV_FILE")"
    cat > "$OLLAMA_ENV_FILE" << 'EOF'
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GPU_MAX_HW_QUEUES=8"
Environment="OLLAMA_HOST=0.0.0.0"
EOF
    
    systemctl daemon-reload
    systemctl enable --now ollama
    
    success "Ollama installed and configured"
    info "API: http://localhost:11434"
}

install_lmstudio() {
    print_section "Installing LM Studio"
    
    if [[ -f "$LMSTUDIO_APPIMAGE" ]]; then
        info "LM Studio already installed at $LMSTUDIO_APPIMAGE"
        return 0
    fi
    
    info "Downloading LM Studio AppImage..."
    mkdir -p "$(dirname "$LMSTUDIO_APPIMAGE")"
    
    local download_url="https://installers.lmstudio.ai/linux/x64/LM-Studio-0.3.6-x86_64.AppImage"
    
    if ! curl -fsSL "$download_url" -o "$LMSTUDIO_APPIMAGE"; then
        warning "Could not download LM Studio automatically"
        info "Please download manually from: https://lmstudio.ai/download"
        return 1
    fi
    
    chmod +x "$LMSTUDIO_APPIMAGE"
    
    mkdir -p "${HOME}/.local/share/applications"
    cat > "${HOME}/.local/share/applications/lmstudio.desktop" << EOF
[Desktop Entry]
Name=LM Studio
Comment=Local LLM Application
Exec=${LMSTUDIO_APPIMAGE}
Icon=lmstudio
Type=Application
Categories=Development;Utility;
Terminal=false
EOF
    
    success "LM Studio installed"
}

install_llamacpp() {
    print_section "Installing llama.cpp"
    
    if command -v llama-cli &>/dev/null || command -v llama-server &>/dev/null; then
        info "llama.cpp already installed"
        return 0
    fi
    
    info "Fetching latest llama.cpp release..."
    
    local version
    version=$(curl -fsSL https://api.github.com/repos/ggerganov/llama.cpp/releases/latest | grep -oP '"tag_name": "\K[^"]+' || echo "b4467")
    
    local rocm_url="https://github.com/ggerganov/llama.cpp/releases/download/${version}/llama-${version}-bin-ubuntu-x64-rocm-6.2.zip"
    local fallback_url="https://github.com/ggerganov/llama.cpp/releases/download/${version}/llama-${version}-bin-ubuntu-x64.zip"
    
    local tmpdir
    tmpdir=$(mktemp -d)
    
    info "Downloading llama.cpp ${version}..."
    if curl -fsSL "$rocm_url" -o "${tmpdir}/llama.zip" 2>/dev/null; then
        info "Using ROCm-enabled build"
    elif curl -fsSL "$fallback_url" -o "${tmpdir}/llama.zip" 2>/dev/null; then
        warning "ROCm build not available, using CPU build"
    else
        error "Failed to download llama.cpp binaries"
        rm -rf "$tmpdir"
        return 1
    fi
    
    unzip -q "${tmpdir}/llama.zip" -d "${tmpdir}"
    find "${tmpdir}" -type f -executable -name "llama-*" -exec install -m 755 {} /usr/local/bin/ \;
    rm -rf "$tmpdir"
    
    success "llama.cpp installed"
}

install_vllm() {
    print_section "Installing vLLM"
    
    if [[ -d "$VLLM_VENV" ]] && "${VLLM_VENV}/bin/python" -c "import vllm" 2>/dev/null; then
        info "vLLM already installed in $VLLM_VENV"
        return 0
    fi
    
    local python_cmd="python3"
    if ! command -v "$python_cmd" &>/dev/null; then
        error "Python 3 not found"
        return 1
    fi
    
    info "Creating vLLM virtual environment..."
    "$python_cmd" -m venv "$VLLM_VENV"
    
    info "Installing vLLM..."
    "${VLLM_VENV}/bin/pip" install --upgrade pip
    "${VLLM_VENV}/bin/pip" install vllm
    
    cat > "${VLLM_VENV}/activate-vllm" << 'EOF'
#!/bin/bash
source /opt/gz302-vllm/bin/activate
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HIP_VISIBLE_DEVICES=0
echo "vLLM environment activated"
EOF
    chmod +x "${VLLM_VENV}/activate-vllm"
    
    success "vLLM installed"
    info "Activate: source ${VLLM_VENV}/activate-vllm"
}

# =============================================================================
# FRONTEND INSTALLATIONS
# =============================================================================

install_docker_if_needed() {
    if command -v docker &>/dev/null; then
        return 0
    fi
    
    info "Installing Docker..."
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)   pacman -S --noconfirm docker docker-compose ;;
        debian) apt-get update && apt-get install -y docker.io docker-compose ;;
        fedora) dnf install -y docker docker-compose ;;
        opensuse) zypper install -y docker docker-compose ;;
    esac
    
    systemctl enable --now docker
    usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    success "Docker installed"
}

install_openwebui() {
    print_section "Installing Open WebUI"
    
    install_docker_if_needed
    
    if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
        info "Open WebUI already running"
        return 0
    fi
    
    docker rm -f open-webui 2>/dev/null || true
    
    info "Deploying Open WebUI..."
    docker run -d \
        --name open-webui \
        --restart always \
        -p 3000:8080 \
        --add-host=host.docker.internal:host-gateway \
        -v open-webui:/app/backend/data \
        ghcr.io/open-webui/open-webui:main
    
    success "Open WebUI installed"
    info "Access: http://localhost:3000"
}

install_sillytavern() {
    print_section "Installing SillyTavern"
    
    install_docker_if_needed
    
    if docker ps --format '{{.Names}}' | grep -q "^sillytavern$"; then
        info "SillyTavern already running"
        return 0
    fi
    
    docker rm -f sillytavern 2>/dev/null || true
    
    info "Deploying SillyTavern..."
    docker run -d \
        --name sillytavern \
        --restart always \
        -p 8000:8000 \
        --add-host=host.docker.internal:host-gateway \
        -v sillytavern-config:/home/node/app/config \
        -v sillytavern-data:/home/node/app/data \
        ghcr.io/sillytavern/sillytavern:latest
    
    success "SillyTavern installed"
    info "Access: http://localhost:8000"
}

install_textgenwebui() {
    print_section "Installing Text Generation WebUI"
    
    local install_dir="/opt/text-generation-webui"
    
    if [[ -d "$install_dir" ]]; then
        info "Text Generation WebUI already installed at $install_dir"
        return 0
    fi
    
    info "Cloning Text Generation WebUI..."
    git clone https://github.com/oobabooga/text-generation-webui.git "$install_dir"
    
    cd "$install_dir"
    info "Running installer (this may take a while)..."
    
    # Use AMD ROCm option
    export GPU_CHOICE="B"  # AMD ROCm
    export CUDA_VERSION="N/A"
    bash start_linux.sh --install-only || true
    
    # Create launcher script
    cat > /usr/local/bin/textgen-webui << 'EOF'
#!/bin/bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HIP_VISIBLE_DEVICES=0
cd /opt/text-generation-webui
./start_linux.sh "$@"
EOF
    chmod +x /usr/local/bin/textgen-webui
    
    success "Text Generation WebUI installed"
    info "Launch: textgen-webui"
}

install_librechat() {
    print_section "Installing LibreChat"
    
    install_docker_if_needed
    
    local install_dir="/opt/librechat"
    
    if [[ -d "$install_dir" ]]; then
        info "LibreChat already installed at $install_dir"
        return 0
    fi
    
    info "Cloning LibreChat..."
    git clone https://github.com/danny-avila/LibreChat.git "$install_dir"
    
    cd "$install_dir"
    
    # Copy default env
    cp .env.example .env
    
    info "Starting LibreChat with Docker Compose..."
    docker compose up -d
    
    success "LibreChat installed"
    info "Access: http://localhost:3080"
}

# =============================================================================
# PYTHON AI LIBRARIES
# =============================================================================

install_python_ai_libs() {
    print_section "Installing Python AI Libraries"
    
    local venv_path="${HOME}/.gz302-ai"
    
    if [[ -d "$venv_path" ]]; then
        info "Python AI environment already exists at $venv_path"
        read -r -p "Reinstall? (y/N): " reinstall
        [[ ! "$reinstall" =~ ^[Yy] ]] && return 0
        rm -rf "$venv_path"
    fi
    
    info "Creating Python AI virtual environment..."
    python3 -m venv "$venv_path"
    
    info "Installing PyTorch with ROCm support..."
    "${venv_path}/bin/pip" install --upgrade pip
    "${venv_path}/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
    
    info "Installing AI/ML libraries..."
    "${venv_path}/bin/pip" install \
        transformers \
        accelerate \
        bitsandbytes \
        datasets \
        huggingface-hub \
        sentencepiece \
        safetensors \
        peft \
        trl \
        einops
    
    cat > "${venv_path}/activate-ai" << EOF
#!/bin/bash
source ${venv_path}/bin/activate
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HIP_VISIBLE_DEVICES=0
echo "Python AI environment activated"
EOF
    chmod +x "${venv_path}/activate-ai"
    
    success "Python AI libraries installed"
    info "Activate: source ${venv_path}/activate-ai"
}

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

ask_backends() {
    echo
    print_section "Step 1: LLM Backends"
    echo
    echo "Select backend(s) to install:"
    echo "  1) Ollama        - Easy model management (recommended)"
    echo "  2) LM Studio     - GUI application, user-friendly"
    echo "  3) llama.cpp     - Fast CLI inference"
    echo "  4) vLLM          - Production server, OpenAI-compatible"
    echo "  5) All backends"
    echo "  6) Skip"
    echo
    read -r -p "Choice (comma-separated, e.g., 1,2 or 6 to skip): " choice || choice="6"
    
    [[ "$choice" == "6" || -z "$choice" ]] && return
    
    IFS=',' read -ra choices <<< "$choice"
    for c in "${choices[@]}"; do
        c=$(echo "$c" | tr -d ' ')
        case "$c" in
            1) install_ollama ;;
            2) install_lmstudio ;;
            3) install_llamacpp ;;
            4) install_vllm ;;
            5)
                install_ollama
                install_lmstudio
                install_llamacpp
                install_vllm
                ;;
            6) return ;;
        esac
    done
}

ask_frontends() {
    echo
    print_section "Step 2: Web Frontends"
    echo
    echo "Select frontend(s) to install:"
    echo "  1) Open WebUI           - Clean Ollama frontend (recommended)"
    echo "  2) SillyTavern          - Character-focused chat"
    echo "  3) Text Generation WebUI - Full-featured, many backends"
    echo "  4) LibreChat            - ChatGPT-like interface"
    echo "  5) All frontends"
    echo "  6) Skip"
    echo
    read -r -p "Choice (comma-separated, e.g., 1,2 or 6 to skip): " choice || choice="6"
    
    [[ "$choice" == "6" || -z "$choice" ]] && return
    
    IFS=',' read -ra choices <<< "$choice"
    for c in "${choices[@]}"; do
        c=$(echo "$c" | tr -d ' ')
        case "$c" in
            1) install_openwebui ;;
            2) install_sillytavern ;;
            3) install_textgenwebui ;;
            4) install_librechat ;;
            5)
                install_openwebui
                install_sillytavern
                install_textgenwebui
                install_librechat
                ;;
            6) return ;;
        esac
    done
}

ask_libraries() {
    echo
    print_section "Step 3: Python AI Libraries"
    echo
    echo "Install Python AI development environment?"
    echo "  - PyTorch with ROCm GPU support"
    echo "  - Transformers, Accelerate, PEFT"
    echo "  - bitsandbytes for quantization"
    echo "  - HuggingFace Hub integration"
    echo
    read -r -p "Install Python AI libraries? (y/N): " choice || choice="n"
    
    if [[ "$choice" =~ ^[Yy] ]]; then
        install_python_ai_libs
    fi
}

show_summary() {
    echo
    print_box "Installation Complete"
    echo
    info "Installed Components:"
    
    # Backends
    command -v ollama &>/dev/null && echo "  ✓ Ollama: ollama run llama3.2"
    [[ -f "$LMSTUDIO_APPIMAGE" ]] && echo "  ✓ LM Studio: $LMSTUDIO_APPIMAGE"
    command -v llama-cli &>/dev/null && echo "  ✓ llama.cpp: llama-cli / llama-server"
    [[ -d "$VLLM_VENV" ]] && echo "  ✓ vLLM: source ${VLLM_VENV}/activate-vllm"
    
    # Frontends
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$" && echo "  ✓ Open WebUI: http://localhost:3000"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^sillytavern$" && echo "  ✓ SillyTavern: http://localhost:8000"
    [[ -d "/opt/text-generation-webui" ]] && echo "  ✓ Text Gen WebUI: textgen-webui"
    [[ -d "/opt/librechat" ]] && echo "  ✓ LibreChat: http://localhost:3080"
    
    # Libraries
    [[ -d "${HOME}/.gz302-ai" ]] && echo "  ✓ Python AI: source ~/.gz302-ai/activate-ai"
    
    echo
    info "GPU configured for AMD Radeon 8060S (Strix Halo)"
    echo
}

main() {
    # Require root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    print_box "GZ302 LLM/AI Module v${LLM_VERSION}"
    echo
    
    # Configure GPU environment first
    configure_amd_gpu_env
    
    # Sequential flow
    ask_backends
    ask_frontends
    ask_libraries
    
    # Summary
    show_summary
}

main "$@"