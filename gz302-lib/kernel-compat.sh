#!/bin/bash
# shellcheck disable=SC2034

# ==============================================================================
# GZ302 Kernel Compatibility Library
# Version: 3.0.0
#
# This library provides central kernel version detection and compatibility
# logic for all other libraries. It determines what workarounds are needed
# based on the running kernel version.
#
# Key Kernel Milestones:
# - 6.12: Absolute minimum (Strix Halo basic support)
# - 6.14: First recommended version (XDNA NPU, MT7925 WiFi)
# - 6.16: Improved stability (GPU fixes, WiFi improvements)
# - 6.17: Production ready (native WiFi ASPM, asus-wmi tablet mode)
# - 6.19+: Latest optimizations
#
# Usage:
#   source gz302-lib/kernel-compat.sh
#   kernel_get_version_num
#   kernel_requires_wifi_workaround
#   kernel_requires_input_workaround
# ==============================================================================

# --- Version Constants ---
readonly KERNEL_MIN=612          # 6.12 - Absolute minimum
readonly KERNEL_RECOMMENDED=614  # 6.14 - First recommended
readonly KERNEL_STABLE=616       # 6.16 - Stable support
readonly KERNEL_NATIVE=617       # 6.17 - Native support for most hardware
readonly KERNEL_OPTIMAL=620      # 6.20+ - Latest optimizations

# --- Core Version Functions ---

# Get kernel version as comparable number
# Returns: Version number (e.g., 617 for 6.17.4)
# Output: None (return value only)
kernel_get_version_num() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    echo $((major * 100 + minor))
}

# Get full kernel version string
# Returns: Full version (e.g., "6.17.4-arch1-1")
kernel_get_version_string() {
    uname -r
}

# Get major.minor version string
# Returns: Short version (e.g., "6.17")
kernel_get_version_short() {
    uname -r | cut -d. -f1,2
}

# Check if kernel meets minimum requirements
# Returns: 0 if meets minimum, 1 if below minimum
kernel_meets_minimum() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_MIN ]]
}

# Check if kernel is at recommended level or above
# Returns: 0 if recommended or better, 1 if below
kernel_is_recommended() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_RECOMMENDED ]]
}

# Check if kernel is at stable level or above
# Returns: 0 if stable or better, 1 if below
kernel_is_stable() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_STABLE ]]
}

# Check if kernel has native hardware support (6.17+)
# Returns: 0 if native support available, 1 if not
kernel_has_native_support() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_NATIVE ]]
}

# Check if kernel is at optimal level (6.20+)
# Returns: 0 if optimal, 1 if not
kernel_is_optimal() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_OPTIMAL ]]
}

# --- Component-Specific Compatibility Checks ---

# Check if WiFi ASPM workaround is required
# Returns: 0 if workaround needed, 1 if not needed
kernel_requires_wifi_workaround() {
    local version_num
    version_num=$(kernel_get_version_num)
    # ASPM workaround needed for kernels < 6.17
    [[ $version_num -lt $KERNEL_NATIVE ]]
}

# Check if input device forcing is required
# Returns: 0 if forcing needed, 1 if not needed
kernel_requires_input_workaround() {
    local version_num
    version_num=$(kernel_get_version_num)
    # Input forcing needed for kernels < 6.17
    [[ $version_num -lt $KERNEL_NATIVE ]]
}

# Check if tablet mode daemon is required
# Returns: 0 if daemon needed, 1 if not needed (native support)
kernel_requires_tablet_daemon() {
    local version_num
    version_num=$(kernel_get_version_num)
    # Tablet mode daemon needed for kernels < 6.17 (no asus-wmi support)
    [[ $version_num -lt $KERNEL_NATIVE ]]
}

# Check if GPU stability workarounds are required
# Returns: 0 if workarounds needed, 1 if not needed
kernel_requires_gpu_workarounds() {
    local version_num
    version_num=$(kernel_get_version_num)
    # GPU workarounds needed for kernels < 6.16
    [[ $version_num -lt $KERNEL_STABLE ]]
}

# Check if audio quirks are still required
# Returns: 0 if quirks needed (always true for now)
# Note: CS35L41 subsystem ID not yet upstream, always need quirks
kernel_requires_audio_quirks() {
    # Audio quirks always required (CS35L41 not yet fully upstream)
    return 0
}

# --- Kernel Feature Detection ---

# Check if kernel has asus-wmi tablet mode support
# Returns: 0 if supported, 1 if not
kernel_has_asus_wmi_tablet_mode() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_NATIVE ]]
}

# Check if kernel has MT7925 WiFi improvements
# Returns: 0 if has improvements, 1 if not
kernel_has_mt7925_improvements() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_NATIVE ]]
}

# Check if kernel has AMD GPU DC stabilization
# Returns: 0 if has stabilization, 1 if not
kernel_has_amdgpu_dc_fixes() {
    local version_num
    version_num=$(kernel_get_version_num)
    [[ $version_num -ge $KERNEL_STABLE ]]
}

# --- Status and Information Functions ---

# Get kernel status category
# Returns: String describing kernel status
kernel_get_status() {
    local version_num
    version_num=$(kernel_get_version_num)
    
    if [[ $version_num -lt $KERNEL_MIN ]]; then
        echo "unsupported"
    elif [[ $version_num -lt $KERNEL_RECOMMENDED ]]; then
        echo "minimal"
    elif [[ $version_num -lt $KERNEL_STABLE ]]; then
        echo "recommended"
    elif [[ $version_num -lt $KERNEL_NATIVE ]]; then
        echo "stable"
    elif [[ $version_num -lt $KERNEL_OPTIMAL ]]; then
        echo "native"
    else
        echo "optimal"
    fi
}

# Get human-readable kernel status description
# Output: Multi-line status description
kernel_print_status() {
    local version_str
    local version_num
    local status
    
    version_str=$(kernel_get_version_string)
    version_num=$(kernel_get_version_num)
    status=$(kernel_get_status)
    
    echo "Kernel Version: $version_str"
    echo "Version Number: $version_num"
    echo "Status: $status"
    echo
    
    case "$status" in
        unsupported)
            echo "❌ UNSUPPORTED: Below minimum required version"
            echo "   Minimum: 6.12+"
            echo "   Action: Upgrade kernel immediately"
            ;;
        minimal)
            echo "⚠️  MINIMAL: Meets minimum but lacks improvements"
            echo "   Recommended: 6.14+"
            echo "   Action: Consider upgrading for stability"
            ;;
        recommended)
            echo "✓ RECOMMENDED: Good basic support"
            echo "   Stable: 6.16+"
            echo "   Note: Some workarounds still needed"
            ;;
        stable)
            echo "✓ STABLE: Well-supported with workarounds"
            echo "   Native: 6.17+"
            echo "   Note: Upgrade to 6.17+ for native support"
            ;;
        native)
            echo "✅ NATIVE: Excellent native hardware support"
            echo "   Optimal: 6.20+"
            echo "   Note: Most workarounds obsolete"
            ;;
        optimal)
            echo "✅ OPTIMAL: Latest kernel with all optimizations"
            echo "   Status: Cutting edge"
            echo "   Note: Best possible experience"
            ;;
    esac
    echo
    
    # List required workarounds
    echo "Required Workarounds:"
    if kernel_requires_wifi_workaround; then
        echo "  • WiFi ASPM workaround"
    fi
    if kernel_requires_input_workaround; then
        echo "  • Input device forcing"
    fi
    if kernel_requires_tablet_daemon; then
        echo "  • Tablet mode daemon"
    fi
    if kernel_requires_gpu_workarounds; then
        echo "  • GPU stability workarounds"
    fi
    if kernel_requires_audio_quirks; then
        echo "  • Audio quirks (CS35L41)"
    fi
    
    if kernel_has_native_support; then
        echo "  (Most hardware now native - minimal fixes needed)"
    fi
}

# Get list of obsolete workarounds for current kernel
# Output: Newline-separated list of obsolete workarounds
kernel_list_obsolete_workarounds() {
    local version_num
    version_num=$(kernel_get_version_num)
    
    if [[ $version_num -ge $KERNEL_NATIVE ]]; then
        # Kernel 6.17+ - these are obsolete
        echo "wifi_aspm_workaround"
        echo "input_device_forcing"
        echo "tablet_mode_daemon"
    fi
    
    if [[ $version_num -ge $KERNEL_STABLE ]]; then
        # Kernel 6.16+ - GPU workarounds obsolete
        echo "gpu_stability_workarounds"
    fi
}

# --- Library Information ---

kernel_lib_version() {
    echo "3.0.0"
}

kernel_lib_help() {
    cat <<'HELP'
GZ302 Kernel Compatibility Library v3.0.0

Version Detection Functions:
  kernel_get_version_num        - Get version as comparable number (e.g., 617)
  kernel_get_version_string     - Get full version string
  kernel_get_version_short      - Get major.minor version (e.g., "6.17")

Version Check Functions:
  kernel_meets_minimum          - Check if >= 6.12 (minimum required)
  kernel_is_recommended         - Check if >= 6.14 (recommended)
  kernel_is_stable              - Check if >= 6.16 (stable)
  kernel_has_native_support     - Check if >= 6.17 (native hardware support)
  kernel_is_optimal             - Check if >= 6.20 (optimal)

Component Compatibility Checks:
  kernel_requires_wifi_workaround    - Check if WiFi ASPM workaround needed
  kernel_requires_input_workaround   - Check if input forcing needed
  kernel_requires_tablet_daemon      - Check if tablet mode daemon needed
  kernel_requires_gpu_workarounds    - Check if GPU workarounds needed
  kernel_requires_audio_quirks       - Check if audio quirks needed

Feature Detection:
  kernel_has_asus_wmi_tablet_mode    - Check if asus-wmi tablet support present
  kernel_has_mt7925_improvements     - Check if MT7925 WiFi improvements present
  kernel_has_amdgpu_dc_fixes         - Check if AMD GPU DC fixes present

Status Functions:
  kernel_get_status                  - Get status category (string)
  kernel_print_status                - Print detailed status (human-readable)
  kernel_list_obsolete_workarounds   - List obsolete workarounds for kernel

Library Information:
  kernel_lib_version                 - Get library version
  kernel_lib_help                    - Show this help

Example Usage:
  source gz302-lib/kernel-compat.sh
  
  # Check kernel version
  if kernel_meets_minimum; then
      echo "Kernel meets minimum requirements"
  fi
  
  # Check if workarounds needed
  if kernel_requires_wifi_workaround; then
      echo "Apply WiFi ASPM workaround"
  else
      echo "Use native WiFi support"
  fi
  
  # Display status
  kernel_print_status

Version Milestones:
  6.12 - Minimum (Strix Halo basic support)
  6.14 - Recommended (XDNA NPU, MT7925 WiFi)
  6.16 - Stable (GPU fixes, WiFi improvements)
  6.17 - Native (native WiFi ASPM, asus-wmi tablet mode)
  6.20 - Optimal (latest optimizations)
HELP
}
