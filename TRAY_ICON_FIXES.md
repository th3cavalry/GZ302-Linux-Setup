# GZ302 Tray Icon Installation - Fixes Summary

## Issues Identified and Fixed

### 1. **Incorrect APP_DIR Detection in install-tray.sh**
   - **Problem**: The script only checked if files existed at the system location (`/usr/local/share/gz302/tray-icon/`), never falling back to the local script directory where `install-tray.sh` was actually located.
   - **Impact**: When the script ran as part of initial setup or manual installation, it couldn't find files and silently failed to create proper desktop entries.
   - **Fix**: Changed priority order in `install-tray.sh` line 10-16:
     ```bash
     # NEW: Check local directory first
     if [[ -f "$SCRIPT_DIR/src/gz302_tray.py" ]]; then
       APP_DIR="$SCRIPT_DIR"
     elif [[ -f "/usr/local/share/gz302/tray-icon/src/gz302_tray.py" ]]; then
       APP_DIR="/usr/local/share/gz302/tray-icon"
     else
       APP_DIR="$SCRIPT_DIR"  # Fallback for better error messages
     fi
     ```

### 2. **Desktop Files Had Incorrect Permissions**
   - **Problem**: Desktop files were being created with executable bit (`chmod +x`), which is incorrect and can cause desktop environment issues.
   - **Standard**: Desktop files should have permissions `644` (rw-r--r--), not executable.
   - **Fix**: Changed in `install-tray.sh` lines 91 and 103:
     ```bash
     # OLD: chmod +x "$DESKTOP_FILE"
     # NEW: chmod 644 "$DESKTOP_FILE"
     ```

### 3. **Improved System File Copy Logic in gz302-main.sh**
   - **Problem**: The main script had to update variables multiple times and lacked proper verification that files were copied successfully.
   - **Fix**: Enhanced `gz302-main.sh` lines 2850-2930 to:
     - Add informative messages about whether files were downloaded or found locally
     - Explicitly verify critical files exist at system location before proceeding
     - Store system directory path consistently throughout the function
     - Better error messages with explicit file paths

### 4. **Verification of System Installation**
   - **Problem**: Script didn't verify that critical files were installed to system location.
   - **Fix**: Added explicit checks after file copy:
     ```bash
     if [[ ! -f "$system_tray_dir/src/gz302_tray.py" ]]; then
       error "Failed to install tray icon: $system_tray_dir/src/gz302_tray.py not found"
     fi
     ```

## Installation Flow (After Fixes)

### When `gz302-main.sh` runs:
1. **Check/Download Tray Files** (local repo or download from GitHub)
   - Downloads to: `$SCRIPT_DIR/tray-icon/`
   
2. **Copy to System Location**
   - Copies all files to: `/usr/local/share/gz302/tray-icon/`
   - Verifies critical files exist
   
3. **Install Python Dependencies**
   - Installs `python3-pyqt6` and `python3-psutil` (distribution-specific)
   
4. **Run Installation Script**
   - Executes `/usr/local/share/gz302/tray-icon/install-tray.sh`
   - Script detects local files correctly via `$SCRIPT_DIR`
   - Creates desktop files with correct permissions (644)
   
5. **Result**:
   - ✓ Desktop file at `~/.local/share/applications/gz302-tray.desktop`
   - ✓ Autostart entry at `~/.config/autostart/gz302-tray.desktop`
   - ✓ System-wide desktop file at `/usr/share/applications/gz302-tray.desktop` (when run as root)
   - ✓ Icon installed at `~/.local/share/icons/hicolor/scalable/apps/gz302-power-manager.svg`
   - ✓ Application appears in app menu/launcher

## Desktop File Content
```ini
[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for ASUS ROG Flow Z13 (GZ302)
Exec=python3 /usr/local/share/gz302/tray-icon/src/gz302_tray.py
Icon=gz302-power-manager
Terminal=false
Categories=Utility;System;Settings;HardwareSettings;
Keywords=power;battery;profile;asus;rog;gz302;
StartupNotify=false
X-GNOME-Autostart-enabled=true
```

## Testing Performed

- ✓ Bash syntax validation: `bash -n` on all modified scripts
- ✓ Desktop file creation with correct permissions (644)
- ✓ Application icon installation and discovery
- ✓ Python import validation (application loads successfully)
- ✓ Complete installation flow simulation
- ✓ File path resolution in various execution contexts

## Files Modified

1. **tray-icon/install-tray.sh**
   - Fixed APP_DIR detection logic
   - Corrected desktop file permissions

2. **gz302-main.sh**
   - Enhanced tray installation function with better checks
   - Improved variable consistency
   - Added file verification

## Known Limitations / Notes

- **GNOME Users**: May still need AppIndicator extension for system tray support
  - Extension: https://extensions.gnome.org/extension/615/appindicator-support/
- **PyQt6 Installation**: Varies by distribution; all major distros supported
- **Icon Cache**: Automatically updated on systems with `gtk-update-icon-cache`

## Troubleshooting

If the tray icon still doesn't appear:

1. **Check desktop files exist**:
   ```bash
   ls -la ~/.local/share/applications/gz302-tray.desktop
   ls -la ~/.config/autostart/gz302-tray.desktop
   ```

2. **Check permissions** (should be 644, not 755):
   ```bash
   ls -l ~/.local/share/applications/gz302-tray.desktop
   ```

3. **Test manual execution**:
   ```bash
   python3 /usr/local/share/gz302/tray-icon/src/gz302_tray.py
   ```

4. **Check for Python/PyQt6 errors**:
   ```bash
   python3 -c "from PyQt6.QtWidgets import QApplication"
   ```

5. **Verify icon installation**:
   ```bash
   ls -la ~/.local/share/icons/hicolor/scalable/apps/gz302-power-manager.svg
   ```

6. **Update application cache** (if needed):
   ```bash
   update-desktop-database ~/.local/share/applications/
   ```

## Version

- **Modified**: November 29, 2025
- **Scripts affected**: `tray-icon/install-tray.sh`, `gz302-main.sh`
- **Version bump required**: Yes (patch increment in main script)
