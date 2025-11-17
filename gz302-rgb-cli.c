/**
 * GZ302 RGB Keyboard Control
 * 
 * This is a minimal, GZ302-specific implementation derived from rogauracore.
 * Extracted code is used under the MIT License (see below).
 *
 * Original rogauracore:
 *   Author: Will Roberts <wildwilhelm@gmail.com>
 *   Copyright (c) 2019 Will Roberts, Josh Ventura
 *   https://github.com/Syndelis/rogauracore
 *   License: MIT
 *
 * MIT License:
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * sublicense, and/or sell copies of the Software, and to permit persons
 * to whom the Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * GZ302 Modifications:
 *   - Removed support for multiple ASUS ROG models
 *   - Focused exclusively on GZ302EA keyboard (USB 0x0b05:0x1a30)
 *   - Removed unnecessary functions and color presets for minimal binary
 *   - Streamlined command-line interface
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <libusb-1.0/libusb.h>

#define MESSAGE_LENGTH 17
#define GZ302_VENDOR_ID 0x0b05
#define GZ302_PRODUCT_ID 0x1a30
#define RGB_CONFIG_DIR "/etc/gz302-rgb"
#define RGB_CONFIG_FILE "/etc/gz302-rgb/last-setting.conf"

/* USB protocol constants for GZ302 keyboard */
const uint8_t SPEED_BYTE_VALUES[] = {0xe1, 0xeb, 0xf5};
const uint8_t MESSAGE_BRIGHTNESS[MESSAGE_LENGTH] = {0x5a, 0xba, 0xc5, 0xc4};
const uint8_t MESSAGE_SET[MESSAGE_LENGTH] = {0x5d, 0xb5};
const uint8_t MESSAGE_APPLY[MESSAGE_LENGTH] = {0x5d, 0xb4};

typedef struct {
    uint8_t r, g, b;
} Color;

/* Initialize a USB control message */
void init_message(uint8_t *msg) {
    memset(msg, 0, MESSAGE_LENGTH);
    msg[0] = 0x5d;
    msg[1] = 0xb3;
}

/* Single static color */
void single_static(uint8_t *msg, Color color) {
    init_message(msg);
    msg[4] = color.r;
    msg[5] = color.g;
    msg[6] = color.b;
}

/* Single breathing animation */
void single_breathing(uint8_t *msg, Color color1, Color color2, int speed) {
    init_message(msg);
    msg[3] = 1;
    msg[4] = color1.r;
    msg[5] = color1.g;
    msg[6] = color1.b;
    msg[7] = SPEED_BYTE_VALUES[speed - 1];
    msg[9] = 1;
    msg[10] = color2.r;
    msg[11] = color2.g;
    msg[12] = color2.b;
}

/* Color cycling animation */
void single_colorcycle(uint8_t *msg, int speed) {
    init_message(msg);
    msg[3] = 2;
    msg[4] = 0xff;
    msg[7] = SPEED_BYTE_VALUES[speed - 1];
}

/* Rainbow cycling animation */
void rainbow_cycle(uint8_t *msg, int speed) {
    init_message(msg);
    msg[3] = 3;
    msg[4] = 0xff;
    msg[7] = SPEED_BYTE_VALUES[speed - 1];
}

/* Set keyboard brightness (0-3) */
void set_brightness(uint8_t *msg, int brightness) {
    memcpy(msg, MESSAGE_BRIGHTNESS, MESSAGE_LENGTH);
    msg[4] = brightness;
}

/* Parse hex color string (e.g., "FF0000" -> Color{255,0,0}) */
int parse_color(const char *arg, Color *color) {
    if (strlen(arg) != 6) {
        fprintf(stderr, "Error: Color must be 6 hex digits (e.g., FF0000)\n");
        return -1;
    }
    for (int i = 0; i < 6; i++) {
        if (!isxdigit(arg[i])) {
            fprintf(stderr, "Error: Invalid hex color: %s\n", arg);
            return -1;
        }
    }
    uint32_t v = (uint32_t)strtol(arg, NULL, 16);
    if (errno == ERANGE) {
        fprintf(stderr, "Error: Color value out of range\n");
        return -1;
    }
    color->r = (v >> 16) & 0xff;
    color->g = (v >> 8) & 0xff;
    color->b = v & 0xff;
    return 0;
}

/* Parse integer (speed or brightness) */
int parse_int(const char *arg, int min, int max, int *result) {
    long val = strtol(arg, NULL, 10);
    if (errno == ERANGE || val < min || val > max) {
        fprintf(stderr, "Error: Value must be between %d and %d\n", min, max);
        return -1;
    }
    *result = (int)val;
    return 0;
}

/* Save RGB setting to config file for boot restoration */
void save_rgb_setting(int argc, char **argv) {
    FILE *config_file;
    
    /* Try to create config directory if it doesn't exist */
    mkdir(RGB_CONFIG_DIR, 0755);
    
    /* Open config file for writing */
    config_file = fopen(RGB_CONFIG_FILE, "w");
    if (!config_file) {
        fprintf(stderr, "Warning: Could not save RGB setting to %s\n", RGB_CONFIG_FILE);
        return;
    }
    
    /* Write command and all arguments to config file */
    fprintf(config_file, "COMMAND=%s\n", argv[1]);
    for (int i = 2; i < argc; i++) {
        fprintf(config_file, "ARG%d=%s\n", i - 1, argv[i]);
    }
    fprintf(config_file, "ARGC=%d\n", argc);
    
    fclose(config_file);
    fprintf(stderr, "RGB setting saved for boot restoration\n");
}

/* Find and open GZ302 keyboard */
libusb_device_handle *find_gz302_device(void) {
    libusb_device **devices;
    libusb_device_handle *handle = NULL;
    ssize_t count = libusb_get_device_list(NULL, &devices);
    
    if (count < 0) {
        fprintf(stderr, "Error: Could not get USB device list\n");
        return NULL;
    }
    
    for (ssize_t i = 0; i < count; i++) {
        struct libusb_device_descriptor desc;
        libusb_get_device_descriptor(devices[i], &desc);
        
        if (desc.idVendor == GZ302_VENDOR_ID && desc.idProduct == GZ302_PRODUCT_ID) {
            if (libusb_open(devices[i], &handle) == 0) {
                libusb_free_device_list(devices, 1);
                return handle;
            }
        }
    }
    
    fprintf(stderr, "Error: GZ302 keyboard not found (USB 0x0b05:0x1a30)\n");
    libusb_free_device_list(devices, 1);
    return NULL;
}

/* Check if device is GZ302 by examining sysfs */
int is_gz302_device(const char *hidraw_path) {
    char sysfs_path[512];
    char vendor[16], product[16];
    FILE *f;
    
    /* Get the hidraw device number from path */
    const char *device_num = hidraw_path + strlen("/dev/hidraw");
    
    /* Check sysfs for device info */
    snprintf(sysfs_path, sizeof(sysfs_path), "/sys/class/hidraw/hidraw%s/device/../../idVendor", device_num);
    
    f = fopen(sysfs_path, "r");
    if (!f) return 0;
    if (!fgets(vendor, sizeof(vendor), f)) {
        fclose(f);
        return 0;
    }
    fclose(f);
    
    snprintf(sysfs_path, sizeof(sysfs_path), "/sys/class/hidraw/hidraw%s/device/../../idProduct", device_num);
    f = fopen(sysfs_path, "r");
    if (!f) return 0;
    if (!fgets(product, sizeof(product), f)) {
        fclose(f);
        return 0;
    }
    fclose(f);
    
    /* Check if vendor:product matches GZ302 (0b05:1a30) */
    int v = (int)strtol(vendor, NULL, 16);
    int p = (int)strtol(product, NULL, 16);
    
    return (v == 0x0b05 && p == 0x1a30);
}

/* Send message to GZ302 keyboard via hidraw device */
int send_to_gz302_hidraw(uint8_t *message) {
    int fd;
    ssize_t ret;
    int found_any = 0;
    int success = 0;
    
    /* Find ALL hidraw devices that belong to GZ302 keyboard and send to all of them */
    /* The RGB control may be on any of the 5 interfaces, so we send to all to ensure it works */
    for (int i = 0; i < 64; i++) {
        char hidraw_path[256];
        snprintf(hidraw_path, sizeof(hidraw_path), "/dev/hidraw%d", i);
        
        fd = open(hidraw_path, O_RDWR);
        if (fd < 0) continue;
        
        /* Verify this is the GZ302 keyboard */
        if (is_gz302_device(hidraw_path)) {
            found_any = 1;
            fprintf(stderr, "Sending to GZ302 keyboard at %s\n", hidraw_path);
            
            ret = write(fd, message, MESSAGE_LENGTH);
            if (ret == MESSAGE_LENGTH) {
                /* Apply changes to this interface */
                write(fd, MESSAGE_SET, MESSAGE_LENGTH);
                write(fd, MESSAGE_APPLY, MESSAGE_LENGTH);
                success = 1;
                fprintf(stderr, "Sent RGB command via %s\n", hidraw_path);
            }
        }
        close(fd);
    }
    
    if (success) {
        return 0;
    } else if (found_any) {
        fprintf(stderr, "Error: Found GZ302 keyboard but could not send RGB command\n");
        return -1;
    } else {
        fprintf(stderr, "Error: Could not find GZ302 hidraw device\n");
        return -1;
    }
}

/* Send message to GZ302 keyboard via libusb (no driver detach) */
int send_to_gz302_libusb(uint8_t *message) {
    libusb_device_handle *handle;
    int ret;
    int actual_length;
    
    if (libusb_init(NULL) < 0) {
        fprintf(stderr, "Error: Could not initialize libusb\n");
        return -1;
    }
    
    handle = find_gz302_device();
    if (!handle) {
        libusb_exit(NULL);
        return -1;
    }
    
    fprintf(stderr, "Found GZ302 keyboard via libusb\n");
    
    /* NOTE: We deliberately do NOT detach kernel drivers */
    /* This keeps the keyboard functional while sending RGB commands */
    
    /* Claim interface 0 for communication */
    ret = libusb_claim_interface(handle, 0);
    if (ret < 0) {
        fprintf(stderr, "Warning: Could not claim interface: %s\n", libusb_error_name(ret));
        /* Continue anyway, might still work */
    }
    
    /* Send via interrupt transfer */
    fprintf(stderr, "Sending RGB command via EP 4...\n");
    
    ret = libusb_interrupt_transfer(
        handle,
        0x04,           /* EP 4 OUT */
        message,
        MESSAGE_LENGTH,
        &actual_length,
        1000
    );
    
    if (ret < 0) {
        fprintf(stderr, "USB interrupt transfer error: %s\n", libusb_error_name(ret));
        libusb_release_interface(handle, 0);
        libusb_close(handle);
        libusb_exit(NULL);
        return ret;
    }
    
    fprintf(stderr, "Interrupt transfer successful, wrote %d bytes\n", actual_length);
    
    /* Apply changes */
    fprintf(stderr, "Applying MESSAGE_SET...\n");
    libusb_interrupt_transfer(handle, 0x04, (unsigned char *)MESSAGE_SET, MESSAGE_LENGTH, &actual_length, 1000);
    
    fprintf(stderr, "Applying MESSAGE_APPLY...\n");
    libusb_interrupt_transfer(handle, 0x04, (unsigned char *)MESSAGE_APPLY, MESSAGE_LENGTH, &actual_length, 1000);
    
    libusb_release_interface(handle, 0);
    libusb_close(handle);
    libusb_exit(NULL);
    
    fprintf(stderr, "RGB command completed\n");
    
    return 0;
}

/* Send message to GZ302 keyboard */
int send_to_gz302(uint8_t *message) {
    /* Try hidraw first (kernel-managed, no detach needed) */
    int ret = send_to_gz302_hidraw(message);
    if (ret == 0) {
        return 0;
    }
    
    fprintf(stderr, "Hidraw device not available, trying libusb with driver detach...\n");
    
    /* Fall back to libusb with driver detach */
    return send_to_gz302_libusb(message);
}

void print_usage(const char *prog) {
    printf("GZ302 RGB Keyboard Control\n");
    printf("Usage: %s COMMAND [ARGS]\n\n", prog);
    printf("Commands:\n");
    printf("  single_static <HEX_COLOR>              - Static color (e.g., FF0000 for red)\n");
    printf("  single_breathing <HEX_COLOR1> <HEX_COLOR2> <SPEED>  - Breathing (speed 1-3)\n");
    printf("  single_colorcycle <SPEED>              - Color cycling (speed 1-3)\n");
    printf("  rainbow_cycle <SPEED>                  - Rainbow animation (speed 1-3)\n");
    printf("  brightness <0-3>                       - Set brightness level\n");
    printf("  red|green|blue|yellow|cyan|magenta|white|black - Preset colors\n");
}

int main(int argc, char **argv) {
    uint8_t message[MESSAGE_LENGTH];
    Color color1, color2;
    int speed, brightness;
    
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    const char *cmd = argv[1];
    
    if (strcmp(cmd, "single_static") == 0) {
        if (argc != 3 || parse_color(argv[2], &color1) < 0) {
            fprintf(stderr, "Usage: %s single_static <HEX_COLOR>\n", argv[0]);
            return 1;
        }
        single_static(message, color1);
    }
    else if (strcmp(cmd, "single_breathing") == 0) {
        if (argc != 5 || parse_color(argv[2], &color1) < 0 || 
            parse_color(argv[3], &color2) < 0 || parse_int(argv[4], 1, 3, &speed) < 0) {
            fprintf(stderr, "Usage: %s single_breathing <HEX_COLOR1> <HEX_COLOR2> <SPEED>\n", argv[0]);
            return 1;
        }
        single_breathing(message, color1, color2, speed);
    }
    else if (strcmp(cmd, "single_colorcycle") == 0) {
        if (argc != 3 || parse_int(argv[2], 1, 3, &speed) < 0) {
            fprintf(stderr, "Usage: %s single_colorcycle <SPEED>\n", argv[0]);
            return 1;
        }
        single_colorcycle(message, speed);
    }
    else if (strcmp(cmd, "rainbow_cycle") == 0) {
        if (argc != 3 || parse_int(argv[2], 1, 3, &speed) < 0) {
            fprintf(stderr, "Usage: %s rainbow_cycle <SPEED>\n", argv[0]);
            return 1;
        }
        rainbow_cycle(message, speed);
    }
    else if (strcmp(cmd, "brightness") == 0) {
        if (argc != 3 || parse_int(argv[2], 0, 3, &brightness) < 0) {
            fprintf(stderr, "Usage: %s brightness <0-3>\n", argv[0]);
            return 1;
        }
        set_brightness(message, brightness);
    }
    else if (strcmp(cmd, "red") == 0) {
        color1 = (Color){0xff, 0x00, 0x00};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "green") == 0) {
        color1 = (Color){0x00, 0xff, 0x00};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "blue") == 0) {
        color1 = (Color){0x00, 0x00, 0xff};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "yellow") == 0) {
        color1 = (Color){0xff, 0xff, 0x00};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "cyan") == 0) {
        color1 = (Color){0x00, 0xff, 0xff};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "magenta") == 0) {
        color1 = (Color){0xff, 0x00, 0xff};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "white") == 0) {
        color1 = (Color){0xff, 0xff, 0xff};
        single_static(message, color1);
    }
    else if (strcmp(cmd, "black") == 0) {
        color1 = (Color){0x00, 0x00, 0x00};
        single_static(message, color1);
    }
    else {
        fprintf(stderr, "Unknown command: %s\n", cmd);
        print_usage(argv[0]);
        return 1;
    }
    
    /* Send RGB command to keyboard */
    int result = send_to_gz302(message);
    
    /* If successful, save setting for boot restoration */
    if (result == 0) {
        save_rgb_setting(argc, argv);
    }
    
    return result;
}
