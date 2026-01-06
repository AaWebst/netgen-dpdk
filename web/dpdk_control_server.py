#!/usr/bin/env python3
"""
NetGen Pro - DPDK Control Server
Python Flask server that controls the DPDK packet generation engine via IPC
"""

from flask import Flask, render_template, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import threading
import time
import json
import sys
import os
import socket
import struct
import subprocess
import signal
from datetime import datetime
from pathlib import Path
from collections import defaultdict

app = Flask(__name__, static_folder='static', template_folder='templates')
CORS(app, resources={r"/*": {"origins": "*"}})

socketio = SocketIO(
    app, 
    cors_allowed_origins="*",
    async_mode='threading',
    logger=False,
    engineio_logger=False
)

# Configuration
DPDK_ENGINE_PATH = os.path.join(os.path.dirname(__file__), '../build/dpdk_engine')
CONTROL_SOCKET = '/tmp/netgen_dpdk_control.sock'
STATS_SOCKET = '/tmp/netgen_dpdk_stats.sock'

# Global state
dpdk_process = None
dpdk_running = False
current_profiles = []
stats_lock = threading.Lock()
current_stats = {
    'running': False,
    'profiles': {},
    'elapsed': 0,
    'total_packets': 0,
    'total_bytes': 0,
    'total_mbps': 0
}

class DPDKController:
    """Controller for DPDK engine process"""
    
    def __init__(self):
        self.process = None
        self.profiles = []
        
    def start_engine(self, dpdk_args=None):
        """Start the DPDK engine process"""
        global dpdk_process, dpdk_running
        
        if self.process and self.process.poll() is None:
            print("DPDK engine already running")
            return True
        
        # Default DPDK arguments
        if dpdk_args is None:
            dpdk_args = [
                '-l', '0-3',  # Use cores 0-3
                '-n', '4',     # 4 memory channels
                '--proc-type', 'primary',
                '--file-prefix', 'netgen'
            ]
        
        cmd = [DPDK_ENGINE_PATH] + dpdk_args
        
        try:
            print(f"Starting DPDK engine: {' '.join(cmd)}")
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True
            )
            
            dpdk_process = self.process
            
            # Wait for engine to initialize
            time.sleep(2)
            
            if self.process.poll() is not None:
                stdout, stderr = self.process.communicate()
                print(f"DPDK engine failed to start:")
                print(f"STDOUT: {stdout}")
                print(f"STDERR: {stderr}")
                return False
            
            dpdk_running = True
            print("✅ DPDK engine started successfully")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start DPDK engine: {e}")
            return False
    
    def stop_engine(self):
        """Stop the DPDK engine process"""
        global dpdk_running
        
        if not self.process:
            return
        
        try:
            # Send shutdown command
            self.send_command("SHUTDOWN")
            
            # Wait for graceful shutdown
            self.process.wait(timeout=5)
            
        except subprocess.TimeoutExpired:
            print("Force killing DPDK engine")
            self.process.kill()
            self.process.wait()
        except Exception as e:
            print(f"Error stopping DPDK engine: {e}")
        
        self.process = None
        dpdk_running = False
        print("DPDK engine stopped")
    
    def send_command(self, command):
        """Send command to DPDK engine via Unix socket"""
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(CONTROL_SOCKET)
            sock.sendall(f"{command}\n".encode())
            response = sock.recv(1024).decode().strip()
            sock.close()
            return response
        except Exception as e:
            print(f"Failed to send command: {e}")
            return None
    
    def load_profiles(self, profiles):
        """Load traffic profiles into DPDK engine"""
        self.profiles = profiles
        
        # TODO: Implement profile loading via socket
        # For now, profiles need to be compiled into the engine
        # In production, you'd use a JSON protocol to send profiles
        
        return True
    
    def start_traffic(self):
        """Start traffic generation"""
        response = self.send_command("START")
        return response == "OK"
    
    def stop_traffic(self):
        """Stop traffic generation"""
        response = self.send_command("STOP")
        return response == "OK"

# Global controller instance
dpdk_controller = DPDKController()

# API Routes
@app.route('/')
def index():
    """Serve the main HTML page"""
    return send_from_directory('templates', 'index.html')

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get current status"""
    return jsonify({
        'engine_running': dpdk_running,
        'traffic_running': current_stats['running'],
        'profiles': len(current_profiles)
    })

@app.route('/api/start', methods=['POST'])
def start_traffic():
    """Start traffic generation"""
    data = request.json
    
    # Ensure DPDK engine is running
    if not dpdk_running:
        if not dpdk_controller.start_engine():
            return jsonify({'error': 'Failed to start DPDK engine'}), 500
    
    # Load profiles
    profiles = data.get('profiles', [])
    if not profiles:
        return jsonify({'error': 'No profiles specified'}), 400
    
    global current_profiles
    current_profiles = profiles
    
    dpdk_controller.load_profiles(profiles)
    
    # Start traffic
    if dpdk_controller.start_traffic():
        current_stats['running'] = True
        return jsonify({'status': 'started'})
    else:
        return jsonify({'error': 'Failed to start traffic'}), 500

@app.route('/api/stop', methods=['POST'])
def stop_traffic():
    """Stop traffic generation"""
    if dpdk_controller.stop_traffic():
        current_stats['running'] = False
        return jsonify({'status': 'stopped'})
    else:
        return jsonify({'error': 'Failed to stop traffic'}), 500

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get current statistics"""
    with stats_lock:
        return jsonify(current_stats)

@app.route('/api/presets', methods=['GET'])
def get_presets():
    """Get traffic presets"""
    presets = {
        'udp_1g': {
            'name': '1 Gbps UDP',
            'description': 'Simple UDP flood at 1 Gbps',
            'total_rate': 1000,
            'profiles': [
                {
                    'name': 'UDP-1G',
                    'protocol': 'udp',
                    'packet_size': 1400,
                    'rate': 1000,
                    'dst_port': 5000
                }
            ]
        },
        'mixed_1g': {
            'name': '1 Gbps Mixed',
            'description': 'Mixed UDP/TCP traffic',
            'total_rate': 1000,
            'profiles': [
                {
                    'name': 'UDP-Large',
                    'protocol': 'udp',
                    'packet_size': 1400,
                    'rate': 500,
                    'dst_port': 5000
                },
                {
                    'name': 'TCP-Web',
                    'protocol': 'tcp',
                    'packet_size': 1500,
                    'rate': 500,
                    'dst_port': 80
                }
            ]
        },
        'udp_10g': {
            'name': '10 Gbps UDP',
            'description': 'High-speed UDP flood',
            'total_rate': 10000,
            'profiles': [
                {
                    'name': '10G-UDP',
                    'protocol': 'udp',
                    'packet_size': 1400,
                    'rate': 10000,
                    'dst_port': 5000
                }
            ]
        }
    }
    return jsonify(presets)

@app.route('/api/interfaces', methods=['GET'])
def get_interfaces():
    """Get available network interfaces"""
    try:
        # This would query DPDK for available ports
        # For now, return mock data
        return jsonify({
            'interfaces': [
                {'id': 0, 'name': 'dpdk0', 'status': 'up', 'speed': '10000'},
                {'id': 1, 'name': 'dpdk1', 'status': 'down', 'speed': '10000'}
            ]
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# WebSocket handlers
@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    print(f"Client connected: {request.sid}")
    emit('connected', {'engine_running': dpdk_running})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    print(f"Client disconnected: {request.sid}")

def stats_broadcaster():
    """Broadcast statistics to all connected clients"""
    while True:
        time.sleep(1)
        if current_stats['running']:
            with stats_lock:
                socketio.emit('stats_update', current_stats)

# Start stats broadcaster thread
stats_thread = threading.Thread(target=stats_broadcaster, daemon=True)
stats_thread.start()

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print(f"\nReceived signal {signum}, shutting down...")
    dpdk_controller.stop_engine()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='NetGen Pro - DPDK Control Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--auto-start-engine', action='store_true', 
                       help='Automatically start DPDK engine on startup')
    
    args = parser.parse_args()
    
    print(f"\n{'='*70}")
    print(f"  NetGen Pro - DPDK Edition")
    print(f"{'='*70}")
    print(f"  Web Interface: http://{args.host}:{args.port}")
    print(f"  DPDK Engine: {DPDK_ENGINE_PATH}")
    print(f"{'='*70}\n")
    
    # Auto-start engine if requested
    if args.auto_start_engine:
        print("Auto-starting DPDK engine...")
        if dpdk_controller.start_engine():
            print("✅ DPDK engine ready")
        else:
            print("❌ Failed to start DPDK engine")
            print("You'll need to start it manually from the web UI")
    
    socketio.run(app, host=args.host, port=args.port, debug=args.debug)

if __name__ == '__main__':
    main()
