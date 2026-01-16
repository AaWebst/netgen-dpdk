/*
 * NetGen Pro v4.0 - Traffic Pattern Generator
 * Implements various traffic patterns: ramp, sine wave, burst, random, etc.
 */

#include "dpdk_engine_v4.h"
#include <math.h>
#include <stdlib.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Random number generator for patterns
static __thread unsigned int rng_seed = 0;

static inline double rand_uniform(void) {
    if (rng_seed == 0) {
        rng_seed = (unsigned int)rte_rdtsc();
    }
    return (double)rand_r(&rng_seed) / RAND_MAX;
}

static inline double rand_exponential(double mean) {
    double u = rand_uniform();
    return -mean * log(1.0 - u);
}

static inline double rand_normal(double mean, double stddev) {
    // Box-Muller transform
    double u1 = rand_uniform();
    double u2 = rand_uniform();
    double z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI * u2);
    return mean + stddev * z0;
}

static inline double rand_poisson(double lambda) {
    double L = exp(-lambda);
    double p = 1.0;
    int k = 0;
    
    do {
        k++;
        p *= rand_uniform();
    } while (p > L);
    
    return k - 1;
}

// ============================================================================
// PATTERN CALCULATION FUNCTIONS
// ============================================================================

double calculate_pattern_rate(struct traffic_pattern *pattern, uint64_t current_cycles) {
    uint64_t hz = rte_get_tsc_hz();
    uint64_t elapsed_cycles = current_cycles - pattern->start_cycles;
    double elapsed_sec = (double)elapsed_cycles / hz;
    
    double rate = pattern->base_rate_mbps;
    
    switch (pattern->type) {
        case PATTERN_CONSTANT:
            // No change
            break;
            
        case PATTERN_RAMP_UP: {
            // Linear increase from base to peak over period
            double progress = fmod(elapsed_sec, pattern->period_sec) / pattern->period_sec;
            rate = pattern->base_rate_mbps + 
                   (pattern->peak_rate_mbps - pattern->base_rate_mbps) * progress;
            break;
        }
        
        case PATTERN_RAMP_DOWN: {
            // Linear decrease from peak to base over period
            double progress = fmod(elapsed_sec, pattern->period_sec) / pattern->period_sec;
            rate = pattern->peak_rate_mbps - 
                   (pattern->peak_rate_mbps - pattern->base_rate_mbps) * progress;
            break;
        }
        
        case PATTERN_SINE_WAVE: {
            // Sine wave oscillation between base and peak
            double phase = fmod(elapsed_sec, pattern->period_sec) / pattern->period_sec;
            double amplitude = (pattern->peak_rate_mbps - pattern->base_rate_mbps) / 2.0;
            double offset = (pattern->peak_rate_mbps + pattern->base_rate_mbps) / 2.0;
            rate = offset + amplitude * sin(2.0 * M_PI * phase);
            break;
        }
        
        case PATTERN_BURST: {
            // Burst mode: full rate for burst_duration_ms, then idle for idle_duration_ms
            uint32_t cycle_ms = pattern->burst_duration_ms + pattern->idle_duration_ms;
            uint32_t elapsed_ms = (uint32_t)((elapsed_sec * 1000)) % cycle_ms;
            
            if (elapsed_ms < pattern->burst_duration_ms) {
                rate = pattern->peak_rate_mbps;  // Burst
            } else {
                rate = 0.0;  // Idle
            }
            break;
        }
        
        case PATTERN_RANDOM_POISSON: {
            // Poisson distribution
            double lambda = pattern->random_mean;
            rate = pattern->base_rate_mbps * (rand_poisson(lambda) / lambda);
            rate = fmin(rate, pattern->peak_rate_mbps);
            break;
        }
        
        case PATTERN_RANDOM_EXPONENTIAL: {
            // Exponential distribution
            double mean = pattern->random_mean;
            rate = rand_exponential(mean);
            rate = fmin(rate, pattern->peak_rate_mbps);
            rate = fmax(rate, pattern->base_rate_mbps);
            break;
        }
        
        case PATTERN_RANDOM_NORMAL: {
            // Normal (Gaussian) distribution
            rate = rand_normal(pattern->random_mean, pattern->random_stddev);
            rate = fmin(rate, pattern->peak_rate_mbps);
            rate = fmax(rate, pattern->base_rate_mbps);
            break;
        }
        
        case PATTERN_STEP_FUNCTION: {
            // Step function: switch between base and peak at intervals
            uint32_t step = (uint32_t)(elapsed_sec / pattern->period_sec) % 2;
            rate = step ? pattern->peak_rate_mbps : pattern->base_rate_mbps;
            break;
        }
        
        case PATTERN_DECAY: {
            // Exponential decay from peak to base
            double progress = fmod(elapsed_sec, pattern->period_sec) / pattern->period_sec;
            double decay_rate = 5.0;  // Decay constant
            rate = pattern->base_rate_mbps + 
                   (pattern->peak_rate_mbps - pattern->base_rate_mbps) * 
                   exp(-decay_rate * progress);
            break;
        }
        
        case PATTERN_CYCLIC: {
            // Cyclic pattern: triangle wave
            double progress = fmod(elapsed_sec, pattern->period_sec) / pattern->period_sec;
            if (progress < 0.5) {
                // Rising edge
                rate = pattern->base_rate_mbps + 
                       2.0 * (pattern->peak_rate_mbps - pattern->base_rate_mbps) * progress;
            } else {
                // Falling edge
                rate = pattern->peak_rate_mbps - 
                       2.0 * (pattern->peak_rate_mbps - pattern->base_rate_mbps) * (progress - 0.5);
            }
            break;
        }
        
        default:
            rate = pattern->base_rate_mbps;
            break;
    }
    
    // Clamp to valid range
    rate = fmax(0.0, fmin(rate, pattern->peak_rate_mbps));
    
    pattern->current_rate_mbps = rate;
    return rate;
}

void update_traffic_pattern(struct traffic_pattern *pattern) {
    uint64_t current_cycles = rte_rdtsc();
    
    if (pattern->start_cycles == 0) {
        pattern->start_cycles = current_cycles;
    }
    
    pattern->current_rate_mbps = calculate_pattern_rate(pattern, current_cycles);
    pattern->last_update_cycles = current_cycles;
}

// ============================================================================
// PATTERN INITIALIZATION HELPERS
// ============================================================================

void init_constant_pattern(struct traffic_pattern *pattern, double rate_mbps) {
    memset(pattern, 0, sizeof(*pattern));
    pattern->type = PATTERN_CONSTANT;
    pattern->base_rate_mbps = rate_mbps;
    pattern->peak_rate_mbps = rate_mbps;
    pattern->current_rate_mbps = rate_mbps;
}

void init_ramp_pattern(struct traffic_pattern *pattern, 
                       bool ramp_up,
                       double start_rate_mbps, 
                       double end_rate_mbps,
                       uint32_t duration_sec) {
    memset(pattern, 0, sizeof(*pattern));
    pattern->type = ramp_up ? PATTERN_RAMP_UP : PATTERN_RAMP_DOWN;
    pattern->base_rate_mbps = ramp_up ? start_rate_mbps : end_rate_mbps;
    pattern->peak_rate_mbps = ramp_up ? end_rate_mbps : start_rate_mbps;
    pattern->period_sec = duration_sec;
}

void init_sine_wave_pattern(struct traffic_pattern *pattern,
                            double min_rate_mbps,
                            double max_rate_mbps,
                            uint32_t period_sec) {
    memset(pattern, 0, sizeof(*pattern));
    pattern->type = PATTERN_SINE_WAVE;
    pattern->base_rate_mbps = min_rate_mbps;
    pattern->peak_rate_mbps = max_rate_mbps;
    pattern->period_sec = period_sec;
}

void init_burst_pattern(struct traffic_pattern *pattern,
                        double burst_rate_mbps,
                        uint32_t burst_duration_ms,
                        uint32_t idle_duration_ms) {
    memset(pattern, 0, sizeof(*pattern));
    pattern->type = PATTERN_BURST;
    pattern->base_rate_mbps = 0.0;
    pattern->peak_rate_mbps = burst_rate_mbps;
    pattern->burst_duration_ms = burst_duration_ms;
    pattern->idle_duration_ms = idle_duration_ms;
}

void init_random_pattern(struct traffic_pattern *pattern,
                         enum pattern_type type,
                         double mean,
                         double stddev) {
    memset(pattern, 0, sizeof(*pattern));
    pattern->type = type;
    pattern->random_mean = mean;
    pattern->random_stddev = stddev;
    pattern->base_rate_mbps = 0.0;
    pattern->peak_rate_mbps = mean * 3.0;  // 3 sigma limit
}

// ============================================================================
// PATTERN-AWARE PACKET GENERATION
// ============================================================================

uint64_t calculate_inter_packet_gap_ns(struct traffic_pattern *pattern, 
                                        uint16_t packet_size) {
    // Update pattern to get current rate
    update_traffic_pattern(pattern);
    
    double current_rate_mbps = pattern->current_rate_mbps;
    
    if (current_rate_mbps <= 0.0) {
        return UINT64_MAX;  // No transmission
    }
    
    // Calculate inter-packet gap for current rate
    // Rate (Mbps) = (packet_size * 8) / (gap_ns / 1e9)
    // gap_ns = (packet_size * 8 * 1e9) / Rate_Mbps / 1e6
    
    double gap_ns = ((double)packet_size * 8.0 * 1000.0) / current_rate_mbps;
    
    return (uint64_t)gap_ns;
}

// ============================================================================
// PATTERN STATISTICS
// ============================================================================

void print_pattern_stats(struct traffic_pattern *pattern) {
    const char *pattern_names[] = {
        "Constant", "Ramp Up", "Ramp Down", "Sine Wave", "Burst",
        "Random Poisson", "Random Exponential", "Random Normal",
        "Step Function", "Decay", "Cyclic"
    };
    
    printf("Pattern Type: %s\n", pattern_names[pattern->type]);
    printf("Base Rate: %.2f Mbps\n", pattern->base_rate_mbps);
    printf("Peak Rate: %.2f Mbps\n", pattern->peak_rate_mbps);
    printf("Current Rate: %.2f Mbps\n", pattern->current_rate_mbps);
    
    if (pattern->period_sec > 0) {
        printf("Period: %u seconds\n", pattern->period_sec);
    }
    
    if (pattern->burst_duration_ms > 0) {
        printf("Burst Duration: %u ms\n", pattern->burst_duration_ms);
        printf("Idle Duration: %u ms\n", pattern->idle_duration_ms);
    }
    
    if (pattern->type >= PATTERN_RANDOM_POISSON && 
        pattern->type <= PATTERN_RANDOM_NORMAL) {
        printf("Mean: %.2f\n", pattern->random_mean);
        if (pattern->type == PATTERN_RANDOM_NORMAL) {
            printf("Std Dev: %.2f\n", pattern->random_stddev);
        }
    }
}

// ============================================================================
// JSON CONFIGURATION PARSING
// ============================================================================

int parse_traffic_pattern_json(struct json_object *json, 
                                struct traffic_pattern *pattern) {
    struct json_object *type_obj, *base_obj, *peak_obj, *period_obj;
    struct json_object *burst_dur_obj, *idle_dur_obj, *mean_obj, *stddev_obj;
    
    // Pattern type
    if (json_object_object_get_ex(json, "pattern_type", &type_obj)) {
        const char *type_str = json_object_get_string(type_obj);
        
        if (strcmp(type_str, "constant") == 0) pattern->type = PATTERN_CONSTANT;
        else if (strcmp(type_str, "ramp_up") == 0) pattern->type = PATTERN_RAMP_UP;
        else if (strcmp(type_str, "ramp_down") == 0) pattern->type = PATTERN_RAMP_DOWN;
        else if (strcmp(type_str, "sine_wave") == 0) pattern->type = PATTERN_SINE_WAVE;
        else if (strcmp(type_str, "burst") == 0) pattern->type = PATTERN_BURST;
        else if (strcmp(type_str, "random_poisson") == 0) pattern->type = PATTERN_RANDOM_POISSON;
        else if (strcmp(type_str, "random_exponential") == 0) pattern->type = PATTERN_RANDOM_EXPONENTIAL;
        else if (strcmp(type_str, "random_normal") == 0) pattern->type = PATTERN_RANDOM_NORMAL;
        else if (strcmp(type_str, "step") == 0) pattern->type = PATTERN_STEP_FUNCTION;
        else if (strcmp(type_str, "decay") == 0) pattern->type = PATTERN_DECAY;
        else if (strcmp(type_str, "cyclic") == 0) pattern->type = PATTERN_CYCLIC;
        else pattern->type = PATTERN_CONSTANT;
    }
    
    // Rates
    if (json_object_object_get_ex(json, "base_rate_mbps", &base_obj)) {
        pattern->base_rate_mbps = json_object_get_double(base_obj);
    }
    if (json_object_object_get_ex(json, "peak_rate_mbps", &peak_obj)) {
        pattern->peak_rate_mbps = json_object_get_double(peak_obj);
    }
    
    // Period
    if (json_object_object_get_ex(json, "period_sec", &period_obj)) {
        pattern->period_sec = json_object_get_int(period_obj);
    }
    
    // Burst parameters
    if (json_object_object_get_ex(json, "burst_duration_ms", &burst_dur_obj)) {
        pattern->burst_duration_ms = json_object_get_int(burst_dur_obj);
    }
    if (json_object_object_get_ex(json, "idle_duration_ms", &idle_dur_obj)) {
        pattern->idle_duration_ms = json_object_get_int(idle_dur_obj);
    }
    
    // Random distribution parameters
    if (json_object_object_get_ex(json, "mean", &mean_obj)) {
        pattern->random_mean = json_object_get_double(mean_obj);
    }
    if (json_object_object_get_ex(json, "stddev", &stddev_obj)) {
        pattern->random_stddev = json_object_get_double(stddev_obj);
    }
    
    return 0;
}
