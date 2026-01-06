# Python Virtual Environment

NetGen Pro - DPDK Edition uses a Python virtual environment to avoid conflicts with system packages and comply with PEP 668 (externally managed environments).

## Automatic Setup

The installation script automatically creates and configures a virtual environment:

```bash
./scripts/install.sh
```

This creates:
- `venv/` directory with isolated Python packages
- `activate.sh` helper script for easy activation

## Manual Activation

If you need to activate the environment manually:

```bash
source activate.sh
# or
source venv/bin/activate
```

## Automatic Activation

The `start.sh` script automatically activates the virtual environment, so you don't need to activate it manually when using the quick start script.

## Deactivation

To deactivate the virtual environment:

```bash
deactivate
```

## Why Virtual Environment?

Modern Python distributions (like Ubuntu 24.04) mark the system Python as "externally managed" to prevent conflicts. Using a virtual environment:
- ✅ Avoids "externally-managed-environment" errors
- ✅ Isolates project dependencies
- ✅ Prevents system package conflicts
- ✅ Follows Python best practices (PEP 668)
- ✅ Makes the project portable

## Troubleshooting

**Issue: "This environment is externally managed"**
```bash
# The installer handles this automatically by using venv
./scripts/install.sh
```

**Issue: Commands not found after installation**
```bash
# Activate the virtual environment first
source activate.sh
```

**Issue: Want to reinstall packages**
```bash
source venv/bin/activate
pip install -r requirements.txt
```
