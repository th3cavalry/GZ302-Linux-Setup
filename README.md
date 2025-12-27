# GZ302 Toolkit

**Performance optimization and convenience toolkit for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into an optimized Linux powerhouse with kernel-aware hardware fixes, intelligent power management, and optional gaming/AI modules.

> **🚀 Version 4.0.0 (Dec 2025)**
> **New Library-First Architecture:** Modular, testable, maintainable codebase
> **GZ302 Control Center:** Renamed system tray app with power/RGB/monitoring
> **Kernel-Aware Fixes:** Automatically detects kernel version (6.14-6.18+) and applies only necessary fixes
> **Obsolescence Cleanup:** Removes outdated workarounds when running on kernel 6.17+ with native support
> **Kernel Requirement:** Linux 6.14+ required (6.17+ recommended) for full native hardware support

---

## ⚡ Quick Start

### Full Setup (Recommended)

The main script uses a modular library-first architecture for better maintainability and testability:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-utils.sh -o gz302-utils.sh
chmod +x gz302-main.sh gz302-utils.sh
sudo ./gz302-main.sh
```

**Features:**
- 🧩 **9 modular libraries** - Each subsystem (WiFi, GPU, audio, power, display, RGB) is a separate, testable library
- 🔄 **State tracking** - Knows what's already applied, avoids duplicate work
- ↩️ **Rollback support** - Can undo changes if something goes wrong
- 📊 **Status mode** - `sudo ./gz302-main.sh --status` shows all subsystem status
- ⚡ **Force mode** - `sudo ./gz302-main.sh --force` re-applies all fixes
- 🤖 **Non-interactive** - `sudo ./gz302-main.sh -y` skips optional modules prompt

### Minimal Setup (Essential Fixes Only)

For users who want **only the essential hardware fixes** to make Linux run properly:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh
sudo ./gz302-minimal.sh
```

**Kernel-Aware Intelligence:**
- **Kernel < 6.17:** Applies WiFi workarounds, touchpad fixes, and tablet mode support
- **Kernel >= 6.17:** Minimal fixes only (most hardware now native) + cleans up obsolete workarounds
- **All Kernels:** Essential AMD Strix Halo optimizations and kernel parameters

The minimal script applies only what your kernel version needs:
- Kernel version detection and verification (6.14+ required)
- WiFi stability fix (MediaTek MT7925) - *only if kernel < 6.17*
- AMD GPU optimization (Radeon 8060S)
- Touchpad/keyboard detection - *only if kernel < 6.17*
- Essential kernel parameters (amd_pstate, amdgpu)

### Legacy V3 Setup (Deprecated)

The original monolithic v3 script is still available but deprecated:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main-v3.sh -o gz302-main-v3.sh
chmod +x gz302-main-v3.sh
sudo ./gz302-main-v3.sh
```

> ⚠️ **Note:** V3 is no longer maintained. Use the main script instead.

### Non-interactive / CI-friendly

To run the installer in non-interactive mode (auto-accept prompts where safe), pass the `-y` or `--assume-yes` flag:

```bash
sudo ./gz302-main.sh -y
```

In non-interactive mode the script will:
- Auto-resume if a previous checkpoint is present
- Auto-confirm safe prompts (network continuation, resume, default options)
- Skip potentially risky interactive choices (optional modules will be skipped by default)


The full script will automatically:
- Detect your distro
- Detect your kernel version
- Apply only necessary hardware fixes (kernel-aware)
- Install Power (pwrcfg) and Refresh Rate (rrcfg) tools
- Ask if you want to install optional modules (Gaming, AI, RGB, etc.)
- Clean up obsolete workarounds if running kernel 6.17+

## 🔄 Repository Evolution: From Hardware Enablement to Optimization Toolkit

**Early 2025 (Kernel 6.14-6.16):** This repository was **essential** - the GZ302 was largely unusable on Linux without extensive workarounds for WiFi, touchpad, tablet mode, and graphics stability.

**Late 2025 (Kernel 6.17+):** The Linux kernel now provides **native GZ302 support**. Most hardware "fixes" are obsolete and can actually harm performance if applied. This repository has evolved into an **optimization and convenience toolkit**.

### What This Means For You

| Your Kernel | Repository Role | What You Need |
|-------------|-----------------|---------------|
| **< 6.14** | ❌ Unsupported | Upgrade kernel first |
| **6.14-6.16** | ✅ Essential | Full hardware workarounds required |
| **6.17-6.18** | ⚠️ Optimization | Minimal fixes + convenience tools |
| **6.19+** | 🎨 Toolkit | Convenience & performance tuning only |

**Key Changes in Kernel 6.17+:**
- ✅ Native WiFi support (MT7925) - no ASPM workarounds needed
- ✅ Native tablet mode (asus-wmi) - automatic rotation in GNOME/KDE
- ✅ Native touchpad enumeration - reliable detection on boot
- ⚠️ Audio still needs quirks (CS35L41 subsystem ID not upstream yet)

**The scripts automatically detect your kernel version and adapt accordingly.**

📚 **Detailed Analysis:** See [Info/OBSOLESCENCE.md](Info/OBSOLESCENCE.md) and [Info/KERNEL_COMPATIBILITY.md](Info/KERNEL_COMPATIBILITY.md)

---

## 💻 Supported Hardware

| Model | Variant | RAM | Status |
|---|---|---|---|
| GZ302EA-XS99 | Top Spec | 128GB | ✅ Fully Supported |
| GZ302EA-XS64 | Mid Spec | 64GB | ✅ Fully Supported |
| GZ302EA-XS32 | Base Spec | 32GB | ✅ Fully Supported |

### 🚀 Distribution-Specific Optimizations

**CachyOS (Recommended for Maximum Performance)**
- Automatically detected with tailored recommendations
- 5-20% performance boost from x86-64-v3/v4 optimized packages
- BORE scheduler for better gaming and interactive performance
- LTO/PGO compiler optimizations throughout the system

**Debian Trixie (Debian 13) Support**
- Full compatibility with latest Debian testing
- Automatic ROCm repository setup for AI/LLM workloads
- Build-from-source fallback for ASUS control packages

**AMD P-State Guidance**
- Script provides recommendations for `guided` vs `active` power modes
- Guidance on power efficiency vs predictable performance trade-offs

## ✨ Features & Modules

This setup is modular. The core script installs essential fixes; everything else is optional.

### 🔧 Core System (Always Installed)

- **WiFi Fixes:** Automated MediaTek MT7925e patches for stability
- **Input:** Complete ASUS touchpad gestures and keyboard integration
- **Performance:** Optimized AMD Ryzen AI MAX+ 395 scheduling
- **Power Management:** 7 custom power profiles (10W - 90W)
- **Display:** 7 refresh rate profiles (30Hz - 180Hz) that auto-sync with power
  - Supports X11/Xorg (xrandr), Wayland (wlr-randr), and Hyprland
- **Keyboard Control:** Brightness control (0-3 levels) and RGB lighting

### 📦 Optional Modules (Select during install)

| Module | Description |
|---|---|
| 🎮 Gaming | Steam, Lutris, MangoHUD, GameMode, Wine, Discord |
| 🤖 AI / LLM | Ollama, LM Studio, llama.cpp, vLLM backends + frontends |
| 💻 Hypervisor | KVM/QEMU stack (recommended) or VirtualBox |

> **Note:** RGB control is now part of the core installation (Step 5) and includes both keyboard and rear window lighting.

## 🎛️ Control Center: Usage Guide

### 1. GZ302 Control Center (System Tray)

The easiest way to manage your device with a simple tray indicator.

- **Right-click** the tray icon to switch profiles
- **Visuals:** Checkmarks indicate active profiles; Tooltips show battery % and power draw
- **Keyboard:** Adjust brightness (0-3) and RGB effects directly from the menu
- **RGB Controls:** Unified menu for keyboard and rear window lighting

**Install Control Center manually:**
```bash
cd tray-icon && sudo ./install-tray.sh
```

### 2. Command Line Tools

You can control everything via terminal. If you enabled "password-less sudo" during setup, you do not need to type sudo.

**Power Management (pwrcfg)**
```bash
pwrcfg gaming       # Switch to Gaming profile (High Wattage)
pwrcfg battery      # Switch to Battery profile (Low Wattage)
pwrcfg status       # Show current watts, temp, and limits
pwrcfg config       # Enable auto-switching when plugging/unplugging AC
```

**Refresh Rate (rrcfg)**
```bash
rrcfg gaming        # Set screen to 180Hz
rrcfg powersave     # Set screen to 30Hz
rrcfg vrr on        # Enable Variable Refresh Rate (FreeSync)
```

**RGB Control (gz302-rgb)**
```bash
gz302-rgb static ff0000     # Set keyboard to Red
gz302-rgb breathing 00ff00  # Green breathing animation
gz302-rgb brightness 50     # Set brightness to 50%
```

*Note: RGB settings persist across reboots automatically.*

## 🤖 AI/LLM Module: Complete Setup Guide

The AI module provides a complete local LLM inference stack optimized for Strix Halo with AMD Radeon 8060S (gfx1151). The module uses a sequential menu flow: **Backends → Frontends → Libraries**.

### Quick Start

```bash
sudo ./gz302-llm.sh
```

The script will guide you through selecting backends, frontends, and Python AI libraries.

### Backend Options (Step 1)

| # | Backend | Description | Best For |
|---|---------|-------------|----------|
| 1 | **Ollama** | Model management + serving via official installer | Easy model switching, API at :11434 |
| 2 | **LM Studio** | GUI application (AppImage) with model library | Visual model management |
| 3 | **llama.cpp** | High-performance inference server (CLI-based) | Speed, low overhead |
| 4 | **vLLM** | Production-grade serving with batching | Multi-user serving, high throughput |
| 5 | Install All | Installs all 4 backends | Maximum flexibility |
| 6 | Skip | Skip backend installation | Use existing backends |

### Frontend Options (Step 2)

| # | Frontend | Description | Best For |
|---|----------|-------------|----------|
| 1 | **Open WebUI** | Modern ChatGPT-like interface | Clean UI, chat-focused |
| 2 | **SillyTavern** | Character AI and roleplay platform | Creative writing, personas |
| 3 | **Text Generation WebUI** | Feature-rich oobabooga interface | Advanced settings, fine-tuning |
| 4 | **LibreChat** | Multi-provider chat interface | API aggregation |
| 5 | Install All | Installs all 4 frontends | Try everything |
| 6 | Skip | Skip frontend installation | CLI-only usage |

### Python AI Libraries (Step 3)

Optionally install PyTorch, Transformers, bitsandbytes, and Accelerate for custom AI development.

### AMD Strix Halo GPU Configuration

The script automatically configures ROCm environment variables in `/etc/profile.d/gz302-rocm.sh`:

```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0   # Required for gfx1151 → gfx1100 compatibility
export HIP_VISIBLE_DEVICES=0
export GPU_MAX_HW_QUEUES=8
```

### CachyOS Optimized Installation

On **CachyOS**, the script automatically uses znver4-optimized packages:
- `ollama-rocm` - Pre-built with ROCm support
- `python-pytorch-opt-rocm` - PyTorch with ROCm + AVX2
- **5-20% faster inference** from optimized builds

### Model Selection & VRAM Planning

All models should be in GGUF format. Recommended sources:

- **Unsloth GGUF Models:** https://huggingface.co/unsloth (High quality, actively maintained)
- **TheBloke:** https://huggingface.co/TheBloke (Largest GGUF collection)

**VRAM Estimation:**
```
Model Size + Context Memory + Overhead = Total VRAM
Example: 7B model (7GB) + 8K context (2GB) + 1GB overhead = ~10GB required
```

See: https://github.com/kyuz0/amd-strix-halo-toolboxes#4--memory-planning--vram-estimator

---

📊 Technical Specifications

### Power Profiles (TDP)

| Profile | TDP | Target Use Case |
|---|---|---|
| Emergency | 10W | Critical battery preservation (30Hz) |
| Battery | 18W | Maximum battery life |
| Efficient | 30W | Light tasks with good performance |
| Balanced | 40W | General computing (Default) |
| Performance | 55W | Heavy workloads (AC Recommended) |
| Gaming | 70W | Optimized for gaming (AC Required) |
| Maximum | 90W | Absolute peak performance (AC Only) |

**Power Limits Persistence:** The system automatically monitors and re-applies power limits every 5 seconds, ensuring settings survive system events (sleep/wake, AC plug/unplug). Use `pwrcfg verify` to manually check if hardware matches your selected profile. This feature requires `ryzenadj` with `ryzen_smu-dkms-git` for hardware verification.

### Kernel Requirements

- **Minimum:** Linux 6.14+ (Required for NPU & WiFi)
- **Recommended:** Linux 6.17+ (Best for Strix Halo performance)
- See `Info/DISTRIBUTION_KERNEL_STATUS.md` for distro-specific details

### Hardware Specifications

- **Processor:** AMD Ryzen AI MAX+ 395 (Strix Halo) - 16 cores, 32 threads
- **Graphics:** AMD Radeon 8060S (RDNA 3.5 integrated) - 100% AMD, NO discrete GPU
- **WiFi:** MediaTek MT7925 (kernel module: mt7925e)
- **NPU:** AMD XDNA™ up to 50TOPS

## 🛠️ Troubleshooting & Advanced

### Password Prompts

If `pwrcfg` asks for a password, the sudoers file is missing. Run:
```bash
cd tray-icon && sudo ./install-policy.sh
```

### Uninstallation

To safely remove all components:
```bash
cd Uninstall && sudo ./gz302-uninstall.sh
```

### Advanced Control Options

- **ec_su_axb35 kernel module** (optional, manual): Advanced fan speed and power mode control for Strix Halo
  - See: https://github.com/cmetz/ec-su_axb35-linux

- **Linux-G14 Kernel** (Arch only): Enhanced ROG laptop support with kernel-level RGB LED control
  - See: https://asus-linux.org

## 📚 Additional Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines and contribution process
- [CHANGELOG.md](Info/CHANGELOG.md) - Version history and release notes
- [Info/kernel_changelog.md](Info/kernel_changelog.md) - Detailed kernel version features (6.14-6.18)
- [Info/DISTRIBUTION_KERNEL_STATUS.md](Info/DISTRIBUTION_KERNEL_STATUS.md) - Current kernel versions by distribution
- [gz302-lib/README.md](gz302-lib/README.md) - V4 library architecture documentation
- [tray-icon/](tray-icon/) - GZ302 Control Center documentation

## 🏗️ Architecture: V3 vs V4

| Aspect | V3 (Monolithic) | V4 (Library-First) |
|--------|-----------------|-------------------|
| Main Script | 4,159 lines | 738 lines |
| Libraries | None | 9 modular files |
| Functions | 64 | 217 |
| State Tracking | Limited | Full persistence |
| Testability | Script-level | Per-library |
| Rollback | Manual | Automated |

V4 is recommended for new installations. V3 remains fully functional for existing users.

## 🤝 Contributing

Open source and community driven.

- **Author:** th3cavalry
- **Research:** Shahzebqazi's Asus-Z13-Flow-PCMR
- **License:** MIT

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

---

**Last Updated:** December 2025 (v4.0.0)
