#!/bin/bash

#############################################################################
# GZ302EA Power & Display Manager
# Version: 1.0.0
#
# Manages CPU/GPU power profiles and display refresh rates based on power 
# source (AC/battery) or manual user control.
#
# Features:
# - Automatic switching between AC and battery power profiles
# - Manual profile switching (performance/balanced/powersave)
# - Display refresh rate switching (high/low)
# - CPU governor control
# - GPU power level management
# - ASUS profile integration (asusctl)
#
# Usage:
#   sudo ./gz302-power-manager.sh [MODE] [OPTIONS]
#
# Modes:
#   auto            Enable automatic power profile switching via udev
#   performance     Set performance profile
#   balanced        Set balanced profile  
#   powersave       Set power saving profile
#   status          Show current power status
#   refresh-high    Set high refresh rate (120Hz)
#   refresh-low     Set low refresh rate (60Hz)
#   install         Install udev rules for automatic switching
#   uninstall       Remove udev rules
#
#############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

#############################################################################
# Helper Functions
#############################################################################

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  GZ302EA Power & Display Manager v${VERSION}${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

#############################################################################
# Power Status Detection
#############################################################################

detect_power_source() {
    # Check if on AC power or battery
    local power_supply="/sys/class/power_supply"
    
    # Look for AC adapter
    for adapter in "$power_supply"/AC*/online "$power_supply"/ADP*/online; do
        if [ -f "$adapter" ]; then
            local status=$(cat "$adapter")
            if [ "$status" = "1" ]; then
                echo "AC"
                return
            fi
        fi
    done
    
    echo "BATTERY"
}

get_battery_percentage() {
    local power_supply="/sys/class/power_supply"
    
    for battery in "$power_supply"/BAT*/capacity; do
        if [ -f "$battery" ]; then
            cat "$battery"
            return
        fi
    done
    
    echo "Unknown"
}

#############################################################################
# CPU Power Management
#############################################################################

set_cpu_governor() {
    local governor=$1
    print_info "Setting CPU governor to: $governor"
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "$governor" > "$cpu" 2>/dev/null || true
        fi
    done
    
    # Verify
    local current=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    print_success "CPU governor set to: $current"
}

set_cpu_boost() {
    local boost=$1  # 0 or 1
    print_info "Setting CPU boost to: $boost"
    
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        echo "$boost" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
    fi
    
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        # Intel (inverse logic: no_turbo=0 means boost enabled)
        local no_turbo=$((1 - boost))
        echo "$no_turbo" > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
    fi
}

#############################################################################
# GPU Power Management
#############################################################################

set_gpu_power_level() {
    local level=$1  # auto, low, high, performance
    print_info "Setting GPU power level to: $level"
    
    # AMD GPU power management
    for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        if [ -f "$card" ]; then
            echo "$level" > "$card" 2>/dev/null || true
        fi
    done
    
    # Verify
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        local current=$(cat /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || echo "unknown")
        print_success "GPU power level set to: $current"
    fi
}

set_gpu_power_state() {
    local state=$1  # battery, balanced, performance
    print_info "Setting GPU power state to: $state"
    
    for card in /sys/class/drm/card*/device/power_dpm_state; do
        if [ -f "$card" ]; then
            echo "$state" > "$card" 2>/dev/null || true
        fi
    done
}

#############################################################################
# ASUS Profile Management
#############################################################################

set_asus_profile() {
    local profile=$1  # Performance, Balanced, Quiet
    
    if command -v asusctl &> /dev/null; then
        print_info "Setting ASUS profile to: $profile"
        asusctl profile -P "$profile" 2>/dev/null || true
        print_success "ASUS profile set to: $profile"
    else
        print_warning "asusctl not installed, skipping ASUS profile"
    fi
}

#############################################################################
# Display Refresh Rate Management
#############################################################################

set_refresh_rate() {
    local rate=$1  # Target refresh rate (e.g., 60, 120)
    print_info "Setting display refresh rate to: ${rate}Hz"
    
    # Detect if running X11 or Wayland
    if [ -n "$WAYLAND_DISPLAY" ]; then
        set_refresh_wayland "$rate"
    elif [ -n "$DISPLAY" ]; then
        set_refresh_x11 "$rate"
    else
        print_warning "No display server detected, skipping refresh rate change"
    fi
}

set_refresh_x11() {
    local rate=$1
    
    if command -v xrandr &> /dev/null; then
        # Get the primary display
        local display=$(xrandr | grep " connected" | grep "primary" | awk '{print $1}')
        
        # If no primary, get the first connected display
        if [ -z "$display" ]; then
            display=$(xrandr | grep " connected" | head -n1 | awk '{print $1}')
        fi
        
        if [ -n "$display" ]; then
            xrandr --output "$display" --rate "$rate" 2>/dev/null || print_warning "Failed to set refresh rate via xrandr"
            print_success "Refresh rate set to ${rate}Hz on $display (X11)"
        else
            print_warning "No display found via xrandr"
        fi
    else
        print_warning "xrandr not found, cannot set refresh rate on X11"
    fi
}

set_refresh_wayland() {
    local rate=$1
    
    if command -v wlr-randr &> /dev/null; then
        # Get the first output
        local output=$(wlr-randr | grep "^[^ ]" | head -n1 | awk '{print $1}')
        
        if [ -n "$output" ]; then
            # Get current mode and resolution
            local mode=$(wlr-randr | grep "current" | head -n1 | awk '{print $1}')
            
            if [ -n "$mode" ]; then
                # Extract resolution (e.g., 1920x1080)
                local resolution
                resolution=$(echo "$mode" | sed 's/@.*//')
                wlr-randr --output "$output" --mode "${resolution}@${rate}Hz" 2>/dev/null || print_warning "Failed to set refresh rate via wlr-randr"
                print_success "Refresh rate set to ${rate}Hz on $output (Wayland)"
            fi
        else
            print_warning "No display found via wlr-randr"
        fi
    else
        print_warning "wlr-randr not found, cannot set refresh rate on Wayland"
    fi
}

#############################################################################
# Power Profiles
#############################################################################

apply_performance_profile() {
    print_info "Applying PERFORMANCE profile..."
    echo ""
    
    set_cpu_governor "performance"
    set_cpu_boost 1
    set_gpu_power_level "high"
    set_gpu_power_state "performance"
    set_asus_profile "Performance"
    
    echo ""
    print_success "Performance profile applied"
}

apply_balanced_profile() {
    print_info "Applying BALANCED profile..."
    echo ""
    
    set_cpu_governor "schedutil"
    set_cpu_boost 1
    set_gpu_power_level "auto"
    set_gpu_power_state "balanced"
    set_asus_profile "Balanced"
    
    echo ""
    print_success "Balanced profile applied"
}

apply_powersave_profile() {
    print_info "Applying POWERSAVE profile..."
    echo ""
    
    set_cpu_governor "powersave"
    set_cpu_boost 0
    set_gpu_power_level "low"
    set_gpu_power_state "battery"
    set_asus_profile "Quiet"
    
    echo ""
    print_success "Powersave profile applied"
}

#############################################################################
# Automatic Profile Switching
#############################################################################

apply_auto_profile() {
    local power_source=$(detect_power_source)
    
    print_info "Detected power source: $power_source"
    
    if [ "$power_source" = "AC" ]; then
        apply_performance_profile
    else
        apply_powersave_profile
    fi
}

#############################################################################
# Status Display
#############################################################################

show_status() {
    print_header
    
    echo -e "${BLUE}Power Status:${NC}"
    echo "  Source: $(detect_power_source)"
    
    local battery=$(get_battery_percentage)
    if [ "$battery" != "Unknown" ]; then
        echo "  Battery: ${battery}%"
    fi
    
    echo ""
    echo -e "${BLUE}CPU Status:${NC}"
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo "  Governor: $governor"
    fi
    
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        local boost=$(cat /sys/devices/system/cpu/cpufreq/boost)
        echo "  Boost: $boost"
    fi
    
    echo ""
    echo -e "${BLUE}GPU Status:${NC}"
    
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        local gpu_level=$(cat /sys/class/drm/card0/device/power_dpm_force_performance_level)
        echo "  Power Level: $gpu_level"
    fi
    
    if [ -f /sys/class/drm/card0/device/power_dpm_state ]; then
        local gpu_state=$(cat /sys/class/drm/card0/device/power_dpm_state)
        echo "  Power State: $gpu_state"
    fi
    
    echo ""
    echo -e "${BLUE}ASUS Profile:${NC}"
    
    if command -v asusctl &> /dev/null; then
        local profile=$(asusctl profile -p 2>/dev/null || echo "Unknown")
        echo "  Current: $profile"
    else
        echo "  asusctl not installed"
    fi
    
    echo ""
}

#############################################################################
# Udev Rules Installation
#############################################################################

install_udev_rules() {
    print_info "Installing udev rules for automatic power profile switching..."
    
    # Create the udev rules file
    cat > /etc/udev/rules.d/90-gz302-power.rules <<'EOF'
# GZ302EA Automatic Power Profile Switching

# Switch to performance profile when AC adapter is connected
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/local/bin/gz302-power-manager.sh performance"

# Switch to powersave profile when AC adapter is disconnected
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/local/bin/gz302-power-manager.sh powersave"
EOF
    
    print_success "Udev rules created: /etc/udev/rules.d/90-gz302-power.rules"
    
    # Copy this script to /usr/local/bin if not already there
    if [ ! -f /usr/local/bin/gz302-power-manager.sh ]; then
        cp "$0" /usr/local/bin/gz302-power-manager.sh
        chmod +x /usr/local/bin/gz302-power-manager.sh
        print_success "Script copied to /usr/local/bin/gz302-power-manager.sh"
    fi
    
    # Reload udev rules
    print_info "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger
    
    print_success "Automatic power profile switching enabled"
    echo ""
    print_info "The system will now automatically switch between:"
    echo "  • Performance mode when plugged into AC power"
    echo "  • Powersave mode when running on battery"
}

uninstall_udev_rules() {
    print_info "Removing udev rules for automatic power profile switching..."
    
    if [ -f /etc/udev/rules.d/90-gz302-power.rules ]; then
        rm /etc/udev/rules.d/90-gz302-power.rules
        print_success "Udev rules removed"
        
        # Reload udev rules
        udevadm control --reload-rules
        print_success "Automatic power profile switching disabled"
    else
        print_warning "Udev rules not found, nothing to remove"
    fi
}

#############################################################################
# Help Text
#############################################################################

show_help() {
    print_header
    
    cat << EOF
Usage: sudo $0 [MODE] [OPTIONS]

MODES:
  auto                Enable automatic profile based on current power source
  performance         Set performance profile (high CPU/GPU, high refresh)
  balanced            Set balanced profile (moderate settings)
  powersave           Set power saving profile (low CPU/GPU, low refresh)
  status              Show current power and profile status
  
  refresh-high        Set high refresh rate (120Hz)
  refresh-low         Set low refresh rate (60Hz)
  
  install             Install udev rules for automatic AC/battery switching
  uninstall           Remove udev rules for automatic switching
  
  --help              Show this help message

EXAMPLES:
  # Manually set performance mode
  sudo $0 performance
  
  # Set low refresh rate to save power
  sudo $0 refresh-low
  
  # Enable automatic switching based on AC/battery
  sudo $0 install
  
  # Check current status
  sudo $0 status

FEATURES:
  • CPU governor control (performance/powersave)
  • GPU power level management (high/low/auto)
  • ASUS profile integration via asusctl
  • Display refresh rate switching (X11 and Wayland)
  • Automatic AC/battery detection and switching

NOTES:
  • This script requires root privileges
  • Works with both X11 (xrandr) and Wayland (wlr-randr)
  • Integrates with asusctl if available
  • Compatible with AMD GPUs (amdgpu driver)

VERSION: $VERSION
EOF
}

#############################################################################
# Main
#############################################################################

main() {
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        status)
            show_status
            exit 0
            ;;
        auto)
            check_root
            apply_auto_profile
            ;;
        performance)
            check_root
            apply_performance_profile
            ;;
        balanced)
            check_root
            apply_balanced_profile
            ;;
        powersave)
            check_root
            apply_powersave_profile
            ;;
        refresh-high)
            set_refresh_rate 120
            ;;
        refresh-low)
            set_refresh_rate 60
            ;;
        install)
            check_root
            install_udev_rules
            ;;
        uninstall)
            check_root
            uninstall_udev_rules
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"
