#!/bin/bash

# ===========================================
# WireGuard Panel Manager v5.0
# ===========================================

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variables
INSTALL_DIR="/opt/wireguard-panel"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
SCRIPT_VERSION="5.0"

PANEL_USERNAME="admin"
PANEL_PASSWORD="admin"
PANEL_PORT="80"
SSL_ENABLED="false"
DOMAIN=""

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Manager v${SCRIPT_VERSION}  🛡️              ║"
    echo "║                                                           ║"
    echo "║     پنل مدیریت وایرگارد                                   ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
}

get_server_ip() {
    local ip=$(curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)
    if [ -z "$ip" ]; then
        ip=$(curl -s -4 --max-time 5 ipinfo.io/ip 2>/dev/null)
    fi
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

is_installed() {
    [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]
}

show_menu() {
    print_banner
    echo ""
    if is_installed; then
        echo -e "  ${GREEN}●${NC} Panel: ${GREEN}Installed / نصب شده${NC}"
        if docker ps 2>/dev/null | grep -q wireguard-panel; then
            echo -e "  ${GREEN}●${NC} Status: ${GREEN}Running / در حال اجرا${NC}"
        else
            echo -e "  ${RED}●${NC} Status: ${RED}Stopped / متوقف${NC}"
        fi
    else
        echo -e "  ${RED}●${NC} Panel: ${RED}Not Installed / نصب نشده${NC}"
    fi
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}1)${NC} Install Panel              ${CYAN}نصب پنل${NC}"
    echo -e "  ${GREEN}2)${NC} Start Panel                ${GREEN}شروع پنل${NC}"
    echo -e "  ${YELLOW}3)${NC} Stop Panel                 ${YELLOW}توقف پنل${NC}"
    echo -e "  ${BLUE}4)${NC} Restart Panel              ${BLUE}ری‌استارت پنل${NC}"
    echo -e "  ${PURPLE}5)${NC} Update Panel               ${PURPLE}آپدیت (بدون حذف دیتا)${NC}"
    echo -e "  ${WHITE}6)${NC} View Logs                  ${WHITE}مشاهده لاگ‌ها${NC}"
    echo -e "  ${WHITE}7)${NC} Panel Status               ${WHITE}وضعیت پنل${NC}"
    echo -e "  ${CYAN}8)${NC} Setup SSL                  ${CYAN}راه‌اندازی SSL${NC}"
    echo -e "  ${YELLOW}9)${NC} Reset Admin Password       ${YELLOW}ریست پسورد ادمین${NC}"
    echo -e "  ${RED}10)${NC} Uninstall Panel           ${RED}حذف کامل${NC}"
    echo -e "  ${NC}0)${NC} Exit                       ${NC}خروج${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_panel_info() {
    SERVER_IP=$(get_server_ip)
    CURRENT_PORT=$(grep -oP '"\K[0-9]+(?=:80")' $INSTALL_DIR/docker-compose.yml 2>/dev/null | head -1)
    [ -z "$CURRENT_PORT" ] && CURRENT_PORT="80"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  Panel URL: ${GREEN}http://$SERVER_IP:$CURRENT_PORT${NC}"
    if [ -f "$INSTALL_DIR/ssl/fullchain.pem" ]; then
        echo -e "  SSL URL: ${GREEN}https://$SERVER_IP${NC}"
    fi
    echo -e "  WireGuard: ${GREEN}$SERVER_IP:51820/UDP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

start_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    print_info "Starting panel..."
    cd $INSTALL_DIR
    docker compose up -d
    sleep 5
    if docker ps | grep -q wireguard-panel; then
        print_success "Panel started!"
        show_panel_info
    else
        print_error "Failed to start"
        docker compose logs --tail=20
    fi
}

stop_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    print_info "Stopping panel..."
    cd $INSTALL_DIR
    docker compose down
    print_success "Panel stopped!"
}

restart_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    print_info "Restarting panel..."
    cd $INSTALL_DIR
    docker compose restart
    sleep 5
    print_success "Panel restarted!"
    show_panel_info
}

update_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    print_warning "This will update without removing data."
    echo -e "${YELLOW}Press Enter to continue or 'n' to cancel${NC}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        return 0
    fi
    print_info "Updating panel..."
    cd $INSTALL_DIR
    docker compose down
    docker compose build --no-cache
    docker compose up -d
    sleep 5
    print_success "Panel updated!"
    show_panel_info
}

view_logs_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    print_info "Showing logs (Ctrl+C to exit)..."
    cd $INSTALL_DIR
    docker compose logs -f --tail=100
}

panel_status_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    echo ""
    print_info "Container Status:"
    cd $INSTALL_DIR
    docker compose ps
    show_panel_info
}

setup_ssl_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}SSL Setup / راه‌اندازی SSL${NC}"
    echo ""
    echo -e "${YELLOW}Enter your domain (e.g., panel.example.com):${NC}"
    read -r DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        print_error "Domain is required!"
        return 1
    fi
    
    echo -e "${YELLOW}Enter your email for Let's Encrypt:${NC}"
    read -r EMAIL
    
    if [ -z "$EMAIL" ]; then
        print_error "Email is required!"
        return 1
    fi
    
    print_info "Installing certbot..."
    apt-get update
    apt-get install -y certbot
    
    print_info "Stopping panel temporarily..."
    cd $INSTALL_DIR
    docker compose down
    
    print_info "Getting SSL certificate..."
    certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        mkdir -p $INSTALL_DIR/ssl
        cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $INSTALL_DIR/ssl/
        cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $INSTALL_DIR/ssl/
        
        # Update nginx config for SSL
        cat > $INSTALL_DIR/nginx.conf << NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location /api {
        proxy_pass http://backend:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINXEOF
        
        # Update docker-compose for SSL
        sed -i 's/- "[0-9]*:80"/- "80:80"\n      - "443:443"/' $INSTALL_DIR/docker-compose.yml
        
        # Add SSL volume
        if ! grep -q "ssl:/etc/nginx/ssl" $INSTALL_DIR/docker-compose.yml; then
            sed -i '/depends_on:/i\    volumes:\n      - ./ssl:/etc/nginx/ssl:ro' $INSTALL_DIR/docker-compose.yml
        fi
        
        docker compose up -d
        print_success "SSL configured successfully!"
        echo -e "  Access panel at: ${GREEN}https://$DOMAIN${NC}"
    else
        print_error "Failed to get SSL certificate"
        docker compose up -d
    fi
}

reset_admin_password() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}Enter new admin username [admin]:${NC}"
    read -r NEW_USER
    [ -z "$NEW_USER" ] && NEW_USER="admin"
    
    echo -e "${YELLOW}Enter new admin password [admin]:${NC}"
    read -r NEW_PASS
    [ -z "$NEW_PASS" ] && NEW_PASS="admin"
    
    print_info "Resetting admin credentials..."
    
    cd $INSTALL_DIR
    
    # Delete all users and restart backend
    docker compose exec -T mongodb mongosh wireguard_panel --eval "db.users.deleteMany({})" 2>/dev/null
    
    # Update environment
    sed -i "s/PANEL_USERNAME=.*/PANEL_USERNAME=$NEW_USER/" $INSTALL_DIR/docker-compose.yml 2>/dev/null
    sed -i "s/PANEL_PASSWORD=.*/PANEL_PASSWORD=$NEW_PASS/" $INSTALL_DIR/docker-compose.yml 2>/dev/null
    
    # Update .env
    sed -i "s/PANEL_USERNAME=.*/PANEL_USERNAME=$NEW_USER/" $INSTALL_DIR/.env 2>/dev/null
    sed -i "s/PANEL_PASSWORD=.*/PANEL_PASSWORD=$NEW_PASS/" $INSTALL_DIR/.env 2>/dev/null
    
    docker compose restart backend
    sleep 3
    
    print_success "Admin credentials reset!"
    echo -e "  Username: ${GREEN}$NEW_USER${NC}"
    echo -e "  Password: ${GREEN}$NEW_PASS${NC}"
}

uninstall_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed!"
        return 1
    fi
    
    print_warning "This will DELETE all data!"
    echo -e "${RED}Type 'DELETE' to confirm:${NC}"
    read -r CONFIRM
    
    if [ "$CONFIRM" != "DELETE" ]; then
        print_info "Cancelled."
        return 0
    fi
    
    print_info "Uninstalling..."
    cd $INSTALL_DIR
    docker compose down -v --remove-orphans 2>/dev/null
    docker rmi wireguard-panel-frontend wireguard-panel-backend 2>/dev/null
    rm -rf $INSTALL_DIR
    print_success "Panel uninstalled!"
}

# ============================================
# INSTALLATION
# ============================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        return 1
    fi
}

wait_for_apt() {
    local count=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [ $count -eq 0 ]; then
            print_warning "Waiting for apt lock..."
        fi
        sleep 2
        count=$((count + 1))
        if [ $count -gt 30 ]; then
            print_error "Timeout waiting for apt"
            return 1
        fi
    done
}

ask_user_config() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}     Panel Configuration / تنظیمات پنل                     ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Admin username / نام کاربری ادمین:${NC}"
    read -r -p "Username [admin]: " input_username
    [ -n "$input_username" ] && PANEL_USERNAME="$input_username"
    
    echo -e "${YELLOW}Admin password / رمز عبور ادمین:${NC}"
    read -r -p "Password [admin]: " input_password
    [ -n "$input_password" ] && PANEL_PASSWORD="$input_password"
    
    echo -e "${YELLOW}Panel port / پورت پنل:${NC}"
    read -r -p "Port [80]: " input_port
    [ -n "$input_port" ] && PANEL_PORT="$input_port"
    
    SERVER_IP=$(get_server_ip)
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  Server IP: ${GREEN}$SERVER_IP${NC}"
    echo -e "  Panel Port: ${GREEN}$PANEL_PORT${NC}"
    echo -e "  Username: ${GREEN}$PANEL_USERNAME${NC}"
    echo -e "  Password: ${GREEN}$PANEL_PASSWORD${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Press Enter to continue or 'n' to cancel${NC}"
    echo -e "${YELLOW}برای ادامه Enter بزنید یا 'n' برای لغو${NC}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

install_prerequisites() {
    print_info "Installing prerequisites..."
    
    case $OS in
        ubuntu|debian)
            wait_for_apt || return 1
            apt-get update -y
            wait_for_apt
            apt-get install -y curl wget ca-certificates gnupg openssl
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget ca-certificates openssl
            ;;
        *)
            print_error "Unsupported OS: $OS"
            return 1
            ;;
    esac
    
    print_success "Prerequisites installed"
}

install_docker() {
    if command -v docker &>/dev/null; then
        print_success "Docker already installed"
        return 0
    fi
    
    print_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    print_success "Docker installed"
}

install_wireguard() {
    if command -v wg &>/dev/null; then
        print_success "WireGuard already installed"
    else
        print_info "Installing WireGuard..."
        case $OS in
            ubuntu|debian)
                wait_for_apt
                apt-get install -y wireguard wireguard-tools
                ;;
            centos|rhel|rocky|almalinux)
                yum install -y epel-release
                yum install -y wireguard-tools
                ;;
        esac
        print_success "WireGuard installed"
    fi
    
    # Enable IP forwarding
    cat > /etc/sysctl.d/99-wireguard.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
    sysctl -p /etc/sysctl.d/99-wireguard.conf 2>/dev/null
}

setup_wireguard() {
    print_info "Setting up WireGuard..."
    
    if [ -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
        SERVER_PRIVATE_KEY=$(grep "PrivateKey" /etc/wireguard/$WG_INTERFACE.conf | cut -d'=' -f2 | tr -d ' ')
        SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
        print_info "Using existing WireGuard config"
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
    
    # Start WireGuard
    if ! wg show $WG_INTERFACE &>/dev/null; then
        wg-quick up $WG_INTERFACE 2>/dev/null || true
    fi
    systemctl enable wg-quick@$WG_INTERFACE 2>/dev/null || true
    
    print_success "WireGuard ready"
}

create_project_files() {
    print_info "Creating project files..."
    
    mkdir -p $INSTALL_DIR/{backend,frontend/src/{pages,components,contexts,utils,i18n/locales},frontend/public}
    
    JWT_SECRET=$(openssl rand -hex 32)
    SERVER_IP=$(get_server_ip)
    
    # .env file
    cat > $INSTALL_DIR/.env << EOF
JWT_SECRET=$JWT_SECRET
PANEL_PORT=$PANEL_PORT
PANEL_USERNAME=$PANEL_USERNAME
PANEL_PASSWORD=$PANEL_PASSWORD
WG_ENDPOINT=$SERVER_IP
WG_PORT=$WG_PORT
WG_NETWORK=$WG_NETWORK
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
EOF

    create_backend_files
    create_frontend_files
    create_docker_files
    
    print_success "Project files created"
}

create_backend_files() {
    # requirements.txt
    cat > $INSTALL_DIR/backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pymongo==4.6.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
pydantic==2.5.2
qrcode[pil]==7.4.2
python-dotenv==1.0.0
EOF

    # server.py
    cat > $INSTALL_DIR/backend/server.py << 'SERVEREOF'
from fastapi import FastAPI, HTTPException, Depends, status, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import List, Optional
from contextlib import asynccontextmanager
from pydantic import BaseModel, Field
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import subprocess, os, io, qrcode, uuid, ipaddress

# ============ MODELS ============
class LoginRequest(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class ClientCreate(BaseModel):
    name: str
    email: Optional[str] = None
    data_limit: Optional[int] = None
    expiry_days: Optional[int] = None
    expiry_date: Optional[datetime] = None
    start_on_first_connect: bool = False
    auto_renew: bool = False
    note: Optional[str] = None

class ClientUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    data_limit: Optional[int] = None
    expiry_days: Optional[int] = None
    expiry_date: Optional[datetime] = None
    is_enabled: Optional[bool] = None
    note: Optional[str] = None

class UserCreate(BaseModel):
    username: str
    password: str
    role: str = "viewer"

# ============ AUTH ============
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()
SECRET_KEY = os.environ.get("JWT_SECRET", "default-secret-key-change-me")
ALGORITHM = "HS256"

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(hours=24)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("user_id") is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# ============ WIREGUARD ============
def wg_genkey():
    try:
        priv = subprocess.run(["wg", "genkey"], capture_output=True, text=True, check=True).stdout.strip()
        pub = subprocess.run(["wg", "pubkey"], input=priv, capture_output=True, text=True, check=True).stdout.strip()
        return priv, pub
    except:
        import secrets, base64
        priv = base64.b64encode(secrets.token_bytes(32)).decode()
        pub = base64.b64encode(secrets.token_bytes(32)).decode()
        return priv, pub

def wg_genpsk():
    try:
        return subprocess.run(["wg", "genpsk"], capture_output=True, text=True, check=True).stdout.strip()
    except:
        import secrets, base64
        return base64.b64encode(secrets.token_bytes(32)).decode()

def get_next_ip(network, used_ips):
    net = ipaddress.ip_network(network, strict=False)
    for host in list(net.hosts())[1:]:
        if str(host) not in used_ips:
            return f"{host}/32"
    raise Exception("No available IPs")

def add_peer(pub_key, psk, allowed_ips):
    try:
        subprocess.run(["wg", "set", "wg0", "peer", pub_key, "allowed-ips", allowed_ips], check=True)
        subprocess.run(["wg-quick", "save", "wg0"], check=False)
        return True
    except:
        return False

def remove_peer(pub_key):
    try:
        subprocess.run(["wg", "set", "wg0", "peer", pub_key, "remove"], check=True)
        subprocess.run(["wg-quick", "save", "wg0"], check=False)
        return True
    except:
        return False

def get_wg_stats():
    try:
        result = subprocess.run(["wg", "show", "wg0", "dump"], capture_output=True, text=True)
        if result.returncode != 0:
            return {}
        stats = {}
        lines = result.stdout.strip().split("\n")
        for line in lines[1:]:
            parts = line.split("\t")
            if len(parts) >= 8:
                stats[parts[0]] = {
                    "rx": int(parts[5]),
                    "tx": int(parts[6]),
                    "handshake": int(parts[4]) if parts[4] != "0" else None
                }
        return stats
    except:
        return {}

# ============ APP ============
@asynccontextmanager
async def lifespan(app: FastAPI):
    init_admin()
    init_settings()
    yield

app = FastAPI(title="WireGuard Panel API", version="5.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
mongo_client = MongoClient(MONGO_URL)
db = mongo_client["wireguard_panel"]
users_col = db["users"]
clients_col = db["clients"]
settings_col = db["settings"]

def init_admin():
    """Create default admin user if none exists"""
    if users_col.count_documents({"role": "super_admin"}) == 0:
        username = os.environ.get("PANEL_USERNAME", "admin")
        password = os.environ.get("PANEL_PASSWORD", "admin")
        
        users_col.insert_one({
            "id": str(uuid.uuid4()),
            "username": username,
            "hashed_password": get_password_hash(password),
            "role": "super_admin",
            "is_active": True,
            "created_at": datetime.utcnow()
        })
        print(f"Created admin user: {username}")

def init_settings():
    """Initialize server settings if not exist"""
    if settings_col.count_documents({"id": "server_settings"}) == 0:
        server_pub = os.environ.get("SERVER_PUBLIC_KEY", "")
        server_priv = os.environ.get("SERVER_PRIVATE_KEY", "")
        
        if not server_pub or not server_priv:
            server_priv, server_pub = wg_genkey()
        
        settings_col.insert_one({
            "id": "server_settings",
            "server_name": "WireGuard Panel",
            "wg_port": int(os.environ.get("WG_PORT", "51820")),
            "wg_network": os.environ.get("WG_NETWORK", "10.0.0.0/24"),
            "wg_dns": "1.1.1.1,8.8.8.8",
            "server_public_key": server_pub,
            "server_private_key": server_priv,
            "endpoint": os.environ.get("WG_ENDPOINT", ""),
            "mtu": 1420,
            "persistent_keepalive": 25
        })
        print("Server settings initialized")

# ============ AUTH ROUTES ============
@app.post("/api/auth/login", response_model=Token)
async def login(req: LoginRequest):
    user = users_col.find_one({"username": req.username})
    if not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    if not verify_password(req.password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    if not user.get("is_active", True):
        raise HTTPException(status_code=403, detail="Account disabled")
    
    token = create_access_token({
        "user_id": user["id"],
        "username": user["username"],
        "role": user["role"]
    })
    return Token(access_token=token)

@app.get("/api/auth/me")
async def get_me(user=Depends(get_current_user)):
    u = users_col.find_one({"id": user["user_id"]})
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": u["id"],
        "username": u["username"],
        "role": u["role"],
        "is_active": u.get("is_active", True)
    }

# ============ USER ROUTES ============
@app.get("/api/users")
async def get_users(user=Depends(get_current_user)):
    if user["role"] != "super_admin":
        raise HTTPException(status_code=403, detail="Not authorized")
    users = list(users_col.find({}, {"_id": 0, "hashed_password": 0}))
    return users

@app.post("/api/users")
async def create_user(data: UserCreate, user=Depends(get_current_user)):
    if user["role"] != "super_admin":
        raise HTTPException(status_code=403, detail="Not authorized")
    
    if users_col.find_one({"username": data.username}):
        raise HTTPException(status_code=400, detail="Username exists")
    
    new_user = {
        "id": str(uuid.uuid4()),
        "username": data.username,
        "hashed_password": get_password_hash(data.password),
        "role": data.role,
        "is_active": True,
        "created_at": datetime.utcnow()
    }
    users_col.insert_one(new_user)
    return {"id": new_user["id"], "username": new_user["username"], "role": new_user["role"]}

@app.delete("/api/users/{user_id}")
async def delete_user(user_id: str, user=Depends(get_current_user)):
    if user["role"] != "super_admin":
        raise HTTPException(status_code=403, detail="Not authorized")
    if user_id == user["user_id"]:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    
    result = users_col.delete_one({"id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    return {"message": "Deleted"}

# ============ CLIENT ROUTES ============
@app.get("/api/clients")
async def get_clients(user=Depends(get_current_user)):
    clients = list(clients_col.find({}, {"_id": 0}))
    stats = get_wg_stats()
    
    for c in clients:
        pub_key = c.get("public_key", "")
        if pub_key in stats:
            s = stats[pub_key]
            c["data_used"] = s["rx"] + s["tx"]
            c["is_online"] = s["handshake"] is not None and (datetime.now().timestamp() - s["handshake"]) < 180
        else:
            c["data_used"] = c.get("data_used", 0)
            c["is_online"] = False
        
        # Determine status
        if not c.get("is_enabled", True):
            c["status"] = "disabled"
        elif c.get("expiry_date"):
            exp = c["expiry_date"]
            if isinstance(exp, str):
                exp = datetime.fromisoformat(exp.replace('Z', '+00:00'))
            if exp < datetime.utcnow():
                c["status"] = "expired"
            else:
                c["status"] = "active"
        elif c.get("data_limit") and c.get("data_used", 0) >= c["data_limit"]:
            c["status"] = "data_limit_reached"
        else:
            c["status"] = "active"
    
    return clients

@app.post("/api/clients")
async def create_client(client: ClientCreate, user=Depends(get_current_user)):
    settings = settings_col.find_one({"id": "server_settings"})
    if not settings:
        raise HTTPException(status_code=500, detail="Server not configured")
    
    if not settings.get("endpoint"):
        raise HTTPException(status_code=400, detail="Set server endpoint in settings first")
    
    priv, pub = wg_genkey()
    psk = wg_genpsk()
    
    used_ips = [c["address"].split("/")[0] for c in clients_col.find({}, {"address": 1})]
    used_ips.append("10.0.0.1")
    
    try:
        address = get_next_ip(settings["wg_network"], used_ips)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # Calculate expiry
    expiry_date = None
    if client.expiry_date:
        expiry_date = client.expiry_date
    elif client.expiry_days and not client.start_on_first_connect:
        expiry_date = datetime.utcnow() + timedelta(days=client.expiry_days)
    
    new_client = {
        "id": str(uuid.uuid4()),
        "name": client.name,
        "email": client.email,
        "private_key": priv,
        "public_key": pub,
        "preshared_key": psk,
        "address": address,
        "data_limit": client.data_limit,
        "expiry_days": client.expiry_days,
        "expiry_date": expiry_date,
        "start_on_first_connect": client.start_on_first_connect,
        "auto_renew": client.auto_renew,
        "note": client.note,
        "is_enabled": True,
        "status": "active",
        "data_used": 0,
        "created_at": datetime.utcnow(),
        "created_by": user["user_id"]
    }
    
    add_peer(pub, psk, address)
    clients_col.insert_one(new_client)
    
    # Convert dates for response
    new_client["created_at"] = new_client["created_at"].isoformat()
    if new_client.get("expiry_date"):
        new_client["expiry_date"] = new_client["expiry_date"].isoformat()
    
    return new_client

@app.put("/api/clients/{client_id}")
async def update_client(client_id: str, data: ClientUpdate, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    update_data = {}
    if data.name is not None:
        update_data["name"] = data.name
    if data.email is not None:
        update_data["email"] = data.email
    if data.data_limit is not None:
        update_data["data_limit"] = data.data_limit
    if data.expiry_days is not None:
        update_data["expiry_days"] = data.expiry_days
    if data.expiry_date is not None:
        update_data["expiry_date"] = data.expiry_date
    if data.note is not None:
        update_data["note"] = data.note
    if data.is_enabled is not None:
        update_data["is_enabled"] = data.is_enabled
        if data.is_enabled:
            add_peer(client["public_key"], client["preshared_key"], client["address"])
        else:
            remove_peer(client["public_key"])
    
    if update_data:
        clients_col.update_one({"id": client_id}, {"$set": update_data})
    
    updated = clients_col.find_one({"id": client_id}, {"_id": 0})
    return updated

@app.delete("/api/clients/{client_id}")
async def delete_client(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    remove_peer(client["public_key"])
    clients_col.delete_one({"id": client_id})
    return {"message": "Deleted"}

@app.get("/api/clients/{client_id}/config")
async def get_client_config(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    settings = settings_col.find_one({"id": "server_settings"})
    
    config = f"""[Interface]
PrivateKey = {client["private_key"]}
Address = {client["address"]}
DNS = {settings["wg_dns"]}
MTU = {settings["mtu"]}

[Peer]
PublicKey = {settings["server_public_key"]}
PresharedKey = {client["preshared_key"]}
Endpoint = {settings["endpoint"]}:{settings["wg_port"]}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = {settings["persistent_keepalive"]}
"""
    return Response(
        content=config,
        media_type="text/plain",
        headers={"Content-Disposition": f"attachment; filename={client['name']}.conf"}
    )

@app.get("/api/clients/{client_id}/qrcode")
async def get_client_qrcode(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    settings = settings_col.find_one({"id": "server_settings"})
    
    config = f"""[Interface]
PrivateKey = {client["private_key"]}
Address = {client["address"]}
DNS = {settings["wg_dns"]}
MTU = {settings["mtu"]}

[Peer]
PublicKey = {settings["server_public_key"]}
PresharedKey = {client["preshared_key"]}
Endpoint = {settings["endpoint"]}:{settings["wg_port"]}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = {settings["persistent_keepalive"]}"""
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(config)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    
    return StreamingResponse(buf, media_type="image/png")

# ============ SETTINGS ROUTES ============
@app.get("/api/settings")
async def get_settings(user=Depends(get_current_user)):
    settings = settings_col.find_one({"id": "server_settings"}, {"_id": 0})
    if settings:
        settings.pop("server_private_key", None)
    return settings

@app.put("/api/settings")
async def update_settings(data: dict, user=Depends(get_current_user)):
    if user["role"] != "super_admin":
        raise HTTPException(status_code=403, detail="Not authorized")
    
    allowed = ["server_name", "endpoint", "wg_port", "wg_dns", "mtu", "persistent_keepalive"]
    update_data = {k: v for k, v in data.items() if k in allowed}
    
    if update_data:
        settings_col.update_one({"id": "server_settings"}, {"$set": update_data})
    
    settings = settings_col.find_one({"id": "server_settings"}, {"_id": 0})
    settings.pop("server_private_key", None)
    return settings

# ============ DASHBOARD ROUTES ============
@app.get("/api/dashboard/stats")
async def get_dashboard_stats(user=Depends(get_current_user)):
    clients = list(clients_col.find({}))
    stats = get_wg_stats()
    
    total = len(clients)
    active = 0
    disabled = 0
    expired = 0
    online = 0
    total_data = 0
    
    for c in clients:
        if not c.get("is_enabled", True):
            disabled += 1
        elif c.get("expiry_date"):
            exp = c["expiry_date"]
            if isinstance(exp, str):
                exp = datetime.fromisoformat(exp.replace('Z', '+00:00'))
            if exp < datetime.utcnow():
                expired += 1
            else:
                active += 1
        else:
            active += 1
        
        pub_key = c.get("public_key", "")
        if pub_key in stats:
            s = stats[pub_key]
            total_data += s["rx"] + s["tx"]
            if s["handshake"] and (datetime.now().timestamp() - s["handshake"]) < 180:
                online += 1
    
    return {
        "total_clients": total,
        "active_clients": active,
        "disabled_clients": disabled,
        "expired_clients": expired,
        "online_clients": online,
        "total_data_used": total_data
    }

@app.get("/api/dashboard/system")
async def get_system_info(user=Depends(get_current_user)):
    wg_installed = subprocess.run(["which", "wg"], capture_output=True).returncode == 0
    wg_up = subprocess.run(["wg", "show", "wg0"], capture_output=True).returncode == 0 if wg_installed else False
    
    return {
        "wireguard_installed": wg_installed,
        "interface_up": wg_up,
        "interface_name": "wg0"
    }

# ============ SUBSCRIPTION PAGE ============
@app.get("/api/sub/{client_id}")
async def get_subscription(client_id: str):
    client = clients_col.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Not found")
    
    stats = get_wg_stats()
    pub_key = client.get("public_key", "")
    
    data_used = 0
    is_online = False
    
    if pub_key in stats:
        s = stats[pub_key]
        data_used = s["rx"] + s["tx"]
        is_online = s["handshake"] is not None and (datetime.now().timestamp() - s["handshake"]) < 180
    
    status = "active"
    if not client.get("is_enabled", True):
        status = "disabled"
    elif client.get("expiry_date"):
        exp = client["expiry_date"]
        if isinstance(exp, str):
            exp = datetime.fromisoformat(exp.replace('Z', '+00:00'))
        if exp < datetime.utcnow():
            status = "expired"
    
    return {
        "name": client["name"],
        "status": status,
        "is_online": is_online,
        "data_used": data_used,
        "data_limit": client.get("data_limit"),
        "expiry_date": client.get("expiry_date"),
        "created_at": client.get("created_at")
    }

@app.get("/api/health")
async def health():
    return {"status": "ok", "version": "5.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
SERVEREOF
}

create_frontend_files() {
    # package.json
    cat > $INSTALL_DIR/frontend/package.json << 'EOF'
{
  "name": "wireguard-panel",
  "version": "5.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.2",
    "i18next": "^23.7.6",
    "react-i18next": "^13.5.0",
    "react-hot-toast": "^2.4.1",
    "lucide-react": "^0.294.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "browserslist": {
    "production": [">0.2%", "not dead"],
    "development": ["last 1 chrome version"]
  },
  "devDependencies": {
    "tailwindcss": "^3.3.6",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32"
  }
}
EOF

    echo "REACT_APP_BACKEND_URL=/api" > $INSTALL_DIR/frontend/.env

    # tailwind.config.js
    cat > $INSTALL_DIR/frontend/tailwind.config.js << 'EOF'
module.exports = {
  content: ["./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        dark: {
          bg: '#0f172a',
          card: '#1e293b',
          border: '#334155',
          text: '#e2e8f0',
          muted: '#94a3b8'
        }
      },
      fontFamily: {
        'vazir': ['Vazirmatn', 'sans-serif'],
        'inter': ['Inter', 'sans-serif']
      }
    }
  },
  plugins: []
}
EOF

    cat > $INSTALL_DIR/frontend/postcss.config.js << 'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }
EOF

    # public/index.html
    cat > $INSTALL_DIR/frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Vazirmatn:wght@400;500;600;700&display=swap" rel="stylesheet">
  <title>WireGuard Panel</title>
</head>
<body><div id="root"></div></body>
</html>
EOF

    # src/index.css
    cat > $INSTALL_DIR/frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
}

[dir="rtl"] body { font-family: 'Vazirmatn', sans-serif; }
[dir="ltr"] body { font-family: 'Inter', sans-serif; }

::-webkit-scrollbar { width: 8px; }
::-webkit-scrollbar-track { background: #1e293b; }
::-webkit-scrollbar-thumb { background: #475569; border-radius: 4px; }
EOF

    # src/index.js
    cat > $INSTALL_DIR/frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import './i18n/i18n';
ReactDOM.createRoot(document.getElementById('root')).render(<App />);
EOF

    # i18n setup
    mkdir -p $INSTALL_DIR/frontend/src/i18n/locales

    cat > $INSTALL_DIR/frontend/src/i18n/i18n.js << 'EOF'
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import fa from './locales/fa.json';

const savedLang = localStorage.getItem('language') || 'fa';

i18n.use(initReactI18next).init({
  resources: { en: { translation: en }, fa: { translation: fa } },
  lng: savedLang,
  fallbackLng: 'en',
  interpolation: { escapeValue: false }
});

export default i18n;
EOF

    # English locale
    cat > $INSTALL_DIR/frontend/src/i18n/locales/en.json << 'EOF'
{
  "app": { "title": "WireGuard Panel" },
  "nav": { "dashboard": "Dashboard", "clients": "Clients", "users": "Users", "settings": "Settings", "logout": "Logout" },
  "login": { "title": "Login", "username": "Username", "password": "Password", "submit": "Login", "error": "Invalid credentials" },
  "dashboard": { "title": "Dashboard", "totalClients": "Total Clients", "activeClients": "Active", "onlineClients": "Online", "disabledClients": "Disabled", "expiredClients": "Expired", "totalData": "Total Data", "system": "System Status", "wgInstalled": "WireGuard", "interfaceUp": "Interface" },
  "clients": { "title": "Clients", "add": "Add Client", "name": "Name", "email": "Email", "address": "IP Address", "status": "Status", "dataUsed": "Data Used", "dataLimit": "Data Limit", "expiry": "Expiry", "actions": "Actions", "active": "Active", "disabled": "Disabled", "expired": "Expired", "unlimited": "Unlimited", "never": "Never", "online": "Online", "offline": "Offline", "download": "Download", "qrcode": "QR Code", "edit": "Edit", "delete": "Delete", "enable": "Enable", "disable": "Disable", "noClients": "No clients", "confirmDelete": "Delete this client?", "expiryDays": "Days", "note": "Note", "startOnConnect": "Start on first connect", "autoRenew": "Auto renew" },
  "users": { "title": "Users", "add": "Add User", "username": "Username", "password": "Password", "role": "Role", "superAdmin": "Super Admin", "admin": "Admin", "viewer": "Viewer", "active": "Active", "confirmDelete": "Delete this user?" },
  "settings": { "title": "Settings", "serverName": "Server Name", "endpoint": "Endpoint (IP/Domain)", "port": "WireGuard Port", "dns": "DNS", "mtu": "MTU", "keepalive": "Keepalive", "publicKey": "Public Key", "save": "Save", "saved": "Settings saved" },
  "common": { "save": "Save", "cancel": "Cancel", "close": "Close", "search": "Search...", "yes": "Yes", "no": "No" },
  "lang": { "en": "English", "fa": "فارسی" }
}
EOF

    # Persian locale
    cat > $INSTALL_DIR/frontend/src/i18n/locales/fa.json << 'EOF'
{
  "app": { "title": "پنل وایرگارد" },
  "nav": { "dashboard": "داشبورد", "clients": "کلاینت‌ها", "users": "کاربران", "settings": "تنظیمات", "logout": "خروج" },
  "login": { "title": "ورود", "username": "نام کاربری", "password": "رمز عبور", "submit": "ورود", "error": "نام کاربری یا رمز عبور اشتباه است" },
  "dashboard": { "title": "داشبورد", "totalClients": "کل کلاینت‌ها", "activeClients": "فعال", "onlineClients": "آنلاین", "disabledClients": "غیرفعال", "expiredClients": "منقضی", "totalData": "کل مصرف", "system": "وضعیت سیستم", "wgInstalled": "وایرگارد", "interfaceUp": "اینترفیس" },
  "clients": { "title": "کلاینت‌ها", "add": "افزودن کلاینت", "name": "نام", "email": "ایمیل", "address": "آدرس IP", "status": "وضعیت", "dataUsed": "مصرف", "dataLimit": "محدودیت", "expiry": "انقضا", "actions": "عملیات", "active": "فعال", "disabled": "غیرفعال", "expired": "منقضی", "unlimited": "نامحدود", "never": "بدون انقضا", "online": "آنلاین", "offline": "آفلاین", "download": "دانلود", "qrcode": "QR کد", "edit": "ویرایش", "delete": "حذف", "enable": "فعال کردن", "disable": "غیرفعال کردن", "noClients": "کلاینتی وجود ندارد", "confirmDelete": "این کلاینت حذف شود؟", "expiryDays": "روز", "note": "یادداشت", "startOnConnect": "شروع از اولین اتصال", "autoRenew": "تمدید خودکار" },
  "users": { "title": "کاربران", "add": "افزودن کاربر", "username": "نام کاربری", "password": "رمز عبور", "role": "نقش", "superAdmin": "مدیر ارشد", "admin": "مدیر", "viewer": "بیننده", "active": "فعال", "confirmDelete": "این کاربر حذف شود؟" },
  "settings": { "title": "تنظیمات", "serverName": "نام سرور", "endpoint": "آدرس سرور (IP یا دامنه)", "port": "پورت وایرگارد", "dns": "DNS", "mtu": "MTU", "keepalive": "Keepalive", "publicKey": "کلید عمومی", "save": "ذخیره", "saved": "تنظیمات ذخیره شد" },
  "common": { "save": "ذخیره", "cancel": "انصراف", "close": "بستن", "search": "جستجو...", "yes": "بله", "no": "خیر" },
  "lang": { "en": "English", "fa": "فارسی" }
}
EOF

    # Main App.js with full features
    cat > $INSTALL_DIR/frontend/src/App.js << 'APPEOF'
import React, { useState, useEffect, createContext, useContext } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Link, useNavigate, useLocation, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Toaster, toast } from 'react-hot-toast';
import { Shield, Users, Settings, LogOut, Menu, X, Plus, Download, Trash2, QrCode, Wifi, WifiOff, LayoutDashboard, User, Lock, Globe, ChevronDown, Search, Edit, Power, CheckCircle, XCircle, Database, Clock, Eye, EyeOff } from 'lucide-react';
import axios from 'axios';

// ============ API ============
const API = axios.create({ baseURL: process.env.REACT_APP_BACKEND_URL || '/api' });
API.interceptors.request.use(cfg => { 
  const t = localStorage.getItem('token'); 
  if (t) cfg.headers.Authorization = `Bearer ${t}`; 
  return cfg; 
});
API.interceptors.response.use(r => r, e => { 
  if (e.response?.status === 401) { 
    localStorage.removeItem('token'); 
    window.location.href = '/login'; 
  } 
  return Promise.reject(e); 
});

// ============ UTILS ============
const formatBytes = (bytes) => {
  if (!bytes) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const formatDate = (date, lang) => {
  if (!date) return '-';
  return new Date(date).toLocaleDateString(lang === 'fa' ? 'fa-IR' : 'en-US');
};

// ============ AUTH CONTEXT ============
const AuthContext = createContext(null);
const useAuth = () => useContext(AuthContext);

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      API.get('/auth/me')
        .then(r => setUser(r.data))
        .catch(() => localStorage.removeItem('token'))
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);
  
  const login = async (username, password) => {
    const r = await API.post('/auth/login', { username, password });
    localStorage.setItem('token', r.data.access_token);
    const u = await API.get('/auth/me');
    setUser(u.data);
  };
  
  const logout = () => { 
    localStorage.removeItem('token'); 
    setUser(null); 
  };
  
  return (
    <AuthContext.Provider value={{ user, login, logout, loading, isAdmin: user?.role !== 'viewer' }}>
      {children}
    </AuthContext.Provider>
  );
};

// ============ PROTECTED ROUTE ============
const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center">
      <div className="animate-spin h-12 w-12 border-t-2 border-blue-500 rounded-full"></div>
    </div>
  );
  return user ? children : <Navigate to="/login" />;
};

// ============ LOGIN ============
const Login = () => {
  const { t, i18n } = useTranslation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPass, setShowPass] = useState(false);
  const { login, user } = useAuth();
  const nav = useNavigate();
  const isRTL = i18n.language === 'fa';
  
  useEffect(() => {
    if (user) nav('/');
  }, [user, nav]);
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(username, password);
      nav('/');
    } catch {
      toast.error(t('login.error'));
    } finally {
      setLoading(false);
    }
  };
  
  const toggleLang = () => {
    const newLang = i18n.language === 'fa' ? 'en' : 'fa';
    i18n.changeLanguage(newLang);
    localStorage.setItem('language', newLang);
  };
  
  return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center p-4" dir={isRTL ? 'rtl' : 'ltr'}>
      <button onClick={toggleLang} className={`absolute top-4 ${isRTL ? 'left-4' : 'right-4'} flex items-center gap-2 px-3 py-2 bg-dark-card border border-dark-border rounded-lg text-dark-text hover:text-white`}>
        <Globe className="w-5 h-5" />
        <span>{i18n.language === 'fa' ? 'English' : 'فارسی'}</span>
      </button>
      
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-20 h-20 bg-blue-600/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <Shield className="w-10 h-10 text-blue-500" />
          </div>
          <h1 className="text-3xl font-bold text-white">{t('app.title')}</h1>
        </div>
        
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-xl font-semibold text-white mb-6 text-center">{t('login.title')}</h2>
          
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="text-dark-text text-sm mb-2 block">{t('login.username')}</label>
              <div className="relative">
                <User className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-3 w-5 h-5 text-dark-muted`} />
                <input 
                  type="text" 
                  value={username} 
                  onChange={e => setUsername(e.target.value)} 
                  className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white focus:border-blue-500 outline-none`}
                  required 
                />
              </div>
            </div>
            
            <div>
              <label className="text-dark-text text-sm mb-2 block">{t('login.password')}</label>
              <div className="relative">
                <Lock className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-3 w-5 h-5 text-dark-muted`} />
                <input 
                  type={showPass ? 'text' : 'password'} 
                  value={password} 
                  onChange={e => setPassword(e.target.value)} 
                  className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-10' : 'pl-10 pr-10'} text-white focus:border-blue-500 outline-none`}
                  required 
                />
                <button type="button" onClick={() => setShowPass(!showPass)} className={`absolute ${isRTL ? 'left-3' : 'right-3'} top-3 text-dark-muted hover:text-white`}>
                  {showPass ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
            
            <button type="submit" disabled={loading} className="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg disabled:opacity-50 transition-colors">
              {loading ? <span className="inline-block w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span> : t('login.submit')}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

// ============ LAYOUT ============
const Layout = ({ children }) => {
  const { t, i18n } = useTranslation();
  const { user, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [langOpen, setLangOpen] = useState(false);
  const location = useLocation();
  const isRTL = i18n.language === 'fa';
  
  const menu = [
    { path: '/', icon: LayoutDashboard, label: t('nav.dashboard') },
    { path: '/clients', icon: Shield, label: t('nav.clients') },
    ...(user?.role === 'super_admin' ? [{ path: '/users', icon: Users, label: t('nav.users') }] : []),
    { path: '/settings', icon: Settings, label: t('nav.settings') },
  ];
  
  const changeLang = (lang) => {
    i18n.changeLanguage(lang);
    localStorage.setItem('language', lang);
    setLangOpen(false);
  };
  
  return (
    <div className={`flex h-screen bg-dark-bg ${isRTL ? 'font-vazir' : 'font-inter'}`} dir={isRTL ? 'rtl' : 'ltr'}>
      {sidebarOpen && <div className="fixed inset-0 bg-black/50 z-40 lg:hidden" onClick={() => setSidebarOpen(false)} />}
      
      <aside className={`fixed lg:static inset-y-0 ${isRTL ? 'right-0' : 'left-0'} z-50 w-64 bg-dark-card border-${isRTL ? 'l' : 'r'} border-dark-border transform transition-transform lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : isRTL ? 'translate-x-full' : '-translate-x-full'}`}>
        <div className="flex flex-col h-full">
          <div className="p-6 border-b border-dark-border">
            <h1 className="text-xl font-bold text-white flex items-center gap-2">
              <Shield className="w-8 h-8 text-blue-500" />
              {t('app.title')}
            </h1>
          </div>
          
          <nav className="flex-1 p-4 space-y-2">
            {menu.map(item => (
              <Link 
                key={item.path} 
                to={item.path} 
                onClick={() => setSidebarOpen(false)} 
                className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${location.pathname === item.path ? 'bg-blue-600 text-white' : 'text-dark-muted hover:bg-dark-border hover:text-white'}`}
              >
                <item.icon className="w-5 h-5" />
                {item.label}
              </Link>
            ))}
          </nav>
          
          <div className="p-4 border-t border-dark-border">
            <div className="mb-4">
              <p className="text-white font-medium">{user?.username}</p>
              <p className="text-dark-muted text-sm">{user?.role?.replace('_', ' ')}</p>
            </div>
            <button onClick={logout} className="flex items-center gap-2 text-red-400 hover:bg-red-500/10 px-4 py-2 rounded-lg w-full transition-colors">
              <LogOut className="w-5 h-5" />
              {t('nav.logout')}
            </button>
          </div>
        </div>
      </aside>
      
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-dark-card border-b border-dark-border px-4 py-4 flex items-center justify-between">
          <button onClick={() => setSidebarOpen(!sidebarOpen)} className="lg:hidden text-white">
            {sidebarOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
          
          <div className="relative mr-auto lg:mr-0">
            <button onClick={() => setLangOpen(!langOpen)} className="flex items-center gap-2 px-3 py-2 bg-dark-border rounded-lg text-dark-text hover:text-white">
              <Globe className="w-5 h-5" />
              <span>{t(`lang.${i18n.language}`)}</span>
              <ChevronDown className="w-4 h-4" />
            </button>
            {langOpen && (
              <div className={`absolute ${isRTL ? 'left-0' : 'right-0'} mt-2 w-32 bg-dark-card border border-dark-border rounded-lg shadow-xl z-50`}>
                <button onClick={() => changeLang('en')} className="w-full px-4 py-2 text-left hover:bg-dark-border text-dark-text">English</button>
                <button onClick={() => changeLang('fa')} className="w-full px-4 py-2 text-left hover:bg-dark-border text-dark-text">فارسی</button>
              </div>
            )}
          </div>
        </header>
        
        <main className="flex-1 overflow-auto p-4 lg:p-6">{children}</main>
      </div>
    </div>
  );
};

// ============ DASHBOARD ============
const Dashboard = () => {
  const { t, i18n } = useTranslation();
  const [stats, setStats] = useState({});
  const [system, setSystem] = useState({});
  
  useEffect(() => {
    API.get('/dashboard/stats').then(r => setStats(r.data)).catch(() => {});
    API.get('/dashboard/system').then(r => setSystem(r.data)).catch(() => {});
  }, []);
  
  const cards = [
    { label: t('dashboard.totalClients'), value: stats.total_clients || 0, icon: Users, color: 'blue' },
    { label: t('dashboard.activeClients'), value: stats.active_clients || 0, icon: CheckCircle, color: 'green' },
    { label: t('dashboard.onlineClients'), value: stats.online_clients || 0, icon: Wifi, color: 'emerald' },
    { label: t('dashboard.disabledClients'), value: stats.disabled_clients || 0, icon: XCircle, color: 'gray' },
    { label: t('dashboard.expiredClients'), value: stats.expired_clients || 0, icon: Clock, color: 'red' },
    { label: t('dashboard.totalData'), value: formatBytes(stats.total_data_used), icon: Database, color: 'purple' },
  ];
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">{t('dashboard.title')}</h1>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {cards.map((card, i) => (
          <div key={i} className="bg-dark-card border border-dark-border rounded-xl p-6 hover:border-dark-muted transition-colors">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-dark-muted text-sm mb-1">{card.label}</p>
                <p className="text-2xl font-bold text-white">{card.value}</p>
              </div>
              <div className={`p-3 bg-${card.color}-500/20 rounded-lg`}>
                <card.icon className={`w-6 h-6 text-${card.color}-500`} />
              </div>
            </div>
          </div>
        ))}
      </div>
      
      <div className="bg-dark-card border border-dark-border rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">{t('dashboard.system')}</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.wgInstalled')}</span>
            {system.wireguard_installed ? 
              <span className="flex items-center gap-2 text-green-500"><CheckCircle className="w-5 h-5" />{t('common.yes')}</span> : 
              <span className="flex items-center gap-2 text-red-500"><XCircle className="w-5 h-5" />{t('common.no')}</span>
            }
          </div>
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.interfaceUp')}</span>
            {system.interface_up ? 
              <span className="flex items-center gap-2 text-green-500"><CheckCircle className="w-5 h-5" />{t('common.yes')}</span> : 
              <span className="flex items-center gap-2 text-yellow-500"><XCircle className="w-5 h-5" />{t('common.no')}</span>
            }
          </div>
        </div>
      </div>
    </div>
  );
};

// ============ CLIENTS ============
const Clients = () => {
  const { t, i18n } = useTranslation();
  const { isAdmin } = useAuth();
  const [clients, setClients] = useState([]);
  const [search, setSearch] = useState('');
  const [showAdd, setShowAdd] = useState(false);
  const [showQR, setShowQR] = useState(null);
  const [qrImg, setQrImg] = useState('');
  const [editClient, setEditClient] = useState(null);
  const [form, setForm] = useState({ name: '', email: '', data_limit: '', expiry_days: '', note: '' });
  const isRTL = i18n.language === 'fa';
  
  const load = () => API.get('/clients').then(r => setClients(r.data)).catch(() => {});
  useEffect(() => { load(); }, []);
  
  const handleSubmit = async () => {
    if (!form.name) return toast.error('Name required');
    try {
      const data = {
        name: form.name,
        email: form.email || null,
        data_limit: form.data_limit ? parseFloat(form.data_limit) * 1024 * 1024 * 1024 : null,
        expiry_days: form.expiry_days ? parseInt(form.expiry_days) : null,
        note: form.note || null
      };
      
      if (editClient) {
        await API.put(`/clients/${editClient.id}`, data);
      } else {
        await API.post('/clients', data);
      }
      
      toast.success(editClient ? 'Updated' : 'Created');
      setShowAdd(false);
      setEditClient(null);
      setForm({ name: '', email: '', data_limit: '', expiry_days: '', note: '' });
      load();
    } catch (e) {
      toast.error(e.response?.data?.detail || 'Error');
    }
  };
  
  const handleDelete = async (c) => {
    if (!window.confirm(t('clients.confirmDelete'))) return;
    await API.delete(`/clients/${c.id}`);
    toast.success('Deleted');
    load();
  };
  
  const handleToggle = async (c) => {
    await API.put(`/clients/${c.id}`, { is_enabled: !c.is_enabled });
    load();
  };
  
  const downloadConfig = async (c) => {
    const r = await API.get(`/clients/${c.id}/config`, { responseType: 'blob' });
    const url = URL.createObjectURL(r.data);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${c.name}.conf`;
    a.click();
  };
  
  const showQRCode = async (c) => {
    const r = await API.get(`/clients/${c.id}/qrcode`, { responseType: 'blob' });
    setQrImg(URL.createObjectURL(r.data));
    setShowQR(c);
  };
  
  const openEdit = (c) => {
    setEditClient(c);
    setForm({
      name: c.name,
      email: c.email || '',
      data_limit: c.data_limit ? (c.data_limit / 1024 / 1024 / 1024).toFixed(0) : '',
      expiry_days: c.expiry_days || '',
      note: c.note || ''
    });
    setShowAdd(true);
  };
  
  const filtered = clients.filter(c => 
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.address?.includes(search)
  );
  
  const getStatusColor = (s) => {
    const colors = { active: 'green', disabled: 'gray', expired: 'red', data_limit_reached: 'orange' };
    return colors[s] || 'gray';
  };
  
  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Shield className="w-7 h-7 text-blue-500" />
          {t('clients.title')}
        </h1>
        {isAdmin && (
          <button onClick={() => { setEditClient(null); setForm({ name: '', email: '', data_limit: '', expiry_days: '', note: '' }); setShowAdd(true); }} className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg flex items-center gap-2">
            <Plus className="w-5 h-5" />
            {t('clients.add')}
          </button>
        )}
      </div>
      
      <div className="relative">
        <Search className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-3 w-5 h-5 text-dark-muted`} />
        <input 
          value={search} 
          onChange={e => setSearch(e.target.value)} 
          placeholder={t('common.search')} 
          className={`w-full bg-dark-card border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white`}
        />
      </div>
      
      {filtered.length === 0 ? (
        <div className="text-center py-12 text-dark-muted">
          <Shield className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{t('clients.noClients')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filtered.map(c => (
            <div key={c.id} className="bg-dark-card border border-dark-border rounded-xl p-4 hover:border-dark-muted transition-colors">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  {c.is_online ? <Wifi className="w-5 h-5 text-green-500" /> : <WifiOff className="w-5 h-5 text-dark-muted" />}
                  <div>
                    <h3 className="font-semibold text-white">{c.name}</h3>
                    <p className="text-dark-muted text-sm">{c.address}</p>
                  </div>
                </div>
                <span className={`px-2 py-1 rounded text-xs bg-${getStatusColor(c.status)}-500/20 text-${getStatusColor(c.status)}-500`}>
                  {t(`clients.${c.status}`)}
                </span>
              </div>
              
              <div className="space-y-2 text-sm mb-4">
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.dataUsed')}:</span>
                  <span className="text-white">{formatBytes(c.data_used)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.dataLimit')}:</span>
                  <span className="text-white">{c.data_limit ? formatBytes(c.data_limit) : t('clients.unlimited')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.expiry')}:</span>
                  <span className="text-white">{c.expiry_date ? formatDate(c.expiry_date, i18n.language) : t('clients.never')}</span>
                </div>
              </div>
              
              <div className="flex gap-2 pt-3 border-t border-dark-border">
                <button onClick={() => downloadConfig(c)} className="p-2 hover:bg-dark-border rounded-lg text-dark-muted hover:text-white" title={t('clients.download')}>
                  <Download className="w-4 h-4" />
                </button>
                <button onClick={() => showQRCode(c)} className="p-2 hover:bg-dark-border rounded-lg text-dark-muted hover:text-white" title={t('clients.qrcode')}>
                  <QrCode className="w-4 h-4" />
                </button>
                {isAdmin && (
                  <>
                    <button onClick={() => openEdit(c)} className="p-2 hover:bg-dark-border rounded-lg text-dark-muted hover:text-white" title={t('clients.edit')}>
                      <Edit className="w-4 h-4" />
                    </button>
                    <button onClick={() => handleToggle(c)} className="p-2 hover:bg-dark-border rounded-lg text-dark-muted hover:text-white" title={c.is_enabled ? t('clients.disable') : t('clients.enable')}>
                      <Power className="w-4 h-4" />
                    </button>
                    <button onClick={() => handleDelete(c)} className="p-2 hover:bg-red-500/10 rounded-lg text-dark-muted hover:text-red-500" title={t('clients.delete')}>
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
      
      {/* Add/Edit Modal */}
      {showAdd && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-dark-card border border-dark-border rounded-xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-semibold text-white mb-4">{editClient ? t('clients.edit') : t('clients.add')}</h2>
            
            <div className="space-y-4">
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('clients.name')} *</label>
                <input value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('clients.email')}</label>
                <input value={form.email} onChange={e => setForm({...form, email: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('clients.dataLimit')} (GB)</label>
                <input type="number" value={form.data_limit} onChange={e => setForm({...form, data_limit: e.target.value})} placeholder={t('clients.unlimited')} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('clients.expiryDays')}</label>
                <input type="number" value={form.expiry_days} onChange={e => setForm({...form, expiry_days: e.target.value})} placeholder="30" className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('clients.note')}</label>
                <textarea value={form.note} onChange={e => setForm({...form, note: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" rows="2" />
              </div>
            </div>
            
            <div className="flex gap-3 mt-6">
              <button onClick={handleSubmit} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg">{t('common.save')}</button>
              <button onClick={() => { setShowAdd(false); setEditClient(null); }} className="flex-1 bg-dark-border text-white py-2 rounded-lg">{t('common.cancel')}</button>
            </div>
          </div>
        </div>
      )}
      
      {/* QR Modal */}
      {showQR && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4" onClick={() => setShowQR(null)}>
          <div className="bg-dark-card border border-dark-border rounded-xl p-6 text-center" onClick={e => e.stopPropagation()}>
            <img src={qrImg} alt="QR" className="mx-auto mb-4 rounded-lg" />
            <p className="text-white font-medium">{showQR.name}</p>
            <p className="text-dark-muted text-sm mt-1">{t('clients.qrcode')}</p>
          </div>
        </div>
      )}
    </div>
  );
};

// ============ USERS ============
const UsersPage = () => {
  const { t, i18n } = useTranslation();
  const [users, setUsers] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ username: '', password: '', role: 'viewer' });
  const isRTL = i18n.language === 'fa';
  
  const load = () => API.get('/users').then(r => setUsers(r.data)).catch(() => {});
  useEffect(() => { load(); }, []);
  
  const handleSubmit = async () => {
    if (!form.username || !form.password) return;
    try {
      await API.post('/users', form);
      toast.success('Created');
      setShowAdd(false);
      setForm({ username: '', password: '', role: 'viewer' });
      load();
    } catch (e) {
      toast.error(e.response?.data?.detail || 'Error');
    }
  };
  
  const handleDelete = async (u) => {
    if (!window.confirm(t('users.confirmDelete'))) return;
    try {
      await API.delete(`/users/${u.id}`);
      toast.success('Deleted');
      load();
    } catch (e) {
      toast.error(e.response?.data?.detail || 'Error');
    }
  };
  
  const getRoleLabel = (r) => {
    const roles = { super_admin: t('users.superAdmin'), admin: t('users.admin'), viewer: t('users.viewer') };
    return roles[r] || r;
  };
  
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Users className="w-7 h-7 text-blue-500" />
          {t('users.title')}
        </h1>
        <button onClick={() => setShowAdd(true)} className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg flex items-center gap-2">
          <Plus className="w-5 h-5" />
          {t('users.add')}
        </button>
      </div>
      
      <div className="bg-dark-card border border-dark-border rounded-xl overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="bg-dark-border">
              <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.username')}</th>
              <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.role')}</th>
              <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('clients.actions')}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-dark-border">
            {users.map(u => (
              <tr key={u.id} className="hover:bg-dark-border/50">
                <td className="px-6 py-4 text-white">{u.username}</td>
                <td className="px-6 py-4 text-dark-text">{getRoleLabel(u.role)}</td>
                <td className="px-6 py-4">
                  <button onClick={() => handleDelete(u)} className="p-2 hover:bg-red-500/10 rounded-lg text-dark-muted hover:text-red-500">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      {showAdd && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-dark-card border border-dark-border rounded-xl p-6 w-full max-w-md">
            <h2 className="text-lg font-semibold text-white mb-4">{t('users.add')}</h2>
            <div className="space-y-4">
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('users.username')} *</label>
                <input value={form.username} onChange={e => setForm({...form, username: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('users.password')} *</label>
                <input type="password" value={form.password} onChange={e => setForm({...form, password: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
              </div>
              <div>
                <label className="text-dark-text text-sm mb-1 block">{t('users.role')}</label>
                <select value={form.role} onChange={e => setForm({...form, role: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white">
                  <option value="super_admin">{t('users.superAdmin')}</option>
                  <option value="admin">{t('users.admin')}</option>
                  <option value="viewer">{t('users.viewer')}</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={handleSubmit} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg">{t('common.save')}</button>
              <button onClick={() => setShowAdd(false)} className="flex-1 bg-dark-border text-white py-2 rounded-lg">{t('common.cancel')}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// ============ SETTINGS ============
const SettingsPage = () => {
  const { t } = useTranslation();
  const [settings, setSettings] = useState({});
  const [form, setForm] = useState({ endpoint: '', wg_dns: '', mtu: 1420, persistent_keepalive: 25 });
  
  useEffect(() => {
    API.get('/settings').then(r => {
      setSettings(r.data);
      setForm({
        endpoint: r.data.endpoint || '',
        wg_dns: r.data.wg_dns || '1.1.1.1,8.8.8.8',
        mtu: r.data.mtu || 1420,
        persistent_keepalive: r.data.persistent_keepalive || 25
      });
    }).catch(() => {});
  }, []);
  
  const handleSave = async () => {
    try {
      await API.put('/settings', form);
      toast.success(t('settings.saved'));
    } catch (e) {
      toast.error('Error');
    }
  };
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white flex items-center gap-2">
        <Settings className="w-7 h-7 text-blue-500" />
        {t('settings.title')}
      </h1>
      
      <div className="bg-dark-card border border-dark-border rounded-xl p-6 space-y-4">
        <div>
          <label className="text-dark-text text-sm mb-2 block">{t('settings.endpoint')} *</label>
          <input value={form.endpoint} onChange={e => setForm({...form, endpoint: e.target.value})} placeholder="example.com or 1.2.3.4" className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
        </div>
        <div>
          <label className="text-dark-text text-sm mb-2 block">{t('settings.dns')}</label>
          <input value={form.wg_dns} onChange={e => setForm({...form, wg_dns: e.target.value})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-dark-text text-sm mb-2 block">{t('settings.mtu')}</label>
            <input type="number" value={form.mtu} onChange={e => setForm({...form, mtu: parseInt(e.target.value)})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
          </div>
          <div>
            <label className="text-dark-text text-sm mb-2 block">{t('settings.keepalive')}</label>
            <input type="number" value={form.persistent_keepalive} onChange={e => setForm({...form, persistent_keepalive: parseInt(e.target.value)})} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" />
          </div>
        </div>
        
        <div className="pt-4 border-t border-dark-border">
          <label className="text-dark-text text-sm mb-2 block">{t('settings.publicKey')}</label>
          <code className="block bg-dark-bg border border-dark-border rounded-lg p-4 text-green-400 text-sm break-all">{settings.server_public_key}</code>
        </div>
        
        <button onClick={handleSave} className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg">
          {t('settings.save')}
        </button>
      </div>
    </div>
  );
};

// ============ SUBSCRIPTION PAGE ============
const Subscription = () => {
  const { clientId } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    axios.get(`/api/sub/${clientId}`)
      .then(r => setData(r.data))
      .catch(e => setError(e.response?.data?.detail || 'Not found'));
  }, [clientId]);
  
  if (error) return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center p-4" dir="rtl">
      <div className="bg-dark-card border border-dark-border rounded-xl p-8 text-center">
        <XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
        <p className="text-white">{error}</p>
      </div>
    </div>
  );
  
  if (!data) return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center">
      <div className="animate-spin h-12 w-12 border-t-2 border-blue-500 rounded-full"></div>
    </div>
  );
  
  return (
    <div className="min-h-screen bg-dark-bg py-8 px-4" dir="rtl">
      <div className="max-w-md mx-auto space-y-4">
        <div className="text-center mb-6">
          <Shield className="w-16 h-16 text-blue-500 mx-auto mb-2" />
          <h1 className="text-2xl font-bold text-white">{data.name}</h1>
        </div>
        
        <div className="bg-dark-card border border-dark-border rounded-xl p-4">
          <div className="flex items-center justify-between">
            <span className="text-dark-muted">وضعیت</span>
            <span className={`px-3 py-1 rounded-full text-sm ${data.status === 'active' ? 'bg-green-500/20 text-green-500' : 'bg-red-500/20 text-red-500'}`}>
              {data.status === 'active' ? 'فعال' : data.status === 'expired' ? 'منقضی' : 'غیرفعال'}
            </span>
          </div>
        </div>
        
        <div className="bg-dark-card border border-dark-border rounded-xl p-4 space-y-3">
          <div className="flex justify-between">
            <span className="text-dark-muted">مصرف</span>
            <span className="text-white">{formatBytes(data.data_used)}</span>
          </div>
          {data.data_limit && (
            <div className="flex justify-between">
              <span className="text-dark-muted">محدودیت</span>
              <span className="text-white">{formatBytes(data.data_limit)}</span>
            </div>
          )}
          {data.expiry_date && (
            <div className="flex justify-between">
              <span className="text-dark-muted">انقضا</span>
              <span className="text-white">{new Date(data.expiry_date).toLocaleDateString('fa-IR')}</span>
            </div>
          )}
        </div>
        
        <div className="flex items-center justify-center gap-2 text-dark-muted">
          {data.is_online ? <><Wifi className="w-5 h-5 text-green-500" /> آنلاین</> : <><WifiOff className="w-5 h-5" /> آفلاین</>}
        </div>
      </div>
    </div>
  );
};

// ============ APP ============
export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/sub/:clientId" element={<Subscription />} />
          <Route path="/" element={<ProtectedRoute><Layout><Dashboard /></Layout></ProtectedRoute>} />
          <Route path="/clients" element={<ProtectedRoute><Layout><Clients /></Layout></ProtectedRoute>} />
          <Route path="/users" element={<ProtectedRoute><Layout><UsersPage /></Layout></ProtectedRoute>} />
          <Route path="/settings" element={<ProtectedRoute><Layout><SettingsPage /></Layout></ProtectedRoute>} />
        </Routes>
        <Toaster position="top-center" />
      </BrowserRouter>
    </AuthProvider>
  );
}
APPEOF
}

create_docker_files() {
    # nginx.conf
    cat > $INSTALL_DIR/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    
    location /api {
        proxy_pass http://backend:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

    # docker-compose.yml
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
      - wg-net
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
      - JWT_SECRET=$JWT_SECRET
      - WG_PORT=$WG_PORT
      - WG_NETWORK=$WG_NETWORK
      - WG_ENDPOINT=$SERVER_IP
      - SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
      - SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
      - PANEL_USERNAME=$PANEL_USERNAME
      - PANEL_PASSWORD=$PANEL_PASSWORD
    volumes:
      - /etc/wireguard:/etc/wireguard
    cap_add:
      - NET_ADMIN
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - wg-net

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    container_name: wireguard-panel-frontend
    restart: unless-stopped
    ports:
      - "$PANEL_PORT:80"
    depends_on:
      - backend
    networks:
      - wg-net

volumes:
  mongodb_data:

networks:
  wg-net:
    driver: bridge
EOF

    # Dockerfile.backend
    cat > $INSTALL_DIR/Dockerfile.backend << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y wireguard-tools iproute2 iptables && rm -rf /var/lib/apt/lists/*
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
EXPOSE 8001
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

    # Dockerfile.frontend
    cat > $INSTALL_DIR/Dockerfile.frontend << 'EOF'
FROM node:18-alpine as builder
WORKDIR /app
COPY frontend/package.json ./
RUN yarn install --network-timeout 100000
COPY frontend/ .
RUN yarn build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
EOF

    print_info "Docker files created"
    print_info "  Username: $PANEL_USERNAME"
    print_info "  Password: $PANEL_PASSWORD"
    print_info "  Port: $PANEL_PORT"
}

configure_firewall() {
    print_info "Configuring firewall..."
    
    if command -v ufw &>/dev/null; then
        ufw allow $WG_PORT/udp 2>/dev/null
        ufw allow $PANEL_PORT/tcp 2>/dev/null
    fi
    
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=$WG_PORT/udp 2>/dev/null
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
    fi
}

build_and_start() {
    print_info "Building and starting containers..."
    cd $INSTALL_DIR
    
    docker compose build --no-cache
    docker compose up -d
    
    print_info "Waiting for services to start..."
    sleep 15
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel is running!"
        return 0
    else
        print_error "Failed to start. Check logs:"
        docker compose logs --tail=30
        return 1
    fi
}

print_complete() {
    SERVER_IP=$(get_server_ip)
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅  Installation Complete!                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Panel URL: ${CYAN}http://$SERVER_IP:$PANEL_PORT${NC}"
    echo -e "  Username:  ${CYAN}$PANEL_USERNAME${NC}"
    echo -e "  Password:  ${CYAN}$PANEL_PASSWORD${NC}"
    echo ""
    echo -e "  WireGuard: ${CYAN}$SERVER_IP:51820/UDP${NC}"
    echo ""
    echo -e "${YELLOW}  ⚠️  Change the default password after login!${NC}"
    echo ""
}

# Full installation
install_panel() {
    if is_installed; then
        print_warning "Panel already installed!"
        echo -e "${YELLOW}Reinstall? This will delete all data! (y/n)${NC}"
        read -r REPLY
        if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
            return 0
        fi
        print_info "Removing old installation..."
        cd $INSTALL_DIR
        docker compose down -v 2>/dev/null || true
        rm -rf $INSTALL_DIR
    fi
    
    detect_os || return 1
    ask_user_config || return 0
    
    print_info "Starting installation..."
    
    install_prerequisites || { print_error "Failed: prerequisites"; return 1; }
    install_docker || { print_error "Failed: docker"; return 1; }
    install_wireguard || { print_error "Failed: wireguard"; return 1; }
    setup_wireguard || { print_error "Failed: wireguard setup"; return 1; }
    create_project_files || { print_error "Failed: create files"; return 1; }
    configure_firewall
    build_and_start || { print_error "Failed: start"; return 1; }
    print_complete
}

# Main menu loop
main_menu() {
    while true; do
        show_menu
        echo -e "${CYAN}Select option / انتخاب گزینه (0-10):${NC}"
        read -r choice
        
        case $choice in
            1) install_panel; read -p "Press Enter..." ;;
            2) start_panel_service; read -p "Press Enter..." ;;
            3) stop_panel_service; read -p "Press Enter..." ;;
            4) restart_panel_service; read -p "Press Enter..." ;;
            5) update_panel_service; read -p "Press Enter..." ;;
            6) view_logs_service ;;
            7) panel_status_service; read -p "Press Enter..." ;;
            8) setup_ssl_service; read -p "Press Enter..." ;;
            9) reset_admin_password; read -p "Press Enter..." ;;
            10) uninstall_panel_service; read -p "Press Enter..." ;;
            0) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Start
check_root
main_menu
