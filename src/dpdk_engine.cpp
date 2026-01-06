/*
 * NetGen Pro - DPDK Edition
 * High-Performance Network Packet Generator Engine
 * 
 * This is the core DPDK packet generation engine that replaces the Python
 * packet generator for maximum performance (10+ Gbps capable).
 */

#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mempool.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <rte_udp.h>
#include <rte_tcp.h>
#include <rte_icmp.h>

#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <cstring>
#include <chrono>
#include <random>
#include <deque>
#include <mutex>
#include <signal.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <arpa/inet.h>

// Configuration constants
#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024
#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32
#define MAX_PROFILES 64
#define STATS_SOCKET_PATH "/tmp/netgen_dpdk_stats.sock"
#define CONTROL_SOCKET_PATH "/tmp/netgen_dpdk_control.sock"

// Traffic profile structure
struct TrafficProfile {
    char name[64];
    uint8_t protocol;      // 0=UDP, 1=TCP, 2=ICMP
    uint16_t packet_size;
    uint32_t rate_mbps;
    uint32_t dst_ip;
    uint16_t dst_port;
    uint32_t src_ip;
    uint16_t src_port;
    
    // Advanced features
    uint8_t ip_version;    // 4 or 6
    uint16_t vlan_id;
    uint8_t vlan_priority;
    uint32_t mpls_labels[4];
    uint8_t mpls_label_count;
    uint8_t dscp;
    uint8_t tcp_flags;
    
    // Payload
    uint8_t payload_pattern; // 0=random, 1=zeros, 2=ones, 3=increment
    uint8_t custom_payload[1500];
    uint16_t custom_payload_len;
    
    // Burst mode
    bool burst_mode;
    uint32_t burst_size;
    uint32_t burst_interval_ms;
    
    // Impairments
    float loss_percent;
    uint32_t latency_ms;
    uint32_t jitter_ms;
    float corruption_percent;
    float reorder_percent;
    float duplicate_percent;
    
    // Statistics (per-profile)
    std::atomic<uint64_t> packets_sent;
    std::atomic<uint64_t> bytes_sent;
    std::atomic<uint64_t> packets_dropped;
    std::atomic<uint64_t> packets_duplicated;
    std::atomic<uint64_t> packets_reordered;
    
    bool enabled;
    uint16_t lcore_id;
};

// Global state
struct GlobalState {
    std::atomic<bool> running;
    std::atomic<bool> shutdown;
    struct rte_mempool *mbuf_pool;
    uint16_t port_id;
    std::vector<TrafficProfile> profiles;
    std::chrono::steady_clock::time_point start_time;
    int control_socket;
    int stats_socket;
};

static GlobalState g_state;

// Latency tracking structure
struct LatencyTracker {
    std::deque<uint64_t> rtts;
    std::mutex lock;
    uint64_t min_rtt;
    uint64_t max_rtt;
    uint64_t total_rtt;
    uint64_t count;
    
    LatencyTracker() : min_rtt(UINT64_MAX), max_rtt(0), total_rtt(0), count(0) {}
    
    void record(uint64_t rtt_ns) {
        std::lock_guard<std::mutex> guard(lock);
        rtts.push_back(rtt_ns);
        if (rtts.size() > 1000) rtts.pop_front();
        min_rtt = std::min(min_rtt, rtt_ns);
        max_rtt = std::max(max_rtt, rtt_ns);
        total_rtt += rtt_ns;
        count++;
    }
};

// Random number generator per thread
thread_local std::mt19937 g_rng(std::random_device{}());

// Calculate checksum (generic)
static uint16_t calculate_checksum(const void *buf, size_t len) {
    const uint16_t *data = static_cast<const uint16_t*>(buf);
    uint32_t sum = 0;
    
    while (len > 1) {
        sum += *data++;
        len -= 2;
    }
    
    if (len > 0) {
        sum += *(uint8_t*)data;
    }
    
    while (sum >> 16) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    
    return ~sum;
}

// Generate payload based on pattern
static void generate_payload(uint8_t *buf, size_t len, uint8_t pattern, 
                            const uint8_t *custom, uint16_t custom_len) {
    if (custom_len > 0 && pattern == 4) {
        // Custom payload
        size_t copied = 0;
        while (copied < len) {
            size_t to_copy = std::min(len - copied, (size_t)custom_len);
            memcpy(buf + copied, custom, to_copy);
            copied += to_copy;
        }
    } else {
        switch (pattern) {
            case 0: // Random
                for (size_t i = 0; i < len; i++) {
                    buf[i] = g_rng() & 0xFF;
                }
                break;
            case 1: // Zeros
                memset(buf, 0, len);
                break;
            case 2: // Ones
                memset(buf, 0xFF, len);
                break;
            case 3: // Increment
                for (size_t i = 0; i < len; i++) {
                    buf[i] = i & 0xFF;
                }
                break;
        }
    }
}

// Apply network impairments
static bool should_drop_packet(float loss_percent) {
    if (loss_percent <= 0.0f) return false;
    std::uniform_real_distribution<float> dist(0.0f, 100.0f);
    return dist(g_rng) < loss_percent;
}

static bool should_duplicate_packet(float dup_percent) {
    if (dup_percent <= 0.0f) return false;
    std::uniform_real_distribution<float> dist(0.0f, 100.0f);
    return dist(g_rng) < dup_percent;
}

static void apply_jitter(uint32_t jitter_ms) {
    if (jitter_ms > 0) {
        std::uniform_int_distribution<uint32_t> dist(0, jitter_ms);
        uint32_t delay = dist(g_rng);
        rte_delay_us(delay * 1000);
    }
}

// Build UDP packet
static struct rte_mbuf* build_udp_packet(struct rte_mempool *pool, TrafficProfile &profile) {
    struct rte_mbuf *mbuf = rte_pktmbuf_alloc(pool);
    if (!mbuf) return nullptr;
    
    // Calculate sizes
    size_t eth_hdr_len = sizeof(struct rte_ether_hdr);
    size_t ip_hdr_len = sizeof(struct rte_ipv4_hdr);
    size_t udp_hdr_len = sizeof(struct rte_udp_hdr);
    size_t payload_len = profile.packet_size - eth_hdr_len - ip_hdr_len - udp_hdr_len;
    
    // Get buffer pointer
    uint8_t *pkt = rte_pktmbuf_mtod(mbuf, uint8_t*);
    
    // Ethernet header
    struct rte_ether_hdr *eth = (struct rte_ether_hdr*)pkt;
    memset(eth->dst_addr.addr_bytes, 0xFF, RTE_ETHER_ADDR_LEN); // Broadcast for now
    rte_eth_macaddr_get(g_state.port_id, &eth->src_addr);
    eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    
    // IPv4 header
    struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)(pkt + eth_hdr_len);
    memset(ip, 0, ip_hdr_len);
    ip->version_ihl = 0x45; // IPv4, 20 byte header
    ip->type_of_service = profile.dscp << 2;
    ip->total_length = rte_cpu_to_be_16(ip_hdr_len + udp_hdr_len + payload_len);
    ip->packet_id = rte_cpu_to_be_16(g_rng() & 0xFFFF);
    ip->fragment_offset = 0;
    ip->time_to_live = 64;
    ip->next_proto_id = IPPROTO_UDP;
    ip->src_addr = rte_cpu_to_be_32(profile.src_ip);
    ip->dst_addr = rte_cpu_to_be_32(profile.dst_ip);
    ip->hdr_checksum = 0;
    ip->hdr_checksum = rte_ipv4_cksum(ip);
    
    // UDP header
    struct rte_udp_hdr *udp = (struct rte_udp_hdr*)(pkt + eth_hdr_len + ip_hdr_len);
    udp->src_port = rte_cpu_to_be_16(profile.src_port);
    udp->dst_port = rte_cpu_to_be_16(profile.dst_port);
    udp->dgram_len = rte_cpu_to_be_16(udp_hdr_len + payload_len);
    udp->dgram_cksum = 0; // Optional for IPv4
    
    // Payload
    uint8_t *payload = pkt + eth_hdr_len + ip_hdr_len + udp_hdr_len;
    generate_payload(payload, payload_len, profile.payload_pattern, 
                    profile.custom_payload, profile.custom_payload_len);
    
    // Set packet length
    mbuf->pkt_len = profile.packet_size;
    mbuf->data_len = profile.packet_size;
    
    return mbuf;
}

// Build TCP packet
static struct rte_mbuf* build_tcp_packet(struct rte_mempool *pool, TrafficProfile &profile) {
    struct rte_mbuf *mbuf = rte_pktmbuf_alloc(pool);
    if (!mbuf) return nullptr;
    
    // Calculate sizes
    size_t eth_hdr_len = sizeof(struct rte_ether_hdr);
    size_t ip_hdr_len = sizeof(struct rte_ipv4_hdr);
    size_t tcp_hdr_len = sizeof(struct rte_tcp_hdr);
    size_t payload_len = profile.packet_size - eth_hdr_len - ip_hdr_len - tcp_hdr_len;
    
    // Get buffer pointer
    uint8_t *pkt = rte_pktmbuf_mtod(mbuf, uint8_t*);
    
    // Ethernet header
    struct rte_ether_hdr *eth = (struct rte_ether_hdr*)pkt;
    memset(eth->dst_addr.addr_bytes, 0xFF, RTE_ETHER_ADDR_LEN);
    rte_eth_macaddr_get(g_state.port_id, &eth->src_addr);
    eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    
    // IPv4 header
    struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)(pkt + eth_hdr_len);
    memset(ip, 0, ip_hdr_len);
    ip->version_ihl = 0x45;
    ip->type_of_service = profile.dscp << 2;
    ip->total_length = rte_cpu_to_be_16(ip_hdr_len + tcp_hdr_len + payload_len);
    ip->packet_id = rte_cpu_to_be_16(g_rng() & 0xFFFF);
    ip->fragment_offset = 0;
    ip->time_to_live = 64;
    ip->next_proto_id = IPPROTO_TCP;
    ip->src_addr = rte_cpu_to_be_32(profile.src_ip);
    ip->dst_addr = rte_cpu_to_be_32(profile.dst_ip);
    ip->hdr_checksum = 0;
    ip->hdr_checksum = rte_ipv4_cksum(ip);
    
    // TCP header
    struct rte_tcp_hdr *tcp = (struct rte_tcp_hdr*)(pkt + eth_hdr_len + ip_hdr_len);
    tcp->src_port = rte_cpu_to_be_16(profile.src_port);
    tcp->dst_port = rte_cpu_to_be_16(profile.dst_port);
    tcp->sent_seq = rte_cpu_to_be_32(g_rng());
    tcp->recv_ack = 0;
    tcp->data_off = (tcp_hdr_len / 4) << 4; // 20 bytes, no options
    tcp->tcp_flags = profile.tcp_flags;
    tcp->rx_win = rte_cpu_to_be_16(65535);
    tcp->cksum = 0;
    tcp->tcp_urp = 0;
    
    // Payload
    uint8_t *payload = pkt + eth_hdr_len + ip_hdr_len + tcp_hdr_len;
    generate_payload(payload, payload_len, profile.payload_pattern,
                    profile.custom_payload, profile.custom_payload_len);
    
    // Set packet length
    mbuf->pkt_len = profile.packet_size;
    mbuf->data_len = profile.packet_size;
    
    return mbuf;
}

// Build ICMP packet
static struct rte_mbuf* build_icmp_packet(struct rte_mempool *pool, TrafficProfile &profile) {
    struct rte_mbuf *mbuf = rte_pktmbuf_alloc(pool);
    if (!mbuf) return nullptr;
    
    // Calculate sizes
    size_t eth_hdr_len = sizeof(struct rte_ether_hdr);
    size_t ip_hdr_len = sizeof(struct rte_ipv4_hdr);
    size_t icmp_hdr_len = sizeof(struct rte_icmp_hdr);
    size_t payload_len = profile.packet_size - eth_hdr_len - ip_hdr_len - icmp_hdr_len;
    
    // Get buffer pointer
    uint8_t *pkt = rte_pktmbuf_mtod(mbuf, uint8_t*);
    
    // Ethernet header
    struct rte_ether_hdr *eth = (struct rte_ether_hdr*)pkt;
    memset(eth->dst_addr.addr_bytes, 0xFF, RTE_ETHER_ADDR_LEN);
    rte_eth_macaddr_get(g_state.port_id, &eth->src_addr);
    eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
    
    // IPv4 header
    struct rte_ipv4_hdr *ip = (struct rte_ipv4_hdr*)(pkt + eth_hdr_len);
    memset(ip, 0, ip_hdr_len);
    ip->version_ihl = 0x45;
    ip->type_of_service = profile.dscp << 2;
    ip->total_length = rte_cpu_to_be_16(ip_hdr_len + icmp_hdr_len + payload_len);
    ip->packet_id = rte_cpu_to_be_16(g_rng() & 0xFFFF);
    ip->fragment_offset = 0;
    ip->time_to_live = 64;
    ip->next_proto_id = IPPROTO_ICMP;
    ip->src_addr = rte_cpu_to_be_32(profile.src_ip);
    ip->dst_addr = rte_cpu_to_be_32(profile.dst_ip);
    ip->hdr_checksum = 0;
    ip->hdr_checksum = rte_ipv4_cksum(ip);
    
    // ICMP header (Echo Request)
    struct rte_icmp_hdr *icmp = (struct rte_icmp_hdr*)(pkt + eth_hdr_len + ip_hdr_len);
    icmp->icmp_type = RTE_IP_ICMP_ECHO_REQUEST;
    icmp->icmp_code = 0;
    icmp->icmp_cksum = 0;
    icmp->icmp_ident = rte_cpu_to_be_16(getpid() & 0xFFFF);
    icmp->icmp_seq_nb = rte_cpu_to_be_16(profile.packets_sent & 0xFFFF);
    
    // Payload
    uint8_t *payload = pkt + eth_hdr_len + ip_hdr_len + icmp_hdr_len;
    generate_payload(payload, payload_len, profile.payload_pattern,
                    profile.custom_payload, profile.custom_payload_len);
    
    // Calculate ICMP checksum
    icmp->icmp_cksum = calculate_checksum(icmp, icmp_hdr_len + payload_len);
    
    // Set packet length
    mbuf->pkt_len = profile.packet_size;
    mbuf->data_len = profile.packet_size;
    
    return mbuf;
}

// Per-lcore packet generation function
static int lcore_tx_function(void *arg) {
    TrafficProfile *profile = static_cast<TrafficProfile*>(arg);
    
    std::cout << "Starting lcore " << rte_lcore_id() 
              << " for profile: " << profile->name << std::endl;
    
    // Calculate packets per second and inter-packet gap
    uint64_t rate_bps = (uint64_t)profile->rate_mbps * 1000000;
    uint64_t pps = rate_bps / (profile->packet_size * 8);
    uint64_t ticks_per_packet = rte_get_tsc_hz() / pps;
    
    uint64_t last_tx_tsc = rte_get_tsc_cycles();
    uint64_t burst_start_tsc = last_tx_tsc;
    uint32_t burst_count = 0;
    
    struct rte_mbuf *pkts_burst[BURST_SIZE];
    
    while (g_state.running) {
        uint64_t now_tsc = rte_get_tsc_cycles();
        
        // Burst mode handling
        if (profile->burst_mode) {
            uint64_t burst_elapsed = (now_tsc - burst_start_tsc) * 1000000 / rte_get_tsc_hz();
            
            if (burst_count >= profile->burst_size) {
                if (burst_elapsed >= profile->burst_interval_ms * 1000) {
                    burst_start_tsc = now_tsc;
                    burst_count = 0;
                } else {
                    rte_delay_us(100);
                    continue;
                }
            }
        }
        
        // Rate limiting
        if (now_tsc - last_tx_tsc < ticks_per_packet) {
            continue;
        }
        
        // Packet loss simulation
        if (should_drop_packet(profile->loss_percent)) {
            profile->packets_dropped++;
            last_tx_tsc = now_tsc;
            continue;
        }
        
        // Apply latency
        if (profile->latency_ms > 0) {
            rte_delay_us(profile->latency_ms * 1000);
        }
        
        // Apply jitter
        apply_jitter(profile->jitter_ms);
        
        // Build packet based on protocol
        struct rte_mbuf *pkt = nullptr;
        switch (profile->protocol) {
            case 0: // UDP
                pkt = build_udp_packet(g_state.mbuf_pool, *profile);
                break;
            case 1: // TCP
                pkt = build_tcp_packet(g_state.mbuf_pool, *profile);
                break;
            case 2: // ICMP
                pkt = build_icmp_packet(g_state.mbuf_pool, *profile);
                break;
        }
        
        if (!pkt) {
            rte_delay_us(1);
            continue;
        }
        
        // Check for duplication
        bool duplicate = should_duplicate_packet(profile->duplicate_percent);
        
        // Send packet
        uint16_t sent = rte_eth_tx_burst(g_state.port_id, 0, &pkt, 1);
        if (sent > 0) {
            profile->packets_sent++;
            profile->bytes_sent += profile->packet_size;
            
            if (profile->burst_mode) {
                burst_count++;
            }
            
            // Send duplicate if needed
            if (duplicate) {
                struct rte_mbuf *dup_pkt = rte_pktmbuf_clone(pkt, g_state.mbuf_pool);
                if (dup_pkt) {
                    rte_eth_tx_burst(g_state.port_id, 0, &dup_pkt, 1);
                    profile->packets_duplicated++;
                }
            }
        }
        
        // Free original packet if not sent or after duplication
        if (sent == 0) {
            rte_pktmbuf_free(pkt);
        }
        
        last_tx_tsc = now_tsc;
    }
    
    std::cout << "Stopping lcore " << rte_lcore_id() << std::endl;
    return 0;
}

// Initialize DPDK port
static int port_init(uint16_t port, struct rte_mempool *mbuf_pool) {
    struct rte_eth_conf port_conf = {};
    const uint16_t rx_rings = 1, tx_rings = 1;
    uint16_t nb_rxd = RX_RING_SIZE;
    uint16_t nb_txd = TX_RING_SIZE;
    int retval;
    uint16_t q;
    struct rte_eth_dev_info dev_info;
    struct rte_eth_txconf txconf;
    
    if (!rte_eth_dev_is_valid_port(port)) {
        return -1;
    }
    
    retval = rte_eth_dev_info_get(port, &dev_info);
    if (retval != 0) {
        printf("Error getting device info: %s\n", strerror(-retval));
        return retval;
    }
    
    // Configure the Ethernet device
    retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
    if (retval != 0) {
        return retval;
    }
    
    retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
    if (retval != 0) {
        return retval;
    }
    
    // Allocate and set up RX queue
    for (q = 0; q < rx_rings; q++) {
        retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
                rte_eth_dev_socket_id(port), NULL, mbuf_pool);
        if (retval < 0) {
            return retval;
        }
    }
    
    // Allocate and set up TX queue
    txconf = dev_info.default_txconf;
    txconf.offloads = port_conf.txmode.offloads;
    for (q = 0; q < tx_rings; q++) {
        retval = rte_eth_tx_queue_setup(port, q, nb_txd,
                rte_eth_dev_socket_id(port), &txconf);
        if (retval < 0) {
            return retval;
        }
    }
    
    // Start the Ethernet port
    retval = rte_eth_dev_start(port);
    if (retval < 0) {
        return retval;
    }
    
    // Enable promiscuous mode
    retval = rte_eth_promiscuous_enable(port);
    if (retval != 0) {
        return retval;
    }
    
    return 0;
}

// Control socket handler (receives commands from Python)
static void handle_control_socket() {
    // Create Unix domain socket
    unlink(CONTROL_SOCKET_PATH);
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return;
    }
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, CONTROL_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return;
    }
    
    if (listen(sock, 5) < 0) {
        perror("listen");
        close(sock);
        return;
    }
    
    std::cout << "Control socket listening on " << CONTROL_SOCKET_PATH << std::endl;
    g_state.control_socket = sock;
    
    // Accept connections and handle commands
    while (!g_state.shutdown) {
        struct sockaddr_un client_addr;
        socklen_t client_len = sizeof(client_addr);
        int client = accept(sock, (struct sockaddr*)&client_addr, &client_len);
        
        if (client < 0) {
            if (g_state.shutdown) break;
            continue;
        }
        
        // Read command (simple protocol: command\n)
        char buffer[4096];
        ssize_t n = read(client, buffer, sizeof(buffer) - 1);
        if (n > 0) {
            buffer[n] = '\0';
            
            // Parse command (JSON or simple text)
            std::string cmd(buffer);
            if (cmd.find("START") == 0) {
                g_state.running = true;
                write(client, "OK\n", 3);
            } else if (cmd.find("STOP") == 0) {
                g_state.running = false;
                write(client, "OK\n", 3);
            } else if (cmd.find("SHUTDOWN") == 0) {
                g_state.running = false;
                g_state.shutdown = true;
                write(client, "OK\n", 3);
            } else {
                write(client, "ERROR: Unknown command\n", 23);
            }
        }
        
        close(client);
    }
    
    close(sock);
    unlink(CONTROL_SOCKET_PATH);
}

// Statistics reporting thread
static void stats_reporter() {
    while (!g_state.shutdown) {
        sleep(5);
        
        if (!g_state.running) continue;
        
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now - g_state.start_time).count();
        
        std::cout << "\n" << std::string(70, '=') << std::endl;
        std::cout << "Statistics (Elapsed: " << elapsed << "s)" << std::endl;
        std::cout << std::string(70, '=') << std::endl;
        
        uint64_t total_packets = 0;
        uint64_t total_bytes = 0;
        
        for (auto &profile : g_state.profiles) {
            if (!profile.enabled) continue;
            
            uint64_t pkts = profile.packets_sent.load();
            uint64_t bytes = profile.bytes_sent.load();
            uint64_t dropped = profile.packets_dropped.load();
            uint64_t duped = profile.packets_duplicated.load();
            
            total_packets += pkts;
            total_bytes += bytes;
            
            double pps = elapsed > 0 ? (double)pkts / elapsed : 0;
            double mbps = elapsed > 0 ? (double)(bytes * 8) / elapsed / 1000000 : 0;
            
            printf("%-25s: %10lu pkts, %8.2f Mbps, %8.0f pps\n",
                   profile.name, pkts, mbps, pps);
            printf("%-25s  Dropped: %lu, Duplicated: %lu\n", "", dropped, duped);
        }
        
        double total_mbps = elapsed > 0 ? (double)(total_bytes * 8) / elapsed / 1000000 : 0;
        std::cout << std::string(70, '-') << std::endl;
        printf("%-25s: %10lu pkts, %8.2f Mbps\n", "TOTAL", total_packets, total_mbps);
        std::cout << std::string(70, '=') << std::endl;
    }
}

// Signal handler
static void signal_handler(int signum) {
    std::cout << "\nSignal " << signum << " received, stopping..." << std::endl;
    g_state.running = false;
    g_state.shutdown = true;
}

// Main function
int main(int argc, char *argv[]) {
    int ret;
    uint16_t portid = 0;
    
    // Initialize signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize EAL
    ret = rte_eal_init(argc, argv);
    if (ret < 0) {
        rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
    }
    
    argc -= ret;
    argv += ret;
    
    // Check that there is an available port
    if (rte_eth_dev_count_avail() == 0) {
        rte_exit(EXIT_FAILURE, "No Ethernet ports available\n");
    }
    
    // Create mbuf pool
    g_state.mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS,
        MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
    
    if (g_state.mbuf_pool == NULL) {
        rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");
    }
    
    // Initialize port
    if (port_init(portid, g_state.mbuf_pool) != 0) {
        rte_exit(EXIT_FAILURE, "Cannot init port %u\n", portid);
    }
    
    g_state.port_id = portid;
    g_state.running = false;
    g_state.shutdown = false;
    g_state.start_time = std::chrono::steady_clock::now();
    
    std::cout << "\n" << std::string(70, '=') << std::endl;
    std::cout << "NetGen Pro - DPDK Engine" << std::endl;
    std::cout << std::string(70, '=') << std::endl;
    std::cout << "Port " << portid << " initialized successfully" << std::endl;
    std::cout << "Available lcores: " << rte_lcore_count() << std::endl;
    std::cout << "Waiting for control commands..." << std::endl;
    std::cout << std::string(70, '=') << std::endl;
    
    // Start control socket handler in separate thread
    std::thread control_thread(handle_control_socket);
    
    // Start stats reporter
    std::thread stats_thread(stats_reporter);
    
    // Wait for shutdown
    while (!g_state.shutdown) {
        sleep(1);
    }
    
    // Cleanup
    control_thread.join();
    stats_thread.join();
    
    std::cout << "Cleaning up..." << std::endl;
    rte_eth_dev_stop(portid);
    rte_eth_dev_close(portid);
    rte_eal_cleanup();
    
    return 0;
}
