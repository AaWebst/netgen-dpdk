#!/usr/bin/env python3
“””
Enhanced Hybrid Port Status API - DPDK-Aware
Handles DPDK interface state transitions correctly

For VEP1445 NetGen DPDK packet generator
“””

from flask import Blueprint, jsonify
import subprocess
import socket
import json
import re
import time
import os
from collections import defaultdict

def run_command(cmd, timeout=3):
“”“Safely run a shell command”””
try:
result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
return result.stdout
except Exception as e:
print(f”Command error: {e}”)
return “”

# ============================================================================

# DPDK Engine Status Detection

# ============================================================================

def check_dpdk_engine_running():
“””
Check if DPDK engine is actually running
“””
# Method 1: Check for process
try:
result = subprocess.run([‘pgrep’, ‘-f’, ‘dpdk_engine’],
capture_output=True, text=True, timeout=1)
if result.returncode == 0:
return True
except:
pass

```
# Method 2: Check for control socket
if os.path.exists('/tmp/dpdk_engine_control.sock'):
    return True

# Method 3: Check for DPDK process via ps
try:
    result = subprocess.run(['ps', 'aux'], capture_output=True, text=True, timeout=1)
    if 'dpdk' in result.stdout.lower() and 'engine' in result.stdout.lower():
        return True
except:
    pass

return False
```

def get_dpdk_stats_via_socket(port_id):
“””
Try to get stats directly from DPDK engine via socket
Returns None if DPDK engine not reachable
“””
try:
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(1)
sock.connect(’/tmp/dpdk_engine_control.sock’)

```
    # Request stats for port
    command = f"GET_STATS {port_id}\n"
    sock.send(command.encode())
    
    response = sock.recv(4096).decode()
    sock.close()
    
    return json.loads(response)
except:
    return None
```

# ============================================================================

# LLDP Discovery (for non-DPDK interfaces like MGMT)

# ============================================================================

def get_lldp_neighbors(interface):
“”“Get LLDP neighbor info for an interface”””
try:
output = run_command([‘lldpctl’, interface])
if not output:
return None

```
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
```

# ============================================================================

# ARP-based Discovery (for DPDK interfaces - requires traffic)

# ============================================================================

def get_arp_neighbors(interface):
“””
Get devices connected to interface via ARP table
NOTE: Only works if IP traffic has been flowing!
“””
try:
result = run_command([‘arp’, ‘-n’])
neighbors = []

```
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
                    'system_name': ip,
                    'port': mac,
                    'discovery_method': 'arp'
                })
    
    return neighbors[0] if neighbors else None
except Exception as e:
    print(f"ARP error for {interface}: {e}")
    return None
```

def get_traffic_stats(interface):
“””
Get interface traffic statistics
Works on DPDK ports only if kernel can still see some stats
“””
try:
output = run_command([‘ethtool’, ‘-S’, interface], timeout=2)

```
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
```

# ============================================================================

# Link Status (works differently for DPDK vs kernel)

# ============================================================================

def get_link_status(interface):
“””
Get link status for an interface
NOTE: May show “down” for DPDK interfaces even when link is up!
“””
try:
output = run_command([‘ethtool’, interface], timeout=2)

```
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
```

# ============================================================================

# Hybrid Discovery with DPDK State Awareness

# ============================================================================

def get_enhanced_port_status(port_config, dpdk_running):
“””
Get status using appropriate method based on port type and DPDK state
“””
interface = port_config[‘name’]
is_dpdk = port_config[‘dpdk’]

```
port_info = {
    'interface': interface,
    'label': port_config['label'],
    'dpdk_bound': is_dpdk,
}

# Case 1: Non-DPDK port (MGMT) - use LLDP + ethtool
if not is_dpdk:
    link_info = get_link_status(interface)
    neighbor = get_lldp_neighbors(interface)
    
    port_info['link'] = link_info['link']
    port_info['speed'] = link_info['speed']
    port_info['neighbor'] = neighbor
    port_info['discovery_method'] = 'lldp'
    port_info['status_note'] = 'Kernel-managed interface'
    
    # Build display name
    if neighbor and neighbor.get('system_name'):
        port_info['display_name'] = f"{port_config['label']} → {neighbor['system_name']}"
        if neighbor.get('port') and len(neighbor['port']) < 50:
            port_info['display_name'] += f":{neighbor['port']}"
    else:
        port_info['display_name'] = port_config['label']

# Case 2: DPDK port with engine running
elif is_dpdk and dpdk_running:
    # Try to get DPDK stats first
    dpdk_stats = get_dpdk_stats_via_socket(port_config.get('port_id', 0))
    
    if dpdk_stats:
        # Got stats from DPDK engine
        port_info['link'] = 'up' if dpdk_stats.get('link_up') else 'down'
        port_info['speed'] = dpdk_stats.get('speed', 0)
        port_info['rx_packets'] = dpdk_stats.get('rx_packets', 0)
        port_info['tx_packets'] = dpdk_stats.get('tx_packets', 0)
        port_info['status_note'] = 'DPDK engine stats'
    else:
        # Fallback to ethtool (may be inaccurate)
        link_info = get_link_status(interface)
        port_info['link'] = link_info['link']
        port_info['speed'] = link_info['speed']
        port_info['status_note'] = 'Kernel view (may be inaccurate for DPDK)'
    
    # Try ARP discovery
    neighbor = get_arp_neighbors(interface)
    port_info['neighbor'] = neighbor
    port_info['discovery_method'] = 'arp'
    
    # Build display name
    if neighbor and neighbor.get('ip'):
        port_info['display_name'] = f"{port_config['label']} → {neighbor['ip']}"
    elif port_info.get('rx_packets', 0) > 0 or port_info.get('tx_packets', 0) > 0:
        port_info['display_name'] = f"{port_config['label']} → Active Traffic"
        port_info['status_note'] = 'Traffic detected but no ARP yet - keep generating traffic'
    else:
        port_info['display_name'] = port_config['label']
        port_info['status_note'] = 'DPDK ready - start traffic to discover devices'

# Case 3: DPDK port but engine NOT running
else:
    link_info = get_link_status(interface)
    port_info['link'] = 'unknown'
    port_info['speed'] = 0
    port_info['neighbor'] = None
    port_info['display_name'] = f"{port_config['label']} (DPDK not running)"
    port_info['status_note'] = 'Start DPDK engine to see port status'
    port_info['discovery_method'] = 'none'

return port_info
```

def get_all_port_status():
“””
Get status for all ports with hybrid discovery
“””
ports = [
{‘name’: ‘eno1’, ‘label’: ‘MGMT’, ‘dpdk’: False, ‘port_id’: None},
{‘name’: ‘eno2’, ‘label’: ‘LAN1’, ‘dpdk’: True, ‘port_id’: 0},
{‘name’: ‘eno3’, ‘label’: ‘LAN2’, ‘dpdk’: True, ‘port_id’: 1},
{‘name’: ‘eno4’, ‘label’: ‘LAN3’, ‘dpdk’: True, ‘port_id’: 2},
{‘name’: ‘eno5’, ‘label’: ‘LAN4’, ‘dpdk’: True, ‘port_id’: 3},
{‘name’: ‘eno6’, ‘label’: ‘LAN5’, ‘dpdk’: True, ‘port_id’: 4},
{‘name’: ‘eno7’, ‘label’: ‘10G-1’, ‘dpdk’: True, ‘port_id’: 5},
{‘name’: ‘eno8’, ‘label’: ‘10G-2’, ‘dpdk’: True, ‘port_id’: 6},
]

```
# Check DPDK engine status once
dpdk_running = check_dpdk_engine_running()

result = []
for port_config in ports:
    port_info = get_enhanced_port_status(port_config, dpdk_running)
    result.append(port_info)

return result, dpdk_running
```

# ============================================================================

# Flask API Routes

# ============================================================================

def add_port_routes(app):
“”“Add port status routes directly to Flask app”””

```
@app.route('/api/ports/status')
def api_port_status():
    """Get enhanced port status with hybrid discovery"""
    try:
        ports, dpdk_running = get_all_port_status()
        
        return jsonify({
            'status': 'success',
            'timestamp': int(time.time()),
            'dpdk_engine_running': dpdk_running,
            'ports': ports,
            'discovery_info': {
                'mgmt_method': 'LLDP (Layer 2)',
                'dpdk_method': 'ARP (Layer 3 - requires traffic)',
                'note': 'ARP discovery needs traffic to be flowing on DPDK ports'
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
        
        # Optional: Flush ARP cache to force re-discovery
        try:
            subprocess.run(['ip', '-s', '-s', 'neigh', 'flush', 'all'], timeout=5)
        except:
            pass
        
        return jsonify({
            'status': 'success',
            'message': 'Discovery refreshed - ARP will repopulate as traffic flows'
        })
    except Exception as e:
        print(f"Refresh error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/ports/dpdk-status')
def api_dpdk_status():
    """Check if DPDK engine is running"""
    try:
        running = check_dpdk_engine_running()
        
        return jsonify({
            'status': 'success',
            'dpdk_running': running,
            'message': 'DPDK engine is running' if running else 'DPDK engine not detected'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/ports/arp-scan/<interface>')
def api_arp_scan(interface):
    """
    Actively scan for devices on an interface
    NOTE: Only works if DPDK is running and generating traffic
    """
    try:
        # Check if DPDK is running
        if not check_dpdk_engine_running():
            return jsonify({
                'status': 'warning',
                'message': 'DPDK engine not running - start it first'
            }), 400
        
        # Get interface's network
        result = subprocess.run(['ip', 'addr', 'show', interface], 
                              capture_output=True, text=True, timeout=2)
        
        # Try to find subnet
        subnet_match = re.search(r'inet (\d+\.\d+\.\d+\.\d+/\d+)', result.stdout)
        
        if subnet_match:
            subnet = subnet_match.group(1)
            
            # Use arping if available
            try:
                subprocess.run(['arping', '-I', interface, '-c', '3', 
                              subnet.split('/')[0]], timeout=5)
            except:
                pass
        
        # Wait for ARP table to update
        time.sleep(2)
        
        # Return current ARP neighbors
        neighbor = get_arp_neighbors(interface)
        
        return jsonify({
            'status': 'success',
            'interface': interface,
            'neighbor': neighbor,
            'note': 'If no neighbor found, make sure traffic is flowing on this port'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500
```

def init_app(app):
“””
Initialize enhanced hybrid port status API with Flask app
“””
print(“Initializing enhanced hybrid port status API (DPDK-aware)…”)
add_port_routes(app)

```
# Check initial DPDK status
dpdk_running = check_dpdk_engine_running()

print("Port status API initialized:")
print("  - /api/ports/status - Get all port status")
print("  - /api/ports/refresh - Refresh discovery")
print("  - /api/ports/dpdk-status - Check DPDK engine")
print("  - /api/ports/arp-scan/<interface> - Active ARP scan")
print(f"  - DPDK engine: {'RUNNING' if dpdk_running else 'NOT RUNNING'}")
print("  - MGMT (eno1): LLDP-based discovery")
print("  - Traffic ports (eno2-8): ARP-based discovery (requires traffic)")
```

# ============================================================================

# Test / Standalone execution

# ============================================================================

if **name** == ‘**main**’:
print(”=” * 70)
print(“Enhanced Hybrid Port Discovery Test (DPDK-Aware)”)
print(”=” * 70)
print()

```
# Check DPDK status
dpdk_running = check_dpdk_engine_running()
print(f"DPDK Engine Status: {'RUNNING ✓' if dpdk_running else 'NOT RUNNING ✗'}")
print()

if not dpdk_running:
    print("⚠️  DPDK engine is not running!")
    print("   DPDK port status will be limited")
    print("   Start DPDK engine for full functionality")
    print()

ports, _ = get_all_port_status()

print(f"Total ports: {len(ports)}")
print()

for port in ports:
    method = port.get('discovery_method', 'none')
    
    print(f"{port['interface']:6} ({port['label']:6}): "
          f"Link {port['link']:7} @ {port['speed']:5} Mbps")
    print(f"         Display: {port['display_name']}")
    print(f"         Method: {method}")
    print(f"         Note: {port.get('status_note', 'N/A')}")
    
    if port['neighbor']:
        print(f"         Neighbor: {json.dumps(port['neighbor'], indent=10)}")
    print()

print("=" * 70)
print("Discovery Workflow:")
print("  1. Start DPDK engine (./dpdk_engine)")
print("  2. Start traffic generation")
print("  3. Wait 5-10 seconds for ARP table to populate")
print("  4. Call /api/ports/status to see discovered devices")
print()
print("For immediate discovery:")
print("  curl http://localhost:8080/api/ports/arp-scan/eno2")
print("=" * 70)
```