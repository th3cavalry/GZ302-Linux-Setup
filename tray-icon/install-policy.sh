#!/bin/bash
# Configure sudoers to allow pwrcfg without password

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

echo "Configuring sudoers for password-less pwrcfg..."

# Find the full path to pwrcfg
PWRCFG_PATH=$(which pwrcfg)

if [[ -z "$PWRCFG_PATH" ]]; then
    echo "ERROR: pwrcfg command not found in PATH!"
    echo "Please install the main GZ302 setup scripts first."
    exit 1
fi

echo "Found pwrcfg at: $PWRCFG_PATH"

# Create sudoers configuration using visudo
SUDOERS_FILE="/etc/sudoers.d/gz302-pwrcfg"

# Use visudo to safely create the sudoers file
cat > /tmp/gz302-pwrcfg << EOF
# Allow all users to run pwrcfg without password
ALL ALL=NOPASSWD: $PWRCFG_PATH
EOF

# Validate and install using visudo
if visudo -c -f /tmp/gz302-pwrcfg; then
    mv /tmp/gz302-pwrcfg "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "Sudoers configuration installed successfully!"
    echo "You can now run: pwrcfg <profile> without typing sudo (no password prompt)."
    echo "GUI apps like the tray icon will work without authentication prompts."
else
    echo "ERROR: Invalid sudoers configuration!"
    rm /tmp/gz302-pwrcfg
    exit 1
fi
