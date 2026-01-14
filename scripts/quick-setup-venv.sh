#!/bin/bash
#
# Quick Virtual Environment Setup
# Use this if you already ran install.sh but venv is missing
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Quick Virtual Environment Setup                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check Python3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found"
    echo "   Install with: sudo apt-get install python3 python3-venv python3-pip"
    exit 1
fi

# Create venv
if [ -d "$VENV_DIR" ]; then
    echo "⚠️  Virtual environment already exists at: $VENV_DIR"
    read -p "Delete and recreate? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VENV_DIR"
    else
        echo "Cancelled"
        exit 0
    fi
fi

echo "Creating virtual environment..."
python3 -m venv "$VENV_DIR"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    echo ""
    echo "Try installing python3-venv:"
    echo "  sudo apt-get install python3-venv"
    exit 1
fi

echo "✅ Virtual environment created"
echo ""

# Activate and install dependencies
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
pip install --upgrade pip

# Install from requirements.txt if it exists
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    pip install -r "$SCRIPT_DIR/requirements.txt"
else
    echo "Installing core packages..."
    pip install Flask==3.0.0 Flask-CORS==4.0.0 Flask-SocketIO==5.3.5 \
                python-socketio==5.10.0 python-engineio==4.8.0 \
                gevent==23.9.1 gevent-websocket==0.10.1 \
                requests==2.31.0 netifaces==0.11.0 psutil==5.9.6
fi

echo ""
echo "✅ Virtual environment ready!"
echo ""
echo "To activate manually:"
echo "  source venv/bin/activate"
echo ""
echo "To start NetGen Pro:"
echo "  ./start.sh"
echo ""
