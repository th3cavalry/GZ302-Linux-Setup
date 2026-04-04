#!/usr/bin/env python3
"""
GZ302 Lightbar RGB Control Script
Controls the rear window RGB lighting on ASUS ROG Flow Z13 (GZ302EA)

Based on: https://github.com/rpheuts/z13
"""

import os
import sys
import glob


class LightbarController:
    """Controller for ASUS ROG Flow Z13 rear window RGB lighting"""
    
    # USB device IDs for ASUS HID devices
    KEYBOARD_VENDOR_ID = "0b05"
    KEYBOARD_PRODUCT_ID = "1a30"
    LIGHTBAR_PRODUCT_ID = "18c6"
    
    # HID device paths
    LIGHTBAR_SIGNATURE = "usb-0000:c6:00.0-5/input0"
    
    def __init__(self):
        self.lightbar_device = self._find_lightbar_device()
    
    def _find_lightbar_device(self):
        """Auto-detect rear window RGB device via USB physical path"""
        for hidraw_path in glob.glob("/sys/class/hidraw/hidraw*/device/uevent"):
            try:
                with open(hidraw_path, 'r') as f:
                    content = f.read()
                    
                # Check for lightbar USB signature
                if "18c6" in content and self.LIGHTBAR_SIGNATURE.split("-")[0] in content:
                    # Extract hidraw device name
                    hidraw_device = os.path.basename(os.path.dirname(hidraw_path))
                    return f"/dev/{hidraw_device}"
            except (IOError, OSError):
                continue
        
        # Fallback: search by vendor/product IDs
        for device_path in glob.glob("/sys/class/hidraw/hidraw*"):
            try:
                vendor_id_file = os.path.join(device_path, "idVendor")
                product_id_file = os.path.join(device_path, "idProduct")
                
                if os.path.exists(vendor_id_file) and os.path.exists(product_id_file):
                    with open(vendor_id_file, 'r') as f:
                        vendor_id = f.read().strip()
                    with open(product_id_file, 'r') as f:
                        product_id = f.read().strip()
                    
                    if vendor_id == self.KEYBOARD_VENDOR_ID and product_id == self.LIGHTBAR_PRODUCT_ID:
                        hidraw_device = os.path.basename(device_path)
                        return f"/dev/{hidraw_device}"
            except (IOError, OSError):
                continue
        
        return None
    
    def _write_rgb_packet(self, r, g, b):
        """Write RGB color packet to lightbar device"""
        if not self.lightbar_device:
            return False
        
        try:
            # RGB color packet: [0x5d, 0xb3, 0x00, 0x00, R, G, B, 0xeb, 0x00, 0x00, 0xff, 0xff, 0xff]
            packet = bytes([
                0x5d, 0xb3, 0x00, 0x00,
                r & 0xff, g & 0xff, b & 0xff,
                0xeb, 0x00, 0x00, 0xff, 0xff, 0xff
            ])
            
            with open(self.lightbar_device, 'wb') as dev:
                dev.write(packet)
                dev.flush()
            
            return True
        except (IOError, OSError) as e:
            print(f"Error writing to lightbar device: {e}", file=sys.stderr)
            return False
    
    def turn_on(self):
        """Turn on the lightbar"""
        if not self.lightbar_device:
            return False
        
        try:
            # Turn ON packet: [0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff]
            packet = bytes([0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff])
            
            with open(self.lightbar_device, 'wb') as dev:
                dev.write(packet)
                dev.flush()
            
            return True
        except (IOError, OSError) as e:
            print(f"Error turning on lightbar: {e}", file=sys.stderr)
            return False
    
    def turn_off(self):
        """Turn off the lightbar"""
        if not self.lightbar_device:
            return False
        
        try:
            # Turn OFF packet: [0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff]
            packet = bytes([0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff])
            
            with open(self.lightbar_device, 'wb') as dev:
                dev.write(packet)
                dev.flush()
            
            return True
        except (IOError, OSError) as e:
            print(f"Error turning off lightbar: {e}", file=sys.stderr)
            return False
    
    def set_color(self, r, g, b):
        """Set lightbar to a specific RGB color"""
        if not self.lightbar_device:
            print("Lightbar device not found", file=sys.stderr)
            return False
        
        # Ensure values are in valid range
        r = max(0, min(255, r))
        g = max(0, min(255, g))
        b = max(0, min(255, b))
        
        # Turn on first
        if not self.turn_on():
            print("Failed to turn on lightbar", file=sys.stderr)
            return False
        
        # Set color
        if not self._write_rgb_packet(r, g, b):
            print("Failed to set color", file=sys.stderr)
            return False
        
        return True
    
    def is_available(self):
        """Check if lightbar controller is available"""
        return self.lightbar_device is not None


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: gz302-lightbar <command> [args]")
        print("Commands:")
        print("  on                    Turn lightbar on")
        print("  off                   Turn lightbar off")
        print("  color <r> <g> <b>     Set RGB color (0-255)")
        print("  status                Show lightbar status")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    controller = LightbarController()
    
    if command == "on":
        if controller.turn_on():
            print("Lightbar turned on")
            sys.exit(0)
        else:
            print("Failed to turn on lightbar", file=sys.stderr)
            sys.exit(1)
    
    elif command == "off":
        if controller.turn_off():
            print("Lightbar turned off")
            sys.exit(0)
        else:
            print("Failed to turn off lightbar", file=sys.stderr)
            sys.exit(1)
    
    elif command == "color":
        if len(sys.argv) < 5:
            print("Usage: gz302-lightbar color <r> <g> <b>", file=sys.stderr)
            sys.exit(1)
        
        try:
            r = int(sys.argv[2])
            g = int(sys.argv[3])
            b = int(sys.argv[4])
        except ValueError:
            print("RGB values must be integers", file=sys.stderr)
            sys.exit(1)
        
        if controller.set_color(r, g, b):
            print(f"Lightbar set to RGB({r}, {g}, {b})")
            sys.exit(0)
        else:
            print("Failed to set lightbar color", file=sys.stderr)
            sys.exit(1)
    
    elif command == "status":
        if controller.is_available():
            print("Lightbar: Available")
            print(f"Device: {controller.lightbar_device}")
        else:
            print("Lightbar: Not detected")
            print("This may be expected if your device doesn't have a rear window")
        sys.exit(0)
    
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()