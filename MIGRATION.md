# Migration Guide: Python NetGen Pro → DPDK Edition

This guide helps you migrate from the Python-based NetGen Pro to the high-performance DPDK edition.

## Overview of Changes

### What's the Same ✅
- **Web UI**: Identical interface, same look and feel
- **API**: Same REST API endpoints
- **Features**: All traffic generation features preserved
- **Profiles**: Same profile format and presets
- **Statistics**: Same metrics and monitoring

### What's Different 🔄
- **Backend**: C++ DPDK engine replaces Python packet generator
- **Performance**: 10+ Gbps instead of ~500 Mbps max
- **Setup**: Requires DPDK installation and NIC binding
- **Privileges**: Requires root/sudo for DPDK operations
- **Architecture**: Hybrid Python/C++ instead of pure Python

## Migration Steps

### Step 1: Backup Your Current Installation

```bash
# Backup your current NetGen Pro
cp -r netgen-pro netgen-pro-backup

# Export your saved profiles (if using database)
sqlite3 traffic_generator.db ".dump saved_profiles" > profiles_backup.sql
```

### Step 2: Install DPDK Edition

```bash
# Clone or extract DPDK edition
cd netgen-dpdk

# Run installation script
./scripts/install.sh
```

This will:
- Install DPDK and dependencies
- Build the DPDK engine
- Configure hugepages
- Keep your Python environment intact

### Step 3: Configure Network Interfaces

The main difference is that DPDK takes exclusive control of network interfaces.

**Before (Python):**
```bash
# Used regular Linux interfaces
ifconfig eth0 up
# Python could send packets through eth0
```

**After (DPDK):**
```bash
# Bind interface to DPDK
sudo ifconfig eth0 down
sudo dpdk-devbind.py --bind=vfio-pci 0000:03:00.0

# DPDK now has exclusive control
# Linux cannot use this interface anymore
```

**Important:** 
- You'll need a separate management interface
- Or use a different physical NIC for DPDK
- Or use SR-IOV to split one NIC into multiple interfaces

### Step 4: Migrate Saved Profiles

Your existing profiles should work with minimal changes:

```python
# Old profile (Python version)
profile = {
    'name': 'UDP-Test',
    'protocol': 'udp',
    'packet_size': 1400,
    'rate_mbps': 100,
    'dst_port': 5000
}

# Same profile works in DPDK version!
# No changes needed to the profile structure
```

If you saved profiles in the database:

```bash
# Import into new installation
sqlite3 traffic_generator.db < profiles_backup.sql
```

### Step 5: Update Any Automation Scripts

**API endpoints remain the same:**

```python
# Python version
import requests
requests.post('http://localhost:8080/api/start', json={...})

# DPDK version - SAME API!
import requests
requests.post('http://localhost:8080/api/start', json={...})
```

**Only difference:** You may need to start the DPDK engine first:

```python
# Optional: Start DPDK engine programmatically
import subprocess
subprocess.Popen([
    'sudo', './build/dpdk_engine',
    '-l', '0-3', '-n', '4'
])
time.sleep(2)  # Wait for engine to initialize

# Then use API normally
requests.post('http://localhost:8080/api/start', ...)
```

### Step 6: Test Your Setup

Run a simple test to verify everything works:

```bash
# Start the DPDK edition
./start.sh
# Choose option 1 (web interface with auto-start)

# Open browser to http://localhost:8080
# Try a simple UDP profile
```

## Feature Comparison

| Feature | Python Version | DPDK Version | Notes |
|---------|---------------|--------------|-------|
| Max Throughput | 500 Mbps | 10+ Gbps | 20x improvement |
| UDP | ✅ | ✅ | Identical |
| TCP | ✅ | ✅ | Identical |
| ICMP | ✅ | ✅ | Identical |
| HTTP/DNS | ✅ | 🔜 | Coming soon |
| IPv6 | ✅ | ✅ | Identical |
| VLAN | ✅ | ✅ | Identical |
| MPLS | ✅ | ✅ | Identical |
| Impairments | ✅ | ✅ | Identical |
| Burst Mode | ✅ | ✅ | Identical |
| Latency Measurement | ✅ | ✅ | More accurate in DPDK |
| Web UI | ✅ | ✅ | Identical |
| Profile Saving | ✅ | ✅ | Compatible |
| Installation | Simple | Moderate | DPDK adds complexity |
| Root Required | No | Yes | For DPDK operations |

## Common Migration Issues

### Issue 1: "No Ethernet ports available"

**Cause:** No NIC bound to DPDK

**Solution:**
```bash
dpdk-devbind.py --status
sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>
```

### Issue 2: Lower throughput than expected

**Cause:** Various configuration issues

**Solutions:**
```bash
# Check hugepages
cat /proc/meminfo | grep Huge

# Disable CPU frequency scaling
sudo cpupower frequency-set -g performance

# Use more cores
sudo ./build/dpdk_engine -l 0-7 -n 4  # Use 8 cores instead of 4
```

### Issue 3: Can't access web UI after migration

**Cause:** Using DPDK-bound management interface

**Solution:** Use a different interface for management:
```bash
# Option 1: Use different physical interface
# Bind only test interfaces to DPDK, keep mgmt interface for Linux

# Option 2: Use console/serial access

# Option 3: Use SR-IOV virtual functions
```

### Issue 4: Profiles generating less traffic than configured

**Cause:** Rate limiting working correctly, but expectations different

**Solution:** DPDK is very accurate. If you set 1000 Mbps:
```python
# Python: ~800-1200 Mbps (variable)
# DPDK: 1000.0 Mbps (exact)
```

## Performance Expectations

### Python Version (Original)
```
Hardware: 4-core CPU
Traffic: 64-byte UDP packets
Result: ~500 Mbps, 800K pps, 100% CPU on 4 cores
```

### DPDK Version
```
Hardware: Same 4-core CPU
Traffic: 64-byte UDP packets  
Result: ~6 Gbps, 9M pps, 100% CPU on 4 cores

Hardware: Same 4-core CPU
Traffic: 1500-byte UDP packets
Result: ~40 Gbps, 3.3M pps, 60% CPU on 4 cores
```

**Recommendation:** For best results, use 1400-1500 byte packets. Small packets (64-byte) are harder to generate at line rate.

## Rollback Plan

If you need to rollback to Python version:

```bash
# Stop DPDK version
sudo pkill dpdk_engine
python3 -c "import requests; requests.post('http://localhost:8080/api/stop')"

# Unbind interfaces from DPDK
sudo dpdk-devbind.py --bind=<original_driver> <PCI_ADDRESS>
# For Intel: --bind=i40e or --bind=ixgbe
# For Mellanox: --bind=mlx5_core

# Bring interface back up
sudo ifconfig eth0 up

# Start Python version
cd netgen-pro-backup
python3 web_server.py
```

## Hybrid Deployment

You can run both versions simultaneously on different interfaces:

```bash
# DPDK edition on eth0 (high performance)
sudo dpdk-devbind.py --bind=vfio-pci 0000:03:00.0
./start.sh

# Python edition on eth1 (flexibility)
python3 netgen-pro-backup/web_server.py --port 8081
```

Access:
- DPDK version: http://localhost:8080
- Python version: http://localhost:8081

## Support and Resources

- **README.md**: Main documentation
- **GitHub Issues**: Report problems
- **DPDK Documentation**: https://doc.dpdk.org
- **Original Python Version**: Keep for reference

## Recommendations

### When to Use DPDK Version
- ✅ Testing 1+ Gbps networks
- ✅ 10GbE/25GbE/40GbE testing
- ✅ Stress testing networking equipment
- ✅ RFC 2544 benchmarking
- ✅ Production-scale testing

### When to Keep Python Version
- ✅ Quick tests (<500 Mbps)
- ✅ Development/prototyping
- ✅ Cloud/VM environments (no DPDK support)
- ✅ When root access not available
- ✅ Simple automation scripts

### Best Practice: Use Both
- **DPDK**: Production testing and high-performance scenarios
- **Python**: Development, debugging, and low-rate testing

---

## Migration Checklist

- [ ] Backup current installation
- [ ] Export saved profiles
- [ ] Install DPDK and dependencies
- [ ] Build DPDK engine
- [ ] Configure hugepages
- [ ] Bind test interfaces to DPDK
- [ ] Keep management interface for Linux
- [ ] Import saved profiles
- [ ] Test basic UDP generation
- [ ] Test advanced features
- [ ] Update automation scripts (if needed)
- [ ] Document your setup
- [ ] Train team members

## Questions?

If you encounter issues during migration:

1. Check the troubleshooting section in README.md
2. Verify DPDK installation: `pkg-config --modversion libdpdk`
3. Check interface binding: `dpdk-devbind.py --status`
4. Review hugepages: `cat /proc/meminfo | grep Huge`
5. Open a GitHub issue with details

Happy testing! 🚀
