#!/bin/bash
cd "$(dirname "$0")/web"
source venv/bin/activate
sudo python3 dpdk_control_server.py
