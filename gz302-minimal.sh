#!/bin/bash

# ==============================================================================
# Minimal Linux Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 2.2.8
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
    
    info "Applying essential GZ302 hardware fixes..."
    
    # 1. Kernel parameters for AMD Strix Halo
    info "Configuring kernel parameters..."
    if [[ -f /etc/default/grub ]]; then
        if ! grep -q "amd_pstate=guided" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff"/' /etc/default/grub
            
            if [[ -f /boot/grub/grub.cfg ]]; then
                grub-mkconfig -o /boot/grub/grub.cfg
            elif command -v update-grub >/dev/null 2>&1; then
                update-grub
            fi
            success "Kernel parameters configured"
        else
            info "Kernel parameters already configured"
        fi
    else
        warning "GRUB config not found - you may need to configure kernel parameters manually"
        info "Add these parameters: amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff"
    fi
    
    # 2. WiFi fix for MediaTek MT7925
    info "Configuring MediaTek MT7925 WiFi..."
    if [[ $kernel_version_num -lt 616 ]]; then
        info "Kernel < 6.16: Applying ASPM workaround for WiFi stability"
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fix for GZ302
# Disable ASPM for stability (required for kernels < 6.16)
options mt7925e disable_aspm=1
EOF
    else
        info "Kernel 6.16+: Using native MT7925 WiFi support"
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.16+ has native support - no workarounds needed
EOF
    fi
    
    # 3. Disable NetworkManager WiFi power saving
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF
    success "WiFi configured"
    
    # 4. AMD GPU configuration
    info "Configuring AMD Radeon 8060S GPU..."
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5)
options amdgpu ppfeaturemask=0xffffffff
EOF
    success "GPU configured"
    
    # 5. ASUS HID (keyboard/touchpad) fix
    info "Configuring ASUS keyboard and touchpad..."
    cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
options hid_asus fnlock_default=0
EOF
    
    # Create service to reload hid_asus for touchpad detection
    cat > /etc/systemd/system/reload-hid_asus.service <<'EOF'
[Unit]
Description=Reload hid_asus module for GZ302 touchpad
After=graphical.target display-manager.service
Wants=graphical.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 3
ExecStart=/bin/bash -c 'if lsmod | grep -q hid_asus; then /usr/sbin/modprobe -r hid_asus && /usr/sbin/modprobe hid_asus; fi'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
    
    systemctl daemon-reload
    systemctl enable reload-hid_asus.service
    success "Touchpad/keyboard configured"
    
    # 6. Reload udev rules
    systemd-hwdb update 2>/dev/null || true
    udevadm control --reload 2>/dev/null || true
    
    success "Essential hardware fixes applied"
}

# --- Main Execution ---
main() {
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Minimal Setup"
    echo "  Version 2.2.8"
    echo "============================================================"
    echo
    echo "This script applies only essential hardware fixes."
    echo "For full features, use: sudo ./gz302-main.sh"
    echo
    
    # Check root
    check_root
    
    # Check kernel version
    info "Checking kernel version..."
    local kernel_ver
    kernel_ver=$(check_kernel_version)
    echo
    
    # Detect distribution
    info "Detecting Linux distribution..."
    local distro
    distro=$(detect_distribution)
    success "Detected distribution: $distro"
    echo
    
    # Apply fixes
    apply_hardware_fixes "$kernel_ver"
    
    echo
    echo "============================================================"
    success "Minimal setup complete!"
    echo "============================================================"
    echo
    info "Applied fixes:"
    echo "  ✓ Kernel parameters (amd_pstate, amdgpu)"
    echo "  ✓ WiFi stability (MediaTek MT7925)"
    echo "  ✓ GPU optimization (Radeon 8060S)"
    echo "  ✓ Touchpad/keyboard detection"
    echo
    warning "REBOOT REQUIRED for changes to take effect"
    echo
    info "For additional features (TDP control, RGB, gaming, AI), run:"
    echo "  sudo ./gz302-main.sh"
    echo
}

main "$@"
