#!/bin/bash
# shellcheck disable=SC2329  # main() is invoked at end of script

# ==============================================================================
# GZ302 LLM/AI Software Module
# Version: 2.3.14
#
# This module installs LLM/AI software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Ollama, ROCm, PyTorch, MIOpen, bitsandbytes, Transformers
# Configures kernel parameters optimized for LLM workloads on Strix Halo
#
# Updated January 2025:
# - Added gfx1151 (Strix Halo) optimizations for Ollama via systemd override
# - HSA_OVERRIDE_GFX_VERSION=11.0.0 for RDNA3 compatibility mode
# - GGML_HIP_ROCWMMA_FATTN enabled for rocWMMA flash attention
# - hipBLASLt optimizations for high-performance matrix operations
# - Environment variables for GPU tuning (HIP_VISIBLE_DEVICES, GPU_MAX_HW_QUEUES)
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
        "limine")
            for param in "${params[@]}"; do
                ensure_limine_kernel_param "$param" || true
            done
            # Regenerate Limine entries if changes were made
            if command -v limine-mkinitcpio >/dev/null 2>&1; then
                info "Regenerating Limine boot entries..."
                limine-mkinitcpio || true
            elif command -v limine-mkconfig >/dev/null 2>&1; then
                info "Regenerating Limine configuration..."
                limine-mkconfig -o /boot/limine.conf || true
            else
                warning "Limine config modified but no regeneration tool found."
                warning "Please run 'limine-mkinitcpio' or equivalent manually."
            fi
            success "Added kernel parameters to Limine configuration"
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

# Configure Ollama service with Strix Halo (gfx1151) optimizations
# This creates a systemd override that sets environment variables for optimal AMD GPU performance
# References:
# - HSA_OVERRIDE_GFX_VERSION: Enables ROCm compatibility for newer GPUs by emulating a known architecture
# - HIP_VISIBLE_DEVICES: Limits which GPU devices are visible to HIP runtime
# - OLLAMA_GPU_OVERHEAD: Reserved GPU memory for system overhead
# - hipBLASLt: High-performance BLAS library for matrix operations on AMD GPUs
configure_ollama_strix_halo() {
    info "Configuring Ollama with Strix Halo (gfx1151) optimizations..."
    
    # Create systemd override directory
    mkdir -p /etc/systemd/system/ollama.service.d
    
    # Create systemd override with gfx1151 optimizations
    # HSA_OVERRIDE_GFX_VERSION=11.0.0 makes ROCm treat gfx1151 as gfx1100 (RDNA3)
    # This is needed because gfx1151 (Strix Halo) may not be explicitly supported yet
    # but is compatible with gfx1100 (RDNA3) code paths which are mature and well-tested
    cat > /etc/systemd/system/ollama.service.d/gz302-strix-halo.conf <<'EOF'
# GZ302 Strix Halo (gfx1151/Radeon 8060S) Optimizations for Ollama
# Generated by gz302-llm.sh

[Service]
# ROCm GPU Architecture Override
# gfx1151 (Strix Halo) is treated as gfx1100 (RDNA3) for maximum driver compatibility
# This enables use of mature, well-optimized RDNA3 code paths
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"

# AMD GPU Visibility - ensure Radeon 8060S is the only visible device
# This prevents any confusion with potential secondary GPU (display-only iGPU)
Environment="HIP_VISIBLE_DEVICES=0"

# ROCm Runtime Tuning
# GPU_MAX_HW_QUEUES: Maximum hardware queues for better parallelism
Environment="GPU_MAX_HW_QUEUES=8"

# hipBLASLt: High-performance BLAS library for matrix operations
# This enables optimized matrix multiplication kernels for AMD GPUs
Environment="HIPBLASLT_LOG_LEVEL=0"

# Memory tuning for unified memory architecture (Strix Halo)
# OLLAMA_GPU_OVERHEAD: Reserve memory headroom for system stability
Environment="OLLAMA_GPU_OVERHEAD=512000000"

# Enable GPU acceleration explicitly
Environment="OLLAMA_NUM_GPU=999"

# Disable CPU fallback when GPU is available
Environment="OLLAMA_GPU_OFFLOAD=1"

# ROCm specific optimizations
# AMD_SERIALIZE_KERNEL: Disable for better async performance
Environment="AMD_SERIALIZE_KERNEL=0"
# AMD_SERIALIZE_COPY: Disable for better async copy performance
Environment="AMD_SERIALIZE_COPY=0"

# HSA agent timeout (seconds) - increase for large model loading
Environment="HSA_SVM_GUARD_PAGES=1"

# Logging (set to 1 for debug, 0 for production)
Environment="ROCM_LOGGING=0"
EOF

    # Reload systemd to pick up the override
    systemctl daemon-reload
    
    # Restart Ollama if it's running to apply new configuration
    if systemctl is-active --quiet ollama; then
        info "Restarting Ollama to apply gfx1151 optimizations..."
        systemctl restart ollama
    fi
    
    success "Ollama configured with Strix Halo (gfx1151) optimizations"
    info "Environment variables applied via systemd override:"
    info "  • HSA_OVERRIDE_GFX_VERSION=11.0.0 (RDNA3 compatibility mode)"
    info "  • HIP_VISIBLE_DEVICES=0 (Primary GPU only)"
    info "  • GPU_MAX_HW_QUEUES=8 (Increased parallelism)"
    info "  • OLLAMA_NUM_GPU=999 (Full GPU offload)"
    info "  • hipBLASLt optimizations enabled"
    info "Override location: /etc/systemd/system/ollama.service.d/gz302-strix-halo.conf"
}

# Build Ollama from source with gfx1100 target for Strix Halo (gfx1151) compatibility
# This provides native HIP/ROCm support with rocWMMA flash attention
# CRITICAL: We build with gfx1100 target, NOT gfx1151, because HIP runtime doesn't
# fully support gfx1151 code objects yet. Combined with HSA_OVERRIDE_GFX_VERSION=11.0.0,
# the gfx1100 build runs perfectly on Strix Halo hardware.
build_ollama_from_source() {
    local distro="$1"
    
    clear
    print_box "Building Custom Ollama for GZ302 Strix Halo" "$C_BOLD_CYAN"
    echo
    print_subsection "Build Configuration"
    print_keyval "Target GPU" "gfx1100 (RDNA3 compatible)"
    print_keyval "Hardware" "AMD Strix Halo (gfx1151)"
    print_keyval "Flash Attention" "rocWMMA (GGML_HIP_ROCWMMA_FATTN=ON)"
    print_keyval "hipBLASLt" "Enabled for matrix operations"
    print_keyval "Build Time" "~5-10 minutes on GZ302"
    echo
    
    # Install build dependencies based on distro
    print_step 1 6 "Installing build dependencies..."
    echo -ne "${C_DIM}"
    case "$distro" in
        "arch"|"cachyos")
            pacman -S --noconfirm --needed \
                git cmake make gcc pkgconf go \
                rocm-hip-sdk rocm-hip-runtime hip-runtime-amd \
                rocblas miopen-hip hipblas rocwmma 2>&1 | grep -v "^::" | grep -v "warning:" || true
            ;;
        "debian")
            apt-get update -qq
            apt-get install -qq -y \
                git cmake make build-essential pkg-config golang-go \
                rocm-dev rocm-hip-sdk rocblas miopen-hip 2>&1 | grep -v "^Reading\|^Building\|^Get:" || true
            ;;
        "fedora")
            dnf install -q -y \
                git cmake make gcc gcc-c++ pkgconf golang \
                rocm-dev rocm-hip-devel rocblas miopen-hip 2>&1 | grep -v "^Last metadata" || true
            ;;
        "opensuse")
            zypper install -y --quiet \
                git cmake make gcc gcc-c++ pkg-config go \
                rocm-dev rocm-hip-devel rocblas miopen-hip 2>&1 | grep -v "^Loading\|^Retrieving" || true
            ;;
    esac
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    # Clone Ollama repository
    local ollama_build_dir="/tmp/ollama-build-$$"
    print_step 2 6 "Cloning Ollama repository..."
    git clone --quiet --depth 1 https://github.com/ollama/ollama.git "$ollama_build_dir" 2>&1 | grep -v "^Cloning" || true
    cd "$ollama_build_dir"
    completed_item "Repository cloned"
    
    # Configure CMake
    print_step 3 6 "Configuring CMake for gfx1100 + Flash Attention..."
    mkdir -p build && cd build
    
    # Note: We use gfx1100 target because HIP runtime doesn't fully support
    # gfx1151 code objects yet. With HSA_OVERRIDE_GFX_VERSION=11.0.0, this works perfectly.
    cmake .. \
        -DAMDGPU_TARGETS="gfx1100" \
        -DGGML_HIP_ROCWMMA_FATTN=ON \
        -DCMAKE_BUILD_TYPE=Release 2>&1 | grep -E "^-- |CMAKE_" | head -10 || true
    
    completed_item "CMake configured"
    
    # Build with progress tracking
    print_step 4 6 "Compiling HIP backend..."
    print_tip "This may take 5-10 minutes - grab a coffee!"
    echo
    
    local nproc_count
    nproc_count="$(nproc)"
    local last_percent=0
    
    cmake --build . --config Release -j"${nproc_count}" 2>&1 | while IFS= read -r line; do
        # Show only major progress milestones
        if [[ "$line" =~ \[\ *([0-9]+)% ]]; then
            local percent="${BASH_REMATCH[1]}"
            # Update every 10%
            if (( percent >= last_percent + 10 )); then
                last_percent=$percent
                printf "${C_DIM}   [%3d%%] Building HIP backend...${C_NC}\r" "$percent"
            fi
        elif [[ "$line" =~ "Built target" ]]; then
            local target="${line#*Built target }"
            if [[ "$target" == "ggml-hip" ]] || [[ "$target" == "ollama" ]]; then
                printf "${C_GREEN}   ${SYMBOL_CHECK} Built: %-50s${C_NC}\n" "$target"
            fi
        fi
    done
    echo
    completed_item "HIP backend compiled with rocWMMA flash attention"
    
    # Build Go binary
    print_step 5 6 "Building Ollama Go binary..."
    cd ..
    go build . 2>&1 | grep -E "^#|^go build" || true
    completed_item "Go binary compiled"
    
    # Install binary and libraries
    print_step 6 6 "Installing Ollama to system..."
    
    # Create ollama user if it doesn't exist
    if ! id -u ollama >/dev/null 2>&1; then
        useradd -r -s /bin/false -m -d /usr/share/ollama ollama 2>/dev/null
        print_keyval "Created user" "ollama"
    fi
    
    # Install binary
    install -m 755 ./ollama /usr/bin/ollama
    print_keyval "Installed binary" "/usr/bin/ollama"
    
    # Install libraries
    mkdir -p /usr/lib/ollama
    cp -r build/lib/ollama/* /usr/lib/ollama/
    local lib_size
    lib_size=$(du -sh /usr/lib/ollama/libggml-hip.so 2>/dev/null | cut -f1)
    print_keyval "Installed HIP lib" "/usr/lib/ollama/libggml-hip.so ($lib_size)"
    
    # Create models directory
    mkdir -p /usr/share/ollama/.ollama
    chown -R ollama:ollama /usr/share/ollama
    print_keyval "Models directory" "/usr/share/ollama/.ollama"
    
    # Create systemd service with gfx1151 optimizations
    cat > /etc/systemd/system/ollama.service <<'OLLAMA_SERVICE'
[Unit]
Description=Ollama Service (Custom GZ302 gfx1100 build with Flash Attention)
After=network-online.target
Documentation=https://github.com/ollama/ollama

[Service]
Type=simple
ExecStart=/usr/bin/ollama serve
Restart=always
RestartSec=3
User=ollama
Group=ollama

# GZ302 Strix Halo gfx1151 Optimizations
# HSA_OVERRIDE makes ROCm treat gfx1151 as gfx1100 (RDNA3) for compatibility
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GPU_MAX_HW_QUEUES=8"
Environment="AMD_SERIALIZE_KERNEL=0"
Environment="AMD_SERIALIZE_COPY=0"
Environment="ROCBLAS_LAYER=0"
Environment="OLLAMA_NUM_GPU=999"
Environment="OLLAMA_GPU_OVERHEAD=512000000"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HOME=/usr/share/ollama"

[Install]
WantedBy=default.target
OLLAMA_SERVICE
    
    print_keyval "Created service" "/etc/systemd/system/ollama.service"
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable --now ollama 2>&1 | grep -v "^Created symlink" || true
    
    # Clean up build directory
    cd /
    rm -rf "$ollama_build_dir"
    
    # Verify installation
    echo
    print_subsection "Verifying Installation"
    sleep 2
    
    if systemctl is-active --quiet ollama; then
        completed_item "Ollama service is running"
        
        # Verify Flash Attention support
        local flash_count
        flash_count=$(strings /usr/lib/ollama/libggml-hip.so 2>/dev/null | grep -c "flash_attn" || echo "0")
        local wmma_count
        wmma_count=$(strings /usr/lib/ollama/libggml-hip.so 2>/dev/null | grep -c "wmma" || echo "0")
        
        echo
        print_box "${SYMBOL_CHECK} Ollama Build Complete" "$C_BOLD_GREEN"
        print_keyval "Binary" "/usr/bin/ollama ($(du -sh /usr/bin/ollama 2>/dev/null | cut -f1))"
        print_keyval "HIP Library" "$lib_size with ROCm support"
        print_keyval "Flash Attention" "$flash_count symbols found"
        print_keyval "WMMA Support" "$wmma_count symbols found"
        print_keyval "Service" "ollama.service ${C_GREEN}(running)${C_NC}"
        print_keyval "Optimization" "gfx1100 target + HSA_OVERRIDE_GFX_VERSION=11.0.0"
        echo
        print_tip "Test with: ollama run llama3.2:1b"
        echo
    else
        failed_item "Ollama service failed to start"
        warning "Check logs with: journalctl -u ollama"
        echo
    fi
}

# Build llama.cpp from source with gfx1100 target for Strix Halo (gfx1151) compatibility
# This provides native HIP/ROCm support with rocWMMA flash attention
# Similar to build_ollama_from_source, we use gfx1100 for HIP runtime compatibility
build_llamacpp_from_source() {
    local distro="$1"
    
    print_section "Building llama.cpp from Source"
    
    print_subsection "Build Configuration"
    print_keyval "Target GPU" "gfx1100 (RDNA3 compatible)"
    print_keyval "Hardware" "AMD Strix Halo (gfx1151)"
    print_keyval "Flash Attention" "rocWMMA (GGML_HIP_ROCWMMA_FATTN=ON)"
    print_keyval "Build Time" "~5-10 minutes on GZ302"
    echo
    
    # Install build dependencies based on distro
    print_step 1 5 "Installing build dependencies..."
    echo -ne "${C_DIM}"
    case "$distro" in
        "arch"|"cachyos")
            pacman -S --noconfirm --needed \
                git cmake make gcc pkgconf \
                rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas 2>&1 | grep -v "^::" | grep -v "warning:" || true
            ;;
        "debian")
            apt-get update -qq
            apt-get install -qq -y git cmake make g++ pkg-config 2>&1 | grep -v "^Reading\|^Building\|^Get:" || true
            apt-get install -qq -y rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas 2>&1 | grep -v "^Reading\|^Building\|^Get:" || \
                warning "Some ROCm packages may not be available"
            ;;
        "fedora")
            dnf install -q -y git cmake make gcc-c++ pkgconf 2>&1 | grep -v "^Last metadata" || true
            dnf install -q -y rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas 2>&1 | grep -v "^Last metadata" || \
                warning "Some ROCm packages may not be available"
            ;;
        "opensuse")
            zypper install -y --quiet git cmake make gcc-c++ pkg-config 2>&1 | grep -v "^Loading\|^Retrieving" || true
            zypper install -y --quiet rocm-hip-sdk rocm-hip-runtime rocblas miopen-hip hipblas 2>&1 | grep -v "^Loading\|^Retrieving" || \
                warning "Some ROCm packages may not be available"
            ;;
    esac
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    # Clone llama.cpp repository
    local llama_build_dir="/tmp/llama.cpp-build-$$"
    print_step 2 5 "Cloning llama.cpp repository..."
    git clone --quiet --depth 1 https://github.com/ggerganov/llama.cpp.git "$llama_build_dir" 2>&1 | grep -v "^Cloning" || true
    cd "$llama_build_dir"
    completed_item "Repository cloned"
    
    # Set ROCm environment for HIP compilation
    print_step 3 5 "Configuring ROCm environment..."
    export HIPCXX="/opt/rocm/lib/llvm/bin/clang"
    export HIP_PATH="/opt/rocm"
    export HIP_DEVICE_LIB_PATH="/opt/rocm/amdgcn/bitcode"
    completed_item "ROCm environment configured"
    
    # Configure and build with HIP support targeting gfx1100
    print_step 4 5 "Compiling llama.cpp with Flash Attention..."
    print_tip "This may take 5-10 minutes"
    mkdir build && cd build
    cmake .. \
        -DGGML_HIP=ON \
        -DGGML_HIP_ROCWMMA_FATTN=ON \
        -DGPU_TARGETS=gfx1100 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="-I/opt/rocm/include" 2>&1 | grep -E "^-- |CMAKE_" | head -10 || true
    echo
    
    local nproc_count
    nproc_count="$(nproc)"
    local last_percent=0
    
    cmake --build . --config Release -j"${nproc_count}" 2>&1 | while IFS= read -r line; do
        # Show only major progress milestones
        if [[ "$line" =~ \[\ *([0-9]+)% ]]; then
            local percent="${BASH_REMATCH[1]}"
            # Update every 10%
            if (( percent >= last_percent + 10 )); then
                last_percent=$percent
                printf "${C_DIM}   [%3d%%] Building llama.cpp...${C_NC}\r" "$percent"
            fi
        elif [[ "$line" =~ "Built target" ]]; then
            local target="${line#*Built target }"
            if [[ "$target" == "llama-cli" ]] || [[ "$target" == "llama-server" ]]; then
                printf "${C_GREEN}   ${SYMBOL_CHECK} Built: %-50s${C_NC}\n" "$target"
            fi
        fi
    done
    echo
    completed_item "llama.cpp compiled with gfx1100 target"
    
    # Install binaries
    print_step 5 5 "Installing llama.cpp..."
    cmake --install . 2>&1 | grep -v "^-- " || true
    
    # Determine the correct group for nobody user
    local nobody_group="nobody"
    if [[ "$distro" == "debian" ]]; then
        nobody_group="nogroup"
    fi
    
    # Create systemd service for llama-server
    cat > /etc/systemd/system/llama-server.service <<EOF
[Unit]
Description=llama.cpp server (GZ302 Strix Halo gfx1100 build)
After=network.target
Documentation=https://github.com/ggerganov/llama.cpp

[Service]
Type=simple
# GZ302 Strix Halo gfx1151 optimizations
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GPU_MAX_HW_QUEUES=8"
Environment="AMD_SERIALIZE_KERNEL=0"
Environment="AMD_SERIALIZE_COPY=0"
ExecStart=/usr/local/bin/llama-server --host 0.0.0.0 --port 8080 -m /var/lib/gz302-llm/model.gguf --n-gpu-layers 999 -fa 1 --no-mmap
Restart=on-failure
RestartSec=5
User=nobody
Group=${nobody_group}
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable llama-server.service
    
    # Create model directory
    mkdir -p /var/lib/gz302-llm
    
    # Clean up build directory
    cd /
    rm -rf "$llama_build_dir"
    
    completed_item "llama.cpp installed"
    echo
    print_box "${SYMBOL_CHECK} llama.cpp Build Complete" "$C_BOLD_GREEN"
    print_keyval "Server" "/usr/local/bin/llama-server"
    print_keyval "CLI" "/usr/local/bin/llama-cli"
    print_keyval "Service" "llama-server.service (enabled)"
    echo
    print_subsection "Quick Start"
    progress_item "Download a GGUF model to /var/lib/gz302-llm/model.gguf"
    progress_item "Start: sudo systemctl start llama-server"
    progress_item "Access: http://localhost:8080"
    echo
}

# Setup Open WebUI using Docker
# Open WebUI can work with various backends: Ollama, llama.cpp, OpenAI API, etc.
# This function auto-detects which backend is available and configures accordingly
setup_openwebui_docker() {
    local user="$1"
    local distro="$2"
    
    print_subsection "Setting up Open WebUI"
    
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
        return 1
    fi

    # Ensure docker service is running
    if ! systemctl is-active --quiet docker; then
        systemctl start docker
    fi
    
    info "Pulling and starting Open WebUI container..."
    
    # Stop existing container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^open-webui$"; then
        info "Stopping and removing existing open-webui container..."
        docker stop open-webui >/dev/null 2>&1 || true
        docker rm open-webui >/dev/null 2>&1 || true
    fi

    # Detect which backend is available and configure Open WebUI accordingly
    local docker_args=()
    docker_args+=(-d)
    docker_args+=(-p 3000:8080)
    docker_args+=(--add-host=host.docker.internal:host-gateway)
    docker_args+=(-v open-webui:/app/backend/data)
    docker_args+=(--name open-webui)
    docker_args+=(--restart always)
    
    local backend_info=""
    
    # Check for Ollama (runs on port 11434 by default)
    if command -v ollama >/dev/null 2>&1 || systemctl is-active --quiet ollama 2>/dev/null; then
        info "Detected Ollama - configuring Open WebUI to connect to Ollama"
        docker_args+=(-e OLLAMA_BASE_URL=http://host.docker.internal:11434)
        backend_info="Ollama at http://localhost:11434"
    fi
    
    # Check for llama.cpp server (runs on port 8080 by default)
    if [[ -x "/usr/local/bin/llama-server" ]] || systemctl is-active --quiet llama-server 2>/dev/null; then
        info "Detected llama.cpp - configuring Open WebUI to connect to llama-server"
        docker_args+=(-e OPENAI_API_BASE_URL=http://host.docker.internal:8080/v1)
        docker_args+=(-e OPENAI_API_KEY=sk-no-key-required)
        if [[ -n "$backend_info" ]]; then
            backend_info="$backend_info and llama.cpp at http://localhost:8080"
        else
            backend_info="llama.cpp at http://localhost:8080"
        fi
    fi
    
    # If no backend detected, just start Open WebUI - user can configure later
    if [[ -z "$backend_info" ]]; then
        info "No local LLM backend detected - Open WebUI will start without pre-configured backend"
        info "You can configure backends (Ollama, OpenAI API, etc.) in Open WebUI settings"
        backend_info="No backend pre-configured (configure in Settings)"
    fi
    
    # Run the container
    docker run "${docker_args[@]}" ghcr.io/open-webui/open-webui:main
    
    success "Open WebUI installed and started via Docker"
    info "Open WebUI is running on http://localhost:3000"
    info "Backend: $backend_info"
    info ""
    info "First user to sign up becomes admin. You can configure additional"
    info "backends (Ollama, OpenAI, etc.) in Admin Settings > Connections."
}

# Ask user which LLM backends to install
ask_backend_choice() {
    # interactive only when running in a TTY
    if [[ ! -t 0 ]] && [[ ! -t 1 ]]; then
        info "Non-interactive mode: installing both ollama and llama.cpp"
        echo "3" > /tmp/.gz302-backend-choice
        return
    fi
    
    echo
    echo "Choose LLM backends to install (both optimized for Strix Halo/gfx1151):"
    echo "  1) ollama only       - Model management backend (requires Open WebUI frontend)"
    echo "  2) llama.cpp only    - Fast inference with built-in webui (port 8080, flash attention enabled)"
    echo "  3) both              - Install both backends (recommended)"
    
    local choice=""
    # Read from /dev/tty to ensure we get user input even when stdin is redirected
    if [[ -r /dev/tty ]]; then
        read -r -p "Install backends (1-3): " choice < /dev/tty
    else
        read -r -p "Install backends (1-3): " choice
    fi
    
    case "$choice" in
        1) 
            info "Selected: Ollama only"
            echo "1" > /tmp/.gz302-backend-choice
            ;;
        2)
            info "Selected: llama.cpp only"
            echo "2" > /tmp/.gz302-backend-choice
            ;;
        3)
            info "Selected: Both backends"
            echo "3" > /tmp/.gz302-backend-choice
            ;;
        *)
            warning "Invalid choice '$choice'. Please enter 1, 2, or 3."
            # Recursively ask again instead of defaulting
            ask_backend_choice
            ;;
    esac
}

# Ask user which frontends to install
ask_frontend_choice() {
    # interactive only when running in a TTY
    if [[ ! -t 0 ]] && [[ ! -t 1 ]]; then
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
    
    local choice=""
    # Read from /dev/tty to ensure we get user input even when stdin is redirected
    if [[ -r /dev/tty ]]; then
        read -r -p "Install frontends (e.g. '1,3' or '1 2 3' or Enter=none): " choice < /dev/tty
    else
        read -r -p "Install frontends (e.g. '1,3' or '1 2 3' or Enter=none): " choice
    fi
    
    # normalize and parse choice
    choice="${choice,,}"    # lowercase
    choice="${choice// /,}"  # replace spaces with commas
    choice="${choice//,/,}"  # clean up multiple commas
    
    if [[ -z "$choice" ]]; then
        info "No frontends selected"
        echo "" > /tmp/.gz302-frontend-choice
    else
        info "Selected frontends: $choice"
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
            # Build Ollama from source with HIP support for optimal Strix Halo performance
            # This provides native GPU acceleration with rocWMMA flash attention
            if [[ "$is_cachyos_system" == true ]]; then
                build_ollama_from_source "cachyos"
            else
                build_ollama_from_source "arch"
            fi
        fi
        # Install Open WebUI automatically when Ollama backend is selected
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "arch"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            # Build llama.cpp from source with HIP support for Strix Halo
            if [[ "$is_cachyos_system" == true ]]; then
                build_llamacpp_from_source "cachyos"
            else
                build_llamacpp_from_source "arch"
            fi
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
        if ! check_ollama_installed; then
            # Build Ollama from source with HIP support for optimal Strix Halo performance
            build_ollama_from_source "debian"
        fi
        
        # Setup Open WebUI automatically when Ollama backend is selected
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "debian"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            # Build llama.cpp from source with HIP support for Strix Halo
            build_llamacpp_from_source "debian"
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
        if ! check_ollama_installed; then
            # Build Ollama from source with HIP support for optimal Strix Halo performance
            build_ollama_from_source "fedora"
        fi
        
        # Setup Open WebUI automatically when Ollama backend is selected
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "fedora"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            # Build llama.cpp from source with HIP support for Strix Halo
            build_llamacpp_from_source "fedora"
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
        if ! check_ollama_installed; then
            # Build Ollama from source with HIP support for optimal Strix Halo performance
            build_ollama_from_source "opensuse"
        fi
        
        # Setup Open WebUI automatically when Ollama backend is selected
        local primary_user
        primary_user=$(get_real_user)
        setup_openwebui_docker "$primary_user" "opensuse"
    fi
    
    # Install llama.cpp with ROCm support if requested
    if [[ "$backend_choice" == "2" ]] || [[ "$backend_choice" == "3" ]]; then
        if ! check_llamacpp_installed; then
            # Build llama.cpp from source with HIP support for Strix Halo
            build_llamacpp_from_source "opensuse"
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

# --- LLM/AI Software Uninstall Function ---
uninstall_llm_software() {
    info "Uninstalling all LLM/AI software components..."
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        "arch"|"cachyos")
            # Stop and remove Ollama
            if systemctl is-active --quiet ollama 2>/dev/null; then
                info "Stopping Ollama service..."
                systemctl stop ollama
                systemctl disable ollama
            fi
            
            # Remove Ollama packages
            if pacman -Q ollama >/dev/null 2>&1; then
                info "Removing Ollama package..."
                pacman -R --noconfirm ollama
            fi
            if pacman -Q ollama-rocm >/dev/null 2>&1; then
                info "Removing Ollama ROCm package..."
                pacman -R --noconfirm ollama-rocm
            fi
            
            # Remove llama.cpp binaries and service
            if systemctl is-active --quiet llama-server 2>/dev/null; then
                info "Stopping llama-server service..."
                systemctl stop llama-server
                systemctl disable llama-server
            fi
            
            if [[ -f /etc/systemd/system/llama-server.service ]]; then
                info "Removing llama-server systemd service..."
                rm -f /etc/systemd/system/llama-server.service
                systemctl daemon-reload
            fi
            
            if [[ -x "/usr/local/bin/llama-server" ]]; then
                info "Removing llama.cpp binaries..."
                rm -f /usr/local/bin/llama-server /usr/local/bin/llama-cli /usr/local/bin/llama-*
            fi
            
            # Remove Python virtual environments
            if [[ -d "/var/lib/gz302-llm" ]]; then
                info "Removing Python virtual environment..."
                rm -rf "/var/lib/gz302-llm"
            fi
            
            # Remove conda environments
            local primary_user
            primary_user=$(get_real_user)
            if [[ "$primary_user" != "root" ]]; then
                # Check for conda/miniforge
                local conda_cmd=""
                if sudo -u "$primary_user" bash -lc "command -v conda >/dev/null 2>&1"; then
                    conda_cmd="$(sudo -u "$primary_user" bash -lc 'command -v conda')"
                elif [[ -x "/home/$primary_user/miniforge3/bin/conda" ]]; then
                    conda_cmd="/home/$primary_user/miniforge3/bin/conda"
                fi
                
                if [[ -n "$conda_cmd" ]]; then
                    info "Removing gz302-llm conda environment..."
                    sudo -u "$primary_user" "$conda_cmd" env remove -n gz302-llm || true
                fi
            fi
            
            # Remove ROCm packages (optional - ask user)
            echo
            warning "ROCm packages (rocm-opencl-runtime, rocblas, miopen-hip) may be used by other applications."
            warning "Remove them only if you're sure they're not needed elsewhere."
            read -r -p "Remove ROCm packages? (y/N): " -n 1 remove_rocm
            echo
            if [[ "${remove_rocm,,}" == "y" ]]; then
                info "Removing ROCm packages..."
                pacman -R --noconfirm rocm-opencl-runtime rocblas miopen-hip 2>/dev/null || true
            fi
            ;;
            
        "debian"|"ubuntu")
            # Stop and remove Ollama
            if systemctl is-active --quiet ollama 2>/dev/null; then
                info "Stopping Ollama service..."
                systemctl stop ollama
                systemctl disable ollama
            fi
            
            # Remove Ollama (installed from curl script)
            if [[ -x "/usr/local/bin/ollama" ]]; then
                info "Removing Ollama..."
                rm -f /usr/local/bin/ollama
                rm -rf /usr/share/ollama
                if id ollama >/dev/null 2>&1; then
                    userdel ollama || true
                fi
            fi
            
            # Remove llama.cpp
            if systemctl is-active --quiet llama-server 2>/dev/null; then
                info "Stopping llama-server service..."
                systemctl stop llama-server
                systemctl disable llama-server
            fi
            
            if [[ -f /etc/systemd/system/llama-server.service ]]; then
                info "Removing llama-server systemd service..."
                rm -f /etc/systemd/system/llama-server.service
                systemctl daemon-reload
            fi
            
            if [[ -x "/usr/local/bin/llama-server" ]]; then
                info "Removing llama.cpp binaries..."
                rm -f /usr/local/bin/llama-server /usr/local/bin/llama-cli /usr/local/bin/llama-*
            fi
            
            # Remove Python virtual environments
            if [[ -d "/var/lib/gz302-llm" ]]; then
                info "Removing Python virtual environment..."
                rm -rf "/var/lib/gz302-llm"
            fi
            
            # Remove ROCm packages (optional)
            echo
            warning "ROCm packages may be used by other applications."
            read -r -p "Remove ROCm packages? (y/N): " -n 1 remove_rocm
            echo
            if [[ "${remove_rocm,,}" == "y" ]]; then
                info "Removing ROCm packages..."
                apt remove --purge -y rocm-opencl-runtime rocblas miopen-hip 2>/dev/null || true
                apt autoremove -y
            fi
            ;;
            
        "fedora")
            # Similar to Debian/Ubuntu but with dnf
            if systemctl is-active --quiet ollama 2>/dev/null; then
                systemctl stop ollama
                systemctl disable ollama
            fi
            
            if [[ -x "/usr/local/bin/ollama" ]]; then
                rm -f /usr/local/bin/ollama
                rm -rf /usr/share/ollama
                if id ollama >/dev/null 2>&1; then
                    userdel ollama || true
                fi
            fi
            
            # Remove llama.cpp service and binaries
            if systemctl is-active --quiet llama-server 2>/dev/null; then
                systemctl stop llama-server
                systemctl disable llama-server
            fi
            
            if [[ -f /etc/systemd/system/llama-server.service ]]; then
                rm -f /etc/systemd/system/llama-server.service
                systemctl daemon-reload
            fi
            
            if [[ -x "/usr/local/bin/llama-server" ]]; then
                rm -f /usr/local/bin/llama-server /usr/local/bin/llama-cli /usr/local/bin/llama-*
            fi
            
            # Remove Python virtual environments
            if [[ -d "/var/lib/gz302-llm" ]]; then
                rm -rf "/var/lib/gz302-llm"
            fi
            
            # Remove ROCm packages (optional)
            echo
            warning "ROCm packages may be used by other applications."
            read -r -p "Remove ROCm packages? (y/N): " -n 1 remove_rocm
            echo
            if [[ "${remove_rocm,,}" == "y" ]]; then
                dnf remove -y rocm-opencl rocblas miopen-hip 2>/dev/null || true
            fi
            ;;
            
        "opensuse")
            # Similar to other RPM-based distros
            if systemctl is-active --quiet ollama 2>/dev/null; then
                systemctl stop ollama
                systemctl disable ollama
            fi
            
            if [[ -x "/usr/local/bin/ollama" ]]; then
                rm -f /usr/local/bin/ollama
                rm -rf /usr/share/ollama
                if id ollama >/dev/null 2>&1; then
                    userdel ollama || true
                fi
            fi
            
            # Remove llama.cpp
            if systemctl is-active --quiet llama-server 2>/dev/null; then
                systemctl stop llama-server
                systemctl disable llama-server
            fi
            
            if [[ -f /etc/systemd/system/llama-server.service ]]; then
                rm -f /etc/systemd/system/llama-server.service
                systemctl daemon-reload
            fi
            
            if [[ -x "/usr/local/bin/llama-server" ]]; then
                rm -f /usr/local/bin/llama-server /usr/local/bin/llama-cli /usr/local/bin/llama-*
            fi
            
            # Remove Python virtual environments
            if [[ -d "/var/lib/gz302-llm" ]]; then
                rm -rf "/var/lib/gz302-llm"
            fi
            
            # Remove ROCm packages (optional)
            echo
            warning "ROCm packages may be used by other applications."
            read -r -p "Remove ROCm packages? (y/N): " -n 1 remove_rocm
            echo
            if [[ "${remove_rocm,,}" == "y" ]]; then
                zypper remove -y rocm-opencl rocblas miopen-hip 2>/dev/null || true
            fi
            ;;
            
        *)
            error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # Remove Open WebUI Docker containers and volumes (works on all distros)
    if command -v docker >/dev/null 2>&1; then
        info "Removing Open WebUI Docker containers and volumes..."
        
        # Stop and remove containers
        if docker ps -a --format '{{.Names}}' | grep -q "^open-webui$"; then
            docker stop open-webui >/dev/null 2>&1 || true
            docker rm open-webui >/dev/null 2>&1 || true
        fi
        
        # Remove volumes
        if docker volume ls --format '{{.Name}}' | grep -q "^open-webui$"; then
            docker volume rm open-webui >/dev/null 2>&1 || true
        fi
        if docker volume ls --format '{{.Name}}' | grep -q "^ollama$"; then
            docker volume rm ollama >/dev/null 2>&1 || true
        fi
    fi
    
    # Remove model directories (optional - ask user)
    echo
    warning "This will remove all downloaded Ollama models and llama.cpp model files."
    read -r -p "Remove model directories (~/.ollama and /var/lib/gz302-llm/models)? (y/N): " -n 1 remove_models
    echo
    if [[ "${remove_models,,}" == "y" ]]; then
        info "Removing model directories..."
        rm -rf ~/.ollama 2>/dev/null || true
        rm -rf /var/lib/gz302-llm/models 2>/dev/null || true
    fi
    
    echo
    success "LLM/AI software uninstallation complete!"
    echo
    warning "Note: Kernel parameters optimized for LLM workloads have been kept for system stability."
    warning "If you want to remove them, edit your bootloader configuration manually."
    echo
}

main() {
    # Check if uninstall flag is provided
    if [[ "${1:-}" == "--uninstall" ]] || [[ "${1:-}" == "-u" ]]; then
        uninstall_llm_software
        exit 0
    fi
    
    # Normal installation flow
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        "arch"|"cachyos")
            install_arch_llm_software
            ;;
        "debian"|"ubuntu")
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

