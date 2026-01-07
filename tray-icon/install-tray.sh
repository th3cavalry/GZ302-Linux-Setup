#!/usr/bin/env bash
set -euo pipefail

# Install a Desktop launcher and Autostart entry for the GZ302 Control Center
# This script can be run as a regular user for user-specific installation
# or with sudo for system-wide installation

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Determine the canonical install location for the tray icon
# Priority: local script directory > system control-center > legacy tray-icon
# This ensures the script works both when run directly and from the main setup
if [[ -f "$SCRIPT_DIR/src/gz302_tray.py" ]]; then
  APP_DIR="$SCRIPT_DIR"
elif [[ -f "/usr/local/share/gz302/control-center/src/gz302_tray.py" ]]; then
  APP_DIR="/usr/local/share/gz302/control-center"
elif [[ -f "/usr/local/share/gz302/tray-icon/src/gz302_tray.py" ]]; then
  APP_DIR="/usr/local/share/gz302/tray-icon"
else
  APP_DIR="$SCRIPT_DIR"
fi

APP_PY="$APP_DIR/src/gz302_tray.py"

if [[ ! -f "$APP_PY" ]]; then
  echo "ERROR: Tray script not found at $APP_PY" >&2
  exit 1
fi

# Ensure executable bit (warn if it fails but continue)
if ! chmod +x "$APP_PY" 2>/dev/null; then
  echo "WARNING: Could not set executable bit on $APP_PY (may already be set)" >&2
fi

# Determine user home directory (handle sudo case)
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

# User locations
AUTOSTART_DIR="$USER_HOME/.config/autostart"
DESKTOP_DIR="$USER_HOME/.local/share/applications"
mkdir -p "$AUTOSTART_DIR" "$DESKTOP_DIR"

# Install icon to system location for proper XDG integration
ICON_NAME="gz302-power-manager"
ICON_SRC="$APP_DIR/assets/profile-b.svg"

# Try to install icon to system-wide location if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -f "$ICON_SRC" ]]; then
  # Install to hicolor icon theme (most widely supported)
  ICON_DEST="/usr/share/icons/hicolor/scalable/apps/${ICON_NAME}.svg"
  mkdir -p "$(dirname "$ICON_DEST")"
  if cp "$ICON_SRC" "$ICON_DEST" 2>/dev/null; then
    echo "Installed system icon: $ICON_DEST"
  else
    echo "WARNING: Could not install system icon to $ICON_DEST" >&2
  fi
  
  # Update icon cache
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
  fi
elif [[ -f "$ICON_SRC" ]]; then
  # Fallback to user icon directory
  USER_ICON_DIR="$USER_HOME/.local/share/icons/hicolor/scalable/apps"
  mkdir -p "$USER_ICON_DIR"
  if cp "$ICON_SRC" "$USER_ICON_DIR/${ICON_NAME}.svg" 2>/dev/null; then
    echo "Installed user icon: $USER_ICON_DIR/${ICON_NAME}.svg"
  else
    echo "WARNING: Could not install user icon" >&2
  fi
fi

# Use python3 explicitly in Exec line for better compatibility across desktop environments
# Respect APP_NAME setting from /etc/gz302/tray.conf if present
APP_NAME_DEFAULT="GZ302 Control Center"
APP_NAME="$APP_NAME_DEFAULT"
if [[ -f /etc/gz302/tray.conf ]]; then
  # shellcheck disable=SC1091
  while IFS='=' read -r k v; do
    k=$(echo "$k" | tr -d ' "')
    v=$(echo "$v" | sed -e 's/^ *//g' -e 's/ *$//g' -e 's/^"//' -e 's/"$//')
    if [[ "$k" == "APP_NAME" && -n "$v" ]]; then
      APP_NAME="$v"
    fi
  done < /etc/gz302/tray.conf
fi

DESKTOP_FILE_CONTENT="[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Power profile, RGB, and hardware control for ASUS ROG Flow Z13 (GZ302)
Exec=python3 $APP_PY
Icon=$ICON_NAME
Terminal=false
Categories=Utility;System;Settings;HardwareSettings;
Keywords=power;battery;profile;asus;rog;gz302;
StartupNotify=false
X-GNOME-Autostart-enabled=true
"

# Install desktop launcher to user directory
DESKTOP_FILE="$DESKTOP_DIR/gz302-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"
chmod 644 "$DESKTOP_FILE"

# Fix ownership if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
  if ! chown "$SUDO_USER:$SUDO_USER" "$DESKTOP_FILE" 2>/dev/null; then
    echo "WARNING: Could not set ownership on $DESKTOP_FILE" >&2
  fi
fi

# Install autostart entry
# Skip user-level autostart if system-level autostart exists (prevents duplicates)
AUTOSTART_FILE="$AUTOSTART_DIR/gz302-tray.desktop"
SYSTEM_AUTOSTART="/etc/xdg/autostart/gz302-control-center.desktop"
if [[ -f "$SYSTEM_AUTOSTART" ]]; then
  echo "System-level autostart exists at $SYSTEM_AUTOSTART - skipping user autostart"
  # Remove any existing user autostart to prevent duplicates
  rm -f "$AUTOSTART_FILE" 2>/dev/null || true
  rm -f "$AUTOSTART_DIR/gz302-control-center.desktop" 2>/dev/null || true
else
  printf "%s" "$DESKTOP_FILE_CONTENT" > "$AUTOSTART_FILE"
  chmod 644 "$AUTOSTART_FILE"
  echo "Enabled autostart entry:    $AUTOSTART_FILE"
fi

# Fix ownership if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
  if ! chown "$SUDO_USER:$SUDO_USER" "$AUTOSTART_FILE" 2>/dev/null; then
    echo "WARNING: Could not set ownership on $AUTOSTART_FILE" >&2
  fi
fi

# Install system-wide desktop file if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SYSTEM_DESKTOP_DIR="/usr/share/applications"
  mkdir -p "$SYSTEM_DESKTOP_DIR"
  SYSTEM_DESKTOP_FILE="$SYSTEM_DESKTOP_DIR/gz302-tray.desktop"
  printf "%s" "$DESKTOP_FILE_CONTENT" > "$SYSTEM_DESKTOP_FILE"
  chmod 644 "$SYSTEM_DESKTOP_FILE"
  echo "Installed system-wide desktop launcher: $SYSTEM_DESKTOP_FILE"
  
  # Update desktop database
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$SYSTEM_DESKTOP_DIR" 2>/dev/null || true
  fi
fi

# Update user desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "Installed desktop launcher: $DESKTOP_FILE"
echo ""

echo "Registering APP_NAME to /etc/gz302/tray.conf and notifying running tray (if any)..."
# Ensure config dir exists
mkdir -p /etc/gz302
if [[ ! -f /etc/gz302/tray.conf ]] || ! grep -q "APP_NAME" /etc/gz302/tray.conf 2>/dev/null; then
  echo "APP_NAME=\"$APP_NAME\"" > /etc/gz302/tray.conf
  chmod 644 /etc/gz302/tray.conf
fi

# ==============================================================================
# RGB Tools Integration
# Ensure RGB backends are installed since the tray app depends on them
# ==============================================================================
RGB_BIN="/usr/local/bin/gz302-rgb"
WINDOW_BIN="/usr/local/bin/gz302-rgb-window"

if [[ ! -f "$RGB_BIN" || ! -f "$WINDOW_BIN" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "RGB Backend Tools Missing"
    echo "The Control Center requires the RGB backend tools to be installed."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Try to find the installer relative to this script
    # Pattern: ../scripts/gz302-rgb-install.sh (from repo structure)
    REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    RGB_INSTALLER="$REPO_ROOT/scripts/gz302-rgb-install.sh"
    
    if [[ ! -f "$RGB_INSTALLER" ]]; then
        # Try finding it if we are in the installed location
        # If installed to /usr/local/share/gz302/tray-icon, scripts might not be there
        # So we download it
        echo "RGB installer not found locally. Downloading..."
        RGB_INSTALLER="/tmp/gz302-rgb-install.sh"
        curl -fsSL "https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/scripts/gz302-rgb-install.sh" -o "$RGB_INSTALLER"
        chmod +x "$RGB_INSTALLER"
    fi
    
    if [[ -f "$RGB_INSTALLER" ]]; then
        echo "Launching RGB installer..."
        echo "NOTE: This may require sudo privileges."
        
        # Detect distro roughly or default to arch (installer handles it better)
        if [[ -f /etc/os-release ]]; then
            # shellcheck disable=SC1091
            source /etc/os-release
            DISTRO="${ID:-arch}"
        else
            DISTRO="arch"
        fi
        
        # Run installer
        if [[ $EUID -eq 0 ]]; then
            bash "$RGB_INSTALLER" "$DISTRO"
        else
            sudo bash "$RGB_INSTALLER" "$DISTRO"
        fi
        
        echo "RGB tools installation attempted."
    else
        echo "WARNING: Failed to locate or download RGB installer."
        echo "The RGB tab in the Control Center may not function."
    fi
    echo ""
fi
# ==============================================================================

# Notify running tray processes using SIGUSR1 so they reload UI strings
pids=()
for name in "gz302_tray.py" "gz302_tray" "gz302-tray"; do
  while read -r p; do
    [[ -n "$p" ]] && pids+=("$p")
  done < <(pgrep -f "$name" 2>/dev/null || true)
done

if [[ ${#pids[@]} -gt 0 ]]; then
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -USR1 "$pid" 2>/dev/null || true
      echo "Sent SIGUSR1 to tray process: $pid"
    fi
  done
  echo "Tray processes notified; they will reload their UI shortly."
else
  echo "No running tray process detected. Start it via the app menu or logging out/in." 
fi

echo ""
echo "You can now launch '$APP_NAME' from your app menu or it will start on login."
echo ""
echo "NOTE: If you use GNOME, you may need to install the 'AppIndicator' extension:"
echo "  - GNOME: Install 'AppIndicator and KStatusNotifierItem Support' from extensions.gnome.org"
echo "  - KDE/XFCE/LXQt: System tray support is built-in"
