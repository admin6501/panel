#!/bin/bash

# ===========================================
# WireGuard Panel Auto Installer v2.0
# ===========================================
# Features:
# - Auto-detect and install WireGuard
# - Optional SSL with Let's Encrypt
# - Auto-configure endpoint
# - Docker deployment
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

# Banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Installer v2.0  🛡️              ║"
    echo "║                                                           ║"
    echo "║     A Modern VPN Management System                        ║"
    echo "║     با پشتیبانی SSL و نصب خودکار                          ║"
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

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$SERVER_IP"
}

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
            # Install using convenience script
            curl -fsSL https://get.docker.com | sh
            ;;
    esac

    # Start and enable Docker
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
    
    # Remove existing entries
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    
    # Add new entries
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
        # Get existing keys
        SERVER_PRIVATE_KEY=$(grep "PrivateKey" /etc/wireguard/$WG_INTERFACE.conf | cut -d'=' -f2 | tr -d ' ')
        SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
        print_info "Using existing WireGuard configuration"
    else
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
        print_success "WireGuard config created"
    fi

    # Start WireGuard if not running
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

    # Install certbot
    case $OS in
        ubuntu|debian)
            apt-get install -y certbot
            ;;
        centos|rhel|rocky|almalinux|fedora)
            yum install -y certbot
            ;;
    esac

    # Stop any service on port 80
    systemctl stop nginx 2>/dev/null || true
    docker stop wireguard-panel-frontend 2>/dev/null || true

    # Get certificate
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --http-01-port 80

    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        print_success "SSL certificate obtained successfully"
        
        # Copy certificates to panel directory
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

    # Generate JWT secret
    JWT_SECRET=$(openssl rand -hex 32)

    # Create .env file
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
EOF

    # Create nginx config based on SSL choice
    if [ "$USE_SSL" = "y" ]; then
        create_nginx_ssl_config
    else
        create_nginx_config
    fi

    # Create docker-compose.yml
    create_docker_compose

    # Create backend Dockerfile
    create_backend_dockerfile

    # Create frontend Dockerfile
    create_frontend_dockerfile

    # Create backend files
    create_backend_files

    # Create frontend files
    create_frontend_files

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

# Create backend files (simplified - copy from repo or create minimal)
create_backend_files() {
    mkdir -p $INSTALL_DIR/backend
    
    # Check if we're running from repo
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -d "$SCRIPT_DIR/backend" ]; then
        cp -r $SCRIPT_DIR/backend/* $INSTALL_DIR/backend/
    else
        # Create minimal backend - in production, download from repo
        print_warning "Backend files not found. Please copy them manually or clone from repository."
    fi
}

# Create frontend files
create_frontend_files() {
    mkdir -p $INSTALL_DIR/frontend
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -d "$SCRIPT_DIR/frontend" ]; then
        cp -r $SCRIPT_DIR/frontend/* $INSTALL_DIR/frontend/
        
        # Update API URL in frontend
        echo "REACT_APP_BACKEND_URL=/api" > $INSTALL_DIR/frontend/.env
    else
        print_warning "Frontend files not found. Please copy them manually or clone from repository."
    fi
}

# Start the panel
start_panel() {
    print_info "Building and starting containers..."

    cd $INSTALL_DIR

    # Build and start
    docker compose up -d --build

    # Wait for services
    print_info "Waiting for services to start..."
    sleep 10

    # Check if running
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel is running!"
    else
        print_error "Failed to start panel. Check logs with: docker compose logs"
    fi
}

# Configure firewall
configure_firewall() {
    print_info "Configuring firewall..."

    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow $WG_PORT/udp
        ufw allow 80/tcp
        [ "$USE_SSL" = "y" ] && ufw allow 443/tcp
        print_success "UFW rules added"
    fi

    # Firewalld (CentOS/RHEL)
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$WG_PORT/udp
        firewall-cmd --permanent --add-port=80/tcp
        [ "$USE_SSL" = "y" ] && firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_success "Firewalld rules added"
    fi
}

# Print completion message
print_complete() {
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
    echo -e "${CYAN}WireGuard Server Public Key:${NC}"
    echo "   $SERVER_PUBLIC_KEY"
    echo ""
    echo -e "${CYAN}Useful Commands / دستورات مفید:${NC}"
    echo -e "   View logs:     ${YELLOW}cd $INSTALL_DIR && docker compose logs -f${NC}"
    echo -e "   Restart:       ${YELLOW}cd $INSTALL_DIR && docker compose restart${NC}"
    echo -e "   Stop:          ${YELLOW}cd $INSTALL_DIR && docker compose down${NC}"
    echo -e "   WG Status:     ${YELLOW}wg show${NC}"
    echo ""
    
    if [ "$USE_SSL" = "y" ]; then
        echo -e "${CYAN}SSL Certificate Renewal:${NC}"
        echo -e "   ${YELLOW}certbot renew${NC}"
        echo ""
    fi
}

# Main installation flow
main() {
    print_banner
    check_root
    detect_os
    
    # Ask configuration questions
    ask_questions

    echo ""
    print_info "Starting installation..."
    echo ""

    # Step 1: Install prerequisites
    print_info "Step 1/7: Installing prerequisites..."
    install_prerequisites

    # Step 2: Install Docker
    print_info "Step 2/7: Installing Docker..."
    install_docker

    # Step 3: Install WireGuard
    print_info "Step 3/7: Installing WireGuard..."
    install_wireguard

    # Step 4: Setup WireGuard interface
    print_info "Step 4/7: Setting up WireGuard interface..."
    setup_wireguard

    # Step 5: Install SSL (if requested)
    print_info "Step 5/7: Setting up SSL..."
    install_ssl

    # Step 6: Setup panel files
    print_info "Step 6/7: Setting up panel files..."
    setup_panel

    # Step 7: Configure firewall and start
    print_info "Step 7/7: Starting panel..."
    configure_firewall
    start_panel

    # Done!
    print_complete
}

# Run main function
main "$@"
