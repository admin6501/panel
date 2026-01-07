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
    data_limit: Optional[int] = None  # in bytes, None = unlimited
    expiry_date: Optional[datetime] = None  # None = never expires
    expiry_days: Optional[int] = None  # Duration in days (used for reset)
    start_on_first_connect: bool = False  # Start timer on first connection
    auto_renew: bool = False  # Auto renew when expired or data limit reached
    auto_renew_days: Optional[int] = None  # Days for auto renewal
    auto_renew_data_limit: Optional[int] = None  # Data limit for auto renewal (bytes)
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
    data_used: int = 0  # in bytes
    created_at: datetime = Field(default_factory=datetime.utcnow)
    created_by: Optional[str] = None
    last_handshake: Optional[datetime] = None
    first_connection_at: Optional[datetime] = None  # First connection time
    timer_started: bool = False  # Has the timer started?
    renew_count: int = 0  # Number of auto renewals

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
