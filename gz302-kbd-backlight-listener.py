#!/usr/bin/env python3
"""
GZ302 Keyboard Backlight Physical Button Listener
Listens to ASUS function key events and cycles keyboard backlight brightness.
Designed to run as a systemd service for physical FN+F11 key support.

Installation:
  1. Place this script in /usr/local/bin/gz302-kbd-backlight-listener
  2. Create systemd service: /etc/systemd/system/gz302-kbd-backlight-listener.service
  3. Enable with: systemctl enable --now gz302-kbd-backlight-listener.service

Key codes for ASUS ROG Flow Z13 (GZ302):
  - FN+F11 (Keyboard Backlight): Typically code 65, 66, 244, or 245
  - The actual code varies by ASUS model and firmware
  - Use `gz302-kbd-detect-key` to identify your system's key code
"""

import struct
import sys
import os
import syslog
from pathlib import Path
from typing import Dict, Optional

class KeyboardBacklightListener:
    """Monitor ASUS input events and control keyboard backlight"""
    
    # Event types
    EV_SYN = 0
    EV_KEY = 1
    
    # Common brightness key codes (can be customized per system)
    BRIGHTNESS_KEYS = {
        65: "toggle",      # Code 65 - toggles or cycles
        66: "toggle",      # Code 66 - alternative
        244: "down",       # Code 244 - decrease
        245: "up",         # Code 245 - increase
        # F11 function key can also be: 87 (F11), 65 (F13 alternative)
        87: "toggle",      # F11 key
    }
    
    def __init__(self, event_device: str = "/dev/input/event10", use_syslog: bool = True):
        """
        Initialize the keyboard backlight listener.
        
        Args:
            event_device: Path to ASUS WMI input event device
            use_syslog: Whether to log to syslog (for systemd service)
        """
        self.event_device = event_device
        self.brightness_path = Path("/sys/class/leds/asus::kbd_backlight/brightness")
        self.current_level = 0
        self.use_syslog = use_syslog
        
        if use_syslog:
            syslog.openlog("gz302-kbd-listener", syslog.LOG_PID, syslog.LOG_USER)
        
        self._load_current_brightness()
    
    def _log(self, message: str, level: str = "INFO"):
        """Log message to syslog or stderr"""
        if self.use_syslog:
            priority = {
                "DEBUG": syslog.LOG_DEBUG,
                "INFO": syslog.LOG_INFO,
                "WARNING": syslog.LOG_WARNING,
                "ERROR": syslog.LOG_ERR,
            }.get(level, syslog.LOG_INFO)
            syslog.syslog(priority, message)
        else:
            print(f"[{level}] {message}", file=sys.stderr)
    
    def _load_current_brightness(self):
        """Load current brightness level from sysfs"""
        try:
            if self.brightness_path.exists():
                self.current_level = int(self.brightness_path.read_text().strip())
        except Exception as e:
            self._log(f"Failed to load brightness: {e}", "WARNING")
            self.current_level = 0
    
    def _set_brightness(self, level: int) -> bool:
        """
        Set keyboard backlight brightness (0-3).
        
        Args:
            level: Brightness level (0=Off, 1=Level1, 2=Level2, 3=Level3)
            
        Returns:
            True if successful, False otherwise
        """
        level = max(0, min(3, level))  # Clamp to 0-3
        
        try:
            # Try direct write first
            self.brightness_path.write_text(str(level))
            self.current_level = level
            self._log(f"Brightness set to level {level}")
            return True
        except PermissionError:
            # Fall back to sudo for unprivileged execution
            result = os.system(f'sudo bash -c "echo {level} > {self.brightness_path}" 2>/dev/null')
            if result == 0:
                self.current_level = level
                self._log(f"Brightness set to level {level} (via sudo)")
                return True
            else:
                self._log(f"Failed to set brightness to {level} (permission denied)", "ERROR")
                return False
        except Exception as e:
            self._log(f"Error setting brightness: {e}", "ERROR")
            return False
    
    def _cycle_brightness(self, direction: Optional[str] = None) -> None:
        """
        Cycle keyboard backlight brightness.
        
        Args:
            direction: "up", "down", or None to cycle forward (0->1->2->3->0)
        """
        if direction == "up":
            next_level = (self.current_level + 1) % 4
        elif direction == "down":
            next_level = (self.current_level - 1) % 4
        else:  # Default: cycle forward
            next_level = (self.current_level + 1) % 4
        
        self._set_brightness(next_level)
    
    def listen(self) -> None:
        """
        Listen for input events and handle keyboard brightness key presses.
        Runs indefinitely until interrupted.
        """
        self._log("Starting keyboard backlight listener")
        
        try:
            with open(self.event_device, 'rb') as f:
                self._log(f"Listening on {self.event_device} for brightness key events")
                
                while True:
                    # Read input event (24 bytes: sec(4), usec(4), type(2), code(2), value(4))
                    event_data = f.read(24)
                    if len(event_data) < 24:
                        continue
                    
                    time_sec, time_usec, etype, code, value = struct.unpack('IIHHI', event_data)
                    
                    # Handle key press events (EV_KEY = 1, value = 1 means pressed)
                    if etype == self.EV_KEY and code in self.BRIGHTNESS_KEYS and value == 1:
                        action = self.BRIGHTNESS_KEYS[code]
                        self._log(f"Brightness key pressed (code={code}, action={action})")
                        
                        if action == "toggle":
                            self._cycle_brightness()
                        elif action == "up":
                            self._cycle_brightness("up")
                        elif action == "down":
                            self._cycle_brightness("down")
        
        except PermissionError:
            self._log("Need root access to read keyboard events. Run with sudo or as root.", "ERROR")
            sys.exit(1)
        except FileNotFoundError:
            self._log(f"Input device not found: {self.event_device}. Check if device exists.", "ERROR")
            sys.exit(1)
        except KeyboardInterrupt:
            self._log("Listener stopped by user")
            sys.exit(0)
        except Exception as e:
            self._log(f"Unexpected error: {e}", "ERROR")
            sys.exit(1)

def main():
    """Main entry point"""
    # Check if running as root (required for event device access)
    if os.geteuid() != 0:
        print("Error: This script must be run as root (use sudo or systemd service)", file=sys.stderr)
        sys.exit(1)
    
    # Create and start listener
    listener = KeyboardBacklightListener(use_syslog=True)
    listener.listen()

if __name__ == "__main__":
    main()
