#!/usr/bin/env python3
"""
NetGen Pro - DPDK Edition v2.0
Complete Python control server with all features from your original version
"""

from flask import Flask, render_template, jsonify, request, send_file
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import threading, time, json, sys, os, sqlite3, subprocess, socket, signal
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
DPDK_ENGINE_PATH = os.path.join(ROOT_DIR, 'build', 'dpdk_engine')
DPDK_CONTROL_SOCKET = '/tmp/dpdk_engine_control.sock'

app = Flask(__name__, static_folder='static', template_folder='templates')
CORS(app, resources={r"/*": {"origins": "*"}})
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='gevent', 
                     logger=False, engineio_logger=False)

# Global state
dpdk_process = None
dpdk_lock = threading.Lock()
current_config = {'running': False, 'profiles': [], 'start_time': None}

# Database
DB_PATH = os.path.join(SCRIPT_DIR, 'traffic_generator.db')
DATA_DIR = os.path.join(SCRIPT_DIR, 'data')
for d in [DATA_DIR, os.path.join(DATA_DIR, 'captures'), os.path.join(DATA_DIR, 'exports')]:
    os.makedirs(d, exist_ok=True)

def init_database():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS saved_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
        description TEXT, config TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    cursor.execute('''CREATE TABLE IF NOT EXISTS test_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, destination TEXT NOT NULL,
        duration INTEGER, total_packets INTEGER, total_bytes INTEGER,
        total_mbps REAL, started_at TIMESTAMP, completed_at TIMESTAMP, status TEXT)''')
    conn.commit()
    conn.close()

init_database()

class DPDKController:
    def __init__(self):
        self.process = None
        self.last_stats = {}
    
    def start_engine(self, config):
        if self.process and self.process.poll() is None:
            return True, "Already running"
        try:
            cmd = [DPDK_ENGINE_PATH, '--', '--control-socket', DPDK_CONTROL_SOCKET]
            for prof in config.get('profiles', []):
                cmd.extend(['--profile', json.dumps(prof)])
            
            self.process = subprocess.Popen(cmd, stdout=subprocess.PIPE, 
                                          stderr=subprocess.PIPE, preexec_fn=os.setsid)
            for _ in range(100):
                if os.path.exists(DPDK_CONTROL_SOCKET):
                    time.sleep(0.2)
                    return True, "Started"
                time.sleep(0.1)
            self.stop_engine()
            return False, "Timeout"
        except Exception as e:
            return False, str(e)
    
    def stop_engine(self):
        if self.process:
            try:
                self.send_command('stop')
                time.sleep(0.5)
                if self.process.poll() is None:
                    os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                    for _ in range(50):
                        if self.process.poll() is not None: break
                        time.sleep(0.1)
                    else:
                        os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
            except: pass
            self.process = None
        if os.path.exists(DPDK_CONTROL_SOCKET):
            try: os.unlink(DPDK_CONTROL_SOCKET)
            except: pass
    
    def send_command(self, command, params=None):
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect(DPDK_CONTROL_SOCKET)
            msg = json.dumps({'command': command, 'params': params or {}}) + '\n'
            sock.sendall(msg.encode())
            data = sock.recv(4096).decode().strip()
            sock.close()
            return json.loads(data) if data else {'status': 'error'}
        except Exception as e:
            return {'status': 'error', 'message': str(e)}
    
    def get_stats(self):
        r = self.send_command('stats')
        if r.get('status') == 'success':
            self.last_stats = r.get('data', {})
        return r
    
    def is_running(self):
        return self.process and self.process.poll() is None

dpdk = DPDKController()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    return jsonify({'running': dpdk.is_running(), 'config': current_config, 'version': '2.0-DPDK'})

@app.route('/api/start', methods=['POST'])
def api_start():
    try:
        config = request.json
        profiles = config.get('profiles', [])
        if not profiles:
            return jsonify({'status': 'error', 'message': 'No profiles'}), 400
        
        with dpdk_lock:
            if dpdk.is_running():
                return jsonify({'status': 'error', 'message': 'Already running'}), 400
            
            success, msg = dpdk.start_engine(config)
            if not success:
                return jsonify({'status': 'error', 'message': msg}), 500
            
            current_config['running'] = True
            current_config['profiles'] = profiles
            current_config['start_time'] = datetime.now().isoformat()
            
            r = dpdk.send_command('start')
            if r.get('status') == 'success':
                return jsonify({'status': 'success', 'message': 'Started'})
            else:
                dpdk.stop_engine()
                current_config['running'] = False
                return jsonify({'status': 'error', 'message': 'Failed to start'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stop', methods=['POST'])
def api_stop():
    try:
        with dpdk_lock:
            final_stats = dpdk.last_stats.copy() if dpdk.is_running() else {}
            dpdk.stop_engine()
            current_config['running'] = False
            
            if final_stats and current_config.get('start_time'):
                try:
                    conn = sqlite3.connect(DB_PATH)
                    cursor = conn.cursor()
                    start = datetime.fromisoformat(current_config['start_time'])
                    duration = int((datetime.now() - start).total_seconds())
                    cursor.execute('''INSERT INTO test_history 
                        (name, destination, duration, total_packets, total_bytes, total_mbps, 
                         started_at, completed_at, status) VALUES (?,?,?,?,?,?,?,?,?)''',
                        ('Test', current_config['profiles'][0].get('dst_ip','N/A'), duration,
                         final_stats.get('packets_sent',0), final_stats.get('bytes_sent',0),
                         final_stats.get('throughput_mbps',0), start.isoformat(),
                         datetime.now().isoformat(), 'completed'))
                    conn.commit()
                    conn.close()
                except: pass
        return jsonify({'status': 'success', 'message': 'Stopped', 'final_stats': final_stats})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stats')
def api_stats():
    if not dpdk.is_running():
        return jsonify({'packets_sent':0,'bytes_sent':0,'throughput_mbps':0,'errors':0})
    r = dpdk.get_stats()
    return jsonify(r.get('data',{})) if r.get('status')=='success' else jsonify({'error':r.get('message')}), 500

@app.route('/api/profiles', methods=['GET'])
def api_list_profiles():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT id,name,description,created_at FROM saved_profiles ORDER BY created_at DESC')
        profiles = [{'id':r[0],'name':r[1],'description':r[2],'created_at':r[3]} for r in cursor.fetchall()]
        conn.close()
        return jsonify(profiles)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/profiles/<int:pid>', methods=['GET'])
def api_get_profile(pid):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT config FROM saved_profiles WHERE id=?', (pid,))
        row = cursor.fetchone()
        conn.close()
        return jsonify(json.loads(row[0])) if row else (jsonify({'error':'Not found'}), 404)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/profiles', methods=['POST'])
def api_save_profile():
    try:
        data = request.json
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('INSERT INTO saved_profiles (name,description,config) VALUES (?,?,?)',
                      (data.get('name'), data.get('description',''), json.dumps(data.get('config',{}))))
        conn.commit()
        pid = cursor.lastrowid
        conn.close()
        return jsonify({'status':'success','id':pid})
    except sqlite3.IntegrityError:
        return jsonify({'error':'Name exists'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/profiles/<int:pid>', methods=['DELETE'])
def api_delete_profile(pid):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM saved_profiles WHERE id=?', (pid,))
        conn.commit()
        conn.close()
        return jsonify({'status':'success'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/history', methods=['GET'])
def api_history():
    try:
        limit = request.args.get('limit', 50, type=int)
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''SELECT id,name,destination,duration,total_packets,total_bytes,total_mbps,
                         started_at,completed_at,status FROM test_history ORDER BY started_at DESC LIMIT ?''', (limit,))
        history = [{'id':r[0],'name':r[1],'destination':r[2],'duration':r[3],'total_packets':r[4],
                   'total_bytes':r[5],'total_mbps':r[6],'started_at':r[7],'completed_at':r[8],'status':r[9]}
                  for r in cursor.fetchall()]
        conn.close()
        return jsonify(history)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def stats_broadcast():
    while True:
        if dpdk.is_running():
            try:
                r = dpdk.get_stats()
                if r.get('status') == 'success':
                    socketio.emit('stats_update', r.get('data',{}))
            except: pass
        time.sleep(1)

@socketio.on('connect')
def handle_connect():
    emit('connected', {'status': 'success'})

threading.Thread(target=stats_broadcast, daemon=True).start()

def cleanup():
    dpdk.stop_engine()

import atexit
atexit.register(cleanup)

if __name__ == '__main__':
    print("🚀 NetGen Pro - DPDK Edition v2.0")
    print("="*60)
    print(f"Engine: {DPDK_ENGINE_PATH}")
    print(f"Database: {DB_PATH}")
    if not os.path.exists(DPDK_ENGINE_PATH):
        print(f"❌ Engine not found: {DPDK_ENGINE_PATH}")
        print("   Run 'make' to build")
        sys.exit(1)
    print("✅ Starting on http://0.0.0.0:8080")
    print("="*60)
    socketio.run(app, host='0.0.0.0', port=8080, debug=False)
