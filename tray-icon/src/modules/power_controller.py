import subprocess
from pathlib import Path

# z13ctl profile names: quiet, balanced, performance
# We map our extended profile names to z13ctl profiles + TDP overrides.
POWER_PROFILES = {
    "quiet":       {"z13ctl_profile": "quiet",       "tdp": None},
    "balanced":    {"z13ctl_profile": "balanced",     "tdp": None},
    "performance": {"z13ctl_profile": "performance",  "tdp": None},
}


class PowerController:
    """Manages power profiles and battery settings via z13ctl."""

    def __init__(self, notifier):
        self.notifier = notifier
        self.current_profile = self._read_current_profile()

    def _read_current_profile(self):
        try:
            result = subprocess.run(
                ["sudo", "-n", "z13ctl", "status"],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                for line in result.stdout.splitlines():
                    low = line.lower()
                    if "profile" in low and ":" in line:
                        return line.split(":", 1)[1].strip().lower()
        except Exception:
            pass
        return "balanced"

    def set_profile(self, profile):
        try:
            spec = POWER_PROFILES.get(profile)
            if spec:
                z13_profile = spec["z13ctl_profile"]
            else:
                # Accept raw z13ctl profile names too
                z13_profile = profile

            result = subprocess.run(
                ["sudo", "-n", "z13ctl", "profile", "--set", z13_profile],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode == 0:
                self.notifier.notify_profile_change(profile, result.stdout.strip())
                self.current_profile = profile
                # Apply TDP override if specified
                if spec and spec.get("tdp"):
                    subprocess.run(
                        ["sudo", "-n", "z13ctl", "tdp", "--set", str(spec["tdp"])],
                        capture_output=True, text=True, timeout=10,
                    )
                return True
            else:
                err = result.stderr.strip()
                hint = "Check sudo permissions" if "permission" in err.lower() else ""
                self.notifier.notify_error("Profile Change Failed", err, hint)
                return False
        except Exception as e:
            self.notifier.notify_error("Profile Change Failed", str(e))
            return False

    def set_tdp(self, watts):
        try:
            result = subprocess.run(
                ["sudo", "-n", "z13ctl", "tdp", "--set", str(watts)],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                self.notifier.notify("Power", f"TDP set to {watts}W", "success", 2000)
                return True
            else:
                self.notifier.notify_error("TDP Failed", result.stderr.strip())
                return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def set_charge_limit(self, limit):
        try:
            result = subprocess.run(
                ["sudo", "-n", "z13ctl", "batterylimit", "--set", str(limit)],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                self.notifier.notify(
                    "Battery", f"Charge limit set to {limit}%", "success", 2000
                )
                return True
            else:
                self.notifier.notify_error("Charge Limit Failed", result.stderr.strip())
                return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def get_status(self):
        try:
            result = subprocess.run(
                ["sudo", "-n", "z13ctl", "status"],
                capture_output=True, text=True, timeout=10,
            )
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except Exception:
            return "Unknown"

    def get_battery_info(self):
        try:
            for sup in Path("/sys/class/power_supply").glob("*"):
                if (sup / "status").exists():
                    status = (sup / "status").read_text().strip().lower()
                    if (sup / "capacity").exists():
                        pct = int((sup / "capacity").read_text().strip())
                        return {
                            "percent": pct,
                            "plugged": status != "discharging",
                            "status": status,
                        }
        except Exception:
            pass
        return {"percent": None, "plugged": None, "status": "unknown"}
