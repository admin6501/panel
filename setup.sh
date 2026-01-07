#!/bin/bash

# ===========================================
# WireGuard Panel - Auto Install Script v3.0
# ===========================================
# This script creates all files and installs the panel
# یک اسکریپت که همه چیز را ایجاد و نصب می‌کند
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
SCRIPT_VERSION="3.0"

# Default values - will be asked from user
PANEL_USERNAME="admin"
PANEL_PASSWORD="admin"
PANEL_PORT="80"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Auto Installer v${SCRIPT_VERSION}  🛡️        ║"
    echo "║                                                           ║"
    echo "║     A Modern VPN Management System                        ║"
    echo "║     پنل مدیریت وایرگارد - نصب خودکار                      ║"
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
        print_error "این اسکریپت باید با دسترسی root اجرا شود"
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

# Ask user for panel credentials
ask_user_config() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}     Panel Configuration / تنظیمات پنل                     ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Ask for Username
    echo -e "${YELLOW}Enter panel admin username / نام کاربری ادمین پنل:${NC}"
    read -p "Username [default: admin]: " input_username
    if [ -n "$input_username" ]; then
        PANEL_USERNAME="$input_username"
    fi
    
    echo ""
    
    # Ask for Password
    echo -e "${YELLOW}Enter panel admin password / رمز عبور ادمین پنل:${NC}"
    read -s -p "Password [default: admin]: " input_password
    echo ""
    if [ -n "$input_password" ]; then
        PANEL_PASSWORD="$input_password"
    fi
    
    echo ""
    
    # Ask for Panel Port
    echo -e "${YELLOW}Enter panel port / پورت پنل وب:${NC}"
    read -p "Port [default: 80]: " input_port
    if [ -n "$input_port" ]; then
        PANEL_PORT="$input_port"
    fi
    
    echo ""
    
    # Get server IP
    SERVER_IP=$(get_server_ip)
    
    # Summary
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}     Configuration Summary / خلاصه تنظیمات                  ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Server IP: ${GREEN}$SERVER_IP${NC}"
    echo -e "  Panel Port: ${GREEN}$PANEL_PORT${NC}"
    echo -e "  Admin Username: ${GREEN}$PANEL_USERNAME${NC}"
    echo -e "  Admin Password: ${GREEN}********${NC}"
    echo -e "  WireGuard Port: ${GREEN}$WG_PORT${NC}"
    echo ""
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue or type 'n' to cancel${NC}"
    echo -e "${YELLOW}برای ادامه Enter بزنید یا 'n' برای لغو${NC}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled. / نصب لغو شد."
        exit 0
    fi
    print_info "Starting installation... / شروع نصب..."
}

# Install prerequisites
install_prerequisites() {
    print_info "Installing prerequisites / نصب پیش‌نیازها..."

    # Wait for any existing apt/dpkg processes
    wait_for_apt() {
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
            print_warning "Waiting for other package manager to finish... / در انتظار اتمام پکیج منیجر دیگر..."
            sleep 5
        done
    }

    wait_for_apt

    case $OS in
        ubuntu|debian)
            apt-get update -y
            wait_for_apt
            apt-get install -y curl wget git ca-certificates gnupg lsb-release dnsutils openssl python3 python3-pip
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum update -y
            yum install -y curl wget git ca-certificates bind-utils openssl python3 python3-pip
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    print_success "Prerequisites installed / پیش‌نیازها نصب شدند"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed / داکر از قبل نصب است"
        docker --version
        return
    fi

    print_info "Installing Docker / نصب داکر..."

    # Wait for apt lock
    wait_for_apt() {
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
            print_warning "Waiting for other package manager... / در انتظار پکیج منیجر..."
            sleep 5
        done
    }

    case $OS in
        ubuntu|debian)
            wait_for_apt
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
            wait_for_apt
            apt-get update -y
            wait_for_apt
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL https://get.docker.com | sh
            ;;
    esac

    systemctl start docker
    systemctl enable docker

    print_success "Docker installed / داکر نصب شد"
}

# Install WireGuard
install_wireguard() {
    if command -v wg &> /dev/null; then
        print_success "WireGuard is already installed / وایرگارد از قبل نصب است"
        wg --version
    else
        print_info "Installing WireGuard / نصب وایرگارد..."

        # Wait for apt lock
        wait_for_apt() {
            while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
                print_warning "Waiting for package manager... / در انتظار پکیج منیجر..."
                sleep 5
            done
        }

        case $OS in
            ubuntu|debian)
                wait_for_apt
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

        print_success "WireGuard installed / وایرگارد نصب شد"
    fi

    # Enable IP forwarding
    print_info "Enabling IP forwarding / فعال‌سازی IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p

    print_success "IP forwarding enabled"
}

# Setup WireGuard interface
setup_wireguard() {
    print_info "Setting up WireGuard interface / راه‌اندازی اینترفیس وایرگارد..."

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
        print_success "WireGuard config created / کانفیگ وایرگارد ایجاد شد"
    fi

    if ! wg show $WG_INTERFACE &>/dev/null; then
        wg-quick up $WG_INTERFACE
        print_success "WireGuard interface started / اینترفیس وایرگارد شروع شد"
    fi
    
    systemctl enable wg-quick@$WG_INTERFACE 2>/dev/null || true

    print_success "WireGuard interface $WG_INTERFACE is ready"
    print_info "Server Public Key: $SERVER_PUBLIC_KEY"
}

# Create all project files
create_project_files() {
    print_info "Creating project files / ایجاد فایل‌های پروژه..."

    mkdir -p $INSTALL_DIR
    mkdir -p $INSTALL_DIR/backend
    mkdir -p $INSTALL_DIR/frontend/src/components
    mkdir -p $INSTALL_DIR/frontend/src/pages
    mkdir -p $INSTALL_DIR/frontend/src/contexts
    mkdir -p $INSTALL_DIR/frontend/src/utils
    mkdir -p $INSTALL_DIR/frontend/src/i18n/locales
    mkdir -p $INSTALL_DIR/frontend/public

    # Generate secrets
    JWT_SECRET=$(openssl rand -hex 32)
    SERVER_IP=$(get_server_ip)

    # Create .env file
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
SCRIPT_VERSION=$SCRIPT_VERSION
EOF

    print_success ".env file created"

    # Create backend files
    create_backend_files
    
    # Create frontend files
    create_frontend_files
    
    # Create docker files
    create_docker_files

    print_success "All project files created / همه فایل‌های پروژه ایجاد شدند"
}

# Create backend files
create_backend_files() {
    print_info "Creating backend files..."

    # requirements.txt
    cat > $INSTALL_DIR/backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pymongo==4.6.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
pydantic==2.5.2
pydantic-settings==2.1.0
qrcode[pil]==7.4.2
python-dotenv==1.0.0
aiofiles==23.2.1
apscheduler==3.10.4
EOF

    # models.py
    cat > $INSTALL_DIR/backend/models.py << 'MODELS_EOF'
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum
import uuid


class UserRole(str, Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    VIEWER = "viewer"


class UserBase(BaseModel):
    username: str
    role: UserRole = UserRole.VIEWER
    is_active: bool = True


class UserCreate(UserBase):
    password: str


class UserUpdate(BaseModel):
    username: Optional[str] = None
    password: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None


class User(UserBase):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    created_by: Optional[str] = None

    class Config:
        from_attributes = True


class UserInDB(User):
    hashed_password: str


class ClientStatus(str, Enum):
    ACTIVE = "active"
    DISABLED = "disabled"
    EXPIRED = "expired"
    DATA_LIMIT_REACHED = "data_limit_reached"


class ClientBase(BaseModel):
    name: str
    email: Optional[str] = None
    data_limit: Optional[int] = None
    expiry_date: Optional[datetime] = None
    expiry_days: Optional[int] = None
    start_on_first_connect: bool = False
    auto_renew: bool = False
    auto_renew_days: Optional[int] = None
    auto_renew_data_limit: Optional[int] = None
    note: Optional[str] = None


class ClientCreate(ClientBase):
    pass


class ClientUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    data_limit: Optional[int] = None
    expiry_date: Optional[datetime] = None
    expiry_days: Optional[int] = None
    start_on_first_connect: Optional[bool] = None
    auto_renew: Optional[bool] = None
    auto_renew_days: Optional[int] = None
    auto_renew_data_limit: Optional[int] = None
    note: Optional[str] = None
    is_enabled: Optional[bool] = None


class Client(ClientBase):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    private_key: str = ""
    public_key: str = ""
    preshared_key: str = ""
    address: str = ""
    is_enabled: bool = True
    status: ClientStatus = ClientStatus.ACTIVE
    data_used: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    created_by: Optional[str] = None
    last_handshake: Optional[datetime] = None
    first_connection_at: Optional[datetime] = None
    timer_started: bool = False
    renew_count: int = 0

    class Config:
        from_attributes = True


class ServerSettings(BaseModel):
    id: str = "server_settings"
    server_name: str = "WireGuard Panel"
    wg_interface: str = "wg0"
    wg_port: int = 51820
    wg_network: str = "10.0.0.0/24"
    wg_dns: str = "1.1.1.1,8.8.8.8"
    server_public_key: str = ""
    server_private_key: str = ""
    server_address: str = ""
    endpoint: str = ""
    mtu: int = 1420
    persistent_keepalive: int = 25


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: Optional[str] = None
    username: Optional[str] = None
    role: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


class DashboardStats(BaseModel):
    total_clients: int = 0
    active_clients: int = 0
    disabled_clients: int = 0
    expired_clients: int = 0
    total_data_used: int = 0
    online_clients: int = 0
MODELS_EOF

    # auth.py
    cat > $INSTALL_DIR/backend/auth.py << 'AUTH_EOF'
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os

from models import TokenData, UserRole

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = os.environ.get("JWT_SECRET", "your-secret-key")
ALGORITHM = os.environ.get("JWT_ALGORITHM", "HS256")
EXPIRATION_HOURS = int(os.environ.get("JWT_EXPIRATION_HOURS", "24"))

security = HTTPBearer()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=EXPIRATION_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[TokenData]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("user_id")
        username: str = payload.get("username")
        role: str = payload.get("role")
        if user_id is None:
            return None
        return TokenData(user_id=user_id, username=username, role=role)
    except JWTError:
        return None


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> TokenData:
    token = credentials.credentials
    token_data = decode_token(token)
    if token_data is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token_data


def require_role(allowed_roles: list[UserRole]):
    async def role_checker(current_user: TokenData = Depends(get_current_user)) -> TokenData:
        if current_user.role not in [role.value for role in allowed_roles]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )
        return current_user
    return role_checker


require_super_admin = require_role([UserRole.SUPER_ADMIN])
require_admin = require_role([UserRole.SUPER_ADMIN, UserRole.ADMIN])
require_viewer = require_role([UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.VIEWER])
AUTH_EOF

    # wireguard.py
    cat > $INSTALL_DIR/backend/wireguard.py << 'WG_EOF'
import subprocess
import os
import re
from typing import Optional, Tuple
from datetime import datetime
import ipaddress


class WireGuardManager:
    def __init__(self, interface: str = "wg0", config_dir: str = "/etc/wireguard"):
        self.interface = interface
        self.config_dir = config_dir
        self.config_file = f"{config_dir}/{interface}.conf"
    
    def generate_keys(self) -> Tuple[str, str]:
        try:
            private_key = subprocess.run(
                ["wg", "genkey"],
                capture_output=True, text=True, check=True
            ).stdout.strip()
            
            public_key = subprocess.run(
                ["wg", "pubkey"],
                input=private_key,
                capture_output=True, text=True, check=True
            ).stdout.strip()
            
            return private_key, public_key
        except subprocess.CalledProcessError as e:
            raise Exception(f"Failed to generate keys: {e}")
        except FileNotFoundError:
            import secrets
            import base64
            private = base64.b64encode(secrets.token_bytes(32)).decode()
            public = base64.b64encode(secrets.token_bytes(32)).decode()
            return private, public
    
    def generate_preshared_key(self) -> str:
        try:
            psk = subprocess.run(
                ["wg", "genpsk"],
                capture_output=True, text=True, check=True
            ).stdout.strip()
            return psk
        except (subprocess.CalledProcessError, FileNotFoundError):
            import secrets
            import base64
            return base64.b64encode(secrets.token_bytes(32)).decode()
    
    def get_next_ip(self, network: str, used_ips: list[str]) -> str:
        net = ipaddress.ip_network(network, strict=False)
        hosts = list(net.hosts())
        
        for host in hosts[1:]:
            ip_str = str(host)
            if ip_str not in used_ips:
                return f"{ip_str}/32"
        
        raise Exception("No available IP addresses in the network")
    
    def get_interface_stats(self) -> dict:
        try:
            result = subprocess.run(
                ["wg", "show", self.interface, "dump"],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                return {}
            
            stats = {}
            lines = result.stdout.strip().split("\n")
            
            for line in lines[1:]:
                parts = line.split("\t")
                if len(parts) >= 8:
                    public_key = parts[0]
                    stats[public_key] = {
                        "preshared_key": parts[1] if parts[1] != "(none)" else None,
                        "endpoint": parts[2] if parts[2] != "(none)" else None,
                        "allowed_ips": parts[3],
                        "latest_handshake": int(parts[4]) if parts[4] != "0" else None,
                        "transfer_rx": int(parts[5]),
                        "transfer_tx": int(parts[6]),
                        "persistent_keepalive": parts[7] if parts[7] != "off" else None
                    }
            
            return stats
        except (subprocess.CalledProcessError, FileNotFoundError):
            return {}
    
    def get_client_data_usage(self, public_key: str) -> Tuple[int, int]:
        stats = self.get_interface_stats()
        if public_key in stats:
            return stats[public_key]["transfer_rx"], stats[public_key]["transfer_tx"]
        return 0, 0
    
    def get_client_last_handshake(self, public_key: str) -> Optional[datetime]:
        stats = self.get_interface_stats()
        if public_key in stats and stats[public_key]["latest_handshake"]:
            return datetime.fromtimestamp(stats[public_key]["latest_handshake"])
        return None
    
    def add_peer(self, public_key: str, preshared_key: str, allowed_ips: str) -> bool:
        try:
            cmd = ["wg", "set", self.interface, "peer", public_key]
            if preshared_key:
                cmd.extend(["preshared-key", "/dev/stdin"])
            cmd.extend(["allowed-ips", allowed_ips])
            
            if preshared_key:
                subprocess.run(cmd, input=preshared_key, text=True, check=True)
            else:
                subprocess.run(cmd, check=True)
            
            self.save_config()
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def remove_peer(self, public_key: str) -> bool:
        try:
            subprocess.run(
                ["wg", "set", self.interface, "peer", public_key, "remove"],
                check=True
            )
            self.save_config()
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def save_config(self) -> bool:
        try:
            subprocess.run(
                ["wg-quick", "save", self.interface],
                check=True
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def restart_interface(self) -> bool:
        try:
            subprocess.run(["wg-quick", "down", self.interface], check=False)
            subprocess.run(["wg-quick", "up", self.interface], check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def generate_client_config(
        self,
        client_private_key: str,
        client_address: str,
        server_public_key: str,
        server_endpoint: str,
        preshared_key: str,
        dns: str = "1.1.1.1,8.8.8.8",
        mtu: int = 1420,
        persistent_keepalive: int = 25
    ) -> str:
        config = f"""[Interface]
PrivateKey = {client_private_key}
Address = {client_address}
DNS = {dns}
MTU = {mtu}

[Peer]
PublicKey = {server_public_key}
PresharedKey = {preshared_key}
Endpoint = {server_endpoint}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = {persistent_keepalive}
"""
        return config
    
    def is_wireguard_installed(self) -> bool:
        try:
            subprocess.run(["wg", "--version"], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def is_interface_up(self) -> bool:
        try:
            result = subprocess.run(
                ["wg", "show", self.interface],
                capture_output=True
            )
            return result.returncode == 0
        except FileNotFoundError:
            return False


wg_manager = WireGuardManager()
WG_EOF

    # server.py - main FastAPI application
    cat > $INSTALL_DIR/backend/server.py << 'SERVER_EOF'
from fastapi import FastAPI, HTTPException, Depends, status, Response, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import List, Optional
from contextlib import asynccontextmanager
import os
import io
import qrcode
import uuid
import asyncio
import threading

from dotenv import load_dotenv
load_dotenv()

from models import (
    User, UserCreate, UserUpdate, UserInDB, UserRole,
    Client, ClientCreate, ClientUpdate, ClientStatus,
    ServerSettings, Token, LoginRequest, DashboardStats, TokenData
)
from auth import (
    get_password_hash, verify_password, create_access_token,
    get_current_user, require_super_admin, require_admin, require_viewer
)
from wireguard import wg_manager


auto_renewal_running = False

def check_clients_task():
    global auto_renewal_running
    while auto_renewal_running:
        try:
            check_and_process_clients()
        except Exception as e:
            print(f"Error in background task: {e}")
        import time
        time.sleep(60)


def check_and_process_clients():
    from pymongo import MongoClient
    mongo_client = MongoClient(os.environ.get("MONGO_URL", "mongodb://localhost:27017"))
    db = mongo_client[os.environ.get("DB_NAME", "wireguard_panel")]
    clients_col = db["clients"]
    
    stats = wg_manager.get_interface_stats()
    
    for client in clients_col.find({"is_enabled": True}):
        client_id = client["id"]
        public_key = client.get("public_key", "")
        
        if client.get("start_on_first_connect") and not client.get("timer_started"):
            if public_key in stats:
                client_stats = stats[public_key]
                if client_stats.get("latest_handshake"):
                    expiry_days = client.get("expiry_days", 30)
                    new_expiry = datetime.utcnow() + timedelta(days=expiry_days)
                    
                    clients_col.update_one(
                        {"id": client_id},
                        {"$set": {
                            "first_connection_at": datetime.utcnow(),
                            "timer_started": True,
                            "expiry_date": new_expiry
                        }}
                    )
                    print(f"Timer started for client {client.get('name')}: {expiry_days} days")
        
        if client.get("auto_renew"):
            needs_renewal = False
            
            expiry_date = client.get("expiry_date")
            if expiry_date:
                if isinstance(expiry_date, str):
                    expiry_date = datetime.fromisoformat(expiry_date.replace('Z', '+00:00'))
                if expiry_date < datetime.utcnow():
                    needs_renewal = True
            
            data_limit = client.get("data_limit")
            data_used = client.get("data_used", 0)
            if data_limit and data_used >= data_limit:
                needs_renewal = True
            
            if needs_renewal:
                renew_days = client.get("auto_renew_days") or client.get("expiry_days") or 30
                renew_data = client.get("auto_renew_data_limit") or client.get("data_limit")
                
                update_data = {
                    "data_used": 0,
                    "renew_count": client.get("renew_count", 0) + 1
                }
                
                if renew_days:
                    update_data["expiry_date"] = datetime.utcnow() + timedelta(days=renew_days)
                
                if renew_data:
                    update_data["data_limit"] = renew_data
                
                clients_col.update_one(
                    {"id": client_id},
                    {"$set": update_data}
                )
                print(f"Auto-renewed client {client.get('name')}: {renew_days} days, {renew_data} bytes")
    
    mongo_client.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    global auto_renewal_running
    auto_renewal_running = True
    
    init_super_admin()
    init_server_settings()
    
    bg_thread = threading.Thread(target=check_clients_task, daemon=True)
    bg_thread.start()
    print("Background auto-renewal task started")
    
    yield
    
    auto_renewal_running = False
    print("Background task stopped")


app = FastAPI(title="WireGuard Panel API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = os.environ.get("DB_NAME", "wireguard_panel")
client = MongoClient(MONGO_URL)
db = client[DB_NAME]

users_collection = db["users"]
clients_collection = db["clients"]
settings_collection = db["settings"]


def init_super_admin():
    if users_collection.count_documents({"role": UserRole.SUPER_ADMIN.value}) == 0:
        username = os.environ.get("PANEL_USERNAME", "admin")
        password = os.environ.get("PANEL_PASSWORD", "admin")
        admin = {
            "id": str(uuid.uuid4()),
            "username": username,
            "hashed_password": get_password_hash(password),
            "role": UserRole.SUPER_ADMIN.value,
            "is_active": True,
            "created_at": datetime.utcnow(),
            "created_by": None
        }
        users_collection.insert_one(admin)
        print(f"Default super admin created: {username}")


def init_server_settings():
    if settings_collection.count_documents({"id": "server_settings"}) == 0:
        server_public_key = os.environ.get("SERVER_PUBLIC_KEY", "")
        server_private_key = os.environ.get("SERVER_PRIVATE_KEY", "")
        
        if not server_public_key or not server_private_key:
            server_private_key, server_public_key = wg_manager.generate_keys()
        
        default_endpoint = os.environ.get("DEFAULT_ENDPOINT", os.environ.get("WG_ENDPOINT", ""))
        
        settings = {
            "id": "server_settings",
            "server_name": "WireGuard Panel",
            "wg_interface": os.environ.get("WG_INTERFACE", "wg0"),
            "wg_port": int(os.environ.get("WG_PORT", "51820")),
            "wg_network": os.environ.get("WG_NETWORK", "10.0.0.0/24"),
            "wg_dns": os.environ.get("WG_DNS", "1.1.1.1,8.8.8.8"),
            "server_public_key": server_public_key,
            "server_private_key": server_private_key,
            "server_address": "10.0.0.1/24",
            "endpoint": default_endpoint,
            "mtu": 1420,
            "persistent_keepalive": 25,
            "subscription_enabled": True
        }
        settings_collection.insert_one(settings)
        print(f"Server settings initialized with endpoint: {default_endpoint or '(not set)'}")


@app.post("/api/auth/login", response_model=Token)
async def login(request: LoginRequest):
    user = users_collection.find_one({"username": request.username})
    if not user or not verify_password(request.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
    
    if not user.get("is_active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    access_token = create_access_token(
        data={
            "user_id": user["id"],
            "username": user["username"],
            "role": user["role"]
        }
    )
    return Token(access_token=access_token)


@app.get("/api/auth/me")
async def get_current_user_info(current_user: TokenData = Depends(get_current_user)):
    user = users_collection.find_one({"id": current_user.user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": user["id"],
        "username": user["username"],
        "role": user["role"],
        "is_active": user.get("is_active", True)
    }


@app.post("/api/auth/change-password")
async def change_password(
    old_password: str,
    new_password: str,
    current_user: TokenData = Depends(get_current_user)
):
    user = users_collection.find_one({"id": current_user.user_id})
    if not user or not verify_password(old_password, user["hashed_password"]):
        raise HTTPException(status_code=400, detail="Invalid old password")
    
    users_collection.update_one(
        {"id": current_user.user_id},
        {"$set": {"hashed_password": get_password_hash(new_password)}}
    )
    return {"message": "Password changed successfully"}


@app.get("/api/users", response_model=List[dict])
async def get_users(current_user: TokenData = Depends(require_super_admin)):
    users = list(users_collection.find({}, {"hashed_password": 0, "_id": 0}))
    return users


@app.post("/api/users", response_model=dict)
async def create_user(user: UserCreate, current_user: TokenData = Depends(require_super_admin)):
    if users_collection.find_one({"username": user.username}):
        raise HTTPException(status_code=400, detail="Username already exists")
    
    new_user = {
        "id": str(uuid.uuid4()),
        "username": user.username,
        "hashed_password": get_password_hash(user.password),
        "role": user.role.value,
        "is_active": user.is_active,
        "created_at": datetime.utcnow(),
        "created_by": current_user.user_id
    }
    users_collection.insert_one(new_user)
    
    return {
        "id": new_user["id"],
        "username": new_user["username"],
        "role": new_user["role"],
        "is_active": new_user["is_active"],
        "created_at": new_user["created_at"].isoformat()
    }


@app.put("/api/users/{user_id}", response_model=dict)
async def update_user(
    user_id: str,
    user_update: UserUpdate,
    current_user: TokenData = Depends(require_super_admin)
):
    user = users_collection.find_one({"id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = {}
    if user_update.username is not None:
        existing = users_collection.find_one({"username": user_update.username, "id": {"$ne": user_id}})
        if existing:
            raise HTTPException(status_code=400, detail="Username already exists")
        update_data["username"] = user_update.username
    
    if user_update.password is not None:
        update_data["hashed_password"] = get_password_hash(user_update.password)
    
    if user_update.role is not None:
        update_data["role"] = user_update.role.value
    
    if user_update.is_active is not None:
        update_data["is_active"] = user_update.is_active
    
    if update_data:
        users_collection.update_one({"id": user_id}, {"$set": update_data})
    
    updated_user = users_collection.find_one({"id": user_id}, {"hashed_password": 0, "_id": 0})
    return updated_user


@app.delete("/api/users/{user_id}")
async def delete_user(user_id: str, current_user: TokenData = Depends(require_super_admin)):
    if user_id == current_user.user_id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    
    result = users_collection.delete_one({"id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {"message": "User deleted successfully"}


@app.get("/api/clients", response_model=List[dict])
async def get_clients(current_user: TokenData = Depends(require_viewer)):
    clients = list(clients_collection.find({}, {"_id": 0}))
    
    stats = wg_manager.get_interface_stats()
    for client in clients:
        if client["public_key"] in stats:
            client_stats = stats[client["public_key"]]
            client["data_used"] = client_stats["transfer_rx"] + client_stats["transfer_tx"]
            client["is_online"] = client_stats["latest_handshake"] is not None and \
                (datetime.now().timestamp() - client_stats["latest_handshake"]) < 180
        else:
            client["is_online"] = False
        
        if not client.get("is_enabled", True):
            client["status"] = ClientStatus.DISABLED.value
        elif client.get("expiry_date") and datetime.fromisoformat(str(client["expiry_date"])) < datetime.utcnow():
            client["status"] = ClientStatus.EXPIRED.value
        elif client.get("data_limit") and client.get("data_used", 0) >= client["data_limit"]:
            client["status"] = ClientStatus.DATA_LIMIT_REACHED.value
        else:
            client["status"] = ClientStatus.ACTIVE.value
    
    return clients


@app.post("/api/clients", response_model=dict)
async def create_client(client: ClientCreate, current_user: TokenData = Depends(require_admin)):
    settings = settings_collection.find_one({"id": "server_settings"})
    if not settings:
        raise HTTPException(status_code=500, detail="Server settings not found")
    
    if not settings.get("endpoint"):
        raise HTTPException(status_code=400, detail="Server endpoint not configured. Please set it in settings.")
    
    private_key, public_key = wg_manager.generate_keys()
    preshared_key = wg_manager.generate_preshared_key()
    
    used_ips = [c["address"].split("/")[0] for c in clients_collection.find({}, {"address": 1})]
    used_ips.append(settings["server_address"].split("/")[0])
    
    try:
        address = wg_manager.get_next_ip(settings["wg_network"], used_ips)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    new_client = {
        "id": str(uuid.uuid4()),
        "name": client.name,
        "email": client.email,
        "private_key": private_key,
        "public_key": public_key,
        "preshared_key": preshared_key,
        "address": address,
        "data_limit": client.data_limit,
        "expiry_date": client.expiry_date if not client.start_on_first_connect else None,
        "expiry_days": client.expiry_days,
        "start_on_first_connect": client.start_on_first_connect,
        "auto_renew": client.auto_renew,
        "auto_renew_days": client.auto_renew_days,
        "auto_renew_data_limit": client.auto_renew_data_limit,
        "note": client.note,
        "is_enabled": True,
        "status": ClientStatus.ACTIVE.value,
        "data_used": 0,
        "created_at": datetime.utcnow(),
        "created_by": current_user.user_id,
        "last_handshake": None,
        "first_connection_at": None,
        "timer_started": not client.start_on_first_connect,
        "renew_count": 0
    }
    
    wg_manager.add_peer(public_key, preshared_key, address)
    
    clients_collection.insert_one(new_client)
    
    response = dict(new_client)
    response["created_at"] = response["created_at"].isoformat()
    if response.get("expiry_date"):
        response["expiry_date"] = response["expiry_date"].isoformat()
    if "_id" in response:
        del response["_id"]
    
    return response


@app.get("/api/clients/{client_id}", response_model=dict)
async def get_client(client_id: str, current_user: TokenData = Depends(require_viewer)):
    client = clients_collection.find_one({"id": client_id}, {"_id": 0})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    return client


@app.put("/api/clients/{client_id}", response_model=dict)
async def update_client(
    client_id: str,
    client_update: ClientUpdate,
    current_user: TokenData = Depends(require_admin)
):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    update_data = {}
    if client_update.name is not None:
        update_data["name"] = client_update.name
    if client_update.email is not None:
        update_data["email"] = client_update.email
    if client_update.data_limit is not None:
        update_data["data_limit"] = client_update.data_limit
    if client_update.expiry_date is not None:
        update_data["expiry_date"] = client_update.expiry_date
    if client_update.expiry_days is not None:
        update_data["expiry_days"] = client_update.expiry_days
    if client_update.start_on_first_connect is not None:
        update_data["start_on_first_connect"] = client_update.start_on_first_connect
    if client_update.auto_renew is not None:
        update_data["auto_renew"] = client_update.auto_renew
    if client_update.auto_renew_days is not None:
        update_data["auto_renew_days"] = client_update.auto_renew_days
    if client_update.auto_renew_data_limit is not None:
        update_data["auto_renew_data_limit"] = client_update.auto_renew_data_limit
    if client_update.note is not None:
        update_data["note"] = client_update.note
    if client_update.is_enabled is not None:
        update_data["is_enabled"] = client_update.is_enabled
        if client_update.is_enabled:
            wg_manager.add_peer(
                client["public_key"],
                client["preshared_key"],
                client["address"]
            )
        else:
            wg_manager.remove_peer(client["public_key"])
    
    if update_data:
        clients_collection.update_one({"id": client_id}, {"$set": update_data})
    
    updated_client = clients_collection.find_one({"id": client_id}, {"_id": 0})
    return updated_client


@app.delete("/api/clients/{client_id}")
async def delete_client(client_id: str, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    wg_manager.remove_peer(client["public_key"])
    
    clients_collection.delete_one({"id": client_id})
    return {"message": "Client deleted successfully"}


@app.get("/api/clients/{client_id}/config")
async def get_client_config(client_id: str, current_user: TokenData = Depends(require_viewer)):
    client = clients_collection.find_one({"id": client_id}, {"_id": 0})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    settings = settings_collection.find_one({"id": "server_settings"})
    if not settings:
        raise HTTPException(status_code=500, detail="Server settings not found")
    
    config = wg_manager.generate_client_config(
        client_private_key=client["private_key"],
        client_address=client["address"],
        server_public_key=settings["server_public_key"],
        server_endpoint=f"{settings['endpoint']}:{settings['wg_port']}",
        preshared_key=client["preshared_key"],
        dns=settings["wg_dns"],
        mtu=settings["mtu"],
        persistent_keepalive=settings["persistent_keepalive"]
    )
    
    return Response(
        content=config,
        media_type="text/plain",
        headers={
            "Content-Disposition": f"attachment; filename={client['name']}.conf"
        }
    )


@app.get("/api/clients/{client_id}/qrcode")
async def get_client_qrcode(client_id: str, current_user: TokenData = Depends(require_viewer)):
    client = clients_collection.find_one({"id": client_id}, {"_id": 0})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    settings = settings_collection.find_one({"id": "server_settings"})
    if not settings:
        raise HTTPException(status_code=500, detail="Server settings not found")
    
    config = wg_manager.generate_client_config(
        client_private_key=client["private_key"],
        client_address=client["address"],
        server_public_key=settings["server_public_key"],
        server_endpoint=f"{settings['endpoint']}:{settings['wg_port']}",
        preshared_key=client["preshared_key"],
        dns=settings["wg_dns"],
        mtu=settings["mtu"],
        persistent_keepalive=settings["persistent_keepalive"]
    )
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(config)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    img_bytes = io.BytesIO()
    img.save(img_bytes, format="PNG")
    img_bytes.seek(0)
    
    return StreamingResponse(img_bytes, media_type="image/png")


@app.post("/api/clients/{client_id}/reset-data")
async def reset_client_data(client_id: str, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    clients_collection.update_one(
        {"id": client_id},
        {"$set": {"data_used": 0}}
    )
    return {"message": "Data usage reset successfully"}


@app.post("/api/clients/{client_id}/reset-expiry")
async def reset_client_expiry(client_id: str, days: int = 30, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    new_expiry = datetime.utcnow() + timedelta(days=days)
    clients_collection.update_one(
        {"id": client_id},
        {"$set": {"expiry_date": new_expiry}}
    )
    return {"message": f"Expiry date extended by {days} days", "new_expiry": new_expiry.isoformat()}


@app.post("/api/clients/{client_id}/remove-expiry")
async def remove_client_expiry(client_id: str, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    clients_collection.update_one(
        {"id": client_id},
        {"$set": {"expiry_date": None}}
    )
    return {"message": "Expiry date removed successfully"}


@app.post("/api/clients/{client_id}/reset-timer")
async def reset_client_timer(client_id: str, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    expiry_days = client.get("expiry_days", 30)
    new_expiry = datetime.utcnow() + timedelta(days=expiry_days)
    
    update_data = {
        "expiry_date": new_expiry,
        "data_used": 0,
        "timer_started": True,
        "first_connection_at": datetime.utcnow()
    }
    
    clients_collection.update_one(
        {"id": client_id},
        {"$set": update_data}
    )
    return {
        "message": f"Timer reset to {expiry_days} days",
        "new_expiry": new_expiry.isoformat(),
        "expiry_days": expiry_days
    }


@app.post("/api/clients/{client_id}/full-reset")
async def full_reset_client(client_id: str, current_user: TokenData = Depends(require_admin)):
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    update_data = {
        "data_used": 0,
        "first_connection_at": None,
        "timer_started": False,
        "renew_count": 0
    }
    
    if client.get("start_on_first_connect"):
        update_data["expiry_date"] = None
    else:
        expiry_days = client.get("expiry_days", 30)
        if expiry_days:
            update_data["expiry_date"] = datetime.utcnow() + timedelta(days=expiry_days)
    
    clients_collection.update_one(
        {"id": client_id},
        {"$set": update_data}
    )
    return {"message": "Client fully reset successfully"}


@app.get("/api/settings")
async def get_settings(current_user: TokenData = Depends(require_admin)):
    settings = settings_collection.find_one({"id": "server_settings"}, {"_id": 0})
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    settings.pop("server_private_key", None)
    return settings


@app.put("/api/settings")
async def update_settings(settings_update: dict, current_user: TokenData = Depends(require_super_admin)):
    allowed_fields = [
        "server_name", "endpoint", "wg_port", "wg_dns", "mtu", "persistent_keepalive",
        "subscription_enabled"
    ]
    update_data = {k: v for k, v in settings_update.items() if k in allowed_fields}
    
    if update_data:
        settings_collection.update_one(
            {"id": "server_settings"},
            {"$set": update_data}
        )
    
    settings = settings_collection.find_one({"id": "server_settings"}, {"_id": 0})
    settings.pop("server_private_key", None)
    return settings


@app.get("/api/sub/{client_id}")
async def get_subscription_info(client_id: str):
    settings = settings_collection.find_one({"id": "server_settings"})
    if not settings or not settings.get("subscription_enabled", True):
        raise HTTPException(status_code=403, detail="Subscription page is disabled")
    
    client = clients_collection.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    stats = wg_manager.get_interface_stats()
    public_key = client.get("public_key", "")
    
    download = 0
    upload = 0
    is_online = False
    
    if public_key in stats:
        client_stats = stats[public_key]
        download = client_stats.get("transfer_rx", 0)
        upload = client_stats.get("transfer_tx", 0)
        if client_stats.get("latest_handshake"):
            is_online = (datetime.now().timestamp() - client_stats["latest_handshake"]) < 180
    
    total_used = download + upload
    data_limit = client.get("data_limit")
    remaining = (data_limit - total_used) if data_limit else None
    
    status = "active"
    if not client.get("is_enabled", True):
        status = "disabled"
    elif client.get("expiry_date"):
        expiry = client["expiry_date"]
        if isinstance(expiry, str):
            expiry = datetime.fromisoformat(expiry.replace('Z', '+00:00'))
        if expiry < datetime.utcnow():
            status = "expired"
    
    if data_limit and total_used >= data_limit:
        status = "data_limit_reached"
    
    return {
        "name": client.get("name"),
        "status": status,
        "is_online": is_online,
        "expiry_date": client.get("expiry_date"),
        "expiry_days": client.get("expiry_days"),
        "start_on_first_connect": client.get("start_on_first_connect", False),
        "timer_started": client.get("timer_started", True),
        "first_connection_at": client.get("first_connection_at"),
        "data_limit": data_limit,
        "data_used": total_used,
        "data_remaining": remaining,
        "download": download,
        "upload": upload,
        "auto_renew": client.get("auto_renew", False),
        "renew_count": client.get("renew_count", 0),
        "created_at": client.get("created_at")
    }


@app.get("/api/dashboard/stats", response_model=DashboardStats)
async def get_dashboard_stats(current_user: TokenData = Depends(require_viewer)):
    clients = list(clients_collection.find({}))
    
    total_clients = len(clients)
    active_clients = 0
    disabled_clients = 0
    expired_clients = 0
    total_data_used = 0
    online_clients = 0
    
    stats = wg_manager.get_interface_stats()
    
    for client in clients:
        if not client.get("is_enabled", True):
            disabled_clients += 1
        elif client.get("expiry_date") and datetime.fromisoformat(str(client["expiry_date"])) < datetime.utcnow():
            expired_clients += 1
        else:
            active_clients += 1
        
        if client["public_key"] in stats:
            client_stats = stats[client["public_key"]]
            data_used = client_stats["transfer_rx"] + client_stats["transfer_tx"]
            total_data_used += data_used
            
            if client_stats["latest_handshake"] and \
               (datetime.now().timestamp() - client_stats["latest_handshake"]) < 180:
                online_clients += 1
    
    return DashboardStats(
        total_clients=total_clients,
        active_clients=active_clients,
        disabled_clients=disabled_clients,
        expired_clients=expired_clients,
        total_data_used=total_data_used,
        online_clients=online_clients
    )


@app.get("/api/dashboard/system")
async def get_system_info(current_user: TokenData = Depends(require_admin)):
    return {
        "wireguard_installed": wg_manager.is_wireguard_installed(),
        "interface_up": wg_manager.is_interface_up(),
        "interface_name": wg_manager.interface
    }


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
SERVER_EOF

    print_success "Backend files created"
}

# Create frontend files
create_frontend_files() {
    print_info "Creating frontend files..."
    
    # package.json
    cat > $INSTALL_DIR/frontend/package.json << 'PKGJSON_EOF'
{
  "name": "wireguard-panel",
  "version": "1.0.0",
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
    "lucide-react": "^0.294.0",
    "date-fns": "^2.30.0",
    "recharts": "^2.10.3"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "tailwindcss": "^3.3.6",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32"
  }
}
PKGJSON_EOF

    # .env
    echo "REACT_APP_BACKEND_URL=/api" > $INSTALL_DIR/frontend/.env

    # tailwind.config.js
    cat > $INSTALL_DIR/frontend/tailwind.config.js << 'TAILWIND_EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
    "./public/index.html"
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
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
    },
  },
  plugins: [],
}
TAILWIND_EOF

    # postcss.config.js
    cat > $INSTALL_DIR/frontend/postcss.config.js << 'POSTCSS_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
POSTCSS_EOF

    # public/index.html
    cat > $INSTALL_DIR/frontend/public/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#1e40af" />
    <meta name="description" content="WireGuard VPN Management Panel" />
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Vazirmatn:wght@400;500;600;700&display=swap" rel="stylesheet">
    <title>WireGuard Panel</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
HTML_EOF

    # Create React source files
    print_info "Creating React source files..."
    
    create_frontend_source_files
    
    print_success "Frontend files created"
}

# Create all frontend source files inline
create_frontend_source_files() {
    # src/index.js
    cat > $INSTALL_DIR/frontend/src/index.js << 'INDEXJS_EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import './i18n/i18n';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
INDEXJS_EOF

    # src/index.css
    cat > $INSTALL_DIR/frontend/src/index.css << 'INDEXCSS_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --font-en: 'Inter', sans-serif;
  --font-fa: 'Vazirmatn', sans-serif;
}

body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

[dir="rtl"] body {
  font-family: var(--font-fa);
}

[dir="ltr"] body {
  font-family: var(--font-en);
}

::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #1e293b;
}

::-webkit-scrollbar-thumb {
  background: #475569;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #64748b;
}

[dir="rtl"] .rtl-flip {
  transform: scaleX(-1);
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.animate-fadeIn {
  animation: fadeIn 0.3s ease-out;
}

.card-hover {
  transition: all 0.3s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 40px -15px rgba(0, 0, 0, 0.3);
}

input:focus, select:focus, textarea:focus {
  outline: none;
  ring: 2px;
  ring-color: #3b82f6;
}

.btn-primary {
  @apply bg-primary-600 hover:bg-primary-700 text-white font-medium py-2 px-4 rounded-lg transition-all duration-200;
}

.btn-secondary {
  @apply bg-slate-600 hover:bg-slate-700 text-white font-medium py-2 px-4 rounded-lg transition-all duration-200;
}

.btn-danger {
  @apply bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-lg transition-all duration-200;
}

.modal-backdrop {
  background-color: rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(4px);
}

.gradient-text {
  background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
INDEXCSS_EOF

    # src/App.css
    cat > $INSTALL_DIR/frontend/src/App.css << 'APPCSS_EOF'
.dark {
  color-scheme: dark;
}
APPCSS_EOF

    # src/App.js
    cat > $INSTALL_DIR/frontend/src/App.js << 'APPJS_EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Clients from './pages/Clients';
import Users from './pages/Users';
import Settings from './pages/Settings';
import Subscription from './pages/Subscription';
import './App.css';

const ProtectedRoute = ({ children, requiredRole }) => {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-dark-bg flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (requiredRole === 'super_admin' && user?.role !== 'super_admin') {
    return <Navigate to="/" replace />;
  }

  return children;
};

function AppContent() {
  const { i18n } = useTranslation();
  const isRTL = i18n.language === 'fa';

  React.useEffect(() => {
    document.documentElement.dir = isRTL ? 'rtl' : 'ltr';
    document.documentElement.lang = i18n.language;
  }, [i18n.language, isRTL]);

  return (
    <Router>
      <div className={`min-h-screen bg-dark-bg ${isRTL ? 'font-vazir' : 'font-inter'}`}>
        <Routes>
          <Route path="/sub/:clientId" element={<Subscription />} />
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="clients" element={<Clients />} />
            <Route
              path="users"
              element={
                <ProtectedRoute requiredRole="super_admin">
                  <Users />
                </ProtectedRoute>
              }
            />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
        <Toaster
          position={isRTL ? 'top-left' : 'top-right'}
          toastOptions={{
            className: 'bg-dark-card text-dark-text border border-dark-border',
            duration: 4000,
          }}
        />
      </div>
    </Router>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
APPJS_EOF

    # src/utils/api.js
    cat > $INSTALL_DIR/frontend/src/utils/api.js << 'APIJS_EOF'
import axios from 'axios';

const API_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:8001/api';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
APIJS_EOF

    # src/utils/helpers.js
    cat > $INSTALL_DIR/frontend/src/utils/helpers.js << 'HELPERSJS_EOF'
export const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 Bytes';

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

export const parseBytes = (value, unit) => {
  const units = {
    'Bytes': 1,
    'KB': 1024,
    'MB': 1024 * 1024,
    'GB': 1024 * 1024 * 1024,
    'TB': 1024 * 1024 * 1024 * 1024
  };
  return value * (units[unit] || 1);
};

export const formatDate = (dateString) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('fa-IR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
};

export const formatDateForInput = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toISOString().split('T')[0];
};

export const getStatusColor = (status) => {
  const colors = {
    active: 'bg-green-500',
    disabled: 'bg-gray-500',
    expired: 'bg-red-500',
    data_limit_reached: 'bg-orange-500'
  };
  return colors[status] || 'bg-gray-500';
};

export const getRoleDisplayName = (role, t) => {
  const roles = {
    super_admin: t('users.superAdmin'),
    admin: t('users.admin'),
    viewer: t('users.viewer')
  };
  return roles[role] || role;
};
HELPERSJS_EOF

    # src/contexts/AuthContext.js
    cat > $INSTALL_DIR/frontend/src/contexts/AuthContext.js << 'AUTHCTX_EOF'
import React, { createContext, useContext, useState, useEffect } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState(localStorage.getItem('token'));

  useEffect(() => {
    if (token) {
      fetchUser();
    } else {
      setLoading(false);
    }
  }, [token]);

  const fetchUser = async () => {
    try {
      const response = await api.get('/auth/me');
      setUser(response.data);
    } catch (error) {
      localStorage.removeItem('token');
      setToken(null);
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const login = async (username, password) => {
    const response = await api.post('/auth/login', { username, password });
    const newToken = response.data.access_token;
    localStorage.setItem('token', newToken);
    setToken(newToken);
    await fetchUser();
    return response.data;
  };

  const logout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
  };

  const isAdmin = () => {
    return user?.role === 'super_admin' || user?.role === 'admin';
  };

  const isSuperAdmin = () => {
    return user?.role === 'super_admin';
  };

  return (
    <AuthContext.Provider value={{
      user,
      token,
      loading,
      login,
      logout,
      isAdmin,
      isSuperAdmin,
      isAuthenticated: !!user
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
AUTHCTX_EOF

    # src/components/Modal.js
    cat > $INSTALL_DIR/frontend/src/components/Modal.js << 'MODALJS_EOF'
import React from 'react';
import { X } from 'lucide-react';

const Modal = ({ isOpen, onClose, title, children, size = 'md' }) => {
  if (!isOpen) return null;

  const sizeClasses = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl'
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 modal-backdrop"
        onClick={onClose}
      />
      <div
        className={`relative bg-dark-card border border-dark-border rounded-xl shadow-2xl w-full ${sizeClasses[size]} max-h-[90vh] overflow-hidden animate-fadeIn`}
      >
        <div className="flex items-center justify-between p-4 border-b border-dark-border">
          <h2 className="text-lg font-semibold text-white">{title}</h2>
          <button
            onClick={onClose}
            className="p-1 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-4 overflow-y-auto max-h-[calc(90vh-60px)]">
          {children}
        </div>
      </div>
    </div>
  );
};

export default Modal;
MODALJS_EOF

    # src/i18n/i18n.js
    cat > $INSTALL_DIR/frontend/src/i18n/i18n.js << 'I18NJS_EOF'
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import fa from './locales/fa.json';

const savedLang = localStorage.getItem('language') || 'fa';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      fa: { translation: fa }
    },
    lng: savedLang,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;
I18NJS_EOF

    # Create locale files
    create_locale_files
    
    # Create page components
    create_page_components
    
    # Create Clients page
    create_clients_page
    
    # Create Layout component
    create_layout_component
}

# Create locale files
create_locale_files() {
    # en.json
    cat > $INSTALL_DIR/frontend/src/i18n/locales/en.json << 'ENJSON_EOF'
{
  "app": {"title": "WireGuard Panel", "subtitle": "VPN Management System"},
  "nav": {"dashboard": "Dashboard", "clients": "Clients", "users": "Users", "settings": "Settings", "logout": "Logout"},
  "login": {"title": "Login", "subtitle": "Enter your credentials to access the panel", "username": "Username", "password": "Password", "submit": "Login", "error": "Invalid username or password"},
  "dashboard": {"title": "Dashboard", "totalClients": "Total Clients", "activeClients": "Active Clients", "onlineClients": "Online Now", "disabledClients": "Disabled", "expiredClients": "Expired", "totalDataUsed": "Total Data Used", "systemStatus": "System Status", "wireguardInstalled": "WireGuard Installed", "interfaceUp": "Interface Up", "yes": "Yes", "no": "No"},
  "clients": {"title": "Clients", "addNew": "Add Client", "name": "Name", "email": "Email", "address": "IP Address", "status": "Status", "dataUsed": "Data Used", "dataLimit": "Data Limit", "expiryDate": "Expiry Date", "expiryDays": "Duration (Days)", "expiryDaysHelp": "Number of days validity", "createdAt": "Created At", "actions": "Actions", "active": "Active", "disabled": "Disabled", "expired": "Expired", "dataLimitReached": "Data Limit Reached", "unlimited": "Unlimited", "never": "Never", "online": "Online", "offline": "Offline", "downloadConfig": "Download Config", "showQR": "Show QR Code", "edit": "Edit", "delete": "Delete", "enable": "Enable", "disable": "Disable", "resetData": "Reset Data Usage", "resetTimer": "Reset Timer", "extendExpiry": "Extend 30 Days", "removeExpiry": "Remove Time Limit", "fullReset": "Full Reset", "expiryExtended": "Expiry date extended", "timerReset": "Timer reset successfully", "fullResetSuccess": "Client fully reset", "confirmFullReset": "Are you sure? This will reset data and time.", "timeSettings": "Time Settings", "startOnFirstConnect": "Start timer on first connection", "autoRenew": "Auto Renewal", "autoRenewDays": "Days for renewal", "autoRenewData": "Data for renewal", "sameAsExpiry": "Same as original duration", "sameAsDataLimit": "Same as original limit", "waitingForConnect": "Waiting for connection", "renewCount": "Renewal count", "copySubLink": "Copy Subscription Link", "subLinkCopied": "Subscription link copied", "filterAll": "All", "showing": "Showing", "note": "Note", "noClients": "No clients found", "confirmDelete": "Are you sure you want to delete this client?", "deleteSuccess": "Client deleted successfully", "createSuccess": "Client created successfully", "updateSuccess": "Client updated successfully", "qrTitle": "QR Code", "scanQR": "Scan this QR code with WireGuard app"},
  "users": {"title": "Users Management", "addNew": "Add User", "username": "Username", "password": "Password", "role": "Role", "status": "Status", "createdAt": "Created At", "actions": "Actions", "superAdmin": "Super Admin", "admin": "Admin", "viewer": "Viewer", "active": "Active", "inactive": "Inactive", "edit": "Edit", "delete": "Delete", "noUsers": "No users found", "confirmDelete": "Are you sure you want to delete this user?", "deleteSuccess": "User deleted successfully", "createSuccess": "User created successfully", "updateSuccess": "User updated successfully", "cannotDeleteSelf": "Cannot delete your own account"},
  "settings": {"title": "Settings", "serverName": "Server Name", "endpoint": "Server Endpoint (IP or Domain)", "port": "WireGuard Port", "dns": "DNS Servers", "mtu": "MTU", "keepalive": "Persistent Keepalive", "publicKey": "Server Public Key", "save": "Save Settings", "saveSuccess": "Settings saved successfully", "endpointRequired": "Server endpoint is required to generate client configs", "subscriptionSettings": "Subscription Page Settings", "subscriptionPage": "User Subscription Page", "subscriptionPageDesc": "Users can view their subscription status with a unique link"},
  "common": {"save": "Save", "cancel": "Cancel", "close": "Close", "confirm": "Confirm", "loading": "Loading...", "error": "Error", "success": "Success", "search": "Search...", "noData": "No data available"},
  "language": {"en": "English", "fa": "فارسی"}
}
ENJSON_EOF

    # fa.json
    cat > $INSTALL_DIR/frontend/src/i18n/locales/fa.json << 'FAJSON_EOF'
{
  "app": {"title": "پنل وایرگارد", "subtitle": "سیستم مدیریت VPN"},
  "nav": {"dashboard": "داشبورد", "clients": "کلاینت‌ها", "users": "کاربران", "settings": "تنظیمات", "logout": "خروج"},
  "login": {"title": "ورود", "subtitle": "برای دسترسی به پنل وارد شوید", "username": "نام کاربری", "password": "رمز عبور", "submit": "ورود", "error": "نام کاربری یا رمز عبور اشتباه است"},
  "dashboard": {"title": "داشبورد", "totalClients": "کل کلاینت‌ها", "activeClients": "کلاینت‌های فعال", "onlineClients": "آنلاین", "disabledClients": "غیرفعال", "expiredClients": "منقضی شده", "totalDataUsed": "کل مصرف داده", "systemStatus": "وضعیت سیستم", "wireguardInstalled": "وایرگارد نصب شده", "interfaceUp": "اینترفیس فعال", "yes": "بله", "no": "خیر"},
  "clients": {"title": "کلاینت‌ها", "addNew": "افزودن کلاینت", "name": "نام", "email": "ایمیل", "address": "آدرس IP", "status": "وضعیت", "dataUsed": "مصرف داده", "dataLimit": "محدودیت داده", "expiryDate": "تاریخ انقضا", "expiryDays": "مدت اعتبار (روز)", "expiryDaysHelp": "تعداد روز اعتبار", "createdAt": "تاریخ ایجاد", "actions": "عملیات", "active": "فعال", "disabled": "غیرفعال", "expired": "منقضی", "dataLimitReached": "محدودیت داده تمام شده", "unlimited": "نامحدود", "never": "بدون انقضا", "online": "آنلاین", "offline": "آفلاین", "downloadConfig": "دانلود کانفیگ", "showQR": "نمایش QR Code", "edit": "ویرایش", "delete": "حذف", "enable": "فعال کردن", "disable": "غیرفعال کردن", "resetData": "ریست مصرف داده", "resetTimer": "ریست تایمر", "extendExpiry": "تمدید ۳۰ روز", "removeExpiry": "حذف محدودیت زمان", "fullReset": "ریست کامل", "expiryExtended": "تاریخ انقضا تمدید شد", "timerReset": "تایمر ریست شد", "fullResetSuccess": "کلاینت با موفقیت ریست شد", "confirmFullReset": "آیا مطمئن هستید؟ این عمل حجم و زمان را ریست می‌کند.", "timeSettings": "تنظیمات زمان", "startOnFirstConnect": "شروع تایمر از اولین اتصال", "autoRenew": "تمدید خودکار", "autoRenewDays": "روز برای تمدید", "autoRenewData": "حجم برای تمدید", "sameAsExpiry": "مانند مدت اصلی", "sameAsDataLimit": "مانند محدودیت اصلی", "waitingForConnect": "در انتظار اتصال", "renewCount": "تعداد تمدید", "copySubLink": "کپی لینک اشتراک", "subLinkCopied": "لینک اشتراک کپی شد", "filterAll": "همه", "showing": "نمایش", "note": "یادداشت", "noClients": "کلاینتی یافت نشد", "confirmDelete": "آیا مطمئن هستید که می‌خواهید این کلاینت را حذف کنید؟", "deleteSuccess": "کلاینت با موفقیت حذف شد", "createSuccess": "کلاینت با موفقیت ایجاد شد", "updateSuccess": "کلاینت با موفقیت بروزرسانی شد", "qrTitle": "کد QR", "scanQR": "این کد را با اپلیکیشن WireGuard اسکن کنید"},
  "users": {"title": "مدیریت کاربران", "addNew": "افزودن کاربر", "username": "نام کاربری", "password": "رمز عبور", "role": "نقش", "status": "وضعیت", "createdAt": "تاریخ ایجاد", "actions": "عملیات", "superAdmin": "مدیر ارشد", "admin": "مدیر", "viewer": "بیننده", "active": "فعال", "inactive": "غیرفعال", "edit": "ویرایش", "delete": "حذف", "noUsers": "کاربری یافت نشد", "confirmDelete": "آیا مطمئن هستید که می‌خواهید این کاربر را حذف کنید؟", "deleteSuccess": "کاربر با موفقیت حذف شد", "createSuccess": "کاربر با موفقیت ایجاد شد", "updateSuccess": "کاربر با موفقیت بروزرسانی شد", "cannotDeleteSelf": "امکان حذف حساب خود وجود ندارد"},
  "settings": {"title": "تنظیمات", "serverName": "نام سرور", "endpoint": "آدرس سرور (IP یا دامنه)", "port": "پورت وایرگارد", "dns": "سرورهای DNS", "mtu": "MTU", "keepalive": "Persistent Keepalive", "publicKey": "کلید عمومی سرور", "save": "ذخیره تنظیمات", "saveSuccess": "تنظیمات با موفقیت ذخیره شد", "endpointRequired": "آدرس سرور برای ایجاد کانفیگ کلاینت‌ها الزامی است", "subscriptionSettings": "تنظیمات صفحه اشتراک", "subscriptionPage": "صفحه اشتراک کاربران", "subscriptionPageDesc": "کاربران می‌توانند با لینک اختصاصی، وضعیت اشتراک خود را مشاهده کنند"},
  "common": {"save": "ذخیره", "cancel": "انصراف", "close": "بستن", "confirm": "تأیید", "loading": "در حال بارگذاری...", "error": "خطا", "success": "موفقیت", "search": "جستجو...", "noData": "داده‌ای موجود نیست"},
  "language": {"en": "English", "fa": "فارسی"}
}
FAJSON_EOF
}

# Create all page components inline
create_page_components() {
    echo "Creating page components inline..."

    # Login.js
    cat > $INSTALL_DIR/frontend/src/pages/Login.js << 'LOGINJS_EOF'
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { Shield, User, Lock, AlertCircle, Globe } from 'lucide-react';
import toast from 'react-hot-toast';

const Login = () => {
  const { t, i18n } = useTranslation();
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const isRTL = i18n.language === 'fa';

  React.useEffect(() => {
    if (isAuthenticated) navigate('/');
  }, [isAuthenticated, navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(username, password);
      toast.success(t('common.success'));
      navigate('/');
    } catch (err) {
      setError(t('login.error'));
    } finally {
      setLoading(false);
    }
  };

  const toggleLanguage = () => {
    const newLang = i18n.language === 'fa' ? 'en' : 'fa';
    i18n.changeLanguage(newLang);
    localStorage.setItem('language', newLang);
  };

  return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center p-4">
      <button onClick={toggleLanguage} className={`absolute top-4 ${isRTL ? 'left-4' : 'right-4'} flex items-center gap-2 px-3 py-2 bg-dark-card border border-dark-border rounded-lg text-dark-text hover:text-white transition-colors`}>
        <Globe className="w-5 h-5" />
        <span>{i18n.language === 'fa' ? 'English' : 'فارسی'}</span>
      </button>
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-primary-600/20 rounded-full mb-4">
            <Shield className="w-10 h-10 text-primary-500" />
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">{t('app.title')}</h1>
          <p className="text-dark-muted">{t('login.subtitle')}</p>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6 shadow-2xl">
          <h2 className="text-xl font-semibold text-white mb-6 text-center">{t('login.title')}</h2>
          {error && (
            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/50 rounded-lg flex items-center gap-2 text-red-400">
              <AlertCircle className="w-5 h-5 flex-shrink-0" /><span>{error}</span>
            </div>
          )}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">{t('login.username')}</label>
              <div className="relative">
                <User className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} />
                <input type="text" value={username} onChange={(e) => setUsername(e.target.value)} className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500 focus:ring-1 focus:ring-primary-500 transition-colors`} placeholder={t('login.username')} required />
              </div>
            </div>
            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">{t('login.password')}</label>
              <div className="relative">
                <Lock className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} />
                <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500 focus:ring-1 focus:ring-primary-500 transition-colors`} placeholder={t('login.password')} required />
              </div>
            </div>
            <button type="submit" disabled={loading} className="w-full bg-primary-600 hover:bg-primary-700 text-white font-medium py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2">
              {loading ? <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" /> : t('login.submit')}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Login;
LOGINJS_EOF

    # Dashboard.js
    cat > $INSTALL_DIR/frontend/src/pages/Dashboard.js << 'DASHBOARDJS_EOF'
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Users, UserCheck, UserX, Clock, Database, Wifi, Server, CheckCircle, XCircle } from 'lucide-react';
import api from '../utils/api';

const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 Bytes';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

const Dashboard = () => {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [systemInfo, setSystemInfo] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => { fetchData(); }, []);

  const fetchData = async () => {
    try {
      const [statsRes, systemRes] = await Promise.all([api.get('/dashboard/stats'), api.get('/dashboard/system')]);
      setStats(statsRes.data);
      setSystemInfo(systemRes.data);
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    { title: t('dashboard.totalClients'), value: stats?.total_clients || 0, icon: Users, color: 'bg-blue-500' },
    { title: t('dashboard.activeClients'), value: stats?.active_clients || 0, icon: UserCheck, color: 'bg-green-500' },
    { title: t('dashboard.onlineClients'), value: stats?.online_clients || 0, icon: Wifi, color: 'bg-emerald-500' },
    { title: t('dashboard.disabledClients'), value: stats?.disabled_clients || 0, icon: UserX, color: 'bg-gray-500' },
    { title: t('dashboard.expiredClients'), value: stats?.expired_clients || 0, icon: Clock, color: 'bg-red-500' },
    { title: t('dashboard.totalDataUsed'), value: formatBytes(stats?.total_data_used || 0), icon: Database, color: 'bg-purple-500' }
  ];

  if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div></div>;

  return (
    <div className="space-y-6 animate-fadeIn">
      <div><h1 className="text-2xl font-bold text-white">{t('dashboard.title')}</h1></div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {statCards.map((card, index) => {
          const Icon = card.icon;
          return (
            <div key={index} className="bg-dark-card border border-dark-border rounded-xl p-6 card-hover">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-dark-muted text-sm mb-1">{card.title}</p>
                  <p className="text-2xl font-bold text-white">{card.value}</p>
                </div>
                <div className={`p-3 ${card.color} rounded-lg bg-opacity-20`}>
                  <Icon className={`w-6 h-6 ${card.color.replace('bg-', 'text-')}`} />
                </div>
              </div>
            </div>
          );
        })}
      </div>
      <div className="bg-dark-card border border-dark-border rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <Server className="w-5 h-5 text-primary-500" />{t('dashboard.systemStatus')}
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.wireguardInstalled')}</span>
            <span className="flex items-center gap-2">
              {systemInfo?.wireguard_installed ? <><CheckCircle className="w-5 h-5 text-green-500" /><span className="text-green-500">{t('dashboard.yes')}</span></> : <><XCircle className="w-5 h-5 text-red-500" /><span className="text-red-500">{t('dashboard.no')}</span></>}
            </span>
          </div>
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.interfaceUp')}</span>
            <span className="flex items-center gap-2">
              {systemInfo?.interface_up ? <><CheckCircle className="w-5 h-5 text-green-500" /><span className="text-green-500">{t('dashboard.yes')}</span></> : <><XCircle className="w-5 h-5 text-yellow-500" /><span className="text-yellow-500">{t('dashboard.no')}</span></>}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
DASHBOARDJS_EOF

    # Settings.js
    cat > $INSTALL_DIR/frontend/src/pages/Settings.js << 'SETTINGSJS_EOF'
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Settings as SettingsIcon, Server, Globe, Network, Key, Save, AlertCircle, Link, Eye, EyeOff } from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';

const Settings = () => {
  const { t } = useTranslation();
  const { isSuperAdmin } = useAuth();
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({ server_name: '', endpoint: '', wg_port: 51820, wg_dns: '1.1.1.1,8.8.8.8', mtu: 1420, persistent_keepalive: 25, subscription_enabled: true });

  useEffect(() => { fetchSettings(); }, []);

  const fetchSettings = async () => {
    try {
      const response = await api.get('/settings');
      setSettings(response.data);
      setFormData({ server_name: response.data.server_name || '', endpoint: response.data.endpoint || '', wg_port: response.data.wg_port || 51820, wg_dns: response.data.wg_dns || '1.1.1.1,8.8.8.8', mtu: response.data.mtu || 1420, persistent_keepalive: response.data.persistent_keepalive || 25, subscription_enabled: response.data.subscription_enabled !== false });
    } catch (error) {
      toast.error(t('common.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.put('/settings', formData);
      toast.success(t('settings.saveSuccess'));
      fetchSettings();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div></div>;

  return (
    <div className="space-y-6 animate-fadeIn">
      <div><h1 className="text-2xl font-bold text-white flex items-center gap-2"><SettingsIcon className="w-7 h-7 text-primary-500" />{t('settings.title')}</h1></div>
      {!settings?.endpoint && <div className="bg-yellow-500/10 border border-yellow-500/50 rounded-xl p-4 flex items-start gap-3"><AlertCircle className="w-5 h-5 text-yellow-500 flex-shrink-0 mt-0.5" /><p className="text-yellow-500">{t('settings.endpointRequired')}</p></div>}
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2"><Server className="w-5 h-5 text-primary-500" />{t('settings.title')}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div><label className="block text-dark-text text-sm font-medium mb-2">{t('settings.serverName')}</label><input type="text" value={formData.server_name} onChange={(e) => setFormData({ ...formData, server_name: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" disabled={!isSuperAdmin()} /></div>
            <div><label className="block text-dark-text text-sm font-medium mb-2"><Globe className="w-4 h-4 inline ml-1" />{t('settings.endpoint')} *</label><input type="text" value={formData.endpoint} onChange={(e) => setFormData({ ...formData, endpoint: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" placeholder="example.com or 1.2.3.4" disabled={!isSuperAdmin()} /></div>
            <div><label className="block text-dark-text text-sm font-medium mb-2"><Network className="w-4 h-4 inline ml-1" />{t('settings.port')}</label><input type="number" value={formData.wg_port} onChange={(e) => setFormData({ ...formData, wg_port: parseInt(e.target.value) })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" disabled={!isSuperAdmin()} /></div>
            <div><label className="block text-dark-text text-sm font-medium mb-2">{t('settings.dns')}</label><input type="text" value={formData.wg_dns} onChange={(e) => setFormData({ ...formData, wg_dns: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" disabled={!isSuperAdmin()} /></div>
            <div><label className="block text-dark-text text-sm font-medium mb-2">{t('settings.mtu')}</label><input type="number" value={formData.mtu} onChange={(e) => setFormData({ ...formData, mtu: parseInt(e.target.value) })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" disabled={!isSuperAdmin()} /></div>
            <div><label className="block text-dark-text text-sm font-medium mb-2">{t('settings.keepalive')}</label><input type="number" value={formData.persistent_keepalive} onChange={(e) => setFormData({ ...formData, persistent_keepalive: parseInt(e.target.value) })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" disabled={!isSuperAdmin()} /></div>
          </div>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2"><Link className="w-5 h-5 text-primary-500" />{t('settings.subscriptionSettings')}</h2>
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <div className="flex items-center gap-3">{formData.subscription_enabled ? <Eye className="w-5 h-5 text-green-500" /> : <EyeOff className="w-5 h-5 text-red-500" />}<div><p className="text-white font-medium">{t('settings.subscriptionPage')}</p><p className="text-dark-muted text-sm">{t('settings.subscriptionPageDesc')}</p></div></div>
            <label className="relative inline-flex items-center cursor-pointer"><input type="checkbox" checked={formData.subscription_enabled} onChange={(e) => setFormData({ ...formData, subscription_enabled: e.target.checked })} className="sr-only peer" disabled={!isSuperAdmin()} /><div className="w-11 h-6 bg-dark-border peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-500"></div></label>
          </div>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2"><Key className="w-5 h-5 text-primary-500" />{t('settings.publicKey')}</h2>
          <div className="bg-dark-bg border border-dark-border rounded-lg p-4"><code className="text-green-400 break-all text-sm">{settings?.server_public_key || 'N/A'}</code></div>
        </div>
        {isSuperAdmin() && <button type="submit" disabled={saving} className="btn-primary flex items-center gap-2">{saving ? <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" /> : <Save className="w-5 h-5" />}{t('settings.save')}</button>}
      </form>
    </div>
  );
};

export default Settings;
SETTINGSJS_EOF

    # Users.js
    cat > $INSTALL_DIR/frontend/src/pages/Users.js << 'USERSJS_EOF'
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Users as UsersIcon, Plus, Search, Edit, Trash2, Shield, ShieldCheck, Eye } from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import Modal from '../components/Modal';
import toast from 'react-hot-toast';

const Users = () => {
  const { t, i18n } = useTranslation();
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [formData, setFormData] = useState({ username: '', password: '', role: 'viewer', is_active: true });
  const isRTL = i18n.language === 'fa';

  useEffect(() => { fetchUsers(); }, []);

  const fetchUsers = async () => {
    try { const response = await api.get('/users'); setUsers(response.data); } catch (error) { toast.error(t('common.error')); } finally { setLoading(false); }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = { username: formData.username, role: formData.role, is_active: formData.is_active };
      if (formData.password) data.password = formData.password;
      if (selectedUser) { await api.put(`/users/${selectedUser.id}`, data); toast.success(t('users.updateSuccess')); }
      else { data.password = formData.password; await api.post('/users', data); toast.success(t('users.createSuccess')); }
      setShowModal(false); resetForm(); fetchUsers();
    } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleDelete = async (user) => {
    if (user.id === currentUser?.id) { toast.error(t('users.cannotDeleteSelf')); return; }
    if (!window.confirm(t('users.confirmDelete'))) return;
    try { await api.delete(`/users/${user.id}`); toast.success(t('users.deleteSuccess')); fetchUsers(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleEdit = (user) => { setSelectedUser(user); setFormData({ username: user.username, password: '', role: user.role, is_active: user.is_active }); setShowModal(true); };
  const resetForm = () => { setSelectedUser(null); setFormData({ username: '', password: '', role: 'viewer', is_active: true }); };
  const getRoleIcon = (role) => { if (role === 'super_admin') return <ShieldCheck className="w-4 h-4 text-purple-500" />; if (role === 'admin') return <Shield className="w-4 h-4 text-blue-500" />; return <Eye className="w-4 h-4 text-gray-500" />; };
  const getRoleLabel = (role) => { if (role === 'super_admin') return t('users.superAdmin'); if (role === 'admin') return t('users.admin'); return t('users.viewer'); };
  const filteredUsers = users.filter(user => user.username.toLowerCase().includes(searchQuery.toLowerCase()));

  if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div></div>;

  return (
    <div className="space-y-6 animate-fadeIn">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2"><UsersIcon className="w-7 h-7 text-primary-500" />{t('users.title')}</h1>
        <button onClick={() => { resetForm(); setShowModal(true); }} className="btn-primary flex items-center gap-2"><Plus className="w-5 h-5" />{t('users.addNew')}</button>
      </div>
      <div className="relative"><Search className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} /><input type="text" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder={t('common.search')} className={`w-full bg-dark-card border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500`} /></div>
      {filteredUsers.length === 0 ? <div className="text-center py-12 text-dark-muted"><UsersIcon className="w-16 h-16 mx-auto mb-4 opacity-50" /><p>{t('users.noUsers')}</p></div> : (
        <div className="bg-dark-card border border-dark-border rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead><tr className="bg-dark-border"><th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.username')}</th><th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.role')}</th><th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.status')}</th><th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase">{t('users.actions')}</th></tr></thead>
              <tbody className="divide-y divide-dark-border">
                {filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-dark-border/50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap"><div className="flex items-center gap-3"><div className="p-2 bg-dark-border rounded-lg">{getRoleIcon(user.role)}</div><span className="text-white font-medium">{user.username}</span></div></td>
                    <td className="px-6 py-4 whitespace-nowrap text-dark-text">{getRoleLabel(user.role)}</td>
                    <td className="px-6 py-4 whitespace-nowrap"><span className={`px-2 py-1 rounded-full text-xs font-medium ${user.is_active ? 'bg-green-500/20 text-green-500' : 'bg-red-500/20 text-red-500'}`}>{user.is_active ? t('users.active') : t('users.inactive')}</span></td>
                    <td className="px-6 py-4 whitespace-nowrap"><div className="flex items-center gap-2"><button onClick={() => handleEdit(user)} className="p-2 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"><Edit className="w-4 h-4" /></button>{user.id !== currentUser?.id && <button onClick={() => handleDelete(user)} className="p-2 text-dark-muted hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors"><Trash2 className="w-4 h-4" /></button>}</div></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      <Modal isOpen={showModal} onClose={() => { setShowModal(false); resetForm(); }} title={selectedUser ? t('users.edit') : t('users.addNew')}>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('users.username')} *</label><input type="text" value={formData.username} onChange={(e) => setFormData({ ...formData, username: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" required /></div>
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('users.password')} {!selectedUser && '*'}</label><input type="password" value={formData.password} onChange={(e) => setFormData({ ...formData, password: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" required={!selectedUser} /></div>
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('users.role')}</label><select value={formData.role} onChange={(e) => setFormData({ ...formData, role: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"><option value="super_admin">{t('users.superAdmin')}</option><option value="admin">{t('users.admin')}</option><option value="viewer">{t('users.viewer')}</option></select></div>
          <div className="flex items-center gap-2"><input type="checkbox" id="is_active" checked={formData.is_active} onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })} className="w-4 h-4 text-primary-600 bg-dark-bg border-dark-border rounded focus:ring-primary-500" /><label htmlFor="is_active" className="text-dark-text">{t('users.active')}</label></div>
          <div className="flex gap-3 pt-4"><button type="submit" className="btn-primary flex-1">{t('common.save')}</button><button type="button" onClick={() => { setShowModal(false); resetForm(); }} className="btn-secondary flex-1">{t('common.cancel')}</button></div>
        </form>
      </Modal>
    </div>
  );
};

export default Users;
USERSJS_EOF

    # Subscription.js
    cat > $INSTALL_DIR/frontend/src/pages/Subscription.js << 'SUBSCRIPTIONJS_EOF'
import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { Shield, Wifi, WifiOff, Clock, Database, Download, Upload, Calendar, CheckCircle, XCircle, AlertCircle, RefreshCw, Zap } from 'lucide-react';
import axios from 'axios';

const API_URL = process.env.REACT_APP_BACKEND_URL || '/api';

const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 بایت';
  const k = 1024; const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['بایت', 'کیلوبایت', 'مگابایت', 'گیگابایت', 'ترابایت'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

const formatDate = (dateString) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('fa-IR', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });
};

const getRemainingDays = (expiryDate) => {
  if (!expiryDate) return null;
  const now = new Date(); const expiry = new Date(expiryDate);
  const diff = expiry - now;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
};

const Subscription = () => {
  const { clientId } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => { fetchData(); const interval = setInterval(fetchData, 30000); return () => clearInterval(interval); }, [clientId]);

  const fetchData = async () => {
    try { const response = await axios.get(`${API_URL}/sub/${clientId}`); setData(response.data); setError(null); }
    catch (err) { setError(err.response?.data?.detail || 'خطا در دریافت اطلاعات'); }
    finally { setLoading(false); }
  };

  const getStatusInfo = (status) => {
    const statusMap = {
      active: { label: 'فعال', color: 'text-green-500', bg: 'bg-green-500/20', icon: CheckCircle },
      disabled: { label: 'غیرفعال', color: 'text-gray-500', bg: 'bg-gray-500/20', icon: XCircle },
      expired: { label: 'منقضی شده', color: 'text-red-500', bg: 'bg-red-500/20', icon: AlertCircle },
      data_limit_reached: { label: 'حجم تمام شده', color: 'text-orange-500', bg: 'bg-orange-500/20', icon: AlertCircle }
    };
    return statusMap[status] || statusMap.active;
  };

  if (loading) return <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center" dir="rtl"><div className="text-center"><div className="animate-spin rounded-full h-16 w-16 border-t-2 border-b-2 border-blue-500 mx-auto mb-4"></div><p className="text-slate-400">در حال بارگذاری...</p></div></div>;
  if (error) return <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center" dir="rtl"><div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-8 text-center max-w-md"><XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" /><h1 className="text-xl font-bold text-white mb-2">خطا</h1><p className="text-slate-400">{error}</p></div></div>;

  const statusInfo = getStatusInfo(data.status);
  const StatusIcon = statusInfo.icon;
  const remainingDays = getRemainingDays(data.expiry_date);
  const usagePercent = data.data_limit ? Math.min((data.data_used / data.data_limit) * 100, 100) : 0;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 py-8 px-4" dir="rtl">
      <div className="max-w-lg mx-auto space-y-6">
        <div className="text-center"><div className="inline-flex items-center justify-center w-20 h-20 bg-blue-500/20 rounded-full mb-4"><Shield className="w-10 h-10 text-blue-500" /></div><h1 className="text-2xl font-bold text-white mb-1">{data.name}</h1><p className="text-slate-400">اطلاعات اشتراک WireGuard</p></div>
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3"><div className={`p-3 rounded-xl ${statusInfo.bg}`}><StatusIcon className={`w-6 h-6 ${statusInfo.color}`} /></div><div><p className="text-slate-400 text-sm">وضعیت</p><p className={`font-bold text-lg ${statusInfo.color}`}>{statusInfo.label}</p></div></div>
            <div className="flex items-center gap-2">{data.is_online ? <span className="flex items-center gap-1 px-3 py-1 bg-green-500/20 text-green-500 rounded-full text-sm"><Wifi className="w-4 h-4" />آنلاین</span> : <span className="flex items-center gap-1 px-3 py-1 bg-slate-600/50 text-slate-400 rounded-full text-sm"><WifiOff className="w-4 h-4" />آفلاین</span>}</div>
          </div>
        </div>
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <h2 className="text-white font-semibold mb-4 flex items-center gap-2"><Database className="w-5 h-5 text-blue-500" />مصرف داده</h2>
          {data.data_limit ? (<><div className="flex justify-between text-sm mb-2"><span className="text-slate-400">مصرف شده</span><span className="text-white">{formatBytes(data.data_used)}</span></div><div className="w-full bg-slate-700 rounded-full h-3 mb-2"><div className={`h-3 rounded-full transition-all ${usagePercent > 90 ? 'bg-red-500' : usagePercent > 70 ? 'bg-yellow-500' : 'bg-green-500'}`} style={{ width: `${usagePercent}%` }} /></div><div className="flex justify-between text-sm"><span className="text-slate-400">باقی‌مانده</span><span className={data.data_remaining > 0 ? 'text-green-500' : 'text-red-500'}>{data.data_remaining > 0 ? formatBytes(data.data_remaining) : 'تمام شده'}</span></div><div className="flex justify-between text-sm mt-1"><span className="text-slate-400">کل حجم</span><span className="text-white">{formatBytes(data.data_limit)}</span></div></>) : <p className="text-green-500 text-center py-4">حجم نامحدود ♾️</p>}
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4"><div className="flex items-center gap-2 mb-2"><Download className="w-5 h-5 text-green-500" /><span className="text-slate-400 text-sm">دانلود</span></div><p className="text-white font-bold text-lg">{formatBytes(data.download)}</p></div>
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4"><div className="flex items-center gap-2 mb-2"><Upload className="w-5 h-5 text-blue-500" /><span className="text-slate-400 text-sm">آپلود</span></div><p className="text-white font-bold text-lg">{formatBytes(data.upload)}</p></div>
        </div>
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <h2 className="text-white font-semibold mb-4 flex items-center gap-2"><Clock className="w-5 h-5 text-blue-500" />اطلاعات زمانی</h2>
          {data.start_on_first_connect && !data.timer_started ? (<div className="text-center py-4"><div className="inline-flex items-center justify-center w-12 h-12 bg-yellow-500/20 rounded-full mb-2"><Clock className="w-6 h-6 text-yellow-500" /></div><p className="text-yellow-500 font-medium">در انتظار اولین اتصال</p><p className="text-slate-400 text-sm mt-1">پس از اولین اتصال، {data.expiry_days} روز اعتبار شروع می‌شود</p></div>) : (<div className="space-y-3">{data.expiry_date ? (<><div className="flex justify-between items-center"><span className="text-slate-400">تاریخ انقضا</span><span className="text-white">{formatDate(data.expiry_date)}</span></div><div className="flex justify-between items-center"><span className="text-slate-400">روز باقی‌مانده</span><span className={remainingDays > 0 ? 'text-green-500 font-bold' : 'text-red-500 font-bold'}>{remainingDays > 0 ? `${remainingDays} روز` : 'منقضی شده'}</span></div></>) : <p className="text-green-500 text-center py-4">بدون محدودیت زمانی ♾️</p>}{data.first_connection_at && <div className="flex justify-between items-center pt-2 border-t border-slate-700"><span className="text-slate-400">اولین اتصال</span><span className="text-white text-sm">{formatDate(data.first_connection_at)}</span></div>}</div>)}
        </div>
        {data.auto_renew && <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-2xl p-4"><div className="flex items-center gap-2 mb-2"><Zap className="w-5 h-5 text-yellow-500" /><span className="text-yellow-500 font-medium">تمدید خودکار فعال</span></div><p className="text-slate-400 text-sm">این اشتراک پس از اتمام حجم یا زمان، به صورت خودکار تمدید می‌شود.</p>{data.renew_count > 0 && <p className="text-slate-400 text-sm mt-1">تعداد تمدید: <span className="text-white">{data.renew_count} بار</span></p>}</div>}
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4"><div className="flex items-center justify-between"><div className="flex items-center gap-2"><Calendar className="w-5 h-5 text-slate-400" /><span className="text-slate-400">تاریخ ایجاد</span></div><span className="text-white">{formatDate(data.created_at)}</span></div></div>
        <button onClick={fetchData} className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 rounded-xl transition-colors flex items-center justify-center gap-2"><RefreshCw className="w-5 h-5" />بروزرسانی اطلاعات</button>
        <p className="text-center text-slate-500 text-sm">آخرین بروزرسانی: {new Date().toLocaleTimeString('fa-IR')}</p>
      </div>
    </div>
  );
};

export default Subscription;
SUBSCRIPTIONJS_EOF

    echo "Page components created successfully"
}

# Create Clients page inline (most important page)
create_clients_page() {
    cat > $INSTALL_DIR/frontend/src/pages/Clients.js << 'CLIENTSJS_EOF'
import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, Search, Download, QrCode, Edit, Trash2, Power, Shield, Wifi, WifiOff, MoreVertical, Clock, Database, RefreshCw, Zap, Filter, Link, Copy } from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import Modal from '../components/Modal';
import toast from 'react-hot-toast';

const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 Bytes';
  const k = 1024; const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

const formatDate = (dateString) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('fa-IR', { year: 'numeric', month: 'long', day: 'numeric' });
};

const formatDateForInput = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toISOString().split('T')[0];
};

const getStatusColor = (status) => {
  const colors = { active: 'bg-green-500', disabled: 'bg-gray-500', expired: 'bg-red-500', data_limit_reached: 'bg-orange-500' };
  return colors[status] || 'bg-gray-500';
};

const Clients = () => {
  const { t, i18n } = useTranslation();
  const { isAdmin } = useAuth();
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [showModal, setShowModal] = useState(false);
  const [showQRModal, setShowQRModal] = useState(false);
  const [selectedClient, setSelectedClient] = useState(null);
  const [qrImage, setQrImage] = useState(null);
  const [formData, setFormData] = useState({ name: '', email: '', data_limit: '', data_limit_unit: 'GB', expiry_days: '', expiry_date: '', start_on_first_connect: false, auto_renew: false, auto_renew_days: '', auto_renew_data_limit: '', auto_renew_data_unit: 'GB', note: '' });
  const [openMenu, setOpenMenu] = useState(null);
  const isRTL = i18n.language === 'fa';

  useEffect(() => { fetchClients(); }, []);

  const fetchClients = async () => {
    try { const response = await api.get('/clients'); setClients(response.data); } catch (error) { toast.error(t('common.error')); } finally { setLoading(false); }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = { name: formData.name, email: formData.email || null, data_limit: formData.data_limit ? parseFloat(formData.data_limit) * getUnitMultiplier(formData.data_limit_unit) : null, expiry_days: formData.expiry_days ? parseInt(formData.expiry_days) : null, expiry_date: (!formData.start_on_first_connect && formData.expiry_date) ? formData.expiry_date : null, start_on_first_connect: formData.start_on_first_connect, auto_renew: formData.auto_renew, auto_renew_days: formData.auto_renew_days ? parseInt(formData.auto_renew_days) : null, auto_renew_data_limit: formData.auto_renew_data_limit ? parseFloat(formData.auto_renew_data_limit) * getUnitMultiplier(formData.auto_renew_data_unit) : null, note: formData.note || null };
      if (selectedClient) { await api.put(`/clients/${selectedClient.id}`, data); toast.success(t('clients.updateSuccess')); }
      else { await api.post('/clients', data); toast.success(t('clients.createSuccess')); }
      setShowModal(false); resetForm(); fetchClients();
    } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleDelete = async (client) => {
    if (!window.confirm(t('clients.confirmDelete'))) return;
    try { await api.delete(`/clients/${client.id}`); toast.success(t('clients.deleteSuccess')); fetchClients(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleToggleStatus = async (client) => {
    try { await api.put(`/clients/${client.id}`, { is_enabled: !client.is_enabled }); toast.success(t('clients.updateSuccess')); fetchClients(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleResetData = async (client) => {
    try { await api.post(`/clients/${client.id}/reset-data`); toast.success(t('common.success')); fetchClients(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleResetExpiry = async (client, days = 30) => {
    try { await api.post(`/clients/${client.id}/reset-expiry?days=${days}`); toast.success(t('clients.expiryExtended')); fetchClients(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleFullReset = async (client) => {
    if (!window.confirm(t('clients.confirmFullReset'))) return;
    try { await api.post(`/clients/${client.id}/full-reset`); toast.success(t('clients.fullResetSuccess')); fetchClients(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleDownloadConfig = async (client) => {
    try { const response = await api.get(`/clients/${client.id}/config`, { responseType: 'blob' }); const url = window.URL.createObjectURL(new Blob([response.data])); const link = document.createElement('a'); link.href = url; link.setAttribute('download', `${client.name}.conf`); document.body.appendChild(link); link.click(); link.remove(); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleShowQR = async (client) => {
    try { const response = await api.get(`/clients/${client.id}/qrcode`, { responseType: 'blob' }); const url = window.URL.createObjectURL(new Blob([response.data])); setQrImage(url); setSelectedClient(client); setShowQRModal(true); } catch (error) { toast.error(error.response?.data?.detail || t('common.error')); }
  };

  const handleCopySubLink = (client) => { navigator.clipboard.writeText(`${window.location.origin}/sub/${client.id}`); toast.success(t('clients.subLinkCopied')); };

  const handleEdit = (client) => { setSelectedClient(client); setFormData({ name: client.name, email: client.email || '', data_limit: client.data_limit ? (client.data_limit / (1024 * 1024 * 1024)).toFixed(2) : '', data_limit_unit: 'GB', expiry_days: client.expiry_days || '', expiry_date: formatDateForInput(client.expiry_date), start_on_first_connect: client.start_on_first_connect || false, auto_renew: client.auto_renew || false, auto_renew_days: client.auto_renew_days || '', auto_renew_data_limit: client.auto_renew_data_limit ? (client.auto_renew_data_limit / (1024 * 1024 * 1024)).toFixed(2) : '', auto_renew_data_unit: 'GB', note: client.note || '' }); setShowModal(true); };
  const resetForm = () => { setSelectedClient(null); setFormData({ name: '', email: '', data_limit: '', data_limit_unit: 'GB', expiry_days: '', expiry_date: '', start_on_first_connect: false, auto_renew: false, auto_renew_days: '', auto_renew_data_limit: '', auto_renew_data_unit: 'GB', note: '' }); };
  const getUnitMultiplier = (unit) => { const units = { 'KB': 1024, 'MB': 1024 * 1024, 'GB': 1024 * 1024 * 1024, 'TB': 1024 * 1024 * 1024 * 1024 }; return units[unit] || 1; };
  const getStatusLabel = (status) => { const labels = { active: t('clients.active'), disabled: t('clients.disabled'), expired: t('clients.expired'), data_limit_reached: t('clients.dataLimitReached') }; return labels[status] || status; };

  const statusFilters = [{ value: 'all', label: t('clients.filterAll') }, { value: 'active', label: t('clients.active') }, { value: 'disabled', label: t('clients.disabled') }, { value: 'expired', label: t('clients.expired') }, { value: 'online', label: t('clients.online') }];
  const filteredClients = clients.filter(client => {
    const matchesSearch = client.name.toLowerCase().includes(searchQuery.toLowerCase()) || client.email?.toLowerCase().includes(searchQuery.toLowerCase()) || client.address?.includes(searchQuery);
    if (!matchesSearch) return false;
    if (statusFilter === 'all') return true;
    if (statusFilter === 'online') return client.is_online;
    return client.status === statusFilter;
  });

  if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div></div>;

  return (
    <div className="space-y-6 animate-fadeIn">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2"><Shield className="w-7 h-7 text-primary-500" />{t('clients.title')}</h1>
        {isAdmin() && <button onClick={() => { resetForm(); setShowModal(true); }} className="btn-primary flex items-center gap-2"><Plus className="w-5 h-5" />{t('clients.addNew')}</button>}
      </div>
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1"><Search className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} /><input type="text" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder={t('common.search')} className={`w-full bg-dark-card border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500`} /></div>
        <div className="relative"><Filter className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} /><select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className={`bg-dark-card border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-8' : 'pl-10 pr-8'} text-white focus:border-primary-500 appearance-none min-w-[180px]`}>{statusFilters.map(filter => <option key={filter.value} value={filter.value}>{filter.label}</option>)}</select></div>
      </div>
      <div className="flex items-center gap-2 text-dark-muted text-sm"><span>{t('clients.showing')}: {filteredClients.length} / {clients.length}</span></div>
      {filteredClients.length === 0 ? <div className="text-center py-12 text-dark-muted"><Shield className="w-16 h-16 mx-auto mb-4 opacity-50" /><p>{t('clients.noClients')}</p></div> : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filteredClients.map((client) => (
            <div key={client.id} className="bg-dark-card border border-dark-border rounded-xl p-4 card-hover relative">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-lg ${client.is_online ? 'bg-green-500/20' : 'bg-dark-border'}`}>{client.is_online ? <Wifi className="w-5 h-5 text-green-500" /> : <WifiOff className="w-5 h-5 text-dark-muted" />}</div>
                  <div><h3 className="font-semibold text-white">{client.name}</h3><p className="text-dark-muted text-sm">{client.address}</p></div>
                </div>
                <div className="relative">
                  <button onClick={() => setOpenMenu(openMenu === client.id ? null : client.id)} className="p-1 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"><MoreVertical className="w-5 h-5" /></button>
                  {openMenu === client.id && (
                    <div className={`absolute ${isRTL ? 'left-0' : 'right-0'} mt-2 w-48 bg-dark-card border border-dark-border rounded-lg shadow-xl z-10`}>
                      <button onClick={() => { handleDownloadConfig(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Download className="w-4 h-4" />{t('clients.downloadConfig')}</button>
                      <button onClick={() => { handleShowQR(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><QrCode className="w-4 h-4" />{t('clients.showQR')}</button>
                      <button onClick={() => { handleCopySubLink(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Link className="w-4 h-4" />{t('clients.copySubLink')}</button>
                      {isAdmin() && (<>
                        <div className="border-t border-dark-border my-1"></div>
                        <button onClick={() => { handleEdit(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Edit className="w-4 h-4" />{t('clients.edit')}</button>
                        <button onClick={() => { handleToggleStatus(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Power className="w-4 h-4" />{client.is_enabled ? t('clients.disable') : t('clients.enable')}</button>
                        <button onClick={() => { handleResetData(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Database className="w-4 h-4" />{t('clients.resetData')}</button>
                        <button onClick={() => { handleResetExpiry(client, 30); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"><Clock className="w-4 h-4" />{t('clients.extendExpiry')}</button>
                        <button onClick={() => { handleFullReset(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-yellow-400 hover:bg-yellow-500/10 transition-colors"><RefreshCw className="w-4 h-4" />{t('clients.fullReset')}</button>
                        <div className="border-t border-dark-border my-1"></div>
                        <button onClick={() => { handleDelete(client); setOpenMenu(null); }} className="w-full flex items-center gap-2 px-4 py-2 text-red-400 hover:bg-red-500/10 transition-colors"><Trash2 className="w-4 h-4" />{t('clients.delete')}</button>
                      </>)}
                    </div>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2 mb-4">
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(client.status)} bg-opacity-20 ${getStatusColor(client.status).replace('bg-', 'text-')}`}>{getStatusLabel(client.status)}</span>
                {client.is_online && <span className="px-2 py-1 rounded-full text-xs font-medium bg-green-500/20 text-green-500">{t('clients.online')}</span>}
              </div>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between"><span className="text-dark-muted">{t('clients.dataUsed')}:</span><span className="text-white">{formatBytes(client.data_used)}</span></div>
                <div className="flex justify-between"><span className="text-dark-muted">{t('clients.dataLimit')}:</span><span className="text-white">{client.data_limit ? formatBytes(client.data_limit) : t('clients.unlimited')}</span></div>
                <div className="flex justify-between"><span className="text-dark-muted">{t('clients.expiryDate')}:</span><span className="text-white">{client.expiry_date ? formatDate(client.expiry_date) : t('clients.never')}</span></div>
              </div>
              {client.data_limit && <div className="mt-4"><div className="w-full bg-dark-border rounded-full h-2"><div className={`h-2 rounded-full transition-all ${(client.data_used / client.data_limit) > 0.9 ? 'bg-red-500' : (client.data_used / client.data_limit) > 0.7 ? 'bg-yellow-500' : 'bg-green-500'}`} style={{ width: `${Math.min((client.data_used / client.data_limit) * 100, 100)}%` }} /></div></div>}
            </div>
          ))}
        </div>
      )}
      <Modal isOpen={showModal} onClose={() => { setShowModal(false); resetForm(); }} title={selectedClient ? t('clients.edit') : t('clients.addNew')}>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.name')} *</label><input type="text" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" required /></div>
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.email')}</label><input type="email" value={formData.email} onChange={(e) => setFormData({ ...formData, email: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" /></div>
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.dataLimit')}</label><div className="flex gap-2"><input type="number" value={formData.data_limit} onChange={(e) => setFormData({ ...formData, data_limit: e.target.value })} className="flex-1 bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" placeholder={t('clients.unlimited')} min="0" step="0.01" /><select value={formData.data_limit_unit} onChange={(e) => setFormData({ ...formData, data_limit_unit: e.target.value })} className="bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"><option value="MB">MB</option><option value="GB">GB</option><option value="TB">TB</option></select></div></div>
          <div className="border border-dark-border rounded-lg p-4 space-y-4">
            <h3 className="text-white font-medium flex items-center gap-2"><Clock className="w-4 h-4 text-primary-500" />{t('clients.timeSettings')}</h3>
            <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.expiryDays')}</label><input type="number" value={formData.expiry_days} onChange={(e) => setFormData({ ...formData, expiry_days: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" placeholder="30" min="1" /></div>
            <div className="flex items-center gap-2"><input type="checkbox" id="start_on_first_connect" checked={formData.start_on_first_connect} onChange={(e) => setFormData({ ...formData, start_on_first_connect: e.target.checked })} className="w-4 h-4 text-primary-600 bg-dark-bg border-dark-border rounded focus:ring-primary-500" /><label htmlFor="start_on_first_connect" className="text-dark-text text-sm">{t('clients.startOnFirstConnect')}</label></div>
            {!formData.start_on_first_connect && <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.expiryDate')}</label><input type="date" value={formData.expiry_date} onChange={(e) => setFormData({ ...formData, expiry_date: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" /></div>}
          </div>
          <div className="border border-dark-border rounded-lg p-4 space-y-4">
            <div className="flex items-center gap-2"><input type="checkbox" id="auto_renew" checked={formData.auto_renew} onChange={(e) => setFormData({ ...formData, auto_renew: e.target.checked })} className="w-4 h-4 text-primary-600 bg-dark-bg border-dark-border rounded focus:ring-primary-500" /><label htmlFor="auto_renew" className="text-white font-medium flex items-center gap-2"><Zap className="w-4 h-4 text-yellow-500" />{t('clients.autoRenew')}</label></div>
            {formData.auto_renew && (<><div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.autoRenewDays')}</label><input type="number" value={formData.auto_renew_days} onChange={(e) => setFormData({ ...formData, auto_renew_days: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" placeholder={t('clients.sameAsExpiry')} min="1" /></div><div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.autoRenewData')}</label><div className="flex gap-2"><input type="number" value={formData.auto_renew_data_limit} onChange={(e) => setFormData({ ...formData, auto_renew_data_limit: e.target.value })} className="flex-1 bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" placeholder={t('clients.sameAsDataLimit')} min="0" step="0.01" /><select value={formData.auto_renew_data_unit} onChange={(e) => setFormData({ ...formData, auto_renew_data_unit: e.target.value })} className="bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"><option value="MB">MB</option><option value="GB">GB</option><option value="TB">TB</option></select></div></div></>)}
          </div>
          <div><label className="block text-dark-text text-sm font-medium mb-2">{t('clients.note')}</label><textarea value={formData.note} onChange={(e) => setFormData({ ...formData, note: e.target.value })} className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white" rows="3" /></div>
          <div className="flex gap-3 pt-4"><button type="submit" className="btn-primary flex-1">{t('common.save')}</button><button type="button" onClick={() => { setShowModal(false); resetForm(); }} className="btn-secondary flex-1">{t('common.cancel')}</button></div>
        </form>
      </Modal>
      <Modal isOpen={showQRModal} onClose={() => { setShowQRModal(false); setQrImage(null); }} title={t('clients.qrTitle')} size="sm">
        <div className="text-center">{qrImage && <img src={qrImage} alt="QR Code" className="mx-auto mb-4 rounded-lg" />}<p className="text-dark-muted">{t('clients.scanQR')}</p><p className="text-white font-medium mt-2">{selectedClient?.name}</p></div>
      </Modal>
      {openMenu && <div className="fixed inset-0 z-0" onClick={() => setOpenMenu(null)} />}
    </div>
  );
};

export default Clients;
CLIENTSJS_EOF
}

# Create Layout component inline
create_layout_component() {
    echo "Creating Layout component..."
    
    cat > $INSTALL_DIR/frontend/src/components/Layout.js << 'LAYOUTJS_EOF'
import React, { useState } from 'react';
import { Outlet, Link, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { LayoutDashboard, Users, Shield, Settings, LogOut, Menu, X, Globe, ChevronDown } from 'lucide-react';

const Layout = () => {
  const { t, i18n } = useTranslation();
  const { user, logout, isSuperAdmin } = useAuth();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [langDropdown, setLangDropdown] = useState(false);
  const isRTL = i18n.language === 'fa';

  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: t('nav.dashboard') },
    { path: '/clients', icon: Shield, label: t('nav.clients') },
    ...(isSuperAdmin() ? [{ path: '/users', icon: Users, label: t('nav.users') }] : []),
    { path: '/settings', icon: Settings, label: t('nav.settings') },
  ];

  const changeLanguage = (lang) => { i18n.changeLanguage(lang); localStorage.setItem('language', lang); setLangDropdown(false); };
  const handleLogout = () => { logout(); };

  return (
    <div className="flex h-screen">
      {sidebarOpen && <div className="fixed inset-0 bg-black/50 z-40 lg:hidden" onClick={() => setSidebarOpen(false)} />}
      <aside className={`fixed lg:static inset-y-0 ${isRTL ? 'right-0' : 'left-0'} z-50 w-64 bg-dark-card border-${isRTL ? 'l' : 'r'} border-dark-border transform transition-transform duration-300 lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : isRTL ? 'translate-x-full' : '-translate-x-full'}`}>
        <div className="flex flex-col h-full">
          <div className="p-6 border-b border-dark-border">
            <h1 className="text-xl font-bold text-white flex items-center gap-2"><Shield className="w-8 h-8 text-primary-500" /><span className="gradient-text">{t('app.title')}</span></h1>
            <p className="text-dark-muted text-sm mt-1">{t('app.subtitle')}</p>
          </div>
          <nav className="flex-1 p-4 space-y-2">
            {menuItems.map((item) => {
              const Icon = item.icon;
              const isActive = location.pathname === item.path;
              return (
                <Link key={item.path} to={item.path} onClick={() => setSidebarOpen(false)} className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${isActive ? 'bg-primary-600 text-white' : 'text-dark-muted hover:bg-dark-border hover:text-white'}`}>
                  <Icon className="w-5 h-5" /><span>{item.label}</span>
                </Link>
              );
            })}
          </nav>
          <div className="p-4 border-t border-dark-border">
            <div className="flex items-center justify-between mb-4"><div><p className="text-white font-medium">{user?.username}</p><p className="text-dark-muted text-sm capitalize">{user?.role?.replace('_', ' ')}</p></div></div>
            <button onClick={handleLogout} className="flex items-center gap-2 w-full px-4 py-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"><LogOut className="w-5 h-5" /><span>{t('nav.logout')}</span></button>
          </div>
        </div>
      </aside>
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-dark-card border-b border-dark-border px-4 lg:px-6 py-4">
          <div className="flex items-center justify-between">
            <button onClick={() => setSidebarOpen(!sidebarOpen)} className="lg:hidden text-dark-text hover:text-white">{sidebarOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}</button>
            <div className="relative mr-auto lg:mr-0">
              <button onClick={() => setLangDropdown(!langDropdown)} className="flex items-center gap-2 px-3 py-2 bg-dark-border rounded-lg text-dark-text hover:text-white transition-colors"><Globe className="w-5 h-5" /><span>{i18n.language === 'fa' ? 'فارسی' : 'English'}</span><ChevronDown className="w-4 h-4" /></button>
              {langDropdown && (
                <div className={`absolute ${isRTL ? 'left-0' : 'right-0'} mt-2 w-32 bg-dark-card border border-dark-border rounded-lg shadow-xl z-50`}>
                  <button onClick={() => changeLanguage('fa')} className={`w-full px-4 py-2 text-right hover:bg-dark-border transition-colors ${i18n.language === 'fa' ? 'text-primary-500' : 'text-dark-text'}`}>فارسی</button>
                  <button onClick={() => changeLanguage('en')} className={`w-full px-4 py-2 text-right hover:bg-dark-border transition-colors ${i18n.language === 'en' ? 'text-primary-500' : 'text-dark-text'}`}>English</button>
                </div>
              )}
            </div>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-4 lg:p-6"><Outlet /></main>
      </div>
    </div>
  );
};

export default Layout;
LAYOUTJS_EOF

    echo "Layout component created"
}

# Create Docker files
create_docker_files() {
    print_info "Creating Docker configuration files..."

    # nginx.conf
    cat > $INSTALL_DIR/nginx.conf << 'NGINX_EOF'
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
NGINX_EOF

    # docker-compose.yml - Using direct values instead of variables
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
      - JWT_SECRET=$JWT_SECRET
      - WG_INTERFACE=$WG_INTERFACE
      - WG_PORT=$WG_PORT
      - WG_NETWORK=$WG_NETWORK
      - WG_DNS=1.1.1.1,8.8.8.8
      - WG_ENDPOINT=$SERVER_IP
      - DEFAULT_ENDPOINT=$SERVER_IP
      - SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
      - SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
      - PANEL_USERNAME=$PANEL_USERNAME
      - PANEL_PASSWORD=$PANEL_PASSWORD
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
      - "$PANEL_PORT:80"
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

    # Also create a .env file for docker-compose
    cat > $INSTALL_DIR/.docker.env << EOF
JWT_SECRET=$JWT_SECRET
PANEL_USERNAME=$PANEL_USERNAME
PANEL_PASSWORD=$PANEL_PASSWORD
PANEL_PORT=$PANEL_PORT
WG_INTERFACE=$WG_INTERFACE
WG_PORT=$WG_PORT
WG_NETWORK=$WG_NETWORK
SERVER_IP=$SERVER_IP
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
SERVER_PRIVATE_KEY=$SERVER_PRIVATE_KEY
EOF

    print_info "Docker compose created with:"
    print_info "  Username: $PANEL_USERNAME"
    print_info "  Port: $PANEL_PORT"

    # Dockerfile.backend
    cat > $INSTALL_DIR/Dockerfile.backend << 'BACKEND_DOCKERFILE_EOF'
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
BACKEND_DOCKERFILE_EOF

    # Dockerfile.frontend
    cat > $INSTALL_DIR/Dockerfile.frontend << 'FRONTEND_DOCKERFILE_EOF'
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
FRONTEND_DOCKERFILE_EOF

    print_success "Docker files created"
}

# Configure firewall
configure_firewall() {
    print_info "Configuring firewall / پیکربندی فایروال..."

    if command -v ufw &> /dev/null; then
        ufw allow $WG_PORT/udp
        ufw allow $PANEL_PORT/tcp
        print_success "UFW rules added"
    fi

    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$WG_PORT/udp
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp
        firewall-cmd --reload
        print_success "Firewalld rules added"
    fi
}

# Start the panel
start_panel() {
    print_info "Building and starting containers / ساخت و اجرای کانتینرها..."

    cd $INSTALL_DIR
    docker compose up -d --build

    print_info "Waiting for services to start / در انتظار راه‌اندازی سرویس‌ها..."
    sleep 15

    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel is running! / پنل در حال اجراست!"
    else
        print_error "Failed to start panel. Check logs with: docker compose logs"
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
    
    echo -e "${CYAN}Panel URL / آدرس پنل:${NC} http://$SERVER_IP:$PANEL_PORT"
    echo ""
    echo -e "${CYAN}Login Information / اطلاعات ورود:${NC}"
    echo -e "   Username / نام کاربری: ${YELLOW}$PANEL_USERNAME${NC}"
    echo -e "   Password / رمز عبور: ${YELLOW}$PANEL_PASSWORD${NC}"
    echo ""
    echo -e "${CYAN}WireGuard Endpoint:${NC} $SERVER_IP:$WG_PORT"
    echo ""
    echo -e "${CYAN}Management Commands / دستورات مدیریت:${NC}"
    echo -e "   Start:     ${YELLOW}cd $INSTALL_DIR && docker compose up -d${NC}"
    echo -e "   Stop:      ${YELLOW}cd $INSTALL_DIR && docker compose down${NC}"
    echo -e "   Restart:   ${YELLOW}cd $INSTALL_DIR && docker compose restart${NC}"
    echo -e "   Logs:      ${YELLOW}cd $INSTALL_DIR && docker compose logs -f${NC}"
    echo -e "   Update:    ${YELLOW}cd $INSTALL_DIR && docker compose up -d --build${NC}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Please change the default password after first login!${NC}"
    echo -e "${RED}⚠️  مهم: لطفاً رمز عبور را بعد از اولین ورود تغییر دهید!${NC}"
    echo ""
}

# Main installation function
main() {
    print_banner
    check_root
    detect_os
    ask_user_config

    echo ""
    print_info "Starting installation... / شروع نصب..."
    echo ""

    print_info "Step 1/7: Installing prerequisites / نصب پیش‌نیازها..."
    install_prerequisites

    print_info "Step 2/7: Installing Docker / نصب داکر..."
    install_docker

    print_info "Step 3/7: Installing WireGuard / نصب وایرگارد..."
    install_wireguard

    print_info "Step 4/7: Setting up WireGuard interface / راه‌اندازی اینترفیس وایرگارد..."
    setup_wireguard

    print_info "Step 5/7: Creating project files / ایجاد فایل‌های پروژه..."
    create_project_files

    print_info "Step 6/7: Configuring firewall / پیکربندی فایروال..."
    configure_firewall

    print_info "Step 7/7: Starting panel / شروع پنل..."
    start_panel

    print_complete
}

# Run main function
main "$@"
