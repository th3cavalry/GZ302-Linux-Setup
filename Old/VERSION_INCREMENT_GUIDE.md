# Version Increment Guide for GZ302-Linux-Setup

## Version Format: MAJOR.MINOR.PATCH

Current Version: **4.3.1**

## Increment Rules

### Third Digit (PATCH) - Bug Fixes
Increment when making bug fixes, corrections, or minor improvements that don't add new functionality.

**Examples:**
- 4.3.0 → 4.3.1: Fix typos in function names
- 4.3.1 → 4.3.2: Correct package installation errors
- 4.3.2 → 4.3.3: Sync Python/Bash implementations

**Command to update:**
```bash
# Update both scripts
sed -i 's/Version: 4.3.1/Version: 4.3.2/' gz302_setup.sh gz302_setup.py
```

### Second Digit (MINOR) - New Features
Increment when adding new functionality, features, or capabilities.

**Examples:**
- 4.3.1 → 4.4.0: Add new hypervisor support
- 4.4.0 → 4.5.0: Add new hardware management features
- 4.5.0 → 4.6.0: Add new distribution support

**Command to update:**
```bash
# Update both scripts  
sed -i 's/Version: 4.5.1/Version: 4.6.0/' gz302_setup.sh gz302_setup.py
```

### First Digit (MAJOR) - Breaking Changes
Increment when making breaking changes or major architectural updates.

**Examples:**
- 4.6.5 → 5.0.0: Complete rewrite
- 5.0.0 → 6.0.0: Change script interface/API

## Version Sync Requirement

**IMPORTANT:** Both `gz302_setup.sh` and `gz302_setup.py` must always have the same version number.

### Version Locations:
- **Bash**: Line 7: `# Version: X.Y.Z`
- **Python**: Line 7: `Version: X.Y.Z`

### Verification:
```bash
# Check current versions
grep "Version:" gz302_setup.sh | head -1
grep "Version:" gz302_setup.py | head -1
```

## Change Log Format

When incrementing version, update commit message with:
```
Version X.Y.Z - Brief description

- Change 1
- Change 2
- Change 3
```

## Quick Reference

| Change Type | Increment | Example | 
|-------------|-----------|---------|
| Bug fix | PATCH (third) | 4.3.1 → 4.3.2 |
| New feature | MINOR (second) | 4.3.2 → 4.4.0 |
| Breaking change | MAJOR (first) | 4.6.5 → 5.0.0 |

---

*Last updated: Version 4.3.1*
