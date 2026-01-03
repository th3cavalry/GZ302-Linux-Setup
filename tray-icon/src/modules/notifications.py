from PyQt6.QtWidgets import QSystemTrayIcon

# Optional: Try to import notify2 for better desktop notifications
try:
    import notify2
    NOTIFY2_AVAILABLE = True
except ImportError:
    NOTIFY2_AVAILABLE = False

class NotificationManager:
    """Manages desktop notifications with optional sound feedback"""

    def __init__(self, tray_icon):
        self.tray = tray_icon
        self.notify2_initialized = False
        self._app_name = "GZ302 Control Center"

        # Try to initialize notify2 for richer notifications
        if NOTIFY2_AVAILABLE:
            try:
                notify2.init("GZ302 Control Center")
                self.notify2_initialized = True
            except Exception:
                pass

    @property
    def app_name(self):
        """Get app name from tray's config if available."""
        try:
            return self.tray.config.get_app_name()
        except:
            return self._app_name

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

        # Prepend application name for clarity
        self.notify(f"{self.app_name}: {title}", message, "success", 4000)

    def notify_error(self, title, message, hint=""):
        """Send error notification with optional hint"""
        full_message = message
        if hint:
            full_message += f"\n\n💡 Tip: {hint}"
        self.notify(f"{self.app_name}: {title}", full_message, "error", 6000, "critical")
