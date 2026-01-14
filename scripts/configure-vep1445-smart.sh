#!/bin/bash
#
# VEP1445 Smart Configuration
# Preserves existing netplan, configures DPDK for eno7/eno8
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          VEP1445 Smart Configuration                              ║"
echo "║          Preserves existing network + DPDK setup                  ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Detect installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

# Step 1: Check existing netplan configuration
echo "Step 1: Checking existing network configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NETPLAN_FILE=""
if [ -f "/etc/netplan/99-networks.yaml" ]; then
    NETPLAN_FILE="/etc/netplan/99-networks.yaml"
elif [ -f "/etc/netplan/01-netcfg.yaml" ]; then
    NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
elif [ -f "/etc/netplan/50-cloud-init.yaml" ]; then
    NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
fi

if [ -n "$NETPLAN_FILE" ]; then
    echo "✅ Found existing netplan: $NETPLAN_FILE"
    echo "   Preserving your existing network configuration"
    
    # Backup existing config
    cp "$NETPLAN_FILE" "$NETPLAN_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    echo "   Backup created: $NETPLAN_FILE.backup-$(date +%Y%m%d-%H%M%S)"
else
    echo "⚠️  No existing netplan found, will create basic config"
fi

echo ""

# Step 2: Find all network interfaces using multiple methods
echo "Step 2: Discovering network interfaces..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Method 1: ip link (shows all interfaces even if down)
ALL_IFACES=$(ip link show | grep -E "^[0-9]+: eno[0-9]+" | awk -F': ' '{print $2}' | cut -d'@' -f1 | sort)

echo "Found interfaces:"
for iface in $ALL_IFACES; do
    # Get PCI address using ethtool (works even if interface is down)
    PCI=$(ethtool -i "$iface" 2>/dev/null | grep "bus-info:" | awk '{print $2}')
    if [ -n "$PCI" ]; then
        echo "  ✓ $iface → $PCI"
    else
        echo "  ✓ $iface (no PCI - virtual/bridge)"
    fi
done

echo ""

# Step 3: Find eno7 and eno8 specifically
echo "Step 3: Locating DPDK target interfaces (eno7, eno8)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ENO7_PCI=""
ENO8_PCI=""

# Check if eno7 exists
if ip link show eno7 &>/dev/null; then
    ENO7_PCI=$(ethtool -i eno7 2>/dev/null | grep "bus-info:" | awk '{print $2}')
    if [ -n "$ENO7_PCI" ]; then
        echo "✅ eno7 found → $ENO7_PCI"
    else
        echo "⚠️  eno7 exists but has no PCI address (may be virtual)"
    fi
else
    echo "❌ eno7 not found"
fi

# Check if eno8 exists
if ip link show eno8 &>/dev/null; then
    ENO8_PCI=$(ethtool -i eno8 2>/dev/null | grep "bus-info:" | awk '{print $2}')
    if [ -n "$ENO8_PCI" ]; then
        echo "✅ eno8 found → $ENO8_PCI"
    else
        echo "⚠️  eno8 exists but has no PCI address (may be virtual)"
    fi
else
    echo "❌ eno8 not found"
fi

echo ""

# Check if we found the interfaces
if [ -z "$ENO7_PCI" ] || [ -z "$ENO8_PCI" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  WARNING: eno7 or eno8 not found with PCI addresses"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This could mean:"
    echo "  1. Your VEP1445 model doesn't have eno7/eno8"
    echo "  2. The interfaces are named differently"
    echo "  3. The interfaces are virtual (VLAN sub-interfaces)"
    echo ""
    echo "Available physical interfaces with PCI addresses:"
    for iface in $ALL_IFACES; do
        PCI=$(ethtool -i "$iface" 2>/dev/null | grep "bus-info:" | awk '{print $2}')
        if [ -n "$PCI" ]; then
            DRIVER=$(ethtool -i "$iface" 2>/dev/null | grep "driver:" | awk '{print $2}')
            SPEED=$(ethtool "$iface" 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "unknown")
            echo "  • $iface → $PCI (driver: $DRIVER, speed: $SPEED)"
        fi
    done
    echo ""
    read -p "Do you want to manually select TX and RX interfaces? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Available interfaces:"
        select TX_IFACE in $ALL_IFACES "Skip DPDK configuration"; do
            if [ "$TX_IFACE" = "Skip DPDK configuration" ]; then
                echo "Skipping DPDK configuration"
                exit 0
            fi
            if [ -n "$TX_IFACE" ]; then
                ENO7_PCI=$(ethtool -i "$TX_IFACE" 2>/dev/null | grep "bus-info:" | awk '{print $2}')
                if [ -n "$ENO7_PCI" ]; then
                    echo "Selected TX interface: $TX_IFACE → $ENO7_PCI"
                    break
                else
                    echo "⚠️  $TX_IFACE has no PCI address, try another"
                fi
            fi
        done
        
        echo ""
        echo "Select RX interface:"
        select RX_IFACE in $ALL_IFACES "Skip DPDK configuration"; do
            if [ "$RX_IFACE" = "Skip DPDK configuration" ]; then
                echo "Skipping DPDK configuration"
                exit 0
            fi
            if [ -n "$RX_IFACE" ]; then
                ENO8_PCI=$(ethtool -i "$RX_IFACE" 2>/dev/null | grep "bus-info:" | awk '{print $2}')
                if [ -n "$ENO8_PCI" ]; then
                    echo "Selected RX interface: $RX_IFACE → $ENO8_PCI"
                    break
                else
                    echo "⚠️  $RX_IFACE has no PCI address, try another"
                fi
            fi
        done
    else
        echo "Exiting without DPDK configuration"
        exit 1
    fi
fi

echo ""

# Step 4: Load DPDK drivers
echo "Step 4: Loading DPDK drivers..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

modprobe vfio-pci 2>/dev/null || modprobe igb_uio 2>/dev/null || {
    echo "⚠️  Could not load vfio-pci or igb_uio"
    echo "   Attempting to continue anyway..."
}

# Setup hugepages
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages 2>/dev/null || {
    echo "⚠️  Could not set hugepages, may need manual configuration"
}

HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
echo "✅ Hugepages: $HUGEPAGES x 2MB"

echo ""

# Step 5: Bind interfaces to DPDK
echo "Step 5: Binding interfaces to DPDK..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Bring interfaces down first
echo "Bringing interfaces down..."
ip link set ${TX_IFACE:-eno7} down 2>/dev/null || true
ip link set ${RX_IFACE:-eno8} down 2>/dev/null || true
sleep 1

# Bind to DPDK
echo "Binding to vfio-pci driver..."
dpdk-devbind.py --bind=vfio-pci "$ENO7_PCI" 2>/dev/null || {
    echo "⚠️  Could not bind $ENO7_PCI with vfio-pci, trying igb_uio..."
    dpdk-devbind.py --bind=igb_uio "$ENO7_PCI" 2>/dev/null || echo "❌ Failed to bind TX interface"
}

dpdk-devbind.py --bind=vfio-pci "$ENO8_PCI" 2>/dev/null || {
    echo "⚠️  Could not bind $ENO8_PCI with vfio-pci, trying igb_uio..."
    dpdk-devbind.py --bind=igb_uio "$ENO8_PCI" 2>/dev/null || echo "❌ Failed to bind RX interface"
}

echo "✅ Interfaces bound to DPDK"
echo ""

# Step 6: Verify binding
echo "Step 6: Verifying DPDK binding..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

dpdk-devbind.py --status | grep -A2 "Network devices using DPDK"

echo ""

# Step 7: Create configuration file
echo "Step 7: Creating NetGen Pro configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONFIG_FILE="$INSTALL_DIR/dpdk-config.json"

cat > "$CONFIG_FILE" << EOF
{
  "dpdk": {
    "tx_port": {
      "interface": "${TX_IFACE:-eno7}",
      "pci": "$ENO7_PCI",
      "port_id": 0
    },
    "rx_port": {
      "interface": "${RX_IFACE:-eno8}",
      "pci": "$ENO8_PCI",
      "port_id": 1
    }
  },
  "network": {
    "management_ip": "$(hostname -I | awk '{print $1}')",
    "web_port": 8080
  }
}
EOF

echo "✅ Configuration saved: $CONFIG_FILE"
echo ""

# Step 8: Summary
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Complete!                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "DPDK Configuration:"
echo "  TX Port: ${TX_IFACE:-eno7} → $ENO7_PCI (port 0)"
echo "  RX Port: ${RX_IFACE:-eno8} → $ENO8_PCI (port 1)"
echo ""
echo "Management Access:"
echo "  IP: $(hostname -I | awk '{print $1}')"
echo "  GUI: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Network Configuration:"
echo "  File: $NETPLAN_FILE"
echo "  Status: Preserved (backup created)"
echo ""
echo "Next Steps:"
echo "  1. Start service: sudo systemctl start netgen-pro-dpdk"
echo "  2. Check status:  sudo systemctl status netgen-pro-dpdk"
echo "  3. View logs:     sudo journalctl -u netgen-pro-dpdk -f"
echo "  4. Access GUI:    http://$(hostname -I | awk '{print $1}'):8080"
echo ""
