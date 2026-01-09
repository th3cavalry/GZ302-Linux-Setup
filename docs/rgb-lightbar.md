# Rear Window RGB Control Research

## Overview

The ASUS ROG Flow Z13 (GZ302) has two separate RGB lighting zones:
1. **Keyboard RGB** - Already supported by our `gz302-rgb.sh` script (C-based implementation)
2. **Rear Window RGB / Lightbar** - The distinctive slash display on the back of the device

## Current Implementation Status

### What We Have
Our current RGB implementation (`gz302-rgb.sh` and `gz302-rgb-cli.c`) controls:
- ✅ Keyboard RGB with static colors
- ✅ Keyboard RGB with animations (breathing, color cycle, pulse, rainbow, strobe)
- ✅ Persistence via systemd service (`gz302-rgb-restore.service`)
- ✅ Integration with tray icon GUI

### What's Missing
- ❌ Rear window / lightbar RGB control
- ❌ Independent control of the two zones (keyboard vs. rear window)

## Research: rpheuts/z13 Repository

**Repository:** https://github.com/rpheuts/z13

### Key Findings

The rpheuts/z13 repository provides a Python-based solution for controlling both RGB zones on the Z13 (2025 model). 

**Architecture:**
- **Language:** Python 3
- **Method:** Direct HID packet writing via `/dev/hidraw*` devices
- **Device Detection:** Uses HID physical path signatures from sysfs uevent files
- **Persistence:** Systemd service + udev rules for auto-restore after sleep/wake

**Device Identification:**
```python
# Physical path signatures used to identify devices
KEYBOARD_SIG = "usb-0000:c6:00.0-4/input1"
LIGHTBAR_SIG = "usb-0000:c6:00.0-5/input0"
```

**Key Components:**
1. `z13-led` - Python script (140 lines) for RGB control
2. `99-asus-rgb.rules` - udev rules for permissions and auto-restore
3. `z13-restore.service` - systemd service to restore colors after sleep/wake

### HID Packet Protocol

**Lightbar Control:**
```python
# Turn ON
[0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff]

# Turn OFF
[0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff]

# Set Color (RGB)
[0x5d, 0xb3, 0x00, 0x00, R, G, B, 0xeb, 0x00, 0x00, 0xff, 0xff, 0xff]
```

**Keyboard Control:**
```python
# Set Color
[0x5d, 0xb3, 0x00, 0x00, R, G, B]
# Apply
[0x5d, 0xb5, 0x00, 0x00]
```

### USB Device IDs
```
Keyboard: idVendor=0b05, idProduct=1a30
Lightbar: idVendor=0b05, idProduct=18c6
```

## Integration Considerations

### Option 1: Pure Python Implementation
**Pros:**
- Direct port of rpheuts/z13 code
- Proven to work on Z13 2025 model
- Simpler HID device auto-detection

**Cons:**
- Requires Python dependency (already present for tray icon)
- Different architecture from current C-based RGB implementation
- Would need to integrate both Python and C tools

### Option 2: C Implementation (Extend Existing)
**Pros:**
- Consistent with current `gz302-rgb-cli.c` implementation
- No additional dependencies
- Single unified RGB control tool

**Cons:**
- Requires porting Python code to C
- Need to implement HID device auto-detection in C
- More development effort

### Option 3: Hybrid Approach
**Pros:**
- Keep existing C tool for keyboard RGB
- Add new Python tool for rear window RGB
- Minimal changes to existing code

**Cons:**
- Two separate tools to maintain
- User confusion about which tool controls what

## Compatibility Analysis

### Hardware Compatibility
The rpheuts/z13 repository targets the 2025 Z13 model (GZ302EA), which is **exactly** our target hardware. The USB device IDs and HID physical paths should be identical.

### Kernel Requirements
- **Minimum:** Linux 6.14+ (matches our current requirement)
- **Optimal:** Linux 6.17+ for native HID support
- No special kernel modules required (uses standard hidraw)

### Distribution Support
The implementation is distribution-agnostic (works on all Linux distros) since it uses:
- Standard Python 3
- Standard /dev/hidraw interface
- Standard systemd and udev (already required by our scripts)

## Recommended Implementation Path

### Phase 1: Add Rear Window Support (Python-based)
1. **Add `gz302-lightbar.py`** - Python script based on rpheuts/z13 `z13-led`
   - Auto-detect lightbar HID device
   - Support commands: `on`, `off`, `color R G B`
   - Follow our naming conventions (gz302-* prefix)

2. **Integrate with existing RGB infrastructure:**
   - Extend `gz302-rgb-restore.service` to restore both keyboard and lightbar
   - Update udev rules in `gz302-main.sh` to include lightbar device permissions
   - Add lightbar device (0b05:18c6) to RGB detection

3. **Update tray icon:**
   - Add "Rear Window RGB" submenu
   - Separate controls for keyboard vs. rear window
   - Allow independent color settings

### Phase 2: Documentation and Testing
1. Update README.md with rear window RGB examples
2. Add CHANGELOG.md entry
3. Test on actual GZ302EA hardware
4. Document any differences from rpheuts/z13 behavior

### Phase 3: Optional Unification (Future)
Consider porting to C for consistency, but only if:
- Python implementation proves problematic
- Users request unified tool
- Development resources available

## Implementation Notes

### Device Detection Strategy
```python
def find_lightbar_device():
    """Auto-detect rear window RGB device"""
    # Check multiple possible signatures
    signatures = [
        "usb-0000:c6:00.0-5/input0",  # Primary
        "usb-0000:*/18c6:*/input0"     # Fallback pattern
    ]
    # Scan /sys/class/hidraw/hidraw*/device/uevent
    # Match against signatures
    return device_path
```

### Error Handling
- Graceful fallback if lightbar not detected (some models may not have it)
- Clear error messages if permissions are wrong
- Verify HID writes succeed before claiming success

### Persistence Strategy
Use the same approach as keyboard RGB:
- Save last color to `/etc/gz302/lightbar-color`
- Restore on boot via systemd service
- Restore after sleep/wake via udev trigger

## Security Considerations

### Permissions
Lightbar device needs write permissions:
```
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"
```

This is safe because:
- Only controls RGB lighting (no security impact)
- Similar to keyboard RGB (already implemented)
- Standard approach used by other RGB control tools

### Sudoers Configuration
Add lightbar command to existing sudoers file:
```
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-lightbar
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-lightbar
```

## Testing Checklist

- [ ] Lightbar turns on/off successfully
- [ ] Color changes apply correctly
- [ ] Settings persist after reboot
- [ ] Settings restore after sleep/wake
- [ ] No conflicts with keyboard RGB
- [ ] Works on all supported distributions
- [ ] Tray icon integration functional
- [ ] Error handling for missing device

## References

- **rpheuts/z13 Repository:** https://github.com/rpheuts/z13
- **ASUS HID Documentation:** https://gitlab.com/asus-linux/asusctl/-/issues/681
- **Linux HID Subsystem:** https://www.kernel.org/doc/html/latest/hid/index.html
- **Our Current RGB Implementation:** `gz302-rgb.sh`, `gz302-rgb-cli.c`

## Conclusion

The rpheuts/z13 repository provides a solid foundation for adding rear window RGB control to the GZ302 Linux Setup toolkit. The implementation is straightforward and proven to work on identical hardware. 

**Recommended approach:** Start with a Python-based implementation (minimal effort, proven to work) and integrate it with our existing RGB infrastructure. This will provide users with complete RGB control over both keyboard and rear window lighting.

---

**Last Updated:** December 2025  
**Status:** Research Complete - Ready for Implementation
