# Archived Files

This directory contains files from previous versions of the GZ302 Linux Setup project that are no longer actively maintained but kept for reference.

## Contents

### Legacy Monolithic Scripts (v4.3.1)

- **gz302_setup.sh** (~3,260 lines) - Original bash implementation
- **gz302_setup.py** (~2,900 lines) - Python alternative implementation
- **requirements.txt** - Python dependencies (stdlib only)

These scripts combined all hardware fixes and software installation into a single monolithic file. They have been replaced by the modular architecture (v0.1.x).

### Legacy Documentation

- **README.md** - Documentation for v4.3.1
- **VERSION_INCREMENT_GUIDE.md** - Version management for legacy scripts
- **PYTHON_CONVERSION.md** - Feature parity documentation between bash and Python

## Why These Files Are Archived

The project underwent a major architectural redesign in version 0.1.0:

1. **Modular Design**: Split into core hardware fixes (gz302-main.sh) and optional software modules
2. **Bash-Only**: Removed Python dependency for simpler deployment
3. **On-Demand Downloads**: Modules are downloaded only when needed
4. **Smaller Footprint**: Main script is ~2,200 lines vs ~3,200 lines
5. **Better Maintainability**: Easier to update individual components

## Current Version

The current version (0.1.1-pre-release) uses:
- **gz302-main.sh** - Core hardware fixes and management tools
- **gz302-gaming.sh** - Gaming software module
- **gz302-llm.sh** - AI/LLM software module
- **gz302-hypervisor.sh** - Virtualization module
- **gz302-snapshots.sh** - System snapshots module
- **gz302-secureboot.sh** - Secure boot module

See the main README.md in the repository root for current documentation.

## Using Legacy Scripts

⚠️ **Not Recommended**: These scripts are no longer maintained and may not work with current distributions or hardware configurations.

If you need to use them for some reason:

```bash
# Bash version
cd Old/
chmod +x gz302_setup.sh
sudo ./gz302_setup.sh

# Python version (requires Python 3.6+)
cd Old/
chmod +x gz302_setup.py
sudo ./gz302_setup.py
```

## Migration

If you're using the legacy scripts and want to migrate to the modular architecture:

1. **Backup your current setup**: Document what software you've installed
2. **Use the new main script**: Follow instructions in the main README.md
3. **Install needed modules**: The script will offer optional modules during setup
4. **Verify functionality**: Test TDP management, refresh rate control, and hardware fixes

---

**Last Updated**: October 2024  
**Archived Version**: 4.3.1  
**Current Version**: 0.1.1-pre-release
