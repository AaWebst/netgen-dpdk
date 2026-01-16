#!/usr/bin/env python3
"""
NetGen Pro v4.0 - Enhanced Port Status API
Features:
- Dynamic DPDK port detection
- Link up/down status
- LLDP neighbor discovery
- Connected device information
"""

import subprocess
import json
import re
import time
from flask import Blueprint, jsonify

ports_api = Blueprint('ports_api', __name__)

def parse_dpdk_status():
    """Parse dpdk-devbind.py output to get port bindings"""
    try:
        result = subprocess.run(['dpdk-devbind.py', '--status'], 
                              capture_output=True, text=True, timeout=5)
        output = result.stdout
        
        ports = {}
        
        # Parse DPDK-bound devices
        dpdk_section = False
        kernel_section = False
        
        for line in output.split('\n'):
            if 'Network devices using DPDK' in line:
                dpdk_section = True
                kernel_section = False
                continue
            elif 'Network devices using kernel driver' in line:
                dpdk_section = False
                kernel_section = True
                continue
            elif line.strip() == '' or '=' in line:
                dpdk_section = False
                kernel_section = False
                continue
            
            # Parse device line: 0000:02:00.0 'Device Name' drv=vfio-pci unused=igb
            match = re.match(r'([0-9a-f:\.]+)\s+\'([^\']+)\'\s+(?:if=(\w+)\s+)?drv=(\S+)\s+unused=(\S+)', line)
            if match:
                pci, device_name, iface, driver, unused = match.groups()
                
                if iface:
                    status = 'LINUX' if kernel_section else 'DPDK'
                    ports[iface] = {
                        'name': iface,
                        'pci': pci,
                        'device': device_name,
                        'driver': driver,
                        'unused_driver': unused,
                        'status': status,
                        'dpdk_bound': dpdk_section
                    }
        
        return ports
    except Exception as e:
        print(f"Error parsing DPDK status: {e}")
        return {}

def get_interface_mapping():
    """Map interface names to their details"""
    mapping = {}
    
    # Standard VEP1445 interfaces
    interfaces = ['eno1', 'eno2', 'eno3', 'eno4', 'eno5', 'eno6', 'eno7', 'eno8']
    
    for iface in interfaces:
        try:
            # Get PCI address
            result = subprocess.run(['ethtool', '-i', iface], 
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                pci = None
                driver = None
                for line in result.stdout.split('\n'):
                    if line.startswith('bus-info:'):
                        pci = line.split(':')[1].strip()
                    elif line.startswith('driver:'):
                        driver = line.split(':')[1].strip()
                
                mapping[iface] = {
                    'name': iface,
                    'pci': pci,
                    'driver': driver
                }
        except:
            pass
    
    return mapping

def get_link_status(interface):
    """Get link up/down status for an interface"""
    try:
        # Try ethtool first
        result = subprocess.run(['ethtool', interface], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if 'Link detected:' in line:
                    return 'up' if 'yes' in line.lower() else 'down'
        
        # Fallback to /sys/class/net
        with open(f'/sys/class/net/{interface}/operstate', 'r') as f:
            state = f.read().strip().lower()
            return 'up' if state == 'up' else 'down'
    except:
        return 'unknown'

def get_link_speed(interface):
    """Get link speed in Mbps"""
    try:
        result = subprocess.run(['ethtool', interface], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if 'Speed:' in line:
                    # Extract speed (e.g., "10000Mb/s" or "1000Mb/s")
                    match = re.search(r'(\d+)Mb/s', line)
                    if match:
                        return int(match.group(1))
        return 0
    except:
        return 0

def get_mac_address(interface):
    """Get MAC address of interface"""
    try:
        with open(f'/sys/class/net/{interface}/address', 'r') as f:
            return f.read().strip()
    except:
        return None

def discover_lldp_neighbors(interface):
    """Discover LLDP neighbors on an interface"""
    try:
        # Check if lldpctl is available
        result = subprocess.run(['which', 'lldpctl'], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            return None
        
        # Get LLDP info for interface
        result = subprocess.run(['lldpctl', interface], 
                              capture_output=True, text=True, timeout=3)
        if result.returncode != 0:
            return None
        
        neighbor = {}
        output = result.stdout
        
        # Parse LLDP output
        for line in output.split('\n'):
            if 'SysName:' in line:
                neighbor['system_name'] = line.split(':', 1)[1].strip()
            elif 'SysDescr:' in line:
                neighbor['system_description'] = line.split(':', 1)[1].strip()
            elif 'PortDescr:' in line:
                neighbor['port_description'] = line.split(':', 1)[1].strip()
            elif 'MgmtIP:' in line:
                neighbor['management_ip'] = line.split(':', 1)[1].strip()
            elif 'Capability:' in line:
                caps = line.split(':', 1)[1].strip()
                neighbor['capabilities'] = caps
        
        return neighbor if neighbor else None
    except Exception as e:
        print(f"LLDP discovery error for {interface}: {e}")
        return None

def get_arp_neighbors(interface):
    """Get ARP table entries for interface subnet"""
    try:
        # Get interface IP
        result = subprocess.run(['ip', 'addr', 'show', interface], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode != 0:
            return []
        
        # Extract IP
        ip_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', result.stdout)
        if not ip_match:
            return []
        
        # Get ARP table
        result = subprocess.run(['arp', '-n'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode != 0:
            return []
        
        neighbors = []
        for line in result.stdout.split('\n')[1:]:  # Skip header
            parts = line.split()
            if len(parts) >= 5 and parts[4] == interface:
                neighbors.append({
                    'ip': parts[0],
                    'mac': parts[2],
                    'type': 'arp'
                })
        
        return neighbors
    except:
        return []

@ports_api.route('/api/ports/status')
def get_ports_status():
    """Get comprehensive port status for all interfaces"""
    
    # Get DPDK bindings
    dpdk_ports = parse_dpdk_status()
    
    # Get interface mapping
    iface_mapping = get_interface_mapping()
    
    # Build comprehensive port status
    ports_status = []
    
    # VEP1445 standard interfaces
    interface_info = {
        'eno1': {'label': 'MGMT', 'type': '1G', 'expected_status': 'LINUX'},
        'eno2': {'label': 'LAN1', 'type': '1G', 'expected_status': 'AVAIL'},
        'eno3': {'label': 'LAN2', 'type': '1G', 'expected_status': 'AVAIL'},
        'eno4': {'label': 'LAN3', 'type': '1G', 'expected_status': 'AVAIL'},
        'eno5': {'label': 'LAN4', 'type': '1G', 'expected_status': 'AVAIL'},
        'eno6': {'label': 'LAN5', 'type': '1G', 'expected_status': 'AVAIL'},
        'eno7': {'label': '10G TX', 'type': '10G', 'expected_status': 'DPDK'},
        'eno8': {'label': '10G RX', 'type': '10G', 'expected_status': 'DPDK'},
    }
    
    for iface_name, info in interface_info.items():
        port = {
            'name': iface_name,
            'label': info['label'],
            'type': info['type'],
            'status': 'UNKNOWN',
            'link': 'unknown',
            'speed': 0,
            'driver': None,
            'pci': None,
            'mac': None,
            'lldp_neighbor': None,
            'arp_neighbors': [],
            'dpdk_bound': False
        }
        
        # Check if in DPDK
        if iface_name in dpdk_ports:
            dpdk_info = dpdk_ports[iface_name]
            port['status'] = dpdk_info['status']
            port['driver'] = dpdk_info['driver']
            port['pci'] = dpdk_info['pci']
            port['dpdk_bound'] = dpdk_info['dpdk_bound']
            
            # For DPDK-bound ports, link status requires testpmd
            # For now, mark as "bound" (we can't easily check link when bound)
            port['link'] = 'bound_to_dpdk'
            
        elif iface_name in iface_mapping:
            # Kernel driver
            iface_info = iface_mapping[iface_name]
            port['status'] = 'LINUX' if iface_info['driver'] != 'vfio-pci' else 'AVAIL'
            port['driver'] = iface_info['driver']
            port['pci'] = iface_info['pci']
            
            # Get link status for kernel interfaces
            port['link'] = get_link_status(iface_name)
            port['speed'] = get_link_speed(iface_name)
            port['mac'] = get_mac_address(iface_name)
            
            # Discover LLDP neighbors (only if link is up)
            if port['link'] == 'up':
                port['lldp_neighbor'] = discover_lldp_neighbors(iface_name)
                port['arp_neighbors'] = get_arp_neighbors(iface_name)
        
        ports_status.append(port)
    
    return jsonify({
        'status': 'success',
        'timestamp': int(time.time()),
        'ports': ports_status
    })

@ports_api.route('/api/ports/topology')
def get_network_topology():
    """Get network topology from LLDP and ARP"""
    
    ports_result = get_ports_status()
    ports_data = ports_result.get_json()
    
    topology = {
        'devices': [],
        'links': []
    }
    
    # Add VEP1445 as center node
    topology['devices'].append({
        'id': 'vep1445',
        'name': 'VEP1445',
        'type': 'tester',
        'ip': None,
        'mac': None
    })
    
    # Add discovered devices
    device_id = 1
    for port in ports_data['ports']:
        port_name = port['name']
        
        # Add LLDP neighbors
        if port.get('lldp_neighbor'):
            neighbor = port['lldp_neighbor']
            device = {
                'id': f'device_{device_id}',
                'name': neighbor.get('system_name', 'Unknown Device'),
                'type': 'network_device',
                'description': neighbor.get('system_description', ''),
                'management_ip': neighbor.get('management_ip'),
                'capabilities': neighbor.get('capabilities', ''),
                'discovered_via': 'lldp'
            }
            topology['devices'].append(device)
            
            # Add link
            topology['links'].append({
                'source': 'vep1445',
                'target': device['id'],
                'source_port': port_name,
                'target_port': neighbor.get('port_description', ''),
                'type': 'lldp'
            })
            
            device_id += 1
        
        # Add ARP neighbors
        for arp_neighbor in port.get('arp_neighbors', []):
            device = {
                'id': f'device_{device_id}',
                'name': f"Host {arp_neighbor['ip']}",
                'type': 'host',
                'ip': arp_neighbor['ip'],
                'mac': arp_neighbor['mac'],
                'discovered_via': 'arp'
            }
            topology['devices'].append(device)
            
            # Add link
            topology['links'].append({
                'source': 'vep1445',
                'target': device['id'],
                'source_port': port_name,
                'type': 'arp'
            })
            
            device_id += 1
    
    return jsonify({
        'status': 'success',
        'topology': topology
    })

@ports_api.route('/api/ports/send_lldp', methods=['POST'])
def send_lldp_packets():
    """Manually trigger LLDP packet transmission"""
    try:
        # This would require lldpd or custom DPDK LLDP implementation
        subprocess.run(['systemctl', 'restart', 'lldpd'], 
                      capture_output=True, timeout=5)
        return jsonify({'status': 'success', 'message': 'LLDP packets sent'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

# Register routes
def register_ports_api(app):
    """Register the ports API blueprint with the Flask app"""
    app.register_blueprint(ports_api)
