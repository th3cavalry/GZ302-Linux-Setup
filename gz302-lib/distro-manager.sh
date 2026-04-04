#!/bin/bash
# shellcheck disable=SC2034,SC2059

# ==============================================================================
# GZ302 Distribution Manager Library
# Version: 5.0.0
#
# This library provides distribution-specific setup orchestration for the GZ302.
# It coordinates hardware fixes across all subsystem libraries and manages
# per-distro package installation and configuration.
#
# Library-First Design:
# - Orchestrator functions (coordinate subsystem libraries)
# - Per-distro setup functions (package installation, system config)
# - Distribution-specific optimization information
#
# Supported Distributions:
# - Arch Linux (including CachyOS, EndeavourOS, Manjaro)
# - Debian / Ubuntu
# - Fedora
# - OpenSUSE
# ==============================================================================

# --- Hardware Fixes (Orchestrator) ---
distro_apply_hardware_fixes() {
    info "Applying GZ302 hardware fixes using modular libraries..."
    
    # Use kernel-compat if available, otherwise manual check
    local kver
    if declare -f kernel_get_version_num >/dev/null; then
        kver=$(kernel_get_version_num)
    else
        kver=0
    fi
    
    # 1. WiFi Configuration
    info "Configuring WiFi (MediaTek MT7925)..."
    if declare -f wifi_detect_hardware >/dev/null && wifi_detect_hardware >/dev/null 2>&1; then
        wifi_apply_configuration || warning "WiFi configuration reported issues"
    else
        info "WiFi hardware not detected or library not loaded, skipping."
    fi

    # 2. GPU Configuration
    info "Configuring GPU (AMD Radeon 8060S)..."
    if declare -f gpu_detect_hardware >/dev/null && gpu_detect_hardware >/dev/null 2>&1; then
        gpu_apply_configuration || warning "GPU configuration reported issues"
    else
        info "GPU hardware not detected or library not loaded, skipping."
    fi

    # 3. Input Configuration
    info "Configuring Input Devices..."
    if declare -f input_detect_hid_devices >/dev/null && input_detect_hid_devices >/dev/null 2>&1; then
        input_apply_configuration "$kver" || warning "Input configuration reported issues"
    else
         info "Input devices not detected or library not loaded, skipping."
    fi

    # 4. RGB Configuration
    info "Configuring RGB Devices..."
    if declare -f rgb_install_udev_rules >/dev/null; then
        if rgb_install_udev_rules; then
            success "RGB udev rules installed"
        else
            warning "Failed to install RGB udev rules"
        fi
    fi

    # 5. Early KMS (Arch-based)
    if declare -f gpu_configure_early_kms >/dev/null; then
        gpu_configure_early_kms
    fi

    # 6. Keyboard Backlight Restore
    if declare -f rgb_configure_backlight_restore >/dev/null; then
        rgb_configure_backlight_restore
    fi

    # 7. Battery Limit (Optional/Fallback)
    if declare -f power_setup_battery_limit_service >/dev/null; then
        power_setup_battery_limit_service
    fi

    success "Hardware fixes applied via libraries"
}

distro_setup_arch() {
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
    print_step 2 7 "Installing AUR helper (yay or paru)..."
    if ! is_step_completed "aur_helper"; then
        if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
            info "Installing yay AUR helper..."
            local temp_dir
            temp_dir=$(mktemp -d)
            sudo -u "$(get_real_user)" git clone https://aur.archlinux.org/yay-bin.git "$temp_dir"
            (cd "$temp_dir" && sudo -u "$(get_real_user)" makepkg -si --noconfirm)
            rm -rf "$temp_dir"
        fi
        complete_step "aur_helper"
    fi
    completed_item "AUR helper installed"

    # Step 3: Install hardware fixes
    print_step 3 7 "Applying GZ302 hardware fixes..."
    if ! is_step_completed "hw_fixes"; then
        distro_apply_hardware_fixes
        complete_step "hw_fixes"
    fi
    completed_item "Hardware fixes applied"

    # Provide distribution-specific optimization information
    distro_provide_optimization_info "$distro"

    # Step 4: Install SOF firmware
    print_step 4 7 "Installing Sound Open Firmware (SOF)..."
    if ! is_step_completed "sof_firmware"; then
        audio_install_sof_firmware "$distro"
        complete_step "sof_firmware"
    fi
    completed_item "SOF firmware installed"

    # Step 5: Configure Power Management
    print_step 5 7 "Configuring power management..."
    if ! is_step_completed "power_mgmt"; then
        if power_install_tools; then
            success "Power management tools installed"
        else
            warning "Power management tools reported issues"
        fi
        complete_step "power_mgmt"
    fi
    completed_item "Power management configured"

    # Step 6: Configure Display
    print_step 6 7 "Configuring display settings..."
    if ! is_step_completed "display_config"; then
        if display_install_tools; then
            success "Display tools installed"
        else
            warning "Display tools reported issues"
        fi
        complete_step "display_config"
    fi
    completed_item "Display configured"

    # Step 7: Finalize
    print_step 7 7 "Finalizing Arch-based setup..."
    completed_item "Setup completed for $distro"
}

distro_setup_debian() {
    local distro="$1"
    print_subsection "Debian/Ubuntu-based System Setup"

    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "debian_update"; then
        apt-get update
        apt-get install -y git build-essential wget curl
        complete_step "debian_update"
    fi
    completed_item "System updated"

    # Step 2: Install hardware fixes
    print_step 2 7 "Applying GZ302 hardware fixes..."
    if ! is_step_completed "hw_fixes"; then
        distro_apply_hardware_fixes
        complete_step "hw_fixes"
    fi
    completed_item "Hardware fixes applied"

    # Provide distribution-specific optimization information
    distro_provide_optimization_info "$distro"

    # Step 3: Install SOF firmware
    print_step 3 7 "Installing Sound Open Firmware (SOF)..."
    if ! is_step_completed "sof_firmware"; then
        audio_install_sof_firmware "$distro"
        complete_step "sof_firmware"
    fi
    completed_item "SOF firmware installed"

    # Step 4: Configure Power Management
    print_step 4 7 "Configuring power management..."
    if ! is_step_completed "power_mgmt"; then
        power_install_tools
        complete_step "power_mgmt"
    fi
    completed_item "Power management configured"

    # Step 5: Configure Display
    print_step 5 7 "Configuring display settings..."
    if ! is_step_completed "display_config"; then
        display_install_tools
        complete_step "display_config"
    fi
    completed_item "Display configured"

    # Step 6: Finalize
    print_step 6 7 "Finalizing Debian-based setup..."
    completed_item "Setup completed for $distro"
}

distro_setup_fedora() {
    local distro="$1"
    print_subsection "Fedora-based System Setup"

    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "fedora_update"; then
        dnf update -y
        dnf install -y git wget curl gcc make
        complete_step "fedora_update"
    fi
    completed_item "System updated"

    # Step 2: Install hardware fixes
    print_step 2 7 "Applying GZ302 hardware fixes..."
    if ! is_step_completed "hw_fixes"; then
        distro_apply_hardware_fixes
        complete_step "hw_fixes"
    fi
    completed_item "Hardware fixes applied"

    # Provide distribution-specific optimization information
    distro_provide_optimization_info "$distro"

    # Step 3: Install SOF firmware
    print_step 3 7 "Installing Sound Open Firmware (SOF)..."
    if ! is_step_completed "sof_firmware"; then
        audio_install_sof_firmware "$distro"
        complete_step "sof_firmware"
    fi
    completed_item "SOF firmware installed"

    # Step 4: Configure Power Management
    print_step 4 7 "Configuring power management..."
    if ! is_step_completed "power_mgmt"; then
        power_install_tools
        complete_step "power_mgmt"
    fi
    completed_item "Power management configured"

    # Step 5: Configure Display
    print_step 5 7 "Configuring display settings..."
    if ! is_step_completed "display_config"; then
        display_install_tools
        complete_step "display_config"
    fi
    completed_item "Display configured"

    # Step 6: Finalize
    print_step 6 7 "Finalizing Fedora-based setup..."
    completed_item "Setup completed for $distro"
}

distro_setup_opensuse() {
    local distro="$1"
    print_subsection "OpenSUSE-based System Setup"

    # Step 1: Update system
    print_step 1 7 "Updating system and installing base dependencies..."
    if ! is_step_completed "suse_update"; then
        zypper refresh
        zypper update -y
        zypper install -y git wget curl gcc make
        complete_step "suse_update"
    fi
    completed_item "System updated"

    # Step 2: Install hardware fixes
    print_step 2 7 "Applying GZ302 hardware fixes..."
    if ! is_step_completed "hw_fixes"; then
        distro_apply_hardware_fixes
        complete_step "hw_fixes"
    fi
    completed_item "Hardware fixes applied"

    # Provide distribution-specific optimization information
    distro_provide_optimization_info "$distro"

    # Step 3: Install SOF firmware
    print_step 3 7 "Installing Sound Open Firmware (SOF)..."
    if ! is_step_completed "sof_firmware"; then
        audio_install_sof_firmware "$distro"
        complete_step "sof_firmware"
    fi
    completed_item "SOF firmware installed"

    # Step 4: Configure Power Management
    print_step 4 7 "Configuring power management..."
    if ! is_step_completed "power_mgmt"; then
        power_install_tools
        complete_step "power_mgmt"
    fi
    completed_item "Power management configured"

    # Step 5: Configure Display
    print_step 5 7 "Configuring display settings..."
    if ! is_step_completed "display_config"; then
        display_install_tools
        complete_step "display_config"
    fi
    completed_item "Display configured"

    # Step 6: Finalize
    print_step 6 7 "Finalizing OpenSUSE setup..."
    completed_item "Setup completed for $distro"
}

# --- Distribution-Specific Optimizations Info ---
# Provides information about distribution-specific optimizations for Strix Halo
distro_provide_optimization_info() {
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

# --- Library Info ---
distro_lib_version() {
    echo "5.0.0"
}

distro_lib_help() {
    echo "GZ302 Distribution Manager Library"
    echo ""
    echo "Functions:"
    echo "  distro_apply_hardware_fixes     - Orchestrate all hardware fix libraries"
    echo "  distro_setup_arch               - Full Arch-based setup"
    echo "  distro_setup_debian             - Full Debian/Ubuntu-based setup"
    echo "  distro_setup_fedora             - Full Fedora-based setup"
    echo "  distro_setup_opensuse           - Full OpenSUSE-based setup"
    echo "  distro_provide_optimization_info - Show distro-specific tuning tips"
    echo "  distro_lib_version              - Show library version"
    echo "  distro_lib_help                 - Show this help"
}
