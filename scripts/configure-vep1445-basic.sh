#!/bin/bash
#
# VEP1445 Basic Configuration
# Sets up: eno1 (management) + eno7/eno8 (DPDK loopback)
#

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          VEP1445 Basic Configuration                              ║"
echo "║          Management + 10G Loopback                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Configure management interface
echo "Step 1: Configuring eno1 (management) for DHCP..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /etc/netplan/01-netcfg.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: true
      dhcp6: false
      optional: false
EOF

netplan apply
sleep 3

# Get management IP
MGMT_IP=$(ip -4 addr show eno1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

if [ -z "$MGMT_IP" ]; then
    echo "⚠️  Warning: Could not get DHCP address on eno1"
    echo "   Management interface may not be connected to DHCP network"
    MGMT_IP="<DHCP_PENDING>"
else
    echo "✅ Management IP: $MGMT_IP"
fi

echo ""

# Step 2: Get PCI addresses
echo "Step 2: Getting PCI addresses for eno7 and eno8..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ENO7_PCI=$(ethtool -i eno7 2>/dev/null | grep "bus-info" | awk '{print $2}')
ENO8_PCI=$(ethtool -i eno8 2>/dev/null | grep "bus-info" | awk '{print $2}')

if [ -z "$ENO7_PCI" ] || [ -z "$ENO8_PCI" ]; then
    echo "❌ Error: Could not find eno7 or eno8"
    echo "   Available interfaces:"
    ip link show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/:$//'
    exit 1
fi

echo "eno7 PCI: $ENO7_PCI"
echo "eno8 PCI: $ENO8_PCI"
echo ""

# Step 3: Bind to DPDK
echo "Step 3: Binding eno7 and eno8 to DPDK (vfio-pci)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Load vfio-pci module
modprobe vfio-pci 2>/dev/null

# Bring interfaces down
ip link set eno7 down 2>/dev/null
ip link set eno8 down 2>/dev/null

# Bind to DPDK
dpdk-devbind.py --bind=vfio-pci $ENO7_PCI
if [ $? -eq 0 ]; then
    echo "✅ eno7 bound to DPDK"
else
    echo "❌ Failed to bind eno7"
    exit 1
fi

dpdk-devbind.py --bind=vfio-pci $ENO8_PCI
if [ $? -eq 0 ]; then
    echo "✅ eno8 bound to DPDK"
else
    echo "❌ Failed to bind eno8"
    exit 1
fi

echo ""

# Step 4: Create configuration file
echo "Step 4: Creating configuration file..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p /opt/netgen-pro-complete

cat > /opt/netgen-pro-complete/vep1445-config.json << EOF
{
  "deployment": "basic-loopback",
  "hostname": "$(hostname)",
  "configured_at": "$(date -Iseconds)",
  "management": {
    "interface": "eno1",
    "ip": "$MGMT_IP",
    "description": "Management interface (Linux kernel, DHCP)"
  },
  "dpdk": {
    "tx_port": {
      "interface": "eno7",
      "pci": "$ENO7_PCI",
      "port_id": 0,
      "speed": "10G",
      "description": "Primary TX port - Connect to LAN1"
    },
    "rx_port": {
      "interface": "eno8",
      "pci": "$ENO8_PCI",
      "port_id": 1,
      "speed": "10G",
      "description": "Primary RX port - Connect to LAN2"
    }
  },
  "available_ports": {
    "eno2": "1G - Available (not bound)",
    "eno3": "1G - Available (not bound)",
    "eno4": "1G - Available (not bound)",
    "eno5": "1G - Available (not bound)",
    "eno6": "1G - Available (not bound)"
  }
}
EOF

echo "✅ Configuration saved to /opt/netgen-pro-complete/vep1445-config.json"
echo ""

# Step 5: Show status
echo "Step 5: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
dpdk-devbind.py --status-dev net | head -40
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Complete!                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Summary:"
echo "  • Management: eno1 → $MGMT_IP (DHCP)"
echo "  • DPDK TX:    eno7 → $ENO7_PCI (port 0)"
echo "  • DPDK RX:    eno8 → $ENO8_PCI (port 1)"
echo "  • Available:  eno2, eno3, eno4, eno5, eno6 (not bound)"
echo ""
echo "🔌 Physical Connections Needed:"
echo "  1. eno1 → Management network (for accessing GUI)"
echo "  2. eno7 → LAN1 switch port (TX)"
echo "  3. eno8 → LAN2 switch port (RX)"
echo ""
echo "🌐 Access NetGen Pro GUI:"
if [ "$MGMT_IP" != "<DHCP_PENDING>" ]; then
    echo "  http://$MGMT_IP:8080"
else
    echo "  http://<check eno1 IP>:8080"
    echo "  (Check IP with: ip addr show eno1)"
fi
echo ""
echo "🚀 Next Steps:"
echo "  1. Connect cables as shown above"
echo "  2. Start NetGen Pro service:"
echo "     sudo systemctl start netgen-pro-dpdk"
echo "  3. Open GUI in browser"
echo "  4. Run RFC 2544 tests!"
echo ""
