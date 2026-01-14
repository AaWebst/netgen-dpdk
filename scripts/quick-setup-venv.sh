#!/bin/bash
#
# NetGen Pro VEP1445 - Quick Python Environment Setup
#

# Detect installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     NetGen Pro VEP1445 - Python Environment Setup                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Not running as root - virtual environment will be created for current user"
fi

# Create virtual environment
echo "📦 Creating Python virtual environment..."
cd "$INSTALL_DIR"

if [ -d "venv" ]; then
    echo "⚠️  Virtual environment already exists at: $INSTALL_DIR/venv"
    read -p "Remove and recreate? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf venv
    else
        echo "ℹ️  Keeping existing virtual environment"
        exit 0
    fi
fi

python3 -m venv venv
if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    echo "Install python3-venv: sudo apt-get install python3-venv"
    exit 1
fi

echo "✅ Virtual environment created"
echo ""

# Activate and install dependencies
echo "📥 Installing Python dependencies..."
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    deactivate
    exit 1
fi

deactivate

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Virtual environment: $INSTALL_DIR/venv"
echo ""
echo "Next steps:"
echo "  1. Build DPDK engine:     make"
echo "  2. Configure interfaces:  sudo bash scripts/configure-vep1445-basic.sh"
echo "  3. Install service:       sudo bash scripts/install-service.sh"
echo "  4. Start server:          sudo systemctl start netgen-pro-dpdk"
echo ""
