# VEP1445 Multi-Port Deployment Architecture

## 🔌 Your Hardware Configuration

```
VEP1445 Lanner Network Appliance
├── eno1: Management (Linux kernel) - 1G
├── eno2: LAN1 Test Port (can be DPDK or Linux)
├── eno3: LAN2 Test Port (can be DPDK or Linux)
├── eno4: LAN3 Test Port (can be DPDK or Linux)
├── eno5: LAN4 Test Port (can be DPDK or Linux)
├── eno6: LAN5 Test Port (can be DPDK or Linux)
├── eno7: 10G TX Primary (DPDK)
└── eno8: 10G RX Primary (DPDK)
```

---

## 🎯 Deployment Scenarios Explained

### ❌ What DOESN'T Work: Static Split
```
Bad Idea:
eno7 → Always TX to Datacenter
eno8 → Moves around to receive

Problem:
- This is ONE-WAY traffic only
- Can't measure loopback latency
- Can't do RFC 2544 properly
- eno7 and eno8 never talk to each other
```

### ✅ What DOES Work: Loopback Pairs

You need to think in **TX/RX PAIRS** for loopback testing:

#### Option 1: Two-Port Loopback
```
Testing LAN1 ↔ LAN2 path:
┌─────────────────────────────────────────┐
│ VEP1445                                  │
│                                          │
│ eno2 (TX) → LAN1 → Your Network → LAN2 ← eno3 (RX) │
└─────────────────────────────────────────┘

Bind: eno2 to DPDK (TX), eno3 to DPDK (RX)
Test: Network path between LAN1 and LAN2
```

#### Option 2: High-Speed Loopback
```
Testing with 10G interfaces:
┌─────────────────────────────────────────┐
│ VEP1445                                  │
│                                          │
│ eno7 (TX) → LAN1 → Your Network → LAN2 ← eno8 (RX) │
└─────────────────────────────────────────┘

Bind: eno7 to DPDK (TX), eno8 to DPDK (RX)
Test: High-speed network path (up to 10 Gbps)
```

---

## 🌐 IP Addressing & DHCP

### The Problem with DPDK:
**When you bind an interface to DPDK, it leaves the Linux kernel.**

```
Before DPDK binding:
eno2 → Linux kernel → Can get DHCP → Has IP: 192.168.1.50

After DPDK binding:
eno2 → DPDK → NO Linux kernel → NO DHCP → NO IP!
```

### How DPDK Works:
```
DPDK doesn't need IP addresses for the bound interfaces!

Why?
- DPDK operates at Layer 2/3 manually
- You specify destination IPs in traffic profiles
- Source IPs are crafted into packets
- No routing table, no ARP, no DHCP
```

---

## 🔧 Recommended Configurations

### Configuration A: Management + 10G Loopback
```
Purpose: High-speed network testing with management access

Port Assignment:
├── eno1: Management (Linux, DHCP) - Access GUI/API
├── eno2-6: Available for future use (Linux, not bound)
├── eno7: DPDK TX (10 Gbps) → Connect to LAN1
└── eno8: DPDK RX (10 Gbps) → Connect to LAN2

Physical Setup:
eno1 → Management switch (for your laptop/PC access)
eno7 → LAN1 switch port
eno8 → LAN2 switch port

Traffic Flow:
eno7 generates → LAN1 → Your Network → LAN2 → eno8 receives

IP Strategy:
- eno1: Gets DHCP (e.g., 192.168.0.100) - for management
- eno7: No IP needed (DPDK, Layer 2)
- eno8: No IP needed (DPDK, Layer 2)
- Packet destinations: You specify in profiles (e.g., 192.168.1.100)

Configuration File:
{
  "management": {
    "interface": "eno1",
    "method": "dhcp"
  },
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

### Configuration B: Multi-Port Testing
```
Purpose: Test multiple LAN paths simultaneously

Port Assignment:
├── eno1: Management (Linux, DHCP)
├── eno2: DPDK TX Port 0 → LAN1
├── eno3: DPDK RX Port 0 → LAN1 (loopback)
├── eno4: DPDK TX Port 1 → LAN2
├── eno5: DPDK RX Port 1 → LAN2 (loopback)
├── eno6: DPDK TX Port 2 → LAN3
├── eno7: DPDK RX Port 2 → LAN3 (loopback)
└── eno8: Available or DPDK TX Port 3

Tests Running:
Test 1: eno2 (TX) → LAN1 → Network → LAN1 → eno3 (RX)
Test 2: eno4 (TX) → LAN2 → Network → LAN2 → eno5 (RX)
Test 3: eno6 (TX) → LAN3 → Network → LAN3 → eno7 (RX)

This tests 3 LANs SIMULTANEOUSLY!
```

### Configuration C: Inter-LAN Testing
```
Purpose: Test traffic BETWEEN different LANs

Example 1: LAN1 → LAN2 path
eno2 (TX) → LAN1 → Network → LAN2 → eno3 (RX)

Example 2: LAN1 → LAN3 path
eno4 (TX) → LAN1 → Network → LAN3 → eno5 (RX)

Example 3: LAN2 → LAN3 path
eno6 (TX) → LAN2 → Network → LAN3 → eno7 (RX)

This measures inter-VLAN or inter-subnet performance!
```

---

## 📋 IP Address Strategy

### Option 1: DPDK Doesn't Use IPs (Recommended)
```
How it works:
1. Bind eno7, eno8 to DPDK (no IPs)
2. Generate packets with ANY source/dest IP you want
3. Network switches route based on MAC/IP in packets
4. Measure performance

Example Traffic Profile:
{
  "name": "Test-LAN1-to-LAN2",
  "src_ip": "192.168.1.50",      ← Fake source (doesn't need to exist)
  "dst_ip": "192.168.2.100",     ← Real destination (needs to exist OR doesn't matter for loopback)
  "src_mac": "00:11:22:33:44:55", ← VEP1445 interface MAC
  "dst_mac": "00:AA:BB:CC:DD:EE", ← Destination MAC (or broadcast)
}

The packets flow based on Layer 2/3 headers you craft!
```

### Option 2: Hybrid (Management + DPDK)
```
Interfaces:
├── eno1: Linux + DHCP → 192.168.0.100 (management)
├── eno7: DPDK → No IP (TX)
└── eno8: DPDK → No IP (RX)

Access VEP1445:
From your laptop: http://192.168.0.100:8080

Generate Traffic:
Packets from eno7 use whatever IPs you specify in profiles
```

### Option 3: All Linux (Not Recommended, Low Performance)
```
All interfaces in Linux kernel:
├── eno1: 192.168.0.100 (management)
├── eno2: 192.168.1.10 (LAN1)
├── eno3: 192.168.2.10 (LAN2)
├── eno7: 10.0.1.10 (LAN1-HighSpeed)
└── eno8: 10.0.2.10 (LAN2-HighSpeed)

Limitations:
- Only 2-5 Gbps (not 10+ Gbps)
- Higher CPU usage
- Can't do hardware timestamping
- No RFC 2544 precision

Use only for simple testing!
```

---

## 🔧 Configuration Scripts

### Script 1: Configure Management + 10G Loopback
```bash
#!/bin/bash
# configure-vep1445-basic.sh

echo "VEP1445 Basic Configuration"
echo "==========================="

# 1. Management interface (Linux, DHCP)
echo "Configuring eno1 (management)..."
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: true
      dhcp6: false
EOF
netplan apply

# 2. Get management IP
MGMT_IP=$(ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "Management IP: $MGMT_IP"

# 3. Bind DPDK interfaces
echo "Binding eno7 (TX) and eno8 (RX) to DPDK..."
ENO7_PCI=$(ethtool -i eno7 | grep bus-info | awk '{print $2}')
ENO8_PCI=$(ethtool -i eno8 | grep bus-info | awk '{print $2}')

ip link set eno7 down
ip link set eno8 down

dpdk-devbind.py --bind=vfio-pci $ENO7_PCI
dpdk-devbind.py --bind=vfio-pci $ENO8_PCI

# 4. Create config file
cat > /opt/netgen-pro-complete/vep1445-config.json << EOF
{
  "deployment": "basic-loopback",
  "management": {
    "interface": "eno1",
    "ip": "$MGMT_IP"
  },
  "dpdk": {
    "tx_port": {
      "interface": "eno7",
      "pci": "$ENO7_PCI",
      "port_id": 0,
      "description": "10G TX - Connect to LAN1"
    },
    "rx_port": {
      "interface": "eno8",
      "pci": "$ENO8_PCI",
      "port_id": 1,
      "description": "10G RX - Connect to LAN2"
    }
  }
}
EOF

echo ""
echo "✅ Configuration Complete!"
echo ""
echo "Access NetGen Pro at: http://$MGMT_IP:8080"
echo ""
echo "Physical connections needed:"
echo "  • eno1 → Management switch"
echo "  • eno7 → LAN1 switch port"
echo "  • eno8 → LAN2 switch port"
echo ""
```

### Script 2: Multi-Port Configuration
```bash
#!/bin/bash
# configure-vep1445-multiport.sh

echo "VEP1445 Multi-Port Configuration"
echo "================================"

# Management
netplan apply

# Bind multiple pairs
PORTS=(
  "eno2:eno3"  # Pair 1: LAN1 loopback
  "eno4:eno5"  # Pair 2: LAN2 loopback
  "eno6:eno7"  # Pair 3: LAN3 loopback
)

for i in "${!PORTS[@]}"; do
  IFS=':' read -r TX RX <<< "${PORTS[$i]}"
  
  TX_PCI=$(ethtool -i $TX | grep bus-info | awk '{print $2}')
  RX_PCI=$(ethtool -i $RX | grep bus-info | awk '{print $2}')
  
  echo "Binding pair $((i+1)): $TX (TX) + $RX (RX)"
  
  ip link set $TX down
  ip link set $RX down
  
  dpdk-devbind.py --bind=vfio-pci $TX_PCI
  dpdk-devbind.py --bind=vfio-pci $RX_PCI
done

echo "✅ Multi-port configuration complete!"
echo ""
echo "You can now test 3 LANs simultaneously"
```

---

## 🎯 Usage Examples

### Example 1: Basic Loopback Test
```bash
# Physical setup:
# eno7 → LAN1 port 1
# eno8 → LAN1 port 2
# (Both ports on same VLAN/subnet)

# Configure
sudo bash configure-vep1445-basic.sh

# Access GUI
http://192.168.0.100:8080

# Run RFC 2544 Throughput Test
curl -X POST http://192.168.0.100:8080/api/rfc2544/throughput \
  -d '{
    "duration": 60,
    "frame_size": 1518,
    "loss_threshold": 0.01
  }'

# Results show:
# - Max throughput of YOUR network path
# - Latency through YOUR network
# - Packet loss on YOUR network
```

### Example 2: Inter-LAN Test
```bash
# Physical setup:
# eno7 → LAN1 (VLAN 10, subnet 192.168.10.0/24)
# eno8 → LAN2 (VLAN 20, subnet 192.168.20.0/24)

# Generate traffic
curl -X POST http://192.168.0.100:8080/api/start \
  -d '{
    "profiles": [{
      "name": "LAN1-to-LAN2",
      "src_ip": "192.168.10.50",
      "dst_ip": "192.168.20.100",
      "protocol": "udp",
      "rate_mbps": 1000
    }]
  }'

# This tests:
# - Inter-VLAN routing performance
# - Firewall throughput (if between LANs)
# - Router performance
```

### Example 3: Multiple Simultaneous Tests
```bash
# Test 3 LANs at once
# Pair 1: eno2 (TX) → LAN1 → eno3 (RX)
# Pair 2: eno4 (TX) → LAN2 → eno5 (RX)
# Pair 3: eno6 (TX) → LAN3 → eno7 (RX)

# Each pair runs independent RFC 2544 test
# Measures network performance under multi-path load
```

---

## 🌐 DHCP & IP Address Details

### Q: Do DPDK interfaces need IPs from DHCP?
**A: No!** DPDK bypasses the Linux network stack entirely.

### Q: How do packets know where to go?
**A:** You specify everything in the packet headers:
```python
Ethernet Header:
  src_mac: 00:11:22:33:44:55  # eno7's MAC
  dst_mac: 00:AA:BB:CC:DD:EE  # Next hop MAC (learned or static)

IP Header:
  src_ip: 192.168.1.50   # Can be anything (even fake)
  dst_ip: 192.168.2.100  # Where you want traffic to go

UDP/TCP Header:
  src_port: 5000
  dst_port: 5000
```

### Q: What if devices expect DHCP?
**A:** For receiving devices (not VEP1445):
```
Scenario: Testing traffic to a device that needs IP

Option 1: Device has static IP
  Device: 192.168.1.100 (static)
  VEP1445 sends to: 192.168.1.100
  ✓ Works!

Option 2: Device uses DHCP
  Device gets DHCP: 192.168.1.50
  VEP1445 sends to: 192.168.1.50
  ✓ Works! (You just need to know the IP)

Option 3: Broadcast traffic
  VEP1445 sends to: 255.255.255.255
  ✓ All devices receive!
```

### Q: Can LANs talk to each other?
**A:** Depends on your network:
```
If you have inter-VLAN routing:
  LAN1 (VLAN 10) → Router → LAN2 (VLAN 20)
  ✓ eno7 (LAN1) can reach eno8 (LAN2)

If LANs are isolated:
  LAN1 (VLAN 10) ← Firewall → LAN2 (VLAN 20)
  ✓ Traffic blocked (by design)
  
You're testing this isolation/routing!
```

---

## 💡 Recommended Deployment

### For Your VEP1445:
```
Configuration: Management + Single 10G Loopback

Interfaces:
├── eno1: Management (Linux, DHCP) → 192.168.0.100
├── eno2-6: Reserved (not bound, available)
├── eno7: DPDK TX (10G) → LAN1 port
└── eno8: DPDK RX (10G) → LAN2 port

Physical Setup:
┌────────────────────────────────────────────┐
│ Your Laptop                                │
│   ↓ (management)                          │
│ eno1 → Management Switch                  │
│                                            │
│ eno7 → LAN1 ──┐                           │
│                │                           │
│           Your Network                     │
│                │                           │
│ eno8 ← LAN2 ──┘                           │
└────────────────────────────────────────────┘

Testing:
1. Generate traffic from eno7 (TX)
2. Traffic flows through YOUR network
3. Measure on eno8 (RX)
4. Get latency, throughput, loss metrics

Access:
- GUI: http://192.168.0.100:8080
- API: http://192.168.0.100:8080/api/*
- No IP needed on eno7/eno8!
```

---

## 📊 Traffic Flow Diagram

### With IP Addressing:
```
Step 1: Packet Generation (eno7)
┌─────────────────────────────────────┐
│ Ethernet: src=eno7_mac              │
│           dst=lan1_gateway_mac      │
│ IP:       src=192.168.1.99 (fake)   │
│           dst=192.168.2.100         │
│ UDP:      src=5000 dst=5000         │
│ Payload:  Test data + timestamp     │
└─────────────────────────────────────┘

Step 2: Network Path
eno7 → LAN1 Switch → Router → LAN2 Switch → eno8

Step 3: Packet Reception (eno8)
┌─────────────────────────────────────┐
│ Extract timestamp                   │
│ Calculate latency                   │
│ Track sequence number               │
│ Update statistics                   │
└─────────────────────────────────────┘
```

---

## ✅ Summary

### Your Questions Answered:

**Q: Does eno7 stay in DC while eno8 moves?**
**A:** No! Both should be in the same test location for loopback testing.

**Q: How do 5 LANs communicate?**
**A:** They communicate through YOUR network infrastructure (routers, switches). You're testing that communication!

**Q: How do IPs work with DPDK?**
**A:** DPDK interfaces don't need IPs. You craft packet headers manually. Management interface (eno1) gets DHCP for GUI access.

**Q: Can each LAN talk to each other?**
**A:** Depends on your network config. You can test:
- Same LAN (loopback)
- Different LANs (inter-VLAN routing)
- Isolated LANs (firewall testing)

### Best Practice:
```
1. Keep eno1 for management (Linux + DHCP)
2. Use eno7 + eno8 as primary TX/RX pair (10G)
3. Keep eno2-6 available for future expansion
4. Place VEP1445 in test location
5. Connect TX/RX to different network paths
6. Measure YOUR network performance
```

**Your VEP1445 is now a portable network performance measurement tool!** 🎯
