# GZ302 Keyboard RGB Color Control

Comprehensive RGB color control for the ASUS ROG Flow Z13 (GZ302) keyboard backlight.

## Overview

The `kbrgb` command provides full RGB color control for your keyboard backlight, including:

- ✅ **10-Color Palette**: Quick access to common colors
- ✅ **Custom Hex Colors**: Fine-tune any color with 6-digit hex codes
- ✅ **Brightness Control**: 4 levels (0=Off, 1-3)
- ✅ **Visual Effects**: Static, breathe, pulse, rainbow, strobe
- ✅ **Tray Icon Integration**: GUI control via system tray
- ✅ **Dual Method Support**: asusctl (RGB) + sysfs (brightness fallback)

## Installation

The `kbrgb` command is automatically installed when you run the main GZ302 setup script:

```bash
sudo ./gz302-main.sh
```

## Command-Line Usage

### Basic Color Control

Set keyboard to a color from the built-in palette:

```bash
kbrgb color red         # Red
kbrgb color green       # Green
kbrgb color blue        # Blue
kbrgb color cyan        # Cyan
kbrgb color magenta     # Magenta
kbrgb color yellow      # Yellow
kbrgb color white       # White
kbrgb color orange      # Orange
kbrgb color purple      # Purple
kbrgb color pink        # Pink
```

### Custom Hex Colors

Set any color using a 6-digit hex code (RRGGBB):

```bash
kbrgb hex ff00ff        # Magenta
kbrgb hex 00ff80        # Spring green
kbrgb hex 8000ff        # Electric purple
kbrgb hex ff6600        # Orange-red
```

### Brightness Control

Set keyboard backlight brightness (works even without asusctl):

```bash
kbrgb brightness 0      # Off
kbrgb brightness 1      # Low
kbrgb brightness 2      # Medium
kbrgb brightness 3      # High (max)
```

### Visual Effects

Apply animated effects to the keyboard (requires asusctl):

```bash
kbrgb effect static     # Solid color (no animation)
kbrgb effect breathe    # Breathing animation
kbrgb effect pulse      # Pulsing animation
kbrgb effect rainbow    # Rainbow cycle
kbrgb effect strobe     # Strobe effect
```

### Information Commands

```bash
kbrgb status            # Show current RGB status
kbrgb list              # List all available colors
kbrgb effects           # List all available effects
kbrgb help              # Show usage help
```

## Tray Icon Integration

The GZ302 system tray icon includes a full keyboard RGB control menu:

### Menu Structure

```
Keyboard Backlight
├── Brightness
│   ├── Off
│   ├── Level 1
│   ├── Level 2
│   └── Level 3
├── ───────────
├── RGB Colors
│   ├── Red
│   ├── Green
│   ├── Blue
│   ├── Cyan
│   ├── Magenta
│   ├── Yellow
│   ├── White
│   ├── Orange
│   ├── Purple
│   ├── Pink
│   ├── ───────────
│   └── Custom Hex Color...
├── ───────────
└── Effects
    ├── Static
    ├── Breathe
    ├── Pulse
    ├── Rainbow
    └── Strobe
```

### Using the Tray Icon

1. **Launch the tray icon**: Run `tray-icon/src/gz302_tray.py`
2. **Right-click the tray icon**
3. **Navigate to**: Keyboard Backlight → RGB Colors or Effects
4. **Click a color** to apply it instantly
5. **Custom colors**: Click "Custom Hex Color..." and enter a 6-digit hex code

## Technical Details

### RGB Control Methods

The `kbrgb` command uses two methods for keyboard control:

#### 1. asusctl (Preferred - Full RGB)

- **Requirement**: `asusctl` package installed
- **Capabilities**: Full RGB color control, effects, brightness
- **Best for**: Complete RGB customization
- **Installation**: Automatically installed via main script on supported distros

#### 2. sysfs (Fallback - Brightness Only)

- **Requirement**: Standard Linux kernel support
- **Capabilities**: Brightness control only (0-3)
- **Best for**: Systems without asusctl
- **Path**: `/sys/class/leds/asus::kbd_backlight/brightness`

### Color Format

- **Hex format**: 6-digit hexadecimal (RRGGBB)
  - Example: `ff00ff` = Red(255) Green(0) Blue(255) = Magenta
- **RGB values**: 0-255 for each channel (R, G, B)
- **Case insensitive**: `FF00FF` and `ff00ff` are equivalent

### Built-in Color Palette

| Color Name | Hex Code | RGB Values |
|------------|----------|------------|
| Red        | `ff0000` | 255, 0, 0  |
| Green      | `00ff00` | 0, 255, 0  |
| Blue       | `0000ff` | 0, 0, 255  |
| Cyan       | `00ffff` | 0, 255, 255 |
| Magenta    | `ff00ff` | 255, 0, 255 |
| Yellow     | `ffff00` | 255, 255, 0 |
| White      | `ffffff` | 255, 255, 255 |
| Orange     | `ff8000` | 255, 128, 0 |
| Purple     | `8000ff` | 128, 0, 255 |
| Pink       | `ff0080` | 255, 0, 128 |

## Rear Window RGB LEDs

### Current Status

**Rear window RGB LED control is NOT supported on Linux for the GZ302.**

### Research Findings

Based on extensive research into ASUS ROG Flow Z13 (2025) GZ302EA models:

1. **Limited Linux Support**
   - Rear window LEDs have minimal to no control via `asusctl` or other Linux tools
   - Only ON/OFF toggle may be available on some models
   - Full color control requires Windows + Armoury Crate

2. **Hardware Limitations**
   - The rear window LEDs use a separate controller from the keyboard backlight
   - Linux kernel drivers for this specific hardware are incomplete
   - Community-reported issues: [GitLab #681](https://gitlab.com/asus-linux/asusctl/-/issues/681)

3. **Potential Future Support**
   - ASUS Linux developers are working on improved RGB support
   - Phoronix article: [ASUS Z13 RGB improvements](https://www.phoronix.com/news/ASUS-Z13-ROG-Ally-RGB)
   - May improve with future kernel/driver updates

4. **Windows Comparison**
   - Windows tools (Armoury Crate, G-Helper) offer limited rear window control
   - G-Helper provides ON/OFF toggle only, not color customization
   - Related issues: [G-Helper #1930](https://github.com/seerge/g-helper/issues/1930), [#2605](https://github.com/seerge/g-helper/issues/2605)

### Workarounds

None available at this time. The rear window LEDs will:
- May stay synchronized with keyboard backlight color (model-dependent)
- May respond to BIOS/UEFI power settings only
- Require Windows for any control beyond ON/OFF

### Contributing

If you have hardware expertise or can contribute device logs to help ASUS Linux developers:
- [asusctl GitLab](https://gitlab.com/asus-linux/asusctl)
- [ASUS Linux Community](https://asus-linux.org)

## Troubleshooting

### RGB colors don't work

**Error**: "asusctl is required for RGB color control"

**Solution**: Install asusctl:

```bash
# Arch-based
sudo pacman -S asusctl

# Debian/Ubuntu
sudo add-apt-repository ppa:asus-linux/ppa
sudo apt update
sudo apt install asusctl

# Fedora
sudo dnf install asusctl

# Or re-run the main setup script
sudo ./gz302-main.sh
```

### Colors not changing

**Possible causes**:
1. asusctl service not running
2. Incompatible hardware variant
3. BIOS setting override

**Solutions**:

```bash
# Check asusctl service
sudo systemctl status asusd

# Restart asusctl service
sudo systemctl restart asusd

# Check hardware support
asusctl led-mode

# Try setting color directly
sudo asusctl led-mode static -c ff0000
```

### Tray icon color options grayed out

**Error**: "kbrgb command not found"

**Solution**: Re-run the main setup script to install kbrgb:

```bash
sudo ./gz302-main.sh
```

### Brightness works but colors don't

This is expected behavior when asusctl is not installed. The sysfs fallback only supports brightness control (0-3), not RGB colors or effects.

**Solution**: Install asusctl for full RGB support (see above).

## System Requirements

- **Kernel**: 6.14+ (minimum), 6.17+ (recommended for full hardware support)
- **Hardware**: ASUS ROG Flow Z13 (GZ302EA-XS99/XS64/XS32)
- **Dependencies**:
  - Bash 4.0+ (for kbrgb command)
  - asusctl (for RGB colors and effects) - optional but recommended
  - Python 3.6+ and PyQt6 (for tray icon)

## Examples

### Quick Start

```bash
# Set keyboard to cyan
kbrgb color cyan

# Set custom teal color
kbrgb hex 008080

# Apply breathing effect
kbrgb effect breathe

# Check current status
kbrgb status
```

### Advanced Usage

```bash
# Set keyboard to a custom "gaming red"
kbrgb hex cc0000

# Set breathing effect for a dynamic look
kbrgb effect breathe

# Reduce brightness to level 2
kbrgb brightness 2

# View all available colors
kbrgb list

# View all effects
kbrgb effects
```

### Automation Examples

Create a script to change colors based on time of day:

```bash
#!/bin/bash
# Auto-change keyboard color based on time

hour=$(date +%H)

if [ $hour -ge 6 ] && [ $hour -lt 12 ]; then
    # Morning: Bright white
    kbrgb color white
elif [ $hour -ge 12 ] && [ $hour -lt 18 ]; then
    # Afternoon: Energetic cyan
    kbrgb color cyan
elif [ $hour -ge 18 ] && [ $hour -lt 22 ]; then
    # Evening: Warm orange
    kbrgb color orange
else
    # Night: Dim red (easier on eyes)
    kbrgb hex 330000
    kbrgb brightness 1
fi
```

## Files

| File | Purpose |
|------|---------|
| `/usr/local/bin/kbrgb` | Main RGB control command |
| `kbrgb.template.sh` | Source template for kbrgb command |
| `tray-icon/src/gz302_tray.py` | System tray icon with RGB menu |
| `KEYBOARD_RGB.md` | This documentation |

## Related Documentation

- [KEYBOARD_BACKLIGHT_BUTTON.md](KEYBOARD_BACKLIGHT_BUTTON.md) - Physical FN+F11 button support
- [README.md](README.md) - Main GZ302 setup documentation
- [tray-icon/README.md](tray-icon/README.md) - Tray icon documentation

## Support

For issues or feature requests:
- GitHub Issues: https://github.com/th3cavalry/GZ302-Linux-Setup/issues
- ASUS Linux Community: https://asus-linux.org

## License

Same as main GZ302-Linux-Setup project (see LICENSE file)
