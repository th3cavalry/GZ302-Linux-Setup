# 2025-11-30: Adding amdgpu.dcdebugmask=0x410 to kernel boot options prevents system freezing

On the ASUS ROG Flow Z13 (GZ302), persistent freezing issues were resolved by adding the following parameter to the kernel boot options:

    amdgpu.dcdebugmask=0x410

This should be appended to the kernel command line (e.g., in `/etc/default/grub` or `/etc/kernel/cmdline`).

Reference: User diagnostic, confirmed stable after multiple reboots.

## 2025-11-30 Evening: System Freeze Incident Analysis

**Time of Freeze**: ~20:03 - 20:04
**Cause**: AMD GPU pageflip timeout errors in KWin Wayland
**Log Evidence**: 
- Multiple "Pageflip timed out! This is a bug in the amdgpu kernel driver" messages
- KWin Wayland process reporting systematic pageflip failures
- System became unresponsive requiring hard reboot

**Current Kernel Parameters**: 
```
amdgpu.dcdebugmask=0x410 amdgpu.sg_display=0
```

**Status**: The `amdgpu.dcdebugmask=0x410` parameter was already present but this freeze still occurred. This suggests either:
1. Additional AMD GPU parameters may be needed
2. The issue is intermittent and not fully resolved by this parameter alone
3. Different underlying cause (display controller vs. general GPU stability)
## GZ302-Linux-Setup: Troubleshooting Diagnostic History

**Device:** ASUS ROG Flow Z13 (GZ302EA)
**Date:** November 30, 2025

### Summary of Issue
- System freezes after login (display unresponsive), but recovers after sleep/wake (lid close/open).
- Issue persists even after full uninstall of GZ302-Linux-Setup scripts and all user/system services.
- Suspected interaction with AMDGPU, Wayland/KWin, and ASUS folio (keyboard cover).

---

### Troubleshooting Steps Already Taken

#### 1. Uninstalled All GZ302-Linux-Setup Components
  - Ran official uninstall script as root.
  - Manually removed:
    - All user/systemd services (pwrcfg, rrcfg, llama-server, ollama, gz302-tray, etc.)
    - All user autostart entries and scripts (gz302-tray, open-webui, display-reset, etc.)
    - All LLM/AI software (ollama, llama.cpp, Open WebUI, etc.)
    - All config directories and binaries created by the scripts.
  - Rebooted after uninstall.

#### 2. Disabled All Power/Refresh Management
  - Disabled and stopped pwrcfg-auto.service and pwrcfg-monitor.service.
  - Disabled all user-level autostart entries.

#### 3. Investigated Logs
  - Found repeated `kwin_wayland: atomic commit failed: Device or resource busy` errors.
  - Found ASUS/keyboard/touchpad kernel bugs and warnings.
  - Found no evidence of folio-specific scripts running.

#### 4. Tested User Autostart and Power Services
  - Disabled all user/systemd autostart entries and services.
  - Issue persisted.

#### 5. Sleep/Wake Always Fixes Display
  - Closing and opening the lid always restores the display after freeze.

#### 6. Suspected Folio (Keyboard Cover)
  - No folio-specific scripts or services found running.
  - Issue persists regardless of uninstall.

#### 7. No User/Script Cause
  - Issue is likely a kernel/driver/display stack bug, not a user config or script.

---

### Next Steps (After Reinstall)
- Check if issue persists on clean Arch install (before running any setup scripts).
- If issue persists, focus on:
  - Kernel/AMDGPU/Wayland bugs
  - BIOS/firmware updates
  - Folio/keyboard cover state at login
  - Kernel parameter workarounds (amdgpu.dc=0, amdgpu.runpm=0, etc.)
- Only reintroduce GZ302-Linux-Setup scripts after confirming baseline system is stable.

---

**Do not repeat the above steps unless something changes in hardware or base OS.**
**Continue from here after reinstall.**