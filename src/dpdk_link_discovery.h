/*
 * NetGen Pro - DPDK Link Status & Device Discovery Header
 */

#ifndef DPDK_LINK_DISCOVERY_H
#define DPDK_LINK_DISCOVERY_H

#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <stdint.h>
#include <stddef.h>

/*
 * Get link status for a DPDK port
 * Returns: 1 = link up, 0 = link down, -1 = error
 */
int dpdk_get_link_status(uint16_t port_id, struct rte_eth_link *link);

/*
 * Get detailed port information as JSON
 * Buffer should be at least 1024 bytes
 */
int dpdk_get_port_info(uint16_t port_id, char *info_buffer, size_t buf_size);

/*
 * Get link speed in human-readable format
 */
const char* dpdk_get_link_speed_str(uint32_t speed);

/*
 * Inspect received packet for device discovery
 * Call this for every RX packet in your main loop
 */
void dpdk_inspect_packet_for_discovery(uint16_t port_id, struct rte_mbuf *pkt);

/*
 * Clean up stale discovered devices
 * Call periodically (e.g., every 60 seconds)
 */
void dpdk_cleanup_discovered_devices(void);

/*
 * Get all discovered devices on a port as JSON
 * Returns number of devices found
 */
int dpdk_get_discovered_devices(uint16_t port_id, char *json_buffer, size_t buf_size);

/*
 * Send ARP probe to discover a specific device
 * target_ip should be in network byte order
 */
int dpdk_send_arp_probe(uint16_t port_id, uint32_t target_ip);

/*
 * Scan entire subnet for devices
 * base_ip: Network address in network byte order (e.g., 192.168.1.0)
 * prefix_len: CIDR prefix (e.g., 24 for /24)
 */
int dpdk_scan_subnet(uint16_t port_id, uint32_t base_ip, uint8_t prefix_len);

/*
 * Get status of all ports as JSON
 * Buffer should be large enough for all ports (suggest 4096 bytes minimum)
 */
int dpdk_get_all_port_status(char *json_buffer, size_t buf_size);

#endif /* DPDK_LINK_DISCOVERY_H */
