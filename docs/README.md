# GZ302 Documentation

Documentation for the ASUS ROG Flow Z13 (GZ302) Linux Setup project.

## Quick Links

| Document | Description |
|----------|-------------|
| [Kernel Support](kernel-support.md) | Kernel compatibility matrix, troubleshooting |
| [AI/ML Packages](ai-ml-packages.md) | ROCm, Ollama, PyTorch setup |
| [ROCm Support](rocm-support.md) | ROCm 7.1.1 configuration |
| [RGB Lightbar](rgb-lightbar.md) | Rear window RGB control |
| [Testing Guide](testing-guide.md) | How to test changes |
| [Changelog](CHANGELOG.md) | Version history |
| [Obsolescence Analysis](obsolescence-analysis.md) | Component lifecycle status |

## Hardware Specifications

**ASUS ROG Flow Z13 (GZ302EA-XS99)**
- **CPU:** AMD Ryzen AI MAX+ 395 (16 cores, 32 threads)
- **GPU:** AMD Radeon 8060S (RDNA 3.5, 40 CUs)
- **NPU:** AMD XDNA (50 TOPS)
- **RAM:** 128GB LPDDR5X (unified memory)
- **WiFi:** MediaTek MT7925e (Wi-Fi 7)
- **Display:** 13.4" 2.5K 180Hz OLED touchscreen

## Supported Distributions

| Distribution | Kernel | Support Level |
|--------------|--------|---------------|
| Arch Linux | 6.17+ | ✅ Full |
| CachyOS | 6.18+ | ✅ Full |
| Fedora 43 | 6.17+ | ✅ Full |
| OpenSUSE TW | 6.17+ | ✅ Full |
| Ubuntu 25.10 | 6.11+ | ⚠️ Upgrade HWE |

## Repository Structure

```
GZ302-Linux-Setup/
├── gz302-main.sh          # Main installer
├── gz302-minimal.sh       # Minimal hardware fixes
├── install-command-center.sh  # GUI tools installer
├── gz302-lib/             # Shared bash libraries
├── modules/               # Optional modules (gaming, AI)
├── scripts/               # Standalone tools & utilities
│   ├── gz302-rgb*         # RGB control scripts
│   └── uninstall/         # Cleanup scripts
├── tray-icon/             # Python/Qt6 system tray app
└── docs/                  # Documentation (you are here)
```

## Updating

To pull the latest fixes and apply them:

```bash
cd GZ302-Linux-Setup
git pull

# Re-run the relevant installer to apply updates:
sudo ./gz302-main.sh              # Hardware fixes
sudo ./install-command-center.sh  # Power/RGB tools
sudo ./scripts/gz302-rgb-install.sh  # RGB only
```

> [!NOTE]
> Some fixes (like suspend hooks) are installed to system paths and require re-running the installer to update.

## Getting Help

1. Check [Kernel Support](kernel-support.md) for compatibility issues
2. See [Testing Guide](testing-guide.md) for diagnostic commands
3. Open an issue: [GitHub Issues](https://github.com/th3cavalry/GZ302-Linux-Setup/issues)
