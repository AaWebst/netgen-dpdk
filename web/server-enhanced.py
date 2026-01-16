#!/usr/bin/env python3
"""
NetGen Pro v4.1 - Enhanced Web Server with DPDK Link Status
Features:
- Real-time link status via DPDK API
- Device discovery via ARP inspection
- Active subnet scanning
- Port statistics
"""

from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit
import subprocess
import json
import time
import socket as sock
import struct

app = Flask(__name__)
app.config['SECRET_KEY'] = 'netgen-pro-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

CONTROL_SOCKET = '/tmp/dpdk_engine_control.sock'

def send_dpdk_command(command_dict, timeout=10):
    """Send command to DPDK engine via Unix socket"""
    try:
        client = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
        client.settimeout(timeout)
        client.connect(CONTROL_SOCKET)
        
        cmd_json = json.dumps(command_dict)
        client.sendall(cmd_json.encode() + b'\n')
        
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
            return {'status': 'error', 'message': 'No response'}
            
    except sock.timeout:
        return {'status': 'error', 'message': 'Timeout'}
    except FileNotFoundError:
        return {'status': 'error', 'message': 'DPDK engine not running'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

@app.route('/api/ports/dpdk_status')
def get_dpdk_port_status():
    """Get DPDK port status including link state"""
    try:
        # Request port status from DPDK engine
        response = send_dpdk_command({'command': 'port_status'})
        
        if response.get('status') == 'success':
            return jsonify(response)
        else:
            # Fallback if command not implemented yet
            return jsonify({
                'status': 'info',
                'message': 'DPDK port status API not yet integrated in engine',
                'ports': []
            })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/ports/discovered_devices')
def get_discovered_devices():
    """Get devices discovered via ARP inspection"""
    try:
        port_id = request.args.get('port_id', 0, type=int)
        
        response = send_dpdk_command({
            'command': 'get_discovered_devices',
            'port_id': port_id
        })
        
        if response.get('status') == 'success':
            return jsonify(response)
        else:
            return jsonify({
                'status': 'info',
                'message': 'Device discovery not yet enabled',
                'devices': []
            })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/ports/scan_subnet', methods=['POST'])
def scan_subnet():
    """Trigger active subnet scan"""
    try:
        data = request.json
        port_id = data.get('port_id', 0)
        subnet = data.get('subnet', '192.168.1.0/24')
        
        # Parse subnet
        network, prefix = subnet.split('/')
        
        response = send_dpdk_command({
            'command': 'scan_subnet',
            'port_id': port_id,
            'network': network,
            'prefix_len': int(prefix)
        })
        
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/ports/enhanced_status')
def get_enhanced_port_status():
    """
    Get comprehensive port status combining:
    - DPDK link status (from DPDK API)
    - Discovered devices (from ARP inspection)  
    - Port statistics
    """
    try:
        # VEP1445 interface definitions
        interfaces = {
            'eno1': {'label': 'MGMT', 'type': '1G', 'dpdk_port_id': None},
            'eno2': {'label': 'LAN1', 'type': '1G', 'dpdk_port_id': 0},
            'eno3': {'label': 'LAN2', 'type': '1G', 'dpdk_port_id': 1},
            'eno4': {'label': 'LAN3', 'type': '1G', 'dpdk_port_id': 2},
            'eno5': {'label': 'LAN4', 'type': '1G', 'dpdk_port_id': 3},
            'eno6': {'label': 'LAN5', 'type': '1G', 'dpdk_port_id': 4},
            'eno7': {'label': '10G TX', 'type': '10G', 'dpdk_port_id': 5},
            'eno8': {'label': '10G RX', 'type': '10G', 'dpdk_port_id': 6},
        }
        
        ports_status = []
        
        # Get DPDK port status
        dpdk_status = send_dpdk_command({'command': 'port_status'}, timeout=3)
        dpdk_ports = {}
        
        if dpdk_status.get('status') == 'success' and 'ports' in dpdk_status:
            for port in dpdk_status['ports']:
                dpdk_ports[port['port_id']] = port
        
        for iface, info in interfaces.items():
            port = {
                'name': iface,
                'label': info['label'],
                'type': info['type'],
                'dpdk_port_id': info['dpdk_port_id'],
                'status': 'UNKNOWN',
                'link': 'unknown',
                'link_speed': 0,
                'link_speed_str': 'Unknown',
                'duplex': 'unknown',
                'mac_address': None,
                'rx_packets': 0,
                'tx_packets': 0,
                'rx_bytes': 0,
                'tx_bytes': 0,
                'discovered_devices': []
            }
            
            # Check if this interface has a DPDK port ID
            if info['dpdk_port_id'] is not None:
                port['status'] = 'DPDK'
                
                # Get DPDK port info if available
                if info['dpdk_port_id'] in dpdk_ports:
                    dpdk_info = dpdk_ports[info['dpdk_port_id']]
                    port['link'] = dpdk_info.get('link_status', 'unknown')
                    port['link_speed'] = dpdk_info.get('link_speed', 0)
                    port['link_speed_str'] = dpdk_info.get('link_speed_str', 'Unknown')
                    port['duplex'] = dpdk_info.get('link_duplex', 'unknown')
                    port['mac_address'] = dpdk_info.get('mac_address')
                    port['rx_packets'] = dpdk_info.get('rx_packets', 0)
                    port['tx_packets'] = dpdk_info.get('tx_packets', 0)
                    port['rx_bytes'] = dpdk_info.get('rx_bytes', 0)
                    port['tx_bytes'] = dpdk_info.get('tx_bytes', 0)
                    
                    # Get discovered devices
                    dev_response = send_dpdk_command({
                        'command': 'get_discovered_devices',
                        'port_id': info['dpdk_port_id']
                    }, timeout=2)
                    
                    if dev_response.get('status') == 'success':
                        port['discovered_devices'] = dev_response.get('devices', [])
                else:
                    port['link'] = 'dpdk_no_info'
            else:
                # eno1 - kernel driver, check via sysfs
                port['status'] = 'LINUX'
                try:
                    with open(f'/sys/class/net/{iface}/operstate', 'r') as f:
                        state = f.read().strip()
                    port['link'] = 'up' if state == 'up' else 'down'
                    
                    try:
                        with open(f'/sys/class/net/{iface}/speed', 'r') as f:
                            speed = int(f.read().strip())
                        port['link_speed'] = speed
                        port['link_speed_str'] = f"{speed} Mbps"
                    except:
                        pass
                    
                    with open(f'/sys/class/net/{iface}/address', 'r') as f:
                        port['mac_address'] = f.read().strip()
                except:
                    pass
            
            ports_status.append(port)
        
        return jsonify({
            'status': 'success',
            'timestamp': int(time.time()),
            'ports': ports_status
        })
        
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/start', methods=['POST'])
def start_traffic():
    """Start traffic generation"""
    try:
        data = request.json
        response = send_dpdk_command({'command': 'start', **data})
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stop', methods=['POST'])
def stop_traffic():
    """Stop traffic generation"""
    try:
        response = send_dpdk_command({'command': 'stop'})
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/status')
def get_status():
    """Get engine status"""
    try:
        response = send_dpdk_command({'command': 'status'}, timeout=3)
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)})

@app.route('/api/stats')
def get_stats():
    """Get statistics"""
    try:
        response = send_dpdk_command({'command': 'stats'}, timeout=3)
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)})

@app.route('/')
def index():
    """Serve main page"""
    return render_template('index.html')

if __name__ == '__main__':
    print("=" * 70)
    print("NetGen Pro v4.1 - Enhanced Web Server")
    print("=" * 70)
    print("Features:")
    print("  • DPDK link status detection")
    print("  • Device discovery via ARP inspection")
    print("  • Active subnet scanning")
    print("  • Real-time port statistics")
    print("=" * 70)
    print(f"Listening on: http://0.0.0.0:8080")
    print(f"Control socket: {CONTROL_SOCKET}")
    print("=" * 70)
    
    socketio.run(app, host='0.0.0.0', port=8080, debug=False, allow_unsafe_werkzeug=True)
