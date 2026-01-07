# GZ302 Linux Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-ASUS%20ROG%20Flow%20Z13-blue)](https://asus-linux.org)

**The ultimate Linux optimization suite for the ASUS ROG Flow Z13 (GZ302).**

Transform your device into a powerhouse with kernel-aware hardware fixes, intelligent power management, and a dedicated Command Center. This toolkit uses a **Library-First Architecture**.

---

## 📥 Installation

**One script to rule them all.**

```bash
# Download the installer
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/install.sh -o install.sh
chmod +x install.sh

# Run the setup
sudo ./install.sh --full      # Recommended: Full setup (Fixes + Command Center + GUI)
sudo ./install.sh --cc        # Command Center only (No kernel patches)
sudo ./install.sh --minimal   # Fixes only (Server/Purist mode)
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

```
GZ302-Linux-Setup/
├── install.sh              # 🟢 Unified Entry Point
├── modules/                # 📦 Feature packs (Gaming, AI, etc.)
├── scripts/                # 🛠️ Standalone binaries
│   └── uninstall/          # 🗑️ Cleanup scripts
├── gz302-lib/              # 📚 Shared core libraries
├── tray-icon/              # 🖼️ Python/Qt6 GUI Application
└── docs/                   # 📄 Hardware research & documentation
```

---

## 🤝 Contributing

See CONTRIBUTING.md. For hardware research, check the docs/ directory.
