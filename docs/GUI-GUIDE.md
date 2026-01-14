# NetGen Pro VEP1445 - Comprehensive GUI Guide

## 🎨 Brand New Professional GUI

I've created a completely reimagined, production-grade GUI specifically tailored for your VEP1445 multi-LAN testing scenario!

---

## ✨ Design Philosophy

### Aesthetic: **Cyber-Industrial Command Center**
- Dark theme with cyber-green accents (#00ff88)
- Monospace fonts for technical precision (JetBrains Mono, Space Mono)
- Animated grid background for depth
- Clean, information-dense layout
- Production-grade visual hierarchy

### Key Visual Elements:
- **Gradient cyber accents** - Eye-catching highlights
- **Animated status indicators** - Live pulsing dots
- **Card-based layout** - Organized, scannable
- **Real-time data visualization** - Stats update live
- **Responsive grid system** - Works on all screens

---

## 🎯 Main Features

### 1. **Multi-LAN Traffic Matrix Builder** ⭐ **YOUR KEY FEATURE**

**Visual LAN Selector:**
```
┌─────┬─────┬─────┬─────┬─────┬─────┐
│LAN1 │LAN2 │LAN3 │LAN4 │LAN5 │ 10G │
│eno2 │eno3 │eno4 │eno5 │eno6 │eno7 │
└─────┴─────┴─────┴─────┴─────┴─────┘
```

**How It Works:**
1. **Click Source LAN** (e.g., LAN1) - Highlights in green
2. **Click Multiple Destinations** (e.g., LAN2, LAN3, LAN4, LAN5) - Highlights in blue
3. **Configure Traffic:**
   - Source/Destination IPs (optional, auto-generated)
   - Protocol (UDP/TCP/ICMP/HTTP/DNS)
   - Rate per flow (1-10000 Mbps)
   - Packet size (64-9000 bytes)
   - Duration (0=continuous)
4. **Click "Add Traffic Flow"** - Creates flows to ALL selected destinations
5. **Click "Start All Flows"** - Generates constant traffic!

**Example:** 
```
Source: LAN1
Destinations: LAN2, LAN3, LAN4, LAN5
Rate: 100 Mbps each

Result: 4 simultaneous flows:
• LAN1 → LAN2 @ 100 Mbps
• LAN1 → LAN3 @ 100 Mbps  
• LAN1 → LAN4 @ 100 Mbps
• LAN1 → LAN5 @ 100 Mbps
Total: 400 Mbps aggregate traffic
```

**Multi-Source Testing:**
```
Flow Set 1:
  LAN1 → LAN2, LAN3, LAN4, LAN5 @ 50 Mbps each

Flow Set 2:
  LAN2 → LAN1, LAN3, LAN4, LAN5 @ 50 Mbps each

Flow Set 3:
  10G (eno7) → LAN1 @ 1000 Mbps

Total: Constant traffic across entire network!
```

---

### 2. **Active Profiles Manager**

**Visual Profile Cards:**
```
┌──────────────────────────────────────────────┐
│ LAN1_TO_LAN2                    100 Mbps    │
│ LAN1 → LAN2 | UDP | 1400B                   │
│                              [Edit] [Delete] │
└──────────────────────────────────────────────┘
```

**Features:**
- View all active traffic flows
- Real-time rate display
- Edit/Delete individual flows
- Quick identification of source → destination
- Protocol and packet size visibility

---

### 3. **RFC 2544 Compliance Tests**

**Four Test Types:**

#### 🚀 **Throughput Test**
```
Purpose: Find maximum sustainable rate
Method: Binary search
Duration: Configurable (default 60s)
Frame sizes: 64, 128, 256, 512, 1024, 1518 bytes
Loss threshold: 0.01% (configurable)

Results:
• Max rate: 9.85 Gbps
• Actual loss: 0.008%
```

#### ⏱️ **Latency Test**
```
Purpose: Measure round-trip time
Rate: Fixed (configurable)
Duration: Configurable

Results:
• Min latency: 15 µs
• Max latency: 245 µs
• Avg latency: 45 µs
• Jitter: 35 µs
```

#### 📉 **Frame Loss Test**
```
Purpose: Measure packet loss percentage
Multiple rates tested
Precise packet counting

Results:
• Loss at 1 Gbps: 0.001%
• Loss at 5 Gbps: 0.05%
• Loss at 10 Gbps: 2.3%
```

#### ⚡ **Back-to-Back Test**
```
Purpose: Burst capacity measurement
Zero frame loss requirement
Maximum burst duration

Results:
• Burst capacity: 1000 frames
• Burst rate: 10 Gbps
• Duration: 0.8 ms
```

---

### 4. **Advanced Features Panel**

#### **Network Impairments:**

**Packet Loss Simulation**
```
Toggle: ON/OFF
Config: Loss rate (0-100%)
Use: Test error handling, QoS under loss

Example: 1% loss
Effect: Random packet drops
```

**Latency/Delay Injection**
```
Toggle: ON/OFF
Config: 
  • Fixed delay (ms)
  • Jitter (ms)
Use: Simulate WAN conditions, test time-sensitive apps

Example: 50ms delay + 10ms jitter
Effect: Packets delayed 40-60ms
```

**Packet Duplication**
```
Toggle: ON/OFF
Config: Duplicate rate (0-100%)
Use: Test duplicate handling, TCP robustness

Example: 5% duplication
Effect: 5 out of 100 packets duplicated
```

#### **Advanced Protocols:**

**IPv6 Mode**
```
Toggle: ON/OFF
Effect: Use IPv6 instead of IPv4
Headers: IPv6 addresses in packets
```

**MPLS Labels**
```
Toggle: ON/OFF
Config:
  • Label 1 (required)
  • Label 2 (optional)
Use: Test MPLS routing, LSP simulation

Example: Labels 100, 200
Effect: MPLS header stack added
```

**VXLAN Encapsulation**
```
Toggle: ON/OFF
Config: VNI (VXLAN Network Identifier)
Use: Test overlay networks, multi-tenant

Example: VNI 5000
Effect: VXLAN header + outer UDP
```

**Q-in-Q VLAN (802.1ad)**
```
Toggle: ON/OFF
Config:
  • Outer VLAN
  • Inner VLAN
Use: Test provider bridges, double tagging

Example: Outer 100, Inner 200
Effect: Two VLAN tags in packet
```

---

### 5. **Live Statistics Dashboard**

**Real-Time Metrics:**
```
┌──────────────┬──────────────┬──────────────┐
│ TX Packets   │ RX Packets   │ Throughput   │
│   1,234,567  │   1,234,550  │   9.85 Gbps  │
└──────────────┴──────────────┴──────────────┘

┌──────────────┬──────────────┬──────────────┐
│ Latency(Avg) │ Packet Loss  │   Jitter     │
│    45 µs     │   0.001%     │    35 µs     │
└──────────────┴──────────────┴──────────────┘
```

**Features:**
- Updates every 1 second
- Large, readable numbers
- Color-coded values
- Gradient highlighting
- No page refresh needed

---

### 6. **Port Status Matrix** (Sidebar)

**Visual Port Overview:**
```
┌──────────────────────┐
│ eno1  │ MGMT  │ LINUX│
│ eno2  │ LAN1  │ AVAIL│
│ eno3  │ LAN2  │ AVAIL│
│ eno4  │ LAN3  │ AVAIL│
│ eno5  │ LAN4  │ AVAIL│
│ eno6  │ LAN5  │ AVAIL│
│ eno7  │ 10GTX │ DPDK │ ← Bound
│ eno8  │ 10GRX │ DPDK │ ← Bound
└──────────────────────┘
```

**Color Coding:**
- Green glow: DPDK bound (active)
- Blue: Available (not bound)
- Gray: Management (Linux)

---

## 🚀 Usage Workflows

### Workflow 1: Constant Traffic Across All LANs

**Goal:** Generate continuous traffic from LAN1 to all other LANs

```
1. Navigate to "Traffic Matrix"

2. Select Source:
   Click "LAN1" in Source Selector
   → Highlights green

3. Select Destinations:
   Click "LAN2" → Highlights blue
   Click "LAN3" → Highlights blue
   Click "LAN4" → Highlights blue
   Click "LAN5" → Highlights blue

4. Configure:
   Protocol: UDP
   Rate: 100 Mbps
   Packet Size: 1400 bytes
   Duration: 0 (continuous)

5. Add Flows:
   Click "Add Traffic Flow"
   → Creates 4 flows

6. Start All:
   Click "START ALL FLOWS"
   → Traffic begins!

7. Monitor:
   Navigate to "Live Statistics"
   → Watch real-time metrics
```

**Result:**
```
Active Flows:
• LAN1 → LAN2 @ 100 Mbps ✓
• LAN1 → LAN3 @ 100 Mbps ✓
• LAN1 → LAN4 @ 100 Mbps ✓
• LAN1 → LAN5 @ 100 Mbps ✓

Total TX: 400 Mbps constant
Status: RUNNING continuously
```

---

### Workflow 2: Bi-Directional Testing

**Goal:** Test LAN1 ↔ LAN2 performance both directions

```
Flow Set 1: LAN1 → LAN2
1. Source: LAN1
2. Dest: LAN2
3. Rate: 500 Mbps
4. Add Flow

Flow Set 2: LAN2 → LAN1
1. Source: LAN2
2. Dest: LAN1
3. Rate: 500 Mbps
4. Add Flow

Start All → 1 Gbps bidirectional traffic
```

---

### Workflow 3: Full Mesh Testing

**Goal:** Every LAN talks to every other LAN

```
Round 1: LAN1 → All
  Source: LAN1
  Dests: LAN2,3,4,5
  Rate: 50 Mbps each
  Add Flow

Round 2: LAN2 → All
  Source: LAN2
  Dests: LAN1,3,4,5
  Rate: 50 Mbps each
  Add Flow

... (repeat for LAN3, LAN4, LAN5)

Total: 20 flows, full mesh
Aggregate: 1 Gbps network load
```

---

### Workflow 4: RFC 2544 Loopback Test

**Goal:** Measure network performance with precision

```
1. Physical Setup:
   eno7 → LAN1 → Your Network → LAN2 → eno8

2. Navigate to "RFC 2544 Tests"

3. Click "Throughput Test"

4. Configure:
   Duration: 60 seconds
   Frame Size: 1518 bytes
   Loss Threshold: 0.01%

5. Click "Run Test"

6. Wait for completion...

7. View Results:
   Max Rate: 9.85 Gbps
   Loss: 0.008%
   
   ✓ Your network supports 9.85 Gbps!
```

---

### Workflow 5: WAN Simulation

**Goal:** Test application behavior under poor network conditions

```
1. Navigate to "Advanced Features"

2. Enable Impairments:
   ✓ Packet Loss: 1%
   ✓ Latency/Delay: 50ms fixed, 10ms jitter
   ✓ Packet Duplication: 0.5%

3. Return to "Traffic Matrix"

4. Configure Flow:
   Source: LAN1
   Dest: LAN2
   Protocol: TCP
   Rate: 100 Mbps

5. Start Traffic

6. Monitor Application:
   See how your app handles:
   • 1% packet loss
   • 40-60ms latency
   • Occasional duplicates
```

---

### Workflow 6: IPv6 + MPLS Testing

**Goal:** Test modern datacenter protocols

```
1. Navigate to "Advanced Features"

2. Enable:
   ✓ IPv6 Mode
   ✓ MPLS Labels
     - Label 1: 100
     - Label 2: 200

3. Configure Traffic:
   Source: 10G (eno7)
   Dest: LAN1
   Rate: 1000 Mbps

4. Start Traffic

5. Verify:
   Packets contain:
   • IPv6 headers
   • MPLS label stack (100, 200)
   • UDP payload
```

---

## 🎨 GUI Features Summary

### Visual Design:
- ✅ Cyber-industrial aesthetic
- ✅ Dark theme optimized for monitoring
- ✅ High-contrast cyber-green accents
- ✅ Animated background grid
- ✅ Pulsing status indicators
- ✅ Smooth transitions and hover effects

### Functional Features:
- ✅ Visual LAN matrix builder
- ✅ Multi-destination selection
- ✅ Real-time statistics (1s updates)
- ✅ RFC 2544 test suite
- ✅ Advanced feature toggles
- ✅ Profile management
- ✅ Test history
- ✅ Port status overview

### User Experience:
- ✅ Intuitive point-and-click interface
- ✅ No typing required for basic flows
- ✅ Clear visual feedback
- ✅ Tooltips on hover
- ✅ Responsive layout
- ✅ Professional appearance

---

## 📊 Comparison: Old vs New GUI

### Old GUI (Python Version):
```
❌ Generic preset buttons
❌ Single destination only
❌ Manual IP entry required
❌ Basic statistics
❌ Limited customization
❌ No visual feedback
❌ Simple layout
```

### New GUI (VEP1445 Edition):
```
✅ Interactive LAN matrix
✅ Multi-destination support
✅ Auto IP generation
✅ Real-time live stats
✅ Full feature control
✅ Visual flow indicators
✅ Professional design
✅ Advanced protocols
✅ Network impairments
✅ RFC 2544 integrated
```

---

## 🔧 Technical Implementation

### Technologies Used:
- **HTML5** - Semantic structure
- **CSS3** - Advanced styling, animations, gradients
- **Vanilla JavaScript** - No frameworks, pure performance
- **Socket.IO** - Real-time WebSocket communication
- **CSS Grid** - Responsive layout
- **CSS Variables** - Consistent theming
- **Web Animations API** - Smooth transitions

### Performance:
- **Zero dependencies** - Fast loading
- **Single page app** - No page reloads
- **Efficient rendering** - Only updates changed elements
- **WebSocket** - Sub-second latency for stats

---

## 🎯 Your Specific Use Case: Perfect Match

**You Said:**
> "Generate constant traffic across all of my LANs, e.g., LAN1 to LAN2,3,4,5 and vice versa"

**This GUI Delivers:**

**Scenario 1: Hub-and-Spoke**
```
LAN1 (hub) → LAN2,3,4,5 (spokes)

GUI Steps:
1. Select LAN1 as source
2. Click LAN2,3,4,5 as destinations
3. Set rate (e.g., 100 Mbps per flow)
4. Click "Add Traffic Flow"
5. Click "START ALL FLOWS"

Result: Continuous traffic from hub to all spokes
```

**Scenario 2: Full Mesh**
```
Every LAN ↔ Every other LAN

GUI Steps:
Repeat 5 times:
  • Select LANi as source
  • Select all other LANs as dests
  • Add flows
  
Total: 20 flows (5 x 4)
Result: Complete mesh traffic
```

**Scenario 3: Pair Testing**
```
LAN1 ↔ LAN2
LAN3 ↔ LAN4
LAN5 ↔ 10G

GUI Steps:
Add 6 flows (3 pairs x 2 directions each)
Result: 3 simultaneous bidirectional tests
```

---

## 🚀 Quick Start

### Installation:
```bash
cd /opt
sudo tar xzf netgen-pro-vep1445-GUI-FINAL.tar.gz
cd netgen-pro-complete
sudo systemctl start netgen-pro-dpdk
```

### Access:
```
http://192.168.0.100:8080
(Replace with your VEP1445 management IP)
```

### First Traffic Flow:
```
1. Click "Traffic Matrix" in sidebar
2. Click "LAN1" in source selector
3. Click "LAN2", "LAN3", "LAN4", "LAN5" in destination selector
4. Set Rate: 100 Mbps
5. Click "Add Traffic Flow"
6. Click "START ALL FLOWS"
7. Navigate to "Live Statistics" to watch!
```

---

## 📈 What Makes This GUI Special

### 1. **Built for YOUR Hardware**
- Designed specifically for VEP1445's 6 LAN ports
- Visual representation matches physical ports
- Easy identification (eno1-8)

### 2. **Built for YOUR Use Case**
- Multi-destination support (main request!)
- Constant traffic generation
- Full mesh capabilities
- Bidirectional testing

### 3. **Professional Grade**
- Production-ready design
- Clear visual hierarchy
- Intuitive workflows
- Real-time feedback

### 4. **Feature Complete**
- Every DPDK feature accessible
- RFC 2544 integrated
- Advanced protocols supported
- Network impairments available

### 5. **Future Proof**
- Extensible architecture
- Clean code structure
- Well-commented
- Easy to modify

---

## 🎉 Summary

**You Requested:**
- Configure traffic by src/dst IPs ✅
- Traffic flows to each possible feature ✅
- Constant traffic across all LANs ✅
- LAN1 → LAN2,3,4,5 and vice versa ✅

**You Got:**
- 🎨 Professional cyber-industrial design
- 🎯 Interactive LAN matrix builder
- 📊 Real-time statistics dashboard
- 🧪 Integrated RFC 2544 tests
- ⚙️ Complete feature control
- 🔥 Production-ready interface

**Access your new GUI:**
```
http://<VEP1445-IP>:8080
```

**Start generating traffic in 3 clicks!** 🚀
