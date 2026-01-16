/*
 * NetGen Pro - DPDK Link Status & Device Discovery
 * 
 * Features:
 * 1. Link status detection via DPDK API (rte_eth_link_get)
 * 2. Port statistics (rte_eth_stats_get)
 * 3. Device info (rte_eth_dev_info_get)
 * 4. MAC address retrieval
 * 5. ARP-like discovery via packet inspection
 */

#include <rte_ethdev.h>
#include <rte_ether.h>
#include <rte_arp.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define MAX_DISCOVERED_DEVICES 256
#define DISCOVERY_TIMEOUT_SEC 300  // 5 minutes

struct discovered_device {
    uint8_t mac_addr[RTE_ETHER_ADDR_LEN];
    uint32_t ip_addr;
    uint16_t port_id;
    time_t last_seen;
    uint64_t packet_count;
    char device_type[32];
};

static struct discovered_device discovered_devices[MAX_DISCOVERED_DEVICES];
static int num_discovered = 0;

/*
 * Get link status for a DPDK port
 * Returns: 1 = link up, 0 = link down, -1 = error
 */
int dpdk_get_link_status(uint16_t port_id, struct rte_eth_link *link)
{
    if (!rte_eth_dev_is_valid_port(port_id)) {
        return -1;
    }
    
    int ret = rte_eth_link_get_nowait(port_id, link);
    if (ret != 0) {
        return -1;
    }
    
    return link->link_status;
}

/*
 * Get detailed port information
 */
int dpdk_get_port_info(uint16_t port_id, char *info_buffer, size_t buf_size)
{
    struct rte_eth_link link;
    struct rte_eth_dev_info dev_info;
    struct rte_ether_addr mac_addr;
    struct rte_eth_stats stats;
    
    if (!rte_eth_dev_is_valid_port(port_id)) {
        snprintf(info_buffer, buf_size, "{\"error\":\"Invalid port\"}");
        return -1;
    }
    
    // Get link status
    int link_status = dpdk_get_link_status(port_id, &link);
    
    // Get device info
    rte_eth_dev_info_get(port_id, &dev_info);
    
    // Get MAC address
    rte_eth_macaddr_get(port_id, &mac_addr);
    
    // Get statistics
    rte_eth_stats_get(port_id, &stats);
    
    // Build JSON response
    snprintf(info_buffer, buf_size,
        "{"
        "\"port_id\":%u,"
        "\"link_status\":\"%s\","
        "\"link_speed\":%u,"
        "\"link_duplex\":\"%s\","
        "\"mac_address\":\"%02x:%02x:%02x:%02x:%02x:%02x\","
        "\"driver\":\"%s\","
        "\"rx_packets\":%lu,"
        "\"tx_packets\":%lu,"
        "\"rx_bytes\":%lu,"
        "\"tx_bytes\":%lu,"
        "\"rx_errors\":%lu,"
        "\"tx_errors\":%lu"
        "}",
        port_id,
        link_status == 1 ? "up" : "down",
        link.link_speed,
        link.link_duplex == RTE_ETH_LINK_FULL_DUPLEX ? "full" : "half",
        mac_addr.addr_bytes[0], mac_addr.addr_bytes[1], mac_addr.addr_bytes[2],
        mac_addr.addr_bytes[3], mac_addr.addr_bytes[4], mac_addr.addr_bytes[5],
        dev_info.driver_name,
        stats.ipackets,
        stats.opackets,
        stats.ibytes,
        stats.obytes,
        stats.ierrors,
        stats.oerrors
    );
    
    return 0;
}

/*
 * Get link speed in human-readable format
 */
const char* dpdk_get_link_speed_str(uint32_t speed)
{
    switch (speed) {
        case RTE_ETH_SPEED_NUM_10M:   return "10 Mbps";
        case RTE_ETH_SPEED_NUM_100M:  return "100 Mbps";
        case RTE_ETH_SPEED_NUM_1G:    return "1 Gbps";
        case RTE_ETH_SPEED_NUM_2_5G:  return "2.5 Gbps";
        case RTE_ETH_SPEED_NUM_5G:    return "5 Gbps";
        case RTE_ETH_SPEED_NUM_10G:   return "10 Gbps";
        case RTE_ETH_SPEED_NUM_20G:   return "20 Gbps";
        case RTE_ETH_SPEED_NUM_25G:   return "25 Gbps";
        case RTE_ETH_SPEED_NUM_40G:   return "40 Gbps";
        case RTE_ETH_SPEED_NUM_50G:   return "50 Gbps";
        case RTE_ETH_SPEED_NUM_56G:   return "56 Gbps";
        case RTE_ETH_SPEED_NUM_100G:  return "100 Gbps";
        case RTE_ETH_SPEED_NUM_200G:  return "200 Gbps";
        default:                       return "Unknown";
    }
}

/*
 * Inspect ARP packets to discover devices
 * Call this for each received packet
 */
void dpdk_inspect_packet_for_discovery(uint16_t port_id, struct rte_mbuf *pkt)
{
    struct rte_ether_hdr *eth_hdr;
    struct rte_arp_hdr *arp_hdr;
    
    eth_hdr = rte_pktmbuf_mtod(pkt, struct rte_ether_hdr *);
    
    // Check if it's an ARP packet
    if (eth_hdr->ether_type != rte_cpu_to_be_16(RTE_ETHER_TYPE_ARP)) {
        return;
    }
    
    arp_hdr = (struct rte_arp_hdr *)(eth_hdr + 1);
    
    // Only process ARP replies or requests
    if (arp_hdr->arp_opcode != rte_cpu_to_be_16(RTE_ARP_OP_REPLY) &&
        arp_hdr->arp_opcode != rte_cpu_to_be_16(RTE_ARP_OP_REQUEST)) {
        return;
    }
    
    // Extract source MAC and IP
    uint8_t src_mac[RTE_ETHER_ADDR_LEN];
    uint32_t src_ip;
    
    memcpy(src_mac, arp_hdr->arp_data.arp_sha.addr_bytes, RTE_ETHER_ADDR_LEN);
    src_ip = arp_hdr->arp_data.arp_sip;
    
    // Check if we already know this device
    int found = -1;
    for (int i = 0; i < num_discovered; i++) {
        if (memcmp(discovered_devices[i].mac_addr, src_mac, RTE_ETHER_ADDR_LEN) == 0) {
            found = i;
            break;
        }
    }
    
    if (found >= 0) {
        // Update existing device
        discovered_devices[found].last_seen = time(NULL);
        discovered_devices[found].packet_count++;
    } else if (num_discovered < MAX_DISCOVERED_DEVICES) {
        // Add new device
        memcpy(discovered_devices[num_discovered].mac_addr, src_mac, RTE_ETHER_ADDR_LEN);
        discovered_devices[num_discovered].ip_addr = src_ip;
        discovered_devices[num_discovered].port_id = port_id;
        discovered_devices[num_discovered].last_seen = time(NULL);
        discovered_devices[num_discovered].packet_count = 1;
        snprintf(discovered_devices[num_discovered].device_type, 32, "Unknown");
        
        printf("Discovered new device on port %u: %02x:%02x:%02x:%02x:%02x:%02x IP: %u.%u.%u.%u\n",
               port_id,
               src_mac[0], src_mac[1], src_mac[2], src_mac[3], src_mac[4], src_mac[5],
               (src_ip >> 0) & 0xFF, (src_ip >> 8) & 0xFF,
               (src_ip >> 16) & 0xFF, (src_ip >> 24) & 0xFF);
        
        num_discovered++;
    }
}

/*
 * Clean up stale discovered devices (not seen in DISCOVERY_TIMEOUT_SEC)
 */
void dpdk_cleanup_discovered_devices(void)
{
    time_t now = time(NULL);
    int i = 0;
    
    while (i < num_discovered) {
        if (now - discovered_devices[i].last_seen > DISCOVERY_TIMEOUT_SEC) {
            // Remove this device by shifting array
            memmove(&discovered_devices[i], 
                   &discovered_devices[i + 1],
                   (num_discovered - i - 1) * sizeof(struct discovered_device));
            num_discovered--;
        } else {
            i++;
        }
    }
}

/*
 * Get all discovered devices for a specific port as JSON
 */
int dpdk_get_discovered_devices(uint16_t port_id, char *json_buffer, size_t buf_size)
{
    dpdk_cleanup_discovered_devices();
    
    char *p = json_buffer;
    size_t remaining = buf_size;
    int written;
    
    written = snprintf(p, remaining, "[");
    p += written;
    remaining -= written;
    
    int count = 0;
    for (int i = 0; i < num_discovered; i++) {
        if (discovered_devices[i].port_id == port_id) {
            if (count > 0) {
                written = snprintf(p, remaining, ",");
                p += written;
                remaining -= written;
            }
            
            uint32_t ip = discovered_devices[i].ip_addr;
            written = snprintf(p, remaining,
                "{"
                "\"mac\":\"%02x:%02x:%02x:%02x:%02x:%02x\","
                "\"ip\":\"%u.%u.%u.%u\","
                "\"last_seen\":%ld,"
                "\"packet_count\":%lu,"
                "\"type\":\"%s\""
                "}",
                discovered_devices[i].mac_addr[0],
                discovered_devices[i].mac_addr[1],
                discovered_devices[i].mac_addr[2],
                discovered_devices[i].mac_addr[3],
                discovered_devices[i].mac_addr[4],
                discovered_devices[i].mac_addr[5],
                (ip >> 0) & 0xFF, (ip >> 8) & 0xFF,
                (ip >> 16) & 0xFF, (ip >> 24) & 0xFF,
                (long)discovered_devices[i].last_seen,
                discovered_devices[i].packet_count,
                discovered_devices[i].device_type
            );
            p += written;
            remaining -= written;
            count++;
        }
    }
    
    written = snprintf(p, remaining, "]");
    
    return count;
}

/*
 * Send ARP requests to probe for devices on the network
 * This actively discovers devices instead of waiting for traffic
 */
int dpdk_send_arp_probe(uint16_t port_id, uint32_t target_ip)
{
    struct rte_mbuf *pkt;
    struct rte_ether_hdr *eth_hdr;
    struct rte_arp_hdr *arp_hdr;
    struct rte_ether_addr src_mac;
    struct rte_mempool *mbuf_pool;
    
    if (!rte_eth_dev_is_valid_port(port_id)) {
        return -1;
    }
    
    // Get our MAC address
    rte_eth_macaddr_get(port_id, &src_mac);
    
    // Allocate mbuf (assuming pool named "MBUF_POOL" exists)
    // In real code, you'd pass the pool as parameter
    mbuf_pool = rte_mempool_lookup("MBUF_POOL");
    if (!mbuf_pool) {
        return -1;
    }
    
    pkt = rte_pktmbuf_alloc(mbuf_pool);
    if (!pkt) {
        return -1;
    }
    
    // Build Ethernet header
    eth_hdr = rte_pktmbuf_mtod(pkt, struct rte_ether_hdr *);
    memset(eth_hdr->dst_addr.addr_bytes, 0xFF, RTE_ETHER_ADDR_LEN);  // Broadcast
    rte_ether_addr_copy(&src_mac, &eth_hdr->src_addr);
    eth_hdr->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_ARP);
    
    // Build ARP header
    arp_hdr = (struct rte_arp_hdr *)(eth_hdr + 1);
    arp_hdr->arp_hardware = rte_cpu_to_be_16(RTE_ARP_HRD_ETHER);
    arp_hdr->arp_protocol = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    arp_hdr->arp_hlen = RTE_ETHER_ADDR_LEN;
    arp_hdr->arp_plen = 4;
    arp_hdr->arp_opcode = rte_cpu_to_be_16(RTE_ARP_OP_REQUEST);
    
    rte_ether_addr_copy(&src_mac, &arp_hdr->arp_data.arp_sha);
    arp_hdr->arp_data.arp_sip = 0;  // We don't have an IP (we're just a traffic generator)
    
    memset(arp_hdr->arp_data.arp_tha.addr_bytes, 0, RTE_ETHER_ADDR_LEN);
    arp_hdr->arp_data.arp_tip = target_ip;
    
    pkt->data_len = sizeof(struct rte_ether_hdr) + sizeof(struct rte_arp_hdr);
    pkt->pkt_len = pkt->data_len;
    
    // Send packet
    uint16_t sent = rte_eth_tx_burst(port_id, 0, &pkt, 1);
    
    if (sent == 0) {
        rte_pktmbuf_free(pkt);
        return -1;
    }
    
    return 0;
}

/*
 * Scan subnet for devices by sending ARP probes
 * e.g., scan 192.168.1.0/24
 */
int dpdk_scan_subnet(uint16_t port_id, uint32_t base_ip, uint8_t prefix_len)
{
    uint32_t num_hosts = (1 << (32 - prefix_len)) - 2;  // -2 for network and broadcast
    
    if (num_hosts > 1024) {
        num_hosts = 1024;  // Limit scan size
    }
    
    printf("Scanning %u hosts on port %u...\n", num_hosts, port_id);
    
    for (uint32_t i = 1; i <= num_hosts; i++) {
        uint32_t target_ip = base_ip + rte_cpu_to_be_32(i);
        dpdk_send_arp_probe(port_id, target_ip);
        
        // Small delay to avoid overwhelming the network
        if (i % 10 == 0) {
            rte_delay_us(1000);  // 1ms delay every 10 probes
        }
    }
    
    return 0;
}

/*
 * Get all port statuses as JSON
 */
int dpdk_get_all_port_status(char *json_buffer, size_t buf_size)
{
    char *p = json_buffer;
    size_t remaining = buf_size;
    int written;
    
    uint16_t num_ports = rte_eth_dev_count_avail();
    
    written = snprintf(p, remaining, "{\"ports\":[");
    p += written;
    remaining -= written;
    
    uint16_t port_id;
    int count = 0;
    
    RTE_ETH_FOREACH_DEV(port_id) {
        if (count > 0) {
            written = snprintf(p, remaining, ",");
            p += written;
            remaining -= written;
        }
        
        char port_info[1024];
        dpdk_get_port_info(port_id, port_info, sizeof(port_info));
        
        written = snprintf(p, remaining, "%s", port_info);
        p += written;
        remaining -= written;
        
        count++;
    }
    
    written = snprintf(p, remaining, "]}");
    
    return count;
}
