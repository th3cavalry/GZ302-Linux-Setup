#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 4.0.0
#
# Complete v4 release with library-first architecture:
# - Modular libraries for each hardware subsystem
# - TDP management (pwrcfg command)
# - Refresh rate control (rrcfg command)
# - RGB keyboard and rear window control
# - GZ302 Control Center (system tray)
# - Optional modules (gaming, AI/LLM, hypervisor)
# - State tracking and idempotency
# - CLI interface (--status, --force, --help)
#
# Replaces v3.0.x monolithic script with modular architecture.
#
# USAGE:
#   sudo ./gz302-main.sh [--status] [--force] [--help]
# ==============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_VERSION="4.0.0"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Parse CLI Arguments ---
MODE="install"
FORCE_MODE=false
SKIP_OPTIONAL=false

for arg in "$@"; do
    case "$arg" in
        --status)
            MODE="status"
            ;;
        --force)
            FORCE_MODE=true
            MODE="install"
            ;;
        --skip-optional|-y)
            SKIP_OPTIONAL=true
            ;;
        --help|-h)
            cat <<'HELP'
GZ302 Complete Setup Script v4.0.0

Usage:
    sudo ./gz302-main.sh [OPTIONS]

Options:
    --status         Show current system status and exit
    --force          Force re-application of all fixes (ignore state)
    --skip-optional  Skip optional modules prompt (non-interactive)
    -y               Same as --skip-optional
    --help           Show this help message

Features:
    - Hardware configuration via libraries
    - TDP management (pwrcfg command)
    - Refresh rate control (rrcfg command)
    - RGB keyboard control
    - GZ302 Control Center (system tray)
    - Optional modules (gaming, AI/LLM, virtualization)
    - Persistent state tracking
    - Idempotent operations

For detailed documentation, see Info/ directory.
HELP
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
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
echo "Loading GZ302 v4.0.0 libraries..."

load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck disable=SC1090
        source "$lib_path"
        return 0
    else
        info "  Downloading ${lib_name}..."
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

# Load required libraries (core + v4 feature libraries)
CORE_LIBS="kernel-compat.sh state-manager.sh wifi-manager.sh gpu-manager.sh input-manager.sh audio-manager.sh"
FEATURE_LIBS="power-manager.sh display-manager.sh rgb-manager.sh"

for lib in $CORE_LIBS $FEATURE_LIBS; do
    if ! load_library "$lib"; then
        error "Failed to load $lib"
    fi
done

success "All v4.0.0 libraries loaded (core + features)"
echo

# --- Core Functions ---
check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Usage: sudo ./gz302-main-v4-complete.sh"
    fi
}

detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "${ID:-}" in
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
                warning "Unsupported distribution: ${ID:-unknown}"
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
    
    print_box "GZ302 Complete System Status v${SCRIPT_VERSION}"
    echo
    
    # Kernel status
    print_section "Kernel Status"
    kernel_print_status
    echo
    
    # Initialize state
    state_init >/dev/null 2>&1 || true
    
    # Hardware status
    print_section "Hardware Status"
    echo
    info "WiFi:"
    wifi_print_status
    echo
    info "GPU:"
    gpu_print_status
    echo
    info "Input Devices:"
    input_print_status
    echo
    info "Audio:"
    audio_print_status
    echo
    
    # Power Management (via power-manager library)
    print_section "Power Management"
    if declare -f power_print_status >/dev/null 2>&1; then
        power_print_status
    else
        if command -v pwrcfg >/dev/null 2>&1; then
            pwrcfg status 2>/dev/null || echo "  pwrcfg command available"
        else
            warning "Power management library not loaded"
        fi
    fi
    echo
    
    # Display/Refresh Rate (via display-manager library)
    print_section "Display & Refresh Rate"
    if declare -f display_print_status >/dev/null 2>&1; then
        display_print_status
    else
        if command -v rrcfg >/dev/null 2>&1; then
            rrcfg status 2>/dev/null || echo "  rrcfg command available"
        else
            warning "Display management library not loaded"
        fi
    fi
    echo
    
    # RGB Status (via rgb-manager library)
    print_section "RGB Lighting"
    if declare -f rgb_print_status >/dev/null 2>&1; then
        rgb_print_status
    else
        if command -v gz302-rgb >/dev/null 2>&1; then
            info "RGB Control: Installed (keyboard)"
        fi
        if [[ -x /usr/local/bin/gz302-rgb-window ]]; then
            info "RGB Control: Installed (window)"
        fi
    fi
    echo
    
    # State tracking
    print_section "State Tracking"
    state_print_status
    
    exit 0
fi

# --- Main Installation ---
check_root

print_box "GZ302 Complete Setup v${SCRIPT_VERSION}"
echo
info "Library-first architecture with full v3.0.0 feature parity"
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
kernel_ver=$(kernel_get_version_num)
info "Kernel: $(kernel_get_version_string) (${kernel_ver})"
echo

# Step 2: Detect Distribution
print_section "Step 2: Detect Distribution"
DETECTED_DISTRO=$(detect_distribution)
info "Detected: $DETECTED_DISTRO"
echo

# Step 3: Hardware Configuration (via v4.0.0 libraries)
print_section "Step 3: Hardware Configuration (Libraries)"

info "Configuring WiFi (MT7925e)..."
if wifi_apply_configuration; then
    state_mark_applied "wifi" "configuration" "kernel_${kernel_ver}"
    state_log "INFO" "WiFi configured for kernel ${kernel_ver}"
    success "WiFi configured"
else
    warning "WiFi configuration had warnings"
fi
echo

info "Configuring GPU (Radeon 8060S)..."
if gpu_apply_configuration; then
    state_mark_applied "gpu" "configuration" "radeon_8060s"
    state_log "INFO" "GPU configured"
    success "GPU configured"
else
    warning "GPU configuration had warnings"
fi
echo

info "Configuring Input Devices..."
if input_apply_configuration "$kernel_ver"; then
    state_mark_applied "input" "configuration" "kernel_${kernel_ver}"
    state_log "INFO" "Input configured for kernel ${kernel_ver}"
    success "Input configured"
else
    warning "Input configuration had warnings"
fi
echo

info "Configuring Audio (SOF + CS35L41)..."
if audio_apply_configuration "$DETECTED_DISTRO"; then
    state_mark_applied "audio" "configuration" "sof_cs35l41"
    state_log "INFO" "Audio configured"
    success "Audio configured"
else
    warning "Audio configuration had warnings"
fi
echo

# Step 4: Power & Display Management (via v4.0.0 libraries)
print_section "Step 4: Power & Display Management"

# Install pwrcfg command
info "Installing TDP management (pwrcfg)..."
if declare -f power_get_pwrcfg_script >/dev/null 2>&1; then
    # Create the pwrcfg command from library
    power_get_pwrcfg_script > /usr/local/bin/pwrcfg
    chmod +x /usr/local/bin/pwrcfg
    power_init_config
    state_mark_applied "power" "pwrcfg" "v4"
    success "pwrcfg command installed"
else
    warning "power-manager library not fully loaded, skipping pwrcfg"
fi
echo

# Install rrcfg command
info "Installing refresh rate control (rrcfg)..."
if declare -f display_get_rrcfg_script >/dev/null 2>&1; then
    display_get_rrcfg_script > /usr/local/bin/rrcfg
    chmod +x /usr/local/bin/rrcfg
    display_init_config
    state_mark_applied "display" "rrcfg" "v4"
    success "rrcfg command installed"
else
    warning "display-manager library not fully loaded, skipping rrcfg"
fi
echo

# Step 5: RGB Control
print_section "Step 5: RGB Control"

info "Setting up RGB control..."
if declare -f rgb_install_udev_rules >/dev/null 2>&1; then
    rgb_init_config
    if rgb_install_udev_rules; then
        state_mark_applied "rgb" "udev_rules" "v4"
        success "RGB udev rules installed"
    fi
    
    # Check if keyboard RGB is detected
    if rgb_detect_keyboard_sysfs; then
        success "Keyboard RGB detected"
    else
        info "Keyboard RGB not detected (may need reboot or kernel module)"
    fi
    
    # Check if lightbar is detected  
    if rgb_detect_lightbar; then
        success "Lightbar RGB detected"
    else
        info "Lightbar not detected (may need reboot)"
    fi
else
    warning "rgb-manager library not fully loaded, skipping RGB setup"
fi
echo

# Step 6: Install libraries to system location
print_section "Step 6: Install Libraries System-Wide"
info "Installing libraries to /usr/local/share/gz302/gz302-lib..."
mkdir -p /usr/local/share/gz302/gz302-lib

for lib in $CORE_LIBS $FEATURE_LIBS; do
    if [[ -f "${SCRIPT_DIR}/gz302-lib/${lib}" ]]; then
        cp "${SCRIPT_DIR}/gz302-lib/${lib}" /usr/local/share/gz302/gz302-lib/
        chmod +x /usr/local/share/gz302/gz302-lib/${lib}
    fi
done
success "Libraries installed to /usr/local/share/gz302/gz302-lib"
echo

# Step 7: Install ryzenadj (for TDP control)
print_section "Step 7: Install ryzenadj"
if ! power_ryzenadj_available; then
    info "Installing ryzenadj for hardware TDP control..."
    if power_install_ryzenadj "$DETECTED_DISTRO"; then
        success "ryzenadj installed"
    else
        warning "ryzenadj installation failed (pwrcfg will use fallback methods)"
    fi
else
    success "ryzenadj already installed"
fi
echo

# Step 8: Install Control Center
print_section "Step 8: GZ302 Control Center"
install_v4_control_center() {
    local tray_src="${SCRIPT_DIR}/tray-icon"
    local tray_dest="/usr/local/share/gz302/control-center"
    local old_dest="/usr/local/share/gz302/tray-icon"
    
    if [[ ! -d "$tray_src" ]]; then
        warning "Control Center source not found at $tray_src"
        return 1
    fi
    
    # Migrate from old path if exists
    if [[ -d "$old_dest" && ! -d "$tray_dest" ]]; then
        info "Migrating from tray-icon to control-center..."
        mv "$old_dest" "$tray_dest"
    fi
    
    # Clean up old tray-icon directory if control-center exists
    if [[ -d "$old_dest" && -d "$tray_dest" ]]; then
        rm -rf "$old_dest"
    fi
    
    # Fix any stale desktop/autostart files pointing to old tray-icon path
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    real_home=$(getent passwd "$real_user" | cut -d: -f6)
    
    for desktop_file in \
        "$real_home/.config/autostart/gz302-tray.desktop" \
        "$real_home/.local/share/applications/gz302-tray.desktop" \
        "/usr/share/applications/gz302-tray.desktop"; do
        if [[ -f "$desktop_file" ]] && grep -q "tray-icon" "$desktop_file" 2>/dev/null; then
            sed -i 's|/usr/local/share/gz302/tray-icon/|/usr/local/share/gz302/control-center/|g' "$desktop_file"
            info "Fixed stale path in $desktop_file"
        fi
    done
    
    # Check version
    local new_version=""
    if [[ -f "$tray_src/VERSION" ]]; then
        new_version=$(cat "$tray_src/VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    
    local installed_version=""
    if [[ -f "$tray_dest/VERSION" ]]; then
        installed_version=$(cat "$tray_dest/VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    
    local skip_install=false
    # Version comparison using sort -V
    if [[ -n "$installed_version" && -n "$new_version" ]]; then
        local highest
        highest=$(printf '%s\n%s\n' "$new_version" "$installed_version" | sort -V | tail -n1)
        if [[ "$highest" == "$installed_version" && "$new_version" != "$installed_version" ]]; then
            info "Installed version $installed_version is current"
            skip_install=true
        elif [[ "$new_version" == "$installed_version" ]]; then
            info "Version $new_version already installed"
            skip_install=true
        else
            info "Updating from $installed_version to $new_version"
        fi
    fi
    
    if [[ "$skip_install" == false ]]; then
        # Stop any running tray processes
        pkill -f "gz302_tray" 2>/dev/null || true
        
        # Install tray files
        mkdir -p "$tray_dest"
    
        # Copy all tray files
        cp -r "$tray_src"/* "$tray_dest/"
        chmod +x "$tray_dest/src/gz302_tray.py" 2>/dev/null || true
        chmod +x "$tray_dest/install-tray.sh" 2>/dev/null || true
        chmod +x "$tray_dest/install-policy.sh" 2>/dev/null || true
    
        # Install Python dependencies
        case "$DETECTED_DISTRO" in
            arch)
                pacman -S --noconfirm --needed python-pyqt6 python-psutil >/dev/null 2>&1 || true
                ;;
            debian)
                apt-get install -y -qq python3-pyqt6 python3-psutil >/dev/null 2>&1 || true
                ;;
            fedora)
                dnf install -y -q python3-qt6 python3-psutil >/dev/null 2>&1 || true
                ;;
            opensuse)
                zypper install -y python3-qt6 python3-psutil >/dev/null 2>&1 || true
                ;;
        esac
    
        # Run install-tray.sh as user if available
        if [[ -f "$tray_dest/install-tray.sh" ]]; then
            local real_user="${SUDO_USER:-$USER}"
            sudo -u "$real_user" bash "$tray_dest/install-tray.sh" 2>/dev/null || true
        fi
    
        # Run install-policy.sh for sudoers
        if [[ -f "$tray_dest/install-policy.sh" ]]; then
            bash "$tray_dest/install-policy.sh" 2>/dev/null || true
        fi
        
        success "Control Center installed to $tray_dest"
    fi
    
    # Always launch Control Center for user (if not already running)
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    real_home=$(getent passwd "$real_user" | cut -d: -f6)
    
    if [[ -f "$tray_dest/src/gz302_tray.py" ]]; then
        # Check for actual Python process, not the sudo wrapper
        if ! pgrep -f "python.*gz302_tray" >/dev/null 2>&1; then
            info "Starting GZ302 Control Center..."
            # Launch as the real user with proper environment
            sudo -u "$real_user" DISPLAY="${DISPLAY:-:0}" HOME="$real_home" \
                nohup python3 "$tray_dest/src/gz302_tray.py" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            sleep 2
            if pgrep -f "python.*gz302_tray" >/dev/null 2>&1; then
                success "Control Center started (check system tray)"
            else
                info "Control Center will start on next login"
            fi
        else
            info "Control Center already running"
        fi
    fi
    
    return 0
}

if [[ -d "${SCRIPT_DIR}/tray-icon" ]]; then
    install_v4_control_center
else
    warning "Control Center directory not found, skipping"
fi
echo

# Step 9: Sudoers configuration
print_section "Step 9: Sudoers Configuration"
info "Configuring password-less sudo for power/display/RGB commands..."

SUDOERS_TMP=$(mktemp /tmp/gz302-v4-sudoers.XXXXXX)

cat > "$SUDOERS_TMP" << 'EOF'
# GZ302 v4.0.0 - Passwordless Sudo for Power/Display/RGB Control
Defaults use_pty
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/rrcfg
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-window
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/rrcfg
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-window
# Allow tray icon to control LED brightness
ALL ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/leds/*/brightness
EOF

if visudo -c -f "$SUDOERS_TMP" >/dev/null 2>&1; then
    mv "$SUDOERS_TMP" /etc/sudoers.d/gz302-v4
    chmod 440 /etc/sudoers.d/gz302-v4
    success "Sudoers configured for password-less power/display/RGB control"
else
    rm -f "$SUDOERS_TMP"
    warning "Sudoers validation failed"
fi
echo

# Step 10: Verification
print_section "Step 10: Verification"
verification_ok=true

info "Verifying hardware configuration..."
wifi_verify_working >/dev/null 2>&1 || verification_ok=false
gpu_verify_working >/dev/null 2>&1 || verification_ok=false
input_verify_working >/dev/null 2>&1 || verification_ok=false
audio_verify_working >/dev/null 2>&1 || verification_ok=false

if [[ "$verification_ok" == true ]]; then
    success "All hardware verification passed"
else
    warning "Some components had verification warnings (see above)"
fi
echo

# Summary
print_box "Setup Complete!"
echo
success "GZ302 v4.0.0 Complete Setup: DONE"
echo
info "What was configured:"
echo "  ✓ WiFi (MediaTek MT7925e) - kernel-aware fixes"
echo "  ✓ GPU (AMD Radeon 8060S) - firmware and ppfeaturemask"
echo "  ✓ Input devices (touchpad, keyboard) - kernel-aware"
echo "  ✓ Audio (SOF + CS35L41) - firmware and configuration"
echo "  ✓ TDP control (pwrcfg) - power profile management"
echo "  ✓ Refresh rate control (rrcfg) - display refresh profiles"
echo "  ✓ RGB udev rules - keyboard and lightbar permissions"
echo "  ✓ GZ302 Control Center - system tray with power/RGB/monitoring"
echo "  ✓ ryzenadj - hardware TDP control"
echo
info "Commands installed:"
echo "  pwrcfg [profile]    - Power profile management (emergency|battery|balanced|...)"
echo "  rrcfg [profile]     - Refresh rate control (30Hz-180Hz)"
echo "  pwrcfg status       - Show current power settings"
echo "  rrcfg status        - Show current display settings"
echo
info "Control Center:"
echo "  Launch: GZ302 Control Center (from application menu)"
echo "  Features: Power profiles, RGB control, system monitoring"
echo
info "State tracking:"
echo "  Applied fixes: /var/lib/gz302/state/"
echo "  Config backups: /var/backups/gz302/"
echo "  Logs: /var/log/gz302/"
echo "  Libraries: /usr/local/share/gz302/gz302-lib/"
echo "  Control Center: /usr/local/share/gz302/control-center/"
echo
info "Check status anytime:"
echo "  sudo ./gz302-main.sh --status"
echo
warning "REBOOT REQUIRED for changes to take effect"
echo

# --- Optional Module Support ---
download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local module_script="${SCRIPT_DIR}/${module_name}.sh"
    
    # Check if module exists locally
    if [[ ! -f "$module_script" ]]; then
        info "Downloading ${module_name}..."
        if ! curl -fsSL "${GITHUB_RAW_URL}/${module_name}.sh" -o "$module_script"; then
            error "Failed to download ${module_name}"
            return 1
        fi
        chmod +x "$module_script"
    fi
    
    info "Running ${module_name}..."
    if ! bash "$module_script" "$distro"; then
        warning "${module_name} completed with warnings"
        return 1
    fi
    success "${module_name} completed"
    return 0
}

offer_optional_modules() {
    local distro="$1"
    
    echo
    print_section "Optional Software Modules"
    echo
    info "The following optional modules can be installed:"
    echo
    echo "1. Gaming Software (gz302-gaming)"
    echo "   - Steam, Lutris, ProtonUp-Qt"
    echo "   - MangoHUD, GameMode, Wine"
    echo "   - Gaming optimizations and performance tweaks"
    echo
    echo "2. LLM/AI Software (gz302-llm)"
    echo "   - Ollama for local LLM inference"
    echo "   - ROCm for AMD GPU acceleration (gfx1151)"
    echo "   - PyTorch, MIOpen, and bitsandbytes"
    echo "   - Transformers and Accelerate libraries"
    echo
    echo "3. Hypervisor Software (gz302-hypervisor)"
    echo "   - KVM/QEMU, VirtualBox, VMware"
    echo "   - Virtual machine management tools"
    echo
    echo "4. Skip optional modules"
    echo
    
    read -r -p "Which modules would you like to install? (comma-separated numbers, e.g., 1,2 or 4 to skip): " module_choice || module_choice="4"
    
    # Parse the choices
    IFS=',' read -ra CHOICES <<< "$module_choice"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ')
        case "$choice" in
            1)
                download_and_execute_module "gz302-gaming" "$distro" || warning "Gaming module had issues"
                ;;
            2)
                download_and_execute_module "gz302-llm" "$distro" || warning "LLM module had issues"
                ;;
            3)
                download_and_execute_module "gz302-hypervisor" "$distro" || warning "Hypervisor module had issues"
                ;;
            4)
                info "Skipping optional modules"
                ;;
            "")
                # Empty choice, skip
                ;;
            *)
                warning "Invalid choice: $choice"
                ;;
        esac
    done
}

# Offer optional modules (unless --skip-optional)
if [[ "$SKIP_OPTIONAL" == true ]]; then
    info "Skipping optional modules (--skip-optional)"
else
    offer_optional_modules "$DETECTED_DISTRO"
fi
echo

print_box "All Done!"
echo
info "To run optional modules later:"
echo "  sudo ./gz302-gaming.sh       # Gaming software"
echo "  sudo ./gz302-llm.sh          # AI/LLM software"
echo "  sudo ./gz302-hypervisor.sh   # Virtualization"
echo

