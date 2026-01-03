#!/bin/bash

# ==============================================================================
# GZ302 Gaming Software Module
# Version: 3.0.0
#
# This module installs gaming software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Steam, Lutris, MangoHUD, GameMode, Wine, and performance tools
#
# This script is designed to be called by gz302-main.sh
# ==============================================================================

set -euo pipefail

# --- Script directory detection ---
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

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/../gz302-lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/../gz302-lib/utils.sh"
elif [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    mkdir -p "$(dirname "${SCRIPT_DIR}/gz302-utils.sh")" || { echo "Error: Failed to create directory"; exit 1; }
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh" || { echo "Error: curl failed"; exit 1; }
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

