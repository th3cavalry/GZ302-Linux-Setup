#!/bin/bash

#############################################################################
# GZ302EA Linux Setup - Verification Script
# Version: 1.0.0
# 
# This script verifies that the setup was successful by checking:
# - Kernel version
# - Graphics drivers
# - WiFi/Bluetooth
# - Audio
# - ASUS tools
# - Power management
#############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  GZ302EA Linux Setup - Verification${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_test() {
    echo -e "\n${BLUE}Testing:${NC} $1"
}

pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "  ${YELLOW}⚠ WARNING:${NC} $1"
    ((TESTS_WARNING++))
}

info() {
    echo -e "  ${BLUE}ℹ INFO:${NC} $1"
}

#############################################################################
# Tests
#############################################################################

test_kernel() {
    print_test "Kernel Version"
    
    local kernel_version=$(uname -r)
    local kernel_major=$(echo $kernel_version | cut -d. -f1)
    local kernel_minor=$(echo $kernel_version | cut -d. -f2)
    
    info "Current kernel: $kernel_version"
    
    if [ "$kernel_major" -gt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -ge 14 ]); then
        pass "Kernel version >= 6.14"
    elif [ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -ge 7 ]; then
        warn "Kernel version >= 6.7 but < 6.14 (6.14+ recommended)"
    else
        fail "Kernel version < 6.7 (at least 6.7 required, 6.14+ recommended)"
    fi
}

test_graphics() {
    print_test "Graphics Drivers"
    
    # Check if amdgpu module is loaded
    if lsmod | grep -q amdgpu; then
        pass "AMDGPU module loaded"
    else
        fail "AMDGPU module not loaded"
        return
    fi
    
    # Check for Mesa
    if command -v glxinfo &> /dev/null; then
        local renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -n1)
        if echo "$renderer" | grep -qi "radeon\|amd"; then
            pass "OpenGL renderer detected: $renderer"
        else
            warn "OpenGL renderer: $renderer (expected AMD/Radeon)"
        fi
    else
        warn "glxinfo not found (install mesa-utils)"
    fi
    
    # Check for Vulkan
    if command -v vulkaninfo &> /dev/null; then
        if vulkaninfo 2>/dev/null | grep -qi "radeon\|amd"; then
            pass "Vulkan driver detected"
        else
            warn "Vulkan driver not detected or not AMD"
        fi
    else
        warn "vulkaninfo not found (install vulkan-tools)"
    fi
}

test_wifi() {
    print_test "WiFi (MediaTek MT7925)"
    
    # Check if WiFi device exists
    if lspci | grep -qi "network.*mediatek\|mt7921\|mt7925"; then
        pass "MediaTek WiFi device detected"
    else
        warn "MediaTek WiFi device not found in lspci"
    fi
    
    # Check if module is loaded
    if lsmod | grep -q "mt7921"; then
        pass "MT7921 driver loaded"
    else
        fail "MT7921 driver not loaded"
    fi
    
    # Check if WiFi interface exists
    if ip link show | grep -q "wlan\|wlp"; then
        local iface=$(ip link show | grep -o "wl[^:]*" | head -n1)
        pass "WiFi interface found: $iface"
        
        # Check if up
        if ip link show "$iface" | grep -q "UP"; then
            pass "WiFi interface is UP"
        else
            info "WiFi interface is DOWN (may be normal if not connected)"
        fi
    else
        fail "No WiFi interface found"
    fi
}

test_bluetooth() {
    print_test "Bluetooth"
    
    # Check if Bluetooth service exists
    if systemctl list-unit-files | grep -q bluetooth.service; then
        if systemctl is-active --quiet bluetooth.service; then
            pass "Bluetooth service is running"
        else
            warn "Bluetooth service is not running (run: systemctl start bluetooth)"
        fi
        
        if systemctl is-enabled --quiet bluetooth.service; then
            pass "Bluetooth service is enabled"
        else
            warn "Bluetooth service is not enabled (run: systemctl enable bluetooth)"
        fi
    else
        fail "Bluetooth service not found"
    fi
    
    # Check for Bluetooth device
    if command -v bluetoothctl &> /dev/null; then
        if timeout 2 bluetoothctl show 2>/dev/null | grep -q "Controller"; then
            pass "Bluetooth controller detected"
        else
            fail "Bluetooth controller not detected"
        fi
    else
        warn "bluetoothctl not found"
    fi
}

test_audio() {
    print_test "Audio"
    
    # Check for audio devices
    if command -v aplay &> /dev/null; then
        if aplay -l 2>/dev/null | grep -q "card"; then
            pass "Audio device(s) detected"
            local cards=$(aplay -l 2>/dev/null | grep "^card" | wc -l)
            info "Found $cards audio card(s)"
        else
            fail "No audio devices found"
        fi
    else
        warn "aplay not found"
    fi
    
    # Check for PipeWire or PulseAudio
    if systemctl --user is-active --quiet pipewire.service; then
        pass "PipeWire audio server is running"
    elif systemctl --user is-active --quiet pulseaudio.service; then
        pass "PulseAudio audio server is running"
    elif pgrep -x pulseaudio > /dev/null; then
        pass "PulseAudio is running (user session)"
    else
        warn "No audio server (PipeWire/PulseAudio) detected running"
    fi
}

test_asus_tools() {
    print_test "ASUS Tools"
    
    # Check for asusctl
    if command -v asusctl &> /dev/null; then
        pass "asusctl installed"
        local profile=$(asusctl profile -p 2>/dev/null | grep "Active profile" || echo "Unknown")
        info "$profile"
    else
        warn "asusctl not installed (optional but recommended)"
    fi
    
    # Check for supergfxctl
    if command -v supergfxctl &> /dev/null; then
        pass "supergfxctl installed"
        local mode=$(supergfxctl -g 2>/dev/null || echo "Unknown")
        info "Graphics mode: $mode"
    else
        warn "supergfxctl not installed (optional but recommended)"
    fi
}

test_power_management() {
    print_test "Power Management"
    
    # Check for TLP
    if command -v tlp &> /dev/null; then
        pass "TLP installed"
        
        if systemctl is-active --quiet tlp.service; then
            pass "TLP service is running"
        else
            warn "TLP service is not running"
        fi
        
        if systemctl is-enabled --quiet tlp.service; then
            pass "TLP service is enabled"
        else
            warn "TLP service is not enabled"
        fi
    else
        warn "TLP not installed (recommended for battery life)"
    fi
    
    # Check CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        info "CPU governor: $governor"
        pass "CPU frequency scaling available"
    else
        warn "CPU frequency scaling not available"
    fi
    
    # Check for AMD P-State
    if [ -f /sys/devices/system/cpu/amd_pstate/status ]; then
        local pstate=$(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null || echo "unknown")
        if [ "$pstate" = "active" ]; then
            pass "AMD P-State is active"
        else
            info "AMD P-State status: $pstate"
        fi
    fi
}

test_grub_config() {
    print_test "GRUB Configuration"
    
    if [ -f /etc/default/grub ]; then
        pass "GRUB config found"
        
        if grep -q "amd_pstate=active" /etc/default/grub; then
            pass "AMD P-State parameter configured"
        else
            warn "AMD P-State parameter not found in GRUB config"
        fi
        
        if grep -q "iommu=pt" /etc/default/grub; then
            pass "IOMMU parameter configured"
        else
            info "IOMMU parameter not found (may not be needed)"
        fi
    else
        warn "GRUB config not found (using different bootloader?)"
    fi
}

test_suspend() {
    print_test "Suspend/Resume"
    
    if [ -f /sys/power/mem_sleep ]; then
        local sleep_mode=$(cat /sys/power/mem_sleep)
        info "Available sleep modes: $sleep_mode"
        
        if echo "$sleep_mode" | grep -q "\[deep\]"; then
            pass "Deep sleep (S3) is active"
        elif echo "$sleep_mode" | grep -q "\[s2idle\]"; then
            warn "S2idle is active (deep sleep/S3 recommended but may not be available)"
        else
            info "Current sleep mode: $sleep_mode"
        fi
    else
        warn "Cannot determine sleep mode"
    fi
}

#############################################################################
# Main
#############################################################################

main() {
    print_header
    
    test_kernel
    test_graphics
    test_wifi
    test_bluetooth
    test_audio
    test_asus_tools
    test_power_management
    test_grub_config
    test_suspend
    
    # Print summary
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Verification Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo -e "${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "${YELLOW}Warnings:${NC} $TESTS_WARNING"
    echo -e "${RED}Failed:${NC}   $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_WARNING -eq 0 ]; then
            echo -e "${GREEN}✓ All tests passed! Your system is properly configured.${NC}"
        else
            echo -e "${YELLOW}⚠ System is functional but has some warnings (see above).${NC}"
        fi
    else
        echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
        echo -e "${YELLOW}See TROUBLESHOOTING.md for solutions.${NC}"
    fi
    
    echo ""
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

main "$@"
