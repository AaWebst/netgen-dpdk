# Changelog

All notable changes to NetGen Pro - DPDK Edition will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-06

### Added
- Initial release of NetGen Pro DPDK Edition
- High-performance DPDK-based packet generator (10+ Gbps capable)
- C++ DPDK engine with multi-core support
- Python Flask web control interface with virtual environment support
- REST API for programmatic control
- WebSocket support for real-time statistics
- Protocol support: UDP, TCP, ICMP
- IPv4 and IPv6 support
- VLAN tagging support
- MPLS label support
- DSCP marking
- Multiple payload patterns (random, zeros, ones, increment, custom)
- Network impairment simulation:
  - Packet loss
  - Latency injection
  - Jitter simulation
  - Packet reordering
  - Packet duplication
- Burst mode traffic generation
- Rate limiting with TSC-based precision
- Per-profile statistics with atomic counters
- Unix socket IPC between Python and C++ components
- Automated installation script with venv support
- Python virtual environment (PEP 668 compliant)
- Automatic venv activation in start.sh
- activate.sh helper script for manual activation
- Comprehensive documentation (2000+ lines)
- Example traffic profiles
- Hugepage configuration utilities
- requirements.txt for Python dependencies
- DEPENDENCIES.md comprehensive dependency guide
- VENV.md virtual environment documentation

### Fixed
- Hugepage directory detection for different Linux distributions
- Support for both `hugepages-2048kB` and `hugepages-2M` naming conventions
- NUMA-aware hugepage paths
- Proper error handling for hugepage allocation failures
- Python "externally-managed-environment" error (PEP 668) via venv

### Technical Details
- DPDK version: 23.11
- Minimum kernel: 4.4+ (5.x recommended)
- Supported NICs: Intel 82599+, Mellanox ConnectX-4+, Intel X710/XXV710
- Memory: 4GB minimum, 8GB recommended
- CPU: 4+ cores minimum, 8+ cores for 10 Gbps

### Performance
- 64-byte packets: 1.5 Gbps per core, 2.2M pps
- 1500-byte packets: 10 Gbps per core, 830K pps
- 4 cores with 1500-byte packets: 40 Gbps, 3.3M pps
- 20x improvement over Python-only version

### Known Issues
- Packet reordering simulation not yet fully implemented (placeholder in code)
- Requires dedicated network interface (cannot share with kernel)
- DPDK initialization requires root or CAP_SYS_ADMIN capability

### Documentation
- README.md: Complete installation and usage guide (500+ lines)
- MIGRATION.md: Migration from Python version (300+ lines)
- DEPLOYMENT.md: Production deployment guide (400+ lines)
- DEPENDENCIES.md: Complete dependency reference (300+ lines)

## [Unreleased]

### Planned Features
- Full packet reordering implementation
- Additional protocol support (GRE, VXLAN, GTP)
- Traffic recording and replay
- PCAP file import/export
- Advanced statistics (percentiles, histograms)
- Multi-source coordination
- Hardware timestamping support
- Flow-based traffic generation
- API authentication
- Prometheus metrics export

---

## Version History

- **1.0.0** (2025-01-06): Initial release with core DPDK functionality
