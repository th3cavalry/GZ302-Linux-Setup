#!/bin/bash

# ==============================================================================
# Author: th3cavalry using Copilot
# Version: $(cat "$(dirname "${BASH_SOURCE[0]}")/VERSION" 2>/dev/null || echo "4.0.0")
#
# Supported Models:
# - GZ302EA-XS99 (128GB RAM)
# - GZ302EA-XS64 (64GB RAM)
# - GZ302EA-XS32 (32GB RAM)
#
# This script automatically detects your Linux distribution and applies
# the appropriate hardware fixes for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
# It applies critical hardware fixes and TDP/refresh rate management.
#
# REQUIRED: Linux kernel 6.14+ minimum (6.17+ strongly recommended)
#
# Core features (automatically installed):
# - Hardware fixes and optimizations
# - Power management (TDP control via pwrcfg)
# - Refresh rate control (rrcfg)
# - Keyboard RGB control (gz302-rgb - all colors and animations)
# - System tray power manager (or use install-command-center.sh for tools only)
#
# Optional software can be installed via modular scripts:
# - gz302-gaming: Gaming software (Steam, Lutris, MangoHUD, etc.)
# - gz302-llm: AI/LLM software (Ollama, ROCm, PyTorch, MIOpen, bitsandbytes, etc.)
# - gz302-hypervisor: Virtualization (KVM, VirtualBox, VMware, etc.)
# - gz302-snapshots: System snapshots (Snapper, LVM, etc.)
# - gz302-secureboot: Secure boot configuration
#
# Supported Distributions:
# - Arch-based: Arch Linux, Omarchy (also supports CachyOS, EndeavourOS, Manjaro)
# - Debian-based: Ubuntu (also supports Pop!_OS, Linux Mint)
# - RPM-based: Fedora (also supports Nobara)
# - OpenSUSE: Tumbleweed and Leap
#
# PRE-REQUISITES:
# 1. A supported Linux distribution
# 2. An active internet connection
# 3. A user with sudo privileges
#
# USAGE:
# 1. Download the script:
#    curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
# 2. Make it executable:
#    chmod +x gz302-main.sh
# 3. Run with sudo:
#    sudo ./gz302-main.sh
#
# OPTIONS:
#    --power-tools-only  Skip hardware fixes (Deprecated: use install-command-center.sh)
#                        (pwrcfg, rrcfg, and Control Center)
#    -y, --assume-yes    Non-interactive mode, assume yes for all prompts
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Global CLI flags
ASSUME_YES="${ASSUME_YES:-false}"
POWER_TOOLS_ONLY="${POWER_TOOLS_ONLY:-false}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--assume-yes)
            ASSUME_YES=true
            shift
            ;;
        --power-tools-only)
            POWER_TOOLS_ONLY=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            # Other flags: break out and allow existing arg handling
            break
            ;;
        *)
            break
            ;;
    esac
done

# GitHub repository base URL for downloading modules
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Script directory detection (must work with sudo and various invocation methods) ---
# Resolves the directory containing this script, handling symlinks and various execution contexts
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

# Set SCRIPT_DIR early so it's available to all functions, including error handlers
SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_dir)}"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-lib/utils.sh"
else
    echo "gz302-lib/utils.sh not found. Downloading..."
    if command -v curl >/dev/null 2>&1; then
        curl -L "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-lib/utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -O "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download gz302-lib/utils.sh"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-lib/utils.sh"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: Failed to download gz302-lib/utils.sh"
        exit 1
    fi
fi

# --- Load Libraries ---
load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
        return 0
    else
        # Try to download if not present
        info "Downloading ${lib_name}..."
        if command -v curl >/dev/null 2>&1; then
            mkdir -p "${SCRIPT_DIR}/gz302-lib"
            curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path" || return 1
            chmod +x "$lib_path"
            source "$lib_path"
            return 0
        else
            return 1
        fi
    fi
}

info "Loading libraries..."
load_library "power-manager.sh" || warning "Failed to load power-manager.sh"
load_library "display-manager.sh" || warning "Failed to load display-manager.sh"

# --- Common helper functions ---

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-main.sh"
    fi
}

check_network() {
    # Try a quick HTTP HEAD to GitHub raw (preferred)
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSIL --max-time 5 "${GITHUB_RAW_URL}/gz302-main.sh" >/dev/null 2>&1; then
            return 0
        fi
    fi
    # Fallback: ping a public IP (no DNS required)
    if command -v ping >/dev/null 2>&1; then
        if ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
            return 0
        fi
    fi
    # Fallback: DNS resolution check
    if command -v getent >/dev/null 2>&1; then
        if getent hosts github.com >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# --- Check Kernel Version ---
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    
    # Convert to comparable format (e.g., 6.14 -> 614)
    local version_num=$((major * 100 + minor))
    local min_version=612  # 6.12 - Strix Halo minimal support (RDNA 3.5 GPU, Zen 5)
    local recommended_version=617  # 6.17+ - Full stability and WiFi improvements
    local optimal_version=618  # 6.18+ - Latest fixes and optimizations (Dec 2025)
    
    info "Detected kernel version: $(uname -r)"
    
    if [[ $version_num -lt $min_version ]]; then
        echo
        echo "❌ UNSUPPORTED KERNEL VERSION ❌"
        echo "Your kernel version ($kernel_version) is below the absolute minimum (6.12)."
        echo
        echo "Kernel 6.12+ is REQUIRED for GZ302EA because it includes:"
        echo "  - Strix Halo (Zen 5) CPU architecture support"
        echo "  - RDNA 3.5 GPU driver (Radeon 8060S integrated graphics)"
        echo "  - AMD XDNA NPU driver (essential for Ryzen AI MAX+ 395)"
        echo "  - MediaTek MT7925 WiFi driver (WiFi 7 support)"
        echo "  - AMD P-State driver with Strix Halo optimizations"
        echo
        error "Installation cancelled. Kernel 6.12+ is required.\nUpgrade options:\n  1. Use your distribution's kernel update mechanism\n  2. Install a mainline kernel from kernel.org\n  3. (Arch only) Install linux-g14 kernel: Optional/gz302-g14-kernel.sh\n  4. Check docs/kernel-support.md for version details\nIf you cannot upgrade, please create an issue on GitHub:\n  https://github.com/th3cavalry/GZ302-Linux-Setup/issues"
    elif [[ $version_num -lt $recommended_version ]]; then
        warning "Your kernel version ($kernel_version) meets minimum requirements (6.12+) but lacks improvements"
        info "For stability, consider upgrading to kernel 6.17+ which includes:"
        info "  - MediaTek MT7925 WiFi: Full MLO support and ASPM fixes"
        info "  - AMD GPU: Display Core (DC) stabilization fixes"
        info "  - Power management: Refined amd_pstate=guided for Strix Halo"
        echo
        if [[ $version_num -lt $optimal_version ]]; then
            info "Kernel 6.18+ (Dec 2025) includes additional improvements:"
            info "  - Wayland/KWin pageflip timeout fixes"
            info "  - RDNA 3.5 shader compiler optimizations"
            info "  - Strix Halo power efficiency enhancements"
        fi
        info "See docs/kernel-support.md for detailed version comparison"
        echo
    elif [[ $version_num -lt $optimal_version ]]; then
        success "Kernel version ($kernel_version) is current and well-supported"
        info "For the latest optimizations, consider upgrading to kernel 6.18+"
        echo
    else
        success "Kernel version ($kernel_version) is at the cutting edge (6.18+)"
        success "You have all latest fixes and optimizations for GZ302EA"
        echo
    fi
    
    # Return the version number for conditional logic
    echo "$version_num"
}

# --- Distribution Detection ---
# (Moved to gz302-lib/utils.sh)

# --- Hardware Fixes for All Distributions ---
# Updated based on latest kernel support and community research (October 2025)
# Sources: docs/kernel-support.md, Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs,
#          asus-linux.org, Strix Halo HomeLab, Phoronix community
# GZ302EA-XS99: AMD Ryzen AI MAX+ 395 with AMD Radeon 8060S integrated graphics (100% AMD)
# REQUIRED: Kernel 6.14+ minimum (6.17+ strongly recommended)
# See docs/kernel-support.md for detailed kernel version comparison

# --- Configure Early KMS ---
configure_early_kms() {
    # Only applies to Arch-based distros using mkinitcpio
    if [[ -f /etc/mkinitcpio.conf ]]; then
        info "Checking Early KMS configuration..."
        # Read the MODULES line
        local modules_line
        modules_line=$(grep "^MODULES=" /etc/mkinitcpio.conf)
        
        if [[ "$modules_line" != *"amdgpu"* ]]; then
            info "Enabling Early KMS for amdgpu (fixes boot/reboot freeze)..."
            # Backup
            cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
            
            # Add amdgpu to MODULES. Robustly handles () or (module1 module2)
            # Remove the closing parenthesis, append ' amdgpu)', and handle double spaces
            sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 amdgpu)/' /etc/mkinitcpio.conf
            # Cleanup leading space if list was empty "()" -> "( amdgpu)"
            sed -i 's/MODULES=( amdgpu)/MODULES=(amdgpu)/' /etc/mkinitcpio.conf
            
            info "Regenerating initramfs..."
            if mkinitcpio -P; then
                success "Early KMS enabled"
            else
                warning "Failed to regenerate initramfs. Please run 'sudo mkinitcpio -P' manually."
            fi
        else
            success "Early KMS already enabled"
        fi
    fi
}

apply_hardware_fixes() {
    info "Applying GZ302 hardware fixes for all distributions..."
    
    # Get kernel version for conditional workarounds
    local kernel_ver
    kernel_ver=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_ver" | cut -d. -f1)
    minor=$(echo "$kernel_ver" | cut -d. -f2)
    local version_num=$((major * 100 + minor))
    
    # Kernel parameters for AMD Ryzen AI MAX+ 395 (Strix Halo) and Radeon 8060S
    info "Adding kernel parameters for AMD Strix Halo optimization..."
    local grub_changed=false
    local kcmd_changed=false
    if [ -f /etc/default/grub ]; then
        # Baseline parameters
        ensure_grub_kernel_param "amd_pstate=guided" && grub_changed=true || true
        ensure_grub_kernel_param "amdgpu.ppfeaturemask=0xffffffff" && grub_changed=true || true
        # Display stability (Wayland/KWin pageflip mitigation)
        ensure_grub_kernel_param "amdgpu.sg_display=0" && grub_changed=true || true
        # dcdebugmask options: 0x410 combines 0x400 (disables DMUB Panel Self-Refresh/Replay) and 0x10 (pageflip timeout fix)
        # This fixes the dmub_replay_enable kernel bug and pageflip timeout that causes system freeze after login
        ensure_grub_kernel_param "amdgpu.dcdebugmask=0x410" && grub_changed=true || true
        # Sleep/ACPI behavior
        ensure_grub_kernel_param "mem_sleep_default=deep" && grub_changed=true || true
        ensure_grub_kernel_param 'acpi_osi="Windows 2022"' && grub_changed=true || true

        # Regenerate GRUB config once if anything changed
        if [[ "$grub_changed" == true ]]; then
            if [ -f /boot/grub/grub.cfg ]; then
                grub-mkconfig -o /boot/grub/grub.cfg
            elif command -v update-grub >/dev/null 2>&1; then
                update-grub
            fi
        fi
    fi

    # systemd-boot (kernel-install) environments
    if [[ -f /etc/kernel/cmdline ]]; then
        ensure_kcmdline_param "amd_pstate=guided" && kcmd_changed=true || true
        ensure_kcmdline_param "amdgpu.ppfeaturemask=0xffffffff" && kcmd_changed=true || true
        ensure_kcmdline_param "amdgpu.sg_display=0" && kcmd_changed=true || true
        ensure_kcmdline_param "amdgpu.dcdebugmask=0x410" && kcmd_changed=true || true
        ensure_kcmdline_param "mem_sleep_default=deep" && kcmd_changed=true || true
        ensure_kcmdline_param 'acpi_osi="Windows 2022"' && kcmd_changed=true || true

        # If cmdline changed, rebuild boot entries appropriately
        if [[ "$kcmd_changed" == true ]]; then
            # Detect distribution to pick rebuild tool
            local distro_family
            distro_family=$(detect_distribution)
            case "$distro_family" in
                arch)
                    if command -v mkinitcpio >/dev/null 2>&1; then
                        mkinitcpio -P || true
                    elif command -v dracut >/dev/null 2>&1; then
                        dracut --regenerate-all -f || true
                    fi
                    ;;
                fedora|opensuse)
                    if command -v dracut >/dev/null 2>&1; then
                        dracut --regenerate-all -f || true
                    fi
                    ;;
                debian|ubuntu)
                    if command -v update-initramfs >/dev/null 2>&1; then
                        update-initramfs -u -k all || true
                    elif command -v dracut >/dev/null 2>&1; then
                        dracut --regenerate-all -f || true
                    fi
                    ;;
            esac
            # Best-effort bootctl update (updates bootloader itself; harmless if N/A)
            if command -v bootctl >/dev/null 2>&1; then
                bootctl update || true
            fi
        fi
    fi

    # systemd-boot loader entries fallback (no /etc/kernel/cmdline present)
    if [[ ! -f /etc/kernel/cmdline && -d /boot/loader/entries ]]; then
        local loader_changed=false
        shopt -s nullglob
        for entry in /boot/loader/entries/*.conf; do
            ensure_loader_entry_param "$entry" "amd_pstate=guided" && loader_changed=true || true
            ensure_loader_entry_param "$entry" "amdgpu.ppfeaturemask=0xffffffff" && loader_changed=true || true
            ensure_loader_entry_param "$entry" "amdgpu.sg_display=0" && loader_changed=true || true
            ensure_loader_entry_param "$entry" "amdgpu.dcdebugmask=0x410" && loader_changed=true || true
            ensure_loader_entry_param "$entry" "mem_sleep_default=deep" && loader_changed=true || true
            ensure_loader_entry_param "$entry" 'acpi_osi="Windows 2022"' && loader_changed=true || true
        done
        shopt -u nullglob
        if [[ "$loader_changed" == true ]] && command -v bootctl >/dev/null 2>&1; then
            bootctl update || true
        fi
    fi

    # Limine bootloader support (/etc/default/limine)
    # Popular on CachyOS and other Arch-based distros
    if [[ -f /etc/default/limine ]]; then
        local limine_changed=false
        info "Limine bootloader detected, configuring kernel parameters..."
        ensure_limine_kernel_param "amd_pstate=guided" && limine_changed=true || true
        ensure_limine_kernel_param "amdgpu.ppfeaturemask=0xffffffff" && limine_changed=true || true
        ensure_limine_kernel_param "amdgpu.sg_display=0" && limine_changed=true || true
        ensure_limine_kernel_param "amdgpu.dcdebugmask=0x410" && limine_changed=true || true
        ensure_limine_kernel_param "mem_sleep_default=deep" && limine_changed=true || true
        ensure_limine_kernel_param 'acpi_osi="Windows 2022"' && limine_changed=true || true

        # Regenerate Limine entries if changes were made
        if [[ "$limine_changed" == true ]]; then
            if command -v limine-mkinitcpio >/dev/null 2>&1; then
                info "Regenerating Limine boot entries..."
                limine-mkinitcpio || true
            elif command -v limine-mkconfig >/dev/null 2>&1; then
                info "Regenerating Limine configuration..."
                limine-mkconfig -o /boot/limine.conf || true
            else
                warning "Limine config modified but no regeneration tool found."
                warning "Please run 'limine-mkinitcpio' or equivalent manually."
            fi
        fi
    fi
    
    # Wi-Fi fixes for MediaTek MT7925
    # See docs/kernel-support.md for detailed kernel version WiFi improvements
    # Kernel 6.14: Basic driver integration with known stability issues
    # Kernel 6.15-6.16: Improved stability and performance
    # Kernel 6.17: Optimized with regression fixes and enhanced performance
    info "Configuring MediaTek MT7925 Wi-Fi..."
    
    if [[ $version_num -lt 616 ]]; then
        info "Kernel < 6.16 detected: Applying ASPM workaround for MT7925 WiFi stability"
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fixes for GZ302
# Disable ASPM for stability (fixes disconnection and suspend/resume issues)
# Required for kernels < 6.16. Kernel 6.16+ has improved native support.
# Based on community findings from EndeavourOS forums and kernel patches
options mt7925e disable_aspm=1
EOF
    else
        info "Kernel 6.16+ detected: Using improved native MT7925 WiFi support"
        info "ASPM workaround not needed with kernel 6.16+"
        # Create a minimal config noting that workarounds aren't needed
        cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.16+ includes native improvements - ASPM workaround not needed
# WiFi 7 MLO support and enhanced stability included natively
EOF
    fi

    # Disable NetworkManager Wi-Fi power saving (recommended for all kernel versions)
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF

    # AMD GPU module configuration for Radeon 8060S (integrated)
    info "Configuring AMD Radeon 8060S GPU (RDNA 3.5)..."
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5, integrated)
# Strix Halo specific: Phoenix/Navi33 equivalent
# Enable all power features for better performance and efficiency
# ROCm-compatible for AI/ML workloads
# ppfeaturemask=0xffffffff enables: PowerPlay, DPM, OverDrive, GFXOFF, etc.
options amdgpu ppfeaturemask=0xffffffff
EOF

    # Check for GPU firmware files (validation)
    info "Verifying AMD GPU firmware files..."
    local gpu_fw_ok=true
    for fw_file in gc_11_5_1_pfp.bin gc_11_5_1_me.bin dcn_3_5_1_dmcub.bin; do
        if [[ -f "/lib/firmware/amdgpu/$fw_file" ]] || [[ -f "/lib/firmware/amdgpu/${fw_file}.zst" ]] || [[ -f "/lib/firmware/amdgpu/${fw_file}.xz" ]]; then
            info "  ✓ $fw_file"
        else
            warning "  ✗ $fw_file (may be loaded from initramfs)"
            gpu_fw_ok=false
        fi
    done
    if [[ "$gpu_fw_ok" == true ]]; then
        success "GPU firmware files verified"
    else
        warning "Some GPU firmware files not found; check dmesg for firmware loading status"
    fi

    # ASUS HID (keyboard/touchpad) configuration
    info "Configuring ASUS keyboard and touchpad..."
    cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
# fnlock_default=0: F1-F12 keys work as media keys by default
# Kernel 6.15+ includes mature touchpad gesture support and improved ASUS HID integration
options hid_asus fnlock_default=0
EOF

    # Additional HID/i2c stability quirk for certain touchpad firmware
    # Avoid blacklisting hid_asus; instead, add i2c_hid_acpi quirk used in field fixes
    info "Applying i2c_hid_acpi quirks for touchpad stability..."
    cat > /etc/modprobe.d/i2c-hid-acpi-gz302.conf <<'EOF'
# ASUS GZ302 touchpad stability
# Some units benefit from enabling i2c_hid_acpi quirk 0x01
options i2c_hid_acpi quirks=0x01
EOF

    # Create systemd service to reload hid_asus module for reliable touchpad detection
    # NOTE: This service runs at graphical.target (not multi-user.target) to avoid
    # causing input device disconnection during KDE/GNOME/XFCE startup, which can
    # cause the desktop to appear "frozen" or unresponsive.
    info "Creating HID module reload service for touchpad detection..."
    cat > /etc/systemd/system/reload-hid_asus.service <<'EOF'
[Unit]
Description=Reload hid_asus module with correct options for GZ302 Touchpad
# Run after graphical target to avoid disconnecting keyboard/touchpad during desktop startup
# This prevents the "freeze" issue on KDE and other desktop environments
After=graphical.target display-manager.service
Wants=graphical.target

[Service]
Type=oneshot
# Add a 3-second delay to ensure the desktop session is stable before reloading
# This allows KDE/GNOME/XFCE to complete their startup without input device interruption
ExecStartPre=/bin/sleep 3
# Reload the module only if it's currently loaded (silent success if not loaded)
# Using a single command ensures atomic check-and-reload to avoid race conditions
ExecStart=/bin/bash -c 'if lsmod | grep -q hid_asus; then /usr/sbin/modprobe -r hid_asus && /usr/sbin/modprobe hid_asus; else echo "hid_asus not loaded, skipping reload"; fi'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

    # Enable the service
    systemctl daemon-reload
    systemctl enable reload-hid_asus.service

    # Reload hardware database and udev
    systemd-hwdb update 2>/dev/null || true
    udevadm control --reload 2>/dev/null || true

    # Enable Early KMS for AMDGPU (Fixes Plymouth/Reboot freezing)
    configure_early_kms

    # GZ302 RGB udev rules for non-root access to HID raw devices
    info "Configuring udev rules for keyboard and lightbar RGB control..."
    cat > /etc/udev/rules.d/99-gz302-rgb.rules <<'EOF'
# GZ302 RGB Control - Allow unprivileged HID raw access for RGB control
# ASUS ROG Flow Z13 (2025) GZ302EA

# Keyboard RGB (USB 0b05:1a30) - for keyboard color control
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", MODE="0666"

# Lightbar/N-KEY Device (USB 0b05:18c6) - for rear window RGB control
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"

# Trigger RGB restore service when lightbar connects (boot or wake from suspend)
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", TAG+="systemd", ENV{SYSTEMD_WANTS}="gz302-rgb-restore.service"
EOF

    # Remove old keyboard-only rules if present
    rm -f /etc/udev/rules.d/99-gz302-keyboard.rules 2>/dev/null || true
    
    udevadm control --reload 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
        # Set up keyboard backlight restore after suspend/resume
        info "Configuring keyboard backlight resume restore..."
        mkdir -p /usr/lib/systemd/system-sleep /var/lib/gz302
        cat > /usr/lib/systemd/system-sleep/gz302-kbd-backlight <<'EOF'
#!/bin/bash
# Restore ASUS keyboard backlight after resume (GZ302)
# Invoked by systemd: $1 is 'pre' or 'post'

STATE_FILE="/var/lib/gz302/kbd_backlight.brightness"

# Collect all potential keyboard backlight LED devices
mapfile -t LEDS < <(ls -d /sys/class/leds/*kbd*backlight* 2>/dev/null)

case "$1" in
    pre)
        # Save current brightness (use the first LED found)
        if [[ ${#LEDS[@]} -gt 0 && -f "${LEDS[0]}/brightness" ]]; then
            cat "${LEDS[0]}/brightness" > "$STATE_FILE" 2>/dev/null || true
        fi
        ;;
    post)
        # Restore brightness; driver may need a short delay after resume
        for _ in 1 2 3 4 5; do
            if [[ ${#LEDS[@]} -gt 0 ]]; then
                for led in "${LEDS[@]}"; do
                    if [[ -f "$led/brightness" ]]; then
                        if [[ -s "$STATE_FILE" ]]; then
                            BR=$(cat "$STATE_FILE" 2>/dev/null)
                        else
                            MAX=$(cat "$led/max_brightness" 2>/dev/null || echo 3)
                            BR=$((MAX/2))
                            [[ $BR -lt 1 ]] && BR=1
                        fi
                        echo "$BR" > "$led/brightness" 2>/dev/null || true
                    fi
                done
                break
            fi
            sleep 0.5
        done

        # Optionally kick asusctl daemon to reapply last profile if available
        if command -v systemctl >/dev/null 2>&1; then
            systemctl try-restart asusd.service 2>/dev/null || true
        fi
        ;;
esac

exit 0
EOF
        chmod +x /usr/lib/systemd/system-sleep/gz302-kbd-backlight

        # Create systemd service to restore keyboard backlight brightness on boot
        cat > /etc/systemd/system/gz302-kbd-backlight-restore.service <<EOF
[Unit]
Description=GZ302 Keyboard Backlight Restore
After=multi-user.target
ConditionPathExists=/var/lib/gz302/kbd_backlight.brightness

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for led in /sys/class/leds/*kbd*backlight*; do [[ -f \$led/brightness ]] && cat /var/lib/gz302/kbd_backlight.brightness > \$led/brightness 2>/dev/null || true; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

        # Create systemd service to save keyboard backlight brightness on shutdown
        cat > /etc/systemd/system/gz302-kbd-backlight-save.service <<EOF
[Unit]
Description=GZ302 Keyboard Backlight Save
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target poweroff.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for led in /sys/class/leds/*kbd*backlight*; do [[ -f \$led/brightness ]] && cat \$led/brightness > /var/lib/gz302/kbd_backlight.brightness 2>/dev/null || true; break; done'
RemainAfterExit=yes

[Install]
WantedBy=shutdown.target reboot.target halt.target poweroff.target
EOF

        systemctl daemon-reload 2>/dev/null || true
        systemctl enable gz302-kbd-backlight-restore.service 2>/dev/null || true
        systemctl enable gz302-kbd-backlight-save.service 2>/dev/null || true

        # Note about advanced fan/power control
    info "Note: For advanced fan and power mode control, consider the ec_su_axb35 kernel module"
    info "See: https://github.com/cmetz/ec-su_axb35-linux for Strix Halo-specific controls"
    
    success "Hardware fixes applied"
}

# --- Distribution-Specific Optimizations Info ---
# Provides information about distribution-specific optimizations for Strix Halo
provide_distro_optimization_info() {
    local distro="$1"
    
    # Detect specific distribution ID for CachyOS
    local distro_id=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-}"
    fi
    
    # CachyOS-specific optimizations
    if [[ "$distro_id" == "cachyos" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "CachyOS Detected - Performance Optimizations Available"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "CachyOS provides excellent out-of-the-box performance for Strix Halo:"
        info ""
        info "✓ Optimized kernel with BORE scheduler (better gaming/interactive performance)"
        info "✓ Packages compiled with x86-64-v3/v4 optimizations (5-20% performance boost)"
        info "✓ LTO/PGO optimizations for better binary performance"
        info "✓ AMD P-State driver enhancements built-in"
        info ""
        info "Additional Optimizations Available:"
        info "1. Consider using 'amd_pstate=active' for better battery life:"
        info "   - Edit /etc/default/grub and change amd_pstate=guided to amd_pstate=active"
        info "   - Run: grub-mkconfig -o /boot/grub/grub.cfg"
        info "   - Active mode lets hardware autonomously choose optimal frequencies"
        info ""
        info "2. Use CachyOS kernel manager to select optimized kernel:"
        info "   - linux-cachyos-bore (recommended for gaming/desktop)"
        info "   - linux-cachyos-rt-bore (for real-time workloads)"
        info "   - linux-cachyos-lts (for stability)"
        info ""
        info "3. Performance tuning via /sys/devices/system/cpu/amd_pstate/:"
        info "   - Set performance governor: for cpu in /sys/devices/system/cpu/cpu[0-9]*; do"
        info "     echo 'performance' > \$cpu/cpufreq/scaling_governor 2>/dev/null; done"
        info "   - Or use 'powersave' governor with energy_performance_preference"
        info ""
        info "Reference: https://wiki.cachyos.org/configuration/general_system_tweaks/"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
    
    # General AMD P-State information for all Arch-based distributions
    if [[ "$distro" == "arch" ]] && [[ "$distro_id" != "cachyos" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "Arch Linux Performance Tuning for Strix Halo"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "AMD P-State Mode: Currently using 'guided' (good for consistent performance)"
        info ""
        info "Alternative: Switch to 'active' mode for better battery life:"
        info "  1. Edit /etc/default/grub"
        info "  2. Change: amd_pstate=guided → amd_pstate=active"
        info "  3. Run: grub-mkconfig -o /boot/grub/grub.cfg"
        info "  4. Reboot"
        info ""
        info "Active mode pros: Better power efficiency, hardware makes smart decisions"
        info "Guided mode pros: More predictable performance, better for gaming/heavy loads"
        info ""
        info "Performance tip: Install CachyOS repositories for optimized packages:"
        info "  - 5-20% performance improvement from x86-64-v3/v4 optimized builds"
        info "  - https://wiki.cachyos.org/features/optimized_repos/"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
    
    # Information for other distributions
    if [[ "$distro" != "arch" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "AMD P-State Driver Information"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "Current mode: 'guided' (balanced performance and power efficiency)"
        info ""
        info "For better battery life, consider switching to 'active' mode:"
        info "  - Hardware autonomously manages frequencies based on workload"
        info "  - Better power efficiency with good performance"
        info ""
        info "To switch modes, edit your bootloader configuration and change:"
        info "  amd_pstate=guided → amd_pstate=active"
        info ""
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
}


# --- Sound Open Firmware (SOF) Configuration ---
install_sof_firmware() {
    info "Installing Sound Open Firmware (SOF) for GZ302EA audio..."
    
    local distro="$1"
    
    case "$distro" in
        arch)
            # Install SOF firmware from official Arch repos
            if pacman -S --noconfirm --needed sof-firmware alsa-ucm-conf 2>/dev/null; then
                success "SOF firmware installed from official repositories"
            else
                warning "SOF firmware installation failed - audio may not work optimally"
            fi
            ;;
        debian|ubuntu)
            # Install SOF firmware from Ubuntu repos
            if apt-get install -y sof-firmware alsa-ucm-conf 2>/dev/null; then
                success "SOF firmware installed"
            else
                warning "SOF firmware installation failed - audio may not work optimally"
            fi
            ;;
        fedora)
            # Install SOF firmware from Fedora repos
            if dnf install -y sof-firmware alsa-sof-firmware alsa-ucm 2>/dev/null; then
                success "SOF firmware installed"
            else
                warning "SOF firmware installation failed - audio may not work optimally"
            fi
            ;;
        opensuse)
            # Install SOF firmware from OpenSUSE repos
            if zypper install -y sof-firmware alsa-ucm-conf 2>/dev/null; then
                success "SOF firmware installed"
            else
                warning "SOF firmware installation failed - audio may not work optimally"
            fi
            ;;
    esac
    
    # Ensure ALSA state is saved/restored
    systemctl enable --now alsa-restore.service 2>/dev/null || true
    systemctl enable --now alsa-state.service 2>/dev/null || true
    
    info "SOF audio configuration complete"

    # Detect Cirrus Logic CS35L41 amplifier on supported units and apply HDA patch config
    if [[ -r /proc/asound/cards ]] && grep -qi "cs35l41" /proc/asound/cards 2>/dev/null; then
        info "Detected Cirrus Logic CS35L41 amplifier; applying HDA patch configuration..."
        cat > /etc/modprobe.d/cs35l41.conf <<'EOF'
# Cirrus Logic CS35L41 amplifier configuration for GZ302
options snd_hda_intel patch=cs35l41-hda
EOF
    fi
}



# --- Battery Limit Fallback Service ---
setup_battery_limit_service() {
    info "Setting up battery charge limit service (80%)"

    # Create script to set battery charge limit
    local script_path="/usr/local/bin/set-battery-limit.sh"
    cat > "$script_path" << 'EOS'
#!/bin/sh
echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold
EOS
    chmod 755 "$script_path"
    chown root:root "$script_path"

    # Create systemd service for battery charge limit
    cat > /etc/systemd/system/battery-charge-limit.service << EOF
[Unit]
Description=Set battery charge limit to 80%
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$script_path
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable --now battery-charge-limit.service 2>/dev/null || warning "Failed to enable battery charge limit service"

    # Verify the setting was applied
    local limit
    limit=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "0")
    if [[ "$limit" == "80" ]]; then
        success "Battery charge limit set to 80%"
        info "Battery will stop charging at 80% to preserve battery health"
        return 0
    else
        warning "Failed to set battery charge limit - may require asusctl for this hardware"
        return 1
    fi
}









# --- Command Center Installation Delegation ---
offer_command_center_install() {
    local distro="$1"
    
    echo
    echo "============================================================"
    echo "  GZ302 Command Center"
    echo "============================================================"
    echo
    info "The Command Center provides a user interface and essential tools for:"
    echo "   - Power Management (TDP control)"
    echo "   - Display Refresh Rate Control"
    echo "   - RGB Lighting Control (Keyboard & Window)"
    echo "   - System Tray Icon"
    echo
    
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        info "ASSUME_YES: Installing Command Center automatically"
        install_command_center
        return
    fi
    
    if ask_yes_no "Do you want to install the GZ302 Command Center? (Y/n): " Y; then
        install_command_center
    else
        info "Skipping Command Center installation."
        info "You can install it later by running: ./install-command-center.sh"
    fi
}

install_command_center() {
    print_section "Installing Command Center"
    
    local cmd_install_script="${SCRIPT_DIR}/install-command-center.sh"
    
    if [[ -f "$cmd_install_script" ]]; then
        info "Running Command Center installer..."
        bash "$cmd_install_script"
    else
        # Try to download if not present
        info "Command Center installer not found locally, downloading..."
        local temp_script="/tmp/install-command-center.sh"
        if curl -fsSL "${GITHUB_RAW_URL}/install-command-center.sh" -o "$temp_script"; then
            chmod +x "$temp_script"
            bash "$temp_script"
            rm -f "$temp_script"
        else
            error "Failed to download Command Center installer"
            return 1
        fi
    fi
}

enable_arch_services() {
    info "Services configuration complete for Arch-based system"
}

enable_debian_services() {
    info "Services configuration complete for Debian-based system"
}

enable_fedora_services() {
    info "Services configuration complete for Fedora-based system"
}

enable_opensuse_services() {
    info "Services configuration complete for OpenSUSE"
}




# --- Module Download and Execution ---

download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local local_module="${SCRIPT_DIR}/modules/${module_name}.sh"
    
    # Try local execution first (Repo mode)
    if [[ -f "$local_module" ]]; then
        info "Executing local module: ${module_name}..."
        bash "$local_module" "$distro"
        return $?
    fi

    # Download fallback (Standalone mode)
    local module_url="${GITHUB_RAW_URL}/modules/${module_name}.sh"
    local temp_script="/tmp/${module_name}.sh"
    
    if ! check_network; then
        warning "No network connectivity. Cannot download ${module_name}."
        return 1
    fi
    
    info "Downloading ${module_name} module..."
    if curl -fsSL "$module_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        
        # Ensure utils are available
        if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
            cp "${SCRIPT_DIR}/gz302-lib/utils.sh" "/tmp/gz302-lib/utils.sh" 2>/dev/null || mkdir -p /tmp/gz302-lib && cp "${SCRIPT_DIR}/gz302-lib/utils.sh" "/tmp/gz302-lib/utils.sh"
        fi
        
        info "Executing ${module_name} module..."
        bash "$temp_script" "$distro"
        local exec_result=$?
        rm -f "$temp_script"
        
        if [[ $exec_result -eq 0 ]]; then
            success "${module_name} module completed"
            return 0
        else
            warning "${module_name} module completed with errors"
            return 1
        fi
    else
        warning "Failed to download ${module_name} module from ${module_url}"
        return 1
    fi
}
# --- Distribution-Specific Setup Functions ---
setup_arch_based() {
    local distro="$1"
    print_subsection "Arch-based System Setup"
    
    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "arch_update"; then
        printf '%s' "${C_DIM}"
        pacman -Syu --noconfirm --needed
        pacman -S --noconfirm --needed git base-devel wget curl
        printf '%s' "${C_NC}"
        complete_step "arch_update"
    fi
    completed_item "System updated"
    
    # Step 2: Install AUR helper
    print_step 2 7 "Setting up AUR helper..."
    if ! is_step_completed "arch_aur"; then
        if [[ "$distro" == "arch" ]] && ! command -v yay >/dev/null 2>&1; then
            info "Installing yay AUR helper..."
            local primary_user
            primary_user=$(get_real_user)
            printf '%s' "${C_DIM}"
            sudo -u "$primary_user" -H bash << 'EOFYAY'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOFYAY
            printf '%s' "${C_NC}"
        fi
        complete_step "arch_aur"
    fi
    completed_item "AUR helper ready"
    
    # Step 3: Apply hardware fixes
    print_step 3 7 "Applying hardware fixes..."
    if ! is_step_completed "arch_hardware"; then
        apply_hardware_fixes
        complete_step "arch_hardware"
    fi
    completed_item "Hardware fixes applied"
    
    # Provide distribution-specific optimization information
    provide_distro_optimization_info "$distro"
    
    # Step 4: Install ASUS-specific packages
    # (Delegated to Command Center)

    
    # Step 5: Install SOF firmware for audio support
    print_step 5 7 "Installing audio firmware..."
    if ! is_step_completed "arch_audio"; then
        printf '%s' "${C_DIM}"
        install_sof_firmware "arch"
        printf '%s' "${C_NC}"
        complete_step "arch_audio"
    fi
    completed_item "Audio firmware installed"
    
    # Step 6: Install GZ302 RGB keyboard control
    # (Delegated to Command Center)
    
    # Step 7: Setup TDP and refresh management
    # (Delegated to Command Center)
    
    enable_arch_services
}

setup_debian_based() {
    local distro="$1"
    print_subsection "Debian-based System Setup"
    
    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "debian_update"; then
        printf '%s' "${C_DIM}"
        apt update
        apt upgrade -y
        apt install -y curl wget git build-essential \
            apt-transport-https ca-certificates gnupg lsb-release
        printf '%s' "${C_NC}"
        complete_step "debian_update"
    fi
    completed_item "System updated"
    
    # Step 2: Apply hardware fixes
    print_step 2 7 "Applying hardware fixes..."
    if ! is_step_completed "debian_hardware"; then
        apply_hardware_fixes
        complete_step "debian_hardware"
    fi
    completed_item "Hardware fixes applied"
    
    # Provide distribution-specific optimization information
    provide_distro_optimization_info "$distro"
    
    # Provide distribution-specific optimization information
    provide_distro_optimization_info "$distro"
    
    # Step 3: Install ASUS-specific packages
    # (Delegated to Command Center)

    
    # Step 4: Install SOF firmware for audio support
    print_step 4 7 "Installing audio firmware..."
    if ! is_step_completed "debian_audio"; then
        printf '%s' "${C_DIM}"
        install_sof_firmware "ubuntu"
        printf '%s' "${C_NC}"
        complete_step "debian_audio"
    fi
    completed_item "Audio firmware installed"
    
    # Step 5: Install GZ302 RGB keyboard control
    # (Delegated to Command Center)
    
    # Step 6-7: Setup TDP management and refresh rate
    # (Delegated to Command Center)
    
    enable_debian_services
}

setup_fedora_based() {
    local distro="$1"
    print_subsection "Fedora-based System Setup"
    
    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "fedora_update"; then
        printf '%s' "${C_DIM}"
        dnf upgrade -y
        dnf install -y curl wget git gcc make kernel-devel
        printf '%s' "${C_NC}"
        complete_step "fedora_update"
    fi
    completed_item "System updated"
    
    # Step 2: Apply hardware fixes
    print_step 2 7 "Applying hardware fixes..."
    if ! is_step_completed "fedora_hardware"; then
        apply_hardware_fixes
        complete_step "fedora_hardware"
    fi
    completed_item "Hardware fixes applied"
    
    # Provide distribution-specific optimization information
    provide_distro_optimization_info "$distro"
    
    # Step 3: Install ASUS-specific packages
    # (Delegated to Command Center)

    
    # Step 4: Install SOF firmware for audio support
    print_step 4 7 "Installing audio firmware..."
    if ! is_step_completed "fedora_audio"; then
        printf '%s' "${C_DIM}"
        install_sof_firmware "fedora"
        printf '%s' "${C_NC}"
        complete_step "fedora_audio"
    fi
    completed_item "Audio firmware installed"
    
    # Step 5: Install GZ302 RGB keyboard control
    # (Delegated to Command Center)
    
    # Step 6-7: Setup TDP management and refresh rate
    # (Delegated to Command Center)
    
    enable_fedora_services
}

setup_opensuse() {
    local distro="$1"
    print_subsection "OpenSUSE System Setup"
    
    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "opensuse_update"; then
        printf '%s' "${C_DIM}"
        zypper refresh
        zypper update -y
        zypper install -y curl wget git gcc make kernel-devel
        printf '%s' "${C_NC}"
        complete_step "opensuse_update"
    fi
    completed_item "System updated"
    
    # Step 2: Apply hardware fixes
    print_step 2 7 "Applying hardware fixes..."
    if ! is_step_completed "opensuse_hardware"; then
        apply_hardware_fixes
        complete_step "opensuse_hardware"
    fi
    completed_item "Hardware fixes applied"
    
    # Provide distribution-specific optimization information
    provide_distro_optimization_info "$distro"
    
    # Step 3: Install ASUS-specific packages
    # (Delegated to Command Center)

    
    # Step 4: Install SOF firmware for audio support
    print_step 4 7 "Installing audio firmware..."
    if ! is_step_completed "opensuse_audio"; then
        printf '%s' "${C_DIM}"
        install_sof_firmware "opensuse"
        printf '%s' "${C_NC}"
        complete_step "opensuse_audio"
    fi
    completed_item "Audio firmware installed"
    
    # Step 5: Install GZ302 RGB keyboard control
    # (Delegated to Command Center)
    
    # Step 6-7: Setup TDP management and refresh rate
    # (Delegated to Command Center)
    
    enable_opensuse_services
}


# --- Optional Module Installation ---
offer_optional_modules() {
    local distro="$1"
    
    echo
    echo "============================================================"
    echo "  Optional Software Modules"
    echo "============================================================"
    echo
    info "The following optional modules can be installed:"
    echo
    echo "1. Gaming Software (gz302-gaming)"
    echo "   - Steam, Lutris, ProtonUp-Qt"
    echo "   - MangoHUD, GameMode, Wine"
    echo "   - Gaming optimizations and performance tweaks"
    echo
    echo "2. LLM/AI Software (gz302-llm)"
    echo "   - Ollama for local LLM inference"
    echo "   - ROCm for AMD GPU acceleration (gfx1151)"
    echo "   - PyTorch, MIOpen, and bitsandbytes"
    echo "   - Transformers and Accelerate libraries"
    echo
    echo "3. Hypervisor Software (gz302-hypervisor)"
    echo "   - KVM/QEMU, VirtualBox, VMware, Xen, or Proxmox"
    echo "   - Virtual machine management tools"
    echo
    echo "4. System Snapshots (gz302-snapshots)"
    echo "   - Automatic daily system backups"
    echo "   - Easy system recovery and rollback"
    echo "   - Supports ZFS, Btrfs, ext4 (LVM), and XFS"
    echo
    echo "5. Secure Boot (gz302-secureboot)"
    echo "   - Enhanced system security and boot integrity"
    echo "   - Automatic kernel signing on updates"
    echo
    echo "6. Skip optional modules"
    echo
    
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        module_choice="6"
        info "ASSUME_YES: Defaulting to skip optional modules"
    else
        read -r -p "Which modules would you like to install? (comma-separated numbers, e.g., 1,2 or 6 to skip): " module_choice
    fi
    
    # Parse the choices
    IFS=',' read -ra CHOICES <<< "$module_choice"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ') # Remove spaces
        case "$choice" in
            1)
                download_and_execute_module "gz302-gaming" "$distro" || warning "Gaming module installation failed"
                ;;
            2)
                download_and_execute_module "gz302-llm" "$distro" || warning "LLM module installation failed"
                ;;
            3)
                download_and_execute_module "gz302-hypervisor" "$distro" || warning "Hypervisor module installation failed"
                ;;
            4)
                download_and_execute_module "gz302-snapshots" "$distro" || warning "Snapshots module installation failed"
                ;;
            5)
                download_and_execute_module "gz302-secureboot" "$distro" || warning "Secure boot module installation failed"
                ;;
            6)
                info "Skipping optional modules"
                ;;
            *)
                warning "Invalid choice: $choice"
                ;;
        esac
    done
}

# --- Path Migration for Backward Compatibility ---
# Migrates old paths from pre-1.3.0 versions to FHS-compliant paths
# NOTE: All info/success/warning messages go to stderr so only the count is captured
migrate_old_paths() {
    local paths_migrated=0
    local sentinel="/etc/gz302/.migrations_v1_done"

    # If we've already migrated and the sentinel exists, skip migration (idempotent)
    if [[ -f "$sentinel" ]]; then
        info "Previously completed migrations detected, skipping." >&2
        echo 0
        return
    fi
    
    info "Checking for old configuration paths that need migration..." >&2
    
    # Migrate old /etc/pwrcfg directory
    if [[ -d /etc/pwrcfg ]]; then
        # Check if directory has content
        if [[ -n "$(ls -A /etc/pwrcfg 2>/dev/null)" ]]; then
            info "Migrating /etc/pwrcfg → /etc/gz302/pwrcfg" >&2
            mkdir -p /etc/gz302/pwrcfg
            if cp -r /etc/pwrcfg/* /etc/gz302/pwrcfg/ 2>/dev/null; then
                chmod 755 /etc/gz302/pwrcfg
                chmod 644 /etc/gz302/pwrcfg/* 2>/dev/null || true
                rm -rf /etc/pwrcfg
                success "Migrated power configuration to /etc/gz302/pwrcfg" >&2
                ((paths_migrated++))
            else
                warning "Failed to migrate /etc/pwrcfg contents" >&2
            fi
        else
            # Empty directory, just remove it
            rm -rf /etc/pwrcfg
        fi
    fi
    
    # Migrate old /etc/rrcfg directory
    if [[ -d /etc/rrcfg ]]; then
        # Check if directory has content
        if [[ -n "$(ls -A /etc/rrcfg 2>/dev/null)" ]]; then
            info "Migrating /etc/rrcfg → /etc/gz302/rrcfg" >&2
            mkdir -p /etc/gz302/rrcfg
            if cp -r /etc/rrcfg/* /etc/gz302/rrcfg/ 2>/dev/null; then
                chmod 755 /etc/gz302/rrcfg
                chmod 644 /etc/gz302/rrcfg/* 2>/dev/null || true
                rm -rf /etc/rrcfg
                success "Migrated refresh configuration to /etc/gz302/rrcfg" >&2
                ((paths_migrated++))
            else
                warning "Failed to migrate /etc/rrcfg contents" >&2
            fi
        else
            # Empty directory, just remove it
            rm -rf /etc/rrcfg
        fi
    fi
    
    # Migrate old /etc/gz302-rgb directory
    if [[ -d /etc/gz302-rgb ]]; then
        # Check if directory has content
        if [[ -n "$(ls -A /etc/gz302-rgb 2>/dev/null)" ]]; then
            info "Migrating /etc/gz302-rgb → /etc/gz302" >&2
            mkdir -p /etc/gz302
            if cp -r /etc/gz302-rgb/* /etc/gz302/ 2>/dev/null; then
                chmod 755 /etc/gz302
                chmod 644 /etc/gz302/* 2>/dev/null || true
                rm -rf /etc/gz302-rgb
                success "Migrated RGB configuration to /etc/gz302" >&2
                ((paths_migrated++))
            else
                warning "Failed to migrate /etc/gz302-rgb contents" >&2
            fi
        else
            # Empty directory, just remove it
            rm -rf /etc/gz302-rgb
        fi
    fi
    
    # Ensure /etc/gz302 has correct permissions
    if [[ -d /etc/gz302 ]]; then
        mkdir -p /etc/gz302/pwrcfg /etc/gz302/rrcfg
        chmod 755 /etc/gz302 /etc/gz302/pwrcfg /etc/gz302/rrcfg
    fi
    
    if [[ $paths_migrated -gt 0 ]]; then
        success "Successfully migrated $paths_migrated old configuration path(s)" >&2
        echo >&2
        # Create a sentinel so we don't repeatedly prompt the user after a single migration
        mkdir -p /etc/gz302
        touch /etc/gz302/.migrations_v1_done
    fi
    echo "$paths_migrated"
}



# --- Main Execution Logic ---
main() {
    # Verify script is run with root privileges (required for system configuration)
    check_root
    
    # Migrate old paths from pre-1.3.0 versions to FHS-compliant paths
    local paths_migrated
    paths_migrated=$(migrate_old_paths)
    
    if [[ $paths_migrated -gt 0 ]]; then
        info "Migration completed. Please run the script again to complete the setup."
        exit 0
    fi
    
    # Display beautiful banner
    print_banner
    print_section "GZ302 Linux Setup v2.3.13"
    
    # Check for resume from previous installation
    if check_resume "main"; then
        if prompt_resume "main"; then
            local completed_steps
            completed_steps=$(get_completed_steps)
            info "Resuming from checkpoint. Completed steps: $(echo "$completed_steps" | tr ',' ' ')"
        fi
    else
        init_checkpoint "main"
    fi
    
    # Step 1: Kernel version check
    print_step 1 5 "Checking kernel version..."
    if ! is_step_completed "kernel_check"; then
        check_kernel_version >/dev/null
        complete_step "kernel_check"
    fi
    success "Kernel version validated"
    
    # Step 2: Network connectivity check
    print_step 2 5 "Checking network connectivity..."
    if ! is_step_completed "network_check"; then
        if ! check_network; then
            warning "Network connectivity check failed"
            warning "Some features may not work without internet access"
            echo
            if ! ask_yes_no "Do you want to continue anyway? (y/N): " N; then
                error "Setup cancelled. Please connect to the internet and try again."
            fi
            warning "Continuing without network validation..."
        else
            success "Network connectivity confirmed"
        fi
        complete_step "network_check"
    else
        success "Network connectivity (cached)"
    fi
    
    # Step 3: Distribution detection
    print_step 3 5 "Detecting Linux distribution..."
    
    # Get original distribution name for display
    local original_distro=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        original_distro="${ID:-}"
    fi
    
    local detected_distro
    detected_distro=$(detect_distribution)
    
    if [[ "$original_distro" != "$detected_distro" ]]; then
        success "Detected: $original_distro (using $detected_distro base)"
    else
        success "Detected: $detected_distro"
    fi
    
    # Step 4: Config backup
    print_step 4 5 "Creating configuration backup..."
    if ! is_step_completed "config_backup"; then
        create_config_backup "pre-install-$(date +%Y%m%d)" >/dev/null
        complete_step "config_backup"
    fi
    success "Configuration backup created"
    
    # Step 5: System ready
    print_step 5 5 "System ready for configuration"
    echo
    print_subsection "System Information"
    print_keyval "Distribution" "${original_distro:-$detected_distro}"
    print_keyval "Kernel" "$(uname -r)"
    print_keyval "Architecture" "$(uname -m)"
    print_keyval "Target Hardware" "ASUS ROG Flow Z13 (GZ302)"
    echo
    
    print_tip "This script will configure hardware drivers, power management, and display settings"
    echo
    
    # --- Installation Mode Selection ---
    local install_fixes=true
    
    # Check if --power-tools-only flag was passed (skip fixes)
    if [[ "${POWER_TOOLS_ONLY:-false}" == "true" ]]; then
        install_fixes=false
        info "Skipping hardware fixes (--power-tools-only mode)"
    elif [[ "${ASSUME_YES:-false}" != "true" ]]; then
        # Ask user if they want to install hardware fixes
        echo
        print_subsection "Hardware Fixes"
        info "Hardware fixes include kernel parameters, GRUB tweaks, ACPI settings,"
        info "audio firmware (SOF), and RGB keyboard control."
        echo
        info "You can skip these if your hardware is already working, or if you only"
        info "want to install the power config tools (pwrcfg, rrcfg) and Control Center."
        echo
        
        if ask_yes_no "Do you want to install hardware fixes? (Y/n): " Y; then
            install_fixes=true
            info "Hardware fixes will be installed"
        else
            install_fixes=false
            info "Skipping hardware fixes - installing power tools only"
        fi
    fi
    
    echo
    
    # Route to appropriate installation mode
    if [[ "$install_fixes" == false ]]; then
        print_section "Installing Command Center Only"
        install_command_center
        
        echo
        print_section "Setup Complete"
        
        info "Hardware fixes were skipped."
        echo
    else
        # Full installation - route to appropriate setup function based on base distribution
        print_section "Installing Core Components"
        
        case "$detected_distro" in
            "arch")
                setup_arch_based "$detected_distro"
                ;;
            "ubuntu")
                setup_debian_based "$detected_distro"
                ;;
            "fedora")
                setup_fedora_based "$detected_distro"
                ;;
            "opensuse")
                setup_opensuse "$detected_distro"
                ;;
            *)
                error "Unsupported distribution: $detected_distro"
                ;;
        esac
    
        echo
        print_section "Setup Complete"
        
        print_subsection "Applied Hardware Fixes"
        completed_item "Wi-Fi stability (MediaTek MT7925e)"
        completed_item "Touchpad detection and functionality"
        completed_item "Audio support (SOF firmware)"
        completed_item "GPU and thermal optimizations"
        completed_item "GPU and thermal optimizations"
        echo
        
        # Offer Command Center installation (User Tools)
        offer_command_center_install "$detected_distro"
        
        # Offer optional modules
        offer_optional_modules "$detected_distro"
    fi
    
    # Clear checkpoint on successful completion
    clear_checkpoint
    
    echo
    print_box "${SYMBOL_ROCKET} SETUP COMPLETE! ${SYMBOL_ROCKET}" "$C_BOLD_GREEN"
    
    success "Your ROG Flow Z13 (GZ302) is now optimized!"
    echo
    print_subsection "Quick Reference"
    print_keyval "Power profiles" "emergency, battery, efficient, balanced, performance, gaming, maximum"
    print_keyval "Check power" "pwrcfg status"
    print_keyval "Check refresh" "rrcfg status"
    print_keyval "Tray icon" "System tray for quick profile switching"
    echo
    
    warning "A REBOOT is recommended to apply all changes"
    print_tip "Run 'pwrcfg gaming' for maximum performance mode"
    echo
}

# --- Run the script ---
main "$@"
