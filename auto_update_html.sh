#!/bin/bash
################################################################################
# Auto-Update index.html for Port Discovery
# This script will automatically add the required CSS/JS links and 
# enhance the Port Status section without you manually editing
################################################################################

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     Auto-Update index.html for Port Discovery                     ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd /opt/netgen-dpdk/web/templates

# Backup first
echo "▶ Creating backup..."
sudo cp index.html index.html.backup_$(date +%Y%m%d_%H%M%S)
echo "  ✓ Backup created"
echo ""

# Add CSS link if not present
echo "▶ Adding CSS link..."
if ! grep -q "port-status-enhanced.css" index.html; then
    sudo sed -i 's|</head>|    <link rel="stylesheet" href="/static/css/port-status-enhanced.css">\n</head>|' index.html
    echo "  ✓ CSS link added to <head>"
else
    echo "  ℹ CSS already linked"
fi

# Add JS link if not present  
echo "▶ Adding JavaScript link..."
if ! grep -q "port-monitor-enhanced.js" index.html; then
    sudo sed -i 's|</body>|    <script src="/static/js/port-monitor-enhanced.js"></script>\n</body>|' index.html
    echo "  ✓ JS link added before </body>"
else
    echo "  ℹ JavaScript already linked"
fi

# Update Port Status section HTML structure
echo ""
echo "▶ Updating Port Status HTML structure..."

# Create the enhanced port status section
cat > /tmp/port_status_section.html << 'EOF'
    <!-- PORT STATUS - Enhanced with Discovery -->
    <div class="sidebar-section">
        <h3>PORT STATUS</h3>
        
        <!-- Control Buttons -->
        <div class="port-controls">
            <button id="refresh-ports-btn" class="refresh-ports-btn">🔄 Refresh</button>
            <button id="force-scan-btn" class="force-scan-btn">📡 Scan</button>
            <button id="toggle-active-scan" class="btn-scan-off">Auto-Scan: OFF</button>
        </div>
        
        <!-- Status Bar -->
        <div class="status-bar">
            <div id="dpdk-status-indicator" class="dpdk-status">○ DPDK</div>
            <div id="monitor-status-indicator" class="monitor-status">○ Monitor</div>
            <div id="scan-status-indicator" class="scan-status">Passive</div>
        </div>
        
        <!-- Notification -->
        <div id="port-notification" class="notification" style="display:none;"></div>
        
        <!-- Port Cards -->
        <div class="port-card" data-port="eno1">
            <div><strong>eno1</strong> (MGMT)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno2">
            <div><strong>eno2</strong> (LAN1)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno3">
            <div><strong>eno3</strong> (LAN2)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno4">
            <div><strong>eno4</strong> (LAN3)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno5">
            <div><strong>eno5</strong> (LAN4)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno6">
            <div><strong>eno6</strong> (LAN5)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno7">
            <div><strong>eno7</strong> (10G-1)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <div class="port-card" data-port="eno8">
            <div><strong>eno8</strong> (10G-2)</div>
            <div class="port-link-status">Checking...</div>
            <div class="port-neighbor"></div>
            <div class="port-status-note"></div>
        </div>
        
        <!-- Last Update -->
        <div class="last-update" style="font-size: 10px; color: #888; margin-top: 10px;">
            Last update: <span id="last-update-time">--:--:--</span>
        </div>
    </div>
EOF

# Find and replace the PORT STATUS section
# This looks for the section and replaces it with the enhanced version
if grep -q "PORT STATUS" index.html; then
    # Use awk to replace the PORT STATUS section
    awk '
    /PORT STATUS/ {
        in_section = 1
        print
        system("cat /tmp/port_status_section.html")
        next
    }
    in_section && /<\/div>/ {
        depth++
        if (depth >= 8) {  # Adjust based on nesting
            in_section = 0
            depth = 0
        }
        next
    }
    !in_section {
        print
    }
    ' index.html > /tmp/index_updated.html
    
    sudo mv /tmp/index_updated.html index.html
    echo "  ✓ Port Status section updated"
else
    echo "  ℹ No PORT STATUS section found - you may need to add it manually"
fi

# Clean up
rm -f /tmp/port_status_section.html

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     Update Complete!                                               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Changes made:"
echo "  ✓ Added port-status-enhanced.css to <head>"
echo "  ✓ Added port-monitor-enhanced.js before </body>"
echo "  ✓ Enhanced PORT STATUS section with discovery features"
echo ""
echo "Backup saved as: index.html.backup_*"
echo ""
echo "Next steps:"
echo "  1. Restart server: sudo systemctl restart netgen-pro-dpdk"
echo "  2. Hard refresh browser: Ctrl+F5"
echo "  3. Port discovery will auto-update every 5 seconds"
echo ""
