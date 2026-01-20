#!/bin/bash
################################################################################
# Build and Install DPDK ARP Discovery Tool
# Enables proactive device discovery on DPDK-bound interfaces
################################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Building DPDK ARP Discovery Tool                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd /opt/netgen-dpdk

# Check if source file exists
if [ ! -f "dpdk_arp_discover.c" ]; then
    echo "✗ dpdk_arp_discover.c not found!"
    echo "  Please place dpdk_arp_discover.c in /opt/netgen-dpdk"
    exit 1
fi

# Check for DPDK development files
echo "▶ Checking DPDK development files..."
if ! pkg-config --exists libdpdk; then
    echo "  ✗ DPDK development files not found"
    echo "  Installing dpdk-dev..."
    sudo apt-get install -y dpdk-dev
fi
echo "  ✓ DPDK development files found"
echo ""

# Compile
echo "▶ Compiling DPDK ARP discovery tool..."

gcc -O3 -march=native \
    dpdk_arp_discover.c \
    -o dpdk_arp_discover \
    $(pkg-config --cflags --libs libdpdk) \
    -lrte_eal -lrte_ethdev -lrte_mbuf -lrte_mempool

if [ $? -eq 0 ] && [ -f "dpdk_arp_discover" ]; then
    echo "  ✓ Compilation successful"
else
    echo "  ✗ Compilation failed"
    exit 1
fi

echo ""

# Set permissions
chmod +x dpdk_arp_discover
echo "  ✓ Made executable"

# Test it
echo ""
echo "▶ Testing tool..."
echo "  Running: ./dpdk_arp_discover"
./dpdk_arp_discover 2>&1 | head -5

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Build Complete                                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Tool installed at: /opt/netgen-dpdk/dpdk_arp_discover"
echo ""
echo "Usage:"
echo "  sudo ./dpdk_arp_discover <port_id> <target_ip> [source_ip]"
echo ""
echo "Example:"
echo "  sudo ./dpdk_arp_discover 0 192.168.1.1 192.168.1.100"
echo ""
echo "Next steps:"
echo "  1. Update ports API to use this tool"
echo "  2. Restart web server"
echo "  3. Discovery will work before traffic flows!"
echo ""
