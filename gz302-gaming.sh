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
if [[ -f "${SCRIPT_DIR}/gz302-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/gz302-utils.sh"
else
    echo "gz302-utils.sh not found. Downloading..."
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main}"
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

# --- Gaming Software Installation Functions ---
install_arch_gaming_software() {
    print_section "Gaming Software Installation (Arch)"
    
    local total_steps=5
    
    # Step 1: Enable multilib
    print_step 1 $total_steps "Configuring multilib repository..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        pacman -Sy --quiet 2>&1 | grep -v "^::" || true
        completed_item "Multilib repository enabled"
    else
        completed_item "Multilib already configured"
    fi
    
    # Remove conflicting jack2 package if present
    if pacman -Q jack2 >/dev/null 2>&1; then
        info "Removing jack2 (conflicts with pipewire-jack)..."
        pacman -R --noconfirm jack2 2>&1 | grep -v "^::" || true
    fi
    
    # Step 2: Core gaming applications
    info "Installing large gaming packages (Steam, Lutris, Vulkan). This may take several minutes depending on your network and mirrors. Avoid interrupting the process." 
    print_step 2 $total_steps "Installing Steam, Lutris, GameMode..."
    echo -ne "${C_DIM}"
    pacman -S --noconfirm --needed steam lutris gamemode lib32-gamemode discord \
        vulkan-radeon lib32-vulkan-radeon \
        gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav 2>&1 | grep -v "^::" | grep -v "warning:" | grep -v "^$" || true
    echo -ne "${C_NC}"
    completed_item "Core gaming apps installed"
    
    # Step 3: Performance tools
    print_step 3 $total_steps "Installing MangoHUD, Wine, and tools..."
    echo -ne "${C_DIM}"
    pacman -S --noconfirm --needed \
        mangohud goverlay \
        wine-staging winetricks \
        corectrl \
        mesa-utils vulkan-tools \
        lib32-mesa lib32-vulkan-radeon \
        pipewire pipewire-pulse pipewire-jack lib32-pipewire 2>&1 | grep -v "^::" | grep -v "warning:" | grep -v "^$" || true
    echo -ne "${C_NC}"
    completed_item "Performance tools installed"
    
    # Step 4: AUR packages
    print_step 4 $total_steps "Installing AUR packages (ProtonUp-Qt)..."
    local primary_user
    primary_user=$(get_real_user)
    if command -v yay &> /dev/null && [[ "$primary_user" != "root" ]]; then
        echo -ne "${C_DIM}"
        sudo -u "$primary_user" -H yay -S --noconfirm --needed protonup-qt 2>&1 | grep -v "^::" | grep -v "warning:" || true
        # Optional: discord-canary (AUR)
        sudo -u "$primary_user" -H yay -S --noconfirm --needed discord-canary 2>&1 | grep -v "^::" | grep -v "warning:" || true
        echo -ne "${C_NC}"
        completed_item "ProtonUp-Qt installed"
    else
        warning "yay not found or running as root - skipping AUR packages"
    fi

    # If discord not installed via pacman, fallback to Flatpak
    if ! command -v discord >/dev/null 2>&1 && ! flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        if install_discord_flatpak "arch"; then
            completed_item "Discord installed via Flatpak"
        else
            warning "Discord is not available via pacman or flatpak using system install"
        fi
    fi
    
    # Step 5: Summary
    print_step 5 $total_steps "Verifying installation..."
    echo
    print_subsection "Installed Gaming Software"
    # Note: Don't run GUI apps (steam, lutris) as root - they show warning popups
    command -v steam >/dev/null && print_keyval "Steam" "installed"
    command -v lutris >/dev/null && print_keyval "Lutris" "installed"
    command -v gamemoded >/dev/null && print_keyval "GameMode" "installed"
    command -v mangohud >/dev/null && print_keyval "MangoHUD" "installed"
    command -v wine >/dev/null && print_keyval "Wine" "$(wine --version 2>/dev/null || echo 'installed')"
    if command -v discord >/dev/null; then
        print_keyval "Discord" "installed"
    elif flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        print_keyval "Discord" "installed (flatpak)"
    fi
    if command -v discord >/dev/null; then
        print_keyval "Discord" "installed"
    elif flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        print_keyval "Discord" "installed (flatpak)"
    fi
    if command -v discord >/dev/null; then
        print_keyval "Discord" "installed"
    elif flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        print_keyval "Discord" "installed (flatpak)"
    fi
    # (Discord status printed above if available or via flatpak)
    echo
}

# Install Discord via Flatpak (system-wide) if package manager does not provide it
install_discord_flatpak() {
    local distro="$1"
    info "Attempting to install Discord via Flatpak (system-wide)..."
    if ! command -v flatpak >/dev/null 2>&1; then
        info "Flatpak not found - installing flatpak via package manager..."
        case "$distro" in
            "arch"|"cachyos") pacman -S --noconfirm --needed flatpak || true ;; 
            "ubuntu"|"debian") apt-get install -qq -y flatpak || true ;; 
            "fedora") dnf install -q -y flatpak || true ;; 
            "opensuse") zypper install -y --quiet flatpak || true ;; 
            *) info "Unknown distro; try manual flatpak install"; return 1 ;; 
        esac
    fi
    # Add Flathub remote if not present
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    # Try system-wide install
    if flatpak install --system -y flathub com.discordapp.Discord >/dev/null 2>&1; then
        success "Installed Discord via Flatpak (system-wide)"
        return 0
    fi
    warning "Flatpak install for Discord failed; user-level install might be required"
    return 1
}

install_debian_gaming_software() {
    print_section "Gaming Software Installation (Debian/Ubuntu)"
    
    local total_steps=5
    
    # Step 1: Add repositories
    print_step 1 $total_steps "Adding multiverse and universe repositories..."
    add-apt-repository -y multiverse 2>&1 | grep -v "^$" || true
    add-apt-repository -y universe 2>&1 | grep -v "^$" || true
    apt-get update -qq
    completed_item "Repositories configured"
    
    # Step 2: Core gaming apps
    info "Installing large gaming packages (Steam, Lutris, Vulkan). This may take several minutes depending on your network and mirrors. Avoid interrupting the process." 
    print_step 2 $total_steps "Installing Steam, Lutris, GameMode..."
    echo -ne "${C_DIM}"
    apt-get install -qq -y steam lutris gamemode discord 2>&1 | grep -v "^Reading\|^Building\|^Get:" || true
    echo -ne "${C_NC}"
    completed_item "Core gaming apps installed"
    
    # Step 3: MangoHUD and Wine
    print_step 3 $total_steps "Installing MangoHUD and Wine..."
    dpkg --add-architecture i386 2>/dev/null || true
    apt-get update -qq
    echo -ne "${C_DIM}"
    apt-get install -qq -y mangohud wine64 wine32 winetricks 2>&1 | grep -v "^Reading\|^Building\|^Get:" || true
    echo -ne "${C_NC}"
    completed_item "MangoHUD and Wine installed"
    
    # Step 4: Media codecs
    print_step 4 $total_steps "Installing media codecs and Vulkan drivers..."
    echo -ne "${C_DIM}"
    apt-get install -qq -y \
        vulkan-tools mesa-vulkan-drivers mesa-utils \
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav 2>&1 | grep -v "^Reading\|^Building\|^Get:" || true
    echo -ne "${C_NC}"
    completed_item "Codecs and drivers installed"

    # If Discord not installed from apt, fallback to Flatpak install (system)
    if ! command -v discord >/dev/null 2>&1 && ! flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        if install_discord_flatpak "debian"; then
            completed_item "Discord installed via Flatpak"
        else
            warning "Discord not found/installed. You can install via the official package or 
            flatpak: flatpak install --user flathub com.discordapp.Discord"
        fi
    fi
    
    # Step 5: Summary
    print_step 5 $total_steps "Verifying installation..."
    echo
    print_subsection "Installed Gaming Software"
    # Note: Don't run GUI apps (steam, lutris) as root - they show warning popups
    command -v steam >/dev/null && print_keyval "Steam" "installed"
    command -v lutris >/dev/null && print_keyval "Lutris" "installed"
    command -v gamemoded >/dev/null && print_keyval "GameMode" "installed"
    command -v mangohud >/dev/null && print_keyval "MangoHUD" "installed"
    command -v wine >/dev/null && print_keyval "Wine" "$(wine --version 2>/dev/null || echo 'installed')"
    # If 'discord' binary isn't present, check flatpak installation
    if ! command -v discord >/dev/null 2>&1; then
        if flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
            print_keyval "Discord" "installed (flatpak)"
        fi
    else
        print_keyval "Discord" "installed"
    fi
    echo
}

install_fedora_gaming_software() {
    print_section "Gaming Software Installation (Fedora)"
    
    local total_steps=5
    
    # Step 1: Enable RPM Fusion
    print_step 1 $total_steps "Enabling RPM Fusion repositories..."
    echo -ne "${C_DIM}"
    dnf install -q -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" 2>&1 | grep -v "^Last metadata" || true
    dnf install -q -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" 2>&1 | grep -v "^Last metadata" || true
    echo -ne "${C_NC}"
    completed_item "RPM Fusion enabled"
    
    # Step 2: Core gaming apps
    info "Installing large gaming packages (Steam, Lutris, Vulkan). This may take several minutes depending on your network and mirrors. Avoid interrupting the process." 
    print_step 2 $total_steps "Installing Steam, Lutris, GameMode..."
    echo -ne "${C_DIM}"
    dnf install -q -y steam lutris gamemode discord 2>&1 | grep -v "^Last metadata" || true
    echo -ne "${C_NC}"
    completed_item "Core gaming apps installed"
    
    # Step 3: MangoHUD and Wine
    print_step 3 $total_steps "Installing MangoHUD and Wine..."
    echo -ne "${C_DIM}"
    dnf install -q -y mangohud wine winetricks 2>&1 | grep -v "^Last metadata" || true
    echo -ne "${C_NC}"
    completed_item "MangoHUD and Wine installed"
    
    # Step 4: Media codecs
    print_step 4 $total_steps "Installing multimedia codecs..."
    echo -ne "${C_DIM}"
    dnf install -q -y \
        gstreamer1-plugins-base gstreamer1-plugins-good \
        gstreamer1-plugins-ugly gstreamer1-libav 2>&1 | grep -v "^Last metadata" || true
    echo -ne "${C_NC}"
    completed_item "Codecs installed"

    # If Discord not installed, fallback to Flatpak (system-wide)
    if ! command -v discord >/dev/null 2>&1 && ! flatpak list --system | grep -q "com.discordapp.Discord" 2>/dev/null; then
        if install_discord_flatpak "fedora"; then
            completed_item "Discord installed via Flatpak"
        else
            warning "Discord not found/installed. You can install it via Flatpak or download the RPM from Discord's website"
        fi
    fi
    
    # Step 5: Summary
    print_step 5 $total_steps "Verifying installation..."
    echo
    print_subsection "Installed Gaming Software"
    # Note: Don't run GUI apps (steam, lutris) as root - they show warning popups
    command -v steam >/dev/null && print_keyval "Steam" "installed"
    command -v lutris >/dev/null && print_keyval "Lutris" "installed"
    command -v gamemoded >/dev/null && print_keyval "GameMode" "installed"
    command -v mangohud >/dev/null && print_keyval "MangoHUD" "installed"
    command -v wine >/dev/null && print_keyval "Wine" "$(wine --version 2>/dev/null || echo 'installed')"
    echo
}

install_opensuse_gaming_software() {
    print_section "Gaming Software Installation (OpenSUSE)"
    
    local total_steps=4
    
    # Step 1: Add Packman repository
    print_step 1 $total_steps "Adding Packman repository..."
    echo -ne "${C_DIM}"
    zypper addrepo -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman 2>&1 | grep -v "^Loading\|^Retrieving" || true
    zypper refresh --quiet 2>&1 | grep -v "^Loading\|^Retrieving" || true
    echo -ne "${C_NC}"
    completed_item "Packman repository added"
    
    # Step 2: Core gaming apps
    info "Installing large gaming packages (Steam, Lutris, Vulkan). This may take several minutes depending on your network and mirrors. Avoid interrupting the process." 
    print_step 2 $total_steps "Installing Steam, Lutris, GameMode..."
    echo -ne "${C_DIM}"
    zypper install -y --quiet steam lutris gamemode discord 2>&1 | grep -v "^Loading\|^Retrieving" || true
    echo -ne "${C_NC}"
    completed_item "Core gaming apps installed"
    
    # Step 3: Wine
    print_step 3 $total_steps "Installing Wine..."
    echo -ne "${C_DIM}"
    zypper install -y --quiet wine 2>&1 | grep -v "^Loading\|^Retrieving" || true
    echo -ne "${C_NC}"
    completed_item "Wine installed"
    
    # Step 4: Summary
    print_step 4 $total_steps "Verifying installation..."
    echo
    print_subsection "Installed Gaming Software"
    # Note: Don't run GUI apps (steam, lutris) as root - they show warning popups
    command -v steam >/dev/null && print_keyval "Steam" "installed"
    command -v lutris >/dev/null && print_keyval "Lutris" "installed"
    command -v gamemoded >/dev/null && print_keyval "GameMode" "installed"
    command -v wine >/dev/null && print_keyval "Wine" "$(wine --version 2>/dev/null || echo 'installed')"
    echo
}

# --- Main Execution ---
main() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
    fi
    
    local distro="${1:-}"
    
    if [[ -z "$distro" ]]; then
        error "Distribution not specified. This script should be called by gz302-main.sh"
    fi
    
    clear
    print_box "GZ302 Gaming Software Setup" "$C_BOLD_CYAN"
    echo
    print_subsection "What Will Be Installed"
    print_keyval "Steam" "Gaming platform with Proton"
    print_keyval "Lutris" "Game manager for Windows games"
    print_keyval "GameMode" "CPU/GPU optimization"
    print_keyval "MangoHUD" "Performance overlay"
    print_keyval "Wine" "Windows compatibility layer"
    echo
    
    case "$distro" in
        "arch")
            install_arch_gaming_software
            ;;
        "ubuntu")
            install_debian_gaming_software
            ;;
        "fedora")
            install_fedora_gaming_software
            ;;
        "opensuse")
            install_opensuse_gaming_software
            ;;
        *)
            error "Unsupported distribution: $distro"
            ;;
    esac
    
    echo
    print_box "${SYMBOL_CHECK} Gaming Setup Complete" "$C_BOLD_GREEN"
    echo
    print_tip "Run games with: gamemoderun %command%"
    print_tip "Enable MangoHUD: mangohud %command%"
    print_tip "Use ProtonUp-Qt to manage Proton versions"
    echo
}

main "$@"
