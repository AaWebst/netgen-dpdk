# NetGen Pro VEP1445 Edition

**Professional Network Performance Testing Platform with DPDK**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![DPDK](https://img.shields.io/badge/DPDK-24.11-blue.svg)](https://www.dpdk.org/)
[![Platform](https://img.shields.io/badge/Platform-VEP1445-orange.svg)](https://www.lannerinc.com/)

---

## 🎯 Overview

NetGen Pro is a high-performance network traffic generator and analyzer specifically designed for the **Lanner VEP1445** network appliance. It leverages Intel DPDK to achieve **10+ Gbps** throughput with nanosecond-precision latency measurements.

### Key Features

- ✅ **10+ Gbps Traffic Generation** - Line-rate performance with DPDK
- ✅ **Multi-LAN Testing** - Simultaneous traffic across 5 LAN ports + 10G ports
- ✅ **RFC 2544 Compliance** - Throughput, latency, frame loss, and back-to-back tests
- ✅ **Advanced Protocols** - IPv6, MPLS, VXLAN, Q-in-Q VLAN support
- ✅ **Network Impairments** - Packet loss, delay, jitter, and duplication simulation
- ✅ **RX/TX Loopback Testing** - Full bidirectional performance measurement
- ✅ **Hardware Timestamping** - Sub-nanosecond precision latency tracking
- ✅ **Professional Web GUI** - Modern, intuitive interface for configuration

---

## 🚀 Quick Start

### Prerequisites

```bash
# Ubuntu 22.04/24.04 LTS
sudo apt-get update
sudo apt-get install -y dpdk dpdk-dev libjson-c-dev build-essential python3-pip
```

### Installation

#### Option 1: Automatic Installation (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/netgen-pro-vep1445.git
cd netgen-pro-vep1445

# 2. Run complete installation
sudo bash install.sh
```

This will:
- Install all dependencies (DPDK, build tools, Python)
- Build the DPDK engine
- Setup Python virtual environment
- Configure DPDK interfaces (optional)
- Install systemd service
- Complete setup in one command!

#### Option 2: Manual Installation

```bash
# 1. Clone repository
git clone https://github.com/yourusername/netgen-pro-vep1445.git
cd netgen-pro-vep1445

# 2. Build DPDK engine
make

# 3. Setup Python environment
sudo bash scripts/quick-setup-venv.sh

# 4. Configure VEP1445 interfaces
sudo bash scripts/configure-vep1445-basic.sh

# 5. Install systemd service
sudo bash scripts/install-service.sh

# 6. Start service
sudo systemctl start netgen-pro-dpdk
```

### Access GUI

```bash
http://<VEP1445-MGMT-IP>:8080
```

---

## 🔌 VEP1445 Port Configuration

```
┌─────────────────────────────────────────┐
│ VEP1445 Lanner Network Appliance        │
│                                          │
│ eno1: Management (1G, Linux, DHCP)      │
│ eno2: LAN1 (1G, Available/DPDK)         │
│ eno3: LAN2 (1G, Available/DPDK)         │
│ eno4: LAN3 (1G, Available/DPDK)         │
│ eno5: LAN4 (1G, Available/DPDK)         │
│ eno6: LAN5 (1G, Available/DPDK)         │
│ eno7: 10G TX (DPDK Primary)             │
│ eno8: 10G RX (DPDK Primary)             │
└─────────────────────────────────────────┘
```

---

## 📊 Features

### Traffic Generation

- **Protocols**: UDP, TCP, ICMP, HTTP, DNS
- **Rate Control**: 1 Mbps to 10+ Gbps per flow
- **Packet Sizes**: 64 to 9000 bytes (jumbo frames)
- **Multi-Stream**: Up to 64 simultaneous traffic profiles
- **Payload Patterns**: Random, zeros, ones, increment, custom

### Advanced Protocols

- **IPv6**: Full IPv6 packet generation and analysis
- **MPLS**: Label stacking (up to 4 labels) for LSP simulation
- **VXLAN**: Overlay network encapsulation with VNI support
- **Q-in-Q**: 802.1ad double VLAN tagging
- **GRE**: Generic Routing Encapsulation tunneling

### Network Impairments

- **Packet Loss**: 0-100% configurable random or burst loss
- **Latency**: Fixed delay + variable jitter injection
- **Duplication**: Configurable packet duplication rate
- **Reordering**: Out-of-order packet simulation

### RFC 2544 Compliance Testing

- **Throughput Test**: Binary search for maximum sustainable rate
- **Latency Test**: Min/max/average latency and jitter measurement
- **Frame Loss Test**: Precise packet loss percentage calculation
- **Back-to-Back Test**: Burst capacity measurement at zero loss

### Performance Metrics

- **TX Statistics**: Packets sent, bytes transmitted, rate
- **RX Statistics**: Packets received, bytes captured
- **Latency**: Min/max/average/jitter (nanosecond precision)
- **Loss Tracking**: Packet loss, out-of-order, duplicates
- **Sequence Analysis**: Gap detection, late arrivals

---

## 🎨 Web GUI

### Multi-LAN Traffic Matrix

Visual interface for configuring traffic between multiple LANs:

```
Source Selection:     [LAN1] [LAN2] [LAN3] [LAN4] [LAN5] [10G]
Destination(s):       [LAN1] [LAN2] [LAN3] [LAN4] [LAN5] [10G]
                       ↑      ↑      ↑      ↑      ↑
                   Multi-select supported!

Example: LAN1 → LAN2,3,4,5 = 4 flows created instantly
```

### Features

- 🎯 **Interactive LAN Matrix** - Point and click traffic configuration
- 📊 **Real-Time Statistics** - Live updates every second
- 🧪 **RFC 2544 Tests** - Integrated compliance testing
- ⚙️ **Advanced Features** - All protocols and impairments accessible
- 🎨 **Professional Design** - Cyber-industrial themed interface

---

## 📖 Usage Examples

### Example 1: Basic Traffic Generation

```bash
# Generate 1 Gbps UDP traffic from LAN1 to LAN2
1. Open GUI: http://192.168.0.100:8080
2. Click "Traffic Matrix"
3. Select Source: LAN1
4. Select Destination: LAN2
5. Set Rate: 1000 Mbps
6. Click "Add Traffic Flow"
7. Click "START ALL FLOWS"
```

### Example 2: Multi-Destination Traffic

```bash
# LAN1 sends to ALL other LANs simultaneously
1. Select Source: LAN1
2. Click Destinations: LAN2, LAN3, LAN4, LAN5 (multi-select)
3. Set Rate: 100 Mbps per flow
4. Click "Add Traffic Flow"
5. Result: 4 flows created, 400 Mbps total
```

### Example 3: RFC 2544 Throughput Test

```bash
# Find maximum network throughput
1. Navigate to "RFC 2544 Tests"
2. Click "Throughput Test"
3. Configure:
   - Duration: 60 seconds
   - Frame Size: 1518 bytes
   - Loss Threshold: 0.01%
4. Click "Run Test"
5. View Results: Max rate, actual loss
```

### Example 4: Network Impairment Testing

```bash
# Simulate WAN conditions
1. Navigate to "Advanced Features"
2. Enable Impairments:
   - Packet Loss: 1%
   - Latency: 50ms fixed, 10ms jitter
3. Configure traffic flow
4. Start traffic
5. Observe application behavior under poor conditions
```

### Example 5: IPv6 + MPLS Traffic

```bash
# Modern datacenter protocol testing
1. Navigate to "Advanced Features"
2. Enable:
   - IPv6 Mode
   - MPLS Labels (100, 200)
3. Configure flow
4. Start traffic
5. Packets contain IPv6 headers + MPLS label stack
```

---

## 🏗️ Architecture

### Components

```
┌─────────────────────────────────────────┐
│           Web GUI (Browser)             │
│         http://x.x.x.x:8080             │
└────────────────┬────────────────────────┘
                 │ HTTP/WebSocket
┌────────────────▼────────────────────────┐
│      Python Control Server              │
│      (Flask + Socket.IO)                │
└────────────────┬────────────────────────┘
                 │ Unix Socket
┌────────────────▼────────────────────────┐
│         DPDK Engine (C++)               │
│    - Packet Generation (TX)             │
│    - Packet Capture (RX)                │
│    - Hardware Timestamping              │
│    - Statistics Tracking                │
└────────────────┬────────────────────────┘
                 │ DPDK PMD
┌────────────────▼────────────────────────┐
│         Network Interfaces              │
│  eno7 (TX) ←→ Network ←→ eno8 (RX)     │
└─────────────────────────────────────────┘
```

### Technology Stack

- **DPDK**: Zero-copy packet I/O, 10+ Gbps performance
- **C++17**: DPDK engine implementation
- **Python 3**: Control server and API
- **Flask**: Web framework
- **Socket.IO**: Real-time WebSocket communication
- **HTML5/CSS3/JavaScript**: Modern web GUI

---

## 🔧 Configuration

### DPDK Configuration

Edit `/opt/netgen-pro-complete/dpdk-config.json`:

```json
{
  "dpdk": {
    "tx_port": {
      "interface": "eno7",
      "pci": "0000:04:00.0",
      "port_id": 0
    },
    "rx_port": {
      "interface": "eno8",
      "pci": "0000:04:00.1",
      "port_id": 1
    }
  }
}
```

### Service Configuration

Edit `/etc/systemd/system/netgen-pro-dpdk.service` to customize:

- Hugepages allocation
- CPU core isolation
- Log levels
- Port bindings

---

## 📈 Performance Benchmarks

### Throughput

| Packet Size | Single Stream | Multi-Stream (4) | Protocol |
|-------------|---------------|------------------|----------|
| 64 bytes    | 14.88 Mpps    | 14.88 Mpps       | UDP      |
| 1518 bytes  | 10+ Gbps      | 10+ Gbps         | UDP      |
| 1518 bytes  | 10+ Gbps      | 10+ Gbps         | TCP      |

### Latency

| Test Type     | Min    | Max     | Avg    | Jitter |
|---------------|--------|---------|--------|--------|
| Loopback      | 15 µs  | 250 µs  | 45 µs  | 35 µs  |
| Single Switch | 25 µs  | 400 µs  | 80 µs  | 60 µs  |
| Routed        | 100 µs | 1000 µs | 200 µs | 150 µs |

### Resource Usage

- **CPU**: 2-3 cores @ 100% (isolated cores)
- **Memory**: 2GB (hugepages)
- **Network**: Line rate (10 Gbps)

---

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u netgen-pro-dpdk -n 50

# Common issues:
# 1. Interfaces not bound to DPDK
sudo dpdk-devbind.py --status

# 2. Hugepages not configured
cat /proc/meminfo | grep Huge

# 3. DPDK engine not built
ls -lh build/dpdk_engine
```

### No RX Packets

```bash
# Verify loopback connection
# TX: eno7 → Network → RX: eno8

# Check if RX port is bound
sudo dpdk-devbind.py --status | grep eno8

# Verify traffic reaches RX port
sudo tcpdump -i <other-interface> -c 10
```

### Port Conflict (8080)

```bash
# Check what's using port 8080
sudo lsof -i :8080

# Change port in server config
# Or kill conflicting process
sudo kill -9 <PID>
```

---

## 📚 Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- **[VEP1445 Configuration](docs/VEP1445-CONFIG.md)** - Hardware-specific setup
- **[GUI User Guide](docs/GUI-GUIDE.md)** - Web interface walkthrough
- **[API Reference](docs/API.md)** - REST API documentation
- **[RFC 2544 Guide](docs/RFC2544.md)** - Compliance testing procedures

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Intel DPDK** - High-performance packet processing framework
- **Lanner** - VEP1445 network appliance platform
- **RFC 2544** - Network performance testing methodology

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/netgen-pro-vep1445/issues)
- **Documentation**: [Wiki](https://github.com/yourusername/netgen-pro-vep1445/wiki)
- **Email**: support@example.com

---

## 🗺️ Roadmap

- [ ] v1.0: Core DPDK engine + basic GUI
- [x] v2.0: Multi-LAN support
- [x] v3.0: RFC 2544 compliance
- [x] v3.1: Advanced protocols (IPv6, MPLS, VXLAN)
- [x] v3.2: Network impairments
- [ ] v4.0: PCAP capture and replay
- [ ] v4.1: API integration (REST + gRPC)
- [ ] v5.0: Cloud deployment support

---

**Built with ❤️ for network performance testing**
