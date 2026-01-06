#!/bin/bash

#
# NetGen Pro - DPDK Edition Quick Start
# Simple script to get up and running quickly
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate virtual environment if it exists
if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
fi

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - DPDK Edition Quick Start                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if already installed
if [ ! -f "$SCRIPT_DIR/build/dpdk_engine" ]; then
    echo "❌ DPDK engine not built. Run installation first:"
    echo "   ./scripts/install.sh"
    exit 1
fi

# Check if DPDK is installed
if ! pkg-config --exists libdpdk; then
    echo "❌ DPDK not installed. Run installation first:"
    echo "   ./scripts/install.sh"
    exit 1
fi

# Check for hugepages
HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
if [ "$HUGEPAGES" -lt 512 ]; then
    echo "⚠️  Warning: Only $HUGEPAGES hugepages allocated (recommended: 1024)"
    echo "   Allocating hugepages..."
    echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
fi

# Check for DPDK-bound interfaces
echo "Checking for DPDK-bound interfaces..."
DPDK_DEVS=$(dpdk-devbind.py --status | grep "drv=vfio-pci\|drv=igb_uio" | wc -l)

if [ "$DPDK_DEVS" -eq 0 ]; then
    echo ""
    echo "⚠️  No DPDK-bound interfaces found!"
    echo ""
    echo "Available interfaces:"
    dpdk-devbind.py --status | grep "Network devices"  -A 10
    echo ""
    echo "To bind an interface:"
    echo "  1. Bring it down: sudo ifconfig <interface> down"
    echo "  2. Bind to DPDK: sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Ask user what they want to do
echo ""
echo "What would you like to do?"
echo ""
echo "  1) Start web interface (with auto-start DPDK engine)"
echo "  2) Start web interface only (manual DPDK engine)"
echo "  3) Start DPDK engine only (no web interface)"
echo "  4) Show network interface status"
echo "  5) Exit"
echo ""
read -p "Choice [1-5]: " choice

case $choice in
    1)
        echo ""
        echo "Starting web interface with auto-start DPDK engine..."
        echo "Access at: http://localhost:8080"
        echo ""
        cd "$SCRIPT_DIR/web"
        python3 dpdk_control_server.py --auto-start-engine --host 0.0.0.0 --port 8080
        ;;
    2)
        echo ""
        echo "Starting web interface (you need to start DPDK engine separately)..."
        echo "Access at: http://localhost:8080"
        echo ""
        cd "$SCRIPT_DIR/web"
        python3 dpdk_control_server.py --host 0.0.0.0 --port 8080
        ;;
    3)
        echo ""
        echo "Starting DPDK engine..."
        echo "Using cores 0-3, 4 memory channels"
        echo ""
        sudo "$SCRIPT_DIR/build/dpdk_engine" -l 0-3 -n 4 --proc-type primary
        ;;
    4)
        echo ""
        dpdk-devbind.py --status
        echo ""
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
