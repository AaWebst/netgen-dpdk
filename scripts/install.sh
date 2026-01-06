#!/bin/bash

#
# NetGen Pro - DPDK Edition Installation Script
# Installs DPDK, dependencies, and sets up the environment
# FIXED: Proper hugepage directory detection for all systems
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
DPDK_VERSION="23.11"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - DPDK Edition Installer                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Please run this script as a regular user (not root)"
    echo "   The script will use sudo when necessary"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Unable to detect OS"
    exit 1
fi

echo "Detected OS: $OS $VERSION"
echo ""

# Function to detect hugepage directory
detect_hugepage_dir() {
    echo "Detecting hugepage directory..."
    
    # Check for different possible paths
    if [ -d "/sys/kernel/mm/hugepages/hugepages-2048kB" ]; then
        HUGEPAGE_DIR="/sys/kernel/mm/hugepages/hugepages-2048kB"
        HUGEPAGE_SIZE="2048kB"
        echo "✅ Found: $HUGEPAGE_DIR"
        return 0
    elif [ -d "/sys/kernel/mm/hugepages/hugepages-2M" ]; then
        HUGEPAGE_DIR="/sys/kernel/mm/hugepages/hugepages-2M"
        HUGEPAGE_SIZE="2M"
        echo "✅ Found: $HUGEPAGE_DIR"
        return 0
    elif [ -d "/sys/devices/system/node/node0/hugepages/hugepages-2048kB" ]; then
        HUGEPAGE_DIR="/sys/devices/system/node/node0/hugepages/hugepages-2048kB"
        HUGEPAGE_SIZE="2048kB"
        echo "✅ Found: $HUGEPAGE_DIR (NUMA node path)"
        return 0
    else
        echo "❌ Could not find hugepage directory"
        echo "Available hugepage info:"
        ls -la /sys/kernel/mm/hugepages/ 2>/dev/null || echo "  /sys/kernel/mm/hugepages/ not found"
        ls -la /sys/devices/system/node/node0/hugepages/ 2>/dev/null || echo "  NUMA hugepages not found"
        return 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Installing system dependencies..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                meson \
                ninja-build \
                python3-pip \
                python3-pyelftools \
                pkg-config \
                libnuma-dev \
                libpcap-dev \
                linux-headers-$(uname -r) \
                python3-dev \
                python3-flask \
                python3-flask-cors \
                python3-flask-socketio \
                git \
                wget \
                pciutils \
                net-tools
            ;;
        centos|rhel|fedora)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                meson \
                ninja-build \
                python3-pip \
                python3-pyelftools \
                pkg-config \
                numactl-devel \
                libpcap-devel \
                kernel-devel \
                python3-devel \
                python3-flask \
                git \
                wget \
                pciutils \
                net-tools
            
            # Install Flask extensions via pip
            pip3 install flask-cors flask-socketio
            ;;
        *)
            echo "❌ Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    echo "✅ Dependencies installed"
    echo ""
}

# Function to install DPDK
install_dpdk() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Installing DPDK $DPDK_VERSION..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    DPDK_DIR="/tmp/dpdk-$DPDK_VERSION"
    
    # Download DPDK if not already present
    if [ ! -d "$DPDK_DIR" ]; then
        echo "Downloading DPDK $DPDK_VERSION..."
        cd /tmp
        wget -q --show-progress https://fast.dpdk.org/rel/dpdk-$DPDK_VERSION.tar.xz
        tar xf dpdk-$DPDK_VERSION.tar.xz
        rm dpdk-$DPDK_VERSION.tar.xz
    fi
    
    cd "$DPDK_DIR"
    
    # Configure DPDK
    echo "Configuring DPDK..."
    meson setup build
    
    # Build DPDK
    echo "Building DPDK (this may take several minutes)..."
    ninja -C build
    
    # Install DPDK
    echo "Installing DPDK..."
    sudo ninja -C build install
    
    # Update library cache
    sudo ldconfig
    
    echo "✅ DPDK installed"
    echo ""
}

# Function to setup hugepages
setup_hugepages() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Configuring hugepages..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Detect hugepage directory first
    if ! detect_hugepage_dir; then
        echo ""
        echo "❌ Cannot configure hugepages - directory not found"
        echo "   Please configure manually using the fix-hugepages.sh script"
        return 1
    fi
    
    # Mount hugepages if not already mounted
    if ! mount | grep -q hugetlbfs; then
        echo "Mounting hugetlbfs..."
        sudo mkdir -p /mnt/huge
        sudo mount -t hugetlbfs nodev /mnt/huge
    fi
    
    # Allocate hugepages
    echo "Allocating 1024 hugepages..."
    echo 1024 | sudo tee ${HUGEPAGE_DIR}/nr_hugepages
    
    # Verify allocation
    sleep 1
    ALLOCATED=$(cat ${HUGEPAGE_DIR}/nr_hugepages 2>/dev/null || echo "0")
    echo "✅ Allocated $ALLOCATED hugepages"
    
    # Make hugepages persistent
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null; then
        echo "Making hugepages persistent..."
        echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf
    fi
    
    # Add to /etc/fstab if not present
    if ! grep -q "/mnt/huge" /etc/fstab 2>/dev/null; then
        echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
    fi
    
    echo "✅ Hugepages configured"
    echo ""
}

# Function to load required kernel modules
load_kernel_modules() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Loading kernel modules..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Load uio module
    sudo modprobe uio || echo "  uio module already loaded or not available"
    
    # Load vfio-pci (prefer this over igb_uio)
    if modinfo vfio-pci &>/dev/null; then
        echo "Loading vfio-pci..."
        sudo modprobe vfio-pci
    else
        echo "⚠️  vfio-pci not available"
    fi
    
    echo "✅ Kernel modules loaded"
    echo ""
}

# Function to setup network interfaces
setup_interfaces() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Network Interface Information"
    echo "═══════════════════════════════════════════════════════════════════"
    
    echo "Available network interfaces:"
    lspci | grep -i ethernet || echo "  No ethernet devices found via lspci"
    echo ""
    
    echo "⚠️  IMPORTANT: To bind interfaces to DPDK, use:"
    echo "   sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>"
    echo ""
    echo "   To see interface status:"
    echo "   dpdk-devbind.py --status"
    echo ""
}

# Function to build the packet generator
build_generator() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Building NetGen Pro DPDK Engine..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$SCRIPT_DIR"
    
    # Build the DPDK engine
    make clean
    make
    
    echo "✅ NetGen Pro DPDK Engine built successfully"
    echo ""
}

# Function to install Python requirements
install_python_deps() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Installing Python dependencies..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        echo "Installing from requirements.txt..."
        pip3 install --user -r "$SCRIPT_DIR/requirements.txt"
    else
        echo "requirements.txt not found, installing core packages..."
        pip3 install --user flask flask-cors flask-socketio gevent netifaces psutil requests
    fi
    
    echo "✅ Python dependencies installed"
    echo ""
}

# Main installation flow
main() {
    echo "This script will install:"
    echo "  • System dependencies"
    echo "  • DPDK $DPDK_VERSION"
    echo "  • Hugepages configuration"
    echo "  • Python dependencies"
    echo "  • NetGen Pro DPDK engine"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Check for existing DPDK installation
    if pkg-config --exists libdpdk; then
        echo "✅ DPDK already installed: $(pkg-config --modversion libdpdk)"
        read -p "Skip DPDK installation? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            SKIP_DPDK=1
        fi
    fi
    
    # Run installation steps
    install_dependencies
    
    if [ -z "$SKIP_DPDK" ]; then
        install_dpdk
    fi
    
    setup_hugepages || echo "⚠️  Hugepage setup failed - use fix-hugepages.sh to configure manually"
    load_kernel_modules
    install_python_deps
    build_generator
    setup_interfaces
    
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    Installation Complete!                          ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Bind network interface to DPDK:"
    echo "   dpdk-devbind.py --status"
    echo "   sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>"
    echo ""
    echo "2. Start the web control server:"
    echo "   cd web"
    echo "   python3 dpdk_control_server.py --auto-start-engine"
    echo ""
    echo "3. Access the web UI at:"
    echo "   http://localhost:8080"
    echo ""
    echo "For help, see README.md or run fix-hugepages.sh if needed"
    echo ""
}

main
