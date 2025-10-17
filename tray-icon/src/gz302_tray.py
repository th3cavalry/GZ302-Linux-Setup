#!/usr/bin/env python3
"""
GZ302 Power Profile Tray Icon
A system tray utility for managing power profiles on ASUS ROG Flow Z13 (GZ302)
"""

import sys
import subprocess
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
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
        
        # Quit action
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(QApplication.quit)
        self.menu.addAction(quit_action)
    
    def change_profile(self, profile):
        """Change power profile using sudo (no password required)"""
        try:
            result = subprocess.run(
                ["sudo", "pwrcfg", profile],
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
                self.showMessage(
                    "Error",
                    f"Failed to change profile: {result.stderr}",
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
                ["sudo", "pwrcfg", "status"],
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
                ["sudo", "-n", "pwrcfg", "status"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                # Extract profile name from status output
                status = result.stdout
                self.setToolTip(f"GZ302 Power Manager\n{status}")
            else:
                self.setToolTip("GZ302 Power Manager\nStatus: Unknown")
        except:
            self.setToolTip("GZ302 Power Manager")

def main():
    app = QApplication(sys.argv)
    
    # For now, use a simple icon (you can replace with custom icon later)
    icon = app.style().standardIcon(QApplication.style().StandardPixmap.SP_ComputerIcon)
    
    tray = GZ302TrayIcon(icon)
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
