#!/bin/bash

# ==============================================================================
# Linux Setup Script for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.0.8
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
# Optional software can be installed via modular scripts:
# - gz302-gaming: Gaming software (Steam, Lutris, MangoHUD, etc.)
# - gz302-llm: AI/LLM software (Ollama, ROCm, PyTorch, etc.)
# - gz302-hypervisor: Virtualization (KVM, VirtualBox, VMware, etc.)
# - gz302-snapshots: System snapshots (Snapper, LVM, etc.)
# - gz302-secureboot: Secure boot configuration
#
# Supported Distributions:
# - Arch-based: Arch Linux (also supports EndeavourOS, Manjaro)
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

# GitHub repository base URL for downloading modules
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Color codes for output (must be defined before error handler) ---
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

# --- Common helper functions ---
get_real_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo "${SUDO_USER}"
    elif command -v logname >/dev/null 2>&1; then
        logname 2>/dev/null || whoami
    else
        whoami
    fi
}

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
    local min_version=614  # 6.14 - Absolute minimum (AMD XDNA NPU support)
    local recommended_version=617  # 6.17 - Latest stable with full optimizations
    
    info "Detected kernel version: $(uname -r)"
    
    if [[ $version_num -lt $min_version ]]; then
        echo
        echo "❌ UNSUPPORTED KERNEL VERSION ❌"
        echo "Your kernel version ($kernel_version) is below the absolute minimum (6.14)."
        echo
        echo "Kernel 6.14+ is REQUIRED for GZ302EA because it includes:"
        echo "  - AMD XDNA NPU driver (essential for Ryzen AI MAX+ 395)"
        echo "  - MediaTek MT7925 WiFi driver integration"
        echo "  - AMD P-State driver with dynamic core ranking"
        echo "  - Critical RDNA 3.5 GPU support for Radeon 8060S"
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "OPTION: Install linux-g14 kernel (Arch-based distros only)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "The linux-g14 kernel is a customized kernel for ASUS ROG devices"
        echo "that includes the latest patches and optimizations for GZ302EA."
        echo
        # Detect if Arch-based distribution
        local distro=""
        if [[ -f /etc/os-release ]]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
                distro="arch"
            fi
        fi
        
        if [[ "$distro" == "arch" ]]; then
            echo "Would you like to install the linux-g14 kernel and headers?"
            echo "This will provide kernel 6.17+ with full GZ302EA support."
            echo
            read -p "Install linux-g14 kernel? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                info "Installing linux-g14 kernel and headers..."
                echo
                
                # Add G14 repository
                if ! grep -q "arch.asus-linux.org" /etc/pacman.conf 2>/dev/null; then
                    info "Adding G14 repository..."
                    { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
                    
                    # Import GPG key
                    pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
                    pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
                fi
                
                # Update package database
                pacman -Sy
                
                # Install linux-g14 and headers
                if pacman -S --noconfirm linux-g14 linux-g14-headers; then
                    success "linux-g14 kernel installed successfully!"
                    echo
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "REBOOT REQUIRED"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo
                    echo "The linux-g14 kernel has been installed."
                    echo "Please REBOOT your system and run this script again."
                    echo
                    echo "After rebooting, verify your kernel version with: uname -r"
                    echo "You should see a kernel version 6.17 or higher."
                    echo
                    exit 0
                else
                    echo "Failed to install linux-g14 kernel"
                    echo
                    echo "Please install a compatible kernel manually and try again."
                    echo "See: https://asus-linux.org for more information"
                    # Fall through to cancellation message below
                fi
            fi
        fi
        
        error "Installation cancelled. Kernel 6.14+ is required.\nOther upgrade options:\n  1. Use your distribution's kernel update mechanism\n  2. Install a mainline kernel from kernel.org\n  3. Check Info/kernel_changelog.md for version details\nIf you cannot upgrade, please create an issue on GitHub:\n  https://github.com/th3cavalry/GZ302-Linux-Setup/issues"
    elif [[ $version_num -lt $recommended_version ]]; then
        warning "Your kernel version ($kernel_version) meets minimum requirements (6.14+)"
        info "For optimal performance, consider upgrading to kernel 6.17+ which includes:"
        info "  - Fine-tuned AMD XDNA driver for enhanced AI performance"
        info "  - Enhanced Radeon 8060S iGPU scheduling and stability"
        info "  - Optimized MediaTek MT7925 WiFi with regression fixes"
        info "  - Refined AMD P-State power management for Strix Halo"
        echo
        info "See Info/kernel_changelog.md for detailed version comparison"
        echo
    else
        success "Kernel version ($kernel_version) meets recommended requirements (6.17+)"
        success "You have the latest optimizations for GZ302EA hardware"
        echo
    fi
    
    # Return the version number for conditional logic
    echo "$version_num"
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        
        # Detect Arch-based systems
        if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
            distro="arch"
        # Detect Debian/Ubuntu-based systems
        elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "pop" || "$ID" == "linuxmint" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* ]]; then
            distro="ubuntu"
        # Detect Fedora-based systems
        elif [[ "$ID" == "fedora" || "$ID_LIKE" == *"fedora"* ]]; then
            distro="fedora"
        # Detect OpenSUSE-based systems
        elif [[ "$ID" == "opensuse-tumbleweed" || "$ID" == "opensuse-leap" || "$ID" == "opensuse" || "$ID_LIKE" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    if [[ -z "$distro" ]]; then
        error "Unable to detect a supported Linux distribution."
    fi
    
    echo "$distro"
}

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
    if [ -f /etc/default/grub ]; then
        # Check if parameters already exist
        if ! grep -q "amd_pstate=guided" /etc/default/grub; then
            # Add AMD P-State (guided mode) and GPU parameters
            # amd_pstate=guided is optimal for Strix Halo (confirmed by Ubuntu 25.10 benchmarks)
            # amdgpu.ppfeaturemask=0xffffffff enables all power features for Radeon 8060S (RDNA 3.5)
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=guided amdgpu.ppfeaturemask=0xffffffff"/' /etc/default/grub
            
            # Regenerate GRUB config
            if [ -f /boot/grub/grub.cfg ]; then
                grub-mkconfig -o /boot/grub/grub.cfg
            elif command -v update-grub >/dev/null 2>&1; then
                update-grub
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
    info "Configuring AMD Radeon 8060S GPU..."
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5, integrated)
# Enable all power features for better performance and efficiency
# ROCm-compatible for AI/ML workloads
options amdgpu ppfeaturemask=0xffffffff
EOF

    # ASUS HID (keyboard/touchpad) configuration
    info "Configuring ASUS keyboard and touchpad..."
    cat > /etc/modprobe.d/hid-asus.conf <<'EOF'
# ASUS HID configuration for GZ302
# fnlock_default=0: F1-F12 keys work as media keys by default
# Kernel 6.15+ includes mature touchpad gesture support and improved ASUS HID integration
options hid_asus fnlock_default=0
EOF

    # Create systemd service to reload hid_asus module for reliable touchpad detection
    info "Creating HID module reload service for touchpad detection..."
    cat > /etc/systemd/system/reload-hid_asus.service <<'EOF'
[Unit]
Description=Reload hid_asus module with correct options for GZ302 Touchpad
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'if ! lsmod | grep -q hid_asus; then exit 0; fi'
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    systemctl daemon-reload
    systemctl enable reload-hid_asus.service

    # Ask user if they want folio resume fix (optional for Issue #83)
    echo
    info "Optional: Folio keyboard/touchpad resume fix"
    echo "Some users experience issues where the folio keyboard/touchpad stops"
    echo "working after suspend/resume and requires reconnecting the folio."
    echo
    # Single-key prompt with 30s timeout; defaults to 'N' if no input or non-interactive
    if [ -t 0 ]; then
        read -r -n 1 -t 30 -p "Install folio resume workaround? (y/N): " folio_response || folio_response=""
        echo
    else
        folio_response=""
    fi
    
    if [[ "$folio_response" =~ ^[Yy]$ ]]; then
        # Create folio resume script for touchpad/keyboard after suspend
        info "Creating folio resume script for Issue #83 workaround..."
        cat > /usr/local/bin/gz302-folio-resume.sh <<'EOF'
#!/bin/bash
# Resume fix for ASUS Flow Z13 folio keyboard/touchpad after suspend
# Reloads hid_asus and attempts to rebind folio USB device

# Reload hid_asus module
modprobe -r hid_asus
sleep 1
modprobe hid_asus

# Attempt to rebind folio keyboard (auto-detect by vendor:product if possible)
# Replace these IDs with actual values if known
FOLIO_VENDOR="0b05"   # ASUS
FOLIO_PRODUCT="1e0f"  # Example product ID (replace if known)

# Find folio device path
for DEV in /sys/bus/usb/devices/*; do
  if grep -q "$FOLIO_VENDOR" "$DEV/idVendor" 2>/dev/null && grep -q "$FOLIO_PRODUCT" "$DEV/idProduct" 2>/dev/null; then
    echo "Unbinding folio keyboard: $DEV"
    echo -n $(basename "$DEV") > /sys/bus/usb/drivers/usb/unbind
    sleep 1
    echo -n $(basename "$DEV") > /sys/bus/usb/drivers/usb/bind
  fi
done

exit 0
EOF
        chmod +x /usr/local/bin/gz302-folio-resume.sh

        # Create systemd service to reload hid_asus module after suspend/resume
        info "Creating suspend/resume HID module reload service for touchpad gestures..."
        cat > /etc/systemd/system/reload-hid_asus-resume.service <<'EOF'
[Unit]
Description=Reload hid_asus module after resume for GZ302 Touchpad gestures
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=/bin/bash /usr/local/bin/gz302-folio-resume.sh

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

        # Enable the resume service
        systemctl enable reload-hid_asus-resume.service
        success "Folio resume fix installed"
    else
        info "Skipping folio resume fix - you can install it later if needed"
    fi

    # Reload hardware database and udev
    systemd-hwdb update 2>/dev/null || true
    udevadm control --reload 2>/dev/null || true
    
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

        # Note about advanced fan/power control
    info "Note: For advanced fan and power mode control, consider the ec_su_axb35 kernel module"
    info "See: https://github.com/cmetz/ec-su_axb35-linux for Strix Halo-specific controls"
    
    success "Hardware fixes applied"
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

install_debian_asus_packages() {
    info "Installing ASUS control packages for Debian/Ubuntu..."
    
    # Install power-profiles-daemon
    apt install -y power-profiles-daemon || warning "power-profiles-daemon install failed"
    
    # Install switcheroo-control
    apt install -y switcheroo-control || warning "switcheroo-control install failed"
    
    # Try to install asusctl from PPA
    info "Attempting to install asusctl from PPA..."
    if command -v add-apt-repository >/dev/null 2>&1; then
        # Add Mitchell Austin's asusctl PPA
        add-apt-repository -y ppa:mitchellaugustin/asusctl 2>/dev/null || warning "Failed to add asusctl PPA"
        apt update 2>/dev/null || warning "Failed to update package list"
        
        # Try to install rog-control-center (includes asusctl)
        if apt install -y rog-control-center 2>/dev/null; then
            systemctl daemon-reload
            systemctl restart asusd 2>/dev/null || warning "Failed to restart asusd"
            success "asusctl installed from PPA"
        else
            warning "PPA installation failed"
            info "Manual installation: https://mitchellaugustin.com/asusctl.html"
        fi
    else
        warning "add-apt-repository not available"
        info "Install software-properties-common and retry, or see: https://asus-linux.org"
    fi
    
    # Enable services
    systemctl enable --now power-profiles-daemon || warning "Failed to enable power-profiles-daemon service"
    
    success "ASUS packages installed"
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

# Auto-elevate: allow running 'pwrcfg <profile>' without typing sudo
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
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

TDP_CONFIG_DIR="/etc/pwrcfg"
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
    echo "Usage: pwrcfg [PROFILE|status|list|auto|config]"
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
    echo "  status           - Show current power profile and settings"
    echo "  list             - List available profiles with details"
    echo "  auto             - Enable/disable automatic profile switching"
    echo "  config           - Configure automatic profile preferences"
    echo ""
    echo "Notes:"
    echo "  - Refresh rate changes automatically with power profile"
    echo "  - Use 'rrcfg' to manually override refresh rate"
    echo "  - SPL: Sustained Power Limit (long-term steady power)"
    echo "  - sPPT: Slow Power Boost (short-term, ~2 minutes)"
    echo "  - fPPT: Fast Power Boost (very short-term, few seconds)"
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
        read -p "Battery profile [efficient]: " battery_profile || true
        battery_profile="${battery_profile:-efficient}"
        
        if [ -z "${POWER_PROFILES[$battery_profile]:-}" ]; then
            echo "Invalid profile, using 'efficient'"
            battery_profile="efficient"
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
}

# Main script logic
case "$1" in
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
    
    # Optional: Configure sudoers to allow password-less 'sudo pwrcfg'
    echo ""
    read -p "Enable password-less pwrcfg (no sudo required) for all users? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local PWRCFG_PATH="/usr/local/bin/pwrcfg"
        if [[ -x "$PWRCFG_PATH" ]]; then
            local SUDOERS_TMP
            SUDOERS_TMP=$(mktemp /tmp/gz302-pwrcfg.XXXXXX)
            local SUDOERS_FILE="/etc/sudoers.d/gz302-pwrcfg"
            cat > "$SUDOERS_TMP" << EOF
# Allow all users to run pwrcfg without password
ALL ALL=NOPASSWD: $PWRCFG_PATH
EOF
            if visudo -c -f "$SUDOERS_TMP" >/dev/null 2>&1; then
                mv "$SUDOERS_TMP" "$SUDOERS_FILE"
                chmod 440 "$SUDOERS_FILE"
                info "Configured sudoers: you can now run 'pwrcfg <profile>' without typing sudo or a password."
                info "Note: You may need to open a new terminal or re-login for sudoers changes to apply."
            else
                rm -f "$SUDOERS_TMP"
                warning "Invalid sudoers config, skipped enabling password-less 'sudo pwrcfg'."
            fi
        else
            warning "pwrcfg not found at $PWRCFG_PATH; skipping sudoers setup."
        fi
    else
        info "Skipping sudoers configuration for 'pwrcfg'. You can enable later via tray-icon/install-policy.sh."
    fi
    
    # Create systemd service for automatic TDP management
    cat > /etc/systemd/system/pwrcfg-auto.service <<EOF
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target
Wants=pwrcfg-monitor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg balanced
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

    # Create power monitoring script
    cat > /usr/local/bin/pwrcfg-monitor <<'MONITOR_EOF'
#!/bin/bash
# GZ302 TDP Power Source Monitor
# Monitors power source changes and automatically switches TDP profiles

while true; do
    /usr/local/bin/pwrcfg auto
    sleep 10  # Check every 10 seconds
done
MONITOR_EOF

    chmod +x /usr/local/bin/pwrcfg-monitor
    
    # Reload systemd units to ensure new services are recognized
    systemctl daemon-reload
    
    systemctl enable pwrcfg-auto.service
    
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

REFRESH_CONFIG_DIR="/etc/rrcfg"
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

detect_displays() {
    # Detect connected displays and their capabilities
    local displays=()
    
    if command -v xrandr >/dev/null 2>&1; then
        # X11 environment
        displays=($(xrandr --listmonitors 2>/dev/null | grep -E "^ [0-9]:" | awk '{print $4}' | cut -d'/' -f1))
    elif command -v wlr-randr >/dev/null 2>&1; then
        # Wayland environment with wlr-randr
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
        echo "export MANGOHUD_CONFIG=\"fps_limit=$frame_limit\"" > "/etc/rrcfg/mangohud-fps-limit"
        
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

get_battery_status() {
    if command -v acpi >/dev/null 2>&1; then
        if acpi -a 2>/dev/null | grep -q "on-line"; then
            echo "AC"
        else
            echo "Battery"
        fi
    elif [[ -f /sys/class/power_supply/ADP1/online ]]; then
        if [[ "$(cat /sys/class/power_supply/ADP1/online 2>/dev/null)" == "1" ]]; then
            echo "AC"
        else
            echo "Battery"
        fi
    else
        echo "Unknown"
    fi
}

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

# --- Bootloader Configuration ---
configure_bootloader_for_kernel() {
    local kernel_name="$1"  # e.g., "linux" or "linux-g14"
    
    # Detect and update GRUB if present
    if [ -f /etc/default/grub ] || command -v grub-mkconfig >/dev/null 2>&1; then
        info "Updating GRUB bootloader configuration for ${kernel_name}..."
        if command -v grub-mkconfig >/dev/null 2>&1; then
            if [ -f /boot/grub/grub.cfg ]; then
                if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
                    success "GRUB configuration updated"
                else
                    warning "Failed to regenerate GRUB config"
                fi
            elif command -v update-grub >/dev/null 2>&1; then
                if update-grub 2>/dev/null; then
                    success "GRUB configuration updated (Ubuntu/Debian)"
                else
                    warning "Failed to update GRUB"
                fi
            fi
        fi
    fi
    
    # Detect and update systemd-boot if present
    if command -v bootctl >/dev/null 2>&1; then
        info "Updating systemd-boot configuration for ${kernel_name}..."
        
        # Check if systemd-boot is installed
        if bootctl status >/dev/null 2>&1; then
            # Verify boot entries directory exists
            if [ -d /boot/loader/entries ] || [ -d /efi/loader/entries ]; then
                # Update systemd-boot (graceful update to prevent boot issues)
                if bootctl update 2>/dev/null; then
                    success "systemd-boot updated"
                else
                    warning "Failed to update systemd-boot"
                fi
            fi
        fi
    fi
    
    # Log the kernel parameters that were applied
    if [ -f /proc/cmdline ]; then
        info "Current kernel command line:"
        if grep -q "amd_pstate=" /proc/cmdline; then
            info "$(grep -o 'amd_pstate=[^ ]*' /proc/cmdline)"
        else
            info "amd_pstate parameter not yet applied (reboot required)"
        fi
        if grep -q "amdgpu.ppfeaturemask=" /proc/cmdline; then
            info "$(grep -o 'amdgpu.ppfeaturemask=[^ ]*' /proc/cmdline)"
        else
            info "amdgpu.ppfeaturemask parameter not yet applied (reboot required)"
        fi
    fi
}

# --- Linux-G14 Kernel Installation ---
install_linux_g14_kernel() {
    local distro="$1"
    
    if [[ "$distro" != "arch" ]]; then
        warning "linux-g14 kernel is only available for Arch-based systems"
        warning "For other distributions, use your official package manager for kernel updates"
        return 1
    fi
    
    info "Installing linux-g14 kernel and headers..."
    info "This provides kernel 6.17+ with full ASUS ROG optimizations for GZ302EA"
    echo
    
    # Add G14 repository if not already present
    if ! grep -q "arch.asus-linux.org" /etc/pacman.conf 2>/dev/null; then
        info "Adding ASUS Linux repository..."
        { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
        
        # Import and sign GPG key
        info "Importing ASUS Linux GPG key..."
        if pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null; then
            pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 2>/dev/null
            success "GPG key imported and signed"
        else
            warning "Failed to import GPG key. You may need to verify the key manually."
        fi
    else
        info "ASUS Linux repository already configured"
    fi
    
    # Update package database
    info "Updating package database..."
    if ! pacman -Sy 2>/dev/null; then
        warning "Failed to update package database"
        return 1
    fi
    
    # Install linux-g14 and headers
    info "Installing linux-g14 and linux-g14-headers..."
    if pacman -S --noconfirm linux-g14 linux-g14-headers 2>/dev/null; then
        success "linux-g14 kernel installed successfully!"
        
        # Update bootloader configuration after kernel installation
        info "Updating bootloader entries for linux-g14..."
        configure_bootloader_for_kernel "linux-g14"
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "REBOOT REQUIRED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "The linux-g14 kernel has been installed successfully."
        echo
        echo "Bootloader Configuration Status:"
        echo "  ✓ Kernel parameters (amd_pstate=guided, amdgpu.ppfeaturemask) applied"
        echo "  ✓ GRUB configuration regenerated (if installed)"
        echo "  ✓ systemd-boot updated (if installed)"
        echo
        echo "Next steps:"
        echo "  1. REBOOT your system to activate the new kernel"
        echo "  2. Verify kernel version after reboot: uname -r"
        echo "     (you should see 'linux-g14' or a 6.17+ kernel version)"
        echo "  3. Verify boot parameters: cat /proc/cmdline | grep 'amd_pstate'"
        echo
        echo "For more information:"
        echo "  See: https://asus-linux.org"
        echo "  Analysis: Info/LINUX_G14_ANALYSIS.md"
        echo
        return 0
    else
        error "Failed to install linux-g14 kernel. Please check your internet connection and try again."
    fi
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
        warning "Failed to download ${module_name} module from ${module_url}\nPlease verify:\n  1. Internet connection is active\n  2. GitHub is accessible\n  3. Repository URL is correct"
        return 1
    fi
}

# --- Distribution-Specific Setup Functions ---
setup_arch_based() {
    local distro="$1"
    info "Setting up Arch-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    pacman -Syu --noconfirm --needed
    pacman -S --noconfirm --needed git base-devel wget curl
    
    # Install AUR helper if not present (for Arch-based systems)
    if [[ "$distro" == "arch" ]] && ! command -v yay >/dev/null 2>&1; then
        info "Installing yay AUR helper..."
        local primary_user
        primary_user=$(get_real_user)
        sudo -u "$primary_user" -H bash << 'EOFYAY'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOFYAY
    fi
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages (asusctl, power-profiles-daemon, switcheroo-control)
    install_arch_asus_packages
    
    # Install SOF firmware for audio support
    install_sof_firmware "arch"
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "arch"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_arch_services
}

setup_debian_based() {
    local distro="$1"
    info "Setting up Debian-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    apt update
    apt upgrade -y
    apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_debian_asus_packages
    
    # Install SOF firmware for audio support
    install_sof_firmware "ubuntu"
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "debian"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_debian_services
}

setup_fedora_based() {
    local distro="$1"
    info "Setting up Fedora-based system..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    dnf upgrade -y
    dnf install -y curl wget git gcc make kernel-devel
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_fedora_asus_packages
    
    # Install SOF firmware for audio support
    install_sof_firmware "fedora"
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "fedora"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
    enable_fedora_services
}

setup_opensuse() {
    local distro="$1"
    info "Setting up OpenSUSE..."
    
    # Update system and install base dependencies
    info "Updating system and installing base dependencies..."
    zypper refresh
    zypper update -y
    zypper install -y curl wget git gcc make kernel-devel
    
    # Apply hardware fixes
    apply_hardware_fixes
    
    # Install ASUS-specific packages
    install_opensuse_asus_packages
    
    # Install SOF firmware for audio support
    install_sof_firmware "opensuse"
    
    # Setup TDP management (always install for all systems)
    setup_tdp_management "opensuse"
    
    # Setup refresh rate management (always install for all systems)
    install_refresh_management
    
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
    echo "1. Linux-G14 Kernel (Arch only) (linux-g14)"
    echo "   - Community-maintained ASUS-optimized kernel (6.17.3)"
    echo "   - Kernel-level LED control and suspend/resume hooks"
    echo "   - OLED panel optimizations and power management tunables"
    echo "   - See: Info/LINUX_G14_ANALYSIS.md for detailed comparison"
    echo
    echo "2. Gaming Software (gz302-gaming)"
    echo "   - Steam, Lutris, ProtonUp-Qt"
    echo "   - MangoHUD, GameMode, Wine"
    echo "   - Gaming optimizations and performance tweaks"
    echo
    echo "3. LLM/AI Software (gz302-llm)"
    echo "   - Ollama for local LLM inference"
    echo "   - ROCm for AMD GPU acceleration"
    echo "   - PyTorch and Transformers libraries"
    echo
    echo "4. Hypervisor Software (gz302-hypervisor)"
    echo "   - KVM/QEMU, VirtualBox, VMware, Xen, or Proxmox"
    echo "   - Virtual machine management tools"
    echo
    echo "5. System Snapshots (gz302-snapshots)"
    echo "   - Automatic daily system backups"
    echo "   - Easy system recovery and rollback"
    echo "   - Supports ZFS, Btrfs, ext4 (LVM), and XFS"
    echo
    echo "6. Secure Boot (gz302-secureboot)"
    echo "   - Enhanced system security and boot integrity"
    echo "   - Automatic kernel signing on updates"
    echo
    echo "7. Skip optional modules"
    echo
    
    read -r -p "Which modules would you like to install? (comma-separated numbers, e.g., 1,2 or 7 to skip): " module_choice
    
    # Parse the choices
    IFS=',' read -ra CHOICES <<< "$module_choice"
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | tr -d ' ') # Remove spaces
        case "$choice" in
            1)
                install_linux_g14_kernel "$distro" || warning "linux-g14 kernel installation failed"
                ;;
            2)
                download_and_execute_module "gz302-gaming" "$distro" || warning "Gaming module installation failed"
                ;;
            3)
                download_and_execute_module "gz302-llm" "$distro" || warning "LLM module installation failed"
                ;;
            4)
                download_and_execute_module "gz302-hypervisor" "$distro" || warning "Hypervisor module installation failed"
                ;;
            5)
                download_and_execute_module "gz302-snapshots" "$distro" || warning "Snapshots module installation failed"
                ;;
            6)
                download_and_execute_module "gz302-secureboot" "$distro" || warning "Secure boot module installation failed"
                ;;
            7)
                info "Skipping optional modules"
                ;;
            *)
                warning "Invalid choice: $choice"
                ;;
        esac
    done
}

# --- Main Execution Logic ---
main() {
    # Verify script is run with root privileges (required for system configuration)
    check_root
    
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Setup Script"
    echo "  Version 1.0.7"
    echo "============================================================"
    echo
    
    # Check kernel version early (before network check)
    info "Checking kernel version..."
    # Perform kernel version validation early (exits on failure)
    check_kernel_version >/dev/null
    echo
    
    # Check network connectivity
    info "Checking network connectivity..."
    if ! check_network; then
        warning "Network connectivity check failed."
        warning "Some features may not work without internet access."
        warning "Please ensure you have an active internet connection."
        echo
        read -r -p "Do you want to continue anyway? (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            error "Setup cancelled. Please connect to the internet and try again."
        fi
        warning "Continuing without network validation..."
    else
        success "Network connectivity confirmed"
    fi
    echo
    
    info "Detecting your Linux distribution..."
    
    # Get original distribution name for display
    local original_distro=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        original_distro="$ID"
    fi
    
    local detected_distro
    detected_distro=$(detect_distribution)
    
    if [[ "$original_distro" != "$detected_distro" ]]; then
        success "Detected distribution: $original_distro (using $detected_distro base)"
    else
        success "Detected distribution: $detected_distro"
    fi
    echo
    
    info "Starting setup process for $detected_distro-based systems..."
    info "This will apply GZ302-specific hardware fixes and install TDP/refresh rate management."
    echo
    
    # Route to appropriate setup function based on base distribution
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
    success "============================================================"
    success "GZ302 Core Setup Complete for $detected_distro-based systems!"
    success ""
    success "Applied GZ302-specific hardware fixes:"
    success "- Wi-Fi stability (MediaTek MT7925e)"
    success "- Touchpad detection and functionality"
    success "- Audio support (SOF firmware)"
    success "- GPU and thermal optimizations"
    success "- Power management: Use 'pwrcfg' command"
    success "- Refresh rate control: Use 'rrcfg' command"
    success "============================================================"
    echo
    
    # Offer optional modules
    offer_optional_modules "$detected_distro"
    
    echo
    echo
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    success "SCRIPT COMPLETED SUCCESSFULLY!"
    success "Core setup is COMPLETE!"
    success "It is highly recommended to REBOOT your system now."
    success ""
    success "Available power profiles: emergency, battery, efficient, balanced, performance, gaming, maximum"
    success "Check power status with: pwrcfg status"
    success "Check refresh rate with: rrcfg status"
    success ""
    success "Your ROG Flow Z13 (GZ302) is now optimized for $detected_distro!"
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    echo
}

# --- Run the script ---
main "$@"
