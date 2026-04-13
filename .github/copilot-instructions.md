# GZ302-Linux-Setup: AI & Copilot Instructions

Hardware optimization toolkit for ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI MAX+ 395 / Radeon 8060S. 
**MANDATORY for all AI/LLM interactions and automated code changes.**

## Core Mandates

1.  **Single Source of Truth (Versioning)**: The root `VERSION` file is the master source. Any change requiring a version bump MUST update the root `VERSION` first, then sync to: `gz302-setup.sh` (header/help), `gz302-lib/*.sh`, `modules/*.sh`, `tray-icon/VERSION`, `pkg/arch/PKGBUILD`, and `README.md`.
2.  **Library-First Architecture**: No complex logic in `gz302-setup.sh`. All core logic MUST be implemented as functions in `gz302-lib/` managers (e.g., `wifi-manager.sh`). `gz302-setup.sh` is for orchestration only.
3.  **Idempotency**: Every configuration function MUST be idempotent. Check if a change is already applied or if the hardware state is correct before modifying. Use `state-manager.sh` for tracking.
4.  **Kernel-Aware Logic**: Fixes MUST be kernel-aware. Use: `if [[ $kernel_ver -lt 617 ]]; then apply_fix; else remove_fix_if_exists; fi`. Clean up obsolete workarounds on newer kernels.
5.  **No Clutter (Hygiene)**: Replaced scripts MUST be moved to `legacy/` or deleted. Logic changes MUST be synced to `docs/technical/kernel-support.md` or `docs/technical/obsolescence-analysis.md`.
6.  **Multi-Distro Equality**: Arch, Debian, Fedora, and OpenSUSE MUST be supported equally. Every fix/package must be implemented for all four distributions.

## Implementation Workflow

1.  **Research**: Map existing manager functions in `gz302-lib/`.
2.  **Strategy**: Propose changes fitting the Library-First pattern.
3.  **Execution**: Update/add library functions -> update `gz302-setup.sh` -> sync versions -> update `docs/technical/`.
4.  **Validation**: Run `bash -n` and `shellcheck` (zero warnings required). Verify version sync.

## Architecture

| Component | Purpose |
|-----------|---------|
| `gz302-setup.sh` | Unified installer: orchestration, user prompts |
| `gz302-lib/` | **Core Logic (Managers)**: wifi, gpu, input, audio, display, state, distro |
| `modules/` | Optional features: gaming, llm, hypervisor |
| `scripts/` | Uninstall, suspend hooks |
| `tray-icon/` | PyQt6 system tray (z13ctl backend) |
| `legacy/` | Deprecated/replaced scripts |

## Bash Conventions

```bash
set -euo pipefail                          # Always at script start
source "${SCRIPT_DIR}/gz302-lib/utils.sh"  # Load shared utilities
local var; var=$(command)                  # Separate declaration from assignment
info "msg"; success "done"; error "fail"   # Use logging helpers
```

- **Safety**: Never use `sudo` inside library functions.
- **Safety**: Never use `exit` in library functions; return non-zero status.

## Hardware Context

- **CPU**: AMD Ryzen AI MAX+ 395 (Strix Halo) — `amd_pstate=guided`
- **GPU**: Radeon 8060S integrated — `amdgpu.ppfeaturemask=0xffffffff`
- **No discrete GPU**: 100% AMD system.
- **Controls**: Powered by [z13ctl](https://github.com/dahui/z13ctl) for RGB, power, TDP, and battery.

## Validation Commands

```bash
bash -n gz302-setup.sh && shellcheck gz302-setup.sh
grep "^# Version:" gz302-*.sh
```
