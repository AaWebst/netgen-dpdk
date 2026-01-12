#!/bin/bash
#
# NetGen Pro - DPDK Edition
# Systemd Service Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="netgen-pro-dpdk.service"
INSTALL_DIR="/opt/netgen-dpdk"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     NetGen Pro - DPDK Edition Systemd Service Installer           ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    echo "   Please run: sudo bash install-service.sh"
    exit 1
fi

# Check if service file exists
if [ ! -f "$SCRIPT_DIR/$SERVICE_FILE" ]; then
    echo "❌ Service file not found: $SCRIPT_DIR/$SERVICE_FILE"
    exit 1
fi

# Check if installation directory is /opt/netgen-dpdk
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    echo "⚠️  Installation directory is: $SCRIPT_DIR"
    echo "   Service file expects: $INSTALL_DIR"
    echo ""
    read -p "Continue and update paths? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Update paths in service file
    echo "Updating paths in service file..."
    sed -i "s|/opt/netgen-dpdk|$SCRIPT_DIR|g" "$SCRIPT_DIR/$SERVICE_FILE"
fi

# Check prerequisites
echo "Checking prerequisites..."

# Check Python venv
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "❌ Virtual environment not found at: $SCRIPT_DIR/venv"
    echo ""
    echo "Please run installation first:"
    echo "  sudo bash scripts/install.sh"
    echo "  OR"
    echo "  sudo bash quick-setup-venv.sh"
    exit 1
fi

# Check DPDK engine
if [ ! -f "$SCRIPT_DIR/build/dpdk_engine" ]; then
    echo "⚠️  DPDK engine not found at: $SCRIPT_DIR/build/dpdk_engine"
    echo ""
    read -p "Continue anyway? (service will fail until engine is built) (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        echo ""
        echo "Build the engine first:"
        echo "  cd $SCRIPT_DIR"
        echo "  make"
        exit 0
    fi
fi

# Check control server
if [ ! -f "$SCRIPT_DIR/web/dpdk_control_server.py" ]; then
    echo "❌ Control server not found at: $SCRIPT_DIR/web/dpdk_control_server.py"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Stop existing service if running
if systemctl is-active --quiet netgen-pro-dpdk 2>/dev/null; then
    echo "Stopping existing service..."
    systemctl stop netgen-pro-dpdk
fi

# Install service file
echo "Installing systemd service..."
cp "$SCRIPT_DIR/$SERVICE_FILE" /etc/systemd/system/

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service
echo "Enabling service to start on boot..."
systemctl enable netgen-pro-dpdk

echo ""
echo "✅ Service installed successfully!"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Service Management Commands:"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Start service:"
echo "  sudo systemctl start netgen-pro-dpdk"
echo ""
echo "Stop service:"
echo "  sudo systemctl stop netgen-pro-dpdk"
echo ""
echo "Restart service:"
echo "  sudo systemctl restart netgen-pro-dpdk"
echo ""
echo "Check status:"
echo "  sudo systemctl status netgen-pro-dpdk"
echo ""
echo "View logs:"
echo "  sudo journalctl -u netgen-pro-dpdk -f"
echo ""
echo "Disable auto-start:"
echo "  sudo systemctl disable netgen-pro-dpdk"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ask if user wants to start now
read -p "Start service now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "Starting service..."
    systemctl start netgen-pro-dpdk
    sleep 2
    
    if systemctl is-active --quiet netgen-pro-dpdk; then
        echo ""
        echo "✅ Service started successfully!"
        echo ""
        echo "Access NetGen Pro at:"
        echo "  http://localhost:8080"
        echo "  http://$(hostname -I | awk '{print $1}'):8080"
        echo ""
        echo "Check status:"
        echo "  sudo systemctl status netgen-pro-dpdk"
        echo ""
    else
        echo ""
        echo "❌ Service failed to start"
        echo ""
        echo "Check logs with:"
        echo "  sudo journalctl -u netgen-pro-dpdk -n 50"
        echo ""
    fi
else
    echo ""
    echo "Service installed but not started"
    echo "Start it manually with:"
    echo "  sudo systemctl start netgen-pro-dpdk"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════════"
echo "Service will now start automatically on boot"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
