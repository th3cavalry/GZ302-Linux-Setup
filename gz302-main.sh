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
# (Moved to gz302-lib/utils.sh)

# --- Hardware Fixes for All Distributions ---
# Updated based on latest kernel support and community research (October 2025)
# Sources: Info/kernel_changelog.md, Shahzebqazi/Asus-Z13-Flow-2025-PCMR, Level1Techs,
#          asus-linux.org, Strix Halo HomeLab, Phoronix community
# GZ302EA-XS99: AMD Ryzen AI MAX+ 395 with AMD Radeon 8060S integrated graphics (100% AMD)
# REQUIRED: Kernel 6.14+ minimum (6.17+ strongly recommended)
# See Info/kernel_changelog.md for detailed kernel version comparison

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
        # dcdebugmask options: 0x400 disables DMUB Panel Self-Refresh/Replay that causes freezes on Strix Halo
        # This fixes the dmub_replay_enable kernel bug that causes system freeze after login
        ensure_grub_kernel_param "amdgpu.dcdebugmask=0x400" && grub_changed=true || true
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
        ensure_kcmdline_param "amdgpu.dcdebugmask=0x400" && kcmd_changed=true || true
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
            ensure_loader_entry_param "$entry" "amdgpu.dcdebugmask=0x400" && loader_changed=true || true
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
        ensure_limine_kernel_param "amdgpu.dcdebugmask=0x400" && limine_changed=true || true
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


setup_tdp_management() {
    local distro_family="$1"
    
    info "Setting up TDP management for GZ302..."
    
    # Install ryzenadj using library
    if command -v power_install_ryzenadj >/dev/null; then
        power_install_ryzenadj "$distro_family"
    else
        warning "Power library not loaded, skipping ryzenadj install check"
    fi
    
    # Install pwrcfg script
    if command -v power_get_pwrcfg_script >/dev/null; then
        power_get_pwrcfg_script > /usr/local/bin/pwrcfg
        chmod +x /usr/local/bin/pwrcfg
        power_init_config
    else
        error "Power library missing. Cannot install pwrcfg."
    fi
    
    # Automatically configure sudoers for password-less pwrcfg/rrcfg/RGB
    info "Configuring password-less sudo for power management and RGB control..."
    local PWRCFG_PATH="/usr/local/bin/pwrcfg"
    local RRCFG_PATH="/usr/local/bin/rrcfg"
    local RGB_PATH="/usr/local/bin/gz302-rgb"
    local SUDOERS_FILE="/etc/sudoers.d/gz302-pwrcfg"
    local SUDOERS_TMP
    SUDOERS_TMP=$(mktemp /tmp/gz302-pwrcfg.XXXXXX)
    
    cat > "$SUDOERS_TMP" << SUDO_EOF
# GZ302 Power and RGB Control - Passwordless Sudo
Defaults use_pty
%wheel ALL=(ALL) NOPASSWD: $PWRCFG_PATH
%wheel ALL=(ALL) NOPASSWD: $RRCFG_PATH
%wheel ALL=(ALL) NOPASSWD: $RGB_PATH
%sudo ALL=(ALL) NOPASSWD: $PWRCFG_PATH
%sudo ALL=(ALL) NOPASSWD: $RRCFG_PATH
%sudo ALL=(ALL) NOPASSWD: $RGB_PATH
# Allow tray icon to control keyboard/window backlight brightness
ALL ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/leds/*/brightness
SUDO_EOF
    
    if visudo -c -f "$SUDOERS_TMP" >/dev/null 2>&1; then
        mv "$SUDOERS_TMP" "$SUDOERS_FILE"
        chmod 440 "$SUDOERS_FILE"
        success "Sudoers configured"
    else
        rm -f "$SUDOERS_TMP"
        warning "Sudoers validation failed"
    fi
    
    # Create systemd service for automatic TDP management
    cat > /etc/systemd/system/pwrcfg-auto.service <<SERVICE_EOF
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
SERVICE_EOF

    # Create systemd service for power monitoring
    cat > /etc/systemd/system/pwrcfg-monitor.service <<SERVICE_EOF
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
SERVICE_EOF

    # Create systemd sleep hook
    cat > /etc/systemd/system/pwrcfg-resume.service <<SERVICE_EOF
[Unit]
Description=GZ302 TDP Resume Handler
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg-restore

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
SERVICE_EOF

    # Create power monitoring script
    cat > /usr/local/bin/pwrcfg-monitor <<'MONITOR_EOF'
#!/bin/bash
while true; do
    /usr/local/bin/pwrcfg auto
    sleep 5
done
MONITOR_EOF
    chmod +x /usr/local/bin/pwrcfg-monitor
    
    # Create power profile restore script
    cat > /usr/local/bin/pwrcfg-restore <<'RESTORE_EOF'
#!/bin/bash
TDP_CONFIG_DIR="/etc/gz302/pwrcfg"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"
DEFAULT_PROFILE="balanced"
if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
    SAVED_PROFILE=$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null | tr -d ' \n')
else
    SAVED_PROFILE="$DEFAULT_PROFILE"
fi
/usr/local/bin/pwrcfg "$SAVED_PROFILE"
RESTORE_EOF
    chmod +x /usr/local/bin/pwrcfg-restore
    
    systemctl daemon-reload
    systemctl enable pwrcfg-auto.service
    systemctl enable pwrcfg-resume.service
    
    success "Power management installed."
}
# Refresh Rate Management Installation
enable_arch_services() {
install_refresh_management() {
    info "Installing virtual refresh rate management system..."
    
    # Install rrcfg script
    if command -v display_get_rrcfg_script >/dev/null; then
        display_get_rrcfg_script > /usr/local/bin/rrcfg
        chmod +x /usr/local/bin/rrcfg
        display_init_config
    else
        error "Display library missing. Cannot install rrcfg."
    fi
    
    success "Refresh rate management installed."
}
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
    info "Starting GZ302 Control Center (Tray Icon) installation..."
    echo
    
    # Use the global SCRIPT_DIR that was determined at script initialization
    local tray_dir="$SCRIPT_DIR/tray-icon"
    local system_tray_dir="/usr/local/share/gz302/tray-icon"
    
    # Get version from VERSION file (single source of truth)
    local new_version=""
    if [[ -f "$tray_dir/VERSION" ]]; then
        new_version=$(cat "$tray_dir/VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Get installed version if it exists
    local installed_version=""
    if [[ -f "$system_tray_dir/VERSION" ]]; then
        installed_version=$(cat "$system_tray_dir/VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Semver comparison using sort -V
    # Returns true if new_version is greater than installed_version
    version_greater() {
        local v1="$1" v2="$2"
        [[ -z "$v1" || -z "$v2" ]] && return 0  # Always update if version unknown
        [[ "$v1" == "$v2" ]] && return 1  # Same version, no update needed
        # Use sort -V: if v1 sorts after v2, then v1 > v2
        local highest
        highest=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | tail -n1)
        [[ "$highest" == "$v1" ]]
    }
    
    # Check if update is needed
    local needs_update=true
    if [[ -n "$installed_version" && -n "$new_version" ]]; then
        if version_greater "$new_version" "$installed_version"; then
            info "Updating tray icon from version $installed_version to $new_version"
        elif [[ "$installed_version" == "$new_version" ]]; then
            info "Tray icon version $installed_version is already installed"
            needs_update=false
        else
            info "Installed version $installed_version is newer than source $new_version - skipping"
            needs_update=false
        fi
    elif [[ -n "$new_version" ]]; then
        info "Installing tray icon version $new_version"
    fi
    
    # Kill any running tray processes before updating (to ensure clean update)
    if [[ "$needs_update" == true ]]; then
        info "Stopping any running tray processes..."
        pkill -f "gz302_tray.py" 2>/dev/null || true
        pkill -f "gz302_tray" 2>/dev/null || true
        sleep 1
        
        # Remove old installation to ensure clean update
        if [[ -d "$system_tray_dir" ]]; then
            info "Removing old tray installation..."
            rm -rf "$system_tray_dir"
        fi
    fi
    
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
        
        # Download requirements.txt and VERSION
        if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/requirements.txt" -o "$tray_dir/requirements.txt" 2>/dev/null; then
            warning "Failed to download tray-icon/requirements.txt"
        fi
        if ! curl -fsSL "${GITHUB_RAW_URL}/tray-icon/VERSION" -o "$tray_dir/VERSION" 2>/dev/null; then
            warning "Failed to download tray-icon/VERSION"
        fi
    else
        info "Tray icon files found locally at: $tray_dir"
    fi
    
    # Copy tray icon files to system location for persistence and proper operation
    info "Installing tray icon to system location: $system_tray_dir"
    mkdir -p "$system_tray_dir"
    
    # Copy VERSION file (single source of truth for versioning)
    if [[ -f "$tray_dir/VERSION" ]]; then
        cp "$tray_dir/VERSION" "$system_tray_dir/"
    fi
    
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
    
    success "GZ302 Control Center (Tray Icon) installation complete!"
    echo
    info "The tray icon has been installed and configured. You can:"
    echo "  - Launch it from your applications menu as 'GZ302 Control Center'"
    echo "  - Run: python3 /usr/local/share/gz302/tray-icon/src/gz302_tray.py"
    echo "  - It will start automatically on login (if your desktop environment supports it)"
    echo
    info "Installation locations:"
    echo "  - System desktop file: /usr/share/applications/gz302-tray.desktop"
    echo "  - User autostart: $real_user_home/.config/autostart/gz302-tray.desktop"
    echo "  - System icon: /usr/share/icons/hicolor/scalable/apps/gz302-power-manager.svg"
    echo
    
    # Start the tray icon for the user after installation
    info "Starting tray icon..."
    if [[ -n "$real_user" && "$real_user" != "root" ]]; then
        # Check if tray is already running
        if ! pgrep -f "gz302_tray.py" > /dev/null 2>&1; then
            # Start as the real user, not root
            su - "$real_user" -c "nohup python3 '$system_tray_dir/src/gz302_tray.py' >/dev/null 2>&1 &" || true
        else
            info "Tray icon is already running"
        fi
    fi
    
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
    completed_item "RGB keyboard and lightbar configured"
    
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
    completed_item "RGB keyboard and lightbar configured"
    
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
    completed_item "RGB keyboard and lightbar configured"
    
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
    completed_item "RGB keyboard and lightbar configured"
    
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

# --- Power Tools Only Installation ---
# Installs only the power management tools (pwrcfg, rrcfg), RGB control, and Control Center
# without applying any hardware fixes (kernel parameters, GRUB changes, etc.)
setup_power_tools_only() {
    local distro="$1"
    print_subsection "Power Tools Only Installation"
    
    info "Skipping hardware fixes - installing power tools, RGB, and Control Center only"
    echo
    
    # Step 1: Install base dependencies for the tools
    print_step 1 5 "Installing base dependencies..."
    case "$distro" in
        arch)
            printf '%s' "${C_DIM}"
            pacman -S --noconfirm --needed python python-pip
            printf '%s' "${C_NC}"
            ;;
        ubuntu)
            printf '%s' "${C_DIM}"
            apt-get install -y python3 python3-pip
            printf '%s' "${C_NC}"
            ;;
        fedora)
            printf '%s' "${C_DIM}"
            dnf install -y python3 python3-pip
            printf '%s' "${C_NC}"
            ;;
        opensuse)
            printf '%s' "${C_DIM}"
            zypper install -y python3 python3-pip
            printf '%s' "${C_NC}"
            ;;
    esac
    completed_item "Base dependencies installed"
    
    # Step 2: Install power management (pwrcfg)
    print_step 2 5 "Setting up power management (pwrcfg)..."
    printf '%s' "${C_DIM}"
    setup_tdp_management "$distro"
    printf '%s' "${C_NC}"
    completed_item "Power management (pwrcfg) installed"
    
    # Step 3: Install refresh rate control (rrcfg)
    print_step 3 5 "Setting up refresh rate control (rrcfg)..."
    printf '%s' "${C_DIM}"
    install_refresh_management
    printf '%s' "${C_NC}"
    completed_item "Refresh rate control (rrcfg) installed"
    
    # Step 4: Install RGB keyboard control
    print_step 4 5 "Setting up RGB keyboard control..."
    printf '%s' "${C_DIM}"
    install_gz302_rgb_keyboard "$distro" || warning "RGB keyboard installation failed"
    printf '%s' "${C_NC}"
    completed_item "RGB keyboard and lightbar configured"
    
    # Step 5: Install Control Center (tray icon)
    print_step 5 5 "Installing GZ302 Control Center..."
    printf '%s' "${C_DIM}"
    install_tray_icon
    printf '%s' "${C_NC}"
    completed_item "Control Center installed"
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
        print_section "Installing Power Tools Only"
        setup_power_tools_only "$detected_distro"
        
        echo
        print_section "Setup Complete"
        
        print_subsection "Installed Components"
        completed_item "Power management (pwrcfg command)"
        completed_item "Refresh rate control (rrcfg command)"
        completed_item "RGB keyboard control"
        completed_item "GZ302 Control Center (tray icon)"
        echo
        
        info "Hardware fixes were skipped. If you need them later, run the script again"
        info "and answer 'yes' when asked about hardware fixes."
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
        completed_item "Power management (pwrcfg command)"
        completed_item "Refresh rate control (rrcfg command)"
        echo
        
        # Install tray icon (core feature - automatically installed)
        info "Installing GZ302 Power Manager (Tray Icon)..."
        install_tray_icon
        
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
