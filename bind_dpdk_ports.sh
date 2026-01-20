#!/bin/bash
################################################################################
# Enhanced DPDK Port Binding with Pre-checks
# Handles interfaces in use, checks IOMMU, brings down interfaces first
################################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Enhanced DPDK Port Binding - VEP1445                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root"
    echo "Usage: sudo bash $0"
    exit 1
fi

# Pre-check 1: IOMMU
echo "▶ Checking IOMMU..."
if grep -q "intel_iommu=on" /proc/cmdline || grep -q "amd_iommu=on" /proc/cmdline; then
    echo "  ✓ IOMMU enabled in kernel"
elif dmesg | grep -qi "iommu.*enabled"; then
    echo "  ✓ IOMMU enabled"
else
    echo "  ⚠️  IOMMU may not be enabled"
    echo "  If binding fails, add to /etc/default/grub:"
    echo "    GRUB_CMDLINE_LINUX=\"intel_iommu=on iommu=pt\""
    echo "  Then: sudo update-grub && sudo reboot"
fi
echo ""

# Pre-check 2: VFIO module
echo "▶ Loading VFIO module..."
modprobe vfio-pci 2>/dev/null
if lsmod | grep -q vfio_pci; then
    echo "  ✓ VFIO module loaded"
else
    echo "  ⚠️  VFIO module not loaded"
fi
echo ""

# Pre-check 3: Check if dpdk-devbind.py exists
echo "▶ Checking for dpdk-devbind.py..."
if command -v dpdk-devbind.py &> /dev/null; then
    echo "  ✓ dpdk-devbind.py found: $(which dpdk-devbind.py)"
elif [ -f "/usr/share/dpdk/usertools/dpdk-devbind.py" ]; then
    echo "  ✓ Found at: /usr/share/dpdk/usertools/dpdk-devbind.py"
    alias dpdk-devbind.py="/usr/share/dpdk/usertools/dpdk-devbind.py"
else
    echo "  ❌ dpdk-devbind.py not found!"
    echo "  Install DPDK tools: sudo apt-get install dpdk dpdk-dev"
    exit 1
fi
echo ""

# Show current status
echo "▶ Current interface status:"
echo "────────────────────────────────────────────────────────────────────"
dpdk-devbind.py --status | grep -E "(Network devices|0000:)" | head -20
echo ""

# Define ports to bind
declare -A PORTS=(
    ["0000:02:00.3"]="eno2:LAN1"
    ["0000:02:00.0"]="eno3:LAN2"
    ["0000:02:00.1"]="eno4:LAN3"
    ["0000:07:00.1"]="eno5:LAN4"
    ["0000:07:00.0"]="eno6:LAN5"
    ["0000:05:00.1"]="eno7:10G-1"
    ["0000:05:00.0"]="eno8:10G-2"
)

echo "▶ Bringing down interfaces and binding to DPDK..."
echo "────────────────────────────────────────────────────────────────────"

SUCCESS=0
FAILED=0

for pci_addr in "${!PORTS[@]}"; do
    IFS=: read -r iface label <<< "${PORTS[$pci_addr]}"
    
    echo -n "  $iface ($label) [$pci_addr]: "
    
    # Step 1: Bring interface down
    if ip link show "$iface" &>/dev/null; then
        ip link set "$iface" down 2>/dev/null
        echo -n "down → "
    fi
    
    # Step 2: Unbind from current driver (if bound)
    if [ -d "/sys/bus/pci/devices/$pci_addr/driver" ]; then
        echo "$pci_addr" > /sys/bus/pci/devices/$pci_addr/driver/unbind 2>/dev/null
        echo -n "unbind → "
    fi
    
    # Step 3: Bind to DPDK
    if dpdk-devbind.py --bind=vfio-pci "$pci_addr" 2>/dev/null; then
        echo "✓ vfio-pci"
        SUCCESS=$((SUCCESS + 1))
    else
        # Try alternative method
        echo "vfio-pci" > /sys/bus/pci/devices/$pci_addr/driver_override 2>/dev/null
        echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null
        
        if [ -d "/sys/bus/pci/devices/$pci_addr/driver" ] && \
           [ "$(readlink /sys/bus/pci/devices/$pci_addr/driver)" = *"vfio-pci"* ]; then
            echo "✓ vfio-pci (manual)"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "  Summary: $SUCCESS bound, $FAILED failed"
echo ""

# Show final status
echo "▶ Final DPDK binding status:"
echo "────────────────────────────────────────────────────────────────────"
dpdk-devbind.py --status

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Binding Complete                                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ $SUCCESS -eq 7 ]; then
    echo "✅ All 7 ports successfully bound to DPDK!"
    echo ""
    echo "Next steps:"
    echo "  1. Start DPDK engine:"
    echo "     cd /opt/netgen-dpdk"
    echo "     sudo bash scripts/start-dpdk-engine.sh"
    echo ""
    echo "  2. Verify ports:"
    echo "     You should see: 'Found 7 DPDK ports'"
    echo ""
elif [ $SUCCESS -gt 0 ]; then
    echo "⚠️  Partial success: $SUCCESS of 7 ports bound"
    echo ""
    echo "Check failed ports with:"
    echo "  dmesg | tail -50"
    echo ""
else
    echo "❌ Binding failed"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check IOMMU:"
    echo "     cat /proc/cmdline | grep iommu"
    echo ""
    echo "  2. Check VFIO:"
    echo "     lsmod | grep vfio"
    echo ""
    echo "  3. Check kernel messages:"
    echo "     dmesg | tail -50 | grep -i vfio"
    echo ""
    echo "  4. Verify DPDK tools installed:"
    echo "     dpkg -l | grep dpdk"
    echo ""
fi
