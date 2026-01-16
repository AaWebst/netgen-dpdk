# Quick Installation Guide

## 1. Install Dependencies (2 minutes)

```bash
sudo apt-get update
sudo apt-get install -y dpdk dpdk-dev build-essential \
    libnuma-dev libpcap-dev python3-flask python3-flask-socketio \
    lldpd netcat-openbsd jq
```

## 2. Clone Repository

```bash
cd /opt
sudo git clone https://github.com/YOUR_USERNAME/netgen-pro-vep1445.git netgen-dpdk
cd netgen-dpdk
```

## 3. Configure System (5 minutes)

```bash
# Hugepages
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
echo "vm.nr_hugepages=1024" | sudo tee -a /etc/sysctl.conf

# VFIO module
sudo modprobe vfio-pci
echo "vfio-pci" | sudo tee -a /etc/modules

# Bind interfaces (all except eno1)
sudo dpdk-devbind.py --bind=vfio-pci 0000:02:00.3  # eno2
sudo dpdk-devbind.py --bind=vfio-pci 0000:02:00.0  # eno3
sudo dpdk-devbind.py --bind=vfio-pci 0000:05:00.1  # eno7
sudo dpdk-devbind.py --bind=vfio-pci 0000:05:00.0  # eno8
```

## 4. Build (2 minutes)

```bash
make clean
make
```

## 5. Run (1 minute)

```bash
# Start DPDK engine
sudo bash scripts/start-dpdk-engine.sh

# Start web server (new terminal)
cd web
python3 server-enhanced.py
```

## 6. Access

Open browser: `http://YOUR_IP:8080`

**Total time: ~10 minutes**
