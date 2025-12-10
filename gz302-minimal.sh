#!/bin/bash

# ==============================================================================
# Minimal Linux Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 3.0.0
#
# This script applies ONLY the essential hardware fixes needed to run Linux
# properly on the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
#
# KERNEL-AWARE: Automatically detects kernel version and applies only necessary
# fixes. For kernel 6.17+, most hardware workarounds are obsolete as native
# support is available. Re-running on kernel 6.17+ will clean up obsolete fixes.
#
# For full features (TDP control, RGB, gaming, AI modules), use gz302-main.sh
#
# Essential fixes applied (kernel-dependent):
# - Kernel version verification (6.14+ required)
# - WiFi stability (MediaTek MT7925) - only needed for kernel < 6.17
# - AMD GPU optimization
# - Touchpad/keyboard detection - only needed for kernel < 6.17
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
    # Informational logs should go to stderr so functions that echo
    # their return values on stdout (like check_kernel_version)
    # do not mix with human-facing logs.
    echo -e "${C_BLUE}INFO:${C_NC} $1" >&2
}

success() {
    # Success messages should go to stderr for the same reason as info
    echo -e "${C_GREEN}SUCCESS:${C_NC} $1" >&2
}

warning() {
    # Warnings to stderr
    echo -e "${C_YELLOW}WARNING:${C_NC} $1" >&2
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

# --- Cleanup Obsolete Fixes ---
cleanup_obsolete_fixes() {
    local kernel_version_num="$1"
    local items_cleaned=0
    
    print_section "Cleaning Up Obsolete Fixes"
    
    info "Kernel 6.17+ detected - checking for obsolete workarounds..."
    echo
    
    # Check and remove obsolete WiFi ASPM workaround
    if [[ -f /etc/modprobe.d/mt7925.conf ]]; then
        if grep -q "disable_aspm=1" /etc/modprobe.d/mt7925.conf 2>/dev/null; then
            warning "Found obsolete WiFi ASPM workaround (harmful on kernel 6.17+)"
            echo -e "  ${C_DIM}This workaround is no longer needed and degrades battery life${C_NC}"
            
            cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.17+ has native ASPM support - workarounds removed
EOF
            completed_item "Removed WiFi ASPM workaround"
            items_cleaned=$((items_cleaned + 1))
            
            # Reload WiFi module
            if lsmod | grep -q mt7925e; then
                info "Reloading WiFi module to apply changes..."
                modprobe -r mt7925e 2>/dev/null || true
                sleep 1
                modprobe mt7925e 2>/dev/null || true
                completed_item "WiFi module reloaded"
            fi
        fi
    fi
    
    # Check and remove obsolete tablet mode daemon
    if systemctl is-enabled gz302-tablet.service >/dev/null 2>&1 || [[ -f /etc/systemd/system/gz302-tablet.service ]]; then
        warning "Found obsolete tablet mode daemon (conflicts with kernel 6.17+)"
        echo -e "  ${C_DIM}Kernel now handles tablet mode natively via asus-wmi driver${C_NC}"
        
        systemctl disable --now gz302-tablet.service 2>/dev/null || true
        rm -f /etc/systemd/system/gz302-tablet.service
        systemctl daemon-reload
        completed_item "Removed tablet mode daemon"
        items_cleaned=$((items_cleaned + 1))
    fi
    
    # Check and remove obsolete input forcing
    if [[ -f /etc/modprobe.d/hid-asus.conf ]]; then
        if grep -q "enable_touchpad=1" /etc/modprobe.d/hid-asus.conf 2>/dev/null; then
            warning "Found obsolete touchpad forcing option (not needed on kernel 6.17+)"
            echo -e "  ${C_DIM}Kernel now handles touchpad enumeration natively${C_NC}"
            
            sed -i '/enable_touchpad=1/d' /etc/modprobe.d/hid-asus.conf
            completed_item "Removed touchpad forcing option"
            items_cleaned=$((items_cleaned + 1))
            
            # Reload HID module if loaded
            if lsmod | grep -q hid_asus; then
                info "Reloading HID module to apply changes..."
                modprobe -r hid_asus 2>/dev/null || true
                sleep 1
                modprobe hid_asus 2>/dev/null || true
                completed_item "HID module reloaded"
            fi
        fi
    fi
    
    # Check for obsolete reload-hid_asus service (touchpad race condition fix)
    if systemctl is-enabled reload-hid_asus.service >/dev/null 2>&1 || [[ -f /etc/systemd/system/reload-hid_asus.service ]]; then
        warning "Found obsolete touchpad reload service (not needed on kernel 6.17+)"
        echo -e "  ${C_DIM}Native enumeration is now reliable${C_NC}"
        
        systemctl disable --now reload-hid_asus.service 2>/dev/null || true
        rm -f /etc/systemd/system/reload-hid_asus.service
        systemctl daemon-reload
        completed_item "Removed touchpad reload service"
        items_cleaned=$((items_cleaned + 1))
    fi
    
    # Summary
    echo
    if [[ $items_cleaned -gt 0 ]]; then
        success "Cleaned up $items_cleaned obsolete fix(es)"
        echo
        echo -e "  ${C_GREEN}✓${C_NC} Your system now uses native kernel 6.17+ support"
        echo -e "  ${C_GREEN}✓${C_NC} Battery life should improve (WiFi ASPM enabled)"
        echo -e "  ${C_GREEN}✓${C_NC} Tablet mode works automatically with desktop environments"
    else
        info "No obsolete fixes found - system is clean"
    fi
}

# --- Apply Essential Hardware Fixes ---
apply_hardware_fixes() {
    local kernel_version_num="$1"
    local total_steps=5
    
    print_section "Essential Hardware Fixes"
    
    # Kernel 6.17+ requires fewer fixes
    if [[ $kernel_version_num -ge 617 ]]; then
        info "Kernel 6.17+ detected - applying minimal fixes (most hardware now native)"
        echo
    fi
    
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
    if [[ $kernel_version_num -lt 617 ]]; then
        # Older kernels need ASPM workaround
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fix for GZ302
# Disable ASPM for stability (required for kernels < 6.17)
options mt7925e disable_aspm=1
EOF
        completed_item "WiFi ASPM workaround applied (kernel < 6.17)"
        warning "This workaround will be removed when you upgrade to kernel 6.17+"
    else
        # Kernel 6.17+ has native WiFi support
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.17+ has native ASPM support - no workarounds needed
EOF
        completed_item "Native WiFi support configured (kernel 6.17+)"
        info "Ensure linux-firmware package is up to date for best WiFi performance"
    fi
    
    # Disable NetworkManager WiFi power saving (still beneficial on all kernels)
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
    
    # 4. ASUS HID (keyboard/touchpad) fix - only for kernel < 6.17
    print_step 4 $total_steps "Configuring ASUS keyboard and touchpad..."
    if [[ $kernel_version_num -lt 617 ]]; then
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
        completed_item "Touchpad/keyboard service enabled (kernel < 6.17)"
    else
        # Kernel 6.17+ only needs basic config
        cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
# Kernel 6.17+ handles touchpad enumeration natively
options hid_asus fnlock_default=0
EOF
        completed_item "Native touchpad support configured (kernel 6.17+)"
    fi
    
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
    echo
    info "Kernel-aware: Automatically detects and applies only necessary fixes"
    
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
    
    # Clean up obsolete fixes if kernel 6.17+
    if [[ $kernel_ver -ge 617 ]]; then
        cleanup_obsolete_fixes "$kernel_ver"
    fi
    
    # Apply fixes
    apply_hardware_fixes "$kernel_ver"
    
    # Summary
    print_section "Applied Fixes Summary"
    completed_item "Kernel parameters (amd_pstate, amdgpu)"
    
    if [[ $kernel_ver -ge 617 ]]; then
        echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} WiFi using native kernel 6.17+ support"
        echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} Touchpad/keyboard using native support"
        echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} Tablet mode using asus-wmi driver"
    else
        completed_item "WiFi stability workaround (MediaTek MT7925)"
        completed_item "Touchpad/keyboard detection"
        warning "Upgrade to kernel 6.17+ for native hardware support"
    fi
    
    completed_item "GPU optimization (Radeon 8060S)"
    
    print_box "Minimal Setup Complete"
    
    if [[ $kernel_ver -ge 617 ]]; then
        echo
        echo -e "  ${C_GREEN}✓${C_NC} ${C_BOLD_CYAN}Kernel 6.17+ Detected${C_NC}"
        echo -e "  ${C_DIM}Your hardware is now supported natively by the Linux kernel${C_NC}"
        echo -e "  ${C_DIM}This script applied only essential optimizations${C_NC}"
        echo
    fi
    
    warning "REBOOT REQUIRED for changes to take effect"
    echo
    echo -e "  ${C_DIM}For additional features (TDP control, RGB, gaming, AI), run:${C_NC}"
    echo -e "  ${C_BOLD_CYAN}sudo ./gz302-main.sh${C_NC}"
    echo
    
    if [[ $kernel_ver -ge 617 ]]; then
        echo -e "  ${C_DIM}Learn more about kernel 6.17+ improvements:${C_NC}"
        echo -e "  ${C_BLUE}https://github.com/th3cavalry/GZ302-Linux-Setup/blob/main/Info/KERNEL_COMPATIBILITY.md${C_NC}"
        echo
    fi
}

main "$@"