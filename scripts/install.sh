#!/bin/bash

#
# NetGen Pro - DPDK Edition Installation Script
# Installs DPDK, dependencies, and sets up the environment
# FIXED: Proper hugepage detection + Python venv support + sudo handling
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
DPDK_VERSION="23.11"
VENV_DIR="$SCRIPT_DIR/venv"

# Detect the actual user (even if run with sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_UID=$(id -u "$SUDO_USER")
    ACTUAL_GID=$(id -g "$SUDO_USER")
else
    ACTUAL_USER="$USER"
    ACTUAL_UID=$(id -u)
    ACTUAL_GID=$(id -g)
fi

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - DPDK Edition Installer                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

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
echo "Install directory: $SCRIPT_DIR"
echo "Installing as user: $ACTUAL_USER"
echo ""

# Function to run command as actual user
run_as_user() {
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$ACTUAL_USER" "$@"
    else
        "$@"
    fi
}

# Function to ensure sudo is available
ensure_sudo() {
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            echo "❌ sudo not found. Please install sudo or run as root."
            exit 1
        fi
    fi
}

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
    
    ensure_sudo
    
    case $OS in
        ubuntu|debian)
            if [ "$EUID" -ne 0 ]; then
                sudo apt-get update
                sudo apt-get install -y \
                    build-essential \
                    meson \
                    ninja-build \
                    python3-pip \
                    python3-venv \
                    python3-pyelftools \
                    pkg-config \
                    libnuma-dev \
                    libpcap-dev \
                    linux-headers-$(uname -r) \
                    python3-dev \
                    git \
                    wget \
                    pciutils \
                    net-tools
            else
                apt-get update
                apt-get install -y \
                    build-essential \
                    meson \
                    ninja-build \
                    python3-pip \
                    python3-venv \
                    python3-pyelftools \
                    pkg-config \
                    libnuma-dev \
                    libpcap-dev \
                    linux-headers-$(uname -r) \
                    python3-dev \
                    git \
                    wget \
                    pciutils \
                    net-tools
            fi
            ;;
        centos|rhel|fedora)
            if [ "$EUID" -ne 0 ]; then
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
                    git \
                    wget \
                    pciutils \
                    net-tools
            else
                yum groupinstall -y "Development Tools"
                yum install -y \
                    meson \
                    ninja-build \
                    python3-pip \
                    python3-pyelftools \
                    pkg-config \
                    numactl-devel \
                    libpcap-devel \
                    kernel-devel \
                    python3-devel \
                    git \
                    wget \
                    pciutils \
                    net-tools
            fi
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
    if [ "$EUID" -ne 0 ]; then
        sudo ninja -C build install
        sudo ldconfig
    else
        ninja -C build install
        ldconfig
    fi
    
    echo "✅ DPDK installed"
    echo ""
}

# Function to setup hugepages
setup_hugepages() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Configuring hugepages..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    ensure_sudo
    
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
        if [ "$EUID" -ne 0 ]; then
            sudo mkdir -p /mnt/huge
            sudo mount -t hugetlbfs nodev /mnt/huge
        else
            mkdir -p /mnt/huge
            mount -t hugetlbfs nodev /mnt/huge
        fi
    fi
    
    # Allocate hugepages
    echo "Allocating 1024 hugepages..."
    if [ "$EUID" -ne 0 ]; then
        echo 1024 | sudo tee ${HUGEPAGE_DIR}/nr_hugepages
    else
        echo 1024 > ${HUGEPAGE_DIR}/nr_hugepages
    fi
    
    # Verify allocation
    sleep 1
    ALLOCATED=$(cat ${HUGEPAGE_DIR}/nr_hugepages 2>/dev/null || echo "0")
    echo "✅ Allocated $ALLOCATED hugepages"
    
    # Make hugepages persistent
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null; then
        echo "Making hugepages persistent..."
        if [ "$EUID" -ne 0 ]; then
            echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf
        else
            echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
        fi
    fi
    
    # Add to /etc/fstab if not present
    if ! grep -q "/mnt/huge" /etc/fstab 2>/dev/null; then
        if [ "$EUID" -ne 0 ]; then
            echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
        else
            echo "nodev /mnt/huge hugetlbfs defaults 0 0" >> /etc/fstab
        fi
    fi
    
    echo "✅ Hugepages configured"
    echo ""
}

# Function to load required kernel modules
load_kernel_modules() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Loading kernel modules..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    ensure_sudo
    
    # Load uio module
    if [ "$EUID" -ne 0 ]; then
        sudo modprobe uio || echo "  uio module already loaded or not available"
    else
        modprobe uio || echo "  uio module already loaded or not available"
    fi
    
    # Load vfio-pci (prefer this over igb_uio)
    if modinfo vfio-pci &>/dev/null; then
        echo "Loading vfio-pci..."
        if [ "$EUID" -ne 0 ]; then
            sudo modprobe vfio-pci
        else
            modprobe vfio-pci
        fi
    else
        echo "⚠️  vfio-pci not available"
    fi
    
    echo "✅ Kernel modules loaded"
    echo ""
}

# Function to setup Python virtual environment
setup_venv() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Setting up Python virtual environment..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$SCRIPT_DIR"
    
    # Create venv if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment at $VENV_DIR..."
        run_as_user python3 -m venv "$VENV_DIR"
        
        if [ $? -ne 0 ]; then
            echo ""
            echo "❌ Failed to create virtual environment"
            exit 1
        fi
        
        # Fix ownership if created as root
        if [ "$EUID" -eq 0 ]; then
            chown -R "$ACTUAL_UID:$ACTUAL_GID" "$VENV_DIR"
        fi
    else
        echo "Virtual environment already exists"
    fi
    
    echo "✅ Virtual environment ready"
    echo ""
}

# Function to install Python requirements
install_python_deps() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Installing Python dependencies..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$SCRIPT_DIR"
    
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        echo "Installing from requirements.txt..."
        run_as_user "$VENV_DIR/bin/pip" install --upgrade pip
        run_as_user "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    else
        echo "requirements.txt not found, installing core packages..."
        run_as_user "$VENV_DIR/bin/pip" install --upgrade pip
        run_as_user "$VENV_DIR/bin/pip" install flask flask-cors flask-socketio gevent netifaces psutil requests
    fi
    
    echo "✅ Python dependencies installed"
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
    
    # Build the DPDK engine as actual user
    run_as_user make clean
    run_as_user make
    
    # Fix ownership if built as root
    if [ "$EUID" -eq 0 ]; then
        chown -R "$ACTUAL_UID:$ACTUAL_GID" "$SCRIPT_DIR/build" 2>/dev/null || true
    fi
    
    echo "✅ NetGen Pro DPDK Engine built successfully"
    echo ""
}

# Function to create activation helper script
create_activation_script() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Creating activation helper script..."
    echo "═══════════════════════════════════════════════════════════════════"
    
    cat > "$SCRIPT_DIR/activate.sh" << 'EOF'
#!/bin/bash
# NetGen Pro - DPDK Edition
# Virtual environment activation script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
    echo "✅ Virtual environment activated"
    echo ""
    echo "To start NetGen Pro:"
    echo "  ./start.sh"
    echo ""
    echo "Or manually:"
    echo "  cd web"
    echo "  python dpdk_control_server.py --auto-start-engine"
    echo ""
    echo "To deactivate: deactivate"
else
    echo "❌ Virtual environment not found"
    echo "   Run ./scripts/install.sh first"
fi
EOF
    
    chmod +x "$SCRIPT_DIR/activate.sh"
    
    # Fix ownership if created as root
    if [ "$EUID" -eq 0 ]; then
        chown "$ACTUAL_UID:$ACTUAL_GID" "$SCRIPT_DIR/activate.sh"
    fi
    
    echo "✅ Created activate.sh helper script"
    echo ""
}

# Function to update start.sh to use venv
update_start_script() {
    echo "Updating start.sh to use virtual environment..."
    
    # Check if start.sh exists
    if [ ! -f "$SCRIPT_DIR/start.sh" ]; then
        echo "⚠️  start.sh not found, skipping update"
        return
    fi
    
    # Add venv activation to start.sh if not already present
    if ! grep -q "source.*venv/bin/activate" "$SCRIPT_DIR/start.sh"; then
        # Backup original
        cp "$SCRIPT_DIR/start.sh" "$SCRIPT_DIR/start.sh.bak"
        
        # Add venv activation after shebang and comments
        sed -i '/^SCRIPT_DIR=/i\
# Activate virtual environment\
if [ -f "$(dirname "$0")/venv/bin/activate" ]; then\
    source "$(dirname "$0")/venv/bin/activate"\
fi\
' "$SCRIPT_DIR/start.sh"
        
        echo "✅ Updated start.sh to use virtual environment"
    fi
}

# Main installation flow
main() {
    echo "This script will install:"
    echo "  • System dependencies"
    echo "  • DPDK $DPDK_VERSION"
    echo "  • Hugepages configuration"
    echo "  • Python virtual environment"
    echo "  • Python dependencies (in venv)"
    echo "  • NetGen Pro DPDK engine"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Check for existing DPDK installation
    if pkg-config --exists libdpdk 2>/dev/null; then
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
    setup_venv
    install_python_deps
    create_activation_script
    update_start_script
    build_generator
    setup_interfaces
    
    # Fix ownership of entire directory if run as root
    if [ "$EUID" -eq 0 ]; then
        echo "Fixing file ownership..."
        chown -R "$ACTUAL_UID:$ACTUAL_GID" "$SCRIPT_DIR"
    fi
    
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    Installation Complete!                          ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Python virtual environment created at: $VENV_DIR"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Activate the virtual environment:"
    echo "   source activate.sh"
    echo "   (or manually: source venv/bin/activate)"
    echo ""
    echo "2. Bind network interface to DPDK:"
    echo "   dpdk-devbind.py --status"
    echo "   sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>"
    echo ""
    echo "3. Start the web control server:"
    echo "   ./start.sh"
    echo "   (or manually: cd web && python dpdk_control_server.py --auto-start-engine)"
    echo ""
    echo "4. Access the web UI at:"
    echo "   http://localhost:8080"
    echo ""
    echo "For help, see README.md"
    echo ""
}

main
