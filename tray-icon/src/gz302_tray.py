#!/usr/bin/env python3
"""
GZ302 Control Center (Modular v4)
"""
import sys
import os
import signal
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QWidget
from PyQt6.QtGui import QIcon, QAction
from PyQt6.QtCore import QTimer
from pathlib import Path

# Import our modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from modules.config import ConfigManager
from modules.notifications import NotificationManager
from modules.rgb_controller import RGBController
from modules.power_controller import PowerController

class GZ302TrayApp(QSystemTrayIcon):
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
        self.setContextMenu(self.menu)
        
        # Set icon
        self.update_icon()
        self.show()
        
        # Timer for status updates
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_status)
        self.timer.start(5000)
        
        # Welcome
        self.notifier.notify(self.config.get_app_name(), "Control Center Ready", "info", 3000)

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
        profiles_menu.addAction("📊 Status").triggered.connect(self.show_power_status)
        profiles_menu.addAction("🔄 Auto (AC/Battery)").triggered.connect(lambda: self.power.set_profile("auto"))
            
        self.menu.addSeparator()
        
        # Display/Refresh Rate
        display_menu = self.menu.addMenu("🖥️ Display")
        for name, rate in [
            ("30 Hz (Battery)", "30"),
            ("60 Hz (Efficient)", "60"),
            ("90 Hz (Balanced)", "90"),
            ("120 Hz (Performance)", "120"),
            ("180 Hz (Gaming)", "180")
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
    
    def set_refresh_rate(self, rate):
        """Set display refresh rate via rrcfg."""
        import subprocess
        try:
            result = subprocess.run(
                ["sudo", "-n", "/usr/local/bin/rrcfg", rate],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.notifier.notify("Display", f"Refresh rate set to {rate}Hz", "success", 2000)
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
            "GZ302 Control Center",
            "Power, Display & RGB control for\nASUS ROG Flow Z13 (GZ302)\n\nVersion 4.0.0",
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

    def update_icon(self):
        # Path resolution logic for assets...
        assets = Path(__file__).parent.parent / "assets"
        icon_path = assets / "profile-b.svg"
        if icon_path.exists():
            self.setIcon(QIcon(str(icon_path)))
    
    def update_status(self):
        # Update tooltip with battery info
        batt = self.power.get_battery_info()
        pct = batt.get('percent')
        status = f"Battery: {pct}%" if pct else "AC Power"
        self.setToolTip(f"GZ302 Control Center\n{status}")

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    
    # Hidden widget for Wayland support
    w = QWidget()
    w.hide()
    
    tray = GZ302TrayApp(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
