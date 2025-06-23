#!/bin/bash

# Installation script for PVE PCIe Network Fix
# This script installs the pve-pcie-netfix service to run at boot

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="pve-pcie-netfix.sh"
SERVICE_NAME="pve-pcie-netfix.service"
INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

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
        print_error "This installation script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
    fi
}

# Function to check if files exist
check_files() {
    if [[ ! -f "$SCRIPT_NAME" ]]; then
        print_error "Script file not found: $SCRIPT_NAME"
        print_info "Please make sure you're running this from the correct directory"
        exit 1
    fi

    if [[ ! -f "$SERVICE_NAME" ]]; then
        print_error "Service file not found: $SERVICE_NAME"
        print_info "Please make sure you're running this from the correct directory"
        exit 1
    fi
}

# Function to install the script
install_script() {
    print_info "Installing $SCRIPT_NAME to $INSTALL_DIR..."

    # Copy script to system directory
    cp "$SCRIPT_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

    print_success "Script installed to $INSTALL_DIR/$SCRIPT_NAME"
}

# Function to install the service
install_service() {
    print_info "Installing systemd service..."

    # Copy service file to systemd directory
    cp "$SERVICE_NAME" "$SERVICE_DIR/"

    # Reload systemd daemon
    systemctl daemon-reload

    print_success "Service file installed to $SERVICE_DIR/$SERVICE_NAME"
}

# Function to enable the service
enable_service() {
    print_info "Enabling $SERVICE_NAME to run at boot..."

    # Enable the service
    systemctl enable "$SERVICE_NAME"

    print_success "Service enabled successfully"
}

# Function to test the service
test_service() {
    print_info "Testing the service..."

    # Test the service
    if systemctl start "$SERVICE_NAME"; then
        print_success "Service started successfully"

        # Check service status
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "Service is running correctly"
        else
            print_warning "Service started but may not be active"
        fi

        # Show service status
        print_info "Service status:"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        print_error "Failed to start service"
        print_info "Check the logs with: journalctl -u $SERVICE_NAME"
        return 1
    fi
}

# Function to show installation summary
show_summary() {
    echo
    print_success "Installation completed successfully!"
    echo
    print_info "The PVE PCIe Network Fix service has been installed and will run automatically at boot."
    echo
    print_info "Useful commands:"
    echo "  - Check service status: systemctl status $SERVICE_NAME"
    echo "  - View service logs: journalctl -u $SERVICE_NAME"
    echo "  - Run manually: systemctl start $SERVICE_NAME"
    echo "  - Disable auto-start: systemctl disable $SERVICE_NAME"
    echo "  - Run script directly: $INSTALL_DIR/$SCRIPT_NAME"
    echo
    print_info "The service will automatically detect and fix PCIe network interface changes on every boot."
}

# Function to uninstall
uninstall() {
    print_info "Uninstalling PVE PCIe Network Fix service..."

    # Stop and disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
        print_info "Service disabled"
    fi

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
        print_info "Service stopped"
    fi

    # Remove files
    if [[ -f "$SERVICE_DIR/$SERVICE_NAME" ]]; then
        rm -f "$SERVICE_DIR/$SERVICE_NAME"
        print_info "Service file removed"
    fi

    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        rm -f "$INSTALL_DIR/$SCRIPT_NAME"
        print_info "Script file removed"
    fi

    # Reload systemd
    systemctl daemon-reload

    print_success "Uninstallation completed"
}

# Function to show help
show_help() {
    echo "PVE PCIe Network Fix Installation Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -u, --uninstall  Uninstall the service"
    echo "  -t, --test-only  Install and test without enabling auto-start"
    echo
    echo "This script installs the PVE PCIe Network Fix service to run automatically at boot."
    echo "The service will detect RTL8111/8168/8211/8411 network cards and update"
    echo "the network configuration accordingly."
}

# Main installation function
main() {
    print_info "PVE PCIe Network Fix Installation Starting..."

    # Check if running as root
    check_root

    # Check if required files exist
    check_files

    # Install script
    install_script

    # Install service
    install_service

    # Enable service (unless test-only mode)
    if [[ "${1:-}" != "--test-only" ]]; then
        enable_service
    fi

    # Test service
    if test_service; then
        show_summary
    else
        print_error "Installation completed but service test failed"
        print_info "Please check the logs and configuration"
        exit 1
    fi
}

# Parse command line arguments
case "${1:-}" in
-h | --help)
    show_help
    exit 0
    ;;
-u | --uninstall)
    check_root
    uninstall
    exit 0
    ;;
-t | --test-only)
    main --test-only
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
