#!/usr/bin/env python3
"""
ASUS ROG Flow Z13 (GZ302) Command Center
"""
import sys
import os
import signal
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PyQt6.QtGui import QIcon, QAction, QCursor, QColor, QFont, QPainter, QPen, QPixmap
from PyQt6.QtCore import QTimer, Qt
from pathlib import Path

try:
    from PyQt6.QtSvg import QSvgRenderer
except ImportError:
    QSvgRenderer = None

# Import our modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from modules.config import ConfigManager
from modules.notifications import NotificationManager
from modules.rgb_controller import RGBController
from modules.power_controller import PowerController

TRAY_ICON_SIZE = 64

class CommandCenterApp(QSystemTrayIcon):
    def __init__(self, app):
        super().__init__()
        self.app = app
        
        # Initialize modules
        self.config = ConfigManager()
        self.notifier = NotificationManager(self)
        self.rgb = RGBController(self.notifier)
        self.power = PowerController(self.notifier)
        
        # Setup UI
        self.menu = QMenu()
        self.setup_menu()
        # Use setContextMenu so KDE/GNOME can render the menu natively via
        # StatusNotifierItem + dbusmenu.  On Wayland, popup() is blocked by
        # the compositor (no input serial), so this is the only working path.
        self.setContextMenu(self.menu)

        # Also connect activated for left-click or DEs that emit it
        self.activated.connect(self._on_activated)
        
        # Set icon FIRST (required before setVisible)
        self.update_icon()
        
        # Show tray (icon must be set first)
        self.show()
        
        # Timer for status updates
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_status)
        self.timer.start(5000)
        
        # Welcome
        self.notifier.notify(self.config.get_app_name(), "Command Center Ready", "info", 3000)

    def setup_menu(self):
        self.menu.clear()
        
        # Power Profiles - All 7 profiles
        profiles_menu = self.menu.addMenu("⚡ Power Profiles")
        for name, code in [
            ("🔋 Emergency (10W)", "emergency"),
            ("🔋 Battery (18W)", "battery"),
            ("⚡ Efficient (30W)", "efficient"),
            ("⚖️ Balanced (40W)", "balanced"),
            ("🚀 Performance (55W)", "performance"),
            ("🎮 Gaming (70W)", "gaming"),
            ("💪 Maximum (90W)", "maximum")
        ]:
            action = QAction(name, self)
            action.triggered.connect(lambda _, c=code: self.power.set_profile(c))
            profiles_menu.addAction(action)
        
        profiles_menu.addSeparator()
        
        # Charge Limit
        charge_menu = profiles_menu.addMenu("🔋 Battery Health")
        charge_menu.addAction("✅ Complete (100%)").triggered.connect(lambda: self.power.set_charge_limit(100))
        charge_menu.addAction("🛡️ Balanced (80%)").triggered.connect(lambda: self.power.set_charge_limit(80))
        
        profiles_menu.addSeparator()
        profiles_menu.addAction("📊 Status").triggered.connect(self.show_power_status)
        self.auto_action = QAction("🔄 Auto Switch (AC/Battery)", self)
        self.auto_action.setCheckable(True)
        self.auto_action.setChecked(self.power.is_auto_enabled())
        self.auto_action.triggered.connect(lambda checked: self.power.set_auto(checked))
        profiles_menu.addAction(self.auto_action)
            
        self.menu.addSeparator()
        
        # Display/Refresh Rate
        display_menu = self.menu.addMenu("🖥️ Display")
        for name, rate in [
            ("30 Hz (Battery)", "battery"),
            ("60 Hz (Efficient)", "efficient"),
            ("90 Hz (Balanced)", "balanced"),
            ("120 Hz (Performance)", "performance"),
            ("180 Hz (Gaming)", "gaming")
        ]:
            action = QAction(name, self)
            action.triggered.connect(lambda _, r=rate: self.set_refresh_rate(r))
            display_menu.addAction(action)
        
        self.menu.addSeparator()
        
        # RGB Controls
        rgb_menu = self.menu.addMenu("🌈 RGB Controls")
        
        # Keyboard submenu
        kb_menu = rgb_menu.addMenu("⌨️ Keyboard")
        
        # Colors
        kb_colors = kb_menu.addMenu("Colors")
        for name, color in [
            ("⬜ White", "FFFFFF"),
            ("🔴 Red", "FF0000"),
            ("🟢 Green", "00FF00"),
            ("🔵 Blue", "0000FF"),
            ("🟣 Purple", "8000FF"),
            ("🟡 Yellow", "FFFF00"),
            ("🟠 Orange", "FF8000"),
            ("🩷 Pink", "FF0080"),
            ("🩵 Cyan", "00FFFF"),
        ]:
            action = QAction(name, self)
            action.triggered.connect(lambda _, c=color: self.rgb.set_keyboard_color(c))
            kb_colors.addAction(action)
        
        # Brightness
        kb_bright = kb_menu.addMenu("Brightness")
        for level in range(4):
            label = ["Off", "Low", "Medium", "High"][level]
            action = QAction(f"{label} ({level})", self)
            action.triggered.connect(lambda _, l=level: self.rgb.set_keyboard_brightness(l))
            kb_bright.addAction(action)
        
        # Animations
        kb_anim = kb_menu.addMenu("Animations")
        kb_anim.addAction("🌈 Rainbow").triggered.connect(lambda: self.rgb.set_keyboard_animation("rainbow"))
        kb_anim.addAction("🔄 Color Cycle").triggered.connect(lambda: self.rgb.set_keyboard_animation("colorcycle"))
        kb_anim.addAction("🌬️ Breathing (Red)").triggered.connect(lambda: self.rgb.set_keyboard_animation("breathing", "FF0000", "000000"))
        kb_anim.addAction("🌬️ Breathing (Blue)").triggered.connect(lambda: self.rgb.set_keyboard_animation("breathing", "0000FF", "000000"))
        kb_anim.addAction("🌬️ Breathing (Purple)").triggered.connect(lambda: self.rgb.set_keyboard_animation("breathing", "8000FF", "000000"))
        
        kb_menu.addSeparator()
        kb_menu.addAction("⬜ Turn On (White)").triggered.connect(lambda: self.rgb.set_keyboard_color("FFFFFF"))
        kb_menu.addAction("⬛ Turn Off").triggered.connect(lambda: self.rgb.set_keyboard_brightness(0))
        
        # Rear Window/Lightbar submenu
        lb_menu = rgb_menu.addMenu("💡 Rear Window")
        
        # Colors
        lb_colors = lb_menu.addMenu("Colors")
        for name, rgb_vals in [
            ("⬜ White", (255, 255, 255)),
            ("🔴 Red", (255, 0, 0)),
            ("🟢 Green", (0, 255, 0)),
            ("🔵 Blue", (0, 0, 255)),
            ("🟣 Purple", (128, 0, 255)),
            ("🟡 Yellow", (255, 255, 0)),
            ("🟠 Orange", (255, 128, 0)),
            ("🩷 Pink", (255, 0, 128)),
            ("🩵 Cyan", (0, 255, 255)),
        ]:
            action = QAction(name, self)
            action.triggered.connect(lambda _, r=rgb_vals: self.rgb.set_window_color(*r))
            lb_colors.addAction(action)
        
        # Brightness
        lb_bright = lb_menu.addMenu("Brightness")
        for level in range(4):
            label = ["Off", "Low", "Medium", "High"][level]
            action = QAction(f"{label} ({level})", self)
            action.triggered.connect(lambda _, l=level: self.rgb.set_window_backlight(l))
            lb_bright.addAction(action)
        
        # Animations
        lb_anim = lb_menu.addMenu("Animations")
        lb_anim.addAction("🌈 Rainbow").triggered.connect(lambda: self.rgb.start_window_animation("rainbow"))
        lb_anim.addAction("🌬️ Breathing (White)").triggered.connect(lambda: self.rgb.start_window_animation("breathing", (255, 255, 255), (0, 0, 0)))
        lb_anim.addAction("🌬️ Breathing (Red)").triggered.connect(lambda: self.rgb.start_window_animation("breathing", (255, 0, 0), (0, 0, 0)))
        lb_anim.addAction("🌬️ Breathing (Blue)").triggered.connect(lambda: self.rgb.start_window_animation("breathing", (0, 0, 255), (0, 0, 0)))
        lb_anim.addAction("⏹️ Stop Animation").triggered.connect(self.rgb.stop_window_animation)
        
        lb_menu.addSeparator()
        lb_menu.addAction("⬜ Turn On (White)").triggered.connect(lambda: self.rgb.set_window_color(255, 255, 255))
        lb_menu.addAction("⬛ Turn Off").triggered.connect(lambda: self.rgb.set_window_backlight(0))
        
        # Quick RGB presets
        rgb_menu.addSeparator()
        rgb_menu.addAction("🔲 All Off").triggered.connect(self.rgb_all_off)
        rgb_menu.addAction("⬜ All White").triggered.connect(self.rgb_all_white)
        rgb_menu.addAction("🌈 All Rainbow").triggered.connect(self.rgb_all_rainbow)
        
        self.menu.addSeparator()
        self.menu.addAction("ℹ️ About").triggered.connect(self.show_about)
        self.menu.addAction("❌ Quit").triggered.connect(self.app.quit)

    def _on_activated(self, reason):
        """Handle tray icon activation.
        
        Right-click is handled natively by setContextMenu via dbusmenu/SNI.
        Left-click (Trigger) also shows the menu for convenience.
        """
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            # Left-click: show the same menu.  On Wayland popup() may fail
            # silently (no input serial), but setContextMenu covers right-click.
            try:
                self.menu.popup(QCursor.pos())
            except Exception:
                pass
    
    def set_refresh_rate(self, rate):
        """Set display refresh rate via rrcfg."""
        import subprocess
        try:
            # Use sudo -n for rrcfg as it requires elevated privileges for sysfs writes
            # and is configured with NOPASSWD in the sudoers policy by install-policy.sh
            result = subprocess.run(
                ["sudo", "-n", "/usr/local/bin/rrcfg", rate],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.notifier.notify("Display", f"Refresh profile set to {rate}", "success", 2000)
            else:
                self.notifier.notify("Display", f"Failed: {result.stderr.strip()}", "error", 3000)
        except FileNotFoundError:
            self.notifier.notify("Display", "rrcfg not installed", "error", 3000)
        except Exception as e:
            self.notifier.notify("Display", str(e), "error", 3000)
    
    def show_power_status(self):
        """Show current power status."""
        status = self.power.get_status()
        batt = self.power.get_battery_info()
        msg = f"Profile: {self.power.current_profile}\nBattery: {batt.get('percent', 'N/A')}%\nStatus: {batt.get('status', 'unknown')}"
        self.notifier.notify("Power Status", msg, "info", 5000)
    
    def show_about(self):
        """Show about information."""
        self.notifier.notify(
            "ASUS ROG Flow Z13 (GZ302)",
            "Power, Display & RGB control for\nASUS ROG Flow Z13 (GZ302)\n\nVersion 5.1.3",
            "info", 5000
        )
    
    def rgb_all_off(self):
        """Turn off all RGB."""
        self.rgb.set_keyboard_brightness(0)
        self.rgb.set_window_backlight(0)
    
    def rgb_all_white(self):
        """Set all RGB to white."""
        self.rgb.set_keyboard_color("FFFFFF")
        self.rgb.set_window_color(255, 255, 255)
    
    def rgb_all_rainbow(self):
        """Set all RGB to rainbow animation."""
        self.rgb.set_keyboard_animation("rainbow")
        self.rgb.start_window_animation("rainbow")

    def _build_fallback_icon(self, icon_name):
        """Build a visible raster fallback for tray backends that fail on SVG."""
        labels = {
            "ac": "A",
            "battery": "B",
            "profile-e": "E",
            "profile-b": "B",
            "profile-p": "P",
            "profile-g": "G",
            "profile-m": "M",
        }
        colors = {
            "ac": "#2563EB",
            "battery": "#16A34A",
            "profile-e": "#16A34A",
            "profile-b": "#2563EB",
            "profile-p": "#EA580C",
            "profile-g": "#9333EA",
            "profile-m": "#DC2626",
        }

        pixmap = QPixmap(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
        pixmap.fill(Qt.GlobalColor.transparent)

        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor(colors.get(icon_name, "#2563EB")))
        painter.setPen(QPen(Qt.GlobalColor.black, 2))
        painter.drawEllipse(2, 2, TRAY_ICON_SIZE - 4, TRAY_ICON_SIZE - 4)

        font = QFont()
        font.setBold(True)
        font.setPointSize(28)
        painter.setFont(font)
        painter.setPen(Qt.GlobalColor.white)
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, labels.get(icon_name, "B"))
        painter.end()

        return QIcon(pixmap)

    def _load_tray_icon(self, icon_path, icon_name):
        """Render SVG icons to a raster pixmap for Linux tray compatibility."""
        if icon_path.exists():
            if QSvgRenderer is not None:
                renderer = QSvgRenderer(str(icon_path))
                if renderer.isValid():
                    pixmap = QPixmap(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
                    pixmap.fill(Qt.GlobalColor.transparent)
                    painter = QPainter(pixmap)
                    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
                    renderer.render(painter)
                    painter.end()
                    if not pixmap.isNull():
                        return QIcon(pixmap)

        return self._build_fallback_icon(icon_name)

    def update_icon(self):
        """Update tray icon based on current power profile."""
        assets = Path(__file__).resolve().parent.parent / "assets"

        # When auto mode is active show power-source icon (battery vs AC)
        if self.power.is_auto_enabled():
            batt_info = self.power.get_battery_info()
            icon_name = "battery" if batt_info.get("plugged") is False else "ac"
        else:
            # Map profiles to icon suffixes
            profile_icons = {
                "emergency": "profile-e",
                "battery": "profile-b",
                "efficient": "profile-e",
                "balanced": "profile-b",
                "performance": "profile-p",
                "gaming": "profile-g",
                "maximum": "profile-m",
            }
            icon_name = profile_icons.get(self.power.current_profile, "profile-b")

        icon_path = assets / f"{icon_name}.svg"
        if not icon_path.exists():
            icon_path = assets / "profile-b.svg"
        self.setIcon(self._load_tray_icon(icon_path, icon_name))
    
    def update_status(self):
        try:
            # Run auto-switch check first (no-op if disabled)
            self.power.check_auto_switch()

            # Sync auto-action checkmark in case state changed externally
            self.auto_action.setChecked(self.power.is_auto_enabled())

            # Get profile TDP details
            profile = self.power.current_profile.capitalize()
            spl, sppt, fppt = self.power.get_profile_details()
            
            # Build tooltip with power info
            tooltip_lines = [
                "ASUS ROG Flow Z13 (GZ302)",
                f"Profile: {profile} ({spl}W)",
            ]
            
            # Show auto-switch status
            if self.power.is_auto_enabled():
                ac = self.power.get_ac_profile().capitalize()
                batt = self.power.get_battery_profile().capitalize()
                tooltip_lines.append(f"Auto: AC→{ac}, Batt→{batt}")
            
            # Battery info
            batt_info = self.power.get_battery_info()
            pct = batt_info.get('percent')
            if pct is not None:
                status = batt_info.get('status', 'unknown').capitalize()
                tooltip_lines.append(f"Battery: {pct}% ({status})")
            else:
                tooltip_lines.append("Power: AC")
            
            self.setToolTip("\n".join(tooltip_lines))
            
            # Update icon to match profile
            self.update_icon()
        except Exception:
            pass  # keep the QTimer alive; a single failure must not kill polling

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    
    # Wait for system tray to become available (DE may still be loading)
    if not QSystemTrayIcon.isSystemTrayAvailable():
        for _ in range(30):
            import time
            time.sleep(1)
            if QSystemTrayIcon.isSystemTrayAvailable():
                break
        else:
            print("ERROR: No system tray available after 30s", file=sys.stderr)
            sys.exit(1)
    
    tray = CommandCenterApp(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
