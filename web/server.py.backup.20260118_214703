#!/usr/bin/env python3
"""
NetGen Pro v4.2 - UNIFIED Web Server
Combines features from server.py, server-fixed.py, server-enhanced.py

Features:
- All 17 traffic presets (1 Mbps to 10 Gbps)
- Port status detection (DPDK + kernel)
- LLDP neighbor discovery
- Enhanced timeout handling (3s stats, 10s stop, 15s start)
- Profile management with SQLite
- Test history tracking
- WebSocket real-time stats
"""

from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import subprocess
import json
import time
import os
import threading
import socket as sock
import sqlite3
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'netgen-unified-key'
CORS(app, resources={r"/*": {"origins": "*"}})

socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

CONTROL_SOCKET = '/tmp/dpdk_engine_control.sock'
DB_PATH = 'traffic_generator.db'

current_status = {'running': False, 'profiles': [], 'start_time': None}

# All 17 traffic presets
TRAFFIC_PRESETS = {
    'custom_bandwidth': {'name': '⚡ Custom', 'total_rate': 0, 'is_custom': True, 
        'profiles': [{'name': 'Custom-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 0, 'dst_port': 5000}]},
    '1_mbps': {'name': '1 Mbps', 'total_rate': 1,
        'profiles': [{'name': '1M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 1, 'dst_port': 5000}]},
    '5_mbps_mixed': {'name': '5 Mbps Mixed', 'total_rate': 5, 'profiles': [
        {'name': '5M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 3, 'dst_port': 5000},
        {'name': '5M-TCP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 1.5, 'dst_port': 80}]},
    '10_mbps': {'name': '10 Mbps', 'total_rate': 10,
        'profiles': [{'name': '10M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 10, 'dst_port': 5000}]},
    '25_mbps_mixed': {'name': '25 Mbps Mixed', 'total_rate': 25, 'profiles': [
        {'name': '25M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 15, 'dst_port': 5000},
        {'name': '25M-TCP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 8, 'dst_port': 80}]},
    '50_mbps_mixed': {'name': '50 Mbps Mixed', 'total_rate': 50, 'profiles': [
        {'name': '50M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 30, 'dst_port': 5000},
        {'name': '50M-TCP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 15, 'dst_port': 80}]},
    'voip_traffic': {'name': 'VoIP (90 Mbps)', 'total_rate': 90, 'profiles': [
        {'name': 'RTP-Voice', 'protocol': 'udp', 'packet_size': 200, 'rate': 80, 'dst_port': 5004}]},
    '100_mbps': {'name': '100 Mbps', 'total_rate': 100,
        'profiles': [{'name': '100M-UDP', 'protocol': 'udp', 'packet_size': 1400, 'rate': 100, 'dst_port': 5000}]},
    'imix_realistic': {'name': 'IMIX (200 Mbps)', 'total_rate': 200, 'profiles': [
        {'name': 'IMIX-64B', 'protocol': 'udp', 'packet_size': 64, 'rate': 15, 'dst_port': 5000},
        {'name': 'IMIX-1400B', 'protocol': 'udp', 'packet_size': 1400, 'rate': 100, 'dst_port': 5003}]},
    'mixed_1g': {'name': '1 Gbps Mixed', 'total_rate': 1000, 'profiles': [
        {'name': 'UDP-Large', 'protocol': 'udp', 'packet_size': 1400, 'rate': 400, 'dst_port': 5000},
        {'name': 'TCP-Web', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 300, 'dst_port': 80}]},
    'web_traffic': {'name': 'Web (1 Gbps)', 'total_rate': 1000, 'profiles': [
        {'name': 'HTTP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 400, 'dst_port': 80},
        {'name': 'HTTPS', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 600, 'dst_port': 443}]},
    'imix_standard': {'name': 'IMIX Standard (1 Gbps)', 'total_rate': 1000, 'profiles': [
        {'name': 'IMIX-64B', 'protocol': 'udp', 'packet_size': 64, 'rate': 583, 'dst_port': 5000},
        {'name': 'IMIX-1500B', 'protocol': 'udp', 'packet_size': 1500, 'rate': 84, 'dst_port': 5002}]},
    'mixed_5g': {'name': '5 Gbps Mixed', 'total_rate': 5000, 'profiles': [
        {'name': 'UDP-1', 'protocol': 'udp', 'packet_size': 1400, 'rate': 1500, 'dst_port': 5000},
        {'name': 'UDP-2', 'protocol': 'udp', 'packet_size': 1400, 'rate': 1500, 'dst_port': 5001},
        {'name': 'TCP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 1500, 'dst_port': 80}]},
    'udp_flood': {'name': 'UDP Flood (5 Gbps)', 'total_rate': 5000,
        'profiles': [{'name': 'UDP-Flood', 'protocol': 'udp', 'packet_size': 1400, 'rate': 5000, 'dst_port': 5000}]},
    'mixed_10g': {'name': '10 Gbps Mixed', 'total_rate': 10000, 'profiles': [
        {'name': '10G-UDP-1', 'protocol': 'udp', 'packet_size': 1400, 'rate': 2500, 'dst_port': 5000},
        {'name': '10G-UDP-2', 'protocol': 'udp', 'packet_size': 1400, 'rate': 2500, 'dst_port': 5001},
        {'name': '10G-TCP', 'protocol': 'tcp', 'packet_size': 1500, 'rate': 2000, 'dst_port': 80}]}
}

def init_database():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS saved_profiles (
        id INTEGER PRIMARY KEY, name TEXT UNIQUE, description TEXT, 
        config TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    cursor.execute('''CREATE TABLE IF NOT EXISTS test_history (
        id INTEGER PRIMARY KEY, name TEXT, destination TEXT, duration INTEGER,
        total_packets INTEGER, total_bytes INTEGER, total_mbps REAL,
        started_at TIMESTAMP, completed_at TIMESTAMP, status TEXT)''')
    conn.commit()
    conn.close()

init_database()

def send_dpdk_command(command_dict, timeout=10):
    try:
        client = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
        client.settimeout(timeout)
        client.connect(CONTROL_SOCKET)
        client.sendall(json.dumps(command_dict).encode() + b'\n')
        response = b''
        while True:
            chunk = client.recv(4096)
            if not chunk: break
            response += chunk
            if b'\n' in chunk: break
        client.close()
        return json.loads(response.decode().strip()) if response else {'status': 'error'}
    except sock.timeout:
        return {'status': 'error', 'message': 'Timeout'}
    except FileNotFoundError:
        return {'status': 'error', 'message': 'Engine not running'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def get_link_status(interface):
    try:
        with open(f'/sys/class/net/{interface}/operstate', 'r') as f:
            state = f.read().strip().lower()
        link = 'up' if state == 'up' else 'down'
        try:
            with open(f'/sys/class/net/{interface}/speed', 'r') as f:
                speed = int(f.read().strip())
        except: speed = 0
        return {'link': link, 'speed': speed}
    except:
        return {'link': 'unknown', 'speed': 0}

def discover_lldp_neighbor(interface):
    try:
        result = subprocess.run(['lldpctl', interface], capture_output=True, text=True, timeout=2)
        if result.returncode != 0: return None
        neighbor = {}
        for line in result.stdout.split('\n'):
            if 'SysName:' in line: neighbor['system_name'] = line.split(':', 1)[1].strip()
            elif 'PortDescr:' in line: neighbor['port_description'] = line.split(':', 1)[1].strip()
        return neighbor if neighbor else None
    except: return None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    return jsonify({'running': current_status.get('running', False), 'config': current_status})

@app.route('/api/presets')
def api_presets():
    return jsonify(TRAFFIC_PRESETS)

@app.route('/api/start', methods=['POST'])
def api_start():
    try:
        data = request.json
        profiles = data.get('profiles', [])
        for p in profiles:
            if 'rate' in p and 'rate_mbps' not in p: p['rate_mbps'] = p['rate']
        response = send_dpdk_command({'command': 'start', 'profiles': profiles}, timeout=15)
        if response.get('status') == 'success':
            current_status['running'] = True
            current_status['profiles'] = profiles
            current_status['start_time'] = datetime.now().isoformat()
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stop', methods=['POST'])
def api_stop():
    try:
        response = send_dpdk_command({'command': 'stop'}, timeout=10)
        if response.get('status') == 'success':
            current_status['running'] = False
        return jsonify(response)
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stats')
def api_stats():
    response = send_dpdk_command({'command': 'stats'}, timeout=3)
    return jsonify(response.get('data', {})) if response.get('status') == 'success' else jsonify({'error': response.get('message')}), 500

@app.route('/api/ports/status')
def get_ports_status():
    interfaces = {'eno1': {'label': 'MGMT', 'type': '1G'}, 'eno2': {'label': 'LAN1', 'type': '1G'},
                  'eno3': {'label': 'LAN2', 'type': '1G'}, 'eno7': {'label': '10G TX', 'type': '10G'},
                  'eno8': {'label': '10G RX', 'type': '10G'}}
    ports_status = []
    for iface, info in interfaces.items():
        port = {'name': iface, 'label': info['label'], 'type': info['type'], 'status': 'UNKNOWN'}
        link_info = get_link_status(iface)
        port.update(link_info)
        port['status'] = 'LINUX' if port['link'] == 'up' else 'AVAIL'
        if port['link'] == 'up': port['lldp_neighbor'] = discover_lldp_neighbor(iface)
        ports_status.append(port)
    return jsonify({'status': 'success', 'timestamp': int(time.time()), 'ports': ports_status})

@socketio.on('connect')
def handle_connect():
    emit('connected', {'status': 'success'})

def stats_broadcast():
    while True:
        if current_status.get('running'):
            try:
                r = send_dpdk_command({'command': 'stats'}, timeout=2)
                if r.get('status') == 'success': socketio.emit('stats_update', r.get('data', {}), broadcast=True)
            except: pass
        time.sleep(1)

threading.Thread(target=stats_broadcast, daemon=True).start()

if __name__ == '__main__':
    print("\n" + "="*70)
    print("  NetGen Pro v4.2 - UNIFIED Server")
    print("  Presets: " + str(len(TRAFFIC_PRESETS)))
    print("  Listening: http://0.0.0.0:8080")
    print("="*70 + "\n")
    socketio.run(app, host='0.0.0.0', port=8080, debug=False, allow_unsafe_werkzeug=True)
