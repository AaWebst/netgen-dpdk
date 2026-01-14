# NetGen Pro DPDK - Complete Build System

CC = g++
CFLAGS = -O3 -march=native -Wall -Wextra -std=c++17
CFLAGS += $(shell pkg-config --cflags libdpdk json-c 2>/dev/null || echo "-I/usr/local/include/dpdk -I/usr/include/json-c")
LDFLAGS = $(shell pkg-config --libs libdpdk json-c 2>/dev/null || echo "-ldpdk -ljson-c")
LDFLAGS += -pthread -lm

# Directories
SRC_DIR = src
BUILD_DIR = build
WEB_DIR = web

# Targets
TARGET = $(BUILD_DIR)/dpdk_engine
SRC = $(SRC_DIR)/dpdk_engine.cpp

# Features
CFLAGS += -DENABLE_RX_SUPPORT
CFLAGS += -DENABLE_RFC2544
CFLAGS += -DENABLE_HTTP_DNS
CFLAGS += -DENABLE_IMPAIRMENTS
CFLAGS += -DENABLE_IPV6_MPLS

.PHONY: all clean install test help

all: $(TARGET)
	@echo "✅ Build complete: $(TARGET)"
	@echo "   Run with: sudo ./$(TARGET)"

$(TARGET): $(SRC)
	@echo "🔨 Building NetGen Pro DPDK Complete..."
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)
	@echo "✅ Compilation successful"

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -f *.o *.a
	@echo "✅ Clean complete"

install: all
	@echo "📦 Installing NetGen Pro DPDK..."
	mkdir -p /opt/netgen-pro-complete
	cp -r . /opt/netgen-pro-complete/
	@echo "✅ Installed to /opt/netgen-pro-complete"

test: all
	@echo "🧪 Running tests..."
	@echo "   Unit tests not yet implemented"
	@echo "   Run integration tests manually with RFC 2544"

help:
	@echo "NetGen Pro DPDK - Complete Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build the DPDK engine"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Install to /opt/netgen-pro-complete"
	@echo "  make test     - Run tests"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Features enabled:"
	@echo "  ✓ Phase 2: HTTP/DNS protocols"
	@echo "  ✓ Phase 3: RFC 2544 + RX support"
	@echo "  ✓ Phase 4: Network impairments"
	@echo "  ✓ Phase 5: IPv6/MPLS/Advanced"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - DPDK libraries (dpdk-dev)"
	@echo "  - JSON-C library (libjson-c-dev)"
	@echo "  - C++17 compiler (g++ or clang++)"
	@echo ""

# Development targets
debug: CFLAGS += -g -DDEBUG -O0
debug: all
	@echo "✅ Debug build complete"

release: CFLAGS += -O3 -DNDEBUG
release: all
	@echo "✅ Release build complete"

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@pkg-config --exists libdpdk && echo "  ✓ DPDK found" || echo "  ✗ DPDK not found"
	@pkg-config --exists json-c && echo "  ✓ JSON-C found" || echo "  ✗ JSON-C not found"
	@which g++ > /dev/null && echo "  ✓ g++ found" || echo "  ✗ g++ not found"
