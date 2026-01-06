#!/bin/bash

#
# NetGen Pro - DPDK Edition Installation Script
# Installs DPDK, dependencies, and sets up the environment
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DPDK_VERSION="23.11"
HUGEPAGE_SIZE="2M"
NUM_HUGEPAGES=1024

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
    
    # Mount hugepages if not already mounted
    if ! mount | grep -q hugetlbfs; then
        echo "Mounting hugetlbfs..."
        sudo mkdir -p /mnt/huge
        sudo mount -t hugetlbfs nodev /mnt/huge
    fi
    
    # Allocate hugepages
    echo "Allocating $NUM_HUGEPAGES hugepages..."
    echo $NUM_HUGEPAGES | sudo tee /sys/kernel/mm/hugepages/hugepages-${HUGEPAGE_SIZE}/nr_hugepages
    
    # Make hugepages persistent
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
        echo "Making hugepages persistent..."
        echo "vm.nr_hugepages = $NUM_HUGEPAGES" | sudo tee -a /etc/sysctl.conf
    fi
    
    # Add to /etc/fstab if not present
    if ! grep -q "/mnt/huge" /etc/fstab; then
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
    sudo modprobe uio
    
    # Load igb_uio or vfio-pci (prefer vfio-pci for better security)
    if modinfo vfio-pci &>/dev/null; then
        echo "Loading vfio-pci..."
        sudo modprobe vfio-pci
    else
        echo "vfio-pci not available, would need igb_uio"
        echo "For production, compile igb_uio from DPDK sources"
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
    lspci | grep -i ethernet
    echo ""
    
    echo "⚠️  IMPORTANT: To bind interfaces to DPDK, use:"
    echo "   sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>"
    echo ""
    echo "   To see interface status:"
    echo "   dpdk-devbind.py --status"
    echo ""
    echo "   Example:"
    echo "   sudo dpdk-devbind.py --bind=vfio-pci 0000:03:00.0"
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

# Function to create systemd service (optional)
create_service() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Creating systemd service (optional)..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    cat > /tmp/netgen-dpdk.service << EOF
[Unit]
Description=NetGen Pro DPDK Control Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR/web
ExecStart=/usr/bin/python3 $SCRIPT_DIR/web/dpdk_control_server.py --host 0.0.0.0 --port 8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/netgen-dpdk.service /etc/systemd/system/
    sudo systemctl daemon-reload
    
    echo "Service created. To enable:"
    echo "  sudo systemctl enable netgen-dpdk"
    echo "  sudo systemctl start netgen-dpdk"
    echo ""
}

# Function to install Python requirements
install_python_deps() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Installing Python dependencies..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    pip3 install --user flask flask-cors flask-socketio gevent
    
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
    
    setup_hugepages
    load_kernel_modules
    install_python_deps
    build_generator
    setup_interfaces
    
    # Optional service installation
    read -p "Create systemd service? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_service
    fi
    
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
    echo "2. Start the DPDK engine manually:"
    echo "   sudo ./build/dpdk_engine -l 0-3 -n 4"
    echo ""
    echo "3. Or start the web control server:"
    echo "   cd web"
    echo "   python3 dpdk_control_server.py --auto-start-engine"
    echo ""
    echo "4. Access the web UI at:"
    echo "   http://localhost:8080"
    echo ""
    echo "For help, see README.md or visit the documentation"
    echo ""
}

main
