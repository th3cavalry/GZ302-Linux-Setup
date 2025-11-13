# GZ302 Keyboard Backlight Physical Button Support

This feature adds support for the physical FN+F11 keyboard backlight brightness control button on the ASUS ROG Flow Z13 (GZ302).

## Overview

The keyboard backlight listener daemon (`gz302-kbd-backlight-listener`) monitors ASUS function key events and automatically cycles the keyboard backlight brightness when you press FN+F11.

### Features

- ✅ **Physical Button Support**: Press FN+F11 to cycle brightness levels
- ✅ **Auto Cycling**: 0 (Off) → 1 → 2 → 3 → 0 (repeats)
- ✅ **Systemd Integration**: Runs as background service
- ✅ **Key Detection Tool**: `gz302-kbd-detect-key` helps identify correct key codes
- ✅ **Syslog Logging**: All events logged to systemd journal
- ✅ **Customizable**: Easy to configure key codes for variants/regions

## Installation

### Automatic (via main script)

The keyboard backlight button support is automatically installed when you run the main GZ302 setup script:

```bash
sudo ./gz302-main.sh
```

Choose the keyboard backlight button support option when prompted.

### Manual Installation

1. **Copy the listener script**:
   ```bash
   sudo cp gz302-kbd-backlight-listener.py /usr/local/bin/gz302-kbd-backlight-listener
   sudo chmod +x /usr/local/bin/gz302-kbd-backlight-listener
   ```

2. **Install the systemd service**:
   ```bash
   sudo cp gz302-kbd-backlight-listener.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable gz302-kbd-backlight-listener
   sudo systemctl start gz302-kbd-backlight-listener
   ```

3. **Verify installation**:
   ```bash
   systemctl status gz302-kbd-backlight-listener
   ```

## Usage

### Basic Usage

Once installed and running, simply press **FN+F11** on your keyboard to cycle brightness levels:

```
Press FN+F11: Off → Level 1 → Level 2 → Level 3 → Off (repeats)
```

### Checking Status

View the service status:

```bash
systemctl status gz302-kbd-backlight-listener
```

View real-time logs:

```bash
journalctl -u gz302-kbd-backlight-listener -f
```

### Enable/Disable

Enable the service:

```bash
sudo systemctl enable gz302-kbd-backlight-listener
sudo systemctl start gz302-kbd-backlight-listener
```

Disable the service:

```bash
sudo systemctl stop gz302-kbd-backlight-listener
sudo systemctl disable gz302-kbd-backlight-listener
```

## Detecting Key Codes

If FN+F11 doesn't work on your system, you can detect the correct key code:

```bash
sudo python3 gz302-kbd-detect-key.py
```

Then press FN+F11 and note the "Code" value. Update the `BRIGHTNESS_KEYS` dictionary in `/usr/local/bin/gz302-kbd-backlight-listener` with your system's key code.

**Example**: If detection shows code 87, add `87: "toggle"` to the `BRIGHTNESS_KEYS` dictionary.

## Troubleshooting

### FN+F11 doesn't work

1. **Check service status**:
   ```bash
   systemctl status gz302-kbd-backlight-listener
   ```

2. **Detect your key code**:
   ```bash
   sudo python3 gz302-kbd-detect-key.py
   # Press FN+F11 and note the code
   ```

3. **Update key code** in `/usr/local/bin/gz302-kbd-backlight-listener`:
   ```python
   BRIGHTNESS_KEYS = {
       YOUR_CODE_HERE: "toggle",  # Add your detected code
       # ... other codes
   }
   ```

4. **Restart the service**:
   ```bash
   sudo systemctl restart gz302-kbd-backlight-listener
   ```

### Permission denied errors

The service runs as root to access input events. If you see permission errors:

1. Verify the service is running:
   ```bash
   sudo systemctl start gz302-kbd-backlight-listener
   ```

2. Check sysfs permissions:
   ```bash
   ls -la /sys/class/leds/asus::kbd_backlight/brightness
   ```

3. Verify sudo configuration:
   ```bash
   sudo cat /etc/sudoers.d/gz302-pwrcfg
   ```

### No events detected

1. Verify the ASUS input device exists:
   ```bash
   ls -la /dev/input/event10
   ```

2. Check available ASUS devices:
   ```bash
   ls -la /dev/input/by-path/ | grep asus
   ```

3. Modify the event device path if needed in `/usr/local/bin/gz302-kbd-backlight-listener`

## System Requirements

- **Kernel**: 6.14+ (recommended 6.17+ for Strix Halo support)
- **Hardware**: ASUS ROG Flow Z13 (GZ302) with MediaTek MT7925 Wi-Fi
- **Dependencies**: Python 3.6+, systemd

## Technical Details

### How It Works

1. **Event Monitoring**: The daemon listens to `/dev/input/event10` (ASUS WMI input device)
2. **Key Detection**: When FN+F11 (or mapped key code) is pressed, an event is captured
3. **Brightness Control**: The brightness level is cycled via `/sys/class/leds/asus::kbd_backlight/brightness`
4. **Logging**: All actions are logged to systemd journal

### Input Event Structure

The daemon reads raw input events from the ASUS WMI device:

```
Event structure: [sec(4), usec(4), type(2), code(2), value(4)] = 24 bytes
Type 0 = EV_SYN (synchronization, ignored)
Type 1 = EV_KEY (keyboard/button press)
Value 0 = Key released
Value 1 = Key pressed
Value > 1 = Key repeat
```

### Supported Key Codes

The daemon supports multiple key codes for brightness control:

| Code | Name | Action |
|------|------|--------|
| 65   | F7   | Toggle/Cycle |
| 66   | F8   | Toggle/Cycle |
| 87   | F11  | Toggle/Cycle |
| 244  | BRIGHTNESS_DOWN | Cycle backward |
| 245  | BRIGHTNESS_UP   | Cycle forward |

## Files

| File | Purpose |
|------|---------|
| `gz302-kbd-backlight-listener.py` | Main daemon script |
| `gz302-kbd-detect-key.py` | Key code detection utility |
| `gz302-kbd-backlight-listener.service` | Systemd service file |
| `KEYBOARD_BACKLIGHT_BUTTON.md` | This documentation |

## Support

For issues or feature requests, visit: https://github.com/th3cavalry/GZ302-Linux-Setup/issues

## License

Same as main GZ302-Linux-Setup project (see LICENSE file)
