# GZ302 AI/ML Package Support - November 2025

**Date**: November 7, 2025  
**Version**: 0.3.0  
**Focus**: ROCm, PyTorch, MIOpen, and bitsandbytes support for AMD Radeon 8060S (gfx1151)

---

## Executive Summary

This document details the current state of AI/ML package support for the ASUS ROG Flow Z13 (GZ302EA) with AMD Radeon 8060S integrated graphics (gfx1151 architecture). The GZ302 setup script now includes comprehensive AI/ML support through the `gz302-llm.sh` module, which installs:

- **Ollama**: Local LLM server
- **ROCm**: AMD GPU acceleration framework
- **PyTorch**: Deep learning framework with ROCm backend
- **MIOpen**: AMD's deep learning primitives library
- **bitsandbytes**: 8-bit quantization for efficient LLM inference
- **Transformers & Accelerate**: Hugging Face ecosystem tools

---

## Hardware Context

### AMD Radeon 8060S Specifications
- **Architecture**: RDNA 3.5 (gfx1151)
- **Compute Units**: Integrated within Ryzen AI MAX+ 395
- **Memory**: Unified system memory (32GB-128GB configurations)
- **ROCm Target**: gfx1151 (Strix Halo)

### ROCm Compatibility Status (November 2025)

**ROCm Version Support**:
- **ROCm 6.4+**: Initial preview support for gfx1151
- **ROCm 7.x**: Improved support with better stability
- **Status**: Preview/Early support - not yet production-grade for all features

**Key Points**:
- Linux support is ahead of Windows
- WSL2 support is not yet functional (CPU-only)
- Some features require custom builds or workarounds
- Community support is active and improving

---

## Package Installation Details

### 1. ROCm Base Packages

**Arch Linux**:
```bash
pacman -S rocm-opencl-runtime rocm-hip-runtime rocblas miopen-hip
```

**Ubuntu/Debian**:
```bash
apt install rocm-opencl-runtime rocblas miopen-hip
# May require adding AMD ROCm repository
```

**Fedora**:
```bash
dnf install rocm-opencl rocblas miopen-hip
# May require EPEL or AMD ROCm repository
```

**OpenSUSE**:
```bash
zypper install rocm-opencl rocblas miopen-hip
# May require OBS repositories
```

### 2. MIOpen (Deep Learning Primitives)

**What is MIOpen?**
MIOpen is AMD's library for high-performance deep learning primitives, similar to NVIDIA's cuDNN. It provides optimized implementations of:
- Convolutions
- Batch normalization
- Activation functions
- Pooling operations

**Installation**:
- Installed via `miopen-hip` package on supported distributions
- Precompiled kernels for gfx1151 may not be available in all repositories
- JIT (Just-In-Time) compilation will occur on first use if precompiled kernels are unavailable

**Performance Considerations**:
- First run may be slower due to kernel compilation
- Compiled kernels are cached for future use
- Shared memory architecture benefits unified memory access patterns

### 3. PyTorch with ROCm

**Current Installation Method**:
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
```

**Compatibility Notes**:
- ROCm 5.7 wheels are used for maximum compatibility
- Python 3.10 recommended (best compatibility)
- Python 3.12/3.13 may require conda/miniforge fallback
- ROCm 6.x+ wheels are becoming available but may have limited gfx1151 support

**Fallback Strategy** (implemented in gz302-llm.sh):
1. Try pip installation in venv
2. If import fails, install Miniforge
3. Create conda environment with Python 3.10
4. Install PyTorch in conda environment
5. Verify import success

### 4. bitsandbytes (8-bit Quantization)

**What is bitsandbytes?**
bitsandbytes provides:
- 8-bit and 4-bit quantization for LLMs
- Reduced memory footprint (critical for local inference)
- Quantized optimizers for training
- ROCm backend support (in development)

**Installation Strategy**:
```bash
# Try standard installation first
pip install bitsandbytes

# If that fails, use ROCm-specific wheel
pip install --no-deps --force-reinstall \
  'https://github.com/bitsandbytes-foundation/bitsandbytes/releases/download/continuous-release_multi-backend-refactor/bitsandbytes-0.44.1.dev0-py3-none-manylinux_2_24_x86_64.whl'
```

**Current Status for gfx1151**:
- ROCm support is in active development
- Multi-backend refactor branch provides best compatibility
- Some features may require building from source
- Tested primarily on MI210/MI250/MI300 series (datacenter GPUs)
- Radeon 8060S support is experimental

**Build from Source** (if needed):
```bash
git clone --recurse-submodules https://github.com/ROCm/bitsandbytes
cd bitsandbytes
git checkout rocm_enabled
cmake -DCOMPUTE_BACKEND=hip -DBNB_ROCM_ARCH="gfx1151" -S .
make
pip install .
```

---

## Distribution-Specific Implementation

### CachyOS (Recommended for Maximum Performance)

**Why CachyOS for AI/ML workloads:**
- Packages compiled with **znver4 optimizations** (Zen 4/5 specific)
- **5-20% performance improvement** over generic x86-64 packages
- **LTO/PGO optimizations** on core packages
- **BORE scheduler** in linux-cachyos kernel for better interactive response

**Optimized AI/ML Packages:**

| Package | Description |
|---------|-------------|
| `ollama-rocm` | Ollama with ROCm support for AMD GPUs |
| `python-pytorch-opt-rocm` | PyTorch with ROCm + AVX2 optimizations |
| `rocm-ml-sdk` | Full ROCm ML development stack |
| `rocm-hip-runtime` | HIP runtime (znver4 compiled) |
| `miopen-hip` | AMD deep learning primitives |

**Installation:**
```bash
# Install Ollama with ROCm (automatic GPU detection)
sudo pacman -S ollama-rocm

# Install optimized PyTorch
sudo pacman -S python-pytorch-opt-rocm

# Install Open WebUI (from AUR)
yay -S open-webui  # or paru -S open-webui

# Full ROCm ML stack (optional, for custom development)
sudo pacman -S rocm-ml-sdk
```

**Verify Installation:**
```bash
# Start Ollama service
sudo systemctl enable --now ollama
ollama pull llama3.2

# Verify PyTorch ROCm
python -c 'import torch; print(f"ROCm: {torch.cuda.is_available()}, Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}")'
```

**Reference:** https://wiki.cachyos.org/features/optimized_repos/

### Arch Linux
**Advantages**:
- Latest ROCm packages in repositories
- AUR provides additional packages
- Rolling release ensures up-to-date support

**Packages**:
- `rocm-opencl-runtime`, `rocm-hip-runtime`, `rocblas`, `miopen-hip`
- MIOpen gfx1151 kernels may be available via AUR

### Ubuntu/Debian
**Considerations**:
- May require adding AMD ROCm official repository
- Ubuntu 24.04 is recommended base
- HWE kernel (6.14+) recommended

**Repository Setup**:
```bash
wget https://repo.radeon.com/amdgpu-install/7.1/ubuntu/noble/amdgpu-install_7.1.70100-1_all.deb
sudo apt install ./amdgpu-install_7.1.70100-1_all.deb
sudo apt update
```

### Fedora
**Considerations**:
- ROCm packages may be in EPEL
- Latest Fedora versions have better support
- COPR repositories may provide additional packages

### OpenSUSE
**Considerations**:
- OBS (Open Build Service) provides ROCm packages
- Tumbleweed recommended for latest packages
- May require manual repository addition

---

## Known Limitations and Workarounds

### 1. Limited gfx1151 Support
**Issue**: ROCm support for gfx1151 is in preview stage  
**Workaround**: 
- Use ROCm 6.4+ or newer
- Monitor AMD ROCm GitHub for updates
- Community patches may be needed for some features

### 2. Python Version Compatibility
**Issue**: ROCm wheels may not be available for Python 3.12+  
**Workaround**: 
- Use Python 3.10 via conda/miniforge
- Script automatically falls back to conda if needed

### 3. MIOpen Kernel Compilation
**Issue**: First run may be slow due to kernel JIT compilation  
**Workaround**: 
- Install precompiled kernels if available
- Accept slower first run (kernels are cached)
- Monitor AMD repositories for gfx1151 kernel packages

### 4. bitsandbytes ROCm Support
**Issue**: ROCm backend is experimental for consumer GPUs  
**Workaround**: 
- Use development wheels from GitHub releases
- Build from source if needed
- Test quantization before production use

### 5. Multi-GPU Systems
**Issue**: Some systems may hang with default IOMMU settings  
**Workaround**: 
- Add `iommu=pt` to kernel boot parameters
- Not applicable to GZ302 (single integrated GPU)

---

## Performance Expectations

### Memory Bandwidth
- **Advantage**: Unified memory architecture provides excellent bandwidth
- **Large Models**: 128GB configurations can run larger models than discrete GPUs
- **Access Patterns**: Optimized for unified memory access

### Compute Performance
- **vs Discrete GPUs**: ~70-80% of RTX 4070 Laptop in some workloads
- **AI Inference**: Strong performance for local LLM inference
- **Training**: Capable but slower than high-end discrete GPUs
- **Quantization**: 8-bit quantization significantly improves throughput

### First Run Considerations
- Kernel compilation may take 5-15 minutes on first PyTorch/MIOpen use
- Subsequent runs use cached kernels
- Plan for initialization time in production workflows

---

## Testing and Validation

### Verification Commands

**Check ROCm Installation**:
```bash
rocminfo
# Should show gfx1151 device

/opt/rocm/bin/rocm-smi
# Should show GPU information
```

**Test PyTorch ROCm**:
```bash
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
# Should show True and device name
```

**Test bitsandbytes**:
```bash
python -m bitsandbytes
# Should run without errors
```

**Test MIOpen**:
```bash
# Run a simple PyTorch CNN model
# First run will compile kernels
```

---

## Recommendations

### For New Installations
1. **Use Arch Linux or Fedora 42+** for best out-of-box ROCm support
2. **Install kernel 6.17+** for optimal AMD Strix Halo support
3. **Use Python 3.10** via conda for best compatibility
4. **Expect first-run delays** for kernel compilation
5. **Monitor AMD ROCm releases** for gfx1151 improvements

### For Existing Systems
1. **Update to latest ROCm** (6.4+ minimum, 7.x preferred)
2. **Use conda environment** for Python package isolation
3. **Test quantization thoroughly** before production use
4. **Keep PyTorch and ROCm versions aligned**

### For Development Workflows
1. **Use virtual environments** for package isolation
2. **Cache compiled kernels** in persistent storage
3. **Monitor memory usage** (unified memory shared with system)
4. **Test on representative models** before scaling up

---

## Future Outlook

### Expected Improvements
- **ROCm 7.x+**: Better gfx1151 support and stability
- **PyTorch 2.8+**: Improved ROCm backend integration
- **bitsandbytes**: Matured ROCm support for consumer GPUs
- **Vendor Support**: AMD increasing focus on AI/ML for consumer products

### Community Development
- Active development in ROCm GitHub repositories
- Community patches for early gfx1151 support
- Growing ecosystem for AMD AI/ML tools

---

## References

### Official Documentation
- [AMD ROCm Documentation](https://rocm.docs.amd.com/)
- [MIOpen Documentation](https://rocm.docs.amd.com/projects/MIOpen/)
- [ROCm Compatibility Matrix](https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html)
- [PyTorch ROCm Support](https://pytorch.org/get-started/locally/)

### Community Resources
- [ROCm GitHub Issues](https://github.com/ROCm/ROCm/issues)
- [bitsandbytes ROCm Branch](https://github.com/ROCm/bitsandbytes)
- [gfx1151 Support Discussions](https://github.com/ROCm/ROCm/issues/4499)

### Real-World Testing
- [YOLOv8 Training on Ryzen AI MAX+ 395](https://tinycomputers.io/posts/getting-yolov8-training-working-on-amd-ryzentm-al-max%2B-395.html)
- [AMD AI Max+ 395 System Review](https://tinycomputers.io/posts/amd-ai-max%2B-395-system-review-a-comprehensive-analysis.html)

---

## Summary

The GZ302 now has comprehensive AI/ML support through the updated `gz302-llm.sh` module. While ROCm support for gfx1151 is in preview stage, the installation includes:

✅ **Ollama** - Local LLM server  
✅ **ROCm** - AMD GPU acceleration  
✅ **PyTorch** - Deep learning framework  
✅ **MIOpen** - Optimized deep learning primitives  
✅ **bitsandbytes** - 8-bit quantization (experimental)  
✅ **Transformers** - Hugging Face ecosystem  

**Users should expect**:
- Preview-quality support (not production-ready for all features)
- First-run kernel compilation delays
- Need for conda fallback on newer Python versions
- Active community development and improvements

**Best experience**:
- Arch Linux or Fedora 42+
- Kernel 6.17+
- Python 3.10 via conda
- ROCm 6.4+ or newer

---

**Document Version**: 1.0  
**Created**: November 7, 2025  
**Maintainer**: th3cavalry  
**License**: Same as parent repository
