#!/bin/bash
# Configure sudoers to allow z13ctl and wrapper commands without password

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Configuring sudoers for password-less z13ctl access..."

# Find z13ctl
Z13CTL_PATH=$(command -v z13ctl 2>/dev/null || echo "")

if [[ -z "$Z13CTL_PATH" ]]; then
    echo "ERROR: z13ctl not found in PATH!"
    echo "Please run gz302-setup.sh first to install z13ctl."
    exit 1
fi

echo "Found z13ctl at: $Z13CTL_PATH"

# Find optional wrapper commands
PWRCFG_PATH=$(command -v pwrcfg 2>/dev/null || echo "")
GZ302RGB_PATH=$(command -v gz302-rgb 2>/dev/null || echo "")
RRCFG_PATH=$(command -v rrcfg 2>/dev/null || echo "")

SUDOERS_FILE="/etc/sudoers.d/gz302"
TMPFILE=$(mktemp /tmp/gz302-sudoers.XXXXXX)

cat > "$TMPFILE" << EOF
# GZ302 Linux Setup — password-less access for z13ctl and wrappers
ALL ALL=NOPASSWD: $Z13CTL_PATH
EOF

[[ -n "$PWRCFG_PATH" ]] && echo "ALL ALL=NOPASSWD: $PWRCFG_PATH" >> "$TMPFILE"
[[ -n "$GZ302RGB_PATH" ]] && echo "ALL ALL=NOPASSWD: $GZ302RGB_PATH" >> "$TMPFILE"
[[ -n "$RRCFG_PATH" ]] && echo "ALL ALL=NOPASSWD: $RRCFG_PATH" >> "$TMPFILE"

if visudo -c -f "$TMPFILE"; then
    mv "$TMPFILE" "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "Sudoers configuration installed at $SUDOERS_FILE"
    echo "z13ctl (and any wrappers) can now run without a password prompt."
else
    echo "ERROR: Invalid sudoers configuration!"
    rm -f "$TMPFILE"
    exit 1
fi
