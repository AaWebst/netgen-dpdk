#!/bin/bash
#
# NetGen Pro - DPDK Edition Startup Script
# Starts the web control server with proper venv activation
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
WEB_DIR="$SCRIPT_DIR/web"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - DPDK Edition v2.0                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found at: $VENV_DIR"
    echo ""
    echo "Please run installation first:"
    echo "  sudo bash scripts/install.sh"
    echo ""
    exit 1
fi

# Check if venv activate script exists
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "❌ Virtual environment corrupted (missing activate script)"
    echo ""
    echo "Please reinstall:"
    echo "  sudo bash scripts/install.sh"
    echo ""
    exit 1
fi

# Check if Flask is installed in venv
if ! "$VENV_DIR/bin/python" -c "import flask" 2>/dev/null; then
    echo "❌ Flask not installed in virtual environment"
    echo ""
    echo "Installing dependencies..."
    "$VENV_DIR/bin/pip" install -q --upgrade pip
    
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        echo "Installing from requirements.txt..."
        "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    else
        echo "Installing core packages..."
        "$VENV_DIR/bin/pip" install flask flask-cors flask-socketio gevent netifaces psutil requests
    fi
    
    echo "✅ Dependencies installed"
    echo ""
fi

# Check if DPDK engine exists
if [ ! -f "$SCRIPT_DIR/build/dpdk_engine" ]; then
    echo "⚠️  DPDK engine not found at: $SCRIPT_DIR/build/dpdk_engine"
    echo ""
    echo "Building DPDK engine..."
    cd "$SCRIPT_DIR"
    make clean && make
    echo ""
fi

# Check if running as root (required for DPDK)
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  NetGen Pro requires root privileges to access DPDK"
    echo ""
    echo "Restarting with sudo..."
    exec sudo "$0" "$@"
fi

# Activate virtual environment
echo "🚀 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Change to web directory
cd "$WEB_DIR"

# Start the server
echo "🌐 Starting web server..."
echo ""
echo "Access NetGen Pro at:"
echo "  • Local:   http://localhost:8080"
echo "  • Network: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Press Ctrl+C to stop"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Run the control server
python dpdk_control_server.py
