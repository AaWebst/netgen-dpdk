#!/bin/bash

#
# Hugepage Configuration Fix Script
# Detects and configures hugepages for your system
#

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              Hugepage Configuration Utility                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Function to find hugepage directory
find_hugepage_dir() {
    echo "Detecting hugepage configuration..."
    
    # Check for 2MB hugepages (most common)
    if [ -d "/sys/kernel/mm/hugepages/hugepages-2048kB" ]; then
        echo "✅ Found 2MB hugepages at: /sys/kernel/mm/hugepages/hugepages-2048kB"
        HUGEPAGE_DIR="/sys/kernel/mm/hugepages/hugepages-2048kB"
        HUGEPAGE_SIZE="2048kB"
        return 0
    fi
    
    # Check alternative naming (hugepages-2M)
    if [ -d "/sys/kernel/mm/hugepages/hugepages-2M" ]; then
        echo "✅ Found 2MB hugepages at: /sys/kernel/mm/hugepages/hugepages-2M"
        HUGEPAGE_DIR="/sys/kernel/mm/hugepages/hugepages-2M"
        HUGEPAGE_SIZE="2M"
        return 0
    fi
    
    # List all available hugepage sizes
    echo "Available hugepage sizes on your system:"
    ls -la /sys/kernel/mm/hugepages/ 2>/dev/null || echo "No hugepages directory found!"
    
    return 1
}

# Function to configure hugepages
configure_hugepages() {
    local num_pages=$1
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Configuring $num_pages hugepages of size $HUGEPAGE_SIZE"
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Allocate hugepages
    echo "Allocating hugepages..."
    echo $num_pages | sudo tee ${HUGEPAGE_DIR}/nr_hugepages
    
    # Verify allocation
    sleep 1
    ALLOCATED=$(cat ${HUGEPAGE_DIR}/nr_hugepages)
    FREE=$(cat ${HUGEPAGE_DIR}/free_hugepages)
    
    echo ""
    echo "Hugepage Status:"
    echo "  Requested: $num_pages"
    echo "  Allocated: $ALLOCATED"
    echo "  Free: $FREE"
    
    if [ "$ALLOCATED" -lt "$num_pages" ]; then
        echo ""
        echo "⚠️  Warning: Could only allocate $ALLOCATED hugepages (requested $num_pages)"
        echo "   This may be due to memory fragmentation."
        echo "   Try rebooting or freeing up memory."
        echo ""
        echo "   Current memory status:"
        free -h
    else
        echo "✅ Successfully allocated $ALLOCATED hugepages"
    fi
}

# Function to mount hugepages
mount_hugepages() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Mounting hugepage filesystem"
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Check if already mounted
    if mount | grep -q hugetlbfs; then
        echo "✅ Hugetlbfs already mounted:"
        mount | grep hugetlbfs
        return 0
    fi
    
    # Create mount point
    sudo mkdir -p /mnt/huge
    
    # Mount hugepages
    echo "Mounting hugetlbfs at /mnt/huge..."
    sudo mount -t hugetlbfs nodev /mnt/huge
    
    if mount | grep -q hugetlbfs; then
        echo "✅ Hugetlbfs mounted successfully"
    else
        echo "❌ Failed to mount hugetlbfs"
        return 1
    fi
}

# Function to make hugepages persistent
make_persistent() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Making hugepage configuration persistent"
    echo "═══════════════════════════════════════════════════════════════════"
    
    local num_pages=$1
    
    # Add to sysctl.conf if not present
    if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null; then
        echo "Adding to /etc/sysctl.conf..."
        echo "vm.nr_hugepages = $num_pages" | sudo tee -a /etc/sysctl.conf
    else
        echo "vm.nr_hugepages already in /etc/sysctl.conf"
        grep "vm.nr_hugepages" /etc/sysctl.conf
    fi
    
    # Add to /etc/fstab if not present
    if ! grep -q "/mnt/huge" /etc/fstab 2>/dev/null; then
        echo "Adding to /etc/fstab..."
        echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
    else
        echo "/mnt/huge already in /etc/fstab"
        grep "/mnt/huge" /etc/fstab
    fi
    
    echo "✅ Hugepage configuration will persist across reboots"
}

# Function to show hugepage status
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Current Hugepage Status"
    echo "═══════════════════════════════════════════════════════════════════"
    
    echo ""
    echo "Memory Information:"
    grep -E "Huge|^Mem" /proc/meminfo
    
    echo ""
    echo "Hugepage Filesystems:"
    mount | grep hugetlbfs || echo "  None mounted"
    
    echo ""
    echo "Available Hugepage Sizes:"
    ls -1 /sys/kernel/mm/hugepages/
}

# Main script
main() {
    echo "Checking current hugepage configuration..."
    echo ""
    
    # Find hugepage directory
    if ! find_hugepage_dir; then
        echo ""
        echo "❌ Could not find hugepage directory!"
        echo ""
        echo "Your kernel may not support hugepages, or they may be disabled."
        echo "Please check your kernel configuration."
        exit 1
    fi
    
    echo ""
    
    # Show current status
    show_status
    
    echo ""
    read -p "Do you want to configure hugepages now? (Y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
    
    # Ask for number of pages
    echo ""
    echo "How many hugepages do you want to allocate?"
    echo "  Recommended: 1024 (2GB for 2MB pages)"
    echo "  Minimum: 512 (1GB for 2MB pages)"
    read -p "Number of pages [1024]: " NUM_PAGES
    NUM_PAGES=${NUM_PAGES:-1024}
    
    # Configure hugepages
    configure_hugepages $NUM_PAGES
    
    # Mount hugepages
    mount_hugepages
    
    # Ask about persistence
    echo ""
    read -p "Make this configuration persistent across reboots? (Y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        make_persistent $NUM_PAGES
    fi
    
    # Final status
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    Configuration Complete!                         ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    
    show_status
    
    echo ""
    echo "You can now proceed with DPDK initialization."
    echo ""
}

# Run main function
main
