/*
 * NetGen Pro v4.0 - Performance Optimizations Implementation
 * Multi-Core, NUMA, Zero-Copy, Batching, Hardware Offloads
 */

#include "dpdk_engine_v4.h"
#include <rte_errno.h>
#include <rte_memzone.h>
#include <rte_malloc.h>

// ============================================================================
// MULTI-CORE SCALING
// ============================================================================

static struct worker_thread workers[MAX_WORKER_CORES];
static unsigned num_workers = 0;

int assign_worker_threads(void) {
    unsigned lcore_id;
    unsigned socket_id;
    num_workers = 0;
    
    RTE_LCORE_FOREACH_WORKER(lcore_id) {
        if (num_workers >= MAX_WORKER_CORES) break;
        
        socket_id = rte_lcore_to_socket_id(lcore_id);
        
        workers[num_workers].lcore_id = lcore_id;
        workers[num_workers].numa_node = socket_id;
        workers[num_workers].packets_processed = 0;
        workers[num_workers].bytes_processed = 0;
        workers[num_workers].cycles_used = 0;
        
        // Create per-core rings for lock-free communication
        char ring_name[32];
        snprintf(ring_name, sizeof(ring_name), "tx_ring_%u", lcore_id);
        workers[num_workers].tx_ring = rte_ring_create(ring_name, 
                                                        4096, 
                                                        socket_id, 
                                                        RING_F_SP_ENQ | RING_F_SC_DEQ);
        
        snprintf(ring_name, sizeof(ring_name), "rx_ring_%u", lcore_id);
        workers[num_workers].rx_ring = rte_ring_create(ring_name, 
                                                        4096, 
                                                        socket_id, 
                                                        RING_F_SP_ENQ | RING_F_SC_DEQ);
        
        if (!workers[num_workers].tx_ring || !workers[num_workers].rx_ring) {
            printf("Failed to create rings for lcore %u\n", lcore_id);
            return -1;
        }
        
        num_workers++;
    }
    
    printf("Assigned %u worker threads across NUMA nodes\n", num_workers);
    return num_workers;
}

int worker_thread_main(void *arg) {
    struct worker_thread *worker = (struct worker_thread*)arg;
    unsigned lcore_id = worker->lcore_id;
    
    printf("Worker thread started on lcore %u (NUMA %d)\n", 
           lcore_id, worker->numa_node);
    
    struct rte_mbuf *bufs[BURST_SIZE];
    struct rte_mbuf *tx_bufs[BURST_SIZE];
    uint64_t start_cycles = rte_rdtsc();
    
    while (running) {
        // RX Processing
        if (worker->is_rx) {
            uint16_t nb_rx = rte_eth_rx_burst(worker->port_id, 0, bufs, BURST_SIZE);
            
            if (nb_rx > 0) {
                // Prefetch packets for better cache utilization
                for (int i = 0; i < nb_rx && i < PREFETCH_OFFSET; i++) {
                    rte_prefetch0(rte_pktmbuf_mtod(bufs[i], void *));
                }
                
                // Process packets
                for (uint16_t i = 0; i < nb_rx; i++) {
                    // Prefetch next packet
                    if (i + PREFETCH_OFFSET < nb_rx) {
                        rte_prefetch0(rte_pktmbuf_mtod(bufs[i + PREFETCH_OFFSET], void *));
                    }
                    
                    worker->packets_processed++;
                    worker->bytes_processed += rte_pktmbuf_pkt_len(bufs[i]);
                    
                    // Process packet (analysis, timestamping, etc.)
                    // ... packet processing logic ...
                }
                
                // Free processed packets
                rte_pktmbuf_free_bulk(bufs, nb_rx);
            }
        }
        
        // TX Processing
        if (worker->is_tx) {
            // Dequeue packets from ring (populated by main thread)
            uint16_t nb_dequeued = rte_ring_dequeue_burst(worker->tx_ring, 
                                                          (void**)tx_bufs, 
                                                          BURST_SIZE, 
                                                          NULL);
            
            if (nb_dequeued > 0) {
                // Send in batches for better efficiency
                uint16_t nb_tx = rte_eth_tx_burst(worker->port_id, 0, 
                                                  tx_bufs, nb_dequeued);
                
                worker->packets_processed += nb_tx;
                
                // Free unsent packets
                if (unlikely(nb_tx < nb_dequeued)) {
                    for (uint16_t i = nb_tx; i < nb_dequeued; i++) {
                        rte_pktmbuf_free(tx_bufs[i]);
                    }
                }
            }
        }
    }
    
    worker->cycles_used = rte_rdtsc() - start_cycles;
    return 0;
}

// ============================================================================
// NUMA AWARENESS
// ============================================================================

static struct numa_config numa_configs[RTE_MAX_NUMA_NODES];

int init_numa_config(void) {
    int num_numa_nodes = rte_socket_count();
    
    for (int socket_id = 0; socket_id < num_numa_nodes; socket_id++) {
        // Create mempool on each NUMA node
        char pool_name[32];
        snprintf(pool_name, sizeof(pool_name), "mbuf_pool_%d", socket_id);
        
        numa_configs[socket_id].mbuf_pool = rte_pktmbuf_pool_create(
            pool_name,
            NUM_MBUFS,
            MBUF_CACHE_SIZE,
            0,
            RTE_MBUF_DEFAULT_BUF_SIZE,
            socket_id
        );
        
        if (!numa_configs[socket_id].mbuf_pool) {
            printf("Failed to create mempool on NUMA node %d\n", socket_id);
            return -1;
        }
        
        numa_configs[socket_id].numa_node = socket_id;
        numa_configs[socket_id].socket_id = socket_id;
        numa_configs[socket_id].initialized = true;
        
        printf("Created mempool on NUMA node %d with %u mbufs\n", 
               socket_id, NUM_MBUFS);
    }
    
    return 0;
}

struct rte_mempool* get_mempool_for_port(uint16_t port_id) {
    int socket_id = rte_eth_dev_socket_id(port_id);
    
    if (socket_id == SOCKET_ID_ANY) {
        socket_id = 0;
    }
    
    if (socket_id >= 0 && socket_id < RTE_MAX_NUMA_NODES) {
        if (numa_configs[socket_id].initialized) {
            return numa_configs[socket_id].mbuf_pool;
        }
    }
    
    // Fallback to socket 0
    return numa_configs[0].mbuf_pool;
}

// ============================================================================
// ZERO-COPY OPERATIONS
// ============================================================================

struct packet_context* get_packet_context(struct rte_mbuf *mbuf) {
    // Allocate context on stack (no heap allocation)
    static __thread struct packet_context ctx;
    
    ctx.mbuf = mbuf;
    ctx.packet_data = rte_pktmbuf_mtod(mbuf, void*);
    ctx.data_len = rte_pktmbuf_data_len(mbuf);
    
    // Direct pointers to packet headers (no copying)
    ctx.l2_header = (uint8_t*)ctx.packet_data;
    ctx.l3_header = ctx.l2_header + sizeof(struct rte_ether_hdr);
    ctx.l4_header = ctx.l3_header + sizeof(struct rte_ipv4_hdr);
    ctx.payload = ctx.l4_header + sizeof(struct rte_udp_hdr);
    
    return &ctx;
}

void build_packet_zerocopy(struct packet_context *ctx, struct traffic_profile_v4 *prof) {
    // Work directly with packet memory - no memcpy!
    struct rte_ether_hdr *eth = (struct rte_ether_hdr*)ctx->l2_header;
    struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)ctx->l3_header;
    struct rte_udp_hdr *udp = (struct rte_udp_hdr*)ctx->l4_header;
    
    // In-place modification (zero-copy)
    eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    
    ip->version_ihl = 0x45;
    ip->total_length = rte_cpu_to_be_16(prof->packet_size - sizeof(struct rte_ether_hdr));
    ip->src_addr = rte_cpu_to_be_32(prof->src_ip);
    ip->dst_addr = rte_cpu_to_be_32(prof->dst_ip);
    ip->next_proto_id = IPPROTO_UDP;
    
    // If checksum offload enabled, mark for hardware
    if (ctx->mbuf->ol_flags & RTE_MBUF_F_TX_IP_CKSUM) {
        ip->hdr_checksum = 0;  // HW will calculate
        ctx->mbuf->l2_len = sizeof(struct rte_ether_hdr);
        ctx->mbuf->l3_len = sizeof(struct rte_ipv4_hdr);
    } else {
        ip->hdr_checksum = rte_ipv4_cksum(ip);
    }
    
    udp->src_port = rte_cpu_to_be_16(prof->src_port);
    udp->dst_port = rte_cpu_to_be_16(prof->dst_port);
    udp->dgram_len = rte_cpu_to_be_16(prof->packet_size - 
                                      sizeof(struct rte_ether_hdr) - 
                                      sizeof(struct rte_ipv4_hdr));
    
    // If UDP checksum offload enabled
    if (ctx->mbuf->ol_flags & RTE_MBUF_F_TX_UDP_CKSUM) {
        udp->dgram_cksum = 0;  // HW will calculate
        ctx->mbuf->l4_len = sizeof(struct rte_udp_hdr);
    }
    
    ctx->mbuf->pkt_len = prof->packet_size;
    ctx->mbuf->data_len = prof->packet_size;
}

// ============================================================================
// HARDWARE OFFLOADS
// ============================================================================

int enable_hw_offloads(uint16_t port_id, struct hw_offload_config *config) {
    struct rte_eth_dev_info dev_info;
    struct rte_eth_conf port_conf = {0};
    
    rte_eth_dev_info_get(port_id, &dev_info);
    
    // TX Offloads
    if (config->tx_checksum_offload) {
        if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_IPV4_CKSUM) {
            port_conf.txmode.offloads |= RTE_ETH_TX_OFFLOAD_IPV4_CKSUM;
            printf("Port %u: TX IPv4 checksum offload enabled\n", port_id);
        }
        if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_UDP_CKSUM) {
            port_conf.txmode.offloads |= RTE_ETH_TX_OFFLOAD_UDP_CKSUM;
            printf("Port %u: TX UDP checksum offload enabled\n", port_id);
        }
        if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_TCP_CKSUM) {
            port_conf.txmode.offloads |= RTE_ETH_TX_OFFLOAD_TCP_CKSUM;
            printf("Port %u: TX TCP checksum offload enabled\n", port_id);
        }
    }
    
    // TSO (TCP Segmentation Offload)
    if (config->tso_enabled) {
        if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_TCP_TSO) {
            port_conf.txmode.offloads |= RTE_ETH_TX_OFFLOAD_TCP_TSO;
            printf("Port %u: TSO enabled\n", port_id);
        }
    }
    
    // RX Offloads
    if (config->rx_checksum_offload) {
        if (dev_info.rx_offload_capa & RTE_ETH_RX_OFFLOAD_CHECKSUM) {
            port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_CHECKSUM;
            printf("Port %u: RX checksum offload enabled\n", port_id);
        }
    }
    
    // VLAN Offload
    if (config->vlan_offload) {
        if (dev_info.rx_offload_capa & RTE_ETH_RX_OFFLOAD_VLAN_STRIP) {
            port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_VLAN_STRIP;
        }
        if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_VLAN_INSERT) {
            port_conf.txmode.offloads |= RTE_ETH_TX_OFFLOAD_VLAN_INSERT;
        }
        printf("Port %u: VLAN offload enabled\n", port_id);
    }
    
    // Jumbo Frames
    if (config->jumbo_frames) {
        if (dev_info.max_rx_pktlen >= config->max_rx_pkt_len) {
            port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_JUMBO_FRAME;
            port_conf.rxmode.mtu = config->max_rx_pkt_len - 
                                   RTE_ETHER_HDR_LEN - RTE_ETHER_CRC_LEN;
            printf("Port %u: Jumbo frames enabled (MTU %u)\n", 
                   port_id, port_conf.rxmode.mtu);
        }
    }
    
    // Multi-segment (scatter-gather)
    if (dev_info.rx_offload_capa & RTE_ETH_RX_OFFLOAD_SCATTER) {
        port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_SCATTER;
    }
    
    // Reconfigure port with new offloads
    int ret = rte_eth_dev_configure(port_id, 1, 1, &port_conf);
    if (ret < 0) {
        printf("Failed to configure offloads on port %u: %s\n", 
               port_id, rte_strerror(-ret));
        return ret;
    }
    
    return 0;
}

int configure_rss(uint16_t port_id, uint16_t num_queues) {
    struct rte_eth_dev_info dev_info;
    struct rte_eth_conf port_conf = {0};
    
    rte_eth_dev_info_get(port_id, &dev_info);
    
    if (!(dev_info.rx_offload_capa & RTE_ETH_RX_OFFLOAD_RSS_HASH)) {
        printf("Port %u does not support RSS\n", port_id);
        return -1;
    }
    
    // Configure RSS
    port_conf.rxmode.mq_mode = RTE_ETH_MQ_RX_RSS;
    port_conf.rx_adv_conf.rss_conf.rss_key = NULL;  // Use default key
    port_conf.rx_adv_conf.rss_conf.rss_hf = RTE_ETH_RSS_IP | 
                                             RTE_ETH_RSS_TCP | 
                                             RTE_ETH_RSS_UDP;
    
    int ret = rte_eth_dev_configure(port_id, num_queues, 1, &port_conf);
    if (ret < 0) {
        printf("Failed to configure RSS on port %u: %s\n", 
               port_id, rte_strerror(-ret));
        return ret;
    }
    
    printf("Port %u: RSS enabled with %u queues\n", port_id, num_queues);
    return 0;
}

// ============================================================================
// BATCHING OPTIMIZATIONS
// ============================================================================

// Batch packet allocation
static inline int alloc_packet_batch(struct rte_mempool *pool, 
                                     struct rte_mbuf **mbufs, 
                                     uint16_t count) {
    // Allocate multiple mbufs at once (more efficient)
    int ret = rte_pktmbuf_alloc_bulk(pool, mbufs, count);
    
    if (ret == 0) {
        // Prefetch allocated mbufs
        for (uint16_t i = 0; i < count && i < PREFETCH_OFFSET; i++) {
            rte_prefetch0(mbufs[i]);
        }
    }
    
    return ret;
}

// Batch packet transmission
static inline uint16_t send_packet_batch(uint16_t port_id, 
                                         uint16_t queue_id,
                                         struct rte_mbuf **tx_pkts, 
                                         uint16_t nb_pkts) {
    uint16_t nb_tx = 0;
    uint16_t nb_sent;
    
    // Send in bursts, retry if needed
    while (nb_tx < nb_pkts) {
        nb_sent = rte_eth_tx_burst(port_id, queue_id, 
                                   &tx_pkts[nb_tx], 
                                   nb_pkts - nb_tx);
        nb_tx += nb_sent;
        
        if (unlikely(nb_sent == 0)) {
            break;  // TX queue full
        }
    }
    
    return nb_tx;
}

// ============================================================================
// PERFORMANCE MONITORING
// ============================================================================

void print_performance_stats(void) {
    printf("\n=== Performance Statistics ===\n");
    
    for (unsigned i = 0; i < num_workers; i++) {
        struct worker_thread *w = &workers[i];
        
        double cycles_per_packet = w->packets_processed > 0 ? 
                                  (double)w->cycles_used / w->packets_processed : 0;
        
        printf("Worker %u (lcore %u, NUMA %d):\n", 
               i, w->lcore_id, w->numa_node);
        printf("  Packets: %lu\n", w->packets_processed);
        printf("  Bytes: %lu\n", w->bytes_processed);
        printf("  Cycles/Packet: %.2f\n", cycles_per_packet);
    }
}
