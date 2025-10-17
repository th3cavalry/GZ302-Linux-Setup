#!/bin/bash
# GZ302 Power Configuration Script (pwrcfg)
# Manages power profiles with SPL/sPPT/fPPT for AMD Ryzen AI MAX+ 395 (Strix Halo)

set -euo pipefail

# Auto-elevate: allow running 'pwrcfg <profile>' without typing sudo
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        # If password-less sudo is configured, re-exec without prompting
        if sudo -n true 2>/dev/null; then
            exec sudo -n "$0" "$@"
        fi
        echo "pwrcfg requires elevated privileges to apply power limits." >&2
        echo "Enable password-less sudo for /usr/local/bin/pwrcfg (recommended) or run with sudo." >&2
        exit 1
    else
        echo "pwrcfg requires elevated privileges and 'sudo' was not found. Run as root." >&2
        exit 1
    fi
fi

TDP_CONFIG_DIR="/etc/pwrcfg"
CURRENT_PROFILE_FILE="$TDP_CONFIG_DIR/current-profile"
AUTO_CONFIG_FILE="$TDP_CONFIG_DIR/auto-config"
AC_PROFILE_FILE="$TDP_CONFIG_DIR/ac-profile"
BATTERY_PROFILE_FILE="$TDP_CONFIG_DIR/battery-profile"

# Power Profiles for GZ302 AMD Ryzen AI MAX+ 395 (Strix Halo)
# SPL (Sustained Power Limit): Long-term steady power level
# sPPT (Slow Power Boost): Short-term boost (up to ~2 minutes)
# fPPT (Fast Power Boost): Very short-term boost (few seconds)
# All values in milliwatts (mW)

# Profile format: "SPL:sPPT:fPPT"
declare -A POWER_PROFILES
POWER_PROFILES[emergency]="10000:12000:12000"      # Emergency: 10W SPL, 12W boost (30Hz)
POWER_PROFILES[battery]="18000:20000:20000"        # Battery: 18W SPL, 20W boost (30Hz)
POWER_PROFILES[efficient]="30000:35000:35000"      # Efficient: 30W SPL, 35W boost (60Hz)
POWER_PROFILES[balanced]="40000:45000:45000"       # Balanced: 40W SPL, 45W boost (90Hz)
POWER_PROFILES[performance]="55000:60000:60000"    # Performance: 55W SPL, 60W boost (120Hz)
POWER_PROFILES[gaming]="70000:80000:80000"         # Gaming: 70W SPL, 80W boost (180Hz)
POWER_PROFILES[maximum]="90000:90000:90000"        # Maximum: 90W sustained (180Hz)

declare -A REFRESH_RATES
REFRESH_RATES[emergency]="30"
REFRESH_RATES[battery]="30"
REFRESH_RATES[efficient]="60"
REFRESH_RATES[balanced]="90"
REFRESH_RATES[performance]="120"
REFRESH_RATES[gaming]="180"
REFRESH_RATES[maximum]="180"

# ...rest of pwrcfg script logic as extracted from gz302-main.sh...
