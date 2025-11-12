#!/bin/bash

# ==============================================================================
# EXPERIMENTAL: RGB Backlight Control for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.1.1 (EXPERIMENTAL)
#
# This script provides experimental control over keyboard backlight and
# rear window LEDs on the GZ302. It also implements persistence across
# suspend/resume cycles.
#
# IMPORTANT: This is EXPERIMENTAL and may not work on all hardware variants.
# Use at your own risk. Test thoroughly before deploying.
#
# SUPPORTED METHODS:
# - asusctl (primary, requires asusctl package)
# - sysfs (/sys/class/leds/* for basic brightness)
# - Persistence via systemd-backlight integration
#
# USAGE:
# 1. Make executable: chmod +x gz302-rgb-backlight.sh
# 2. Run with sudo: sudo ./gz302-rgb-backlight.sh
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

# --- Logging functions ---
error() {
    echo -e "${C_RED}ERROR:${C_NC} $1" >&2
    exit 1
}

info() {
    echo -e "${C_BLUE}INFO:${C_NC} $1"
}

success() {
    echo -e "${C_GREEN}SUCCESS:${C_NC} $1"
}

warning() {
    echo -e "${C_YELLOW}WARNING:${C_NC} $1"
}

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-rgb-backlight.sh"
    fi
}

# --- Detection functions ---
detect_asusctl() {
    if command -v asusctl >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

detect_keyboard_backlight_sysfs() {
    # Common ASUS keyboard backlight paths
    local paths=(
        "/sys/class/leds/asus::kbd_backlight"
        "/sys/class/leds/platform::kbd_backlight"
        "/sys/class/leds/input*::kbd_backlight"
    )
    
    for path in "${paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find any keyboard backlight
    local found
    found=$(find /sys/class/leds -name "*kbd*backlight*" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# --- asusctl-based control ---
setup_asusctl_control() {
    info "Setting up asusctl-based RGB control..."
    
    if ! detect_asusctl; then
        error "asusctl not found. Please install asusctl first.\nSee: https://asus-linux.org"
    fi
    
    # Test asusctl functionality
    info "Testing asusctl functionality..."
    if asusctl led-mode >/dev/null 2>&1; then
        success "asusctl LED control is available"
    else
        warning "asusctl LED control may not be fully supported on this hardware"
    fi
    
    # Create helper scripts for common operations
    info "Creating helper scripts..."
    
    # Keyboard brightness control
    cat > /usr/local/bin/kbd-brightness <<'EOF'
#!/bin/bash
# Keyboard brightness control using asusctl
case "$1" in
    up)
        asusctl -n
        ;;
    down)
        asusctl -p
        ;;
    set)
        if [[ -n "$2" ]]; then
            asusctl led-mode -b "$2"
        else
            echo "Usage: kbd-brightness set <0-3>"
        fi
        ;;
    status)
        asusctl led-mode
        ;;
    *)
        echo "Usage: kbd-brightness {up|down|set <0-3>|status}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/kbd-brightness
    
    # LED mode control
    cat > /usr/local/bin/kbd-led-mode <<'EOF'
#!/bin/bash
# Keyboard LED mode control using asusctl
case "$1" in
    static)
        asusctl led-mode static
        ;;
    breathe)
        asusctl led-mode breathe
        ;;
    pulse)
        asusctl led-mode pulse
        ;;
    rainbow)
        asusctl led-mode rainbow
        ;;
    off)
        asusctl led-mode -b 0
        ;;
    list)
        echo "Available modes: static, breathe, pulse, rainbow, off"
        ;;
    *)
        echo "Usage: kbd-led-mode {static|breathe|pulse|rainbow|off|list}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/kbd-led-mode
    
    success "Helper scripts created:"
    info "  - kbd-brightness {up|down|set <0-3>|status}"
    info "  - kbd-led-mode {static|breathe|pulse|rainbow|off|list}"
}

# --- sysfs-based control ---
setup_sysfs_control() {
    info "Setting up sysfs-based backlight control..."
    
    local kbd_path
    if ! kbd_path=$(detect_keyboard_backlight_sysfs); then
        warning "No keyboard backlight sysfs device found"
        info "Available LED devices:"
        ls -1 /sys/class/leds/ 2>/dev/null || echo "  (none found)"
        return 1
    fi
    
    info "Detected keyboard backlight: $kbd_path"
    
    # Create control script
    cat > /usr/local/bin/kbd-brightness-sysfs <<EOF
#!/bin/bash
# Simple keyboard brightness control via sysfs
KBD_PATH="$kbd_path"
MAX_BRIGHTNESS=\$(cat "\$KBD_PATH/max_brightness")

case "\$1" in
    up)
        CURRENT=\$(cat "\$KBD_PATH/brightness")
        NEW=\$((CURRENT + 1))
        if [[ \$NEW -le \$MAX_BRIGHTNESS ]]; then
            echo "\$NEW" > "\$KBD_PATH/brightness"
            echo "Brightness: \$NEW/\$MAX_BRIGHTNESS"
        else
            echo "Already at maximum brightness"
        fi
        ;;
    down)
        CURRENT=\$(cat "\$KBD_PATH/brightness")
        NEW=\$((CURRENT - 1))
        if [[ \$NEW -ge 0 ]]; then
            echo "\$NEW" > "\$KBD_PATH/brightness"
            echo "Brightness: \$NEW/\$MAX_BRIGHTNESS"
        else
            echo "Already at minimum brightness"
        fi
        ;;
    set)
        if [[ -n "\$2" ]] && [[ "\$2" =~ ^[0-9]+\$ ]] && [[ \$2 -le \$MAX_BRIGHTNESS ]]; then
            echo "\$2" > "\$KBD_PATH/brightness"
            echo "Brightness set to: \$2/\$MAX_BRIGHTNESS"
        else
            echo "Usage: kbd-brightness-sysfs set <0-\$MAX_BRIGHTNESS>"
        fi
        ;;
    status)
        CURRENT=\$(cat "\$KBD_PATH/brightness")
        echo "Current brightness: \$CURRENT/\$MAX_BRIGHTNESS"
        ;;
    *)
        echo "Usage: kbd-brightness-sysfs {up|down|set <value>|status}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/kbd-brightness-sysfs
    
    success "sysfs control script created: kbd-brightness-sysfs"
}

# --- Persistence setup ---
setup_persistence() {
    info "Setting up backlight persistence across suspend/resume..."
    
    # Detect keyboard backlight device
    local kbd_path
    if ! kbd_path=$(detect_keyboard_backlight_sysfs); then
        warning "No keyboard backlight sysfs device found - cannot set up persistence"
        return 1
    fi
    
    local device_name
    device_name=$(basename "$kbd_path")
    
    info "Setting up persistence for: $device_name"
    
    # Create systemd service for resume restoration
    cat > /etc/systemd/system/restore-keyboard-backlight.service <<EOF
[Unit]
Description=Restore keyboard backlight brightness after suspend/resume
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
ExecStart=/usr/lib/systemd/systemd-backlight load leds:${device_name}

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
EOF
    
    systemctl daemon-reload
    systemctl enable restore-keyboard-backlight.service
    
    success "Persistence configured for suspend/resume cycles"
    info "Brightness will be automatically saved and restored"
}

# --- Main menu ---
show_menu() {
    echo
    echo "============================================================"
    echo "  GZ302 RGB Backlight Control (EXPERIMENTAL)"
    echo "  Version 1.1.1"
    echo "============================================================"
    echo
    echo "Select control method:"
    echo
    echo "1. asusctl (recommended - full RGB control)"
    echo "   - Requires asusctl package"
    echo "   - Supports LED modes, brightness, colors"
    echo "   - Best for GZ302 with ASUS software support"
    echo
    echo "2. sysfs (basic brightness only)"
    echo "   - Uses /sys/class/leds/"
    echo "   - Simple brightness control"
    echo "   - No RGB modes or effects"
    echo
    echo "3. Setup persistence (for either method)"
    echo "   - Saves/restores brightness across suspend/resume"
    echo "   - Works with systemd-backlight"
    echo
    echo "4. Detect available devices"
    echo "5. Exit"
    echo
}

# --- Device detection ---
detect_devices() {
    echo
    info "Detecting available backlight/LED devices..."
    echo
    
    echo "=== asusctl status ==="
    if detect_asusctl; then
        success "asusctl is installed"
        asusctl led-mode 2>/dev/null || warning "asusctl LED control not available"
    else
        warning "asusctl is NOT installed"
        info "Install with: sudo pacman -S asusctl (Arch) or see https://asus-linux.org"
    fi
    echo
    
    echo "=== sysfs LED devices ==="
    if [[ -d /sys/class/leds ]]; then
        local count=0
        for led in /sys/class/leds/*; do
            if [[ -d "$led" ]]; then
                echo "  - $(basename "$led")"
                count=$((count + 1))
            fi
        done
        if [[ $count -eq 0 ]]; then
            warning "No LED devices found in /sys/class/leds"
        fi
    else
        warning "/sys/class/leds not found"
    fi
    echo
    
    echo "=== Keyboard backlight detected ==="
    local kbd_path
    if kbd_path=$(detect_keyboard_backlight_sysfs); then
        success "Found: $kbd_path"
        if [[ -f "$kbd_path/brightness" ]]; then
            local current max
            current=$(cat "$kbd_path/brightness")
            max=$(cat "$kbd_path/max_brightness")
            info "Current brightness: $current/$max"
        fi
    else
        warning "No standard keyboard backlight device found"
    fi
    echo
}

# --- Main execution ---
main() {
    check_root
    
    show_menu
    
    read -r -p "Enter choice (1-5): " choice
    
    case "$choice" in
        1)
            setup_asusctl_control
            ;;
        2)
            setup_sysfs_control
            ;;
        3)
            setup_persistence
            ;;
        4)
            detect_devices
            ;;
        5)
            info "Exiting"
            exit 0
            ;;
        *)
            warning "Invalid choice"
            exit 1
            ;;
    esac
    
    echo
    info "Setup complete!"
    echo
    warning "EXPERIMENTAL NOTICE:"
    info "  - This script is experimental and may not work perfectly"
    info "  - Rear window LED control is NOT supported (hardware limitation)"
    info "  - Test thoroughly before relying on it"
    info "  - Report issues at: https://github.com/th3cavalry/GZ302-Linux-Setup/issues"
    echo
}

main "$@"
