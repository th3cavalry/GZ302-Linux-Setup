# Temporary Scripts (Experimental)

This folder contains **experimental scripts** that are being tested and refined before potential integration into the main setup script or optional modules.

## ⚠️ WARNING: EXPERIMENTAL SCRIPTS

**Use at your own risk!** These scripts are:
- Not fully tested on all hardware variants
- May have bugs or unexpected behavior
- Subject to frequent changes
- Not officially supported

## Available Scripts

### gz302-rgb-backlight.sh (EXPERIMENTAL)

**Purpose:** Control keyboard backlight and implement persistence across suspend/resume.

**Features:**
- asusctl-based RGB control (full LED mode support)
- sysfs-based brightness control (basic)
- Persistence setup via systemd-backlight integration
- Helper scripts for common operations

**Limitations:**
- Rear window LED control is **NOT supported** due to hardware limitations
- May not work on all GZ302 variants
- Requires asusctl for full RGB features

**Usage:**
```bash
cd Temporary
sudo ./gz302-rgb-backlight.sh
```

**Installation Options:**
1. **asusctl method** (recommended)
   - Requires: `asusctl` package installed
   - Provides: Full RGB control (modes, brightness, colors)
   - Creates: `kbd-brightness`, `kbd-led-mode` commands

2. **sysfs method** (fallback)
   - Requires: Kernel support for `/sys/class/leds/`
   - Provides: Basic brightness control only
   - Creates: `kbd-brightness-sysfs` command

3. **Persistence setup**
   - Works with either method
   - Saves/restores brightness across suspend/resume
   - Uses systemd-backlight integration

**Research Notes:**

Based on community research and testing:
- **Keyboard backlight**: Controllable via asusctl or sysfs (limited)
- **Rear window LEDs**: No Linux support (proprietary firmware)
- **Persistence**: Requires systemd service for suspend/resume cycles
- **RGB modes**: Only available through asusctl (kernel-level for linux-g14)

**References:**
- https://asus-linux.org (asusctl documentation)
- https://github.com/seerge/g-helper (Windows G-Helper project)
- Community reports: Rear window and keyboard backlight are linked in firmware

## Feedback

If you test these scripts, please report your experience at:
https://github.com/th3cavalry/GZ302-Linux-Setup/issues

Include:
- Hardware model (GZ302EA-XS99/XS64/XS32)
- Linux distribution and kernel version
- What works and what doesn't
- Any error messages

## Integration Path

Once an experimental script is:
1. Tested on multiple hardware variants
2. Confirmed stable and reliable
3. Well-documented with known limitations

It may be:
- Integrated into the main setup script
- Moved to the Optional/ folder as a standalone installer
- Added as a downloadable module

Until then, consider these scripts as "proof of concept" implementations.
