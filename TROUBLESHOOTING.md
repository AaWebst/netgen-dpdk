# NetGen Pro VEP1445 - Troubleshooting Guide

## Issue: Traffic Not Starting

### Symptoms:
- Click "Start All Flows" but no traffic generated
- Statistics show 0 packets TX/RX
- No errors in GUI

### Diagnostic Steps:

#### 1. Run Diagnostic Script
```bash
cd /opt/netgen-dpdk
sudo bash scripts/diagnostics.sh
```

This will check:
- ✅ Service status
- ✅ DPDK engine running
- ✅ Control socket exists
- ✅ Ports bound to DPDK
- ✅ Hugepages allocated
- ✅ Link status

#### 2. Check Service Status
```bash
sudo systemctl status netgen-pro-dpdk
```

Should show: `Active: active (running)`

If not:
```bash
sudo systemctl start netgen-pro-dpdk
sudo journalctl -u netgen-pro-dpdk -f
```

#### 3. Verify DPDK Bindings
```bash
sudo dpdk-devbind.py --status
```

Should see at least 2 ports bound to DPDK:
```
Network devices using DPDK-compatible driver
============================================
0000:05:00.0 '...' drv=vfio-pci unused=ixgbe
0000:05:00.1 '...' drv=vfio-pci unused=ixgbe
```

If not:
```bash
cd /opt/netgen-dpdk
sudo bash scripts/configure-vep1445-smart.sh
```

#### 4. Check Port Mapping
The DPDK engine uses **port IDs (0, 1, 2...)** not interface names!

Example mapping:
- Port 0 → eno7 (first DPDK-bound interface)
- Port 1 → eno8 (second DPDK-bound interface)

**Common Issue:** GUI says "LAN1" but DPDK doesn't know which port that is!

**Solution:** The GUI needs to map LAN names to DPDK port IDs.

#### 5. Test with Direct API Call
```bash
# Create test config
cat > /tmp/test.json << 'EOFF'
{
    "profiles": [
        {
            "src_port": 1234,
            "dst_port": 5678,
            "src_ip": "24.1.6.130",
            "dst_ip": "24.1.1.130",
            "protocol": "UDP",
            "rate_mbps": 20,
            "packet_size": 1400,
            "duration_sec": 10
        }
    ]
}
EOFF

# Start traffic
curl -X POST http://localhost:8080/api/start \
     -H "Content-Type: application/json" \
     -d @/tmp/test.json

# Check status
curl http://localhost:8080/api/status
```

#### 6. Check Control Socket Communication
```bash
# Test if control socket works
echo '{"command":"status"}' | nc -U /tmp/dpdk_engine_control.sock
```

Should return JSON with engine status.

If no response:
```bash
# Check if socket exists
ls -lh /tmp/dpdk_engine_control.sock

# Check DPDK engine logs
sudo journalctl -u netgen-pro-dpdk -n 100 | grep -i socket
```

### Common Causes & Solutions:

#### Cause 1: Wrong Port IDs
**Problem:** GUI sends "LAN1" but engine expects port 0/1

**Solution:** Check `/opt/netgen-dpdk/dpdk-config.json`:
```json
{
    "dpdk": {
        "tx_port": {"interface": "eno7", "pci": "...", "port_id": 0},
        "rx_port": {"interface": "eno8", "pci": "...", "port_id": 1}
    }
}
```

#### Cause 2: Ports Not Bound to DPDK
**Problem:** Interfaces still using kernel driver

**Solution:**
```bash
sudo dpdk-devbind.py --bind=vfio-pci 0000:05:00.0
sudo dpdk-devbind.py --bind=vfio-pci 0000:05:00.1
sudo systemctl restart netgen-pro-dpdk
```

#### Cause 3: Insufficient Hugepages
**Problem:** Not enough memory for DPDK

**Solution:**
```bash
# Check current
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Set to 1024
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Make persistent
echo "vm.nr_hugepages=1024" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### Cause 4: Firewall Blocking
**Problem:** Firewall blocking DPDK or web server

**Solution:**
```bash
# Check firewall
sudo ufw status

# Allow if needed
sudo ufw allow 8080/tcp
sudo ufw allow from 127.0.0.1
```

#### Cause 5: Engine Not Receiving Commands
**Problem:** Web server can't communicate with DPDK engine

**Solution:**
```bash
# Check if both processes are running
pgrep -a python.*server.py
pgrep -a dpdk_engine

# Check control socket permissions
ls -l /tmp/dpdk_engine_control.sock

# Should be readable/writable
sudo chmod 666 /tmp/dpdk_engine_control.sock
```

---

## Issue: Link Status Shows "Unknown"

### Solution:
Install lldpd for LLDP discovery:
```bash
sudo apt-get install lldpd
sudo systemctl enable lldpd
sudo systemctl start lldpd

# Wait 30 seconds for LLDP exchange
sleep 30

# Check neighbors
lldpctl
```

---

## Issue: No Connected Devices Shown

### Solution:
1. **For LLDP:** Ensure connected devices support LLDP
2. **For ARP:** Ensure interfaces have IP addresses assigned
3. **Check with:**
```bash
# LLDP neighbors
lldpctl

# ARP table
arp -n

# Interface IPs
ip addr show
```

---

## Issue: Performance Lower Than Expected

### Solution:
1. **Enable hardware offloads:**
```bash
sudo ethtool -K eno7 tx on rx on tso on gso on gro on
```

2. **Check CPU governor:**
```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Should be "performance"
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

3. **Isolate CPU cores:**
```bash
# Edit /etc/default/grub:
GRUB_CMDLINE_LINUX="isolcpus=2,3,4,5,6,7"

sudo update-grub
sudo reboot
```

4. **Check NUMA:**
```bash
numactl --hardware

# Verify NICs are on same NUMA node as memory
cat /sys/class/net/eno7/device/numa_node
```

---

## Issue: Build Errors

### Missing Dependencies:
```bash
sudo apt-get install -y \
    build-essential \
    libnuma-dev \
    libpcap-dev \
    libjson-c-dev \
    dpdk \
    dpdk-dev
```

### Clean Rebuild:
```bash
cd /opt/netgen-dpdk
make clean
rm -rf build
make
```

---

## Debug Mode

### Enable Verbose Logging:
```bash
# Edit service file
sudo systemctl edit netgen-pro-dpdk

# Add:
[Service]
Environment="DPDK_LOG_LEVEL=debug"

# Restart
sudo systemctl daemon-reload
sudo systemctl restart netgen-pro-dpdk

# Watch logs
sudo journalctl -u netgen-pro-dpdk -f
```

---

## Getting Help

If issues persist:

1. **Collect diagnostic info:**
```bash
cd /opt/netgen-dpdk
sudo bash scripts/diagnostics.sh > /tmp/diagnostics.log 2>&1
```

2. **Check documentation:**
- `README.md` - Overview
- `docs/INSTALLATION.md` - Setup guide
- `docs/VEP1445-CONFIG.md` - Hardware config
- `V4-QUICK-START-GUIDE.md` - v4.0 features

3. **Review logs:**
```bash
sudo journalctl -u netgen-pro-dpdk -n 200 > /tmp/service.log
```

4. **Create GitHub issue** with:
- Output of `diagnostics.sh`
- Service logs
- System info (`uname -a`, `lsb_release -a`)
- DPDK status (`dpdk-devbind.py --status`)
