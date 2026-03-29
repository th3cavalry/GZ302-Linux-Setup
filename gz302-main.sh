#!/bin/bash

# ==============================================================================
# Author: th3cavalry using Copilot
# Version: 4.2.0 (Refactored)
#
# Supported Models:
# - GZ302EA-XS99 (128GB RAM)
# - GZ302EA-XS98 (64GB RAM)
# - GZ302EA-XS96 (32GB RAM)
#
# This script automatically detects your Linux distribution and applies
# the appropriate hardware fixes for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
# It applies critical hardware fixes and TDP/refresh rate management.
#
# REQUIRED: Linux kernel 6.14+ minimum (6.17+ strongly recommended)
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Global CLI flags
ASSUME_YES="${ASSUME_YES:-false}"
POWER_TOOLS_ONLY="${POWER_TOOLS_ONLY:-false}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--assume-yes)
            ASSUME_YES=true
            shift
            ;;
        --power-tools-only)
            POWER_TOOLS_ONLY=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            # Other flags: break out and allow existing arg handling
            break
            ;;
        *)
            break
            ;;
    esac
done

# GitHub repository base URL for downloading modules
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

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

# Set SCRIPT_DIR early
SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_dir)}"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-lib/utils.sh"
else
    echo "gz302-lib/utils.sh not found. Downloading..."
    mkdir -p "${SCRIPT_DIR}/gz302-lib"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-lib/utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -O "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download gz302-lib/utils.sh"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-lib/utils.sh"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: Failed to download gz302-lib/utils.sh"
        exit 1
    fi
fi

# --- Load Libraries ---
load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
        return 0
    else
        # Try to download if not present
        info "Downloading ${lib_name}..."
        if command -v curl >/dev/null 2>&1; then
            mkdir -p "${SCRIPT_DIR}/gz302-lib"
            curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path" || return 1
            chmod +x "$lib_path"
            # shellcheck source=/dev/null
            source "$lib_path"
            return 0
        else
            return 1
        fi
    fi
}

info "Loading libraries..."
load_library "power-manager.sh" || warning "Failed to load power-manager.sh"
load_library "display-manager.sh" || warning "Failed to load display-manager.sh"
load_library "wifi-manager.sh" || warning "Failed to load wifi-manager.sh"
load_library "gpu-manager.sh" || warning "Failed to load gpu-manager.sh"
load_library "audio-manager.sh" || warning "Failed to load audio-manager.sh"
load_library "input-manager.sh" || warning "Failed to load input-manager.sh"
load_library "rgb-manager.sh" || warning "Failed to load rgb-manager.sh"
load_library "kernel-compat.sh" || warning "Failed to load kernel-compat.sh"
load_library "state-manager.sh" || warning "Failed to load state-manager.sh"
load_library "distro-manager.sh" || warning "Failed to load distro-manager.sh"

# Initialize state manager
state_init >/dev/null 2>&1 || true

# --- Helper Functions ---

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-main.sh"
    fi
}

check_network() {
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSIL --max-time 5 "${GITHUB_RAW_URL}/gz302-main.sh" >/dev/null 2>&1; then
            return 0
        fi
    fi
    if command -v ping >/dev/null 2>&1; then
        if ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

check_kernel_version() {
    if declare -f kernel_check_version >/dev/null || declare -f kernel_get_version_num >/dev/null; then
        local kver
        kver=$(kernel_get_version_num)
        info "Detected kernel version: $(uname -r)"
        
        if ! kernel_meets_minimum; then
             error "Kernel 6.14+ is required. Please upgrade."
        fi
        
        if [[ $kver -ge 700 ]]; then
            success "Kernel version is Linux 7.0+ (latest development)"
        elif [[ $kver -ge 619 ]]; then
            success "Kernel version is optimal (6.19+) - all hardware native"
        elif [[ $kver -ge 617 ]]; then
             success "Kernel version meets recommended requirements (6.17+)"
        else
             warning "Kernel version meets minimum (6.14+) but < 6.17. Some features require workarounds."
        fi
        echo "$kver"
    else
        local kernel_version
        kernel_version=$(uname -r | cut -d. -f1,2)
        local major minor
        major=$(echo "$kernel_version" | cut -d. -f1)
        minor=$(echo "$kernel_version" | cut -d. -f2)
        local version_num=$((major * 100 + minor))
        echo "$version_num"
    fi
}


offer_command_center_install() {
    local distro="$1"
    echo
    print_subsection "GZ302 Command Center"
    info "The Command Center provides a user interface for power, display, and RGB control."
    echo
    
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        install_command_center
        return
    fi
    
    if ask_yes_no "Do you want to install the GZ302 Command Center? (Y/n): " Y; then
        install_command_center
    else
        info "Skipping Command Center installation. Install later via ./install-command-center.sh"
    fi
}

install_command_center() {
    print_section "Installing Command Center"
    local cmd_install_script="${SCRIPT_DIR}/install-command-center.sh"
    
    if [[ -f "$cmd_install_script" ]]; then
        bash "$cmd_install_script"
    else
        local temp_script="/tmp/install-command-center.sh"
        if curl -fsSL "${GITHUB_RAW_URL}/install-command-center.sh" -o "$temp_script"; then
            chmod +x "$temp_script"
            bash "$temp_script"
            rm -f "$temp_script"
        else
            error "Failed to download Command Center installer"
        fi
    fi
}

download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local local_module="${SCRIPT_DIR}/modules/${module_name}.sh"
    
    if [[ -f "$local_module" ]]; then
        info "Executing local module: ${module_name}..."
        bash "$local_module" "$distro"
        return $?
    fi

    local module_url="${GITHUB_RAW_URL}/modules/${module_name}.sh"
    local temp_script="/tmp/${module_name}.sh"
    
    info "Downloading ${module_name} module..."
    if curl -fsSL "$module_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        bash "$temp_script" "$distro"
        local exec_result=$?
        rm -f "$temp_script"
        return $exec_result
    else
        warning "Failed to download ${module_name} module"
        return 1
    fi
}

offer_optional_modules() {
    local distro="$1"
    echo
    print_section "Optional Software Modules"
    info "1. Gaming Software (Steam, Lutris, etc.)"
    info "2. LLM/AI Software (Ollama, ROCm, PyTorch)"
    info "3. Hypervisor Software (KVM/QEMU, VirtualBox)"
    info "4. System Snapshots (Snapper, LVM)"
    info "5. Secure Boot Configuration"
    info "6. Skip optional modules"
    echo
    
    local module_choice
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        module_choice="6"
    else
        read -r -p "Select modules (e.g., 1,2 or 6 to skip): " module_choice
    fi
    
    IFS=',' read -ra CHOICES <<< "$module_choice"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ')
        case "$choice" in
            1) download_and_execute_module "gz302-gaming" "$distro" ;;
            2) download_and_execute_module "gz302-llm" "$distro" ;;
            3) download_and_execute_module "gz302-hypervisor" "$distro" ;;
            4) download_and_execute_module "gz302-snapshots" "$distro" ;;
            5) download_and_execute_module "gz302-secureboot" "$distro" ;;
            6) info "Skipping optional modules" ;;
        esac
    done
}

migrate_old_paths() {
    local paths_migrated=0
    local sentinel="/etc/gz302/.migrations_v1_done"

    if [[ -f "$sentinel" ]]; then
        echo 0
        return
    fi
    
    info "Checking for old configuration paths..." >&2
    
    # Simple migration logic for major paths
    for dir in /etc/pwrcfg /etc/rrcfg /etc/gz302-rgb; do
        if [[ -d "$dir" ]]; then
            local target="/etc/gz302/$(basename "$dir")"
            [[ "$dir" == "/etc/gz302-rgb" ]] && target="/etc/gz302"
            mkdir -p "$target"
            cp -r "$dir"/* "$target/" 2>/dev/null && rm -rf "$dir" && ((paths_migrated++)) || true
        fi
    done
    
    if [[ $paths_migrated -gt 0 ]]; then
        mkdir -p /etc/gz302
        touch "$sentinel"
    fi
    echo "$paths_migrated"
}

main() {
    check_root
    
    local paths_migrated
    paths_migrated=$(migrate_old_paths)
    if [[ $paths_migrated -gt 0 ]]; then
        info "Migration completed. Please run the script again."
        exit 0
    fi
    
    print_banner
    print_section "GZ302 Linux Setup v4.2.0"
    
    if check_resume "main"; then
        if prompt_resume "main"; then
            info "Resuming from checkpoint..."
        fi
    else
        init_checkpoint "main"
    fi
    
    # Steps
    print_step 1 5 "Validating system..."
    check_kernel_version >/dev/null
    complete_step "kernel_check"
    
    print_step 2 5 "Checking network..."
    check_network || warning "Network connectivity limited"
    complete_step "network_check"
    
    print_step 3 5 "Detecting distribution..."
    local detected_distro
    detected_distro=$(detect_distribution)
    success "Detected: $detected_distro"
    
    print_step 4 5 "Backing up configuration..."
    if ! is_step_completed "config_backup"; then
        create_config_backup "pre-install" >/dev/null
        complete_step "config_backup"
    fi
    
    print_step 5 5 "System ready"
    echo
    print_keyval "Distribution" "$detected_distro"
    print_keyval "Kernel" "$(uname -r)"
    
    local install_fixes=true
    if [[ "${POWER_TOOLS_ONLY:-false}" == "true" ]]; then
        install_fixes=false
    elif [[ "${ASSUME_YES:-false}" != "true" ]]; then
        if ! ask_yes_no "Do you want to install hardware fixes? (Y/n): " Y; then
            install_fixes=false
        fi
    fi
    
    if [[ "$install_fixes" == false ]]; then
        install_command_center
    else
        case "$detected_distro" in
            "arch") setup_arch_based "$detected_distro" ;;
            "ubuntu"|"debian") setup_debian_based "$detected_distro" ;;
            "fedora") setup_fedora_based "$detected_distro" ;;
            "opensuse") setup_opensuse "$detected_distro" ;;
            *) error "Unsupported distribution: $detected_distro" ;;
        esac
    
        echo
        print_section "Setup Complete"
        offer_command_center_install "$detected_distro"
        offer_optional_modules "$detected_distro"
    fi
    
    clear_checkpoint
    echo
    print_box "🚀 SETUP COMPLETE! 🚀" "$C_BOLD_GREEN"
    warning "A REBOOT is recommended to apply all changes"
    echo
}

main "$@"
