#!/bin/bash
# ==============================================================================
# GZ302 Command Center Installer
# Version: 4.0.2
#
# Installs the complete user-facing toolset for ASUS ROG Flow Z13 (GZ302):
# 1. Power Controls (pwrcfg) - TDP and Power Profile management
# 2. Display Controls (rrcfg) - Refresh Rate and VRR management
# 3. RGB Controls (gz302-rgb) - Keyboard and Lightbar control
# 4. Command Center (Tray Icon) - GUI for all the above
#
# Usage:
#   sudo ./install-command-center.sh
# ==============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/gz302-lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/gz302-lib/utils.sh"
else
    echo "gz302-lib/utils.sh not found. Downloading..."
    mkdir -p "${SCRIPT_DIR}/gz302-lib"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/utils.sh" -o "${SCRIPT_DIR}/gz302-lib/utils.sh"
        chmod +x "${SCRIPT_DIR}/gz302-lib/utils.sh"
        source "${SCRIPT_DIR}/gz302-lib/utils.sh"
    else
        echo "Error: curl not found."
        exit 1
    fi
fi

# --- Load Libraries ---
load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        echo "Downloading ${lib_name}..."
        mkdir -p "${SCRIPT_DIR}/gz302-lib"
        curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path"
        chmod +x "$lib_path"
        source "$lib_path"
    fi
}

load_library "power-manager.sh"
load_library "display-manager.sh"

# --- Helper Functions ---

install_dependencies() {
    print_subsection "Installing System Dependencies"
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            echo "Installing dependencies for Arch Linux..."
            pacman -S --noconfirm --needed python-pyqt6 python-psutil libusb \
                libnotify base-devel git cmake 2>/dev/null || true
            # Check for AUR helpers for ryzenadj
            if ! command -v ryzenadj >/dev/null 2>&1; then
                echo "Note: 'ryzenadj' will be built from source if not found in AUR"
            fi
            ;;
        debian|ubuntu)
            echo "Installing dependencies for Debian/Ubuntu..."
            apt-get update
            apt-get install -y python3-pyqt6 python3-psutil libusb-1.0-0-dev \
                libnotify-bin build-essential git cmake libpci-dev
            ;;
        fedora)
            echo "Installing dependencies for Fedora..."
            dnf install -y python3-pyqt6 python3-psutil libusb1-devel \
                libnotify gcc gcc-c++ git cmake pciutils-devel
            ;;
        opensuse)
            echo "Installing dependencies for OpenSUSE..."
            zypper install -y python3-qt6 python3-psutil libusb-1_0-devel \
                libnotify-tools gcc gcc-c++ git cmake pciutils-devel
            ;;
        *)
            warning "Unsupported distribution: $distro. Attempting to proceed..."
            ;;
    esac
    completed_item "Dependencies installed"
}

# --- System Daemon Installation (Moved from Main Installer) ---
install_system_daemon() {
    print_subsection "Installing System Daemons (PPD & ASUS Tools)"
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            echo "Installing packages for Arch Linux..."
            # Install PPD
            pacman -S --noconfirm --needed power-profiles-daemon
            
            # Install asusctl (G14 repo or AUR)
            if ! grep -q '\[g14\]' /etc/pacman.conf; then
                echo "Adding G14 repository..."
                pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || echo "Warning: Failed to receive G14 key"
                pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35 || echo "Warning: Failed to sign G14 key"
                { echo ""; echo "[g14]"; echo "Server = https://arch.asus-linux.org"; } >> /etc/pacman.conf
                pacman -Sy
            fi
            
            if pacman -S --noconfirm --needed asusctl; then
                echo "asusctl installed from G14 repository"
            else
                echo "G14 repo failed, trying AUR (yay)..."
                local primary_user
                primary_user=$(get_real_user)
                if command -v yay >/dev/null 2>&1; then
                    sudo -u "$primary_user" yay -S --noconfirm --needed asusctl || echo "Warning: AUR install failed"
                    sudo -u "$primary_user" yay -S --noconfirm --needed switcheroo-control || echo "Warning: switcheroo-control install failed"
                else
                    echo "Warning: yay not found, skipping asusctl"
                fi
            fi
            ;;
            
        debian|ubuntu)
            echo "Installing packages for Debian/Ubuntu..."
            apt-get install -y power-profiles-daemon switcheroo-control
            
            # Install asusctl (PPA)
            if [[ "$(lsb_release -sc)" == "oracular" ]]; then
                if command -v add-apt-repository >/dev/null 2>&1; then
                    add-apt-repository -y ppa:mitchellaugustin/asusctl 2>/dev/null || true
                    apt-get update
                    if apt-get install -y rog-control-center; then
                        echo "asusctl installed from PPA"
                    else
                        echo "PPA install failed, attempting source build..."
                        build_asusctl_from_source
                    fi
                fi
            else
                echo "Not Ubuntu Oracular, attempting source build..."
                build_asusctl_from_source
            fi
            ;;
            
        fedora)
            echo "Installing packages for Fedora..."
            
            # Fedora 43+ uses tuned-ppd instead of power-profiles-daemon
            # tuned-ppd provides the same ppd-service and powerprofilesctl interface
            if rpm -q tuned-ppd >/dev/null 2>&1; then
                echo "tuned-ppd already installed (Fedora 43+ default)"
                echo "tuned-ppd provides compatible power profile management"
            else
                # Fedora < 43 or if tuned-ppd was removed
                if dnf install -y power-profiles-daemon 2>/dev/null; then
                    echo "power-profiles-daemon installed"
                else
                    # Try tuned-ppd as fallback
                    echo "Installing tuned-ppd (compatible replacement)..."
                    dnf install -y tuned-ppd || echo "Warning: Failed to install power profile daemon"
                fi
            fi
            
            # Install switcheroo-control
            dnf install -y switcheroo-control 2>/dev/null || echo "Warning: switcheroo-control install failed"
            
            # Install asusctl (COPR)
            if command -v dnf >/dev/null 2>&1; then
                dnf copr enable -y lukenukem/asus-linux 2>/dev/null || true
                dnf install -y asusctl 2>/dev/null || echo "Warning: asusctl install failed"
            fi
            ;;
            
        opensuse)
            echo "Installing packages for OpenSUSE..."
            zypper install -y power-profiles-daemon switcheroo-control
            
            # Install asusctl (OBS)
            local os_ver="openSUSE_Tumbleweed"
            if grep -q "openSUSE Leap" /etc/os-release 2>/dev/null; then
                os_ver="openSUSE_Leap_15.6"
            fi
            zypper ar -f "https://download.opensuse.org/repositories/hardware:/asus/${os_ver}/" hardware:asus 2>/dev/null || true
            zypper ref 2>/dev/null || true
            zypper install -y asusctl 2>/dev/null || echo "Warning: asusctl install failed"
            ;;
    esac
    
    # Enable PPD service (power-profiles-daemon or tuned-ppd)
    # Try power-profiles-daemon first (traditional PPD)
    if systemctl enable --now power-profiles-daemon 2>/dev/null; then
        echo "power-profiles-daemon service enabled"
    elif systemctl enable --now tuned 2>/dev/null; then
        # Fedora 43+ with tuned-ppd: enable tuned service
        echo "tuned service enabled (provides power profile management via tuned-ppd)"
    else
        echo "Warning: Failed to enable power profile daemon service"
    fi
    
    # Enable asusctl daemon
    systemctl enable --now asusd 2>/dev/null || true
    
    completed_item "System Daemons installed (PPD, asusctl)"
}

build_asusctl_from_source() {
    echo "Building asusctl from source..."
    
    # Build dependencies
    apt-get update
    apt-get install -y make cargo gcc pkg-config libasound2-dev cmake build-essential python3 \
        libfreetype6-dev libexpat1-dev libxcb-composite0-dev libssl-dev libx11-dev \
        libfontconfig1-dev curl libclang-dev libudev-dev libseat-dev libinput-dev \
        libxkbcommon-dev libgbm-dev git || return 1
    
    local work_dir="/tmp/asusctl_build"
    local original_dir
    original_dir=$(pwd)
    
    mkdir -p "$work_dir"
    
    # Use pushd/popd to safely change directories (avoids getcwd errors)
    if ! pushd "$work_dir" > /dev/null 2>&1; then
        echo "Error: Could not enter $work_dir"
        return 1
    fi
    
    if [[ ! -d "asusctl" ]]; then
        git clone https://gitlab.com/asus-linux/asusctl.git || {
            echo "Error: Failed to clone asusctl repository"
            popd > /dev/null 2>&1
            return 1
        }
    fi
    
    if ! pushd asusctl > /dev/null 2>&1; then
        echo "Error: Could not enter asusctl directory"
        popd > /dev/null 2>&1
        return 1
    fi
    
    # Fetch latest stable tag to avoid build issues with main branch
    git fetch --tags 2>/dev/null || true
    local stable_tag
    stable_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$stable_tag" ]]; then
        echo "Checking out stable release: $stable_tag"
        git checkout "$stable_tag" 2>/dev/null || true
    fi
    
    echo "Compiling asusd (core daemon)..."
    # Build only asusd - skip rog-control-center due to slint GUI framework dependency issues
    # The rog-control-center requires slint which may have version/dependency conflicts
    if make asusd 2>/dev/null; then
        echo "asusd compiled successfully"
    else
        echo "asusd target not found, trying full build (may fail on rog-control-center)..."
        make || {
            echo "Warning: Full build failed, attempting daemon-only install..."
            # Try to install just what was built
            make install 2>/dev/null || true
        }
    fi
    
    make install 2>/dev/null || true
    
    # Return to original directories
    popd > /dev/null 2>&1  # exit asusctl
    popd > /dev/null 2>&1  # exit work_dir
    
    # Return to original directory as fallback
    cd "$original_dir" 2>/dev/null || true
    
    systemctl daemon-reload
    systemctl enable --now asusd 2>/dev/null || echo "Note: asusd service may need manual configuration"
}

install_power_tools() {
    print_section "Step 1: Power Controls (pwrcfg)"
    
    # Install ryzenadj (TDP control backend)
    local distro
    distro=$(detect_distribution)
    
    if ! command -v ryzenadj >/dev/null 2>&1; then
        info "Installing ryzenadj..."
        power_install_ryzenadj "$distro"
    fi
    
    # Install pwrcfg script
    info "Installing pwrcfg CLI..."
    power_get_pwrcfg_script > /usr/local/bin/pwrcfg
    chmod +x /usr/local/bin/pwrcfg
    power_init_config
    
    # Install systemd services for persistence
    cat > /etc/systemd/system/pwrcfg-auto.service <<'EOF'
[Unit]
Description=GZ302 Automatic TDP Management
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pwrcfg-restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Install pwrcfg-monitor service for AC/Battery auto-switching
    cat > /etc/systemd/system/pwrcfg-monitor.service <<'EOF'
[Unit]
Description=GZ302 Power Source Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pwrcfg-monitor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Install pwrcfg-resume service for sleep/hibernate
    cat > /etc/systemd/system/pwrcfg-resume.service <<'EOF'
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

    # Enable and start services
    systemctl daemon-reload
    systemctl enable pwrcfg-auto.service
    systemctl enable pwrcfg-monitor.service
    systemctl enable pwrcfg-resume.service
    
    # Start monitor service if not already running
    if ! systemctl is-active --quiet pwrcfg-monitor.service; then
        systemctl start pwrcfg-monitor.service
    fi
    
    completed_item "Power controls installed (pwrcfg)"
}

install_display_tools() {
    print_section "Step 2: Display Controls (rrcfg)"
    
    info "Installing rrcfg CLI..."
    display_get_rrcfg_script > /usr/local/bin/rrcfg
    chmod +x /usr/local/bin/rrcfg
    display_init_config
    
    completed_item "Display controls installed (rrcfg)"
}

install_rgb_tools() {
    print_section "Step 3: RGB Controls"
    
    # Check if rgb-install script exists locally or download it
    local rgb_install_script="${SCRIPT_DIR}/scripts/gz302-rgb-install.sh"
    local distro
    distro=$(detect_distribution)
    # Fallback to arch if detection is unreliable
    if [[ "${distro:-}" == "unknown" || -z "${distro:-}" ]]; then
        info "Distribution detection returned 'unknown' — using 'arch' fallback for RGB installer"
        distro="arch"
    fi
    
    if [[ -f "$rgb_install_script" ]]; then
        info "Running RGB installation (distro=${distro})..."
        bash "$rgb_install_script" "$distro"
    else
        info "Downloading RGB installation script..."
        curl -fsSL "${GITHUB_RAW_URL}/scripts/gz302-rgb-install.sh" -o /tmp/gz302-rgb-install.sh
        bash /tmp/gz302-rgb-install.sh "$distro"
        rm -f /tmp/gz302-rgb-install.sh
    fi
    
    completed_item "RGB controls installed (gz302-rgb)"
}

# Stop any running tray instances before update
stop_running_tray() {
    local pids
    pids=$(pgrep -f 'gz302_tray.py|gz302-control-center' 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        info "Stopping running Control Center instances..."
        pkill -f 'gz302_tray.py' 2>/dev/null || true
        pkill -f 'gz302-control-center' 2>/dev/null || true
        sleep 1
        completed_item "Stopped existing tray processes"
    fi
    
    # Remove any user-level autostart files to prevent duplicates
    # (we only use system-level /etc/xdg/autostart)
    local real_user="${SUDO_USER:-}"
    if [[ -n "$real_user" && "$real_user" != "root" ]]; then
        local real_home
        real_home=$(getent passwd "$real_user" | cut -d: -f6)
        rm -f "$real_home/.config/autostart/gz302-tray.desktop" 2>/dev/null || true
        rm -f "$real_home/.config/autostart/gz302-control-center.desktop" 2>/dev/null || true
    fi
}

# Restart tray for the user who invoked sudo
start_tray_for_user() {
    local real_user="${SUDO_USER:-}"
    if [[ -z "$real_user" || "$real_user" == "root" ]]; then
        info "No regular user detected; skipping tray auto-start"
        return
    fi
    
    local real_home
    real_home=$(getent passwd "$real_user" | cut -d: -f6)
    local display_env=""
    
    # Try to find user's display
    if [[ -n "${DISPLAY:-}" ]]; then
        display_env="DISPLAY=$DISPLAY"
    else
        # Check common display values
        for d in :0 :1; do
            if [[ -e "/tmp/.X11-unix/X${d#:}" ]]; then
                display_env="DISPLAY=$d"
                break
            fi
        done
    fi
    
    # Try to find WAYLAND_DISPLAY
    local wayland_env=""
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        wayland_env="WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    elif [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u "$real_user")}/wayland-0" ]]; then
        wayland_env="WAYLAND_DISPLAY=wayland-0"
    fi
    
    local user_id
    user_id=$(id -u "$real_user")
    local xdg_runtime="XDG_RUNTIME_DIR=/run/user/${user_id}"
    
    info "Starting Control Center for user $real_user..."
    su - "$real_user" -c "$display_env $wayland_env $xdg_runtime setsid /usr/local/bin/gz302-control-center >/tmp/gz302-tray.log 2>&1 &" || true
    sleep 1
    
    if pgrep -f 'gz302_tray.py' >/dev/null 2>&1; then
        completed_item "Control Center started for $real_user"
    else
        warning "Could not auto-start tray; start manually or log out/in"
    fi
}

install_tray_icon() {
    print_section "Step 4: Command Center (Tray Icon)"
    
    local tray_dir="${SCRIPT_DIR}/tray-icon"
    local install_dir="/opt/gz302-control-center"
    
    # Create install directory
    mkdir -p "$install_dir"
    mkdir -p "$install_dir/src/modules"
    mkdir -p "$install_dir/assets"
    
    # Copy tray application files
    if [[ -d "$tray_dir" ]]; then
        cp -r "$tray_dir/src/"* "$install_dir/src/"
        cp -r "$tray_dir/assets/"* "$install_dir/assets/"
        [[ -f "$tray_dir/requirements.txt" ]] && cp "$tray_dir/requirements.txt" "$install_dir/"
        [[ -f "$tray_dir/VERSION" ]] && cp "$tray_dir/VERSION" "$install_dir/"
    else
        # Download from GitHub
        info "Downloading tray application..."
        mkdir -p /tmp/gz302-tray
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/gz302_tray.py" -o "$install_dir/src/gz302_tray.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/modules/__init__.py" -o "$install_dir/src/modules/__init__.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/modules/config.py" -o "$install_dir/src/modules/config.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/modules/notifications.py" -o "$install_dir/src/modules/notifications.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/modules/power_controller.py" -o "$install_dir/src/modules/power_controller.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/src/modules/rgb_controller.py" -o "$install_dir/src/modules/rgb_controller.py"
        curl -fsSL "${GITHUB_RAW_URL}/tray-icon/VERSION" -o "$install_dir/VERSION" 2>/dev/null || true
        for icon in ac battery lightning profile-b profile-e profile-f profile-g profile-m profile-p; do
            curl -fsSL "${GITHUB_RAW_URL}/tray-icon/assets/${icon}.svg" -o "$install_dir/assets/${icon}.svg" 2>/dev/null || true
        done
    fi
    
    # Install system icon for proper XDG integration
    local icon_src="$install_dir/assets/profile-b.svg"
    if [[ -f "$icon_src" ]]; then
        local icon_dest="/usr/share/icons/hicolor/scalable/apps/gz302-control-center.svg"
        mkdir -p "$(dirname "$icon_dest")"
        cp "$icon_src" "$icon_dest"
        # Update icon cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
        fi
    fi
    
    # Install sudoers for password-less operation
    install_sudoers_policy
    
    # Create launcher script
    cat > /usr/local/bin/gz302-control-center <<'EOF'
#!/bin/bash
cd /opt/gz302-control-center
exec python3 src/gz302_tray.py "$@"
EOF
    chmod +x /usr/local/bin/gz302-control-center
    
    # Create desktop entry
    local desktop_file="/usr/share/applications/gz302-control-center.desktop"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=GZ302 Control Center
Comment=Power and RGB control for ASUS ROG Flow Z13
Exec=/usr/local/bin/gz302-control-center
Icon=gz302-control-center
Terminal=false
Type=Application
Categories=System;Settings;HardwareSettings;
Keywords=power;tdp;rgb;asus;rog;
StartupNotify=false
EOF

    # Create autostart entry
    local autostart_dir="/etc/xdg/autostart"
    mkdir -p "$autostart_dir"
    cat > "$autostart_dir/gz302-control-center.desktop" <<EOF
[Desktop Entry]
Name=GZ302 Control Center
Comment=Power and RGB control for ASUS ROG Flow Z13
Exec=/usr/local/bin/gz302-control-center
Icon=gz302-control-center
Terminal=false
Type=Application
Categories=System;
X-GNOME-Autostart-enabled=true
Hidden=false
EOF

    completed_item "Command Center installed"
}

install_sudoers_policy() {
    print_subsection "Configuring Sudoers"
    
    local sudoers_file="/etc/sudoers.d/gz302-pwrcfg"
    
    cat > "$sudoers_file" <<'EOF'
# GZ302 Control Center - Password-less sudo for system tools
# This allows the tray application to control power and RGB without prompts

# Power profile control
ALL ALL=NOPASSWD: /usr/local/bin/pwrcfg
ALL ALL=NOPASSWD: /usr/local/bin/rrcfg

# RGB control  
ALL ALL=NOPASSWD: /usr/local/bin/gz302-rgb
ALL ALL=NOPASSWD: /usr/local/bin/gz302-rgb-window
ALL ALL=NOPASSWD: /usr/local/bin/gz302-rgb-restore

# Ryzenadj direct access (fallback)
ALL ALL=NOPASSWD: /usr/local/bin/ryzenadj
ALL ALL=NOPASSWD: /usr/bin/ryzenadj
EOF

    chmod 440 "$sudoers_file"
    
    # Validate sudoers
    if visudo -c >/dev/null 2>&1; then
        completed_item "Sudoers policy installed"
    else
        warning "Sudoers validation failed - removing file"
        rm -f "$sudoers_file"
    fi
}

# --- Main Installation Flow ---

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo ./install-command-center.sh)"
        exit 1
    fi
    
    print_banner "GZ302 Command Center Installer"
    
    echo ""
    echo "This will install the complete control suite for your ROG Flow Z13:"
    echo "  • pwrcfg  - Power profile management (10W-90W TDP control)"
    echo "  • rrcfg   - Display refresh rate control (30Hz-180Hz)"
    echo "  • gz302-rgb - Keyboard and rear window RGB control"
    echo "  • Control Center - System tray GUI for all the above"
    echo ""
    
    # Stop running tray before update
    stop_running_tray
    
    # Install in order
    # Install in order
    install_dependencies
    install_system_daemon
    install_power_tools
    install_display_tools
    install_rgb_tools
    install_tray_icon
    
    # Restart tray for user
    start_tray_for_user
    
    # Final summary
    print_section "Installation Complete!"
    
    echo ""
    success "All components installed successfully!"
    echo ""
    echo "Available commands:"
    echo "  pwrcfg [profile|status|auto]     - Power profile control"
    echo "  rrcfg [profile|status]           - Refresh rate control"
    echo "  gz302-rgb [color|effect]         - Keyboard RGB control"
    echo "  gz302-rgb-window [--lightbar N]  - Rear window RGB control"
    echo "  gz302-control-center             - Launch system tray GUI"
    echo ""
    echo "The Control Center will auto-start on login."
    echo "You can also launch it manually or from your application menu."
    echo ""
    
    # Check desktop environment for compatibility notes
    local current_de="${XDG_CURRENT_DESKTOP:-unknown}"
    if [[ "$current_de" == *"GNOME"* ]]; then
        warning "GNOME detected: You may need to install the 'AppIndicator' extension for system tray support."
        echo "  Install from: https://extensions.gnome.org/extension/615/appindicator-support/"
        echo ""
    fi
}

main "$@"
