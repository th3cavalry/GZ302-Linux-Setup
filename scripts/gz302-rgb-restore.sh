#!/bin/bash

# ==============================================================================
# GZ302 RGB Restore Script
# Version: 3.0.4
#
# Restores the last used RGB setting on system boot and after resume.
# Called by systemd service: gz302-rgb-restore.service
#
# This script handles both keyboard RGB and rear window/lightbar RGB.
# ==============================================================================

set -euo pipefail

# Config paths (FHS compliant)
CONFIG_DIR="/etc/gz302"
KEYBOARD_CONFIG="${CONFIG_DIR}/rgb-keyboard.conf"
WINDOW_CONFIG="${CONFIG_DIR}/rgb-window.conf"
LEGACY_CONFIG="${CONFIG_DIR}/last-setting.conf"

# Binary paths
RGB_BIN="/usr/local/bin/gz302-rgb"
WINDOW_BIN="/usr/local/bin/gz302-rgb-window"

# Helper to read config values safely without sourcing
# Returns empty string if key not found (grep || true prevents pipefail exit)
get_config_var() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        (grep "^${key}=" "$file" 2>/dev/null || true) | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'"
    fi
}

# Migrate old RGB config paths
migrate_rgb_config() {
    local old_paths=(
        "/etc/gz302-rgb/last-setting.conf"
    )
    
    mkdir -p "$CONFIG_DIR"
    
    for old_config in "${old_paths[@]}"; do
        if [[ -f "$old_config" ]] && [[ ! -f "$KEYBOARD_CONFIG" ]]; then
            if cp "$old_config" "$KEYBOARD_CONFIG" 2>/dev/null; then
                chmod 644 "$KEYBOARD_CONFIG"
                rm -f "$old_config"
            fi
        fi
    done
    
    # Also migrate legacy config format
    if [[ -f "$LEGACY_CONFIG" ]] && [[ ! -f "$KEYBOARD_CONFIG" ]]; then
        cp "$LEGACY_CONFIG" "$KEYBOARD_CONFIG" 2>/dev/null || true
    fi
    
    # Clean up old directories
    for old_dir in /etc/gz302-rgb; do
        if [[ -d "$old_dir" ]] && [[ -z "$(ls -A "$old_dir" 2>/dev/null)" ]]; then
            rm -rf "$old_dir"
        fi
    done
}

# Wait for hardware to be ready
sleep 2

# Migrate old RGB config path if needed
migrate_rgb_config

# Enable keyboard brightness so RGB is visible after restoring
# Set both asus::kbd_backlight and asus::kbd_backlight_1 explicitly
for brightness_path in /sys/class/leds/asus::kbd_backlight/brightness \
                       /sys/class/leds/asus::kbd_backlight_1/brightness \
                       /sys/class/leds/*::kbd_backlight/brightness; do
    if [[ -f "$brightness_path" ]]; then
        echo 3 > "$brightness_path" 2>/dev/null || true
    fi
done

# Restore keyboard RGB settings
if [[ -f "$KEYBOARD_CONFIG" ]]; then
    # Read values safely
    KEYBOARD_COMMAND=$(get_config_var "$KEYBOARD_CONFIG" "KEYBOARD_COMMAND")
    COMMAND=$(get_config_var "$KEYBOARD_CONFIG" "COMMAND")
    ARGC=$(get_config_var "$KEYBOARD_CONFIG" "ARGC")
    
    # Handle new format (KEYBOARD_COMMAND)
    if [[ -n "${KEYBOARD_COMMAND:-}" ]] && [[ -x "$RGB_BIN" ]]; then
        # KEYBOARD_COMMAND contains the full command string (e.g. "static ff0000")
        # Split into array to avoid eval
        read -r -a CMD_ARGS <<< "$KEYBOARD_COMMAND"
        "$RGB_BIN" "${CMD_ARGS[@]}" 2>/dev/null || true
        
    # Handle legacy format (COMMAND + ARG1, ARG2, etc.)
    elif [[ -n "${COMMAND:-}" && -n "${ARGC:-}" ]] && [[ -x "$RGB_BIN" ]]; then
        # Reconstruct args array
        args=("$COMMAND")
        for ((i=1; i<ARGC-1; i++)); do
            val=$(get_config_var "$KEYBOARD_CONFIG" "ARG$i")
            if [[ -n "$val" ]]; then
                args+=("$val")
            fi
        done
        "$RGB_BIN" "${args[@]}" 2>/dev/null || true
    fi
fi

# Restore rear window/lightbar RGB settings
if [[ -f "$WINDOW_CONFIG" ]]; then
    WINDOW_BRIGHTNESS=$(get_config_var "$WINDOW_CONFIG" "WINDOW_BRIGHTNESS")
    WINDOW_COLOR=$(get_config_var "$WINDOW_CONFIG" "WINDOW_COLOR")
    
    if [[ -n "${WINDOW_BRIGHTNESS:-}" ]] && [[ -x "$WINDOW_BIN" ]]; then
        "$WINDOW_BIN" --lightbar "$WINDOW_BRIGHTNESS" 2>/dev/null || true
    fi

    # Restore color if present (format: R,G,B)
    if [[ -n "${WINDOW_COLOR:-}" ]] && [[ -x "$WINDOW_BIN" ]]; then
        IFS=',' read -r R G B <<< "$WINDOW_COLOR"
        if [[ -n "${R:-}" && -n "${G:-}" && -n "${B:-}" ]]; then
            "$WINDOW_BIN" --color "$R" "$G" "$B" 2>/dev/null || true
        fi
    fi
fi

exit 0
