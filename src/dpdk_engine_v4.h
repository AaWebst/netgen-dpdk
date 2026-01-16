/*
 * NetGen Pro v4.0 - Enhanced DPDK Engine
 * Priority Features Implementation
 */

#ifndef DPDK_ENGINE_V4_H
#define DPDK_ENGINE_V4_H

#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mempool.h>
#include <rte_ring.h>
#include <rte_malloc.h>
#include <json-c/json.h>

// ============================================================================
// V4.0 ENHANCEMENTS
// ============================================================================

// Multi-Core Scaling Configuration
#define MAX_WORKER_CORES 16
#define RX_RING_SIZE 4096      // Increased from 2048
#define TX_RING_SIZE 4096
#define NUM_MBUFS 32767        // Increased from 8191
#define BURST_SIZE 64          // Optimal for performance
#define PREFETCH_OFFSET 3      // Prefetch packets ahead

// NUMA Awareness
struct numa_config {
    int numa_node;
    int socket_id;
    struct rte_mempool *mbuf_pool;
    bool initialized;
};

// Multi-Core Worker Thread
struct worker_thread {
    unsigned lcore_id;
    int numa_node;
    uint16_t port_id;
    bool is_tx;
    bool is_rx;
    struct rte_ring *tx_ring;
    struct rte_ring *rx_ring;
    
    // Per-core statistics
    uint64_t packets_processed;
    uint64_t bytes_processed;
    uint64_t cycles_used;
};

// Zero-Copy Packet Context
struct packet_context {
    struct rte_mbuf *mbuf;
    void *packet_data;
    uint16_t data_len;
    uint8_t *l2_header;
    uint8_t *l3_header;
    uint8_t *l4_header;
    uint8_t *payload;
};

// Hardware Offload Configuration
struct hw_offload_config {
    bool tx_checksum_offload;
    bool rx_checksum_offload;
    bool tso_enabled;           // TCP Segmentation Offload
    bool rss_enabled;           // Receive Side Scaling
    bool vlan_offload;
    bool jumbo_frames;
    uint16_t max_rx_pkt_len;
};

// Traffic Pattern Generator
enum pattern_type {
    PATTERN_CONSTANT = 0,
    PATTERN_RAMP_UP,
    PATTERN_RAMP_DOWN,
    PATTERN_SINE_WAVE,
    PATTERN_BURST,
    PATTERN_RANDOM_POISSON,
    PATTERN_RANDOM_EXPONENTIAL,
    PATTERN_RANDOM_NORMAL,
    PATTERN_STEP_FUNCTION,
    PATTERN_DECAY,
    PATTERN_CYCLIC
};

struct traffic_pattern {
    enum pattern_type type;
    double base_rate_mbps;
    double peak_rate_mbps;
    uint32_t period_sec;
    uint32_t burst_duration_ms;
    uint32_t idle_duration_ms;
    double random_mean;
    double random_stddev;
    
    // Runtime state
    uint64_t start_cycles;
    uint64_t last_update_cycles;
    double current_rate_mbps;
};

// QoS Configuration
struct qos_config {
    bool enabled;
    uint8_t dscp_value;         // 0-63
    uint8_t cos_value;          // 0-7 (802.1p)
    uint32_t min_rate_mbps;
    uint32_t max_rate_mbps;
    uint32_t burst_size_kb;
    uint8_t priority_queue;
};

// Custom Protocol Support
struct custom_protocol {
    char name[32];
    uint16_t ethertype;
    uint8_t ip_protocol;
    
    // Custom header template (up to 256 bytes)
    uint8_t header_template[256];
    uint16_t header_len;
    
    // Payload pattern
    uint8_t payload_pattern[1024];
    uint16_t payload_len;
    
    // Field positions for dynamic updates
    uint16_t seq_num_offset;
    uint16_t timestamp_offset;
    uint16_t checksum_offset;
};

// Enhanced Traffic Profile with v4.0 features
struct traffic_profile_v4 {
    // Original fields
    bool active;
    char name[64];
    uint16_t src_port;
    uint16_t dst_port;
    uint8_t protocol;
    
    // Network layer
    uint32_t src_ip;
    uint32_t dst_ip;
    bool use_ipv6;
    
    // Performance settings
    uint32_t rate_mbps;
    uint16_t packet_size;
    uint64_t packets_to_send;
    uint64_t duration_ns;
    
    // V4.0 Enhancements
    struct traffic_pattern pattern;
    struct qos_config qos;
    struct custom_protocol *custom_proto;
    
    // Statistics
    uint64_t packets_sent;
    uint64_t packets_received;
    uint64_t bytes_sent;
    uint64_t bytes_received;
    uint64_t packets_dropped;
    
    // Latency tracking
    uint64_t min_latency_ns;
    uint64_t max_latency_ns;
    uint64_t sum_latency_ns;
    uint64_t latency_samples;
    
    // Core assignment
    unsigned assigned_lcore;
};

// Network Topology Discovery
struct discovered_device {
    uint8_t mac_addr[6];
    uint32_t ip_addr;
    char hostname[128];
    char vendor[64];
    uint16_t port_number;
    char port_description[256];
    uint32_t last_seen;
    
    // LLDP information
    char system_name[128];
    char system_description[256];
    uint16_t capabilities;
};

struct topology_info {
    uint16_t num_devices;
    struct discovered_device devices[256];
    uint32_t last_discovery_time;
};

// PCAP Capture Context
struct pcap_capture {
    bool active;
    char filename[256];
    FILE *pcap_file;
    uint16_t port_id;
    uint32_t max_packets;
    uint32_t max_bytes;
    uint32_t packets_captured;
    uint32_t bytes_captured;
    char bpf_filter[512];
};

// Hardware Monitoring
struct hardware_stats {
    // CPU
    uint32_t cpu_temp[16];      // Per-core temperature (Celsius)
    uint32_t cpu_freq[16];      // Per-core frequency (MHz)
    uint8_t cpu_usage[16];      // Per-core utilization (%)
    
    // Memory
    uint64_t hugepage_free;
    uint64_t hugepage_total;
    uint64_t memory_free_kb;
    uint64_t memory_total_kb;
    
    // NIC
    uint64_t rx_missed;         // Packets dropped by NIC
    uint64_t rx_errors;
    uint64_t tx_errors;
    uint64_t rx_crc_errors;
    uint64_t rx_frame_errors;
    
    // PCIe
    uint32_t pcie_link_speed;   // GT/s
    uint8_t pcie_link_width;    // Number of lanes
    uint64_t pcie_errors;
    
    // Power (if available)
    uint32_t power_watts;
};

// Aggregate Statistics (Multi-Port)
struct aggregate_stats {
    // System-wide totals
    uint64_t total_tx_packets;
    uint64_t total_rx_packets;
    uint64_t total_tx_bytes;
    uint64_t total_rx_bytes;
    uint64_t total_dropped;
    
    // Throughput
    double total_tx_mbps;
    double total_rx_mbps;
    double peak_tx_mbps;
    double peak_rx_mbps;
    
    // Latency
    uint64_t avg_latency_ns;
    uint64_t min_latency_ns;
    uint64_t max_latency_ns;
    
    // Loss
    double aggregate_loss_pct;
    
    // System load
    uint8_t system_utilization_pct;
    uint32_t active_flows;
    uint32_t active_cores;
};

// Enhanced RFC 2544 with multiple frame sizes
struct rfc2544_test_v4 {
    bool running;
    uint8_t test_type;
    
    // Multi-size testing
    uint16_t frame_sizes[8];    // e.g., 64, 128, 256, 512, 1024, 1518
    uint8_t num_frame_sizes;
    uint8_t current_size_idx;
    
    // Bidirectional testing
    bool bidirectional;
    
    // Duration and criteria
    uint32_t duration_sec;
    double loss_threshold_pct;
    double target_rate_mbps;
    
    // Results per frame size
    struct {
        uint16_t frame_size;
        double max_throughput_mbps;
        double max_throughput_fps;
        uint64_t avg_latency_ns;
        uint64_t min_latency_ns;
        uint64_t max_latency_ns;
        uint64_t jitter_ns;
        double loss_pct;
        bool passed;
    } results[8];
    
    // Micro-burst detection
    uint32_t microburst_count;
    uint64_t microburst_max_duration_ns;
};

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================

// Multi-Core & NUMA
int init_numa_config(void);
int assign_worker_threads(void);
int worker_thread_main(void *arg);

// Zero-Copy Operations
struct packet_context* get_packet_context(struct rte_mbuf *mbuf);
void build_packet_zerocopy(struct packet_context *ctx, struct traffic_profile_v4 *prof);

// Hardware Offloads
int enable_hw_offloads(uint16_t port_id, struct hw_offload_config *config);
int configure_rss(uint16_t port_id, uint16_t num_queues);

// Traffic Patterns
double calculate_pattern_rate(struct traffic_pattern *pattern, uint64_t current_cycles);
void update_traffic_pattern(struct traffic_pattern *pattern);

// QoS
void apply_qos_marking(struct packet_context *ctx, struct qos_config *qos);
int configure_qos_queues(uint16_t port_id);

// Custom Protocols
int register_custom_protocol(struct custom_protocol *proto);
void build_custom_protocol_packet(struct packet_context *ctx, struct custom_protocol *proto);

// Network Topology
int discover_network_topology(uint16_t port_id, struct topology_info *topo);
int send_lldp_packet(uint16_t port_id);
int parse_lldp_packet(struct rte_mbuf *mbuf, struct discovered_device *device);

// PCAP Capture
int start_pcap_capture(struct pcap_capture *cap);
int stop_pcap_capture(struct pcap_capture *cap);
int write_pcap_packet(struct pcap_capture *cap, struct rte_mbuf *mbuf);

// Hardware Monitoring
int collect_hardware_stats(struct hardware_stats *hw);
int read_cpu_temperature(uint32_t *temps);
int read_nic_stats(uint16_t port_id, struct hardware_stats *hw);

// Aggregate Statistics
void update_aggregate_stats(struct aggregate_stats *agg);
void calculate_system_utilization(struct aggregate_stats *agg);

// Enhanced RFC 2544
int run_rfc2544_multisize(struct rfc2544_test_v4 *test);
int run_rfc2544_bidirectional(struct rfc2544_test_v4 *test);
double binary_search_throughput(uint16_t frame_size, double loss_threshold);

// Error Recovery
int watchdog_thread_main(void *arg);
void recover_from_error(const char *error_type);
int health_check(void);

#endif // DPDK_ENGINE_V4_H
