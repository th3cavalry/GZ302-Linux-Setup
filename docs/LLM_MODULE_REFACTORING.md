# LLM Module Refactoring Plan

**Issue Reference:** GitHub Issue #141 Item 8  
**Date:** December 2025  
**Status:** Planned

## Current Implementation

The `gz302-llm.sh` module currently supports:
- **Ollama** - Built from source with gfx1100 target for Strix Halo (gfx1151) compatibility
- **llama.cpp** - Built from source with HIP/ROCm support
- **Open WebUI** - Docker-based frontend (auto-detects Ollama/llama.cpp)
- **Python AI libraries** - PyTorch with ROCm, transformers, accelerate, bitsandbytes

### Issues with Current Approach
1. Builds from source instead of using official installation methods
2. Limited to Ollama and llama.cpp
3. Custom ROCm environment configuration
4. Long build times (5-10 minutes per component)

## Requested Changes

Replace current implementation with:

### 1. Backend Options (Selectable)

| Backend | Official Install Method | Default Path |
|---------|------------------------|--------------|
| **Ollama** | `curl -fsSL https://ollama.com/install.sh \| sh` | `/usr/share/ollama`, `~/.ollama` |
| **llama.cpp** | Release binary or CMake build | `/usr/local/bin/llama-*` |
| **LM Studio** | AppImage or .deb from lmstudio.ai | `~/LMStudio` or `/opt/lmstudio` |
| **vLLM** | `pip install vllm` | Python venv |

### 2. Installation Philosophy

- **Use official documentation methods** - No custom builds unless necessary
- **Default paths only** - No custom installation paths for easier troubleshooting
- **Minimal configuration** - Let users customize after install
- **ROCm compatibility** - Configure HSA_OVERRIDE_GFX_VERSION for Strix Halo

### 3. Recommended GUIs

| Backend | Recommended UI |
|---------|---------------|
| Ollama | Open WebUI (Docker) |
| llama.cpp | Built-in web server |
| LM Studio | Built-in UI (Electron) |
| vLLM | FastAPI server + any OpenAI-compatible UI |

## Implementation Plan

### Phase 1: Refactor Selection Menu
```bash
ask_llm_backend_choice() {
    echo "Select LLM backend(s) to install:"
    echo "  1) Ollama          - Easiest, great model management"
    echo "  2) llama.cpp       - Fast inference, lightweight"
    echo "  3) LM Studio       - GUI-first, user-friendly"
    echo "  4) vLLM            - Production-grade, OpenAI-compatible"
    echo "  5) All backends"
    read -p "Choice (1-5): " choice
}
```

### Phase 2: Ollama (Official Method)
```bash
install_ollama() {
    # Official install script
    curl -fsSL https://ollama.com/install.sh | sh
    
    # Strix Halo optimization via systemd override
    mkdir -p /etc/systemd/system/ollama.service.d
    cat > /etc/systemd/system/ollama.service.d/gz302.conf << 'EOF'
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="HIP_VISIBLE_DEVICES=0"
EOF
    
    systemctl daemon-reload
    systemctl enable --now ollama
}
```

### Phase 3: llama.cpp (Release Binaries)
```bash
install_llamacpp() {
    # Get latest release with ROCm support
    local version=$(curl -s https://api.github.com/repos/ggerganov/llama.cpp/releases/latest | jq -r .tag_name)
    local url="https://github.com/ggerganov/llama.cpp/releases/download/${version}/llama-${version}-bin-linux-x64-rocm.zip"
    
    curl -L "$url" -o /tmp/llama.zip
    unzip /tmp/llama.zip -d /usr/local/bin/
}
```

### Phase 4: LM Studio
```bash
install_lmstudio() {
    # Download AppImage from official site
    local url="https://releases.lmstudio.ai/linux/x64/latest"
    curl -L "$url" -o ~/LMStudio.AppImage
    chmod +x ~/LMStudio.AppImage
    
    # Create desktop entry
    cat > ~/.local/share/applications/lmstudio.desktop << 'EOF'
[Desktop Entry]
Name=LM Studio
Exec=$HOME/LMStudio.AppImage
Type=Application
Categories=Utility;Development;
EOF
}
```

### Phase 5: vLLM
```bash
install_vllm() {
    # Create virtual environment
    python3 -m venv /var/lib/gz302-vllm
    
    # Install vLLM with ROCm support
    source /var/lib/gz302-vllm/bin/activate
    pip install vllm
    
    # ROCm environment
    export HSA_OVERRIDE_GFX_VERSION=11.0.0
    
    # Test installation
    vllm --version
}
```

### Phase 6: Open WebUI (Universal Frontend)
```bash
install_openwebui() {
    # Always install Open WebUI as universal frontend
    docker run -d \
        -p 3000:8080 \
        --add-host=host.docker.internal:host-gateway \
        -v open-webui:/app/backend/data \
        --name open-webui \
        --restart always \
        ghcr.io/open-webui/open-webui:main
}
```

## ROCm/AMD GPU Configuration

All backends need Strix Halo (gfx1151) configuration:

```bash
# Environment variables for AMD ROCm compatibility
export HSA_OVERRIDE_GFX_VERSION=11.0.0  # Treat gfx1151 as gfx1100
export HIP_VISIBLE_DEVICES=0             # Use primary GPU
export GPU_MAX_HW_QUEUES=8               # Parallelism
export AMD_SERIALIZE_KERNEL=0            # Async performance
export AMD_SERIALIZE_COPY=0              # Async copy
```

## Files to Modify

1. `gz302-llm.sh` - Complete refactoring
2. `Info/AI_ML_PACKAGES.md` - Update documentation
3. `README.md` - Update LLM section
4. `.github/copilot-instructions.md` - Add LLM architecture notes

## Testing Matrix

| Backend | Arch | Debian | Fedora | OpenSUSE |
|---------|------|--------|--------|----------|
| Ollama | ✓ | ✓ | ✓ | ✓ |
| llama.cpp | ✓ | ✓ | ✓ | ✓ |
| LM Studio | ✓ | ✓ | ✓ | ✓ |
| vLLM | ✓ | ✓ | ✓ | ✓ |
| Open WebUI | ✓ | ✓ | ✓ | ✓ |

## Timeline Estimate

- Phase 1 (Menu): 1 hour
- Phase 2 (Ollama): 2 hours (simplify existing)
- Phase 3 (llama.cpp): 2 hours (release binaries vs source)
- Phase 4 (LM Studio): 1 hour (new)
- Phase 5 (vLLM): 3 hours (new, complex)
- Phase 6 (Open WebUI): 1 hour (existing)
- Testing: 4 hours

**Total: ~14 hours of work**

## Notes

- LM Studio is closed-source but provides excellent UX
- vLLM is more complex but offers production-grade features
- Keep source build option as fallback for custom requirements
- ROCm 6.2+ recommended for best Strix Halo support
