# Contributing to GZ302-Linux-Setup

Thank you for your interest in contributing to the GZ302 Linux Setup project! This guide will help you contribute effectively.

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

## 📝 Code Style Guidelines

### Bash Script Standards

1. **Always use `set -euo pipefail`** at the start of scripts
2. **Quote all variables** to prevent word splitting: `"$variable"`
3. **Quote command substitutions**: `"$(command)"`
4. **Use `-r` flag with `read`**: `read -r -p "prompt: " variable`
5. **Separate variable declarations**: 
   ```bash
   # Good
   local var
   var=$(command)
   
   # Avoid
   local var=$(command)  # Can mask return values
   ```

### Function Conventions

- Use descriptive function names with underscores: `install_arch_packages`
- Document complex functions with comments
- Return 0 for success, non-zero for errors
- Use `local` for function-scoped variables

### Output Messages

Use the helper functions consistently:
```bash
info "Informational message"
success "Success message"
warning "Warning message"
error "Error message (exits script)"
```

## 🧪 Testing Your Changes

### 1. Syntax Validation

**Required before committing:**
```bash
# Test individual script
bash -n gz302-main.sh

# Test all scripts
for script in gz302-*.sh; do
    bash -n "$script" && echo "✓ $script" || echo "✗ $script FAILED"
done
```

### 2. ShellCheck Linting

**Required before committing:**
```bash
# Lint individual script
shellcheck gz302-main.sh

# Lint all scripts
for script in gz302-*.sh; do
    echo "=== $script ==="
    shellcheck "$script"
done
```

**All scripts must pass with zero warnings.**

### 3. Distribution Testing

**Strongly recommended:**
Test your changes on all supported distributions:
- Arch Linux (or EndeavourOS, Manjaro)
- Ubuntu (or Pop!_OS, Linux Mint)
- Fedora (or Nobara)
- OpenSUSE Tumbleweed or Leap

You can use virtual machines or containers for testing.

## 🔀 Pull Request Process

1. **Fork the repository** and create a feature branch
2. **Make your changes** following the code style guidelines
3. **Test thoroughly**:
   - Run syntax validation: `bash -n script.sh`
   - Run shellcheck: `shellcheck script.sh`
   - Test on target hardware or VM if possible
4. **Commit with clear messages**:
   ```
   Add support for XYZ feature
   
   - Specific change 1
   - Specific change 2
   - Tested on: Arch Linux, Ubuntu 24.04
   ```
5. **Ensure equal distribution support**: If you add a feature, implement it for all 4 distributions
6. **Submit pull request** with:
   - Clear description of changes
   - Testing details (which distributions you tested)
   - Any known limitations or issues

## 📦 Module Development

When creating or modifying modules (`gz302-*.sh`):

1. **Follow the modular pattern**: Each module should be self-contained
2. **Include standard helpers**: Copy color codes and helper functions
3. **Support all distributions**: Implement for Arch, Debian, Fedora, OpenSUSE
4. **Add proper error handling**: Use `set -euo pipefail`
5. **Document usage**: Add comments explaining what the module does

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

When reporting bugs, please include:

1. **Distribution and version**: `cat /etc/os-release`
2. **Hardware info**: `lscpu`, `lspci` output
3. **Error messages**: Complete error output
4. **Steps to reproduce**: Exact commands you ran
5. **Expected vs actual behavior**: What should happen vs what happened

## 💡 Feature Requests

For new features:

1. **Check existing issues** to avoid duplicates
2. **Describe the use case**: Why is this feature needed?
3. **Hardware relevance**: Is it specific to GZ302 hardware?
4. **Distribution support**: Can it work on all 4 distributions?

## 📚 Documentation

When updating documentation:

1. **Keep README.md user-focused**: Installation and usage instructions
2. **Update version numbers** in both README.md and script headers
3. **Use clear examples**: Show actual commands users would run
4. **Maintain consistency**: Follow existing formatting and style

## ✅ Checklist Before Submitting

- [ ] Code passes `bash -n` syntax check
- [ ] Code passes `shellcheck` with zero warnings
- [ ] Changes tested on at least one supported distribution
- [ ] All 4 distributions have equivalent implementation
- [ ] Documentation updated if needed
- [ ] Commit messages are clear and descriptive
- [ ] No sensitive data (credentials, personal info) in commits

## 🤝 Code Review

All contributions go through code review:

- Maintainers will review for code quality, security, and compatibility
- Feedback will be provided constructively
- You may be asked to make changes before merging
- Be patient - reviews may take a few days

## 📞 Getting Help

- **Questions**: Open a GitHub issue with the "question" label
- **Discussion**: Use GitHub Discussions for general topics
- **Security issues**: Report privately to the maintainer

## 📜 License

By contributing, you agree that your contributions will be provided as-is for the GZ302 community, matching the project's license.

---

**Thank you for helping make GZ302 Linux Setup better!** 🎉
