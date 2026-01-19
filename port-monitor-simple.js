// Simple Port Monitor with LLDP
// Updates port status every 5 seconds

class PortMonitor {
    constructor() {
        this.interval = null;
        this.updateFrequency = 5000; // 5 seconds
    }
    
    start() {
        console.log('Port monitor started');
        this.update();
        this.interval = setInterval(() => this.update(), this.updateFrequency);
    }
    
    stop() {
        if (this.interval) {
            clearInterval(this.interval);
        }
    }
    
    async update() {
        try {
            const response = await fetch('/api/ports/status');
            const data = await response.json();
            
            if (data.status === 'success') {
                this.updateDisplay(data.ports);
            }
        } catch (error) {
            console.error('Port status error:', error);
        }
    }
    
    updateDisplay(ports) {
        ports.forEach(port => {
            this.updatePortCard(port);
            this.updateLanBox(port);
        });
    }
    
    updatePortCard(port) {
        // Find port status element in sidebar
        const card = document.querySelector(`[data-port="${port.interface}"]`);
        if (!card) return;
        
        // Update link status
        const statusEl = card.querySelector('.port-link-status');
        if (statusEl) {
            statusEl.className = 'port-link-status ' + port.link;
            statusEl.textContent = port.link === 'up' ? 
                `Link Up (${port.speed} Mbps)` : 
                'Link Down';
        }
        
        // Update neighbor info
        const neighborEl = card.querySelector('.port-neighbor');
        if (neighborEl && port.neighbor) {
            neighborEl.textContent = port.display_name;
            neighborEl.style.display = 'block';
        } else if (neighborEl) {
            neighborEl.style.display = 'none';
        }
    }
    
    updateLanBox(port) {
        // Find LAN selector boxes
        const boxes = document.querySelectorAll(`[data-interface="${port.interface}"]`);
        
        boxes.forEach(box => {
            // Update visual state
            if (port.link === 'up') {
                box.classList.add('link-up');
                box.classList.remove('link-down');
            } else {
                box.classList.add('link-down');
                box.classList.remove('link-up');
            }
            
            // Update label if neighbor found
            if (port.neighbor) {
                const label = box.querySelector('.lan-connected');
                if (label) {
                    label.textContent = port.neighbor.system_name || '';
                }
            }
        });
    }
    
    async refresh() {
        try {
            await fetch('/api/ports/refresh');
            setTimeout(() => this.update(), 3000);
        } catch (error) {
            console.error('LLDP refresh error:', error);
        }
    }
}

// Auto-start when page loads
let portMonitor = null;

document.addEventListener('DOMContentLoaded', function() {
    portMonitor = new PortMonitor();
    portMonitor.start();
    
    // Add refresh button handler
    const refreshBtn = document.getElementById('refresh-ports-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            portMonitor.refresh();
        });
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    if (portMonitor) {
        portMonitor.stop();
    }
});
