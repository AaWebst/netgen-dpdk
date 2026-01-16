#!/bin/bash
# Start DPDK engine with proper permissions

cd /opt/netgen-dpdk

# Kill any existing
sudo pkill -9 dpdk_engine 2>/dev/null || true
sudo rm -f /tmp/dpdk_engine_control.sock

# Create log file with proper permissions
sudo touch /var/log/dpdk_engine.log
sudo chmod 666 /var/log/dpdk_engine.log

# Start engine
sudo ./build/dpdk_engine > /var/log/dpdk_engine.log 2>&1 &

echo "DPDK engine starting..."
sleep 5

# Check if started
if [ -S "/tmp/dpdk_engine_control.sock" ]; then
    echo "✓ Control socket created"
    echo '{"command":"status"}' | nc -U /tmp/dpdk_engine_control.sock
else
    echo "✗ Failed to start - check logs:"
    tail -20 /var/log/dpdk_engine.log
fi
