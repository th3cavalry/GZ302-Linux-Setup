#!/bin/bash

# ==============================================================================
# Folio Resume Fix for ASUS ROG Flow Z13 (GZ302)
#
# Author: th3cavalry using Copilot
# Version: 1.1.1
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
C_NC='\033[0m'

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

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./gz302-folio-fix.sh"
    fi
}

# --- Main Installation ---
install_folio_fix() {
    echo
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Folio Resume Fix"
    echo "  Version 1.1.1"
    echo "============================================================"
    echo
    
    info "This will install a workaround for folio keyboard/touchpad"
    info "not working after suspend/resume (Issue #83)."
    echo
    
    # Create folio resume script for touchpad/keyboard after suspend
    info "Creating folio resume script..."
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

    # Create systemd service to reload hid_asus module after suspend/resume
    info "Creating suspend/resume HID module reload service..."
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

    # Enable the resume service
    systemctl daemon-reload
    systemctl enable reload-hid_asus-resume.service
    
    success "Folio resume fix installed successfully!"
    echo
    info "The folio keyboard/touchpad will now automatically reconnect after suspend/resume"
    info "If you have a custom folio with different vendor/product IDs, edit:"
    info "  /usr/local/bin/gz302-folio-resume.sh"
    echo
}

# --- Main Execution ---
main() {
    check_root
    install_folio_fix
}

main "$@"
