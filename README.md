# PVE PCIe Network Fix

A script to automatically fix network interface configuration in Proxmox VE (PVE) when PCIe network cards are plugged/unplugged or replaced, causing network card sequence numbers to change.

## Problem

When using PCIe network cards in Proxmox VE, inserting/removing or replacing PCIe hardware can cause network card sequence numbers to change. For example, a network card that was previously `enp3s0` might become `enp6s0` after hardware changes, breaking the network configuration.

## Solution

This script automatically:
1. Detects RTL8111/8168/8211/8411 PCIe network cards
2. Extracts the current PCIe sequence number
3. Updates `/etc/network/interfaces` with the correct interface name
4. Optionally restarts networking services

## Features

- ✅ Automatic detection of RTL8111/8168/8211/8411 network cards
- ✅ Safe backup of current configuration before changes
- ✅ Dry-run mode to preview changes
- ✅ Systemd service for automatic boot-time execution
- ✅ Colored output for better readability
- ✅ Comprehensive error handling and logging
- ✅ Easy installation and uninstallation

## Files

- [`pve-pcie-netfix.sh`](./pve-pcie-netfix.sh) - Main script
- [`pve-pcie-netfix.service`](./pve-pcie-netfix.service) - Systemd service file
- [`install.sh`](./install.sh) - Installation script
- [`README.md`](./README.md) - This documentation

## Quick Start

### 1. Download and Install

```bash
# Clone the repository
git clone https://github.com/gitsang/pve-pcie-netfix.git
cd pve-pcie-netfix

# Install the service (requires root)
sudo ./install.sh
```

### 2. Manual Usage

```bash
# Run the script manually
sudo ./pve-pcie-netfix.sh

# Dry run to see what would change
sudo ./pve-pcie-netfix.sh --dry-run

# Show current network status
sudo ./pve-pcie-netfix.sh --status
```

## Installation

### Automatic Installation (Recommended)

The installation script will:
- Copy the script to `/usr/local/bin/`
- Install the systemd service
- Enable automatic execution at boot
- Test the service

```bash
sudo ./install.sh
```

### Manual Installation

If you prefer manual installation:

```bash
# Copy script to system directory
sudo cp pve-pcie-netfix.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/pve-pcie-netfix.sh

# Install systemd service
sudo cp pve-pcie-netfix.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pve-pcie-netfix.service

# Test the service
sudo systemctl start pve-pcie-netfix.service
```

## Usage

### Command Line Options

```bash
# Show help
./pve-pcie-netfix.sh --help

# Run normally (interactive)
sudo ./pve-pcie-netfix.sh

# Dry run (no changes made)
sudo ./pve-pcie-netfix.sh --dry-run

# Show current network status
sudo ./pve-pcie-netfix.sh --status
```

### Installation Script Options

```bash
# Show help
./install.sh --help

# Install normally
sudo ./install.sh

# Install but don't enable auto-start
sudo ./install.sh --test-only

# Uninstall
sudo ./install.sh --uninstall
```

## How It Works

### Detection Process

1. Uses [`lspci`](./pve-pcie-netfix.sh:67) to find RTL8111/8168/8211/8411 network cards:
   ```bash
   lspci | grep Ethernet | grep "RTL8111/8168/8211/8411"
   ```

2. Extracts PCIe sequence number from output like:
   ```
   06:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet Controller (rev 15)
   ```
   The sequence number is `6` (from `06:00.0`).

### Configuration Update

The script updates [`/etc/network/interfaces`](./etc/network/interfaces:1) by replacing the interface name in the `bridge-ports` line:

**Before:**
```
bridge-ports enp3s0
```

**After:**
```
bridge-ports enp6s0
```

### Backup System

- Backups are stored in `/etc/network/backup/`
- Filename format: `interfaces_YYYYMMDD_HHMMSS`
- Automatic backup before any changes

## Systemd Service

The service runs at boot time before network services start:

- **Service file:** [`/etc/systemd/system/pve-pcie-netfix.service`](./pve-pcie-netfix.service:1)
- **Execution order:** After `network-pre.target`, before `network.target`
- **Type:** `oneshot` (runs once and exits)

### Service Management

```bash
# Check service status
systemctl status pve-pcie-netfix.service

# View service logs
journalctl -u pve-pcie-netfix.service

# Start service manually
sudo systemctl start pve-pcie-netfix.service

# Enable/disable auto-start
sudo systemctl enable pve-pcie-netfix.service
sudo systemctl disable pve-pcie-netfix.service
```

## Example Network Configuration

The script works with standard PVE bridge configurations:

```bash
auto lo
iface lo inet loopback

iface enp6s0 inet manual

auto vmbr0
allow-hotplug vmbr0
iface vmbr0 inet static
        address 192.168.5.200/24
        gateway 192.168.5.1
        bridge-ports enp6s0
        bridge-stp off
        bridge-fd 0
iface vmbr0 inet6 auto

source /etc/network/interfaces.d/*
```

## Supported Network Cards

Currently supports Realtek network cards:
- RTL8111
- RTL8168  
- RTL8211
- RTL8411

The detection pattern can be easily modified in the script to support other network cards.

## Troubleshooting

### Common Issues

1. **Script requires root privileges**
   ```bash
   sudo ./pve-pcie-netfix.sh
   ```

2. **No network card detected**
   - Verify your network card is supported
   - Check with: `lspci | grep Ethernet`

3. **Service fails to start**
   ```bash
   # Check service logs
   journalctl -u pve-pcie-netfix.service
   
   # Check script logs
   sudo /usr/local/bin/pve-pcie-netfix.sh --dry-run
   ```

### Log Locations

- **Service logs:** `journalctl -u pve-pcie-netfix.service`
- **Network backups:** `/etc/network/backup/`
- **System logs:** `/var/log/syslog`

## Safety Features

- **Automatic backups** before any changes
- **Dry-run mode** to preview changes
- **Validation** of changes before applying
- **Error handling** with detailed messages
- **Rollback capability** using backup files

## Uninstallation

```bash
# Using the installation script
sudo ./install.sh --uninstall

# Manual uninstallation
sudo systemctl disable pve-pcie-netfix.service
sudo systemctl stop pve-pcie-netfix.service
sudo rm /etc/systemd/system/pve-pcie-netfix.service
sudo rm /usr/local/bin/pve-pcie-netfix.sh
sudo systemctl daemon-reload
```

## Development

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Testing

```bash
# Test without making changes
sudo ./pve-pcie-netfix.sh --dry-run

# Test installation without enabling
sudo ./install.sh --test-only
```

## License

This project is licensed under the MIT License - see the [`LICENSE`](./LICENSE:1) file for details.

## Changelog

### v1.0.0
- Initial release
- Automatic RTL8111/8168/8211/8411 detection
- Systemd service integration
- Backup and safety features
- Comprehensive installation script

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review service logs: `journalctl -u pve-pcie-netfix.service`
3. Run in dry-run mode: `sudo ./pve-pcie-netfix.sh --dry-run`
4. Open an issue on GitHub

## Acknowledgments

- Designed for Proxmox VE environments
- Supports common Realtek network cards
- Follows systemd best practices