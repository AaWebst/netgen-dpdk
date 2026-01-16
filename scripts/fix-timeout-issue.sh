#!/bin/bash
#
# NetGen Pro v4.0.1 - Quick Fix for Timeout & Port Status Issues
#

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  NetGen Pro - Quick Fix for Your Specific Issues                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() { echo -e "${RED}✗${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# 1. Check if DPDK engine is running
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking DPDK Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if pgrep -f dpdk_engine > /dev/null; then
    success "DPDK engine is running"
    DPDK_PID=$(pgrep -f dpdk_engine)
    echo "  PID: $DPDK_PID"
else
    error "DPDK engine is NOT running"
    echo ""
    echo "Fix: sudo systemctl start netgen-pro-dpdk"
    exit 1
fi

# 2. Check control socket
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checking Control Socket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -S "/tmp/dpdk_engine_control.sock" ]; then
    success "Control socket exists"
    
    # Test if it's responsive
    echo "  Testing socket responsiveness..."
    RESPONSE=$(echo '{"command":"status"}' | timeout 2 nc -U /tmp/dpdk_engine_control.sock 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
        success "Socket is responsive"
        echo "  Response: ${RESPONSE:0:50}..."
    else
        error "Socket exists but not responding"
        echo ""
        echo "This causes the timeout issue!"
        echo ""
        echo "Fix options:"
        echo "  1. Restart service: sudo systemctl restart netgen-pro-dpdk"
        echo "  2. Check logs: sudo journalctl -u netgen-pro-dpdk -n 50"
        echo "  3. Kill and restart: sudo pkill dpdk_engine && sudo systemctl start netgen-pro-dpdk"
        
        # Offer to fix automatically
        read -p "Automatically restart service? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Restarting service..."
            sudo systemctl restart netgen-pro-dpdk
            sleep 3
            
            if [ -S "/tmp/dpdk_engine_control.sock" ]; then
                success "Service restarted, socket recreated"
            else
                error "Service restart failed, check logs"
                exit 1
            fi
        else
            exit 1
        fi
    fi
else
    error "Control socket does NOT exist"
    echo "  Expected: /tmp/dpdk_engine_control.sock"
    echo ""
    echo "This is why traffic won't start!"
    echo ""
    echo "Fix: sudo systemctl restart netgen-pro-dpdk"
    exit 1
fi

# 3. Check port bindings
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Checking DPDK Port Bindings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DPDK_PORTS=$(dpdk-devbind.py --status | grep "drv=vfio-pci\|drv=igb_uio" | wc -l)

if [ "$DPDK_PORTS" -ge 2 ]; then
    success "Found $DPDK_PORTS DPDK-bound ports"
    echo ""
    dpdk-devbind.py --status | grep -A 15 "Network devices using DPDK"
else
    error "Only $DPDK_PORTS DPDK port(s) found (need at least 2)"
    echo ""
    echo "Fix: sudo bash scripts/configure-vep1445-smart.sh"
    exit 1
fi

# 4. Check eno2 and eno3 link status (your specific issue)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Checking eno2 & eno3 Link Status (Your LANs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for iface in eno2 eno3; do
    echo ""
    echo "Interface: $iface"
    
    # Check if interface exists
    if [ -d "/sys/class/net/$iface" ]; then
        success "Interface exists"
        
        # Check operstate
        STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "unknown")
        
        if [ "$STATE" = "up" ]; then
            success "Link is UP"
            
            # Get speed
            SPEED=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "0")
            echo "  Speed: ${SPEED} Mbps"
            
            # Get IP address
            IP=$(ip addr show $iface | grep "inet " | awk '{print $2}' | head -1)
            if [ -n "$IP" ]; then
                echo "  IP: $IP"
            else
                warning "No IP address assigned"
            fi
            
        elif [ "$STATE" = "down" ]; then
            error "Link is DOWN"
            echo "  Check physical cable connection"
            
        else
            warning "Link state: $STATE"
        fi
        
        # Check driver
        DRIVER=$(ethtool -i $iface 2>/dev/null | grep "driver:" | awk '{print $2}')
        echo "  Driver: $DRIVER"
        
        if [ "$DRIVER" = "vfio-pci" ] || [ "$DRIVER" = "igb_uio" ]; then
            warning "Bound to DPDK - link status unavailable from OS"
            echo "  (This is normal for traffic generation ports)"
        fi
        
    else
        error "Interface $iface does not exist"
    fi
done

# 5. Check LLDP
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Checking LLDP Discovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if systemctl is-active --quiet lldpd; then
    success "LLDP daemon is running"
    
    echo ""
    echo "LLDP Neighbors:"
    
    NEIGHBORS=0
    for iface in eno2 eno3; do
        echo ""
        echo "  $iface:"
        
        LLDP_OUTPUT=$(lldpctl $iface 2>/dev/null)
        
        if [ -n "$LLDP_OUTPUT" ] && echo "$LLDP_OUTPUT" | grep -q "SysName:"; then
            ((NEIGHBORS++))
            
            # Extract key info
            SYS_NAME=$(echo "$LLDP_OUTPUT" | grep "SysName:" | head -1 | cut -d: -f2- | xargs)
            PORT_DESC=$(echo "$LLDP_OUTPUT" | grep "PortDescr:" | head -1 | cut -d: -f2- | xargs)
            
            success "Neighbor found"
            echo "    Name: $SYS_NAME"
            echo "    Port: $PORT_DESC"
        else
            warning "No LLDP neighbor detected"
            echo "    Make sure connected device supports LLDP"
        fi
    done
    
    if [ $NEIGHBORS -eq 0 ]; then
        warning "No LLDP neighbors found on eno2 or eno3"
        echo ""
        echo "Possible reasons:"
        echo "  1. Connected devices don't support LLDP"
        echo "  2. LLDP not enabled on switches"
        echo "  3. Interfaces bound to DPDK (LLDP needs kernel driver)"
        echo ""
        echo "Note: If eno2/eno3 are bound to DPDK for traffic gen,"
        echo "      they can't receive LLDP frames in the kernel."
    fi
    
else
    error "LLDP daemon is not running"
    echo ""
    echo "Install and enable LLDP:"
    echo "  sudo apt-get install lldpd"
    echo "  sudo systemctl enable lldpd"
    echo "  sudo systemctl start lldpd"
    echo "  sleep 30  # Wait for neighbor discovery"
fi

# 6. Test web server
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Testing Web Server API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -s http://localhost:8080/api/status > /dev/null 2>&1; then
    success "Web server is responding"
    
    # Test port status API
    echo ""
    echo "Testing port status API..."
    
    PORT_STATUS=$(curl -s http://localhost:8080/api/ports/status)
    
    if [ -n "$PORT_STATUS" ]; then
        success "Port status API working"
        
        # Show eno2 and eno3 status
        echo ""
        echo "Port Status from API:"
        echo "$PORT_STATUS" | python3 -m json.tool 2>/dev/null | grep -A 10 "eno2\|eno3" || echo "$PORT_STATUS"
    else
        error "Port status API not responding"
    fi
    
else
    error "Web server not responding on port 8080"
    echo ""
    echo "Check if web server is running:"
    echo "  ps aux | grep server.py"
fi

# 7. Test traffic generation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Testing Traffic Generation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /tmp/test_traffic.json << 'EOF'
{
    "profiles": [{
        "src": "LAN1",
        "dst": "LAN2",
        "src_ip": "192.168.1.50",
        "dst_ip": "192.168.2.100",
        "protocol": "UDP",
        "rate_mbps": 100,
        "packet_size": 1400,
        "duration_sec": 5
    }]
}
EOF

echo "Sending test traffic command..."

START_RESPONSE=$(curl -s -X POST http://localhost:8080/api/start \
    -H "Content-Type: application/json" \
    -d @/tmp/test_traffic.json)

echo "Response: $START_RESPONSE"

if echo "$START_RESPONSE" | grep -q '"status":"success"'; then
    success "Traffic started successfully!"
    
    echo ""
    echo "Monitoring for 5 seconds..."
    sleep 2
    
    STATS=$(curl -s http://localhost:8080/api/stats)
    echo "Stats: $STATS"
    
    # Stop traffic
    echo ""
    echo "Stopping traffic..."
    STOP_RESPONSE=$(curl -s -X POST http://localhost:8080/api/stop)
    echo "Stop response: $STOP_RESPONSE"
    
elif echo "$START_RESPONSE" | grep -q "timeout"; then
    error "TIMEOUT ERROR - This is your issue!"
    echo ""
    echo "Cause: DPDK engine not responding to commands"
    echo ""
    echo "Solutions:"
    echo "  1. Check if engine is stuck:"
    echo "     sudo journalctl -u netgen-pro-dpdk -n 100 | tail -20"
    echo ""
    echo "  2. Restart service:"
    echo "     sudo systemctl restart netgen-pro-dpdk"
    echo ""
    echo "  3. Check for errors in engine:"
    echo "     sudo journalctl -u netgen-pro-dpdk | grep -i error"
    
else
    error "Traffic start failed"
    echo "Response: $START_RESPONSE"
fi

# 8. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Summary & Recommendations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Quick Fixes for Your Issues:"
echo ""

echo "Issue 1: Traffic timeout when starting"
echo "  → Check if control socket is responsive (section 2 above)"
echo "  → If stuck: sudo systemctl restart netgen-pro-dpdk"
echo ""

echo "Issue 2: Port status not updating (shows AVAIL instead of link status)"
echo "  → Update to fixed web server:"
echo "    sudo cp web/server-fixed.py web/server.py"
echo "    sudo systemctl restart netgen-pro-web"
echo ""

echo "Issue 3: No LLDP info showing"
echo "  → If ports bound to DPDK: Can't receive LLDP (normal)"
echo "  → If ports in kernel: Install lldpd"
echo "    sudo apt-get install lldpd"
echo "    sudo systemctl enable --now lldpd"
echo "    sleep 30  # Wait for discovery"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
