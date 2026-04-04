# GZ302-Linux-Setup: Copilot Instructions

Hardware optimization toolkit for ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395 / Radeon 8060S. Bash-first, kernel-aware (6.14+), multi-distro (Arch, Debian, Fedora, OpenSUSE).

## Architecture

| Component | Purpose |
|-----------|---------|
| `gz302-setup.sh` | Unified installer: hardware fixes, z13ctl, display tools, optional modules |
| `gz302-lib/utils.sh` | Shared utilities: colors, logging, checkpoints, backups |
| `gz302-lib/` | Library-first modules (v5 architecture): wifi, gpu, input, audio, display, state managers |
| `modules/` | Optional modules (downloaded on demand): gaming, llm, hypervisor |
| `scripts/` | Uninstall, suspend hooks |
| `tray-icon/` | PyQt6 system tray for power profile switching (z13ctl backend) |

**Key design:** Scripts are **kernel-aware**—kernel 6.17+ needs fewer workarounds than 6.14-6.16. See `docs/obsolescence-analysis.md`.  
**Hardware control:** Powered by [z13ctl](https://github.com/dahui/z13ctl) for RGB, power profiles, TDP, fan curves, and battery limit.

## Validation (Required Before Commits)

```bash
bash -n gz302-setup.sh && shellcheck gz302-setup.sh   # Syntax + lint
grep "^# Version:" gz302-*.sh                          # Check version sync
```

CI runs: syntax check, ShellCheck (warning severity), version consistency across all modules.

## Version Management

**Current version: 5.0.0** (line 6 of `gz302-setup.sh`)

All module scripts must match. On any change:
1. Increment version in `gz302-setup.sh` (PATCH/MINOR/MAJOR)
2. Update `VERSION` file and matching scripts in `gz302-lib/`, `modules/`, `scripts/`
3. CI will fail if versions mismatch

## Bash Conventions

```bash
set -euo pipefail                          # Always at script start
source "${SCRIPT_DIR}/gz302-utils.sh"      # Load shared utilities
local var; var=$(command)                  # Separate declaration from assignment
info "message"; success "done"; error "fail"  # Use logging helpers
print_section "Title"; print_step 1 5 "Desc"  # Use visual formatters
```

**Distribution detection:** Use `detect_distribution()` → returns `arch|debian|ubuntu|fedora|opensuse`

## Package Installation Pattern

```bash
case "$DISTRO" in
    arch)   sudo pacman -S --noconfirm pkg || install_with_yay pkg ;;
    debian|ubuntu) sudo apt install -y pkg ;;
    fedora) sudo dnf install -y pkg ;;
    opensuse) sudo zypper install -y pkg ;;
esac
```

For AUR packages on Arch: use `install_arch_packages_with_yay()` helper.

## Hardware Context

- **CPU:** AMD Ryzen AI MAX+ 395 (Strix Halo) — use `amd_pstate=guided`
- **GPU:** Radeon 8060S integrated — use `amdgpu.ppfeaturemask=0xffffffff`
- **WiFi:** MediaTek MT7925 — needs `disable_aspm=1` on kernel < 6.17
- **No discrete GPU:** 100% AMD system, no NVIDIA components

## Custom Commands (Created by Scripts)

- `z13ctl apply --color X --mode Y` — RGB lighting (z13ctl native)
- `z13ctl profile --set X` — Power profile switching (quiet, balanced, performance)
- `z13ctl tdp --set X` — TDP control in watts
- `z13ctl batterylimit --set X` — Battery charge limit
- `z13ctl fancurve --set "..."` — Custom fan curves
- `pwrcfg [profile|status|auto|tdp|fan|battery]` — Wrapper for z13ctl (backward compat)
- `gz302-rgb [mode] [color]` — Wrapper for z13ctl apply (backward compat)
- `rrcfg [profile|status|auto]` — Refresh rate control (30Hz-180Hz)

## RGB Control Architecture

RGB control is handled by [z13ctl](https://github.com/dahui/z13ctl):
- `z13ctl apply --color X --mode Y` — Set color and animation mode
- `z13ctl off` — Turn off all RGB
- Settings restored on boot/resume by z13ctl's own daemon

## Key Files

- **Modprobe configs:** `/etc/modprobe.d/gz302-*.conf`
- **Systemd services:** `/etc/systemd/system/gz302-*.service`
- **State/checkpoints:** `/var/lib/gz302/`, `/var/backups/gz302/`
- **RGB configs:** `/etc/gz302/` (FHS-compliant)
- **Module download URL:** `https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/`

## Safety

- **Never run on dev machines** — scripts modify `/etc/modprobe.d`, systemd, sudoers
- **Always validate syntax** before commit
- **Test all 4 distros** — VMs/containers acceptable