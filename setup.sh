#!/bin/bash

# ===========================================
# WireGuard Panel Manager v4.0
# ===========================================

# Don't exit on error - handle errors manually
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
SCRIPT_VERSION="4.0"

PANEL_USERNAME="admin"
PANEL_PASSWORD="admin"
PANEL_PORT="80"

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
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    echo "$SERVER_IP"
}

is_installed() {
    [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]
}

show_menu() {
    print_banner
    echo ""
    if is_installed; then
        echo -e "  ${GREEN}●${NC} Panel: ${GREEN}Installed / نصب شده${NC}"
    else
        echo -e "  ${RED}●${NC} Panel: ${RED}Not Installed / نصب نشده${NC}"
    fi
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}1)${NC} Install Panel          ${CYAN}نصب پنل${NC}"
    echo -e "  ${GREEN}2)${NC} Start Panel            ${GREEN}شروع پنل${NC}"
    echo -e "  ${YELLOW}3)${NC} Stop Panel             ${YELLOW}توقف پنل${NC}"
    echo -e "  ${BLUE}4)${NC} Restart Panel          ${BLUE}ری‌استارت پنل${NC}"
    echo -e "  ${PURPLE}5)${NC} Update Panel           ${PURPLE}آپدیت (بدون حذف دیتا)${NC}"
    echo -e "  ${WHITE}6)${NC} View Logs              ${WHITE}مشاهده لاگ‌ها${NC}"
    echo -e "  ${WHITE}7)${NC} Panel Status           ${WHITE}وضعیت پنل${NC}"
    echo -e "  ${RED}8)${NC} Uninstall Panel        ${RED}حذف کامل${NC}"
    echo -e "  ${NC}0)${NC} Exit                   ${NC}خروج${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_panel_info() {
    SERVER_IP=$(get_server_ip)
    CURRENT_PORT=$(grep -oP '^\s*-\s*"\K[0-9]+(?=:80")' $INSTALL_DIR/docker-compose.yml 2>/dev/null || echo "80")
    echo ""
    echo -e "  Panel URL: ${GREEN}http://$SERVER_IP:$CURRENT_PORT${NC}"
    echo ""
}

start_panel_service() {
    if ! is_installed; then
        print_error "Panel not installed! / پنل نصب نشده!"
        return 1
    fi
    print_info "Starting panel..."
    cd $INSTALL_DIR && docker compose up -d
    sleep 3
    docker ps | grep -q wireguard-panel && print_success "Panel started!" && show_panel_info || print_error "Failed to start"
}

stop_panel_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    print_info "Stopping panel..."
    cd $INSTALL_DIR && docker compose down
    print_success "Panel stopped!"
}

restart_panel_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    print_info "Restarting panel..."
    cd $INSTALL_DIR && docker compose restart
    sleep 3
    print_success "Panel restarted!"
    show_panel_info
}

update_panel_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    print_warning "This will update without removing data."
    echo -e "${YELLOW}Press Enter to continue or 'n' to cancel${NC}"
    read -r REPLY
    [[ "$REPLY" =~ ^[Nn]$ ]] && return 0
    print_info "Updating panel..."
    cd $INSTALL_DIR
    docker compose down
    docker compose up -d --build
    sleep 5
    print_success "Panel updated!"
    show_panel_info
}

view_logs_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    print_info "Showing logs (Ctrl+C to exit)..."
    cd $INSTALL_DIR && docker compose logs -f --tail=100
}

panel_status_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    cd $INSTALL_DIR && docker compose ps
    show_panel_info
}

uninstall_panel_service() {
    if ! is_installed; then print_error "Panel not installed!"; return 1; fi
    print_warning "This will DELETE all data!"
    echo -e "${RED}Type 'DELETE' to confirm:${NC}"
    read -r CONFIRM
    [ "$CONFIRM" != "DELETE" ] && print_info "Cancelled." && return 0
    cd $INSTALL_DIR
    docker compose down -v --remove-orphans 2>/dev/null || true
    docker rmi wireguard-panel-frontend wireguard-panel-backend 2>/dev/null || true
    rm -rf $INSTALL_DIR
    print_success "Panel uninstalled!"
}

# ============================================
# INSTALLATION FUNCTIONS
# ============================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

wait_for_apt() {
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        print_warning "Waiting for apt..."
        sleep 5
    done
}

ask_user_config() {
    echo ""
    echo -e "${CYAN}Panel Configuration / تنظیمات پنل${NC}"
    echo ""
    
    echo -e "${YELLOW}Admin username / نام کاربری:${NC}"
    read -r -p "Username [admin]: " input_username
    if [ -n "$input_username" ]; then
        PANEL_USERNAME="$input_username"
    fi
    
    echo -e "${YELLOW}Admin password / رمز عبور:${NC}"
    read -r -p "Password [admin]: " input_password
    if [ -n "$input_password" ]; then
        PANEL_PASSWORD="$input_password"
    fi
    
    echo -e "${YELLOW}Panel port / پورت پنل:${NC}"
    read -r -p "Port [80]: " input_port
    if [ -n "$input_port" ]; then
        PANEL_PORT="$input_port"
    fi
    
    SERVER_IP=$(get_server_ip)
    echo ""
    echo -e "  Server IP: ${GREEN}$SERVER_IP${NC}"
    echo -e "  Port: ${GREEN}$PANEL_PORT${NC}"
    echo -e "  Username: ${GREEN}$PANEL_USERNAME${NC}"
    echo ""
    
    echo -e "${YELLOW}Press Enter to continue or 'n' to cancel${NC}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled."
        return 1
    fi
    return 0
}

install_prerequisites() {
    print_info "Installing prerequisites..."
    wait_for_apt
    case $OS in
        ubuntu|debian)
            apt-get update -y
            apt-get install -y curl wget ca-certificates gnupg openssl
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget ca-certificates openssl
            ;;
    esac
    print_success "Prerequisites installed"
}

install_docker() {
    if command -v docker &>/dev/null; then
        print_success "Docker already installed"
        return
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
        wait_for_apt
        case $OS in
            ubuntu|debian) apt-get install -y wireguard wireguard-tools ;;
            centos|rhel|rocky|almalinux) yum install -y epel-release && yum install -y wireguard-tools ;;
        esac
        print_success "WireGuard installed"
    fi
    
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf
}

setup_wireguard() {
    print_info "Setting up WireGuard..."
    
    if [ -f "/etc/wireguard/$WG_INTERFACE.conf" ]; then
        SERVER_PRIVATE_KEY=$(grep "PrivateKey" /etc/wireguard/$WG_INTERFACE.conf | cut -d'=' -f2 | tr -d ' ')
        SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
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
    fi
    
    wg show $WG_INTERFACE &>/dev/null || wg-quick up $WG_INTERFACE
    systemctl enable wg-quick@$WG_INTERFACE 2>/dev/null || true
    print_success "WireGuard ready"
}

create_project_files() {
    print_info "Creating project files..."
    
    mkdir -p $INSTALL_DIR/{backend,frontend/src/{pages,components,contexts,utils,i18n/locales},frontend/public}
    
    JWT_SECRET=$(openssl rand -hex 32)
    SERVER_IP=$(get_server_ip)
    
    # Create .env
    cat > $INSTALL_DIR/.env << EOF
JWT_SECRET=$JWT_SECRET
PANEL_PORT=$PANEL_PORT
PANEL_USERNAME=$PANEL_USERNAME
PANEL_PASSWORD=$PANEL_PASSWORD
WG_ENDPOINT=$SERVER_IP
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
aiofiles==23.2.1
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

# Models
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

# Auth
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()
SECRET_KEY = os.environ.get("JWT_SECRET", "secret")
ALGORITHM = "HS256"

def verify_password(plain, hashed): return pwd_context.verify(plain, hashed)
def get_password_hash(password): return pwd_context.hash(password)
def create_access_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(hours=24)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# WireGuard
def wg_genkey():
    try:
        priv = subprocess.run(["wg", "genkey"], capture_output=True, text=True).stdout.strip()
        pub = subprocess.run(["wg", "pubkey"], input=priv, capture_output=True, text=True).stdout.strip()
        return priv, pub
    except: 
        import secrets, base64
        return base64.b64encode(secrets.token_bytes(32)).decode(), base64.b64encode(secrets.token_bytes(32)).decode()

def wg_genpsk():
    try: return subprocess.run(["wg", "genpsk"], capture_output=True, text=True).stdout.strip()
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
    except: pass

def remove_peer(pub_key):
    try:
        subprocess.run(["wg", "set", "wg0", "peer", pub_key, "remove"], check=True)
        subprocess.run(["wg-quick", "save", "wg0"], check=False)
    except: pass

def get_wg_stats():
    try:
        result = subprocess.run(["wg", "show", "wg0", "dump"], capture_output=True, text=True)
        stats = {}
        for line in result.stdout.strip().split("\n")[1:]:
            parts = line.split("\t")
            if len(parts) >= 8:
                stats[parts[0]] = {"rx": int(parts[5]), "tx": int(parts[6]), "handshake": int(parts[4]) if parts[4] != "0" else None}
        return stats
    except: return {}

# App
@asynccontextmanager
async def lifespan(app: FastAPI):
    init_admin()
    init_settings()
    yield

app = FastAPI(lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
client = MongoClient(MONGO_URL)
db = client["wireguard_panel"]
users_col = db["users"]
clients_col = db["clients"]
settings_col = db["settings"]

def init_admin():
    if users_col.count_documents({"role": "super_admin"}) == 0:
        users_col.insert_one({
            "id": str(uuid.uuid4()),
            "username": os.environ.get("PANEL_USERNAME", "admin"),
            "hashed_password": get_password_hash(os.environ.get("PANEL_PASSWORD", "admin")),
            "role": "super_admin",
            "is_active": True,
            "created_at": datetime.utcnow()
        })

def init_settings():
    if settings_col.count_documents({"id": "server_settings"}) == 0:
        priv, pub = wg_genkey()
        settings_col.insert_one({
            "id": "server_settings",
            "server_name": "WireGuard Panel",
            "wg_port": int(os.environ.get("WG_PORT", "51820")),
            "wg_network": os.environ.get("WG_NETWORK", "10.0.0.0/24"),
            "wg_dns": "1.1.1.1,8.8.8.8",
            "server_public_key": os.environ.get("SERVER_PUBLIC_KEY", pub),
            "server_private_key": os.environ.get("SERVER_PRIVATE_KEY", priv),
            "endpoint": os.environ.get("WG_ENDPOINT", ""),
            "mtu": 1420,
            "persistent_keepalive": 25
        })

@app.post("/api/auth/login", response_model=Token)
async def login(req: LoginRequest):
    user = users_col.find_one({"username": req.username})
    if not user or not verify_password(req.password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return Token(access_token=create_access_token({"user_id": user["id"], "username": user["username"], "role": user["role"]}))

@app.get("/api/auth/me")
async def get_me(user=Depends(get_current_user)):
    u = users_col.find_one({"id": user["user_id"]})
    return {"id": u["id"], "username": u["username"], "role": u["role"]}

@app.get("/api/clients")
async def get_clients(user=Depends(get_current_user)):
    clients = list(clients_col.find({}, {"_id": 0}))
    stats = get_wg_stats()
    for c in clients:
        if c["public_key"] in stats:
            s = stats[c["public_key"]]
            c["data_used"] = s["rx"] + s["tx"]
            c["is_online"] = s["handshake"] and (datetime.now().timestamp() - s["handshake"]) < 180
        else:
            c["data_used"] = 0
            c["is_online"] = False
    return clients

@app.post("/api/clients")
async def create_client(client: ClientCreate, user=Depends(get_current_user)):
    settings = settings_col.find_one({"id": "server_settings"})
    if not settings.get("endpoint"):
        raise HTTPException(status_code=400, detail="Set server endpoint in settings first")
    
    priv, pub = wg_genkey()
    psk = wg_genpsk()
    used = [c["address"].split("/")[0] for c in clients_col.find({}, {"address": 1})]
    used.append("10.0.0.1")
    address = get_next_ip(settings["wg_network"], used)
    
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
        "expiry_date": datetime.utcnow() + timedelta(days=client.expiry_days) if client.expiry_days else None,
        "is_enabled": True,
        "status": "active",
        "data_used": 0,
        "created_at": datetime.utcnow()
    }
    
    add_peer(pub, psk, address)
    clients_col.insert_one(new_client)
    new_client["created_at"] = new_client["created_at"].isoformat()
    if new_client.get("expiry_date"): new_client["expiry_date"] = new_client["expiry_date"].isoformat()
    return new_client

@app.delete("/api/clients/{client_id}")
async def delete_client(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    if not client: raise HTTPException(status_code=404, detail="Not found")
    remove_peer(client["public_key"])
    clients_col.delete_one({"id": client_id})
    return {"message": "Deleted"}

@app.get("/api/clients/{client_id}/config")
async def get_config(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    settings = settings_col.find_one({"id": "server_settings"})
    if not client: raise HTTPException(status_code=404)
    
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
    return Response(content=config, media_type="text/plain", headers={"Content-Disposition": f"attachment; filename={client['name']}.conf"})

@app.get("/api/clients/{client_id}/qrcode")
async def get_qr(client_id: str, user=Depends(get_current_user)):
    client = clients_col.find_one({"id": client_id})
    settings = settings_col.find_one({"id": "server_settings"})
    if not client: raise HTTPException(status_code=404)
    
    config = f"[Interface]\nPrivateKey = {client['private_key']}\nAddress = {client['address']}\nDNS = {settings['wg_dns']}\n\n[Peer]\nPublicKey = {settings['server_public_key']}\nPresharedKey = {client['preshared_key']}\nEndpoint = {settings['endpoint']}:{settings['wg_port']}\nAllowedIPs = 0.0.0.0/0, ::/0\nPersistentKeepalive = {settings['persistent_keepalive']}"
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(config)
    qr.make(fit=True)
    img = qr.make_image()
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return StreamingResponse(buf, media_type="image/png")

@app.get("/api/settings")
async def get_settings(user=Depends(get_current_user)):
    s = settings_col.find_one({"id": "server_settings"}, {"_id": 0, "server_private_key": 0})
    return s

@app.put("/api/settings")
async def update_settings(data: dict, user=Depends(get_current_user)):
    allowed = ["server_name", "endpoint", "wg_port", "wg_dns", "mtu", "persistent_keepalive"]
    update = {k: v for k, v in data.items() if k in allowed}
    if update: settings_col.update_one({"id": "server_settings"}, {"$set": update})
    return settings_col.find_one({"id": "server_settings"}, {"_id": 0, "server_private_key": 0})

@app.get("/api/dashboard/stats")
async def get_stats(user=Depends(get_current_user)):
    clients = list(clients_col.find({}))
    stats = get_wg_stats()
    total = len(clients)
    active = sum(1 for c in clients if c.get("is_enabled", True))
    online = sum(1 for c in clients if c["public_key"] in stats and stats[c["public_key"]].get("handshake"))
    data = sum(stats[c["public_key"]]["rx"] + stats[c["public_key"]]["tx"] for c in clients if c["public_key"] in stats)
    return {"total_clients": total, "active_clients": active, "online_clients": online, "total_data_used": data}

@app.get("/api/dashboard/system")
async def get_system(user=Depends(get_current_user)):
    wg_installed = subprocess.run(["which", "wg"], capture_output=True).returncode == 0
    wg_up = subprocess.run(["wg", "show", "wg0"], capture_output=True).returncode == 0
    return {"wireguard_installed": wg_installed, "interface_up": wg_up}

@app.get("/api/health")
async def health():
    return {"status": "ok"}

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
    "qrcode.react": "^3.1.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "browserslist": {"production": [">0.2%"], "development": ["last 1 chrome version"]},
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
        dark: { bg: '#0f172a', card: '#1e293b', border: '#334155', text: '#e2e8f0', muted: '#94a3b8' }
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
<html lang="fa" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;600;700&display=swap" rel="stylesheet">
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
body { font-family: 'Vazirmatn', sans-serif; margin: 0; }
EOF

    # src/index.js
    cat > $INSTALL_DIR/frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
ReactDOM.createRoot(document.getElementById('root')).render(<App />);
EOF

    # src/App.js
    cat > $INSTALL_DIR/frontend/src/App.js << 'APPEOF'
import React, { useState, useEffect, createContext, useContext } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Link, useNavigate, useLocation } from 'react-router-dom';
import { Toaster, toast } from 'react-hot-toast';
import { Shield, Users, Settings, LogOut, Menu, X, Plus, Download, Trash2, QrCode, Wifi, WifiOff, LayoutDashboard, User, Lock } from 'lucide-react';
import axios from 'axios';

const API = axios.create({ baseURL: process.env.REACT_APP_BACKEND_URL || '/api' });
API.interceptors.request.use(cfg => { const t = localStorage.getItem('token'); if (t) cfg.headers.Authorization = `Bearer ${t}`; return cfg; });
API.interceptors.response.use(r => r, e => { if (e.response?.status === 401) { localStorage.removeItem('token'); window.location.href = '/login'; } return Promise.reject(e); });

const AuthContext = createContext(null);
const useAuth = () => useContext(AuthContext);

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) API.get('/auth/me').then(r => setUser(r.data)).catch(() => localStorage.removeItem('token')).finally(() => setLoading(false));
    else setLoading(false);
  }, []);
  
  const login = async (username, password) => {
    const r = await API.post('/auth/login', { username, password });
    localStorage.setItem('token', r.data.access_token);
    const u = await API.get('/auth/me');
    setUser(u.data);
  };
  
  const logout = () => { localStorage.removeItem('token'); setUser(null); };
  
  return <AuthContext.Provider value={{ user, login, logout, loading }}>{children}</AuthContext.Provider>;
};

const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return <div className="min-h-screen bg-dark-bg flex items-center justify-center"><div className="animate-spin h-12 w-12 border-t-2 border-blue-500 rounded-full"></div></div>;
  return user ? children : <Navigate to="/login" />;
};

const Login = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const nav = useNavigate();
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try { await login(username, password); nav('/'); } catch { toast.error('نام کاربری یا رمز عبور اشتباه است'); }
    finally { setLoading(false); }
  };
  
  return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-20 h-20 bg-blue-600/20 rounded-full flex items-center justify-center mx-auto mb-4"><Shield className="w-10 h-10 text-blue-500" /></div>
          <h1 className="text-3xl font-bold text-white">WireGuard Panel</h1>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="text-dark-text text-sm mb-2 block">نام کاربری</label>
              <div className="relative">
                <User className="absolute right-3 top-3 w-5 h-5 text-dark-muted" />
                <input type="text" value={username} onChange={e => setUsername(e.target.value)} className="w-full bg-dark-bg border border-dark-border rounded-lg py-3 pr-10 pl-4 text-white" required />
              </div>
            </div>
            <div>
              <label className="text-dark-text text-sm mb-2 block">رمز عبور</label>
              <div className="relative">
                <Lock className="absolute right-3 top-3 w-5 h-5 text-dark-muted" />
                <input type="password" value={password} onChange={e => setPassword(e.target.value)} className="w-full bg-dark-bg border border-dark-border rounded-lg py-3 pr-10 pl-4 text-white" required />
              </div>
            </div>
            <button type="submit" disabled={loading} className="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg disabled:opacity-50">
              {loading ? 'در حال ورود...' : 'ورود'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

const Layout = ({ children }) => {
  const { user, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();
  
  const menu = [
    { path: '/', icon: LayoutDashboard, label: 'داشبورد' },
    { path: '/clients', icon: Users, label: 'کلاینت‌ها' },
    { path: '/settings', icon: Settings, label: 'تنظیمات' },
  ];
  
  return (
    <div className="flex h-screen bg-dark-bg">
      {sidebarOpen && <div className="fixed inset-0 bg-black/50 z-40 lg:hidden" onClick={() => setSidebarOpen(false)} />}
      <aside className={`fixed lg:static inset-y-0 right-0 z-50 w-64 bg-dark-card border-l border-dark-border transform transition-transform lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="p-6 border-b border-dark-border">
          <h1 className="text-xl font-bold text-white flex items-center gap-2"><Shield className="w-8 h-8 text-blue-500" />WireGuard</h1>
        </div>
        <nav className="p-4 space-y-2">
          {menu.map(item => (
            <Link key={item.path} to={item.path} onClick={() => setSidebarOpen(false)} className={`flex items-center gap-3 px-4 py-3 rounded-lg ${location.pathname === item.path ? 'bg-blue-600 text-white' : 'text-dark-muted hover:bg-dark-border'}`}>
              <item.icon className="w-5 h-5" />{item.label}
            </Link>
          ))}
        </nav>
        <div className="absolute bottom-0 w-full p-4 border-t border-dark-border">
          <p className="text-white mb-2">{user?.username}</p>
          <button onClick={logout} className="flex items-center gap-2 text-red-400 hover:bg-red-500/10 px-4 py-2 rounded-lg w-full"><LogOut className="w-5 h-5" />خروج</button>
        </div>
      </aside>
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-dark-card border-b border-dark-border px-4 py-4 lg:hidden">
          <button onClick={() => setSidebarOpen(!sidebarOpen)}>{sidebarOpen ? <X className="w-6 h-6 text-white" /> : <Menu className="w-6 h-6 text-white" />}</button>
        </header>
        <main className="flex-1 overflow-auto p-4 lg:p-6">{children}</main>
      </div>
    </div>
  );
};

const Dashboard = () => {
  const [stats, setStats] = useState({});
  useEffect(() => { API.get('/dashboard/stats').then(r => setStats(r.data)); }, []);
  const formatBytes = b => b ? (b / 1024 / 1024 / 1024).toFixed(2) + ' GB' : '0 GB';
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">داشبورد</h1>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <p className="text-dark-muted text-sm">کل کلاینت‌ها</p>
          <p className="text-2xl font-bold text-white">{stats.total_clients || 0}</p>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <p className="text-dark-muted text-sm">کلاینت‌های فعال</p>
          <p className="text-2xl font-bold text-green-500">{stats.active_clients || 0}</p>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <p className="text-dark-muted text-sm">آنلاین</p>
          <p className="text-2xl font-bold text-blue-500">{stats.online_clients || 0}</p>
        </div>
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <p className="text-dark-muted text-sm">کل مصرف</p>
          <p className="text-2xl font-bold text-purple-500">{formatBytes(stats.total_data_used)}</p>
        </div>
      </div>
    </div>
  );
};

const Clients = () => {
  const [clients, setClients] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [showQR, setShowQR] = useState(null);
  const [name, setName] = useState('');
  const [qrImg, setQrImg] = useState('');
  
  const load = () => API.get('/clients').then(r => setClients(r.data));
  useEffect(() => { load(); }, []);
  
  const addClient = async () => {
    if (!name) return;
    try { await API.post('/clients', { name }); toast.success('کلاینت ایجاد شد'); setShowAdd(false); setName(''); load(); }
    catch (e) { toast.error(e.response?.data?.detail || 'خطا'); }
  };
  
  const deleteClient = async (id) => {
    if (!window.confirm('حذف شود؟')) return;
    await API.delete(`/clients/${id}`);
    toast.success('حذف شد');
    load();
  };
  
  const downloadConfig = async (c) => {
    const r = await API.get(`/clients/${c.id}/config`, { responseType: 'blob' });
    const url = URL.createObjectURL(r.data);
    const a = document.createElement('a');
    a.href = url; a.download = `${c.name}.conf`; a.click();
  };
  
  const showQRCode = async (c) => {
    const r = await API.get(`/clients/${c.id}/qrcode`, { responseType: 'blob' });
    setQrImg(URL.createObjectURL(r.data));
    setShowQR(c);
  };
  
  const formatBytes = b => b ? (b / 1024 / 1024).toFixed(2) + ' MB' : '0';
  
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-white">کلاینت‌ها</h1>
        <button onClick={() => setShowAdd(true)} className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg flex items-center gap-2"><Plus className="w-5 h-5" />افزودن</button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {clients.map(c => (
          <div key={c.id} className="bg-dark-card border border-dark-border rounded-xl p-4">
            <div className="flex justify-between items-start mb-4">
              <div className="flex items-center gap-3">
                {c.is_online ? <Wifi className="w-5 h-5 text-green-500" /> : <WifiOff className="w-5 h-5 text-dark-muted" />}
                <div>
                  <h3 className="font-semibold text-white">{c.name}</h3>
                  <p className="text-dark-muted text-sm">{c.address}</p>
                </div>
              </div>
            </div>
            <div className="text-sm text-dark-muted mb-4">مصرف: {formatBytes(c.data_used)}</div>
            <div className="flex gap-2">
              <button onClick={() => downloadConfig(c)} className="p-2 hover:bg-dark-border rounded-lg"><Download className="w-4 h-4 text-dark-muted" /></button>
              <button onClick={() => showQRCode(c)} className="p-2 hover:bg-dark-border rounded-lg"><QrCode className="w-4 h-4 text-dark-muted" /></button>
              <button onClick={() => deleteClient(c.id)} className="p-2 hover:bg-red-500/10 rounded-lg"><Trash2 className="w-4 h-4 text-red-400" /></button>
            </div>
          </div>
        ))}
      </div>
      
      {showAdd && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4">
          <div className="bg-dark-card border border-dark-border rounded-xl p-6 w-full max-w-md">
            <h2 className="text-lg font-semibold text-white mb-4">افزودن کلاینت</h2>
            <input value={name} onChange={e => setName(e.target.value)} placeholder="نام کلاینت" className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white mb-4" />
            <div className="flex gap-3">
              <button onClick={addClient} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg">ذخیره</button>
              <button onClick={() => setShowAdd(false)} className="flex-1 bg-dark-border text-white py-2 rounded-lg">انصراف</button>
            </div>
          </div>
        </div>
      )}
      
      {showQR && (
        <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50 p-4" onClick={() => setShowQR(null)}>
          <div className="bg-dark-card border border-dark-border rounded-xl p-6 text-center" onClick={e => e.stopPropagation()}>
            <img src={qrImg} alt="QR" className="mx-auto mb-4" />
            <p className="text-white">{showQR.name}</p>
          </div>
        </div>
      )}
    </div>
  );
};

const SettingsPage = () => {
  const [settings, setSettings] = useState({});
  const [endpoint, setEndpoint] = useState('');
  
  useEffect(() => { API.get('/settings').then(r => { setSettings(r.data); setEndpoint(r.data.endpoint || ''); }); }, []);
  
  const save = async () => {
    await API.put('/settings', { endpoint });
    toast.success('ذخیره شد');
  };
  
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-white">تنظیمات</h1>
      <div className="bg-dark-card border border-dark-border rounded-xl p-6">
        <label className="text-dark-text text-sm mb-2 block">آدرس سرور (IP یا دامنه) *</label>
        <input value={endpoint} onChange={e => setEndpoint(e.target.value)} placeholder="example.com" className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white mb-4" />
        <p className="text-dark-muted text-sm mb-4">کلید عمومی: {settings.server_public_key}</p>
        <button onClick={save} className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg">ذخیره</button>
      </div>
    </div>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<ProtectedRoute><Layout><Dashboard /></Layout></ProtectedRoute>} />
          <Route path="/clients" element={<ProtectedRoute><Layout><Clients /></Layout></ProtectedRoute>} />
          <Route path="/settings" element={<ProtectedRoute><Layout><SettingsPage /></Layout></ProtectedRoute>} />
        </Routes>
        <Toaster position="top-left" />
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
    root /usr/share/nginx/html;
    index index.html;
    
    location /api { proxy_pass http://backend:8001; proxy_set_header Host $host; }
    location / { try_files $uri $uri/ /index.html; }
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
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

    # Dockerfile.frontend
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
CMD ["nginx", "-g", "daemon off;"]
EOF

    print_info "Docker files created with Username: $PANEL_USERNAME, Port: $PANEL_PORT"
}

configure_firewall() {
    if command -v ufw &>/dev/null; then
        ufw allow $WG_PORT/udp
        ufw allow $PANEL_PORT/tcp
    fi
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=$WG_PORT/udp
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp
        firewall-cmd --reload
    fi
}

build_and_start() {
    print_info "Building and starting containers..."
    cd $INSTALL_DIR
    docker compose up -d --build
    sleep 10
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel is running!"
    else
        print_error "Failed to start. Check: docker compose logs"
    fi
}

print_complete() {
    SERVER_IP=$(get_server_ip)
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅  Installation Complete!                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Panel URL: ${CYAN}http://$SERVER_IP:$PANEL_PORT${NC}"
    echo -e "  Username: ${CYAN}$PANEL_USERNAME${NC}"
    echo -e "  Password: ${CYAN}$PANEL_PASSWORD${NC}"
    echo ""
}

# Full installation
install_panel() {
    if is_installed; then
        print_warning "Panel already installed!"
        echo -e "${YELLOW}Reinstall? (y/n)${NC}"
        read -r REPLY
        if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
            return 0
        fi
        print_info "Removing old installation..."
        cd $INSTALL_DIR
        docker compose down -v 2>/dev/null || true
        rm -rf $INSTALL_DIR
    fi
    
    detect_os
    ask_user_config
    if [ $? -ne 0 ]; then
        return 0
    fi
    
    print_info "Starting installation..."
    
    install_prerequisites || { print_error "Failed to install prerequisites"; return 1; }
    install_docker || { print_error "Failed to install docker"; return 1; }
    install_wireguard || { print_error "Failed to install wireguard"; return 1; }
    setup_wireguard || { print_error "Failed to setup wireguard"; return 1; }
    create_project_files || { print_error "Failed to create files"; return 1; }
    configure_firewall
    build_and_start || { print_error "Failed to start"; return 1; }
    print_complete
}

# Main menu loop
main_menu() {
    while true; do
        show_menu
        echo -e "${CYAN}Select option / انتخاب گزینه:${NC}"
        read -p "> " choice
        
        case $choice in
            1) install_panel; read -p "Press Enter..." ;;
            2) start_panel_service; read -p "Press Enter..." ;;
            3) stop_panel_service; read -p "Press Enter..." ;;
            4) restart_panel_service; read -p "Press Enter..." ;;
            5) update_panel_service; read -p "Press Enter..." ;;
            6) view_logs_service ;;
            7) panel_status_service; read -p "Press Enter..." ;;
            8) uninstall_panel_service; read -p "Press Enter..." ;;
            0) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option"; sleep 2 ;;
        esac
    done
}

check_root
main_menu
