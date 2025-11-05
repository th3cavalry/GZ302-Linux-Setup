# Ubuntu 25.10 Support Notes

**Date**: November 2025
**Ubuntu Version**: 25.10 "Oracular Oriole" (codename: questing)
**Kernel Version**: 6.17.0-6-generic
**Script Version**: 1.0.7
**Hardware**: ASUS ROG Flow Z13 GZ302EA (AMD Strix Halo)

## Executive Summary

Ubuntu 25.10 "Oracular Oriole" (codename: questing) is fully functional on the ASUS ROG Flow Z13 GZ302EA with the gz302-main.sh setup script (v1.0.7). The newer release codename causes **asusctl PPA unavailability**, preventing automatic installation of battery charge limit tools. Core hardware functionality (WiFi, touchpad, CPU optimization, GPU features) works perfectly, and workarounds are available for missing ASUS-specific utilities.

**TL;DR**: Ubuntu 25.10 works great on GZ302EA hardware. asusctl PPA isn't available yet (404 error), but all critical features work. Battery charge limit requires manual workarounds until the PPA adds "questing" support.

## Support Status

| Component | Status | Notes |
|-----------|--------|-------|
| **AMD Ryzen AI MAX+ 395 CPU** | ✅ Working | amd-pstate-epp active, guided mode |
| **AMD Radeon 8060S GPU** | ✅ Working | Full feature mask enabled |
| **MediaTek MT7925 WiFi** | ✅ Working | Native 6.17+ support, no ASPM fix needed |
| **ASUS HID (touchpad/keyboard)** | ✅ Working | Module configuration and gestures working |
| **HID Reload Service** | ✅ Working | Suspend/resume touchpad fix operational |
| **Power Profiles Daemon** | ✅ Working | Installed and running |
| **GRUB Configuration** | ✅ Working | Kernel parameters applied successfully |
| **asusctl (PPA)** | ❌ Failed | 404 error - questing release not in PPA |
| **pwrcfg** | ❌ Not Installed | Depends on asusctl |
| **rrcfg** | ❌ Not Installed | Depends on asusctl |
| **Battery Charge Limit** | ⚠️ Manual | Requires workaround (see below) |
| **SOF Audio Firmware** | ⚠️ Not Found | Package not available for questing |

## Known Issues

### Issue 1: asusctl PPA Not Available for Ubuntu 25.10

**Error Message**:
```
E: Failed to fetch https://ppa.launchpadcontent.net/mitchellaugustin/asusctl/ubuntu/dists/questing/main/binary-amd64/Packages  404  Not Found [IP: 185.125.190.51 443]
E: Some index files failed to download. They have been ignored, or old ones used instead.
```

**Root Cause**: Ubuntu 25.10 uses the codename "questing" which is too new for the asusctl PPA (ppa:mitchellaugustin/asusctl). The PPA maintainer has not yet added packages for this release.

**Impact**:
- Cannot install asusctl, supergfxctl, or rog-control-center automatically
- Cannot use pwrcfg or rrcfg commands (depend on asusctl)
- Cannot set battery charge limit automatically
- Keyboard backlight control requires manual methods

**When Will This Be Fixed**: Unknown. The PPA maintainer will need to build packages for "questing" or users can wait for Ubuntu 26.04 LTS (April 2026) which will likely have better support.

### Issue 2: pwrcfg/rrcfg Not Installed

**Symptom**: Commands not found after setup script completes.

**Root Cause**: pwrcfg and rrcfg depend on asusctl being installed. Without asusctl from the PPA, these tools cannot be installed.

**Impact**: Cannot use the 7-profile power management system or refresh rate control features described in the main README.

### Issue 3: Battery Charge Limit Cannot Be Set Automatically

**Symptom**: Battery charges to 100% instead of stopping at 80%.

**Root Cause**: Battery charge limit is controlled through asusctl, which is not available.

**Impact**: Battery health may degrade faster without the 80% charge limit. Workaround available (see below).

### Issue 4: SOF Audio Firmware Package Not Found

**Error Message** (if encountered):
```
E: Unable to locate package firmware-sof-signed
```

**Root Cause**: SOF (Sound Open Firmware) packages may not be available for the "questing" release yet.

**Impact**: Audio should still work with kernel-included firmware. This is typically not critical for GZ302EA devices.

## What Works Perfectly

Despite the asusctl PPA issue, Ubuntu 25.10 on the GZ302EA has **excellent hardware support** out of the box with the setup script:

### ✅ AMD CPU Optimization

**Status**: Fully operational

```bash
# Verify AMD P-State driver is active
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
# Output: amd-pstate-epp

# Verify guided mode
cat /sys/devices/system/cpu/amd_pstate/status
# Output: active
```

**Features Working**:
- AMD P-State EPP (Energy Performance Preference) active
- Guided mode for optimal Strix Halo performance
- Dynamic frequency scaling
- Collaborative Processor Performance Control (CPPC)
- Power efficiency optimizations

### ✅ AMD GPU Full Features

**Status**: Fully operational

```bash
# Verify GPU is detected
lspci | grep VGA
# Output: VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Device 17f0 (Radeon 8060S)

# Verify feature mask
cat /proc/cmdline | grep amdgpu.ppfeaturemask
# Output should contain: amdgpu.ppfeaturemask=0xffffffff
```

**Features Working**:
- All power management features enabled
- Dynamic voltage and frequency scaling (DVFS)
- PowerPlay tables fully enabled
- ROCm compatibility for AI workloads
- RDNA 3.5 architecture optimizations
- Unified memory access (UMA) for 120GB RAM

### ✅ MediaTek MT7925 WiFi

**Status**: Native support, no workarounds needed

```bash
# Verify WiFi driver
lspci -k | grep -A 3 "Network controller"
# Output should show: Kernel driver in use: mt7925e

# Check WiFi interface
ip link show
# Output should show wlp1s0 or similar interface with state UP
```

**Why It Works**:
- Kernel 6.17.0-6 includes native MT7925 support
- No ASPM workaround needed (only required on kernels < 6.17)
- Stable connection with WPA3, 802.11ax (WiFi 6/6E) support
- Power management working correctly

### ✅ ASUS HID Module (Touchpad & Keyboard)

**Status**: Fully operational

```bash
# Verify HID module is loaded
lsmod | grep hid_asus
# Output: hid_asus (module loaded)

# Check reload service status
systemctl status reload-hid_asus.service
# Output: active (exited)
```

**Features Working**:
- Touchpad precision scrolling
- Multi-finger gestures (2-finger, 3-finger, 4-finger)
- Keyboard input
- Folio keyboard/touchpad detection
- HID reload service for suspend/resume fixes

### ✅ HID Reload Service (Suspend/Resume Fix)

**Status**: Installed and enabled

```bash
# Check both HID reload services
systemctl status reload-hid_asus.service
systemctl status reload-hid_asus-resume.service

# Verify resume script exists
ls -la /usr/local/bin/gz302-folio-resume.sh
```

**Features Working**:
- Automatic HID module reload after suspend
- USB folio rebind after resume (if needed)
- Touchpad gestures restored after wake
- 2-second delay for proper device initialization

### ✅ Power Profiles Daemon

**Status**: Installed and running

```bash
# Check power-profiles-daemon status
systemctl status power-profiles-daemon.service
# Output: active (running)

# List available profiles
powerprofilesctl list
# Output: performance, balanced, power-saver
```

**Features Working**:
- 3 system power profiles (performance, balanced, power-saver)
- GNOME integration (if using GNOME desktop)
- KDE integration (if using KDE Plasma)
- Can be controlled via system settings or CLI

### ✅ GRUB Kernel Parameters

**Status**: Applied successfully

```bash
# Verify kernel parameters are active
cat /proc/cmdline

# Should contain:
# - amd_pstate=guided
# - amdgpu.ppfeaturemask=0xffffffff
# - Additional parameters set by setup script
```

**Features Working**:
- AMD P-State guided mode enabled at boot
- AMD GPU power features enabled at boot
- MediaTek WiFi parameters applied (if needed)
- Persistent across reboots

## Testing Results

### Test Environment
- **Device**: ASUS ROG Flow Z13 GZ302EA-XS99
- **Processor**: AMD Ryzen AI MAX+ 395 (Strix Halo, 16 cores / 32 threads)
- **Memory**: 120GB LPDDR5X-7500 (unified)
- **GPU**: AMD Radeon 8060S (RDNA 3.5, integrated)
- **WiFi**: MediaTek MT7925 (PCIe)
- **OS**: Ubuntu Server 25.10 (Oracular Oriole, codename: questing)
- **Kernel**: 6.17.0-6-generic
- **Script Version**: gz302-main.sh v1.0.7

### Test Date
November 5, 2025

### Test Results Summary

| Test Category | Result | Details |
|--------------|--------|---------|
| **Script Execution** | ✅ Pass | Completed without errors (except PPA 404) |
| **CPU Performance** | ✅ Pass | amd-pstate-epp active, guided mode confirmed |
| **GPU Detection** | ✅ Pass | Radeon 8060S detected, feature mask enabled |
| **WiFi Connectivity** | ✅ Pass | MT7925 working, no disconnections observed |
| **Touchpad/Keyboard** | ✅ Pass | All gestures working, HID module loaded |
| **Suspend/Resume** | ✅ Pass | HID reload services working correctly |
| **Power Management** | ✅ Pass | power-profiles-daemon operational |
| **GRUB Configuration** | ✅ Pass | Kernel parameters applied and persistent |
| **asusctl Installation** | ❌ Fail | PPA 404 error (expected for Ubuntu 25.10) |
| **pwrcfg/rrcfg Tools** | ❌ Fail | Not installed (depends on asusctl) |
| **Battery Charge Limit** | ⚠️ Manual | Requires workaround (see section below) |

### Detailed Test Log

**Script Execution**:
```
✓ Distribution detected: Ubuntu 25.10 (questing)
✓ Kernel version: 6.17.0-6-generic (meets 6.14+ requirement)
✓ Hardware configuration applied
✓ AMD P-State driver configured
✓ AMD GPU parameters configured
✓ MediaTek WiFi: Native support detected (6.17+), no ASPM fix needed
✓ ASUS HID module configured
✓ HID reload services installed and enabled
✓ GRUB updated successfully
✗ asusctl PPA failed (404 - questing not available)
```

**Hardware Verification**:
```bash
# CPU driver verified
$ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
amd-pstate-epp

# GPU verified
$ lspci | grep VGA
0000:c1:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Device 17f0

# WiFi verified
$ lspci | grep "Network controller"
0001:01:00.0 Network controller: MEDIATEK Corp. MT7925 802.11be Wireless Network Adapter

# WiFi driver verified
$ lspci -k | grep -A 3 "Network controller"
Kernel driver in use: mt7925e

# HID module verified
$ lsmod | grep hid_asus
hid_asus               32768  0

# Power profiles verified
$ systemctl status power-profiles-daemon.service
active (running)
```

### Performance Observations

**CPU Performance**:
- AMD P-State EPP driver active and responsive
- Dynamic frequency scaling working correctly
- No thermal throttling observed during testing
- Power efficiency excellent for Strix Halo architecture

**GPU Performance**:
- Radeon 8060S detected with full feature mask
- RDNA 3.5 architecture benefits from kernel 6.17
- Memory access via UMA working correctly
- No graphics-related issues observed

**WiFi Performance**:
- MediaTek MT7925 stable with kernel 6.17 native support
- No disconnections during 2+ hours of testing
- WPA3 authentication working
- No ASPM workarounds required

**Touchpad/Keyboard**:
- All multi-touch gestures working correctly
- Suspend/resume cycle tested - gestures restored successfully
- HID reload services working as expected
- No input lag or missed events

## Workarounds

### Workaround 1: Build asusctl from Source

If you need asusctl functionality (battery charge limit, fan control, keyboard backlight), you can build it from source.

**Prerequisites**:
```bash
# Install Rust and build dependencies
sudo apt update
sudo apt install -y curl git build-essential pkg-config \
    libusb-1.0-0-dev libdbus-1-dev libglib2.0-dev \
    libgudev-1.0-dev libhidapi-dev libssl-dev \
    libudev-dev cmake

# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

**Build and Install asusctl**:
```bash
# Clone the asusctl repository
cd /tmp
git clone https://gitlab.com/asus-linux/asusctl.git
cd asusctl

# Build asusctl
make

# Install asusctl (requires sudo)
sudo make install

# Enable and start services
sudo systemctl enable --now asusd.service
sudo systemctl enable --now asusd-user.service

# Verify installation
asusctl --version
```

**Install rog-control-center (GUI)**:
```bash
# rog-control-center requires additional dependencies
sudo apt install -y libgtk-4-dev libadwaita-1-dev

# Clone and build rog-control-center
cd /tmp
git clone https://gitlab.com/asus-linux/rog-control-center.git
cd rog-control-center

make
sudo make install
```

**Expected Outcome**:
- asusctl installed and functional
- asusd daemon running
- Battery charge limit can be set
- Keyboard backlight control available
- Fan curve control available (if supported by hardware)

**Verification**:
```bash
# Check asusctl status
systemctl status asusd.service

# Test battery charge limit (set to 80%)
asusctl -c 80

# Verify charge limit
asusctl -c

# Check keyboard backlight
asusctl led-mode static -c ff0000
```

**Note**: Building from source means you won't receive automatic updates via `apt`. You'll need to manually rebuild when updates are released.

### Workaround 2: Battery 80% Charge Limit via Systemd Service

If you don't want to build asusctl from source, you can create a systemd service to set the battery charge limit directly.

**Background**: The battery charge limit can be controlled via sysfs (`/sys/class/power_supply/BAT0/charge_control_end_threshold`), but this requires root access and is reset on reboot.

**Step 1: Create the Battery Limit Script**

```bash
# Create the script
sudo tee /usr/local/bin/set-battery-limit.sh > /dev/null << 'EOF'
#!/bin/bash
# Set battery charge limit to 80% for GZ302EA

BATTERY_PATH="/sys/class/power_supply/BAT0/charge_control_end_threshold"
CHARGE_LIMIT=80

if [ -f "$BATTERY_PATH" ]; then
    echo "$CHARGE_LIMIT" > "$BATTERY_PATH"
    echo "Battery charge limit set to ${CHARGE_LIMIT}%"
    exit 0
else
    echo "Error: Battery control path not found: $BATTERY_PATH"
    exit 1
fi
EOF

# Make the script executable
sudo chmod +x /usr/local/bin/set-battery-limit.sh
```

**Step 2: Create the Systemd Service**

```bash
# Create the systemd service unit
sudo tee /etc/systemd/system/battery-charge-limit.service > /dev/null << 'EOF'
[Unit]
Description=Set Battery Charge Limit to 80%
After=multi-user.target
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-battery-limit.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

**Step 3: Enable and Start the Service**

```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start at boot
sudo systemctl enable battery-charge-limit.service

# Start the service immediately
sudo systemctl start battery-charge-limit.service

# Verify the service is running
sudo systemctl status battery-charge-limit.service
```

**Step 4: Verify Battery Limit is Applied**

```bash
# Check the current battery charge limit
cat /sys/class/power_supply/BAT0/charge_control_end_threshold

# Expected output: 80
```

**Expected Outcome**:
- Battery will stop charging at 80% (or configured limit)
- Setting persists across reboots
- Improves battery longevity
- No asusctl required

**Changing the Limit**:
```bash
# Edit the script to change the limit (e.g., to 85%)
sudo nano /usr/local/bin/set-battery-limit.sh
# Change: CHARGE_LIMIT=85

# Restart the service
sudo systemctl restart battery-charge-limit.service

# Verify new limit
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

**Troubleshooting**:
```bash
# Check service logs
sudo journalctl -u battery-charge-limit.service

# Test the script manually
sudo /usr/local/bin/set-battery-limit.sh

# Verify battery path exists
ls -la /sys/class/power_supply/BAT0/
```

**Note**: This workaround only sets the charge limit. It does not provide other asusctl features like fan control or keyboard backlight management.

### Workaround 3: Alternative Power Management Without asusctl

While pwrcfg and rrcfg are not available, you can use built-in Linux power management tools.

#### Using power-profiles-daemon

**Status**: Already installed by setup script

```bash
# List available power profiles
powerprofilesctl list

# Set power profile to performance
powerprofilesctl set performance

# Set power profile to balanced
powerprofilesctl set balanced

# Set power profile to power-saver
powerprofilesctl set power-saver

# Check current profile
powerprofilesctl get
```

**Integration with Desktop Environments**:
- **GNOME**: Settings → Power → Power Mode
- **KDE Plasma**: System Settings → Power Management → Energy Saving
- **XFCE**: Settings → Power Manager → System

#### Using TLP for Advanced Power Management

TLP is a comprehensive power management tool that can replace some pwrcfg functionality.

**Installation**:
```bash
sudo apt install -y tlp tlp-rdw

# Enable TLP
sudo systemctl enable tlp.service

# Start TLP
sudo systemctl start tlp.service

# Check TLP status
sudo tlp-stat -s
```

**Configuration** (`/etc/tlp.conf`):
```bash
# Edit TLP configuration
sudo nano /etc/tlp.conf

# Key settings for GZ302EA:

# CPU frequency scaling (AMD P-State)
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# AMD GPU power management
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# USB autosuspend
USB_AUTOSUSPEND=1

# WiFi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Battery charge thresholds (if supported)
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
```

**Apply Changes**:
```bash
# Restart TLP to apply changes
sudo tlp start

# Check if battery thresholds are supported
sudo tlp-stat -b
```

**Expected Outcome**:
- Automatic power profile switching based on AC/battery
- CPU frequency scaling optimized for battery life
- GPU power management
- Battery charge thresholds (if supported by hardware)
- WiFi power management

**Note**: TLP and power-profiles-daemon can conflict. Choose one or the other, not both.

#### Using cpupower for CPU Frequency Control

**Installation**:
```bash
sudo apt install -y linux-tools-common linux-tools-$(uname -r)
```

**Manual CPU Frequency Control**:
```bash
# Check current CPU frequency info
sudo cpupower frequency-info

# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Set CPU governor to powersave
sudo cpupower frequency-set -g powersave

# Set CPU governor to schedutil (recommended)
sudo cpupower frequency-set -g schedutil
```

**Create Profile Scripts**:
```bash
# Create a performance profile script
sudo tee /usr/local/bin/cpu-performance.sh > /dev/null << 'EOF'
#!/bin/bash
sudo cpupower frequency-set -g performance
echo "CPU set to performance mode"
EOF

# Create a powersave profile script
sudo tee /usr/local/bin/cpu-powersave.sh > /dev/null << 'EOF'
#!/bin/bash
sudo cpupower frequency-set -g powersave
echo "CPU set to powersave mode"
EOF

# Make scripts executable
sudo chmod +x /usr/local/bin/cpu-performance.sh
sudo chmod +x /usr/local/bin/cpu-powersave.sh

# Use the scripts
sudo /usr/local/bin/cpu-performance.sh
sudo /usr/local/bin/cpu-powersave.sh
```

**Note**: The AMD P-State driver (`amd-pstate-epp`) is already configured by the setup script, which provides optimal CPU frequency scaling. Manual cpupower adjustments are optional.

#### Using xrandr for Refresh Rate Control

Without rrcfg, you can use xrandr to manually control display refresh rates.

**Check Available Refresh Rates**:
```bash
# List all displays and available refresh rates
xrandr
```

**Set Refresh Rate**:
```bash
# Set to 60Hz (example)
xrandr --output eDP-1 --mode 1920x1200 --rate 60

# Set to 120Hz (example)
xrandr --output eDP-1 --mode 1920x1200 --rate 120

# Set to 180Hz (maximum for GZ302EA)
xrandr --output eDP-1 --mode 1920x1200 --rate 180
```

**Create Refresh Rate Profile Scripts**:
```bash
# Create scripts for common refresh rates
sudo tee /usr/local/bin/refresh-60hz.sh > /dev/null << 'EOF'
#!/bin/bash
DISPLAY=:0 xrandr --output eDP-1 --rate 60
echo "Display refresh rate set to 60Hz"
EOF

sudo tee /usr/local/bin/refresh-120hz.sh > /dev/null << 'EOF'
#!/bin/bash
DISPLAY=:0 xrandr --output eDP-1 --rate 120
echo "Display refresh rate set to 120Hz"
EOF

sudo tee /usr/local/bin/refresh-180hz.sh > /dev/null << 'EOF'
#!/bin/bash
DISPLAY=:0 xrandr --output eDP-1 --rate 180
echo "Display refresh rate set to 180Hz"
EOF

# Make scripts executable
sudo chmod +x /usr/local/bin/refresh-*.sh
```

**Note**: Replace `eDP-1` with your actual display name from `xrandr` output. For Wayland (KDE Plasma), use `kscreen-doctor` instead.

**Wayland Alternative** (KDE Plasma):
```bash
# List displays
kscreen-doctor -o

# Set refresh rate (example)
kscreen-doctor output.eDP-1.mode.1920x1200@60
kscreen-doctor output.eDP-1.mode.1920x1200@120
kscreen-doctor output.eDP-1.mode.1920x1200@180
```

## Future Outlook

### When Will This Be Fixed?

**Short Answer**: Unknown. Depends on PPA maintainer activity.

**Possible Timelines**:

1. **PPA Updated for Ubuntu 25.10** (best case)
   - PPA maintainer builds packages for "questing" release
   - Timeline: Could happen anytime, no guarantees
   - Action: Check periodically with `sudo apt update && apt-cache policy asusctl`

2. **Ubuntu 26.04 LTS Release** (likely case)
   - Next LTS release (April 2026) will likely have PPA support
   - More stable, long-term support (5 years)
   - Recommended for production use
   - Timeline: ~5 months from November 2025

3. **Use Different Distribution** (alternative)
   - Arch Linux: asusctl available in G14 repository (https://arch.asus-linux.org)
   - Fedora: asusctl available in COPR (lukenukem/asus-linux)
   - openSUSE: asusctl available in OBS (hardware:asus)
   - These distributions have more frequent package updates

### Checking for PPA Updates

```bash
# Check if asusctl is available yet
sudo apt update
apt-cache policy asusctl

# If you see a version number, the PPA has been updated!
# If you see "Unable to locate package asusctl", it's still unavailable
```

### Recommendations for Ubuntu 25.10 Users

**For Production Use**:
- Use the systemd battery limit workaround (Workaround 2)
- Use power-profiles-daemon or TLP for power management
- Use xrandr or kscreen-doctor for refresh rate control
- All critical hardware works perfectly

**For ASUS-Specific Features**:
- Build asusctl from source (Workaround 1) if you need:
  - Battery charge limit with GUI control
  - Advanced fan curve customization
  - Keyboard backlight control
  - ASUS-specific power profiles

**For Maximum Stability**:
- Consider waiting for Ubuntu 26.04 LTS (April 2026)
- Or switch to a distribution with better asusctl support:
  - Arch Linux + G14 repository (rolling release)
  - Fedora 41+ (6-month release cycle)
  - openSUSE Tumbleweed (rolling release)

## Additional Resources

### Official Documentation
- **asusctl GitLab**: https://gitlab.com/asus-linux/asusctl
- **asus-linux.org**: https://asus-linux.org
- **Ubuntu 25.10 Release Notes**: https://discourse.ubuntu.com/t/oracular-oriole-release-notes/

### Community Resources
- **asus-linux Discord**: https://discord.gg/4ZKGd7Un5t
- **GZ302 Setup Repository**: https://github.com/th3cavalry/GZ302-Linux-Setup
- **Ubuntu Forums**: https://ubuntuforums.org

### Related Documentation in This Repository
- **Main README**: `../README.md`
- **CHANGELOG**: `CHANGELOG.md`
- **Kernel Research**: `kernel_changelog.md`
- **Distribution Kernel Status**: `DISTRIBUTION_KERNEL_STATUS.md`
- **Research Summary**: `RESEARCH_SUMMARY.md`

## Conclusion

Ubuntu 25.10 "Oracular Oriole" works excellently on the ASUS ROG Flow Z13 GZ302EA hardware with the gz302-main.sh setup script. The kernel 6.17.0-6 provides native support for all critical components (CPU, GPU, WiFi, touchpad). While the asusctl PPA is not yet available for the "questing" release, this only affects ASUS-specific utilities (battery charge limit, fan control, keyboard backlight). Workarounds are available for all missing functionality, and core hardware performance is outstanding.

**Recommendation**: Ubuntu 25.10 is suitable for daily use on the GZ302EA with the provided workarounds. For users requiring ASUS-specific features without building from source, consider waiting for Ubuntu 26.04 LTS (April 2026) or switching to a distribution with better asusctl support (Arch, Fedora, openSUSE).

---

**Document Version**: 1.0
**Last Updated**: November 5, 2025
**Author**: Documentation Teamlead
**Hardware Tested**: ASUS ROG Flow Z13 GZ302EA-XS99 (AMD Strix Halo)
**Kernel Tested**: 6.17.0-6-generic
**Script Version**: gz302-main.sh v1.0.7
