# GZ302 Library Directory

This directory contains modular library files that implement the "Library-First" design pattern for the GZ302 Linux Toolkit.

## Architecture Philosophy

**Traditional Approach (Monolithic):**
```bash
# Big script that does everything
detect_hardware()
apply_all_fixes()
verify_everything()
```

**Library-First Approach (Modular):**
```bash
# Separate libraries for each subsystem
source gz302-lib/wifi-manager.sh
source gz302-lib/audio-manager.sh
source gz302-lib/input-manager.sh

# Detection separate from application
wifi_detect_hardware
wifi_check_state
wifi_apply_configuration
wifi_verify_working
```

## Design Principles

1. **Separation of Concerns:** Detection, configuration, and verification are separate functions
2. **Idempotency:** Safe to run multiple times - checks before applying
3. **Kernel-Aware:** Adapts configuration based on kernel version
4. **State-Aware:** Knows what's already applied, doesn't duplicate work
5. **Testable:** Each function can be tested independently
6. **Maintainable:** Small, focused libraries easier to understand and modify

## Current Libraries

### wifi-manager.sh
Manages the MediaTek MT7925e WiFi controller.

**Key Functions:**
- `wifi_detect_hardware()` - Check if WiFi hardware present (read-only)
- `wifi_requires_aspm_workaround()` - Check if kernel needs workaround
- `wifi_get_state()` - Get complete WiFi state (JSON format)
- `wifi_apply_configuration()` - Apply kernel-appropriate config (idempotent)
- `wifi_verify_working()` - Verify WiFi is functional
- `wifi_print_status()` - Display formatted status for users

**Example Usage:**
```bash
#!/bin/bash
source gz302-lib/wifi-manager.sh

# Check if WiFi hardware is present
if wifi_detect_hardware; then
    echo "WiFi hardware found"
    
    # Get current state
    wifi_get_state
    
    # Apply configuration (idempotent)
    wifi_apply_configuration
    
    # Verify it's working
    wifi_verify_working
    
    # Show status to user
    wifi_print_status
fi
```

## Planned Libraries

### audio-manager.sh (Future)
Will manage Cirrus Logic CS35L41 audio amplifiers.

**Planned Functions:**
- `audio_detect_hardware()` - Detect audio subsystem
- `audio_check_subsystem_id()` - Verify subsystem ID (0x1043:0x1fb3)
- `audio_manage_firmware()` - Handle firmware symlinks
- `audio_verify_speakers()` - Test speaker output

### input-manager.sh (Future)
Will manage ASUS HID devices (keyboard, touchpad, tablet mode).

**Planned Functions:**
- `input_detect_devices()` - Detect input hardware
- `input_requires_forcing()` - Check if kernel needs touchpad forcing
- `input_check_tablet_mode()` - Verify tablet mode functionality
- `input_apply_configuration()` - Apply HID configuration

### gpu-manager.sh (Future)
Will manage AMD Radeon 8060S GPU configuration.

**Planned Functions:**
- `gpu_detect_hardware()` - Detect GPU model
- `gpu_verify_firmware()` - Check firmware files present
- `gpu_apply_optimizations()` - Apply ppfeaturemask and parameters
- `gpu_check_stability()` - Monitor for errors

### kernel-compat.sh (Future)
Central kernel version logic for all libraries.

**Planned Functions:**
- `kernel_get_version()` - Get kernel version as comparable number
- `kernel_requires_workarounds()` - List needed workarounds for version
- `kernel_cleanup_obsolete()` - Remove workarounds for modern kernels

### state-manager.sh (Future)
Track what's installed and provide rollback capabilities.

**Planned Functions:**
- `state_init()` - Initialize state directory
- `state_mark_applied(component, config)` - Mark fix as applied
- `state_is_applied(component)` - Check if fix is applied
- `state_rollback(component)` - Remove specific fix
- `state_backup_config(file)` - Backup before changing
- `state_restore_config(file)` - Restore from backup

## Benefits of Library-First Design

### For Users
- **Faster Execution:** Skip already-applied fixes (idempotency)
- **Selective Control:** Apply/remove individual components
- **Clear Status:** See exactly what's configured
- **Less Risk:** Smaller changes, easier to rollback

### For Developers
- **Easier Testing:** Test individual functions in isolation
- **Simpler Debugging:** Smaller code units easier to understand
- **Better Collaboration:** Multiple people can work on different libraries
- **Code Reuse:** Libraries can be used by multiple scripts

### For Maintainers
- **Reduced Complexity:** 3961-line monolith → multiple 200-300 line libraries
- **Easier Updates:** Change one library without touching others
- **Better Documentation:** Each library self-contained with clear API
- **Sustainable Growth:** Add new hardware support without growing monolith

## Migration Strategy

### Phase 1: Proof of Concept (Current)
✅ Create wifi-manager.sh as reference implementation  
✅ Document architecture and design principles  
✅ Validate concept with community

### Phase 2: Core Libraries (Next)
- [ ] Extract audio logic → audio-manager.sh
- [ ] Extract input logic → input-manager.sh
- [ ] Extract GPU logic → gpu-manager.sh
- [ ] Create kernel-compat.sh for version checking

### Phase 3: State Management
- [ ] Create state-manager.sh
- [ ] Implement state tracking in /var/lib/gz302/state/
- [ ] Add rollback capabilities
- [ ] Integrate state checks into all libraries

### Phase 4: Integration
- [ ] Refactor gz302-main.sh to use libraries
- [ ] Refactor gz302-minimal.sh to use libraries
- [ ] Update optional modules to use libraries
- [ ] Comprehensive testing on all distros

## Usage Examples

### Basic Detection
```bash
source gz302-lib/wifi-manager.sh

if wifi_detect_hardware >/dev/null 2>&1; then
    echo "WiFi hardware found"
    wifi_get_state | jq .
fi
```

### Apply Configuration
```bash
source gz302-lib/wifi-manager.sh

# Apply appropriate config for kernel version
wifi_apply_configuration

# Verify it worked
if wifi_verify_working; then
    echo "WiFi configured successfully"
fi
```

### Check Status
```bash
source gz302-lib/wifi-manager.sh

# Display formatted status
wifi_print_status
```

### Idempotency Demonstration
```bash
source gz302-lib/wifi-manager.sh

# First run: applies configuration
wifi_apply_configuration
# Output: "ASPM workaround applied successfully"

# Second run: detects already applied, does nothing
wifi_apply_configuration
# Output: "Native ASPM support already configured"
```

## Testing

### Unit Testing (Planned)
```bash
# Using bats (Bash Automated Testing System)
@test "wifi_detect_hardware detects MT7925e" {
    run wifi_detect_hardware
    [ "$status" -eq 0 ]
    [[ "$output" =~ "14c3:0616" ]]
}

@test "wifi_requires_aspm_workaround returns correct value" {
    # Mock kernel version 6.16
    uname() { echo "6.16.0"; }
    run wifi_requires_aspm_workaround
    [ "$status" -eq 0 ]  # Workaround needed
    
    # Mock kernel version 6.17
    uname() { echo "6.17.0"; }
    run wifi_requires_aspm_workaround
    [ "$status" -eq 1 ]  # Workaround not needed
}
```

### Integration Testing (Planned)
```bash
# Full workflow test
source gz302-lib/wifi-manager.sh

# 1. Detect
wifi_detect_hardware || exit 1

# 2. Apply
wifi_apply_configuration || exit 1

# 3. Verify
wifi_verify_working || exit 1

# 4. Status
wifi_print_status

echo "Integration test passed"
```

## Contributing

When adding new libraries:

1. **Follow the Pattern:** Use wifi-manager.sh as template
2. **Separate Concerns:** Detection, state check, configuration, verification
3. **Make Idempotent:** Always check before applying
4. **Document Well:** Add comprehensive comments and help function
5. **Test Thoroughly:** Test on multiple kernel versions and distros
6. **Use Standard Tools:** Prefer standard commands over complex parsing

## Version History

- **3.0.0** (Dec 2025): Initial library-first architecture
  - Created wifi-manager.sh as proof-of-concept
  - Established design principles and patterns
  - Documented architecture and roadmap

## References

- [Strategic Refactoring Plan](../Info/STRATEGIC_REFACTORING_PLAN.md)
- [Kernel Compatibility Matrix](../Info/KERNEL_COMPATIBILITY.md)
- [Obsolescence Analysis](../Info/OBSOLESCENCE.md)
- [Main README](../README.md)
