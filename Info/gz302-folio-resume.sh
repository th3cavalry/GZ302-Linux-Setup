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
