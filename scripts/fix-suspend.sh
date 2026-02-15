#!/bin/bash
# GZ302 Suspend Fix Installer
# Fixes: "mmc0: error -110 writing Power Off Notify bit" blocking suspend

set -e

HOOK_PATH="/usr/lib/systemd/system-sleep/gz302-reset.sh"

echo "Installing suspend fix for MMC timeout issue..."
echo "This will update: $HOOK_PATH"
echo ""

sudo tee "$HOOK_PATH" > /dev/null << 'EOF'
#!/bin/bash
# GZ302 Suspend/Resume Hook (Optimized)
# Handles MMC suspend issues, resets USB devices on resume to fix touchpad and RGB
# v2.2 - Added MMC unbind/rebind to fix suspend timeout

MMC_DRIVER_PATH="/sys/bus/mmc/drivers/mmcblk"
MMC_STATE_FILE="/run/gz302-mmc-devices"

case "$1" in
    pre)
        # Unbind MMC devices before suspend to prevent "Power Off Notify" timeout
        # This fixes: "mmc0: error -110 writing Power Off Notify bit"
        logger -t gz302-reset "Preparing for suspend, unbinding MMC devices..."
        > "$MMC_STATE_FILE"
        
        if [[ -d "$MMC_DRIVER_PATH" ]]; then
            for dev in "$MMC_DRIVER_PATH"/mmc*; do
                [[ -e "$dev" ]] || continue
                dev_name=$(basename "$dev")
                # Check if device is not mounted as root
                if ! mount | grep -q "^/dev/${dev_name}"; then
                    logger -t gz302-reset "Unbinding $dev_name"
                    echo "$dev_name" >> "$MMC_STATE_FILE"
                    echo "$dev_name" > "$MMC_DRIVER_PATH/unbind" 2>/dev/null || true
                fi
            done
        fi
        ;;
    post)
        logger -t gz302-reset "Resume detected, rebinding MMC and resetting USB devices..."
        
        # Rebind MMC devices that were unbound
        if [[ -f "$MMC_STATE_FILE" ]]; then
            while read -r dev_name; do
                [[ -n "$dev_name" ]] || continue
                logger -t gz302-reset "Rebinding $dev_name"
                echo "$dev_name" > "$MMC_DRIVER_PATH/bind" 2>/dev/null || true
            done < "$MMC_STATE_FILE"
            rm -f "$MMC_STATE_FILE"
        fi
        
        # Single pass through USB devices - reset both keyboard and lightbar
        # Product IDs: 1a30 = Keyboard/Touchpad, 18c6 = Lightbar
        for dev in /sys/bus/usb/devices/*; do
            [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
            vid=$(<"$dev/idVendor")
            pid=$(<"$dev/idProduct")
            
            # Only process ASUS devices (0b05)
            [[ "$vid" == "0b05" ]] || continue
            
            case "$pid" in
                1a30)
                    # Keyboard/Touchpad - fixes touchpad not working after sleep
                    logger -t gz302-reset "Resetting keyboard/touchpad at $dev"
                    echo 0 > "$dev/authorized"
                    sleep 0.1
                    echo 1 > "$dev/authorized"
                    ;;
                18c6)
                    # Lightbar - ensures RGB commands work
                    logger -t gz302-reset "Resetting lightbar at $dev"
                    echo 0 > "$dev/authorized"
                    sleep 0.1
                    echo 1 > "$dev/authorized"
                    ;;
            esac
        done
        
        # Wait for USB devices to fully reinitialize, then restore RGB
        sleep 1
        logger -t gz302-reset "Restoring RGB settings..."
        /usr/local/bin/gz302-rgb-restore 2>&1 | logger -t gz302-rgb-restore || true
        logger -t gz302-reset "Resume hook completed"
        ;;
esac
exit 0
EOF

sudo chmod +x "$HOOK_PATH"
echo ""
echo "✓ Suspend fix installed!"
echo ""
echo "The fix unbinds the internal SD card (mmcblk0) before suspend to prevent"
echo "the 'Power Off Notify' timeout that was blocking sleep."
echo ""
echo "Try suspending now to test."
