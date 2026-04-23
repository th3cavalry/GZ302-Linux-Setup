#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 Display Fix Library
# Version: 5.1.3
#
# This library provides display-specific fixes for OLED panels on GZ302.
# Focuses on all eDP power-saving features that can cause display artifacts.
#
# Key Issues Addressed:
# - PSR/PSR-SU causes scrolling artifacts on OLED panels
# - Panel Replay (PR) causes flicker on OLED eDP panels
# - IPS (Idle Power States) causes intermittent display instability
# - DRAM memory stutter causes micro-glitches during display memory fetches
# - Scatter-gather display causes flicker under memory pressure on APUs
#
# Fixes Applied:
# - amdgpu.dcdebugmask=0xe12:
#   DC_DISABLE_STUTTER  (0x002) — DRAM memory stutter off
#   DC_DISABLE_PSR      (0x010) — PSR v1 + PSR-SU off
#   DC_DISABLE_PSR_SU   (0x200) — belt-and-suspenders PSR-SU disable
#   DC_DISABLE_REPLAY   (0x400) — Panel Replay off
#   DC_DISABLE_IPS      (0x800) — all Idle Power States off
# - amdgpu.sg_display=0: Scatter-gather display disabled (APU flicker)
# - amdgpu.abmlevel=0:   ABM disabled for OLED panels (DPCD capability)
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

    current=$(grep -oE 'amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)' "$file" 2>/dev/null | head -1 || true)
    if [[ -z "$current" ]]; then
        return 1
    fi

    current="${current#amdgpu.dcdebugmask=}"
    printf -v merged "0x%x" $((current | 0xe12))
    sed -i -E "s/amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)/amdgpu.dcdebugmask=${merged}/g" "$file"
    return 0
}

display_merge_runtime_debug_mask() {
    local file="$1"
    local current="0x0"
    local merged

    if [[ -r "$file" ]]; then
        current=$(cat "$file" 2>/dev/null || echo "0x0")
    fi

    printf -v merged "0x%x" $((current | 0xe12))
    echo "$merged" > "$file" 2>/dev/null || true
}

display_has_psr_su_disable_bit() {
    local file="$1"
    local token
    local value

    while read -r token; do
        value="${token#amdgpu.dcdebugmask=}"
        if (( (value & 0xe12) == 0xe12 )); then
            return 0
        fi
    done < <(grep -oE 'amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)' "$file" 2>/dev/null || true)

    return 1
}

# --- PSR-SU Detection Functions ---

# Check if PSR-SU is currently enabled
# Returns: 0 if enabled, 1 if disabled
display_psr_su_enabled() {
    # Check if dcdebugmask has all required display fix bits set (0xe12)
    if [[ -f /etc/default/grub ]]; then
        if display_has_psr_su_disable_bit /etc/default/grub; then
            return 1  # display fixes disabled
        fi
    fi
    
    # Check kernel cmdline (systemd-boot)
    if [[ -f /etc/kernel/cmdline ]]; then
        if display_has_psr_su_disable_bit /etc/kernel/cmdline; then
            return 1  # display fixes disabled
        fi
    fi

    # Check Limine bootloader configs
    local limine_cfg
    for limine_cfg in /etc/limine/limine.conf /boot/limine/limine.conf /boot/limine.cfg; do
        if [[ -f "$limine_cfg" ]]; then
            if display_has_psr_su_disable_bit "$limine_cfg"; then
                return 1  # PSR-SU disabled
            fi
        fi
    done

    # Check rEFInd per-kernel and global configs
    if [[ -f /boot/refind_linux.conf ]]; then
        if display_has_psr_su_disable_bit /boot/refind_linux.conf; then
            return 1  # PSR-SU disabled
        fi
    fi
    local refind_cfg
    for refind_cfg in /boot/EFI/refind/refind.conf /boot/efi/EFI/refind/refind.conf \
                      /efi/EFI/refind/refind.conf; do
        if [[ -f "$refind_cfg" ]]; then
            if display_has_psr_su_disable_bit "$refind_cfg"; then
                return 1  # PSR-SU disabled
            fi
        fi
    done

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

# Append/merge parameter into /etc/kernel/cmdline as a single line
display_ensure_cmdline_param() {
    local cmdline_file="$1"
    local param="$2"
    local current

    current=$(tr '\n' ' ' < "$cmdline_file" 2>/dev/null | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' || true)
    if [[ "$current" == *"$param"* ]]; then
        return 1
    fi

    if [[ -n "$current" ]]; then
        printf '%s %s\n' "$current" "$param" > "$cmdline_file"
    else
        printf '%s\n' "$param" > "$cmdline_file"
    fi

    return 0
}

# Apply PSR-SU disable fix (idempotent)
# Returns: 0 on success
display_apply_psr_su_fix() {
    info "Applying PSR-SU disable fix for OLED panel scrolling artifacts..."
    
    # Add to GRUB if present
    if [[ -f /etc/default/grub ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/default/grub 2>/dev/null; then
            info "Merging display fix bits into existing GRUB dcdebugmask..."
            display_merge_dcdebugmask_file /etc/default/grub || true
        else
            info "Adding amdgpu.dcdebugmask=0xe12 to GRUB..."
            if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
                sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amdgpu.dcdebugmask=0xe12"/' /etc/default/grub 2>/dev/null || true
            elif grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
                sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 amdgpu.dcdebugmask=0xe12"/' /etc/default/grub 2>/dev/null || true
            else
                echo 'GRUB_CMDLINE_LINUX="amdgpu.dcdebugmask=0xe12"' >> /etc/default/grub
            fi
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
            info "Merging display fix bits into existing systemd-boot dcdebugmask..."
            display_merge_dcdebugmask_file /etc/kernel/cmdline || true
        else
            info "Adding amdgpu.dcdebugmask=0xe12 to systemd-boot..."
            display_ensure_cmdline_param /etc/kernel/cmdline "amdgpu.dcdebugmask=0xe12" || true

            # Regenerate boot entries (only if mkinitcpio hasn't run yet this session)
            if command -v mkinitcpio >/dev/null 2>&1 && [[ "${GZ302_MKINITCPIO_DONE:-false}" != "true" ]]; then
                mkinitcpio -P 2>/dev/null || true
                export GZ302_MKINITCPIO_DONE=true
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
                        sed -i 's/\(options.*\)$/\1 amdgpu.dcdebugmask=0xe12/' "$entry"
                    else
                        echo "options amdgpu.dcdebugmask=0xe12" >> "$entry"
                    fi
                fi
            fi
        done
    fi

    # --- Limine ---
    local limine_cfg
    for limine_cfg in /etc/limine/limine.conf /boot/limine/limine.conf /boot/limine.cfg; do
        [[ -f "$limine_cfg" ]] || continue
        if grep -q "amdgpu.dcdebugmask=" "$limine_cfg" 2>/dev/null; then
            info "Merging display fix bits into existing Limine dcdebugmask..."
            display_merge_dcdebugmask_file "$limine_cfg" || true
        else
            info "Adding amdgpu.dcdebugmask=0xe12 to Limine config: $(basename "$limine_cfg")"
            # v5 TOML-style: "    cmdline: ..."
            if grep -qE '^\s*cmdline\s*:' "$limine_cfg"; then
                sed -i -E 's|(^\s*cmdline\s*:.*)$|\1 amdgpu.dcdebugmask=0xe12|' "$limine_cfg"
            # v4 uppercase: "CMDLINE=..."
            elif grep -q '^CMDLINE=' "$limine_cfg"; then
                sed -i 's|^\(CMDLINE=.*\)$|\1 amdgpu.dcdebugmask=0xe12|' "$limine_cfg"
            else
                warning "Limine config $(basename "$limine_cfg"): no CMDLINE/cmdline entry — add 'amdgpu.dcdebugmask=0xe12' manually"
            fi
        fi
    done

    # --- rEFInd ---
    if [[ -f /boot/refind_linux.conf ]]; then
        if grep -q "amdgpu.dcdebugmask=" /boot/refind_linux.conf 2>/dev/null; then
            info "Merging display fix bits into existing rEFInd per-kernel dcdebugmask..."
            display_merge_dcdebugmask_file /boot/refind_linux.conf || true
        else
            info "Adding amdgpu.dcdebugmask=0xe12 to refind_linux.conf..."
            # Each line: "label"  "params ..." — append to the last quoted string
            sed -i -E 's|"([^"]+)"\s*$|"\1 amdgpu.dcdebugmask=0xe12"|' /boot/refind_linux.conf
        fi
    fi
    local refind_cfg
    for refind_cfg in /boot/EFI/refind/refind.conf /boot/efi/EFI/refind/refind.conf \
                      /efi/EFI/refind/refind.conf; do
        [[ -f "$refind_cfg" ]] || continue
        if grep -q "amdgpu.dcdebugmask=" "$refind_cfg" 2>/dev/null; then
            info "Merging display fix bits into existing rEFInd global dcdebugmask..."
            display_merge_dcdebugmask_file "$refind_cfg" || true
        else
            info "Adding amdgpu.dcdebugmask=0xe12 to $(basename "$refind_cfg")..."
            sed -i 's|^\(options .*\)$|\1 amdgpu.dcdebugmask=0xe12|' "$refind_cfg"
        fi
    done
    
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
    echo "  amdgpu.dcdebugmask=0xe12 (disables PSR/PSR-SU/Replay/IPS/stutter)"
    echo "  amdgpu.sg_display=0 (disables scatter-gather display for APU)"
    echo ""
    echo "To apply fix:"
    echo "  source gz302-lib/display-fix.sh"
    echo "  display_apply_psr_su_fix"
    echo "  sudo reboot"
}

# --- Library Information ---

display_fix_lib_version() {
    echo "5.1.3"
}

display_fix_lib_help() {
    cat <<'HELP'
GZ302 Display Fix Library v5.0.2

PSR/Replay/IPS Detection Functions:
  display_psr_su_enabled        - Check if display fix bits are set
  display_psr_su_fix_applied    - Check if fix has been applied

Fix Application Functions:
  display_apply_psr_su_fix      - Apply display fix (idempotent, all bootloaders)

Verification Functions:
  display_verify_psr_su_fix     - Verify fix is working

Status Functions:
  display_print_psr_su_status   - Print current status

Library Information:
  display_fix_lib_version       - Get library version
  display_fix_lib_help          - Show this help

Display Fix Information (dcdebugmask=0xe12):
  DC_DISABLE_STUTTER (0x002)  - DRAM memory stutter off (APU LCD latency)
  DC_DISABLE_PSR     (0x010)  - PSR v1 + PSR-SU off
  DC_DISABLE_PSR_SU  (0x200)  - belt-and-suspenders PSR-SU disable
  DC_DISABLE_REPLAY  (0x400)  - Panel Replay off (eDP0 flicker)
  DC_DISABLE_IPS     (0x800)  - all Idle Power States off

  Also requires in /etc/modprobe.d/amdgpu.conf:
    options amdgpu sg_display=0   (APU scatter-gather flicker)
    options amdgpu abmlevel=0     (OLED ABM disable)

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
