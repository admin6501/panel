from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


# Enums
class UserRole(str, Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    SUPPORT = "support"


class OrderStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class PaymentStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class TicketStatus(str, Enum):
    OPEN = "open"
    ANSWERED = "answered"
    WAITING = "waiting"
    CLOSED = "closed"


class TicketPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


# Auth Models
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: str
    username: str
    role: str


class LoginRequest(BaseModel):
    username: str
    password: str


# Admin Models
class AdminCreate(BaseModel):
    username: str
    password: str
    role: UserRole = UserRole.ADMIN


class AdminUpdate(BaseModel):
    username: Optional[str] = None
    password: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None


# Telegram User Models
class TelegramUser(BaseModel):
    telegram_id: int
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    wallet_balance: float = 0
    is_banned: bool = False
    is_reseller: bool = False
    reseller_discount: float = 0
    referred_by: Optional[int] = None
    referral_earnings: float = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)


# Server/Panel Models
class ServerCreate(BaseModel):
    name: str
    panel_url: str
    panel_username: str
    panel_password: str
    is_active: bool = True
    max_users: Optional[int] = None
    description: Optional[str] = None


class ServerUpdate(BaseModel):
    name: Optional[str] = None
    panel_url: Optional[str] = None
    panel_username: Optional[str] = None
    panel_password: Optional[str] = None
    is_active: Optional[bool] = None
    max_users: Optional[int] = None
    description: Optional[str] = None


# Plan Models
class PlanCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    duration_days: int
    traffic_gb: Optional[float] = None
    user_limit: int = 1
    server_ids: List[str] = []
    is_active: bool = True
    is_test: bool = False
    sort_order: int = 0


class PlanUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    duration_days: Optional[int] = None
    traffic_gb: Optional[float] = None
    user_limit: Optional[int] = None
    server_ids: Optional[List[str]] = None
    is_active: Optional[bool] = None
    is_test: Optional[bool] = None
    sort_order: Optional[int] = None


# Order Models
class OrderCreate(BaseModel):
    telegram_user_id: int
    plan_id: str
    server_id: str
    discount_code: Optional[str] = None


# Payment Models
class PaymentCreate(BaseModel):
    order_id: str
    amount: float
    card_number: str
    receipt_image: Optional[str] = None


class PaymentReview(BaseModel):
    status: PaymentStatus
    admin_note: Optional[str] = None


# Discount Code Models
class DiscountCodeCreate(BaseModel):
    code: str
    discount_percent: Optional[float] = None
    discount_amount: Optional[float] = None
    max_uses: Optional[int] = None
    valid_until: Optional[datetime] = None
    min_order_amount: Optional[float] = None
    plan_ids: List[str] = []
    is_active: bool = True


class DiscountCodeUpdate(BaseModel):
    code: Optional[str] = None
    discount_percent: Optional[float] = None
    discount_amount: Optional[float] = None
    max_uses: Optional[int] = None
    valid_until: Optional[datetime] = None
    min_order_amount: Optional[float] = None
    plan_ids: Optional[List[str]] = None
    is_active: Optional[bool] = None


# Department Models
class DepartmentCreate(BaseModel):
    name: str
    description: Optional[str] = None
    is_active: bool = True
    sort_order: int = 0


class DepartmentUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


# Ticket Models
class TicketCreate(BaseModel):
    telegram_user_id: int
    department_id: str
    subject: str
    message: str


class TicketReply(BaseModel):
    message: str
    is_admin: bool = False
    admin_id: Optional[str] = None


class TicketUpdate(BaseModel):
    status: Optional[TicketStatus] = None
    priority: Optional[TicketPriority] = None


# Reseller Models
class ResellerCreate(BaseModel):
    telegram_user_id: int
    discount_percent: float = 10
    credit_limit: float = 0
    is_active: bool = True


class ResellerUpdate(BaseModel):
    discount_percent: Optional[float] = None
    credit_limit: Optional[float] = None
    is_active: Optional[bool] = None
    balance: Optional[float] = None


# Bot Settings Models
class BotSettingsUpdate(BaseModel):
    bot_token: Optional[str] = None
    bot_username: Optional[str] = None
    channel_id: Optional[str] = None
    channel_username: Optional[str] = None
    support_username: Optional[str] = None
    card_number: Optional[str] = None
    card_holder: Optional[str] = None
    welcome_message: Optional[str] = None
    rules_message: Optional[str] = None
    payment_timeout_minutes: Optional[int] = None
    test_account_enabled: Optional[bool] = None
    referral_enabled: Optional[bool] = None
    referral_percent: Optional[float] = None
    min_withdrawal: Optional[float] = None


# Broadcast Models
class BroadcastCreate(BaseModel):
    message: str
    target: str = "all"  # all, users, resellers
    include_media: Optional[str] = None


# Dashboard Stats
class DashboardStats(BaseModel):
    total_users: int = 0
    total_orders: int = 0
    total_revenue: float = 0
    pending_payments: int = 0
    active_subscriptions: int = 0
    open_tickets: int = 0
    total_resellers: int = 0
    today_revenue: float = 0
    today_orders: int = 0
    today_users: int = 0
