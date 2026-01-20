#!/usr/bin/env python3
"""
Proactive DPDK Port Discovery API
Uses custom DPDK ARP discovery tool to find devices BEFORE traffic flows
"""

from flask import Blueprint, jsonify, request
import subprocess
import json
import re
import os

ports_bp = Blueprint('ports', __name__)

# DPDK port mapping with discovery targets
DPDK_PORTS = {
    'eno2': {
        'label': 'LAN1', 
        'dpdk_bound': True, 
        'port_id': 0,
        'probe_ips': ['192.168.1.1', '192.168.1.2', '192.168.1.254'],
        'src_ip': '192.168.1.100'
    },
    'eno3': {
        'label': 'LAN2', 
        'dpdk_bound': True, 
        'port_id': 1,
        'probe_ips': ['192.168.2.1', '192.168.2.2', '192.168.2.254'],
        'src_ip': '192.168.2.100'
    },
    'eno4': {
        'label': 'LAN3', 
        'dpdk_bound': True, 
        'port_id': 2,
        'probe_ips': ['192.168.3.1', '192.168.3.2', '192.168.3.254'],
        'src_ip': '192.168.3.100'
    },
    'eno5': {
        'label': 'LAN4', 
        'dpdk_bound': True, 
        'port_id': 3,
        'probe_ips': ['192.168.4.1', '192.168.4.2', '192.168.4.254'],
        'src_ip': '192.168.4.100'
    },
    'eno6': {
        'label': 'LAN5', 
        'dpdk_bound': True, 
        'port_id': 4,
        'probe_ips': ['192.168.5.1', '192.168.5.2', '192.168.5.254'],
        'src_ip': '192.168.5.100'
    },
    'eno7': {
        'label': '10G-1', 
        'dpdk_bound': True, 
        'port_id': 5,
        'probe_ips': ['192.168.6.1', '192.168.6.2', '192.168.6.254'],
        'src_ip': '192.168.6.100'
    },
    'eno8': {
        'label': '10G-2', 
        'dpdk_bound': True, 
        'port_id': 6,
        'probe_ips': ['192.168.7.1', '192.168.7.2', '192.168.7.254'],
        'src_ip': '192.168.7.100'
    },
    'eno1': {
        'label': 'MGMT', 
        'dpdk_bound': False, 
        'port_id': None,
        'probe_ips': [],
        'src_ip': None
    }
}

# Cache for discovered devices
DEVICE_CACHE = {}

def run_command(cmd):
    """Execute shell command"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout.strip(), result.returncode
    except:
        return "", -1

def get_link_status(interface):
    """Get link status"""
    output, _ = run_command(f"ethtool {interface} 2>/dev/null | grep 'Link detected'")
    if 'yes' in output.lower():
        speed_output, _ = run_command(f"ethtool {interface} 2>/dev/null | grep Speed")
        speed_match = re.search(r'(\d+)', speed_output)
        speed = speed_match.group(1) if speed_match else 'unknown'
        return 'up', speed
    return 'down', '0'

def dpdk_arp_probe(port_id, target_ip, src_ip):
    """
    Use DPDK ARP discovery tool to probe for device
    Returns: (ip, mac) tuple or None
    """
    tool_path = "/opt/netgen-dpdk/dpdk_arp_discover"
    
    # Check if tool exists
    if not os.path.exists(tool_path):
        print(f"DPDK ARP tool not found at {tool_path}")
        return None
    
    # Run the tool
    cmd = f"{tool_path} {port_id} {target_ip} {src_ip} 2>/dev/null"
    output, ret = run_command(cmd)
    
    # Parse output: "FOUND:192.168.1.1:aa:bb:cc:dd:ee:ff"
    if "FOUND:" in output:
        parts = output.split("FOUND:")[1].strip().split(":")
        if len(parts) >= 7:
            ip = parts[0]
            mac = ":".join(parts[1:7])
            return (ip, mac.lower())
    
    return None

def get_device_hostname(ip):
    """Try to get hostname via DNS reverse lookup"""
    try:
        import socket
        hostname, _, _ = socket.gethostbyaddr(ip)
        return hostname
    except:
        return None

def discover_on_port(interface, info):
    """
    Proactively discover devices on a port
    Returns neighbor info or None
    """
    if not info['dpdk_bound'] or not info['probe_ips']:
        return None
    
    port_id = info['port_id']
    src_ip = info['src_ip']
    
    # Try each probe IP
    for target_ip in info['probe_ips']:
        result = dpdk_arp_probe(port_id, target_ip, src_ip)
        
        if result:
            ip, mac = result
            
            # Try to get hostname
            hostname = get_device_hostname(ip)
            
            # Cache the result
            cache_key = f"{interface}:{ip}"
            DEVICE_CACHE[cache_key] = {
                'ip': ip,
                'mac': mac,
                'hostname': hostname,
                'system_name': hostname if hostname else f"Device at {ip}"
            }
            
            return DEVICE_CACHE[cache_key]
    
    return None

def get_lldp_neighbors(interface):
    """Get LLDP neighbors"""
    try:
        output, _ = run_command(f"lldpctl -f json {interface} 2>/dev/null")
        if output:
            data = json.loads(output)
            lldp_info = data.get('lldp', {}).get('interface', {}).get(interface, {})
            chassis = lldp_info.get('chassis', {})
            port = lldp_info.get('port', {})
            
            system_name = chassis.get('name', {}).get('value')
            if system_name:
                return {
                    'system_name': system_name,
                    'port_id': port.get('id', {}).get('value'),
                    'port_descr': port.get('descr', {}).get('value'),
                    'mac': chassis.get('mac', {}).get('value')
                }
    except:
        pass
    return None

@ports_bp.route('/api/ports/status', methods=['GET'])
def get_ports_status():
    """Get status with proactive discovery"""
    
    ports_status = []
    
    for interface, info in DPDK_PORTS.items():
        port_info = {
            'interface': interface,
            'label': info['label'],
            'dpdk_bound': info['dpdk_bound'],
            'port_id': info.get('port_id'),
            'link': 'unknown',
            'speed': '0',
            'neighbor': None,
            'discovery_method': 'none',
            'status_note': None
        }
        
        # Get link status
        link, speed = get_link_status(interface)
        port_info['link'] = link
        port_info['speed'] = speed
        
        if info['dpdk_bound'] and link == 'up':
            # Proactively discover
            neighbor = discover_on_port(interface, info)
            
            if neighbor:
                port_info['neighbor'] = neighbor
                port_info['discovery_method'] = 'dpdk_arp_probe'
            else:
                port_info['status_note'] = 'No device responding on probe IPs'
        
        elif not info['dpdk_bound']:
            # MGMT port - use LLDP
            lldp_neighbor = get_lldp_neighbors(interface)
            if lldp_neighbor:
                port_info['neighbor'] = lldp_neighbor
                port_info['discovery_method'] = 'lldp'
        
        else:
            port_info['status_note'] = 'Link down or no cable'
        
        ports_status.append(port_info)
    
    # Check DPDK engine
    dpdk_pid, _ = run_command("pgrep -f dpdk_engine")
    
    return jsonify({
        'status': 'success',
        'ports': ports_status,
        'dpdk_engine_running': bool(dpdk_pid),
        'discovery_method': 'proactive_dpdk_arp'
    })

@ports_bp.route('/api/ports/discover/<interface>', methods=['POST'])
def force_discover(interface):
    """Force discovery on specific port"""
    
    if interface not in DPDK_PORTS:
        return jsonify({'status': 'error', 'message': 'Invalid interface'}), 400
    
    info = DPDK_PORTS[interface]
    
    if not info['dpdk_bound']:
        return jsonify({'status': 'error', 'message': 'Not a DPDK port'}), 400
    
    # Discover
    neighbor = discover_on_port(interface, info)
    
    if neighbor:
        return jsonify({
            'status': 'success',
            'interface': interface,
            'neighbor': neighbor
        })
    else:
        return jsonify({
            'status': 'success',
            'interface': interface,
            'neighbor': None,
            'message': 'No device found'
        })

@ports_bp.route('/api/ports/neighbors', methods=['GET'])
def get_all_neighbors():
    """
    Get all discovered neighbors
    Useful for populating the Traffic Matrix GUI
    """
    neighbors = {}
    
    for interface, info in DPDK_PORTS.items():
        if info['dpdk_bound']:
            link, _ = get_link_status(interface)
            if link == 'up':
                neighbor = discover_on_port(interface, info)
                if neighbor:
                    neighbors[interface] = {
                        'label': info['label'],
                        'device_name': neighbor['system_name'],
                        'ip': neighbor['ip'],
                        'mac': neighbor['mac']
                    }
    
    return jsonify({
        'status': 'success',
        'neighbors': neighbors
    })

def init_app(app):
    """Initialize blueprint"""
    app.register_blueprint(ports_bp)
    print("✓ Proactive DPDK Port Discovery API initialized")
