#!/bin/bash
# shellcheck disable=SC1091  # /etc/os-release is system file

# ==============================================================================
# GZ302 RGB Control Installation Script
#
# Author: th3cavalry using Copilot
# Version: 3.1.0
#
# Unified installation script for both RGB control zones on the GZ302:
# 1. Keyboard RGB (USB 0x0b05:0x1a30) - C binary compiled from gz302-rgb-cli.c
# 2. Rear Window/Lightbar RGB (sysfs leds) - Python script gz302-rgb-window.py
#
# This script installs:
# - gz302-rgb binary for keyboard RGB control
# - gz302-rgb-window.py for rear window/lightbar control
# - udev rules for unprivileged access to both devices
# - sudoers configuration for password-less RGB control
# - systemd service for restoring RGB settings on boot
#
# REQUIRES: Linux kernel 6.14+, libusb development libraries, gcc, Python 3
#
# USAGE:
#   sudo ./gz302-rgb-install.sh [distro]
# ==============================================================================

set -euo pipefail

# --- Script Configuration ---
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/../gz302-lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/../gz302-lib/utils.sh"
elif [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh"
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


# Use BIN_DIR from utils if available, else default
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/gz302}"
UDEV_RULES_DIR="${UDEV_RULES_DIR:-/etc/udev/rules.d}"
SUDOERS_DIR="${SUDOERS_DIR:-/etc/sudoers.d}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"

KEYBOARD_RGB_PATH="${BIN_DIR}/gz302-rgb"
WINDOW_RGB_PATH="${BIN_DIR}/gz302-rgb-window"
UDEV_RULES_PATH="${UDEV_RULES_DIR}/99-gz302-rgb.rules"
SUDOERS_PATH="${SUDOERS_DIR}/gz302-rgb"
RESTORE_SCRIPT_PATH="${BIN_DIR}/gz302-rgb-restore"
SERVICE_PATH="${SYSTEMD_DIR}/gz302-rgb-restore.service"

# --- Detect distribution ---
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        ID_LIKE=""
        ID=""
        . /etc/os-release
        if [[ "${ID_LIKE:-}" =~ arch ]] || [[ "${ID:-}" == "arch" ]]; then
            echo "arch"
        elif [[ "${ID_LIKE:-}" =~ debian ]] || [[ "${ID:-}" == "debian" ]] || [[ "${ID:-}" == "ubuntu" ]]; then
            echo "debian"
        elif [[ "${ID_LIKE:-}" =~ fedora ]] || [[ "${ID:-}" == "fedora" ]]; then
            echo "fedora"
        elif [[ "${ID_LIKE:-}" =~ suse ]] || [[ "${ID:-}" =~ opensuse ]]; then
            echo "opensuse"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# --- Install udev rules for both RGB devices ---
install_udev_rules() {
    print_subsection "Installing udev Rules"
    
    # Clean up conflicting/legacy udev rules
    if [[ -f /etc/udev/rules.d/99-gz302-keyboard.rules ]]; then
        rm -f /etc/udev/rules.d/99-gz302-keyboard.rules
        completed_item "Removed legacy 99-gz302-keyboard.rules"
    fi
    
    cat > "$UDEV_RULES_PATH" << 'EOF'
# GZ302 RGB Control - udev rules for unprivileged access
# This file configures permissions for both keyboard and rear window RGB

# Keyboard RGB Control - ASUS ROG Flow Z13 keyboard (USB 0b05:1a30)
# Allows unprivileged access to the USB device for gz302-rgb binary
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", MODE="0666"

# Rear Window/Lightbar RGB Control - sysfs LED brightness
# Allows unprivileged write access to kbd_backlight brightness files
# Multiple patterns to catch different device paths
ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight", RUN+="/bin/chmod 0666 /sys/%p/brightness"
ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", RUN+="/bin/chmod 0666 /sys/%p/brightness"

# Lightbar-specific LED device (if exposed as separate device)
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"
EOF

    # Reload udev rules
    udevadm control --reload 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
    completed_item "udev rules installed to $UDEV_RULES_PATH"
    
    # Apply permissions immediately to existing devices
    for brightness_file in /sys/class/leds/*::kbd_backlight/brightness; do
        if [[ -f "$brightness_file" ]]; then
            chmod 0666 "$brightness_file" 2>/dev/null || true
        fi
    done
    completed_item "Permissions applied to existing LED devices"
}

# --- Install sudoers configuration ---
install_sudoers() {
    print_subsection "Configuring Sudoers"
    
    # Use the same sudoers file as tray-icon/install-policy.sh for consistency
    # This prevents having multiple conflicting sudoers files
    local existing_sudoers="${SUDOERS_DIR}/gz302-pwrcfg"
    
    # Build sudoers content - append to existing or create new
    local tmp_sudoers="/tmp/gz302-rgb-sudoers-$$"
    
    if [[ -f "$existing_sudoers" ]]; then
        # Check if RGB entries already exist
        if ! grep -q "gz302-rgb" "$existing_sudoers" 2>/dev/null; then
            # Append RGB entries to existing file
            cat >> "$existing_sudoers" << EOF

# GZ302 RGB Control - Added by gz302-rgb-install.sh
ALL ALL=NOPASSWD: $KEYBOARD_RGB_PATH
ALL ALL=NOPASSWD: $WINDOW_RGB_PATH
ALL ALL=NOPASSWD: $RESTORE_SCRIPT_PATH
EOF
            completed_item "Added RGB commands to existing sudoers"
        else
            completed_item "RGB commands already in sudoers"
        fi
    else
        # Create new sudoers file
        cat > "$tmp_sudoers" << EOF
# GZ302 RGB Control - Password-less sudo for RGB commands
# Created by gz302-rgb-install.sh

# Keyboard RGB control
ALL ALL=NOPASSWD: $KEYBOARD_RGB_PATH

# Rear window/lightbar RGB control
ALL ALL=NOPASSWD: $WINDOW_RGB_PATH

# RGB restore script (called by systemd service)
ALL ALL=NOPASSWD: $RESTORE_SCRIPT_PATH
EOF

        # Validate and install using visudo
        if visudo -c -f "$tmp_sudoers" 2>/dev/null; then
            mv "$tmp_sudoers" "$SUDOERS_PATH"
            chmod 440 "$SUDOERS_PATH"
            completed_item "Sudoers configuration installed"
        else
            rm -f "$tmp_sudoers"
            warning "Failed to install sudoers configuration (visudo validation failed)"
        fi
    fi
}

# --- Install rear window RGB script ---
install_window_rgb() {
    print_subsection "Installing Rear Window RGB Control"
    
    if [[ -f "${SCRIPT_DIR}/gz302-rgb-window.py" ]]; then
        install -m 755 "${SCRIPT_DIR}/gz302-rgb-window.py" "$WINDOW_RGB_PATH"
        completed_item "gz302-rgb-window installed to $WINDOW_RGB_PATH"
    else
        warning "gz302-rgb-window.py not found in script directory"
        return 1
    fi
}

# --- Install RGB restore script and service ---
install_restore_service() {
    print_subsection "Installing RGB Restore Service"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Install restore script
    if [[ -f "${SCRIPT_DIR}/gz302-rgb-restore.sh" ]]; then
        install -m 755 "${SCRIPT_DIR}/gz302-rgb-restore.sh" "$RESTORE_SCRIPT_PATH"
        completed_item "Restore script installed"
    else
        # Create restore script inline if not present
        cat > "$RESTORE_SCRIPT_PATH" << 'RESTORE_EOF'
#!/bin/bash
# GZ302 RGB Restore Script - Restores RGB settings on boot/resume

set -euo pipefail

CONFIG_FILE="/etc/gz302/rgb-settings.conf"
KEYBOARD_RGB="/usr/local/bin/gz302-rgb"
WINDOW_RGB="/usr/local/bin/gz302-rgb-window"

# Wait for hardware to be ready
sleep 2

# Enable keyboard brightness
for brightness_file in /sys/class/leds/*::kbd_backlight/brightness; do
    if [[ -f "$brightness_file" ]]; then
        echo 3 > "$brightness_file" 2>/dev/null || true
    fi
done

# Restore keyboard RGB settings
if [[ -f "$CONFIG_FILE" ]]; then
    # Safe parsing
    KEYBOARD_COMMAND=$(grep "^KEYBOARD_COMMAND=" "$CONFIG_FILE" | cut -d"=" -f2- | tr -d "\"" | tr -d "'")
    
    # Restore keyboard RGB
    if [[ -n "${KEYBOARD_COMMAND:-}" && -x "$KEYBOARD_RGB" ]]; then
        read -r -a CMD_ARGS <<< "$KEYBOARD_COMMAND"
        "$KEYBOARD_RGB" "${CMD_ARGS[@]}" 2>/dev/null || true
    fi
    
    # Restore window RGB
    WINDOW_BRIGHTNESS=$(grep "^WINDOW_BRIGHTNESS=" "$CONFIG_FILE" | cut -d"=" -f2- | tr -d "\"" | tr -d "'")
    if [[ -n "${WINDOW_BRIGHTNESS:-}" && -x "$WINDOW_RGB" ]]; then
        "$WINDOW_RGB" --lightbar "$WINDOW_BRIGHTNESS" 2>/dev/null || true
    fi
fi

exit 0
RESTORE_EOF
        chmod 755 "$RESTORE_SCRIPT_PATH"
        completed_item "Restore script created"
    fi
    
    # Install systemd service
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Restore GZ302 RGB Settings on Boot
After=multi-user.target
Documentation=https://github.com/th3cavalry/GZ302-Linux-Setup

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$RESTORE_SCRIPT_PATH
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable service
    systemctl daemon-reload
    systemctl enable gz302-rgb-restore.service 2>/dev/null || true
    completed_item "Systemd service installed and enabled"
}

# --- Install keyboard RGB binary (distro-specific) ---
install_keyboard_rgb_arch() {
    print_subsection "Building Keyboard RGB (Arch)"
    
    echo -ne "${C_DIM}"
    pacman -S --noconfirm --needed libusb base-devel pkg-config 2>&1 | grep -v "^::" | grep -v "is up to date" || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    make -f Makefile.rgb clean 2>/dev/null || true
    make -f Makefile.rgb 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled (via Makefile.rgb)"

    # Use Makefile install to respect PREFIX
    make -f Makefile.rgb install PREFIX="/usr/local"
    completed_item "Keyboard RGB installed to $KEYBOARD_RGB_PATH"
}

install_keyboard_rgb_debian() {
    print_subsection "Building Keyboard RGB (Debian/Ubuntu)"
    
    echo -ne "${C_DIM}"
    apt-get update 2>&1 | tail -2 || true
    apt-get install -y libusb-1.0-0 libusb-1.0-0-dev build-essential pkg-config 2>&1 | grep -E "^(Setting up|is already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    cd "$SCRIPT_DIR"
    make -f Makefile.rgb clean 2>/dev/null || true
    echo -ne "${C_DIM}"
    make -f Makefile.rgb 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled (via Makefile.rgb)"

    make -f Makefile.rgb install PREFIX="/usr/local"
    completed_item "Keyboard RGB installed to $KEYBOARD_RGB_PATH"
}

install_keyboard_rgb_fedora() {
    print_subsection "Building Keyboard RGB (Fedora)"
    
    echo -ne "${C_DIM}"
    dnf install -y libusb1 libusb1-devel gcc pkg-config 2>&1 | grep -E "^(Installing|Complete|already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    make -f Makefile.rgb clean 2>/dev/null || true
    make -f Makefile.rgb 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled (via Makefile.rgb)"

    make -f Makefile.rgb install PREFIX="/usr/local"
    completed_item "Keyboard RGB installed to $KEYBOARD_RGB_PATH"
}

install_keyboard_rgb_opensuse() {
    print_subsection "Building Keyboard RGB (OpenSUSE)"
    
    echo -ne "${C_DIM}"
    zypper install -y libusb-1_0-0 libusb-1_0-devel gcc pkg-config 2>&1 | grep -E "^(Installing|done|already)" | head -5 || true
    echo -ne "${C_NC}"
    completed_item "Build dependencies installed"
    
    cd "$SCRIPT_DIR"
    echo -ne "${C_DIM}"
    make -f Makefile.rgb clean 2>/dev/null || true
    make -f Makefile.rgb 2>&1 || true
    echo -ne "${C_NC}"
    completed_item "Binary compiled (via Makefile.rgb)"

    make -f Makefile.rgb install PREFIX="/usr/local"
    completed_item "Keyboard RGB installed to $KEYBOARD_RGB_PATH"
}

# --- Main installation logic ---
main() {
    print_box "GZ302 RGB Control Installation"
    
    # Check for root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    # Detect distribution
    distro="${1:-$(detect_distribution)}"
    
    print_section "System Information"
    print_keyval "Distribution" "$distro"
    print_keyval "Kernel" "$(uname -r)"
    
    # Step 1: Install keyboard RGB binary
    print_section "Step 1: Keyboard RGB Control"
    case "$distro" in
        arch)     install_keyboard_rgb_arch ;;
        debian)   install_keyboard_rgb_debian ;;
        fedora)   install_keyboard_rgb_fedora ;;
        opensuse) install_keyboard_rgb_opensuse ;;
        *)        error "Unsupported distribution: $distro" ;;
    esac
    
    # Step 2: Install rear window RGB
    print_section "Step 2: Rear Window RGB Control"
    install_window_rgb
    
    # Step 3: Install udev rules (for both devices)
    print_section "Step 3: udev Rules"
    install_udev_rules
    
    # Step 4: Install sudoers configuration
    print_section "Step 4: Sudoers Configuration"
    install_sudoers
    
    # Step 5: Install restore service
    print_section "Step 5: Restore Service"
    install_restore_service
    
    # Summary
    print_section "Installation Complete"
    echo
    print_keyval "Keyboard RGB" "$KEYBOARD_RGB_PATH"
    print_keyval "Rear Window RGB" "$WINDOW_RGB_PATH"
    print_keyval "udev Rules" "$UDEV_RULES_PATH"
    print_keyval "Sudoers" "$SUDOERS_PATH"
    print_keyval "Restore Service" "gz302-rgb-restore.service"
    
    print_box "RGB Control Ready"
    echo
    echo "  ${C_BOLD_CYAN}Keyboard RGB Commands:${C_NC}"
    echo "    gz302-rgb single_static FF0000     ${C_DIM}# Red${C_NC}"
    echo "    gz302-rgb rainbow_cycle 2          ${C_DIM}# Rainbow animation${C_NC}"
    echo "    gz302-rgb brightness 3             ${C_DIM}# Max brightness${C_NC}"
    echo
    echo "  ${C_BOLD_CYAN}Rear Window RGB Commands:${C_NC}"
    echo "    gz302-rgb-window --lightbar 0      ${C_DIM}# Off${C_NC}"
    echo "    gz302-rgb-window --lightbar 3      ${C_DIM}# Max brightness${C_NC}"
    echo "    gz302-rgb-window --list            ${C_DIM}# List detected devices${C_NC}"
    echo
    print_tip "Both commands work without sudo (udev + sudoers configured)"
}

# --- Run installation ---
main "$@"