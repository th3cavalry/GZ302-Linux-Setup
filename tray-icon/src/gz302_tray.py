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
        
        # Power Profiles
        profiles_menu = self.menu.addMenu("Power Profiles")
        for name, code in [
            ("🔋 Battery (18W)", "battery"),
            ("⚖️ Balanced (40W)", "balanced"),
            ("🚀 Performance (55W)", "performance"),
            ("🎮 Gaming (70W)", "gaming")
        ]:
            action = QAction(name, self)
            action.triggered.connect(lambda _, c=code: self.power.set_profile(c))
            profiles_menu.addAction(action)
            
        self.menu.addSeparator()
        
        # RGB Controls
        rgb_menu = self.menu.addMenu("RGB Controls")
        
        # Keyboard
        kb_menu = rgb_menu.addMenu("Keyboard")
        kb_menu.addAction("Turn On (White)").triggered.connect(lambda: self.rgb.set_keyboard_color("FFFFFF"))
        kb_menu.addAction("Turn Off").triggered.connect(lambda: self.rgb.set_keyboard_brightness(0))
        kb_menu.addSeparator()
        kb_menu.addAction("Rainbow").triggered.connect(lambda: self.rgb.set_keyboard_animation("rainbow"))
        kb_menu.addAction("Breathing").triggered.connect(lambda: self.rgb.set_keyboard_animation("breathing", "FF0000", "000000"))
        
        # Lightbar
        lb_menu = rgb_menu.addMenu("Rear Window")
        lb_menu.addAction("Turn On (White)").triggered.connect(lambda: self.rgb.set_window_color(255, 255, 255))
        lb_menu.addAction("Turn Off").triggered.connect(lambda: self.rgb.set_window_backlight(0))
        
        self.menu.addSeparator()
        self.menu.addAction("Quit").triggered.connect(self.app.quit)

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
