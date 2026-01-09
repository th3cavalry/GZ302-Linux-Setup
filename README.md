# 🚀 GZ302 Linux Toolkit

![Version](https://img.shields.io/badge/version-4.0.0-blue?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Kernel-6.14%2B-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Device-ASUS%20ROG%20Flow%20Z13-red?style=for-the-badge)

**The ultimate Linux optimization suite for the ASUS ROG Flow Z13 (GZ302).**
Transform your device into a powerhouse with kernel-aware hardware fixes, intelligent power management, and a dedicated Command Center.

---

## 📥 Installation

### ❓ Which script should I use?

| Feature | 1. Command Center | 2. Full Setup | 3. Minimal |
| :--- | :---: | :---: | :---: |
| **Best For** | **Existing Users / Power Users** | **Fresh Installations** | **Purists / Servers** |
| **Hardware Fixes** | ❌ (Assumes native/fixed) | ✅ (Kernel-aware) | ✅ (Kernel-aware) |
| **Power/Fan Control** | ✅ | ✅ | ❌ |
| **RGB Control** | ✅ | ✅ | ❌ |
| **GUI / Tray App** | ✅ | ✅ | ❌ |
| **Optional Modules** | ❌ | ✅ | ❌ |

---

### 1. Command Center Installer (Recommended)
**Installs:** Power profiles, Fan curves, RGB control, Refresh rate manager, and the System Tray App.
*Does NOT touch kernel parameters or hardware drivers.*

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/install-command-center.sh -o install-command-center.sh
chmod +x install-command-center.sh
sudo ./install-command-center.sh
```

### 2. Full Setup (Fresh Install)
**Installs:** Everything in Command Center **PLUS** essential hardware fixes (WiFi, GPU, Input) tailored to your kernel version.

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh
sudo ./gz302-main.sh
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

## 📂 Repository Structure

The project uses a **Library-First Architecture** for stability and modularity.

```
GZ302-Linux-Setup/
├── gz302-main.sh              # 🟢 Entry Point: Full Setup
├── install-command-center.sh  # 🟢 Entry Point: Tools Only
├── gz302-minimal.sh           # 🟢 Entry Point: Minimal Fixes
├── modules/                   # 📦 Optional feature packs (Gaming, AI, etc.)
├── scripts/                   # 🛠️ Standalone binaries & helpers (RGB, Restore)
├── gz302-lib/                 # 📚 Shared core libraries (Power, Display, Utils)
├── tray-icon/                 # 🖼️ Python/Qt6 GUI Application
└── docs/                      # 📄 Documentation & hardware research
```

---

## 🤝 Contributing & Support

*   **Documentation:** Check the [docs/](docs/) directory for detailed hardware research.
*   **Issues:** Please report bugs on the [Issues page](https://github.com/th3cavalry/GZ302-Linux-Setup/issues).
*   **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

**License:** MIT  
**Maintained by:** th3cavalry
