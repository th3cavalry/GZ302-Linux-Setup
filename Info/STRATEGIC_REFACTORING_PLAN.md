# GZ302 Linux Toolkit: Strategic Refactoring Plan
## Post-6.17 Era Architectural Modernization

**Document Version:** 1.0.0  
**Date:** December 2025  
**Status:** Planning & Analysis Phase  
**Based on:** Gemini Pro 3 Strategic Vision Analysis

---

## Executive Summary

The GZ302-Linux-Setup repository has successfully transitioned from a "hardware enablement repair kit" (v2.x, kernel 6.14-6.16) to a "performance optimization toolkit" (v3.0.0, kernel 6.17+). This document outlines the strategic vision for further architectural modernization to create a professional-grade system administration utility.

### Current State (v3.0.0)
✅ **Achieved:**
- Kernel-aware conditional fixes (6.14-6.17+ detection)
- Modular architecture with optional components
- Obsolescence cleanup for modern kernels
- Distribution-agnostic design (4 distro families)
- Shared utilities library (gz302-utils.sh)
- CI/CD validation pipeline
- Beautiful terminal output and error handling

### Vision: Library-First Toolkit Architecture

The goal is to evolve from "shell scripts that do things" to a **stateful, idempotent, professional toolkit** with:
- Hardware detection separate from configuration application
- State tracking (don't reapply what's already correct)
- Granular rollback capabilities
- Enhanced error recovery
- Comprehensive logging
- Testing infrastructure

---

## Part 1: Technical Context - The Hardware Evolution

### 1.1 WiFi Subsystem: MediaTek MT7925e (WiFi 7)

**Problem (Kernel < 6.17):**
- ASPM (Active State Power Management) aggressive L1/L1.2 transitions
- Connection drops, device disappears from PCI bus
- Fails to wake from low-power states

**Legacy Solution:**
```bash
options mt7925e disable_aspm=1  # Sledgehammer approach
```

**Impact:** Prevents S0ix deep sleep, degrades battery life significantly

**Modern Reality (Kernel 6.17+):**
- Upstream kernel includes timing adjustments and quirks
- Native ASPM management works correctly
- Applying old workaround is **counter-productive** and **harms battery life**

**Toolkit Approach:**
```bash
# Conditional logic based on kernel version
if kernel < 6.17; then
    apply_aspm_workaround()
else
    verify_native_support()
    cleanup_obsolete_workaround()
fi
```

### 1.2 Audio Subsystem: Cirrus Logic CS35L41 Smart Amplifiers

**Architecture:**
- Realtek ALC294 codec + dual CS35L41 amps via I2C
- Requires ACPI _DSD (Device Specific Data) properties
- Manufacturer ACPI tables optimized for Windows, not Linux

**Failure Mode:**
```
cs35l41-hda: Failed to sync masks
```
Result: Dummy output or headphones work but speakers silent

**Current State:**
- Kernel 6.17+ improved generic CS35L41 handling
- Still requires device-specific firmware (subsystem ID 0x1043:0x1fb3)
- Firmware not yet in linux-firmware upstream package

**Toolkit Role:**
1. Verify specific subsystem ID
2. Manage firmware symbolic links
3. Provision device-specific firmware payloads
4. Validate audio initialization

**Status:** Still needed on all kernel versions (not yet fully upstream)

### 1.3 Input & Tablet Mode: ASUS WMI

**Legacy Challenge (Kernel < 6.17):**
- No ACPI events for keyboard detachment
- Required userspace polling + rotation scripts
- Manual screen rotation via xrandr/wlr-randr

**Modern Integration (Kernel 6.17+):**
- Kernel emits `SW_TABLET_MODE` input events
- GNOME 49+, KDE Plasma 6 native support via Wayland
- `iio-sensor-proxy` reads accelerometer correctly
- Automatic rotation without manual intervention

**Toolkit Approach:**
- Kernel < 6.17: Install userspace daemon
- Kernel 6.17+: Verify native support, provide fallback for X11/i3/tiling WMs
- Configuration utility for desktop environment settings

---

## Part 2: Architectural Analysis - Current vs. Vision

### 2.1 Current Architecture (v3.0.0)

```
gz302-main.sh (3961 lines)
├── Kernel version detection
├── Distribution detection
├── Hardware fixes (monolithic function)
├── Package installation (per-distro functions)
├── Power management setup (TDP/refresh)
├── RGB keyboard setup
├── Tray icon installation
└── Optional module installation

gz302-utils.sh (830 lines)
├── Color codes & symbols
├── Visual formatting functions
├── Error handling
├── Config backup system
├── Checkpoint/resume system
└── Distribution detection helpers

Optional Modules:
├── gz302-gaming.sh (314 lines)
├── gz302-llm.sh (2117 lines)
├── gz302-hypervisor.sh (570 lines)
├── gz302-snapshots.sh (171 lines)
└── gz302-secureboot.sh (149 lines)
```

**Strengths:**
- Clean separation between core and optional features
- Excellent visual output and user experience
- Robust error handling
- Good modularity

**Limitations:**
- Hardware fixes applied monolithically
- Limited idempotency checking
- State not tracked between runs
- Difficult to selectively apply/remove specific fixes
- Testing requires full execution

### 2.2 Vision Architecture: Library-First Design

```
Core Libraries (gz302-lib/):
├── hardware-detect.sh      # Detection without modification
│   ├── detect_wifi_controller()
│   ├── detect_audio_subsystem()
│   ├── detect_input_devices()
│   └── detect_gpu()
├── kernel-compat.sh        # Kernel version logic
│   ├── get_kernel_version()
│   ├── requires_wifi_workaround()
│   ├── requires_tablet_daemon()
│   └── cleanup_obsolete_fixes()
├── state-manager.sh        # Track what's installed
│   ├── is_fix_applied()
│   ├── mark_fix_applied()
│   ├── get_fix_status()
│   └── rollback_fix()
├── wifi-manager.sh         # WiFi-specific logic
│   ├── detect_wifi_state()
│   ├── apply_wifi_fix()
│   ├── verify_wifi_fix()
│   └── cleanup_wifi_fix()
├── audio-manager.sh        # Audio-specific logic
├── input-manager.sh        # Input/tablet mode logic
└── gpu-manager.sh          # GPU optimization logic

Main Scripts:
├── gz302-main.sh           # Orchestrator (calls libraries)
├── gz302-minimal.sh        # Minimal orchestrator
└── gz302-utils.sh          # Visual/formatting utilities

State Tracking:
├── /var/lib/gz302/state/
│   ├── wifi.status
│   ├── audio.status
│   ├── input.status
│   └── gpu.status
```

---

## Part 3: Implementation Roadmap

### Phase 1: Library Extraction (Weeks 1-2)
**Goal:** Extract hardware-specific logic into dedicated library files

**Tasks:**
- [ ] Create `gz302-lib/` directory structure
- [ ] Extract WiFi detection and fix logic → `wifi-manager.sh`
- [ ] Extract audio logic → `audio-manager.sh`
- [ ] Extract input/tablet logic → `input-manager.sh`
- [ ] Extract GPU logic → `gpu-manager.sh`
- [ ] Create `kernel-compat.sh` for version checking
- [ ] Update main scripts to use library functions
- [ ] Validate: All scripts pass shellcheck and syntax check
- [ ] Validate: CI/CD pipeline passes
- [ ] Test: Manual testing on VM with different kernel versions

**Success Criteria:**
- Main script < 1500 lines (down from 3961)
- Each library < 300 lines, single responsibility
- All existing functionality preserved
- Zero breaking changes for users

### Phase 2: State Management (Weeks 3-4)
**Goal:** Implement idempotency and state tracking

**Tasks:**
- [ ] Create `/var/lib/gz302/state/` directory structure
- [ ] Implement state file format (JSON or simple key=value)
- [ ] Add `is_fix_applied()` function for each component
- [ ] Add `mark_fix_applied()` function for each component
- [ ] Update fix application logic to check state first
- [ ] Add `--force` flag to override state checking
- [ ] Add `--status` command to show current state
- [ ] Validate: Re-running script is idempotent (no changes if already applied)

**Success Criteria:**
- Running script twice produces no changes on second run
- State files accurately reflect installed components
- `--status` command provides clear system state overview
- User can selectively re-apply specific fixes

### Phase 3: Enhanced Error Handling (Week 5)
**Goal:** Implement granular error recovery and rollback

**Tasks:**
- [ ] Add rollback functions for each component
- [ ] Implement transaction-like apply/verify/commit pattern
- [ ] Add `--rollback-component <name>` command
- [ ] Enhanced logging to `/var/log/gz302/`
- [ ] Pre-change backups for critical files
- [ ] Post-change verification for each fix
- [ ] Validate: Rollback successfully undoes changes

**Success Criteria:**
- Each fix can be individually rolled back
- Failed fixes don't leave system in broken state
- Comprehensive logs aid troubleshooting
- Backup/restore mechanism tested and working

### Phase 4: Testing Infrastructure (Week 6)
**Goal:** Create automated testing framework

**Tasks:**
- [ ] Create `tests/` directory
- [ ] Unit tests for library functions (bats or bash-tap)
- [ ] Integration tests for full script execution
- [ ] Mock kernel version for testing different paths
- [ ] Mock hardware detection for testing edge cases
- [ ] CI/CD integration for automated testing
- [ ] Validate: All tests pass on multiple distros

**Success Criteria:**
- 80%+ code coverage with unit tests
- Integration tests cover all major workflows
- Tests run automatically in CI/CD
- Tests document expected behavior

### Phase 5: Documentation & Polish (Week 7)
**Goal:** Complete documentation and architectural diagrams

**Tasks:**
- [ ] Architecture diagram (ASCII art or Mermaid)
- [ ] Library API documentation
- [ ] Migration guide from v3.0.0 to v4.0.0
- [ ] Developer guide for adding new hardware support
- [ ] User guide for advanced features
- [ ] Update README.md with new architecture
- [ ] Create ARCHITECTURE.md document
- [ ] Validate: Documentation is clear and complete

**Success Criteria:**
- New contributors can understand architecture
- Users understand how to use new features
- All public functions have documentation
- Examples provided for common use cases

---

## Part 4: Backward Compatibility Strategy

### Compatibility Promise
- v3.0.0 scripts continue to work unchanged
- v4.0.0 is opt-in for new features
- Smooth migration path with automated tools
- Support v3.0.0 for 6 months after v4.0.0 release

### Migration Tools
```bash
# Auto-migrate from v3.0.0 to v4.0.0
gz302-migrate-v4.sh
├── Detect v3.0.0 installation
├── Convert configs to v4.0.0 format
├── Initialize state tracking
├── Validate migration success
└── Create rollback point
```

---

## Part 5: Success Metrics

### Technical Metrics
- **Code Modularity:** Main script < 1500 lines (63% reduction)
- **Idempotency:** 100% of operations idempotent
- **Test Coverage:** 80%+ unit test coverage
- **Maintainability:** Average function < 50 lines
- **Documentation:** Every public function documented

### User Experience Metrics
- **Installation Time:** < 10 minutes for core features
- **Error Recovery:** Automatic rollback on critical failures
- **State Visibility:** Clear status reporting for all components
- **Selective Control:** Apply/remove individual fixes
- **Learning Curve:** New users productive in < 5 minutes

### Performance Metrics
- **Battery Life:** 10-20% improvement on kernel 6.17+ (vs. v2.x workarounds)
- **WiFi Performance:** Native ASPM = lower latency, better throughput
- **System Stability:** No regressions vs. v3.0.0
- **Boot Time:** No measurable increase in boot time

---

## Part 6: Risk Assessment

### High Risk
- **Breaking Changes:** Library refactor could break existing workflows
  - *Mitigation:* Extensive testing, gradual rollout, v3.0.0 support

- **State Corruption:** Bad state files could cause incorrect behavior
  - *Mitigation:* State validation, recovery mode, fresh install option

### Medium Risk
- **Performance Overhead:** State checking could slow execution
  - *Mitigation:* Minimal overhead design, caching, parallel operations

- **Compatibility Issues:** Library dependencies could cause issues
  - *Mitigation:* Keep libraries self-contained, minimal dependencies

### Low Risk
- **User Adoption:** Users may not upgrade from v3.0.0
  - *Mitigation:* Clear value proposition, migration tools, documentation

---

## Part 7: Next Actions

### Immediate (This Week)
1. **Review & Approval:** Maintainer review this strategic plan
2. **Prototype:** Create proof-of-concept for wifi-manager.sh library
3. **Testing Setup:** Set up test VMs with kernel 6.14, 6.16, 6.17+
4. **Baseline Metrics:** Document current performance/behavior for comparison

### Short Term (Month 1)
1. **Phase 1 Implementation:** Library extraction and refactoring
2. **Community Feedback:** Share roadmap, gather input from users
3. **CI/CD Enhancement:** Add library-specific validation
4. **Documentation Start:** Begin ARCHITECTURE.md document

### Medium Term (Months 2-3)
1. **Phase 2-3 Implementation:** State management and error handling
2. **Beta Testing:** Community testing of v4.0.0-beta
3. **Performance Validation:** Measure battery life improvements
4. **Migration Tool:** Create v3→v4 migration script

### Long Term (Months 4-6)
1. **Phase 4-5 Implementation:** Testing and documentation
2. **Release v4.0.0:** Public release with full feature set
3. **Community Education:** Tutorials, videos, blog posts
4. **Advanced Features:** AI workload scheduling, gaming profiles

---

## Conclusion

The GZ302 Linux Toolkit is well-positioned to evolve from a hardware enablement tool into a professional-grade system administration utility. The v3.0.0 foundation is solid, with kernel-aware fixes and modular architecture. The proposed library-first refactoring will enhance maintainability, testability, and user control while preserving the excellent user experience.

**Key Principle:** Evolution, not revolution. Build on existing strengths, maintain backward compatibility, and deliver incremental value.

**Success Definition:** A toolkit that is:
- **Short and sweet** for users (simple interface)
- **Robust and sophisticated** internally (professional architecture)
- **Sustainable** for maintainers (easy to extend and debug)
- **Valuable** for the GZ302 community (real performance benefits)

---

**Document Status:** Living document, will be updated as implementation progresses.

**Feedback:** Community input welcome via GitHub issues or discussions.

**Version History:**
- 1.0.0 (Dec 2025): Initial strategic plan based on Gemini Pro 3 vision analysis
