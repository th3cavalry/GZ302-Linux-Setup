#!/usr/bin/env python3
"""
GZ302 Rear Window (Lightbar) RGB Control

Controls the rear window RGB lighting on ASUS ROG Flow Z13 (2025) GZ302EA.
Uses HID raw device access to send commands to the N-KEY Device (USB 0b05:18c6).

Requires udev rules for non-root access:
  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="18c6", MODE="0666"

Usage:
  gz302-rgb-window --on                    # Turn on lightbar
  gz302-rgb-window --off                   # Turn off lightbar
  gz302-rgb-window --color 255 0 0         # Set to red
  gz302-rgb-window --color 255 255 255     # Set to white
  gz302-rgb-window --brightness 0-3        # Set brightness level (0=off)
"""

import sys
import os
import glob
import argparse
import time

# HID physical path signature for the lightbar (N-KEY Device on USB port 5)
LIGHTBAR_SIG = "usb-0000:c6:00.0-5/input0"
KEYBOARD_SIG = "usb-0000:c6:00.0-4/input"


def get_hid_phys(path):
    """Returns the HID_PHYS string from the device uevent file."""
    try:
        with open(os.path.join(path, "device/uevent"), "r") as f:
            for line in f:
                if line.startswith("HID_PHYS="):
                    return line.strip().split('=')[1]
    except Exception:
        pass
    return ""


def find_device_by_phys(target_sig):
    """Find HID raw device by physical path signature."""
    for path in glob.glob("/sys/class/hidraw/hidraw*"):
        phys = get_hid_phys(path)
        if target_sig in phys:
            return f"/dev/{os.path.basename(path)}"
    return None


def send_packet(device_path, packet_bytes):
    """Send a 64-byte HID packet to the device."""
    if len(packet_bytes) < 64:
        packet_bytes = packet_bytes + bytes([0] * (64 - len(packet_bytes)))
    try:
        with open(device_path, 'wb') as f:
            f.write(packet_bytes)
    except PermissionError:
        print(f"Permission denied: {device_path}")
        print("Run the GZ302 setup script to install udev rules, or use sudo.")
        sys.exit(1)
    except OSError as e:
        print(f"Error writing to {device_path}: {e}")
        sys.exit(1)


def set_lightbar_power(device_path, state):
    """Turn lightbar on or off."""
    if state:
        packet = bytes([0x5d, 0xbd, 0x01, 0xae, 0x05, 0x22, 0xff, 0xff])
    else:
        packet = bytes([0x5d, 0xbd, 0x01, 0xaa, 0x00, 0x00, 0xff, 0xff])
    send_packet(device_path, packet)


def set_lightbar_color(device_path, r, g, b):
    """Set lightbar color (RGB values 0-255)."""
    packet = bytes([
        0x5d, 0xb3, 0x00, 0x00,
        r, g, b,
        0xeb, 0x00, 0x00,
        0xff, 0xff, 0xff
    ])
    send_packet(device_path, packet)


def set_keyboard_color(device_path, r, g, b):
    """Set keyboard color (RGB values 0-255)."""
    packet = bytes([0x5d, 0xb3, 0x00, 0x00, r, g, b])
    send_packet(device_path, packet)
    send_packet(device_path, bytes([0x5d, 0xb5, 0x00, 0x00]))


def main():
    parser = argparse.ArgumentParser(
        description="ROG Flow Z13 (2025) Rear Window RGB Control",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --on                    Turn on lightbar (white)
  %(prog)s --off                   Turn off lightbar
  %(prog)s --color 255 0 0         Set to red
  %(prog)s --brightness 2          Set brightness level 2 (medium)
  %(prog)s --keyboard -c 0 0 255   Set keyboard to blue
  %(prog)s --list                  List detected HID devices
"""
    )

    # Target selection
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument('--keyboard', '-k', action='store_true',
                            help="Control keyboard instead of lightbar")
    mode_group.add_argument('--lightbar', '-l', action='store_true',
                            help="Control lightbar (default)")

    # Actions
    cmd_group = parser.add_mutually_exclusive_group()
    cmd_group.add_argument('--on', action='store_true',
                           help="Turn on lightbar")
    cmd_group.add_argument('--off', action='store_true',
                           help="Turn off lightbar")
    cmd_group.add_argument('--color', '-c', nargs=3, type=int,
                           metavar=('R', 'G', 'B'),
                           help="Set color (0-255 for each channel)")
    cmd_group.add_argument('--brightness', '-b', type=int, choices=range(4),
                           metavar='LEVEL',
                           help="Set brightness level (0=off, 1-3=dim to bright)")

    parser.add_argument('--list', action='store_true',
                        help="List detected HID devices")
    parser.add_argument('--dev', type=str,
                        help="Override device path (e.g., /dev/hidraw9)")

    args = parser.parse_args()

    # List devices
    if args.list:
        print("Detected HID devices:")
        for path in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
            devname = os.path.basename(path)
            phys = get_hid_phys(path)
            try:
                with open(os.path.join(path, "device/uevent"), "r") as f:
                    name = ""
                    for line in f:
                        if line.startswith("HID_NAME="):
                            name = line.strip().split('=')[1]
                            break
                print(f"  /dev/{devname}: {name}")
                print(f"    PHYS: {phys}")
                if LIGHTBAR_SIG in phys:
                    print(f"    -> This is the LIGHTBAR")
                elif KEYBOARD_SIG in phys:
                    print(f"    -> This is the KEYBOARD")
            except Exception:
                pass
        return

    # Determine target device
    if args.keyboard:
        target_sig = KEYBOARD_SIG
        target_name = "Keyboard"
    else:
        target_sig = LIGHTBAR_SIG
        target_name = "Lightbar"

    device_path = args.dev
    if not device_path:
        device_path = find_device_by_phys(target_sig)
        if not device_path:
            print(f"Error: Could not find {target_name} device.")
            print(f"Expected HID_PHYS containing: {target_sig}")
            print("Run with --list to see available devices.")
            sys.exit(1)

    # Execute action
    if args.keyboard:
        if args.color:
            r, g, b = args.color
            print(f"Setting keyboard color to RGB({r}, {g}, {b})")
            set_keyboard_color(device_path, r, g, b)
        else:
            print("Keyboard only supports --color option.")
            sys.exit(1)
    else:
        if args.off:
            print(f"Turning lightbar OFF")
            set_lightbar_power(device_path, False)
        elif args.on:
            print(f"Turning lightbar ON (white)")
            set_lightbar_power(device_path, True)
            time.sleep(0.1)
            set_lightbar_color(device_path, 255, 255, 255)
        elif args.color:
            r, g, b = args.color
            print(f"Setting lightbar to RGB({r}, {g}, {b})")
            set_lightbar_power(device_path, True)
            time.sleep(0.1)
            set_lightbar_color(device_path, r, g, b)
        elif args.brightness is not None:
            level = args.brightness
            if level == 0:
                print("Setting lightbar brightness to 0 (off)")
                set_lightbar_power(device_path, False)
            else:
                intensity = [0, 85, 170, 255][level]
                print(f"Setting lightbar brightness to {level} (intensity {intensity})")
                set_lightbar_power(device_path, True)
                time.sleep(0.1)
                set_lightbar_color(device_path, intensity, intensity, intensity)
        else:
            parser.print_help()
            sys.exit(1)


if __name__ == "__main__":
    main()
