#!/usr/bin/env python3
"""
GZ302 Command Center — Strix Halo Edition (v6.2.0)
Unified Dashboard and System Tray Controller.
Inspired by G-Helper and Strix-Halo-Control.
"""
import sys
import os
import signal
import subprocess
import re
from pathlib import Path
from PyQt6.QtWidgets import (
    QApplication, QSystemTrayIcon, QMenu, QWidget, QVBoxLayout, 
    QHBoxLayout, QLabel, QPushButton, QFrame, QGridLayout, 
    QComboBox, QSlider, QProgressBar, QStackedWidget, QListWidget,
    QLineEdit, QScrollArea
)
from PyQt6.QtGui import QIcon, QAction, QColor, QFont, QPainter, QPixmap
from PyQt6.QtCore import QTimer, Qt, QProcess, QSize

try:
    from PyQt6.QtSvg import QSvgRenderer
except ImportError:
    QSvgRenderer = None

try:
    import psutil
except ImportError:
    psutil = None

# Import modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from modules.config import ConfigManager
from modules.notifications import NotificationManager
from modules.rgb_controller import RGBController
from modules.power_controller import PowerController

TRAY_ICON_SIZE = 24
VERSION = "6.2.0"

class DashboardWindow(QWidget):
    """The main ROG-themed control panel with Sidebar Navigation."""
    def __init__(self, power_ctrl, rgb_controller, config, notifier):
        super().__init__()
        self.power = power_ctrl
        self.rgb = rgb_controller
        self.config = config
        self.notifier = notifier
        
        self.setWindowTitle("GZ302 Strix Halo Control")
        self.setFixedSize(650, 500)
        self.setWindowFlags(Qt.WindowType.Window | Qt.WindowType.WindowCloseButtonHint)
        
        self.setup_ui()
        self.apply_styles()
        
    def setup_ui(self):
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # --- Sidebar ---
        self.sidebar = QListWidget()
        self.sidebar.setFixedWidth(160)
        self.sidebar.setObjectName("sidebar")
        self.sidebar.addItems(["🏠 Dashboard", "⚡ Performance", "🌈 Lighting", "🌪️ Fan Curves", "🧠 AI & NPU"])
        self.sidebar.currentRowChanged.connect(self.display_tab)
        layout.addWidget(self.sidebar)
        
        # --- Content Area ---
        self.content = QStackedWidget()
        layout.addWidget(self.content)
        
        self.create_dashboard_tab()
        self.create_performance_tab()
        self.create_lighting_tab()
        self.create_fans_tab()
        self.create_ai_tab()
        
        self.sidebar.setCurrentRow(0)

    def create_dashboard_tab(self):
        tab = QWidget()
        vbox = QVBoxLayout(tab)
        
        header = QFrame()
        header.setObjectName("header_panel")
        h_layout = QVBoxLayout(header)
        h_layout.addWidget(QLabel("ROG FLOW Z13 (GZ302)"), alignment=Qt.AlignmentFlag.AlignCenter)
        self.big_temp = QLabel("--°C")
        self.big_temp.setObjectName("big_stat")
        h_layout.addWidget(self.big_temp, alignment=Qt.AlignmentFlag.AlignCenter)
        vbox.addWidget(header)
        
        grid = QGridLayout()
        self.cpu_usage = QProgressBar()
        grid.addWidget(QLabel("CPU LOAD:"), 0, 0)
        grid.addWidget(self.cpu_usage, 0, 1)
        
        self.fan_stat = QLabel("Fans: 0 RPM")
        grid.addWidget(self.fan_stat, 1, 0, 1, 2)
        
        self.pwr_stat = QLabel("Power: Balanced (40W)")
        grid.addWidget(self.pwr_stat, 2, 0, 1, 2)
        
        vbox.addLayout(grid)
        vbox.addStretch()
        self.content.addWidget(tab)

    def create_performance_tab(self):
        tab = QWidget()
        vbox = QVBoxLayout(tab)
        vbox.addWidget(QLabel("PERFORMANCE PROFILES"))
        
        for name, code in [("Silent (Quiet)", "quiet"), ("Balanced", "balanced"), ("Turbo (Perf)", "performance"), ("Maximum (Gaming)", "gaming")]:
            btn = QPushButton(name)
            btn.clicked.connect(lambda _, c=code: self.power.set_profile(c))
            vbox.addWidget(btn)
            
        vbox.addWidget(QLabel("BATTERY CHARGE LIMIT"))
        hbox = QHBoxLayout()
        for lim in [60, 80, 100]:
            btn = QPushButton(f"{lim}%")
            btn.clicked.connect(lambda _, l=lim: self.power.set_charge_limit(l))
            hbox.addWidget(btn)
        vbox.addLayout(hbox)
        vbox.addStretch()
        self.content.addWidget(tab)

    def create_lighting_tab(self):
        tab = QWidget()
        vbox = QVBoxLayout(tab)
        vbox.addWidget(QLabel("RGB LIGHTING"))
        
        vbox.addWidget(QLabel("Keyboard Brightness:"))
        kb_s = QSlider(Qt.Orientation.Horizontal)
        kb_s.setRange(0, 3)
        kb_s.valueChanged.connect(self.rgb.set_keyboard_brightness)
        vbox.addWidget(kb_s)
        
        vbox.addWidget(QLabel("Rear Window Brightness:"))
        lb_s = QSlider(Qt.Orientation.Horizontal)
        lb_s.setRange(0, 3)
        lb_s.valueChanged.connect(self.rgb.set_window_backlight)
        vbox.addWidget(lb_s)
        
        hbox = QHBoxLayout()
        rb = QPushButton("Rainbow")
        rb.clicked.connect(lambda: self.rgb.set_keyboard_animation("rainbow"))
        hbox.addWidget(rb)
        off = QPushButton("All Off")
        off.clicked.connect(self.rgb.turn_off)
        hbox.addWidget(off)
        vbox.addLayout(hbox)
        
        vbox.addStretch()
        self.content.addWidget(tab)

    def create_fans_tab(self):
        tab = QWidget()
        vbox = QVBoxLayout(tab)
        vbox.addWidget(QLabel("CUSTOM FAN CURVE"))
        
        self.curve_input = QLineEdit("48:2,53:22,57:30,60:43,63:56,65:68,70:89,76:102")
        vbox.addWidget(QLabel("Curve (temp:pwm pairs):"))
        vbox.addWidget(self.curve_input)
        
        apply_btn = QPushButton("Apply Curve")
        apply_btn.clicked.connect(self.apply_fan_curve)
        vbox.addWidget(apply_btn)
        
        vbox.addWidget(QLabel("Note: 8 points required. Format: T1:P1,T2:P2..."))
        vbox.addStretch()
        self.content.addWidget(tab)

    def create_ai_tab(self):
        tab = QWidget()
        vbox = QVBoxLayout(tab)
        vbox.addWidget(QLabel("STRIX HALO AI / NPU STATUS"))
        
        self.npu_stat = QLabel("AMD Ryzen AI (NPU): Active")
        vbox.addWidget(self.npu_stat)
        
        vbox.addWidget(QLabel("Graphics: Radeon 8060S (gfx1151)"))
        vbox.addWidget(QLabel("UMA Framebuffer: Dynamic (GTT)"))
        
        vbox.addStretch()
        self.content.addWidget(tab)

    def display_tab(self, index):
        self.content.setCurrentIndex(index)

    def apply_fan_curve(self):
        curve = self.curve_input.text().strip()
        subprocess.run(["sudo", "-n", "z13ctl", "fancurve", "--set", curve])
        self.notifier.notify("Fans", "Custom curve applied", "success")

    def apply_styles(self):
        self.setStyleSheet("""
            QWidget { background-color: #0f0f0f; color: #ffffff; font-family: sans-serif; }
            #sidebar { background-color: #1a1a1a; border: none; font-size: 13px; padding-top: 10px; }
            #sidebar::item { padding: 12px; border-left: 3px solid transparent; }
            #sidebar::item:selected { background-color: #2a2a2a; border-left: 3px solid #ff4d4d; color: #ff4d4d; }
            #header_panel { background-color: #1a1a1a; border-radius: 10px; margin: 10px; }
            #big_stat { font-size: 32px; font-weight: bold; color: #00ccff; }
            QPushButton { background-color: #222; border: 1px solid #333; padding: 10px; border-radius: 5px; margin: 2px; }
            QPushButton:hover { background-color: #333; }
            QProgressBar { border: 1px solid #333; border-radius: 5px; text-align: center; background: #000; }
            QProgressBar::chunk { background-color: #ff4d4d; }
            QLabel { font-size: 11px; color: #888; text-transform: uppercase; }
        """)

    def update_ui_states(self):
        status = self.power.get_status()
        temp, fans = "--°C", "0 RPM"
        for line in status.splitlines():
            if "APU:" in line: temp = line.split(":")[1].strip()
            if "Fans:" in line: fans = re.sub(r', mode:.*', '', line.split(":")[1].strip())
        
        self.big_temp.setText(temp)
        self.fan_stat.setText(f"FANS: {fans}")
        self.pwr_stat.setText(f"POWER: {self.power.current_profile.upper()}")
        
        if psutil:
            self.cpu_usage.setValue(int(psutil.cpu_percent()))

class CommandCenterApp(QSystemTrayIcon):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.config = ConfigManager()
        self.notifier = NotificationManager(self)
        self.rgb = RGBController(self.notifier)
        self.power = PowerController(self.notifier)
        
        self.dashboard = DashboardWindow(self.power, self.rgb, self.config, self.notifier)
        
        self.menu = QMenu()
        self.setup_menu()
        self.setContextMenu(self.menu)
        
        self.activated.connect(self._on_activated)
        self.update_icon()
        self.show()
        
        self.timer = QTimer()
        self.timer.timeout.connect(self.poll_status)
        self.timer.start(3000)
        
        self.notifier.notify("Strix Halo", "Control Panel Ready", "success", 2000)

    def setup_menu(self):
        self.menu.clear()
        self.menu.addAction("🖥️ Open Dashboard").triggered.connect(self.dashboard.show)
        self.menu.addSeparator()
        profiles_menu = self.menu.addMenu("⚡ Profiles")
        for n, c in [("Silent", "quiet"), ("Balanced", "balanced"), ("Turbo", "performance")]:
            a = QAction(n, self)
            a.triggered.connect(lambda _, code=c: self.power.set_profile(code))
            profiles_menu.addAction(a)
        self.menu.addSeparator()
        self.menu.addAction("❌ Quit").triggered.connect(self.app.quit)

    def _on_activated(self, reason):
        if reason in (QSystemTrayIcon.ActivationReason.Trigger, QSystemTrayIcon.ActivationReason.DoubleClick):
            if self.dashboard.isVisible(): self.dashboard.hide()
            else: self.dashboard.show(); self.dashboard.raise_(); self.dashboard.activateWindow()

    def update_icon(self):
        assets = Path(__file__).resolve().parent.parent / "assets"
        icon_name = "battery" if self.power.is_auto_enabled() and not self.power.get_battery_info().get("plugged") else "ac"
        if not self.power.is_auto_enabled():
            icon_name = {"quiet": "profile-b", "balanced": "profile-b", "performance": "profile-p", "gaming": "profile-g"}.get(self.power.current_profile, "profile-b")
        
        icon_path = assets / f"{icon_name}.svg"
        if QSvgRenderer is not None and icon_path.exists():
            renderer = QSvgRenderer(str(icon_path))
            if renderer.isValid():
                pixmap = QPixmap(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
                pixmap.fill(Qt.GlobalColor.transparent)
                painter = QPainter(pixmap)
                renderer.render(painter)
                painter.end()
                self.setIcon(QIcon(pixmap))
                return
        self.setIcon(QIcon.fromTheme("preferences-desktop-peripherals"))

    def poll_status(self):
        try:
            self.power.check_auto_switch()
            self.update_icon()
            if self.dashboard.isVisible(): self.dashboard.update_ui_states()
        except Exception: pass

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = QApplication(sys.argv)
    app.setApplicationName("GZ302 Dashboard")
    app.setQuitOnLastWindowClosed(False)
    
    if not QSystemTrayIcon.isSystemTrayAvailable():
        for _ in range(10):
            import time
            time.sleep(1)
            if QSystemTrayIcon.isSystemTrayAvailable(): break
            
    tray = CommandCenterApp(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
