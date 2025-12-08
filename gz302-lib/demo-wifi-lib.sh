#!/bin/bash
# ==============================================================================
# WiFi Library Demonstration Script
# Version: 3.0.0
#
# This script demonstrates the usage of the wifi-manager.sh library.
# It shows the library-first approach: detection, state checking, configuration,
# and verification as separate, composable operations.
#
# USAGE:
#   sudo ./demo-wifi-lib.sh
#
# This is a DEMONSTRATION script showing the architectural vision.
# It is NOT intended for production use yet.
# ==============================================================================

set -euo pipefail

# --- Get script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Color output ---
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_NC='\033[0m'

info() {
    echo -e "${C_BLUE}INFO:${C_NC} $1"
}

success() {
    echo -e "${C_GREEN}SUCCESS:${C_NC} $1"
}

warning() {
    echo -e "${C_YELLOW}WARNING:${C_NC} $1"
}

section() {
    echo
    echo -e "${C_CYAN}━━━ $1 ━━━${C_NC}"
}

# --- Check root ---
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: This demo requires root privileges"
    echo "Usage: sudo ./demo-wifi-lib.sh"
    exit 1
fi

# --- Load WiFi library ---
if [[ -f "${SCRIPT_DIR}/wifi-manager.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/wifi-manager.sh"
    success "Loaded wifi-manager.sh library"
else
    echo "ERROR: wifi-manager.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

# --- Demonstration ---

echo
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      GZ302 WiFi Manager Library - Demonstration          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo

info "This demonstrates the library-first architecture vision"
info "Library version: $(wifi_lib_version)"
echo

# --- Step 1: Hardware Detection ---
section "Step 1: Hardware Detection (Read-Only)"

info "Detecting WiFi hardware..."
if wifi_detect_hardware; then
    success "MT7925e WiFi controller detected"
    echo "  Device: $(wifi_detect_hardware)"
else
    warning "MT7925e WiFi controller not detected"
    echo "  This demo requires the GZ302 WiFi hardware"
    exit 0
fi

echo
info "Checking if kernel module is loaded..."
if wifi_module_loaded; then
    success "mt7925e kernel module is loaded"
else
    warning "mt7925e kernel module is not loaded"
fi

echo
info "Checking firmware version..."
fw_ver=$(wifi_get_firmware_version)
echo "  Firmware: $fw_ver"

# --- Step 2: Kernel Compatibility Check ---
section "Step 2: Kernel Compatibility Check"

info "Current kernel: $(uname -r)"

if wifi_requires_aspm_workaround; then
    warning "Kernel < 6.17 detected - ASPM workaround is REQUIRED"
    echo "  Without the workaround, WiFi will be unstable (packet loss, disconnects)"
else
    success "Kernel 6.17+ detected - ASPM workaround is NOT NEEDED"
    echo "  Native kernel support is sufficient"
    echo "  Applying the workaround would harm battery life"
fi

# --- Step 3: Current State Check ---
section "Step 3: Current State Check"

info "Checking current WiFi configuration state..."
echo

# Display state as JSON
info "Current state (JSON format):"
wifi_get_state | while IFS= read -r line; do
    echo "  $line"
done

echo
info "Checking specific configurations..."

if wifi_aspm_workaround_applied >/dev/null 2>&1; then
    echo "  ✓ ASPM workaround: APPLIED"
else
    echo "  ✗ ASPM workaround: NOT APPLIED"
fi

if wifi_powersave_disabled; then
    echo "  ✓ Power saving: DISABLED"
else
    echo "  ✗ Power saving: NOT DISABLED"
fi

# --- Step 4: Configuration Application ---
section "Step 4: Apply Configuration (Idempotent)"

info "This step demonstrates idempotency - safe to run multiple times"
echo

info "Applying WiFi configuration for current kernel version..."
if wifi_apply_configuration; then
    success "WiFi configuration applied successfully"
else
    warning "WiFi configuration had warnings (see above)"
fi

echo
info "Running configuration again to demonstrate idempotency..."
info "(Note: Nothing should be re-applied)"
echo
if wifi_apply_configuration; then
    success "Configuration check passed - already applied"
else
    warning "Configuration check had warnings"
fi

# --- Step 5: Verification ---
section "Step 5: Verification"

info "Verifying WiFi is working correctly..."
if wifi_verify_working; then
    success "WiFi verification passed"
else
    warning "WiFi verification detected issues (see above)"
fi

# --- Step 6: Status Display ---
section "Step 6: Comprehensive Status Display"

info "Displaying user-friendly status..."
echo
wifi_print_status

# --- Step 7: Architecture Benefits ---
section "Step 7: Architecture Benefits Demonstrated"

echo "This demonstration showed:"
echo
echo "  ✓ Separation of Concerns"
echo "    - Detection (read-only) separate from configuration"
echo "    - State checking before application"
echo "    - Verification after changes"
echo
echo "  ✓ Idempotency"
echo "    - Safe to run multiple times"
echo "    - Checks before applying"
echo "    - No duplicate work"
echo
echo "  ✓ Kernel Awareness"
echo "    - Adapts to kernel version automatically"
echo "    - Applies workarounds only when needed"
echo "    - Cleans up obsolete fixes"
echo
echo "  ✓ Clear State Visibility"
echo "    - JSON state format for parsing"
echo "    - Human-readable status display"
echo "    - Warnings for misconfigurations"
echo

# --- Comparison ---
section "Comparison: Old vs. New Approach"

echo "OLD MONOLITHIC APPROACH:"
echo "  - One big function applies everything"
echo "  - No state checking (re-applies on every run)"
echo "  - Hard to debug (3961 lines in one file)"
echo "  - Can't selectively apply fixes"
echo "  - Difficult to test individual components"
echo
echo "NEW LIBRARY-FIRST APPROACH:"
echo "  - Small, focused functions (wifi-manager.sh ~400 lines)"
echo "  - Idempotent (checks before applying)"
echo "  - Easy to debug (single responsibility)"
echo "  - Selective control (apply/remove individual fixes)"
echo "  - Testable (each function independent)"
echo

# --- Next Steps ---
section "Next Steps in Refactoring"

echo "This WiFi library is a proof-of-concept for:"
echo
echo "  1. audio-manager.sh - Cirrus Logic CS35L41 management"
echo "  2. input-manager.sh - HID device and tablet mode"
echo "  3. gpu-manager.sh - AMD Radeon 8060S optimization"
echo "  4. kernel-compat.sh - Central kernel version logic"
echo "  5. state-manager.sh - Persistent state tracking"
echo
echo "Once all libraries are ready, gz302-main.sh becomes a simple orchestrator:"
echo
echo "  source gz302-lib/*.sh"
echo "  wifi_apply_configuration"
echo "  audio_apply_configuration"
echo "  input_apply_configuration"
echo "  gpu_apply_configuration"
echo
echo "Main script: 3961 lines → ~1000 lines (orchestration only)"
echo "Libraries: ~300 lines each (focused, testable, maintainable)"
echo

# --- Final Message ---
section "Demonstration Complete"

success "WiFi library demonstration completed successfully"
echo
info "For more information:"
echo "  - Library documentation: gz302-lib/README.md"
echo "  - Strategic plan: Info/STRATEGIC_REFACTORING_PLAN.md"
echo "  - Library help: source wifi-manager.sh && wifi_lib_help"
echo

if wifi_requires_aspm_workaround; then
    warning "REMINDER: Your kernel requires the ASPM workaround for stability"
    info "Configuration has been applied - WiFi should work correctly now"
else
    info "REMINDER: Your kernel has native WiFi support - no workarounds needed"
    info "Configuration verified - WiFi should have optimal battery life"
fi

echo
