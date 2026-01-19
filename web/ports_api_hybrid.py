#!/usr/bin/env python3
"""
Hybrid Port Status API - LLDP + ARP Discovery
Combines LLDP (for kernel interfaces) and ARP-based discovery (for DPDK interfaces)

For VEP1445 NetGen DPDK packet generator
"""

from flask import Blueprint, jsonify
import subprocess
import json
import re
import time
from collections import defaultdict

def run_command(cmd, timeout=3):
    """Safely run a shell command"""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return result.stdout
    except Exception as e:
        print(f"Command error: {e}")
        return ""

# ============================================================================
# LLDP Discovery (for non-DPDK interfaces like MGMT)
# ============================================================================

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
        
        if neighbor:
            neighbor['discovery_method'] = 'lldp'
        return neighbor if neighbor else None
    except Exception as e:
        print(f"LLDP error for {interface}: {e}")
        return None

# ============================================================================
# ARP-based Discovery (for DPDK interfaces)
# ============================================================================

def get_arp_neighbors(interface):
    """
    Get devices connected to interface via ARP table
    Works for DPDK ports that have IP traffic
    """
    try:
        result = run_command(['arp', '-n'])
        neighbors = []
        
        for line in result.split('\n')[1:]:  # Skip header
            if not line.strip():
                continue
            
            parts = line.split()
            if len(parts) >= 5:
                ip = parts[0]
                mac = parts[2]
                iface = parts[4] if len(parts) > 4 else 'unknown'
                
                # Skip incomplete entries
                if mac == '<incomplete>' or '(' in mac:
                    continue
                
                # Match our interface
                if iface == interface:
                    neighbors.append({
                        'ip': ip,
                        'mac': mac,
                        'system_name': ip,  # Use IP as system name
                        'port': mac,  # Use MAC as port identifier
                        'discovery_method': 'arp'
                    })
        
        return neighbors[0] if neighbors else None
    except Exception as e:
        print(f"ARP error for {interface}: {e}")
        return None

def get_traffic_stats(interface):
    """
    Get interface traffic statistics
    Even on DPDK ports, this can show if something is connected
    """
    try:
        output = run_command(['ethtool', '-S', interface], timeout=2)
        
        rx_packets = 0
        tx_packets = 0
        
        for line in output.split('\n'):
            if 'rx_packets:' in line.lower() or 'rx_pkts:' in line.lower():
                match = re.search(r'(\d+)', line)
                if match:
                    rx_packets = int(match.group(1))
            elif 'tx_packets:' in line.lower() or 'tx_pkts:' in line.lower():
                match = re.search(r'(\d+)', line)
                if match:
                    tx_packets = int(match.group(1))
        
        return {
            'rx_packets': rx_packets,
            'tx_packets': tx_packets,
            'has_traffic': rx_packets > 0 or tx_packets > 0
        }
    except Exception as e:
        return {'rx_packets': 0, 'tx_packets': 0, 'has_traffic': False}

# ============================================================================
# Link Status (works on all interfaces)
# ============================================================================

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

# ============================================================================
# Hybrid Discovery (LLDP + ARP)
# ============================================================================

def get_hybrid_neighbor(interface, is_dpdk=False):
    """
    Get neighbor using appropriate discovery method:
    - Non-DPDK (MGMT): Use LLDP
    - DPDK (traffic ports): Use ARP + traffic stats
    """
    neighbor = None
    
    if not is_dpdk:
        # Try LLDP first for non-DPDK interfaces
        neighbor = get_lldp_neighbors(interface)
    
    if not neighbor:
        # Try ARP-based discovery (works on both DPDK and non-DPDK)
        neighbor = get_arp_neighbors(interface)
    
    # If still no neighbor but interface has traffic, note that
    if not neighbor:
        stats = get_traffic_stats(interface)
        if stats['has_traffic']:
            neighbor = {
                'system_name': 'Active Device',
                'port': f"RX: {stats['rx_packets']} / TX: {stats['tx_packets']}",
                'discovery_method': 'traffic_stats'
            }
    
    return neighbor

def get_all_port_status():
    """
    Get status for all ports with hybrid discovery
    """
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
        
        # Get neighbor using hybrid discovery
        neighbor = get_hybrid_neighbor(port['name'], port['dpdk'])
        
        # Build display name
        display_name = port['label']
        if neighbor and neighbor.get('system_name'):
            display_name = f"{port['label']} → {neighbor['system_name']}"
            if neighbor.get('port') and len(neighbor['port']) < 50:
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

# ============================================================================
# Flask API Routes
# ============================================================================

def add_port_routes(app):
    """Add port status routes directly to Flask app"""
    
    @app.route('/api/ports/status')
    def api_port_status():
        """Get enhanced port status with hybrid discovery"""
        try:
            ports = get_all_port_status()
            return jsonify({
                'status': 'success',
                'timestamp': int(time.time()),
                'ports': ports,
                'discovery_methods': {
                    'mgmt': 'LLDP (Layer 2)',
                    'dpdk': 'ARP + Traffic Stats (Layer 3)'
                }
            })
        except Exception as e:
            print(f"Port status API error: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500
    
    @app.route('/api/ports/refresh')
    def api_port_refresh():
        """Force LLDP refresh and clear ARP cache"""
        try:
            # Restart LLDP daemon
            subprocess.run(['systemctl', 'restart', 'lldpd'], timeout=5)
            
            # Optional: Force ARP refresh by pinging gateway
            # This helps discover new devices
            try:
                subprocess.run(['ip', '-s', '-s', 'neigh', 'flush', 'all'], timeout=5)
            except:
                pass
            
            return jsonify({
                'status': 'success',
                'message': 'Discovery refreshed (LLDP + ARP)'
            })
        except Exception as e:
            print(f"Refresh error: {e}")
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500
    
    @app.route('/api/ports/arp-scan/<interface>')
    def api_arp_scan(interface):
        """
        Actively scan for devices on an interface
        WARNING: Generates network traffic
        """
        try:
            # Get interface's network
            result = subprocess.run(['ip', 'addr', 'show', interface], 
                                  capture_output=True, text=True, timeout=2)
            
            # Try to find subnet
            import re
            subnet_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+/\d+)', result.stdout)
            
            if subnet_match:
                subnet = subnet_match.group(1)
                
                # Use arping if available
                try:
                    subprocess.run(['arping', '-I', interface, '-c', '3', 
                                  subnet.split('/')[0]], timeout=5)
                except:
                    pass
            
            # Return current ARP neighbors after scan
            neighbor = get_arp_neighbors(interface)
            
            return jsonify({
                'status': 'success',
                'interface': interface,
                'neighbor': neighbor
            })
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500

def init_app(app):
    """
    Initialize hybrid port status API with Flask app
    Uses LLDP for MGMT and ARP discovery for DPDK ports
    """
    print("Initializing hybrid port status API (LLDP + ARP)...")
    add_port_routes(app)
    print("Port status API initialized: /api/ports/status and /api/ports/refresh")
    print("  - MGMT (eno1): LLDP-based discovery")
    print("  - Traffic ports (eno2-8): ARP-based discovery")

# ============================================================================
# Test / Standalone execution
# ============================================================================

if __name__ == '__main__':
    print("=" * 70)
    print("Hybrid Port Discovery Test (LLDP + ARP)")
    print("=" * 70)
    print()
    
    ports = get_all_port_status()
    
    print(f"Total ports: {len(ports)}")
    print()
    
    for port in ports:
        method = port['neighbor']['discovery_method'] if port['neighbor'] else 'none'
        dpdk_note = " [DPDK - using ARP]" if port['dpdk_bound'] else " [Kernel - using LLDP]"
        
        print(f"{port['interface']:6} ({port['label']:6}): "
              f"Link {port['link']:7} @ {port['speed']:5} Mbps{dpdk_note}")
        print(f"         Display: {port['display_name']}")
        
        if port['neighbor']:
            print(f"         Method: {method}")
            print(f"         Neighbor: {json.dumps(port['neighbor'], indent=10)}")
        else:
            print(f"         Neighbor: None detected")
        print()
    
    print("=" * 70)
    print("Discovery Methods:")
    print("  ✓ LLDP for eno1 (MGMT) - Layer 2 neighbor discovery")
    print("  ✓ ARP for eno2-8 (DPDK) - Layer 3 device discovery")
    print("  ✓ Traffic stats as fallback - detects active connections")
    print("=" * 70)
