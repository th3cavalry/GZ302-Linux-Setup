#!/bin/bash

# ==============================================================================
# Complete Arch Linux Installation Script for ASUS ROG Flow Z13 (GZ302)
#
# This script performs a complete Arch Linux installation specifically
# optimized for the ASUS ROG Flow Z13 (GZ302) with AMD Ryzen AI 395+ processor.
# 
# IMPORTANT: This script will ERASE the target drive completely!
# 
# Usage:
# 1. Boot from Arch Linux USB
# 2. Connect to internet: iwctl (for Wi-Fi) or ethernet
# 3. Download script: curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/install-arch-gz302.sh -o install-arch-gz302.sh
# 4. Make executable: chmod +x install-arch-gz302.sh
# 5. Run: ./install-arch-gz302.sh
# ==============================================================================

set -euo pipefail

# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

info() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}[WARNING]${C_NC} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_NC} $1"; exit 1; }

# Configuration variables
HOSTNAME=""
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE=""
LOCALE="en_US.UTF-8"
KEYMAP="us"
TARGET_DISK=""
SWAP_SIZE="16G"  # 16GB swap for hibernation support

# Detect if we're running in UEFI mode
check_uefi() {
    if [ ! -d /sys/firmware/efi ]; then
        error "This script requires UEFI mode. Please boot in UEFI mode."
    fi
    success "UEFI mode detected."
}

# Check internet connectivity
check_internet() {
    info "Checking internet connectivity..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection. Please connect to the internet first."
    fi
    success "Internet connection verified."
}

# Update system clock
update_clock() {
    info "Updating system clock..."
    timedatectl set-ntp true
    success "System clock updated."
}

# Get user configuration
get_user_config() {
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Arch Linux Installation"
    echo "============================================================"
    echo
    
    # Get hostname
    while [[ -z "$HOSTNAME" ]]; do
        read -p "Enter hostname for this system: " HOSTNAME
    done
    
    # Get username
    while [[ -z "$USERNAME" ]]; do
        read -p "Enter username for the main user: " USERNAME
    done
    
    # Get user password
    while [[ -z "$USER_PASSWORD" ]]; do
        read -s -p "Enter password for user $USERNAME: " USER_PASSWORD
        echo
        read -s -p "Confirm password: " USER_PASSWORD_CONFIRM
        echo
        if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
            warning "Passwords do not match. Please try again."
            USER_PASSWORD=""
        fi
    done
    
    # Get root password
    while [[ -z "$ROOT_PASSWORD" ]]; do
        read -s -p "Enter root password: " ROOT_PASSWORD
        echo
        read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo
        if [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
            warning "Root passwords do not match. Please try again."
            ROOT_PASSWORD=""
        fi
    done
    
    # Get timezone
    echo "Available timezones (showing common ones):"
    echo "  America/New_York, America/Chicago, America/Denver, America/Los_Angeles"
    echo "  Europe/London, Europe/Paris, Europe/Berlin, Europe/Rome"
    echo "  Asia/Tokyo, Asia/Shanghai, Asia/Kolkata, Australia/Sydney"
    echo "  Or run 'timedatectl list-timezones' to see all options"
    echo
    while [[ -z "$TIMEZONE" ]]; do
        read -p "Enter your timezone (e.g., America/New_York): " TIMEZONE
        if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
            warning "Invalid timezone. Please enter a valid timezone."
            TIMEZONE=""
        fi
    done
    
    # Show available disks
    echo
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL | grep -E "nvme|sd"
    echo
    while [[ -z "$TARGET_DISK" ]]; do
        read -p "Enter target disk (e.g., /dev/nvme0n1): " TARGET_DISK
        if [[ ! -b "$TARGET_DISK" ]]; then
            warning "Invalid disk. Please enter a valid block device."
            TARGET_DISK=""
        fi
    done
    
    echo
    warning "WARNING: This will completely erase $TARGET_DISK!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        error "Installation cancelled by user."
    fi
}

# Partition the disk
partition_disk() {
    info "Partitioning disk $TARGET_DISK..."
    
    # Clear existing partition table
    wipefs -af "$TARGET_DISK"
    
    # Create new GPT partition table
    parted -s "$TARGET_DISK" mklabel gpt
    
    # Create EFI System Partition (1GB)
    parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$TARGET_DISK" set 1 esp on
    
    # Create swap partition
    parted -s "$TARGET_DISK" mkpart swap linux-swap 1025MiB $((1025 + ${SWAP_SIZE%G} * 1024))MiB
    
    # Create root partition (remaining space)
    parted -s "$TARGET_DISK" mkpart root ext4 $((1025 + ${SWAP_SIZE%G} * 1024))MiB 100%
    
    success "Disk partitioned successfully."
}

# Format partitions
format_partitions() {
    info "Formatting partitions..."
    
    # Determine partition naming scheme
    if [[ "$TARGET_DISK" =~ nvme ]]; then
        EFI_PART="${TARGET_DISK}p1"
        SWAP_PART="${TARGET_DISK}p2"
        ROOT_PART="${TARGET_DISK}p3"
    else
        EFI_PART="${TARGET_DISK}1"
        SWAP_PART="${TARGET_DISK}2"
        ROOT_PART="${TARGET_DISK}3"
    fi
    
    # Format EFI partition
    mkfs.fat -F32 "$EFI_PART"
    
    # Setup swap
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
    
    # Format root partition with ext4
    mkfs.ext4 -F "$ROOT_PART"
    
    success "Partitions formatted successfully."
}

# Mount filesystems
mount_filesystems() {
    info "Mounting filesystems..."
    
    # Mount root partition
    mount "$ROOT_PART" /mnt
    
    # Create and mount EFI directory
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
    
    success "Filesystems mounted successfully."
}

# Install base system
install_base_system() {
    info "Installing base system..."
    
    # Update pacman mirrors for better download speeds
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    # Install base system with additional packages needed for GZ302
    pacstrap /mnt base base-devel linux linux-firmware \
        networkmanager wifi-menu iwd dhcpcd \
        grub efibootmgr \
        sudo nano vim git curl wget \
        amd-ucode \
        mesa vulkan-radeon libva-mesa-driver mesa-vdpau
    
    success "Base system installed."
}

# Configure system
configure_system() {
    info "Configuring system..."
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Configure system in chroot
    arch-chroot /mnt /bin/bash << EOF
set -euo pipefail

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Configure locale
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Configure keymap
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOL

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create user
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Enable essential services
systemctl enable NetworkManager
systemctl enable iwd

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
EOF
    
    success "System configured."
}

# Apply GZ302-specific optimizations and GRUB configuration
configure_grub_gz302() {
    info "Configuring GRUB with GZ302-specific optimizations..."
    
    arch-chroot /mnt /bin/bash << 'EOF'
# Configure GRUB with GZ302 optimizations
cat > /etc/default/grub << 'EOL'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active amdgpu.dc=1 amdgpu.gpu_recovery=1 amdgpu.ppfeaturemask=0xffffffff iommu=soft"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
EOL

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg
EOF
    
    success "GRUB configured with GZ302 optimizations."
}

# Download and prepare post-installation setup script
prepare_post_install() {
    info "Preparing post-installation setup script..."
    
    # Copy the existing flowz13_setup.sh to the new system
    cp /tmp/flowz13_setup.sh /mnt/home/$USERNAME/ 2>/dev/null || {
        # Download the script if not available locally
        arch-chroot /mnt /bin/bash << EOF
cd /home/$USERNAME
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Arch-Setup/main/flowz13_setup.sh -o flowz13_setup.sh
chmod +x flowz13_setup.sh
chown $USERNAME:$USERNAME flowz13_setup.sh
EOF
    }
    
    success "Post-installation setup script prepared."
}

# Main installation function
main() {
    echo "============================================================"
    echo "  ASUS ROG Flow Z13 (GZ302) Arch Linux Installation"
    echo "============================================================"
    echo
    
    check_uefi
    check_internet
    update_clock
    get_user_config
    
    info "Starting installation..."
    partition_disk
    format_partitions
    mount_filesystems
    install_base_system
    configure_system
    configure_grub_gz302
    prepare_post_install
    
    # Unmount filesystems
    umount -R /mnt
    swapoff "$SWAP_PART"
    
    echo
    success "============================================================"
    success "Arch Linux installation completed successfully!"
    success ""
    success "Next steps:"
    success "1. Remove the installation media"
    success "2. Reboot the system"
    success "3. Log in as $USERNAME"
    success "4. Run the post-installation setup script:"
    success "   sudo ./flowz13_setup.sh"
    success ""
    success "The post-installation script will:"
    success "- Install the linux-g14 kernel for better hardware support"
    success "- Apply ROG Flow Z13 specific hardware fixes"
    success "- Install gaming software (Steam, Lutris, ProtonUp-Qt)"
    success "- Configure performance optimizations"
    success "============================================================"
    echo
    
    read -p "Press Enter to reboot or Ctrl+C to stay in live environment..."
    reboot
}

# Copy this script to /tmp for access in chroot if needed
cp "$0" /tmp/$(basename "$0") 2>/dev/null || true

# Run the installation
main "$@"