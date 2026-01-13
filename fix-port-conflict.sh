#!/bin/bash
#
# Fix port 8080 conflict
#

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          NetGen Pro - Port Conflict Resolver                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    echo "   Run: sudo bash fix-port-conflict.sh"
    exit 1
fi

echo "Checking what's using port 8080..."
echo ""

# Find what's using port 8080
PROCESS=$(lsof -ti :8080 2>/dev/null)

if [ -z "$PROCESS" ]; then
    echo "✅ Port 8080 is free!"
    echo ""
    echo "Trying to start service..."
    systemctl start netgen-pro-dpdk
    sleep 2
    systemctl status netgen-pro-dpdk --no-pager -l | head -15
    exit 0
fi

# Show what's using the port
echo "Found process using port 8080:"
echo ""
lsof -i :8080 | head -10
echo ""

# Get process details
PID=$(echo $PROCESS | awk '{print $1}')
PNAME=$(ps -p $PID -o comm= 2>/dev/null || echo "Unknown")

echo "Process: $PNAME (PID: $PID)"
echo ""

# Check if it's another instance of our service
if ps -p $PID -o cmd= 2>/dev/null | grep -q "dpdk_control_server\|netgen"; then
    echo "This appears to be another NetGen instance!"
    echo ""
    read -p "Kill this process and start service? (Y/n) " -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Killing process $PID..."
        kill -9 $PID 2>/dev/null
        sleep 1
        
        echo "Starting NetGen Pro service..."
        systemctl start netgen-pro-dpdk
        sleep 2
        
        if systemctl is-active --quiet netgen-pro-dpdk; then
            echo ""
            echo "✅ Service started successfully!"
            systemctl status netgen-pro-dpdk --no-pager -l | head -15
        else
            echo ""
            echo "❌ Service still failed to start"
            journalctl -u netgen-pro-dpdk -n 20 --no-pager
        fi
    fi
else
    echo "This is NOT a NetGen process."
    echo ""
    echo "Options:"
    echo "  1. Kill this process and use port 8080 for NetGen"
    echo "  2. Change NetGen to use a different port"
    echo "  3. Cancel"
    echo ""
    read -p "Choose (1/2/3): " -r CHOICE
    echo ""
    
    case $CHOICE in
        1)
            echo "Killing process $PID..."
            kill -9 $PID 2>/dev/null
            sleep 1
            echo "Starting NetGen Pro..."
            systemctl start netgen-pro-dpdk
            sleep 2
            systemctl status netgen-pro-dpdk --no-pager -l | head -15
            ;;
        2)
            echo "Changing NetGen to port 8081..."
            # Update control server
            sed -i "s/port=8080/port=8081/g" /opt/netgen-dpdk/web/dpdk_control_server.py
            
            echo "Starting NetGen Pro on port 8081..."
            systemctl start netgen-pro-dpdk
            sleep 2
            
            if systemctl is-active --quiet netgen-pro-dpdk; then
                echo ""
                echo "✅ Service started on port 8081!"
                echo ""
                echo "Access at: http://localhost:8081"
                echo ""
                systemctl status netgen-pro-dpdk --no-pager -l | head -15
            else
                echo ""
                echo "❌ Failed to start"
                journalctl -u netgen-pro-dpdk -n 20 --no-pager
            fi
            ;;
        *)
            echo "Cancelled"
            exit 0
            ;;
    esac
fi
