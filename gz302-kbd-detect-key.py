#!/usr/bin/env python3
"""
GZ302 Keyboard Key Code Detector
Helps identify the correct ASUS function key codes for keyboard brightness control.
Run as: sudo python3 gz302-kbd-detect-key.py

This tool captures raw input events and displays all key codes.
Press FN+F11 (or other function keys) and note the code value.
Then update gz302-kbd-backlight-listener.py with the correct code.
"""

import struct
import sys
import os

def detect_key_codes(event_device: str = "/dev/input/event10", max_events: int = 100):
    """
    Detect key codes from ASUS WMI input device.
    
    Args:
        event_device: Path to the input event device
        max_events: Maximum number of events to capture
    """
    # Common key names for reference
    KEY_NAMES = {
        1: "ESC", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9",
        11: "0", 12: "-", 13: "=", 15: "TAB", 16: "Q", 17: "W", 18: "E", 19: "R", 20: "T",
        21: "Y", 22: "U", 23: "I", 24: "O", 25: "P", 26: "[", 27: "]", 28: "ENTER",
        29: "LCTRL", 30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J",
        37: "K", 38: "L", 39: ";", 40: "'", 41: "`", 42: "LSHIFT", 43: "\\",
        44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M", 51: ",",
        52: ".", 53: "/", 54: "RSHIFT", 55: "*", 56: "LALT", 57: "SPACE", 58: "CAPS",
        59: "F1", 60: "F2", 61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8",
        67: "F9", 68: "F10", 69: "NUMLOCK", 70: "SCROLLLOCK",
        87: "F11", 88: "F12", 89: "F13", 90: "F14", 91: "F15",
        92: "F16", 93: "F17", 94: "F18", 95: "F19", 96: "F20",
        224: "LMETA", 225: "RMETA", 226: "MENU",
        240: "BRIGHTNESS_MIN",
        241: "BRIGHTNESS_POWER",
        244: "BRIGHTNESS_DOWN",
        245: "BRIGHTNESS_UP",
        259: "BRIGHTNESS_CYCLE",
    }
    
    if os.geteuid() != 0:
        print("Error: Must run as root (use: sudo python3 gz302-kbd-detect-key.py)")
        sys.exit(1)
    
    try:
        with open(event_device, 'rb') as f:
            print(f"\n{'='*70}")
            print(f"GZ302 Keyboard Key Code Detector")
            print(f"Device: {event_device}")
            print(f"{'='*70}\n")
            print("Press keys on your keyboard (especially FN+F11 for backlight)\n")
            print(f"{'Code':<6} | {'Name':<20} | {'Action':<10} | Notes")
            print("-" * 70)
            
            event_count = 0
            prev_code = None
            
            while event_count < max_events:
                event_data = f.read(24)
                if len(event_data) < 24:
                    continue
                
                time_sec, time_usec, etype, code, value = struct.unpack('IIHHI', event_data)
                
                # Skip synchronization events (EV_SYN)
                if etype == 0:
                    continue
                
                event_count += 1
                
                # Only show key events (EV_KEY = 1)
                if etype == 1:
                    key_name = KEY_NAMES.get(code, "UNKNOWN")
                    action = "PRESS" if value == 1 else "RELEASE" if value == 0 else f"REP({value})"
                    
                    # Mark potential brightness keys
                    notes = ""
                    if code in [65, 66, 244, 245]:
                        notes = "← POSSIBLE BRIGHTNESS KEY"
                    elif 240 <= code <= 259:
                        notes = "← Likely brightness key"
                    
                    # Highlight key presses
                    if value == 1:  # Only show presses
                        print(f"{code:<6} | {key_name:<20} | {action:<10} | {notes}")
                        prev_code = code
            
            print(f"\n{'='*70}")
            print("Detection complete!")
            print("\nIf you pressed FN+F11 for brightness, note the code above.")
            print("Update gz302-kbd-backlight-listener.py with the code in BRIGHTNESS_KEYS.")
            print(f"{'='*70}\n")
    
    except PermissionError:
        print("Error: Need root access to read keyboard events")
        print("Run with sudo: sudo python3 gz302-kbd-detect-key.py")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: Input device not found: {event_device}")
        print("\nAvailable ASUS input devices:")
        os.system("ls -la /dev/input/by-path/ | grep asus")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nDetection stopped by user.")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    detect_key_codes()
