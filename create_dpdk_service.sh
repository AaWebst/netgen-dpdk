#!/bin/bash
################################################################################
# Create Systemd Service for DPDK Engine Auto-Start
################################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Creating DPDK Engine Systemd Service                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Error: Run as root"
    exit 1
fi

cd /opt/netgen-dpdk

# Create systemd service file
echo "▶ Creating systemd service..."

cat > /etc/systemd/system/dpdk-engine.service << 'EOF'
[Unit]
Description=NetGen DPDK Packet Engine
After=network.target dpdk-bind-ports.service
Requires=dpdk-bind-ports.service

[Service]
Type=simple
WorkingDirectory=/opt/netgen-dpdk
ExecStart=/opt/netgen-dpdk/build/dpdk_engine -l 0-3 -n 4 -- -p 0x7f
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Resource limits
LimitMEMLOCK=infinity
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "  ✓ Service file created: /etc/systemd/system/dpdk-engine.service"
echo ""

# Reload systemd
echo "▶ Reloading systemd..."
systemctl daemon-reload
echo "  ✓ Reloaded"
echo ""

# Enable service
echo "▶ Enabling DPDK engine to start on boot..."
systemctl enable dpdk-engine.service
echo "  ✓ Service enabled"
echo ""

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Service Created Successfully                              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Commands:"
echo "  Start now:     sudo systemctl start dpdk-engine"
echo "  Stop:          sudo systemctl stop dpdk-engine"
echo "  Restart:       sudo systemctl restart dpdk-engine"
echo "  Status:        sudo systemctl status dpdk-engine"
echo "  View logs:     sudo journalctl -u dpdk-engine -f"
echo "  Disable:       sudo systemctl disable dpdk-engine"
echo ""
echo "The DPDK engine will now start automatically on boot!"
echo ""
