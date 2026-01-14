# Changelog

All notable changes to NetGen Pro VEP1445 will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2026-01-14

### Added
- **Multi-LAN Traffic Matrix** - Visual interface for multi-destination traffic generation
- **Interactive GUI** - Complete redesign with cyber-industrial theme
- **Multi-Destination Support** - Select multiple destination LANs simultaneously
- **Auto IP Generation** - Automatic source/destination IP assignment per LAN
- **Visual Port Status** - Real-time port binding and status overview
- **Advanced Protocol Toggles** - Easy enable/disable for IPv6, MPLS, VXLAN, Q-in-Q
- **Network Impairment Controls** - Visual toggles for loss, delay, duplication
- **Professional Design** - Cyber-themed dark interface with animations

### Changed
- GUI completely redesigned for VEP1445 multi-port testing
- Simplified traffic flow creation (3-click setup)
- Improved real-time statistics visualization
- Enhanced RFC 2544 test interface

### Fixed
- Socket.IO connection stability
- Port conflict detection and resolution
- Service startup reliability

## [3.1.0] - 2026-01-13

### Added
- **Network Impairments** - Packet loss, delay, jitter, duplication simulation
- **IPv6 Support** - Full IPv6 packet generation and analysis
- **MPLS Labels** - Label stacking for LSP simulation (up to 4 labels)
- **VXLAN Encapsulation** - Overlay network support with VNI
- **Q-in-Q VLAN** - 802.1ad double VLAN tagging
- **GRE Tunneling** - Generic Routing Encapsulation support
- Impairment configuration in GUI
- Advanced protocol toggles

### Changed
- Extended packet builder for advanced protocols
- Enhanced traffic profile structure
- Improved DPDK engine architecture

## [3.0.0] - 2026-01-12

### Added
- **RFC 2544 Compliance** - Full test suite implementation
- **RX Support** - Dual-port TX/RX operation
- **Hardware Timestamping** - Nanosecond precision latency measurement
- **Throughput Test** - Binary search for maximum sustainable rate
- **Latency Test** - Min/max/average/jitter measurement
- **Frame Loss Test** - Precise packet loss calculation
- **Back-to-Back Test** - Burst capacity testing
- Loopback testing support (eno7 TX, eno8 RX)
- TX→RX packet correlation
- Sequence number tracking
- Out-of-order detection
- Duplicate packet detection

### Changed
- DPDK engine enhanced with RX capabilities
- Statistics tracking expanded
- GUI updated with RFC 2544 test interface

## [2.0.0] - 2026-01-10

### Added
- **Multi-Port Support** - Support for all 6 LAN ports + 10G ports
- **HTTP Traffic Generation** - GET/POST/PUT/DELETE requests
- **DNS Query Generation** - A/AAAA/MX record queries
- **Custom Payload Patterns** - 6 different payload types
- VEP1445-specific configuration script
- Port status matrix in GUI
- Multiple simultaneous traffic profiles

### Changed
- Architecture redesigned for multi-port operation
- Configuration system improved
- Web GUI enhanced for multi-LAN selection

## [1.0.0] - 2025-12-15

### Added
- Initial DPDK engine implementation
- Basic UDP/TCP/ICMP packet generation
- Single-port TX operation (10+ Gbps)
- Web-based GUI
- Flask control server
- Socket.IO real-time statistics
- 17 traffic presets
- Rate limiting and burst mode
- VLAN tagging and QoS (DSCP)
- Systemd service integration
- SQLite database for profiles and history

### Features
- 10+ Gbps throughput
- Multi-stream support (up to 64 profiles)
- Real-time statistics
- Profile management
- Test history tracking

---

## Version History

- **v3.2.0** - Multi-LAN GUI + Enhanced UX
- **v3.1.0** - Advanced Protocols + Impairments
- **v3.0.0** - RFC 2544 + RX Support
- **v2.0.0** - Multi-Port + Application Protocols
- **v1.0.0** - Initial Release

---

## Upgrade Notes

### Upgrading to v3.2.0

```bash
# Stop service
sudo systemctl stop netgen-pro-dpdk

# Backup configuration
cp /opt/netgen-pro-complete/dpdk-config.json ~/dpdk-config.backup

# Extract new version
cd /opt
sudo tar xzf netgen-pro-vep1445-v3.2.0.tar.gz

# Restore configuration
cp ~/dpdk-config.backup /opt/netgen-pro-complete/dpdk-config.json

# Rebuild
cd /opt/netgen-pro-complete
make clean && make

# Restart service
sudo systemctl start netgen-pro-dpdk
```

### Breaking Changes

None in v3.2.0 - fully backward compatible.

---

## Future Roadmap

### Planned for v4.0.0
- PCAP capture and replay
- Advanced filtering
- Flow analysis
- Export to Wireshark format

### Planned for v4.1.0
- REST API enhancements
- gRPC support
- API authentication
- Rate limiting

### Planned for v5.0.0
- Container deployment
- Kubernetes support
- Cloud integration
- Distributed testing
