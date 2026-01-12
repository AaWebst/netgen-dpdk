# NetGen Pro - DPDK Edition - Troubleshooting Guide

## Error: "venv/bin/activate: No such file or directory"

**Problem:** Virtual environment was not created during installation.

**Solution 1 - Quick Fix:**
```bash
cd /opt/netgen-dpdk
sudo bash quick-setup-venv.sh
```

**Solution 2 - Full Reinstall:**
```bash
cd /opt/netgen-dpdk
sudo bash scripts/install.sh
```

**Solution 3 - Manual Setup:**
```bash
cd /opt/netgen-dpdk
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Error: "ModuleNotFoundError: No module named 'flask'"

**Problem:** Flask not installed in virtual environment.

**Solution:**
```bash
cd /opt/netgen-dpdk
source venv/bin/activate
pip install -r requirements.txt

# Or if requirements.txt is missing:
pip install Flask Flask-CORS Flask-SocketIO gevent netifaces psutil requests
```

---

## Error: "DPDK engine not found"

**Problem:** DPDK engine binary wasn't built.

**Solution:**
```bash
cd /opt/netgen-dpdk
make clean
make
```

**If build fails:**
```bash
# Check if DPDK is installed
pkg-config --modversion libdpdk

# If not found, install DPDK:
sudo bash scripts/install.sh
```

---

## Error: "Permission denied" when starting

**Problem:** DPDK requires root access.

**Solution:**
```bash
sudo ./start.sh
```

---

## Error: "Cannot allocate hugepages"

**Problem:** Hugepages not configured.

**Solution:**
```bash
# Check current allocation
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Allocate hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Make persistent
echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf
```

---

## Error: "No Ethernet devices found"

**Problem:** No DPDK-compatible interfaces or not bound.

**Solution:**
```bash
# Check available interfaces
dpdk-devbind.py --status

# Bind interface to DPDK
sudo dpdk-devbind.py --bind=vfio-pci 02:01.0
```

---

## Low Performance (<1 Gbps)

**Possible causes:**

1. **CPU governor not set to performance**
   ```bash
   # Check current setting
   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   
   # Set to performance
   sudo cpupower frequency-set -g performance
   ```

2. **Not enough hugepages**
   ```bash
   # Increase to 2048
   echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
   ```

3. **Interface not bound to DPDK**
   ```bash
   dpdk-devbind.py --status
   # Should show interface bound to vfio-pci
   ```

4. **Too few CPU cores**
   - DPDK uses multiple cores
   - Minimum: 4 cores
   - Recommended: 8+ cores

---

## Web UI Not Loading

**Problem:** Can't access http://localhost:8080

**Check 1 - Is server running?**
```bash
ps aux | grep dpdk_control_server
```

**Check 2 - Is port available?**
```bash
sudo lsof -i :8080
```

**Check 3 - Firewall?**
```bash
sudo ufw status
# If active, allow port:
sudo ufw allow 8080/tcp
```

**Check 4 - Check logs**
```bash
# Run server in foreground to see errors
cd /opt/netgen-dpdk/web
source ../venv/bin/activate
sudo python dpdk_control_server.py
```

---

## Complete Reinstall

If nothing works, clean reinstall:

```bash
# 1. Cleanup
cd /opt/netgen-dpdk
sudo ./start.sh  # Stop if running (Ctrl+C)
sudo rm -rf venv build

# 2. Reinstall
sudo bash scripts/install.sh

# 3. Test
sudo ./start.sh
```

---

## Check Installation Status

Run this diagnostic script:

```bash
#!/bin/bash
echo "=== NetGen Pro Installation Diagnostic ==="
echo ""

echo "1. Python3:"
which python3 && python3 --version || echo "  ❌ Not found"

echo ""
echo "2. Virtual environment:"
[ -d "/opt/netgen-dpdk/venv" ] && echo "  ✅ Exists" || echo "  ❌ Missing"

echo ""
echo "3. Flask in venv:"
/opt/netgen-dpdk/venv/bin/python -c "import flask; print('  ✅ Version:', flask.__version__)" 2>/dev/null || echo "  ❌ Not installed"

echo ""
echo "4. DPDK:"
pkg-config --modversion libdpdk 2>/dev/null && echo "  ✅ Installed" || echo "  ❌ Not installed"

echo ""
echo "5. DPDK engine binary:"
[ -f "/opt/netgen-dpdk/build/dpdk_engine" ] && echo "  ✅ Exists" || echo "  ❌ Missing"

echo ""
echo "6. Hugepages:"
HUGE=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages 2>/dev/null || echo "0")
echo "  Allocated: $HUGE"
[ "$HUGE" -ge 1024 ] && echo "  ✅ Sufficient" || echo "  ⚠️  Too few (need 1024+)"

echo ""
echo "7. Kernel modules:"
lsmod | grep -q vfio_pci && echo "  ✅ vfio-pci loaded" || echo "  ⚠️  vfio-pci not loaded"

echo ""
echo "8. Network interfaces:"
dpdk-devbind.py --status 2>/dev/null | head -20 || echo "  ⚠️  dpdk-devbind.py not found"

echo ""
echo "=== End Diagnostic ==="
```

Save as `check-install.sh` and run:
```bash
chmod +x check-install.sh
./check-install.sh
```

---

## Getting Help

1. Check this file first
2. Review README.md
3. Check QUICK-START.md
4. Run diagnostic script above
5. Check GitHub issues

---

## Common Quick Fixes

| Problem | Quick Fix |
|---------|-----------|
| No venv | `sudo bash quick-setup-venv.sh` |
| No Flask | `source venv/bin/activate && pip install -r requirements.txt` |
| No engine | `make clean && make` |
| No DPDK | `sudo bash scripts/install.sh` |
| Low performance | `sudo cpupower frequency-set -g performance` |
| Can't bind NIC | `sudo modprobe vfio-pci` |
| Permission denied | `sudo ./start.sh` |
| Port 8080 busy | Edit web/dpdk_control_server.py, change port |

---

## Still Having Issues?

Provide this information when asking for help:

```bash
# System info
uname -a
cat /etc/os-release

# Installation status
./check-install.sh

# Error messages
cd /opt/netgen-dpdk
sudo ./start.sh 2>&1 | tee error.log
```
