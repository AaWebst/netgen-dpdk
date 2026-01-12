# NetGen Pro - DPDK Edition v2.0

## 🚀 High-Performance Network Traffic Generator

**10+ Gbps capable with DPDK acceleration**

### Features
- ✅ **10+ Gbps throughput** (vs 2-5 Gbps Python)
- ✅ Modern web interface
- ✅ **Systemd service** (auto-start on boot)
- ✅ UDP, TCP, ICMP protocols
- ✅ Multi-profile support
- ✅ VLAN tagging & QoS
- ✅ Real-time statistics
- ✅ Profile management (save/load)
- ✅ Test history tracking
- ✅ CSV export
- ✅ Coordinator integration
- ✅ SQLite database
- ✅ REST API + WebSocket

---

## 📦 Quick Start

### Option 1: With Systemd Service (Production) ⭐ RECOMMENDED

```bash
# 1. Extract
cd /opt
sudo tar xzf netgen-pro-dpdk-v2.0-FINAL.tar.gz
cd netgen-dpdk

# 2. Install everything (including systemd service)
sudo bash scripts/install.sh
# Say YES when asked about systemd service

# 3. Bind network interface
sudo dpdk-devbind.py --bind=vfio-pci 02:01.0

# 4. Service is now running and will start on boot!
# Access: http://localhost:8080
```

### Option 2: Manual Start (Development/Testing)

```bash
# 1. Extract and install
cd /opt
sudo tar xzf netgen-pro-dpdk-v2.0-FINAL.tar.gz
cd netgen-dpdk
sudo bash scripts/install.sh
# Say NO to systemd service

# 2. Start manually
sudo ./start.sh

# 3. Access
http://localhost:8080
```

---

## 🎛️ Systemd Service Management

### Install Service (if not done during installation)
```bash
sudo bash install-service.sh
```

### Service Commands
```bash
# Start service
sudo systemctl start netgen-pro-dpdk

# Stop service
sudo systemctl stop netgen-pro-dpdk

# Restart service
sudo systemctl restart netgen-pro-dpdk

# Check status
sudo systemctl status netgen-pro-dpdk

# View logs
sudo journalctl -u netgen-pro-dpdk -f

# Enable auto-start on boot
sudo systemctl enable netgen-pro-dpdk

# Disable auto-start
sudo systemctl disable netgen-pro-dpdk
```

**See SYSTEMD-SERVICE.md for complete guide**

---

## 🆚 Manual vs Service

| Feature | Manual (`./start.sh`) | Systemd Service |
|---------|---------------------|-----------------|
| Auto-start on boot | ❌ | ✅ |
| Auto-restart on crash | ❌ | ✅ |
| Centralized logging | ❌ | ✅ |
| Production use | ❌ | ✅ |
| Development/testing | ✅ | ❌ |
| See output directly | ✅ | ❌ |

---

## 📊 Performance

| CPU Cores | Throughput | Use Case |
|-----------|------------|----------|
| 2 | 2-4 Gbps | Light testing |
| 4 | 8-12 Gbps | Heavy testing |
| 8+ | **Line-rate 10G** | Production |

**3-5x faster than Python version!**

---

## 🐛 Troubleshooting

### Virtual Environment Missing
```bash
sudo bash quick-setup-venv.sh
```

### Service Won't Start
```bash
sudo journalctl -u netgen-pro-dpdk -n 50
```

### DPDK Engine Not Built
```bash
make clean && make
sudo systemctl restart netgen-pro-dpdk
```

**See TROUBLESHOOTING.md for complete guide**

---

## 📚 Documentation

- **SYSTEMD-SERVICE.md** - Complete service management guide
- **FIX-VENV-ERROR.md** - Fix virtual environment issues
- **QUICK-START.md** - Detailed installation guide
- **TROUBLESHOOTING.md** - Common issues & solutions
- **DPDK-CONVERSION-COMPLETE.md** - Feature comparison

---

## 📁 File Structure

```
netgen-dpdk/
├── src/
│   └── dpdk_engine.cpp          # DPDK C++ engine
├── web/
│   ├── dpdk_control_server.py   # Python control server
│   └── templates/
│       └── index.html            # Web UI
├── scripts/
│   └── install.sh                # Main installer
├── start.sh                      # Manual startup script
├── quick-setup-venv.sh           # Quick venv fix
├── install-service.sh            # Systemd service installer
├── netgen-pro-dpdk.service       # Systemd service file
├── requirements.txt              # Python dependencies
├── Makefile                      # Build configuration
└── *.md                          # Documentation
```

---

## 🌐 Access

**Web UI:** http://localhost:8080

**API Examples:**

```bash
# Get status
curl http://localhost:8080/api/status

# Start traffic
curl -X POST http://localhost:8080/api/start \
  -H "Content-Type: application/json" \
  -d '{"profiles": [{"dst_ip": "192.168.1.100", "rate_mbps": 1000}]}'

# Get stats
curl http://localhost:8080/api/stats

# Stop traffic
curl -X POST http://localhost:8080/api/stop
```

---

## 🔧 System Requirements

- Ubuntu 20.04+ or Debian 11+
- 4+ CPU cores (8+ recommended)
- 8+ GB RAM
- DPDK-compatible network interface
- Root/sudo access

---

## 📞 Support

- Read documentation in `*.md` files
- Check TROUBLESHOOTING.md first
- Review systemd logs: `journalctl -u netgen-pro-dpdk`

---

## 🎉 Summary

**Production Deployment:**
1. Install with systemd service
2. Starts automatically on boot
3. Restarts if crashed
4. Access http://localhost:8080

**Development/Testing:**
1. Install without service
2. Start manually with `./start.sh`
3. Stop with Ctrl+C

---

## 🚀 Made with ❤️ for network engineers

**10+ Gbps for $0 - That's the NetGen Pro way!**
