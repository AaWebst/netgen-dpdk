#!/bin/bash
# Quick Deploy Script for LLDP Enhancement
# Automates the deployment of enhanced port status with LLDP discovery

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  NetGen Pro - LLDP Enhancement Quick Deploy               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root (use sudo)"
    exit 1
fi

# Detect repository location
REPO_DIR="/opt/netgen-dpdk"
if [ ! -d "$REPO_DIR" ]; then
    echo "❌ NetGen Pro not found at $REPO_DIR"
    echo "   Please specify location:"
    read -p "   Path to netgen-dpdk: " REPO_DIR
    if [ ! -d "$REPO_DIR" ]; then
        echo "❌ Directory not found: $REPO_DIR"
        exit 1
    fi
fi

echo "📁 Repository: $REPO_DIR"
echo ""

# Step 1: Install LLDP
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Installing LLDP Daemon"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if systemctl is-active --quiet lldpd; then
    echo "✓ LLDP already installed and running"
else
    echo "Installing lldpd..."
    apt-get update -qq
    apt-get install -y lldpd lldpctl >/dev/null 2>&1
    systemctl enable lldpd
    systemctl start lldpd
    echo "✓ LLDP installed and started"
fi
echo ""

# Step 2: Copy files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Copying Enhancement Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create directories
mkdir -p "$REPO_DIR/web/static/css"
mkdir -p "$REPO_DIR/web/static/js"

# Copy files
if [ -f "ports_enhanced_api.py" ]; then
    cp ports_enhanced_api.py "$REPO_DIR/web/"
    echo "✓ Copied ports_enhanced_api.py"
else
    echo "❌ ports_enhanced_api.py not found in current directory"
    exit 1
fi

if [ -f "enhanced-port-status.css" ]; then
    cp enhanced-port-status.css "$REPO_DIR/web/static/css/"
    echo "✓ Copied enhanced-port-status.css"
else
    echo "❌ enhanced-port-status.css not found"
    exit 1
fi

if [ -f "enhanced-port-monitor.js" ]; then
    cp enhanced-port-monitor.js "$REPO_DIR/web/static/js/"
    echo "✓ Copied enhanced-port-monitor.js"
else
    echo "❌ enhanced-port-monitor.js not found"
    exit 1
fi

# Set permissions
chown -R root:root "$REPO_DIR/web/"
echo "✓ Permissions set"
echo ""

# Step 3: Update server.py
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Updating server.py"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVER_FILE="$REPO_DIR/web/server.py"

if [ ! -f "$SERVER_FILE" ]; then
    echo "❌ server.py not found at $SERVER_FILE"
    exit 1
fi

# Backup server.py
cp "$SERVER_FILE" "$SERVER_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backed up server.py"

# Check if already has the import
if grep -q "from ports_enhanced_api import" "$SERVER_FILE"; then
    echo "ℹ️  Import already exists in server.py"
else
    # Add import after other imports (before app = Flask)
    sed -i '/^from flask import/a from ports_enhanced_api import register_enhanced_ports_api' "$SERVER_FILE"
    echo "✓ Added import to server.py"
fi

# Check if already has the register call
if grep -q "register_enhanced_ports_api" "$SERVER_FILE"; then
    echo "ℹ️  API registration already exists in server.py"
else
    # Add register call before socketio.run
    sed -i '/socketio.run/i \    # Register enhanced ports API\n    register_enhanced_ports_api(app)\n' "$SERVER_FILE"
    echo "✓ Added API registration to server.py"
fi
echo ""

# Step 4: Update index.html
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Checking index.html"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HTML_FILE="$REPO_DIR/web/templates/index.html"

if [ ! -f "$HTML_FILE" ]; then
    echo "⚠️  index.html not found at $HTML_FILE"
    echo "   You'll need to manually add CSS/JS includes"
else
    # Backup
    cp "$HTML_FILE" "$HTML_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ Backed up index.html"
    
    # Check if CSS is already included
    if grep -q "enhanced-port-status.css" "$HTML_FILE"; then
        echo "ℹ️  CSS already included in index.html"
    else
        echo "⚠️  Need to manually add CSS to index.html <head>:"
        echo '   <link rel="stylesheet" href="/static/css/enhanced-port-status.css">'
    fi
    
    # Check if JS is already included
    if grep -q "enhanced-port-monitor.js" "$HTML_FILE"; then
        echo "ℹ️  JS already included in index.html"
    else
        echo "⚠️  Need to manually add JS to index.html <head>:"
        echo '   <script src="/static/js/enhanced-port-monitor.js"></script>'
    fi
fi
echo ""

# Step 5: Restart service
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Restarting Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl restart netgen-pro-dpdk
sleep 3

if systemctl is-active --quiet netgen-pro-dpdk; then
    echo "✓ Service restarted successfully"
else
    echo "❌ Service failed to start - check logs:"
    echo "   sudo journalctl -u netgen-pro-dpdk -n 50"
    exit 1
fi
echo ""

# Step 6: Test LLDP
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Testing LLDP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Waiting 10 seconds for LLDP discovery..."
sleep 10

if lldpctl >/dev/null 2>&1; then
    echo "✓ LLDP is working"
    
    # Count neighbors
    NEIGHBOR_COUNT=$(lldpctl 2>/dev/null | grep -c "SysName:" || echo "0")
    if [ "$NEIGHBOR_COUNT" -gt 0 ]; then
        echo "✓ Discovered $NEIGHBOR_COUNT LLDP neighbor(s)"
        echo ""
        echo "Neighbors:"
        lldpctl | grep -E "Interface:|SysName:|PortDescr:" | head -15
    else
        echo "ℹ️  No LLDP neighbors discovered yet (wait 30-60 seconds)"
    fi
else
    echo "⚠️  LLDP command failed"
fi
echo ""

# Step 7: Test API
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Testing Enhanced Port Status API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v jq >/dev/null 2>&1; then
    API_RESPONSE=$(curl -s http://localhost:8080/api/ports/enhanced_status)
    if echo "$API_RESPONSE" | jq -e '.status == "success"' >/dev/null 2>&1; then
        echo "✓ API endpoint working"
        
        # Show sample port
        echo ""
        echo "Sample port status:"
        echo "$API_RESPONSE" | jq '.ports[0] | {name, label, display_name, link, link_speed}'
    else
        echo "⚠️  API returned error or unexpected response"
    fi
else
    echo "ℹ️  jq not installed, skipping API test"
    echo "   Install with: sudo apt-get install jq"
fi
echo ""

# Final summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ LLDP Enhancement Deployment Complete                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Open web UI: http://$(hostname -I | awk '{print $1}'):8080"
echo "  2. Check Port Status sidebar for link indicators"
echo "  3. Wait 30-60 seconds for full LLDP discovery"
echo "  4. Click 'Refresh LLDP' button to force update"
echo ""
echo "Manual steps required:"
echo "  - Add CSS/JS includes to index.html <head> if not already present"
echo "  - Add data-lan-interface attributes to LAN selector boxes"
echo "  - See DEPLOYMENT_INSTRUCTIONS.md for details"
echo ""
echo "Troubleshooting:"
echo "  - Logs: sudo journalctl -u netgen-pro-dpdk -f"
echo "  - LLDP: sudo lldpctl"
echo "  - Test API: curl http://localhost:8080/api/ports/enhanced_status | jq"
echo ""
