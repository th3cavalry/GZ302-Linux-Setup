#!/usr/bin/env bash
set -euo pipefail

# Install a Desktop launcher and Autostart entry for the GZ302 tray icon

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
APP_DIR="$SCRIPT_DIR"
APP_PY="$APP_DIR/src/gz302_tray.py"

if [[ ! -f "$APP_PY" ]]; then
  echo "ERROR: Tray script not found at $APP_PY" >&2
  exit 1
fi

# Ensure executable bit
chmod +x "$APP_PY"

# User locations
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$AUTOSTART_DIR" "$DESKTOP_DIR"

# Use custom icon from assets if available, otherwise fallback to system icon
ICON_PATH="$APP_DIR/assets/profile-b.svg"
if [[ -f "$ICON_PATH" ]]; then
  ICON_NAME="$ICON_PATH"
else
  ICON_NAME="battery"
fi

# Use python3 explicitly in Exec line for better compatibility across desktop environments
DESKTOP_FILE_CONTENT="[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for GZ302
Exec=python3 $APP_PY
Icon=$ICON_NAME
Terminal=false
Categories=Utility;System;
StartupNotify=false
X-GNOME-Autostart-enabled=true
"

# Install desktop launcher
DESKTOP_FILE="$DESKTOP_DIR/gz302-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Install autostart entry
AUTOSTART_FILE="$AUTOSTART_DIR/gz302-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$AUTOSTART_FILE"
chmod +x "$AUTOSTART_FILE"

echo "Installed desktop launcher: $DESKTOP_FILE"
echo "Enabled autostart entry:    $AUTOSTART_FILE"
echo ""
echo "You can now launch 'GZ302 Power Manager' from your app menu or it will start on login."
echo ""
echo "NOTE: If you use GNOME, you may need to install the 'AppIndicator' extension:"
echo "  - GNOME: Install 'AppIndicator and KStatusNotifierItem Support' from extensions.gnome.org"
echo "  - KDE/XFCE/LXQt: System tray support is built-in"
