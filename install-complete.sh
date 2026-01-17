#!/bin/bash
# NetGen Pro v4.1 - One-Command Install
# Usage: sudo bash install-complete.sh

set -e
echo "NetGen Pro VEP1445 - Installing with 7 DPDK ports..."

[ "$EUID" -ne 0 ] && { echo "Run as root!"; exit 1; }

# Dependencies
apt-get update -qq && apt-get install -y dpdk dpdk-dev build-essential \
    libnuma-dev libpcap-dev python3-flask python3-flask-socketio \
    lldpd netcat-openbsd jq >/dev/null 2>&1

# Hugepages
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
echo "vm.nr_hugepages=1024" >> /etc/sysctl.conf

# VFIO
modprobe vfio-pci
echo "vfio-pci" >> /etc/modules

# Bind 7 ports
dpdk-devbind.py --bind=vfio-pci 0000:02:00.3 0000:02:00.0 0000:02:00.1 \
    0000:07:00.1 0000:07:00.0 0000:05:00.1 0000:05:00.0

# Build
make clean && make

# Systemd
cat > /etc/systemd/system/netgen-pro-dpdk.service << 'EOF'
[Unit]
Description=NetGen Pro DPDK
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/netgen-dpdk
ExecStartPre=/bin/bash -c 'echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages'
ExecStartPre=/sbin/modprobe vfio-pci
ExecStartPre=/usr/bin/dpdk-devbind.py --bind=vfio-pci 0000:02:00.3 0000:02:00.0 0000:02:00.1 0000:07:00.1 0000:07:00.0 0000:05:00.1 0000:05:00.0
ExecStart=/opt/netgen-dpdk/build/dpdk_engine
Restart=always
StandardOutput=append:/var/log/dpdk_engine.log
StandardError=append:/var/log/dpdk_engine.log
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable netgen-pro-dpdk
systemctl start netgen-pro-dpdk

sleep 10
echo '{"command":"status"}' | nc -U /tmp/dpdk_engine_control.sock

echo "✅ Installed! GUI: http://$(hostname -I | awk '{print $1}'):8080"