# GZ302 Linux Support Research Summary

**Date**: October 2025  
**Version**: 0.1.2-pre-release  
**Research Focus**: Current state of Linux support for ASUS ROG Flow Z13 GZ302 and AMD Strix Halo

## Executive Summary

This document summarizes comprehensive research into the current state of Linux support for the ASUS ROG Flow Z13 (GZ302EA-XS99) with AMD Ryzen AI MAX+ 395 (Strix Halo) processor. The research covered multiple forums, community projects, official documentation, and benchmark results to identify optimal configurations and best practices.

## Hardware Specifications

- **Model**: ASUS ROG Flow Z13 (2025, GZ302EA-XS99)
- **CPU**: AMD Ryzen AI MAX+ 395 (Strix Halo)
- **GPU**: AMD Radeon 8060S integrated graphics (RDNA 3.5)
- **WiFi**: MediaTek MT7925e
- **Memory**: Up to 128GB unified memory
- **Display**: 13" touchscreen with 180Hz support

**Key Point**: This is a 100% AMD system with integrated graphics only - no discrete GPU or NVIDIA components.

## Kernel Requirements

### Minimum Requirements
- **Linux Kernel 6.11+** for basic Strix Halo support
- Provides initial AMD P-State driver support and Radeon 8060S recognition

### Recommended Versions
- **Linux Kernel 6.12+** or **6.13+** for optimal performance
- Includes improved AMDGPU driver support, better power management
- Enhanced runtime repartitioning and SDMA queue reset features
- Improved support for AMD 3D V-Cache CPUs

### Future Improvements
- **Linux Kernel 6.14+** includes additional MediaTek MT7925 WiFi patches
- Addresses suspend/resume issues and connection stability

**Source**: Phoronix news, Linux kernel documentation, Ubuntu 25.10 testing

## AMD Strix Halo CPU Optimization

### AMD P-State Driver
- **Recommended Mode**: `amd_pstate=guided`
- **Confirmation**: Ubuntu 25.10 benchmarks show significant performance improvements
- **Technology**: Collaborative Processor Performance Control (CPPC)
- Provides finer-grained frequency management than legacy ACPI P-States

### Kernel Parameters
```bash
amd_pstate=guided
```

**Why "guided" over "active"?**
- Community testing confirms better performance for Strix Halo
- Ubuntu 25.10 and Mesa 25.3 optimizations leverage this mode
- Better power efficiency and thermal management

**Sources**: 
- Red Hat documentation on amd_pstate driver
- Ubuntu 25.10 Strix Halo benchmark results
- WebProNews AMD Ryzen AI Max+ benchmarks

## AMD Radeon 8060S GPU Configuration

### GPU Specifications
- **Architecture**: RDNA 3.5
- **Type**: Integrated graphics
- **Memory**: Unified system memory (up to 128GB)
- **ROCm Support**: Compatible for AI/ML workloads

### Optimal Configuration
```bash
amdgpu.ppfeaturemask=0xffffffff
```

**Features Enabled**:
- All power management features
- Full performance scaling
- Enhanced thermal management
- ROCm compatibility for GPU compute

### Performance Notes
- Phoronix testing shows performance comparable to RTX 4070 Laptop in some workloads
- Excellent memory bandwidth due to unified memory architecture
- Strong performance in AI/ML tasks with ROCm

**Sources**:
- Phoronix AMD Radeon 8060S Linux performance testing
- ROCm documentation compatibility matrix
- Notebookcheck review

## WiFi Configuration (MediaTek MT7925)

### Common Issues
1. Random disconnections
2. Suspend/resume failures
3. Reduced performance
4. Network instability

### Primary Fix: Disable ASPM
```bash
# /etc/modprobe.d/mt7925.conf
options mt7925e disable_aspm=1
```

### Additional Configuration
```bash
# /etc/NetworkManager/conf.d/wifi-powersave.conf
[connection]
wifi.powersave = 2
```

### Why This Works
- ASPM (Active State Power Management) causes instability with MT7925
- Kernel 6.11+ includes initial fixes, but ASPM disable still recommended
- Kernel 6.14+ includes additional patches for better stability

**Sources**:
- EndeavourOS forums (WiFi slow thread)
- GitHub: alimert-t/suspend-freeze-fix-for-mt7921e
- Arch Linux forums MT7922 discussions
- Kernel mailing list patches

## ASUS Control Software (asusctl)

### Arch Linux Installation

**Method 1: G14 Repository** (Recommended)
```bash
# Add repository key
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35

# Add repository to /etc/pacman.conf
[g14]
Server = https://arch.asus-linux.org

# Install
sudo pacman -Syu asusctl
```

**Method 2: AUR Fallback**
```bash
yay -S asusctl
```

**Sources**: Arch Wiki (asusctl page), asus-linux.org installation guides

### Ubuntu/Debian Installation

**Mitchell Austin's PPA** (Automated in script)
```bash
sudo add-apt-repository ppa:mitchellaugustin/asusctl
sudo apt update
sudo apt install rog-control-center
sudo systemctl daemon-reload && sudo systemctl restart asusd
```

**Sources**: 
- mitchellaugustin.com/asusctl.html
- Launchpad PPA documentation
- Ask Ubuntu forums

### Fedora Installation

**COPR Repository**
```bash
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
```

**Note**: supergfxctl not needed for GZ302 (no discrete GPU)

**Sources**:
- COPR repository documentation
- Fedora package repositories
- GitHub: icedman/asus-tuf-a14-fedora

### OpenSUSE Installation

**OBS Repository**
```bash
# For Tumbleweed
sudo zypper ar -f https://download.opensuse.org/repositories/hardware:/asus/openSUSE_Tumbleweed/ hardware:asus
sudo zypper ref
sudo zypper install asusctl

# For Leap (adjust version)
sudo zypper ar -f https://download.opensuse.org/repositories/hardware:/asus/openSUSE_Leap_15.6/ hardware:asus
```

**Alternative**: Build from source if repository unavailable

**Sources**:
- asus-linux.org installation guides
- OpenSUSE forums
- GitHub: asus-linux/asusctl

### asusctl Features
- Keyboard backlight control
- Custom fan curves
- Power profile management
- Battery charge limit settings
- RGB LED control (where applicable)

## Advanced Power and Fan Control

### ec_su_axb35 Kernel Module

**Repository**: https://github.com/cmetz/ec-su_axb35-linux

**Capabilities**:
- Direct fan RPM control with custom curves
- Power mode switching (balanced 85W, performance 100W, turbo 120W)
- APU temperature monitoring
- Manual fan speed control

**Installation** (Manual - Not automated in script):
```bash
# Install dependencies
sudo apt install build-essential linux-headers-$(uname -r)  # Debian/Ubuntu
# Or equivalent for your distribution

# Clone and build
git clone https://github.com/cmetz/ec-su_axb35-linux.git
cd ec-su_axb35-linux
sudo make install

# Load module
sudo modprobe ec_su_axb35

# Optional: Load on boot
sudo echo ec_su_axb35 >> /etc/modules
```

**Usage Examples**:
```bash
# Get current RPM of fan 2
cat /sys/class/ec_su_axb35/fan2/rpm

# Set fan 3 to fixed mode at level 2
echo fixed > /sys/class/ec_su_axb35/fan3/mode
echo 2 > /sys/class/ec_su_axb35/fan3/level

# Set power mode to balanced (85W)
echo balanced > /sys/class/ec_su_axb35/apu/power_mode
```

**Sources**:
- Strix Halo HomeLab (strixhalo-homelab.d7.wtf)
- GitHub: kyuz0/amd-strix-halo-toolboxes
- Level1Techs forums

## TDP Management (RyzenAdj)

### Installation
Script compiles from source across all distributions for consistency.

**Repository**: https://github.com/FlyGoat/RyzenAdj

### Integration
- 7 TDP profiles: emergency (10W), battery (15W), efficient (25W), balanced (35W), performance (45W), gaming (54W), maximum (65W)
- Automatic AC/battery switching
- Real-time power monitoring via `gz302-tdp` command

**Sources**:
- Arch Linux forums TDP discussion
- GitHub: aarron-lee/simple-ryzen-tdp
- Community testing results

## Community Resources

### Primary Sources

1. **Shahzebqazi/Asus-Z13-Flow-2025-PCMR** (GitHub)
   - Original GZ302 Linux setup scripts
   - Community-driven hardware testing
   - TDP management research

2. **Level1Techs Forums**
   - "Flow Z13 Asus Setup on Linux (May 2025) [WIP]"
   - "Asus Z13 flow Strix Halo Arch Linux Set-up (Fall 2025)"
   - Active community support and troubleshooting

3. **Strix Halo HomeLab** (strixhalo-homelab.d7.wtf)
   - Comprehensive power mode and fan control guides
   - Performance testing and optimization
   - ec_su_axb35 kernel module documentation

4. **asus-linux.org**
   - Official asusctl documentation
   - Installation guides for all distributions
   - Feature documentation and support

5. **Phoronix Community**
   - "AMD Radeon 8060S Linux Graphics Performance with Strix Halo"
   - Benchmark results and performance analysis
   - Hardware compatibility discussions

### Secondary Sources

- Reddit (r/linux, r/archlinux): User experiences and troubleshooting
- EndeavourOS Forums: WiFi stability solutions
- GitHub Issue Trackers: Kernel patches and driver updates
- Ubuntu Forums: PPA and package management
- Fedora Forums: COPR repository discussions

## Distribution-Specific Recommendations

### Arch Linux
- **Advantages**: Latest kernels, G14 repository, extensive AUR support
- **Recommended**: Use G14 repository for asusctl
- **Kernel**: Install latest kernel packages promptly

### Ubuntu/Debian
- **Advantages**: Stable, well-documented, PPA support
- **Recommended**: Ubuntu 25.10+ for best Strix Halo support
- **Kernel**: Consider mainline kernel PPA for latest versions

### Fedora
- **Advantages**: Recent kernels, good AMD support, COPR ecosystem
- **Recommended**: Use lukenukem/asus-linux COPR
- **Kernel**: Usually ships with recent kernels by default

### OpenSUSE
- **Advantages**: Stable (Leap) or cutting-edge (Tumbleweed) options
- **Recommended**: Tumbleweed for latest kernel support
- **Kernel**: Tumbleweed provides rolling kernel updates

## Testing and Validation

### Confirmed Working Configurations

1. **Arch Linux** (Kernel 6.12+)
   - Full hardware support
   - asusctl from G14 repository
   - Excellent performance

2. **Ubuntu 25.10** (Kernel 6.11+)
   - Benchmark-confirmed optimal performance
   - Mesa 25.3 drivers
   - Good out-of-box experience

3. **Fedora 40+** (Kernel 6.11+)
   - COPR repository for asusctl
   - Strong AMD driver support

### Known Issues and Workarounds

1. **GPU Detection Delay**
   - Some systems experience slow initial GPU detection
   - Usually resolves after first boot
   - No impact on functionality

2. **DisplayPort over USB4**
   - Occasional issues reported
   - Typically resolved with kernel updates
   - Monitor connection/disconnection may require reload

3. **Suspend/Resume with WiFi**
   - Fixed by ASPM disable in most cases
   - Kernel 6.14+ includes additional patches

## Future Outlook

### Upcoming Improvements

1. **Kernel 6.14+**
   - Additional MediaTek MT7925 WiFi patches
   - Continued AMDGPU improvements
   - Better power management

2. **Mesa Updates**
   - Ongoing RDNA 3.5 optimizations
   - ROCm integration improvements
   - Performance enhancements

3. **asusctl Development**
   - Continued feature additions
   - Better GZ302 support
   - Enhanced GUI tools

### Recommendations for Users

1. **Use Recent Kernels**: 6.11+ minimum, 6.12+/6.13+ preferred
2. **Enable Official Repositories**: Use G14/PPA/COPR/OBS for asusctl
3. **Apply WiFi Fixes**: ASPM disable is essential
4. **Monitor Updates**: Kernel and driver updates continue to improve support
5. **Engage Community**: Level1Techs and asus-linux.org forums are valuable resources

## Conclusion

Linux support for the ASUS ROG Flow Z13 (GZ302) with AMD Strix Halo has matured significantly. With kernel 6.11+ and proper configuration, users can expect excellent hardware compatibility, strong performance, and good power management. The community continues to actively develop and improve support through projects like asusctl and ec_su_axb35.

**Key Success Factors**:
- Use recent Linux kernel (6.11+, preferably 6.12+/6.13+)
- Apply WiFi fixes (ASPM disable)
- Use official asusctl repositories for your distribution
- Configure AMD P-State driver (amd_pstate=guided)
- Enable full AMDGPU feature mask

---

**Document Version**: 1.0  
**Last Updated**: October 2025  
**Maintainer**: th3cavalry  
**License**: Same as parent repository
