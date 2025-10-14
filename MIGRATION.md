# Migration Guide: gz302-power-manager.sh → pwrcfg/rrcfg

If you were using the old `gz302-power-manager.sh` script, this guide will help you migrate to the new `pwrcfg` and `rrcfg` commands.

## What Changed

The power management system has been redesigned based on user feedback:

**Old System:**
- Single script: `gz302-power-manager.sh`
- 3 power profiles
- Basic refresh rate control

**New System:**
- Two simple commands: `pwrcfg` and `rrcfg`
- 6 power profiles with TDP control
- Flexible refresh rate support (any rate)
- Interactive configuration
- Better AC/battery customization

## Command Migration

### Power Profiles

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `sudo ./gz302-power-manager.sh performance` | `sudo pwrcfg turbo` | High performance |
| `sudo ./gz302-power-manager.sh balanced` | `sudo pwrcfg balanced` | Same |
| `sudo ./gz302-power-manager.sh powersave` | `sudo pwrcfg powersave` | Same |
| `sudo ./gz302-power-manager.sh auto` | `sudo pwrcfg auto on` | Auto-switching |
| `sudo ./gz302-power-manager.sh status` | `pwrcfg status` | Check status |

### New Profiles Available

The new system adds more granular control:

- `sudo pwrcfg max` - Maximum performance (120W TDP)
- `sudo pwrcfg turbo` - Gaming mode (100W TDP)
- `sudo pwrcfg performance` - Work mode (80W TDP)
- `sudo pwrcfg balanced` - General use (60W TDP)
- `sudo pwrcfg powersave` - Battery saving (35W TDP)
- `sudo pwrcfg extreme` - Extreme battery saving (20W TDP)

### Refresh Rate Control

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `sudo ./gz302-power-manager.sh refresh-high` | `rrcfg 120` | High refresh |
| `sudo ./gz302-power-manager.sh refresh-low` | `rrcfg 60` | Low refresh |
| N/A | `rrcfg 90` | New: Balanced |
| N/A | `rrcfg 40` | New: Extreme saving |
| N/A | `rrcfg auto` | New: Auto-match profile |

### Automatic Switching

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `sudo ./gz302-power-manager.sh install` | `sudo pwrcfg config` then `sudo pwrcfg auto on` | Interactive setup |
| `sudo ./gz302-power-manager.sh uninstall` | `sudo pwrcfg auto off` | Disable auto-switching |

## New Features

### 1. Interactive Configuration

```bash
sudo pwrcfg config
```

This lets you choose:
- Which profile to use on AC power
- Which profile to use on battery
- Whether to link refresh rate to power profiles

### 2. More Power Profiles

The new system offers 6 power levels instead of 3:

```bash
pwrcfg list   # See all available profiles
```

### 3. Flexible Refresh Rates

Set any refresh rate your display supports:

```bash
rrcfg 120     # 120Hz
rrcfg 90      # 90Hz
rrcfg 60      # 60Hz
rrcfg 40      # 40Hz (extreme battery saving)
rrcfg list    # See what your display supports
```

### 4. TDP Control

With `ryzenadj` installed, you get full TDP control:

```bash
# Install ryzenadj (Arch example)
yay -S ryzenadj

# Profiles automatically control TDP
sudo pwrcfg turbo    # Sets 100W TDP
sudo pwrcfg extreme  # Sets 20W TDP
```

## Migration Steps

1. **Remove old automatic switching (if installed):**
   ```bash
   sudo rm /etc/udev/rules.d/90-gz302-power.rules 2>/dev/null
   sudo udevadm control --reload-rules
   ```

2. **Install new commands system-wide:**
   ```bash
   sudo cp pwrcfg /usr/local/bin/
   sudo cp rrcfg /usr/local/bin/
   sudo chmod +x /usr/local/bin/pwrcfg /usr/local/bin/rrcfg
   ```

3. **Configure your preferences:**
   ```bash
   sudo pwrcfg config
   ```

4. **Enable automatic switching:**
   ```bash
   sudo pwrcfg auto on
   ```

5. **Test your setup:**
   ```bash
   pwrcfg status
   rrcfg status
   ```

## Quick Examples

### Gaming Setup
```bash
sudo pwrcfg turbo
rrcfg 120
```

### Battery Life
```bash
sudo pwrcfg powersave
rrcfg 60
```

### Automatic AC/Battery
```bash
# Configure once
sudo pwrcfg config
# Choose: AC=turbo, Battery=powersave, Link refresh=yes

# Enable
sudo pwrcfg auto on

# Now it switches automatically when you plug/unplug
```

## Troubleshooting

### Old udev rules still active?

```bash
# Remove old rules
sudo rm /etc/udev/rules.d/90-gz302-power.rules 2>/dev/null
sudo rm /usr/local/bin/gz302-power-manager.sh 2>/dev/null
sudo udevadm control --reload-rules
```

### Commands not found?

```bash
# Make sure they're in your PATH
sudo cp pwrcfg rrcfg /usr/local/bin/
sudo chmod +x /usr/local/bin/{pwrcfg,rrcfg}
```

### Want old behavior?

The closest equivalent to the old automatic behavior:

```bash
sudo pwrcfg config
# Select: AC=turbo, Battery=powersave, Link=yes
sudo pwrcfg auto on
```

This will:
- Use turbo (100W) on AC power with 120Hz refresh
- Use powersave (35W) on battery with 60Hz refresh

## Benefits of New System

1. **Simpler commands**: `pwrcfg turbo` vs `sudo ./gz302-power-manager.sh performance`
2. **More control**: 6 profiles instead of 3
3. **Better TDP management**: Real TDP control with ryzenadj
4. **Flexible refresh rates**: Set any rate, not just high/low
5. **Better customization**: Choose exactly what you want for AC and battery
6. **System-wide**: Commands available from anywhere once installed

## Need Help?

- Check status: `pwrcfg status` and `rrcfg status`
- List options: `pwrcfg list` and `rrcfg list`
- See help: `pwrcfg --help` and `rrcfg --help`
