#!/bin/bash
# ==============================================================================
# kbrgb - Keyboard RGB Color Control for ASUS ROG Flow Z13 (GZ302)
#
# Provides command-line control for keyboard backlight RGB colors
# Supports: Color palette, hex colors, brightness, and effects
# Methods: asusctl (preferred), sysfs (fallback)
#
# Version: 1.2.0
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

# --- Logging functions ---
error() {
    echo -e "${C_RED}ERROR:${C_NC} $1" >&2
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

# --- Color palette (10 basic colors) ---
declare -A COLOR_PALETTE=(
    ["red"]="ff0000"
    ["green"]="00ff00"
    ["blue"]="0000ff"
    ["cyan"]="00ffff"
    ["magenta"]="ff00ff"
    ["yellow"]="ffff00"
    ["white"]="ffffff"
    ["orange"]="ff8000"
    ["purple"]="8000ff"
    ["pink"]="ff0080"
)

# --- Detection functions ---
has_asusctl() {
    command -v asusctl >/dev/null 2>&1
}

has_kbd_backlight_sysfs() {
    [[ -d /sys/class/leds/asus::kbd_backlight ]]
}

# --- RGB color control via asusctl ---
set_color_asusctl() {
    local hex_color="$1"
    
    # Convert hex to RGB values
    local r=$((16#${hex_color:0:2}))
    local g=$((16#${hex_color:2:2}))
    local b=$((16#${hex_color:4:2}))
    
    # Try hex format first (newer asusctl)
    if asusctl led-mode static -c "$hex_color" >/dev/null 2>&1; then
        success "Keyboard color set to #$hex_color via asusctl"
        return 0
    fi
    
    # Try RGB format (older asusctl versions)
    if asusctl led-mode static -c "$r" "$g" "$b" >/dev/null 2>&1; then
        success "Keyboard color set to RGB($r,$g,$b) via asusctl"
        return 0
    fi
    
    error "Failed to set color via asusctl"
    return 1
}

# --- Brightness control via sysfs ---
set_brightness_sysfs() {
    local level="$1"
    local brightness_path="/sys/class/leds/asus::kbd_backlight/brightness"
    
    if [[ ! -f "$brightness_path" ]]; then
        error "Keyboard backlight sysfs not found"
        return 1
    fi
    
    # Clamp to 0-3
    level=$((level > 3 ? 3 : level < 0 ? 0 : level))
    
    # Try direct write
    if echo "$level" | sudo tee "$brightness_path" >/dev/null 2>&1; then
        local label="Off"
        case $level in
            1) label="Level 1" ;;
            2) label="Level 2" ;;
            3) label="Level 3" ;;
        esac
        success "Keyboard brightness set to $label"
        return 0
    fi
    
    error "Failed to set brightness"
    return 1
}

# --- Set color effect via asusctl ---
set_effect_asusctl() {
    local effect="$1"
    
    case "$effect" in
        static|breathe|pulse|rainbow|strobe)
            if asusctl led-mode "$effect" >/dev/null 2>&1; then
                success "Keyboard effect set to $effect"
                return 0
            fi
            ;;
        *)
            error "Unknown effect: $effect"
            return 1
            ;;
    esac
    
    error "Failed to set effect"
    return 1
}

# --- Show current status ---
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Keyboard RGB Status"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    if has_asusctl; then
        info "asusctl: Available"
        if asusctl led-mode 2>&1 | grep -q "Mode:"; then
            asusctl led-mode
        fi
    else
        warning "asusctl: Not installed"
    fi
    
    echo ""
    
    if has_kbd_backlight_sysfs; then
        local brightness_path="/sys/class/leds/asus::kbd_backlight/brightness"
        local max_path="/sys/class/leds/asus::kbd_backlight/max_brightness"
        
        if [[ -f "$brightness_path" && -f "$max_path" ]]; then
            local current
            local max
            current=$(cat "$brightness_path")
            max=$(cat "$max_path")
            info "sysfs brightness: $current/$max"
        fi
    else
        warning "sysfs: Keyboard backlight not found"
    fi
    
    echo ""
}

# --- List available colors ---
list_colors() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Available Color Palette"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    for color in "${!COLOR_PALETTE[@]}"; do
        local hex="${COLOR_PALETTE[$color]}"
        printf "  %-10s #%s\n" "$color" "$hex"
    done | sort
    
    echo ""
    echo "Custom colors: Use hex format (e.g., kbrgb hex ff00ff)"
    echo ""
}

# --- List available effects ---
list_effects() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Available Effects (requires asusctl)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "  static     - Solid color"
    echo "  breathe    - Breathing effect"
    echo "  pulse      - Pulsing effect"
    echo "  rainbow    - Rainbow cycle"
    echo "  strobe     - Strobe effect"
    echo ""
}

# --- Show usage ---
show_usage() {
    cat << 'EOF'
Usage: kbrgb [COMMAND] [OPTIONS]

Commands:
  color <name>        Set keyboard color from palette
  hex <RRGGBB>        Set keyboard color using hex code
  brightness <0-3>    Set keyboard brightness (0=off, 3=max)
  effect <name>       Set keyboard effect (static, breathe, pulse, rainbow, strobe)
  status              Show current keyboard RGB status
  list                List available color palette
  effects             List available effects
  help                Show this help message

Color Palette:
  red, green, blue, cyan, magenta, yellow, white, orange, purple, pink

Examples:
  kbrgb color red              # Set keyboard to red
  kbrgb hex ff00ff             # Set keyboard to magenta using hex
  kbrgb brightness 2           # Set brightness to level 2
  kbrgb effect breathe         # Set breathing effect
  kbrgb status                 # Show current status
  kbrgb list                   # List all palette colors

Requirements:
  - asusctl (recommended for full RGB control)
  - sysfs fallback for basic brightness control

Note: asusctl provides full RGB color and effect control.
      Without asusctl, only basic brightness control is available via sysfs.
EOF
}

# --- Main function ---
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        color)
            if [[ $# -lt 1 ]]; then
                error "Missing color name"
                echo "Available colors:"
                list_colors
                exit 1
            fi
            
            local color_name="${1,,}"  # Convert to lowercase
            
            if [[ ! -v COLOR_PALETTE[$color_name] ]]; then
                error "Unknown color: $color_name"
                echo ""
                list_colors
                exit 1
            fi
            
            if ! has_asusctl; then
                error "asusctl is required for RGB color control"
                info "Install asusctl or use 'kbrgb brightness <0-3>' for basic control"
                exit 1
            fi
            
            set_color_asusctl "${COLOR_PALETTE[$color_name]}"
            ;;
            
        hex)
            if [[ $# -lt 1 ]]; then
                error "Missing hex color code"
                echo "Usage: kbrgb hex RRGGBB (e.g., kbrgb hex ff00ff)"
                exit 1
            fi
            
            local hex_color="$1"
            
            # Validate hex format
            if [[ ! "$hex_color" =~ ^[0-9a-fA-F]{6}$ ]]; then
                error "Invalid hex color format. Use 6-digit hex (e.g., ff00ff)"
                exit 1
            fi
            
            if ! has_asusctl; then
                error "asusctl is required for RGB color control"
                info "Install asusctl or use 'kbrgb brightness <0-3>' for basic control"
                exit 1
            fi
            
            set_color_asusctl "$hex_color"
            ;;
            
        brightness)
            if [[ $# -lt 1 ]]; then
                error "Missing brightness level"
                echo "Usage: kbrgb brightness <0-3>"
                exit 1
            fi
            
            local level="$1"
            
            if [[ ! "$level" =~ ^[0-3]$ ]]; then
                error "Invalid brightness level. Use 0-3"
                exit 1
            fi
            
            set_brightness_sysfs "$level"
            ;;
            
        effect)
            if [[ $# -lt 1 ]]; then
                error "Missing effect name"
                list_effects
                exit 1
            fi
            
            if ! has_asusctl; then
                error "asusctl is required for effects"
                info "Install asusctl for full RGB control"
                exit 1
            fi
            
            set_effect_asusctl "$1"
            ;;
            
        status)
            show_status
            ;;
            
        list)
            list_colors
            ;;
            
        effects)
            list_effects
            ;;
            
        help|--help|-h)
            show_usage
            ;;
            
        *)
            error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
