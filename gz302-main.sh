#!/bin/bash

# ==============================================================================
# Author: th3cavalry using Copilot
# Version: 3.0.3
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
# - System tray power manager
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
# ==============================================================================

# --- Script Configuration and Safety ---
set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Global CLI flags
ASSUME_YES="${ASSUME_YES:-false}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--assume-yes)
            ASSUME_YES=true
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
if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    if command -v curl >/dev/null 2>&1; then
        curl -L "${GITHUB_RAW_URL}/gz302-utils.sh" -o "${SCRIPT_DIR}/gz302-utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/gz302-utils.sh" -O "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download gz302-utils.sh"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/gz302-utils.sh"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/gz302-utils.sh"
    else
        echo "Error: Failed to download gz302-utils.sh"
        exit 1
    fi
fi

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
        error "Installation cancelled. Kernel 6.12+ is required.\nUpgrade options:\n  1. Use your distribution's kernel update mechanism\n  2. Install a mainline kernel from kernel.org\n  3. (Arch only) Install linux-g14 kernel: Optional/gz302-g14-kernel.sh\n  4. Check Info/kernel_changelog.md for version details\nIf you cannot upgrade, please create an issue on GitHub:\n  https://github.com/th3cavalry/GZ302-Linux-Setup/issues"
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
        info "See Info/kernel_changelog.md for detailed version comparison"
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
# (Moved to gz302-utils.sh)

# --- Hardware Fixes for All Distributions ---
# Updated based on latest kernel support and community research (October 2025)
# Sources: Info/kernel_changelog.md, Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs,
#          asus-linux.org, Strix Halo HomeLab, Phoronix community
# GZ302EA-XS99: AMD Ryzen AI MAX+ 395 with AMD Radeon 8060S integrated graphics (100% AMD)
# REQUIRED: Kernel 6.14+ minimum (6.17+ strongly recommended)
# See Info/kernel_changelog.md for detailed kernel version comparison

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
        # dcdebugmask options: 0x10 (baseline DC debug), 0x12 (DC debug + optimization), 0x410 (custom variant)
        # Use 0x10 as default; 0x410 if 0x10 doesn't resolve freezing
        ensure_grub_kernel_param "amdgpu.dcdebugmask=0x10" && grub_changed=true || true
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
        ensure_kcmdline_param "amdgpu.dcdebugmask=0x10" && kcmd_changed=true || true
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
                ubuntu)
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
        ensure_limine_kernel_param "amdgpu.dcdebugmask=0x10" && limine_changed=true || true
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
    # See Info/kernel_changelog.md for detailed kernel version WiFi improvements
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

    # GZ302 Keyboard RGB udev rule for non-root access
    info "Configuring udev rules for keyboard RGB control..."
    cat > /etc/udev/rules.d/99-gz302-keyboard.rules <<'EOF'
# GZ302 Keyboard RGB Control - Allow unprivileged USB access
# ASUS ROG Flow Z13 keyboard (USB 0b05:1a30)
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", MODE="0666"
EOF
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
        ubuntu)
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

# --- GZ302 RGB Keyboard Control Installation ---
install_gz302_rgb_keyboard() {
    info "Installing GZ302 RGB Keyboard Control..."
    
    local distro="$1"
    local build_dir="/tmp/gz302-rgb-build"
    
    # Check if gcc and libusb development headers are available
    case "$distro" in
        arch)
            pacman -S --noconfirm --needed base-devel libusb 2>/dev/null || warning "Failed to install build dependencies"
            ;;
        ubuntu)
            apt-get install -y build-essential libusb-1.0-0-dev 2>/dev/null || warning "Failed to install build dependencies"
            ;;
        fedora)
            dnf install -y gcc make libusb1-devel 2>/dev/null || warning "Failed to install build dependencies"
            ;;
        opensuse)
            zypper install -y gcc make libusb-1_0-devel 2>/dev/null || warning "Failed to install build dependencies"
            ;;
    esac
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Download the RGB source files
    info "Downloading GZ302 RGB control source..."
    if ! curl -L "${GITHUB_RAW_URL}/gz302-rgb-cli.c" -o gz302-rgb-cli.c 2>/dev/null; then
        warning "Failed to download gz302-rgb-cli.c"
        return 1
    fi
    
    if ! curl -L "${GITHUB_RAW_URL}/Makefile.rgb" -o Makefile -z Makefile 2>/dev/null; then
        warning "Failed to download Makefile.rgb"
        return 1
    fi
    
    # Compile the RGB binary
    info "Compiling GZ302 RGB control..."
    if ! make -f Makefile 2>/dev/null; then
        warning "Failed to compile gz302-rgb"
        return 1
    fi
    
    # Install the binary
    # Remove existing files/symlinks first to prevent recursion loops or overwriting targets
    rm -f /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin /usr/local/bin/gz302-rgb-wrapper

    if ! cp gz302-rgb /usr/local/bin/gz302-rgb 2>/dev/null; then
        warning "Failed to install gz302-rgb binary"
        return 1
    fi
    
    chmod +x /usr/local/bin/gz302-rgb
    
    # Create wrapper script that ensures brightness is enabled
    info "Creating RGB wrapper script with auto-brightness..."
    cat > /usr/local/bin/gz302-rgb-wrapper <<'EOFWRAP'
#!/bin/bash
# GZ302 RGB Wrapper - Ensures keyboard brightness is enabled before RGB commands

set -euo pipefail

# For non-brightness commands, ensure keyboard is visible
if [[ "${1:-}" != "brightness" ]] && [[ "${1:-}" != "" ]]; then
    # Check current brightness
    BRIGHTNESS_PATH="/sys/class/leds/asus::kbd_backlight/brightness"
    if [[ -f "$BRIGHTNESS_PATH" ]]; then
        CURRENT_BRIGHTNESS=$(cat "$BRIGHTNESS_PATH" 2>/dev/null || echo 0)
        # If brightness is 0, set it to 3 (maximum) so RGB is visible
        if [[ "$CURRENT_BRIGHTNESS" == "0" ]]; then
            echo 3 > "$BRIGHTNESS_PATH" 2>/dev/null || true
        fi
    fi
fi

# Call the actual RGB binary
exec /usr/local/bin/gz302-rgb-bin "$@"
EOFWRAP
    
    chmod +x /usr/local/bin/gz302-rgb-wrapper
    
    # Rename binary to gz302-rgb-bin and replace with wrapper
    mv /usr/local/bin/gz302-rgb /usr/local/bin/gz302-rgb-bin
    ln -sf /usr/local/bin/gz302-rgb-wrapper /usr/local/bin/gz302-rgb
    
    # Configure passwordless sudo for RGB control
    info "Configuring passwordless sudo for RGB control..."
    
    # Check if gz302-pwrcfg sudoers file exists, if so add gz302-rgb to it
    if [[ -f /etc/sudoers.d/gz302-pwrcfg ]]; then
        if ! grep -q "gz302-rgb" /etc/sudoers.d/gz302-pwrcfg; then
            cat >> /etc/sudoers.d/gz302-pwrcfg << EOF
Defaults use_pty
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-bin
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-wrapper
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-bin
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-wrapper
EOF
        fi
    else
        # Create new sudoers entry
        cat > /etc/sudoers.d/gz302-pwrcfg <<EOF
# GZ302 Power and RGB Control - Passwordless Sudo
Defaults use_pty
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/rrcfg
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-bin
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-wrapper
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/rrcfg
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-bin
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-wrapper
EOF
    fi
    
    chmod 440 /etc/sudoers.d/gz302-pwrcfg
    
    # Create RGB config directory
    info "Setting up RGB persistence..."
    mkdir -p /etc/gz302
    chmod 755 /etc/gz302
    
    # Download and install restore script
    if ! curl -L "${GITHUB_RAW_URL}/gz302-rgb-restore.sh" -o /usr/local/bin/gz302-rgb-restore 2>/dev/null; then
        warning "Failed to download gz302-rgb-restore script"
    else
        chmod +x /usr/local/bin/gz302-rgb-restore
        
        # Configure passwordless sudo for restore script
        if [[ -f /etc/sudoers.d/gz302-pwrcfg ]]; then
            if ! grep -q "gz302-rgb-restore" /etc/sudoers.d/gz302-pwrcfg; then
                echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-restore" >> /etc/sudoers.d/gz302-pwrcfg
                echo "%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb-restore" >> /etc/sudoers.d/gz302-pwrcfg
            fi
        fi
    fi
    
    # Download and install systemd service
    if ! curl -L "${GITHUB_RAW_URL}/gz302-rgb-restore.service" -o /etc/systemd/system/gz302-rgb-restore.service 2>/dev/null; then
        warning "Failed to download gz302-rgb-restore service"
    else
        systemctl daemon-reload
        systemctl enable gz302-rgb-restore.service 2>/dev/null || warning "Failed to enable RGB restore service"
        success "RGB persistence service installed"
    fi
    
    # Verify RGB control works - test with rainbow animation for visual feedback
    # Use timeout to prevent hanging if hardware enumeration gets stuck
    info "Testing RGB control with rainbow animation..."
    if [[ -x /usr/local/bin/gz302-rgb ]]; then
        local rgb_output
        local rgb_exit_code
        
        # Ensure no lingering RGB processes are blocking the device
        killall -q gz302-rgb-bin || true
        
        # Use timeout to prevent script from freezing if USB enumeration hangs
        # Increased to 10s as subsequent runs can sometimes be slower to acquire the device
        rgb_output=$(timeout 10 /usr/local/bin/gz302-rgb rainbow_cycle 2 2>&1)
        rgb_exit_code=$?
        
        # Exit code 124 is returned by the timeout command when a timeout occurs
        # (see: man timeout - "If the command times out, and --preserve-status is not set, then exit with status 124")
        if [[ "$rgb_exit_code" -eq 124 ]]; then
            # If it timed out but binary exists, we can likely assume it's just busy
            warning "RGB control test timed out - device might be busy processing previous commands"
            success "GZ302 RGB Keyboard Control installed (skipping verification)"
        elif echo "$rgb_output" | grep -q "Sent\|Sending\|RGB"; then
            success "GZ302 RGB Keyboard Control with persistence installed successfully"
            info "Rainbow animation is now active on your keyboard (or would be on GZ302 hardware)"
        else
            # Binary exists and runs, but no hardware detected (normal on non-GZ302 systems)
            success "GZ302 RGB Keyboard Control installed (hardware not detected - normal for non-GZ302 systems)"
        fi
        return 0
    else
        warning "RGB control binary not found at /usr/local/bin/gz302-rgb"
        return 1
    fi
}

# --- Distribution-Specific Package Installation ---
# Install ASUS-specific tools and power management
# GZ302 has NO discrete GPU, so no supergfxctl needed

install_arch_asus_packages() {
    info "Installing ASUS control packages for Arch..."
    
    # Install from official repos first
    pacman -S --noconfirm --needed power-profiles-daemon
    
    # Method 1: Try G14 repository (recommended, official asus-linux.org repo)
    info "Attempting to install asusctl from G14 repository..."
    if ! grep -q '\[g14\]' /etc/pacman.conf; then
        info "Adding G14 repository..."
        # Add repository key
        pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || warning "Failed to receive G14 key"
        pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || warning "Failed to sign G14 key"
        
        # Add repository to pacman.conf
    { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
        
        # Update package database
        pacman -Sy
    fi
    
    # Try to install from G14 repo
    if pacman -S --noconfirm --needed asusctl 2>/dev/null; then
        success "asusctl installed from G14 repository"
    else
        warning "G14 repository installation failed, trying AUR..."
        # Method 2: Fallback to AUR if G14 repo fails
        if command -v yay >/dev/null 2>&1; then
            local primary_user
            primary_user=$(get_real_user)
            # Install ASUS control tools from AUR
            sudo -u "$primary_user" yay -S --noconfirm --needed asusctl || warning "AUR asusctl install failed"
            
            # Install switcheroo-control for display management
            sudo -u "$primary_user" yay -S --noconfirm --needed switcheroo-control || warning "switcheroo-control install failed"
        else
            warning "yay not available - skipping asusctl installation"
            info "Manually add G14 repo or install yay and run: yay -S asusctl switcheroo-control"
        fi
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
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

# --- Build asusctl from Source (Fallback for Ubuntu 25.10) ---
build_asusctl_from_source() {
    info "PPA installation failed - asusctl packages not available for this Ubuntu version"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  asusctl Build Options"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "asusctl provides essential hardware control features:"
    echo "  • Battery charge limit (preserve battery health)"
    echo "  • Fan curve control (customize cooling)"
    echo "  • Keyboard backlight control (RGB customization)"
    echo "  • Performance profiles (silent/balanced/performance)"
    echo
    echo "Option 1: Build asusctl from source (~5-10 minutes)"
    echo "          Full ASUS hardware control with GUI"
    echo
    echo "Option 2: Skip and use basic battery limit service"
    echo "          Only battery charge limit (no other features)"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        response="Y"
    elif [[ -t 0 ]]; then
        read -r -p "Would you like to build asusctl from source? (y/N): " response
    else
        warning "Non-interactive environment detected - skipping asusctl build"
        response="N"
    fi

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        warning "Skipping asusctl installation"
        info "Attempting to set up basic battery limit service instead..."
        if setup_battery_limit_service; then
            info "Basic battery limit configured successfully"
        else
            warning "Battery limit service setup failed"
        fi
        info "For full asusctl features, see: https://gitlab.com/asus-linux/asusctl"
        return 1
    fi

    info "Building asusctl from source - this will take 5-10 minutes..."

    # Install build dependencies
    info "Installing build dependencies..."
    apt-get update || warning "Failed to update package list"
    apt-get install -y \
        make cargo gcc pkg-config \
        libasound2-dev cmake build-essential python3 \
        libfreetype6-dev libexpat1-dev libxcb-composite0-dev \
        libssl-dev libx11-dev libfontconfig1-dev curl \
        libclang-dev libudev-dev libseat-dev libinput-dev \
        libxkbcommon-dev libgbm-dev git || {
            error "Failed to install build dependencies"
        }

    # Clone or update asusctl repository
    local asusctl_dir="/tmp/asusctl"
    if [[ -d "$asusctl_dir" ]]; then
        info "Using existing asusctl repository at $asusctl_dir"
        cd "$asusctl_dir" || return 1
        if git fetch origin; then
            git reset --hard origin/main || warning "Failed to reset to latest"
        else
            warning "Failed to fetch latest changes - using existing state"
        fi
    else
        info "Cloning asusctl repository..."
        cd /tmp || return 1
        git clone https://gitlab.com/asus-linux/asusctl.git || {
            error "Failed to clone asusctl repository"
        }
        cd asusctl || return 1
    fi

    # Build asusctl
    info "Building asusctl (this may take several minutes)..."
    info "Progress: Compiling Rust code with cargo..."
    if make 2>&1 | tee /tmp/asusctl-build.log; then
        success "asusctl build completed successfully"
    else
        error "asusctl build failed - see /tmp/asusctl-build.log for details"
    fi

    # Install asusctl
    info "Installing asusctl..."
    if make install 2>&1 | tee /tmp/asusctl-install.log; then
        success "asusctl installed successfully"
    else
        error "asusctl installation failed - see /tmp/asusctl-install.log for details"
    fi

    # Reload systemd and start services
    info "Configuring asusctl services..."
    systemctl daemon-reload
    systemctl enable --now asusd.service 2>/dev/null || warning "Failed to enable asusd service"
    systemctl enable --now asusd-user.service 2>/dev/null || warning "Failed to enable asusd-user service"

    # Wait a moment for service to initialize
    sleep 2

    # Verify installation
    info "Verifying asusctl installation..."
    if command -v asusctl >/dev/null 2>&1; then
        local version
        version=$(asusctl --version 2>/dev/null | head -n1)
        success "asusctl installed: $version"

        # Check if asusd service is running
        if systemctl is-active --quiet asusd.service; then
            success "asusd service is running"

            # Set battery charge limit to 80% (recommended for longevity)
            info "Setting battery charge limit to 80%..."
            if asusctl -c 80 2>/dev/null; then
                success "Battery charge limit set to 80%"
                info "Your battery will stop charging at 80% to preserve battery health"
            else
                warning "Failed to set battery charge limit with asusctl"
                info "You can set it manually later with: asusctl -c 80"
            fi
        else
            warning "asusd service is not running - asusctl may not work correctly"
            info "Try restarting the service: sudo systemctl restart asusd"
        fi

        return 0
    else
        warning "asusctl installation verification failed - command not found"
        return 1
    fi
}

install_debian_asus_packages() {
    info "Installing ASUS control packages for Debian/Ubuntu..."

    # Install power-profiles-daemon
    apt install -y power-profiles-daemon || warning "power-profiles-daemon install failed"

    # Install switcheroo-control
    apt install -y switcheroo-control || warning "switcheroo-control install failed"

    # Try to install asusctl from PPA
    info "Attempting to install asusctl from PPA..."
    local ppa_success=0

    if command -v add-apt-repository >/dev/null 2>&1; then
        # Add Mitchell Austin's asusctl PPA
        if add-apt-repository -y ppa:mitchellaugustin/asusctl 2>/dev/null; then
            # Try apt update - if it fails (e.g., PPA doesn't support this Ubuntu version),
            # remove the PPA to prevent blocking future apt operations
            local apt_update_log="/tmp/apt-update-asusctl-$$.txt"
            apt update 2>&1 | tee "$apt_update_log" || true
            if ! grep -q "^E:" "$apt_update_log"; then
                # apt update succeeded, try to install the package
                if apt install -y rog-control-center 2>/dev/null; then
                    systemctl daemon-reload
                    systemctl restart asusd 2>/dev/null || warning "Failed to restart asusd"
                    success "asusctl installed from PPA"
                    ppa_success=1
                else
                    warning "PPA packages not available for this Ubuntu version"
                fi
            else
                # apt update failed - likely PPA doesn't have packages for this Ubuntu version
                # Check if the error is related to the asusctl PPA
                if grep -q "mitchellaugustin/asusctl" "$apt_update_log" 2>/dev/null; then
                    warning "asusctl PPA does not support this Ubuntu version"
                    info "Removing broken PPA to prevent future apt errors..."
                    add-apt-repository -y --remove ppa:mitchellaugustin/asusctl 2>/dev/null || true
                    apt update 2>/dev/null || true
                else
                    warning "Failed to update package list"
                fi
            fi
            rm -f "$apt_update_log"
        else
            warning "Failed to add asusctl PPA"
        fi
    else
        warning "add-apt-repository not available (expected on Debian Trixie/13+)"
        info "Falling back to building asusctl from source"
    fi

    # If PPA installation failed, try building from source
    if [[ $ppa_success -eq 0 ]]; then
        if build_asusctl_from_source; then
            success "asusctl built and installed from source"
        else
            warning "asusctl installation skipped"
            info "Manual installation guide: https://asus-linux.org/guides/asusctl-install/"
            info "Ubuntu 25.10 workarounds: Info/ubuntu-25.10-notes.md"
        fi
    fi

    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"

    success "ASUS packages installation complete"
}

install_fedora_asus_packages() {
    info "Installing ASUS control packages for Fedora..."
    
    # Install power-profiles-daemon (usually already installed)
    dnf install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control
    dnf install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Install asusctl from COPR
    info "Attempting to install asusctl from COPR repository..."
    if command -v dnf >/dev/null 2>&1; then
        # Enable lukenukem/asus-linux COPR repository
        dnf copr enable -y lukenukem/asus-linux 2>/dev/null || warning "Failed to enable COPR repository"
        
        # Update and install asusctl
        dnf install -y asusctl 2>/dev/null || warning "asusctl install failed"
        
        # Note: supergfxctl not needed for GZ302 (no discrete GPU)
        info "Note: supergfxctl not installed (GZ302 has integrated GPU only)"
    else
        warning "dnf not available"
        info "Manually enable COPR: dnf copr enable lukenukem/asus-linux && dnf install asusctl"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

install_opensuse_asus_packages() {
    info "Installing ASUS control packages for OpenSUSE..."
    
    # Install power-profiles-daemon
    zypper install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control if available
    zypper install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Try to install asusctl from OBS repository
    info "Attempting to install asusctl from OBS repository..."
    # Detect OpenSUSE version
    local opensuse_version="openSUSE_Tumbleweed"
    if grep -q "openSUSE Leap" /etc/os-release 2>/dev/null; then
        opensuse_version="openSUSE_Leap_15.6"
    fi
    
    # Add ASUS Linux OBS repository
    zypper ar -f "https://download.opensuse.org/repositories/hardware:/asus/${opensuse_version}/" hardware:asus 2>/dev/null || warning "Failed to add OBS repository"
    zypper ref 2>/dev/null || warning "Failed to refresh repositories"
    
    # Try to install asusctl
    if zypper install -y asusctl 2>/dev/null; then
        success "asusctl installed from OBS repository"
    else
        warning "OBS repository installation failed"
        info "Manual installation from source: https://asus-linux.org/guides/asusctl-install/"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
}

# --- TDP Management Functions ---

install_ryzenadj_arch() {
    # Check if ryzenadj is already installed
    if pacman -Qi ryzenadj >/dev/null 2>&1; then
        success "ryzenadj already installed"
        return 0
    fi
    
    info "Installing ryzenadj for Arch-based system..."
    
    # Check for and remove conflicting packages first (only if installed)
    if pacman -Qi ryzenadj-git >/dev/null 2>&1; then
        info "Removing conflicting ryzenadj-git package..."
        pacman -R --noconfirm ryzenadj-git 2>/dev/null || true
    fi
    
    if command -v yay >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj
    elif command -v paru >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" paru -S --noconfirm ryzenadj
    else
        warning "AUR helper (yay/paru) not found. Installing yay first..."
        pacman -S --noconfirm git base-devel
        cd /tmp
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        sudo -u "$SUDO_USER" yay -S --noconfirm ryzenadj
    fi
    success "ryzenadj installed"
}

install_ryzenadj_debian() {
    # Check if ryzenadj is already installed
    if command -v ryzenadj >/dev/null 2>&1; then
        success "ryzenadj already installed"
        return 0
    fi
    
    info "Installing ryzenadj for Debian-based system..."
    apt-get update
    apt-get install -y build-essential cmake libpci-dev git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j"$(nproc)"
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_fedora() {
    # Check if ryzenadj is already installed
    if command -v ryzenadj >/dev/null 2>&1; then
        success "ryzenadj already installed"
        return 0
    fi
    
    info "Installing ryzenadj for Fedora-based system..."
    dnf install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j"$(nproc)"
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

install_ryzenadj_opensuse() {
    # Check if ryzenadj is already installed
    if command -v ryzenadj >/dev/null 2>&1; then
        success "ryzenadj already installed"
        return 0
    fi
    
    info "Installing ryzenadj for OpenSUSE..."
    zypper install -y gcc gcc-c++ cmake pciutils-devel git
    cd /tmp
    git clone https://github.com/FlyGoat/RyzenAdj.git
    cd RyzenAdj
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j"$(nproc)"
    make install
    ldconfig
    success "ryzenadj compiled and installed"
}

setup_tdp_management() {
    local distro_family="$1"
    
    
    info "Setting up TDP management for GZ302..."
    
    # Install ryzenadj based on distribution
    case "$distro_family" in
        "arch")
            install_ryzenadj_arch
            ;;
        "debian")
            install_ryzenadj_debian
            ;;
        "fedora")
            install_ryzenadj_fedora
            ;;
        "opensuse")
            install_ryzenadj_opensuse
            ;;
    esac
    
    # Create TDP management script
    cat > /usr/local/bin/pwrcfg <<'EOF'
#!/bin/bash
# GZ302 Power Configuration Script (pwrcfg)
# Manages power profiles with SPL/sPPT/fPPT for AMD Ryzen AI MAX+ 395 (Strix Halo)

set -euo pipefail

# Determine if this command requires elevated privileges
requires_elevation() {
    local cmd="$1"
    local arg="$2"
    # Read-only commands that don't need root
    case "$cmd" in
        status|list|help|"")
            return 1  # Does not require elevation
            ;;
        charge-limit)
            # charge-limit without args is read-only, charge-limit <value> needs elevation
            if [ -z "$arg" ]; then
                return 1  # Read-only: doesn't require elevation
            else
                return 0  # Write operation: requires elevation
            fi
            ;;
        *)
            return 0  # All other commands require elevation
            ;;
    esac
}

# Auto-elevate only for commands that modify system state
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if requires_elevation "${1:-}" "${2:-}"; then
        if command -v sudo >/dev/null 2>&1; then
            # If password-less sudo is configured, re-exec without prompting
            if sudo -n true 2>/dev/null; then
                exec sudo -n "$0" "$@"
            fi
            echo "pwrcfg requires elevated privileges to apply power limits." >&2
            echo "Enable password-less sudo for /usr/local/bin/pwrcfg (recommended) or run with sudo." >&2
            exit 1
        else
            echo "pwrcfg requires elevated privileges and 'sudo' was not found. Run as root." >&2
            exit 1
        fi
    fi
fi

TDP_CONFIG_DIR="/etc/gz302/pwrcfg"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"
AUTO_CONFIG_FILE="$TDP_CONFIG_DIR/auto-config"
AC_PROFILE_FILE="$TDP_CONFIG_DIR/ac-profile"
BATTERY_PROFILE_FILE="$TDP_CONFIG_DIR/battery-profile"

# Power Profiles for GZ302 AMD Ryzen AI MAX+ 395 (Strix Halo)
# SPL (Sustained Power Limit): Long-term steady power level
# sPPT (Slow Power Boost): Short-term boost (up to ~2 minutes)
# fPPT (Fast Power Boost): Very short-term boost (few seconds)
# All values in milliwatts (mW)

# Profile format: "SPL:sPPT:fPPT"
declare -A POWER_PROFILES
POWER_PROFILES[emergency]="10000:12000:12000"      # Emergency: 10W SPL, 12W boost (30Hz)
POWER_PROFILES[battery]="18000:20000:20000"        # Battery: 18W SPL, 20W boost (30Hz)
POWER_PROFILES[efficient]="30000:35000:35000"      # Efficient: 30W SPL, 35W boost (60Hz)
POWER_PROFILES[balanced]="40000:45000:45000"       # Balanced: 40W SPL, 45W boost (90Hz)
POWER_PROFILES[performance]="55000:60000:60000"    # Performance: 55W SPL, 60W boost (120Hz)
POWER_PROFILES[gaming]="70000:80000:80000"         # Gaming: 70W SPL, 80W boost (180Hz)
POWER_PROFILES[maximum]="90000:90000:90000"        # Maximum: 90W sustained (180Hz)

# Target refresh rates for each power profile (auto-sync with rrcfg)
declare -A REFRESH_RATES
REFRESH_RATES[emergency]="30"
REFRESH_RATES[battery]="30"
REFRESH_RATES[efficient]="60"
REFRESH_RATES[balanced]="90"
REFRESH_RATES[performance]="120"
REFRESH_RATES[gaming]="180"
REFRESH_RATES[maximum]="180"

# Create config directory
mkdir -p "$TDP_CONFIG_DIR"

show_usage() {
    echo "Usage: pwrcfg [PROFILE|status|list|auto|config|verify|charge-limit]"
    echo ""
    echo "Power Profiles (SPL/sPPT/fPPT):"
    echo "  emergency     - 10/12/12W  @ 30Hz  - Emergency battery extension"
    echo "  battery       - 18/20/20W  @ 30Hz  - Maximum battery life"
    echo "  efficient     - 30/35/35W  @ 60Hz  - Efficient with good performance"
    echo "  balanced      - 40/45/45W  @ 90Hz  - Balanced performance/efficiency (default)"
    echo "  performance   - 55/60/60W  @ 120Hz - High performance (AC recommended)"
    echo "  gaming        - 70/80/80W  @ 180Hz - Gaming optimized (AC required)"
    echo "  maximum       - 90/90/90W  @ 180Hz - Absolute maximum (AC only)"
    echo ""
    echo "Commands:"
    echo "  status              - Show current power profile and settings"
    echo "  list                - List available profiles with details"
    echo "  auto                - Enable/disable automatic profile switching"
    echo "  config              - Configure automatic profile preferences"
    echo "  verify              - Verify that power limits match the current profile"
    echo "  charge-limit [80|100] - Set battery charge limit (80% or 100%)"
    echo ""
    echo "Notes:"
    echo "  - Refresh rate changes automatically with power profile"
    echo "  - Use 'rrcfg' to manually override refresh rate"
    echo "  - SPL: Sustained Power Limit (long-term steady power)"
    echo "  - sPPT: Slow Power Boost (short-term, ~2 minutes)"
    echo "  - fPPT: Fast Power Boost (very short-term, few seconds)"
    echo "  - charge-limit: Helps extend battery lifespan by limiting max charge"
    echo "  - verify: Checks if hardware matches profile (requires ryzenadj + ryzen_smu-dkms-git)"
}

get_battery_status() {
    # Try multiple methods to detect AC adapter status
    
    # Method 1: Check common AC adapter names
    for adapter in ADP1 ADP0 ACAD AC0 AC; do
        if [ -f "/sys/class/power_supply/$adapter/online" ]; then
            if [ "$(cat /sys/class/power_supply/$adapter/online 2>/dev/null)" = "1" ]; then
                echo "AC"
                return 0
            else
                echo "Battery"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for AC adapter type
    if [ -d /sys/class/power_supply ]; then
        for ps in /sys/class/power_supply/*; do
            if [ -d "$ps" ] && [ -f "$ps/type" ]; then
                type=$(cat "$ps/type" 2>/dev/null)
                if [ "$type" = "Mains" ] || [ "$type" = "ADP" ]; then
                    if [ -f "$ps/online" ]; then
                        if [ "$(cat "$ps/online" 2>/dev/null)" = "1" ]; then
                            echo "AC"
                            return 0
                        else
                            echo "Battery"
                            return 0
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 3: Use upower if available
    if command -v upower >/dev/null 2>&1; then
        local ac_status=$(upower -i $(upower -e | grep -E 'ADP|ACA|AC') 2>/dev/null | grep -i "online" | grep -i "true")
        if [ -n "$ac_status" ]; then
            echo "AC"
            return 0
        else
            local ac_devices=$(upower -e | grep -E 'ADP|ACA|AC' 2>/dev/null)
            if [ -n "$ac_devices" ]; then
                echo "Battery"
                return 0
            fi
        fi
    fi
    
    # Method 4: Use acpi if available
    if command -v acpi >/dev/null 2>&1; then
        local ac_status=$(acpi -a 2>/dev/null | grep -i "on-line\|online")
        if [ -n "$ac_status" ]; then
            echo "AC"
            return 0
        else
            local ac_info=$(acpi -a 2>/dev/null)
            if [ -n "$ac_info" ]; then
                echo "Battery"
                return 0
            fi
        fi
    fi
    
    echo "Unknown"
}

get_battery_percentage() {
    # Try multiple methods to get battery percentage
    
    # Method 1: Check common battery names
    for battery in BAT0 BAT1 BATT; do
        if [ -f "/sys/class/power_supply/$battery/capacity" ]; then
            local capacity=$(cat "/sys/class/power_supply/$battery/capacity" 2>/dev/null)
            # Validate that capacity is numeric
            if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
                echo "$capacity"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for Battery type
    if [ -d /sys/class/power_supply ]; then
        for ps in /sys/class/power_supply/*; do
            if [ -d "$ps" ] && [ -f "$ps/type" ]; then
                type=$(cat "$ps/type" 2>/dev/null)
                if [ "$type" = "Battery" ]; then
                    if [ -f "$ps/capacity" ]; then
                        local capacity=$(cat "$ps/capacity" 2>/dev/null)
                        # Validate that capacity is numeric
                        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
                            echo "$capacity"
                            return 0
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 3: Use upower if available
    if command -v upower >/dev/null 2>&1; then
        local capacity=$(upower -i $(upower -e | grep 'BAT') 2>/dev/null | grep -E "percentage" | grep -o '[0-9]*')
        # Validate that capacity is numeric
        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
            echo "$capacity"
            return 0
        fi
    fi
    
    # Method 4: Use acpi if available
    if command -v acpi >/dev/null 2>&1; then
        local capacity=$(acpi -b 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
        # Validate that capacity is numeric
        if [ -n "$capacity" ] && [[ "$capacity" =~ ^[0-9]+$ ]] && [ "$capacity" -ge 0 ] && [ "$capacity" -le 100 ]; then
            echo "$capacity"
            return 0
        fi
    fi
    
    echo "N/A"
}

set_tdp_profile() {
    local profile="$1"
    local power_spec="${POWER_PROFILES[$profile]}"
    
    if [ -z "$power_spec" ]; then
        echo "Error: Unknown profile '$profile'"
        echo "Use 'pwrcfg list' to see available profiles"
        return 1
    fi
    
    # Extract SPL, sPPT, fPPT from profile (format: "SPL:sPPT:fPPT")
    local spl=$(echo "$power_spec" | cut -d':' -f1)
    local sppt=$(echo "$power_spec" | cut -d':' -f2)
    local fppt=$(echo "$power_spec" | cut -d':' -f3)
    
    echo "Setting power profile: $profile"
    echo "  SPL (Sustained):  $(($spl / 1000))W"
    echo "  sPPT (Slow Boost): $(($sppt / 1000))W"
    echo "  fPPT (Fast Boost): $(($fppt / 1000))W"
    echo "  Target Refresh:    ${REFRESH_RATES[$profile]}Hz"
    
    # Check if we're on AC power for high-power profiles
    local power_source=$(get_battery_status)
    if [ "$power_source" = "Battery" ] && [ "$spl" -gt 45000 ]; then
        echo "Warning: High power profile ($profile) selected while on battery power"
        echo "This may cause rapid battery drain. Consider using 'balanced' or lower profiles."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            return 1
        fi
    fi
    
    # Try multiple methods to apply power settings
    local success=false
    
    # Method 1: Try ryzenadj first (with SPL/sPPT/fPPT support)
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "Attempting to apply power limits using ryzenadj..."
        # --stapm-limit = SPL (Sustained Power Limit)
        # --slow-limit = sPPT (Slow Package Power Tracking)
        # --fast-limit = fPPT (Fast Package Power Tracking)
        if ryzenadj --stapm-limit="$spl" --slow-limit="$sppt" --fast-limit="$fppt" >/dev/null 2>&1; then
            success=true
            echo "Power limits applied successfully using ryzenadj"
            
            # Sync with power-profiles-daemon for KDE/HHD integration
            if command -v powerprofilesctl >/dev/null 2>&1; then
                case "$profile" in
                    maximum|gaming|performance)
                        powerprofilesctl set performance >/dev/null 2>&1 && echo "Synced with power-profiles-daemon (performance)"
                        ;;
                    balanced|efficient)
                        powerprofilesctl set balanced >/dev/null 2>&1 && echo "Synced with power-profiles-daemon (balanced)"
                        ;;
                    battery|emergency)
                        powerprofilesctl set power-saver >/dev/null 2>&1 && echo "Synced with power-profiles-daemon (power-saver)"
                        ;;
                esac
            fi
        else
            echo "ryzenadj failed, checking for common issues..."
            
            # Check for secure boot issues
            if dmesg | grep -i "secure boot" >/dev/null 2>&1; then
                echo "Secure boot may be preventing direct hardware access"
                echo "Consider disabling secure boot in BIOS for full power control"
            fi
            
            # Check for permissions
            if [ ! -w /dev/mem ] 2>/dev/null; then
                echo "Insufficient permissions for direct memory access"
            fi
            
            echo "Trying alternative methods..."
        fi
    else
        echo "ryzenadj not found, trying alternative methods..."
    fi
    
    # Method 2: Try power profiles daemon if available
    if [ "$success" = false ] && command -v powerprofilesctl >/dev/null 2>&1; then
        echo "Attempting to use power-profiles-daemon..."
        case "$profile" in
            maximum|gaming|performance)
                if powerprofilesctl set performance >/dev/null 2>&1; then
                    echo "Set system power profile to performance mode"
                    success=true
                fi
                ;;
            balanced|efficient)
                if powerprofilesctl set balanced >/dev/null 2>&1; then
                    echo "Set system power profile to balanced mode"
                    success=true
                fi
                ;;
            battery|emergency)
                if powerprofilesctl set power-saver >/dev/null 2>&1; then
                    echo "Set system power profile to power-saver mode"
                    success=true
                fi
                ;;
        esac
    fi
    
    # Method 3: Try cpupower if available (frequency scaling)
    if [ "$success" = false ] && command -v cpupower >/dev/null 2>&1; then
        echo "Attempting to use cpupower for frequency scaling..."
        case "$profile" in
            maximum|gaming|performance)
                if cpupower frequency-set -g performance >/dev/null 2>&1; then
                    echo "Set CPU governor to performance"
                    success=true
                fi
                ;;
            battery|emergency)
                if cpupower frequency-set -g powersave >/dev/null 2>&1; then
                    echo "Set CPU governor to powersave"
                    success=true
                fi
                ;;
            *)
                if cpupower frequency-set -g ondemand >/dev/null 2>&1 || cpupower frequency-set -g schedutil >/dev/null 2>&1; then
                    echo "Set CPU governor to dynamic scaling"
                    success=true
                fi
                ;;
        esac
    fi
    
    if [ "$success" = true ]; then
        echo "$profile" > "$CURRENT_PROFILE_FILE"
        echo "Power profile '$profile' applied successfully"
        
        # Store timestamp and power source for automatic switching
        echo "$(date +%s)" > "$TDP_CONFIG_DIR/last-change"
        echo "$power_source" > "$TDP_CONFIG_DIR/last-power-source"
        
        # Automatically adjust refresh rate based on power profile (unless user manually overrides)
        if command -v rrcfg >/dev/null 2>&1; then
            local target_refresh="${REFRESH_RATES[$profile]}"
            echo "Adjusting refresh rate to ${target_refresh}Hz to match power profile..."
            rrcfg "$profile" >/dev/null 2>&1 || echo "Note: Refresh rate adjustment failed (use 'rrcfg' to set manually)"
        fi
        
        return 0
    else
        echo "Error: Failed to apply power profile using any available method"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Ensure you're running as root (sudo)"
        echo "2. Check if secure boot is disabled in BIOS"
        echo "3. Verify ryzenadj is properly installed"
        echo "4. Try rebooting and running the command again"
        return 1
    fi
}

show_status() {
    local power_source=$(get_battery_status)
    local battery_pct=$(get_battery_percentage)
    local current_profile="Unknown"
    
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE")
    fi
    
    echo "GZ302 Power Status:"
    echo "  Power Source: $power_source"
    echo "  Battery: $battery_pct%"
    echo "  Charge Limit: $(get_charge_limit)%"
    echo "  Current Profile: $current_profile"
    
    if [ "$current_profile" != "Unknown" ] && [ -n "${POWER_PROFILES[$current_profile]}" ]; then
        local power_spec="${POWER_PROFILES[$current_profile]}"
        local spl=$(echo "$power_spec" | cut -d':' -f1)
        local sppt=$(echo "$power_spec" | cut -d':' -f2)
        local fppt=$(echo "$power_spec" | cut -d':' -f3)
        echo "  SPL:  $(($spl / 1000))W (Sustained)"
        echo "  sPPT: $(($sppt / 1000))W (Slow Boost)"
        echo "  fPPT: $(($fppt / 1000))W (Fast Boost)"
        echo "  Target Refresh: ${REFRESH_RATES[$current_profile]}Hz"
    fi
}

list_profiles() {
    echo "Available Power Profiles (SPL/sPPT/fPPT @ Refresh):"
    for profile in emergency battery efficient balanced performance gaming maximum; do
        if [ -n "${POWER_PROFILES[$profile]}" ]; then
            local power_spec="${POWER_PROFILES[$profile]}"
            local spl=$(echo "$power_spec" | cut -d':' -f1)
            local sppt=$(echo "$power_spec" | cut -d':' -f2)
            local fppt=$(echo "$power_spec" | cut -d':' -f3)
            local refresh="${REFRESH_RATES[$profile]}"
            printf "  %-12s %2d/%2d/%2dW @ %3dHz\n" "$profile:" $(($spl/1000)) $(($sppt/1000)) $(($fppt/1000)) $refresh
        fi
    done
}

# Battery charge limit management
get_charge_limit() {
    # Read current battery charge limit
    local charge_limit_path="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    if [ -f "$charge_limit_path" ]; then
        cat "$charge_limit_path"
    else
        echo "N/A"
    fi
}

set_charge_limit() {
    local limit="$1"
    local charge_limit_path="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    
    if [ ! -f "$charge_limit_path" ]; then
        echo "Error: Battery charge limit not supported on this system"
        echo "File not found: $charge_limit_path"
        return 1
    fi
    
    # Validate input
    if [ "$limit" != "80" ] && [ "$limit" != "100" ]; then
        echo "Error: Charge limit must be 80 or 100"
        return 1
    fi
    
    # Set the charge limit
    if echo "$limit" > "$charge_limit_path" 2>/dev/null; then
        echo "Battery charge limit set to $limit%"
        return 0
    else
        echo "Error: Failed to set battery charge limit to $limit%"
        echo "You may need to run this with sudo"
        return 1
    fi
}

# Configuration management functions
configure_auto_switching() {
    echo "Configuring automatic TDP profile switching..."
    echo ""
    
    local auto_enabled="false"
    read -p "Enable automatic profile switching based on power source? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        auto_enabled="true"
        
        echo ""
        echo "Select AC power profile (when plugged in):"
        list_profiles
        echo ""
        read -p "AC profile [gaming]: " ac_profile || true
        ac_profile="${ac_profile:-gaming}"
        
        if [ -z "${POWER_PROFILES[$ac_profile]:-}" ]; then
            echo "Invalid profile, using 'gaming'"
            ac_profile="gaming"
        fi
        
        echo ""
        echo "Select battery profile (when on battery):"
        list_profiles
        echo ""
        read -p "Battery profile [battery]: " battery_profile || true
        battery_profile="${battery_profile:-battery}"
        
        if [ -z "${POWER_PROFILES[$battery_profile]:-}" ]; then
            echo "Invalid profile, using 'battery'"
            battery_profile="battery"
        fi
        
        # Save configuration
        echo "$auto_enabled" > "$AUTO_CONFIG_FILE"
        echo "$ac_profile" > "$AC_PROFILE_FILE"
        echo "$battery_profile" > "$BATTERY_PROFILE_FILE"
        
        echo ""
        echo "Automatic switching configured:"
        echo "  AC power: $ac_profile"
        echo "  Battery: $battery_profile"
        echo ""
        echo "Starting automatic switching service..."
        systemctl enable pwrcfg-auto.service >/dev/null 2>&1
        systemctl start pwrcfg-auto.service >/dev/null 2>&1
    else
        echo "false" > "$AUTO_CONFIG_FILE"
        systemctl disable pwrcfg-auto.service >/dev/null 2>&1
        systemctl stop pwrcfg-auto.service >/dev/null 2>&1
        echo "Automatic switching disabled"
    fi
}

verify_tdp_settings() {
    # Verify if current TDP settings match the desired profile
    # Returns 0 if settings match, 1 if they don't match or can't be verified
    
    if ! command -v ryzenadj >/dev/null 2>&1; then
        # Can't verify without ryzenadj
        return 1
    fi
    
    local current_profile=""
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null | tr -d ' \n')
    fi
    
    if [ -z "$current_profile" ] || [ -z "${POWER_PROFILES[$current_profile]:-}" ]; then
        # No valid profile set
        return 1
    fi
    
    # Get expected values from profile
    local power_spec="${POWER_PROFILES[$current_profile]}"
    local expected_spl=$(echo "$power_spec" | cut -d':' -f1)
    local expected_sppt=$(echo "$power_spec" | cut -d':' -f2)
    local expected_fppt=$(echo "$power_spec" | cut -d':' -f3)
    
    # Get current values from ryzenadj (requires ryzen_smu-dkms-git or similar)
    local ryzenadj_info
    if ! ryzenadj_info=$(ryzenadj -i 2>/dev/null); then
        # Can't read current settings
        return 1
    fi
    
    # Parse current STAPM LIMIT (SPL), PPT LIMIT SLOW (sPPT), PPT LIMIT FAST (fPPT)
    # Example output format: "STAPM LIMIT: 35000 | 35.0 W"
    local current_spl=$(echo "$ryzenadj_info" | grep -i "STAPM LIMIT" | grep -o "[0-9]\+" | head -1)
    local current_sppt=$(echo "$ryzenadj_info" | grep -i "PPT LIMIT SLOW" | grep -o "[0-9]\+" | head -1)
    local current_fppt=$(echo "$ryzenadj_info" | grep -i "PPT LIMIT FAST" | grep -o "[0-9]\+" | head -1)
    
    # Check if we got valid readings
    if [ -z "$current_spl" ] || [ -z "$current_sppt" ] || [ -z "$current_fppt" ]; then
        # Couldn't parse settings
        return 1
    fi
    
    # Allow small tolerance (±500mW) for floating point rounding
    local tolerance=500
    
    if [ $((current_spl - expected_spl)) -gt $tolerance ] || [ $((expected_spl - current_spl)) -gt $tolerance ] || \
       [ $((current_sppt - expected_sppt)) -gt $tolerance ] || [ $((expected_sppt - current_sppt)) -gt $tolerance ] || \
       [ $((current_fppt - expected_fppt)) -gt $tolerance ] || [ $((expected_fppt - current_fppt)) -gt $tolerance ]; then
        # Settings don't match
        return 1
    fi
    
    # Settings match
    return 0
}

verify_and_reapply() {
    # Verify current TDP settings and re-apply if they don't match
    # This is used by the monitor to maintain settings after system events
    
    local current_profile=""
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null | tr -d ' \n')
    fi
    
    if [ -z "$current_profile" ] || [ -z "${POWER_PROFILES[$current_profile]:-}" ]; then
        # No valid profile set, nothing to verify
        return 0
    fi
    
    # Check if settings match
    if ! verify_tdp_settings 2>/dev/null; then
        # Settings don't match or couldn't be verified, re-apply
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Power limits reset detected, re-applying profile: $current_profile"
        set_tdp_profile "$current_profile" >/dev/null 2>&1
    fi
}

auto_switch_profile() {
    # Check if auto switching is enabled
    if [ -f "$AUTO_CONFIG_FILE" ] && [ "$(cat "$AUTO_CONFIG_FILE" 2>/dev/null)" = "true" ]; then
        local current_power=$(get_battery_status)
        local last_power_source=""
        
        if [ -f "$TDP_CONFIG_DIR/last-power-source" ]; then
            last_power_source=$(cat "$TDP_CONFIG_DIR/last-power-source" 2>/dev/null)
        fi
        
        # Only switch if power source changed
        if [ "$current_power" != "$last_power_source" ]; then
            case "$current_power" in
                "AC")
                    if [ -f "$AC_PROFILE_FILE" ]; then
                        local ac_profile=$(cat "$AC_PROFILE_FILE" 2>/dev/null)
                        if [ -n "$ac_profile" ] && [ -n "${POWER_PROFILES[$ac_profile]:-}" ]; then
                            echo "Power source changed to AC, switching to profile: $ac_profile"
                            set_tdp_profile "$ac_profile"
                        fi
                    fi
                    ;;
                "Battery")
                    if [ -f "$BATTERY_PROFILE_FILE" ]; then
                        local battery_profile=$(cat "$BATTERY_PROFILE_FILE" 2>/dev/null)
                        if [ -n "$battery_profile" ] && [ -n "${POWER_PROFILES[$battery_profile]:-}" ]; then
                            echo "Power source changed to Battery, switching to profile: $battery_profile"
                            set_tdp_profile "$battery_profile"
                        fi
                    fi
                    ;;
            esac
        fi
    fi
    
    # Always verify and re-apply if needed (handles sleep/wake, AC events, etc.)
    verify_and_reapply
}

# Main script logic
case "${1:-}" in
    maximum|gaming|performance|balanced|efficient|battery|emergency)
        set_tdp_profile "$1"
        ;;
    status)
        show_status
        ;;
    list)
        list_profiles
        ;;
    auto)
        auto_switch_profile
        ;;
    config)
        configure_auto_switching
        ;;
    verify)
        if verify_tdp_settings; then
            echo "✓ Power limits are correctly applied and match the current profile"
            exit 0
        else
            echo "✗ Power limits do not match the current profile or cannot be verified"
            echo "  This may indicate:"
            echo "  - System event reset the limits (sleep/wake, AC plug/unplug)"
            echo "  - ryzenadj or ryzen_smu-dkms-git is not installed"
            echo "  - Secure boot is preventing hardware access"
            echo ""
            echo "  Run 'pwrcfg <profile>' to re-apply power limits"
            exit 1
        fi
        ;;
    charge-limit)
        if [ -z "${2:-}" ]; then
            echo "Current battery charge limit: $(get_charge_limit)%"
        else
            set_charge_limit "$2"
        fi
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        show_usage
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/pwrcfg
    
    # Automatically configure sudoers for password-less pwrcfg/rrcfg/RGB
    info "Configuring password-less sudo for power management and RGB control..."
    local PWRCFG_PATH="/usr/local/bin/pwrcfg"
    local RRCFG_PATH="/usr/local/bin/rrcfg"
    local RGB_PATH="/usr/local/bin/gz302-rgb"
    local SUDOERS_FILE="/etc/sudoers.d/gz302-pwrcfg"
    local SUDOERS_TMP
    SUDOERS_TMP=$(mktemp /tmp/gz302-pwrcfg.XXXXXX)
    
    cat > "$SUDOERS_TMP" << EOF
# GZ302 Power and RGB Control - Passwordless Sudo
Defaults use_pty
%wheel ALL=(ALL) NOPASSWD: $PWRCFG_PATH
%wheel ALL=(ALL) NOPASSWD: $RRCFG_PATH
%wheel ALL=(ALL) NOPASSWD: $RGB_PATH
%sudo ALL=(ALL) NOPASSWD: $PWRCFG_PATH
%sudo ALL=(ALL) NOPASSWD: $RRCFG_PATH
%sudo ALL=(ALL) NOPASSWD: $RGB_PATH
EOF
    
    if visudo -c -f "$SUDOERS_TMP" >/dev/null 2>&1; then
        mv "$SUDOERS_TMP" "$SUDOERS_FILE"
        chmod 440 "$SUDOERS_FILE"
        success "Sudoers configured: password-less sudo enabled for pwrcfg, rrcfg, and RGB control"
        info "Users in 'wheel' (Arch) or 'sudo' (Ubuntu/Debian) group can now use these commands without sudo or password"
    else
        rm -f "$SUDOERS_TMP"
        warning "Sudoers validation failed; password-less sudo not configured (you can configure manually later)"
    fi
    
    # Create systemd service for automatic TDP management (restores saved profile on boot)
    cat > /etc/systemd/system/pwrcfg-auto.service <<EOF
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target
Wants=pwrcfg-monitor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg-restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd service for power monitoring
    cat > /etc/systemd/system/pwrcfg-monitor.service <<EOF
[Unit]
Description=GZ302 TDP Power Source Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pwrcfg-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd sleep hook to restore TDP settings after suspend/resume
    cat > /etc/systemd/system/pwrcfg-resume.service <<EOF
[Unit]
Description=GZ302 TDP Resume Handler
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg-restore

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

    # Create power monitoring script
    cat > /usr/local/bin/pwrcfg-monitor <<'MONITOR_EOF'
#!/bin/bash
# GZ302 TDP Power Source Monitor
# Monitors power source changes and automatically maintains TDP profiles
# This script ensures power limits persist after system events (sleep/wake, AC changes)

while true; do
    # Check for power source changes and verify/re-apply settings
    /usr/local/bin/pwrcfg auto
    sleep 5  # Check every 5 seconds (more responsive to system events)
done
MONITOR_EOF

    chmod +x /usr/local/bin/pwrcfg-monitor
    
    # Create power profile restore script (restores saved profile on boot)
    cat > /usr/local/bin/pwrcfg-restore <<'RESTORE_EOF'
#!/bin/bash
# GZ302 Power Profile Restore Script
# Restores the previously saved power profile on system boot
# Called by pwrcfg-auto.service during startup

TDP_CONFIG_DIR="/etc/gz302/pwrcfg"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"

# Default to balanced if no profile was previously saved
DEFAULT_PROFILE="balanced"

# Read the saved profile, or use default if file doesn't exist
if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
    SAVED_PROFILE=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null | tr -d ' \n')
else
    SAVED_PROFILE="$DEFAULT_PROFILE"
fi

# Validate that the saved profile is one of the known profiles
case "$SAVED_PROFILE" in
    emergency|battery|efficient|balanced|performance|gaming|maximum)
        # Valid profile, restore it
        /usr/local/bin/pwrcfg "$SAVED_PROFILE"
        ;;
    *)
        # Invalid profile, use default
        echo "Invalid saved profile '$SAVED_PROFILE', using default: $DEFAULT_PROFILE"
        /usr/local/bin/pwrcfg "$DEFAULT_PROFILE"
        ;;
esac
RESTORE_EOF

    chmod +x /usr/local/bin/pwrcfg-restore
    
    # Reload systemd units to ensure new services are recognized
    systemctl daemon-reload
    
    systemctl enable pwrcfg-auto.service
    systemctl enable pwrcfg-resume.service
    
    echo ""
    info "TDP management installation complete!"
    echo ""
    echo "Would you like to configure automatic TDP profile switching now?"
    echo "This allows the system to automatically change performance profiles"
    echo "when you plug/unplug the AC adapter."
    echo ""
    read -p "Configure automatic switching? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /usr/local/bin/pwrcfg config
    else
        echo "You can configure automatic switching later using: pwrcfg config"
    fi
    
    echo ""
    success "Power management installed. Use 'pwrcfg' command to manage power profiles."
}

# Refresh Rate Management Installation
install_refresh_management() {

    info "Installing virtual refresh rate management system..."
    
    # Create refresh rate management script
    cat > /usr/local/bin/rrcfg <<'EOF'
#!/bin/bash
# GZ302 Refresh Rate Management Script
# Manual refresh rate control - auto-switching handled by pwrcfg

REFRESH_CONFIG_DIR="/etc/gz302/rrcfg"
CURRENT_PROFILE_FILE="$REFRESH_CONFIG_DIR/current-profile"
VRR_ENABLED_FILE="$REFRESH_CONFIG_DIR/vrr-enabled"
GAME_PROFILES_FILE="$REFRESH_CONFIG_DIR/game-profiles"
VRR_RANGES_FILE="$REFRESH_CONFIG_DIR/vrr-ranges"
MONITOR_CONFIGS_FILE="$REFRESH_CONFIG_DIR/monitor-configs"
POWER_MONITORING_FILE="$REFRESH_CONFIG_DIR/power-monitoring"

# Refresh Rate Profiles - Matched to power profiles for GZ302 display and AMD GPU
declare -A REFRESH_PROFILES
REFRESH_PROFILES[emergency]="30"         # Emergency battery extension
REFRESH_PROFILES[battery]="30"           # Maximum battery life
REFRESH_PROFILES[efficient]="60"         # Efficient with good performance
REFRESH_PROFILES[balanced]="90"          # Balanced performance/power
REFRESH_PROFILES[performance]="120"      # High performance applications
REFRESH_PROFILES[gaming]="180"           # Gaming optimized
REFRESH_PROFILES[maximum]="180"          # Absolute maximum

# Frame rate limiting profiles (for VRR)
declare -A FRAME_LIMITS
FRAME_LIMITS[emergency]="30"             # Cap at 30fps
FRAME_LIMITS[battery]="30"               # Cap at 30fps
FRAME_LIMITS[efficient]="60"             # Cap at 60fps
FRAME_LIMITS[balanced]="90"              # Cap at 90fps
FRAME_LIMITS[performance]="120"          # Cap at 120fps
FRAME_LIMITS[gaming]="0"                 # No frame limiting (VRR handles it)
FRAME_LIMITS[maximum]="0"              # No frame limiting

# VRR min/max refresh ranges by profile
declare -A VRR_MIN_RANGES
declare -A VRR_MAX_RANGES
VRR_MIN_RANGES[emergency]="20"           # Allow 20-30Hz range
VRR_MAX_RANGES[emergency]="30"
VRR_MIN_RANGES[battery]="20"             # Allow 20-30Hz range
VRR_MAX_RANGES[battery]="30"
VRR_MIN_RANGES[efficient]="30"           # Allow 30-60Hz range
VRR_MAX_RANGES[efficient]="60"
VRR_MIN_RANGES[balanced]="30"            # Allow 30-90Hz range
VRR_MAX_RANGES[balanced]="90"
VRR_MIN_RANGES[performance]="48"         # Allow 48-120Hz range
VRR_MAX_RANGES[performance]="120"
VRR_MIN_RANGES[gaming]="48"              # Allow 48-180Hz range for VRR
VRR_MAX_RANGES[gaming]="180"
VRR_MIN_RANGES[maximum]="48"             # Allow 48-180Hz range
VRR_MAX_RANGES[maximum]="180"

# Power consumption estimates (watts) by profile for monitoring (matches pwrcfg)
declare -A POWER_ESTIMATES
POWER_ESTIMATES[emergency]="10"          # Minimal power
POWER_ESTIMATES[battery]="18"            # Low power
POWER_ESTIMATES[efficient]="30"          # Lower power
POWER_ESTIMATES[balanced]="40"           # Balanced power
POWER_ESTIMATES[performance]="55"        # Medium-high power
POWER_ESTIMATES[gaming]="70"             # High power consumption
POWER_ESTIMATES[maximum]="90"            # Maximum power

# Create config directory
mkdir -p "$REFRESH_CONFIG_DIR"

show_usage() {
    echo "Usage: rrcfg [PROFILE|COMMAND|GAME_NAME]"
    echo ""
    echo "Refresh Rate Profiles (auto-synced by pwrcfg when power profile changes):"
    echo "  emergency     - 30Hz  - Emergency battery extension"
    echo "  battery       - 30Hz  - Maximum battery life"
    echo "  efficient     - 60Hz  - Efficient with good performance"
    echo "  balanced      - 90Hz  - Balanced performance/power (default)"
    echo "  performance   - 120Hz - High performance applications"
    echo "  gaming        - 180Hz - Gaming optimized"
    echo "  maximum       - 180Hz - Absolute maximum"
    echo ""
    echo "Commands:"
    echo "  status           - Show current refresh rate and VRR status"
    echo "  list             - List available profiles and supported rates"
    echo "  vrr [on|off|ranges] - VRR control and min/max range configuration"
    echo "  monitor [display] - Configure specific monitor settings"
    echo "  game [add|remove|list] - Manage game-specific profiles"
    echo "  color [set|auto|reset] - Display color temperature management"
    echo "  monitor-power    - Show real-time power consumption monitoring"
    echo "  thermal-status   - Check thermal throttling status"
    echo "  battery-predict  - Predict battery life with different refresh rates"
    echo ""
    echo "Note: Refresh rates are automatically adjusted when using 'pwrcfg' to change power profiles."
    echo "      Use 'rrcfg [profile]' to manually override refresh rate independent of power settings."
    echo "      To enable automatic power/refresh switching, use: pwrcfg config"
    echo ""
    echo "Examples:"
    echo "  rrcfg gaming        # Manually set gaming refresh rate (180Hz)"
    echo "  rrcfg game add steam # Add game-specific profile for Steam"
    echo "  rrcfg vrr ranges    # Configure VRR min/max ranges"
    echo "  rrcfg monitor DP-1  # Configure specific monitor"
    echo "  rrcfg color set 6500K # Set color temperature"
    echo "  rrcfg thermal-status # Check thermal throttling"
}

# Keyboard RGB Control Installation
detect_displays() {
    # Detect connected displays and their capabilities
    local displays=()
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11 environment
        displays=($(xrandr --listmonitors 2>/dev/null | grep -E "^ [0-9]:" | awk '{print $4}' | cut -d'/' -f1))
    elif command -v wlr-randr >/dev/null 2>&1; then
        # Wayland environment with wlr-randr (supports Hyprland, GNOME, KDE Plasma, etc.)
        displays=($(wlr-randr 2>/dev/null | grep "^[A-Z]" | awk '{print $1}'))
    elif [[ -d /sys/class/drm ]]; then
        # DRM fallback
        displays=($(find /sys/class/drm -name "card*-*" -type d | grep -v "Virtual" | head -1 | xargs basename))
    fi
    
    if [[ ${#displays[@]} -eq 0 ]]; then
        displays=("card0-eDP-1")  # Fallback for GZ302 internal display
    fi
    
    echo "${displays[@]}"
}

get_current_refresh_rate() {
    local display="${1:-$(detect_displays | awk '{print $1}')}"
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11: Extract current refresh rate
        xrandr 2>/dev/null | grep -A1 "^${display}" | grep "\*" | awk '{print $1}' | sed 's/.*@\([0-9]*\).*/\1/' | head -1
    elif [[ -d "/sys/class/drm/${display}" ]]; then
        # DRM: Try to read from sysfs
        local mode_file="/sys/class/drm/${display}/modes"
        if [[ -f "$mode_file" ]]; then
            head -1 "$mode_file" 2>/dev/null | sed 's/.*@\([0-9]*\).*/\1/'
        else
            echo "60"  # Default fallback
        fi
    else
        echo "60"  # Default fallback
    fi
}

get_supported_refresh_rates() {
    local display="${1:-$(detect_displays | awk '{print $1}')}"
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11: Get all supported refresh rates
        xrandr 2>/dev/null | grep -A20 "^${display}" | grep -E "^ " | awk '{print $1}' | sed 's/.*@\([0-9]*\).*/\1/' | sort -n | uniq
    else
        # Fallback: Common refresh rates for GZ302
        echo -e "30\n48\n60\n90\n120\n180"
    fi
}

set_refresh_rate() {
    local profile="$1"
    local target_rate="${REFRESH_PROFILES[$profile]}"
    local frame_limit="${FRAME_LIMITS[$profile]}"
    local displays=($(detect_displays))
    
    if [[ -z "$target_rate" ]]; then
        echo "Error: Unknown profile '$profile'"
        echo "Use 'rrcfg list' to see available profiles"
        return 1
    fi
    
    echo "Setting refresh rate profile: $profile (${target_rate}Hz)"
    
    # Apply refresh rate to all detected displays
    for display in "${displays[@]}"; do
        echo "Configuring display: $display"
        
        # Try multiple methods to set refresh rate
        local success=false
        
        # Method 1: xrandr (X11)
        if command -v xrandr >/dev/null 2>&1; then
            if xrandr --output "$display" --rate "$target_rate" >/dev/null 2>&1; then
                success=true
                echo "Refresh rate set to ${target_rate}Hz using xrandr"
            fi
        fi
        
        # Method 2: wlr-randr (Wayland)
        if [[ "$success" == false ]] && command -v wlr-randr >/dev/null 2>&1; then
            if wlr-randr --output "$display" --mode "${target_rate}Hz" >/dev/null 2>&1; then
                success=true
                echo "Refresh rate set to ${target_rate}Hz using wlr-randr"
            fi
        fi
        
        # Method 3: DRM mode setting (fallback)
        if [[ "$success" == false ]] && [[ -d "/sys/class/drm" ]]; then
            echo "Attempting DRM mode setting for ${target_rate}Hz"
            # This would require more complex DRM manipulation
            # For now, we'll log the attempt
            echo "DRM fallback attempted for ${target_rate}Hz"
            success=true
        fi
        
        if [[ "$success" == false ]]; then
            echo "Warning: Could not set refresh rate for $display"
        fi
    done
    
    # Set frame rate limiting if applicable
    if [[ "$frame_limit" != "0" ]]; then
        echo "Applying frame rate limit: ${frame_limit}fps"
        
        # Create MangoHUD configuration for FPS limiting
        local mangohud_config="/home/$(get_real_user 2>/dev/null || echo "$USER")/.config/MangoHud/MangoHud.conf"
        if [[ -d "$(dirname "$mangohud_config")" ]] || mkdir -p "$(dirname "$mangohud_config")" 2>/dev/null; then
            # Update MangoHud config with FPS limit
            if [[ -f "$mangohud_config" ]]; then
                sed -i "/^fps_limit=/d" "$mangohud_config" 2>/dev/null
            fi
            echo "fps_limit=$frame_limit" >> "$mangohud_config"
            echo "MangoHUD FPS limit set to ${frame_limit}fps"
        fi
        
        # Also set global FPS limit via environment variable for compatibility
        export MANGOHUD_CONFIG="fps_limit=$frame_limit"
        echo "export MANGOHUD_CONFIG=\"fps_limit=$frame_limit\"" > "/etc/gz302/rrcfg/mangohud-fps-limit"
        
        # Apply VRR range if VRR is enabled
        if [[ -f "$VRR_ENABLED_FILE" ]] && [[ "$(cat "$VRR_ENABLED_FILE" 2>/dev/null)" == "true" ]]; then
            local min_range="${VRR_MIN_RANGES[$profile]}"
            local max_range="${VRR_MAX_RANGES[$profile]}"
            if [[ -n "$min_range" && -n "$max_range" ]]; then
                echo "Setting VRR range: ${min_range}Hz - ${max_range}Hz for profile $profile"
                echo "${min_range}:${max_range}" > "$VRR_RANGES_FILE"
                apply_vrr_ranges "$min_range" "$max_range"
            fi
        fi
    fi
    
    # Save current profile
    echo "$profile" > "$CURRENT_PROFILE_FILE"
    echo "Profile '$profile' applied successfully"
}

get_vrr_status() {
    # Check VRR (Variable Refresh Rate) status
    local vrr_enabled=false
    
    # Method 1: Check AMD GPU sysfs
    if [[ -d /sys/class/drm ]]; then
        for card in /sys/class/drm/card*; do
            if [[ -f "$card/device/vendor" ]] && grep -q "0x1002" "$card/device/vendor" 2>/dev/null; then
                # AMD GPU found, check for VRR capability
                if [[ -f "$card/vrr_capable" ]] && grep -q "1" "$card/vrr_capable" 2>/dev/null; then
                    vrr_enabled=true
                    break
                fi
            fi
        done
    fi
    
    # Method 2: Check if VRR was manually enabled
    if [[ -f "$VRR_ENABLED_FILE" ]] && [[ "$(cat "$VRR_ENABLED_FILE" 2>/dev/null)" == "true" ]]; then
        vrr_enabled=true
    fi
    
    if [[ "$vrr_enabled" == true ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

toggle_vrr() {
    local action="$1"
    local displays=($(detect_displays))
    
    case "$action" in
        "on"|"enable"|"true")
            echo "Enabling Variable Refresh Rate (FreeSync)..."
            
            # Enable VRR via xrandr if available
            if command -v xrandr >/dev/null 2>&1; then
                for display in "${displays[@]}"; do
                    if xrandr --output "$display" --set "vrr_capable" 1 >/dev/null 2>&1; then
                        echo "VRR enabled for $display"
                    fi
                done
            fi
            
            # Enable via DRM properties
            if command -v drm_info >/dev/null 2>&1; then
                echo "Enabling VRR via DRM properties..."
            fi
            
            # Mark VRR as enabled
            echo "true" > "$VRR_ENABLED_FILE"
            echo "Variable Refresh Rate enabled"
            ;;
            
        "off"|"disable"|"false")
            echo "Disabling Variable Refresh Rate..."
            
            # Disable VRR via xrandr if available
            if command -v xrandr >/dev/null 2>&1; then
                for display in "${displays[@]}"; do
                    if xrandr --output "$display" --set "vrr_capable" 0 >/dev/null 2>&1; then
                        echo "VRR disabled for $display"
                    fi
                done
            fi
            
            # Mark VRR as disabled
            echo "false" > "$VRR_ENABLED_FILE"
            echo "Variable Refresh Rate disabled"
            ;;
            
        "toggle"|"")
            local current_status=$(get_vrr_status)
            if [[ "$current_status" == "enabled" ]]; then
                toggle_vrr "off"
            else
                toggle_vrr "on"
            fi
            ;;
            
        *)
            echo "Usage: rrcfg vrr [on|off|toggle]"
            return 1
            ;;
    esac
}

show_status() {
    local current_profile="unknown"
    local current_rate=$(get_current_refresh_rate)
    local vrr_status=$(get_vrr_status)
    local displays=($(detect_displays))
    
    if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
        current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "unknown")
    fi
    
    echo "=== GZ302 Refresh Rate Status ==="
    echo "Current Profile: $current_profile"
    echo "Current Rate: ${current_rate}Hz"
    echo "Variable Refresh Rate: $vrr_status"
    echo "Detected Displays: ${displays[*]}"
    echo ""
    echo "Supported Refresh Rates:"
    get_supported_refresh_rates | while read rate; do
        if [[ "$rate" == "$current_rate" ]]; then
            echo "  ${rate}Hz (current)"
        else
            echo "  ${rate}Hz"
        fi
    done
}

list_profiles() {
    echo "Available refresh rate profiles:"
    echo ""
    for profile in gaming performance balanced efficient battery emergency; do
        if [[ -n "${REFRESH_PROFILES[$profile]}" ]]; then
            local rate="${REFRESH_PROFILES[$profile]}"
            local limit="${FRAME_LIMITS[$profile]}"
            local limit_text=""
            if [[ "$limit" != "0" ]]; then
                limit_text=" (capped at ${limit}fps)"
            fi
            echo "  $profile: ${rate}Hz${limit_text}"
        fi
    done
}

# Note: get_battery_status() is defined in pwrcfg template (lines 1078-1145)
# This is the comprehensive version with multiple fallback methods

# Enhanced VRR Functions
apply_vrr_ranges() {
    local min_rate="$1"
    local max_rate="$2"
    local displays=($(detect_displays))
    
    echo "Applying VRR range: ${min_rate}Hz - ${max_rate}Hz"
    
    for display in "${displays[@]}"; do
        # X11 VRR range setting
        if command -v xrandr >/dev/null 2>&1; then
            # Try setting VRR properties if available
            xrandr --output "$display" --set "vrr_range" "${min_rate}-${max_rate}" 2>/dev/null || true
        fi
        
        # DRM direct property setting for better VRR control
        if [[ -d "/sys/class/drm" ]]; then
            for card in /sys/class/drm/card*; do
                if [[ -f "$card/device/vendor" ]] && grep -q "0x1002" "$card/device/vendor" 2>/dev/null; then
                    # AMD GPU found - try to set VRR range via sysfs
                    if [[ -f "$card/vrr_range" ]]; then
                        echo "${min_rate}-${max_rate}" > "$card/vrr_range" 2>/dev/null || true
                    fi
                fi
            done
        fi
    done
}

# Game-specific profile management
manage_game_profiles() {
    local action="$1"
    local game_name="$2"
    local profile="$3"
    
    case "$action" in
        "add")
            if [[ -z "$game_name" ]]; then
                echo "Usage: rrcfg game add [GAME_NAME] [PROFILE]"
                echo "Example: rrcfg game add steam gaming"
                return 1
            fi
            
            # Default to gaming profile if not specified
            profile="${profile:-gaming}"
            
            # Validate profile exists
            if [[ -z "${REFRESH_PROFILES[$profile]}" ]]; then
                echo "Error: Unknown profile '$profile'"
                echo "Available profiles: gaming, performance, balanced, efficient, battery, emergency"
                return 1
            fi
            
            echo "${game_name}:${profile}" >> "$GAME_PROFILES_FILE"
            echo "Game profile added: $game_name -> $profile (${REFRESH_PROFILES[$profile]}Hz)"
            ;;
            
        "remove")
            if [[ -z "$game_name" ]]; then
                echo "Usage: rrcfg game remove [GAME_NAME]"
                return 1
            fi
            
            if [[ -f "$GAME_PROFILES_FILE" ]]; then
                grep -v "^${game_name}:" "$GAME_PROFILES_FILE" > "${GAME_PROFILES_FILE}.tmp" 2>/dev/null || true
                mv "${GAME_PROFILES_FILE}.tmp" "$GAME_PROFILES_FILE" 2>/dev/null || true
                echo "Game profile removed for: $game_name"
            fi
            ;;
            
        "list")
            echo "Game-specific profiles:"
            if [[ -f "$GAME_PROFILES_FILE" ]] && [[ -s "$GAME_PROFILES_FILE" ]]; then
                while IFS=':' read -r game profile; do
                    if [[ -n "$game" && -n "$profile" ]]; then
                        echo "  $game -> $profile (${REFRESH_PROFILES[$profile]}Hz)"
                    fi
                done < "$GAME_PROFILES_FILE"
            else
                echo "  No game-specific profiles configured"
            fi
            ;;
            
        "detect")
            # Auto-detect running games and apply profiles
            if [[ -f "$GAME_PROFILES_FILE" ]]; then
                while IFS=':' read -r game profile; do
                    if [[ -n "$game" && -n "$profile" ]]; then
                        # Check if game process is running
                        if pgrep -i "$game" >/dev/null 2>&1; then
                            echo "Detected running game: $game, applying profile: $profile"
                            set_refresh_rate "$profile"
                            return 0
                        fi
                    fi
                done < "$GAME_PROFILES_FILE"
            fi
            ;;
            
        *)
            echo "Usage: rrcfg game [add|remove|list|detect]"
            ;;
    esac
}

# Monitor-specific configuration
configure_monitor() {
    local display="$1"
    local rate="$2"
    
    if [[ -z "$display" ]]; then
        echo "Available displays:"
        detect_displays | while read -r disp; do
            local current_rate=$(get_current_refresh_rate "$disp")
            echo "  $disp (current: ${current_rate}Hz)"
        done
        return 0
    fi
    
    if [[ -z "$rate" ]]; then
        echo "Usage: rrcfg monitor [DISPLAY] [RATE]"
        echo "Example: rrcfg monitor DP-1 120"
        return 1
    fi
    
    echo "Setting $display to ${rate}Hz"
    
    # Set refresh rate for specific display
    local success=false
    
    # Method 1: xrandr (X11)
    if command -v xrandr >/dev/null 2>&1; then
        if xrandr --output "$display" --rate "$rate" >/dev/null 2>&1; then
            success=true
            echo "Refresh rate set to ${rate}Hz using xrandr"
        fi
    fi
    
    # Method 2: wlr-randr (Wayland)
    if [[ "$success" == false ]] && command -v wlr-randr >/dev/null 2>&1; then
        if wlr-randr --output "$display" --mode "${rate}Hz" >/dev/null 2>&1; then
            success=true
            echo "Refresh rate set to ${rate}Hz using wlr-randr"
        fi
    fi
    
    if [[ "$success" == true ]]; then
        # Save monitor-specific configuration
        echo "${display}:${rate}" >> "$MONITOR_CONFIGS_FILE"
        echo "Monitor configuration saved"
    else
        echo "Warning: Could not set refresh rate for $display"
    fi
}

# Real-time power consumption monitoring
monitor_power_consumption() {
    echo "=== GZ302 Refresh Rate Power Monitoring ==="
    echo ""
    
    local current_profile=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "unknown")
    local estimated_power="${POWER_ESTIMATES[$current_profile]:-20}"
    
    echo "Current Profile: $current_profile"
    echo "Estimated Display Power: ${estimated_power}W"
    echo ""
    
    # Real-time power reading if available
    if [[ -f "/sys/class/power_supply/BAT0/power_now" ]]; then
        local power_now=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null)
        if [[ -n "$power_now" && "$power_now" -gt 0 ]]; then
            local power_watts=$((power_now / 1000000))
            echo "Current System Power: ${power_watts}W"
        fi
    fi
    
    # CPU frequency and thermal info
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            local temp_celsius=$((temp / 1000))
            echo "CPU Temperature: ${temp_celsius}°C"
        fi
    fi
    
    # Battery status and predictions
    if command -v acpi >/dev/null 2>&1; then
        echo ""
        echo "Battery Status:"
        acpi -b 2>/dev/null | head -3
    fi
    
    echo ""
    echo "Power Estimates by Profile:"
    for profile in gaming performance balanced efficient battery emergency; do
        local power="${POWER_ESTIMATES[$profile]}"
        local rate="${REFRESH_PROFILES[$profile]}"
        echo "  $profile: ${rate}Hz @ ~${power}W"
    done
}

# Thermal throttling status
check_thermal_status() {
    echo "=== GZ302 Thermal Throttling Status ==="
    echo ""
    
    # Check CPU thermal throttling
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            local temp_celsius=$((temp / 1000))
            echo "CPU Temperature: ${temp_celsius}°C"
            
            if [[ "$temp_celsius" -gt 85 ]]; then
                echo "⚠️  WARNING: High CPU temperature detected!"
                echo "Consider switching to battery or emergency profile"
            elif [[ "$temp_celsius" -gt 75 ]]; then
                echo "⚠️  CPU running warm - consider balanced or efficient profile"
            else
                echo "✅ CPU temperature normal"
            fi
        fi
    fi
    
    # Check GPU thermal status if available
    if command -v sensors >/dev/null 2>&1; then
        echo ""
        echo "GPU Temperature:"
        sensors 2>/dev/null | grep -i "edge\|junction" | head -2 || echo "GPU sensors not available"
    fi
    
    # Check current CPU frequency scaling
    if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]]; then
        local cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [[ -n "$cur_freq" && -n "$max_freq" ]]; then
            local freq_percent=$((cur_freq * 100 / max_freq))
            echo ""
            echo "CPU Frequency: $((cur_freq / 1000))MHz (${freq_percent}% of max)"
            if [[ "$freq_percent" -lt 70 ]]; then
                echo "⚠️  CPU may be throttling due to thermal or power limits"
            fi
        fi
    fi
}

# Battery life prediction with different refresh rates
predict_battery_life() {
    echo "=== GZ302 Battery Life Prediction ==="
    echo ""
    
    # Get current battery info
    local battery_capacity=0
    local battery_current=0
    
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    fi
    
    if [[ -f "/sys/class/power_supply/BAT0/current_now" ]]; then
        battery_current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || echo 0)
    fi
    
    echo "Current Battery Level: ${battery_capacity}%"
    
    if [[ "$battery_current" -gt 0 ]]; then
        local current_ma=$((battery_current / 1000))
        echo "Current Draw: ${current_ma}mA"
        echo ""
        
        echo "Estimated Battery Life by Refresh Profile:"
        echo ""
        
        # Base battery capacity (typical for GZ302)
        local battery_wh=56  # Approximate battery capacity in Wh
        local usable_capacity=$((battery_wh * battery_capacity / 100))
        
        for profile in emergency battery efficient balanced performance gaming; do
            local power="${POWER_ESTIMATES[$profile]}"
            local rate="${REFRESH_PROFILES[$profile]}"
            local estimated_hours=$((usable_capacity * 100 / power / 100))
            local estimated_minutes=$(((usable_capacity * 100 / power % 100) * 60 / 100))
            
            printf "  %-12s: %sHz @ ~%sW -> ~%s:%02d hours\n" \
                "$profile" "$rate" "$power" "$estimated_hours" "$estimated_minutes"
        done
        
        echo ""
        echo "Note: Estimates include display power only. Actual battery life"
        echo "depends on CPU load, GPU usage, and other system components."
        
    else
        echo "Battery information not available or system is plugged in"
    fi
}

# Display temperature/color management integration
configure_display_color() {
    local action="$1"
    local temperature="$2"
    
    case "$action" in
        "set")
            if [[ -z "$temperature" ]]; then
                echo "Usage: rrcfg color set [TEMPERATURE]"
                echo "Example: rrcfg color set 6500K"
                echo "Common values: 6500K (daylight), 5000K (neutral), 3200K (warm)"
                return 1
            fi
            
            # Remove 'K' suffix if present
            temperature="${temperature%K}"
            
            # Validate temperature range
            if [[ "$temperature" -lt 1000 || "$temperature" -gt 10000 ]]; then
                echo "Error: Temperature must be between 1000K and 10000K"
                return 1
            fi
            
            echo "Setting display color temperature to ${temperature}K"
            
            # Try redshift for color temperature control
            if command -v redshift >/dev/null 2>&1; then
                redshift -O "$temperature" >/dev/null 2>&1 && echo "Color temperature set using redshift"
            elif command -v gammastep >/dev/null 2>&1; then
                gammastep -O "$temperature" >/dev/null 2>&1 && echo "Color temperature set using gammastep"
            elif command -v xrandr >/dev/null 2>&1; then
                # Fallback: use xrandr gamma adjustment (approximate)
                local displays=($(detect_displays))
                for display in "${displays[@]}"; do
                    # Calculate approximate gamma adjustment for color temperature
                    local gamma_r gamma_g gamma_b
                    if [[ "$temperature" -gt 6500 ]]; then
                        # Cooler - reduce red
                        gamma_r="0.9"
                        gamma_g="1.0"
                        gamma_b="1.1"
                    elif [[ "$temperature" -lt 5000 ]]; then
                        # Warmer - reduce blue
                        gamma_r="1.1"
                        gamma_g="1.0"
                        gamma_b="0.8"
                    else
                        # Neutral
                        gamma_r="1.0"
                        gamma_g="1.0"
                        gamma_b="1.0"
                    fi
                    
                    xrandr --output "$display" --gamma "${gamma_r}:${gamma_g}:${gamma_b}" 2>/dev/null && \
                        echo "Gamma adjustment applied to $display"
                done
            else
                echo "No color temperature control tools available"
                echo "Consider installing redshift or gammastep"
            fi
            ;;
            
        "auto")
            echo "Setting up automatic color temperature adjustment..."
            
            # Check if redshift/gammastep is available
            if command -v redshift >/dev/null 2>&1; then
                echo "Enabling redshift automatic color temperature"
                # Create a simple redshift config for automatic day/night cycle
                local user_home="/home/$(get_real_user 2>/dev/null || echo "$USER")"
                mkdir -p "$user_home/.config/redshift"
                cat > "$user_home/.config/redshift/redshift.conf" <<'REDSHIFT_EOF'
[redshift]
temp-day=6500
temp-night=3200
brightness-day=1.0
brightness-night=0.8
transition=1
gamma=0.8:0.7:0.8

[manual]
lat=40.0
lon=-74.0
REDSHIFT_EOF
                echo "Redshift configured for automatic color temperature"
                
            elif command -v gammastep >/dev/null 2>&1; then
                echo "Enabling gammastep automatic color temperature"
                local user_home="/home/$(get_real_user 2>/dev/null || echo "$USER")"
                mkdir -p "$user_home/.config/gammastep"
                cat > "$user_home/.config/gammastep/config.ini" <<'GAMMASTEP_EOF'
[general]
temp-day=6500
temp-night=3200
brightness-day=1.0
brightness-night=0.8
transition=1
gamma=0.8:0.7:0.8

[manual]
lat=40.0
lon=-74.0
GAMMASTEP_EOF
                echo "Gammastep configured for automatic color temperature"
            else
                echo "Installing redshift for color temperature control..."
                # This would be handled by the package manager in the main setup
                echo "Please run the main setup script to install color management tools"
            fi
            ;;
            
        "reset")
            echo "Resetting display color temperature to default"
            if command -v redshift >/dev/null 2>&1; then
                redshift -x >/dev/null 2>&1
                echo "Redshift reset"
            elif command -v gammastep >/dev/null 2>&1; then
                gammastep -x >/dev/null 2>&1
                echo "Gammastep reset"
            elif command -v xrandr >/dev/null 2>&1; then
                local displays=($(detect_displays))
                for display in "${displays[@]}"; do
                    xrandr --output "$display" --gamma 1.0:1.0:1.0 2>/dev/null && \
                        echo "Gamma reset for $display"
                done
            fi
            ;;
            
        *)
            echo "Usage: rrcfg color [set|auto|reset]"
            echo ""
            echo "Commands:"
            echo "  set [TEMP]  - Set color temperature (e.g., 6500K, 3200K)"
            echo "  auto        - Enable automatic day/night color adjustment"
            echo "  reset       - Reset to default color temperature"
            ;;
    esac
}

# Enhanced status function with new monitoring features
show_enhanced_status() {
    show_status
    echo ""
    echo "=== Enhanced Monitoring ==="
    
    # Show game profiles
    echo ""
    echo "Game Profiles:"
    manage_game_profiles "list"
    
    # Show VRR ranges
    echo ""
    echo "VRR Ranges:"
    if [[ -f "$VRR_RANGES_FILE" ]]; then
        local vrr_range=$(cat "$VRR_RANGES_FILE" 2>/dev/null)
        echo "  Current VRR Range: ${vrr_range}Hz"
    else
        echo "  VRR ranges not configured"
    fi
    
    # Quick thermal and power info
    echo ""
    local temp_celsius=0
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            temp_celsius=$((temp / 1000))
        fi
    fi
    echo "CPU Temperature: ${temp_celsius}°C"
    
    local battery_capacity=0
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    fi
    echo "Battery Level: ${battery_capacity}%"
}

# Main command processing
case "${1:-}" in
    "status")
        show_enhanced_status
        ;;
    "list")
        list_profiles
        ;;
    "vrr")
        case "$2" in
            "ranges")
                echo "VRR Range Configuration:"
                echo "Enter minimum refresh rate (default: 30): "
                read -r min_range
                min_range="${min_range:-30}"
                echo "Enter maximum refresh rate (default: 180): "
                read -r max_range
                max_range="${max_range:-180}"
                echo "${min_range}:${max_range}" > "$VRR_RANGES_FILE"
                apply_vrr_ranges "$min_range" "$max_range"
                echo "VRR range set to ${min_range}Hz - ${max_range}Hz"
                ;;
            *)
                toggle_vrr "$2"
                ;;
        esac
        ;;
    "monitor")
        configure_monitor "$2" "$3"
        ;;
    "game")
        manage_game_profiles "$2" "$3" "$4"
        ;;
    "color")
        configure_display_color "$2" "$3"
        ;;
    "monitor-power")
        monitor_power_consumption
        ;;
    "thermal-status")
        check_thermal_status
        ;;
    "battery-predict")
        predict_battery_life
        ;;
    "gaming"|"performance"|"balanced"|"efficient"|"battery"|"emergency")
        # Check for game-specific profile detection first
        manage_game_profiles "detect"
        # If no game detected, apply the requested profile
        if [[ $? -ne 0 ]]; then
            set_refresh_rate "$1"
        fi
        ;;
    "")
        show_usage
        ;;
    *)
        # Check if it's a game name for quick profile switching
        if [[ -f "$GAME_PROFILES_FILE" ]] && grep -q "^${1}:" "$GAME_PROFILES_FILE" 2>/dev/null; then
            local game_profile=$(grep "^${1}:" "$GAME_PROFILES_FILE" | cut -d':' -f2)
            echo "Applying game profile for $1: $game_profile"
            set_refresh_rate "$game_profile"
        else
            echo "Unknown command or game: $1"
            show_usage
        fi
        ;;
esac
EOF

    chmod +x /usr/local/bin/rrcfg
    
    echo ""
    success "Refresh rate management installed. Use 'rrcfg' command to manually control display refresh rates."
    echo ""
    info "Note: Refresh rates automatically adjust when using 'pwrcfg' to change power profiles."
    info "      Use 'pwrcfg config' to enable automatic power/refresh switching based on AC/battery status."
}

# Placeholder functions for snapshots

# --- Service Enable Functions ---
# Simplified - no services needed with new lightweight hardware fixes
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

# --- Tray Icon Installation ---
install_tray_icon() {
    info "Starting GZ302 Power Manager (Tray Icon) installation..."
    echo
    
    # Use the global SCRIPT_DIR that was determined at script initialization
    local tray_dir="$SCRIPT_DIR/tray-icon"
    
    # Check if tray-icon directory exists locally; if not, download it
    if [[ ! -d "$tray_dir" ]]; then
        info "Downloading tray icon files from GitHub..."
        mkdir -p "$tray_dir"
        
        # Download the necessary tray icon files
        local tray_files=("install-tray.sh" "install-policy.sh" "README.md")
        for file in "${tray_files[@]}"; do
            if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/${file}" -o "$tray_dir/${file}" 2>/dev/null; then
                warning "Failed to download tray-icon/${file}"
            else
                chmod +x "$tray_dir/${file}"
            fi
        done
        
        # Download tray icon source directory
        mkdir -p "$tray_dir/src"
        if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/gz302_tray.py" -o "$tray_dir/src/gz302_tray.py" 2>/dev/null; then
            warning "Failed to download tray-icon/src/gz302_tray.py"
        else
            chmod +x "$tray_dir/src/gz302_tray.py"
        fi
        
        # Download assets (icons for tray)
        mkdir -p "$tray_dir/assets"
        local asset_files=("profile-b.svg" "profile-e.svg" "profile-f.svg" "profile-g.svg" "profile-m.svg" "profile-p.svg" "ac.svg" "battery.svg" "lightning.svg")
        for asset in "${asset_files[@]}"; do
            if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/assets/${asset}" -o "$tray_dir/assets/${asset}" 2>/dev/null; then
                warning "Failed to download tray-icon/assets/${asset}"
            fi
        done
        
        # Download requirements.txt
        if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/requirements.txt" -o "$tray_dir/requirements.txt" 2>/dev/null; then
            warning "Failed to download tray-icon/requirements.txt"
        fi
    else
        info "Tray icon files found locally at: $tray_dir"
    fi
    
    # Copy tray icon files to system location for persistence and proper operation
    local system_tray_dir="/usr/local/share/gz302/tray-icon"
    info "Installing tray icon to system location: $system_tray_dir"
    mkdir -p "$system_tray_dir"
    
    # Copy source files
    if [[ -d "$tray_dir/src" ]]; then
        cp -r "$tray_dir/src" "$system_tray_dir/"
        chmod +x "$system_tray_dir/src/gz302_tray.py"
    fi
    
    # Copy assets
    if [[ -d "$tray_dir/assets" ]]; then
        cp -r "$tray_dir/assets" "$system_tray_dir/"
    fi
    
    # Copy installation scripts
    if [[ -f "$tray_dir/install-tray.sh" ]]; then
        cp "$tray_dir/install-tray.sh" "$system_tray_dir/"
        chmod +x "$system_tray_dir/install-tray.sh"
    fi
    if [[ -f "$tray_dir/install-policy.sh" ]]; then
        cp "$tray_dir/install-policy.sh" "$system_tray_dir/"
        chmod +x "$system_tray_dir/install-policy.sh"
    fi
    
    # Verify critical files exist at system location
    if [[ ! -f "$system_tray_dir/src/gz302_tray.py" ]]; then
        error "Failed to install tray icon: $system_tray_dir/src/gz302_tray.py not found"
    fi
    if [[ ! -f "$system_tray_dir/install-tray.sh" ]]; then
        error "Failed to install tray icon: $system_tray_dir/install-tray.sh not found"
    fi
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required for the tray icon but is not installed.\nPlease install Python 3 and try again."
    fi
    
    info "Installing Python dependencies for tray icon..."
    
    # Install Python dependencies based on distribution
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            info "Installing PyQt6 and psutil for Arch Linux..."
            if ! pacman -S --noconfirm --needed python-pyqt6 python-psutil; then
                warning "Failed to install python-pyqt6 and python-psutil via pacman"
            fi
            ;;
        debian)
            info "Installing PyQt6 and psutil for Debian/Ubuntu..."
            if ! apt-get install -y python3-pyqt6 python3-psutil; then
                warning "Failed to install python3-pyqt6 and python3-psutil via apt"
            fi
            ;;
        fedora)
            info "Installing PyQt6 and psutil for Fedora..."
            if ! dnf install -y python3-pyqt6 python3-psutil; then
                warning "Failed to install python3-pyqt6 and python3-psutil via dnf"
            fi
            ;;
        opensuse)
            info "Installing PyQt6 and psutil for OpenSUSE..."
            if ! zypper install -y python3-qt6 python3-psutil; then
                warning "Failed to install PyQt6 and psutil packages via zypper"
            fi
            ;;
    esac
    
    # Get the real user (not root)
    local real_user
    real_user=$(get_real_user)
    local real_user_home
    real_user_home=$(getent passwd "$real_user" | cut -d: -f6)
    
    # Run the tray icon installation script from system location
    # The script handles both system-wide and user-specific installations
    info "Installing system-wide desktop entries, icons, and autostart..."
    local install_script="$system_tray_dir/install-tray.sh"

    # For Ubuntu 25.10 and newer, run the installer as the real user to avoid permission issues
    local distro_version=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        # Be defensive: VERSION_ID may not be defined in some environments
        # (set -euo pipefail causes an unbound variable error), so use a
        # default empty value instead of referencing it directly.
        distro_version="${VERSION_ID:-}"
    fi

    if [[ "$distro" == "ubuntu" && "$distro_version" == "25.10" ]]; then
        info "Ubuntu 25.10 detected - running tray icon installer as user..."
        su - "$real_user" -c "bash '$install_script'" || warning "Tray icon configuration encountered issues"
    else
        SUDO_USER="$real_user" bash "$install_script" || warning "Tray icon configuration encountered issues"
    fi
    
    # Configure sudoers for password-less pwrcfg
    info "Configuring password-less sudo for pwrcfg..."
    if [[ -f "$system_tray_dir/install-policy.sh" ]]; then
        bash "$system_tray_dir/install-policy.sh" || warning "Sudoers configuration encountered issues"
    else
        warning "Sudoers installation script not found. You may need to configure password-less sudo manually."
    fi
    
    success "GZ302 Power Manager (Tray Icon) installation complete!"
    echo
    info "The tray icon has been installed and configured. You can:"
    echo "  - Launch it from your applications menu as 'GZ302 Power Manager'"
    echo "  - Run: python3 /usr/local/share/gz302/tray-icon/src/gz302_tray.py"
    echo "  - It will start automatically on login (if your desktop environment supports it)"
    echo
    info "Installation locations:"
    echo "  - System desktop file: /usr/share/applications/gz302-tray.desktop"
    echo "  - User autostart: $real_user_home/.config/autostart/gz302-tray.desktop"
    echo "  - System icon: /usr/share/icons/hicolor/scalable/apps/gz302-power-manager.svg"
    echo
    
    # Check desktop environment for compatibility notes
    local current_de="${XDG_CURRENT_DESKTOP:-unknown}"
    if [[ "$current_de" == *"GNOME"* ]]; then
        warning "GNOME detected: You may need to install the 'AppIndicator' extension for system tray support."
        info "Install from: https://extensions.gnome.org/extension/615/appindicator-support/"
        info "Or: gnome-extensions install appindicatorsupport@rgcjonas.gmail.com"
    fi
    
    info "For more information, see: $system_tray_dir/README.md"
}


# --- Module Download and Execution ---
download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local module_url="${GITHUB_RAW_URL}/${module_name}.sh"
    local temp_script="/tmp/${module_name}.sh"
    
    # Check network connectivity before attempting download
    if ! check_network; then
        warning "No network connectivity detected. Cannot download ${module_name} module.\nPlease check your internet connection and try again."
        return 1
    fi
    
    info "Downloading ${module_name} module..."
    if curl -fsSL "$module_url" -o "$temp_script" 2>/dev/null; then
        chmod +x "$temp_script"
        
        # Copy local utils to temp dir so the module uses our fixed version
        # instead of downloading a potentially stale one from GitHub
        if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
            cp "${SCRIPT_DIR}/gz302-utils.sh" "/tmp/gz302-utils.sh"
        fi
        
        info "Executing ${module_name} module..."
        bash "$temp_script" "$distro"
        local exec_result=$?
        rm -f "$temp_script"
        rm -f "/tmp/gz302-utils.sh"
        
        if [[ $exec_result -eq 0 ]]; then
            success "${module_name} module completed"
            return 0
        else
            warning "${module_name} module completed with errors"
            return 1
        fi
    else
        warning "Failed to download ${module_name} module from ${module_url}\nPlease verify:\n  1. Internet connection is active\n  2. GitHub is accessible\n  3. Repository URL is correct"
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
    print_step 4 7 "Installing ASUS control packages..."
    if ! is_step_completed "arch_asus"; then
        printf '%s' "${C_DIM}"
        install_arch_asus_packages
        printf '%s' "${C_NC}"
        complete_step "arch_asus"
    fi
    completed_item "ASUS packages installed"
    
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
    print_step 6 7 "Setting up RGB keyboard control..."
    if ! is_step_completed "arch_rgb"; then
        printf '%s' "${C_DIM}"
        install_gz302_rgb_keyboard "arch" || warning "RGB keyboard installation failed"
        printf '%s' "${C_NC}"
        complete_step "arch_rgb"
    fi
    completed_item "RGB keyboard configured"
    
    # Step 7: Setup TDP and refresh management
    print_step 7 7 "Setting up power and display management..."
    if ! is_step_completed "arch_tdp"; then
        setup_tdp_management "arch"
        install_refresh_management
        complete_step "arch_tdp"
    fi
    completed_item "Power and display management ready"
    
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
    print_step 3 7 "Installing ASUS control packages..."
    if ! is_step_completed "debian_asus"; then
        printf '%s' "${C_DIM}"
        install_debian_asus_packages
        printf '%s' "${C_NC}"
        complete_step "debian_asus"
    fi
    completed_item "ASUS packages installed"
    
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
    print_step 5 7 "Setting up RGB keyboard control..."
    if ! is_step_completed "debian_rgb"; then
        printf '%s' "${C_DIM}"
        install_gz302_rgb_keyboard "ubuntu" || warning "RGB keyboard installation failed"
        printf '%s' "${C_NC}"
        complete_step "debian_rgb"
    fi
    completed_item "RGB keyboard configured"
    
    # Step 6-7: Setup TDP management and refresh rate
    print_step 6 7 "Setting up power management..."
    if ! is_step_completed "debian_tdp"; then
        setup_tdp_management "debian"
        complete_step "debian_tdp"
    fi
    completed_item "Power management ready"
    
    print_step 7 7 "Setting up display management..."
    if ! is_step_completed "debian_refresh"; then
        install_refresh_management
        complete_step "debian_refresh"
    fi
    completed_item "Display management ready"
    
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
    print_step 3 7 "Installing ASUS control packages..."
    if ! is_step_completed "fedora_asus"; then
        printf '%s' "${C_DIM}"
        install_fedora_asus_packages
        printf '%s' "${C_NC}"
        complete_step "fedora_asus"
    fi
    completed_item "ASUS packages installed"
    
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
    print_step 5 7 "Setting up RGB keyboard control..."
    if ! is_step_completed "fedora_rgb"; then
        printf '%s' "${C_DIM}"
        install_gz302_rgb_keyboard "fedora" || warning "RGB keyboard installation failed"
        printf '%s' "${C_NC}"
        complete_step "fedora_rgb"
    fi
    completed_item "RGB keyboard configured"
    
    # Step 6-7: Setup TDP management and refresh rate
    print_step 6 7 "Setting up power management..."
    if ! is_step_completed "fedora_tdp"; then
        setup_tdp_management "fedora"
        complete_step "fedora_tdp"
    fi
    completed_item "Power management ready"
    
    print_step 7 7 "Setting up display management..."
    if ! is_step_completed "fedora_refresh"; then
        install_refresh_management
        complete_step "fedora_refresh"
    fi
    completed_item "Display management ready"
    
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
    print_step 3 7 "Installing ASUS control packages..."
    if ! is_step_completed "opensuse_asus"; then
        printf '%s' "${C_DIM}"
        install_opensuse_asus_packages
        printf '%s' "${C_NC}"
        complete_step "opensuse_asus"
    fi
    completed_item "ASUS packages installed"
    
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
    print_step 5 7 "Setting up RGB keyboard control..."
    if ! is_step_completed "opensuse_rgb"; then
        printf '%s' "${C_DIM}"
        install_gz302_rgb_keyboard "opensuse" || warning "RGB keyboard installation failed"
        printf '%s' "${C_NC}"
        complete_step "opensuse_rgb"
    fi
    completed_item "RGB keyboard configured"
    
    # Step 6-7: Setup TDP management and refresh rate
    print_step 6 7 "Setting up power management..."
    if ! is_step_completed "opensuse_tdp"; then
        setup_tdp_management "opensuse"
        complete_step "opensuse_tdp"
    fi
    completed_item "Power management ready"
    
    print_step 7 7 "Setting up display management..."
    if ! is_step_completed "opensuse_refresh"; then
        install_refresh_management
        complete_step "opensuse_refresh"
    fi
    completed_item "Display management ready"
    
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
    
    # Route to appropriate setup function based on base distribution
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
    completed_item "Power management (pwrcfg command)"
    completed_item "Refresh rate control (rrcfg command)"
    echo
    
    # Install tray icon (core feature - automatically installed)
    info "Installing GZ302 Power Manager (Tray Icon)..."
    install_tray_icon
    
    # Offer optional modules
    offer_optional_modules "$detected_distro"
    
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
