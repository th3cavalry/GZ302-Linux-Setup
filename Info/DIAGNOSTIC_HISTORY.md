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