#!/bin/bash
# install.sh
# Unified installer for GZ302 Linux Setup
# Usage: ./install.sh [--full | --minimal | --tools]

set -euo pipefail

# ==============================================================================
# GZ302 Linux Setup - Unified Installer
# Version: 4.0.0
#
# Author: th3cavalry
# 
# This unified installer replaces gz302-main.sh, gz302-minimal.sh, and 
# install-command-center.sh with a single entry point and mode flags.
#
# Supported Models:
# - GZ302EA-XS99 (128GB RAM)
# - GZ302EA-XS64 (64GB RAM)
# - GZ302EA-XS32 (32GB RAM)
#
# REQUIRED: Linux kernel 6.14+ minimum (6.17+ strongly recommended)
#
# Installation Modes:
# - --full: (Default) Hardware fixes + Command Center + GUI
# - --minimal: Hardware fixes only (kernel patches, no GUI)
# - --cc: Command Center + GUI only (no kernel patches)
#
# Supported Distributions:
# - Arch-based: Arch Linux, EndeavourOS, Manjaro, CachyOS, Omarchy
# - Debian-based: Ubuntu, Pop!_OS, Linux Mint
# - RPM-based: Fedora, Nobara
# - OpenSUSE: Tumbleweed and Leap
# ==============================================================================

REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_ROOT/gz302-lib"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Early Checks ---

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "❌ Error: This script must be run as root"
        echo "Usage: sudo ./install.sh [--full|--minimal|--tools]"
        exit 1
    fi
}

check_library() {
    if [ ! -d "$LIB_DIR" ]; then
        echo "❌ Error: gz302-lib directory not found!"
        echo "Expected location: $LIB_DIR"
        exit 1
    fi
}

# --- Load Core Libraries ---

load_library() {
    local lib_name="$1"
    local lib_path="$LIB_DIR/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck disable=SC1090
        source "$lib_path"
        return 0
    else
        # Try to download if not present
        echo "Downloading ${lib_name}..."
        if command -v curl >/dev/null 2>&1; then
            mkdir -p "$LIB_DIR"
            if curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path"; then
                chmod +x "$lib_path"
                # shellcheck disable=SC1090
                source "$lib_path"
                return 0
            fi
        fi
        return 1
    fi
}

# Source core libraries
echo "Loading GZ302 libraries..."
load_library "utils.sh" || { echo "❌ Failed to load utils.sh"; exit 1; }
load_library "kernel-compat.sh" || { echo "❌ Failed to load kernel-compat.sh"; exit 1; }
load_library "state-manager.sh" || { echo "❌ Failed to load state-manager.sh"; exit 1; }
load_library "wifi-manager.sh" || warning "Failed to load wifi-manager.sh"
load_library "gpu-manager.sh" || warning "Failed to load gpu-manager.sh"
load_library "input-manager.sh" || warning "Failed to load input-manager.sh"
load_library "audio-manager.sh" || warning "Failed to load audio-manager.sh"
load_library "power-manager.sh" || warning "Failed to load power-manager.sh"
load_library "display-manager.sh" || warning "Failed to load display-manager.sh"
load_library "rgb-manager.sh" || warning "Failed to load rgb-manager.sh"

# --- Help Function ---

show_help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║          GZ302 Linux Setup - Unified Installer           ║
╚═══════════════════════════════════════════════════════════╝

USAGE:
    sudo ./install.sh [OPTION]

OPTIONS:
    --full      (Default) Full installation
                • Kernel fixes and hardware patches
                • Power management tools (pwrcfg, rrcfg)
                • RGB control (gz302-rgb)
                • GUI Command Center (system tray)

    --minimal   Minimal installation (Fixes only)
                • Kernel patches and hardware fixes
                • NO GUI, NO power tools
                • Best for: Servers, purists, troubleshooting

    --cc        Command Center only (No kernel patches)
                • Power management tools
                • RGB control
                • GUI Command Center
                • Best for: Existing users with working hardware

    -h, --help  Show this help message

EXAMPLES:
    # Recommended for fresh installations
    sudo ./install.sh --full

    # Minimal fixes only (no GUI)
    sudo ./install.sh --minimal

    # Command Center only (skip hardware fixes)
    sudo ./install.sh --cc

REQUIREMENTS:
    • Linux kernel 6.14+ (6.17+ recommended)
    • Root privileges (sudo)
    • Internet connection

SUPPORTED DISTRIBUTIONS:
    • Arch Linux, EndeavourOS, Manjaro, CachyOS
    • Ubuntu, Pop!_OS, Linux Mint
    • Fedora, Nobara
    • OpenSUSE Tumbleweed, Leap

For more information: https://github.com/th3cavalry/GZ302-Linux-Setup
EOF
}

# --- Installation Functions ---

install_fixes() {
    print_section "Installing Hardware Fixes"
    
    # Initialize state management
    if state_init; then
        info "State management initialized"
    else
        warning "State management initialization had issues (continuing anyway)"
    fi
    
    # Kernel compatibility check
    print_subsection "Kernel Compatibility Check"
    if ! kernel_meets_minimum; then
        error "Unsupported kernel version. Please upgrade to kernel 6.14+"
    fi
    
    local kernel_ver
    kernel_ver=$(kernel_get_version_num)
    local kernel_status
    kernel_status=$(kernel_get_status)
    
    info "Kernel: $(kernel_get_version_string)"
    info "Status: $kernel_status"
    
    if kernel_has_native_support; then
        success "Kernel has native GZ302 hardware support"
        info "Minimal fixes needed, obsolete workarounds will be cleaned up"
    else
        warning "Kernel needs workarounds for full hardware support"
        info "Consider upgrading to kernel 6.17+ for native support"
    fi
    
    # WiFi Configuration
    print_subsection "WiFi Configuration (MediaTek MT7925)"
    if declare -F wifi_detect_hardware > /dev/null && wifi_detect_hardware >/dev/null 2>&1; then
        info "MT7925e WiFi controller detected"
        if declare -F wifi_apply_configuration > /dev/null && wifi_apply_configuration; then
            if declare -F state_mark_applied > /dev/null; then
                state_mark_applied "wifi" "configuration" "kernel_${kernel_ver}"
            fi
            success "WiFi configuration completed"
        else
            warning "WiFi configuration had warnings"
        fi
    else
        warning "MT7925e WiFi controller not detected, skipping"
    fi
    
    # GPU Configuration
    print_subsection "GPU Configuration (AMD Radeon 8060S)"
    if declare -F gpu_detect_hardware > /dev/null && gpu_detect_hardware >/dev/null 2>&1; then
        info "AMD Radeon GPU detected"
        if declare -F gpu_apply_configuration > /dev/null && gpu_apply_configuration; then
            if declare -F state_mark_applied > /dev/null; then
                state_mark_applied "gpu" "configuration" "radeon_8060s"
            fi
            success "GPU configuration completed"
        else
            warning "GPU configuration had warnings"
        fi
    else
        warning "AMD Radeon GPU not detected, skipping"
    fi
    
    # Input Configuration (Touchpad, Keyboard, Tablet mode)
    print_subsection "Input Configuration"
    if declare -F input_detect_hid_devices > /dev/null && input_detect_hid_devices >/dev/null 2>&1; then
        info "HID devices detected"
        if declare -F input_apply_configuration > /dev/null && input_apply_configuration; then
            if declare -F state_mark_applied > /dev/null; then
                state_mark_applied "input" "configuration" "hid_asus"
            fi
            success "Input configuration completed"
        else
            warning "Input configuration had warnings"
        fi
    else
        info "HID configuration not needed or devices not detected"
    fi
    
    # Audio Configuration
    print_subsection "Audio Configuration (SOF)"
    if declare -F audio_detect_controller > /dev/null && audio_detect_controller >/dev/null 2>&1; then
        info "Audio controller detected"
        if declare -F audio_apply_configuration > /dev/null && audio_apply_configuration; then
            if declare -F state_mark_applied > /dev/null; then
                state_mark_applied "audio" "configuration" "sof_firmware"
            fi
            success "Audio configuration completed"
        else
            warning "Audio configuration had warnings"
        fi
    else
        info "Audio configuration not needed"
    fi
    
    completed_item "Hardware fixes applied successfully"
}

install_tools() {
    print_section "Installing Power Tools & Command Center"
    
    # Check if the install-command-center script exists
    local cmd_install_script="$REPO_ROOT/install-command-center.sh"
    
    if [[ -f "$cmd_install_script" ]]; then
        info "Running Command Center installer..."
        bash "$cmd_install_script"
    else
        # Inline installation logic for power tools and RGB
        print_subsection "Installing Power Management Tools"
        
        # Power config (pwrcfg)
        if declare -F power_install_pwrcfg > /dev/null; then
            info "Installing pwrcfg (power profile manager)..."
            if power_install_pwrcfg; then
                success "pwrcfg installed"
            else
                warning "pwrcfg installation had issues"
            fi
        else
            info "Installing pwrcfg from scripts..."
            if [[ -f "$REPO_ROOT/scripts/pwrcfg" ]]; then
                cp "$REPO_ROOT/scripts/pwrcfg" /usr/local/bin/
                chmod +x /usr/local/bin/pwrcfg
                success "pwrcfg installed"
            else
                warning "pwrcfg script not found"
            fi
        fi
        
        # Refresh rate config (rrcfg)
        if declare -F display_install_rrcfg > /dev/null; then
            info "Installing rrcfg (refresh rate manager)..."
            if display_install_rrcfg; then
                success "rrcfg installed"
            else
                warning "rrcfg installation had issues"
            fi
        else
            info "Installing rrcfg from scripts..."
            if [[ -f "$REPO_ROOT/scripts/rrcfg" ]]; then
                cp "$REPO_ROOT/scripts/rrcfg" /usr/local/bin/
                chmod +x /usr/local/bin/rrcfg
                success "rrcfg installed"
            else
                warning "rrcfg script not found"
            fi
        fi
        
        # RGB control
        print_subsection "Installing RGB Control"
        if [[ -f "$REPO_ROOT/scripts/gz302-rgb-install.sh" ]]; then
            info "Running RGB installer..."
            bash "$REPO_ROOT/scripts/gz302-rgb-install.sh"
        else
            warning "RGB installer not found, skipping"
        fi
        
        # System tray
        print_subsection "Installing System Tray Application"
        if [[ -d "$REPO_ROOT/tray-icon" ]] && [[ -f "$REPO_ROOT/tray-icon/install-tray.sh" ]]; then
            info "Running tray installer..."
            bash "$REPO_ROOT/tray-icon/install-tray.sh"
        else
            warning "Tray installer not found, skipping"
        fi
    fi
    
    completed_item "Power tools and Command Center installed"
}

install_modules() {
    print_section "Optional Modules"
    
    info "Optional modules are available for:"
    echo "  • Gaming (Steam, Lutris, MangoHUD)"
    echo "  • AI/LLM (Ollama, ROCm, PyTorch)"
    echo "  • Hypervisor (KVM, QEMU)"
    echo
    info "To install optional modules, download them from:"
    info "https://github.com/th3cavalry/GZ302-Linux-Setup/tree/main/modules"
}

# --- Main Execution ---

check_root
check_library

MODE="full"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --full) MODE="full" ;;
        --minimal) MODE="minimal" ;;
        --cc) MODE="cc" ;;
        --tools) MODE="cc" ;; # Backward compatibility
        -h|--help) show_help; exit 0 ;;
        *) 
            echo "❌ Unknown parameter: $1"
            echo
            show_help
            exit 1
            ;;
    esac
    shift
done

# Display banner
echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      GZ302 Linux Setup - Unified Installer v4.0.0        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo
info "Installation mode: $MODE"
echo

# Execute based on mode
case $MODE in
    full)
        info "Installing: Hardware fixes + Command Center + GUI"
        echo
        install_fixes
        echo
        install_tools
        echo
        install_modules
        ;;
    minimal)
        info "Installing: Hardware fixes only (no GUI)"
        echo
        install_fixes
        ;;
    cc)
        info "Installing: Command Center + GUI (no kernel patches)"
        echo
        install_tools
        ;;
esac

# Final message
echo
print_section "Installation Complete"
success "GZ302 Linux Setup has been installed successfully!"
echo
info "What's next?"
case $MODE in
    full|cc)
        echo "  1. Reboot your system"
        echo "  2. Look for 'GZ302 Command Center' in your system tray"
        echo "  3. Try these commands:"
        echo "     • pwrcfg status    - Check power profile"
        echo "     • rrcfg status     - Check refresh rate"
        echo "     • gz302-rgb help   - RGB control"
        ;;
    minimal)
        echo "  1. Reboot your system"
        echo "  2. Your hardware should now work properly"
        echo "  3. To install Command Center later, run:"
        echo "     sudo ./install.sh --cc"
        ;;
esac
echo
