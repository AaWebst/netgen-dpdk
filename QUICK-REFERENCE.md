# NetGen Pro - DPDK Edition - Quick Reference Card

## 🎯 Installation (One Time)

```bash
cd /opt && sudo tar xzf netgen-pro-dpdk-v2.0-FINAL.tar.gz
cd netgen-dpdk && sudo bash scripts/install.sh
sudo dpdk-devbind.py --bind=vfio-pci 02:01.0
```

---

## 🎛️ Systemd Service (Production)

```bash
# Install service
sudo bash install-service.sh

# Start
sudo systemctl start netgen-pro-dpdk

# Stop
sudo systemctl stop netgen-pro-dpdk

# Status
sudo systemctl status netgen-pro-dpdk

# Logs
sudo journalctl -u netgen-pro-dpdk -f

# Enable auto-start
sudo systemctl enable netgen-pro-dpdk
```

---

## 🖥️ Manual Control (Development)

```bash
# Start
sudo ./start.sh

# Stop
Ctrl+C

# Check if running
ps aux | grep dpdk_control_server
```

---

## 🌐 Web UI

**URL:** http://localhost:8080

**Features:**
- Real-time statistics
- Start/stop traffic
- Profile management
- Test history
- Export to CSV

---

## 📡 API Endpoints

```bash
# Status
curl http://localhost:8080/api/status

# Start traffic
curl -X POST http://localhost:8080/api/start \
  -H "Content-Type: application/json" \
  -d '{"profiles": [{"dst_ip": "192.168.1.100", "rate_mbps": 1000}]}'

# Stop traffic
curl -X POST http://localhost:8080/api/stop

# Get statistics
curl http://localhost:8080/api/stats

# List profiles
curl http://localhost:8080/api/profiles

# Test history
curl http://localhost:8080/api/history
```

---

## 🔧 Troubleshooting

```bash
# Fix missing venv
sudo bash quick-setup-venv.sh

# Rebuild DPDK engine
make clean && make

# Check service logs
sudo journalctl -u netgen-pro-dpdk -n 50

# Check hugepages
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Allocate hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Check network interfaces
dpdk-devbind.py --status

# Bind interface
sudo dpdk-devbind.py --bind=vfio-pci 02:01.0
```

---

## 🔍 Monitoring

```bash
# Service status
systemctl status netgen-pro-dpdk

# Live logs
journalctl -u netgen-pro-dpdk -f

# Check web UI
curl http://localhost:8080/api/status

# CPU usage
top -p $(pgrep -f dpdk_control_server)

# Memory usage
ps aux | grep dpdk_control_server
```

---

## 📊 Performance Tips

```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Increase hugepages
echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Check CPU isolation (optional)
cat /proc/cmdline | grep isolcpus
```

---

## 🚀 Common Tasks

### Start 1 Gbps UDP Traffic
```bash
curl -X POST http://localhost:8080/api/start -H "Content-Type: application/json" \
-d '{
  "profiles": [{
    "name": "Test1",
    "dst_ip": "192.168.1.100",
    "dst_port": 5000,
    "protocol": "udp",
    "packet_size": 1024,
    "rate_mbps": 1000
  }]
}'
```

### Stop All Traffic
```bash
curl -X POST http://localhost:8080/api/stop
```

### Export Test History
```bash
curl http://localhost:8080/api/export/history -o history.csv
```

---

## 📁 File Locations

```
/opt/netgen-dpdk/
├── build/dpdk_engine           # DPDK engine binary
├── web/dpdk_control_server.py  # Python server
├── venv/                        # Python virtual env
├── scripts/install.sh           # Installer
├── start.sh                     # Manual start
├── install-service.sh           # Service installer
└── *.md                         # Documentation
```

---

## 🆘 Quick Fixes

| Problem | Solution |
|---------|----------|
| Missing venv | `sudo bash quick-setup-venv.sh` |
| Service won't start | `journalctl -u netgen-pro-dpdk -n 50` |
| Low performance | `sudo cpupower frequency-set -g performance` |
| Engine not found | `make clean && make` |
| Port 8080 busy | `sudo lsof -i :8080` |
| Permission denied | Run with `sudo` |

---

## 📚 Documentation Files

- **README.md** - Overview
- **SYSTEMD-SERVICE.md** - Service management
- **TROUBLESHOOTING.md** - Problem solving
- **FIX-VENV-ERROR.md** - Virtual environment fixes
- **QUICK-START.md** - Detailed installation
- **QUICK-REFERENCE.md** - This file

---

## 🎯 Production Checklist

- [ ] Install with systemd service
- [ ] Enable auto-start: `systemctl enable netgen-pro-dpdk`
- [ ] Bind network interface to DPDK
- [ ] Set CPU governor to performance
- [ ] Configure firewall (allow port 8080)
- [ ] Test web UI access
- [ ] Test API endpoints
- [ ] Monitor logs: `journalctl -u netgen-pro-dpdk -f`
- [ ] Verify performance
- [ ] Document configuration

---

**Quick access:** Bookmark this file for instant reference!
