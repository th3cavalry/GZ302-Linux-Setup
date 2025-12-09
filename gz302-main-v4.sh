#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (GZ302) - v4.0.0
#
# Author: th3cavalry using Copilot
# Version: 4.0.0-dev (Library-First Architecture)
#
# NEW IN v4.0.0:
# - Library-first modular architecture
# - Persistent state tracking (idempotent)
# - Automatic backups and logging
# - CLI interface (--status, --force, --help)
# - Enhanced ROCm 6.3+ support documentation
#
# Supported Models:
# - GZ302EA-XS99 (128GB RAM)
# - GZ302EA-XS64 (64GB RAM)  
# - GZ302EA-XS32 (32GB RAM)
#
# REQUIRED: Linux kernel 6.12+ minimum (6.17+ strongly recommended)
#
# Core features (automatically installed):
# - Hardware fixes via modular libraries
# - Power management (TDP control via pwrcfg)
# - Refresh rate control (rrcfg)
# - Keyboard RGB control (gz302-rgb)
# - System tray power manager
#
# Optional modules: gaming, llm/AI (with ROCm 6.3+), hypervisor, snapshots, secureboot
#
# Supported Distributions:
# - Arch-based, Debian-based, RPM-based (Fedora), OpenSUSE
#
# USAGE:
#   sudo ./gz302-main-v4.sh [--status] [--force] [--help]
# ==============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_VERSION="4.0.0-dev"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Parse CLI Arguments ---
MODE="install"
FORCE_MODE=false

for arg in "$@"; do
    case "$arg" in
        --status)
            MODE="status"
            ;;
        --force)
            FORCE_MODE=true
            MODE="install"
            ;;
        --help|-h)
            cat <<'HELP'
GZ302 Main Setup Script v4.0.0-dev

Usage:
    sudo ./gz302-main-v4.sh [OPTIONS]

Options:
    --status    Show current system status and exit
    --force     Force re-application of all fixes (ignore state)
    --help      Show this help message

Features:
    - Full hardware configuration via libraries
    - TDP management (pwrcfg command)
    - Refresh rate control (rrcfg command)
    - RGB keyboard control
    - System tray integration
    - Optional modules (gaming, AI/LLM, virtualization)
    - Persistent state tracking
    - Idempotent operations
HELP
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# --- Script Directory ---
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

# --- Load Utilities ---
load_file() {
    local file_name="$1"
    local file_path="${SCRIPT_DIR}/${file_name}"
    
    if [[ -f "$file_path" ]]; then
        # shellcheck disable=SC1090
        source "$file_path"
        return 0
    else
        echo "Downloading ${file_name}..."
        if curl -fsSL "${GITHUB_RAW_URL}/${file_name}" -o "$file_path" 2>/dev/null; then
            chmod +x "$file_path"
            # shellcheck disable=SC1090
            source "$file_path"
            return 0
        fi
        return 1
    fi
}

# Load gz302-utils.sh first
if ! load_file "gz302-utils.sh"; then
    echo "ERROR: Failed to load gz302-utils.sh"
    exit 1
fi

# --- Load Libraries ---
echo "Loading GZ302 libraries..."

load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck disable=SC1090
        source "$lib_path"
        return 0
    else
        echo "  Downloading ${lib_name}..."
        mkdir -p "${SCRIPT_DIR}/gz302-lib"
        if curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path" 2>/dev/null; then
            chmod +x "$lib_path"
            # shellcheck disable=SC1090
            source "$lib_path"
            return 0
        fi
        return 1
    fi
}

# Load required libraries
for lib in kernel-compat.sh state-manager.sh wifi-manager.sh gpu-manager.sh input-manager.sh audio-manager.sh; do
    if ! load_library "$lib"; then
        error "Failed to load $lib"
    fi
done

success "All libraries loaded"
echo

# --- Check Root ---
check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Usage: sudo ./gz302-main-v4.sh"
    fi
}

# --- Detect Distribution ---
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "$ID" in
            arch|cachyos|endeavouros|manjaro)
                echo "arch"
                ;;
            ubuntu|pop|linuxmint|debian)
                echo "ubuntu"
                ;;
            fedora|nobara)
                echo "fedora"
                ;;
            opensuse*|suse*)
                echo "opensuse"
                ;;
            *)
                warning "Unsupported distribution: $ID"
                echo "unknown"
                ;;
        esac
    else
        error "Cannot detect distribution (no /etc/os-release)"
    fi
}


# --- Status Mode ---
if [[ "$MODE" == "status" ]]; then
    check_root
    
    print_box "GZ302 System Status v${SCRIPT_VERSION}"
    echo
    
    # Kernel status
    print_section "Kernel Status"
    kernel_print_status
    echo
    
    # Initialize state
    state_init >/dev/null 2>&1 || true
    
    # Component status
    print_section "Component Status"
    echo
    info "WiFi Status:"
    wifi_print_status
    echo
    info "GPU Status:"
    gpu_print_status
    echo
    info "Input Status:"
    input_print_status
    echo
    info "Audio Status:"
    audio_print_status
    echo
    
    # State tracking
    print_section "State Tracking"
    state_print_status
    
    exit 0
fi

# --- Main Installation ---
check_root

print_box "GZ302 Setup v${SCRIPT_VERSION} - Library-First Architecture"
echo

if [[ "$FORCE_MODE" == true ]]; then
    warning "FORCE MODE: Re-applying all fixes"
    echo
fi

# Step 1: Initialize
print_section "Step 1: Initialize"
state_init || warning "State init had issues"
if [[ "$FORCE_MODE" == true ]]; then
    state_clear_all >/dev/null 2>&1 || true
fi
echo

# Step 2: Kernel Check
print_section "Step 2: Kernel Compatibility"
if ! kernel_meets_minimum; then
    error "Kernel version too old. Minimum: 6.12+"
fi

kernel_ver=$(kernel_get_version_num)
info "Kernel: $(kernel_get_version_string)"
info "Status: $(kernel_get_status)"
echo

# Step 3: Detect Distribution
print_section "Step 3: Detect Distribution"
DETECTED_DISTRO=$(detect_distribution)
info "Detected: $DETECTED_DISTRO"
echo

# Step 4: Hardware Configuration
print_section "Step 4: Hardware Configuration (Libraries)"

info "Configuring WiFi..."
if wifi_apply_configuration; then
    state_mark_applied "wifi" "configuration" "kernel_${kernel_ver}"
    success "WiFi configured"
else
    warning "WiFi configuration had warnings"
fi
echo

info "Configuring GPU..."
if gpu_apply_configuration; then
    state_mark_applied "gpu" "configuration" "radeon_8060s"
    success "GPU configured"
else
    warning "GPU configuration had warnings"
fi
echo

info "Configuring Input Devices..."
if input_apply_configuration "$kernel_ver"; then
    state_mark_applied "input" "configuration" "kernel_${kernel_ver}"
    success "Input configured"
else
    warning "Input configuration had warnings"
fi
echo

info "Configuring Audio..."
if audio_apply_configuration "$DETECTED_DISTRO"; then
    state_mark_applied "audio" "configuration" "sof_cs35l41"
    success "Audio configured"
else
    warning "Audio configuration had warnings"
fi
echo

# Step 5: Verification
print_section "Step 5: Verification"
verification_ok=true

wifi_verify_working >/dev/null 2>&1 || verification_ok=false
gpu_verify_working >/dev/null 2>&1 || verification_ok=false
input_verify_working >/dev/null 2>&1 || verification_ok=false
audio_verify_working >/dev/null 2>&1 || verification_ok=false

if [[ "$verification_ok" == true ]]; then
    success "All hardware verification passed"
else
    warning "Some components had verification warnings"
fi
echo

# Note: TDP, refresh rate, RGB, tray icon, and optional modules would be added here
# For now, this demonstrates the library integration pattern

print_box "Core Hardware Setup Complete!"
echo
info "Next: TDP control, RGB, tray icon (using existing v3.0.0 logic)"
info "Run: sudo ./gz302-main-v4.sh --status"
echo
warning "Full feature parity with v3.0.0 in progress"
warning "This v4.0.0-dev demonstrates library integration"
echo

