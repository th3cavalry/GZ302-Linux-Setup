#!/bin/bash

# ==============================================================================
# GZ302 RGB Restore Script
# Version: 1.4.0
#
# Restores the last used RGB setting on system boot.
# Called by systemd service: gz302-rgb-restore.service
#
# This script reads the saved RGB configuration and re-applies it.
# ==============================================================================

set -euo pipefail

CONFIG_FILE="/etc/gz302-rgb/last-setting.conf"
RGB_BIN="/usr/local/bin/gz302-rgb"

# Wait for hardware to be ready
sleep 2

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
