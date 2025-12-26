#!/usr/bin/env python3
import sys
import os
import glob
import argparse
import time

# ROG Flow Z13 (2025) LED Driver
# Targeting specific HID interfaces via HID_PHYS

# Signatures to look for in the "HID_PHYS=" line of uevent
# USB port -4 is keyboard, -5 is rear window lightbar
# Note: input0 vs input1 may vary by kernel version
KEYBOARD_SIG = "usb-0000:c6:00.0-4/"
LIGHTBAR_SIG = "usb-0000:c6:00.0-5/"

def get_hid_phys(path):
    # Returns the physical path string from uevent
    try:
        with open(os.path.join(path, "device/uevent"), "r") as f:
            for line in f:
                if line.startswith("HID_PHYS="):
                    return line.split("=")[1].strip()
    except Exception:
        pass
    return None

def find_led_devices():
    # Scans /sys/class/leds/*kbd_backlight* for all backlight devices
    # Returns dict: {'keyboard': path, 'lightbar': path}
    devices = {}
    
    # Look for any backlight devices (includes kbd_backlight and kbd_backlight_1)
    candidates = glob.glob("/sys/class/leds/*kbd_backlight*")
    
    for path in candidates:
        phys = get_hid_phys(path)
        if not phys:
            continue
            
        if KEYBOARD_SIG in phys:
            devices['keyboard'] = path
        elif LIGHTBAR_SIG in phys:
            devices['lightbar'] = path
            
    # Fallback: if signatures don't match (different USB ports/hubs on other models)
    # try to identify by index or other heuristics if needed.
    # For now, return what we found.
    return devices

def set_brightness(device_path, value):
    if not device_path:
        return
    try:
        with open(os.path.join(device_path, "brightness"), "w") as f:
            f.write(str(value))
    except Exception as e:
        print(f"Error setting brightness for {device_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description="ROG Z13 LED Control")
    parser.add_argument("--keyboard", type=int, choices=range(0, 4), help="Set keyboard brightness (0-3)")
    parser.add_argument("--lightbar", type=int, choices=range(0, 4), help="Set lightbar brightness (0-3)")
    parser.add_argument("--list", action="store_true", help="List detected devices")
    
    args = parser.parse_args()
    
    devices = find_led_devices()
    
    if args.list:
        print("Detected devices:")
        for name, path in devices.items():
            print(f"  {name}: {path}")
            phys = get_hid_phys(path)
            print(f"    PHYS: {phys}")
        return

    if args.keyboard is not None:
        if 'keyboard' in devices:
            set_brightness(devices['keyboard'], args.keyboard)
        else:
            print("Keyboard device not found")

    if args.lightbar is not None:
        if 'lightbar' in devices:
            set_brightness(devices['lightbar'], args.lightbar)
        else:
            print("Lightbar device not found")

if __name__ == "__main__":
    main()
