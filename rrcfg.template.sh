#!/bin/bash
# GZ302 Refresh Rate Management Script
# Manual refresh rate control - auto-switching handled by pwrcfg

REFRESH_CONFIG_DIR="/etc/rrcfg"
CURRENT_PROFILE_FILE="$REFRESH_CONFIG_DIR/current-profile"
VRR_ENABLED_FILE="$REFRESH_CONFIG_DIR/vrr-enabled"
GAME_PROFILES_FILE="$REFRESH_CONFIG_DIR/game-profiles"
VRR_RANGES_FILE="$REFRESH_CONFIG_DIR/vrr-ranges"
MONITOR_CONFIGS_FILE="$REFRESH_CONFIG_DIR/monitor-configs"
POWER_MONITORING_FILE="$REFRESH_CONFIG_DIR/power-monitoring"

# Refresh Rate Profiles - Matched to power profiles for GZ302 display and AMD GPU
declare -A REFRESH_PROFILES
REFRESH_PROFILES[emergency]="30"         # Emergency battery extension
REFRESH_PROFILES[battery]="30"           # Maximum battery life
REFRESH_PROFILES[efficient]="60"         # Efficient with good performance
REFRESH_PROFILES[balanced]="90"          # Balanced performance/power
REFRESH_PROFILES[performance]="120"      # High performance applications
REFRESH_PROFILES[gaming]="180"           # Gaming optimized
REFRESH_PROFILES[maximum]="180"          # Absolute maximum

# ...rest of rrcfg script logic as extracted from gz302-main.sh...
