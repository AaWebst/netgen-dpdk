#!/usr/bin/env python3
"""
Enhanced Port Status API with LLDP Discovery
Adds real-time link detection and connected device information
"""

from flask import Blueprint, jsonify
import subprocess
import json
import re
import time

ports_enhanced_api = Blueprint('ports_enhanced_api', __name__)

def get_dpdk_port_link_status(port_id):
    """
    Get link status from DPDK port using testpmd or rte_eth_link_get
    This would require extending the DPDK engine with port_status command
    For now, we'll return based on interface state
    """
    # Map DPDK port IDs to interfaces
    dpdk_port_map = {
        0: 'eno2',  # LAN1
        1: 'eno3',  # LAN2
        2: 'eno4',  # LAN3
        3: 'eno5',  # LAN4
        4: 'eno6',  # LAN5
        5: 'eno7',  # 10G TX
        6: 'eno8',  # 10G RX
    }
    
    interface = dpdk_port_map.get(port_id)
    if not interface:
        return {'link': 'unknown', 'speed': 0}
    
    # For DPDK-bound ports, check carrier via sysfs before binding
    # Or extend DPDK engine to report link status
    try:
        # Check if interface was up before DPDK binding
        result = subprocess.run(['ethtool', interface], 
                              capture_output=True, text=True, timeout=2)
        if 'Link detected: yes' in result.stdout:
            # Parse speed
            speed_match = re.search(r'Speed: (\d+)Mb/s', result.stdout)
            speed = int(speed_match.group(1)) if speed_match else 0
            return {'link': 'up', 'speed': speed}
    except:
        pass
    
    return {'link': 'down', 'speed': 0}

def discover_lldp_neighbor(interface):
    """Discover LLDP neighbor on an interface"""
    try:
        # Check if lldpd is running
        result = subprocess.run(['systemctl', 'is-active', 'lldpd'],
                              capture_output=True, text=True)
        if result.stdout.strip() != 'active':
            # Try to start lldpd
            subprocess.run(['systemctl', 'start', 'lldpd'], 
                          capture_output=True, timeout=5)
            time.sleep(2)
        
        # Get LLDP info for interface
        result = subprocess.run(['lldpctl', interface],
                              capture_output=True, text=True, timeout=3)
        if result.returncode != 0:
            return None
        
        neighbor = {}
        output = result.stdout
        
        # Parse LLDP output
        for line in output.split('\n'):
            line = line.strip()
            if 'SysName:' in line:
                neighbor['system_name'] = line.split(':', 1)[1].strip()
            elif 'SysDescr:' in line:
                neighbor['system_description'] = line.split(':', 1)[1].strip()
            elif 'PortDescr:' in line or 'PortID:' in line:
                neighbor['port_description'] = line.split(':', 1)[1].strip()
            elif 'MgmtIP:' in line:
                neighbor['management_ip'] = line.split(':', 1)[1].strip()
            elif 'Capability:' in line or 'Capabilities:' in line:
                caps = line.split(':', 1)[1].strip() if ':' in line else ''
                neighbor['capabilities'] = caps
        
        return neighbor if neighbor else None
    except Exception as e:
        print(f"LLDP discovery error for {interface}: {e}")
        return None

def get_interface_carrier_state(interface):
    """Get carrier state even for DPDK-bound interfaces"""
    try:
        # Try sysfs first (won't work for DPDK-bound)
        with open(f'/sys/class/net/{interface}/carrier', 'r') as f:
            carrier = f.read().strip()
            return carrier == '1'
    except:
        pass
    
    # For DPDK-bound ports, we need to check via DPDK
    # This requires extending the DPDK engine
    return None

def get_mac_address(interface):
    """Get MAC address of interface"""
    try:
        with open(f'/sys/class/net/{interface}/address', 'r') as f:
            return f.read().strip()
    except:
        return None

@ports_enhanced_api.route('/api/ports/enhanced_status')
def get_enhanced_ports_status():
    """
    Get enhanced port status with:
    - Real-time link state
    - LLDP neighbor discovery
    - Connected device information
    """
    
    # VEP1445 interface definitions
    interfaces = {
        'eno1': {'label': 'MGMT', 'type': '1G', 'dpdk_port_id': None, 'color': 'blue'},
        'eno2': {'label': 'LAN1', 'type': '1G', 'dpdk_port_id': 0, 'color': 'primary'},
        'eno3': {'label': 'LAN2', 'type': '1G', 'dpdk_port_id': 1, 'color': 'primary'},
        'eno4': {'label': 'LAN3', 'type': '1G', 'dpdk_port_id': 2, 'color': 'primary'},
        'eno5': {'label': 'LAN4', 'type': '1G', 'dpdk_port_id': 3, 'color': 'primary'},
        'eno6': {'label': 'LAN5', 'type': '1G', 'dpdk_port_id': 4, 'color': 'primary'},
        'eno7': {'label': '10G TX', 'type': '10G', 'dpdk_port_id': 5, 'color': 'accent'},
        'eno8': {'label': '10G RX', 'type': '10G', 'dpdk_port_id': 6, 'color': 'accent'},
    }
    
    ports_status = []
    
    for iface, info in interfaces.items():
        port = {
            'name': iface,
            'label': info['label'],
            'original_label': info['label'],  # Keep original
            'type': info['type'],
            'dpdk_port_id': info['dpdk_port_id'],
            'color': info['color'],
            'status': 'UNKNOWN',
            'link': 'unknown',
            'link_speed': 0,
            'mac_address': None,
            'lldp_neighbor': None,
            'connected_device': None,
            'display_name': info['label']  # This will be updated with LLDP info
        }
        
        # Get MAC address
        port['mac_address'] = get_mac_address(iface)
        
        # Check if DPDK-bound
        try:
            result = subprocess.run(['dpdk-devbind.py', '--status'],
                                  capture_output=True, text=True, timeout=3)
            if iface in result.stdout and 'drv=vfio-pci' in result.stdout:
                port['status'] = 'DPDK'
                port['dpdk_bound'] = True
            else:
                port['status'] = 'LINUX'
                port['dpdk_bound'] = False
        except:
            port['status'] = 'UNKNOWN'
            port['dpdk_bound'] = False
        
        # Get link status (try multiple methods)
        if port['dpdk_bound']:
            # For DPDK ports, check before binding or via DPDK API
            # For now, assume link up if DPDK bound (we'll enhance DPDK engine later)
            port['link'] = 'dpdk_bound'
            port['link_speed'] = 1000 if info['type'] == '1G' else 10000
        else:
            # For kernel interfaces, use ethtool
            try:
                result = subprocess.run(['ethtool', iface],
                                      capture_output=True, text=True, timeout=2)
                if 'Link detected: yes' in result.stdout:
                    port['link'] = 'up'
                    # Get speed
                    speed_match = re.search(r'Speed: (\d+)Mb/s', result.stdout)
                    if speed_match:
                        port['link_speed'] = int(speed_match.group(1))
                else:
                    port['link'] = 'down'
            except:
                port['link'] = 'unknown'
        
        # LLDP discovery (only for non-DPDK or if we unbind temporarily)
        if not port['dpdk_bound'] or True:  # Try anyway
            lldp_info = discover_lldp_neighbor(iface)
            if lldp_info:
                port['lldp_neighbor'] = lldp_info
                
                # Update display name with connected device
                system_name = lldp_info.get('system_name', '')
                port_desc = lldp_info.get('port_description', '')
                
                if system_name:
                    # Format: "LAN1 → Switch1"
                    port['connected_device'] = system_name
                    port['display_name'] = f"{info['label']} → {system_name}"
                    
                    if port_desc and port_desc != system_name:
                        # Add port info: "LAN1 → Switch1:ge-0/0/1"
                        port['display_name'] = f"{info['label']} → {system_name}:{port_desc}"
                        port['connected_port'] = port_desc
        
        ports_status.append(port)
    
    return jsonify({
        'status': 'success',
        'timestamp': int(time.time()),
        'ports': ports_status
    })

@ports_enhanced_api.route('/api/ports/refresh_lldp')
def refresh_lldp():
    """Force LLDP refresh by restarting lldpd"""
    try:
        # Restart lldpd to force neighbor discovery
        subprocess.run(['systemctl', 'restart', 'lldpd'],
                      capture_output=True, timeout=5)
        time.sleep(3)  # Wait for LLDP to discover neighbors
        
        return jsonify({
            'status': 'success',
            'message': 'LLDP refreshed, discovering neighbors...'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# Register the blueprint
def register_enhanced_ports_api(app):
    app.register_blueprint(ports_enhanced_api)
