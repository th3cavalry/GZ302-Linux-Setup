#!/bin/bash

# ==============================================================================
# GZ302 RGB Restore Script
# Version: 3.0.3
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
for brightness_path in /sys/class/leds/*::kbd_backlight/brightness; do
    if [[ -f "$brightness_path" ]]; then
        echo 3 > "$brightness_path" 2>/dev/null || true
    fi
done

# Restore keyboard RGB settings
if [[ -f "$KEYBOARD_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$KEYBOARD_CONFIG"
    
    # Handle new format (KEYBOARD_COMMAND)
    if [[ -n "${KEYBOARD_COMMAND:-}" ]] && [[ -x "$RGB_BIN" ]]; then
        # KEYBOARD_COMMAND contains the full command string
        eval "$RGB_BIN $KEYBOARD_COMMAND" 2>/dev/null || true
    # Handle legacy format (COMMAND + ARG1, ARG2, etc.)
    elif [[ -n "${COMMAND:-}" && -n "${ARGC:-}" ]] && [[ -x "$RGB_BIN" ]]; then
        args=()
        args+=("$COMMAND")
        for ((i=1; i<ARGC-1; i++)); do
            var_name="ARG$i"
            if [[ -n "${!var_name:-}" ]]; then
                args+=("${!var_name}")
            fi
        done
        "$RGB_BIN" "${args[@]}" 2>/dev/null || true
    fi
fi

# Restore rear window/lightbar RGB settings
if [[ -f "$WINDOW_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$WINDOW_CONFIG"
    
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
