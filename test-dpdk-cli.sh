#!/bin/bash
# Direct CLI test of DPDK engine - bypasses web GUI completely

echo "=========================================="
echo "DPDK Engine CLI Test"
echo "=========================================="
echo ""

SOCKET="/tmp/dpdk_engine_control.sock"

# Check if DPDK engine is running
if [ ! -S "$SOCKET" ]; then
    echo "❌ DPDK engine control socket not found at: $SOCKET"
    echo ""
    echo "Is the service running?"
    systemctl status netgen-pro-dpdk | head -10
    exit 1
fi

echo "✅ Control socket found: $SOCKET"
echo ""

# Test 1: Get status
echo "Test 1: Checking engine status..."
echo '{"command":"status"}' | nc -U -w 3 "$SOCKET"
echo ""
echo ""

# Test 2: Start traffic with default profile
echo "Test 2: Starting traffic with default UDP profile..."
echo '{"command":"start"}' | nc -U -w 5 "$SOCKET"
echo ""
echo ""

# Wait for traffic to start
echo "Waiting 5 seconds for traffic generation..."
sleep 5

# Test 3: Get statistics
echo "Test 3: Checking statistics..."
echo '{"command":"stats"}' | nc -U -w 3 "$SOCKET"
echo ""
echo ""

# Test 4: Check port status if available
echo "Test 4: Checking port status..."
echo '{"command":"port_status"}' | nc -U -w 3 "$SOCKET"
echo ""
echo ""

echo "Test 5: Keep monitoring for 10 seconds..."
for i in {1..10}; do
    echo "=== Second $i ==="
    echo '{"command":"stats"}' | nc -U -w 2 "$SOCKET" | jq '.data.packets_sent, .data.bytes_sent' 2>/dev/null || echo "Parse error"
    sleep 1
done
echo ""

# Test 6: Stop traffic
echo "Test 6: Stopping traffic..."
echo '{"command":"stop"}' | nc -U -w 5 "$SOCKET"
echo ""

echo "=========================================="
echo "CLI Test Complete"
echo "=========================================="
