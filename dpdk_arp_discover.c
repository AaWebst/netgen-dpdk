/*
 * DPDK ARP Discovery Tool
 * Sends ARP requests on DPDK-bound interfaces to discover connected devices
 * 
 * Compile: gcc -O3 dpdk_arp_discover.c -o dpdk_arp_discover $(pkg-config --cflags --libs libdpdk)
 * Usage: sudo ./dpdk_arp_discover <port_id> <target_ip>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_ether.h>
#include <rte_arp.h>

#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 1
#define RX_RING_SIZE 128
#define TX_RING_SIZE 512

// ARP packet structure
struct arp_packet {
    struct rte_ether_hdr eth;
    struct rte_arp_hdr arp;
} __attribute__((packed));

static struct rte_mempool *mbuf_pool = NULL;

// Send ARP request
static int send_arp_request(uint16_t port_id, uint32_t src_ip, uint32_t dst_ip) {
    struct rte_mbuf *pkt;
    struct arp_packet *arp_pkt;
    struct rte_ether_addr src_mac;
    
    // Get port MAC address
    rte_eth_macaddr_get(port_id, &src_mac);
    
    // Allocate mbuf
    pkt = rte_pktmbuf_alloc(mbuf_pool);
    if (!pkt) {
        fprintf(stderr, "Failed to allocate mbuf\n");
        return -1;
    }
    
    // Build ARP request
    arp_pkt = rte_pktmbuf_mtod(pkt, struct arp_packet *);
    
    // Ethernet header (broadcast)
    memset(&arp_pkt->eth.dst_addr, 0xFF, RTE_ETHER_ADDR_LEN);
    rte_ether_addr_copy(&src_mac, &arp_pkt->eth.src_addr);
    arp_pkt->eth.ether_type = htons(RTE_ETHER_TYPE_ARP);
    
    // ARP header
    arp_pkt->arp.arp_hardware = htons(RTE_ARP_HRD_ETHER);
    arp_pkt->arp.arp_protocol = htons(RTE_ETHER_TYPE_IPV4);
    arp_pkt->arp.arp_hlen = RTE_ETHER_ADDR_LEN;
    arp_pkt->arp.arp_plen = 4;
    arp_pkt->arp.arp_opcode = htons(RTE_ARP_OP_REQUEST);
    
    // Source MAC and IP
    rte_ether_addr_copy(&src_mac, &arp_pkt->arp.arp_data.arp_sha);
    arp_pkt->arp.arp_data.arp_sip = htonl(src_ip);
    
    // Target MAC (unknown, set to 0) and IP
    memset(&arp_pkt->arp.arp_data.arp_tha, 0, RTE_ETHER_ADDR_LEN);
    arp_pkt->arp.arp_data.arp_tip = htonl(dst_ip);
    
    // Set packet length
    pkt->data_len = sizeof(struct arp_packet);
    pkt->pkt_len = sizeof(struct arp_packet);
    
    // Send packet
    uint16_t nb_tx = rte_eth_tx_burst(port_id, 0, &pkt, 1);
    
    if (nb_tx == 0) {
        rte_pktmbuf_free(pkt);
        return -1;
    }
    
    return 0;
}

// Receive and process ARP replies
static int receive_arp_replies(uint16_t port_id, uint32_t target_ip, int timeout_ms) {
    struct rte_mbuf *pkts[BURST_SIZE];
    int found = 0;
    int iterations = timeout_ms / 10;  // 10ms per iteration
    
    for (int i = 0; i < iterations && !found; i++) {
        uint16_t nb_rx = rte_eth_rx_burst(port_id, 0, pkts, BURST_SIZE);
        
        for (uint16_t j = 0; j < nb_rx; j++) {
            struct arp_packet *arp_pkt = rte_pktmbuf_mtod(pkts[j], struct arp_packet *);
            
            // Check if it's an ARP reply
            if (ntohs(arp_pkt->eth.ether_type) == RTE_ETHER_TYPE_ARP &&
                ntohs(arp_pkt->arp.arp_opcode) == RTE_ARP_OP_REPLY &&
                ntohl(arp_pkt->arp.arp_data.arp_sip) == target_ip) {
                
                // Found the device!
                printf("FOUND:%d.%d.%d.%d:%02x:%02x:%02x:%02x:%02x:%02x\n",
                    (target_ip >> 24) & 0xFF,
                    (target_ip >> 16) & 0xFF,
                    (target_ip >> 8) & 0xFF,
                    target_ip & 0xFF,
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[0],
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[1],
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[2],
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[3],
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[4],
                    arp_pkt->arp.arp_data.arp_sha.addr_bytes[5]);
                
                found = 1;
            }
            
            rte_pktmbuf_free(pkts[j]);
        }
        
        if (!found) {
            rte_delay_ms(10);
        }
    }
    
    return found ? 0 : -1;
}

int main(int argc, char **argv) {
    int ret;
    uint16_t port_id;
    uint32_t src_ip, dst_ip;
    
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <port_id> <target_ip> [source_ip]\n", argv[0]);
        fprintf(stderr, "Example: %s 0 192.168.1.1 192.168.1.100\n", argv[0]);
        return 1;
    }
    
    port_id = atoi(argv[1]);
    
    // Parse target IP
    struct in_addr addr;
    if (inet_pton(AF_INET, argv[2], &addr) != 1) {
        fprintf(stderr, "Invalid target IP\n");
        return 1;
    }
    dst_ip = ntohl(addr.s_addr);
    
    // Parse or generate source IP
    if (argc >= 4) {
        if (inet_pton(AF_INET, argv[3], &addr) != 1) {
            fprintf(stderr, "Invalid source IP\n");
            return 1;
        }
        src_ip = ntohl(addr.s_addr);
    } else {
        // Use same subnet as target, but .100
        src_ip = (dst_ip & 0xFFFFFF00) | 100;
    }
    
    // Initialize DPDK
    ret = rte_eal_init(argc, argv);
    if (ret < 0) {
        fprintf(stderr, "DPDK EAL init failed\n");
        return 1;
    }
    
    // Create mbuf pool
    mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS,
        MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
    
    if (!mbuf_pool) {
        fprintf(stderr, "Cannot create mbuf pool\n");
        return 1;
    }
    
    // Configure port
    struct rte_eth_conf port_conf = {0};
    ret = rte_eth_dev_configure(port_id, 1, 1, &port_conf);
    if (ret < 0) {
        fprintf(stderr, "Cannot configure port %u\n", port_id);
        return 1;
    }
    
    // Setup RX queue
    ret = rte_eth_rx_queue_setup(port_id, 0, RX_RING_SIZE,
        rte_eth_dev_socket_id(port_id), NULL, mbuf_pool);
    if (ret < 0) {
        fprintf(stderr, "Cannot setup RX queue\n");
        return 1;
    }
    
    // Setup TX queue
    ret = rte_eth_tx_queue_setup(port_id, 0, TX_RING_SIZE,
        rte_eth_dev_socket_id(port_id), NULL);
    if (ret < 0) {
        fprintf(stderr, "Cannot setup TX queue\n");
        return 1;
    }
    
    // Start port
    ret = rte_eth_dev_start(port_id);
    if (ret < 0) {
        fprintf(stderr, "Cannot start port %u\n", port_id);
        return 1;
    }
    
    // Set promiscuous mode
    rte_eth_promiscuous_enable(port_id);
    
    // Send ARP request
    printf("Sending ARP request for %s on port %u...\n", argv[2], port_id);
    
    for (int i = 0; i < 3; i++) {  // Try 3 times
        send_arp_request(port_id, src_ip, dst_ip);
        
        if (receive_arp_replies(port_id, dst_ip, 1000) == 0) {
            // Success
            rte_eth_dev_stop(port_id);
            return 0;
        }
    }
    
    printf("NOT_FOUND\n");
    
    rte_eth_dev_stop(port_id);
    return 1;
}
