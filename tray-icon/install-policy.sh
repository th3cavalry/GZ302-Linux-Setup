#!/bin/bash
# Configure sudoers to allow pwrcfg and gz302-rgb without password

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

echo "Configuring sudoers for password-less pwrcfg and gz302-rgb..."

# Find the full path to pwrcfg
PWRCFG_PATH=$(which pwrcfg)

if [[ -z "$PWRCFG_PATH" ]]; then
    echo "ERROR: pwrcfg command not found in PATH!"
    echo "Please install the main GZ302 setup scripts first."
    exit 1
fi

echo "Found pwrcfg at: $PWRCFG_PATH"

# Find the full path to gz302-rgb
RGB_PATH=$(which gz302-rgb)

if [[ -z "$RGB_PATH" ]]; then
    echo "WARNING: gz302-rgb command not found in PATH!"
    echo "RGB control will require a password. Install gz302-rgb module to use it without sudo."
    RGB_PATH=""
fi

if [[ -n "$RGB_PATH" ]]; then
    echo "Found gz302-rgb at: $RGB_PATH"
fi

# Create sudoers configuration using visudo
SUDOERS_FILE="/etc/sudoers.d/gz302-pwrcfg"

# Use visudo to safely create the sudoers file
cat > /tmp/gz302-pwrcfg << EOF
# Allow all users to run pwrcfg without password
ALL ALL=NOPASSWD: $PWRCFG_PATH

# Allow all users to run gz302-rgb without password
EOF

if [[ -n "$RGB_PATH" ]]; then
    cat >> /tmp/gz302-pwrcfg << EOF
ALL ALL=NOPASSWD: $RGB_PATH

EOF
fi

cat >> /tmp/gz302-pwrcfg << EOF
# Allow tray icon to control keyboard backlight without password
ALL ALL=NOPASSWD: /usr/bin/bash -c *
EOF

# Validate and install using visudo
if visudo -c -f /tmp/gz302-pwrcfg; then
    mv /tmp/gz302-pwrcfg "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "Sudoers configuration installed successfully!"
    echo "You can now run: pwrcfg <profile> without typing sudo (no password prompt)."
    if [[ -n "$RGB_PATH" ]]; then
        echo "You can now run: gz302-rgb <command> without typing sudo (no password prompt)."
    fi
    echo "GUI apps like the tray icon will work without authentication prompts."
    echo "Keyboard backlight and RGB control are configured for password-less sudo."
else
    echo "ERROR: Invalid sudoers configuration!"
    rm /tmp/gz302-pwrcfg
    exit 1
fi
