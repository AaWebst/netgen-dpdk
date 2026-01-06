# Permission Fix for /opt Installation

## Problem

When NetGen Pro is installed in `/opt/netgen-dpdk` (or any system directory), the install script needs write permission to create the Python virtual environment.

## Error Message

```
Error: [Errno 13] Permission denied: '/opt/netgen-dpdk/venv'
```

## Solutions

### Option 1: Change Ownership (Recommended)

Give yourself ownership of the installation directory:

```bash
sudo chown -R $USER:$USER /opt/netgen-dpdk
```

Then run the install script normally:

```bash
./scripts/install.sh
```

**Why this works:** You now own the directory and can create files/folders in it.

### Option 2: Install in Home Directory

Copy NetGen Pro to your home directory where you have write permissions:

```bash
cp -r /opt/netgen-dpdk ~/netgen-dpdk
cd ~/netgen-dpdk
./scripts/install.sh
```

**Why this works:** Your home directory is always writable by you.

### Option 3: Run from Home, Symlink from /opt

Install in home but keep convenience symlink in /opt:

```bash
# Install in home
cp -r /opt/netgen-dpdk ~/netgen-dpdk
cd ~/netgen-dpdk
./scripts/install.sh

# Create symlink in /opt (optional)
sudo rm -rf /opt/netgen-dpdk
sudo ln -s ~/netgen-dpdk /opt/netgen-dpdk
```

**Why this works:** Actual files in your home (writable), symlink provides convenient path.

## Why This Happens

Python virtual environments (`venv`) need to create directories and files:
- `venv/` - Main virtual environment directory
- `venv/bin/` - Python executables
- `venv/lib/` - Python packages
- `venv/pyvenv.cfg` - Configuration file

System directories like `/opt` require root permissions to write to. However, we **don't want to run the install script as root** because:
1. Python venv should be owned by regular user
2. Installing packages as root is a security risk
3. DPDK engine should be built as regular user

## Recommended Setup

### For Development/Testing

```bash
# Install in home directory
~/netgen-dpdk/
```

### For Production

```bash
# Create dedicated directory with proper ownership
sudo mkdir -p /opt/netgen-dpdk
sudo chown -R netgen:netgen /opt/netgen-dpdk

# Then as netgen user:
cd /opt/netgen-dpdk
./scripts/install.sh
```

Or use systemd user services to run from home directory.

## Quick Fix Command

If you're in `/opt/netgen-dpdk` right now:

```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/netgen-dpdk

# Run install
./scripts/install.sh
```

That's it!

## Verification

After applying the fix, verify you have write permission:

```bash
cd /opt/netgen-dpdk
touch test.txt
rm test.txt
```

If that works without `sudo`, you're good to go!

## Alternative: Use --user Flag (NOT Recommended)

You could install Python packages with `pip install --user`, but this:
- ❌ Doesn't isolate dependencies
- ❌ Can conflict with system packages
- ❌ Doesn't follow modern Python best practices (PEP 668)
- ❌ Still causes issues on Ubuntu 24.04

**Use venv instead!** (Which the install script does automatically)
