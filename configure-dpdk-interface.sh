#!/bin/bash
#
# Configure DPDK Interface
# Binds network interface to DPDK and configures engine
#

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - DPDK Interface Configuration                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    exit 1
fi

# Show current network interfaces
echo "Current network interfaces:"
echo "═══════════════════════════════════════════════════════════════════"
ip link show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/:$//' | while read iface; do
    STATUS=$(ip link show $iface | grep -o "state [A-Z]*" | awk '{print $2}')
    MAC=$(ip link show $iface | grep -o "link/ether [0-9a-f:]*" | awk '{print $2}')
    echo "  $iface - $STATUS - $MAC"
done
echo ""

# Show DPDK-bound interfaces
echo "DPDK-bound interfaces:"
echo "═══════════════════════════════════════════════════════════════════"
dpdk-devbind.py --status-dev net 2>/dev/null | grep -A 20 "Network devices using DPDK-compatible driver" || echo "  None"
echo ""

# Show available for DPDK
echo "Available for DPDK binding:"
echo "═══════════════════════════════════════════════════════════════════"
dpdk-devbind.py --status-dev net 2>/dev/null | grep -A 50 "Network devices using kernel driver" | grep -E "^\s*[0-9a-f]{4}:" | head -10
echo ""

# Ask which interface to use
echo "Which interface do you want to use for DPDK traffic generation?"
read -p "Interface name (e.g., eno7): " IFACE

if [ -z "$IFACE" ]; then
    echo "❌ No interface specified"
    exit 1
fi

# Get PCI address
PCI=$(ethtool -i $IFACE 2>/dev/null | grep "bus-info" | awk '{print $2}')

if [ -z "$PCI" ]; then
    echo "❌ Could not find PCI address for $IFACE"
    exit 1
fi

echo ""
echo "Interface: $IFACE"
echo "PCI Address: $PCI"
echo ""

# Check if already bound
if dpdk-devbind.py --status | grep -q "$PCI.*drv=vfio-pci"; then
    echo "✅ Already bound to DPDK (vfio-pci)"
else
    echo "Binding $IFACE ($PCI) to DPDK..."
    
    # Bring down interface first
    ip link set $IFACE down
    
    # Bind to vfio-pci
    dpdk-devbind.py --bind=vfio-pci $PCI
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully bound to DPDK"
    else
        echo "❌ Failed to bind to DPDK"
        exit 1
    fi
fi

echo ""
echo "Creating configuration file..."

# Create DPDK config file
cat > /opt/netgen-dpdk/dpdk-config.json << EOF
{
    "interface": "$IFACE",
    "pci_address": "$PCI",
    "port_id": 0,
    "configured_at": "$(date -Iseconds)"
}
EOF

echo "✅ Configuration saved to /opt/netgen-dpdk/dpdk-config.json"
echo ""

# Show final status
echo "Final DPDK status:"
echo "═══════════════════════════════════════════════════════════════════"
dpdk-devbind.py --status-dev net | head -30
echo ""

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Complete                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Interface $IFACE ($PCI) is now bound to DPDK"
echo "DPDK engine will use port 0 (this interface)"
echo ""
echo "To unbind and return to kernel driver:"
echo "  dpdk-devbind.py --bind=<original_driver> $PCI"
echo ""
