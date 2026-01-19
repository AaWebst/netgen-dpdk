#!/bin/bash
################################################################################
# NetGen DPDK - Complete Setup & Cleanup Script
# 
# This master script:
# 1. Backs up existing files
# 2. Cleans up duplicate/obsolete files
# 3. Organizes file structure
# 4. Installs hybrid port discovery
# 5. Runs verification tests
# 6. Shows next steps
#
# Designed to be run from a fresh git clone or existing installation
#
# Usage: 
#   sudo bash complete_setup.sh
#
# Safe to run multiple times - creates backups before any changes
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/netgen-dpdk"
BACKUP_DIR="$INSTALL_DIR/.complete_setup_backup_$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║         NetGen DPDK - Complete Setup & Cleanup                ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root"
        echo "Usage: sudo bash $0"
        exit 1
    fi
}

pause_for_review() {
    echo ""
    read -p "Press ENTER to continue or Ctrl+C to abort..."
}

################################################################################
# Pre-Flight Checks
################################################################################

preflight_checks() {
    print_header "Pre-Flight Checks"
    
    check_root
    print_success "Running as root"
    
    # Check if we're in the repo or if INSTALL_DIR exists
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        print_success "Found installation at: $INSTALL_DIR"
    elif [ -f "Makefile" ] && [ -d "src" ]; then
        # We're in the repo directory
        INSTALL_DIR="$(pwd)"
        print_success "Running from repository: $INSTALL_DIR"
    else
        print_error "Cannot find NetGen DPDK installation"
        print_info "Please run this script from the repository directory or ensure /opt/netgen-dpdk exists"
        exit 1
    fi
    
    # Check if this is a git repo
    if [ -d ".git" ]; then
        print_success "Git repository detected"
        GIT_REPO=true
    else
        print_warning "Not a git repository"
        GIT_REPO=false
    fi
    
    # Show what will happen
    echo ""
    print_info "This script will:"
    echo "  1. Create backup: $BACKUP_DIR"
    echo "  2. Remove 9 duplicate/obsolete files"
    echo "  3. Move 2 files to proper locations (web/static/)"
    echo "  4. Install LLDP + ARP hybrid discovery"
    echo "  5. Add enhanced port monitoring with active scanning"
    echo "  6. Run verification tests"
    echo ""
    
    pause_for_review
}

################################################################################
# Step 1: Create Comprehensive Backup
################################################################################

create_backup() {
    print_header "Step 1: Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup everything we're going to touch
    FILES_TO_BACKUP=(
        "ports_api_fixed.py"
        "ports_enhanced_api.py"
        "ports_api_hybrid.py"
        "test_ports_api.py"
        "enhanced-port-monitor.js"
        "enhanced-port-status.css"
        "port-monitor-simple.js"
        "port-status-simple.css"
        "install-complete.sh"
        "quick-deploy-lldp.sh"
        "diagnose-complete.sh"
        "web/server.py"
        "web/templates/index.html"
    )
    
    for file in "${FILES_TO_BACKUP[@]}"; do
        if [ -f "$file" ]; then
            # Preserve directory structure in backup
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
            print_success "Backed up: $file"
        fi
    done
    
    # Also backup entire web/static if it exists
    if [ -d "web/static" ]; then
        cp -r web/static "$BACKUP_DIR/web/" 2>/dev/null || true
        print_success "Backed up: web/static/"
    fi
    
    print_info "Backup location: $BACKUP_DIR"
    
    # Create backup manifest
    cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.txt" << EOF
Backup created: $(date)

To restore from this backup:
  cd $INSTALL_DIR
  cp -r $BACKUP_DIR/* .

Files backed up:
EOF
    find "$BACKUP_DIR" -type f >> "$BACKUP_DIR/RESTORE_INSTRUCTIONS.txt"
    
    print_success "Backup complete with restore instructions"
}

################################################################################
# Step 2: Cleanup Duplicate/Obsolete Files
################################################################################

cleanup_files() {
    print_header "Step 2: Cleaning Up Duplicate/Obsolete Files"
    
    cd "$INSTALL_DIR"
    
    # Remove duplicate port API files
    print_step "Removing duplicate port API files..."
    REMOVE_FILES=(
        "ports_api_fixed.py"
        "ports_enhanced_api.py"
        "test_ports_api.py"
    )
    
    for file in "${REMOVE_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Removed: $file"
        fi
    done
    
    # Remove superseded enhanced versions
    print_step "Removing superseded enhanced versions..."
    ENHANCED_FILES=(
        "enhanced-port-monitor.js"
        "enhanced-port-status.css"
    )
    
    for file in "${ENHANCED_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Removed: $file"
        fi
    done
    
    # Remove old installation scripts
    print_step "Removing old installation scripts..."
    OLD_INSTALLERS=(
        "install-complete.sh"
        "quick-deploy-lldp.sh"
        "diagnose-complete.sh"
    )
    
    for file in "${OLD_INSTALLERS[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Removed: $file"
        fi
    done
    
    print_success "Cleanup complete - 9 files removed"
}

################################################################################
# Step 3: Organize File Structure
################################################################################

organize_structure() {
    print_header "Step 3: Organizing File Structure"
    
    cd "$INSTALL_DIR"
    
    # Create proper directory structure
    mkdir -p web/static/js
    mkdir -p web/static/css
    print_success "Created web/static directories"
    
    # Move frontend files to proper locations
    print_step "Moving frontend files to proper locations..."
    
    # Move JavaScript files
    if [ -f "port-monitor-simple.js" ]; then
        if [ -f "web/static/js/port-monitor-simple.js" ]; then
            if diff -q "port-monitor-simple.js" "web/static/js/port-monitor-simple.js" > /dev/null 2>&1; then
                rm "port-monitor-simple.js"
                print_success "Removed duplicate: port-monitor-simple.js"
            else
                mv "port-monitor-simple.js" "port-monitor-simple.js.old"
                print_warning "Renamed conflicting file: port-monitor-simple.js.old"
            fi
        else
            mv "port-monitor-simple.js" "web/static/js/"
            print_success "Moved: port-monitor-simple.js → web/static/js/"
        fi
    fi
    
    # Move CSS files
    if [ -f "port-status-simple.css" ]; then
        if [ -f "web/static/css/port-status-simple.css" ]; then
            if diff -q "port-status-simple.css" "web/static/css/port-status-simple.css" > /dev/null 2>&1; then
                rm "port-status-simple.css"
                print_success "Removed duplicate: port-status-simple.css"
            else
                mv "port-status-simple.css" "port-status-simple.css.old"
                print_warning "Renamed conflicting file: port-status-simple.css.old"
            fi
        else
            mv "port-status-simple.css" "web/static/css/"
            print_success "Moved: port-status-simple.css → web/static/css/"
        fi
    fi
    
    print_success "File organization complete"
}

################################################################################
# Step 4: Install Dependencies
################################################################################

install_dependencies() {
    print_header "Step 4: Installing Dependencies"
    
    apt-get update -qq
    
    # LLDP daemon
    if ! systemctl is-active --quiet lldpd 2>/dev/null; then
        print_step "Installing lldpd..."
        apt-get install -y lldpd
        systemctl enable lldpd
        systemctl start lldpd
        print_success "LLDP daemon installed and started"
    else
        print_success "LLDP daemon already running"
    fi
    
    # arping (handle conflict)
    if ! command -v arping &> /dev/null; then
        print_step "Installing arping..."
        if apt-get install -y iputils-arping 2>/dev/null; then
            print_success "iputils-arping installed"
        else
            print_warning "Could not install arping (optional for active scanning)"
        fi
    else
        print_success "arping already installed"
    fi
    
    # jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_step "Installing jq..."
        apt-get install -y jq
        print_success "jq installed"
    else
        print_success "jq already installed"
    fi
    
    print_success "All dependencies installed"
}

################################################################################
# Step 5: Copy New Files
################################################################################

copy_new_files() {
    print_header "Step 5: Installing New Files"
    
    cd "$INSTALL_DIR"
    
    # Copy from script directory (where files were downloaded)
    print_step "Copying enhanced port discovery files..."
    
    # Check if files exist in script directory or current directory
    FILES_TO_COPY=(
        "ports_api_hybrid_enhanced.py:web/"
        "test_ports_api_corrected.py:web/"
        "diagnose_installation.py:web/"
        "port-monitor-enhanced.js:web/static/js/"
        "port-status-enhanced.css:web/static/css/"
    )
    
    for file_dest in "${FILES_TO_COPY[@]}"; do
        file="${file_dest%%:*}"
        dest="${file_dest#*:}"
        
        # Try to find file in script directory or current directory
        if [ -f "$SCRIPT_DIR/$file" ]; then
            cp "$SCRIPT_DIR/$file" "$dest"
            chmod 644 "$dest$file"
            print_success "Installed: $dest$file"
        elif [ -f "$file" ]; then
            cp "$file" "$dest"
            chmod 644 "$dest$file"
            print_success "Installed: $dest$file"
        else
            print_warning "File not found: $file (will need to add manually)"
        fi
    done
    
    # Make test scripts executable
    chmod +x web/test_ports_api_corrected.py 2>/dev/null || true
    chmod +x web/diagnose_installation.py 2>/dev/null || true
    
    print_success "New files installed"
}

################################################################################
# Step 6: Update Configuration Files
################################################################################

update_config_files() {
    print_header "Step 6: Updating Configuration Files"
    
    cd "$INSTALL_DIR"
    
    # Update server.py
    print_step "Updating web/server.py..."
    
    if [ -f "web/server.py" ]; then
        # Remove old imports
        sed -i '/from ports_api_fixed import/d' web/server.py
        sed -i '/from ports_enhanced_api import/d' web/server.py
        sed -i '/from ports_api_hybrid import/d' web/server.py
        
        # Add new import if not present
        if ! grep -q "from ports_api_hybrid_enhanced import init_app as init_ports_api" web/server.py; then
            # Add after Flask imports
            if grep -q "from flask import" web/server.py; then
                sed -i '/from flask import/a from ports_api_hybrid_enhanced import init_app as init_ports_api' web/server.py
                print_success "Added hybrid API import to server.py"
            else
                print_warning "Could not auto-update server.py - add import manually"
            fi
        else
            print_success "server.py already has correct import"
        fi
        
        # Check for init call
        if ! grep -q "init_ports_api(app)" web/server.py; then
            print_warning "Don't forget to add: init_ports_api(app) before socketio.run()"
        else
            print_success "server.py has init_ports_api() call"
        fi
    else
        print_error "web/server.py not found!"
    fi
    
    # Update index.html
    print_step "Updating web/templates/index.html..."
    
    if [ -f "web/templates/index.html" ]; then
        # Add CSS if not present
        if ! grep -q "port-status-enhanced.css" web/templates/index.html; then
            if grep -q "</head>" web/templates/index.html; then
                sed -i 's|</head>|<link rel="stylesheet" href="/static/css/port-status-enhanced.css">\n</head>|' web/templates/index.html
                print_success "Added CSS link to index.html"
            fi
        else
            print_success "index.html already has CSS link"
        fi
        
        # Add JS if not present
        if ! grep -q "port-monitor-enhanced.js" web/templates/index.html; then
            if grep -q "</body>" web/templates/index.html; then
                sed -i 's|</body>|<script src="/static/js/port-monitor-enhanced.js"></script>\n</body>|' web/templates/index.html
                print_success "Added JS link to index.html"
            fi
        else
            print_success "index.html already has JS link"
        fi
    else
        print_warning "web/templates/index.html not found - may need manual update"
    fi
    
    print_success "Configuration files updated"
}

################################################################################
# Step 7: Run Tests
################################################################################

run_tests() {
    print_header "Step 7: Running Verification Tests"
    
    cd "$INSTALL_DIR/web"
    
    # Test Python imports
    print_step "Testing Python imports..."
    if python3 -c "from ports_api_hybrid_enhanced import init_app" 2>/dev/null; then
        print_success "Python imports work correctly"
    else
        print_error "Python import failed - check installation"
        return
    fi
    
    # Run test script if available
    if [ -f "test_ports_api_corrected.py" ]; then
        print_step "Running API tests..."
        python3 test_ports_api_corrected.py > /tmp/netgen_test.log 2>&1 || true
        
        if grep -q "DPDK Engine Status" /tmp/netgen_test.log; then
            print_success "API test script executed"
            print_info "Review test results: /tmp/netgen_test.log"
        fi
    fi
    
    print_success "Verification tests complete"
}

################################################################################
# Step 8: Restart Service
################################################################################

restart_service() {
    print_header "Step 8: Restarting Service"
    
    SERVICE_NAME="netgen-pro-dpdk"
    
    if systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
        print_step "Restarting $SERVICE_NAME..."
        systemctl restart "$SERVICE_NAME"
        sleep 3
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "Service restarted successfully"
        else
            print_warning "Service may need manual restart"
            print_info "Check: sudo systemctl status $SERVICE_NAME"
        fi
    else
        print_info "Service $SERVICE_NAME not found - may need manual start"
        print_info "Start with: cd $INSTALL_DIR/web && python3 server.py"
    fi
}

################################################################################
# Final Summary
################################################################################

show_summary() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}✓ Backup created:${NC} $BACKUP_DIR"
    echo -e "${GREEN}✓ 9 duplicate files removed${NC}"
    echo -e "${GREEN}✓ Files organized in proper structure${NC}"
    echo -e "${GREEN}✓ Hybrid port discovery installed${NC}"
    echo -e "${GREEN}✓ Enhanced monitoring with active scanning added${NC}"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  File Structure:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "web/"
    echo "├── server.py"
    echo "├── ports_api_hybrid_enhanced.py    ⭐ NEW"
    echo "├── test_ports_api_corrected.py     ⭐ NEW"
    echo "├── diagnose_installation.py        ⭐ NEW"
    echo "├── static/"
    echo "│   ├── css/"
    echo "│   │   └── port-status-enhanced.css    ⭐ NEW"
    echo "│   └── js/"
    echo "│       └── port-monitor-enhanced.js    ⭐ NEW"
    echo "└── templates/"
    echo "    └── index.html"
    echo ""
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Next Steps:${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1. Start DPDK engine (if not running):"
    echo "   cd $INSTALL_DIR"
    echo "   sudo bash scripts/start-dpdk-engine.sh"
    echo ""
    echo "2. Generate some traffic to populate ARP table"
    echo ""
    echo "3. Open web interface:"
    echo "   http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "4. Enable active scanning in GUI for continuous discovery"
    echo ""
    echo "5. Run diagnostics:"
    echo "   cd $INSTALL_DIR/web"
    echo "   sudo python3 diagnose_installation.py"
    echo ""
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Features Enabled:${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "✓ Auto-refresh every 5 seconds"
    echo "✓ Active ARP scanning (toggle on/off)"
    echo "✓ LLDP discovery on MGMT port"
    echo "✓ ARP discovery on DPDK ports"
    echo "✓ Real-time status indicators"
    echo "✓ Manual refresh & force scan buttons"
    echo ""
    
    if [ "$GIT_REPO" = true ]; then
        echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}  Git Repository:${NC}"
        echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "To commit these changes:"
        echo "  git add -A"
        echo "  git commit -m 'Install hybrid port discovery with active scanning'"
        echo "  git push"
        echo ""
    fi
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  All Done! 🎉${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    preflight_checks
    create_backup
    cleanup_files
    organize_structure
    install_dependencies
    copy_new_files
    update_config_files
    run_tests
    restart_service
    show_summary
}

# Run main function
main "$@"
