#!/bin/bash
# NetGen Pro - Emergency Timeout Fix
# Restarts DPDK engine and tests control socket

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  NetGen Pro - Emergency Fix                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Kill old engine
echo "1. Stopping old DPDK engine..."
pkill -9 dpdk_engine 2>/dev/null || true
rm -f /tmp/dpdk_engine_control.sock
sleep 2

# Start fresh
echo "2. Starting DPDK engine..."
cd /opt/netgen-dpdk
nohup ./build/dpdk_engine > /var/log/dpdk_engine.log 2>&1 &

echo "3. Waiting for initialization..."
sleep 8

# Check socket
if [ -S "/tmp/dpdk_engine_control.sock" ]; then
    echo "✓ Control socket created"
    
    # Test it
    RESP=$(echo '{"command":"status"}' | timeout 3 nc -U /tmp/dpdk_engine_control.sock 2>&1 || echo "")
    
    if [ -n "$RESP" ]; then
        echo "✓ Socket is responsive!"
        echo "Response: $RESP"
    else
        echo "✗ Socket not responding"
        echo "Check logs: tail -50 /var/log/dpdk_engine.log"
        exit 1
    fi
else
    echo "✗ Socket not created"
    echo "Check logs: tail -50 /var/log/dpdk_engine.log"
    exit 1
fi

# Restart web server
echo "4. Restarting web server..."
pkill -f "python.*server" 2>/dev/null || true
sleep 1

cd /opt/netgen-dpdk/web
nohup python3 server.py > /var/log/netgen-web.log 2>&1 &
sleep 2

# Test traffic
echo "5. Testing traffic generation..."
curl -s -X POST http://localhost:8080/api/start \
    -H "Content-Type: application/json" \
    -d '{"profiles":[{"src_port":1234,"dst_port":5678,"src_ip":"24.1.6.130","dst_ip":"24.1.1.130","protocol":"UDP","rate_mbps":20,"packet_size":1400}]}'

echo ""
echo "✓ Fix complete! Try GUI now."
