#!/bin/bash
# GZ302 PSR-SU Fix Script
# Version: 4.2.1
#
# This script applies the PSR-SU (Power Save Refresh - Sub-Viewport Update) disable
# fix to resolve scrolling artifacts on OLED panels in the ASUS ROG Flow Z13 (GZ302).
#
# Issues Fixed:
# - Purple/green color artifacts during scrolling
# - Digital/QR-code-like patterns visible during scrolling
# - Display microstutters during slow scrolling
#
# Fix Applied:
# - amdgpu.dcdebugmask=0x200: Disables PSR-SU (DC_DISABLE_PSR_SU)
#
# Usage:
#   sudo ./gz302-psr-su-fix.sh
#
# To verify the fix:
#   cat /etc/default/grub | grep dcdebugmask
#
# To remove the fix (if needed):
#   sudo sed -i '/amdgpu\.dcdebugmask=0x200/d' /etc/default/grub
#   sudo update-grub

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

merge_dcdebugmask_file() {
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
    print_info "Updated existing dcdebugmask to ${merged} in ${file}"
    return 0
}

merge_runtime_debug_mask() {
    local file="$1"
    local current="0x0"
    local merged

    if [[ -r "$file" ]]; then
        current=$(cat "$file" 2>/dev/null || echo "0x0")
    fi

    printf -v merged "0x%x" $((current | 0x200))
    echo "$merged" > "$file" 2>/dev/null || true
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

print_info "Applying PSR-SU disable fix for OLED scrolling artifacts..."
print_info "Fix: amdgpu.dcdebugmask=0x200"

# Check if GRUB is configured
if [[ -f /etc/default/grub ]]; then
    print_info "Found GRUB configuration"

    if grep -q "amdgpu.dcdebugmask=" /etc/default/grub 2>/dev/null; then
        print_warning "dcdebugmask already present in GRUB; merging PSR-SU bit"
        merge_dcdebugmask_file /etc/default/grub
    else
        print_info "Adding amdgpu.dcdebugmask=0x200 to GRUB..."

        # Add new parameter to GRUB_CMDLINE_LINUX_DEFAULT
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
            sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amdgpu.dcdebugmask=0x200"/' /etc/default/grub
            print_info "GRUB_CMDLINE_LINUX_DEFAULT updated"
        else
            print_error "Could not find GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
            exit 1
        fi
    fi

    print_info "Regenerating GRUB configuration..."
    if command -v grub-mkconfig >/dev/null 2>&1; then
        if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
            print_info "GRUB configuration regenerated successfully"
        else
            print_warning "Failed to regenerate GRUB - manual update may be required"
            print_info "Run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
        fi
    else
        print_warning "grub-mkconfig not found - manual update required"
        print_info "Run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi
else
    print_warning "GRUB configuration not found at /etc/default/grub"
    print_info "Trying systemd-boot..."

    # Check systemd-boot
    if [[ -f /etc/kernel/cmdline ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/kernel/cmdline 2>/dev/null; then
            print_warning "dcdebugmask already present in systemd-boot; merging PSR-SU bit"
            merge_dcdebugmask_file /etc/kernel/cmdline
        else
            print_info "Adding amdgpu.dcdebugmask=0x200 to systemd-boot..."
            if [[ -s /etc/kernel/cmdline ]]; then
                echo " amdgpu.dcdebugmask=0x200" >> /etc/kernel/cmdline
            else
                echo "amdgpu.dcdebugmask=0x200" > /etc/kernel/cmdline
            fi
            print_info "systemd-boot configuration updated"
        fi

        if command -v mkinitcpio >/dev/null 2>&1; then
            mkinitcpio -P 2>/dev/null || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --regenerate-all -f 2>/dev/null || true
        elif command -v kernel-install >/dev/null 2>&1; then
            kernel-install add "$(uname -r)" "/lib/modules/$(uname -r)/vmlinuz" 2>/dev/null || true
        fi
    else
        print_error "No bootloader configuration found"
        print_info "Manual configuration required"
        exit 1
    fi
fi

# Apply runtime fix (if possible)
print_info "Applying runtime PSR-SU disable..."
if [[ -d /sys/kernel/debug/dri ]]; then
    for dri_dir in /sys/kernel/debug/dri/*/; do
        debug_mask=""
        if [[ -d "$dri_dir" ]]; then
            debug_mask="${dri_dir}amdgpu_dm_debug_mask"
            if [[ -w "$debug_mask" ]]; then
                merge_runtime_debug_mask "$debug_mask"
                print_info "Runtime PSR-SU disable applied"
            fi
        fi
    done
else
    print_warning "Debugfs not available - runtime fix not applied"
fi

print_info ""
print_info "PSR-SU fix applied successfully!"
print_info ""
print_info "What was fixed:"
print_info "  - PSR-SU (Power Save Refresh - Sub-Viewport Update) disabled"
print_info "  - Scrolling artifacts on OLED panels should be resolved"
print_info "  - Purple/green color shifts during scrolling should be eliminated"
print_info ""
print_info "Reboot required to apply changes permanently."
print_info ""
print_info "To verify the fix after reboot:"
print_info "  grep dcdebugmask /etc/default/grub"
print_info ""
print_info "To remove the fix (if needed):"
print_info "  sudo sed -i '/amdgpu\.dcdebugmask=0x200/d' /etc/default/grub"
print_info "  sudo update-grub"
print_info ""
