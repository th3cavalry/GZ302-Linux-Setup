# 🚀 GZ302 Linux Toolkit

![Version](https://img.shields.io/badge/version-4.2.1-blue?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Kernel-6.14%2B-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Device-ASUS%20ROG%20Flow%20Z13-red?style=for-the-badge)

**The ultimate Linux optimization suite for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into a powerhouse with kernel-aware hardware fixes, intelligent power management, and a dedicated Command Center.

---

## 📥 Installation

### ❓ Which script should I use?

| Feature | 1. Full Setup | 2. Command Center | 3. Minimal |
| :--- | :---: | :---: | :---: |
| **Best For** | **Fresh Installations** | **Existing Users / Power Users** | **Purists / Servers** |
| **Hardware Fixes** | ✅ (Modular) | ❌ (Assumes native/fixed) | ✅ (Kernel-aware) |
| **Power/Fan Control** | ✅ | ✅ | ❌ |
| **RGB Control** | ✅ | ✅ | ❌ |
| **GUI / Tray App** | ✅ | ✅ | ❌ |
| **Optional Modules** | ✅ | ❌ | ❌ |

---

### 1. Full Setup (Fresh Install - Recommended)
**Installs:** Essential hardware fixes (WiFi, GPU, Input) and the complete Command Center toolset. Now refactored for maximum efficiency.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
```

### 2. Command Center Installer
**Installs:** Power profiles, Fan curves, RGB control, Refresh rate manager, and the System Tray App.
*Does NOT touch kernel parameters or hardware drivers.*

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/install-command-center.sh -o install-command-center.sh
chmod +x install-command-center.sh
sudo ./install-command-center.sh
```

### 3. Minimal Setup (Fixes Only)
**Installs:** Only the bare minimum kernel patches and configuration files to make the hardware function. No extra tools.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-minimal.sh -o gz302-minimal.sh
chmod +x gz302-minimal.sh
sudo ./gz302-minimal.sh
```

---

## 🎛️ Features & Usage

### 🖥️ Command Center GUI
After installation, look for **"GZ302 Command Center"** in your application menu or system tray.
* **Right-click:** Quick profile switching (Silent, Balanced, Turbo).
* **Middle-click:** Toggle RGB on/off.
* **Hover:** See real-time power draw and battery health.

### ⌨️ CLI Tools
Control your device entirely from the terminal.

| Command | Usage | Description |
| :--- | :--- | :--- |
| **`pwrcfg`** | `pwrcfg gaming` | Switch power/fan profiles (silent, balanced, gaming, max) |
| **`rrcfg`** | `rrcfg 120` | Set refresh rate (30, 60, 120, 144, 165) or VRR mode |
| **`gz302-rgb`** | `gz302-rgb static ff0000` | Control Keyboard and Rear Window RGB lighting |

> **Note:** RGB settings persist across reboots automatically.

---

## 🧩 Optional Modules
The **Full Setup** script includes an optional module manager:

*   🎮 **Gaming:** Installs Steam, Lutris, MangoHUD, GameMode, and optimized Wine builds.
*   🤖 **AI / LLM:** Sets up a local AI stack (Ollama, LM Studio, ROCm) optimized for the Strix Halo NPU/GPU.
*   💻 **Hypervisor:** Configures KVM/QEMU for maximum performance VM passthrough.

---

## ⚠️ Kernel Compatibility

The scripts automatically detect your kernel and adapt the strategy:

*   **Kernel < 6.14:** ❌ **Unsupported.** Please upgrade.
*   **Kernel 6.14 - 6.16:** ✅ **Essential.** Applies heavy patching for WiFi (MT7925), Touchpad, and Tablet mode.
*   **Kernel 6.17+:** ✨ **Native Mode.** Most hardware works out of the box. The script cleans up obsolete fixes and focuses on performance tuning.

---

## 🖥️ Display Fixes

### OLED Scrolling Artifacts Fix

**Issue:** Purple/green color artifacts and digital/QR-code-like patterns visible during scrolling on the OLED display.

**Cause:** PSR-SU (Power Save Refresh - Sub-Viewport Update) can cause visual artifacts on OLED panels, especially during scrolling.

**Fix Applied:** `amdgpu.dcdebugmask=0x200` disables PSR-SU.

**Automatic Fix:** The full setup scripts (`gz302-main.sh`, `gz302-minimal.sh`) automatically apply this fix during installation.

**Manual Fix:** If you need to apply the fix manually:

```bash
# Add to GRUB (replace /boot/grub/grub.cfg with your GRUB config path)
sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amdgpu.dcdebugmask=0x200"/' /etc/default/grub
sudo update-grub

# Or add to systemd-boot kernel cmdline
echo "amdgpu.dcdebugmask=0x200" | sudo tee -a /etc/kernel/cmdline
```

---

## 📂 Repository Structure

The project uses a **Modular Library-First Architecture** for stability and maintainability.

```
GZ302-Linux-Setup/
├── gz302-main.sh              # 🟢 Entry Point: Full Setup (Orchestrator)
├── install-command-center.sh  # 🟢 Entry Point: Tools Only
├── gz302-minimal.sh           # 🟢 Entry Point: Minimal Fixes
├── gz302-lib/                 # 📚 Refactored Core Libraries (Manager-based)
│   ├── distro-manager.sh      # 🚀 NEW: Distribution setup orchestrator
│   ├── power-manager.sh       # ⚡ TDP & Battery management
│   ├── gpu-manager.sh         # 🎮 GPU & KMS configuration
│   └── ...                    # (Audio, WiFi, Input, RGB, etc.)
├── modules/                   # 📦 Optional feature packs (Gaming, AI, etc.)
└── tray-icon/                 # 🖼️ Python/Qt6 GUI Application
```

---

## 🤝 Contributing & Support

*   **Documentation:** Check the [docs/](docs/) directory for detailed hardware research.
*   **Issues:** Please report bugs on the [Issues page](https://github.com/th3cavalry/GZ302-Linux-Setup/issues).
*   **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

**License:** MIT  
**Maintained by:** th3cavalry

