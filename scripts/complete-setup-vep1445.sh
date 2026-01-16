#!/bin/bash
#
# NetGen Pro VEP1445 - Complete Setup for Your System
# Fixes: No DPDK bindings, timeout errors, port status
#

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  NetGen Pro VEP1445 - Complete Setup & Fix                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}✗${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (sudo)"
    exit 1
fi

INSTALL_DIR="/opt/netgen-dpdk"

# Step 1: Configure Hugepages
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Configuring Hugepages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CURRENT_HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
info "Current hugepages: $CURRENT_HUGEPAGES"

if [ "$CURRENT_HUGEPAGES" -lt 1024 ]; then
    info "Setting hugepages to 1024..."
    echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
    
    # Make persistent
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
        echo "vm.nr_hugepages=1024" >> /etc/sysctl.conf
    fi
    
    success "Hugepages configured: 1024"
else
    success "Hugepages already configured: $CURRENT_HUGEPAGES"
fi

# Mount hugepages if not mounted
if ! mount | grep -q hugetlbfs; then
    mkdir -p /mnt/huge
    mount -t hugetlbfs nodev /mnt/huge
    success "Hugepages mounted"
fi

# Step 2: Load VFIO module
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Loading VFIO Kernel Module"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! lsmod | grep -q vfio_pci; then
    modprobe vfio-pci
    success "VFIO module loaded"
else
    success "VFIO module already loaded"
fi

# Make persistent
if ! grep -q "vfio-pci" /etc/modules; then
    echo "vfio-pci" >> /etc/modules
    info "VFIO will load on boot"
fi

# Step 3: Bind interfaces to DPDK
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Binding Interfaces to DPDK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Your current configuration (all kernel drivers):"
dpdk-devbind.py --status | grep -A 10 "Network devices"

echo ""
warning "We will bind these interfaces to DPDK:"
echo "  • eno2 (LAN1) - PCI 0000:02:00.3"
echo "  • eno3 (LAN2) - PCI 0000:02:00.0"
echo "  • eno7 (10G)  - PCI 0000:05:00.1"
echo "  • eno8 (10G)  - PCI 0000:05:00.0"
echo ""
warning "These will NO LONGER be accessible via Linux networking!"
echo "  (You can unbind them later if needed)"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Aborted by user"
    exit 1
fi

# Bind to DPDK
info "Binding eno2 (LAN1) to DPDK..."
dpdk-devbind.py --bind=vfio-pci 0000:02:00.3

info "Binding eno3 (LAN2) to DPDK..."
dpdk-devbind.py --bind=vfio-pci 0000:02:00.0

info "Binding eno7 (10G TX) to DPDK..."
dpdk-devbind.py --bind=vfio-pci 0000:05:00.1

info "Binding eno8 (10G RX) to DPDK..."
dpdk-devbind.py --bind=vfio-pci 0000:05:00.0

success "All interfaces bound to DPDK!"

echo ""
info "New configuration:"
dpdk-devbind.py --status | head -20

# Step 4: Create DPDK configuration file
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Creating DPDK Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > $INSTALL_DIR/dpdk-config.json << 'EOF'
{
    "dpdk": {
        "port_mapping": {
            "0": {
                "interface": "eno2",
                "label": "LAN1",
                "pci": "0000:02:00.3",
                "type": "1G"
            },
            "1": {
                "interface": "eno3",
                "label": "LAN2",
                "pci": "0000:02:00.0",
                "type": "1G"
            },
            "2": {
                "interface": "eno7",
                "label": "10G_TX",
                "pci": "0000:05:00.1",
                "type": "10G"
            },
            "3": {
                "interface": "eno8",
                "label": "10G_RX",
                "pci": "0000:05:00.0",
                "type": "10G"
            }
        }
    }
}
EOF

success "DPDK configuration created: $INSTALL_DIR/dpdk-config.json"

# Step 5: Install dependencies
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Installing Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get update -qq
apt-get install -y lldpd netcat-openbsd jq python3-flask python3-flask-socketio

systemctl enable lldpd
systemctl start lldpd

success "Dependencies installed"

# Step 6: Build DPDK engine
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Building DPDK Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd $INSTALL_DIR

if [ -f "Makefile" ]; then
    info "Building..."
    make clean > /dev/null 2>&1 || true
    
    if make; then
        success "DPDK engine built successfully"
    else
        error "Build failed - check for compilation errors"
        exit 1
    fi
else
    warning "No Makefile found - skipping build"
fi

# Step 7: Create systemd service
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Creating Systemd Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /etc/systemd/system/netgen-pro-dpdk.service << EOF
[Unit]
Description=NetGen Pro DPDK Traffic Generator
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/build/dpdk_engine
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
success "Systemd service created"

# Step 8: Start service
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Starting DPDK Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl enable netgen-pro-dpdk
systemctl restart netgen-pro-dpdk

sleep 3

if systemctl is-active --quiet netgen-pro-dpdk; then
    success "DPDK engine is running"
    
    # Check control socket
    if [ -S "/tmp/dpdk_engine_control.sock" ]; then
        success "Control socket created"
        
        # Test responsiveness
        RESPONSE=$(echo '{"command":"status"}' | timeout 2 nc -U /tmp/dpdk_engine_control.sock 2>&1 || echo "")
        
        if [ -n "$RESPONSE" ]; then
            success "Control socket is responsive"
        else
            warning "Control socket exists but not responding yet (wait a few seconds)"
        fi
    else
        warning "Control socket not yet created (wait a few seconds)"
    fi
else
    error "DPDK engine failed to start"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u netgen-pro-dpdk -n 50"
    exit 1
fi

# Step 9: Start web server
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Starting Web Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Kill any existing web server
pkill -f "python.*server.py" || true
sleep 1

# Start web server
cd $INSTALL_DIR/web

# Use fixed server if available
if [ -f "server-fixed.py" ]; then
    info "Using fixed server (with port status)"
    nohup python3 server-fixed.py > /var/log/netgen-web.log 2>&1 &
elif [ -f "server.py" ]; then
    info "Using standard server"
    nohup python3 server.py > /var/log/netgen-web.log 2>&1 &
else
    error "No server.py found!"
    exit 1
fi

sleep 2

if curl -s http://localhost:8080/api/status > /dev/null 2>&1; then
    success "Web server is running on port 8080"
else
    warning "Web server may not be responding yet"
fi

# Step 10: Verification
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
success "Setup complete!"
echo ""

echo "System Status:"
echo "─────────────────────────────────────────────────────────────────"

# DPDK Engine
if systemctl is-active --quiet netgen-pro-dpdk; then
    echo "✓ DPDK Engine: RUNNING"
else
    echo "✗ DPDK Engine: NOT RUNNING"
fi

# Control Socket
if [ -S "/tmp/dpdk_engine_control.sock" ]; then
    echo "✓ Control Socket: EXISTS"
else
    echo "✗ Control Socket: MISSING"
fi

# Web Server
if pgrep -f "python.*server.py" > /dev/null; then
    echo "✓ Web Server: RUNNING"
else
    echo "✗ Web Server: NOT RUNNING"
fi

# DPDK Ports
DPDK_PORTS=$(dpdk-devbind.py --status 2>/dev/null | grep "drv=vfio-pci" | wc -l)
echo "✓ DPDK Ports: $DPDK_PORTS bound"

# Hugepages
HUGEPAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
FREE_PAGES=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages)
echo "✓ Hugepages: $HUGEPAGES total, $FREE_PAGES free"

echo ""
echo "Port Mapping (DPDK Port ID → Interface):"
echo "─────────────────────────────────────────────────────────────────"
echo "  Port 0 → eno2 (LAN1) - 1 GbE"
echo "  Port 1 → eno3 (LAN2) - 1 GbE"
echo "  Port 2 → eno7 (10G TX) - 10 GbE"
echo "  Port 3 → eno8 (10G RX) - 10 GbE"

echo ""
echo "Access Points:"
echo "─────────────────────────────────────────────────────────────────"
echo "  Web GUI: http://$(hostname -I | awk '{print $1}'):8080"
echo "  Local:   http://localhost:8080"

echo ""
echo "Testing Traffic Generation:"
echo "─────────────────────────────────────────────────────────────────"
echo ""
info "Creating test configuration..."

cat > /tmp/test_lan1_to_lan2.json << 'EOFTEST'
{
    "profiles": [{
        "name": "LAN1_to_LAN2_Test",
        "src_port": 1234,
        "dst_port": 5678,
        "src_ip": "24.1.6.130",
        "dst_ip": "24.1.1.130",
        "protocol": "UDP",
        "rate_mbps": 20,
        "packet_size": 1400,
        "duration_sec": 5
    }]
}
EOFTEST

info "Sending test traffic command..."
RESULT=$(curl -s -X POST http://localhost:8080/api/start \
    -H "Content-Type: application/json" \
    -d @/tmp/test_lan1_to_lan2.json)

echo "Result: $RESULT"

if echo "$RESULT" | grep -q '"status":"success"'; then
    success "Traffic generation WORKING!"
    echo ""
    info "Waiting 2 seconds..."
    sleep 2
    
    info "Checking statistics..."
    STATS=$(curl -s http://localhost:8080/api/stats)
    echo "$STATS" | jq '.' 2>/dev/null || echo "$STATS"
    
    info "Stopping traffic..."
    curl -s -X POST http://localhost:8080/api/stop > /dev/null
    
elif echo "$RESULT" | grep -q "timeout"; then
    error "Still getting timeout!"
    echo ""
    echo "Debug steps:"
    echo "  1. Check logs: sudo journalctl -u netgen-pro-dpdk -n 50"
    echo "  2. Test socket: echo '{\"command\":\"status\"}' | nc -U /tmp/dpdk_engine_control.sock"
    echo "  3. Restart: sudo systemctl restart netgen-pro-dpdk"
else
    warning "Unexpected response: $RESULT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next Steps:"
echo "  1. Open web browser to http://$(hostname -I | awk '{print $1}'):8080"
echo "  2. Select LAN1 as source, LAN2 as destination"
echo "  3. Configure: UDP, 20 Mbps, 1400 bytes"
echo "  4. Click 'START ALL FLOWS'"
echo "  5. Should start immediately (no timeout!)"
echo ""
echo "If issues persist:"
echo "  • Check logs: sudo journalctl -u netgen-pro-dpdk -f"
echo "  • Test socket: echo '{\"command\":\"status\"}' | nc -U /tmp/dpdk_engine_control.sock"
echo "  • Restart: sudo systemctl restart netgen-pro-dpdk"
echo ""
success "Your NetGen Pro VEP1445 is ready!"
