#!/usr/bin/env python3
"""
GZ302 Power Profile Tray Icon
A system tray utility for managing power profiles on ASUS ROG Flow Z13 (GZ302)
Version: 2.3.13
"""

import sys
import os
import subprocess
import threading
from pathlib import Path
from datetime import datetime
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QInputDialog, QWidget
from PyQt6.QtGui import QIcon, QAction
from PyQt6.QtCore import QTimer, pyqtSignal, QObject

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
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
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
                notify2.init("GZ302 Power Manager")
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
            duration
        )
    
    def notify_profile_change(self, profile, power_info=""):
        """Send notification for profile change with detailed info"""
        profile_info = {
            "emergency": ("🔋 Emergency Mode", "10W - Maximum battery preservation"),
            "battery": ("🔋 Battery Mode", "18W - Extended battery life"),
            "efficient": ("⚡ Efficient Mode", "30W - Light tasks with good performance"),
            "balanced": ("⚖️ Balanced Mode", "40W - General computing (Default)"),
            "performance": ("🚀 Performance Mode", "55W - Heavy workloads"),
            "gaming": ("🎮 Gaming Mode", "70W - Optimized for gaming"),
            "maximum": ("💪 Maximum Mode", "90W - Peak performance"),
        }
        
        title, desc = profile_info.get(profile, (f"Profile: {profile}", ""))
        message = desc
        if power_info:
            message += f"\n{power_info}"
        
        self.notify(title, message, "success", 4000)
    
    def notify_error(self, title, message, hint=""):
        """Send error notification with optional hint"""
        full_message = message
        if hint:
            full_message += f"\n\n💡 Tip: {hint}"
        self.notify(title, full_message, "error", 6000, "critical")

class GZ302TrayIcon(QSystemTrayIcon):
    def __init__(self, icon, parent=None):
        super().__init__(icon, parent)
        
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
            ("💪 Maximum (90W)", "maximum")
        ]
        
        # Store current profile name
        self.current_profile = "balanced"
        
        # Track last notification time to avoid spam
        self.last_notification_time = None
        
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
        self.setToolTip("GZ302 Power Manager\n🚀 Ready")
        
        # Show startup notification
        self.notifier.notify(
            "GZ302 Power Manager",
            "System tray utility ready.\nRight-click to manage power profiles.",
            "info",
            3000
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
            label_80 = "✓ 80% (Recommended)" if current_limit == "80" else "   80% (Recommended)"
            charge_80_action = QAction(label_80, self)
            charge_80_action.triggered.connect(lambda: self.set_charge_limit("80"))
            charge_limit_menu.addAction(charge_80_action)
            
            # 100% option
            label_100 = "✓ 100% (Maximum)" if current_limit == "100" else "   100% (Maximum)"
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
                action.triggered.connect(lambda checked, l=level: self.set_keyboard_backlight(l))
                brightness_menu.addAction(action)
        
        self.menu.addSeparator()

        # Keyboard RGB Colors
        if self.check_rgb_available():
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
                    action.triggered.connect(lambda checked, h=hex_value: self.set_rgb_color(h))
                    colors_submenu.addAction(action)
                
                rgb_menu.addSeparator()
                
                # Animations submenu
                animations_submenu = rgb_menu.addMenu("Animations")
                
                # Breathing animation
                breathing_action = QAction("Breathing (Red)", self)
                breathing_action.triggered.connect(lambda: self.set_rgb_animation("breathing", "FF0000", "000000", 2))
                animations_submenu.addAction(breathing_action)
                
                # Color cycle
                cycle_action = QAction("Color Cycle", self)
                cycle_action.triggered.connect(lambda: self.set_rgb_animation("colorcycle", None, None, 2))
                animations_submenu.addAction(cycle_action)
                
                # Rainbow
                rainbow_action = QAction("Rainbow", self)
                rainbow_action.triggered.connect(lambda: self.set_rgb_animation("rainbow", None, None, 2))
                animations_submenu.addAction(rainbow_action)
                
                rgb_menu.addSeparator()
                
                # Custom color
                custom_action = QAction("Custom Color...", self)
                custom_action.triggered.connect(self.set_custom_rgb_color)
                rgb_menu.addAction(custom_action)
            
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
            # Show immediate feedback
            self.notifier.notify(
                "Changing Profile",
                f"Switching to {profile}...",
                "info",
                2000
            )
            
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", profile],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                # Parse the output to get power values
                power_info = ""
                for line in result.stdout.split('\n'):
                    if 'SPL' in line or 'Refresh' in line:
                        power_info += line.strip() + "\n"
                
                # Send profile change notification with details
                self.notifier.notify_profile_change(profile, power_info.strip())
                
                # Update current profile and refresh menu immediately
                self.current_profile = profile
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new profile
            else:
                err = (result.stderr or "").strip()
                hint = ""
                if "requires elevated privileges" in err or "permission" in err.lower():
                    hint = "Run tray-icon/install-policy.sh or enable sudoers in the main script to allow password-less pwrcfg."
                self.notifier.notify_error("Profile Change Failed", f"Could not switch to {profile}: {err}", hint)
        except subprocess.TimeoutExpired:
            self.notifier.notify_error("Profile Change Failed", "Command timed out after 30 seconds")
        except Exception as e:
            self.notifier.notify_error("Profile Change Failed", f"Unexpected error: {str(e)}")
    
    def show_status(self):
        """Show current power profile status"""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "status"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Get additional system info
                power = self.get_power_status()
                power_line = ""
                if power.get('present'):
                    pct = power.get('percent')
                    plugged = power.get('plugged')
                    if pct is not None:
                        power_line = f"\n🔋 Battery: {pct}% {'(Charging)' if plugged else '(Discharging)'}"
                    else:
                        power_line = f"\n🔌 Power: {'AC Connected' if plugged else 'On Battery'}"
                
                self.notifier.notify(
                    "System Status",
                    f"{result.stdout.strip()}{power_line}",
                    "info",
                    6000
                )
            else:
                self.notifier.notify("Status Error", "Could not retrieve status", "warning", 3000)
        except Exception as e:
            self.notifier.notify_error("Status Error", f"Failed to get status: {str(e)}")
    
    def update_current_profile(self):
        """Update tooltip with current profile and icon"""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "status"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                # Extract profile name from status output
                status = result.stdout
                
                # Extract the profile name from "Current Profile:" line
                profile_name = "balanced"  # default
                for line in status.split('\n'):
                    if 'current profile:' in line.lower():
                        # Extract the profile name after the colon
                        parts = line.split(':')
                        if len(parts) > 1:
                            extracted = parts[1].strip().lower()
                            # Validate it's a known profile
                            if extracted in ['emergency', 'battery', 'efficient', 'balanced', 'performance', 'gaming', 'maximum']:
                                profile_name = extracted
                            break
                
                # Update current profile and rebuild menu if it changed
                if self.current_profile != profile_name:
                    self.current_profile = profile_name
                    self.create_menu()  # Rebuild menu to show checkmark on new profile
                
                # Build a rich tooltip with emoji and status
                power = self.get_power_status()
                power_line = ''
                if power.get('present'):
                    pct = power.get('percent')
                    plugged = power.get('plugged')
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
                    "maximum": "💪"
                }
                
                emoji = profile_emoji.get(profile_name, "⚖️")
                tooltip = f"GZ302 Power Manager\n{emoji} {profile_name.title()}{power_line}"
                self.setToolTip(tooltip)
                
                # Update icon based on current profile letter
                self.update_icon_for_profile(profile_name)
            else:
                self.setToolTip("GZ302 Power Manager\n⚠️ Status: Unknown")
                # Use balanced as fallback
                self.update_icon_for_profile("balanced")
        except:
            self.setToolTip("GZ302 Power Manager")
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
                return { 'present': True, 'percent': int(batt.percent), 'plugged': bool(batt.power_plugged) }
        except Exception:
            pass

        # Fallback: check /sys/class/power_supply
        try:
            base = Path('/sys/class/power_supply')
            if base.exists():
                for entry in base.iterdir():
                    # Look for an 'online' or 'status' file
                    online = entry / 'online'
                    status = entry / 'status'
                    if online.exists():
                        val = online.read_text().strip()
                        return { 'present': True, 'percent': None, 'plugged': val == '1' }
                    if status.exists():
                        val = status.read_text().strip().lower()
                        if val in ('charging', 'full', 'discharging'):
                            return { 'present': True, 'percent': None, 'plugged': val != 'discharging' }
        except Exception:
            pass

        return { 'present': False, 'percent': None, 'plugged': None }

    def update_icon_for_profile(self, profile):
        """Set tray icon based on power profile letter."""
        try:
            assets_dir = Path(__file__).resolve().parent.parent / 'assets'
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
                "maximum": "profile-m.svg"
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
            autostart_dir = home / '.config' / 'autostart'
            autostart_dir.mkdir(parents=True, exist_ok=True)
            exec_path = Path(__file__).resolve()
            
            # Use custom icon from assets if available
            assets_dir = exec_path.parent.parent / 'assets'
            icon_path = assets_dir / 'profile-b.svg'
            if icon_path.exists():
                icon_name = str(icon_path)
            else:
                icon_name = "battery"
            
            desktop = autostart_dir / 'gz302-tray.desktop'
            desktop.write_text(f"""[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for GZ302
Exec=python3 {exec_path}
Icon={icon_name}
Terminal=false
Categories=Utility;System;
StartupNotify=false
X-GNOME-Autostart-enabled=true
""")
            self.notifier.notify(
                "Autostart Enabled",
                "GZ302 Power Manager will start automatically on login.\n📁 ~/.config/autostart/gz302-tray.desktop",
                "success",
                4000
            )
        except Exception as e:
            self.notifier.notify_error("Autostart Error", f"Failed to create autostart entry: {e}")

    def get_current_charge_limit(self):
        """Get the current battery charge limit setting."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "charge-limit"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                # Parse output to find the limit value
                for line in result.stdout.split('\n'):
                    if 'Charge Limit:' in line:
                        # Extract percentage value
                        parts = line.split(':')
                        if len(parts) > 1:
                            limit = parts[1].strip().rstrip('%')
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
                timeout=10
            )
            
            if result.returncode == 0:
                emoji = "🔋" if limit == "80" else "⚡"
                desc = "Battery longevity mode" if limit == "80" else "Full charge mode"
                self.notifier.notify(
                    "Charge Limit Updated",
                    f"{emoji} {desc}\nBattery will charge to {limit}%",
                    "success",
                    3000
                )
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new limit
            else:
                err = (result.stderr or "").strip()
                self.notifier.notify_error("Charge Limit Error", f"Failed to set charge limit: {err}")
        except Exception as e:
            self.notifier.notify_error("Charge Limit Error", f"Failed to set charge limit: {str(e)}")

    def set_keyboard_backlight(self, brightness):
        """Set keyboard backlight brightness (0-3)."""
        try:
            # Validate brightness level
            if not isinstance(brightness, int) or brightness < 0 or brightness > 3:
                self.notifier.notify(
                    "Invalid Brightness",
                    "Keyboard brightness must be between 0 and 3",
                    "warning",
                    3000
                )
                return
            
            # Use gz302-rgb command with sudo (NOPASSWD configured)
            result = subprocess.run(
                ["sudo", "gz302-rgb", "brightness", str(brightness)],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                level_names = ["💡 Off", "💡 Dim", "💡 Medium", "💡 Bright"]
                self.notifier.notify(
                    "Keyboard Backlight",
                    f"Brightness set to {level_names[brightness]}",
                    "success",
                    2000
                )
            else:
                err = (result.stderr or "").strip()
                self.notifier.notify_error("Backlight Error", f"Failed to set brightness: {err}")
        except subprocess.TimeoutExpired:
            self.notifier.notify_error("Backlight Error", "Command timed out")
        except Exception as e:
            self.notifier.notify_error("Backlight Error", f"Unexpected error: {str(e)}")

    def check_rgb_available(self):
        """Check if gz302-rgb binary is available."""
        try:
            result = subprocess.run(
                ["which", "gz302-rgb"],
                capture_output=True,
                timeout=2
            )
            return result.returncode == 0
        except Exception:
            return False

    def save_rgb_setting(self, command, *args):
        """Save RGB setting to config file for boot persistence."""
        try:
            config_file = "/etc/gz302-rgb/last-setting.conf"
            
            # Build the config content
            config_lines = [f"COMMAND={command}"]
            for i, arg in enumerate(args, 1):
                config_lines.append(f"ARG{i}={arg}")
            config_lines.append(f"ARGC={len(args) + 1}")
            config_content = "\n".join(config_lines) + "\n"
            
            # Write to config file using sudo
            # Create a temporary file and use tee to write it
            temp_file = f"/tmp/gz302-rgb-{os.getpid()}.conf"
            with open(temp_file, 'w') as f:
                f.write(config_content)
            
            subprocess.run(
                ["sudo", "-n", "tee", config_file],
                input=config_content,
                text=True,
                capture_output=True,
                timeout=2
            )
            
            # Clean up temp file
            try:
                os.remove(temp_file)
            except:
                pass
                
        except Exception as e:
            # Silently fail - saving is not critical
            pass

    def set_rgb_color(self, hex_color):
        """Set RGB keyboard to static color (runs in background thread)."""
        # Show a "processing" message immediately
        self.notifier.notify(
            "Keyboard RGB",
            f"🌈 Setting color to #{hex_color}...",
            "info",
            3000
        )
        
        # Run the command in a background thread to avoid blocking UI
        def run_rgb_command():
            try:
                result = subprocess.run(
                    ["sudo", "-n", "gz302-rgb", "single_static", hex_color],
                    capture_output=True,
                    text=True,
                    timeout=60  # Increased timeout to 60 seconds for RGB hardware operations
                )
                
                # Check for actual errors (RGB binary writes diagnostics to stderr, so we check for "Error:" messages)
                has_error = result.returncode != 0 or "Error:" in result.stderr
                
                if not has_error:
                    # Save the RGB setting for boot persistence
                    self.save_rgb_setting("single_static", hex_color)
                    self.notifier.notify(
                        "Keyboard RGB",
                        f"🌈 Color set to #{hex_color}",
                        "success",
                        2000
                    )
                else:
                    err = (result.stderr or "").strip()
                    self.notifier.notify_error("RGB Error", f"Failed to set color: {err or 'Unknown error'}")
            except subprocess.TimeoutExpired:
                self.notifier.notify_error("RGB Error", "Command timed out (hardware may be unresponsive)")
            except Exception as e:
                self.notifier.notify_error("RGB Error", f"Failed: {str(e)}")
        
        # Run in background thread
        thread = threading.Thread(target=run_rgb_command, daemon=True)
        thread.start()

    def set_rgb_animation(self, animation_type, color1=None, color2=None, speed=2):
        """Set RGB keyboard animation (runs in background thread)."""
        
        if animation_type == "breathing":
            cmd = ["sudo", "-n", "gz302-rgb", "single_breathing", color1, color2, str(speed)]
            desc = "🌬️ Breathing animation"
        elif animation_type == "colorcycle":
            cmd = ["sudo", "-n", "gz302-rgb", "single_colorcycle", str(speed)]
            desc = "🔄 Color cycle animation"
        elif animation_type == "rainbow":
            cmd = ["sudo", "-n", "gz302-rgb", "rainbow_cycle", str(speed)]
            desc = "🌈 Rainbow animation"
        else:
            self.notifier.notify("Animation Error", f"Unknown animation type: {animation_type}", "warning", 3000)
            return
        
        # Show processing message
        self.notifier.notify("Keyboard RGB", f"Activating {desc}...", "info", 2000)
        
        # Run in background thread
        def run_animation():
            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=60  # Increased timeout to 60 seconds
                )
                
                # Check for actual errors (RGB binary writes diagnostics to stderr, so we check for "Error:" messages)
                has_error = result.returncode != 0 or "Error:" in result.stderr
                
                if not has_error:
                    # Save animation setting for boot persistence
                    if animation_type == "breathing":
                        self.save_rgb_setting("single_breathing", color1, color2, str(speed))
                    elif animation_type == "colorcycle":
                        self.save_rgb_setting("single_colorcycle", str(speed))
                    elif animation_type == "rainbow":
                        self.save_rgb_setting("rainbow_cycle", str(speed))
                    
                    self.notifier.notify("Keyboard RGB", f"{desc} activated", "success", 2000)
                else:
                    err = (result.stderr or "").strip()
                    self.notifier.notify_error("RGB Error", f"Failed to set animation: {err or 'Unknown error'}")
            except subprocess.TimeoutExpired:
                self.notifier.notify_error("RGB Error", "Command timed out (hardware may be unresponsive)")
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
                text="FF0000"
            )
            
            if ok and text:
                # Validate hex color
                hex_color = text.strip().upper()
                if len(hex_color) == 6 and all(c in '0123456789ABCDEF' for c in hex_color):
                    self.set_rgb_color(hex_color)
                else:
                    self.notifier.notify(
                        "Invalid Color",
                        "Please use format: RRGGBB (e.g., FF0000 for red)",
                        "warning",
                        3000
                    )
        except Exception as e:
            self.notifier.notify_error("Color Input Error", f"Failed to get custom color: {str(e)}")



def main():
    app = QApplication(sys.argv)
    
    # Try to load default profile icon (balanced), fallback to system icon if not available
    assets_dir = Path(__file__).resolve().parent.parent / 'assets'
    
    if assets_dir.exists():
        # Use balanced icon as default (B for Balanced)
        icon_path = assets_dir / 'profile-b.svg'
        if icon_path.exists():
            icon = QIcon(str(icon_path))
        else:
            # Fallback to system icon
            style = app.style()
            icon = style.standardIcon(style.StandardPixmap.SP_ComputerIcon) if style else QIcon()
    else:
        # Fallback to system icon
        style = app.style()
        icon = style.standardIcon(style.StandardPixmap.SP_ComputerIcon) if style else QIcon()
    
    # Create a hidden widget as parent for the tray icon (required for Wayland compatibility)
    widget = QWidget()
    widget.hide()
    
    tray = GZ302TrayIcon(icon, widget)
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
