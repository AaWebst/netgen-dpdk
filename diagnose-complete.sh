#!/bin/bash
# Master diagnostic for VEP1445 DPDK packet transmission issue

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  VEP1445 DPDK Packet Transmission Diagnostic                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. Check if service is running
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl is-active --quiet netgen-pro-dpdk
check "DPDK service is running"
echo ""

# 2. Check control socket
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Control Socket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -S /tmp/dpdk_engine_control.sock ]; then
    echo -e "${GREEN}✓${NC} Control socket exists"
    ls -lh /tmp/dpdk_engine_control.sock
else
    echo -e "${RED}✗${NC} Control socket NOT found"
    echo "   Expected: /tmp/dpdk_engine_control.sock"
fi
echo ""

# 3. Check DPDK port bindings
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. DPDK Port Bindings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
dpdk-devbind.py --status | grep "drv=vfio-pci"
echo ""
echo "Port mapping (based on PCI order):"
echo "  DPDK Port 0 (TX) = 0000:02:00.0 (eno2/LAN1)"
echo "  DPDK Port 1 (RX) = 0000:02:00.1 (eno3/LAN2)"
echo ""

# 4. Test control socket communication
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Control Socket Communication Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sending status command..."
RESPONSE=$(echo '{"command":"status"}' | nc -U -w 3 /tmp/dpdk_engine_control.sock 2>&1)
if echo "$RESPONSE" | grep -q "status"; then
    echo -e "${GREEN}✓${NC} Communication successful"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
else
    echo -e "${RED}✗${NC} Communication failed"
    echo "Response: $RESPONSE"
fi
echo ""

# 5. Start traffic and monitor
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Traffic Generation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting traffic with default profile..."
START_RESPONSE=$(echo '{"command":"start"}' | nc -U -w 10 /tmp/dpdk_engine_control.sock 2>&1)
echo "$START_RESPONSE" | jq '.' 2>/dev/null || echo "$START_RESPONSE"
echo ""

echo "Waiting 3 seconds for traffic to start..."
sleep 3

echo ""
echo "Checking statistics (5 samples, 1 second apart):"
for i in {1..5}; do
    STATS=$(echo '{"command":"stats"}' | nc -U -w 2 /tmp/dpdk_engine_control.sock 2>&1)
    TX=$(echo "$STATS" | jq -r '.data.packets_sent // 0' 2>/dev/null)
    BYTES=$(echo "$STATS" | jq -r '.data.bytes_sent // 0' 2>/dev/null)
    
    if [ "$TX" != "0" ] && [ "$TX" != "" ]; then
        echo -e "  Sample $i: ${GREEN}TX: $TX packets, $BYTES bytes${NC}"
    else
        echo -e "  Sample $i: ${RED}TX: $TX packets${NC}"
    fi
    
    sleep 1
done
echo ""

# Stop traffic
echo "Stopping traffic..."
STOP_RESPONSE=$(echo '{"command":"stop"}' | nc -U -w 5 /tmp/dpdk_engine_control.sock 2>&1)
echo "$STOP_RESPONSE" | jq '.' 2>/dev/null || echo "$STOP_RESPONSE"
echo ""

# 6. Check logs for errors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Recent DPDK Engine Logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
journalctl -u netgen-pro-dpdk -n 30 --no-pager
echo ""

# 7. Check for port start confirmation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Port Initialization Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Looking for 'Port X STARTED' messages..."
journalctl -u netgen-pro-dpdk | grep "STARTED\|initialized" | tail -10
echo ""

# 8. Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  DIAGNOSIS SUMMARY                                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Expected results for working system:"
echo "  • Service: ${GREEN}running${NC}"
echo "  • Control socket: ${GREEN}exists and responds${NC}"
echo "  • Ports: ${GREEN}bound to vfio-pci${NC}"
echo "  • TX packets: ${GREEN}increasing over time${NC}"
echo "  • Logs show: ${GREEN}'Port 0 STARTED'${NC}"
echo ""
echo "Common failure modes:"
echo ""
echo "  ${RED}1. TX packets = 0 (not generating)${NC}"
echo "     → Default profile not created"
echo "     → Check: num_profiles in dpdk_engine.cpp start handler"
echo ""
echo "  ${RED}2. TX packets increase but switch sees nothing${NC}"
echo "     → Port not started (rte_eth_dev_start missing)"
echo "     → Wrong MAC addresses"
echo "     → Physical link issue"
echo ""
echo "  ${RED}3. Control socket timeout${NC}"
echo "     → DPDK engine crashed"
echo "     → Check: journalctl -u netgen-pro-dpdk"
echo ""
