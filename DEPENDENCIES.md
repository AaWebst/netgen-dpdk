# Dependencies Guide

Complete list of all dependencies for NetGen Pro - DPDK Edition.

## Overview

The project has three types of dependencies:
1. **System packages** - OS-level libraries
2. **DPDK** - Data Plane Development Kit
3. **Python packages** - For the control server

## System Dependencies

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    meson \
    ninja-build \
    python3-pip \
    python3-dev \
    python3-pyelftools \
    pkg-config \
    libnuma-dev \
    libpcap-dev \
    linux-headers-$(uname -r) \
    pciutils \
    net-tools \
    iproute2 \
    git \
    wget \
    curl
```

### CentOS/RHEL/Fedora

```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    meson \
    ninja-build \
    python3-pip \
    python3-devel \
    python3-pyelftools \
    pkg-config \
    numactl-devel \
    libpcap-devel \
    kernel-devel \
    pciutils \
    net-tools \
    iproute \
    git \
    wget
```

## DPDK Dependencies

### Core Requirements

**DPDK Version:** 23.11 (recommended)
- Minimum: 20.11
- Maximum tested: 23.11

**Installation:**
```bash
# Automated (via install.sh)
./scripts/install.sh

# Manual
cd /tmp
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11
meson setup build
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

### Kernel Modules

Required kernel modules:
- `uio` - Userspace I/O
- `vfio-pci` - Virtual Function I/O (recommended)
- `igb_uio` - Intel userspace driver (optional, older alternative)

**Load modules:**
```bash
sudo modprobe uio
sudo modprobe vfio-pci
```

### Hugepages

Required for DPDK memory management.

**Configuration:**
```bash
# Allocate 1024 x 2MB pages (2GB total)
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Mount hugepages
sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge

# Make persistent
echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf
echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
```

**For higher performance (1GB pages):**
```bash
# Allocate 8 x 1GB pages (8GB total)
echo 8 | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
```

## Python Dependencies

### Core Python Packages

Install from `requirements.txt`:
```bash
pip3 install -r requirements.txt
```

Or install manually:

```bash
pip3 install Flask==3.0.0
pip3 install Flask-CORS==4.0.0
pip3 install Flask-SocketIO==5.3.5
pip3 install gevent==23.9.1
pip3 install gevent-websocket==0.10.1
pip3 install python-socketio==5.10.0
pip3 install python-engineio==4.8.0
pip3 install netifaces==0.11.0
pip3 install psutil==5.9.6
pip3 install requests==2.31.0
```

### Detailed Package List

| Package | Version | Purpose |
|---------|---------|---------|
| Flask | 3.0.0 | Web framework |
| Flask-CORS | 4.0.0 | Cross-origin resource sharing |
| Flask-SocketIO | 5.3.5 | WebSocket support |
| gevent | 23.9.1 | Async event loop |
| gevent-websocket | 0.10.1 | WebSocket server |
| python-socketio | 5.10.0 | Socket.IO protocol |
| python-engineio | 4.8.0 | Engine.IO protocol |
| netifaces | 0.11.0 | Network interface detection |
| psutil | 5.9.6 | System monitoring |
| requests | 2.31.0 | HTTP client |

**Note:** `sqlite3` is included in Python standard library (no installation needed)

## C++ Build Dependencies

### Compiler Requirements

**Minimum:**
- GCC 7.0+
- Clang 6.0+

**Recommended:**
- GCC 11+
- Clang 13+

**Check version:**
```bash
gcc --version
g++ --version
```

### Build Tools

- **make** - GNU Make 4.0+
- **cmake** - CMake 3.16+ (optional)
- **meson** - 0.53+ (for DPDK)
- **ninja** - 1.8+ (for DPDK)
- **pkg-config** - For library detection

## Network Card Requirements

### Supported NICs

**Tier 1 (Best Performance):**
- Intel X710 / XXV710 / XL710 (10/25/40 Gbps)
- Intel E810 (100 Gbps)
- Mellanox ConnectX-5 / ConnectX-6 (25/100 Gbps)

**Tier 2 (Good Performance):**
- Intel 82599 (10 Gbps)
- Intel i350 (1 Gbps)
- Mellanox ConnectX-4 (25/100 Gbps)

**Tier 3 (Basic Support):**
- Intel e1000e (1 Gbps)
- Broadcom NetXtreme II (with DPDK patches)

**Check compatibility:**
```bash
# List network devices
lspci | grep -i ethernet

# Check DPDK PMD support
dpdk-devbind.py --status
```

### NIC Firmware

Ensure your NIC has updated firmware:
```bash
# Intel NICs
ethtool -i eth0  # Check firmware version

# Update if needed (Intel)
sudo apt-get install intel-nic-firmware
```

## Optional Dependencies

### For Packet Capture

```bash
# tcpdump for packet inspection
sudo apt-get install tcpdump

# wireshark for analysis
sudo apt-get install wireshark
```

### For Performance Monitoring

```bash
# CPU frequency tools
sudo apt-get install linux-tools-common linux-tools-generic

# Network monitoring
sudo apt-get install iftop nethogs bmon

# System monitoring
sudo apt-get install htop sysstat
```

### For Development

```bash
# Code formatting
pip3 install black flake8

# C++ debugging
sudo apt-get install gdb valgrind

# DPDK examples
sudo apt-get install dpdk-dev dpdk-doc
```

## Verification Commands

### Check All Dependencies

```bash
# System packages
dpkg -l | grep -E "build-essential|meson|libnuma"  # Ubuntu
rpm -qa | grep -E "gcc|meson|numactl"              # CentOS

# DPDK
pkg-config --exists libdpdk && echo "DPDK: OK" || echo "DPDK: Missing"
pkg-config --modversion libdpdk

# Python packages
pip3 list | grep -E "Flask|gevent|socketio"

# Kernel modules
lsmod | grep -E "uio|vfio"

# Hugepages
grep Huge /proc/meminfo

# Network cards
lspci | grep -i ethernet
dpdk-devbind.py --status
```

### Quick Health Check

```bash
#!/bin/bash
echo "=== Dependency Health Check ==="

# GCC
if command -v gcc &> /dev/null; then
    echo "✅ GCC: $(gcc --version | head -n1)"
else
    echo "❌ GCC: Not found"
fi

# Python
if command -v python3 &> /dev/null; then
    echo "✅ Python: $(python3 --version)"
else
    echo "❌ Python: Not found"
fi

# DPDK
if pkg-config --exists libdpdk; then
    echo "✅ DPDK: $(pkg-config --modversion libdpdk)"
else
    echo "❌ DPDK: Not found"
fi

# Hugepages
HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
if [ "$HUGEPAGES" -gt 512 ]; then
    echo "✅ Hugepages: $HUGEPAGES (OK)"
else
    echo "⚠️  Hugepages: $HUGEPAGES (Low, need 1024+)"
fi

# VFIO module
if lsmod | grep -q vfio_pci; then
    echo "✅ vfio-pci: Loaded"
else
    echo "⚠️  vfio-pci: Not loaded"
fi

# Flask
if python3 -c "import flask" 2>/dev/null; then
    echo "✅ Flask: Installed"
else
    echo "❌ Flask: Not found"
fi
```

## Minimum Versions Summary

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| OS | Ubuntu 20.04 | Ubuntu 22.04 | Any modern Linux |
| Kernel | 4.4 | 5.15+ | For VFIO support |
| GCC | 7.0 | 11+ | C++17 support |
| Python | 3.8 | 3.10+ | |
| DPDK | 20.11 | 23.11 | Latest stable |
| Hugepages | 512MB | 2GB+ | More = better |
| RAM | 4GB | 8GB+ | System memory |
| CPU Cores | 2 | 4+ | One per profile |

## Installation Script

The provided `install.sh` script handles all of this automatically:

```bash
./scripts/install.sh
```

It will:
1. ✅ Detect your OS
2. ✅ Install system packages
3. ✅ Download and compile DPDK
4. ✅ Configure hugepages
5. ✅ Load kernel modules
6. ✅ Install Python packages
7. ✅ Build the DPDK engine
8. ✅ Verify installation

## Troubleshooting

### "DPDK not found"

```bash
# Check if installed
pkg-config --exists libdpdk

# If missing, reinstall
cd /tmp
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11
meson setup build
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

### "Cannot import Flask"

```bash
# Install Python packages
pip3 install -r requirements.txt

# Or individual packages
pip3 install Flask Flask-CORS Flask-SocketIO
```

### "No hugepages available"

```bash
# Check current allocation
cat /proc/meminfo | grep Huge

# Allocate hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Verify
cat /proc/meminfo | grep Huge
```

### "vfio-pci module not found"

```bash
# Load the module
sudo modprobe vfio-pci

# Make persistent
echo "vfio-pci" | sudo tee -a /etc/modules

# Verify
lsmod | grep vfio
```

## Docker/Container Support

### Dockerfile Example

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential meson ninja-build \
    python3-pip libnuma-dev libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
COPY requirements.txt /tmp/
RUN pip3 install -r /tmp/requirements.txt

# Install DPDK
RUN cd /tmp && \
    wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz && \
    tar xf dpdk-23.11.tar.xz && \
    cd dpdk-23.11 && \
    meson setup build && \
    ninja -C build && \
    ninja -C build install && \
    ldconfig

# Copy application
COPY . /app
WORKDIR /app

# Build DPDK engine
RUN make

# Run with --privileged and --device flags
CMD ["python3", "web/dpdk_control_server.py"]
```

**Note:** Containers need special configuration for DPDK (hugepages, device access, privileges).

## Cloud Deployments

### AWS EC2

**Supported instances:**
- c5n.large, c5n.xlarge (ENA with DPDK)
- i3en.* instances (ENA with DPDK)

**Setup:**
```bash
# Enable ENA on EC2 instance
sudo modprobe ena
sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>
```

### Bare Metal

Best performance on dedicated servers:
- No virtualization overhead
- Direct NIC access
- Full CPU isolation possible

## Summary

**Automated Installation:**
```bash
./scripts/install.sh  # Does everything
```

**Manual Installation:**
1. Install system packages (gcc, meson, libnuma, etc.)
2. Install DPDK 23.11
3. Configure hugepages (1024 x 2MB)
4. Load kernel modules (vfio-pci)
5. Install Python packages (`pip3 install -r requirements.txt`)
6. Build engine (`make`)

**Total install time:** 15-30 minutes (automated)

---

For issues, see README.md or open a GitHub issue.
