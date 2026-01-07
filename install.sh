#!/bin/bash

# ===========================================
# WireGuard Panel Auto Installer
# ===========================================
# This script installs WireGuard Panel with Docker
# Supports Ubuntu/Debian and CentOS/RHEL
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Installer  🛡️                     ║"
    echo "║                                                           ║"
    echo "║     A Modern VPN Management System                        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print colored messages
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
    print_info "Detected OS: $OS $VERSION"
}

# Check and install prerequisites
install_prerequisites() {
    print_info "Checking and installing prerequisites..."

    case $OS in
        ubuntu|debian)
            apt-get update -y
            apt-get install -y curl wget git ca-certificates gnupg lsb-release
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum update -y
            yum install -y curl wget git ca-certificates
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    print_success "Prerequisites installed"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        docker --version
        return
    fi

    print_info "Installing Docker..."

    case $OS in
        ubuntu|debian)
            # Remove old versions
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

            # Add Docker's official GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            # Set up repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # Remove old versions
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true

            # Install using convenience script
            curl -fsSL https://get.docker.com | sh
            ;;
    esac

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    print_success "Docker installed successfully"
    docker --version
}

# Install WireGuard
install_wireguard() {
    if command -v wg &> /dev/null; then
        print_success "WireGuard is already installed"
        return
    fi

    print_info "Installing WireGuard..."

    case $OS in
        ubuntu|debian)
            apt-get install -y wireguard wireguard-tools
            ;;
        centos|rhel|rocky|almalinux)
            if [[ "$VERSION" == "7" ]]; then
                yum install -y epel-release elrepo-release
                yum install -y kmod-wireguard wireguard-tools
            else
                yum install -y epel-release
                yum install -y wireguard-tools
            fi
            ;;
        fedora)
            dnf install -y wireguard-tools
            ;;
    esac

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p

    print_success "WireGuard installed successfully"
}

# Setup WireGuard interface
setup_wireguard() {
    WG_INTERFACE="wg0"
    WG_PORT="51820"
    WG_NETWORK="10.0.0.0/24"
    WG_SERVER_IP="10.0.0.1"

    if [ -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
        print_warning "WireGuard interface $WG_INTERFACE already exists"
        read -p "Do you want to recreate it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    print_info "Setting up WireGuard interface..."

    # Generate server keys
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)

    # Get default network interface
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

    # Create WireGuard config
    cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
EOF

    chmod 600 /etc/wireguard/$WG_INTERFACE.conf

    # Start WireGuard
    wg-quick up $WG_INTERFACE
    systemctl enable wg-quick@$WG_INTERFACE

    print_success "WireGuard interface $WG_INTERFACE created"
    print_info "Server Public Key: $SERVER_PUBLIC_KEY"
}

# Clone and setup the panel
setup_panel() {
    INSTALL_DIR="/opt/wireguard-panel"

    print_info "Setting up WireGuard Panel..."

    # Create directory
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR

    # If we're running from the source directory, copy files
    if [ -f "$(dirname $0)/docker/docker-compose.yml" ]; then
        cp -r $(dirname $0)/* $INSTALL_DIR/
    else
        # Clone from repository (if available)
        print_info "Downloading panel files..."
        # For now, we'll create the necessary files
        mkdir -p backend frontend docker
    fi

    # Generate JWT secret
    JWT_SECRET=$(openssl rand -hex 32)

    # Create .env file
    cat > $INSTALL_DIR/docker/.env << EOF
JWT_SECRET=$JWT_SECRET
PANEL_PORT=80
EOF

    print_success "Panel files setup complete"
}

# Build and start containers
start_panel() {
    print_info "Building and starting containers..."

    cd /opt/wireguard-panel/docker

    # Build and start
    docker compose up -d --build

    print_success "Containers started successfully"
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "your-server-ip")
    echo $SERVER_IP
}

# Print installation complete message
print_complete() {
    SERVER_IP=$(get_server_ip)
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║     ✅  Installation Complete!                            ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Panel URL:${NC} http://$SERVER_IP"
    echo -e "${CYAN}Default Login:${NC}"
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Password: ${YELLOW}admin${NC}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Please change the default password immediately!${NC}"
    echo ""
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "   View logs:     ${YELLOW}cd /opt/wireguard-panel/docker && docker compose logs -f${NC}"
    echo -e "   Restart:       ${YELLOW}cd /opt/wireguard-panel/docker && docker compose restart${NC}"
    echo -e "   Stop:          ${YELLOW}cd /opt/wireguard-panel/docker && docker compose down${NC}"
    echo -e "   Update:        ${YELLOW}cd /opt/wireguard-panel/docker && docker compose pull && docker compose up -d${NC}"
    echo ""
    echo -e "${CYAN}WireGuard Status:${NC}"
    echo -e "   Check status:  ${YELLOW}wg show${NC}"
    echo -e "   Start:         ${YELLOW}wg-quick up wg0${NC}"
    echo -e "   Stop:          ${YELLOW}wg-quick down wg0${NC}"
    echo ""
}

# Main installation flow
main() {
    print_banner
    check_root
    detect_os

    echo ""
    print_info "Starting installation..."
    echo ""

    # Step 1: Install prerequisites
    print_info "Step 1/5: Installing prerequisites..."
    install_prerequisites

    # Step 2: Install Docker
    print_info "Step 2/5: Installing Docker..."
    install_docker

    # Step 3: Install WireGuard
    print_info "Step 3/5: Installing WireGuard..."
    install_wireguard

    # Step 4: Setup WireGuard interface
    print_info "Step 4/5: Setting up WireGuard interface..."
    setup_wireguard

    # Step 5: Setup and start panel
    print_info "Step 5/5: Setting up and starting panel..."
    setup_panel
    start_panel

    # Done!
    print_complete
}

# Run main function
main "$@"
