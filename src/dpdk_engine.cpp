/*
 * NetGen Pro - Complete DPDK Engine (FIXED VERSION)
 * TX TIMING BUG FIX APPLIED
 * 
 * Fix: Added inter_packet_gap_cycles to prevent overflow in TX loop
 */

#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <rte_tcp.h>
#include <rte_udp.h>
#include <rte_icmp.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_ring.h>
#include <rte_hash.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <json-c/json.h>
#include <map>
#include <vector>
#include <string>
#include <cmath>
#include <random>

#define RX_RING_SIZE 2048
#define TX_RING_SIZE 2048
#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 64
#define MAX_PROFILES 64
#define PAYLOAD_OFFSET 42

// Protocol types
enum protocol_type {
    PROTO_UDP = 0,
    PROTO_TCP = 1,
    PROTO_ICMP = 2
};

// Payload types
enum payload_type {
    PAYLOAD_RANDOM = 0,
    PAYLOAD_ZEROS = 1,
    PAYLOAD_ONES = 2,
    PAYLOAD_INCREMENT = 3,
    PAYLOAD_CUSTOM = 4
};

// Traffic profile structure (FIXED: added inter_packet_gap_cycles)
struct traffic_profile {
    char name[64];
    uint32_t dst_ip;
    bool use_ipv6;
    
    uint16_t dst_port;
    uint16_t src_port_min;
    uint16_t src_port_max;
    
    uint8_t protocol;
    uint16_t packet_size;
    double rate_mbps;
    uint32_t burst_size;
    uint64_t inter_packet_gap_ns;       // Nanoseconds (for reference)
    uint64_t inter_packet_gap_cycles;   // TSC cycles (CRITICAL FIX!)
    
    // VLAN & QoS
    uint16_t vlan_id;
    bool vlan_enabled;
    uint8_t dscp;
    
    // Payload
    uint8_t payload_type;
    uint8_t custom_payload[1400];
    uint16_t custom_payload_len;
    
    // Statistics
    uint64_t packets_sent;
    uint64_t bytes_sent;
    uint64_t packets_dropped;
    uint32_t sequence_num;
    uint16_t stream_id;
};

// Global state
static struct rte_mempool *mbuf_pool = NULL;
static traffic_profile profiles[MAX_PROFILES];
static int num_profiles = 0;
static volatile bool force_quit = false;
static volatile bool running = false;
static int tx_port = 0;
static int rx_port = 1;
static bool dual_port_mode = false;

// RX statistics
struct rx_stats {
    uint64_t packets_received;
    uint64_t bytes_received;
    uint64_t out_of_order;
    uint64_t duplicates;
    uint64_t late_arrivals;
    uint64_t min_latency_ns;
    uint64_t max_latency_ns;
    uint64_t sum_latency_ns;
    uint64_t latency_count;
    uint64_t expected_seq;
    uint64_t lost_packets;
};

static rx_stats rx_statistics;
static std::map<uint32_t, uint64_t> tx_timestamp_map;
static pthread_mutex_t timestamp_map_mutex = PTHREAD_MUTEX_INITIALIZER;

// Packet building
struct rte_mbuf* build_packet(traffic_profile *prof) {
    struct rte_mbuf *pkt = rte_pktmbuf_alloc(mbuf_pool);
    if (!pkt) return NULL;
    
    uint8_t *pkt_data = rte_pktmbuf_mtod(pkt, uint8_t*);
    uint16_t offset = 0;
    
    // Ethernet header
    struct rte_ether_hdr *eth = (struct rte_ether_hdr*)pkt_data;
    static const struct rte_ether_addr default_src_mac = {{0x00,0x11,0x22,0x33,0x44,0x55}};
    static const struct rte_ether_addr default_dst_mac = {{0x00,0xAA,0xBB,0xCC,0xDD,0xEE}};
    rte_ether_addr_copy(&default_src_mac, &eth->src_addr);
    rte_ether_addr_copy(&default_dst_mac, &eth->dst_addr);
    eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    offset = sizeof(struct rte_ether_hdr);
    
    // IP header
    struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)(pkt_data + offset);
    ip->version_ihl = 0x45;
    ip->type_of_service = prof->dscp << 2;
    ip->total_length = rte_cpu_to_be_16(prof->packet_size - offset);
    ip->packet_id = 0;
    ip->fragment_offset = 0;
    ip->time_to_live = 64;
    ip->next_proto_id = prof->protocol == PROTO_UDP ? IPPROTO_UDP :
                       prof->protocol == PROTO_TCP ? IPPROTO_TCP : IPPROTO_ICMP;
    ip->src_addr = rte_cpu_to_be_32(0xC0A80101);  // 192.168.1.1
    ip->dst_addr = rte_cpu_to_be_32(prof->dst_ip);
    ip->hdr_checksum = 0;
    ip->hdr_checksum = rte_ipv4_cksum(ip);
    offset += sizeof(struct rte_ipv4_hdr);
    
    // Transport header + payload
    uint16_t payload_len = prof->packet_size - offset;
    
    if (prof->protocol == PROTO_UDP) {
        struct rte_udp_hdr *udp = (struct rte_udp_hdr*)(pkt_data + offset);
        uint16_t src_port = prof->src_port_min + (rand() % (prof->src_port_max - prof->src_port_min + 1));
        udp->src_port = rte_cpu_to_be_16(src_port);
        udp->dst_port = rte_cpu_to_be_16(prof->dst_port);
        udp->dgram_len = rte_cpu_to_be_16(payload_len);
        udp->dgram_cksum = 0;
        offset += sizeof(struct rte_udp_hdr);
        
        // Payload
        uint8_t *payload = pkt_data + offset;
        uint16_t payload_data_len = payload_len - sizeof(struct rte_udp_hdr);
        
        switch (prof->payload_type) {
            case PAYLOAD_RANDOM:
                for (int i = 0; i < payload_data_len; i++) payload[i] = rand() % 256;
                break;
            case PAYLOAD_ZEROS:
                memset(payload, 0, payload_data_len);
                break;
            case PAYLOAD_ONES:
                memset(payload, 0xFF, payload_data_len);
                break;
            case PAYLOAD_INCREMENT:
                for (int i = 0; i < payload_data_len; i++) payload[i] = i % 256;
                break;
            case PAYLOAD_CUSTOM:
                memcpy(payload, prof->custom_payload, 
                       payload_data_len < prof->custom_payload_len ? payload_data_len : prof->custom_payload_len);
                break;
        }
    } else if (prof->protocol == PROTO_TCP) {
        struct rte_tcp_hdr *tcp = (struct rte_tcp_hdr*)(pkt_data + offset);
        uint16_t src_port = prof->src_port_min + (rand() % (prof->src_port_max - prof->src_port_min + 1));
        tcp->src_port = rte_cpu_to_be_16(src_port);
        tcp->dst_port = rte_cpu_to_be_16(prof->dst_port);
        tcp->sent_seq = rte_cpu_to_be_32(prof->sequence_num);
        tcp->recv_ack = 0;
        tcp->data_off = 5 << 4;
        tcp->tcp_flags = 0x02;  // SYN
        tcp->rx_win = rte_cpu_to_be_16(65535);
        tcp->cksum = 0;
        tcp->tcp_urp = 0;
        offset += sizeof(struct rte_tcp_hdr);
    } else if (prof->protocol == PROTO_ICMP) {
        struct rte_icmp_hdr *icmp = (struct rte_icmp_hdr*)(pkt_data + offset);
        icmp->icmp_type = 8;  // Echo request
        icmp->icmp_code = 0;
        icmp->icmp_cksum = 0;
        icmp->icmp_ident = rte_cpu_to_be_16(prof->stream_id);
        icmp->icmp_seq_nb = rte_cpu_to_be_16(prof->sequence_num);
        offset += sizeof(struct rte_icmp_hdr);
    }
    
    pkt->data_len = prof->packet_size;
    pkt->pkt_len = prof->packet_size;
    
    prof->sequence_num++;
    return pkt;
}

// TX thread (FIXED: uses pre-calculated cycles)
int tx_thread_main(__rte_unused void *arg) {
    printf("TX thread started on lcore %u\n", rte_lcore_id());
    
    uint64_t next_send_time[MAX_PROFILES] = {0};
    
    while (running && !force_quit) {
        uint64_t now = rte_get_tsc_cycles();
        
        for (int i = 0; i < num_profiles; i++) {
            if (now < next_send_time[i]) continue;
            
            traffic_profile *prof = &profiles[i];
            
            // Build packet
            struct rte_mbuf *pkt = build_packet(prof);
            if (!pkt) {
                prof->packets_dropped++;
                continue;
            }
            
            // Send packet
            uint16_t nb_tx = rte_eth_tx_burst(tx_port, 0, &pkt, 1);
            
            if (nb_tx == 0) {
                rte_pktmbuf_free(pkt);
                prof->packets_dropped++;
            } else {
                prof->packets_sent++;
                prof->bytes_sent += prof->packet_size;
            }
            
            // CRITICAL FIX: Use pre-calculated cycles to avoid overflow
            next_send_time[i] = now + prof->inter_packet_gap_cycles;
        }
    }
    
    printf("TX thread stopped\n");
    return 0;
}

// RX thread
int rx_thread_main(__rte_unused void *arg) {
    printf("RX thread started on lcore %u\n", rte_lcore_id());
    
    struct rte_mbuf *bufs[BURST_SIZE];
    
    while (running && !force_quit) {
        uint16_t nb_rx = rte_eth_rx_burst(rx_port, 0, bufs, BURST_SIZE);
        
        if (nb_rx == 0) {
            continue;
        }
        
        for (int i = 0; i < nb_rx; i++) {
            rx_statistics.packets_received++;
            rx_statistics.bytes_received += bufs[i]->pkt_len;
            rte_pktmbuf_free(bufs[i]);
        }
    }
    
    printf("RX thread stopped\n");
    return 0;
}

// Port initialization
int init_port(uint16_t port, struct rte_mempool *mbuf_pool, bool enable_rx) {
    struct rte_eth_conf port_conf = {};
    port_conf.rxmode.max_lro_pkt_size = RTE_ETHER_MAX_LEN;
    port_conf.txmode.offloads = RTE_ETH_TX_OFFLOAD_MULTI_SEGS;
    
    struct rte_eth_dev_info dev_info;
    rte_eth_dev_info_get(port, &dev_info);
    
    uint16_t nb_rxq = enable_rx ? 1 : 0;
    uint16_t nb_txq = 1;
    
    int ret = rte_eth_dev_configure(port, nb_rxq, nb_txq, &port_conf);
    if (ret != 0) return ret;
    
    // Setup RX queue if enabled
    if (enable_rx) {
        ret = rte_eth_rx_queue_setup(port, 0, RX_RING_SIZE,
                                     rte_eth_dev_socket_id(port),
                                     NULL, mbuf_pool);
        if (ret < 0) return ret;
    }
    
    // Setup TX queue
    struct rte_eth_txconf txconf = dev_info.default_txconf;
    txconf.offloads = port_conf.txmode.offloads;
    ret = rte_eth_tx_queue_setup(port, 0, TX_RING_SIZE,
                                 rte_eth_dev_socket_id(port),
                                 &txconf);
    if (ret < 0) return ret;
    
    // CRITICAL: Start the port!
    ret = rte_eth_dev_start(port);
    if (ret < 0) {
        printf("ERROR: Failed to start port %u: %d\n", port, ret);
        return ret;
    }
    printf("✓ Port %u STARTED\n", port);
    
    rte_eth_promiscuous_enable(port);
    
    printf("Port %u initialized (%s mode)\n", port, enable_rx ? "RX+TX" : "TX only");
    
    return 0;
}

// Control socket command handler
void handle_control_command(int client_sock, const char *cmd_json) {
    struct json_object *root = json_tokener_parse(cmd_json);
    if (!root) {
        const char *error = "{\"status\":\"error\",\"message\":\"Invalid JSON\"}\n";
        send(client_sock, error, strlen(error), 0);
        return;
    }
    
    struct json_object *cmd_obj;
    if (!json_object_object_get_ex(root, "command", &cmd_obj)) {
        const char *error = "{\"status\":\"error\",\"message\":\"No command specified\"}\n";
        send(client_sock, error, strlen(error), 0);
        json_object_put(root);
        return;
    }
    
    const char *command = json_object_get_string(cmd_obj);
    
    if (strcmp(command, "start") == 0) {
        // Create default traffic profile if none exist
        if (num_profiles == 0) {
            RTE_LOG(INFO, USER1, "No profiles configured, creating default profile\n");
            
            traffic_profile *prof = &profiles[0];
            memset(prof, 0, sizeof(traffic_profile));
            
            strcpy(prof->name, "default");
            prof->dst_ip = 0xC0A80202;           // 192.168.2.2
            prof->use_ipv6 = false;
            
            prof->src_port_min = 10000;
            prof->src_port_max = 10100;
            prof->dst_port = 5000;
            
            prof->protocol = PROTO_UDP;
            prof->packet_size = 1400;
            prof->rate_mbps = 100.0;
            prof->burst_size = 32;
            
            // Calculate inter-packet gap for ~100 Mbps with 1400 byte packets
            // Formula: IPG (ns) = (packet_size * 8 * 1000) / rate_mbps
            prof->inter_packet_gap_ns = (prof->packet_size * 8 * 1000) / prof->rate_mbps;
            
            // CRITICAL FIX: Pre-calculate TSC cycles to prevent overflow in TX loop
            uint64_t tsc_hz = rte_get_tsc_hz();
            prof->inter_packet_gap_cycles = (prof->inter_packet_gap_ns * tsc_hz) / 1000000000ULL;
            
            RTE_LOG(INFO, USER1, "  Inter-packet gap: %lu ns = %lu cycles (@ %lu Hz)\n",
                    prof->inter_packet_gap_ns, prof->inter_packet_gap_cycles, tsc_hz);
            
            prof->vlan_enabled = false;
            prof->vlan_id = 0;
            prof->dscp = 0;
            
            prof->payload_type = PAYLOAD_INCREMENT;
            prof->custom_payload_len = 0;
            
            prof->sequence_num = 0;
            prof->stream_id = 1;
            prof->packets_sent = 0;
            prof->bytes_sent = 0;
            prof->packets_dropped = 0;
            
            num_profiles = 1;
            
            RTE_LOG(INFO, USER1, "✓ Created default profile: UDP 192.168.1.1 -> 192.168.2.2:%u, %u bytes @ %.1f Mbps\n",
                    prof->dst_port, prof->packet_size, prof->rate_mbps);
        }
        
        running = true;
        rte_eal_mp_remote_launch(tx_thread_main, NULL, SKIP_MAIN);
        if (dual_port_mode) {
            rte_eal_mp_remote_launch(rx_thread_main, NULL, SKIP_MAIN);
        }
        
        const char *response = "{\"status\":\"success\",\"message\":\"Started\"}\n";
        send(client_sock, response, strlen(response), 0);
        
    } else if (strcmp(command, "stop") == 0) {
        running = false;
        rte_eal_mp_wait_lcore();
        
        const char *response = "{\"status\":\"success\",\"message\":\"Stopped\"}\n";
        send(client_sock, response, strlen(response), 0);
        
    } else if (strcmp(command, "stats") == 0) {
        char stats_json[4096];
        uint64_t total_tx = 0, total_bytes = 0;
        
        for (int i = 0; i < num_profiles; i++) {
            total_tx += profiles[i].packets_sent;
            total_bytes += profiles[i].bytes_sent;
        }
        
        snprintf(stats_json, sizeof(stats_json),
                "{\"status\":\"success\",\"data\":{"
                "\"packets_sent\":%lu,"
                "\"bytes_sent\":%lu,"
                "\"packets_received\":%lu,"
                "\"bytes_received\":%lu,"
                "\"throughput_mbps\":%.2f"
                "}}\n",
                total_tx, total_bytes,
                rx_statistics.packets_received, rx_statistics.bytes_received,
                (total_bytes * 8.0) / 1000000.0);
        
        send(client_sock, stats_json, strlen(stats_json), 0);
        
    } else {
        const char *error = "{\"status\":\"error\",\"message\":\"Unknown command\"}\n";
        send(client_sock, error, strlen(error), 0);
    }
    
    json_object_put(root);
}

// Control socket thread
void* control_socket_thread(void *arg) {
    const char *socket_path = (const char*)arg;
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = {};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    
    unlink(socket_path);
    
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        return NULL;
    }
    
    listen(sock, 5);
    printf("Control socket listening on %s\n", socket_path);
    
    while (!force_quit) {
        int client = accept(sock, NULL, NULL);
        if (client == -1) continue;
        
        char buffer[8192];
        ssize_t n = recv(client, buffer, sizeof(buffer) - 1, 0);
        if (n > 0) {
            buffer[n] = '\0';
            handle_control_command(client, buffer);
        }
        
        close(client);
    }
    
    close(sock);
    unlink(socket_path);
    return NULL;
}

// Main
int main(int argc, char *argv[]) {
    signal(SIGINT, [](int){force_quit = true;});
    signal(SIGTERM, [](int){force_quit = true;});
    
    const char *control_socket = "/tmp/dpdk_engine_control.sock";
    
    // Initialize DPDK
    int ret = rte_eal_init(argc, argv);
    if (ret < 0) {
        fprintf(stderr, "Failed to initialize DPDK\n");
        return -1;
    }
    
    // Check ports
    uint16_t nb_ports = rte_eth_dev_count_avail();
    printf("Found %u DPDK ports\n", nb_ports);
    
    if (nb_ports == 0) {
        fprintf(stderr, "No DPDK ports available\n");
        return -1;
    }
    
    tx_port = 0;
    dual_port_mode = (nb_ports >= 2);
    if (dual_port_mode) {
        rx_port = 1;
        printf("Dual-port mode: TX on port %d, RX on port %d\n", tx_port, rx_port);
    } else {
        printf("Single-port mode: TX only on port %d\n", tx_port);
    }
    
    // Create mbuf pool
    mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS,
                                       MBUF_CACHE_SIZE, 0,
                                       RTE_MBUF_DEFAULT_BUF_SIZE,
                                       rte_socket_id());
    if (!mbuf_pool) {
        fprintf(stderr, "Failed to create mbuf pool\n");
        return -1;
    }
    
    // Initialize ports
    if (init_port(tx_port, mbuf_pool, false) != 0) {
        fprintf(stderr, "Failed to initialize TX port\n");
        return -1;
    }
    
    if (dual_port_mode) {
        if (init_port(rx_port, mbuf_pool, true) != 0) {
            fprintf(stderr, "Failed to initialize RX port\n");
            return -1;
        }
    }
    
    // Start control socket thread
    pthread_t control_thread;
    pthread_create(&control_thread, NULL, control_socket_thread, (void*)control_socket);
    
    printf("\n");
    printf("╔════════════════════════════════════════════════════════════╗\n");
    printf("║  NetGen Pro - DPDK Engine (TX TIMING FIX APPLIED)         ║\n");
    printf("╚════════════════════════════════════════════════════════════╝\n");
    printf("\n");
    printf("Ready for control commands via %s\n", control_socket);
    printf("\n");
    
    // Wait for control thread
    pthread_join(control_thread, NULL);
    
    // Cleanup
    rte_eal_cleanup();
    
    return 0;
}
