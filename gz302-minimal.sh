#!/bin/bash

# ==============================================================================
# Minimal Linux Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 2.3.14
#
# This script applies ONLY the essential hardware fixes needed to run Linux
# properly on the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
#
# For full features (TDP control, RGB, gaming, AI modules), use gz302-main.sh
#
# Essential fixes applied:
# - Kernel version verification (6.14+ required)
# - WiFi stability (MediaTek MT7925)
# - AMD GPU optimization
# - Touchpad/keyboard detection
# - Power management kernel parameters
#
# Supported Distributions:
# - Arch-based (Arch, Omarchy, CachyOS, EndeavourOS, Manjaro)
# - Debian-based (Ubuntu, Pop!_OS, Linux Mint)
# - RPM-based (Fedora, Nobara)
# - OpenSUSE (Tumbleweed, Leap)
#
# USAGE:
#   curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
#   chmod +x gz302-minimal.sh
#   sudo ./gz302-minimal.sh
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BOLD_CYAN='\033[1;36m'
C_DIM='\033[2m'
C_NC='\033[0m'

# --- Symbols ---
SYMBOL_CHECK='✓'
SYMBOL_CROSS='✗'

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

# --- Visual formatting functions ---
print_box() {
    local text="$1"
    local padding=4
    local text_len=${#text}
    local total_width=$((text_len + padding * 2))
    
    echo
    echo -e "${C_GREEN}╔$(printf '═%.0s' $(seq 1 $total_width))╗${C_NC}"
    echo -e "${C_GREEN}║${C_NC}$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $padding))${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}╚$(printf '═%.0s' $(seq 1 $total_width))╝${C_NC}"
    echo
}

print_section() {
    echo
    echo -e "${C_BOLD_CYAN}━━━ $1 ━━━${C_NC}"
}

print_step() {
    local step="$1"
    local total="$2"
    local desc="$3"
    echo -e "${C_BOLD_CYAN}[$step/$total]${C_NC} $desc"
}

print_keyval() {
    printf "  ${C_DIM}%-20s${C_NC} %s\n" "$1:" "$2"
}

completed_item() {
    echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} $1"
}

failed_item() {
    echo -e "  ${C_RED}${SYMBOL_CROSS}${C_NC} $1"
}

# --- Check root privileges ---
check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-minimal.sh"
    fi
}

# --- Check Kernel Version ---
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    
    local version_num=$((major * 100 + minor))
    local min_version=614  # 6.14 minimum
    local recommended_version=617  # 6.17 recommended
    
    info "Detected kernel version: $(uname -r)"
    
    if [[ $version_num -lt $min_version ]]; then
        echo
        echo "❌ UNSUPPORTED KERNEL VERSION ❌"
        echo "Your kernel version ($kernel_version) is below the minimum (6.14)."
        echo
        echo "Kernel 6.14+ is REQUIRED for GZ302EA because it includes:"
        echo "  - AMD XDNA NPU driver (essential for Ryzen AI MAX+ 395)"
        echo "  - MediaTek MT7925 WiFi driver"
        echo "  - AMD P-State driver"
        echo "  - RDNA 3.5 GPU support for Radeon 8060S"
        echo
        error "Please upgrade your kernel to 6.14 or later."
    elif [[ $version_num -lt $recommended_version ]]; then
        warning "Kernel $kernel_version meets minimum requirements (6.14+)"
        info "For best performance, consider upgrading to kernel 6.17+"
    else
        success "Kernel version ($kernel_version) meets recommended requirements (6.17+)"
    fi
    
    echo "$version_num"
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        
        if [[ "$ID" == "arch" || "$ID" == "omarchy" || "$ID" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; then
            distro="arch"
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "pop" || "$ID" == "linuxmint" || "${ID_LIKE:-}" == *"ubuntu"* || "${ID_LIKE:-}" == *"debian"* ]]; then
            distro="ubuntu"
        elif [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
            distro="fedora"
        elif [[ "$ID" == "opensuse-tumbleweed" || "$ID" == "opensuse-leap" || "$ID" == "opensuse" || "${ID_LIKE:-}" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    if [[ -z "$distro" ]]; then
        error "Unable to detect a supported Linux distribution."
    fi
    
    echo "$distro"
}

# --- Apply Essential Hardware Fixes ---
apply_hardware_fixes() {
    local kernel_version_num="$1"
    local total_steps=5
    
    print_section "Essential Hardware Fixes"
    
    # 1. Kernel parameters for AMD Strix Halo
    print_step 1 $total_steps "Configuring kernel parameters..."
    if [[ -f /etc/default/grub ]]; then
        if ! grep -q "amd_pstate=guided" /etc/default/grub || ! grep -q "amdgpu.ppfeaturemask=0xffffffff" /etc/default/grub; then
            local params_to_add=""
            if ! grep -q "amd_pstate=guided" /etc/default/grub; then
                params_to_add="$params_to_add amd_pstate=guided"
            fi
            if ! grep -q "amdgpu.ppfeaturemask=0xffffffff" /etc/default/grub; then
                params_to_add="$params_to_add amdgpu.ppfeaturemask=0xffffffff"
            fi
            
            if [[ -n "$params_to_add" ]]; then
                sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1${params_to_add}\"/" /etc/default/grub
                
                echo -ne "${C_DIM}"
                if [[ -f /boot/grub/grub.cfg ]]; then
                    grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -3 || true
                elif command -v update-grub >/dev/null 2>&1; then
                    update-grub 2>&1 | tail -3 || true
                fi
                echo -ne "${C_NC}"
                completed_item "Kernel parameters configured"
            fi
        else
            completed_item "Kernel parameters already configured"
        fi
    else
        warning "GRUB config not found - configure manually: amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff"
    fi
    
    # 2. WiFi fix for MediaTek MT7925
    print_step 2 $total_steps "Configuring MediaTek MT7925 WiFi..."
    if [[ $kernel_version_num -lt 616 ]]; then
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fix for GZ302
# Disable ASPM for stability (required for kernels < 6.16)
options mt7925e disable_aspm=1
EOF
        completed_item "WiFi ASPM workaround applied (kernel < 6.16)"
    else
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.16+ has native support - no workarounds needed
EOF
        completed_item "Native WiFi support configured (kernel 6.16+)"
    fi
    
    # Disable NetworkManager WiFi power saving
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
# Disable WiFi power saving for stability (2 = disabled)
wifi.powersave = 2
EOF
    completed_item "WiFi power saving disabled"
    
    # 3. AMD GPU configuration
    print_step 3 $total_steps "Configuring AMD Radeon 8060S GPU..."
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5)
options amdgpu ppfeaturemask=0xffffffff
EOF
    completed_item "GPU feature mask configured"
    
    # 4. ASUS HID (keyboard/touchpad) fix
    print_step 4 $total_steps "Configuring ASUS keyboard and touchpad..."
    cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
options hid_asus fnlock_default=0
EOF
    
    cat > /etc/systemd/system/reload-hid_asus.service <<'EOF'
[Unit]
Description=Reload hid_asus module for GZ302 touchpad
After=graphical.target display-manager.service
Wants=graphical.target

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 3
ExecStart=/usr/bin/bash -c 'if /usr/bin/lsmod | /usr/bin/grep -q hid_asus; then /usr/sbin/modprobe -r hid_asus && /usr/sbin/modprobe hid_asus; fi'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
    
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable reload-hid_asus.service >/dev/null 2>&1
    completed_item "Touchpad/keyboard service enabled"
    
    # 5. Reload udev rules
    print_step 5 $total_steps "Reloading system configuration..."
    systemd-hwdb update 2>/dev/null || true
    udevadm control --reload 2>/dev/null || true
    completed_item "System configuration reloaded"
}

# --- Main Execution ---
main() {
    print_box "ASUS ROG Flow Z13 (GZ302) Minimal Setup"
    
    info "This script applies only essential hardware fixes."
    echo -e "  ${C_DIM}For full features, use: sudo ./gz302-main.sh${C_NC}"
    
    # Check root
    check_root
    
    # Check kernel version
    print_section "Kernel Verification"
    local kernel_ver
    kernel_ver=$(check_kernel_version)
    
    # Detect distribution
    print_section "Distribution Detection"
    local distro
    distro=$(detect_distribution)
    print_keyval "Distribution" "$distro"
    completed_item "Distribution detected"
    
    # Apply fixes
    apply_hardware_fixes "$kernel_ver"
    
    # Summary
    print_section "Applied Fixes Summary"
    completed_item "Kernel parameters (amd_pstate, amdgpu)"
    completed_item "WiFi stability (MediaTek MT7925)"
    completed_item "GPU optimization (Radeon 8060S)"
    completed_item "Touchpad/keyboard detection"
    
    print_box "Minimal Setup Complete"
    
    warning "REBOOT REQUIRED for changes to take effect"
    echo
    echo -e "  ${C_DIM}For additional features (TDP control, RGB, gaming, AI), run:${C_NC}"
    echo -e "  ${C_BOLD_CYAN}sudo ./gz302-main.sh${C_NC}"
    echo
}

main "$@"