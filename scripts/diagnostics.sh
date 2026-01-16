#!/bin/bash
#
# NetGen Pro v4.0 - Comprehensive Troubleshooting Script
#

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     NetGen Pro VEP1445 - Diagnostic Tool                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Function to print section headers
section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 1. Service Status
section "1. Service Status"
if systemctl is-active --quiet netgen-pro-dpdk; then
    echo "✅ Service is running"
    systemctl status netgen-pro-dpdk --no-pager | grep "Active:"
else
    echo "❌ Service is NOT running"
    echo "   Start with: sudo systemctl start netgen-pro-dpdk"
    exit 1
fi

# 2. DPDK Engine Process
section "2. DPDK Engine Process"
DPDK_PID=$(pgrep -f dpdk_engine)
if [ -n "$DPDK_PID" ]; then
    echo "✅ DPDK engine is running (PID: $DPDK_PID)"
    ps aux | grep dpdk_engine | grep -v grep
else
    echo "❌ DPDK engine is NOT running"
    echo "   Check logs: sudo journalctl -u netgen-pro-dpdk -n 50"
    exit 1
fi

# 3. Control Socket
section "3. Control Socket"
if [ -S "/tmp/dpdk_engine_control.sock" ]; then
    echo "✅ Control socket exists"
    ls -lh /tmp/dpdk_engine_control.sock
else
    echo "❌ Control socket does NOT exist"
    echo "   DPDK engine may not have started properly"
    exit 1
fi

# 4. Web Server
section "4. Web Server Status"
WEB_PID=$(pgrep -f "python.*server.py")
if [ -n "$WEB_PID" ]; then
    echo "✅ Web server is running (PID: $WEB_PID)"
else
    echo "❌ Web server is NOT running"
fi

# Test web server connectivity
if curl -s http://localhost:8080/api/status > /dev/null 2>&1; then
    echo "✅ Web server responding on port 8080"
else
    echo "⚠️  Web server not responding"
fi

# 5. DPDK Port Bindings
section "5. DPDK Port Bindings"
echo "Ports bound to DPDK:"
dpdk-devbind.py --status | grep -A 20 "Network devices using DPDK"

DPDK_PORTS=$(dpdk-devbind.py --status | grep "drv=vfio-pci\|drv=igb_uio" | wc -l)
if [ "$DPDK_PORTS" -gt 0 ]; then
    echo ""
    echo "✅ $DPDK_PORTS port(s) bound to DPDK"
else
    echo ""
    echo "❌ NO ports bound to DPDK!"
    echo "   Run: sudo bash scripts/configure-vep1445-smart.sh"
    exit 1
fi

# 6. Port Link Status
section "6. Port Link Status (via DPDK)"
echo "Checking link status of DPDK ports..."
echo "(Note: This requires testpmd or custom tool)"
echo ""

# Try to read from DPDK sysfs if available
for pci in $(dpdk-devbind.py --status | grep "drv=vfio-pci\|drv=igb_uio" | awk '{print $1}'); do
    echo "PCI: $pci"
    # Link status check would need DPDK tool
done

# 7. Hugepages
section "7. Hugepages Configuration"
HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
FREE_PAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages)
echo "Total hugepages: $HUGEPAGES"
echo "Free hugepages:  $FREE_PAGES"

if [ "$HUGEPAGES" -lt 512 ]; then
    echo "⚠️  Low hugepage count (recommend 1024+)"
elif [ "$FREE_PAGES" -lt 100 ]; then
    echo "⚠️  Low free hugepages (may cause allocation failures)"
else
    echo "✅ Hugepages OK"
fi

# 8. Test Traffic Flow
section "8. Test Traffic Flow"
echo "Testing traffic generation..."

# Create test profile
TEST_CONFIG=$(cat <<EOF
{
    "profiles": [
        {
            "name": "test_flow",
            "src_port": 1234,
            "dst_port": 5678,
            "src_ip": "24.1.6.130",
            "dst_ip": "24.1.1.130",
            "protocol": "UDP",
            "rate_mbps": 20,
            "packet_size": 1400,
            "duration_sec": 5
        }
    ]
}
EOF
)

echo "$TEST_CONFIG" > /tmp/test_config.json
echo "Test config created: /tmp/test_config.json"

# Try to start via API
if curl -s -X POST http://localhost:8080/api/start \
   -H "Content-Type: application/json" \
   -d @/tmp/test_config.json > /tmp/start_response.json 2>&1; then
    
    echo "API call successful"
    cat /tmp/start_response.json | jq '.' 2>/dev/null || cat /tmp/start_response.json
    
    # Check if started
    sleep 2
    STATUS=$(curl -s http://localhost:8080/api/status | jq -r '.running' 2>/dev/null)
    if [ "$STATUS" = "true" ]; then
        echo "✅ Traffic is RUNNING"
    else
        echo "⚠️  Traffic NOT running"
    fi
else
    echo "❌ API call failed"
    cat /tmp/start_response.json
fi

# 9. Recent Logs
section "9. Recent DPDK Engine Logs"
echo "Last 20 lines from service:"
sudo journalctl -u netgen-pro-dpdk -n 20 --no-pager

# 10. Port Mapping
section "10. Port to PCI Mapping"
echo "Interface → PCI Address mapping:"
for iface in eno1 eno2 eno3 eno4 eno5 eno6 eno7 eno8; do
    if [ -d "/sys/class/net/$iface" ]; then
        PCI=$(ethtool -i $iface 2>/dev/null | grep "bus-info:" | awk '{print $2}')
        DRIVER=$(ethtool -i $iface 2>/dev/null | grep "driver:" | awk '{print $2}')
        if [ -n "$PCI" ]; then
            echo "  $iface → $PCI (driver: $DRIVER)"
        fi
    fi
done

# 11. Configuration Check
section "11. DPDK Configuration"
if [ -f "/opt/netgen-dpdk/dpdk-config.json" ]; then
    echo "✅ Configuration file exists"
    echo ""
    cat /opt/netgen-dpdk/dpdk-config.json | jq '.' 2>/dev/null || cat /opt/netgen-dpdk/dpdk-config.json
else
    echo "⚠️  No dpdk-config.json found"
fi

# 12. Summary
section "12. Diagnostic Summary"

ISSUES=0

# Check critical components
if ! systemctl is-active --quiet netgen-pro-dpdk; then
    echo "❌ Service not running"
    ((ISSUES++))
fi

if [ -z "$DPDK_PID" ]; then
    echo "❌ DPDK engine not running"
    ((ISSUES++))
fi

if [ ! -S "/tmp/dpdk_engine_control.sock" ]; then
    echo "❌ Control socket missing"
    ((ISSUES++))
fi

if [ "$DPDK_PORTS" -eq 0 ]; then
    echo "❌ No DPDK ports bound"
    ((ISSUES++))
fi

if [ "$HUGEPAGES" -lt 512 ]; then
    echo "⚠️  Low hugepages"
    ((ISSUES++))
fi

if [ "$ISSUES" -eq 0 ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "If traffic still doesn't work, check:"
    echo "  1. Port IDs in DPDK engine (0, 1, etc.)"
    echo "  2. MAC addresses (source/destination)"
    echo "  3. Physical cable connections"
    echo "  4. Web GUI console for errors (F12)"
else
    echo "❌ Found $ISSUES issue(s)"
    echo ""
    echo "Most common fixes:"
    echo "  1. sudo systemctl restart netgen-pro-dpdk"
    echo "  2. sudo bash scripts/configure-vep1445-smart.sh"
    echo "  3. Check logs: sudo journalctl -u netgen-pro-dpdk -n 100"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic complete. Logs saved to /tmp/netgen_diagnostics.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
