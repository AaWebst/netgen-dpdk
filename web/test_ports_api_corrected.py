#!/usr/bin/env python3
"""
Test script for ports API - CORRECTED VERSION
Run this to verify the API functions work before integrating

USAGE:
  sudo python3 test_ports_api_corrected.py

NOTE: Must run as root for ethtool/lldpctl access
"""

import sys
import os

# Add the correct path for /opt/netgen-dpdk installation
sys.path.insert(0, '/opt/netgen-dpdk/web')

try:
    from ports_api_fixed import get_all_port_status, get_link_status, get_lldp_neighbors
except ImportError as e:
    print("ERROR: Cannot import ports_api_fixed.py")
    print(f"Details: {e}")
    print()
    print("Make sure ports_api_fixed.py is in /opt/netgen-dpdk/web/")
    print("Current sys.path:")
    for path in sys.path:
        print(f"  - {path}")
    sys.exit(1)

import json

print("=" * 60)
print("Testing Port Status API Functions")
print("=" * 60)
print()

# Check if running as root
if os.geteuid() != 0:
    print("⚠️  WARNING: Not running as root!")
    print("   ethtool and lldpctl may fail without sudo")
    print("   Run: sudo python3 test_ports_api_corrected.py")
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
    import traceback
    traceback.print_exc()
print()

# Test 2: LLDP
print("Test 2: LLDP Discovery")
print("-" * 60)
print("NOTE: LLDP will NOT work on DPDK-bound interfaces!")
print("      Only kernel-managed interfaces (like eno1/MGMT) will show neighbors")
print()
try:
    # Test on MGMT port (not DPDK-bound)
    neighbor = get_lldp_neighbors('eno1')
    if neighbor:
        print(f"eno1 neighbor: {json.dumps(neighbor, indent=2)}")
    else:
        print("eno1 neighbor: None (no LLDP neighbor detected)")
    
    print()
    
    # Test on DPDK port (will likely fail)
    neighbor = get_lldp_neighbors('eno2')
    if neighbor:
        print(f"eno2 neighbor: {json.dumps(neighbor, indent=2)}")
    else:
        print("eno2 neighbor: None (expected - DPDK-bound interface)")
    
    print()
    print("✓ LLDP function works (neighbor may or may not exist)")
except Exception as e:
    print(f"✗ LLDP error: {e}")
    import traceback
    traceback.print_exc()
print()

# Test 3: Full port status
print("Test 3: All Ports Status")
print("-" * 60)
try:
    ports = get_all_port_status()
    print(f"Total ports: {len(ports)}")
    print()
    
    for port in ports:
        dpdk_note = " [DPDK - LLDP unavailable]" if port['dpdk_bound'] else ""
        print(f"{port['interface']:6} ({port['label']:6}): "
              f"Link {port['link']:7} @ {port['speed']:5} Mbps - "
              f"{port['display_name']}{dpdk_note}")
    
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
print("IMPORTANT NOTES:")
print("1. LLDP WILL NOT WORK on DPDK-bound interfaces (eno2-eno8)")
print("   - DPDK bypasses the kernel network stack")
print("   - lldpd cannot access DPDK interfaces")
print("   - Only eno1 (MGMT) can show LLDP neighbors")
print()
print("2. To see LLDP on traffic ports, you would need to:")
print("   - Unbind interfaces from DPDK")
print("   - Use kernel drivers instead")
print("   - This defeats the purpose of DPDK performance")
print()
print("If all tests passed, the API is ready to integrate.")
print("Add to server.py:")
print("  from ports_api_fixed import init_app as init_ports_api")
print("  init_ports_api(app)")
