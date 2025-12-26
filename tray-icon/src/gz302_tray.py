#!/usr/bin/env python3
"""
GZ302 Control Center
A system tray utility for managing power profiles, RGB, and hardware settings
on ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395
Version: 3.0.3
"""

import os
import subprocess
import sys
import threading
from datetime import datetime
from pathlib import Path

from PyQt6.QtCore import QObject, QTimer, pyqtSignal
import signal
from pathlib import Path
from PyQt6.QtGui import QAction, QIcon
from PyQt6.QtWidgets import (QApplication, QInputDialog, QMenu,
                             QSystemTrayIcon, QWidget)

# Optional: Try to import notify2 for better desktop notifications
try:
    import notify2

    NOTIFY2_AVAILABLE = True
except ImportError:
    NOTIFY2_AVAILABLE = False


class CommandResult(QObject):
    """Signal emitter for background command execution"""

    finished = pyqtSignal(int, str, str)  # returncode, stdout, stderr

    def run_command(self, cmd, timeout=30):
        """Run command in background and emit results"""
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout
            )
            self.finished.emit(result.returncode, result.stdout, result.stderr)
        except subprocess.TimeoutExpired:
            self.finished.emit(-1, "", "Command timed out")
        except Exception as e:
            self.finished.emit(-2, "", str(e))


class NotificationManager:
    """Manages desktop notifications with optional sound feedback"""

    def __init__(self, tray_icon):
        self.tray = tray_icon
        self.notify2_initialized = False

        # Try to initialize notify2 for richer notifications
        if NOTIFY2_AVAILABLE:
            try:
                notify2.init("GZ302 Control Center")
                self.notify2_initialized = True
            except Exception:
                pass

    def notify(self, title, message, icon_type="info", duration=4000, urgency="normal"):
        """
        Send a desktop notification.

        Args:
            title: Notification title
            message: Notification body
            icon_type: "info", "warning", "error", "success"
            duration: Display duration in milliseconds
            urgency: "low", "normal", "critical"
        """
        # Map icon types
        qt_icons = {
            "info": QSystemTrayIcon.MessageIcon.Information,
            "warning": QSystemTrayIcon.MessageIcon.Warning,
            "error": QSystemTrayIcon.MessageIcon.Critical,
            "success": QSystemTrayIcon.MessageIcon.Information,
        }

        # Add emoji prefix for visual feedback
        emoji_prefix = {
            "info": "ℹ️",
            "warning": "⚠️",
            "error": "❌",
            "success": "✅",
        }

        # Format message with emoji
        formatted_title = f"{emoji_prefix.get(icon_type, '')} {title}"

        # Try notify2 first for richer notifications
        if self.notify2_initialized:
            try:
                # Re-init notify2 with current app name in case it changed
                try:
                    notify2.init(self.tray.app_name)
                except Exception:
                    pass
                urgency_map = {
                    "low": notify2.URGENCY_LOW,
                    "normal": notify2.URGENCY_NORMAL,
                    "critical": notify2.URGENCY_CRITICAL,
                }
                n = notify2.Notification(formatted_title, message)
                n.set_urgency(urgency_map.get(urgency, notify2.URGENCY_NORMAL))
                n.set_timeout(duration)
                n.show()
                return
            except Exception:
                pass

        # Fallback to Qt system tray notification
        self.tray.showMessage(
            formatted_title,
            message,
            qt_icons.get(icon_type, QSystemTrayIcon.MessageIcon.Information),
            duration,
        )

    def notify_profile_change(self, profile, power_info=""):
        """Send notification for profile change with detailed info"""
        profile_info = {
            "emergency": ("🔋 Emergency Mode", "10W - Maximum battery preservation"),
            "battery": ("🔋 Battery Mode", "18W - Extended battery life"),
            "efficient": (
                "⚡ Efficient Mode",
                "30W - Light tasks with good performance",
            ),
            "balanced": ("⚖️ Balanced Mode", "40W - General computing (Default)"),
            "performance": ("🚀 Performance Mode", "55W - Heavy workloads"),
            "gaming": ("🎮 Gaming Mode", "70W - Optimized for gaming"),
            "maximum": ("💪 Maximum Mode", "90W - Peak performance"),
        }

        title, desc = profile_info.get(profile, (f"Profile: {profile}", ""))
        message = desc
        if power_info:
            message += f"\n{power_info}"

        # Prepend application name for clarity
        self.notify(f"{self.tray.app_name}: {title}", message, "success", 4000)

    def notify_error(self, title, message, hint=""):
        """Send error notification with optional hint"""
        full_message = message
        if hint:
            full_message += f"\n\n💡 Tip: {hint}"
        self.notify(f"{self.tray.app_name}: {title}", full_message, "error", 6000, "critical")


class GZ302TrayIcon(QSystemTrayIcon):
    def __init__(self, icon, parent=None):
        super().__init__(icon, parent)

        # Load config (APP_NAME, etc.) so we can update UI dynamically
        self.config_file = Path('/etc/gz302/tray.conf')
        self.app_name = "GZ302 Control Center"
        self.load_tray_config()

        # Initialize notification manager
        self.notifier = NotificationManager(self)

        # Power profiles with descriptions
        self.profiles = [
            ("🔋 Emergency (10W)", "emergency"),
            ("🔋 Battery (18W)", "battery"),
            ("⚡ Efficient (30W)", "efficient"),
            ("⚖️ Balanced (40W)", "balanced"),
            ("🚀 Performance (55W)", "performance"),
            ("🎮 Gaming (70W)", "gaming"),
            ("💪 Maximum (90W)", "maximum"),
        ]

        # Store current profile name
        self.current_profile = "balanced"

        # Track if profile was changed by user (vs auto-switch)
        self.user_initiated_change = False

        # Track last notification time to avoid spam
        self.last_notification_time = None

        # Track whether keyboard RGB binary is available
        self.rgb_available = self.check_rgb_available()

        # Register signal handler so installer can request a UI reload (SIGUSR1)
        try:
            signal.signal(signal.SIGUSR1, lambda s, f: QTimer.singleShot(0, self.reload_from_signal))
            signal.signal(signal.SIGHUP, lambda s, f: QTimer.singleShot(0, self.reload_from_signal))
        except Exception:
            pass

        # Track whether keyboard RGB binary is available
        self.rgb_available = self.check_rgb_available()

        # Create menu
        self.menu = QMenu()
        self.create_menu()
        self.setContextMenu(self.menu)

        # Update current profile on startup
        self.update_current_profile()

        # Set up timer to update profile status every 5 seconds
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_current_profile)
        self.timer.start(5000)  # 5 seconds

        # Set initial tooltip with welcome message
        self.setToolTip("GZ302 Control Center\n🚀 Ready")

        # Show startup notification
        self.notifier.notify(
            self.app_name,
            "System tray utility ready.\nRight-click to manage power, RGB, and settings.",
            "info",
            3000,
        )

        # Show the tray icon
        self.show()

    def create_menu(self):
        """Create the context menu"""
        self.menu.clear()

        # Add profile options
        for name, profile in self.profiles:
            # Add checkmark to currently active profile
            if profile == self.current_profile:
                display_name = f"✓ {name}"
            else:
                display_name = f"   {name}"

            action = QAction(display_name, self)
            action.triggered.connect(lambda checked, p=profile: self.change_profile(p))
            self.menu.addAction(action)

        self.menu.addSeparator()

        # Status action
        status_action = QAction("Show Status", self)
        status_action.triggered.connect(self.show_status)
        self.menu.addAction(status_action)

        self.menu.addSeparator()

        # Battery charge limit
        charge_limit_menu = self.menu.addMenu("Battery Charge Limit")
        if charge_limit_menu is not None:
            # Get current charge limit
            current_limit = self.get_current_charge_limit()

            # 80% option
            label_80 = (
                "✓ 80% (Recommended)"
                if current_limit == "80"
                else "   80% (Recommended)"
            )
            charge_80_action = QAction(label_80, self)
            charge_80_action.triggered.connect(lambda: self.set_charge_limit("80"))
            charge_limit_menu.addAction(charge_80_action)

            # 100% option
            label_100 = (
                "✓ 100% (Maximum)" if current_limit == "100" else "   100% (Maximum)"
            )
            charge_100_action = QAction(label_100, self)
            charge_100_action.triggered.connect(lambda: self.set_charge_limit("100"))
            charge_limit_menu.addAction(charge_100_action)

        # Keyboard brightness
        brightness_menu = self.menu.addMenu("Keyboard Brightness")
        if brightness_menu is not None:
            for level in range(4):
                if level == 0:
                    label = f"Off"
                else:
                    label = f"Level {level}"
                action = QAction(label, self)
                action.triggered.connect(
                    lambda checked, l=level: self.set_keyboard_backlight(l)
                )
                brightness_menu.addAction(action)

        self.menu.addSeparator()

        # Keyboard RGB Colors
        if self.rgb_available:
            rgb_menu = self.menu.addMenu("Keyboard RGB")
            if rgb_menu is not None:
                # Static colors submenu
                colors_submenu = rgb_menu.addMenu("Static Colors")
                color_options = [
                    ("Red", "FF0000"),
                    ("Green", "00FF00"),
                    ("Blue", "0000FF"),
                    ("Yellow", "FFFF00"),
                    ("Cyan", "00FFFF"),
                    ("Magenta", "FF00FF"),
                    ("White", "FFFFFF"),
                    ("Black", "000000"),
                ]
                for color_name, hex_value in color_options:
                    action = QAction(color_name, self)
                    action.triggered.connect(
                        lambda checked, h=hex_value: self.set_rgb_color(h)
                    )
                    colors_submenu.addAction(action)

                rgb_menu.addSeparator()

                # Animations submenu
                animations_submenu = rgb_menu.addMenu("Animations")

                # Breathing animation
                breathing_action = QAction("Breathing (Red)", self)
                breathing_action.triggered.connect(
                    lambda: self.set_rgb_animation("breathing", "FF0000", "000000", 2)
                )
                animations_submenu.addAction(breathing_action)

                # Color cycle
                cycle_action = QAction("Color Cycle", self)
                cycle_action.triggered.connect(
                    lambda: self.set_rgb_animation("colorcycle", None, None, 2)
                )
                animations_submenu.addAction(cycle_action)

                # Rainbow
                rainbow_action = QAction("Rainbow", self)
                rainbow_action.triggered.connect(
                    lambda: self.set_rgb_animation("rainbow", None, None, 2)
                )
                animations_submenu.addAction(rainbow_action)

                rgb_menu.addSeparator()

                # Custom color
                custom_action = QAction("Custom Color...", self)
                custom_action.triggered.connect(self.set_custom_rgb_color)
                rgb_menu.addAction(custom_action)
            
            self.menu.addSeparator()
            
            # Rear Window RGB (brightness only - color control pending HID implementation)
            window_menu = self.menu.addMenu("Rear Window Brightness")
            if window_menu is not None:
                 for level in range(4):
                    if level == 0:
                        label = f"Off"
                    else:
                        label = f"Level {level}"
                    action = QAction(label, self)
                    action.triggered.connect(
                        lambda checked, l=level: self.set_window_backlight(l)
                    )
                    window_menu.addAction(action)

            self.menu.addSeparator()

        # Autostart
        autostart_action = QAction("Enable Autostart", self)
        autostart_action.triggered.connect(self.enable_autostart)
        self.menu.addAction(autostart_action)

        self.menu.addSeparator()

        # Quit action
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(QApplication.quit)
        self.menu.addAction(quit_action)

    def change_profile(self, profile):
        """Change power profile by invoking pwrcfg with sudo (password-less via sudoers)."""
        try:
            # Mark as user-initiated to prevent duplicate notification from update_current_profile
            self.user_initiated_change = True

            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", profile],
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode == 0:
                # Parse the output to get power values
                power_info = ""
                for line in result.stdout.split("\n"):
                    if "SPL" in line or "Refresh" in line:
                        power_info += line.strip() + "\n"

                # Send profile change notification with details
                self.notifier.notify_profile_change(profile, power_info.strip())

                # Update current profile and refresh menu immediately
                self.current_profile = profile
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new profile
            else:
                self.user_initiated_change = False  # Reset on failure
                err = (result.stderr or "").strip()
                hint = ""
                if "requires elevated privileges" in err or "permission" in err.lower():
                    hint = "Run tray-icon/install-policy.sh or enable sudoers in the main script to allow password-less pwrcfg."
                self.notifier.notify_error(
                    "Profile Change Failed",
                    f"Could not switch to {profile}: {err}",
                    hint,
                )
        except subprocess.TimeoutExpired:
            self.user_initiated_change = False
            self.notifier.notify_error(
                "Profile Change Failed", "Command timed out after 30 seconds"
            )
        except Exception as e:
            self.user_initiated_change = False
            self.notifier.notify_error(
                "Profile Change Failed", f"Unexpected error: {str(e)}"
            )

    def show_status(self):
        """Show current power profile status"""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "status"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode == 0:
                # Get additional system info
                power = self.get_power_status()
                power_line = ""
                if power.get("present"):
                    pct = power.get("percent")
                    plugged = power.get("plugged")
                    if pct is not None:
                        power_line = f"\n🔋 Battery: {pct}% {'(Charging)' if plugged else '(Discharging)'}"
                    else:
                        power_line = (
                            f"\n🔌 Power: {'AC Connected' if plugged else 'On Battery'}"
                        )

                self.notifier.notify(
                    "System Status",
                    f"{result.stdout.strip()}{power_line}",
                    "info",
                    6000,
                )
            else:
                self.notifier.notify(
                    "Status Error", "Could not retrieve status", "warning", 3000
                )
        except Exception as e:
            self.notifier.notify_error(
                "Status Error", f"Failed to get status: {str(e)}"
            )

    def update_current_profile(self):
        """Update tooltip with current profile and icon"""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "status"],
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode == 0:
                # Extract profile name from status output
                status = result.stdout

                # Extract the profile name from "Current Profile:" line
                profile_name = "balanced"  # default
                for line in status.split("\n"):
                    if "current profile:" in line.lower():
                        # Extract the profile name after the colon
                        parts = line.split(":")
                        if len(parts) > 1:
                            extracted = parts[1].strip().lower()
                            # Validate it's a known profile
                            if extracted in [
                                "emergency",
                                "battery",
                                "efficient",
                                "balanced",
                                "performance",
                                "gaming",
                                "maximum",
                            ]:
                                profile_name = extracted
                            break

                # Update current profile and rebuild menu if it changed
                if self.current_profile != profile_name:
                    old_profile = self.current_profile
                    self.current_profile = profile_name
                    self.create_menu()  # Rebuild menu to show checkmark on new profile
                    
                    # Show toast notification for auto-switch (external profile change)
                    # Only notify if this wasn't a user-initiated change
                    if not self.user_initiated_change:
                        power = self.get_power_status()
                        source = "AC" if power.get("plugged") else "Battery"
                        self.notifier.notify_profile_change(
                            profile_name,
                            f"Auto-switched from {old_profile} ({source} detected)"
                        )
                    self.user_initiated_change = False  # Reset flag

                # Build a rich tooltip with emoji and status
                power = self.get_power_status()
                power_line = ""
                if power.get("present"):
                    pct = power.get("percent")
                    plugged = power.get("plugged")
                    if pct is not None:
                        battery_emoji = "🔋" if pct > 20 else "🪫"
                        charge_status = "⚡" if plugged else ""
                        power_line = f"\n{battery_emoji} {pct}% {charge_status}"
                    else:
                        power_line = f"\n{'🔌 AC' if plugged else '🔋 Battery'}"

                # Profile emoji map
                profile_emoji = {
                    "emergency": "🔋",
                    "battery": "🔋",
                    "efficient": "⚡",
                    "balanced": "⚖️",
                    "performance": "🚀",
                    "gaming": "🎮",
                    "maximum": "💪",
                }

                emoji = profile_emoji.get(profile_name, "⚖️")
                tooltip = (
                    f"GZ302 Control Center\n{emoji} {profile_name.title()}{power_line}"
                )
                self.setToolTip(tooltip)

                # Update icon based on current profile letter
                self.update_icon_for_profile(profile_name)
            else:
                self.setToolTip("GZ302 Control Center\n⚠️ Status: Unknown")
                # Use balanced as fallback
                self.update_icon_for_profile("balanced")
        except:
            self.setToolTip("GZ302 Control Center")
            self.update_icon_for_profile("balanced")

    def get_power_status(self):
        """Try multiple methods to determine AC/battery status and percentage.

        Returns a dict: { present: bool, percent: int|None, plugged: bool|None }
        """
        # Try psutil if available
        try:
            import psutil

            batt = psutil.sensors_battery()
            if batt:
                return {
                    "present": True,
                    "percent": int(batt.percent),
                    "plugged": bool(batt.power_plugged),
                }
        except Exception:
            pass

        # Fallback: check /sys/class/power_supply
        try:
            base = Path("/sys/class/power_supply")
            if base.exists():
                for entry in base.iterdir():
                    # Look for an 'online' or 'status' file
                    online = entry / "online"
                    status = entry / "status"
                    if online.exists():
                        val = online.read_text().strip()
                        return {"present": True, "percent": None, "plugged": val == "1"}
                    if status.exists():
                        val = status.read_text().strip().lower()
                        if val in ("charging", "full", "discharging"):
                            return {
                                "present": True,
                                "percent": None,
                                "plugged": val != "discharging",
                            }
        except Exception:
            pass

        return {"present": False, "percent": None, "plugged": None}

    def update_icon_for_profile(self, profile):
        """Set tray icon based on power profile letter."""
        try:
            assets_dir = Path(__file__).resolve().parent.parent / "assets"
            if not assets_dir.exists():
                return

            # Map profile to first letter and icon file
            profile_icons = {
                "emergency": "profile-e.svg",
                "battery": "profile-b.svg",
                "efficient": "profile-f.svg",
                "balanced": "profile-b.svg",
                "performance": "profile-p.svg",
                "gaming": "profile-g.svg",
                "maximum": "profile-m.svg",
            }

            # Get the icon filename for this profile
            icon_filename = profile_icons.get(profile, "profile-b.svg")
            icon_file = assets_dir / icon_filename

            if icon_file.exists():
                self.setIcon(QIcon(str(icon_file)))
        except Exception:
            pass

    def enable_autostart(self):
        """Create a desktop autostart entry for this tray app in the current user's session."""
        try:
            home = Path.home()
            autostart_dir = home / ".config" / "autostart"
            autostart_dir.mkdir(parents=True, exist_ok=True)
            exec_path = Path(__file__).resolve()

            # Use custom icon from assets if available
            assets_dir = exec_path.parent.parent / "assets"
            icon_path = assets_dir / "profile-b.svg"
            if icon_path.exists():
                icon_name = str(icon_path)
            else:
                icon_name = "battery"

            desktop = autostart_dir / "gz302-tray.desktop"
            desktop.write_text(
                f"""[Desktop Entry]
Type=Application
Name=GZ302 Control Center
Comment=System tray power profile manager for GZ302
Exec=python3 {exec_path}
Icon={icon_name}
Terminal=false
Categories=Utility;System;
StartupNotify=false
X-GNOME-Autostart-enabled=true
"""
            )
            self.notifier.notify(
                "Autostart Enabled",
                "GZ302 Control Center will start automatically on login.\n📁 ~/.config/autostart/gz302-tray.desktop",
                "success",
                4000,
            )
        except Exception as e:
            self.notifier.notify_error(
                "Autostart Error", f"Failed to create autostart entry: {e}"
            )

    def get_current_charge_limit(self):
        """Get the current battery charge limit setting."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "charge-limit"],
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode == 0:
                # Parse output to find the limit value
                for line in result.stdout.split("\n"):
                    if "Charge Limit:" in line:
                        # Extract percentage value
                        parts = line.split(":")
                        if len(parts) > 1:
                            limit = parts[1].strip().rstrip("%")
                            return limit
            return "N/A"
        except Exception:
            return "N/A"

    def set_charge_limit(self, limit):
        """Set battery charge limit (80 or 100)."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "charge-limit", limit],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode == 0:
                emoji = "🔋" if limit == "80" else "⚡"
                desc = "Battery longevity mode" if limit == "80" else "Full charge mode"
                self.notifier.notify(
                    "Charge Limit Updated",
                    f"{emoji} {desc}\nBattery will charge to {limit}%",
                    "success",
                    3000,
                )
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new limit
            else:
                err = (result.stderr or "").strip()
                self.notifier.notify_error(
                    "Charge Limit Error", f"Failed to set charge limit: {err}"
                )
        except Exception as e:
            self.notifier.notify_error(
                "Charge Limit Error", f"Failed to set charge limit: {str(e)}"
            )

    def _find_lightbar_hidraw(self):
        """Find the lightbar HID raw device by physical path signature."""
        import glob
        lightbar_sig = "usb-0000:c6:00.0-5/input0"  # N-KEY Device = lightbar
        
        for path in glob.glob("/sys/class/hidraw/hidraw*"):
            uevent_path = os.path.join(path, "device/uevent")
            try:
                with open(uevent_path, "r") as f:
                    for line in f:
                        if line.startswith("HID_PHYS=") and lightbar_sig in line:
                            return f"/dev/{os.path.basename(path)}"
            except Exception:
                pass
        return None

    def _send_hid_packet(self, device_path, packet_bytes):
        """Send a 64-byte HID packet to the device."""
        if len(packet_bytes) < 64:
            packet_bytes = packet_bytes + bytes([0] * (64 - len(packet_bytes)))
        with open(device_path, 'wb') as f:
            f.write(packet_bytes)

    def set_window_backlight(self, brightness):
        """Set rear window lightbar brightness (0=off, 1-3=on with color)."""
        try:
            # Validate brightness level
            if not isinstance(brightness, int) or brightness < 0 or brightness > 3:
                self.notifier.notify(
                    "Invalid Brightness",
                    "Window brightness must be between 0 and 3",
                    "warning",
                    3000,
                )
                return
            
            # Find the lightbar HID raw device
            device_path = self._find_lightbar_hidraw()
            if not device_path:
                self.notifier.notify_error(
                    "Lightbar Not Found",
                    "Rear window lightbar device not detected. Check USB connection."
                )
                return
            
            try:
                if brightness == 0:
                    # Turn off lightbar
                    packet = bytes([0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff])
                    self._send_hid_packet(device_path, packet)
                else:
                    # Turn on lightbar first
                    on_packet = bytes([0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff])
                    self._send_hid_packet(device_path, on_packet)
                    
                    # Set color based on brightness (white with varying intensity)
                    # brightness 1 = dim, 2 = medium, 3 = bright
                    intensity = [0, 85, 170, 255][brightness]
                    color_packet = bytes([
                        0x5d, 0xb3, 0x00, 0x00,
                        intensity, intensity, intensity,  # R, G, B
                        0xeb, 0x00, 0x00,
                        0xff, 0xff, 0xff
                    ])
                    import time
                    time.sleep(0.1)  # Small delay between packets
                    self._send_hid_packet(device_path, color_packet)
                    
            except PermissionError:
                self.notifier.notify_error(
                    "Permission Denied",
                    "Run the main setup script to install udev rules for RGB control."
                )
                return
            except Exception as e:
                self.notifier.notify_error(
                    "Lightbar Error", f"Failed to control lightbar: {str(e)}"
                )
                return

            # Save window brightness setting for restore on boot
            self._save_window_brightness(brightness)

            level_names = ["💡 Off", "💡 Dim", "💡 Medium", "💡 Bright"]
            self.notifier.notify(
                "Rear Window Backlight",
                f"Brightness set to {level_names[brightness]}",
                "success",
                2000,
            )

        except subprocess.TimeoutExpired:
            self.notifier.notify_error("Backlight Error", "Command timed out")
        except Exception as e:
            self.notifier.notify_error("Backlight Error", f"Unexpected error: {str(e)}")

    def _save_window_brightness(self, brightness):
        """Save window brightness to config for restore on boot."""
        try:
            config_dir = Path("/etc/gz302")
            config_file = config_dir / "rgb-window.conf"
            
            # Write to temp file then move (requires sudo)
            temp_file = Path(f"/tmp/gz302-window-{os.getpid()}.conf")
            temp_file.write_text(f"WINDOW_BRIGHTNESS={brightness}\n")
            
            subprocess.run(
                ["sudo", "-n", "mkdir", "-p", str(config_dir)],
                capture_output=True,
                timeout=5,
            )
            subprocess.run(
                ["sudo", "-n", "mv", str(temp_file), str(config_file)],
                capture_output=True,
                timeout=5,
            )
        except Exception:
            pass  # Non-critical - just means settings won't persist

    def set_keyboard_backlight(self, brightness):
        """Set keyboard backlight brightness (0-3)."""
        try:
            # Validate brightness level
            if not isinstance(brightness, int) or brightness < 0 or brightness > 3:
                self.notifier.notify(
                    "Invalid Brightness",
                    "Keyboard brightness must be between 0 and 3",
                    "warning",
                    3000,
                )
                return

            # Use gz302-rgb command with sudo -n (NOPASSWD configured via install-policy.sh)
            result = subprocess.run(
                ["sudo", "-n", "gz302-rgb", "brightness", str(brightness)],
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode == 0:
                level_names = ["💡 Off", "💡 Dim", "💡 Medium", "💡 Bright"]
                self.notifier.notify(
                    "Keyboard Backlight",
                    f"Brightness set to {level_names[brightness]}",
                    "success",
                    2000,
                )
            else:
                err = (result.stderr or "").strip()
                if "password is required" in err.lower():
                    self.notifier.notify_error(
                        "Backlight Error",
                        "Run 'sudo tray-icon/install-policy.sh' to configure permissions"
                    )
                else:
                    self.notifier.notify_error(
                        "Backlight Error", f"Failed to set brightness: {err}"
                    )
        except subprocess.TimeoutExpired:
            self.notifier.notify_error("Backlight Error", "Command timed out")
        except Exception as e:
            self.notifier.notify_error("Backlight Error", f"Unexpected error: {str(e)}")

    def check_rgb_available(self):
        """Check if gz302-rgb binary is available."""
        try:
            result = subprocess.run([
                "which",
                "gz302-rgb",
            ], capture_output=True, timeout=2)
            if result.returncode == 0:
                return True
            # Fallback: check common install location
            from pathlib import Path

            if Path("/usr/local/bin/gz302-rgb").exists() and Path("/usr/local/bin/gz302-rgb").is_file():
                return True
            return False
        except Exception:
            return False

    def load_tray_config(self):
        """Load tray configuration from /etc/gz302/tray.conf (optional)."""
        try:
            if self.config_file.exists():
                for line in self.config_file.read_text().splitlines():
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        k, v = line.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k == 'APP_NAME':
                            self.app_name = v
        except Exception:
            pass

    def reload_from_signal(self):
        """Reload visible UI elements in response to an external signal."""
        try:
            # Re-read config
            self.load_tray_config()
            # Re-init notify2 with new name
            try:
                if NOTIFY2_AVAILABLE:
                    import notify2
                    notify2.init(self.app_name)
            except Exception:
                pass

            # Rebuild the menu and tooltip
            self.create_menu()
            self.update_current_profile()

            # Inform user the tray reloaded
            self.notifier.notify(self.app_name, "Control Center updated", "info", 2000)
        except Exception:
            pass

    def save_rgb_setting(self, command, *args):
        """Save RGB setting to config file for boot persistence."""
        try:
            # Use FHS-compliant path: /etc/gz302/rgb-keyboard.conf
            config_dir = "/etc/gz302"
            config_file = f"{config_dir}/rgb-keyboard.conf"

            # Build the config content - use new format (KEYBOARD_COMMAND)
            # Properly quote all arguments to handle colors like FF0000
            command_str = f"{command} {' '.join(str(a) for a in args)}".strip()
            config_lines = [
                f"# GZ302 Keyboard RGB Settings",
                f"# Saved at {datetime.now().isoformat()}",
                f'KEYBOARD_COMMAND="{command_str}"',
                f"# Legacy format for backward compatibility",
                f'COMMAND="{command}"',
            ]
            for i, arg in enumerate(args, 1):
                config_lines.append(f'ARG{i}="{arg}"')
            config_lines.append(f"ARGC={len(args) + 1}")
            config_content = "\n".join(config_lines) + "\n"

            # Write to config file using sudo
            temp_file = f"/tmp/gz302-rgb-{os.getpid()}.conf"
            with open(temp_file, "w") as f:
                f.write(config_content)

            # Ensure config directory exists
            subprocess.run(
                ["sudo", "-n", "mkdir", "-p", config_dir],
                capture_output=True,
                timeout=2,
            )
            
            subprocess.run(
                ["sudo", "-n", "mv", temp_file, config_file],
                capture_output=True,
                timeout=2,
            )

        except Exception as e:
            # Silently fail - saving is not critical
            pass

    def set_rgb_color(self, hex_color):
        """Set RGB keyboard to static color (runs in background thread)."""
        # Run the command in a background thread to avoid blocking UI
        def run_rgb_command():
            try:
                result = subprocess.run(
                    ["sudo", "-n", "gz302-rgb", "single_static", hex_color],
                    capture_output=True,
                    text=True,
                    timeout=60,  # Increased timeout to 60 seconds for RGB hardware operations
                )

                # Check for actual errors (RGB binary writes diagnostics to stderr, so we check for "Error:" messages)
                has_error = result.returncode != 0 or "Error:" in result.stderr

                if not has_error:
                    # Save the RGB setting for boot persistence
                    self.save_rgb_setting("single_static", hex_color)
                    self.notifier.notify(
                        "Keyboard RGB", f"🌈 Color set to #{hex_color}", "success", 2000
                    )
                else:
                    err = (result.stderr or "").strip()
                    self.notifier.notify_error(
                        "RGB Error", f"Failed to set color: {err or 'Unknown error'}"
                    )
            except subprocess.TimeoutExpired:
                self.notifier.notify_error(
                    "RGB Error", "Command timed out (hardware may be unresponsive)"
                )
            except Exception as e:
                self.notifier.notify_error("RGB Error", f"Failed: {str(e)}")

        # Run in background thread
        thread = threading.Thread(target=run_rgb_command, daemon=True)
        thread.start()

    def set_rgb_animation(self, animation_type, color1=None, color2=None, speed=2):
        """Set RGB keyboard animation (runs in background thread)."""

        if animation_type == "breathing":
            cmd = [
                "sudo",
                "-n",
                "gz302-rgb",
                "single_breathing",
                color1,
                color2,
                str(speed),
            ]
            desc = "🌬️ Breathing animation"
        elif animation_type == "colorcycle":
            cmd = ["sudo", "-n", "gz302-rgb", "single_colorcycle", str(speed)]
            desc = "🔄 Color cycle animation"
        elif animation_type == "rainbow":
            cmd = ["sudo", "-n", "gz302-rgb", "rainbow_cycle", str(speed)]
            desc = "🌈 Rainbow animation"
        else:
            self.notifier.notify(
                "Animation Error",
                f"Unknown animation type: {animation_type}",
                "warning",
                3000,
            )
            return

        # Run in background thread
        def run_animation():
            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=60,  # Increased timeout to 60 seconds
                )

                # Check for actual errors (RGB binary writes diagnostics to stderr, so we check for "Error:" messages)
                has_error = result.returncode != 0 or "Error:" in result.stderr

                if not has_error:
                    # Save animation setting for boot persistence
                    if animation_type == "breathing":
                        self.save_rgb_setting(
                            "single_breathing", color1, color2, str(speed)
                        )
                    elif animation_type == "colorcycle":
                        self.save_rgb_setting("single_colorcycle", str(speed))
                    elif animation_type == "rainbow":
                        self.save_rgb_setting("rainbow_cycle", str(speed))

                    self.notifier.notify(
                        "Keyboard RGB", f"{desc} activated", "success", 2000
                    )
                else:
                    err = (result.stderr or "").strip()
                    self.notifier.notify_error(
                        "RGB Error",
                        f"Failed to set animation: {err or 'Unknown error'}",
                    )
            except subprocess.TimeoutExpired:
                self.notifier.notify_error(
                    "RGB Error", "Command timed out (hardware may be unresponsive)"
                )
            except Exception as e:
                self.notifier.notify_error("RGB Error", f"Failed: {str(e)}")

        thread = threading.Thread(target=run_animation, daemon=True)
        thread.start()

    def set_custom_rgb_color(self):
        """Prompt user for custom RGB color (hex format)."""
        try:
            text, ok = QInputDialog.getText(
                None,
                "🌈 Custom RGB Color",
                "Enter hex color (e.g., FF0000 for red):",
                text="FF0000",
            )

            if ok and text:
                # Validate hex color
                hex_color = text.strip().upper()
                if len(hex_color) == 6 and all(
                    c in "0123456789ABCDEF" for c in hex_color
                ):
                    self.set_rgb_color(hex_color)
                else:
                    self.notifier.notify(
                        "Invalid Color",
                        "Please use format: RRGGBB (e.g., FF0000 for red)",
                        "warning",
                        3000,
                    )
        except Exception as e:
            self.notifier.notify_error(
                "Color Input Error", f"Failed to get custom color: {str(e)}"
            )


def main():
    app = QApplication(sys.argv)

    # Try to load default profile icon (balanced), fallback to system icon if not available
    assets_dir = Path(__file__).resolve().parent.parent / "assets"

    if assets_dir.exists():
        # Use balanced icon as default (B for Balanced)
        icon_path = assets_dir / "profile-b.svg"
        if icon_path.exists():
            icon = QIcon(str(icon_path))
        else:
            # Fallback to system icon
            style = app.style()
            icon = (
                style.standardIcon(style.StandardPixmap.SP_ComputerIcon)
                if style
                else QIcon()
            )
    else:
        # Fallback to system icon
        style = app.style()
        icon = (
            style.standardIcon(style.StandardPixmap.SP_ComputerIcon)
            if style
            else QIcon()
        )

    # Create a hidden widget as parent for the tray icon (required for Wayland compatibility)
    widget = QWidget()
    widget.hide()

    tray = GZ302TrayIcon(icon, widget)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
