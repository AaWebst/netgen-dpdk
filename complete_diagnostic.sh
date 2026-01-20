#!/bin/bash
################################################################################
# Complete Diagnostic & Fix for NetGen DPDK
################################################################################

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen DPDK - Complete Diagnostic                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd /opt/netgen-dpdk

# Check 1: DPDK Engine
echo "▶ 1. DPDK Engine Status"
echo "────────────────────────────────────────────────────────────────────"

if pgrep -f dpdk_engine > /dev/null; then
    echo "  ✓ DPDK engine is running (PID: $(pgrep -f dpdk_engine))"
else
    echo "  ✗ DPDK engine NOT running"
    echo ""
    echo "  Starting DPDK engine..."
    if [ -f "scripts/start-dpdk-engine.sh" ]; then
        sudo bash scripts/start-dpdk-engine.sh
        sleep 3
        if pgrep -f dpdk_engine > /dev/null; then
            echo "  ✓ DPDK engine started successfully"
        else
            echo "  ✗ Failed to start DPDK engine"
            echo "  Check: sudo journalctl -xe | grep dpdk"
        fi
    else
        echo "  ✗ start-dpdk-engine.sh not found"
    fi
fi

echo ""

# Check 2: Web Server
echo "▶ 2. Web Server Status"
echo "────────────────────────────────────────────────────────────────────"

if systemctl is-active --quiet netgen-pro-dpdk 2>/dev/null; then
    echo "  ✓ Web server running (systemd)"
elif pgrep -f "server.py" > /dev/null; then
    echo "  ✓ Web server running (manual)"
else
    echo "  ✗ Web server NOT running"
fi

echo ""

# Check 3: Frontend Files
echo "▶ 3. Frontend Files"
echo "────────────────────────────────────────────────────────────────────"

FILES_MISSING=0

if [ -f "web/static/js/port-monitor-enhanced.js" ]; then
    echo "  ✓ port-monitor-enhanced.js exists"
else
    echo "  ✗ port-monitor-enhanced.js MISSING"
    FILES_MISSING=$((FILES_MISSING + 1))
fi

if [ -f "web/static/css/port-status-enhanced.css" ]; then
    echo "  ✓ port-status-enhanced.css exists"
else
    echo "  ✗ port-status-enhanced.css MISSING"
    FILES_MISSING=$((FILES_MISSING + 1))
fi

echo ""

# Check 4: HTML Links
echo "▶ 4. HTML File Links"
echo "────────────────────────────────────────────────────────────────────"

if grep -q "port-monitor-enhanced.js" web/templates/index.html; then
    echo "  ✓ JavaScript linked in index.html"
else
    echo "  ✗ JavaScript NOT linked in index.html"
fi

if grep -q "port-status-enhanced.css" web/templates/index.html; then
    echo "  ✓ CSS linked in index.html"
else
    echo "  ✗ CSS NOT linked in index.html"
fi

echo ""

# Check 5: API Endpoint
echo "▶ 5. Port Discovery API"
echo "────────────────────────────────────────────────────────────────────"

API_RESPONSE=$(curl -s http://localhost:8080/api/ports/status 2>/dev/null | head -1)

if echo "$API_RESPONSE" | grep -q "success"; then
    echo "  ✓ API endpoint responding"
    echo "  Sample: $API_RESPONSE" | cut -c1-70
else
    echo "  ✗ API endpoint not responding correctly"
    echo "  Response: ${API_RESPONSE:-No response}"
fi

echo ""

# Check 6: Browser Console Errors
echo "▶ 6. JavaScript Console Check"
echo "────────────────────────────────────────────────────────────────────"
echo "  ℹ  Open browser console (F12) and check for errors"
echo "  Common issues:"
echo "    - 404 for port-monitor-enhanced.js → File not in web/static/js/"
echo "    - 404 for port-status-enhanced.css → File not in web/static/css/"
echo "    - ReferenceError → JS not loading properly"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          Summary & Next Steps                                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ $FILES_MISSING -gt 0 ]; then
    echo "❌ CRITICAL: $FILES_MISSING frontend file(s) missing!"
    echo ""
    echo "You need to:"
    echo "  1. Download these files from your Claude session:"
    echo "     - port-monitor-enhanced.js"
    echo "     - port-status-enhanced.css"
    echo ""
    echo "  2. Add to your GitHub repo:"
    echo "     git add web/static/js/port-monitor-enhanced.js"
    echo "     git add web/static/css/port-status-enhanced.css"
    echo "     git commit -m 'Add port discovery frontend'"
    echo "     git push"
    echo ""
    echo "  3. Pull on VEP1445:"
    echo "     cd /opt/netgen-dpdk"
    echo "     sudo git pull"
    echo ""
    echo "  4. Restart server:"
    echo "     sudo systemctl restart netgen-pro-dpdk"
    echo ""
    echo "  5. Hard refresh browser: Ctrl+F5"
    echo ""
else
    echo "✅ All files present!"
    echo ""
    echo "If GUI still not updating:"
    echo "  1. Hard refresh browser: Ctrl+F5"
    echo "  2. Check browser console (F12) for errors"
    echo "  3. Verify JS is loading:"
    echo "     curl http://localhost:8080/static/js/port-monitor-enhanced.js | head"
    echo ""
fi

echo "To manually test API:"
echo "  curl http://localhost:8080/api/ports/status | jq"
echo ""
