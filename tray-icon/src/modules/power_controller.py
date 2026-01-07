import subprocess
from pathlib import Path

# Profile definitions: "profile_name": (SPL, sPPT, fPPT) in watts
POWER_PROFILES = {
    "emergency": (10, 12, 12),
    "battery": (18, 20, 20),
    "efficient": (30, 35, 35),
    "balanced": (40, 45, 45),
    "performance": (55, 60, 60),
    "gaming": (70, 80, 80),
    "maximum": (90, 90, 90),
}

class PowerController:
    """Manages power profiles and battery settings."""
    
    PROFILE_FILE = Path("/etc/gz302/pwrcfg/current-profile")
    AUTO_CONFIG_FILE = Path("/etc/gz302/pwrcfg/auto-config")
    AC_PROFILE_FILE = Path("/etc/gz302/pwrcfg/ac-profile")
    BATTERY_PROFILE_FILE = Path("/etc/gz302/pwrcfg/battery-profile")
    
    def __init__(self, notifier):
        self.notifier = notifier
        self.current_profile = self._read_current_profile()
    
    def _read_current_profile(self):
        """Read current profile from config file."""
        try:
            if self.PROFILE_FILE.exists():
                return self.PROFILE_FILE.read_text().strip()
        except:
            pass
        return "balanced"
    
    def is_auto_enabled(self):
        """Check if auto-switching is enabled."""
        try:
            if self.AUTO_CONFIG_FILE.exists():
                return self.AUTO_CONFIG_FILE.read_text().strip().lower() == "true"
        except:
            pass
        return False
    
    def get_ac_profile(self):
        """Get AC profile for auto-switching."""
        try:
            if self.AC_PROFILE_FILE.exists():
                return self.AC_PROFILE_FILE.read_text().strip()
        except:
            pass
        return "gaming"
    
    def get_battery_profile(self):
        """Get battery profile for auto-switching."""
        try:
            if self.BATTERY_PROFILE_FILE.exists():
                return self.BATTERY_PROFILE_FILE.read_text().strip()
        except:
            pass
        return "battery"
    
    def get_profile_details(self, profile=None):
        """Get TDP details for a profile (SPL, sPPT, fPPT in watts)."""
        if profile is None:
            profile = self.current_profile
        return POWER_PROFILES.get(profile, (0, 0, 0))

    def set_profile(self, profile):
        """Change power profile via pwrcfg."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", profile],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode == 0:
                power_info = ""
                for line in result.stdout.split("\n"):
                    if "SPL" in line or "Refresh" in line:
                        power_info += line.strip() + "\n"
                        
                self.notifier.notify_profile_change(profile, power_info.strip())
                self.current_profile = profile
                return True
            else:
                err = result.stderr.strip()
                hint = "Check sudo permissions" if "permission" in err.lower() else ""
                self.notifier.notify_error("Profile Change Failed", err, hint)
                return False
        except Exception as e:
            self.notifier.notify_error("Profile Change Failed", str(e))
            return False

    def set_charge_limit(self, limit):
        """Set battery charge limit (80 or 100)."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "charge-limit", str(limit)],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.notifier.notify("Battery", f"Charge limit set to {limit}%", "success", 2000)
                return True
            else:
                self.notifier.notify_error("Charge Limit Failed", result.stderr.strip())
                return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def get_status(self):
        """Get current power status string."""
        try:
            result = subprocess.run(
                ["sudo", "/usr/local/bin/pwrcfg", "status"],
                capture_output=True, text=True, timeout=10
            )
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Unknown"

    def get_battery_info(self):
        """Get battery percentage and status."""
        # Try sysfs first
        try:
            from pathlib import Path
            for sup in Path("/sys/class/power_supply").glob("*"):
                if (sup / "status").exists():
                    status = (sup / "status").read_text().strip().lower()
                    if (sup / "capacity").exists():
                        pct = int((sup / "capacity").read_text().strip())
                        return {"percent": pct, "plugged": status != "discharging", "status": status}
        except:
            pass
        return {"percent": None, "plugged": None, "status": "unknown"}
