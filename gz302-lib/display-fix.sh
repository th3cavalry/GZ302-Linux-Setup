#!/bin/bash
# shellcheck disable=SC2034,SC2059

# ==============================================================================
# GZ302 Display Fix Library
# Version: 4.2.1
#
# This library provides display-specific fixes for OLED panels on GZ302.
# Focuses on PSR-SU (Power Save Refresh - Sub-Viewport Update) fixes to
# prevent scrolling artifacts and purple/green color glitches.
#
# Key Issues Addressed:
# - PSR-SU causes scrolling artifacts on OLED panels
# - Purple/green color shifts during scrolling
# - Digital/QR-code-like patterns visible during scrolling
# - Display microstutters during slow scrolling
#
# Fixes Applied:
# - amdgpu.dcdebugmask=0x200: Disable PSR-SU (DC_DISABLE_PSR_SU)
# - PSR-SU disabled by default for OLED panels (kernel 6.12+)
#
# Usage:
#   source gz302-lib/display-fix.sh
#   display_fix_psr_su_enabled
#   display_apply_psr_su_fix
# ==============================================================================

display_merge_dcdebugmask_file() {
    local file="$1"
    local current
    local merged

    current=$(grep -oE 'amdgpu\.dcdebugmask=0x[0-9A-Fa-f]+' "$file" 2>/dev/null | head -1 || true)
    if [[ -z "$current" ]]; then
        return 1
    fi

    current="${current#amdgpu.dcdebugmask=}"
    printf -v merged "0x%x" $((current | 0x200))
    sed -i -E "s/amdgpu\.dcdebugmask=0x[0-9A-Fa-f]+/amdgpu.dcdebugmask=${merged}/g" "$file"
    return 0
}

display_merge_runtime_debug_mask() {
    local file="$1"
    local current="0x0"
    local merged

    if [[ -r "$file" ]]; then
        current=$(cat "$file" 2>/dev/null || echo "0x0")
    fi

    printf -v merged "0x%x" $((current | 0x200))
    echo "$merged" > "$file" 2>/dev/null || true
}

display_has_psr_su_disable_bit() {
    local file="$1"
    local token
    local value

    while read -r token; do
        value="${token#amdgpu.dcdebugmask=}"
        if (( (value & 0x200) != 0 || (value & 0x10) != 0 )); then
            return 0
        fi
    done < <(grep -oE 'amdgpu\.dcdebugmask=0x[0-9A-Fa-f]+' "$file" 2>/dev/null || true)

    return 1
}

# --- PSR-SU Detection Functions ---

# Check if PSR-SU is currently enabled
# Returns: 0 if enabled, 1 if disabled
display_psr_su_enabled() {
    # Check if dcdebugmask has PSR disable bits set (0x200 or 0x10)
    if [[ -f /etc/default/grub ]]; then
        if display_has_psr_su_disable_bit /etc/default/grub; then
            return 1  # PSR-SU disabled
        fi
    fi
    
    # Check kernel cmdline (systemd-boot)
    if [[ -f /etc/kernel/cmdline ]]; then
        if display_has_psr_su_disable_bit /etc/kernel/cmdline; then
            return 1  # PSR-SU disabled
        fi
    fi
    
    # PSR-SU is enabled by default (no PSR-disable dcdebugmask bits)
    return 0
}

# Check if PSR-SU fix has been applied
# Returns: 0 if fix applied, 1 if not applied
display_psr_su_fix_applied() {
    if display_psr_su_enabled; then
        return 1  # PSR enabled, fix not applied
    else
        return 0  # PSR disabled, fix applied
    fi
}

# --- PSR-SU Fix Application ---

# Apply PSR-SU disable fix (idempotent)
# Returns: 0 on success
display_apply_psr_su_fix() {
    info "Applying PSR-SU disable fix for OLED panel scrolling artifacts..."
    
    # Add to GRUB if present
    if [[ -f /etc/default/grub ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/default/grub 2>/dev/null; then
            info "Merging PSR-SU bit into existing GRUB dcdebugmask..."
            display_merge_dcdebugmask_file /etc/default/grub || true
        else
            info "Adding amdgpu.dcdebugmask=0x200 to GRUB..."
            # Add new parameter (before the closing quote)
            sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amdgpu.dcdebugmask=0x200"/' /etc/default/grub 2>/dev/null || true
        fi

        # Regenerate GRUB config
        if command -v grub-mkconfig >/dev/null 2>&1; then
            info "Regenerating GRUB configuration..."
            if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
                success "GRUB configuration updated"
            else
                warning "Failed to regenerate GRUB - manual update may be required"
            fi
        else
            warning "grub-mkconfig not found - manual update required"
        fi
    fi
    
    # Add to systemd-boot if present
    if [[ -f /etc/kernel/cmdline ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/kernel/cmdline 2>/dev/null; then
            info "Merging PSR-SU bit into existing systemd-boot dcdebugmask..."
            display_merge_dcdebugmask_file /etc/kernel/cmdline || true
        else
            info "Adding amdgpu.dcdebugmask=0x200 to systemd-boot..."
            # Check if file is empty or needs new line
            if [[ -s /etc/kernel/cmdline ]]; then
                echo " amdgpu.dcdebugmask=0x200" >> /etc/kernel/cmdline
            else
                echo "amdgpu.dcdebugmask=0x200" > /etc/kernel/cmdline
            fi

            # Regenerate boot entries
            if command -v mkinitcpio >/dev/null 2>&1; then
                mkinitcpio -P 2>/dev/null || true
            elif command -v dracut >/dev/null 2>&1; then
                dracut --regenerate-all -f 2>/dev/null || true
            fi
        fi

        success "systemd-boot configuration updated"
    fi
    
    # For systemd-boot with loader entries
    if [[ -d /boot/loader/entries ]]; then
        for entry in /boot/loader/entries/*.conf; do
            if [[ -f "$entry" ]]; then
                if grep -q "amdgpu.dcdebugmask=" "$entry" 2>/dev/null; then
                    display_merge_dcdebugmask_file "$entry" || true
                else
                    info "Updating bootloader entry: $(basename "$entry")"
                    # Add to options line
                    if grep -q "^options" "$entry"; then
                        sed -i 's/\(options.*\)$/\1 amdgpu.dcdebugmask=0x200/' "$entry"
                    else
                        echo "options amdgpu.dcdebugmask=0x200" >> "$entry"
                    fi
                fi
            fi
        done
    fi
    
    # Apply runtime fix (if possible)
    if [[ -d /sys/kernel/debug/dri ]]; then
        for dri_dir in /sys/kernel/debug/dri/*/; do
            if [[ -d "$dri_dir" ]]; then
                local debug_mask="${dri_dir}amdgpu_dm_debug_mask"
                if [[ -w "$debug_mask" ]]; then
                    info "Applying runtime PSR-SU disable..."
                    display_merge_runtime_debug_mask "$debug_mask"
                fi
            fi
        done
    fi
    
    success "PSR-SU fix applied successfully"
    info "Reboot required to apply changes permanently"
    
    return 0
}

# --- Verification Functions ---

# Verify PSR-SU fix is working
# Returns: 0 if working, 1 if issues detected
display_verify_psr_su_fix() {
    local status=0
    
    # Check if fix is applied
    if display_psr_su_enabled; then
        echo "  ⚠️  PSR-SU is still enabled - scrolling artifacts may occur"
        status=1
    else
        echo "  ✓ PSR-SU is disabled - scrolling artifacts should be resolved"
    fi
    
    # Check kernel version
    local kver
    kver=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kver" | cut -d. -f1)
    minor=$(echo "$kver" | cut -d. -f2)
    local version_num=$((major * 100 + minor))
    
    if [[ $version_num -ge 612 ]]; then
        echo "  ✓ Kernel 6.12+ has native PSR-SU disable on eDP panels"
    else
        echo "  ⚠️  Kernel < 6.12 - manual PSR-SU disable recommended"
        status=1
    fi
    
    return $status
}

# --- Status Functions ---

# Print PSR-SU status
display_print_psr_su_status() {
    local psr_enabled
    local fix_applied
    
    if display_psr_su_enabled; then
        psr_enabled="enabled"
    else
        psr_enabled="disabled"
    fi
    
    if display_psr_su_fix_applied; then
        fix_applied="not applied"
    else
        fix_applied="applied"
    fi
    
    echo "PSR-SU Status:"
    echo "  PSR-SU Status: $psr_enabled"
    echo "  Fix Applied: $fix_applied"
    echo ""
    
    # Check current runtime status if available
    if [[ -d /sys/kernel/debug/dri ]]; then
        echo "Runtime Status:"
        for dri_dir in /sys/kernel/debug/dri/*/; do
            if [[ -d "$dri_dir" ]]; then
                local debug_mask="${dri_dir}amdgpu_dm_debug_mask"
                if [[ -f "$debug_mask" ]]; then
                    echo "  Debug mask: $(cat "$debug_mask" 2>/dev/null || echo 'N/A')"
                fi
            fi
        done
    fi
    
    echo ""
    echo "Recommended Fix:"
    echo "  amdgpu.dcdebugmask=0x200 (disables PSR-SU)"
    echo ""
    echo "To apply fix:"
    echo "  source gz302-lib/display-fix.sh"
    echo "  display_apply_psr_su_fix"
    echo "  sudo reboot"
}

# --- Library Information ---

display_fix_lib_version() {
    echo "4.1.0"
}

display_fix_lib_help() {
    cat <<'HELP'
GZ302 Display Fix Library v4.1.0

PSR-SU Detection Functions:
  display_psr_su_enabled        - Check if PSR-SU is currently enabled
  display_psr_su_fix_applied    - Check if PSR-SU fix has been applied

PSR-SU Fix Functions:
  display_apply_psr_su_fix      - Apply PSR-SU disable fix (idempotent)

Verification Functions:
  display_verify_psr_su_fix     - Verify PSR-SU fix is working

Status Functions:
  display_print_psr_su_status   - Print PSR-SU status

Library Information:
  display_fix_lib_version       - Get library version
  display_fix_lib_help          - Show this help

PSR-SU Information:
  PSR-SU (Power Save Refresh - Sub-Viewport Update) can cause:
  - Scrolling artifacts on OLED panels
  - Purple/green color shifts
  - Digital/QR-code-like patterns
  - Display microstutters during slow scrolling

    Fix: amdgpu.dcdebugmask=0x200 disables PSR-SU
  Kernel 6.12+ has native PSR-SU disable on eDP panels

Example Usage:
  source gz302-lib/display-fix.sh
  
  # Check current status
  display_print_psr_su_status
  
  # Apply fix
  display_apply_psr_su_fix
  
  # Verify fix
  display_verify_psr_su_fix
HELP
}