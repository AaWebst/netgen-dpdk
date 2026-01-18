/*
 * Enhanced Port Status Monitor with LLDP Discovery
 * Real-time link detection and connected device display
 */

class EnhancedPortMonitor {
    constructor() {
        this.updateInterval = 3000; // 3 seconds
        this.intervalId = null;
        this.portsData = {};
    }
    
    start() {
        console.log('Starting enhanced port monitor with LLDP...');
        this.update();
        this.intervalId = setInterval(() => this.update(), this.updateInterval);
    }
    
    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }
    
    async update() {
        try {
            const response = await fetch('/api/ports/enhanced_status');
            const data = await response.json();
            
            if (data.status === 'success') {
                this.portsData = data.ports;
                this.updateUI();
            }
        } catch (error) {
            console.error('Error fetching enhanced port status:', error);
        }
    }
    
    async refreshLLDP() {
        try {
            await fetch('/api/ports/refresh_lldp');
            console.log('LLDP refresh requested');
            // Wait 3 seconds then update
            setTimeout(() => this.update(), 3000);
        } catch (error) {
            console.error('Error refreshing LLDP:', error);
        }
    }
    
    updateUI() {
        this.portsData.forEach(port => {
            this.updatePortCard(port);
            this.updatePortSelector(port);
        });
    }
    
    updatePortCard(port) {
        // Update port status cards in sidebar
        const portCard = document.querySelector(`[data-port="${port.name}"]`);
        if (!portCard) return;
        
        // Update status badge
        const statusBadge = portCard.querySelector('.port-status');
        if (statusBadge) {
            statusBadge.className = 'port-status';
            statusBadge.classList.add(port.status.toLowerCase());
            statusBadge.textContent = port.status;
        }
        
        // Update/create link indicator
        let linkIndicator = portCard.querySelector('.link-indicator');
        if (!linkIndicator) {
            linkIndicator = document.createElement('div');
            linkIndicator.className = 'link-indicator';
            portCard.appendChild(linkIndicator);
        }
        
        // Set link status with color
        linkIndicator.className = 'link-indicator';
        if (port.link === 'up') {
            linkIndicator.classList.add('link-up');
            linkIndicator.innerHTML = `<span class="status-dot green"></span> Link Up (${port.link_speed} Mbps)`;
        } else if (port.link === 'down') {
            linkIndicator.classList.add('link-down');
            linkIndicator.innerHTML = '<span class="status-dot red"></span> Link Down';
        } else if (port.link === 'dpdk_bound') {
            linkIndicator.classList.add('link-dpdk');
            linkIndicator.innerHTML = `<span class="status-dot cyan"></span> DPDK Active (${port.link_speed} Mbps)`;
        } else {
            linkIndicator.classList.add('link-unknown');
            linkIndicator.innerHTML = '<span class="status-dot gray"></span> Unknown';
        }
        
        // Update/create LLDP neighbor info
        let lldpInfo = portCard.querySelector('.lldp-neighbor-info');
        if (!lldpInfo) {
            lldpInfo = document.createElement('div');
            lldpInfo.className = 'lldp-neighbor-info';
            portCard.appendChild(lldpInfo);
        }
        
        if (port.lldp_neighbor) {
            const neighbor = port.lldp_neighbor;
            lldpInfo.innerHTML = `
                <div class="neighbor-device">
                    <div class="neighbor-icon">🔗</div>
                    <div class="neighbor-details">
                        <div class="neighbor-name">${this.escapeHtml(neighbor.system_name || 'Unknown')}</div>
                        ${neighbor.port_description ? `<div class="neighbor-port">${this.escapeHtml(neighbor.port_description)}</div>` : ''}
                    </div>
                </div>
            `;
            lldpInfo.style.display = 'block';
        } else {
            lldpInfo.style.display = 'none';
        }
    }
    
    updatePortSelector(port) {
        // Update LAN selector boxes in Traffic Matrix
        const lanBoxes = document.querySelectorAll(`[data-lan-interface="${port.name}"]`);
        
        lanBoxes.forEach(box => {
            // Update label if LLDP discovered device
            const labelEl = box.querySelector('.lan-label');
            if (labelEl && port.connected_device) {
                // Show connected device name
                labelEl.textContent = port.original_label; // Keep original label
            }
            
            // Add/update connection indicator
            let connIndicator = box.querySelector('.connection-indicator');
            if (!connIndicator) {
                connIndicator = document.createElement('div');
                connIndicator.className = 'connection-indicator';
                box.appendChild(connIndicator);
            }
            
            if (port.connected_device) {
                connIndicator.innerHTML = `→ ${this.escapeHtml(port.connected_device)}`;
                connIndicator.style.display = 'block';
            } else {
                connIndicator.style.display = 'none';
            }
            
            // Update visual state based on link
            box.classList.remove('link-up', 'link-down', 'link-unknown');
            if (port.link === 'up' || port.link === 'dpdk_bound') {
                box.classList.add('link-up');
                box.style.borderColor = 'var(--color-primary)';
            } else if (port.link === 'down') {
                box.classList.add('link-down');
                box.style.borderColor = '#ff4444';
                box.style.opacity = '0.5';
            }
        });
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize on page load
let enhancedPortMonitor;

document.addEventListener('DOMContentLoaded', function() {
    enhancedPortMonitor = new EnhancedPortMonitor();
    enhancedPortMonitor.start();
    
    // Add refresh button handler
    const refreshBtn = document.getElementById('refresh-lldp-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            enhancedPortMonitor.refreshLLDP();
        });
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    if (enhancedPortMonitor) {
        enhancedPortMonitor.stop();
    }
});

// Export for global access
window.enhancedPortMonitor = enhancedPortMonitor;
