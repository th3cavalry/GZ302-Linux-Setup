import os
import subprocess
import threading
from pathlib import Path
import time
import colorsys

class RGBController:
    """Manages Keyboard and Lightbar RGB control."""
    
    def __init__(self, notifier):
        self.notifier = notifier
        self.window_animation_thread = None
        self.window_animation_stop = None

    def check_available(self):
        """Check if gz302-rgb binary is available."""
        try:
            result = subprocess.run(["which", "gz302-rgb"], capture_output=True, timeout=2)
            if result.returncode == 0:
                return True
            if Path("/usr/local/bin/gz302-rgb").exists():
                return True
            return False
        except Exception:
            return False

    def save_setting(self, command, *args):
        """Save RGB setting to config file for boot persistence."""
        try:
            config_dir = "/etc/gz302"
            config_file = f"{config_dir}/rgb-keyboard.conf"
            command_str = f"{command} {' '.join(str(a) for a in args)}".strip()
            
            lines = [
                f'KEYBOARD_COMMAND="{command_str}"',
                f'COMMAND="{command}"'
            ]
            for i, arg in enumerate(args, 1):
                lines.append(f'ARG{i}="{arg}"')
            lines.append(f"ARGC={len(args) + 1}")
            
            self._write_config(config_file, lines)
        except Exception:
            pass

    def set_keyboard_color(self, hex_color):
        """Set static color."""
        self._run_bg_command(
            ["sudo", "-n", "gz302-rgb", "single_static", hex_color],
            success_msg=f"🌈 Color set to #{hex_color}",
            error_msg="Failed to set color",
            save_cb=lambda: self.save_setting("single_static", hex_color)
        )

    def set_keyboard_animation(self, anim_type, c1=None, c2=None, speed=2):
        cmd = []
        desc = ""
        if anim_type == "breathing":
            cmd = ["single_breathing", c1, c2, str(speed)]
            desc = "🌬️ Breathing"
        elif anim_type == "colorcycle":
            cmd = ["single_colorcycle", str(speed)]
            desc = "🔄 Color Cycle"
        elif anim_type == "rainbow":
            cmd = ["rainbow_cycle", str(speed)]
            desc = "🌈 Rainbow"
            
        full_cmd = ["sudo", "-n", "gz302-rgb"] + cmd
        
        self._run_bg_command(
            full_cmd,
            success_msg=f"{desc} activated",
            error_msg="Failed to set animation",
            save_cb=lambda: self.save_setting(*cmd)
        )

    def set_keyboard_brightness(self, level):
        if not (0 <= level <= 3): return
        
        self._run_bg_command(
            ["sudo", "-n", "gz302-rgb", "brightness", str(level)],
            success_msg=f"Brightness set to level {level}",
            error_msg="Failed to set brightness",
            timeout=5
        )

    def _run_bg_command(self, cmd, success_msg, error_msg, save_cb=None, timeout=60):
        def worker():
            try:
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
                if res.returncode == 0 and "Error:" not in res.stderr:
                    if save_cb: save_cb()
                    self.notifier.notify("Keyboard RGB", success_msg, "success", 2000)
                else:
                    self.notifier.notify_error("RGB Error", f"{error_msg}: {res.stderr.strip()}")
            except Exception as e:
                self.notifier.notify_error("RGB Error", str(e))
        threading.Thread(target=worker, daemon=True).start()

    # --- Window / Lightbar Logic ---
    
    def _find_lightbar(self):
        """Find the lightbar HID raw device by physical path signature."""
        import glob
        # Try primary signature first
        sigs = ["usb-0000:c6:00.0-5/input0", "usb-0000:c6:00.0-5"]
        
        for path in glob.glob("/sys/class/hidraw/hidraw*"):
            try:
                uevent = Path(path) / "device/uevent"
                if uevent.exists():
                    content = uevent.read_text()
                    for sig in sigs:
                        if sig in content:
                            return f"/dev/{Path(path).name}"
            except: pass
            
        # Fallback: check all hidraw devices for VID:PID 0b05:18c6
        for path in glob.glob("/sys/class/hidraw/hidraw*"):
            try:
                uevent = Path(path) / "device/uevent"
                if uevent.exists():
                    content = uevent.read_text()
                    if "HID_ID=0003:00000B05:000018C6" in content:
                        return f"/dev/{Path(path).name}"
            except: pass
            
        return None

    def _send_packet(self, dev, data):
        if len(data) < 64: data += bytes([0] * (64 - len(data)))
        try:
            with open(dev, 'wb') as f: f.write(data)
        except PermissionError:
            raise Exception(f"Permission denied accessing {dev}. Check udev rules.")
        except Exception as e:
            raise Exception(f"Failed to write to {dev}: {str(e)}")

    def set_window_backlight(self, level):
        try:
            dev = self._find_lightbar()
            if not dev: raise Exception("Rear window lightbar not detected")
            
            if level == 0:
                self._send_packet(dev, bytes([0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff]))
            else:
                self._send_packet(dev, bytes([0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff]))
                val = [0, 85, 170, 255][level]
                time.sleep(0.1)
                self._send_packet(dev, bytes([0x5d, 0xb3, 0x00, 0x00, val, val, val, 0xeb, 0x00, 0x00, 0xff, 0xff, 0xff]))
            
            self._save_window_config({"WINDOW_BRIGHTNESS": str(level)})
            self.notifier.notify("Rear Window", f"Brightness: {level}", "success", 2000)
        except Exception as e:
            self.notifier.notify_error("Lightbar Error", str(e))

    def set_window_color(self, r, g, b):
        try:
            self.stop_window_animation()
            dev = self._find_lightbar()
            if not dev: raise Exception("Rear window lightbar not detected")
            
            self._send_packet(dev, bytes([0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff]))
            time.sleep(0.08)
            self._send_packet(dev, bytes([0x5d, 0xb3, 0x00, 0x00, r, g, b, 0xeb, 0x00, 0x00, 0xff, 0xff, 0xff]))
            
            self._save_window_config({"WINDOW_COLOR": f"{r},{g},{b}", "WINDOW_ANIMATION": None})
            self.notifier.notify("Rear Window", f"Color: RGB({r},{g},{b})", "success", 2000)
        except Exception as e:
            self.notifier.notify_error("Lightbar Error", str(e))

    def stop_window_animation(self):
        if self.window_animation_stop: self.window_animation_stop.set()
        if self.window_animation_thread: self.window_animation_thread.join(timeout=1)
        self.window_animation_stop = None
        self.window_animation_thread = None

    def start_window_animation(self, anim_type, c1=None, c2=None, speed=2):
        self.stop_window_animation()
        self.window_animation_stop = threading.Event()
        
        def run(animation_type, color1, color2, spd, stop_event):
            # Try to find device once
            dev = self._find_lightbar()
            
            # Helper to set color safely inside thread
            def set_color_safe(r, g, b):
                nonlocal dev
                try:
                    if not dev or not Path(dev).exists():
                        dev = self._find_lightbar()
                        if not dev: return
                    self._send_packet(dev, bytes([0x5d, 0xb3, 0x00, 0x00, r, g, b, 0xeb, 0x00, 0x00, 0xff, 0xff, 0xff]))
                except: pass

            # Rainbow logic
            if animation_type == "rainbow":
                hue = 0.0
                step = {1: 0.015, 2: 0.03, 3: 0.06}.get(spd, 0.03)
                while not stop_event.is_set():
                    r, g, b = [int(x * 255) for x in colorsys.hsv_to_rgb(hue % 1.0, 1.0, 1.0)]
                    set_color_safe(r, g, b)
                    hue += step
                    time.sleep(0.08)
            
            # Breathing logic
            elif animation_type == "breathing":
                col1 = color1 or (255, 255, 255)
                col2 = color2 or (0, 0, 0)
                steps = 24
                period = {1: 3.0, 2: 2.0, 3: 1.0}.get(spd, 2.0)
                while not stop_event.is_set():
                    # Fade 1->2
                    for i in range(steps):
                        if stop_event.is_set(): return
                        t = i / float(steps - 1)
                        r = int(col1[0] + (col2[0] - col1[0]) * t)
                        g = int(col1[1] + (col2[1] - col1[1]) * t)
                        b = int(col1[2] + (col2[2] - col1[2]) * t)
                        set_color_safe(r, g, b)
                        time.sleep(period / steps)
                    # Fade 2->1
                    for i in range(steps):
                        if stop_event.is_set(): return
                        t = i / float(steps - 1)
                        r = int(col2[0] + (col1[0] - col2[0]) * t)
                        g = int(col2[1] + (col1[1] - col2[1]) * t)
                        b = int(col2[2] + (col1[2] - col2[2]) * t)
                        set_color_safe(r, g, b)
                        time.sleep(period / steps)

        # Start thread
        self.window_animation_thread = threading.Thread(
            target=run, 
            args=(anim_type, c1, c2, speed, self.window_animation_stop), 
            daemon=True
        )
        self.window_animation_thread.start()
        self.notifier.notify("Rear Window", f"Animation: {anim_type.title()}", "success", 2000)

    def _write_config(self, filepath, lines):
        # Helper to write config with sudo
        tmp = f"/tmp/gz302-cfg-{os.getpid()}"
        with open(tmp, 'w') as f: f.write("\n".join(lines) + "\n")
        subprocess.run(["sudo", "-n", "mkdir", "-p", os.path.dirname(filepath)])
        subprocess.run(["sudo", "-n", "mv", tmp, filepath])

    def _save_window_config(self, updates):
        try:
            config_dir = Path("/etc/gz302")
            config_file = config_dir / "rgb-window.conf"
            existing = {}
            
            # Read existing
            if config_file.exists():
                txt = config_file.read_text()
                for line in txt.splitlines():
                    if "=" in line:
                        k, v = line.split("=", 1)
                        existing[k.strip()] = v.strip()
            
            # Update
            for k, v in updates.items():
                if v is None:
                    existing.pop(k, None)
                else:
                    existing[k] = v
            
            lines = [f"{k}={v}" for k,v in existing.items()]
            self._write_config(str(config_file), lines)
        except: pass
