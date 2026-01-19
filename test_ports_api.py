#!/usr/bin/env python3
"""
Test script for ports API
Run this to verify the API functions work before integrating
"""

import sys
sys.path.insert(0, '/home/claude')

from ports_api_fixed import get_all_port_status, get_link_status, get_lldp_neighbors
import json

print("=" * 60)
print("Testing Port Status API Functions")
print("=" * 60)
print()

# Test 1: Link status
print("Test 1: Link Status")
print("-" * 60)
try:
    link = get_link_status('eno1')
    print(f"eno1 link status: {json.dumps(link, indent=2)}")
    print("✓ Link status function works")
except Exception as e:
    print(f"✗ Link status error: {e}")
print()

# Test 2: LLDP
print("Test 2: LLDP Discovery")
print("-" * 60)
try:
    neighbor = get_lldp_neighbors('eno2')
    if neighbor:
        print(f"eno2 neighbor: {json.dumps(neighbor, indent=2)}")
    else:
        print("eno2 neighbor: None (no LLDP neighbor detected)")
    print("✓ LLDP function works (neighbor may or may not exist)")
except Exception as e:
    print(f"✗ LLDP error: {e}")
print()

# Test 3: Full port status
print("Test 3: All Ports Status")
print("-" * 60)
try:
    ports = get_all_port_status()
    print(f"Total ports: {len(ports)}")
    print()
    
    for port in ports:
        print(f"{port['interface']:6} ({port['label']:6}): "
              f"Link {port['link']:7} @ {port['speed']:5} Mbps - "
              f"{port['display_name']}")
    
    print()
    print("✓ Full port status works")
    print()
    print("JSON output:")
    print(json.dumps({'status': 'success', 'ports': ports}, indent=2))
except Exception as e:
    print(f"✗ Full status error: {e}")
    import traceback
    traceback.print_exc()
print()

print("=" * 60)
print("Test Complete")
print("=" * 60)
print()
print("If all tests passed, the API is ready to integrate.")
print("Add to server.py:")
print("  from ports_api_fixed import init_app as init_ports_api")
print("  init_ports_api(app)")
