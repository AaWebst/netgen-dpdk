# Hugepage Configuration Error - Quick Fix

## The Problem

You're seeing this error:
```
tee: /sys/kernel/mm/hugepages/hugepages-2M/nr_hugepages: No such file or directory
```

This happens because your system uses a different hugepage directory path than expected.

## Quick Fix (Choose One)

### Option 1: Use the Fix Script (Recommended)

I've created a script that auto-detects your system's hugepage configuration:

```bash
chmod +x fix-hugepages.sh
./fix-hugepages.sh
```

This will:
- ✅ Auto-detect your hugepage directory
- ✅ Configure hugepages correctly
- ✅ Mount the hugepage filesystem
- ✅ Make it persistent across reboots

### Option 2: Manual Fix

Find your hugepage directory:

```bash
ls -la /sys/kernel/mm/hugepages/
```

You'll see something like:
- `hugepages-2048kB` (most common)
- `hugepages-2M` (some systems)
- `hugepages-1048576kB` (for 1GB pages)

Then allocate hugepages manually:

```bash
# For 2048kB (2MB) pages - most common
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Verify
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
grep Huge /proc/meminfo
```

Mount hugepages:

```bash
sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge
```

Make persistent:

```bash
# Add to sysctl
echo "vm.nr_hugepages = 1024" | sudo tee -a /etc/sysctl.conf

# Add to fstab
echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab
```

## Verify Configuration

Check if hugepages are working:

```bash
# Should show allocated hugepages
grep Huge /proc/meminfo

# Should show mount point
mount | grep huge

# Should show allocated pages
cat /sys/kernel/mm/hugepages/hugepages-*/nr_hugepages
```

Expected output:
```
HugePages_Total:    1024
HugePages_Free:     1024
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
```

## Why This Happens

Different Linux distributions and kernel versions use different naming:
- **Ubuntu/Debian**: Usually `hugepages-2048kB`
- **RHEL/CentOS**: Sometimes `hugepages-2M`
- **Older kernels**: May use different paths

The fix script auto-detects this for you!

## Continue Installation

After fixing hugepages:

```bash
# Continue with the install script
./scripts/install.sh

# Or skip directly to building
make

# Then start
./start.sh
```

## Troubleshooting

### "Could not allocate enough hugepages"

This happens when memory is fragmented. Solutions:

```bash
# 1. Free memory
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

# 2. Try again
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# 3. If still failing, reboot (best solution for fragmentation)
sudo reboot
```

### "Permission denied"

Make sure you're using `sudo`:

```bash
sudo echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

### "Hugepages not supported"

Check if your kernel supports hugepages:

```bash
# Should show hugepage directories
ls /sys/kernel/mm/hugepages/

# If empty or doesn't exist, your kernel may not support hugepages
uname -r  # Check kernel version (need 2.6.23+)
```

## Alternative: Use Smaller Allocation

If you can't get 1024 pages, you can use fewer:

```bash
# Try 512 pages (1GB instead of 2GB)
echo 512 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Verify
grep Huge /proc/meminfo
```

**Note:** Less hugepages = less DPDK performance, but it will still work.

## Need Help?

If you're still having issues:

1. Run the diagnostic:
   ```bash
   ./fix-hugepages.sh  # Choose "n" to just see status
   ```

2. Check your output:
   ```bash
   grep Huge /proc/meminfo
   ls -la /sys/kernel/mm/hugepages/
   mount | grep huge
   ```

3. Share the output for troubleshooting

---

**Quick Summary:**
1. Download: `fix-hugepages.sh`
2. Run: `chmod +x fix-hugepages.sh && ./fix-hugepages.sh`
3. Follow prompts
4. Done! ✅
