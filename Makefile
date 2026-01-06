# NetGen Pro - DPDK Edition Makefile

# DPDK configuration
RTE_SDK ?= /usr/local/share/dpdk
RTE_TARGET ?= x86_64-native-linux-gcc
PKGCONF ?= pkg-config

# If DPDK is installed via pkg-config
ifneq ($(shell $(PKGCONF) --exists libdpdk && echo 0),0)
$(error "DPDK not found. Please install DPDK or set RTE_SDK")
endif

# Compiler and flags
CXX = g++
CXXFLAGS = -O3 -g -std=c++17 -Wall -Wextra
CXXFLAGS += $(shell $(PKGCONF) --cflags libdpdk)
LDFLAGS = $(shell $(PKGCONF) --libs libdpdk)
LDFLAGS += -pthread -lm

# Directories
SRC_DIR = src
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

# Target
TARGET = $(BUILD_DIR)/dpdk_engine

# Phony targets
.PHONY: all clean install check-dpdk

all: check-dpdk $(TARGET)

check-dpdk:
	@echo "Checking DPDK installation..."
	@$(PKGCONF) --exists libdpdk || (echo "ERROR: DPDK not found" && exit 1)
	@echo "✅ DPDK found: $(shell $(PKGCONF) --modversion libdpdk)"

$(TARGET): $(OBJECTS)
	@mkdir -p $(BUILD_DIR)
	@echo "Linking $@..."
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo "✅ Build complete: $@"

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(OBJ_DIR)
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete"

install: all
	@echo "Installing dpdk_engine to /usr/local/bin..."
	sudo cp $(TARGET) /usr/local/bin/
	sudo chmod +x /usr/local/bin/dpdk_engine
	@echo "✅ Installation complete"

# Development helpers
run: all
	sudo $(TARGET) -l 0-3 -n 4 --proc-type primary

debug: CXXFLAGS += -DDEBUG -g3
debug: all

# Show configuration
info:
	@echo "DPDK Version: $(shell $(PKGCONF) --modversion libdpdk)"
	@echo "DPDK CFLAGS: $(shell $(PKGCONF) --cflags libdpdk)"
	@echo "DPDK LDFLAGS: $(shell $(PKGCONF) --libs libdpdk)"
	@echo "CXX: $(CXX)"
	@echo "CXXFLAGS: $(CXXFLAGS)"
	@echo "Sources: $(SOURCES)"
	@echo "Objects: $(OBJECTS)"
