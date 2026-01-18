#!/bin/bash
# Check DPDK port statistics at hardware level

echo "=========================================="
echo "DPDK Hardware Port Statistics"
echo "=========================================="
echo ""

# Check if dpdk-devbind shows link status
echo "1. Port binding status:"
dpdk-devbind.py --status
echo ""

# Check DPDK port stats using testpmd if available
if command -v dpdk-testpmd >/dev/null 2>&1; then
    echo "2. DPDK testpmd available - can run interactive test"
    echo "   Run: sudo dpdk-testpmd -- --stats-period=1"
else
    echo "2. dpdk-testpmd not available"
fi
echo ""

# Check system logs for DPDK
echo "3. Recent DPDK engine logs:"
journalctl -u netgen-pro-dpdk -n 50 --no-pager
echo ""

# Check if there are any TX errors
echo "4. Checking for DPDK errors in logs:"
journalctl -u netgen-pro-dpdk | grep -i "error\|fail\|cannot\|timeout" | tail -20
echo ""

# Check the actual DPDK engine process
echo "5. DPDK engine process info:"
ps aux | grep dpdk_engine | grep -v grep
echo ""

# Check control socket
echo "6. Control socket status:"
ls -lh /tmp/dpdk_engine_control.sock 2>/dev/null || echo "Socket not found"
echo ""

# Quick stats check
echo "7. Quick stats test:"
echo '{"command":"stats"}' | nc -U -w 2 /tmp/dpdk_engine_control.sock 2>/dev/null || echo "Cannot connect to control socket"
echo ""

echo "=========================================="
