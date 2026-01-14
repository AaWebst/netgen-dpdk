#!/bin/bash
#
# NetGen Pro VEP1445 - Complete Installation Script
# Run this first after cloning the repository
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root (use sudo)"
    exit 1
fi

# Detect installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     NetGen Pro VEP1445 - Complete Installation                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo ""

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for DPDK
if ! dpkg -l | grep -q dpdk-dev; then
    echo "⚠️  DPDK not found, installing..."
    apt-get update
    apt-get install -y dpdk dpdk-dev
    echo "✅ DPDK installed"
else
    echo "✅ DPDK already installed"
fi

# Check for build tools
if ! command -v g++ &> /dev/null; then
    echo "⚠️  Build tools not found, installing..."
    apt-get install -y build-essential
    echo "✅ Build tools installed"
else
    echo "✅ Build tools already installed"
fi

# Check for json-c
if ! dpkg -l | grep -q libjson-c-dev; then
    echo "⚠️  libjson-c-dev not found, installing..."
    apt-get install -y libjson-c-dev
    echo "✅ libjson-c-dev installed"
else
    echo "✅ libjson-c-dev already installed"
fi

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found, installing..."
    apt-get install -y python3 python3-pip python3-venv
    echo "✅ Python 3 installed"
else
    echo "✅ Python 3 already installed"
fi

echo ""

# Step 2: Build DPDK engine
echo "Step 2: Building DPDK engine..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "$INSTALL_DIR"
make clean
make

if [ ! -f "$INSTALL_DIR/build/dpdk_engine" ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ DPDK engine built successfully"
echo ""

# Step 3: Setup Python environment
echo "Step 3: Setting up Python environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$INSTALL_DIR/scripts/quick-setup-venv.sh"
echo ""

# Step 4: Configure DPDK interfaces (optional)
echo "Step 4: Configure DPDK interfaces"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Configure DPDK interfaces now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash "$INSTALL_DIR/scripts/configure-vep1445-basic.sh"
else
    echo "ℹ️  Skipping interface configuration"
    echo "   Run later: sudo bash scripts/configure-vep1445-basic.sh"
fi
echo ""

# Step 5: Install systemd service
echo "Step 5: Install systemd service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$INSTALL_DIR/scripts/install-service.sh"
echo ""

# Step 6: Final summary
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Installation directory: $INSTALL_DIR"
echo "🔨 DPDK engine: build/dpdk_engine"
echo "🐍 Python venv: venv/"
echo "⚙️  Service: netgen-pro-dpdk.service"
echo ""
echo "🚀 Quick Start:"
echo "  1. Start service:  sudo systemctl start netgen-pro-dpdk"
echo "  2. Check status:   sudo systemctl status netgen-pro-dpdk"
echo "  3. View logs:      sudo journalctl -u netgen-pro-dpdk -f"
echo "  4. Open GUI:       http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "📚 Documentation: $INSTALL_DIR/docs/"
echo ""
echo "✨ NetGen Pro VEP1445 is ready to use!"
echo ""
