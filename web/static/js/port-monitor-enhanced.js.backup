// Enhanced Port Monitor with Auto-Refresh and Active Scanning
// Continuously updates port status and performs active discovery

class EnhancedPortMonitor {
    constructor() {
        this.interval = null;
        this.updateFrequency = 5000; // 5 seconds
        this.activeScanning = false;
        this.scanInterval = null;
        this.scanFrequency = 30000; // 30 seconds for active scans
        this.lastUpdate = null;
        this.autoRefresh = true;
    }
    
    start() {
        console.log('Enhanced port monitor started');
        this.update();
        this.interval = setInterval(() => this.update(), this.updateFrequency);
        
        // Start active scanning if enabled
        if (this.activeScanning) {
            this.startActiveScanning();
        }
        
        this.updateStatusIndicator('active');
    }
    
    stop() {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
        this.stopActiveScanning();
        this.updateStatusIndicator('stopped');
    }
    
    async update() {
        try {
            const response = await fetch('/api/ports/status');
            const data = await response.json();
            
            if (data.status === 'success') {
                this.lastUpdate = new Date();
                this.updateDisplay(data.ports, data.dpdk_engine_running);
                this.updateTimestamp();
                
                // Update DPDK status indicator
                this.updateDpdkStatus(data.dpdk_engine_running);
            } else {
                console.error('Port status error:', data);
                this.showError('Failed to get port status');
            }
        } catch (error) {
            console.error('Port status error:', error);
            this.showError('Connection error - retrying...');
        }
    }
    
    updateDisplay(ports, dpdkRunning) {
        ports.forEach(port => {
            this.updatePortCard(port, dpdkRunning);
            this.updateLanBox(port, dpdkRunning);
        });
    }
    
    updatePortCard(port, dpdkRunning) {
        const card = document.querySelector(`[data-port="${port.interface}"]`);
        if (!card) return;
        
        // Update link status with appropriate styling
        const statusEl = card.querySelector('.port-link-status');
        if (statusEl) {
            statusEl.className = 'port-link-status ' + port.link;
            
            if (port.link === 'up') {
                statusEl.textContent = `Link Up (${port.speed} Mbps)`;
            } else if (port.link === 'down') {
                statusEl.textContent = 'Link Down';
            } else {
                statusEl.textContent = port.dpdk_bound && !dpdkRunning ? 
                    'DPDK Not Running' : 'Unknown';
            }
        }
        
        // Update neighbor info
        const neighborEl = card.querySelector('.port-neighbor');
        if (neighborEl) {
            if (port.neighbor) {
                const method = port.neighbor.discovery_method || 'unknown';
                let displayText = '';
                
                if (port.neighbor.system_name) {
                    displayText = `→ ${port.neighbor.system_name}`;
                }
                if (port.neighbor.ip) {
                    displayText += ` (${port.neighbor.ip})`;
                }
                
                neighborEl.textContent = displayText;
                neighborEl.title = `Discovered via: ${method}`;
                neighborEl.style.display = 'block';
            } else {
                neighborEl.style.display = 'none';
            }
        }
        
        // Update status note
        const noteEl = card.querySelector('.port-status-note');
        if (noteEl && port.status_note) {
            noteEl.textContent = port.status_note;
            noteEl.style.display = 'block';
        } else if (noteEl) {
            noteEl.style.display = 'none';
        }
        
        // Add discovery method badge
        const methodEl = card.querySelector('.discovery-method');
        if (methodEl && port.discovery_method) {
            methodEl.textContent = port.discovery_method.toUpperCase();
            methodEl.className = `discovery-method ${port.discovery_method}`;
        }
    }
    
    updateLanBox(port, dpdkRunning) {
        const boxes = document.querySelectorAll(`[data-interface="${port.interface}"]`);
        
        boxes.forEach(box => {
            // Update visual state
            if (port.link === 'up') {
                box.classList.add('link-up');
                box.classList.remove('link-down', 'link-unknown');
            } else if (port.link === 'down') {
                box.classList.add('link-down');
                box.classList.remove('link-up', 'link-unknown');
            } else {
                box.classList.add('link-unknown');
                box.classList.remove('link-up', 'link-down');
            }
            
            // Update label
            const label = box.querySelector('.lan-connected');
            if (label) {
                if (port.neighbor && port.neighbor.system_name) {
                    label.textContent = port.neighbor.system_name;
                } else if (port.neighbor && port.neighbor.ip) {
                    label.textContent = port.neighbor.ip;
                } else if (port.dpdk_bound && !dpdkRunning) {
                    label.textContent = 'Start DPDK';
                } else if (port.status_note) {
                    label.textContent = 'Start traffic';
                } else {
                    label.textContent = '';
                }
            }
        });
    }
    
    updateDpdkStatus(running) {
        const indicator = document.getElementById('dpdk-status-indicator');
        if (indicator) {
            if (running) {
                indicator.textContent = '● DPDK Running';
                indicator.className = 'dpdk-status running';
            } else {
                indicator.textContent = '○ DPDK Not Running';
                indicator.className = 'dpdk-status stopped';
            }
        }
    }
    
    updateTimestamp() {
        const timestampEl = document.getElementById('last-update-time');
        if (timestampEl && this.lastUpdate) {
            timestampEl.textContent = this.lastUpdate.toLocaleTimeString();
        }
    }
    
    updateStatusIndicator(status) {
        const indicator = document.getElementById('monitor-status-indicator');
        if (indicator) {
            indicator.textContent = status === 'active' ? 
                '● Monitoring Active' : '○ Monitoring Stopped';
            indicator.className = `monitor-status ${status}`;
        }
    }
    
    // Active Scanning Functions
    
    startActiveScanning() {
        if (this.scanInterval) return;
        
        console.log('Active scanning started');
        this.activeScanning = true;
        
        // Scan immediately
        this.performActiveScan();
        
        // Then scan periodically
        this.scanInterval = setInterval(() => {
            this.performActiveScan();
        }, this.scanFrequency);
        
        this.updateScanIndicator(true);
    }
    
    stopActiveScanning() {
        if (this.scanInterval) {
            clearInterval(this.scanInterval);
            this.scanInterval = null;
        }
        this.activeScanning = false;
        this.updateScanIndicator(false);
        console.log('Active scanning stopped');
    }
    
    async performActiveScan() {
        console.log('Performing active scan...');
        
        // Get list of DPDK interfaces (eno2-eno8)
        const dpdkInterfaces = ['eno2', 'eno3', 'eno4', 'eno5', 'eno6', 'eno7', 'eno8'];
        
        for (const iface of dpdkInterfaces) {
            try {
                const response = await fetch(`/api/ports/arp-scan/${iface}`);
                const data = await response.json();
                
                if (data.status === 'success' && data.neighbor) {
                    console.log(`Found neighbor on ${iface}:`, data.neighbor);
                }
            } catch (error) {
                console.error(`Scan error on ${iface}:`, error);
            }
            
            // Small delay between scans
            await this.sleep(500);
        }
        
        // After scanning, update display
        this.update();
    }
    
    updateScanIndicator(active) {
        const indicator = document.getElementById('scan-status-indicator');
        if (indicator) {
            if (active) {
                indicator.textContent = '📡 Active Scanning';
                indicator.className = 'scan-status active';
            } else {
                indicator.textContent = 'Passive Discovery';
                indicator.className = 'scan-status passive';
            }
        }
    }
    
    // Manual Actions
    
    async manualRefresh() {
        this.showNotification('Refreshing port status...');
        
        try {
            // Refresh LLDP
            await fetch('/api/ports/refresh');
            
            // Wait a bit for LLDP to update
            await this.sleep(2000);
            
            // Update display
            await this.update();
            
            this.showNotification('Port status refreshed', 'success');
        } catch (error) {
            this.showNotification('Refresh failed', 'error');
        }
    }
    
    async forceScan() {
        this.showNotification('Forcing active scan on all ports...');
        await this.performActiveScan();
        this.showNotification('Active scan complete', 'success');
    }
    
    toggleAutoRefresh() {
        this.autoRefresh = !this.autoRefresh;
        
        if (this.autoRefresh) {
            this.start();
            this.showNotification('Auto-refresh enabled', 'success');
        } else {
            this.stop();
            this.showNotification('Auto-refresh disabled', 'info');
        }
        
        this.updateAutoRefreshButton();
    }
    
    toggleActiveScanning() {
        if (this.activeScanning) {
            this.stopActiveScanning();
            this.showNotification('Active scanning disabled', 'info');
        } else {
            this.startActiveScanning();
            this.showNotification('Active scanning enabled', 'success');
        }
        
        this.updateActiveScanButton();
    }
    
    updateAutoRefreshButton() {
        const btn = document.getElementById('toggle-auto-refresh');
        if (btn) {
            btn.textContent = this.autoRefresh ? '⏸ Pause Auto-Refresh' : '▶ Resume Auto-Refresh';
            btn.className = this.autoRefresh ? 'btn-pause' : 'btn-resume';
        }
    }
    
    updateActiveScanButton() {
        const btn = document.getElementById('toggle-active-scan');
        if (btn) {
            btn.textContent = this.activeScanning ? '📡 Active Scan: ON' : '📡 Active Scan: OFF';
            btn.className = this.activeScanning ? 'btn-scan-on' : 'btn-scan-off';
        }
    }
    
    // UI Helpers
    
    showNotification(message, type = 'info') {
        console.log(`[${type}] ${message}`);
        
        const notification = document.getElementById('port-notification');
        if (notification) {
            notification.textContent = message;
            notification.className = `notification ${type}`;
            notification.style.display = 'block';
            
            setTimeout(() => {
                notification.style.display = 'none';
            }, 3000);
        }
    }
    
    showError(message) {
        this.showNotification(message, 'error');
    }
    
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Auto-start when page loads
let portMonitor = null;

document.addEventListener('DOMContentLoaded', function() {
    portMonitor = new EnhancedPortMonitor();
    portMonitor.start();
    
    // Refresh button
    const refreshBtn = document.getElementById('refresh-ports-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            portMonitor.manualRefresh();
        });
    }
    
    // Force scan button
    const scanBtn = document.getElementById('force-scan-btn');
    if (scanBtn) {
        scanBtn.addEventListener('click', () => {
            portMonitor.forceScan();
        });
    }
    
    // Toggle auto-refresh
    const autoRefreshBtn = document.getElementById('toggle-auto-refresh');
    if (autoRefreshBtn) {
        autoRefreshBtn.addEventListener('click', () => {
            portMonitor.toggleAutoRefresh();
        });
    }
    
    // Toggle active scanning
    const activeScanBtn = document.getElementById('toggle-active-scan');
    if (activeScanBtn) {
        activeScanBtn.addEventListener('click', () => {
            portMonitor.toggleActiveScanning();
        });
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    if (portMonitor) {
        portMonitor.stop();
    }
});

// Export for external access
window.portMonitor = portMonitor;
