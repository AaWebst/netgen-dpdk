#!/bin/bash
################################################################################
# Setup Auto-Bind DPDK Ports at Boot
# Creates systemd service to bind DPDK ports automatically on system startup
################################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Setup Auto-Bind DPDK Ports at Boot                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Error: Run as root"
    exit 1
fi

# Copy binding script to /usr/local/bin
echo "▶ Installing bind script..."
cp bind_dpdk_ports.sh /usr/local/bin/bind-dpdk-ports
chmod +x /usr/local/bin/bind-dpdk-ports
echo "  ✓ Installed to /usr/local/bin/bind-dpdk-ports"
echo ""

# Create systemd service
echo "▶ Creating systemd service..."

cat > /etc/systemd/system/dpdk-bind-ports.service << 'EOF'
[Unit]
Description=Bind Network Ports to DPDK
After=network.target
Before=netgen-pro-dpdk.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bind-dpdk-ports
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "  ✓ Service file created"
echo ""

# Reload systemd
echo "▶ Reloading systemd..."
systemctl daemon-reload
echo "  ✓ Reloaded"
echo ""

# Enable service
echo "▶ Enabling service to run at boot..."
systemctl enable dpdk-bind-ports.service
echo "  ✓ Service enabled"
echo ""

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Setup Complete                                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "DPDK ports will now bind automatically at boot!"
echo ""
echo "Manual commands:"
echo "  Start now:    sudo systemctl start dpdk-bind-ports"
echo "  Check status: sudo systemctl status dpdk-bind-ports"
echo "  View logs:    sudo journalctl -u dpdk-bind-ports"
echo "  Disable:      sudo systemctl disable dpdk-bind-ports"
echo ""
echo "To bind ports right now:"
echo "  sudo systemctl start dpdk-bind-ports"
echo ""
