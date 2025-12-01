#!/bin/bash

# ==============================================================================
# GZ302 Shared Utilities Library
# Version: 2.3.3
#
# This library contains shared functions for the GZ302 Linux Setup scripts.
# It is sourced by gz302-main.sh and all optional modules.
# ==============================================================================

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m' # No Color

# --- Logging and error functions ---
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

# --- User Detection ---
get_real_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo "${SUDO_USER}"
    elif command -v logname >/dev/null 2>&1; then
        logname 2>/dev/null || whoami
    else
        whoami
    fi
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        
        # Detect Arch-based systems (including Omarchy, CachyOS, EndeavourOS, Manjaro)
        if [[ "$ID" == "arch" || "$ID" == "omarchy" || "$ID" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; then
            distro="arch"
        # Detect Debian/Ubuntu-based systems
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "pop" || "$ID" == "linuxmint" || "${ID_LIKE:-}" == *"ubuntu"* || "${ID_LIKE:-}" == *"debian"* ]]; then
            distro="ubuntu"
        # Detect Fedora-based systems
        elif [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
            distro="fedora"
        # Detect OpenSUSE-based systems
        elif [[ "$ID" == "opensuse-tumbleweed" || "$ID" == "opensuse-leap" || "$ID" == "opensuse" || "${ID_LIKE:-}" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    if [[ -z "$distro" ]]; then
        # Fallback for unknown distros, return unknown but don't exit
        echo "unknown"
    else
        echo "$distro"
    fi
}

# --- Bootloader Detection ---
detect_bootloader() {
    if [[ -d "/boot/loader" ]] && [[ -f "/boot/loader/loader.conf" ]]; then
        echo "systemd-boot"
    elif [[ -f "/boot/grub/grub.cfg" ]] || [[ -f "/boot/grub2/grub.cfg" ]]; then
        echo "grub"
    elif [[ -f "/boot/refind_linux.conf" ]]; then
        echo "refind"
    elif [[ -f "/boot/syslinux/syslinux.cfg" ]]; then
        echo "syslinux"
    elif [[ -f "/boot/extlinux/extlinux.conf" ]]; then
        echo "extlinux"
    else
        echo "unknown"
    fi
}

# --- Kernel Parameter Helpers ---

# Appends a kernel parameter to GRUB_CMDLINE_LINUX_DEFAULT if it's missing.
# Returns 0 if a change was made, 1 if no change was needed, 2 if GRUB config not found.
ensure_grub_kernel_param() {
    local param="$1"
    local grub_file="/etc/default/grub"
    if [[ ! -f "$grub_file" ]]; then
        return 2
    fi
    # Extract the current line value
    local current
    current=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT="' "$grub_file" || true)
    if [[ -z "$current" ]]; then
        return 2
    fi
    # If already present in the default line, no change
    if echo "$current" | grep -q -- "$param"; then
        return 1
    fi
    # Escape characters for sed (including quotes inside param)
    local escaped
    escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g' -e 's/\"/\\\\\"/g')
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${escaped}\"/" "$grub_file"
    return 0
}

# Appends a kernel parameter to /etc/kernel/cmdline if it's missing.
# Returns 0 if a change was made, 1 if no change was needed, 2 if cmdline not found.
ensure_kcmdline_param() {
    local param="$1"
    local cmdline_file="/etc/kernel/cmdline"
    if [[ ! -f "$cmdline_file" ]]; then
        return 2
    fi
    local current
    current=$(cat "$cmdline_file" 2>/dev/null || true)
    if printf '%s' "$current" | grep -q -- "$param"; then
        return 1
    fi
    # Append parameter preserving existing content; ensure trailing newline
    printf '%s %s\n' "${current}" "$param" | sed 's/^ *//' > "${cmdline_file}.tmp" && mv "${cmdline_file}.tmp" "$cmdline_file"
    return 0
}

# Patch a systemd-boot loader entry "options" line to include a param if missing
# Args: file_path, param
ensure_loader_entry_param() {
    local file="$1"
    local param="$2"
    if [[ ! -f "$file" ]]; then
        return 2
    fi
    # Read the existing options line (first occurrence)
    local opts
    opts=$(grep -m1 '^options ' "$file" || true)
    if [[ -z "$opts" ]]; then
        return 2
    fi
    if printf '%s' "$opts" | grep -q -- "$param"; then
        return 1
    fi
    # Safely append to options line
    local escaped
    escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
    sed -i "0,/^options /s//& ${escaped} /" "$file"
    return 0
}

# Configure kernel parameters for rEFInd
ensure_refind_kernel_param() {
    local param="$1"
    local refind_conf="/boot/refind_linux.conf"

    if [[ -f "$refind_conf" ]]; then
        # Check if parameters already exist
        if ! grep -q "$param" "$refind_conf"; then
            # Add parameters to the options line
            # Escaping for sed
            local escaped
            escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
            sed -i "/^\"Boot with standard options\"/ s/\"$/ ${escaped}\"/" "$refind_conf"
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

# Configure kernel parameters for syslinux/extlinux
ensure_syslinux_kernel_param() {
    local param="$1"
    local syslinux_cfg=""

    if [[ -f "/boot/syslinux/syslinux.cfg" ]]; then
        syslinux_cfg="/boot/syslinux/syslinux.cfg"
    elif [[ -f "/boot/extlinux/extlinux.conf" ]]; then
        syslinux_cfg="/boot/extlinux/extlinux.conf"
    fi

    if [[ -n "$syslinux_cfg" ]]; then
        # Check if parameters already exist
        if ! grep -q "$param" "$syslinux_cfg"; then
            # Add parameters to APPEND line
            local escaped
            escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
            sed -i "/^APPEND/ s/$/ ${escaped}/" "$syslinux_cfg"
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}
