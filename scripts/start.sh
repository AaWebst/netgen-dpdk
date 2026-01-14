#!/bin/bash
#
# NetGen Pro VEP1445 - Manual Start Script
#

# Detect installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro VEP1445 - Starting Server                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo ""

# Check for virtual environment
if [ ! -d "$INSTALL_DIR/venv" ]; then
    echo "❌ Virtual environment not found at: $INSTALL_DIR/venv"
    echo ""
    echo "Please run installation first:"
    echo "  sudo bash $SCRIPT_DIR/install-service.sh"
    exit 1
fi

# Activate virtual environment
source "$INSTALL_DIR/venv/bin/activate"

# Check if DPDK engine is built
if [ ! -f "$INSTALL_DIR/build/dpdk_engine" ]; then
    echo "⚠️  DPDK engine not built"
    echo "Building now..."
    cd "$INSTALL_DIR"
    make
    if [ $? -ne 0 ]; then
        echo "❌ Build failed"
        exit 1
    fi
fi

# Start the control server
echo "🚀 Starting NetGen Pro control server..."
echo ""
cd "$INSTALL_DIR/web"
python3 server.py
