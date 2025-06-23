#!/bin/bash

# PVE PCIe Network Fix Script
# Automatically fixes network interface configuration when PCIe network card sequence changes
# Author: Generated for PVE PCIe network card management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INTERFACES_FILE="/etc/network/interfaces"
BACKUP_DIR="/etc/network/backup"
TARGET_CONTROLLER="RTL8111/8168/8211/8411"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Function to create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        print_info "Created backup directory: $BACKUP_DIR"
    fi
}

# Function to backup current interfaces file
backup_interfaces() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/interfaces_$timestamp"

    if [[ -f "$INTERFACES_FILE" ]]; then
        cp "$INTERFACES_FILE" "$backup_file"
        print_success "Backed up current interfaces file to: $backup_file"
    else
        print_warning "Interfaces file not found: $INTERFACES_FILE"
    fi
}

# Function to detect RTL network card PCIe sequence
detect_network_card() {
    print_info "Detecting RTL8111/8168/8211/8411 network cards..."

    local pcie_info
    pcie_info=$(lspci | grep Ethernet | grep "$TARGET_CONTROLLER")

    if [[ -z "$pcie_info" ]]; then
        print_error "No RTL8111/8168/8211/8411 network card found"
        exit 1
    fi

    print_info "Found network card(s):"
    echo "$pcie_info"

    # Extract PCIe sequence number (e.g., "06:00.0" -> "6")
    local pcie_sequence
    pcie_sequence=$(echo "$pcie_info" | head -n1 | cut -d':' -f1 | sed 's/^0*//')

    if [[ -z "$pcie_sequence" ]]; then
        print_error "Failed to extract PCIe sequence number"
        exit 1
    fi

    echo "$pcie_sequence"
}

# Function to get current interface name from config
get_current_interface() {
    if [[ ! -f "$INTERFACES_FILE" ]]; then
        print_error "Interfaces file not found: $INTERFACES_FILE"
        exit 1
    fi

    # Look for enp*s0 pattern in bridge-ports line
    local current_interface
    current_interface=$(grep "bridge-ports" "$INTERFACES_FILE" | grep -o "enp[0-9]*s0" | head -n1)

    if [[ -z "$current_interface" ]]; then
        print_warning "No enp*s0 interface found in current configuration"
        return 1
    fi

    echo "$current_interface"
}

# Function to update interfaces file
update_interfaces() {
    local new_sequence="$1"
    local new_interface="enp${new_sequence}s0"

    print_info "Updating network interface to: $new_interface"

    # Get current interface name
    local current_interface
    if current_interface=$(get_current_interface); then
        print_info "Current interface in config: $current_interface"

        if [[ "$current_interface" == "$new_interface" ]]; then
            print_success "Interface configuration is already correct: $new_interface"
            return 0
        fi
    else
        print_warning "Could not determine current interface, proceeding with update"
        current_interface="enp[0-9]*s0"
    fi

    # Create temporary file for new configuration
    local temp_file
    temp_file=$(mktemp)

    # Replace interface name in configuration
    if [[ "$current_interface" =~ ^enp[0-9]+s0$ ]]; then
        # Replace specific interface name
        sed "s/$current_interface/$new_interface/g" "$INTERFACES_FILE" >"$temp_file"
    else
        # Use regex replacement for any enp*s0 pattern
        sed "s/enp[0-9]*s0/$new_interface/g" "$INTERFACES_FILE" >"$temp_file"
    fi

    # Verify the change was made
    if grep -q "$new_interface" "$temp_file"; then
        mv "$temp_file" "$INTERFACES_FILE"
        print_success "Updated interface configuration to: $new_interface"
    else
        rm -f "$temp_file"
        print_error "Failed to update interface configuration"
        exit 1
    fi
}

# Function to restart networking
restart_networking() {
    print_info "Restarting networking service..."

    if systemctl restart networking; then
        print_success "Networking service restarted successfully"
    else
        print_warning "Failed to restart networking service automatically"
        print_info "Please restart networking manually with: systemctl restart networking"
        print_info "Or reboot the system to apply changes"
    fi
}

# Function to show current network status
show_network_status() {
    print_info "Current network interface status:"
    ip addr show | grep -E "^[0-9]+:|inet " | grep -A1 "enp.*s0"

    print_info "Current bridge status:"
    brctl show 2>/dev/null || ip link show type bridge
}

# Main function
main() {
    print_info "PVE PCIe Network Fix Script Starting..."

    # Check if running as root
    check_root

    # Create backup directory
    create_backup_dir

    # Backup current configuration
    backup_interfaces

    # Detect network card PCIe sequence
    local pcie_sequence
    pcie_sequence=$(detect_network_card)
    print_success "Detected PCIe sequence: $pcie_sequence"

    # Update interfaces configuration
    update_interfaces "$pcie_sequence"

    # Ask user if they want to restart networking
    echo
    read -p "Do you want to restart networking now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_networking
        echo
        show_network_status
    else
        print_info "Network configuration updated but not restarted"
        print_info "Please restart networking with: systemctl restart networking"
        print_info "Or reboot the system to apply changes"
    fi

    print_success "PVE PCIe Network Fix completed successfully!"
}

# Help function
show_help() {
    echo "PVE PCIe Network Fix Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --dry-run  Show what would be changed without making changes"
    echo "  -s, --status   Show current network configuration"
    echo
    echo "This script automatically detects RTL8111/8168/8211/8411 PCIe network cards"
    echo "and updates /etc/network/interfaces with the correct interface name."
}

# Dry run function
dry_run() {
    print_info "DRY RUN MODE - No changes will be made"

    # Detect network card
    local pcie_sequence
    pcie_sequence=$(detect_network_card)
    print_info "Detected PCIe sequence: $pcie_sequence"

    local new_interface="enp${pcie_sequence}s0"
    print_info "New interface would be: $new_interface"

    # Show current configuration
    if [[ -f "$INTERFACES_FILE" ]]; then
        print_info "Current configuration in $INTERFACES_FILE:"
        grep -n "enp.*s0\|bridge-ports" "$INTERFACES_FILE" || print_warning "No enp*s0 interface found in current config"
    fi

    print_info "DRY RUN completed - no changes made"
}

# Parse command line arguments
case "${1:-}" in
-h | --help)
    show_help
    exit 0
    ;;
-d | --dry-run)
    dry_run
    exit 0
    ;;
-s | --status)
    show_network_status
    exit 0
    ;;
"")
    main
    ;;
*)
    print_error "Unknown option: $1"
    show_help
    exit 1
    ;;
esac
