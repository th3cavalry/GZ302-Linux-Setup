#!/bin/bash

# ==============================================================================
# Minimal Linux Setup Script for ASUS ROG Flow Z13 (GZ302) - v4.0.0
#
# Author: th3cavalry using Copilot
# Version: 4.0.2
#
# This script applies ONLY the essential hardware fixes needed to run Linux
# properly on the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395.
#
# NEW IN v4.0.0:
# - Library-first architecture (modular, testable)
# - Persistent state tracking (idempotent operations)
# - Automatic backups before modifications
# - Comprehensive logging
# - Command-line interface (--status, --force)
#
# KERNEL-AWARE: Automatically detects kernel version and applies only necessary
# fixes. For kernel 6.17+, most hardware workarounds are obsolete as native
# support is available. Re-running on kernel 6.17+ will clean up obsolete fixes.
#
# For full features (TDP control, RGB, gaming, AI modules), use gz302-main.sh
#
# Essential fixes applied (kernel-dependent):
# - Kernel version verification (6.12+ required, 6.17+ recommended)
# - WiFi stability (MediaTek MT7925) - only needed for kernel < 6.17
# - AMD GPU optimization
# - Touchpad/keyboard detection - only needed for kernel < 6.17
# - Power management kernel parameters
#
# Supported Distributions:
# - Arch-based (Arch, Omarchy, CachyOS, EndeavourOS, Manjaro)
# - Debian-based (Ubuntu, Pop!_OS, Linux Mint)
# - RPM-based (Fedora, Nobara)
# - OpenSUSE (Tumbleweed, Leap)
#
# USAGE:
#   curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal-v4.sh -o gz302-minimal-v4.sh
#   chmod +x gz302-minimal-v4.sh
#   sudo ./gz302-minimal-v4.sh [--status] [--force]
#
# OPTIONS:
#   --status    Show current system status and exit
#   --force     Force re-application of all fixes (ignore state)
# ==============================================================================

set -euo pipefail

# --- Script Configuration ---
SCRIPT_VERSION="4.0.2"
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Parse command-line arguments ---
MODE="install"  # install, status, force
FORCE_MODE=false

for arg in "$@"; do
    case "$arg" in
        --status)
            MODE="status"
            ;;
        --force)
            FORCE_MODE=true
            MODE="install"
            ;;
        --help|-h)
            cat <<'HELP'
GZ302 Minimal Setup Script v4.0.0-dev

Usage:
    sudo ./gz302-minimal-v4.sh [OPTIONS]

Options:
    --status    Show current system status and exit
    --force     Force re-application of all fixes (ignore state)
    --help      Show this help message

Examples:
    # Normal installation (idempotent)
    sudo ./gz302-minimal-v4.sh

    # Check status
    sudo ./gz302-minimal-v4.sh --status

    # Force re-apply all fixes
    sudo ./gz302-minimal-v4.sh --force

Features:
    - Kernel-aware hardware fixes
    - Persistent state tracking
    - Idempotent operations (safe to re-run)
    - Automatic backups
    - Comprehensive logging
HELP
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# --- Get script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load Libraries ---
load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/gz302-lib/${lib_name}"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck disable=SC1090
        source "$lib_path"
        return 0
    else
        # Try to download if not present
        echo "Downloading ${lib_name}..."
        if command -v curl >/dev/null 2>&1; then
            mkdir -p "${SCRIPT_DIR}/gz302-lib"
            curl -fsSL "${GITHUB_RAW_URL}/gz302-lib/${lib_name}" -o "$lib_path" || return 1
            chmod +x "$lib_path"
            # shellcheck disable=SC1090
            source "$lib_path"
            return 0
        else
            return 1
        fi
    fi
}

echo "Loading GZ302 libraries..."

# Load required libraries
if ! load_library "kernel-compat.sh"; then
    echo "ERROR: Failed to load kernel-compat.sh"
    exit 1
fi

if ! load_library "state-manager.sh"; then
    echo "ERROR: Failed to load state-manager.sh"
    exit 1
fi

if ! load_library "wifi-manager.sh"; then
    echo "ERROR: Failed to load wifi-manager.sh"
    exit 1
fi

if ! load_library "gpu-manager.sh"; then
    echo "ERROR: Failed to load gpu-manager.sh"
    exit 1
fi

if ! load_library "input-manager.sh"; then
    echo "ERROR: Failed to load input-manager.sh"
    exit 1
fi

echo "✓ All libraries loaded successfully"
echo

# --- Check root ---
check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "ERROR: This script must be run as root"
        echo "Usage: sudo ./gz302-minimal-v4.sh"
        exit 1
    fi
}

# --- Status Mode ---
if [[ "$MODE" == "status" ]]; then
    check_root
    
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         GZ302 Minimal Setup - System Status              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo
    
    # Kernel status
    echo "━━━ Kernel Status ━━━"
    kernel_print_status
    echo
    
    # Initialize state manager
    state_init >/dev/null 2>&1 || true
    
    # Component status
    echo "━━━ WiFi Status ━━━"
    wifi_print_status
    echo
    
    echo "━━━ GPU Status ━━━"
    gpu_print_status
    echo
    
    echo "━━━ Input Status ━━━"
    input_print_status
    echo
    
    # State manager status
    echo "━━━ State Tracking Status ━━━"
    state_print_status
    
    exit 0
fi

# --- Main Installation ---
check_root

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║    ASUS ROG Flow Z13 (GZ302) Minimal Setup v${SCRIPT_VERSION}    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo
echo "Library-first architecture: Modular, idempotent, kernel-aware"
echo

if [[ "$FORCE_MODE" == true ]]; then
    echo "⚠️  FORCE MODE: Will re-apply all fixes (ignoring state)"
    echo
fi

# Step 1: Initialize state management
echo "━━━ Step 1: Initialize State Management ━━━"
if state_init; then
    echo "✓ State management initialized"
    if [[ "$FORCE_MODE" == true ]]; then
        echo "  Clearing state for force mode..."
        state_clear_all >/dev/null 2>&1 || true
    fi
else
    echo "⚠️  State management initialization had issues (continuing anyway)"
fi
echo

# Step 2: Kernel compatibility check
echo "━━━ Step 2: Kernel Compatibility Check ━━━"
if ! kernel_meets_minimum; then
    echo
    echo "❌ UNSUPPORTED KERNEL VERSION"
    echo
    kernel_print_status
    echo
    echo "Installation cancelled. Please upgrade your kernel."
    exit 1
fi

kernel_ver=$(kernel_get_version_num)
kernel_status=$(kernel_get_status)

echo "Kernel: $(kernel_get_version_string)"
echo "Status: $kernel_status"
echo "Version number: $kernel_ver"

if kernel_has_native_support; then
    echo "✓ Kernel has native GZ302 hardware support"
    echo "  Minimal fixes needed, obsolete workarounds will be cleaned up"
else
    echo "⚠️  Kernel needs workarounds for full hardware support"
    echo "  Consider upgrading to kernel 6.17+ for native support"
fi
echo

# Step 3: WiFi Configuration
echo "━━━ Step 3: WiFi Configuration (MediaTek MT7925) ━━━"

if wifi_detect_hardware >/dev/null 2>&1; then
    echo "✓ MT7925e WiFi controller detected"
    
    if wifi_apply_configuration; then
        state_mark_applied "wifi" "configuration" "kernel_${kernel_ver}"
        state_log "INFO" "WiFi configuration applied for kernel ${kernel_ver}"
        echo "✓ WiFi configuration completed successfully"
    else
        echo "⚠️  WiFi configuration had warnings"
    fi
else
    echo "⚠️  MT7925e WiFi controller not detected"
    echo "  Skipping WiFi configuration"
fi
echo

# Step 4: GPU Configuration
echo "━━━ Step 4: GPU Configuration (AMD Radeon 8060S) ━━━"

if gpu_detect_hardware >/dev/null 2>&1; then
    echo "✓ AMD Radeon GPU detected"
    
    if gpu_apply_configuration; then
        state_mark_applied "gpu" "configuration" "radeon_8060s"
        state_log "INFO" "GPU configuration applied"
        echo "✓ GPU configuration completed successfully"
    else
        echo "⚠️  GPU configuration had warnings"
    fi
else
    echo "⚠️  AMD Radeon GPU not detected"
    echo "  Skipping GPU configuration"
fi
echo

# Step 5: Input Configuration
echo "━━━ Step 5: Input Configuration (Keyboard & Touchpad) ━━━"

if input_detect_hid_devices >/dev/null 2>&1; then
    echo "✓ ASUS HID devices detected"
    
    if input_apply_configuration "$kernel_ver"; then
        state_mark_applied "input" "configuration" "kernel_${kernel_ver}"
        state_log "INFO" "Input configuration applied for kernel ${kernel_ver}"
        echo "✓ Input configuration completed successfully"
    else
        echo "⚠️  Input configuration had warnings"
    fi
else
    echo "⚠️  ASUS HID devices not detected"
    echo "  Skipping input configuration"
fi
echo

# Step 6: Verification
echo "━━━ Step 6: Verification ━━━"

verification_passed=true

echo "Verifying WiFi..."
if wifi_verify_working >/dev/null 2>&1; then
    echo "  ✓ WiFi verification passed"
else
    echo "  ⚠️  WiFi verification had warnings"
    verification_passed=false
fi

echo "Verifying GPU..."
if gpu_verify_working >/dev/null 2>&1; then
    echo "  ✓ GPU verification passed"
else
    echo "  ⚠️  GPU verification had warnings"
    verification_passed=false
fi

echo "Verifying Input..."
if input_verify_working >/dev/null 2>&1; then
    echo "  ✓ Input verification passed"
else
    echo "  ⚠️  Input verification had warnings"
    verification_passed=false
fi

if [[ "$verification_passed" == true ]]; then
    echo "✓ All components verified successfully"
else
    echo "⚠️  Some components had verification warnings (see above)"
fi
echo

# Summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Minimal Setup Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo
echo "Applied Fixes:"
echo "  ✓ Kernel parameters (amd_pstate, amdgpu)"

if [[ $kernel_ver -ge 617 ]]; then
    echo "  ✓ WiFi using native kernel 6.17+ support"
    echo "  ✓ Touchpad/keyboard using native support"
    echo "  ✓ Tablet mode using asus-wmi driver"
else
    echo "  ✓ WiFi stability workaround (MediaTek MT7925)"
    echo "  ✓ Touchpad/keyboard detection workaround"
    echo "  ⚠️  Upgrade to kernel 6.17+ for native hardware support"
fi

echo "  ✓ GPU optimization (Radeon 8060S)"
echo
echo "State Tracking:"
echo "  State files: /var/lib/gz302/state/"
echo "  Backups: /var/backups/gz302/"
echo "  Logs: /var/log/gz302/"
echo
echo "Next Steps:"
echo "  1. Reboot your system for changes to take effect"
echo "  2. Check status: sudo ./gz302-minimal-v4.sh --status"
echo "  3. For full features: sudo ./gz302-main.sh"
echo

if [[ $kernel_ver -ge 617 ]]; then
    echo "ℹ️  Your kernel (6.17+) has native GZ302 support"
    echo "   This script applied only essential optimizations"
    echo "   Learn more: docs/kernel-support.md"
    echo
fi

echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo
