#!/bin/bash
# shellcheck disable=SC2034,SC2059

# ==============================================================================
# GZ302 GPU Manager Library
# Version: 3.0.0
#
# This library manages AMD Radeon 8060S (RDNA 3.5) integrated GPU configuration
# for the GZ302 (Strix Halo platform).
#
# Key Features:
# - GPU hardware detection
# - Firmware verification
# - Power feature mask configuration
# - Kernel parameter management
# - ROCm compatibility setup
#
# Usage:
#   source gz302-lib/gpu-manager.sh
#   gpu_detect_hardware
#   gpu_apply_configuration
#   gpu_verify_firmware
# ==============================================================================

# --- GPU Hardware Detection ---

# Detect AMD Radeon 8060S GPU
# Returns: 0 if found, 1 if not found
# Output: GPU information if found
gpu_detect_hardware() {
    # Radeon 8060S is integrated - check for Strix Halo device
    # PCI ID may vary, look for AMD/ATI device
    if lspci | grep -qi "VGA.*AMD\|Display.*AMD"; then
        local gpu_info
        gpu_info=$(lspci | grep -i "VGA.*AMD\|Display.*AMD")
        echo "$gpu_info"
        return 0
    else
        return 1
    fi
}

# Get GPU device ID
# Returns: Device ID string or "unknown"
gpu_get_device_id() {
    local device_id
    device_id=$(lspci -nn | grep -i "VGA.*AMD\|Display.*AMD" | grep -oP '\[[\da-f]{4}:[\da-f]{4}\]' | head -1 | tr -d '[]')
    if [[ -n "$device_id" ]]; then
        echo "$device_id"
    else
        echo "unknown"
    fi
}

# Check if amdgpu kernel module is loaded
# Returns: 0 if loaded, 1 if not loaded
gpu_module_loaded() {
    lsmod | grep -q "^amdgpu"
}

# Get GPU firmware directory
# Returns: Path to firmware directory
gpu_get_firmware_dir() {
    echo "/lib/firmware/amdgpu"
}

# --- Firmware Verification ---

# Check if specific firmware file exists
# Args: $1 = firmware filename
# Returns: 0 if exists, 1 if not found
gpu_firmware_exists() {
    local fw_file="$1"
    local fw_dir
    fw_dir=$(gpu_get_firmware_dir)
    
    # Check for uncompressed, zst, or xz compressed versions
    if [[ -f "$fw_dir/$fw_file" ]] || \
       [[ -f "$fw_dir/${fw_file}.zst" ]] || \
       [[ -f "$fw_dir/${fw_file}.xz" ]]; then
        return 0
    else
        return 1
    fi
}

# Verify all required GPU firmware files
# Returns: 0 if all present, 1 if any missing
# Output: Status of each firmware file
gpu_verify_firmware() {
    local all_present=true
    
    # RDNA 3.5 / GC 11.5 firmware files for Radeon 8060S
    local required_files=(
        "gc_11_5_1_pfp.bin"          # Graphics Command Processor - Prefetch
        "gc_11_5_1_me.bin"           # Graphics Command Processor - Microengine
        "gc_11_5_1_rlc.bin"          # RunList Controller
        "gc_11_5_1_mec.bin"          # MicroEngine Compute
        "dcn_3_5_1_dmcub.bin"        # Display Core Next - DMCU microcode
        "psp_14_0_4_ta.bin"          # Platform Security Processor - Trusted Apps
        "psp_14_0_4_toc.bin"         # PSP Table of Contents
        "sdma_6_1_0.bin"             # System DMA Engine
    )
    
    echo "GPU Firmware Verification:"
    for fw_file in "${required_files[@]}"; do
        if gpu_firmware_exists "$fw_file"; then
            echo "  ✓ $fw_file"
        else
            echo "  ✗ $fw_file (missing or may be in initramfs)"
            all_present=false
        fi
    done
    
    if [[ "$all_present" == true ]]; then
        return 0
    else
        return 1
    fi
}

# --- Configuration State Detection ---

# Check if amdgpu ppfeaturemask is configured
# Returns: 0 if configured, 1 if not configured
gpu_ppfeaturemask_configured() {
    if [[ -f /etc/modprobe.d/amdgpu.conf ]]; then
        if grep -q "ppfeaturemask=0xffffffff" /etc/modprobe.d/amdgpu.conf 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get current ppfeaturemask value
# Returns: Current value or "not_set"
gpu_get_ppfeaturemask() {
    if [[ -f /sys/module/amdgpu/parameters/ppfeaturemask ]]; then
        cat /sys/module/amdgpu/parameters/ppfeaturemask
    else
        echo "not_set"
    fi
}

# Check if GPU kernel parameters are set in bootloader
# Returns: 0 if set, 1 if not set
gpu_kernel_params_set() {
    local grub_set=false
    local cmdline_set=false
    
    # Check GRUB
    if [[ -f /etc/default/grub ]]; then
        if grep -q "amdgpu.ppfeaturemask=0xffffffff" /etc/default/grub 2>/dev/null; then
            grub_set=true
        fi
    fi
    
    # Check kernel cmdline (systemd-boot)
    if [[ -f /etc/kernel/cmdline ]]; then
        if grep -q "amdgpu.ppfeaturemask=0xffffffff" /etc/kernel/cmdline 2>/dev/null; then
            cmdline_set=true
        fi
    fi
    
    # Return true if either is set
    [[ "$grub_set" == true ]] || [[ "$cmdline_set" == true ]]
}

# Get comprehensive GPU state
# Output: JSON-like state information
gpu_get_state() {
    local hardware_present="false"
    local module_loaded="false"
    local ppfeaturemask_configured="false"
    local kernel_params_set="false"
    local firmware_complete="false"
    local device_id="unknown"
    
    if gpu_detect_hardware >/dev/null 2>&1; then
        hardware_present="true"
        device_id=$(gpu_get_device_id)
    fi
    
    if gpu_module_loaded; then
        module_loaded="true"
    fi
    
    if gpu_ppfeaturemask_configured; then
        ppfeaturemask_configured="true"
    fi
    
    if gpu_kernel_params_set; then
        kernel_params_set="true"
    fi
    
    if gpu_verify_firmware >/dev/null 2>&1; then
        firmware_complete="true"
    fi
    
    cat <<EOF
{
    "hardware_present": "$hardware_present",
    "device_id": "$device_id",
    "module_loaded": "$module_loaded",
    "ppfeaturemask_configured": "$ppfeaturemask_configured",
    "kernel_params_set": "$kernel_params_set",
    "firmware_complete": "$firmware_complete",
    "current_ppfeaturemask": "$(gpu_get_ppfeaturemask)"
}
EOF
}

# --- Configuration Application (Idempotent) ---

# Apply amdgpu modprobe configuration (idempotent)
# Returns: 0 if applied or already applied
gpu_apply_modprobe_config() {
    # Check if already configured
    if gpu_ppfeaturemask_configured; then
        return 0  # Already configured
    fi
    
    # Create modprobe configuration
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
# AMD GPU configuration for Radeon 8060S (RDNA 3.5, integrated)
# Strix Halo specific: Phoenix/Navi33 equivalent
# Enable all power features for better performance and efficiency
# ROCm-compatible for AI/ML workloads
# ppfeaturemask=0xffffffff enables: PowerPlay, DPM, OverDrive, GFXOFF, etc.
options amdgpu ppfeaturemask=0xffffffff
EOF
    
    # Verify creation
    if [[ ! -f /etc/modprobe.d/amdgpu.conf ]]; then
        return 1
    fi
    
    return 0
}

# Apply GPU configuration (modprobe only)
# Returns: 0 on success
# Output: Status messages
# Note: Kernel parameters handled by main script bootloader logic
gpu_apply_configuration() {
    echo "Configuring AMD Radeon 8060S GPU (RDNA 3.5)..."
    
    if ! gpu_apply_modprobe_config; then
        echo "ERROR: Failed to apply GPU modprobe configuration"
        return 1
    fi
    
    if gpu_ppfeaturemask_configured; then
        echo "GPU ppfeaturemask configured successfully"
    else
        echo "WARNING: GPU configuration may not have applied"
        return 1
    fi
    
    return 0
}

# --- Verification Functions ---

# Verify GPU is working correctly
# Returns: 0 if working, 1 if issues detected
# Output: Status information
gpu_verify_working() {
    local status=0
    
    # Check hardware present
    if ! gpu_detect_hardware >/dev/null 2>&1; then
        echo "ERROR: AMD GPU not detected"
        return 1
    fi
    
    # Check module loaded
    if ! gpu_module_loaded; then
        echo "WARNING: amdgpu kernel module not loaded"
        status=1
    fi
    
    # Check for kernel errors
    if dmesg | tail -200 | grep -qi "amdgpu.*error\|amdgpu.*fail"; then
        echo "WARNING: Recent GPU errors in kernel log"
        status=1
    fi
    
    # Check DRM device exists
    if [[ ! -d /sys/class/drm/card0 ]]; then
        echo "WARNING: DRM device not found"
        status=1
    fi
    
    if [[ $status -eq 0 ]]; then
        echo "GPU verification passed"
    fi
    
    return $status
}

# --- Status Functions ---

# Print comprehensive GPU status (for user display)
# Output: Formatted status information
gpu_print_status() {
    local state
    state=$(gpu_get_state)
    
    local hardware_present
    local device_id
    local module_loaded
    local ppfeaturemask_configured
    local firmware_complete
    local current_mask
    
    hardware_present=$(echo "$state" | grep "hardware_present" | cut -d'"' -f4)
    device_id=$(echo "$state" | grep "device_id" | cut -d'"' -f4)
    module_loaded=$(echo "$state" | grep "module_loaded" | cut -d'"' -f4)
    ppfeaturemask_configured=$(echo "$state" | grep "ppfeaturemask_configured" | cut -d'"' -f4)
    firmware_complete=$(echo "$state" | grep "firmware_complete" | cut -d'"' -f4)
    current_mask=$(echo "$state" | grep "current_ppfeaturemask" | cut -d'"' -f4)
    
    echo "GPU Status (AMD Radeon 8060S):"
    echo "  Hardware Present:    $hardware_present"
    echo "  Device ID:           $device_id"
    echo "  Module Loaded:       $module_loaded"
    echo "  PPFeatureMask:       $ppfeaturemask_configured"
    echo "  Current Mask:        $current_mask"
    echo "  Firmware Complete:   $firmware_complete"
    
    # Check for issues
    if [[ "$ppfeaturemask_configured" == "false" ]]; then
        echo "  ⚠️  WARNING: PPFeatureMask not configured"
        echo "      Run 'gpu_apply_configuration' to configure"
    fi
    
    if [[ "$firmware_complete" == "false" ]]; then
        echo "  ⚠️  WARNING: Some firmware files missing"
        echo "      GPU may not function optimally"
    fi
    
    if [[ "$module_loaded" == "false" && "$hardware_present" == "true" ]]; then
        echo "  ⚠️  WARNING: GPU hardware present but module not loaded"
    fi
}

# --- Library Information ---

gpu_lib_version() {
    echo "3.0.0"
}

gpu_lib_help() {
    cat <<'HELP'
GZ302 GPU Manager Library v3.0.0

Detection Functions (read-only):
  gpu_detect_hardware           - Check if Radeon 8060S present
  gpu_get_device_id             - Get GPU PCI device ID
  gpu_module_loaded             - Check if amdgpu module loaded
  gpu_get_firmware_dir          - Get firmware directory path

Firmware Functions:
  gpu_firmware_exists <file>    - Check if specific firmware file exists
  gpu_verify_firmware           - Verify all required firmware files

State Check Functions:
  gpu_ppfeaturemask_configured  - Check if ppfeaturemask is configured
  gpu_get_ppfeaturemask         - Get current ppfeaturemask value
  gpu_kernel_params_set         - Check if kernel params are set
  gpu_get_state                 - Get comprehensive state (JSON)

Configuration Functions (idempotent):
  gpu_apply_modprobe_config     - Apply modprobe configuration
  gpu_apply_configuration       - Apply complete GPU configuration

Verification Functions:
  gpu_verify_working            - Verify GPU is working correctly
  gpu_print_status              - Print formatted status (for users)

Library Information:
  gpu_lib_version               - Get library version
  gpu_lib_help                  - Show this help

Example Usage:
  source gz302-lib/gpu-manager.sh
  
  # Detect hardware
  if gpu_detect_hardware; then
      echo "GPU found"
  fi
  
  # Apply configuration
  gpu_apply_configuration
  
  # Verify firmware
  gpu_verify_firmware
  
  # Check status
  gpu_print_status

GPU Details:
  Model: AMD Radeon 8060S
  Architecture: RDNA 3.5
  Compute Units: 16
  Platform: Strix Halo (Zen 5 + RDNA 3.5)
  ROCm Compatible: Yes
  AI/ML Support: Yes (via ROCm)

Design Principles:
  - Idempotent: Safe to run multiple times
  - Read-only detection separate from configuration
  - Comprehensive firmware verification
  - Clear state reporting
HELP
}
