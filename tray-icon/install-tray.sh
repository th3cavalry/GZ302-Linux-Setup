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

ICON_NAME="battery" # Will fall back to our internal icons at runtime

DESKTOP_FILE_CONTENT="[Desktop Entry]
Type=Application
Name=GZ302 Power Manager
Comment=System tray power profile manager for GZ302
Exec=$APP_PY
Icon=$ICON_NAME
Terminal=false
Categories=Utility;System;
"

# Install desktop launcher
DESKTOP_FILE="$DESKTOP_DIR/gz302-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"

# Install autostart entry
AUTOSTART_FILE="$AUTOSTART_DIR/gz302-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$AUTOSTART_FILE"

echo "Installed desktop launcher: $DESKTOP_FILE"
echo "Enabled autostart entry:    $AUTOSTART_FILE"
echo "You can now launch 'GZ302 Power Manager' from your app menu or it will start on login."
