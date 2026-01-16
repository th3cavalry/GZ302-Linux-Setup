#!/bin/bash
# shellcheck disable=SC2034,SC2059

# ==============================================================================
# GZ302 RGB Manager Library
# Version: 4.0.0
#
# This library provides RGB lighting control for the ASUS ROG Flow Z13 (GZ302):
# - Keyboard RGB via gz302-rgb C binary (aura_keyboard sysfs)
# - Rear Window/Lightbar RGB via HID raw device (N-KEY Device)
#
# Library-First Design:
# - Detection functions (read-only, no system changes)
# - Control functions (idempotent where possible)
# - Status functions (display current state)
#
# Hardware:
# - Keyboard: aura_keyboard sysfs interface, compiled C binary for speed
# - Lightbar: USB 0b05:18c6 (N-KEY Device) via /dev/hidrawX
#
# Usage:
#   source gz302-lib/rgb-manager.sh
#   rgb_detect_keyboard
#   rgb_set_keyboard_color 255 0 0  # Red
#   rgb_set_lightbar_brightness 3
# ==============================================================================

# --- Configuration Paths ---
RGB_CONFIG_DIR="/etc/gz302"
RGB_KEYBOARD_CONFIG="$RGB_CONFIG_DIR/rgb-keyboard.conf"
RGB_WINDOW_CONFIG="$RGB_CONFIG_DIR/rgb-window.conf"
RGB_BINARY_PATH="/usr/local/bin/gz302-rgb"
RGB_WINDOW_SCRIPT="/usr/local/bin/gz302-rgb-window"

# --- USB Device Signatures ---
# These identify the specific USB ports on the GZ302
RGB_LIGHTBAR_PHYS_SIG="usb-0000:c6:00.0-5/input0"
RGB_KEYBOARD_PHYS_SIG="usb-0000:c6:00.0-4/input"
RGB_LIGHTBAR_USB_ID="0b05:18c6"  # N-KEY Device
RGB_KEYBOARD_USB_ID="0b05:1a30"  # Keyboard

# --- Color Presets ---
declare -gA RGB_COLOR_PRESETS
RGB_COLOR_PRESETS[white]="255:255:255"
RGB_COLOR_PRESETS[red]="255:0:0"
RGB_COLOR_PRESETS[green]="0:255:0"
RGB_COLOR_PRESETS[blue]="0:0:255"
RGB_COLOR_PRESETS[purple]="128:0:255"
RGB_COLOR_PRESETS[yellow]="255:255:0"
RGB_COLOR_PRESETS[cyan]="0:255:255"
RGB_COLOR_PRESETS[orange]="255:128:0"
RGB_COLOR_PRESETS[pink]="255:0:128"
RGB_COLOR_PRESETS[off]="0:0:0"

# --- Keyboard RGB Detection ---

# Check if ASUS aura_keyboard sysfs interface exists
# Returns: 0 if found, 1 if not found
rgb_detect_keyboard_sysfs() {
    [[ -d /sys/class/leds/aura_keyboard ]]
}

# Check if gz302-rgb binary is installed
# Returns: 0 if installed, 1 if not
rgb_keyboard_binary_installed() {
    [[ -x "$RGB_BINARY_PATH" ]]
}

# Get keyboard brightness from sysfs
# Returns: brightness value (0-3)
rgb_get_keyboard_brightness() {
    if rgb_detect_keyboard_sysfs; then
        cat /sys/class/leds/aura_keyboard/kbd_rgb_mode_index 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Set keyboard color via gz302-rgb binary
# Args: $1=R $2=G $3=B (0-255 each)
# Returns: 0 on success, 1 on failure
rgb_set_keyboard_color() {
    local r="$1" g="$2" b="$3"
    local ret
    
    if rgb_keyboard_binary_installed; then
        "$RGB_BINARY_PATH" "$r" "$g" "$b" 2>/dev/null
        return $?
    elif rgb_detect_keyboard_sysfs; then
        # Fallback to sysfs if binary not available
        # Format: echo "mode r g b" > kbd_rgb_mode
        if echo "0 $r $g $b" > /sys/class/leds/aura_keyboard/kbd_rgb_mode 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        echo "Keyboard RGB not available" >&2
        return 1
    fi
}

# Set keyboard brightness (0-3)
# Args: $1 = brightness level
# Returns: 0 on success, 1 on failure
rgb_set_keyboard_brightness() {
    local level="$1"
    local ret
    
    if [[ "$level" -lt 0 || "$level" -gt 3 ]]; then
        echo "Invalid brightness level: $level (must be 0-3)" >&2
        return 1
    fi
    
    if rgb_detect_keyboard_sysfs; then
        if echo "$level" > /sys/class/leds/aura_keyboard/brightness 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        echo "Keyboard brightness control not available" >&2
        return 1
    fi
}

# --- Lightbar/Window RGB Detection ---

# Get HID physical path for a hidraw device
# Args: $1 = hidraw sysfs path (e.g., /sys/class/hidraw/hidraw0)
# Returns: HID_PHYS string
rgb_get_hid_phys() {
    local path="$1"
    local uevent_file="$path/device/uevent"
    
    if [[ -f "$uevent_file" ]]; then
        grep "^HID_PHYS=" "$uevent_file" 2>/dev/null | cut -d= -f2
    fi
}

# Find HID raw device by physical path signature
# Args: $1 = physical path signature to match
# Returns: device path (e.g., /dev/hidraw9) or empty
rgb_find_hidraw_by_phys() {
    local target_sig="$1"
    local hidraw_path
    
    for hidraw_path in /sys/class/hidraw/hidraw*; do
        if [[ -d "$hidraw_path" ]]; then
            local phys
            phys=$(rgb_get_hid_phys "$hidraw_path")
            if [[ "$phys" == *"$target_sig"* ]]; then
                echo "/dev/$(basename "$hidraw_path")"
                return 0
            fi
        fi
    done
    return 1
}

# Check if lightbar device is available
# Returns: 0 if found, 1 if not found
rgb_detect_lightbar() {
    local device
    device=$(rgb_find_hidraw_by_phys "$RGB_LIGHTBAR_PHYS_SIG")
    [[ -n "$device" && -e "$device" ]]
}

# Get lightbar device path
# Returns: device path or empty
rgb_get_lightbar_device() {
    rgb_find_hidraw_by_phys "$RGB_LIGHTBAR_PHYS_SIG"
}

# Send HID packet to device (used internally)
# Args: $1 = device path, $2+ = bytes to send
# Returns: 0 on success, 1 on failure
rgb_send_hid_packet() {
    local device="$1"
    shift
    local bytes=("$@")
    
    # Build 64-byte packet
    local packet=""
    local i
    for i in "${bytes[@]}"; do
        packet+="\\x$(printf '%02x' "$i")"
    done
    # Pad to 64 bytes
    local padding=$((64 - ${#bytes[@]}))
    for ((i=0; i<padding; i++)); do
        packet+="\\x00"
    done
    
    # Write packet using printf (requires dd for binary write)
    if printf "$packet" | dd of="$device" bs=64 count=1 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Turn lightbar on
# Returns: 0 on success, 1 on failure
rgb_lightbar_on() {
    local device
    device=$(rgb_get_lightbar_device)
    
    if [[ -z "$device" ]]; then
        echo "Lightbar device not found" >&2
        return 1
    fi
    
    # Power on packet: 0x5d 0xbd 0x01 0xae 0x05 0x22 0xff 0xff
    rgb_send_hid_packet "$device" 0x5d 0xbd 0x01 0xae 0x05 0x22 0xff 0xff
}

# Turn lightbar off
# Returns: 0 on success, 1 on failure
rgb_lightbar_off() {
    local device
    device=$(rgb_get_lightbar_device)
    
    if [[ -z "$device" ]]; then
        echo "Lightbar device not found" >&2
        return 1
    fi
    
    # Power off packet: 0x5d 0xbd 0x01 0xaa 0x00 0x00 0xff 0xff
    rgb_send_hid_packet "$device" 0x5d 0xbd 0x01 0xaa 0x00 0x00 0xff 0xff
}

# Set lightbar color
# Args: $1=R $2=G $3=B (0-255 each)
# Returns: 0 on success, 1 on failure
rgb_set_lightbar_color() {
    local r="$1" g="$2" b="$3"
    local device
    device=$(rgb_get_lightbar_device)
    
    if [[ -z "$device" ]]; then
        echo "Lightbar device not found" >&2
        return 1
    fi
    
    # Color packet: 0x5d 0xb3 0x00 0x00 R G B 0xeb 0x00 0x00 0xff 0xff 0xff
    rgb_send_hid_packet "$device" 0x5d 0xb3 0x00 0x00 "$r" "$g" "$b" 0xeb 0x00 0x00 0xff 0xff 0xff
}

# Set lightbar brightness (0-3)
# Maps to intensity values: 0=off, 1=85, 2=170, 3=255
# Args: $1 = brightness level
# Returns: 0 on success, 1 on failure
rgb_set_lightbar_brightness() {
    local level="$1"
    
    if [[ "$level" -lt 0 || "$level" -gt 3 ]]; then
        echo "Invalid brightness level: $level (must be 0-3)" >&2
        return 1
    fi
    
    local intensity
    case "$level" in
        0) intensity=0 ;;
        1) intensity=85 ;;
        2) intensity=170 ;;
        3) intensity=255 ;;
    esac
    
    # Use white color at given intensity
    rgb_set_lightbar_color "$intensity" "$intensity" "$intensity"
}

# --- Configuration Persistence ---

# Save keyboard RGB settings
# Args: $1=brightness $2=R $3=G $4=B
rgb_save_keyboard_config() {
    local brightness="$1" r="$2" g="$3" b="$4"
    
    mkdir -p "$RGB_CONFIG_DIR"
    cat > "$RGB_KEYBOARD_CONFIG" <<EOF
# GZ302 Keyboard RGB Configuration
# Generated by rgb-manager.sh
KEYBOARD_BRIGHTNESS=$brightness
KEYBOARD_COLOR_R=$r
KEYBOARD_COLOR_G=$g
KEYBOARD_COLOR_B=$b
EOF
}

# Save window/lightbar RGB settings
# Args: $1=brightness $2=R $3=G $4=B $5=animation (optional)
rgb_save_window_config() {
    local brightness="$1" r="$2" g="$3" b="$4" animation="${5:-static}"
    
    mkdir -p "$RGB_CONFIG_DIR"
    cat > "$RGB_WINDOW_CONFIG" <<EOF
# GZ302 Rear Window RGB Configuration
# Generated by rgb-manager.sh
WINDOW_BRIGHTNESS=$brightness
WINDOW_COLOR=$r,$g,$b
WINDOW_ANIMATION=$animation
EOF
}

# Load and apply keyboard config from saved file
# Returns: 0 on success, 1 on failure
rgb_restore_keyboard() {
    if [[ ! -f "$RGB_KEYBOARD_CONFIG" ]]; then
        return 1
    fi
    
    # shellcheck disable=SC1090
    source "$RGB_KEYBOARD_CONFIG" 2>/dev/null || return 1
    
    if [[ -n "${KEYBOARD_COLOR_R:-}" ]]; then
        rgb_set_keyboard_color "${KEYBOARD_COLOR_R}" "${KEYBOARD_COLOR_G:-0}" "${KEYBOARD_COLOR_B:-0}"
    fi
    if [[ -n "${KEYBOARD_BRIGHTNESS:-}" ]]; then
        rgb_set_keyboard_brightness "${KEYBOARD_BRIGHTNESS}"
    fi
    
    return 0
}

# Load and apply window config from saved file
# Returns: 0 on success, 1 on failure
rgb_restore_window() {
    if [[ ! -f "$RGB_WINDOW_CONFIG" ]]; then
        return 1
    fi
    
    # shellcheck disable=SC1090
    source "$RGB_WINDOW_CONFIG" 2>/dev/null || return 1
    
    if [[ -n "${WINDOW_BRIGHTNESS:-}" && "${WINDOW_BRIGHTNESS}" != "0" ]]; then
        rgb_lightbar_on
    fi
    
    if [[ -n "${WINDOW_COLOR:-}" ]]; then
        local r g b
        IFS=',' read -r r g b <<< "$WINDOW_COLOR"
        rgb_set_lightbar_color "$r" "$g" "$b"
    fi
    
    return 0
}

# Restore both keyboard and window RGB from saved configs
rgb_restore_all() {
    local success=true
    
    if rgb_detect_keyboard_sysfs; then
        rgb_restore_keyboard || success=false
    fi
    
    if rgb_detect_lightbar; then
        rgb_restore_window || success=false
    fi
    
    $success
}

# --- Status Display ---

# Print formatted RGB status
rgb_print_status() {
    echo "RGB Status:"
    echo ""
    
    # Keyboard
    echo "Keyboard RGB:"
    if rgb_detect_keyboard_sysfs; then
        echo "  ✓ Detected (aura_keyboard sysfs)"
        local brightness
        brightness=$(rgb_get_keyboard_brightness)
        echo "  Brightness: $brightness/3"
        if rgb_keyboard_binary_installed; then
            echo "  ✓ gz302-rgb binary installed"
        else
            echo "  ⚠ gz302-rgb binary not installed"
        fi
        if [[ -f "$RGB_KEYBOARD_CONFIG" ]]; then
            echo "  ✓ Config saved"
        fi
    else
        echo "  ✗ Not detected"
    fi
    echo ""
    
    # Lightbar
    echo "Rear Window (Lightbar) RGB:"
    if rgb_detect_lightbar; then
        local device
        device=$(rgb_get_lightbar_device)
        echo "  ✓ Detected at $device"
        if [[ -w "$device" ]]; then
            echo "  ✓ Device is writable"
        else
            echo "  ⚠ Device requires root (udev rules may not be installed)"
        fi
        if [[ -f "$RGB_WINDOW_CONFIG" ]]; then
            echo "  ✓ Config saved"
        fi
    else
        echo "  ✗ Not detected"
    fi
    echo ""
    
    # udev rules
    echo "udev Rules:"
    if [[ -f /etc/udev/rules.d/99-gz302-rgb.rules ]]; then
        echo "  ✓ /etc/udev/rules.d/99-gz302-rgb.rules installed"
    else
        echo "  ⚠ udev rules not installed (RGB may require root)"
    fi
}

# List available color presets
rgb_list_presets() {
    echo "Available Color Presets:"
    local preset
    for preset in "${!RGB_COLOR_PRESETS[@]}"; do
        local rgb="${RGB_COLOR_PRESETS[$preset]}"
        local r g b
        IFS=':' read -r r g b <<< "$rgb"
        printf "  %-10s RGB(%3d, %3d, %3d)\n" "$preset" "$r" "$g" "$b"
    done | sort
}

# Parse color from preset name or R G B values
# Args: $1 = preset name OR $1=$R $2=$G $3=$B
# Returns: "R G B" on stdout
rgb_parse_color() {
    if [[ $# -eq 1 ]]; then
        # Preset name
        local preset="$1"
        if [[ -n "${RGB_COLOR_PRESETS[$preset]:-}" ]]; then
            echo "${RGB_COLOR_PRESETS[$preset]}" | tr ':' ' '
            return 0
        else
            echo "Unknown color preset: $preset" >&2
            return 1
        fi
    elif [[ $# -eq 3 ]]; then
        # Direct RGB values
        echo "$1 $2 $3"
        return 0
    else
        echo "Usage: rgb_parse_color <preset> OR rgb_parse_color R G B" >&2
        return 1
    fi
}

# --- Installation Support ---

# Generate udev rules for RGB devices
# Returns: udev rule content on stdout
rgb_get_udev_rules() {
    cat <<'UDEV_RULES'
# GZ302 RGB Control udev Rules
# Allows non-root access to keyboard and lightbar RGB devices

# ASUS ROG Keyboard RGB (per-key lighting)
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", MODE="0666"

# ASUS ROG Lightbar (N-KEY Device for rear window RGB)
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"

# aura_keyboard sysfs permissions (for keyboard brightness/mode)
SUBSYSTEM=="leds", KERNEL=="aura_keyboard*", RUN+="/bin/chmod 0666 %S%p/brightness %S%p/kbd_rgb_mode %S%p/kbd_rgb_mode_index"
UDEV_RULES
}

# Check if udev rules are installed
# Returns: 0 if installed, 1 if not
rgb_udev_rules_installed() {
    [[ -f /etc/udev/rules.d/99-gz302-rgb.rules ]]
}

# Install udev rules (requires root)
# Returns: 0 on success, 1 on failure
rgb_install_udev_rules() {
    if [[ $EUID -ne 0 ]]; then
        echo "Installing udev rules requires root" >&2
        return 1
    fi
    
    rgb_get_udev_rules > /etc/udev/rules.d/99-gz302-rgb.rules
    udevadm control --reload-rules 2>/dev/null
    udevadm trigger 2>/dev/null
    
    echo "udev rules installed"
    return 0
}

# Initialize RGB configuration directory
rgb_init_config() {
    mkdir -p "$RGB_CONFIG_DIR"
}
