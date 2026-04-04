#!/usr/bin/env bash
# ==============================================================================
# GZ302 RGB Control Wrapper
# Provides unified control for both keyboard and rear window (lightbar) RGB
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RGB_BINARY="${SCRIPT_DIR}/gz302-rgb"
LIGHTBAR_SCRIPT="${SCRIPT_DIR}/gz302-lightbar.py"
RGB_CONFIG_DIR="/etc/gz302"

# Check if gz302-rgb binary exists
rgb_binary_exists() {
    [[ -x "$RGB_BINARY" ]]
}

# Check if lightbar script exists
lightbar_script_exists() {
    [[ -x "$LIGHTBAR_SCRIPT" || -f "$LIGHTBAR_SCRIPT" ]]
}

# Get RGB config directory
get_rgb_config_dir() {
    echo "$RGB_CONFIG_DIR"
}

# Print usage
print_usage() {
    echo "GZ302 RGB Control (Unified)"
    echo "Usage: gz302-rgb <target> <command> [args]"
    echo ""
    echo "Targets:"
    echo "  keyboard   - Control keyboard RGB"
    echo "  lightbar   - Control rear window RGB (lightbar)"
    echo "  all        - Control both keyboard and lightbar"
    echo ""
    echo "Keyboard Commands:"
    if rgb_binary_exists; then
        echo "  single_static <HEX_COLOR>              - Static color (e.g., FF0000)"
        echo "  single_breathing <HEX1> <HEX2> <SPEED> - Breathing (speed 1-3)"
        echo "  single_colorcycle <SPEED>              - Color cycling (speed 1-3)"
        echo "  rainbow_cycle <SPEED>                  - Rainbow animation (speed 1-3)"
        echo "  brightness <0-3>                       - Set brightness level"
        echo "  red|green|blue|yellow|cyan|magenta|white|black - Preset colors"
    else
        echo "  Keyboard control not available (gz302-rgb binary missing)"
    fi
    echo ""
    echo "Lightbar Commands:"
    if lightbar_script_exists; then
        echo "  on                                     - Turn lightbar on"
        echo "  off                                    - Turn lightbar off"
        echo "  color <R> <G> <B>                      - Set RGB color (0-255)"
        echo "  status                                 - Show lightbar status"
    else
        echo "  Lightbar control not available (gz302-lightbar.py missing)"
    fi
    echo ""
    echo "Examples:"
    echo "  gz302-rgb keyboard red                  - Set keyboard to red"
    echo "  gz302-rgb lightbar on                   - Turn lightbar on"
    echo "  gz302-rgb lightbar color 255 0 0        - Set lightbar to red"
    echo "  gz302-rgb all keyboard red lightbar on  - Set both to red/on"
}

# Execute keyboard command
exec_keyboard_command() {
    shift 1  # Remove 'keyboard' from args
    if rgb_binary_exists; then
        "$RGB_BINARY" "$@"
    else
        echo "Error: gz302-rgb binary not found or not executable" >&2
        return 1
    fi
}

# Execute lightbar command
exec_lightbar_command() {
    shift 1  # Remove 'lightbar' from args
    if lightbar_script_exists; then
        python3 "$LIGHTBAR_SCRIPT" "$@"
    else
        echo "Error: gz302-lightbar.py not found or not executable" >&2
        return 1
    fi
}

# Execute command on all targets
exec_all_command() {
    shift 1  # Remove 'all' from args
    local keyboard_args=()
    local lightbar_args=()
    local found_target=false
    
    # Parse arguments to separate keyboard and lightbar commands
    while [[ $# -gt 0 ]]; do
        case "$1" in
            keyboard)
                found_target=true
                shift
                while [[ $# -gt 0 && "$1" != "lightbar" ]]; do
                    keyboard_args+=("$1")
                    shift
                done
                ;;
            lightbar)
                found_target=true
                shift
                while [[ $# -gt 0 && "$1" != "keyboard" ]]; do
                    lightbar_args+=("$1")
                    shift
                done
                ;;
            *)
                # Assume it applies to both if no target specified
                if [[ "$found_target" == false ]]; then
                    keyboard_args+=("$1")
                    lightbar_args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    local success=true
    
    # Execute keyboard command
    if [[ ${#keyboard_args[@]} -gt 0 ]]; then
        if ! exec_keyboard_command "${keyboard_args[@]}"; then
            success=false
        fi
    fi
    
    # Execute lightbar command
    if [[ ${#lightbar_args[@]} -gt 0 ]]; then
        if ! exec_lightbar_command "${lightbar_args[@]}"; then
            success=false
        fi
    fi
    
    $success
}

# Main entry point
main() {
    if [[ $# -lt 2 ]]; then
        print_usage
        exit 1
    fi
    
    local target="$1"
    shift
    
    case "$target" in
        keyboard)
            exec_keyboard_command "$@"
            ;;
        lightbar)
            exec_lightbar_command "$@"
            ;;
        all)
            exec_all_command "$@"
            ;;
        *)
            # No target specified, try keyboard first (backward compatibility)
            exec_keyboard_command "$@"
            ;;
    esac
}

main "$@"
