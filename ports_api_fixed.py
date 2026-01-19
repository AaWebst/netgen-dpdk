#!/usr/bin/env python3
"""
Enhanced Port Status API - FIXED VERSION
Corrects Flask Blueprint registration and endpoint paths
"""

from flask import Blueprint, jsonify
import subprocess
import json
import re
import time

def run_command(cmd, timeout=3):
    """Safely run a shell command"""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return result.stdout
    except Exception as e:
        print(f"Command error: {e}")
        return ""

def get_lldp_neighbors(interface):
    """Get LLDP neighbor info for an interface"""
    try:
        output = run_command(['lldpctl', interface])
        if not output:
            return None
        
        neighbor = {}
        for line in output.split('\n'):
            line = line.strip()
            if 'SysName:' in line:
                neighbor['system_name'] = line.split(':', 1)[1].strip()
            elif 'PortDescr:' in line or 'PortID:' in line:
                neighbor['port'] = line.split(':', 1)[1].strip()
        
        return neighbor if neighbor else None
    except Exception as e:
        print(f"LLDP error for {interface}: {e}")
        return None

def get_link_status(interface):
    """Get link status for an interface"""
    try:
        output = run_command(['ethtool', interface], timeout=2)
        
        link = 'down'
        speed = 0
        
        if 'Link detected: yes' in output:
            link = 'up'
            
        speed_match = re.search(r'Speed: (\d+)Mb/s', output)
        if speed_match:
            speed = int(speed_match.group(1))
        
        return {'link': link, 'speed': speed}
    except Exception as e:
        print(f"Link status error for {interface}: {e}")
        return {'link': 'unknown', 'speed': 0}

def get_all_port_status():
    """Get status for all ports"""
    # VEP1445 port definitions
    ports = [
        {'name': 'eno1', 'label': 'MGMT', 'dpdk': False},
        {'name': 'eno2', 'label': 'LAN1', 'dpdk': True},
        {'name': 'eno3', 'label': 'LAN2', 'dpdk': True},
        {'name': 'eno4', 'label': 'LAN3', 'dpdk': True},
        {'name': 'eno5', 'label': 'LAN4', 'dpdk': True},
        {'name': 'eno6', 'label': 'LAN5', 'dpdk': True},
        {'name': 'eno7', 'label': '10G-1', 'dpdk': True},
        {'name': 'eno8', 'label': '10G-2', 'dpdk': True},
    ]
    
    result = []
    
    for port in ports:
        # Get link status
        link_info = get_link_status(port['name'])
        
        # Get LLDP neighbor
        neighbor = get_lldp_neighbors(port['name'])
        
        # Build display name
        display_name = port['label']
        if neighbor and neighbor.get('system_name'):
            display_name = f"{port['label']} → {neighbor['system_name']}"
            if neighbor.get('port'):
                display_name = f"{port['label']} → {neighbor['system_name']}:{neighbor['port']}"
        
        port_info = {
            'interface': port['name'],
            'label': port['label'],
            'display_name': display_name,
            'link': link_info['link'],
            'speed': link_info['speed'],
            'dpdk_bound': port['dpdk'],
            'neighbor': neighbor
        }
        
        result.append(port_info)
    
    return result

# OPTION 1: Add routes directly to main app (no Blueprint)
def add_port_routes(app):
    """Add port status routes directly to Flask app"""
    
    @app.route('/api/ports/status')
    def api_port_status():
        """Get enhanced port status with LLDP"""
        try:
            ports = get_all_port_status()
            return jsonify({
                'status': 'success',
                'timestamp': int(time.time()),
                'ports': ports
            })
        except Exception as e:
            print(f"Port status API error: {e}")
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500
    
    @app.route('/api/ports/refresh')
    def api_port_refresh():
        """Force LLDP refresh"""
        try:
            subprocess.run(['systemctl', 'restart', 'lldpd'], timeout=5)
            return jsonify({
                'status': 'success',
                'message': 'LLDP refreshed'
            })
        except Exception as e:
            print(f"LLDP refresh error: {e}")
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500

# OPTION 2: Use Blueprint (alternative method)
ports_blueprint = Blueprint('ports', __name__)

@ports_blueprint.route('/api/ports/status')
def bp_port_status():
    """Get enhanced port status with LLDP"""
    try:
        ports = get_all_port_status()
        return jsonify({
            'status': 'success',
            'timestamp': int(time.time()),
            'ports': ports
        })
    except Exception as e:
        print(f"Port status API error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@ports_blueprint.route('/api/ports/refresh')
def bp_port_refresh():
    """Force LLDP refresh"""
    try:
        subprocess.run(['systemctl', 'restart', 'lldpd'], timeout=5)
        return jsonify({
            'status': 'success',
            'message': 'LLDP refreshed'
        })
    except Exception as e:
        print(f"LLDP refresh error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

def register_blueprint(app):
    """Register the blueprint (Option 2)"""
    app.register_blueprint(ports_blueprint)

# Main init function - USE THIS
def init_app(app):
    """
    Initialize port status API with Flask app
    
    This uses Option 1 (direct routes) which is simpler and more reliable
    """
    print("Initializing port status API...")
    add_port_routes(app)
    print("Port status API initialized: /api/ports/status and /api/ports/refresh")
