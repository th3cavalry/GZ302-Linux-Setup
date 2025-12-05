---
applyTo: '**'
---

# Memory

This file stores information about user preferences and context for personalized assistance.

## Current Context
- Repository: GZ302-Linux-Setup
- Focus: Hardware-specific Linux setup scripts for ASUS ROG Flow Z13 (GZ302EA-XS99)
- Architecture: Modular bash-only implementation (version 0.2.0-RC1)

## User Preferences

### Shell Environment
- **Default shell**: fish
- **Important**: Fish does NOT support heredocs (`<< EOF` syntax)
- **Alternative methods**: Use `printf` or `echo` with pipes for multi-line content
- **Example**: `printf 'line1\nline2\n' | sudo tee /path/to/file`
