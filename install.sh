#!/bin/bash

# ===========================================
# WireGuard Panel Manager v2.0
# ===========================================
# Commands:
#   install   - Install the panel
#   start     - Start the panel
#   stop      - Stop the panel
#   restart   - Restart the panel
#   status    - Show panel status
#   update    - Update panel without losing data
#   uninstall - Remove panel completely
#   logs      - Show panel logs
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

# Variables
INSTALL_DIR="/opt/wireguard-panel"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
PANEL_PORT="80"
PANEL_SSL_PORT="443"
USE_SSL="n"
DOMAIN=""
SERVER_IP=""
SCRIPT_VERSION="2.0"

# Banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Manager v${SCRIPT_VERSION}  🛡️              ║"
    echo "║                                                           ║"
    echo "║     A Modern VPN Management System                        ║"
    echo "║     پنل مدیریت وایرگارد                                   ║"
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
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$SERVER_IP"
}

# Check if panel is installed
check_installed() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Panel is not installed. Run: $0 install"
        exit 1
    fi
}

# Check if Docker is running
check_docker() {
    if ! systemctl is-active --quiet docker; then
        print_error "Docker is not running. Starting Docker..."
        systemctl start docker
    fi
}

# ==================== PANEL COMMANDS ====================

# Start panel
cmd_start() {
    check_root
    check_installed
    check_docker
    
    print_info "Starting WireGuard Panel..."
    
    cd $INSTALL_DIR
    docker compose up -d
    
    # Start WireGuard if not running
    if ! wg show $WG_INTERFACE &>/dev/null; then
        wg-quick up $WG_INTERFACE 2>/dev/null || true
    fi
    
    sleep 3
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel started successfully!"
        cmd_status
    else
        print_error "Failed to start panel. Check logs with: $0 logs"
    fi
}

# Stop panel
cmd_stop() {
    check_root
    check_installed
    
    print_info "Stopping WireGuard Panel..."
    
    cd $INSTALL_DIR
    docker compose down
    
    print_success "Panel stopped successfully!"
}

# Restart panel
cmd_restart() {
    check_root
    check_installed
    check_docker
    
    print_info "Restarting WireGuard Panel..."
    
    cd $INSTALL_DIR
    docker compose restart
    
    sleep 3
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel restarted successfully!"
        cmd_status
    else
        print_error "Failed to restart panel. Check logs with: $0 logs"
    fi
}

# Show status
cmd_status() {
    check_root
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Panel Status                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check Docker containers
    echo -e "${YELLOW}Docker Containers:${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        cd $INSTALL_DIR
        docker compose ps 2>/dev/null || echo "  Not running"
    else
        echo "  Panel not installed"
    fi
    
    echo ""
    
    # Check WireGuard
    echo -e "${YELLOW}WireGuard Status:${NC}"
    if wg show $WG_INTERFACE &>/dev/null; then
        echo -e "  Interface: ${GREEN}UP${NC}"
        echo "  Peers: $(wg show $WG_INTERFACE peers | wc -l)"
    else
        echo -e "  Interface: ${RED}DOWN${NC}"
    fi
    
    echo ""
    
    # Show URLs
    SERVER_IP=$(get_server_ip)
    echo -e "${YELLOW}Access URLs:${NC}"
    if [ -f "$INSTALL_DIR/.env" ]; then
        source $INSTALL_DIR/.env 2>/dev/null
        if [ "$USE_SSL" = "y" ] && [ -n "$DOMAIN" ]; then
            echo "  Panel: https://$DOMAIN"
        else
            echo "  Panel: http://$SERVER_IP"
        fi
    else
        echo "  Panel: http://$SERVER_IP"
    fi
    
    echo ""
}

# Show logs
cmd_logs() {
    check_root
    check_installed
    
    cd $INSTALL_DIR
    docker compose logs -f --tail=100
}

# Update panel
cmd_update() {
    check_root
    check_installed
    check_docker
    
    print_banner
    
    echo ""
    print_info "Updating WireGuard Panel..."
    print_info "Your data will be preserved."
    echo ""
    
    cd $INSTALL_DIR
    
    # Backup current config
    print_info "Backing up configuration..."
    cp -f .env .env.backup 2>/dev/null || true
    
    # Stop containers
    print_info "Stopping containers..."
    docker compose down
    
    # Pull latest images or rebuild
    print_info "Rebuilding containers with latest code..."
    docker compose build --no-cache
    
    # Start containers
    print_info "Starting updated containers..."
    docker compose up -d
    
    sleep 5
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel updated successfully!"
        echo ""
        print_info "Your data has been preserved."
        cmd_status
    else
        print_error "Update failed. Restoring backup..."
        cp -f .env.backup .env 2>/dev/null || true
        docker compose up -d
    fi
}

# Uninstall panel
cmd_uninstall() {
    check_root
    
    print_banner
    
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                      ⚠️  WARNING  ⚠️                       ║${NC}"
    echo -e "${RED}║                                                           ║${NC}"
    echo -e "${RED}║   This will completely remove WireGuard Panel including:  ║${NC}"
    echo -e "${RED}║   - All Docker containers and images                      ║${NC}"
    echo -e "${RED}║   - All configuration files                               ║${NC}"
    echo -e "${RED}║   - All user data and clients                             ║${NC}"
    echo -e "${RED}║                                                           ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Are you sure you want to uninstall? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Uninstall cancelled."
        exit 0
    fi
    
    echo ""
    read -p "Do you want to keep WireGuard installed? (y/n): " keep_wg
    
    echo ""
    print_info "Uninstalling WireGuard Panel..."
    
    # Stop and remove containers
    if [ -d "$INSTALL_DIR" ]; then
        cd $INSTALL_DIR
        print_info "Stopping containers..."
        docker compose down -v 2>/dev/null || true
        
        print_info "Removing Docker images..."
        docker rmi $(docker images -q wireguard-panel* 2>/dev/null) 2>/dev/null || true
    fi
    
    # Remove installation directory
    print_info "Removing installation files..."
    rm -rf $INSTALL_DIR
    
    # Remove WireGuard config (optional)
    if [ "$keep_wg" != "y" ]; then
        print_info "Stopping WireGuard..."
        wg-quick down $WG_INTERFACE 2>/dev/null || true
        systemctl disable wg-quick@$WG_INTERFACE 2>/dev/null || true
        
        print_info "Removing WireGuard configuration..."
        rm -f /etc/wireguard/$WG_INTERFACE.conf
    fi
    
    # Clean up Docker
    print_info "Cleaning up Docker..."
    docker system prune -f 2>/dev/null || true
    
    echo ""
    print_success "WireGuard Panel has been uninstalled."
    
    if [ "$keep_wg" = "y" ]; then
        print_info "WireGuard has been kept installed."
    fi
}

# ==================== INSTALLATION ====================

# Ask user questions
ask_questions() {
    echo ""
    print_info "Configuration Questions / سوالات پیکربندی"
    echo ""
    
    # Get server IP
    SERVER_IP=$(get_server_ip)
    print_info "Server IP detected: $SERVER_IP"
    echo ""
    
    # Ask about domain and SSL
    echo -e "${YELLOW}Do you want to use a domain with SSL? / آیا می‌خواهید از دامنه با SSL استفاده کنید?${NC}"
    echo "1) Yes, I have a domain / بله، دامنه دارم"
    echo "2) No, use IP address / خیر، از IP استفاده کن"
    read -p "Choose [1-2]: " ssl_choice
    
    case $ssl_choice in
        1)
            USE_SSL="y"
            echo ""
            read -p "Enter your domain (e.g., vpn.example.com): " DOMAIN
            if [ -z "$DOMAIN" ]; then
                print_error "Domain cannot be empty"
                exit 1
            fi
            
            # Validate domain
            print_info "Validating domain..."
            DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | tail -n1)
            if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
                print_warning "Domain $DOMAIN does not point to this server ($SERVER_IP)"
                print_warning "Domain resolves to: $DOMAIN_IP"
                read -p "Continue anyway? (y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
            ENDPOINT="$DOMAIN"
            ;;
        *)
            USE_SSL="n"
            ENDPOINT="$SERVER_IP"
            ;;
    esac
    
    echo ""
    print_info "Configuration Summary / خلاصه پیکربندی:"
    echo "  - Endpoint: $ENDPOINT"
    echo "  - SSL: $([ "$USE_SSL" = "y" ] && echo "Yes" || echo "No")"
    echo "  - WireGuard Port: $WG_PORT"
    echo "  - Panel Port: $([ "$USE_SSL" = "y" ] && echo "$PANEL_SSL_PORT (HTTPS)" || echo "$PANEL_PORT (HTTP)")"
    echo ""
    read -p "Continue with installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# Check and install prerequisites
install_prerequisites() {
    print_info "Installing prerequisites..."

    case $OS in
        ubuntu|debian)
            apt-get update -y
            apt-get install -y curl wget git ca-certificates gnupg lsb-release dnsutils openssl
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum update -y
            yum install -y curl wget git ca-certificates bind-utils openssl
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
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL https://get.docker.com | sh
            ;;
    esac

    systemctl start docker
    systemctl enable docker

    print_success "Docker installed successfully"
}

# Install WireGuard
install_wireguard() {
    if command -v wg &> /dev/null; then
        print_success "WireGuard is already installed"
        wg --version
    else
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

        print_success "WireGuard installed successfully"
    fi

    # Enable IP forwarding
    print_info "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p

    print_success "IP forwarding enabled"
}

# Setup WireGuard interface
setup_wireguard() {
    print_info "Setting up WireGuard interface..."

    if [ -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
        print_warning "WireGuard interface $WG_INTERFACE already exists"
        SERVER_PRIVATE_KEY=$(grep "PrivateKey" /etc/wireguard/$WG_INTERFACE.conf | cut -d'=' -f2 | tr -d ' ')
        SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
        print_info "Using existing WireGuard configuration"
    else
        SERVER_PRIVATE_KEY=$(wg genkey)
        SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
        DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

        cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
EOF

        chmod 600 /etc/wireguard/$WG_INTERFACE.conf
        print_success "WireGuard config created"
    fi

    if ! wg show $WG_INTERFACE &>/dev/null; then
        wg-quick up $WG_INTERFACE
        print_success "WireGuard interface started"
    fi
    
    systemctl enable wg-quick@$WG_INTERFACE 2>/dev/null || true

    print_success "WireGuard interface $WG_INTERFACE is ready"
    print_info "Server Public Key: $SERVER_PUBLIC_KEY"
}

# Install SSL certificate
install_ssl() {
    if [ "$USE_SSL" != "y" ]; then
        return
    fi

    print_info "Installing SSL certificate for $DOMAIN..."

    case $OS in
        ubuntu|debian)
            apt-get install -y certbot
            ;;
        centos|rhel|rocky|almalinux|fedora)
            yum install -y certbot
            ;;
    esac

    systemctl stop nginx 2>/dev/null || true
    docker stop wireguard-panel-frontend 2>/dev/null || true

    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --http-01-port 80

    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        print_success "SSL certificate obtained successfully"
        mkdir -p $INSTALL_DIR/ssl
        cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $INSTALL_DIR/ssl/
        cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $INSTALL_DIR/ssl/
        chmod 600 $INSTALL_DIR/ssl/*.pem
    else
        print_error "Failed to obtain SSL certificate"
        USE_SSL="n"
    fi
}

# Setup panel files
setup_panel() {
    print_info "Setting up WireGuard Panel..."

    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR

    JWT_SECRET=$(openssl rand -hex 32)

    cat > $INSTALL_DIR/.env << EOF
JWT_SECRET=$JWT_SECRET
PANEL_PORT=$PANEL_PORT
PANEL_SSL_PORT=$PANEL_SSL_PORT
DOMAIN=$DOMAIN
USE_SSL=$USE_SSL
WG_ENDPOINT=$ENDPOINT
WG_PORT=$WG_PORT
WG_NETWORK=$WG_NETWORK
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
SCRIPT_VERSION=$SCRIPT_VERSION
EOF

    if [ "$USE_SSL" = "y" ]; then
        create_nginx_ssl_config
    else
        create_nginx_config
    fi

    create_docker_compose
    create_backend_dockerfile
    create_frontend_dockerfile

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -d "$SCRIPT_DIR/backend" ]; then
        cp -r $SCRIPT_DIR/backend $INSTALL_DIR/
        cp -r $SCRIPT_DIR/frontend $INSTALL_DIR/
    fi

    echo "REACT_APP_BACKEND_URL=/api" > $INSTALL_DIR/frontend/.env 2>/dev/null || true

    print_success "Panel files created"
}

# Create nginx config without SSL
create_nginx_config() {
    cat > $INSTALL_DIR/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location /api {
        proxy_pass http://backend:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
}

# Create nginx config with SSL
create_nginx_ssl_config() {
    cat > $INSTALL_DIR/nginx.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    root /usr/share/nginx/html;
    index index.html;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location /api {
        proxy_pass http://backend:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
}

# Create docker-compose.yml
create_docker_compose() {
    if [ "$USE_SSL" = "y" ]; then
        cat > $INSTALL_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  mongodb:
    image: mongo:6
    container_name: wireguard-panel-mongodb
    restart: unless-stopped
    volumes:
      - mongodb_data:/data/db
    networks:
      - wireguard-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 40s

  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: wireguard-panel-backend
    restart: unless-stopped
    environment:
      - MONGO_URL=mongodb://mongodb:27017
      - DB_NAME=wireguard_panel
      - JWT_SECRET=${JWT_SECRET}
      - WG_INTERFACE=$WG_INTERFACE
      - WG_PORT=$WG_PORT
      - WG_NETWORK=$WG_NETWORK
      - WG_DNS=1.1.1.1,8.8.8.8
      - DEFAULT_ENDPOINT=$ENDPOINT
      - SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
      - SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
    volumes:
      - /etc/wireguard:/etc/wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - wireguard-network

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    container_name: wireguard-panel-frontend
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - backend
    networks:
      - wireguard-network

volumes:
  mongodb_data:

networks:
  wireguard-network:
    driver: bridge
EOF
    else
        cat > $INSTALL_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  mongodb:
    image: mongo:6
    container_name: wireguard-panel-mongodb
    restart: unless-stopped
    volumes:
      - mongodb_data:/data/db
    networks:
      - wireguard-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 40s

  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: wireguard-panel-backend
    restart: unless-stopped
    environment:
      - MONGO_URL=mongodb://mongodb:27017
      - DB_NAME=wireguard_panel
      - JWT_SECRET=${JWT_SECRET}
      - WG_INTERFACE=$WG_INTERFACE
      - WG_PORT=$WG_PORT
      - WG_NETWORK=$WG_NETWORK
      - WG_DNS=1.1.1.1,8.8.8.8
      - DEFAULT_ENDPOINT=$ENDPOINT
      - SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
      - SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
    volumes:
      - /etc/wireguard:/etc/wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - wireguard-network

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    container_name: wireguard-panel-frontend
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - wireguard-network

volumes:
  mongodb_data:

networks:
  wireguard-network:
    driver: bridge
EOF
    fi
}

# Create Backend Dockerfile
create_backend_dockerfile() {
    cat > $INSTALL_DIR/Dockerfile.backend << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    wireguard-tools \
    iproute2 \
    iptables \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

EXPOSE 8001

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
EOF
}

# Create Frontend Dockerfile
create_frontend_dockerfile() {
    cat > $INSTALL_DIR/Dockerfile.frontend << 'EOF'
FROM node:18-alpine as builder

WORKDIR /app

COPY frontend/package.json ./

RUN yarn install

COPY frontend/ .

RUN yarn build

FROM nginx:alpine

COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
EOF
}

# Configure firewall
configure_firewall() {
    print_info "Configuring firewall..."

    if command -v ufw &> /dev/null; then
        ufw allow $WG_PORT/udp
        ufw allow 80/tcp
        [ "$USE_SSL" = "y" ] && ufw allow 443/tcp
        print_success "UFW rules added"
    fi

    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$WG_PORT/udp
        firewall-cmd --permanent --add-port=80/tcp
        [ "$USE_SSL" = "y" ] && firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_success "Firewalld rules added"
    fi
}

# Start the panel
start_panel() {
    print_info "Building and starting containers..."

    cd $INSTALL_DIR
    docker compose up -d --build

    print_info "Waiting for services to start..."
    sleep 10

    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel is running!"
    else
        print_error "Failed to start panel. Check logs with: $0 logs"
    fi
}

# Print completion message
print_complete() {
    SERVER_IP=$(get_server_ip)
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║     ✅  Installation Complete! / نصب کامل شد!            ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$USE_SSL" = "y" ]; then
        echo -e "${CYAN}Panel URL:${NC} https://$DOMAIN"
    else
        echo -e "${CYAN}Panel URL:${NC} http://$SERVER_IP"
    fi
    
    echo ""
    echo -e "${CYAN}Default Login / اطلاعات ورود:${NC}"
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Password: ${YELLOW}admin${NC}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Please change the default password immediately!${NC}"
    echo -e "${RED}⚠️  مهم: لطفاً رمز عبور پیش‌فرض را فوراً تغییر دهید!${NC}"
    echo ""
    echo -e "${CYAN}WireGuard Endpoint:${NC} $ENDPOINT:$WG_PORT"
    echo ""
    echo -e "${CYAN}Management Commands / دستورات مدیریت:${NC}"
    echo -e "   Start:     ${YELLOW}$0 start${NC}"
    echo -e "   Stop:      ${YELLOW}$0 stop${NC}"
    echo -e "   Restart:   ${YELLOW}$0 restart${NC}"
    echo -e "   Status:    ${YELLOW}$0 status${NC}"
    echo -e "   Logs:      ${YELLOW}$0 logs${NC}"
    echo -e "   Update:    ${YELLOW}$0 update${NC}"
    echo -e "   Uninstall: ${YELLOW}$0 uninstall${NC}"
    echo ""
}

# Install command
cmd_install() {
    check_root
    detect_os
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Panel is already installed at $INSTALL_DIR"
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    print_banner
    ask_questions

    echo ""
    print_info "Starting installation..."
    echo ""

    print_info "Step 1/7: Installing prerequisites..."
    install_prerequisites

    print_info "Step 2/7: Installing Docker..."
    install_docker

    print_info "Step 3/7: Installing WireGuard..."
    install_wireguard

    print_info "Step 4/7: Setting up WireGuard interface..."
    setup_wireguard

    print_info "Step 5/7: Setting up SSL..."
    install_ssl

    print_info "Step 6/7: Setting up panel files..."
    setup_panel

    print_info "Step 7/7: Starting panel..."
    configure_firewall
    start_panel

    print_complete
}

# Show help
show_help() {
    print_banner
    echo ""
    echo -e "${CYAN}Usage:${NC} $0 <command>"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${YELLOW}install${NC}     Install WireGuard Panel"
    echo -e "  ${YELLOW}start${NC}       Start the panel"
    echo -e "  ${YELLOW}stop${NC}        Stop the panel"
    echo -e "  ${YELLOW}restart${NC}     Restart the panel"
    echo -e "  ${YELLOW}status${NC}      Show panel status"
    echo -e "  ${YELLOW}logs${NC}        Show panel logs"
    echo -e "  ${YELLOW}update${NC}      Update panel (keeps data)"
    echo -e "  ${YELLOW}uninstall${NC}   Remove panel completely"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 install"
    echo "  $0 start"
    echo "  $0 update"
    echo ""
}

# ==================== MAIN ====================

# Parse command
case "${1:-}" in
    install)
        cmd_install
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    update)
        cmd_update
        ;;
    uninstall)
        cmd_uninstall
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # No argument - show menu
        print_banner
        echo ""
        echo -e "${CYAN}Select an option / یک گزینه انتخاب کنید:${NC}"
        echo ""
        echo "  1) Install Panel / نصب پنل"
        echo "  2) Start Panel / شروع پنل"
        echo "  3) Stop Panel / توقف پنل"
        echo "  4) Restart Panel / ریستارت پنل"
        echo "  5) Show Status / نمایش وضعیت"
        echo "  6) Show Logs / نمایش لاگ"
        echo "  7) Update Panel / آپدیت پنل"
        echo "  8) Uninstall Panel / حذف پنل"
        echo "  0) Exit / خروج"
        echo ""
        read -p "Enter option [0-8]: " option
        
        case $option in
            1) cmd_install ;;
            2) cmd_start ;;
            3) cmd_stop ;;
            4) cmd_restart ;;
            5) cmd_status ;;
            6) cmd_logs ;;
            7) cmd_update ;;
            8) cmd_uninstall ;;
            0) exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
