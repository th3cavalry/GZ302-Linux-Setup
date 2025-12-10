# GZ302 Linux Setup - Passwordless Sudo Configuration Plan

## Problem Summary
The GZ302 installation script fails when attempting to install Linux Armoury because it requires sudo password authentication in a non-interactive environment:
```
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
⚠  Linux Armoury installation failed
```

## Root Cause
- The `install_linux_armoury()` function in `gz302-main.sh` (line 3234-3283) checks for passwordless sudo
- Without passwordless sudo configured, the Linux Armoury installer cannot escalate privileges in non-interactive mode
- The script gracefully skips Linux Armoury when this check fails, but then the installation may be incomplete

## Solution: Configure Passwordless Sudo

### Step 1: Edit Sudoers File

Run the following command to safely edit sudoers:
```bash
sudo visudo
```

### Step 2: Add Passwordless Sudo Entry

At the END of the file (before `#includedir /etc/sudoers.d`), add one of the following entries based on your user group:

**For Arch Linux users (wheel group):**
```
%wheel ALL=(ALL) NOPASSWD: ALL
```

**For Ubuntu/Debian users (sudo group):**
```
%sudo ALL=(ALL) NOPASSWD: ALL
```

**For specific user only (replace `brandon` with your username):**
```
brandon ALL=(ALL) NOPASSWD: ALL
```

### Step 3: Verify Configuration

Save and exit (`Ctrl+X` then `Y` then `Enter` in nano, or `:wq` in vi).

Test passwordless sudo:
```bash
sudo -n true && echo "Passwordless sudo works!" || echo "Failed to configure"
```

Expected output:
```
Passwordless sudo works!
```

## Security Considerations

⚠️ **Important**: Passwordless sudo allows any process running as your user to execute commands as root without a password prompt.

**Risk Mitigation:**
1. **Recommended**: Use group-based configuration (`%wheel` or `%sudo`) instead of user-specific
2. **Alternative**: Restrict passwordless sudo to specific commands only (see Advanced section below)
3. **Monitoring**: Regularly audit `/var/log/auth.log` for suspicious sudo usage

### Advanced: Restrict Passwordless Sudo to Specific Commands

Instead of allowing ALL commands, you can restrict to only GZ302-related tools:

```
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg, /usr/local/bin/rrcfg, /usr/local/bin/gz302-rgb, /tmp/Linux-Armoury/install.sh
%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg, /usr/local/bin/rrcfg, /usr/local/bin/gz302-rgb, /tmp/Linux-Armoury/install.sh
```

## Next Steps After Configuration

Once passwordless sudo is configured:

1. **Run the installation script again:**
   ```bash
   sudo ./gz302-main.sh
   ```

2. **Expected behavior:**
   - Linux Armoury will install successfully
   - All core components will be configured
   - Optional modules can be selected

3. **Verification:**
   - System tray icon will appear in your desktop environment
   - Power profiles will be available via `pwrcfg` command
   - Refresh rate control via `rrcfg` command

## Troubleshooting

**Issue: "sudo: command not found in sudoers"**
- Verify exact path: `which pwrcfg`
- Update sudoers entry with correct path

**Issue: Still prompts for password**
- Ensure your user is in the correct group:
  - Arch: `groups $USER | grep wheel`
  - Ubuntu: `groups $USER | grep sudo`
- If not in group, add with: `sudo usermod -aG wheel $USER` (Arch) or `sudo usermod -aG sudo $USER` (Ubuntu)
- Log out and back in for group changes to take effect

**Issue: Sudoers syntax error**
- Undo with: `sudo visudo -c` to check syntax
- If file is locked, remove lock: `sudo rm /etc/sudoers.d/sudoers.tmp`

## Related Files
- Main setup script: `gz302-main.sh` (lines 3234-3283)
- Linux Armoury: https://github.com/th3cavalry/Linux-Armoury
- GZ302 Project: https://github.com/th3cavalry/GZ302-Linux-Setup

## References
- Ubuntu visudo guide: https://help.ubuntu.com/community/Sudoers
- Arch wiki sudoers: https://wiki.archlinux.org/title/Sudo#Sudoers
- Passwordless sudo best practices: https://superuser.com/questions/119156