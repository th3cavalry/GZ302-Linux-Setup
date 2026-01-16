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
ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight*", RUN+="/bin/chmod 0666 /sys/%p/brightness"
ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight*", RUN+="/bin/chmod 0666 /sys/%p/brightness"

# Lightbar-specific HID device (direct control)
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"
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

# --- Install RGB restore service ---
install_restore_service() {
    print_subsection "Installing RGB Restore Service"
    
    # Create config directory with permissive permissions
    # This allows the GUI/CLI (running as user) to save settings without sudo
    mkdir -p "$CONFIG_DIR"
    chmod 777 "$CONFIG_DIR"
    completed_item "Config directory created with user write permissions"
    
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

KBD_CONFIG="/etc/gz302/rgb-keyboard.conf"
WIN_CONFIG="/etc/gz302/rgb-window.conf"
KEYBOARD_RGB="/usr/local/bin/gz302-rgb"
WINDOW_RGB="/usr/local/bin/gz302-rgb-window"

# Ensure config files are user-writable if they exist
touch "$KBD_CONFIG" "$WIN_CONFIG" 2>/dev/null || true
chmod 666 "$KBD_CONFIG" "$WIN_CONFIG" 2>/dev/null || true

# Wait for hardware to be ready
sleep 2

# Enable keyboard brightness
for brightness_file in /sys/class/leds/*::kbd_backlight/brightness; do
    if [[ -f "$brightness_file" ]]; then
        echo 3 > "$brightness_file" 2>/dev/null || true
    fi
done

# Restore keyboard RGB settings
if [[ -f "$KBD_CONFIG" && -x "$KEYBOARD_RGB" ]]; then
    # Safe parsing
    KEYBOARD_COMMAND=$(grep "^KEYBOARD_COMMAND=" "$KBD_CONFIG" 2>/dev/null | cut -d"=" -f2- | tr -d "\"" | tr -d "'" || true)
    
    # Restore keyboard RGB
    if [[ -n "${KEYBOARD_COMMAND:-}" ]]; then
        read -r -a CMD_ARGS <<< "$KEYBOARD_COMMAND"
        "$KEYBOARD_RGB" "${CMD_ARGS[@]}" 2>/dev/null || true
    fi
fi

# Restore window RGB settings
if [[ -f "$WIN_CONFIG" && -x "$WINDOW_RGB" ]]; then
    # Try color first
    WINDOW_COLOR=$(grep "^WINDOW_COLOR=" "$WIN_CONFIG" 2>/dev/null | cut -d"=" -f2- | tr -d "\"" | tr -d "'" || true)
    if [[ -n "${WINDOW_COLOR:-}" ]]; then
        # Convert comma to space for arguments
        IFS=',' read -r R G B <<< "$WINDOW_COLOR"
        "$WINDOW_RGB" --color "$R" "$G" "$B" 2>/dev/null || true
    else
        # Try brightness
        WINDOW_BRIGHTNESS=$(grep "^WINDOW_BRIGHTNESS=" "$WIN_CONFIG" 2>/dev/null | cut -d"=" -f2- | tr -d "\"" | tr -d "'" || true)
        if [[ -n "${WINDOW_BRIGHTNESS:-}" ]]; then
            "$WINDOW_RGB" --brightness "$WINDOW_BRIGHTNESS" 2>/dev/null || true
        fi
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
After=multi-user.target gz302-lightbar-reset.service
Wants=gz302-lightbar-reset.service
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

# --- Install lightbar reset service ---
# This is critical: asusd locks the lightbar HID device, preventing direct control.
# Unbinding and rebinding the device to the asus driver resets it and allows our commands to work.
install_lightbar_reset_service() {
    print_subsection "Installing Lightbar Reset Service"
    
    local reset_service_path="${SYSTEMD_DIR}/gz302-lightbar-reset.service"
    
    cat > "$reset_service_path" << 'EOF'
[Unit]
Description=Reset GZ302 Lightbar HID device for direct control
After=asusd.service
Wants=asusd.service

[Service]
Type=oneshot
# Unbind and rebind the N-KEY device (lightbar) from the asus HID driver
# This resets the device and allows direct HID commands to work
ExecStart=/bin/bash -c 'DEV=$(ls /sys/bus/hid/drivers/asus/ 2>/dev/null | grep "0B05:18C6" | head -1); if [ -n "$DEV" ]; then echo "$DEV" > /sys/bus/hid/drivers/asus/unbind 2>/dev/null; sleep 0.5; echo "$DEV" > /sys/bus/hid/drivers/asus/bind 2>/dev/null; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable gz302-lightbar-reset.service 2>/dev/null || true
    completed_item "Lightbar reset service installed and enabled"
}

# --- Install suspend/resume hook ---
install_suspend_hook() {
    print_subsection "Installing Suspend/Resume Hook"
    
    local hook_dir="/usr/lib/systemd/system-sleep"
    local hook_path="${hook_dir}/gz302-reset.sh"
    
    if [[ ! -d "$hook_dir" ]]; then
        # On some distros this might be different, but it's standard systemd
        mkdir -p "$hook_dir"
    fi
    
    cat > "$hook_path" << 'EOF'
#!/bin/bash
# GZ302 Resume Reset Hook
# Resets keyboard and lightbar USB devices on resume to fix touchpad and RGB

case "$1" in
    post)
        # 1. Reset Keyboard/Touchpad (0b05:1a30)
        # This fixes the touchpad not working after sleep
        for dev in /sys/bus/usb/devices/*; do
            if [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]]; then
                vid=$(cat "$dev/idVendor")
                pid=$(cat "$dev/idProduct")
                if [[ "$vid" == "0b05" && "$pid" == "1a30" ]]; then
                    echo "Resetting Keyboard/Touchpad ($dev)..."
                    echo 0 > "$dev/authorized"
                    sleep 0.5
                    echo 1 > "$dev/authorized"
                fi
            fi
        done
        
        # 2. Reset Lightbar (0b05:18c6)
        # This ensures the lightbar is ready for commands
        for dev in /sys/bus/usb/devices/*; do
            if [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]]; then
                vid=$(cat "$dev/idVendor")
                pid=$(cat "$dev/idProduct")
                if [[ "$vid" == "0b05" && "$pid" == "18c6" ]]; then
                    echo "Resetting Lightbar ($dev)..."
                    echo 0 > "$dev/authorized"
                    sleep 0.5
                    echo 1 > "$dev/authorized"
                fi
            fi
        done
        
        # 3. Restore RGB settings
        # Wait a moment for devices to reappear
        sleep 2
        systemctl restart gz302-rgb-restore.service
        ;;
esac
exit 0
EOF

    chmod +x "$hook_path"
    completed_item "Suspend hook installed to $hook_path"
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
        arch)          install_keyboard_rgb_arch ;;
        debian|ubuntu) install_keyboard_rgb_debian ;;
        fedora)        install_keyboard_rgb_fedora ;;
        opensuse)      install_keyboard_rgb_opensuse ;;
        *)             error "Unsupported distribution: $distro" ;;
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
    
    # Step 6: Install lightbar reset service (fixes asusd locking the device)
    print_section "Step 6: Lightbar Reset Service"
    install_lightbar_reset_service
    
    # Step 7: Install suspend/resume hook
    print_section "Step 7: Suspend/Resume Hook"
    install_suspend_hook
    
    # Summary
    print_section "Installation Complete"
    echo
    print_keyval "Keyboard RGB" "$KEYBOARD_RGB_PATH"
    print_keyval "Rear Window RGB" "$WINDOW_RGB_PATH"
    print_keyval "udev Rules" "$UDEV_RULES_PATH"
    print_keyval "Sudoers" "$SUDOERS_PATH"
    print_keyval "Restore Service" "gz302-rgb-restore.service"
    print_keyval "Lightbar Reset" "gz302-lightbar-reset.service"
    print_keyval "Suspend Hook" "/usr/lib/systemd/system-sleep/gz302-reset.sh"
    
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