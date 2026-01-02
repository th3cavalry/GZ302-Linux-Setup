#!/bin/bash
# ==============================================================================
# GZ302 Command Center Installer
# Version: 1.0.0
#
# Installs the complete user-facing toolset for ASUS ROG Flow Z13 (GZ302):
# 1. Power Controls (pwrcfg) - TDP and Power Profile management
# 2. Display Controls (rrcfg) - Refresh Rate and VRR management
# 3. RGB Controls (gz302-rgb) - Keyboard and Lightbar control
# 4. Command Center (Tray Icon) - GUI for all the above
#
# Usage:
#   sudo ./install-command-center.sh
# ==============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/gz302-lib/utils.sh"
else
    echo "gz302-lib/utils.sh not found. Downloading..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-lib/utils.sh"
        chmod +x "${SCRIPT_DIR}/gz302-lib/utils.sh"
        source "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: curl not found."
        exit 1
    fi
fi

# --- Load Libraries ---
load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        echo "Downloading ${lib_name}..."
        mkdir -p "${SCRIPT_DIR}/gz302-lib"
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path"
        chmod +x "$lib_path"
        source "$lib_path"
    fi
}

load_library "power-manager.sh"
load_library "display-manager.sh"

# --- Helper Functions ---

install_dependencies() {
    print_subsection "Installing System Dependencies"
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            echo "Installing dependencies for Arch Linux..."
            pacman -S --noconfirm --needed python-pyqt6 python-psutil libusb \
                libnotify base-devel git cmake 2>/dev/null || true
            # Check for AUR helpers for ryzenadj
            if ! command -v ryzenadj >/dev/null 2>&1; then
                echo "Note: 'ryzenadj' will be built from source if not found in AUR"
            fi
            ;;
        debian)
            echo "Installing dependencies for Debian/Ubuntu..."
            apt-get update
            apt-get install -y python3-pyqt6 python3-psutil libusb-1.0-0-dev \
                libnotify-bin build-essential git cmake libpci-dev
            ;;
        fedora)
            echo "Installing dependencies for Fedora..."
            dnf install -y python3-pyqt6 python3-psutil libusb1-devel \
                libnotify gcc gcc-c++ git cmake pciutils-devel
            ;;
        opensuse)
            echo "Installing dependencies for OpenSUSE..."
            zypper install -y python3-qt6 python3-psutil libusb-1_0-devel \
                libnotify-tools gcc gcc-c++ git cmake pciutils-devel
            ;;
        *)
            warning "Unsupported distribution: $distro. Attempting to proceed..."
            ;;
    esac
    completed_item "Dependencies installed"
}

install_power_tools() {
    print_section "Step 1: Power Controls (pwrcfg)"
    
    # Install ryzenadj (TDP control backend)
    local distro
    distro=$(detect_distribution)
    
    if ! command -v ryzenadj >/dev/null 2>&1; then
        info "Installing ryzenadj..."
        power_install_ryzenadj "$distro"
    fi
    
    # Install pwrcfg script
    info "Installing pwrcfg CLI..."
    power_get_pwrcfg_script > /usr/local/bin/pwrcfg
    chmod +x /usr/local/bin/pwrcfg
    power_init_config
    
    # Install systemd services for persistence
    cat > /etc/systemd/system/pwrcfg-auto.service <<EOF
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target
Wants=pwrcfg-monitor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg-restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
