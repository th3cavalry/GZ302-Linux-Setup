#!/usr/bin/env python3
"""
GZ302 Power Profile Tray Icon
A system tray utility for managing power profiles on ASUS ROG Flow Z13 (GZ302)
"""

import sys
import os
import subprocess
from pathlib import Path
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QInputDialog
from PyQt6.QtGui import QIcon, QAction
from PyQt6.QtCore import QTimer

class GZ302TrayIcon(QSystemTrayIcon):
    def __init__(self, icon, parent=None):
        super().__init__(icon, parent)
        
        # Power profiles
        self.profiles = [
            ("Emergency (10W)", "emergency"),
            ("Battery (18W)", "battery"),
            ("Efficient (30W)", "efficient"),
            ("Balanced (40W)", "balanced"),
            ("Performance (55W)", "performance"),
            ("Gaming (70W)", "gaming"),
            ("Maximum (90W)", "maximum")
        ]
        
        # Store current profile name
        self.current_profile = "balanced"
        
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
                
                # Show detailed notification
                notification_text = f"Switched to {profile} profile"
                if power_info:
                    notification_text += f"\n{power_info.strip()}"
                
                self.showMessage(
                    "Power Profile Changed",
                    notification_text,
                    QSystemTrayIcon.MessageIcon.Information,
                    4000
                )
                
                # Update current profile and refresh menu immediately
                self.current_profile = profile
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new profile
            else:
                err = (result.stderr or "").strip()
                hint = ""
                if "requires elevated privileges" in err or "permission" in err.lower():
                    hint = "\nTip: Run tray-icon/install-policy.sh or enable sudoers in the main script to allow password-less pwrcfg."
                self.showMessage(
                    "Error",
                    f"Failed to change profile: {err}{hint}",
                    QSystemTrayIcon.MessageIcon.Critical,
                    5000
                )
        except subprocess.TimeoutExpired:
            self.showMessage(
                "Error",
                "Command timed out",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to change profile: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )
    
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
                self.showMessage(
                    "Power Profile Status",
                    result.stdout,
                    QSystemTrayIcon.MessageIcon.Information,
                    5000
                )
            else:
                self.showMessage(
                    "Error",
                    "Failed to get status",
                    QSystemTrayIcon.MessageIcon.Warning,
                    3000
                )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to get status: {str(e)}",
                QSystemTrayIcon.MessageIcon.Warning,
                3000
            )
    
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
                
                # Append power status for tooltip only
                power = self.get_power_status()
                power_line = ''
                if power.get('present'):
                    pct = power.get('percent')
                    plugged = power.get('plugged')
                    if pct is not None:
                        power_line = f"Power: {pct}% {'(AC)' if plugged else '(Battery)'}"
                    else:
                        power_line = f"Power: {'AC' if plugged else 'Battery'}"

                self.setToolTip(f"GZ302 Power Manager\n{status}\n{power_line}")
                
                # Update icon based on current profile letter
                self.update_icon_for_profile(profile_name)
            else:
                self.setToolTip("GZ302 Power Manager\nStatus: Unknown")
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
            exec_path = Path(__file__).resolve().parent / 'gz302_tray.py'
            desktop = autostart_dir / 'gz302-tray.desktop'
            desktop.write_text(f"""[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for GZ302
Exec={exec_path}
Icon=battery
Terminal=false
Categories=Utility;System;
""")
            self.showMessage("Autostart", "Autostart entry created at ~/.config/autostart/gz302-tray.desktop", QSystemTrayIcon.MessageIcon.Information, 4000)
        except Exception as e:
            self.showMessage("Autostart Error", f"Failed to create autostart: {e}", QSystemTrayIcon.MessageIcon.Warning, 4000)

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
                self.showMessage(
                    "Charge Limit Changed",
                    f"Battery charge limit set to {limit}%",
                    QSystemTrayIcon.MessageIcon.Information,
                    3000
                )
                self.update_current_profile()
                self.create_menu()  # Rebuild menu to show checkmark on new limit
            else:
                err = (result.stderr or "").strip()
                self.showMessage(
                    "Error",
                    f"Failed to set charge limit: {err}",
                    QSystemTrayIcon.MessageIcon.Critical,
                    5000
                )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to set charge limit: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )

    def set_keyboard_backlight(self, brightness):
        """Set keyboard backlight brightness (0-3)."""
        try:
            # Validate brightness level
            if not isinstance(brightness, int) or brightness < 0 or brightness > 3:
                self.showMessage(
                    "Error",
                    "Keyboard brightness must be between 0 and 3",
                    QSystemTrayIcon.MessageIcon.Warning,
                    3000
                )
                return
            
            # Try primary keyboard backlight
            backlight_path = Path("/sys/class/leds/asus::kbd_backlight/brightness")
            
            if backlight_path.exists():
                try:
                    # Try writing directly first (might work without sudo on some systems)
                    backlight_path.write_text(str(brightness))
                    level_name = ["Off", "Level 1", "Level 2", "Level 3"][brightness]
                    self.showMessage(
                        "Keyboard Backlight",
                        f"Brightness set to {level_name}",
                        QSystemTrayIcon.MessageIcon.Information,
                        2000
                    )
                except PermissionError:
                    # Fall back to sudo with echo
                    result = subprocess.run(
                        ["sudo", "bash", "-c", f"echo {brightness} > {backlight_path}"],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    
                    if result.returncode == 0:
                        level_name = ["Off", "Level 1", "Level 2", "Level 3"][brightness]
                        self.showMessage(
                            "Keyboard Backlight",
                            f"Brightness set to {level_name}",
                            QSystemTrayIcon.MessageIcon.Information,
                            2000
                        )
                    else:
                        err = (result.stderr or "").strip()
                        self.showMessage(
                            "Error",
                            f"Failed to set keyboard backlight: {err or 'Permission denied'}",
                            QSystemTrayIcon.MessageIcon.Critical,
                            5000
                        )
            else:
                self.showMessage(
                    "Error",
                    "Keyboard backlight not found on this system",
                    QSystemTrayIcon.MessageIcon.Warning,
                    3000
                )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to set keyboard backlight: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )

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
        """Set RGB keyboard to static color."""
        try:
            result = subprocess.run(
                ["sudo", "-n", "gz302-rgb", "single_static", hex_color],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            # Check for actual errors (RGB binary writes diagnostics to stderr, so we check for "Error:" messages)
            has_error = result.returncode != 0 or "Error:" in result.stderr
            
            if not has_error:
                # Save the RGB setting for boot persistence
                self.save_rgb_setting("single_static", hex_color)
                self.showMessage(
                    "Keyboard RGB",
                    f"Color set to #{hex_color}",
                    QSystemTrayIcon.MessageIcon.Information,
                    2000
                )
            else:
                err = (result.stderr or "").strip()
                self.showMessage(
                    "Error",
                    f"Failed to set RGB color: {err or 'Unknown error'}",
                    QSystemTrayIcon.MessageIcon.Critical,
                    5000
                )
        except subprocess.TimeoutExpired:
            self.showMessage(
                "Error",
                "RGB command timed out",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to set RGB color: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )

    def set_rgb_animation(self, animation_type, color1=None, color2=None, speed=2):
        """Set RGB keyboard animation."""
        try:
            if animation_type == "breathing":
                cmd = ["sudo", "-n", "gz302-rgb", "single_breathing", color1, color2, str(speed)]
                desc = "Breathing animation"
            elif animation_type == "colorcycle":
                cmd = ["sudo", "-n", "gz302-rgb", "single_colorcycle", str(speed)]
                desc = "Color cycle animation"
            elif animation_type == "rainbow":
                cmd = ["sudo", "-n", "gz302-rgb", "rainbow_cycle", str(speed)]
                desc = "Rainbow animation"
            else:
                self.showMessage(
                    "Error",
                    f"Unknown animation type: {animation_type}",
                    QSystemTrayIcon.MessageIcon.Warning,
                    3000
                )
                return
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=5
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
                
                self.showMessage(
                    "Keyboard RGB",
                    f"{desc} activated",
                    QSystemTrayIcon.MessageIcon.Information,
                    2000
                )
            else:
                err = (result.stderr or "").strip()
                self.showMessage(
                    "Error",
                    f"Failed to set animation: {err or 'Unknown error'}",
                    QSystemTrayIcon.MessageIcon.Critical,
                    5000
                )
        except subprocess.TimeoutExpired:
            self.showMessage(
                "Error",
                "RGB command timed out",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to set animation: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )

    def set_custom_rgb_color(self):
        """Prompt user for custom RGB color (hex format)."""
        try:
            text, ok = QInputDialog.getText(
                None,
                "Custom RGB Color",
                "Enter hex color (e.g., FF0000 for red):",
                text="FF0000"
            )
            
            if ok and text:
                # Validate hex color
                hex_color = text.strip().upper()
                if len(hex_color) == 6 and all(c in '0123456789ABCDEF' for c in hex_color):
                    self.set_rgb_color(hex_color)
                else:
                    self.showMessage(
                        "Error",
                        "Invalid hex color. Use format: RRGGBB (e.g., FF0000)",
                        QSystemTrayIcon.MessageIcon.Warning,
                        3000
                    )
        except Exception as e:
            self.showMessage(
                "Error",
                f"Failed to get custom color: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                5000
            )



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
    
    tray = GZ302TrayIcon(icon)
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
