#!/bin/bash

# ==============================================================================
# Folio Resume Fix for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 2.3.14
#
# This script installs a workaround for Issue #83 where the folio keyboard/
# touchpad stops working after suspend/resume and requires reconnecting.
#
# USAGE:
# 1. Make executable: chmod +x gz302-folio-fix.sh
# 2. Run with sudo: sudo ./gz302-folio-fix.sh
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BOLD_CYAN='\033[1;36m'
C_DIM='\033[2m'
C_NC='\033[0m'

# --- Symbols ---
SYMBOL_CHECK='✓'

# --- Logging functions ---
error() {
    echo -e "${C_RED}ERROR:${C_NC} $1" >&2
    exit 1
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

# --- Visual formatting functions ---
print_box() {
    local text="$1"
    local padding=4
    local text_len=${#text}
    local total_width=$((text_len + padding * 2))
    
    echo
    echo -e "${C_GREEN}╔$(printf '═%.0s' $(seq 1 $total_width))╗${C_NC}"
    echo -e "${C_GREEN}║${C_NC}$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $padding))${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}╚$(printf '═%.0s' $(seq 1 $total_width))╝${C_NC}"
    echo
}

print_section() {
    echo
    echo -e "${C_BOLD_CYAN}━━━ $1 ━━━${C_NC}"
}

print_step() {
    local step="$1"
    local total="$2"
    local desc="$3"
    echo -e "${C_BOLD_CYAN}[$step/$total]${C_NC} $desc"
}

completed_item() {
    echo -e "  ${C_GREEN}${SYMBOL_CHECK}${C_NC} $1"
}

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-folio-fix.sh"
    fi
}

# --- Main Installation ---
install_folio_fix() {
    local total_steps=3
    
    print_box "GZ302 Folio Resume Fix"
    
    info "This installs a workaround for folio keyboard/touchpad"
    echo -e "  ${C_DIM}not working after suspend/resume (Issue #83)${C_NC}"
    
    print_section "Installation"
    
    # Step 1: Create resume script
    print_step 1 $total_steps "Creating folio resume script..."
    cat > /usr/local/bin/gz302-folio-resume.sh <<'EOF'
#!/bin/bash
# Resume fix for ASUS Flow Z13 folio keyboard/touchpad after suspend
# Reloads hid_asus and attempts to rebind folio USB device

# Reload hid_asus module
modprobe -r hid_asus
sleep 1
modprobe hid_asus

# Attempt to rebind folio keyboard (auto-detect by vendor:product if possible)
# Replace these IDs with actual values if known
FOLIO_VENDOR="0b05"   # ASUS
FOLIO_PRODUCT="1e0f"  # Example product ID (replace if known)

# Find folio device path
for DEV in /sys/bus/usb/devices/*; do
  if grep -q "$FOLIO_VENDOR" "$DEV/idVendor" 2>/dev/null && grep -q "$FOLIO_PRODUCT" "$DEV/idProduct" 2>/dev/null; then
    echo "Unbinding folio keyboard: $DEV"
    echo -n $(basename "$DEV") > /sys/bus/usb/drivers/usb/unbind
    sleep 1
    echo -n $(basename "$DEV") > /sys/bus/usb/drivers/usb/bind
  fi
done

exit 0
EOF
    chmod +x /usr/local/bin/gz302-folio-resume.sh
    completed_item "Resume script created"

    # Step 2: Create systemd service
    print_step 2 $total_steps "Creating systemd resume service..."
    cat > /etc/systemd/system/reload-hid_asus-resume.service <<'EOF'
[Unit]
Description=Reload hid_asus module after resume for GZ302 Touchpad gestures
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=/bin/bash /usr/local/bin/gz302-folio-resume.sh

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF
    completed_item "Systemd service created"

    # Step 3: Enable service
    print_step 3 $total_steps "Enabling service..."
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable reload-hid_asus-resume.service >/dev/null 2>&1
    completed_item "Service enabled"
    
    print_box "Folio Resume Fix Installed"
    
    echo -e "  ${C_DIM}Folio keyboard/touchpad will auto-reconnect after suspend/resume${C_NC}"
    echo -e "  ${C_DIM}Custom device IDs: edit /usr/local/bin/gz302-folio-resume.sh${C_NC}"
    echo
}

# --- Main Execution ---
main() {
    check_root
    install_folio_fix
}

main "$@"
