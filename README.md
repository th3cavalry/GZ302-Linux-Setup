# GZ302 Toolkit

**Performance optimization and convenience toolkit for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into an optimized Linux powerhouse with kernel-aware hardware fixes, intelligent power management, and optional gaming/AI modules.

> **🚀 Version 2.3.16 (Dec 2025)**
> **Kernel-Aware Fixes:** Automatically detects kernel version (6.14-6.18+) and applies only necessary fixes
> **Obsolescence Cleanup:** Removes outdated workarounds when running on kernel 6.17+ with native support
> **Repository Transition:** Evolved from "hardware enablement" to "optimization toolkit" for modern kernels
> **New GUI Option:** "Linux Armoury" - A full-featured GTK4 control center (optional)
> **Kernel Requirement:** Linux 6.14+ required (6.17+ recommended) for full native hardware support

---

## ⚡ Quick Start

### Option 1: Minimal Setup (Essential Fixes Only)

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

### Option 2: Full Setup (All Features)

**One-line installation for all supported distros:**
- **Arch-based:** Arch Linux, CachyOS (optimized), Omarchy, EndeavourOS, Manjaro
- **Debian-based:** Debian (including Trixie/13), Ubuntu, Pop!_OS, Linux Mint
- **RPM-based:** Fedora, Nobara
- **SUSE-based:** OpenSUSE Tumbleweed, OpenSUSE Leap

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
```

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
| 🎮 Gaming | Steam, Lutris, MangoHUD, GameMode, Wine |
| 🤖 AI / LLM | Ollama, ROCm, PyTorch, bitsandbytes, Transformers |
| 🌈 RGB | Advanced keyboard lighting control (Static, Breathing, Rainbow) |
| 💻 Hypervisor | KVM/QEMU stack (recommended) or VirtualBox |
| 📸 Snapshots | Automatic system backups via Snapper/Btrfs |
| 🔒 Secure Boot | Boot integrity and kernel signing tools |

## 🎛️ Control Center: Usage Guide

### 1. Linux Armoury (Comprehensive GUI)

A modern, full-featured GTK4 control center designed specifically for the GZ302.
- **Features:** Visual power profile management, refresh rate control, fan curves, and system monitoring.
- **Integration:** Uses standard `asusctl` backend for maximum compatibility.
- **Note:** If you select this during installation, the custom `pwrcfg` and `rrcfg` tools will **not** be installed to avoid conflicts.
- **Usage:** Launch "Linux Armoury" from your application menu.

### 2. System Tray Icon (Legacy GUI)

The easiest way to manage your device if you prefer a simple tray indicator.

- **Right-click** the tray icon to switch profiles
- **Visuals:** Checkmarks indicate active profiles; Tooltips show battery % and power draw
- **Keyboard:** Adjust brightness (0-3) and RGB effects directly from the menu

**Install Tray Icon manually:**
```bash
cd tray-icon && sudo ./install-tray.sh
```

### 3. Command Line Tools

You can control everything via terminal. If you enabled "password-less sudo" during setup, you do not need to type sudo.

**Note:** These tools are only available if you did **not** install Linux Armoury.

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

The AI module provides a complete local LLM inference stack optimized for Strix Halo. This section covers backend selection, frontend options, Python 3.11 setup, and kernel optimization.

### CachyOS Optimized Installation (Recommended)

If you're running **CachyOS**, the script automatically uses optimized packages from CachyOS repositories:

```bash
# CachyOS automatically installs these znver4-optimized packages:
sudo pacman -S ollama-rocm           # Ollama with ROCm for AMD GPUs
sudo pacman -S python-pytorch-opt-rocm  # PyTorch with ROCm + AVX2

# Optional: Install Open WebUI from AUR
yay -S open-webui
```

**CachyOS LLM advantages:**
- **znver4 optimizations**: Packages compiled specifically for Zen 4/5 (like your Ryzen AI MAX+ 395)
- **5-20% faster inference** from optimized builds vs generic x86-64
- **ollama-rocm**: Pre-built with ROCm support for AMD Radeon 8060S
- **No virtualenv needed**: System PyTorch package works out of the box

### Backend Options

When you run the AI module, you'll be prompted to choose an inference backend:

**1. Ollama (Model Management)**
- Unified model downloading, management, and serving
- Works with various frontend UIs (Open WebUI, text-generation-webui, etc.)
- Best for: Multiple model experimentation, easy model switching
- API available at http://localhost:11434

**2. llama.cpp (Fast Inference)**
- Direct model inference, built-in web UI (port 8080)
- Single-model focused, optimized for performance
- Best for: Speed, low resource overhead
- Systemd service: `sudo systemctl enable --now llama-server`
- Access web UI: http://localhost:8080

**3. Both (Recommended)**
- Installs Ollama + llama.cpp for maximum flexibility
- Use Ollama for complex workflows, llama.cpp for quick inference
- Default in non-interactive mode

### Frontend UIs (Top 3)

After selecting a backend, you can install one or more frontends:

**1. text-generation-webui** (Feature-Rich LLM Interface)
- Popular, community-driven, extensive customization
- Best for: Text generation, fine-tuning, advanced settings
- Install location: `~/.local/share/gz302/frontends/text-generation-webui`
- Setup: `cd ~/.local/share/gz302/frontends/text-generation-webui && python -m venv venv && source venv/bin/activate && pip install -r requirements/portable/requirements.txt`

**2. ComfyUI** (Node-Based Visual Workflows)
- Ideal for image generation and complex pipelines
- Best for: Stable Diffusion, ControlNet, advanced image workflows
- Install location: `~/.local/share/gz302/frontends/ComfyUI`
- Setup: `cd ~/.local/share/gz302/frontends/ComfyUI && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`

**3. llama.cpp Built-In WebUI** (Lightweight)
- No separate installation needed
- Runs on port 8080 when llama.cpp service is active
- Best for: Quick inference without overhead
- Automatically available when llama.cpp backend is selected

**4. Open WebUI** (Modern Web Interface)
- Sleek, modern web interface for various LLM backends
- Best for: Clean UI, chat-focused interactions, multi-model management
- Can work with Ollama, llama.cpp, or other backends
- Uses uv for Python environment management
- Directory: `~/open-webui`
- Run: `cd ~/open-webui && source .venv/bin/activate && open-webui serve`

### Strix Halo GPU Optimization

**Critical Flags for llama-server (Automatically Applied):**
```bash
-fa 1          # Flash attention - REQUIRED for Strix Halo, improves throughput by 10x
--no-mmap      # Prevents memory-mapping issues with unified memory aperture
-ngl 999       # All layers to GPU for maximum performance
```

These flags are automatically configured in the systemd service (`/etc/systemd/system/llama-server.service`). Without `-fa 1 --no-mmap`, performance collapses or the system crashes.

**Kernel Parameters (Set by LLM script for AI workloads):**
```bash
amd_iommu=off              # Disables IOMMU for lower latency GPU memory access
amdgpu.gttsize=131072      # Sets GTT size to 128MB for larger unified memory pools
```

These are automatically configured when installing the LLM/AI software module. The script detects your boot loader (GRUB, systemd-boot, Limine, rEFInd, syslinux) and configures the appropriate configuration files. To verify: `cat /proc/cmdline`

**Note:** The `ttm.pages_limit` parameter mentioned in some documentation is not a valid kernel parameter and has been removed.

### Python 3.11 & Open WebUI

Open WebUI uses **uv** for Python environment management and requires Python 3.11. The installer automatically:

- **Installs uv** if not present:
  - **Arch:** `pacman -S uv`
  - **Debian/Ubuntu:** `curl -LsSf https://astral.sh/uv/install.sh | sh`
  - **Fedora:** `dnf install uv`
  - **OpenSUSE:** `zypper install uv`

- **Installs Python 3.11** if not present (distro-specific)
- **Creates uv venv** at `~/open-webui/.venv` with Python 3.11
- **Installs Open WebUI** via `uv pip install open-webui`

- **Directory:** `~/open-webui`
- **Activation:** `cd ~/open-webui && source .venv/bin/activate`
- **Launch:** `open-webui serve`
- **Access:** http://localhost:3000 (default port)

### Model Selection & VRAM Planning

All models should be in GGUF format (quantized for CPU/GPU inference). Recommended sources:

- **Unsloth GGUF Models:** https://huggingface.co/unsloth (High quality, actively maintained)
- **TheBloke:** https://huggingface.co/TheBloke (Largest GGUF collection)

**VRAM Estimation Tool:**
Use the VRAM estimator from kyuz0 Strix Halo toolbox to plan:
```
Model Size + Context Memory + Overhead = Total VRAM
Example: 7B model (7GB) + 8K context (2GB) + 1GB overhead = ~10GB required
```

See: https://github.com/kyuz0/amd-strix-halo-toolboxes#4--memory-planning--vram-estimator

### Performance Tuning

**Recommended ROCm Versions (in order):**
1. **ROCm 7.1 with ROCWMMA** - Best throughput, flash attention optimized
2. **ROCm 6.4.4** - Stable, excellent compatibility
3. **Vulkan RADV** - Most stable, works everywhere (slower)

**Model Quantization Guidelines:**
- **Q4_K_M:** Best balance (4-bit, medium) - Recommended starting point
- **Q3_K_XL:** For larger models or limited VRAM
- **BF16/FP16:** For maximum quality, requires more VRAM

**Batch Size Tuning:**
- Start with `-ngl 999` (all layers to GPU)
- If OOM: Reduce context length (`-c 4096` instead of 8192)
- Test batch sizes with small context first

### Troubleshooting

**"Flash attention disabled" warning:**
- The system is running without optimization. Recheck kernel params.
- Solution: `pwrcfg` and verify `--no-mmap` in llama-server service

**"Could not find Open WebUI wheels for Python X.Y":**
- Open WebUI requires Python 3.11 specifically
- Solution: Manually set up Python 3.11 venv or use Ollama Docker container

**Slow inference (< 10 tokens/sec):**
- Missing `-fa 1` flag
- Check: `sudo systemctl cat llama-server.service | grep ExecStart`
- Fix: Reinstall or manually update the service file

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

### Folio Keyboard Issues

If your keyboard disconnects after sleep, run the specific fix:
```bash
cd Optional && sudo ./gz302-folio-fix.sh
```

### Uninstallation

To safely remove all components:
```bash
cd Uninstall && sudo ./gz302-uninstall.sh
```

### Advanced Control Options

- **ec_su_axb35 kernel module** (optional, manual): Advanced fan speed and power mode control for Strix Halo
  - See: https://github.com/cmetz/ec-su_axb35-linux

- **Linux-G14 Kernel** (optional, Arch only): Enhanced ROG laptop support with kernel-level RGB LED control
  - See: `Optional/gz302-g14-kernel.sh` and https://asus-linux.org

## 📚 Additional Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines and contribution process
- [CHANGELOG.md](Info/CHANGELOG.md) - Version history and release notes
- [Info/kernel_changelog.md](Info/kernel_changelog.md) - Detailed kernel version features (6.14-6.18)
- [Info/DISTRIBUTION_KERNEL_STATUS.md](Info/DISTRIBUTION_KERNEL_STATUS.md) - Current kernel versions by distribution
- [tray-icon/](tray-icon/) - GUI system tray utility documentation

## 🤝 Contributing

Open source and community driven.

- **Author:** th3cavalry
- **Research:** Shahzebqazi's Asus-Z13-Flow-PCMR
- **License:** MIT

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

---

**Last Updated:** December 2025 (v2.3.16)
