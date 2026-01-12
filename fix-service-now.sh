#!/bin/bash
#
# Quick fix for systemd service file
#

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - Service Fix Script                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    echo "   Run: sudo bash fix-service-now.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1. Stopping service..."
systemctl stop netgen-pro-dpdk 2>/dev/null || true

echo "2. Backing up old service file..."
if [ -f /etc/systemd/system/netgen-pro-dpdk.service ]; then
    cp /etc/systemd/system/netgen-pro-dpdk.service /etc/systemd/system/netgen-pro-dpdk.service.backup
fi

echo "3. Installing fixed service file..."
cp "$SCRIPT_DIR/netgen-pro-dpdk.service" /etc/systemd/system/

echo "4. Reloading systemd..."
systemctl daemon-reload

echo "5. Starting service..."
systemctl start netgen-pro-dpdk

sleep 2

echo ""
echo "═══════════════════════════════════════════════════════════════════"
if systemctl is-active --quiet netgen-pro-dpdk; then
    echo "✅ Service started successfully!"
    echo ""
    systemctl status netgen-pro-dpdk --no-pager -l | head -15
    echo ""
    echo "Access NetGen Pro at: http://localhost:8080"
else
    echo "❌ Service failed to start"
    echo ""
    echo "Checking logs..."
    journalctl -u netgen-pro-dpdk -n 20 --no-pager
    echo ""
    echo "Common issues:"
    echo "  1. Virtual environment missing: sudo bash quick-setup-venv.sh"
    echo "  2. Flask not installed: source venv/bin/activate && pip install -r requirements.txt"
    echo "  3. Template missing: ls web/templates/index.html"
fi
echo "═══════════════════════════════════════════════════════════════════"
