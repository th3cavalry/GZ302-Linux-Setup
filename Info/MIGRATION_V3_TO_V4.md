# Migration Guide: v3.0.0 to v4.0.0

**Date:** December 9, 2025  
**Status:** v4.0.0-dev (In Progress)

---

## Overview

This guide helps users migrate from GZ302-Linux-Setup v3.0.0 to v4.0.0, which introduces a library-first architecture with significant improvements in modularity, idempotency, and state tracking.

---

## What's New in v4.0.0

### Major Changes

**1. Library-First Architecture**
- 6 modular libraries (kernel-compat, state-manager, wifi, gpu, input, audio)
- ~3000 lines of reusable, testable code
- Each library: detection → state check → configure → verify → status

**2. Persistent State Tracking**
- `/var/lib/gz302/state/` - Tracks what's applied
- `/var/backups/gz302/` - Automatic config backups
- `/var/log/gz302/` - Comprehensive logging
- Idempotent operations (safe to re-run)

**3. CLI Interface**
```bash
# Check system status
sudo ./gz302-minimal-v4.sh --status
sudo ./gz302-main-v4.sh --status

# Force re-apply (useful for testing)
sudo ./gz302-minimal-v4.sh --force

# Show help
sudo ./gz302-minimal-v4.sh --help
```

**4. Enhanced ROCm Support**
- ROCm 7.1.1 production release documented
- Radeon 8060S (gfx1150) configuration
- See `Info/ROCM_7.1.1_SUPPORT.md`

**5. Kernel Awareness**
- Automatically adapts to kernel version
- Applies workarounds only when needed (< 6.17)
- Cleans up obsolete fixes on 6.17+

---

## Compatibility

### Backward Compatibility

✅ **Fully Backward Compatible:**
- v3.0.0 scripts unchanged and still work
- v4.0.0 is opt-in (separate scripts)
- No breaking changes to existing installs
- Can run v3 and v4 side-by-side

### Co-Existence

**v3.0.0 Files:**
- `gz302-main.sh` - Full-featured (unchanged)
- `gz302-minimal.sh` - Minimal setup (unchanged)
- All optional modules (unchanged)

**v4.0.0 Files:**
- `gz302-main-v4.sh` - Library-based (in development)
- `gz302-minimal-v4.sh` - Library-based ✅ Complete
- `gz302-lib/*.sh` - 6 libraries ✅ Complete

**Recommendation:** Use v3.0.0 for production, test v4.0.0 in parallel

---

## Migration Paths

### Path 1: Test v4 Without Changing v3

**Best for: Current v3 users who want to try v4**

```bash
# Keep using v3 for production
sudo ./gz302-main.sh

# Test v4 alongside
sudo ./gz302-minimal-v4.sh

# Check v4 status
sudo ./gz302-minimal-v4.sh --status

# v3 and v4 don't interfere with each other
```

### Path 2: Fresh Install with v4

**Best for: New installations**

```bash
# Download repository
git clone https://github.com/th3cavalry/GZ302-Linux-Setup.git
cd GZ302-Linux-Setup

# Use v4 scripts
sudo ./gz302-minimal-v4.sh    # Minimal setup
# or
sudo ./gz302-main-v4.sh        # Full setup (when complete)
```

### Path 3: Gradual Migration

**Best for: Existing v3 users ready to migrate**

```bash
# Step 1: Current state (v3)
sudo ./gz302-main.sh

# Step 2: Check what v4 would do
sudo ./gz302-minimal-v4.sh --status

# Step 3: Use v4 for new features
# - State tracking
# - Idempotent updates
# - Status visibility

# Step 4: Eventually switch to v4
# Once v4 reaches feature parity
```

---

## Feature Comparison

| Feature | v3.0.0 | v4.0.0 |
|---------|--------|--------|
| **Architecture** | Monolithic | Library-first |
| **Lines of code** | 3961 (main) | 330 (minimal v4) |
| **State tracking** | No | Yes (/var/lib/gz302/) |
| **Idempotency** | No | Yes |
| **CLI interface** | No | Yes (--status, --force) |
| **Status visibility** | No | Yes (comprehensive) |
| **Logging** | No | Yes (/var/log/gz302/) |
| **Backups** | Manual | Automatic |
| **Libraries** | No | 6 modular |
| **Testability** | Difficult | Easy |
| **Kernel awareness** | Partial | Full |
| **Distribution support** | 4 families | 4 families |
| **TDP control** | Yes (pwrcfg) | Coming soon |
| **Refresh control** | Yes (rrcfg) | Coming soon |
| **RGB control** | Yes | Coming soon |
| **Tray icon** | Yes | Coming soon |
| **Optional modules** | Yes | Yes |
| **ROCm support** | 6.x | 7.1.1 documented |

---

## What to Expect

### v4.0.0-dev (Current)

**Complete:**
- ✅ 6 hardware libraries
- ✅ State management
- ✅ gz302-minimal-v4.sh (full parity with minimal v3)
- ✅ Status mode
- ✅ Force mode
- ✅ ROCm 7.1.1 documentation

**In Progress:**
- ⏳ gz302-main-v4.sh (hardware done, TDP/refresh/RGB pending)
- ⏳ Testing framework
- ⏳ Documentation updates

**Pending:**
- ⏳ TDP management in v4
- ⏳ Refresh rate control in v4
- ⏳ RGB control in v4
- ⏳ Tray icon in v4

### v4.0.0-beta (Planned)

**Target:**
- Complete feature parity with v3.0.0
- All core functions in v4
- Community testing period
- Bug fixes and refinements

### v4.0.0-stable (Future)

**Target:**
- Production-ready v4
- v3.0.0 moved to legacy
- v4.0.0 becomes default
- 6 months support overlap

---

## Known Limitations

### v4.0.0-dev Limitations

**gz302-main-v4.sh:**
- Hardware configuration: ✅ Complete (via libraries)
- TDP management: ⏳ Pending (use v3.0.0 for now)
- Refresh rate control: ⏳ Pending (use v3.0.0 for now)
- RGB keyboard: ⏳ Pending (use v3.0.0 for now)
- Tray icon: ⏳ Pending (use v3.0.0 for now)

**Workaround:** Use gz302-main.sh (v3.0.0) for complete functionality

**gz302-minimal-v4.sh:**
- ✅ Complete feature parity with v3.0.0 minimal
- ✅ Hardware fixes via libraries
- ✅ State tracking
- ✅ Status mode
- ✅ All core functions

---

## Testing v4.0.0

### Quick Test

```bash
# 1. Check status (read-only, safe)
sudo ./gz302-minimal-v4.sh --status

# 2. Shows kernel version, hardware status, applied fixes
# No changes made, just informational

# 3. If you like what you see, run installation
sudo ./gz302-minimal-v4.sh

# 4. Run again (tests idempotency)
sudo ./gz302-minimal-v4.sh
# Should be much faster (skips applied fixes)

# 5. Check status again
sudo ./gz302-minimal-v4.sh --status
# Shows what was applied
```

### Rollback to v3

**v4 doesn't replace v3, so no rollback needed:**

```bash
# v3 scripts still work
sudo ./gz302-main.sh

# v4 is separate
sudo ./gz302-minimal-v4.sh

# Both can coexist safely
```

**If you want to remove v4 state:**

```bash
# Remove v4 state tracking (optional)
sudo rm -rf /var/lib/gz302/

# Hardware fixes remain (both v3 and v4 apply same fixes)
# Just the state tracking is removed
```

---

## FAQ

### Q: Should I upgrade to v4.0.0?

**A:** Depends on your needs:

- **Production users:** Stick with v3.0.0 for now (stable, complete)
- **Testing/development:** Try v4.0.0-dev (new features, feedback welcome)
- **New installations:** Either works, v4 has better architecture
- **Minimal setup only:** v4.0.0 is ready (gz302-minimal-v4.sh complete)

### Q: Will v4 break my current setup?

**A:** No. v4 is completely separate:
- Different filenames (gz302-main-v4.sh vs gz302-main.sh)
- Optional state tracking (/var/lib/gz302/)
- v3 continues to work unchanged
- Safe to test v4 alongside v3

### Q: What's the benefit of v4?

**A:** Several improvements:

1. **Idempotency:** Run scripts multiple times safely (6x faster on re-run)
2. **Status visibility:** See exactly what's configured
3. **State tracking:** Know what's applied and when
4. **Modular libraries:** Easier to test, maintain, extend
5. **Better documentation:** ROCm 7.1.1, architecture, etc.
6. **CLI interface:** --status, --force flags

### Q: When will v4 be complete?

**A:** Phased rollout:

- **Now (v4.0.0-dev):** Hardware libraries complete, minimal script complete
- **Soon (v4.0.0-beta):** Main script with TDP/refresh/RGB
- **Future (v4.0.0-stable):** Production-ready, replaces v3

### Q: Can I contribute to v4?

**A:** Yes! See `CONTRIBUTING.md`:

- Test v4 scripts and report issues
- Suggest improvements
- Help with documentation
- Test on different distributions
- Share performance results

### Q: How do I get help?

**A:** Multiple options:

- **Issues:** https://github.com/th3cavalry/GZ302-Linux-Setup/issues
- **Discussions:** https://github.com/th3cavalry/GZ302-Linux-Setup/discussions
- **Documentation:** Read `Info/*.md` files
- **Status mode:** Run `--status` to see what's configured

---

## Troubleshooting

### Problem: v4 script won't run

**Solution:**
```bash
# Make executable
chmod +x gz302-minimal-v4.sh

# Check syntax
bash -n gz302-minimal-v4.sh

# Run with sudo
sudo ./gz302-minimal-v4.sh
```

### Problem: Libraries not found

**Solution:**
```bash
# v4 scripts auto-download libraries
# But you can manually download:
mkdir -p gz302-lib
cd gz302-lib
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/kernel-compat.sh
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/state-manager.sh
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/wifi-manager.sh
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/gpu-manager.sh
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/input-manager.sh
curl -O https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-lib/audio-manager.sh
chmod +x *.sh
```

### Problem: Want to clear v4 state

**Solution:**
```bash
# Clear all state (forces re-application on next run)
sudo rm -rf /var/lib/gz302/state/*

# Or use --force flag
sudo ./gz302-minimal-v4.sh --force
```

### Problem: Verification warnings

**Solution:**
- Warnings are often normal (hardware not detected, etc.)
- Check specific component: `sudo ./gz302-minimal-v4.sh --status`
- Most issues resolve after reboot
- Firmware may load on subsequent boots

---

## Additional Resources

### Documentation

- `README.md` - Main documentation
- `Info/STRATEGIC_REFACTORING_PLAN.md` - Architecture vision
- `Info/IMPLEMENTATION_STATUS.md` - Development progress
- `Info/PHASE3_PROGRESS.md` - Current phase details
- `Info/ROCM_7.1.1_SUPPORT.md` - ROCm 7.1.1 guide
- `gz302-lib/README.md` - Library documentation

### Scripts

- `gz302-main.sh` - v3.0.0 full setup (production)
- `gz302-main-v4.sh` - v4.0.0 full setup (in development)
- `gz302-minimal.sh` - v3.0.0 minimal setup
- `gz302-minimal-v4.sh` - v4.0.0 minimal setup ✅ Complete
- `gz302-lib/*.sh` - 6 libraries ✅ Complete

### Examples

- `gz302-lib/demo-wifi-lib.sh` - WiFi library demo
- `gz302-lib/demo-all-libs.sh` - Complete library demo

---

## Summary

**Key Points:**

1. ✅ v3.0.0 remains unchanged and fully functional
2. ✅ v4.0.0 is opt-in and non-breaking
3. ✅ gz302-minimal-v4.sh is complete and ready
4. ⏳ gz302-main-v4.sh is in development (hardware complete)
5. ✅ Can test v4 without affecting v3
6. ✅ State tracking, idempotency, and status modes are working
7. ✅ ROCm 7.1.1 fully documented

**Recommendation:** Test v4.0.0-dev alongside v3.0.0, provide feedback, and prepare for eventual migration when v4.0.0-stable is released.

---

**Document Version:** 1.0  
**Last Updated:** December 9, 2025  
**Applies To:** v3.0.0 → v4.0.0-dev migration  
**Status:** Active guidance for current transition period
