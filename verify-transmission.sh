#!/bin/bash
# Verify if ANY packets are leaving the interface

echo "=========================================="
echo "Packet Transmission Verification"
echo "=========================================="
echo ""

# Check which ports are actually bound to DPDK
echo "Step 1: Identifying TX port (first DPDK port should be port 0)"
echo ""
dpdk-devbind.py --status | grep "drv=vfio-pci"
echo ""

echo "Step 2: The DPDK engine should be using port 0 for TX"
echo "        Based on your binding, port 0 = 0000:02:00.0 (eno2/LAN1)"
echo ""

# Since DPDK controls the port, we can't use tcpdump on it directly
# Instead, we check if the Juniper switch sees anything

echo "Step 3: Checking DPDK statistics..."
echo ""
echo "Starting traffic..."
echo '{"command":"start"}' | nc -U -w 5 /tmp/dpdk_engine_control.sock
sleep 2

echo ""
echo "Getting stats after 2 seconds..."
echo '{"command":"stats"}' | nc -U -w 2 /tmp/dpdk_engine_control.sock | jq '.'
echo ""

echo "Waiting 5 more seconds..."
sleep 5

echo ""
echo "Final stats check..."
echo '{"command":"stats"}' | nc -U -w 2 /tmp/dpdk_engine_control.sock | jq '.'
echo ""

echo '{"command":"stop"}' | nc -U -w 3 /tmp/dpdk_engine_control.sock
echo ""

echo "=========================================="
echo "Analysis:"
echo "=========================================="
echo ""
echo "If packets_sent is increasing but your switch sees nothing:"
echo "  → DPDK is counting packets but NOT actually transmitting"
echo "  → This means init_port() succeeded but rte_eth_tx_burst() is failing"
echo ""
echo "If packets_sent stays at 0:"
echo "  → DPDK engine is not generating packets at all"
echo "  → Check if default profile is created in dpdk_engine.cpp"
echo ""
echo "If control socket times out:"
echo "  → DPDK engine is not running or crashed"
echo "  → Check: journalctl -u netgen-pro-dpdk -n 100"
echo ""
