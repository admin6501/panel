from fastapi import FastAPI, HTTPException, Depends, status, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import List, Optional
import os
import io
import qrcode
import uuid

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

app = FastAPI(title="WireGuard Panel API", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = os.environ.get("DB_NAME", "wireguard_panel")
client = MongoClient(MONGO_URL)
db = client[DB_NAME]

# Collections
users_collection = db["users"]
clients_collection = db["clients"]
settings_collection = db["settings"]


# ==================== INITIALIZATION ====================

def init_super_admin():
    """Create default super admin if not exists"""
    if users_collection.count_documents({"role": UserRole.SUPER_ADMIN.value}) == 0:
        admin = {
            "id": str(uuid.uuid4()),
            "username": "admin",
            "hashed_password": get_password_hash("admin"),
            "role": UserRole.SUPER_ADMIN.value,
            "is_active": True,
            "created_at": datetime.utcnow(),
            "created_by": None
        }
        users_collection.insert_one(admin)
        print("Default super admin created: admin/admin")


def init_server_settings():
    """Initialize server settings if not exists"""
    if settings_collection.count_documents({"id": "server_settings"}) == 0:
        private_key, public_key = wg_manager.generate_keys()
        settings = {
            "id": "server_settings",
            "server_name": "WireGuard Panel",
            "wg_interface": os.environ.get("WG_INTERFACE", "wg0"),
            "wg_port": int(os.environ.get("WG_PORT", "51820")),
            "wg_network": os.environ.get("WG_NETWORK", "10.0.0.0/24"),
            "wg_dns": os.environ.get("WG_DNS", "1.1.1.1,8.8.8.8"),
            "server_public_key": public_key,
            "server_private_key": private_key,
            "server_address": "10.0.0.1/24",
            "endpoint": "",
            "mtu": 1420,
            "persistent_keepalive": 25
        }
        settings_collection.insert_one(settings)
        print("Server settings initialized")


@app.on_event("startup")
async def startup_event():
    init_super_admin()
    init_server_settings()


# ==================== AUTH ROUTES ====================

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


# ==================== USER MANAGEMENT ROUTES ====================

@app.get("/api/users", response_model=List[dict])
async def get_users(current_user: TokenData = Depends(require_super_admin)):
    users = list(users_collection.find({}, {"hashed_password": 0, "_id": 0}))
    return users


@app.post("/api/users", response_model=dict)
async def create_user(user: UserCreate, current_user: TokenData = Depends(require_super_admin)):
    # Check if username exists
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
        # Check if new username exists
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


# ==================== CLIENT MANAGEMENT ROUTES ====================

@app.get("/api/clients", response_model=List[dict])
async def get_clients(current_user: TokenData = Depends(require_viewer)):
    clients = list(clients_collection.find({}, {"_id": 0}))
    
    # Update stats from WireGuard
    stats = wg_manager.get_interface_stats()
    for client in clients:
        if client["public_key"] in stats:
            client_stats = stats[client["public_key"]]
            client["data_used"] = client_stats["transfer_rx"] + client_stats["transfer_tx"]
            client["is_online"] = client_stats["latest_handshake"] is not None and \
                (datetime.now().timestamp() - client_stats["latest_handshake"]) < 180
        else:
            client["is_online"] = False
        
        # Check status
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
    # Get server settings
    settings = settings_collection.find_one({"id": "server_settings"})
    if not settings:
        raise HTTPException(status_code=500, detail="Server settings not found")
    
    if not settings.get("endpoint"):
        raise HTTPException(status_code=400, detail="Server endpoint not configured. Please set it in settings.")
    
    # Generate keys
    private_key, public_key = wg_manager.generate_keys()
    preshared_key = wg_manager.generate_preshared_key()
    
    # Get used IPs
    used_ips = [c["address"].split("/")[0] for c in clients_collection.find({}, {"address": 1})]
    used_ips.append(settings["server_address"].split("/")[0])
    
    # Get next available IP
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
        "expiry_date": client.expiry_date,
        "note": client.note,
        "is_enabled": True,
        "status": ClientStatus.ACTIVE.value,
        "data_used": 0,
        "created_at": datetime.utcnow(),
        "created_by": current_user.user_id,
        "last_handshake": None
    }
    
    # Add peer to WireGuard
    wg_manager.add_peer(public_key, preshared_key, address)
    
    clients_collection.insert_one(new_client)
    
    # Don't return private key in response
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
    if client_update.note is not None:
        update_data["note"] = client_update.note
    if client_update.is_enabled is not None:
        update_data["is_enabled"] = client_update.is_enabled
        # Enable/disable peer in WireGuard
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
    
    # Remove peer from WireGuard
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
    
    # Generate QR code
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(config)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Save to bytes
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


# ==================== SETTINGS ROUTES ====================

@app.get("/api/settings")
async def get_settings(current_user: TokenData = Depends(require_admin)):
    settings = settings_collection.find_one({"id": "server_settings"}, {"_id": 0})
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    # Don't return private key
    settings.pop("server_private_key", None)
    return settings


@app.put("/api/settings")
async def update_settings(settings_update: dict, current_user: TokenData = Depends(require_super_admin)):
    allowed_fields = [
        "server_name", "endpoint", "wg_port", "wg_dns", "mtu", "persistent_keepalive"
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


# ==================== DASHBOARD ROUTES ====================

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
        
        # Get data usage from WireGuard stats
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


# ==================== HEALTH CHECK ====================

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
