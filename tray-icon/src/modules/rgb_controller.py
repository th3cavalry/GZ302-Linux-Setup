import subprocess
import threading
from pathlib import Path

# Speed mapping: internal numeric → z13ctl speed names
_SPEED_MAP = {1: "slow", 2: "normal", 3: "fast"}


class RGBController:
    """Manages Keyboard and Lightbar RGB control via z13ctl."""

    def __init__(self, notifier):
        self.notifier = notifier
        self.window_animation_thread = None
        self.window_animation_stop = None
        self._check_installation()

    def _check_installation(self):
        self.keyboard_available = self.check_available()
        # z13ctl handles both keyboard and lightbar
        self.window_available = self.keyboard_available

    def check_available(self):
        try:
            for p in ["/usr/local/bin/z13ctl", "/usr/bin/z13ctl"]:
                if Path(p).exists():
                    return True
            result = subprocess.run(["which", "z13ctl"], capture_output=True, timeout=2)
            return result.returncode == 0
        except Exception:
            return False

    def set_keyboard_color(self, hex_color):
        if not self.keyboard_available:
            self.notifier.notify_error(
                "RGB", "z13ctl not installed. Run: sudo ./gz302-setup.sh"
            )
            return
        self._run_bg_command(
            ["sudo", "-n", "z13ctl", "apply", "--mode", "static", "--color", hex_color],
            success_msg=f"Color set to #{hex_color}",
            error_msg="Failed to set color",
        )

    def set_keyboard_animation(self, anim_type, c1=None, c2=None, speed=2):
        if not self.keyboard_available:
            self.notifier.notify_error("RGB", "z13ctl not installed")
            return
        speed_name = _SPEED_MAP.get(speed, "normal")
        cmd = ["sudo", "-n", "z13ctl", "apply"]
        desc = ""
        if anim_type == "breathing":
            cmd += [
                "--mode", "breathe", "--color", c1 or "FFFFFF", "--speed", speed_name,
            ]
            desc = "Breathing"
        elif anim_type == "colorcycle":
            cmd += ["--mode", "cycle", "--speed", speed_name]
            desc = "Color Cycle"
        elif anim_type == "rainbow":
            cmd += ["--mode", "rainbow", "--speed", speed_name]
            desc = "Rainbow"
        else:
            self.notifier.notify_error("RGB", f"Unknown animation: {anim_type}")
            return
        self._run_bg_command(
            cmd,
            success_msg=f"{desc} activated",
            error_msg="Failed to set animation",
        )

    def set_keyboard_brightness(self, level):
        if not (0 <= level <= 3):
            return
        if not self.keyboard_available:
            self.notifier.notify_error("RGB", "z13ctl not installed")
            return
        level_name = {0: "off", 1: "low", 2: "medium", 3: "high"}.get(level, "medium")
        self._run_bg_command(
            ["sudo", "-n", "z13ctl", "brightness", level_name],
            success_msg=f"Brightness set to {level_name}",
            error_msg="Failed to set brightness",
            timeout=5,
        )

    def turn_off(self):
        if not self.keyboard_available:
            return
        self._run_bg_command(
            ["sudo", "-n", "z13ctl", "off"],
            success_msg="Lighting turned off",
            error_msg="Failed to turn off lighting",
        )

    def _run_bg_command(self, cmd, success_msg, error_msg, timeout=60):
        def worker():
            try:
                res = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=timeout
                )
                if res.returncode == 0:
                    self.notifier.notify("RGB", success_msg, "success", 2000)
                else:
                    err_detail = (
                        res.stderr.strip() or res.stdout.strip() or "Unknown error"
                    )
                    if "permission" in err_detail.lower():
                        hint = "Check sudoers: /etc/sudoers.d/gz302"
                        self.notifier.notify_error("RGB Error", f"{error_msg}\n{hint}")
                    else:
                        self.notifier.notify_error(
                            "RGB Error", f"{error_msg}: {err_detail[:100]}"
                        )
            except subprocess.TimeoutExpired:
                self.notifier.notify_error(
                    "RGB Error", f"{error_msg}: Command timed out"
                )
            except FileNotFoundError:
                self.notifier.notify_error(
                    "RGB Error", "z13ctl not found. Run gz302-setup.sh"
                )
                self.keyboard_available = False
            except Exception as e:
                self.notifier.notify_error("RGB Error", str(e)[:100])
        threading.Thread(target=worker, daemon=True).start()

    # --- Window / Lightbar ---
    # z13ctl handles lightbar natively; these methods provide tray-level
    # animation that calls z13ctl apply per frame for advanced effects
    # not yet supported by z13ctl's built-in modes.

    def set_window_backlight(self, level):
        if not self.window_available:
            self.notifier.notify_error("Lightbar", "z13ctl not installed")
            return
        if level == 0:
            self._run_bg_command(
                ["sudo", "-n", "z13ctl", "off"],
                success_msg="Lightbar turned off",
                error_msg="Failed to turn off lightbar",
            )
        else:
            level_name = {1: "low", 2: "medium", 3: "high"}.get(level, "medium")
            self._run_bg_command(
                ["sudo", "-n", "z13ctl", "apply", "--brightness", level_name],
                success_msg=f"Lightbar brightness: {level_name}",
                error_msg="Failed to set lightbar brightness",
            )

    def set_window_color(self, r, g, b):
        self.stop_window_animation()
        if not self.window_available:
            self.notifier.notify_error("Lightbar", "z13ctl not installed")
            return
        hex_color = f"{r:02x}{g:02x}{b:02x}"
        self._run_bg_command(
            ["sudo", "-n", "z13ctl", "apply", "--mode", "static", "--color", hex_color],
            success_msg=f"Lightbar color: RGB({r},{g},{b})",
            error_msg="Failed to set lightbar color",
        )

    def stop_window_animation(self):
        if self.window_animation_stop:
            self.window_animation_stop.set()
        if self.window_animation_thread:
            self.window_animation_thread.join(timeout=1)
        self.window_animation_stop = None
        self.window_animation_thread = None

    def start_window_animation(self, anim_type, c1=None, c2=None, speed=2):
        self.stop_window_animation()
        speed_name = _SPEED_MAP.get(speed, "normal")
        # Use z13ctl's built-in animation modes when available
        if anim_type == "rainbow":
            self._run_bg_command(
                [
                    "sudo", "-n", "z13ctl", "apply",
                    "--mode", "rainbow", "--speed", speed_name,
                ],
                success_msg="Lightbar: Rainbow",
                error_msg="Failed to set lightbar animation",
            )
            return
        if anim_type == "breathing":
            color = f"{c1[0]:02x}{c1[1]:02x}{c1[2]:02x}" if c1 else "FFFFFF"
            self._run_bg_command(
                [
                    "sudo", "-n", "z13ctl", "apply",
                    "--mode", "breathe", "--color", color, "--speed", speed_name,
                ],
                success_msg="Lightbar: Breathing",
                error_msg="Failed to set lightbar animation",
            )
            return
        self.notifier.notify(
            "Lightbar", f"Animation: {anim_type.title()}", "success", 2000
        )
