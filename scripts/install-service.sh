#!/bin/bash
#
# NetGen Pro VEP1445 - Service Installer
# Installs systemd service for automatic startup
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root (use sudo)"
    exit 1
fi

# Detect installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     NetGen Pro VEP1445 - Systemd Service Installer                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo ""

# Check if service file exists
SERVICE_FILE="$INSTALL_DIR/config/netgen-pro-dpdk.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "⚠️  Service file not found, creating..."
    
    mkdir -p "$INSTALL_DIR/config"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=NetGen Pro DPDK Network Traffic Generator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStartPre=/bin/bash -c 'modprobe vfio-pci 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages'
ExecStart=/bin/bash $INSTALL_DIR/scripts/start.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ Service file created"
fi

# Install Python dependencies if needed
if [ ! -d "$INSTALL_DIR/venv" ]; then
    echo ""
    echo "📦 Setting up Python virtual environment..."
    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    echo "✅ Python environment ready"
fi

# Copy service file to systemd
echo ""
echo "📋 Installing systemd service..."
cp "$SERVICE_FILE" /etc/systemd/system/netgen-pro-dpdk.service

# Update paths in service file
sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|g" /etc/systemd/system/netgen-pro-dpdk.service
sed -i "s|ExecStart=.*|ExecStart=/bin/bash $INSTALL_DIR/scripts/start.sh|g" /etc/systemd/system/netgen-pro-dpdk.service

# Reload systemd
systemctl daemon-reload

echo "✅ Service installed successfully"
echo ""

# Ask about enabling on boot
read -p "Enable service to start on boot? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl enable netgen-pro-dpdk
    echo "✅ Service enabled for boot"
else
    echo "ℹ️  Service not enabled for boot"
    echo "   To enable later: sudo systemctl enable netgen-pro-dpdk"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start netgen-pro-dpdk"
echo "  Stop:    sudo systemctl stop netgen-pro-dpdk"
echo "  Status:  sudo systemctl status netgen-pro-dpdk"
echo "  Logs:    sudo journalctl -u netgen-pro-dpdk -f"
echo ""
echo "Web GUI will be available at: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
