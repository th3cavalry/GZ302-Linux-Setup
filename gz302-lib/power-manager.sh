#!/bin/bash
# shellcheck disable=SC2034,SC2059

# ==============================================================================
# GZ302 Power Manager Library
# Version: 4.0.0
#
# This library provides TDP management and power profile control for the
# AMD Ryzen AI MAX+ 395 (Strix Halo) in the GZ302.
#
# Library-First Design:
# - Detection functions (read-only, no system changes)
# - Configuration functions (idempotent, check before apply)
# - Verification functions (validate settings are correct)
# - Status functions (display current state)
#
# Dependencies:
# - ryzenadj (for direct TDP control)
# - powerprofilesctl (fallback, system power profiles)
# - cpupower (fallback, CPU governor)
#
# Usage:
#   source gz302-lib/power-manager.sh
#   power_detect_hardware
#   power_apply_profile "balanced"
#   power_print_status
# ==============================================================================

# --- Power Profile Definitions ---
# Format: "SPL:sPPT:fPPT" (all in milliwatts)
# SPL  = Sustained Power Limit (long-term steady power)
# sPPT = Slow Power Boost (short-term, ~2 minutes)
# fPPT = Fast Power Boost (very short-term, few seconds)

declare -gA POWER_PROFILES
POWER_PROFILES[emergency]="10000:12000:12000"      # 10W SPL, 12W boost
POWER_PROFILES[battery]="18000:20000:20000"        # 18W SPL, 20W boost
POWER_PROFILES[efficient]="30000:35000:35000"      # 30W SPL, 35W boost
POWER_PROFILES[balanced]="40000:45000:45000"       # 40W SPL, 45W boost
POWER_PROFILES[performance]="55000:60000:60000"    # 55W SPL, 60W boost
POWER_PROFILES[gaming]="70000:80000:80000"         # 70W SPL, 80W boost
POWER_PROFILES[maximum]="90000:90000:90000"        # 90W sustained

# Refresh rate targets for each profile (used by display-manager.sh)
declare -gA POWER_REFRESH_RATES
POWER_REFRESH_RATES[emergency]="30"
POWER_REFRESH_RATES[battery]="30"
POWER_REFRESH_RATES[efficient]="60"
POWER_REFRESH_RATES[balanced]="90"
POWER_REFRESH_RATES[performance]="120"
POWER_REFRESH_RATES[gaming]="180"
POWER_REFRESH_RATES[maximum]="180"

# Profile order for iteration
POWER_PROFILE_ORDER="emergency battery efficient balanced performance gaming maximum"

# Configuration paths
POWER_CONFIG_DIR="/etc/gz302/pwrcfg"
POWER_CURRENT_PROFILE_FILE="$POWER_CONFIG_DIR/current-profile"
POWER_AUTO_CONFIG_FILE="$POWER_CONFIG_DIR/auto-config"
POWER_AC_PROFILE_FILE="$POWER_CONFIG_DIR/ac-profile"
POWER_BATTERY_PROFILE_FILE="$POWER_CONFIG_DIR/battery-profile"

# --- Hardware Detection (Read-Only) ---

# Detect AMD Ryzen AI MAX+ 395 (Strix Halo) CPU
# Returns: 0 if found, 1 if not found
power_detect_hardware() {
    local cpu_model
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    
    if [[ "$cpu_model" == *"Ryzen AI"* ]] || [[ "$cpu_model" == *"Strix"* ]] || [[ "$cpu_model" == *"395"* ]]; then
        echo "$cpu_model"
        return 0
    else
        # Still return success for AMD Ryzen CPUs (compatible with ryzenadj)
        if [[ "$cpu_model" == *"Ryzen"* ]]; then
            echo "$cpu_model"
            return 0
        fi
        return 1
    fi
}

# Check if ryzenadj is available
# Returns: 0 if available, 1 if not
power_ryzenadj_available() {
    command -v ryzenadj >/dev/null 2>&1
}

# Check if powerprofilesctl is available
# Returns: 0 if available, 1 if not
power_ppd_available() {
    command -v powerprofilesctl >/dev/null 2>&1
}

# Check if cpupower is available
# Returns: 0 if available, 1 if not
power_cpupower_available() {
    command -v cpupower >/dev/null 2>&1
}

# --- Power Source Detection ---

# Get current power source (AC or Battery)
# Returns: "AC", "Battery", or "Unknown"
power_get_source() {
    # Method 1: Check common AC adapter names
    local adapter
    for adapter in ADP1 ADP0 ACAD AC0 AC; do
        if [[ -f "/sys/class/power_supply/$adapter/online" ]]; then
            if [[ "$(cat /sys/class/power_supply/$adapter/online 2>/dev/null)" == "1" ]]; then
                echo "AC"
                return 0
            else
                echo "Battery"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for Mains type
    if [[ -d /sys/class/power_supply ]]; then
        local ps
        for ps in /sys/class/power_supply/*; do
            if [[ -d "$ps" && -f "$ps/type" ]]; then
                local type
                type=$(cat "$ps/type" 2>/dev/null)
                if [[ "$type" == "Mains" || "$type" == "ADP" ]]; then
                    if [[ -f "$ps/online" ]]; then
                        if [[ "$(cat "$ps/online" 2>/dev/null)" == "1" ]]; then
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
        local ac_device
        ac_device=$(upower -e 2>/dev/null | grep -E 'ADP|ACA|AC' | head -1)
        if [[ -n "$ac_device" ]]; then
            if upower -i "$ac_device" 2>/dev/null | grep -qi "online.*yes"; then
                echo "AC"
                return 0
            else
                echo "Battery"
                return 0
            fi
        fi
    fi
    
    echo "Unknown"
}

# Get current battery percentage
# Returns: 0-100 or "N/A"
power_get_battery_percent() {
    # Method 1: Check common battery names
    local battery
    for battery in BAT0 BAT1 BATT; do
        if [[ -f "/sys/class/power_supply/$battery/capacity" ]]; then
            local capacity
            capacity=$(cat "/sys/class/power_supply/$battery/capacity" 2>/dev/null)
            if [[ -n "$capacity" && "$capacity" =~ ^[0-9]+$ && "$capacity" -ge 0 && "$capacity" -le 100 ]]; then
                echo "$capacity"
                return 0
            fi
        fi
    done
    
    # Method 2: Check all power supplies for Battery type
    if [[ -d /sys/class/power_supply ]]; then
        local ps
        for ps in /sys/class/power_supply/*; do
            if [[ -d "$ps" && -f "$ps/type" ]]; then
                local type
                type=$(cat "$ps/type" 2>/dev/null)
                if [[ "$type" == "Battery" && -f "$ps/capacity" ]]; then
                    local capacity
                    capacity=$(cat "$ps/capacity" 2>/dev/null)
                    if [[ -n "$capacity" && "$capacity" =~ ^[0-9]+$ ]]; then
                        echo "$capacity"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    echo "N/A"
}

# Get current battery charge limit
# Returns: 80, 100, or "N/A"
power_get_charge_limit() {
    local charge_limit_path="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    if [[ -f "$charge_limit_path" ]]; then
        cat "$charge_limit_path" 2>/dev/null
    else
        echo "N/A"
    fi
}

# Set battery charge limit (requires root)
# Args: $1 = limit (80 or 100)
# Returns: 0 on success, 1 on failure
power_set_charge_limit() {
    local limit="$1"
    local charge_limit_path="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    
    if [[ ! -f "$charge_limit_path" ]]; then
        echo "Error: Battery charge limit not supported on this system" >&2
        return 1
    fi
    
    if [[ "$limit" != "80" && "$limit" != "100" ]]; then
        echo "Error: Charge limit must be 80 or 100" >&2
        return 1
    fi
    
    if echo "$limit" > "$charge_limit_path" 2>/dev/null; then
        echo "Battery charge limit set to ${limit}%"
        return 0
    else
        echo "Error: Failed to set battery charge limit (need root?)" >&2
        return 1
    fi
}

# --- Profile State ---

# Get current power profile
# Returns: profile name or "unknown"
power_get_current_profile() {
    if [[ -f "$POWER_CURRENT_PROFILE_FILE" ]]; then
        cat "$POWER_CURRENT_PROFILE_FILE" 2>/dev/null | tr -d ' \n'
    else
        echo "unknown"
    fi
}

# Check if profile is valid
# Args: $1 = profile name
# Returns: 0 if valid, 1 if invalid
power_profile_valid() {
    local profile="$1"
    [[ -n "${POWER_PROFILES[$profile]:-}" ]]
}

# Get profile SPL/sPPT/fPPT values
# Args: $1 = profile name
# Returns: "SPL sPPT fPPT" in watts (not milliwatts)
power_get_profile_watts() {
    local profile="$1"
    local power_spec="${POWER_PROFILES[$profile]:-}"
    
    if [[ -z "$power_spec" ]]; then
        echo "0 0 0"
        return 1
    fi
    
    local spl sppt fppt
    spl=$(($(echo "$power_spec" | cut -d: -f1) / 1000))
    sppt=$(($(echo "$power_spec" | cut -d: -f2) / 1000))
    fppt=$(($(echo "$power_spec" | cut -d: -f3) / 1000))
    
    echo "$spl $sppt $fppt"
}

# --- Profile Application ---

# Apply a power profile using ryzenadj
# Args: $1 = profile name
# Returns: 0 on success, 1 on failure
power_apply_ryzenadj() {
    local profile="$1"
    local power_spec="${POWER_PROFILES[$profile]:-}"
    
    if [[ -z "$power_spec" ]]; then
        return 1
    fi
    
    local spl sppt fppt
    spl=$(echo "$power_spec" | cut -d: -f1)
    sppt=$(echo "$power_spec" | cut -d: -f2)
    fppt=$(echo "$power_spec" | cut -d: -f3)
    
    if ryzenadj --stapm-limit="$spl" --slow-limit="$sppt" --fast-limit="$fppt" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Apply a power profile using powerprofilesctl
# Args: $1 = profile name
# Returns: 0 on success, 1 on failure
power_apply_ppd() {
    local profile="$1"
    local ppd_profile
    
    case "$profile" in
        maximum|gaming|performance)
            ppd_profile="performance"
            ;;
        balanced|efficient)
            ppd_profile="balanced"
            ;;
        battery|emergency)
            ppd_profile="power-saver"
            ;;
        *)
            return 1
            ;;
    esac
    
    if powerprofilesctl set "$ppd_profile" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Apply a power profile using cpupower
# Args: $1 = profile name
# Returns: 0 on success, 1 on failure
power_apply_cpupower() {
    local profile="$1"
    local governor
    
    case "$profile" in
        maximum|gaming|performance)
            governor="performance"
            ;;
        battery|emergency)
            governor="powersave"
            ;;
        *)
            governor="schedutil"
            ;;
    esac
    
    if cpupower frequency-set -g "$governor" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Apply a power profile (tries all methods)
# Args: $1 = profile name
# Returns: 0 on success, 1 on failure
power_apply_profile() {
    local profile="$1"
    
    if ! power_profile_valid "$profile"; then
        echo "Error: Unknown profile '$profile'" >&2
        return 1
    fi
    
    local success=false
    local method=""
    
    # Try ryzenadj first (most precise)
    if power_ryzenadj_available; then
        if power_apply_ryzenadj "$profile"; then
            success=true
            method="ryzenadj"
            
            # Also sync with PPD if available
            if power_ppd_available; then
                power_apply_ppd "$profile" && method="$method+ppd"
            fi
        fi
    fi
    
    # Fallback to powerprofilesctl
    if [[ "$success" == false ]] && power_ppd_available; then
        if power_apply_ppd "$profile"; then
            success=true
            method="ppd"
        fi
    fi
    
    # Fallback to cpupower
    if [[ "$success" == false ]] && power_cpupower_available; then
        if power_apply_cpupower "$profile"; then
            success=true
            method="cpupower"
        fi
    fi
    
    if [[ "$success" == true ]]; then
        # Save current profile
        mkdir -p "$POWER_CONFIG_DIR"
        echo "$profile" > "$POWER_CURRENT_PROFILE_FILE"
        echo "$(date +%s)" > "$POWER_CONFIG_DIR/last-change"
        echo "$(power_get_source)" > "$POWER_CONFIG_DIR/last-power-source"
        
        echo "Power profile '$profile' applied ($method)"
        return 0
    else
        echo "Error: Failed to apply power profile using any method" >&2
        return 1
    fi
}

# --- Verification ---

# Verify current TDP settings match the active profile
# Returns: 0 if match, 1 if mismatch or can't verify
power_verify_settings() {
    if ! power_ryzenadj_available; then
        return 1  # Can't verify without ryzenadj
    fi
    
    local current_profile
    current_profile=$(power_get_current_profile)
    
    if ! power_profile_valid "$current_profile"; then
        return 1
    fi
    
    local power_spec="${POWER_PROFILES[$current_profile]}"
    local expected_spl=$(($(echo "$power_spec" | cut -d: -f1)))
    local expected_sppt=$(($(echo "$power_spec" | cut -d: -f2)))
    local expected_fppt=$(($(echo "$power_spec" | cut -d: -f3)))
    
    # Get current values from ryzenadj
    local ryzenadj_info
    if ! ryzenadj_info=$(ryzenadj -i 2>/dev/null); then
        return 1
    fi
    
    local current_spl current_sppt current_fppt
    current_spl=$(echo "$ryzenadj_info" | grep -i "STAPM LIMIT" | grep -o "[0-9]\+" | head -1)
    current_sppt=$(echo "$ryzenadj_info" | grep -i "PPT LIMIT SLOW" | grep -o "[0-9]\+" | head -1)
    current_fppt=$(echo "$ryzenadj_info" | grep -i "PPT LIMIT FAST" | grep -o "[0-9]\+" | head -1)
    
    if [[ -z "$current_spl" || -z "$current_sppt" || -z "$current_fppt" ]]; then
        return 1
    fi
    
    # Allow small tolerance (±500mW)
    local tolerance=500
    local diff
    
    diff=$((current_spl - expected_spl))
    [[ $diff -lt 0 ]] && diff=$((-diff))
    [[ $diff -gt $tolerance ]] && return 1
    
    diff=$((current_sppt - expected_sppt))
    [[ $diff -lt 0 ]] && diff=$((-diff))
    [[ $diff -gt $tolerance ]] && return 1
    
    diff=$((current_fppt - expected_fppt))
    [[ $diff -lt 0 ]] && diff=$((-diff))
    [[ $diff -gt $tolerance ]] && return 1
    
    return 0
}

# --- Auto-Switching ---

# Check if auto-switching is enabled
# Returns: 0 if enabled, 1 if disabled
power_auto_enabled() {
    [[ -f "$POWER_AUTO_CONFIG_FILE" ]] && [[ "$(cat "$POWER_AUTO_CONFIG_FILE" 2>/dev/null)" == "true" ]]
}

# Get the AC profile for auto-switching
# Returns: profile name
power_get_ac_profile() {
    if [[ -f "$POWER_AC_PROFILE_FILE" ]]; then
        cat "$POWER_AC_PROFILE_FILE" 2>/dev/null
    else
        echo "gaming"
    fi
}

# Get the battery profile for auto-switching
# Returns: profile name
power_get_battery_profile() {
    if [[ -f "$POWER_BATTERY_PROFILE_FILE" ]]; then
        cat "$POWER_BATTERY_PROFILE_FILE" 2>/dev/null
    else
        echo "battery"
    fi
}

# Configure auto-switching (non-interactive for library)
# Args: $1 = enabled (true/false), $2 = ac_profile, $3 = battery_profile
power_configure_auto() {
    local enabled="${1:-true}"
    local ac_profile="${2:-gaming}"
    local battery_profile="${3:-battery}"
    
    mkdir -p "$POWER_CONFIG_DIR"
    echo "$enabled" > "$POWER_AUTO_CONFIG_FILE"
    echo "$ac_profile" > "$POWER_AC_PROFILE_FILE"
    echo "$battery_profile" > "$POWER_BATTERY_PROFILE_FILE"
}

# Perform auto-switch if power source changed
# Returns: 0 if switched or no switch needed, 1 on error
power_auto_switch() {
    if ! power_auto_enabled; then
        return 0
    fi
    
    local current_source
    current_source=$(power_get_source)
    
    local last_source=""
    if [[ -f "$POWER_CONFIG_DIR/last-power-source" ]]; then
        last_source=$(cat "$POWER_CONFIG_DIR/last-power-source" 2>/dev/null)
    fi
    
    if [[ "$current_source" != "$last_source" ]]; then
        case "$current_source" in
            "AC")
                local ac_profile
                ac_profile=$(power_get_ac_profile)
                if power_profile_valid "$ac_profile"; then
                    echo "Power source changed to AC, switching to: $ac_profile"
                    power_apply_profile "$ac_profile"
                fi
                ;;
            "Battery")
                local battery_profile
                battery_profile=$(power_get_battery_profile)
                if power_profile_valid "$battery_profile"; then
                    echo "Power source changed to Battery, switching to: $battery_profile"
                    power_apply_profile "$battery_profile"
                fi
                ;;
        esac
    fi
    
    return 0
}

# --- Status Display ---

# Print formatted power status
power_print_status() {
    local power_source
    power_source=$(power_get_source)
    
    local battery_pct
    battery_pct=$(power_get_battery_percent)
    
    local charge_limit
    charge_limit=$(power_get_charge_limit)
    
    local current_profile
    current_profile=$(power_get_current_profile)
    
    echo "Power Status:"
    echo "  Power Source: $power_source"
    echo "  Battery: ${battery_pct}%"
    echo "  Charge Limit: ${charge_limit}%"
    echo "  Current Profile: $current_profile"
    
    if power_profile_valid "$current_profile"; then
        read -r spl sppt fppt < <(power_get_profile_watts "$current_profile")
        local refresh="${POWER_REFRESH_RATES[$current_profile]:-}"
        echo "  SPL:  ${spl}W (Sustained)"
        echo "  sPPT: ${sppt}W (Slow Boost)"
        echo "  fPPT: ${fppt}W (Fast Boost)"
        [[ -n "$refresh" ]] && echo "  Target Refresh: ${refresh}Hz"
    fi
    
    # Tool availability
    echo ""
    echo "Available Tools:"
    power_ryzenadj_available && echo "  ✓ ryzenadj" || echo "  ✗ ryzenadj (not installed)"
    power_ppd_available && echo "  ✓ powerprofilesctl" || echo "  ✗ powerprofilesctl"
    power_cpupower_available && echo "  ✓ cpupower" || echo "  ✗ cpupower"
    
    # Verification
    if power_ryzenadj_available; then
        if power_verify_settings 2>/dev/null; then
            echo "  ✓ TDP settings verified"
        else
            echo "  ⚠ TDP settings may not match profile"
        fi
    fi
}

# List all profiles with details
power_list_profiles() {
    echo "Available Power Profiles (SPL/sPPT/fPPT @ Refresh):"
    local profile
    for profile in $POWER_PROFILE_ORDER; do
        if power_profile_valid "$profile"; then
            read -r spl sppt fppt < <(power_get_profile_watts "$profile")
            local refresh="${POWER_REFRESH_RATES[$profile]:-}"
            printf "  %-12s %2d/%2d/%2dW @ %3dHz\n" "${profile}:" "$spl" "$sppt" "$fppt" "$refresh"
        fi
    done
}

# --- Installation Support ---

# Check if pwrcfg command is installed
# Returns: 0 if installed, 1 if not
power_command_installed() {
    [[ -x /usr/local/bin/pwrcfg ]]
}

# Get the pwrcfg script content for installation
# This is meant to be called by the installer
power_get_pwrcfg_script() {
    cat <<'PWRCFG_SCRIPT'
#!/bin/bash
# GZ302 Power Configuration Script (pwrcfg)
# This is a thin wrapper that loads the power-manager library
# and provides a CLI interface.

set -euo pipefail

# Determine if command requires elevation
requires_elevation() {
    case "${1:-}" in
        status|list|help|"") return 1 ;;
        charge-limit)
            [[ -z "${2:-}" ]] && return 1
            return 0
            ;;
        *) return 0 ;;
    esac
}

# Auto-elevate for write operations
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if requires_elevation "${1:-}" "${2:-}"; then
        if sudo -n true 2>/dev/null; then
            exec sudo -n "$0" "$@"
        fi
        echo "pwrcfg requires elevated privileges." >&2
        exit 1
    fi
fi

# Load power-manager library
LIB_PATH="/usr/local/share/gz302/gz302-lib"
if [[ -f "$LIB_PATH/power-manager.sh" ]]; then
    source "$LIB_PATH/power-manager.sh"
else
    echo "Error: power-manager.sh not found at $LIB_PATH" >&2
    exit 1
fi

# CLI handling
case "${1:-}" in
    emergency|battery|efficient|balanced|performance|gaming|maximum)
        power_apply_profile "$1"
        ;;
    status)
        power_print_status
        ;;
    list)
        power_list_profiles
        ;;
    auto)
        power_auto_switch
        ;;
    verify)
        if power_verify_settings; then
            echo "✓ Power limits match current profile"
        else
            echo "✗ Power limits do not match profile or cannot be verified"
            exit 1
        fi
        ;;
    charge-limit)
        if [[ -z "${2:-}" ]]; then
            echo "Current battery charge limit: $(power_get_charge_limit)%"
        else
            power_set_charge_limit "$2"
        fi
        ;;
    help|--help|-h|"")
        echo "Usage: pwrcfg [PROFILE|COMMAND]"
        echo ""
        power_list_profiles
        echo ""
        echo "Commands:"
        echo "  status              - Show current power status"
        echo "  list                - List available profiles"
        echo "  auto                - Trigger auto-switch based on power source"
        echo "  verify              - Verify TDP settings match profile"
        echo "  charge-limit [80|100] - Get/set battery charge limit"
        echo "  help                - Show this help"
        ;;
    *)
        echo "Error: Unknown command '$1'" >&2
        echo "Use 'pwrcfg help' for usage" >&2
        exit 1
        ;;
esac
PWRCFG_SCRIPT
}

# Ensure configuration directory exists
# Called during installation
power_init_config() {
    mkdir -p "$POWER_CONFIG_DIR"
    
    # Set default auto-switch configuration if not present
    if [[ ! -f "$POWER_AUTO_CONFIG_FILE" ]]; then
        echo "false" > "$POWER_AUTO_CONFIG_FILE"
    fi
    if [[ ! -f "$POWER_AC_PROFILE_FILE" ]]; then
        echo "gaming" > "$POWER_AC_PROFILE_FILE"
    fi
    if [[ ! -f "$POWER_BATTERY_PROFILE_FILE" ]]; then
        echo "battery" > "$POWER_BATTERY_PROFILE_FILE"
    fi
}

# --- ryzenadj Installation ---

# Install ryzenadj on Arch-based distros
# Returns: 0 on success, 1 on failure
power_install_ryzenadj_arch() {
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "ryzenadj already installed"
        return 0
    fi
    
    # Try pacman first (some repos have it)
    if pacman -Qi ryzenadj >/dev/null 2>&1; then
        echo "ryzenadj already installed via pacman"
        return 0
    fi
    
    # Install via yay/paru (AUR)
    if command -v yay >/dev/null 2>&1; then
        echo "Installing ryzenadj from AUR via yay..."
        sudo -u "${SUDO_USER:-$USER}" yay -S --noconfirm ryzenadj 2>/dev/null && return 0
    elif command -v paru >/dev/null 2>&1; then
        echo "Installing ryzenadj from AUR via paru..."
        sudo -u "${SUDO_USER:-$USER}" paru -S --noconfirm ryzenadj 2>/dev/null && return 0
    fi
    
    # Build from source as fallback
    echo "Building ryzenadj from source..."
    power_install_ryzenadj_source
}

# Install ryzenadj on Debian/Ubuntu-based distros
# Returns: 0 on success, 1 on failure
power_install_ryzenadj_debian() {
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "ryzenadj already installed"
        return 0
    fi
    
    echo "Building ryzenadj from source for Debian/Ubuntu..."
    
    # Install build dependencies
    apt-get update -qq
    apt-get install -y -qq git build-essential cmake libpci-dev >/dev/null 2>&1
    
    power_install_ryzenadj_source
}

# Install ryzenadj on Fedora
# Returns: 0 on success, 1 on failure
power_install_ryzenadj_fedora() {
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "ryzenadj already installed"
        return 0
    fi
    
    echo "Building ryzenadj from source for Fedora..."
    
    # Install build dependencies
    dnf install -y -q git cmake gcc pciutils-devel >/dev/null 2>&1
    
    power_install_ryzenadj_source
}

# Install ryzenadj on openSUSE
# Returns: 0 on success, 1 on failure
power_install_ryzenadj_opensuse() {
    if command -v ryzenadj >/dev/null 2>&1; then
        echo "ryzenadj already installed"
        return 0
    fi
    
    echo "Building ryzenadj from source for openSUSE..."
    
    # Install build dependencies
    zypper install -y git cmake gcc pciutils-devel >/dev/null 2>&1
    
    power_install_ryzenadj_source
}

# Build ryzenadj from source (used by distro-specific installers)
# Returns: 0 on success, 1 on failure
power_install_ryzenadj_source() {
    local build_dir="/tmp/ryzenadj-build-$$"
    
    mkdir -p "$build_dir"
    cd "$build_dir" || return 1
    
    # Clone ryzenadj
    if ! git clone https://github.com/FlyGoat/RyzenAdj.git 2>/dev/null; then
        echo "Failed to clone ryzenadj repository" >&2
        rm -rf "$build_dir"
        return 1
    fi
    
    cd RyzenAdj || return 1
    
    # Build
    mkdir build && cd build || return 1
    if cmake .. >/dev/null 2>&1 && make -j"$(nproc)" >/dev/null 2>&1; then
        # Install
        cp ryzenadj /usr/local/bin/
        chmod +x /usr/local/bin/ryzenadj
        
        # Install library
        if [[ -f libryzenadj.so ]]; then
            cp libryzenadj.so /usr/local/lib/
            ldconfig 2>/dev/null || true
        fi
        
        echo "ryzenadj installed successfully"
        rm -rf "$build_dir"
        return 0
    else
        echo "Failed to build ryzenadj" >&2
        rm -rf "$build_dir"
        return 1
    fi
}

# Install ryzenadj (auto-detect distro)
# Args: $1 = distro (arch|debian|fedora|opensuse) - optional
# Returns: 0 on success, 1 on failure
power_install_ryzenadj() {
    local distro="${1:-}"
    
    # Auto-detect distro if not specified
    if [[ -z "$distro" ]]; then
        if [[ -f /etc/os-release ]]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            case "${ID:-}" in
                arch|cachyos|endeavouros|manjaro)
                    distro="arch"
                    ;;
                ubuntu|pop|linuxmint|debian)
                    distro="debian"
                    ;;
                fedora|nobara)
                    distro="fedora"
                    ;;
                opensuse*)
                    distro="opensuse"
                    ;;
                *)
                    echo "Unknown distro, attempting source build" >&2
                    distro="source"
                    ;;
            esac
        fi
    fi
    
    case "$distro" in
        arch)    power_install_ryzenadj_arch ;;
        debian)  power_install_ryzenadj_debian ;;
        fedora)  power_install_ryzenadj_fedora ;;
        opensuse) power_install_ryzenadj_opensuse ;;
        *)       power_install_ryzenadj_source ;;
    esac
}
