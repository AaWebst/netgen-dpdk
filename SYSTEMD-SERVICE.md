# NetGen Pro - DPDK Edition - Systemd Service Guide

## 🚀 Quick Setup

### Install Service (One Time)
```bash
cd /opt/netgen-dpdk
sudo bash install-service.sh
```

That's it! NetGen Pro will now:
- ✅ Start automatically on boot
- ✅ Restart if it crashes
- ✅ Run as a system service
- ✅ Integrate with systemd logging

---

## 📋 Service Management Commands

### Start Service
```bash
sudo systemctl start netgen-pro-dpdk
```

### Stop Service
```bash
sudo systemctl stop netgen-pro-dpdk
```

### Restart Service
```bash
sudo systemctl restart netgen-pro-dpdk
```

### Check Status
```bash
sudo systemctl status netgen-pro-dpdk
```

### Enable Auto-Start (on boot)
```bash
sudo systemctl enable netgen-pro-dpdk
```

### Disable Auto-Start
```bash
sudo systemctl disable netgen-pro-dpdk
```

---

## 📊 Monitoring

### View Live Logs
```bash
# Follow logs in real-time
sudo journalctl -u netgen-pro-dpdk -f

# Last 50 lines
sudo journalctl -u netgen-pro-dpdk -n 50

# Last 100 lines
sudo journalctl -u netgen-pro-dpdk -n 100

# Since today
sudo journalctl -u netgen-pro-dpdk --since today

# Since specific time
sudo journalctl -u netgen-pro-dpdk --since "2024-01-12 10:00:00"
```

### Check if Running
```bash
systemctl is-active netgen-pro-dpdk
# Returns: active or inactive

systemctl is-enabled netgen-pro-dpdk
# Returns: enabled or disabled
```

### Performance Stats
```bash
# CPU and memory usage
systemctl status netgen-pro-dpdk | grep -A 5 "Memory\|CPU"

# Or use top
top -p $(pgrep -f dpdk_control_server)
```

---

## 🔧 What the Service Does

### On Start
1. ✅ Mounts hugepages (`/mnt/huge`)
2. ✅ Allocates 1024 hugepages
3. ✅ Loads kernel modules (`uio`, `vfio-pci`)
4. ✅ Starts Python web control server
5. ✅ Web control server manages DPDK engine

### On Stop
1. ✅ Stops DPDK engine gracefully
2. ✅ Stops web control server
3. ✅ Cleans up control socket

### Auto-Restart
- If service crashes, systemd restarts it after 10 seconds
- Useful for reliability in production

---

## 🎯 Service Configuration

### Service File Location
```
/etc/systemd/system/netgen-pro-dpdk.service
```

### View Service Configuration
```bash
cat /etc/systemd/system/netgen-pro-dpdk.service
```

### Edit Service Configuration
```bash
sudo systemctl edit --full netgen-pro-dpdk

# After editing, reload:
sudo systemctl daemon-reload
sudo systemctl restart netgen-pro-dpdk
```

---

## 🔍 Troubleshooting

### Service Won't Start

**Check status:**
```bash
sudo systemctl status netgen-pro-dpdk
```

**Check logs:**
```bash
sudo journalctl -u netgen-pro-dpdk -n 50 --no-pager
```

**Common issues:**

1. **Virtual environment missing**
   ```bash
   cd /opt/netgen-dpdk
   sudo bash quick-setup-venv.sh
   sudo systemctl restart netgen-pro-dpdk
   ```

2. **DPDK engine not built**
   ```bash
   cd /opt/netgen-dpdk
   make clean && make
   sudo systemctl restart netgen-pro-dpdk
   ```

3. **Hugepages not allocated**
   ```bash
   echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
   sudo systemctl restart netgen-pro-dpdk
   ```

4. **Port 8080 already in use**
   ```bash
   sudo lsof -i :8080
   # Kill the conflicting process or change port in dpdk_control_server.py
   ```

### Service Keeps Restarting

**Check why it's failing:**
```bash
sudo journalctl -u netgen-pro-dpdk --since "5 minutes ago"
```

**Disable auto-restart temporarily:**
```bash
sudo systemctl stop netgen-pro-dpdk
# Fix the issue
sudo systemctl start netgen-pro-dpdk
```

### View Detailed Status
```bash
systemctl status netgen-pro-dpdk --no-pager -l
```

---

## 📝 Manual Control vs Service

### Use Manual Start (`./start.sh`) When:
- ✅ Testing or development
- ✅ Running one-time tests
- ✅ Need to see output directly
- ✅ Troubleshooting issues

### Use Systemd Service When:
- ✅ Production deployment
- ✅ Want auto-start on boot
- ✅ Need automatic restart on crash
- ✅ Want centralized logging
- ✅ Running 24/7

---

## 🔄 Switching Between Manual and Service

### Stop Service, Start Manually
```bash
sudo systemctl stop netgen-pro-dpdk
cd /opt/netgen-dpdk
sudo ./start.sh
```

### Stop Manual, Start Service
```bash
# Press Ctrl+C to stop manual instance
sudo systemctl start netgen-pro-dpdk
```

**⚠️ WARNING:** Don't run both at the same time!

---

## 🔐 Security Considerations

The service runs as **root** because:
- DPDK requires raw hardware access
- Hugepages management needs privileges
- Network interface binding needs root

### Reduce Security Risk:
1. Firewall port 8080 (allow only trusted IPs)
2. Use nginx reverse proxy with authentication
3. Run on isolated management network
4. Monitor logs regularly

---

## 🎨 Customization

### Change Port

Edit `/opt/netgen-dpdk/web/dpdk_control_server.py`:
```python
# Line near bottom, change:
socketio.run(app, host='0.0.0.0', port=8080, debug=False)
# To:
socketio.run(app, host='0.0.0.0', port=8081, debug=False)
```

Then restart:
```bash
sudo systemctl restart netgen-pro-dpdk
```

### Change Restart Behavior

Edit service file:
```bash
sudo systemctl edit --full netgen-pro-dpdk
```

Change:
```ini
Restart=always
RestartSec=10
```

To:
```ini
Restart=on-failure
RestartSec=30
```

Reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart netgen-pro-dpdk
```

### Add Environment Variables

Edit service file:
```bash
sudo systemctl edit --full netgen-pro-dpdk
```

Add in `[Service]` section:
```ini
Environment="COORDINATOR_URL=http://coordinator:5000"
Environment="INSTANCE_ID=site1"
```

---

## 📊 Monitoring Examples

### Create Monitoring Script

```bash
cat > /opt/netgen-dpdk/monitor.sh << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "NetGen Pro - DPDK Edition - Service Monitor"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Service status
    echo "Status: $(systemctl is-active netgen-pro-dpdk)"
    echo "Uptime: $(systemctl show netgen-pro-dpdk --property=ActiveEnterTimestamp --value | cut -d' ' -f1-2)"
    echo ""
    
    # Memory usage
    echo "Memory Usage:"
    systemctl status netgen-pro-dpdk | grep Memory || echo "  N/A"
    echo ""
    
    # CPU usage
    echo "CPU Usage:"
    top -b -n 1 -p $(pgrep -f dpdk_control_server) | tail -1 || echo "  N/A"
    echo ""
    
    # Recent logs
    echo "Recent Logs (last 5 lines):"
    journalctl -u netgen-pro-dpdk -n 5 --no-pager
    
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
EOF

chmod +x /opt/netgen-dpdk/monitor.sh
```

Run it:
```bash
/opt/netgen-dpdk/monitor.sh
```

### Check Web UI Availability

```bash
curl -s http://localhost:8080/api/status | python3 -m json.tool
```

### Create Alert Script

```bash
cat > /opt/netgen-dpdk/check-service.sh << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet netgen-pro-dpdk; then
    echo "❌ NetGen Pro service is DOWN!"
    journalctl -u netgen-pro-dpdk -n 20 --no-pager
    exit 1
else
    echo "✅ NetGen Pro service is running"
    exit 0
fi
EOF

chmod +x /opt/netgen-dpdk/check-service.sh
```

Add to cron for monitoring:
```bash
# Check every 5 minutes
*/5 * * * * /opt/netgen-dpdk/check-service.sh
```

---

## 🎯 Complete Setup Example

```bash
# 1. Install NetGen Pro
cd /opt
sudo tar xzf netgen-pro-dpdk-v2.0-FINAL.tar.gz
cd netgen-dpdk

# 2. Run full installation
sudo bash scripts/install.sh

# 3. Bind network interface
sudo dpdk-devbind.py --bind=vfio-pci 02:01.0

# 4. Install systemd service
sudo bash install-service.sh

# 5. Check status
sudo systemctl status netgen-pro-dpdk

# 6. View logs
sudo journalctl -u netgen-pro-dpdk -f

# 7. Access web UI
# http://localhost:8080
```

---

## 🎉 Benefits of Using Systemd Service

| Benefit | Description |
|---------|-------------|
| **Auto-Start** | Starts on boot automatically |
| **Auto-Restart** | Restarts if crashed (10s delay) |
| **Centralized Logs** | All logs in journald |
| **Easy Management** | Standard systemctl commands |
| **Monitoring** | Built-in status checking |
| **Reliability** | Production-grade service management |
| **No Manual Start** | No need to SSH and start manually |
| **Dependency Management** | Waits for network before starting |

---

## 🚀 Quick Reference Card

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

# Disable auto-start
sudo systemctl disable netgen-pro-dpdk

# Restart
sudo systemctl restart netgen-pro-dpdk

# Access
http://localhost:8080
```

---

## 📞 Getting Help

If service won't start:
1. Check logs: `sudo journalctl -u netgen-pro-dpdk -n 50`
2. Check status: `sudo systemctl status netgen-pro-dpdk`
3. Verify venv: `ls -la /opt/netgen-dpdk/venv`
4. Verify engine: `ls -la /opt/netgen-dpdk/build/dpdk_engine`
5. Check hugepages: `cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages`

---

**NetGen Pro is now a production-grade system service!** 🎉
