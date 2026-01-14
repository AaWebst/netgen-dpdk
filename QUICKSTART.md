# Quick Start Guide

Get NetGen Pro VEP1445 running in 5 minutes!

## 🚀 One-Command Installation

```bash
git clone https://github.com/yourusername/netgen-pro-vep1445.git
cd netgen-pro-vep1445
sudo bash install.sh
```

**That's it!** The installer automatically:
- ✅ Installs all dependencies (DPDK, build tools, Python)
- ✅ Builds the DPDK engine
- ✅ Sets up Python virtual environment
- ✅ Configures DPDK interfaces (optional)
- ✅ Installs systemd service
- ✅ Completes full setup

## 📱 Access the GUI

After installation completes:

```bash
# The installer shows the URL, or find it:
http://$(hostname -I | awk '{print $1}'):8080
```

## 🎯 Generate Your First Traffic Flow

1. Open GUI in browser
2. Click **"Traffic Matrix"** tab
3. Select **Source**: Click "LAN1" box (highlights green)
4. Select **Destination**: Click "LAN2" box (highlights blue)
5. Set **Rate**: 100 Mbps
6. Click **"Add Traffic Flow"**
7. Click **"START ALL FLOWS"**

**Traffic is now flowing!** 🎉

---

## 🔧 Manual Installation (Alternative)

If you prefer step-by-step control:

```bash
# Clone repository
git clone https://github.com/yourusername/netgen-pro-vep1445.git
cd netgen-pro-vep1445

# Build DPDK engine
make

# Setup Python environment
sudo bash scripts/quick-setup-venv.sh

# Configure interfaces
sudo bash scripts/configure-vep1445-basic.sh

# Install service
sudo bash scripts/install-service.sh

# Start service
sudo systemctl start netgen-pro-dpdk
```

---

## 🐛 Troubleshooting

### Build Fails

```bash
# Install dependencies manually
sudo apt-get update
sudo apt-get install -y dpdk dpdk-dev libjson-c-dev build-essential python3-venv

# Clean and rebuild
make clean && make
```

### Service Won't Start

```bash
# Check logs
sudo journalctl -u netgen-pro-dpdk -n 50

# Common fixes:
sudo modprobe vfio-pci
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Restart service
sudo systemctl restart netgen-pro-dpdk
```

### Can't Access GUI

```bash
# Check if service is running
sudo systemctl status netgen-pro-dpdk

# Check if port 8080 is in use
sudo lsof -i :8080

# Find correct IP address
ip addr show eno1
```

### Interfaces Not Binding to DPDK

```bash
# Check interface status
sudo dpdk-devbind.py --status

# Manually bind interface (example for eno7)
sudo ip link set eno7 down
sudo dpdk-devbind.py --bind=vfio-pci $(ethtool -i eno7 | grep bus-info | awk '{print $2}')
```

---

## 📊 Quick Commands Reference

```bash
# Service management
sudo systemctl start netgen-pro-dpdk    # Start service
sudo systemctl stop netgen-pro-dpdk     # Stop service
sudo systemctl status netgen-pro-dpdk   # Check status
sudo systemctl restart netgen-pro-dpdk  # Restart service

# View logs
sudo journalctl -u netgen-pro-dpdk -f   # Follow logs
sudo journalctl -u netgen-pro-dpdk -n 50  # Last 50 lines

# Check DPDK interfaces
sudo dpdk-devbind.py --status           # Show interface status
sudo dpdk-devbind.py --status-dev net   # Network devices only

# Rebuild engine
cd /opt/netgen-pro-vep1445  # Or wherever you installed
make clean && make
```

---

## 🎓 Next Steps

- **Multi-LAN Testing**: See `docs/GUI-GUIDE.md`
- **RFC 2544 Tests**: See `docs/FEATURES.md`
- **Advanced Configuration**: See `docs/VEP1445-CONFIG.md`
- **Full Documentation**: See `docs/INSTALLATION.md`

---

**Need help?** Open an issue on GitHub!
