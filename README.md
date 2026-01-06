# NetGen Pro - DPDK Edition

High-performance network packet generator with DPDK acceleration, capable of generating 10+ Gbps traffic with minimal CPU usage.

## 🚀 Features

### Performance
- **10+ Gbps** packet generation on commodity hardware
- **Multi-core scaling** - one core per traffic profile
- **Zero-copy** packet transmission via DPDK
- **Sub-microsecond latency** with kernel bypass

### Protocols & Features
- ✅ UDP, TCP, ICMP packet generation
- ✅ IPv4 and IPv6 support
- ✅ VLAN tagging (802.1Q)
- ✅ MPLS label stacking
- ✅ Custom payload patterns
- ✅ Burst mode traffic generation
- ✅ DSCP/TOS marking

### Network Impairments (Testing)
- 📉 Configurable packet loss
- ⏱️ Latency injection
- 📊 Jitter simulation
- 🔀 Packet reordering
- 📋 Packet duplication
- 🔧 Corruption injection

### Statistics & Monitoring
- Real-time packet/byte counters
- Per-profile statistics
- Latency measurement (min/max/avg/percentiles)
- Jitter calculation
- RFC 2544 benchmarking support
- Web-based monitoring UI

### User Interface
- 🌐 **Web GUI** - Beautiful, responsive web interface
- 🖥️ **CLI** - Command-line interface for automation
- 📊 **Real-time charts** - Live traffic visualization
- 💾 **Profile management** - Save and load traffic profiles

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Web Browser                          │
│                    (http://host:8080)                       │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP/WebSocket
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Python Flask Control Server                    │
│              (dpdk_control_server.py)                       │
│   • Web UI serving                                          │
│   • Profile management                                      │
│   • Statistics aggregation                                  │
│   • Database (SQLite)                                       │
└────────────────────────┬────────────────────────────────────┘
                         │ Unix Socket (IPC)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              C++ DPDK Packet Engine                         │
│              (dpdk_engine binary)                           │
│   • DPDK EAL initialization                                 │
│   • Multi-core packet generation                            │
│   • Hardware offload (checksums, segmentation)              │
│   • Zero-copy TX via rte_eth_tx_burst()                     │
└────────────────────────┬────────────────────────────────────┘
                         │ DPDK PMD
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Network Interface Card (NIC)                   │
│              (Intel, Mellanox, etc.)                        │
└─────────────────────────────────────────────────────────────┘
```

### Design Philosophy

**Hybrid Architecture:**
- **Python Frontend**: Flask web server provides user-friendly control and monitoring
- **C++ DPDK Backend**: High-performance packet generation engine for maximum throughput
- **IPC Communication**: Unix domain sockets for low-latency control/stats exchange

**Why This Approach?**
1. **Performance**: C++/DPDK achieves 10+ Gbps, Python alone would struggle at 1 Gbps
2. **Usability**: Python web UI is easier to develop and maintain
3. **Flexibility**: Separate processes allow independent updates and debugging
4. **Compatibility**: Keep familiar web interface while gaining DPDK performance

## 📋 Requirements

### Hardware
- Intel x86_64 CPU (Xeon recommended for best performance)
- Network card with DPDK support:
  - Intel: 82599, X710, XXV710, E810
  - Mellanox: ConnectX-4/5/6
  - Other DPDK-compatible NICs
- Minimum 4GB RAM
- Hugepages support (2MB or 1GB pages)

### Software
- Linux kernel 4.4+ (5.x recommended)
- Ubuntu 20.04+, CentOS 8+, or RHEL 8+
- GCC 7+ or Clang 6+
- Python 3.8+
- DPDK 20.11+ (23.11 recommended)

### Privileges
- Root/sudo access for:
  - DPDK initialization
  - Hugepages configuration
  - NIC binding
  - Packet transmission

## 🔧 Installation

### Quick Install (Ubuntu/Debian)

```bash
# Clone the repository
git clone https://github.com/yourusername/netgen-dpdk.git
cd netgen-dpdk

# Run automated installation
chmod +x scripts/install.sh
./scripts/install.sh
```

This will:
1. Install system dependencies
2. Download and compile DPDK 23.11
3. Configure hugepages
4. Load required kernel modules
5. Build the DPDK engine
6. Install Python dependencies

### Manual Installation

#### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y build-essential meson ninja-build \
    python3-pip pkg-config libnuma-dev libpcap-dev \
    linux-headers-$(uname -r) python3-dev python3-flask \
    python3-flask-cors python3-flask-socketio
```

**CentOS/RHEL:**
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y meson ninja-build python3-pip \
    pkg-config numactl-devel libpcap-devel kernel-devel
pip3 install flask flask-cors flask-socketio
```

#### 2. Install DPDK

```bash
cd /tmp
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11

meson setup build
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

#### 3. Configure Hugepages

```bash
# Allocate 1024 x 2MB hugepages (2GB total)
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Mount hugepages
sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge

# Make persistent
echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf
echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
```

#### 4. Build NetGen Pro

```bash
cd netgen-dpdk
make
```

## 🎯 Quick Start

### 1. Bind Network Interface

First, find your network interface PCI address:

```bash
dpdk-devbind.py --status
```

Example output:
```
Network devices using kernel driver
===================================
0000:03:00.0 'Ethernet Controller X710' if=ens3 drv=i40e unused=vfio-pci
```

Bind the interface to DPDK:

```bash
# Bring interface down first
sudo ifconfig ens3 down

# Bind to DPDK (using vfio-pci driver)
sudo dpdk-devbind.py --bind=vfio-pci 0000:03:00.0
```

### 2. Start the Web Interface

```bash
cd web
python3 dpdk_control_server.py --auto-start-engine
```

Access the web UI at: `http://localhost:8080`

### 3. Generate Traffic via Web UI

1. Navigate to `http://localhost:8080`
2. Enter destination IP
3. Select a preset (e.g., "1 Gbps UDP")
4. Click "Start Traffic"
5. Monitor real-time statistics

### 4. Or Use CLI Mode

```bash
# Start DPDK engine manually
sudo ./build/dpdk_engine -l 0-3 -n 4 --proc-type primary

# In another terminal, send commands via socket
echo "START" | nc -U /tmp/netgen_dpdk_control.sock
```

## 📖 Usage Examples

### Example 1: Simple UDP Flood

Generate 1 Gbps UDP traffic to 192.168.1.100:

```python
# Via Python API
import requests

requests.post('http://localhost:8080/api/start', json={
    'destination': '192.168.1.100',
    'profiles': [{
        'name': 'UDP-1G',
        'protocol': 'udp',
        'packet_size': 1400,
        'rate_mbps': 1000,
        'dst_port': 5000
    }]
})
```

### Example 2: Mixed Traffic

Generate mixed UDP/TCP traffic:

```python
requests.post('http://localhost:8080/api/start', json={
    'destination': '192.168.1.100',
    'profiles': [
        {
            'name': 'UDP-Voice',
            'protocol': 'udp',
            'packet_size': 172,
            'rate_mbps': 10,
            'dst_port': 5004,
            'dscp': 46  # EF for voice
        },
        {
            'name': 'TCP-Data',
            'protocol': 'tcp',
            'packet_size': 1500,
            'rate_mbps': 500,
            'dst_port': 80,
            'dscp': 0
        }
    ]
})
```

### Example 3: Network Impairment Testing

Test application behavior with packet loss and latency:

```python
requests.post('http://localhost:8080/api/start', json={
    'destination': '192.168.1.100',
    'profiles': [{
        'name': 'Impaired-UDP',
        'protocol': 'udp',
        'packet_size': 1400,
        'rate_mbps': 100,
        'dst_port': 5000,
        'loss_percent': 5.0,        # 5% packet loss
        'latency_ms': 50,           # 50ms fixed latency
        'jitter_ms': 10,            # ±10ms jitter
        'reorder_percent': 1.0,     # 1% reordering
        'duplicate_percent': 0.5    # 0.5% duplication
    }]
})
```

### Example 4: VLAN Tagged Traffic

Generate VLAN-tagged packets:

```python
requests.post('http://localhost:8080/api/start', json={
    'destination': '192.168.1.100',
    'profiles': [{
        'name': 'VLAN-100',
        'protocol': 'udp',
        'packet_size': 1400,
        'rate_mbps': 1000,
        'dst_port': 5000,
        'vlan_id': 100,
        'vlan_priority': 5
    }]
})
```

## 🔍 Performance Tuning

### CPU Isolation

For maximum performance, isolate CPU cores for DPDK:

```bash
# Add to GRUB_CMDLINE_LINUX in /etc/default/grub
isolcpus=1,2,3,4

# Update GRUB
sudo update-grub
sudo reboot
```

### Hugepage Optimization

For >10 Gbps, use 1GB hugepages:

```bash
# Allocate 8 x 1GB hugepages
echo 8 | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

# Pass to DPDK
sudo ./build/dpdk_engine -l 0-3 -n 4 --socket-mem 2048,0
```

### NIC Offloads

Enable hardware offloads for better performance:

```bash
# In your DPDK code, enable:
# - TX checksum offload
# - TX segmentation offload
# - Multi-queue support
```

### Expected Performance

| Configuration | Rate | PPS | CPU Usage |
|--------------|------|-----|-----------|
| 1 core, 64B packets | 1.5 Gbps | 2.2M | 100% |
| 1 core, 1500B packets | 10 Gbps | 830K | 60% |
| 4 cores, 1500B packets | 40 Gbps | 3.3M | 4×60% |

## 🐛 Troubleshooting

### Issue: "No Ethernet ports available"

**Solution:** Bind your NIC to DPDK:
```bash
sudo dpdk-devbind.py --bind=vfio-pci <PCI_ADDRESS>
```

### Issue: "Cannot allocate memory"

**Solution:** Configure hugepages:
```bash
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

### Issue: Low throughput (<1 Gbps)

**Causes:**
1. Not using DPDK-bound NIC
2. Insufficient hugepages
3. CPU frequency scaling enabled
4. Incorrect rate limiting

**Solution:**
```bash
# Disable CPU frequency scaling
sudo cpupower frequency-set -g performance

# Verify hugepages
cat /proc/meminfo | grep Huge

# Check NIC binding
dpdk-devbind.py --status
```

### Issue: "Permission denied" when starting engine

**Solution:** Run with sudo or configure capabilities:
```bash
sudo setcap cap_net_raw,cap_net_admin=eip ./build/dpdk_engine
```

## 📊 Statistics & Monitoring

### Real-time Statistics

The web UI displays:
- **Packets/sec** per profile
- **Mbps** per profile
- **Packet loss** percentage
- **Duplicates** and **reordered** packets
- **Latency** (min/max/avg/p50/p95/p99)
- **Jitter**

### Exporting Data

Statistics can be exported as:
- CSV for analysis
- JSON for automation
- PCAP for packet inspection (when capture enabled)

## 🤝 Comparison: Python vs DPDK

| Feature | Python Version | DPDK Version |
|---------|---------------|--------------|
| Max Throughput | ~500 Mbps | 10+ Gbps |
| CPU Efficiency | Low (100% for 500 Mbps) | High (60% for 10 Gbps) |
| Latency | ~1-10ms | <1μs |
| Packet Loss | High at >100 Mbps | None (hardware queues) |
| Setup Complexity | Simple | Moderate |
| Dependencies | Python only | DPDK + drivers |
| Root Required | No (for <1000 pps) | Yes |

## 📝 Configuration Files

### Profile Configuration (JSON)

```json
{
  "name": "My Test Profile",
  "profiles": [
    {
      "name": "UDP-Video",
      "protocol": "udp",
      "packet_size": 1400,
      "rate_mbps": 100,
      "dst_ip": "192.168.1.100",
      "dst_port": 5004,
      "dscp": 34,
      "burst_mode": false
    }
  ]
}
```

## 🔒 Security Considerations

- DPDK requires root/elevated privileges
- Kernel bypass means no firewall rules apply
- Hugepages can be read by privileged users
- Consider using vfio-pci over uio for better isolation
- Rate limiting is critical to avoid self-DoS

## 📜 License

MIT License - see LICENSE file

## 🙏 Acknowledgments

- **DPDK Project** - For the amazing packet processing framework
- **Original NetGen Pro** - Python-based packet generator
- **Intel** - For DPDK development and optimization

## 📞 Support

- **Issues**: GitHub Issues
- **Documentation**: See `docs/` directory
- **Community**: DPDK mailing list

## 🚧 Roadmap

- [ ] IPv6 full support
- [ ] HTTP/DNS protocol simulation
- [ ] PCAP replay functionality
- [ ] Multi-node coordination
- [ ] Cloud deployment (AWS/Azure)
- [ ] Container support (Docker/K8s)
- [ ] Grafana integration
- [ ] REST API v2

---

**Built with ❤️ for network testing and lab environments**
