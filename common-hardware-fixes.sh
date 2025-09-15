#!/bin/bash

# ==============================================================================
# Common Hardware Fixes for ASUS ROG Flow Z13 (GZ302)
# 
# This file contains all the shared hardware fixes that are applied
# across all distribution setup scripts to reduce code duplication.
# ==============================================================================

# Apply hardware-specific fixes for the ROG Flow Z13 GZ302
apply_common_hardware_fixes() {
    info "Applying hardware fixes for the ROG Flow Z13 (GZ302)..."
    info "These fixes address Wi-Fi, touchpad, audio, camera, and graphics issues..."

    # Fix Wi-Fi instability (MediaTek MT7925)
    info "Fixing Wi-Fi stability for MediaTek MT7925..."
    cat > /etc/modprobe.d/mt7925e_wifi.conf <<EOF
# Fix Wi-Fi stability for MediaTek MT7925E
options mt7925e disable_aspm=1
options mt7925e power_save=0
EOF

    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf <<EOF
[connection]
wifi.powersave = 2

[device]
wifi.scan-rand-mac-address=no
EOF
    
    # Fix touchpad detection and sensitivity
    info "Fixing touchpad detection and sensitivity..."
    cat > /etc/udev/hwdb.d/61-asus-touchpad.hwdb <<EOF
# ASUS ROG Flow Z13 touchpad fix
evdev:input:b0003v0b05p1a30*
 ENV{ID_INPUT_TOUCHPAD}="1"
 ENV{ID_INPUT_MULTITOUCH}="1"
 ENV{ID_INPUT_MOUSE}="0"
 EVDEV_ABS_00=::100
 EVDEV_ABS_01=::100
 EVDEV_ABS_35=::100
 EVDEV_ABS_36=::100
EOF

    # Create service to reload touchpad driver
    cat > /etc/systemd/system/reload-hid_asus.service <<EOF
[Unit]
Description=Reload hid_asus module for Z13 Touchpad
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r hid_asus
ExecStart=/usr/sbin/modprobe hid_asus

[Install]
WantedBy=multi-user.target
EOF

    # Fix audio issues
    info "Fixing audio compatibility..."
    cat > /etc/modprobe.d/alsa-gz302.conf <<EOF
# Audio fixes for ROG Flow Z13 GZ302
options snd-hda-intel probe_mask=1
options snd-hda-intel model=asus-zenbook
EOF

    # Fix AMD GPU issues
    info "Optimizing AMD GPU performance..."
    cat > /etc/modprobe.d/amdgpu-gz302.conf <<EOF
# AMD GPU optimizations for GZ302
options amdgpu dc=1
options amdgpu gpu_recovery=1
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=1
EOF

    # Fix thermal management
    info "Setting up thermal management..."
    cat > /etc/udev/rules.d/50-gz302-thermal.rules <<EOF
# Thermal management for GZ302
SUBSYSTEM=="thermal", KERNEL=="thermal_zone*", ATTR{type}=="x86_pkg_temp", ATTR{policy}="step_wise"
SUBSYSTEM=="thermal", KERNEL=="thermal_zone*", ATTR{type}=="acpi", ATTR{policy}="step_wise"
EOF

    # Fix camera issues
    info "Fixing camera compatibility..."
    cat > /etc/modprobe.d/uvcvideo-gz302.conf <<EOF
# Camera fixes for ASUS ROG Flow Z13 GZ302
options uvcvideo quirks=0x80
options uvcvideo nodrop=1
EOF

    cat > /etc/udev/rules.d/99-gz302-camera.rules <<EOF
# Camera access rules for GZ302
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", GROUP="video", MODE="0664"
EOF

    # Update hardware database
    info "Updating hardware database..."
    systemd-hwdb update
    
    success "All hardware fixes applied successfully."
}

# Apply common performance optimizations
apply_common_performance_tweaks() {
    info "Applying performance optimizations..."
    
    # Gaming kernel parameters
    cat > /etc/sysctl.d/99-gaming.conf <<EOF
# Gaming performance optimizations
vm.max_map_count = 2147483642
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Network optimizations
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 1048576 2097152
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mtu_probing = 1

# System responsiveness
kernel.sched_autogroup_enabled = 0
EOF
    sysctl -p /etc/sysctl.d/99-gaming.conf

    # Hardware acceleration
    if ! grep -q "LIBVA_DRIVER_NAME" /etc/environment; then
        cat >> /etc/environment <<EOF

# Hardware acceleration for AMD GPU
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi

# Gaming optimizations
RADV_PERFTEST=gpl,sam,nggc
DXVK_HUD=compiler
MANGOHUD=1
EOF
    fi

    # I/O scheduler optimization
    cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Optimize I/O schedulers for storage performance
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF

    # System limits for gaming
    cat > /etc/security/limits.d/99-gaming.conf <<EOF
# Gaming system limits
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF

    success "Performance optimizations applied."
}

# Enable common services
enable_common_services() {
    info "Enabling hardware fix services..."
    systemctl enable --now reload-hid_asus.service
    success "Hardware services enabled."
}