# Contributing to GZ302-Linux-Setup

## 🎯 Project Goals

- **Hardware-specific**: Focused on ASUS ROG Flow Z13 (GZ302EA-XS99) with AMD Ryzen AI MAX+ 395
- **Equal distribution support**: Arch, Debian/Ubuntu, Fedora, and OpenSUSE receive identical treatment
- **Modular design**: Core hardware fixes separated from optional software modules
- **Quality focus**: Clean, maintainable bash scripts with proper error handling

## 🛠️ Development Setup

### Prerequisites

- A Linux system (preferably with one of the supported distributions)
- `bash` 4.0 or higher
- `shellcheck` for linting (recommended)
- `git` for version control

### Installing ShellCheck

```bash
# Arch-based
sudo pacman -S shellcheck

# Debian/Ubuntu-based
sudo apt install shellcheck

# Fedora-based
sudo dnf install ShellCheck

# OpenSUSE
sudo zypper install ShellCheck
```

## 📝 Code Standards

### Bash Scripts

1. Start with `set -euo pipefail`
2. Quote variables: `"$variable"`
3. Quote command substitutions: `"$(command)"`
4. Use `read -r` for input
5. Separate variable declarations:
   ```bash
   local var
   var=$(command)
   ```

### Functions & Output

- Use descriptive names: `install_arch_packages`
- Return 0 for success, non-zero for errors
- Use `local` for function scope
- Use helper functions: `info`, `success`, `warning`, `error`

## 🧪 Testing

### Required Before Commit

```bash
# Syntax validation
bash -n gz302-main.sh

# ShellCheck (must pass with zero warnings)
shellcheck gz302-main.sh
```

### Distribution Testing (Recommended)

Test on all supported distributions:
- Arch Linux / Manjaro / EndeavourOS
- Ubuntu / Pop!_OS / Linux Mint
- Fedora / Nobara
- OpenSUSE Tumbleweed / Leap

## 🔀 Pull Request Process

1. Fork and create feature branch
2. Make changes following code standards
3. Test: syntax validation and shellcheck
4. Commit with clear messages (include tested distros)
5. Ensure equal distribution support (all 4 distros)
6. Submit PR with description and testing details

## 📦 Module Development

Requirements for modules (`gz302-*.sh`):

1. Self-contained modular design
2. Include standard helper functions
3. Support all 4 distributions
4. Use `set -euo pipefail`
5. Document purpose in comments

### Module Template

```bash
#!/bin/bash

# ==============================================================================
# GZ302 [Module Name] Module
#
# Description of what this module does
# ==============================================================================

set -euo pipefail

# Color codes
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

# Helper functions
info() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}[WARNING]${C_NC} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_NC} $1"; exit 1; }

# Main installation function
install_module() {
    local distro="$1"
    
    case "$distro" in
        "arch") install_arch ;;
        "debian") install_debian ;;
        "fedora") install_fedora ;;
        "opensuse") install_opensuse ;;
        *) error "Unsupported distribution: $distro" ;;
    esac
}

# Distribution-specific functions
install_arch() {
    info "Installing for Arch-based system..."
    # Implementation
}

install_debian() {
    info "Installing for Debian-based system..."
    # Implementation
}

install_fedora() {
    info "Installing for Fedora-based system..."
    # Implementation
}

install_opensuse() {
    info "Installing for OpenSUSE..."
    # Implementation
}

# Entry point
if [[ $# -ne 1 ]]; then
    error "Usage: $0 <distro>"
fi

install_module "$1"
```

## 🐛 Bug Reports

Include:
1. Distribution and version (`cat /etc/os-release`)
2. Hardware info (`lscpu`, `lspci`)
3. Complete error messages
4. Steps to reproduce
5. Expected vs actual behavior

## 💡 Feature Requests

Include:
1. Use case and rationale
2. GZ302 hardware relevance
3. Multi-distribution feasibility

## 📚 Documentation

Guidelines:
1. Keep README.md user-focused
2. Update version numbers
3. Use clear command examples
4. Maintain consistency

## ✅ Pre-Submit Checklist

- [ ] `bash -n` passes
- [ ] `shellcheck` passes with zero warnings
- [ ] Tested on at least one distribution
- [ ] All 4 distributions supported
- [ ] Documentation updated
- [ ] Clear commit messages
- [ ] No sensitive data in commits

## 📞 Help & Support

- Questions: GitHub issues
- Discussion: GitHub Discussions
- Security: Report privately to maintainer

---

**License**: Contributions are provided as-is, matching project license (MIT).
