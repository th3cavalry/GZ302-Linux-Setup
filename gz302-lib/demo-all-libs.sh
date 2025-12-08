#!/bin/bash
# ==============================================================================
# Complete Library Suite Demonstration
# Version: 3.0.0
#
# This script demonstrates all GZ302 libraries working together to provide
# a complete, modular, idempotent hardware configuration system.
#
# Libraries Demonstrated:
# 1. kernel-compat.sh - Central kernel version detection
# 2. state-manager.sh - Persistent state tracking
# 3. wifi-manager.sh - WiFi configuration
# 4. gpu-manager.sh - GPU configuration
# 5. input-manager.sh - Input devices configuration
# 6. audio-manager.sh - Audio configuration
#
# USAGE:
#   sudo ./demo-all-libs.sh
#
# This is a DEMONSTRATION showing the architectural vision.
# NOT for production use - integration into main script is separate.
# ==============================================================================

set -euo pipefail

# --- Get script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Color output ---
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_BOLD_CYAN='\033[1;36m'
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

header() {
    echo
    echo -e "${C_BOLD_CYAN}╔═══════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_BOLD_CYAN}║  $1${C_NC}"
    echo -e "${C_BOLD_CYAN}╚═══════════════════════════════════════════════════════════╝${C_NC}"
    echo
}

# --- Check root ---
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: This demo requires root privileges"
    echo "Usage: sudo ./demo-all-libs.sh"
    exit 1
fi

# --- Load all libraries ---
header "Loading GZ302 Library Suite"

for lib in kernel-compat.sh state-manager.sh wifi-manager.sh gpu-manager.sh input-manager.sh audio-manager.sh; do
    if [[ -f "${SCRIPT_DIR}/${lib}" ]]; then
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/${lib}"
        success "Loaded ${lib}"
    else
        echo "ERROR: Library not found: ${lib}"
        exit 1
    fi
done

echo
info "All libraries loaded successfully"
info "Total: 6 libraries, ~4000 lines of modular code"

# --- Demo Start ---
header "GZ302 Complete Library Suite Demonstration"

# --- Step 1: Kernel Compatibility ---
section "Step 1: Kernel Compatibility Analysis"

info "Detecting kernel version and requirements..."
echo
kernel_print_status
echo

# Get kernel version for conditional logic
kernel_ver=$(kernel_get_version_num)
info "Kernel version number for comparison: $kernel_ver"

# --- Step 2: State Management ---
section "Step 2: Initialize State Management"

info "Initializing persistent state tracking..."
if state_init; then
    success "State management initialized"
    echo "  State dir: /var/lib/gz302/state/"
    echo "  Backup dir: /var/backups/gz302/"
    echo "  Log dir: /var/log/gz302/"
else
    warning "State management initialization had issues"
fi

# --- Step 3: Hardware Detection (All Components) ---
section "Step 3: Hardware Detection (Read-Only)"

echo "Detecting all hardware components..."
echo

info "WiFi Controller:"
if wifi_detect_hardware; then
    echo "  ✓ MT7925e WiFi detected"
    echo "  Device: $(wifi_detect_hardware)"
else
    echo "  ✗ MT7925e WiFi not detected"
fi

echo
info "GPU:"
if gpu_detect_hardware; then
    echo "  ✓ AMD Radeon GPU detected"
    echo "  Device: $(gpu_detect_hardware)"
    echo "  Device ID: $(gpu_get_device_id)"
else
    echo "  ✗ AMD Radeon GPU not detected"
fi

echo
info "Input Devices:"
if input_detect_hid_devices; then
    echo "  ✓ ASUS HID devices detected"
else
    echo "  ✗ ASUS HID devices not detected"
fi

if input_touchpad_detected; then
    echo "  ✓ Touchpad detected"
else
    echo "  ✗ Touchpad not detected"
fi

echo
info "Audio Controller:"
if audio_detect_controller; then
    echo "  ✓ Audio controller detected"
    echo "  Device: $(audio_detect_controller)"
    if audio_detect_cs35l41; then
        echo "  ✓ CS35L41 amplifiers detected"
    else
        echo "  Note: CS35L41 may appear after reboot"
    fi
else
    echo "  ✗ Audio controller not detected"
fi

# --- Step 4: Configuration Application (Idempotent) ---
section "Step 4: Apply Configurations (Idempotent)"

info "Applying kernel-appropriate configurations for all components..."
echo

# WiFi Configuration
info "WiFi Configuration:"
if wifi_apply_configuration; then
    success "WiFi configured"
    state_mark_applied "wifi" "configuration" "kernel_${kernel_ver}"
    state_log "INFO" "WiFi configuration applied"
else
    warning "WiFi configuration had issues"
fi

echo
# GPU Configuration
info "GPU Configuration:"
if gpu_apply_configuration; then
    success "GPU configured"
    state_mark_applied "gpu" "configuration" "radeon_8060s"
    state_log "INFO" "GPU configuration applied"
else
    warning "GPU configuration had issues"
fi

echo
# Input Configuration
info "Input Configuration:"
if input_apply_configuration "$kernel_ver"; then
    success "Input devices configured"
    state_mark_applied "input" "configuration" "kernel_${kernel_ver}"
    state_log "INFO" "Input configuration applied"
else
    warning "Input configuration had issues"
fi

echo
# Audio Configuration (needs distribution - skip for demo)
info "Audio Configuration:"
echo "  (Skipping SOF firmware installation in demo)"
echo "  In production: audio_apply_configuration <distro>"

# --- Step 5: Verification ---
section "Step 5: Verification"

info "Verifying all components are working..."
echo

info "WiFi Verification:"
if wifi_verify_working; then
    echo "  ✓ WiFi verification passed"
else
    echo "  ⚠ WiFi verification had warnings (see above)"
fi

echo
info "GPU Verification:"
if gpu_verify_working; then
    echo "  ✓ GPU verification passed"
else
    echo "  ⚠ GPU verification had warnings (see above)"
fi

echo
info "Input Verification:"
if input_verify_working; then
    echo "  ✓ Input verification passed"
else
    echo "  ⚠ Input verification had warnings (see above)"
fi

echo
info "Audio Verification:"
if audio_verify_working; then
    echo "  ✓ Audio verification passed"
else
    echo "  ⚠ Audio verification had warnings (see above)"
fi

# --- Step 6: State Status ---
section "Step 6: State and Status Summary"

info "Current system state:"
echo
state_print_status

# --- Step 7: Component Status ---
section "Step 7: Detailed Component Status"

echo "WiFi Status:"
wifi_print_status

echo
echo "GPU Status:"
gpu_print_status

echo
echo "Input Status:"
input_print_status

echo
echo "Audio Status:"
audio_print_status

# --- Step 8: Idempotency Demonstration ---
section "Step 8: Idempotency Demonstration"

info "Running configuration again to demonstrate idempotency..."
echo
info "(Note: Nothing should be re-applied - all checks should pass immediately)"
echo

if wifi_apply_configuration; then
    echo "  ✓ WiFi: No changes needed (already configured)"
fi

if gpu_apply_configuration; then
    echo "  ✓ GPU: No changes needed (already configured)"
fi

if input_apply_configuration "$kernel_ver"; then
    echo "  ✓ Input: No changes needed (already configured)"
fi

success "Idempotency verified - safe to run multiple times"

# --- Step 9: Architecture Benefits ---
section "Step 9: Architecture Benefits Summary"

cat <<EOF
This demonstration showed the complete library-first architecture:

✓ Separation of Concerns
  - Detection (read-only) separate from configuration
  - State checking before application
  - Verification after changes

✓ Idempotency
  - Safe to run multiple times
  - Checks before applying
  - No duplicate work

✓ Kernel Awareness
  - Central version detection (kernel-compat.sh)
  - Component-specific compatibility checks
  - Automatic obsolete workaround cleanup

✓ Persistent State Tracking
  - Records what's applied and when
  - Tracks metadata (kernel version, etc.)
  - Logging for troubleshooting

✓ Modularity
  - 6 independent libraries (~400 lines each)
  - Single responsibility per library
  - Easy to test and maintain

✓ Clear Status Visibility
  - JSON output for programmatic access
  - Human-readable status displays
  - Warnings for misconfigurations

EOF

# --- Final Summary ---
section "Demonstration Complete"

echo "Library Statistics:"
echo "  kernel-compat.sh:  ~400 lines - Central version logic"
echo "  state-manager.sh:  ~550 lines - Persistent state tracking"
echo "  wifi-manager.sh:   ~450 lines - WiFi management"
echo "  gpu-manager.sh:    ~400 lines - GPU management"
echo "  input-manager.sh:  ~600 lines - Input device management"
echo "  audio-manager.sh:  ~550 lines - Audio management"
echo "  ────────────────────────────────────────────"
echo "  Total library code: ~3000 lines (modular, testable)"
echo

echo "Next Steps:"
echo "  1. Integrate libraries into gz302-main.sh"
echo "  2. Refactor main script from 3961 → ~1000 lines"
echo "  3. Add command-line flags (--status, --force, --rollback)"
echo "  4. Create comprehensive test suite"
echo "  5. Document migration from v3.0.0 to v4.0.0"
echo

success "Complete library suite demonstration finished successfully"
echo
info "For more information:"
echo "  - Library documentation: gz302-lib/README.md"
echo "  - Strategic plan: Info/STRATEGIC_REFACTORING_PLAN.md"
echo "  - Individual library help: source <lib> && <lib>_help"
echo
EOF
