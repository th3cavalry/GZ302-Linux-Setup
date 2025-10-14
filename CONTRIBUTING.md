# Contributing to GZ302 Linux Setup

Thank you for your interest in improving Linux support for the Asus ROG Flow Z13 2025! This guide will help you contribute to this project.

## Table of Contents

- [How Can I Contribute?](#how-can-i-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Code Contributions](#code-contributions)
- [Testing](#testing)
- [Documentation](#documentation)

## How Can I Contribute?

There are many ways to contribute:

1. **Report bugs** - Found an issue? Let us know!
2. **Test the script** - Try it on your GZ302EA and report results
3. **Improve documentation** - Help make our docs clearer
4. **Add distribution support** - Help us support more Linux distributions
5. **Submit fixes** - Fix bugs or improve the script
6. **Share your configuration** - Help others with your working setup

## Reporting Bugs

### Before Submitting a Bug Report

1. **Check existing issues** - Your bug might already be reported
2. **Test with latest version** - Make sure you're using the latest script
3. **Check troubleshooting guide** - See if there's a known solution
4. **Gather information** - Collect logs and system details

### How to Submit a Bug Report

Create an issue on GitHub with the following information:

**Required Information:**
```markdown
## System Information
- **Model**: GZ302EA-XS99 / XS64 / XS32
- **Distribution**: (e.g., Ubuntu 25.04, Arch Linux, Fedora 42)
- **Kernel Version**: (output of `uname -r`)
- **Script Version**: (check top of gz302-setup.sh)

## Description
Clear description of the issue

## Steps to Reproduce
1. Run the script with: `sudo ./gz302-setup.sh`
2. Select option X
3. Error occurs

## Expected Behavior
What you expected to happen

## Actual Behavior
What actually happened

## Logs
```
Paste relevant logs here (dmesg, journalctl, script output)
```

## Additional Context
Any other information that might be relevant
```

## Suggesting Enhancements

We welcome suggestions for improvements! When suggesting an enhancement:

1. **Check existing issues** - It might already be suggested
2. **Be specific** - Clearly describe what you want and why
3. **Provide examples** - Show how it would work
4. **Consider impact** - Think about who would benefit

### Enhancement Template

```markdown
## Enhancement Description
Clear description of the enhancement

## Motivation
Why is this enhancement needed? What problem does it solve?

## Proposed Solution
How would you implement this?

## Alternatives Considered
What other solutions did you consider?

## Additional Context
Any other information
```

## Code Contributions

### Development Setup

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/GZ302-Linux-Setup.git
   cd GZ302-Linux-Setup
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

3. **Make your changes**
   - Follow the coding style (see below)
   - Test thoroughly
   - Update documentation if needed

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

5. **Push and create Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a Pull Request on GitHub

### Coding Style

Follow these guidelines when contributing code:

#### Shell Script Style

1. **Use bash shebang:**
   ```bash
   #!/bin/bash
   ```

2. **Use `set -e`** to exit on errors

3. **Use functions** for reusable code:
   ```bash
   my_function() {
       local var="value"
       # function code
   }
   ```

4. **Quote variables:**
   ```bash
   echo "$variable"      # Good
   echo $variable        # Avoid
   ```

5. **Use meaningful names:**
   ```bash
   install_package()     # Good
   ip()                  # Avoid (too short)
   ```

6. **Add comments** for complex sections:
   ```bash
   # Check if running on supported distribution
   if [ "$DISTRO_FAMILY" = "arch" ]; then
       # Implementation
   fi
   ```

7. **Error handling:**
   ```bash
   if ! command; then
       print_error "Command failed"
       return 1
   fi
   ```

8. **Use consistent indentation** (4 spaces)

#### Documentation Style

1. **Use Markdown** for all documentation
2. **Keep lines under 80 characters** when possible
3. **Use code blocks** for commands and code
4. **Include examples** where helpful
5. **Update TOC** if you add sections

### Pull Request Process

1. **Ensure your PR:**
   - Has a clear description
   - References any related issues
   - Includes tests if applicable
   - Updates documentation if needed
   - Follows the coding style

2. **PR Description Template:**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Related Issues
   Fixes #123, Related to #456
   
   ## Changes Made
   - Added feature X
   - Fixed bug Y
   - Updated documentation Z
   
   ## Testing
   - Tested on: Ubuntu 25.04, Arch Linux
   - Test procedure: ...
   - Results: ...
   
   ## Screenshots (if applicable)
   [Add screenshots]
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] Tested on at least one distribution
   ```

3. **Review Process:**
   - Maintainers will review your PR
   - Address any requested changes
   - Once approved, it will be merged

## Testing

### Testing the Script

When testing changes:

1. **Test on multiple distributions** if possible:
   - Arch-based (Arch, Manjaro, etc.)
   - Debian-based (Ubuntu, Debian, etc.)
   - Fedora
   - At least one other

2. **Test different modes:**
   ```bash
   sudo ./gz302-setup.sh                    # Interactive
   sudo ./gz302-setup.sh --auto --full      # Automatic full
   sudo ./gz302-setup.sh --minimal          # Minimal install
   ```

3. **Check for errors:**
   - Watch for error messages
   - Check logs: `dmesg`, `journalctl`
   - Verify features work after reboot

4. **Document your testing:**
   - Which distribution
   - Which script options
   - What worked / what didn't
   - Any workarounds needed

### Test VMs

Consider testing in VMs before testing on hardware:
- VirtualBox
- QEMU/KVM
- VMware

**Note:** Some hardware-specific features won't work in VMs.

### Reporting Test Results

Share your test results by:
1. Creating an issue with test results
2. Commenting on related PR
3. Updating compatibility documentation

## Documentation

### Types of Documentation

1. **README.md** - Main documentation
2. **TROUBLESHOOTING.md** - Problem solutions
3. **CONTRIBUTING.md** - This file
4. **Code comments** - Inline documentation

### Documentation Contributions

We especially welcome:
- Corrections to existing documentation
- Additional troubleshooting solutions
- More detailed explanations
- Translations (future)

### Documentation Guidelines

1. **Be clear and concise**
2. **Use examples**
3. **Keep it up-to-date**
4. **Test commands before documenting**
5. **Link to external resources** when helpful

## Distribution Support

Want to add support for a new distribution?

1. **Check if similar distro exists** (e.g., Ubuntu-based)
2. **Test the script** on your distribution
3. **Identify what needs changing:**
   - Package names
   - Package manager commands
   - Repository setup
   - Service names

4. **Submit PR with:**
   - Detection code
   - Package installation code
   - Testing results
   - Documentation updates

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy toward others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## Questions?

- **General questions:** Open a GitHub Discussion
- **Bug reports:** Open an Issue
- **Security issues:** Email maintainers directly (see README)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to better Linux support for the Asus ROG Flow Z13 2025!
