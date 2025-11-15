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
        
        # Create menu
        self.menu = QMenu()
        self.create_menu()
        self.setContextMenu(self.menu)
        
        # Update current profile on startup
        self.update_current_profile()
        
        # Update icon based on power state on startup
        power = self.get_power_status()
        self.update_icon_for_power(power)
        
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
            action = QAction(name, self)
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
            charge_80_action = QAction("80% (Recommended)", self)
            charge_80_action.triggered.connect(lambda: self.set_charge_limit("80"))
            charge_limit_menu.addAction(charge_80_action)
            
            charge_100_action = QAction("100% (Maximum)", self)
            charge_100_action.triggered.connect(lambda: self.set_charge_limit("100"))
            charge_limit_menu.addAction(charge_100_action)

        # Keyboard backlight (GZ302 supports brightness 0-3 only, no RGB)
        backlight_menu = self.menu.addMenu("Keyboard Backlight")
        if backlight_menu is not None:
            # Brightness submenu
            brightness_submenu = backlight_menu.addMenu("Brightness")
            if brightness_submenu is not None:
                for level in range(4):
                    if level == 0:
                        label = f"Off"
                    else:
                        label = f"Level {level}"
                    action = QAction(label, self)
                    action.triggered.connect(lambda checked, l=level: self.set_keyboard_backlight(l))
                    brightness_submenu.addAction(action)
        
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
                self.showMessage(
                    "Power Profile Changed",
                    f"Switched to {profile} profile",
                    QSystemTrayIcon.MessageIcon.Information,
                    3000
                )
                self.update_current_profile()
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
        """Update tooltip with current profile"""
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
                # Append power status
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
                # Update icon based on power
                self.update_icon_for_power(power)
            else:
                self.setToolTip("GZ302 Power Manager\nStatus: Unknown")
        except:
            self.setToolTip("GZ302 Power Manager")

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

    def update_icon_for_power(self, power):
        """Set tray icon depending on power state, if asset icons exist."""
        try:
            assets_dir = Path(__file__).resolve().parent.parent / 'assets'
            if not assets_dir.exists():
                return
            if power.get('present'):
                if power.get('plugged'):
                    icon_file = assets_dir / 'ac.svg'
                else:
                    icon_file = assets_dir / 'battery.svg'
            else:
                icon_file = None

            if icon_file and icon_file.exists():
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



def main():
    app = QApplication(sys.argv)
    
    # Try to load custom SVG icon, fallback to system icon if not available
    assets_dir = Path(__file__).resolve().parent.parent / 'assets'
    
    if assets_dir.exists():
        # Use battery icon as primary (adapts to theme via currentColor)
        icon_path = assets_dir / 'battery.svg'
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
