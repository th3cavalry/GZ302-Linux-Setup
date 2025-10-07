# Legacy Files - DO NOT USE

⚠️ **WARNING: These files are obsolete and should NOT be used.** ⚠️

## What's in this directory?

This directory contains **legacy files** from the old monolithic architecture (version 4.x series). These files are preserved for reference only.

### Legacy Files:
- **gz302_setup.sh** (version 4.3.2) - Old monolithic bash script
- **gz302_setup.py** (version 4.3.2) - Old Python implementation  
- **requirements.txt** - Python dependencies (no longer needed)
- **PYTHON_CONVERSION.md** - Old feature parity documentation
- **VERSION_INCREMENT_GUIDE.md** - Old version management guide

## Current Version (0.1.x)

The current implementation uses a **modular architecture** with:
- **Bash-only implementation** (no Python dependencies)
- **Lightweight main script** (gz302-main.sh) for core hardware fixes
- **Optional modules** downloaded on demand:
  - gz302-gaming.sh
  - gz302-llm.sh
  - gz302-hypervisor.sh
  - gz302-snapshots.sh
  - gz302-secureboot.sh

## Why the change?

The old monolithic approach (4.x) had several issues:
1. **Large file size** - Single script >1400 lines
2. **Python dependency** - Required Python installation
3. **Harder to maintain** - All features in one file
4. **Slower setup** - Had to install everything at once

The new modular approach (0.1.x) provides:
1. **Smaller downloads** - Only get what you need
2. **Faster setup** - Core fixes complete in minutes
3. **Easy maintenance** - Update modules independently
4. **Bash-only** - No external language dependencies
5. **Better flexibility** - Install optional software anytime

## Migration Guide

If you're using the old scripts (4.x), please migrate to the new modular system:

```bash
# Download the new main script
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-main.sh -o gz302-main.sh
chmod +x gz302-main.sh

# Run with sudo
sudo ./gz302-main.sh
```

The new script will:
1. Apply all the same hardware fixes as before
2. Offer to download optional software modules
3. Complete setup much faster

---

**For current documentation, please see the main [README.md](../README.md) in the repository root.**
