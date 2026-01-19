#!/bin/bash
################################################################################
# Hybrid Port Discovery Installer for NetGen DPDK
# Automatically installs LLDP + ARP-based device discovery
#
# This script:
# - Backs up existing files
# - Installs dependencies (lldpd, arping)
# - Copies all necessary files to correct locations
# - Updates server.py with hybrid API
# - Updates index.html with CSS/JS links
# - Restarts services
# - Runs diagnostics
#
# Usage: sudo bash install_hybrid_discovery.sh
################################################################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/netgen-dpdk"
WEB_DIR="$INSTALL_DIR/web"
BACKUP_DIR="$INSTALL_DIR/backup_$(date +%Y%m%d_%H%M%S)"
SERVICE_NAME="netgen-pro-dpdk"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root"
        echo "Usage: sudo bash $0"
        exit 1
    fi
    print_success "Running as root"
}

check_install_dir() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Installation directory not found: $INSTALL_DIR"
        echo "Please verify NetGen DPDK is installed at this location"
        exit 1
    fi
    print_success "Installation directory found: $INSTALL_DIR"
}

################################################################################
# Backup Existing Files
################################################################################

backup_files() {
    print_header "Backing Up Existing Files"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup server.py if exists
    if [ -f "$WEB_DIR/server.py" ]; then
        cp "$WEB_DIR/server.py" "$BACKUP_DIR/server.py.bak"
        print_success "Backed up server.py"
    fi
    
    # Backup index.html if exists
    if [ -f "$WEB_DIR/templates/index.html" ]; then
        cp "$WEB_DIR/templates/index.html" "$BACKUP_DIR/index.html.bak"
        print_success "Backed up index.html"
    fi
    
    # Backup any existing port API files
    for file in ports_api_fixed.py ports_api_hybrid.py ports_enhanced_api.py; do
        if [ -f "$WEB_DIR/$file" ]; then
            cp "$WEB_DIR/$file" "$BACKUP_DIR/${file}.bak"
            print_success "Backed up $file"
        fi
    done
    
    print_info "Backup location: $BACKUP_DIR"
}

################################################################################
# Install Dependencies
################################################################################

install_dependencies() {
    print_header "Installing Dependencies"
    
    apt-get update -qq
    
    # LLDP daemon
    if ! systemctl is-active --quiet lldpd; then
        print_info "Installing lldpd..."
        apt-get install -y lldpd
        systemctl enable lldpd
        systemctl start lldpd
        print_success "LLDP daemon installed and started"
    else
        print_success "LLDP daemon already running"
    fi
    
    # arping for active scanning
    if ! command -v arping &> /dev/null; then
        print_info "Installing arping..."
        apt-get install -y arping iputils-arping
        print_success "arping installed"
    else
        print_success "arping already installed"
    fi
    
    # jq for JSON parsing (useful for testing)
    if ! command -v jq &> /dev/null; then
        print_info "Installing jq..."
        apt-get install -y jq
        print_success "jq installed"
    else
        print_success "jq already installed"
    fi
}

################################################################################
# Copy Files
################################################################################

copy_files() {
    print_header "Copying Files"
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Copy hybrid API (main file)
    if [ -f "$SCRIPT_DIR/ports_api_hybrid.py" ]; then
        cp "$SCRIPT_DIR/ports_api_hybrid.py" "$WEB_DIR/"
        chmod 644 "$WEB_DIR/ports_api_hybrid.py"
        print_success "Copied ports_api_hybrid.py"
    else
        print_error "ports_api_hybrid.py not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Copy ARP discovery module (optional standalone)
    if [ -f "$SCRIPT_DIR/dpdk_arp_discovery.py" ]; then
        cp "$SCRIPT_DIR/dpdk_arp_discovery.py" "$WEB_DIR/"
        chmod 644 "$WEB_DIR/dpdk_arp_discovery.py"
        print_success "Copied dpdk_arp_discovery.py"
    fi
    
    # Copy test script
    if [ -f "$SCRIPT_DIR/test_ports_api_corrected.py" ]; then
        cp "$SCRIPT_DIR/test_ports_api_corrected.py" "$WEB_DIR/"
        chmod 755 "$WEB_DIR/test_ports_api_corrected.py"
        print_success "Copied test_ports_api_corrected.py"
    fi
    
    # Copy diagnostic script
    if [ -f "$SCRIPT_DIR/diagnose_installation.py" ]; then
        cp "$SCRIPT_DIR/diagnose_installation.py" "$WEB_DIR/"
        chmod 755 "$WEB_DIR/diagnose_installation.py"
        print_success "Copied diagnose_installation.py"
    fi
    
    # Create directories for frontend files
    mkdir -p "$WEB_DIR/static/js"
    mkdir -p "$WEB_DIR/static/css"
    
    # Copy JavaScript (check both uploaded files and script directory)
    JS_FILE=""
    if [ -f "$SCRIPT_DIR/port-monitor-simple.js" ]; then
        JS_FILE="$SCRIPT_DIR/port-monitor-simple.js"
    elif [ -f "./port-monitor-simple.js" ]; then
        JS_FILE="./port-monitor-simple.js"
    fi
    
    if [ -n "$JS_FILE" ]; then
        cp "$JS_FILE" "$WEB_DIR/static/js/"
        chmod 644 "$WEB_DIR/static/js/port-monitor-simple.js"
        print_success "Copied port-monitor-simple.js"
    else
        print_warning "port-monitor-simple.js not found (will need to copy manually)"
    fi
    
    # Copy CSS
    CSS_FILE=""
    if [ -f "$SCRIPT_DIR/port-status-simple.css" ]; then
        CSS_FILE="$SCRIPT_DIR/port-status-simple.css"
    elif [ -f "./port-status-simple.css" ]; then
        CSS_FILE="./port-status-simple.css"
    fi
    
    if [ -n "$CSS_FILE" ]; then
        cp "$CSS_FILE" "$WEB_DIR/static/css/"
        chmod 644 "$WEB_DIR/static/css/port-status-simple.css"
        print_success "Copied port-status-simple.css"
    else
        print_warning "port-status-simple.css not found (will need to copy manually)"
    fi
}

################################################################################
# Update server.py
################################################################################

update_server_py() {
    print_header "Updating server.py"
    
    SERVER_FILE="$WEB_DIR/server.py"
    
    if [ ! -f "$SERVER_FILE" ]; then
        print_error "server.py not found at $SERVER_FILE"
        exit 1
    fi
    
    # Check if already updated
    if grep -q "from ports_api_hybrid import init_app as init_ports_api" "$SERVER_FILE"; then
        print_warning "server.py already has hybrid API import"
        return
    fi
    
    # Remove old imports if they exist
    sed -i '/from ports_api_fixed import/d' "$SERVER_FILE"
    sed -i '/from ports_enhanced_api import/d' "$SERVER_FILE"
    
    # Find the import section (after Flask imports, before app creation)
    # Look for "from flask import" and add our import after it
    if grep -q "from flask import" "$SERVER_FILE"; then
        # Add import after Flask imports
        sed -i '/from flask import/a from ports_api_hybrid import init_app as init_ports_api' "$SERVER_FILE"
        print_success "Added hybrid API import to server.py"
    else
        print_warning "Could not find Flask import section"
        print_info "Please manually add: from ports_api_hybrid import init_app as init_ports_api"
    fi
    
    # Check if init_ports_api() is called
    if ! grep -q "init_ports_api(app)" "$SERVER_FILE"; then
        print_warning "init_ports_api(app) call not found"
        print_info "Please manually add before socketio.run():"
        print_info "  init_ports_api(app)"
    else
        print_success "init_ports_api(app) call found"
    fi
}

################################################################################
# Update index.html
################################################################################

update_index_html() {
    print_header "Updating index.html"
    
    HTML_FILE="$WEB_DIR/templates/index.html"
    
    if [ ! -f "$HTML_FILE" ]; then
        print_warning "index.html not found at $HTML_FILE"
        print_info "Frontend files will need to be added manually"
        return
    fi
    
    # Check if already updated
    if grep -q "port-status-simple.css" "$HTML_FILE"; then
        print_warning "index.html already has CSS link"
    else
        # Try to add CSS link in <head>
        if grep -q "</head>" "$HTML_FILE"; then
            sed -i 's|</head>|<link rel="stylesheet" href="/static/css/port-status-simple.css">\n</head>|' "$HTML_FILE"
            print_success "Added CSS link to index.html"
        else
            print_warning "Could not find </head> tag"
            print_info "Please manually add: <link rel=\"stylesheet\" href=\"/static/css/port-status-simple.css\">"
        fi
    fi
    
    if grep -q "port-monitor-simple.js" "$HTML_FILE"; then
        print_warning "index.html already has JS link"
    else
        # Try to add JS link before </body>
        if grep -q "</body>" "$HTML_FILE"; then
            sed -i 's|</body>|<script src="/static/js/port-monitor-simple.js"></script>\n</body>|' "$HTML_FILE"
            print_success "Added JS link to index.html"
        else
            print_warning "Could not find </body> tag"
            print_info "Please manually add: <script src=\"/static/js/port-monitor-simple.js\"></script>"
        fi
    fi
}

################################################################################
# Test Installation
################################################################################

test_installation() {
    print_header "Testing Installation"
    
    # Test Python import
    print_info "Testing Python imports..."
    cd "$WEB_DIR"
    if python3 -c "from ports_api_hybrid import init_app" 2>/dev/null; then
        print_success "Python imports work"
    else
        print_error "Python import failed"
        print_info "Run: cd $WEB_DIR && python3 -c 'from ports_api_hybrid import init_app'"
        return
    fi
    
    # Run the test script
    print_info "Running API tests..."
    if python3 "$WEB_DIR/test_ports_api_corrected.py" > /tmp/port_test.log 2>&1; then
        print_success "API tests passed"
        echo ""
        cat /tmp/port_test.log
    else
        print_warning "API tests had some issues (check /tmp/port_test.log)"
    fi
}

################################################################################
# Restart Service
################################################################################

restart_service() {
    print_header "Restarting Service"
    
    if systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
        print_info "Restarting $SERVICE_NAME..."
        systemctl restart "$SERVICE_NAME"
        sleep 3
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "Service restarted successfully"
            
            # Show recent logs
            print_info "Recent logs:"
            journalctl -u "$SERVICE_NAME" -n 10 --no-pager
        else
            print_error "Service failed to start"
            print_info "Check logs: journalctl -u $SERVICE_NAME -n 50"
        fi
    else
        print_warning "Service $SERVICE_NAME not found"
        print_info "You may need to start the web server manually:"
        print_info "  cd $WEB_DIR && python3 server.py"
    fi
}

################################################################################
# Test API Endpoint
################################################################################

test_api_endpoint() {
    print_header "Testing API Endpoint"
    
    # Wait a bit for service to be ready
    sleep 2
    
    print_info "Testing /api/ports/status endpoint..."
    
    if curl -s http://localhost:8080/api/ports/status > /tmp/api_test.json 2>&1; then
        if jq -e '.status == "success"' /tmp/api_test.json > /dev/null 2>&1; then
            print_success "API endpoint is working!"
            echo ""
            print_info "Sample response:"
            jq '.' /tmp/api_test.json | head -30
        else
            print_warning "API returned response but status != success"
            cat /tmp/api_test.json
        fi
    else
        print_warning "Could not connect to API endpoint"
        print_info "This is normal if the web server isn't running yet"
        print_info "Start it with: cd $WEB_DIR && python3 server.py"
    fi
}

################################################################################
# Print Summary
################################################################################

print_summary() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}What was installed:${NC}"
    echo "  ✓ LLDP daemon (for MGMT port discovery)"
    echo "  ✓ arping (for active scanning)"
    echo "  ✓ Hybrid API (ports_api_hybrid.py)"
    echo "  ✓ Frontend files (JS + CSS)"
    echo "  ✓ Test and diagnostic scripts"
    echo ""
    
    echo -e "${BLUE}Discovery Methods:${NC}"
    echo "  • eno1 (MGMT):     LLDP (Layer 2 - switch/router discovery)"
    echo "  • eno2-8 (DPDK):   ARP (Layer 3 - IP device discovery)"
    echo "  • All ports:       Traffic stats (active connection detection)"
    echo ""
    
    echo -e "${YELLOW}IMPORTANT - About ARP Discovery:${NC}"
    echo "  ⚠  ARP-based discovery requires IP traffic to be flowing"
    echo "  ⚠  DPDK interfaces appear 'down' until DPDK application starts"
    echo "  ⚠  Run your packet generator to populate ARP table"
    echo ""
    echo "  To force discovery after traffic starts:"
    echo "    curl http://localhost:8080/api/ports/refresh"
    echo ""
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Start your DPDK packet generator"
    echo "  2. Generate some traffic (even small amounts)"
    echo "  3. Wait 5-10 seconds for ARP table to populate"
    echo "  4. Check web GUI: http://YOUR_IP:8080"
    echo "  5. Or test API: curl http://localhost:8080/api/ports/status | jq"
    echo ""
    
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  # Check what's discovered right now"
    echo "  arp -n"
    echo ""
    echo "  # Manually check LLDP on MGMT"
    echo "  lldpctl eno1"
    echo ""
    echo "  # Run diagnostics"
    echo "  cd $WEB_DIR && python3 diagnose_installation.py"
    echo ""
    echo "  # View service logs"
    echo "  journalctl -u $SERVICE_NAME -n 50 -f"
    echo ""
    
    echo -e "${GREEN}Backup Location:${NC}"
    echo "  $BACKUP_DIR"
    echo ""
    
    echo -e "${BLUE}Documentation:${NC}"
    echo "  See HYBRID_INSTALL_GUIDE.md for detailed information"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_header "Hybrid Port Discovery Installer"
    
    echo "This will install LLDP + ARP-based device discovery for NetGen DPDK"
    echo "Installation directory: $INSTALL_DIR"
    echo ""
    
    # Checks
    check_root
    check_install_dir
    
    # Installation steps
    backup_files
    install_dependencies
    copy_files
    update_server_py
    update_index_html
    test_installation
    restart_service
    test_api_endpoint
    
    # Summary
    print_summary
}

# Run main installation
main "$@"
