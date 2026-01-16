#!/usr/bin/env python3
"""
NetGen Pro v4.0.1 - Enhanced Web Server
Fixes:
- Port status integration
- LLDP discovery
- Traffic flow API
- Proper timeout handling
"""

from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_socketio import SocketIO, emit
import subprocess
import json
import time
import os
import threading
import socket as sock

app = Flask(__name__)
app.config['SECRET_KEY'] = 'netgen-pro-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Control socket path
CONTROL_SOCKET = '/tmp/dpdk_engine_control.sock'

# Global state
current_status = {
    'running': False,
    'profiles': [],
    'stats': {
        'tx_packets': 0,
        'rx_packets': 0,
        'tx_bytes': 0,
        'rx_bytes': 0,
        'throughput_mbps': 0.0
    }
}

# Port mapping (auto-detected from DPDK)
port_mapping = {}

def send_command_to_engine(command_dict, timeout=5):
    """Send command to DPDK engine via Unix socket"""
    try:
        # Create socket
        client = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
        client.settimeout(timeout)
        
        # Connect
        client.connect(CONTROL_SOCKET)
        
        # Send command
        cmd_json = json.dumps(command_dict)
        client.sendall(cmd_json.encode() + b'\n')
        
        # Receive response
        response = b''
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            response += chunk
            if b'\n' in chunk:
                break
        
        client.close()
        
        if response:
            return json.loads(response.decode().strip())
        else:
            return {'status': 'error', 'message': 'No response from engine'}
            
    except sock.timeout:
        return {'status': 'error', 'message': 'Engine timeout - check if DPDK engine is running'}
    except FileNotFoundError:
        return {'status': 'error', 'message': 'Control socket not found - DPDK engine not running'}
    except Exception as e:
        return {'status': 'error', 'message': f'Communication error: {str(e)}'}

def get_link_status(interface):
    """Get link status for an interface"""
    try:
        # Check operstate
        with open(f'/sys/class/net/{interface}/operstate', 'r') as f:
            state = f.read().strip().lower()
        
        # Get speed
        try:
            with open(f'/sys/class/net/{interface}/speed', 'r') as f:
                speed = int(f.read().strip())
        except:
            speed = 0
        
        return {
            'link': 'up' if state == 'up' else 'down',
            'speed': speed
        }
    except:
        return {'link': 'unknown', 'speed': 0}

def discover_lldp_neighbor(interface):
    """Discover LLDP neighbor on interface"""
    try:
        # Check if lldpd is running
        result = subprocess.run(['systemctl', 'is-active', 'lldpd'],
                              capture_output=True, text=True)
        if result.stdout.strip() != 'active':
            return None
        
        # Get LLDP info
        result = subprocess.run(['lldpctl', interface],
                              capture_output=True, text=True, timeout=2)
        if result.returncode != 0:
            return None
        
        neighbor = {}
        for line in result.stdout.split('\n'):
            if 'SysName:' in line:
                neighbor['system_name'] = line.split(':', 1)[1].strip()
            elif 'SysDescr:' in line:
                neighbor['system_description'] = line.split(':', 1)[1].strip()
            elif 'PortDescr:' in line:
                neighbor['port_description'] = line.split(':', 1)[1].strip()
            elif 'MgmtIP:' in line:
                neighbor['management_ip'] = line.split(':', 1)[1].strip()
        
        return neighbor if neighbor else None
    except:
        return None

def get_dpdk_ports():
    """Get DPDK port bindings and create mapping"""
    global port_mapping
    
    try:
        result = subprocess.run(['dpdk-devbind.py', '--status'],
                              capture_output=True, text=True, timeout=5)
        
        ports = {}
        dpdk_port_id = 0
        
        for line in result.stdout.split('\n'):
            # Match lines like: 0000:05:00.0 '...' if=eno7 drv=vfio-pci
            if 'if=' in line and 'drv=' in line:
                parts = line.split()
                for i, part in enumerate(parts):
                    if part.startswith('if='):
                        iface = part.split('=')[1]
                        if i > 0 and parts[i-1].startswith('drv='):
                            driver = parts[i-1].split('=')[1]
                            if driver == 'vfio-pci' or driver == 'igb_uio':
                                # This is a DPDK-bound port
                                ports[iface] = {
                                    'dpdk_port_id': dpdk_port_id,
                                    'driver': driver,
                                    'status': 'DPDK'
                                }
                                dpdk_port_id += 1
                            else:
                                ports[iface] = {
                                    'driver': driver,
                                    'status': 'LINUX'
                                }
        
        port_mapping = ports
        return ports
    except Exception as e:
        print(f"Error getting DPDK ports: {e}")
        return {}

@app.route('/')
def index():
    """Serve main page"""
    return render_template('index.html')

@app.route('/api/ports/status')
def get_ports_status():
    """Get enhanced port status with LLDP and link detection"""
    
    # Refresh DPDK port mapping
    dpdk_ports = get_dpdk_ports()
    
    # VEP1445 interface definitions
    interfaces = {
        'eno1': {'label': 'MGMT', 'type': '1G'},
        'eno2': {'label': 'LAN1', 'type': '1G'},
        'eno3': {'label': 'LAN2', 'type': '1G'},
        'eno4': {'label': 'LAN3', 'type': '1G'},
        'eno5': {'label': 'LAN4', 'type': '1G'},
        'eno6': {'label': 'LAN5', 'type': '1G'},
        'eno7': {'label': '10G TX', 'type': '10G'},
        'eno8': {'label': '10G RX', 'type': '10G'},
    }
    
    ports_status = []
    
    for iface, info in interfaces.items():
        port = {
            'name': iface,
            'label': info['label'],
            'type': info['type'],
            'status': 'UNKNOWN',
            'link': 'unknown',
            'speed': 0,
            'dpdk_port_id': None,
            'lldp_neighbor': None
        }
        
        # Check if in DPDK
        if iface in dpdk_ports:
            port.update(dpdk_ports[iface])
            if port['status'] == 'DPDK':
                port['link'] = 'dpdk_bound'
        else:
            # Try to get link status for kernel interfaces
            link_info = get_link_status(iface)
            port['link'] = link_info['link']
            port['speed'] = link_info['speed']
            port['status'] = 'LINUX' if port['link'] == 'up' else 'AVAIL'
        
        # Try LLDP discovery (only for non-DPDK interfaces)
        if port['status'] != 'DPDK':
            port['lldp_neighbor'] = discover_lldp_neighbor(iface)
        
        ports_status.append(port)
    
    return jsonify({
        'status': 'success',
        'timestamp': int(time.time()),
        'ports': ports_status
    })

@app.route('/api/start', methods=['POST'])
def start_traffic():
    """Start traffic generation"""
    try:
        data = request.json
        profiles = data.get('profiles', [])
        
        if not profiles:
            return jsonify({
                'status': 'error',
                'message': 'No profiles provided'
            }), 400
        
        # Map LAN names to DPDK port IDs
        for profile in profiles:
            # Handle source mapping
            src = profile.get('src', '')
            if src.startswith('LAN'):
                # Find corresponding interface
                iface = f"eno{int(src[3:]) + 1}"  # LAN1 -> eno2, LAN2 -> eno3
                if iface in port_mapping:
                    profile['src_port_id'] = port_mapping[iface].get('dpdk_port_id', 0)
                else:
                    profile['src_port_id'] = 0
            elif src == '10G':
                profile['src_port_id'] = port_mapping.get('eno7', {}).get('dpdk_port_id', 0)
            
            # Handle destination mapping
            dst = profile.get('dst', '')
            if dst.startswith('LAN'):
                iface = f"eno{int(dst[3:]) + 1}"
                if iface in port_mapping:
                    profile['dst_port_id'] = port_mapping[iface].get('dpdk_port_id', 1)
                else:
                    profile['dst_port_id'] = 1
            elif dst == '10G':
                profile['dst_port_id'] = port_mapping.get('eno8', {}).get('dpdk_port_id', 1)
        
        # Send to DPDK engine with longer timeout
        command = {
            'command': 'start',
            'profiles': profiles
        }
        
        response = send_command_to_engine(command, timeout=10)
        
        if response.get('status') == 'success':
            current_status['running'] = True
            current_status['profiles'] = profiles
        
        return jsonify(response)
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Failed to start traffic: {str(e)}'
        }), 500

@app.route('/api/stop', methods=['POST'])
def stop_traffic():
    """Stop traffic generation"""
    try:
        command = {'command': 'stop'}
        response = send_command_to_engine(command, timeout=10)
        
        if response.get('status') == 'success':
            current_status['running'] = False
            current_status['profiles'] = []
        
        return jsonify(response)
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Failed to stop traffic: {str(e)}'
        }), 500

@app.route('/api/status')
def get_status():
    """Get current engine status"""
    try:
        command = {'command': 'status'}
        response = send_command_to_engine(command, timeout=3)
        
        # Update local status
        if response.get('status') == 'success':
            current_status.update(response)
        
        return jsonify(current_status)
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e),
            'running': False
        })

@app.route('/api/stats')
def get_stats():
    """Get traffic statistics"""
    try:
        command = {'command': 'stats'}
        response = send_command_to_engine(command, timeout=3)
        
        if response.get('status') == 'success':
            current_status['stats'] = response.get('stats', {})
        
        return jsonify(response)
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        })

@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection"""
    print('Client connected')
    emit('status', current_status)

@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket disconnection"""
    print('Client disconnected')

@socketio.on('request_update')
def handle_update_request():
    """Handle request for status update"""
    try:
        command = {'command': 'stats'}
        response = send_command_to_engine(command, timeout=2)
        
        if response.get('status') == 'success':
            current_status['stats'] = response.get('stats', {})
            emit('stats_update', current_status['stats'])
    except:
        pass

def stats_update_thread():
    """Background thread to push stats updates"""
    while True:
        try:
            if current_status['running']:
                command = {'command': 'stats'}
                response = send_command_to_engine(command, timeout=2)
                
                if response.get('status') == 'success':
                    stats = response.get('stats', {})
                    socketio.emit('stats_update', stats, broadcast=True)
            
            time.sleep(1)
        except:
            time.sleep(1)

# Start background stats thread
stats_thread = threading.Thread(target=stats_update_thread, daemon=True)
stats_thread.start()

if __name__ == '__main__':
    # Initialize port mapping on startup
    get_dpdk_ports()
    
    print("=" * 70)
    print("NetGen Pro v4.0.1 Web Server")
    print("=" * 70)
    print(f"Listening on: http://0.0.0.0:8080")
    print(f"Control socket: {CONTROL_SOCKET}")
    print(f"DPDK ports detected: {len(port_mapping)}")
    for iface, info in port_mapping.items():
        if 'dpdk_port_id' in info:
            print(f"  {iface} → DPDK port {info['dpdk_port_id']}")
    print("=" * 70)
    
    # Check if LLDP is available
    try:
        result = subprocess.run(['systemctl', 'is-active', 'lldpd'],
                              capture_output=True, text=True)
        if result.stdout.strip() == 'active':
            print("✓ LLDP discovery enabled")
        else:
            print("✗ LLDP not available - install with: sudo apt-get install lldpd")
    except:
        print("✗ LLDP not available")
    
    print("=" * 70)
    
    # Run with SocketIO
    socketio.run(app, host='0.0.0.0', port=8080, debug=False, allow_unsafe_werkzeug=True)
