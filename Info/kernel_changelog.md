# Linux Kernel Changelog - GZ302EA Specific Changes

This document tracks kernel changes specifically relevant to the ASUS ROG Flow Z13 (GZ302EA) variants and their components:

**Supported Models**:
- **GZ302EA-XS99** - 128GB RAM model
- **GZ302EA-XS64** - 64GB RAM model  
- **GZ302EA-XS32** - 32GB RAM model

**Hardware Components**:
- **CPU**: AMD Ryzen AI MAX+ 395 (Strix Halo)
- **GPU**: AMD Radeon 8060S integrated GPU (RDNA 3.5)
- **WiFi**: MediaTek MT7925 (mt7925e module)
- **Audio**: SOF (Sound Open Firmware) compatible

**Last Updated**: October 15, 2025

---

## Linux Kernel 6.18 (Upcoming - Expected December 2025)

### AMD Strix Halo (Ryzen AI MAX+ 395)
- **AMD Secure AVIC**: Hardware-assisted virtualization security and performance enhancements
- **Power Management Refinements**: Further energy efficiency improvements for Ryzen AI processors
- **Memory Management**: Optimizations for high-density workloads and improved system robustness

### AMD Radeon 8060S iGPU (RDNA 3.5)
- **AMDGPU Driver Updates**: Enhanced power management and display handling
- **Graphics Performance**: Continued optimizations for RDNA 3.5 architecture
- **Hardware Support**: Expanded feature support for Radeon integrated graphics

### Audio Support
- **SOF Updates**: Continued Sound Open Firmware improvements for better audio compatibility

### Recommendation
**FUTURE RELEASE** - Expected December 2025. Will include further AMD optimizations and security enhancements.

---

## Linux Kernel 6.17 (Latest Stable - October 2025)

### AMD Strix Halo (Ryzen AI MAX+ 395)
- **AI Performance**: Fine-tuned AMD XDNA driver for enhanced AI task management and NPU processing
- **Power Management**: Refined AMD P-State driver optimizations for Strix Halo architecture
- **Gaming Performance**: Enhanced support for Wine and Proton gaming frameworks

### AMD Radeon 8060S iGPU (RDNA 3.5)
- **AMDGPU Driver**: Performance and stability improvements for post-RDNA 3.5 hardware
- **Bug Fixes**: Specific targeting of RDNA 3.5 GPU issues
- **GPU Scheduling**: Enhanced integrated GPU scheduling for better performance

### MediaTek MT7925 WiFi
- **Performance Optimizations**: Significant improvements to wireless command handling
- **Stability Fixes**: Regression fixes addressing wireless speed drops
- **MT76 Driver**: Continued refinements for better reliability

### Recommendation
**HIGHLY RECOMMENDED** - Kernel 6.17 is the current stable release with the most comprehensive support for GZ302EA hardware.

---

## Linux Kernel 6.16

### AMD Strix Halo (Ryzen AI MAX+ 395)
- **Virtualization**: Enhanced KVM support optimized for Ryzen AI processors
- **I/O Operations**: Improved input/output efficiency for AMD AI-driven processors

### AMD Radeon 8060S iGPU (RDNA 3.5)
- **Context Switching**: Refined GPU context switching improvements
- **Multi-core Processing**: Better multi-core GPU workload distribution
- **Power Management**: Enhanced power management for integrated graphics

### MediaTek MT7925 WiFi
- **MT76 Driver**: General performance and stability enhancements
- **Bug Fixes**: Continued improvements to wireless stability

### Recommendation
**RECOMMENDED** - Solid kernel version with good hardware support.

---

## Linux Kernel 6.15

### AMD Strix Halo (Ryzen AI MAX+ 395)
- **XDNA NPU Support**: Extended optimizations for AMD XDNA driver
- **AI Workloads**: Better handling of extensive AI processing tasks
- **Security**: Enhanced AES encryption support with performance improvements

### AMD Radeon 8060S iGPU (RDNA 3.5)
- **Cleaner Shader Support**: GPU resources initialized in clean state between workloads
- **Shared Computing**: Critical improvements for shared GPU computing environments
- **Trusted Execution**: Better support for trusted/untrusted application scenarios

### MediaTek MT7925 WiFi
- **Stability**: General improvements to MT76 driver stability
- **Performance**: Enhanced wireless performance

### Recommendation
**ACCEPTABLE** - Minimum recommended kernel with essential RDNA 3.5 and NPU support.

---

## Linux Kernel 6.14 (Current Minimum Supported)

### AMD Strix Halo (Ryzen AI MAX+ 395)
- **AMD XDNA Driver**: Initial integration of NPU driver for AI task execution
- **P-State Driver**: Dynamic core ranking support introduced
- **Energy Policy**: Default 'balance_performance' EPP on Ryzen processors
- **Performance**: General AES encryption performance improvements
- **CPU Support**: Capability to support up to 4,096 CPU cores

### AMD Radeon 8060S iGPU (RDNA 3.5)
- **General Support**: Basic RDNA 3.5 hardware support and maintenance updates
- **Driver Updates**: Standard AMDGPU driver improvements

### MediaTek MT7925 WiFi
- **MT76 Driver Integration**: Integration of mlo_sta_cmd and sta_cmd into MT76 driver
- **Stability**: Addressed various stability and performance issues

### Recommendation
**MINIMUM SUPPORTED** - This is the absolute minimum kernel version required for GZ302EA. Upgrading to 6.15+ strongly recommended.

---

## Summary of Recommendations

| Kernel Version | Status | GZ302EA Support Level |
|---------------|--------|----------------------|
| 6.18 | Upcoming (Dec 2025) | **Future** - Advanced features |
| 6.17 | Current Stable | **Best** - Full optimization |
| 6.16 | Stable | **Good** - Enhanced features |
| 6.15 | Stable | **Acceptable** - Core features |
| 6.14 | Minimum | **Basic** - Limited optimization |
| < 6.14 | Not Supported | **Incompatible** - Missing critical drivers |

---

## Critical Features by Kernel Version

### NPU (Neural Processing Unit) Support
- **6.14+**: AMD XDNA driver with basic NPU support
- **6.15+**: Extended XDNA optimizations for AI workloads
- **6.17**: Fine-tuned AI task management

### WiFi (MediaTek MT7925) Stability
- **6.14**: Basic driver integration with known issues
- **6.15-6.16**: Improved stability
- **6.17**: Optimized performance with regression fixes

### GPU (AMD Radeon 8060S) Performance
- **6.14**: Basic RDNA 3.5 support
- **6.15**: Cleaner shader support (critical for shared computing)
- **6.16**: Context switching and power management improvements
- **6.17**: Enhanced scheduling and stability

### Power Management
- **6.14**: AMD P-State with dynamic core ranking
- **6.15+**: Enhanced EPP and power management
- **6.17**: Refined optimizations for Strix Halo

---

## Conditional Fixes in Scripts

The GZ302 setup scripts apply kernel-version-specific workarounds:

1. **WiFi Fixes (MT7925)**: Applied on kernels < 6.16 to address stability issues
2. **AMDGPU Configuration**: All kernel versions get full feature mask (0xffffffff)
3. **AMD P-State**: amd_pstate=guided recommended for all 6.14+ kernels
4. **NPU Support**: Automatic on 6.14+ (XDNA driver available)

---

## Sources

- Linux Kernel 6.14: A Leap Forward in Intel and AMD CPU Support (LinuxJournal)
- Linux Kernel 6.14 Arrives With Performance Gains (ItsFOSS)
- AMD RDNA 3.5 Cleaner Shader Support for Linux 6.15 (Phoronix)
- AMD Ryzen AI Max+ "Strix Halo" Performance on Linux (Phoronix)
- Linux Kernel Newbies - Kernel 6.17 Release Notes
- MT7925 Wireless Driver Discussion (Linux Kernel Mailing List)
- Strix Halo Development Tracking (Community Resources)

---

**Document Version**: 1.0  
**Created**: October 15, 2025  
**Maintainer**: th3cavalry  
**License**: Same as parent repository
