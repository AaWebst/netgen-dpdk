# Quick Start Guide

Get NetGen Pro running in 5 minutes!

## 1. Prerequisites

```bash
# VEP1445 with Ubuntu 22.04/24.04
sudo apt-get update
sudo apt-get install -y dpdk dpdk-dev libjson-c-dev build-essential python3-pip
```

## 2. Installation

```bash
git clone https://github.com/yourusername/netgen-pro-vep1445.git
cd netgen-pro-vep1445
make
sudo bash scripts/configure-vep1445-basic.sh
sudo bash scripts/install-service.sh
sudo systemctl start netgen-pro-dpdk
```

## 3. Access GUI

```bash
# Find management IP
ip addr show eno1

# Open browser
http://<MGMT-IP>:8080
```

## 4. Generate First Traffic

```bash
1. Click "Traffic Matrix"
2. Click "LAN1" in source
3. Click "LAN2" in destination
4. Set Rate: 100 Mbps
5. Click "Add Traffic Flow"
6. Click "START ALL FLOWS"
```

Done! Traffic is now flowing! 🚀
