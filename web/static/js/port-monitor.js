/*
 * NetGen Pro v4.0 - Enhanced Port Status Monitor
 * Features: Dynamic status, Link up/down, LLDP neighbors, Connected devices
 */

class PortStatusMonitor {
    constructor() {
        this.updateInterval = 2000; // 2 seconds
        this.intervalId = null;
        this.portsData = {};
    }
    
    start() {
        console.log('Starting port status monitor...');
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
            const response = await fetch('/api/ports/status');
            const data = await response.json();
            
            if (data.status === 'success') {
                this.portsData = data.ports;
                this.updateUI();
            }
        } catch (error) {
            console.error('Error fetching port status:', error);
        }
    }
    
    updateUI() {
        this.portsData.forEach(port => {
            this.updatePortCard(port);
        });
    }
    
    updatePortCard(port) {
        // Find port card by name
        const portCard = document.querySelector(`[data-port="${port.name}"]`);
        if (!portCard) {
            console.warn(`Port card not found for ${port.name}`);
            return;
        }
        
        // Update status badge
        const statusBadge = portCard.querySelector('.port-status');
        if (statusBadge) {
            // Remove old classes
            statusBadge.classList.remove('linux', 'dpdk', 'avail', 'unknown');
            
            // Add new class and text
            const statusClass = port.status.toLowerCase();
            statusBadge.classList.add(statusClass);
            statusBadge.textContent = port.status;
        }
        
        // Update or create link status indicator
        let linkIndicator = portCard.querySelector('.link-status');
        if (!linkIndicator) {
            linkIndicator = document.createElement('div');
            linkIndicator.className = 'link-status';
            portCard.appendChild(linkIndicator);
        }
        
        // Set link status
        linkIndicator.classList.remove('up', 'down', 'bound', 'unknown');
        
        if (port.link === 'up') {
            linkIndicator.classList.add('up');
            linkIndicator.textContent = '● Link Up';
            linkIndicator.title = `Speed: ${port.speed} Mbps`;
        } else if (port.link === 'down') {
            linkIndicator.classList.add('down');
            linkIndicator.textContent = '○ Link Down';
            linkIndicator.title = 'No link detected';
        } else if (port.link === 'bound_to_dpdk') {
            linkIndicator.classList.add('bound');
            linkIndicator.textContent = '◆ DPDK Bound';
            linkIndicator.title = 'Bound to DPDK (link status via DPDK only)';
        } else {
            linkIndicator.classList.add('unknown');
            linkIndicator.textContent = '? Unknown';
        }
        
        // Update or create LLDP neighbor info
        this.updateLLDPInfo(portCard, port);
        
        // Update driver info tooltip
        if (port.driver) {
            portCard.title = `Driver: ${port.driver}\\nPCI: ${port.pci || 'N/A'}\\nMAC: ${port.mac || 'N/A'}`;
        }
    }
    
    updateLLDPInfo(portCard, port) {
        // Remove existing LLDP info
        const existingLLDP = portCard.querySelector('.lldp-info');
        if (existingLLDP) {
            existingLLDP.remove();
        }
        
        // If no LLDP neighbor, check ARP neighbors
        if (!port.lldp_neighbor && (!port.arp_neighbors || port.arp_neighbors.length === 0)) {
            return;
        }
        
        // Create LLDP/device info section
        const lldpDiv = document.createElement('div');
        lldpDiv.className = 'lldp-info';
        
        if (port.lldp_neighbor) {
            // LLDP neighbor found
            const neighbor = port.lldp_neighbor;
            lldpDiv.innerHTML = `
                <div class="connected-device lldp-device">
                    <div class="device-icon">🔗</div>
                    <div class="device-details">
                        <div class="device-name">${this.escapeHtml(neighbor.system_name || 'Unknown Device')}</div>
                        <div class="device-type">${this.escapeHtml(neighbor.capabilities || 'Network Device')}</div>
                        ${neighbor.management_ip ? `<div class="device-ip">IP: ${neighbor.management_ip}</div>` : ''}
                        ${neighbor.port_description ? `<div class="device-port">Port: ${this.escapeHtml(neighbor.port_description)}</div>` : ''}
                    </div>
                </div>
            `;
        } else if (port.arp_neighbors && port.arp_neighbors.length > 0) {
            // ARP neighbors found
            lldpDiv.innerHTML = `
                <div class="connected-device arp-device">
                    <div class="device-icon">💻</div>
                    <div class="device-details">
                        <div class="device-name">${port.arp_neighbors.length} Device(s)</div>
                        <div class="device-type">Discovered via ARP</div>
                        ${port.arp_neighbors.slice(0, 3).map(n => 
                            `<div class="device-ip">${n.ip} (${n.mac})</div>`
                        ).join('')}
                        ${port.arp_neighbors.length > 3 ? 
                            `<div class="device-more">+${port.arp_neighbors.length - 3} more...</div>` : ''}
                    </div>
                </div>
            `;
        }
        
        portCard.appendChild(lldpDiv);
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    // Show network topology
    async showTopology() {
        try {
            const response = await fetch('/api/ports/topology');
            const data = await response.json();
            
            if (data.status === 'success') {
                this.renderTopology(data.topology);
            }
        } catch (error) {
            console.error('Error fetching topology:', error);
        }
    }
    
    renderTopology(topology) {
        // This would integrate with D3.js or vis.js for network diagram
        console.log('Network Topology:', topology);
        
        // For now, show in console or modal
        // Full implementation would draw interactive network diagram
        alert(`Discovered ${topology.devices.length} devices with ${topology.links.length} connections`);
    }
}

// Initialize when page loads
let portMonitor;

document.addEventListener('DOMContentLoaded', function() {
    portMonitor = new PortStatusMonitor();
    portMonitor.start();
    
    // Add topology button handler (if exists)
    const topologyBtn = document.getElementById('show-topology');
    if (topologyBtn) {
        topologyBtn.addEventListener('click', () => {
            portMonitor.showTopology();
        });
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
    if (portMonitor) {
        portMonitor.stop();
    }
});
