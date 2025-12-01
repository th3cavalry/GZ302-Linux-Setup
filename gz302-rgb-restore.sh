#!/bin/bash

# ==============================================================================
# GZ302 RGB Restore Script
# Version: 2.3.7
#
# Restores the last used RGB setting on system boot.
# Called by systemd service: gz302-rgb-restore.service
#
# This script reads the saved RGB configuration and re-applies it.
# ==============================================================================

set -euo pipefail

CONFIG_FILE="/etc/gz302/last-setting.conf"
RGB_BIN="/usr/local/bin/gz302-rgb"

# Migrate old RGB config path from pre-1.3.0 versions to FHS-compliant path
migrate_rgb_config() {
    local old_config="/etc/gz302-rgb/last-setting.conf"
    
    # If old config exists but new one doesn't, migrate it
    if [[ -f "$old_config" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p /etc/gz302
        if cp "$old_config" "$CONFIG_FILE" 2>/dev/null; then
            chmod 644 "$CONFIG_FILE"
            rm -f "$old_config"
            
            # Clean up old directory if empty
            if [[ -d /etc/gz302-rgb ]] && ! ls -A /etc/gz302-rgb >/dev/null 2>&1; then
                rm -rf /etc/gz302-rgb
            fi
        fi
    fi
}

# Wait for hardware to be ready
sleep 2

# Enable keyboard brightness so RGB is visible after restoring
BRIGHTNESS_PATH="/sys/class/leds/asus::kbd_backlight/brightness"
if [[ -f "$BRIGHTNESS_PATH" ]]; then
    echo 3 > "$BRIGHTNESS_PATH" 2>/dev/null || true
fi

# Migrate old RGB config path if needed
migrate_rgb_config

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Read config and reconstruct command
if [[ -f "$CONFIG_FILE" ]]; then
    # Source the config file to get variables
    source "$CONFIG_FILE"
    
    # Reconstruct command arguments
    if [[ -n "${COMMAND:-}" && -n "${ARGC:-}" ]]; then
        args=()
        args+=("$COMMAND")
        
        # Add all arguments
        for ((i=1; i<ARGC-1; i++)); do
            var_name="ARG$i"
            if [[ -n "${!var_name:-}" ]]; then
                args+=("${!var_name}")
            fi
        done
        
        # Execute the restored command
        if [[ -x "$RGB_BIN" ]]; then
            sudo -n "$RGB_BIN" "${args[@]}" 2>/dev/null || true
        fi
    fi
fi

exit 0
