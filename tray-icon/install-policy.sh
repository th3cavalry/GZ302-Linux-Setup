#!/bin/bash
# Install polkit policy to allow pwrcfg without sudo

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

echo "Installing polkit policy for pwrcfg..."
cp policies/org.gz302.pwrcfg.policy /usr/share/polkit-1/actions/
chmod 644 /usr/share/polkit-1/actions/org.gz302.pwrcfg.policy

echo "Policy installed successfully!"
echo "You can now use: pkexec pwrcfg <profile>"
echo "Or from GUI applications without entering password each time."
