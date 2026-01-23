from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import List, Optional
from contextlib import asynccontextmanager
import os
import uuid
import httpx
import base64

from dotenv import load_dotenv
load_dotenv()

from models import (
    Token, LoginRequest, TokenData, UserRole,
    AdminCreate, AdminUpdate,
    ServerCreate, ServerUpdate,
    CategoryCreate, CategoryUpdate,
    PlanCreate, PlanUpdate,
    OrderStatus, PaymentStatus, PaymentReview,
    DiscountCodeCreate, DiscountCodeUpdate,
    DepartmentCreate, DepartmentUpdate,
    TicketStatus, TicketPriority, TicketReply, TicketUpdate,
    ResellerCreate, ResellerUpdate,
    BotSettingsUpdate, BroadcastCreate, DashboardStats
)
from auth import (
    get_password_hash, verify_password, create_access_token,
    get_current_user, require_super_admin, require_admin, require_support
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_super_admin()
    init_bot_settings()
    init_default_departments()
    yield


app = FastAPI(title="V2Ray Sales Bot API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB
MONGO_URL = os.environ.get("MONGO_URL")
DB_NAME = os.environ.get("DB_NAME", "v2ray_bot")
client = MongoClient(MONGO_URL)
db = client[DB_NAME]

# Collections
admins_col = db["admins"]
users_col = db["telegram_users"]
servers_col = db["servers"]
categories_col = db["categories"]
plans_col = db["plans"]
orders_col = db["orders"]
payments_col = db["payments"]
discounts_col = db["discount_codes"]
departments_col = db["departments"]
tickets_col = db["tickets"]
resellers_col = db["resellers"]
settings_col = db["bot_settings"]
subscriptions_col = db["subscriptions"]


# ==================== INITIALIZATION ====================

def init_super_admin():
    if admins_col.count_documents({"role": UserRole.SUPER_ADMIN.value}) == 0:
        admin = {
            "id": str(uuid.uuid4()),
            "username": "admin",
            "hashed_password": get_password_hash("admin"),
            "role": UserRole.SUPER_ADMIN.value,
            "is_active": True,
            "created_at": datetime.utcnow()
        }
        admins_col.insert_one(admin)
        print("Default admin created: admin/admin")


def init_bot_settings():
    if settings_col.count_documents({"id": "bot_settings"}) == 0:
        settings = {
            "id": "bot_settings",
            "bot_token": "",
            "bot_username": "",
            "channel_id": "",
            "channel_username": "",
            "support_username": "",
            "card_number": "",
            "card_holder": "",
            "welcome_message": "به ربات فروش V2Ray خوش آمدید! 🎉",
            "rules_message": "لطفاً قوانین را مطالعه کنید.",
            "payment_timeout_minutes": 30,
            "test_account_enabled": True,
            "referral_enabled": True,
            "referral_percent": 10,
            "min_withdrawal": 50000
        }
        settings_col.insert_one(settings)


def init_default_departments():
    if departments_col.count_documents({}) == 0:
        departments = [
            {"id": str(uuid.uuid4()), "name": "پشتیبانی فنی", "description": "مشکلات فنی و اتصال", "is_active": True, "sort_order": 1, "created_at": datetime.utcnow()},
            {"id": str(uuid.uuid4()), "name": "مالی", "description": "مشکلات پرداخت و شارژ", "is_active": True, "sort_order": 2, "created_at": datetime.utcnow()},
            {"id": str(uuid.uuid4()), "name": "فروش", "description": "سوالات قبل از خرید", "is_active": True, "sort_order": 3, "created_at": datetime.utcnow()},
        ]
        departments_col.insert_many(departments)


# ==================== AUTH ROUTES ====================

@app.post("/api/auth/login", response_model=Token)
async def login(request: LoginRequest):
    admin = admins_col.find_one({"username": request.username})
    if not admin or not verify_password(request.password, admin["hashed_password"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="نام کاربری یا رمز عبور اشتباه است")
    
    if not admin.get("is_active", True):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="حساب کاربری غیرفعال است")
    
    access_token = create_access_token(data={"user_id": admin["id"], "username": admin["username"], "role": admin["role"]})
    return Token(access_token=access_token)


@app.get("/api/auth/me")
async def get_me(current_user: TokenData = Depends(get_current_user)):
    admin = admins_col.find_one({"id": current_user.user_id}, {"_id": 0, "hashed_password": 0})
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    return admin


# ==================== ADMIN MANAGEMENT ====================

@app.get("/api/admins")
async def get_admins(current_user: TokenData = Depends(require_super_admin)):
    admins = list(admins_col.find({}, {"_id": 0, "hashed_password": 0}))
    return admins


@app.post("/api/admins")
async def create_admin(admin: AdminCreate, current_user: TokenData = Depends(require_super_admin)):
    if admins_col.find_one({"username": admin.username}):
        raise HTTPException(status_code=400, detail="نام کاربری تکراری است")
    
    new_admin = {
        "id": str(uuid.uuid4()),
        "username": admin.username,
        "hashed_password": get_password_hash(admin.password),
        "role": admin.role.value,
        "is_active": True,
        "created_at": datetime.utcnow()
    }
    admins_col.insert_one(new_admin)
    return {"id": new_admin["id"], "username": new_admin["username"], "role": new_admin["role"]}


@app.put("/api/admins/{admin_id}")
async def update_admin(admin_id: str, admin_update: AdminUpdate, current_user: TokenData = Depends(require_super_admin)):
    admin = admins_col.find_one({"id": admin_id})
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    
    update_data = {}
    if admin_update.username:
        update_data["username"] = admin_update.username
    if admin_update.password:
        update_data["hashed_password"] = get_password_hash(admin_update.password)
    if admin_update.role:
        update_data["role"] = admin_update.role.value
    if admin_update.is_active is not None:
        update_data["is_active"] = admin_update.is_active
    
    if update_data:
        admins_col.update_one({"id": admin_id}, {"$set": update_data})
    
    return admins_col.find_one({"id": admin_id}, {"_id": 0, "hashed_password": 0})


@app.delete("/api/admins/{admin_id}")
async def delete_admin(admin_id: str, current_user: TokenData = Depends(require_super_admin)):
    if admin_id == current_user.user_id:
        raise HTTPException(status_code=400, detail="نمی‌توانید خودتان را حذف کنید")
    result = admins_col.delete_one({"id": admin_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Admin not found")
    return {"message": "Admin deleted"}


# ==================== SERVER MANAGEMENT ====================

@app.get("/api/servers")
async def get_servers(current_user: TokenData = Depends(require_admin)):
    servers = list(servers_col.find({}, {"_id": 0}))
    return servers


@app.post("/api/servers")
async def create_server(server: ServerCreate, current_user: TokenData = Depends(require_admin)):
    new_server = {
        "id": str(uuid.uuid4()),
        **server.model_dump(),
        "current_users": 0,
        "created_at": datetime.utcnow()
    }
    servers_col.insert_one(new_server)
    return {k: v for k, v in new_server.items() if k != "_id"}


@app.put("/api/servers/{server_id}")
async def update_server(server_id: str, server_update: ServerUpdate, current_user: TokenData = Depends(require_admin)):
    server = servers_col.find_one({"id": server_id})
    if not server:
        raise HTTPException(status_code=404, detail="Server not found")
    
    update_data = {k: v for k, v in server_update.model_dump().items() if v is not None}
    if update_data:
        servers_col.update_one({"id": server_id}, {"$set": update_data})
    
    return servers_col.find_one({"id": server_id}, {"_id": 0})


@app.delete("/api/servers/{server_id}")
async def delete_server(server_id: str, current_user: TokenData = Depends(require_admin)):
    result = servers_col.delete_one({"id": server_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Server not found")
    return {"message": "Server deleted"}


@app.post("/api/servers/{server_id}/test")
async def test_server_connection(server_id: str, current_user: TokenData = Depends(require_admin)):
    server = servers_col.find_one({"id": server_id})
    if not server:
        raise HTTPException(status_code=404, detail="Server not found")
    
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                f"{server['panel_url']}/login",
                data={"username": server["panel_username"], "password": server["panel_password"]}
            )
            if response.status_code == 200:
                return {"status": "success", "message": "اتصال برقرار شد"}
            return {"status": "error", "message": f"خطا: {response.status_code}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


# ==================== PLAN MANAGEMENT ====================

@app.get("/api/plans")
async def get_plans(current_user: TokenData = Depends(require_admin)):
    plans = list(plans_col.find({}, {"_id": 0}).sort("sort_order", 1))
    return plans


@app.post("/api/plans")
async def create_plan(plan: PlanCreate, current_user: TokenData = Depends(require_admin)):
    new_plan = {
        "id": str(uuid.uuid4()),
        **plan.model_dump(),
        "sales_count": 0,
        "created_at": datetime.utcnow()
    }
    plans_col.insert_one(new_plan)
    return {k: v for k, v in new_plan.items() if k != "_id"}


@app.put("/api/plans/{plan_id}")
async def update_plan(plan_id: str, plan_update: PlanUpdate, current_user: TokenData = Depends(require_admin)):
    plan = plans_col.find_one({"id": plan_id})
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    update_data = {k: v for k, v in plan_update.model_dump().items() if v is not None}
    if update_data:
        plans_col.update_one({"id": plan_id}, {"$set": update_data})
    
    return plans_col.find_one({"id": plan_id}, {"_id": 0})


@app.delete("/api/plans/{plan_id}")
async def delete_plan(plan_id: str, current_user: TokenData = Depends(require_admin)):
    result = plans_col.delete_one({"id": plan_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Plan not found")
    return {"message": "Plan deleted"}


# ==================== ORDER & PAYMENT MANAGEMENT ====================

@app.get("/api/orders")
async def get_orders(
    status: Optional[str] = None,
    limit: int = 50,
    skip: int = 0,
    current_user: TokenData = Depends(require_admin)
):
    query = {}
    if status:
        query["status"] = status
    
    orders = list(orders_col.find(query, {"_id": 0}).sort("created_at", -1).skip(skip).limit(limit))
    total = orders_col.count_documents(query)
    
    # Enrich with user and plan info
    for order in orders:
        user = users_col.find_one({"telegram_id": order.get("telegram_user_id")}, {"_id": 0})
        plan = plans_col.find_one({"id": order.get("plan_id")}, {"_id": 0})
        order["user"] = user
        order["plan"] = plan
    
    return {"orders": orders, "total": total}


@app.get("/api/payments")
async def get_payments(
    status: Optional[str] = None,
    limit: int = 50,
    skip: int = 0,
    current_user: TokenData = Depends(require_admin)
):
    query = {}
    if status:
        query["status"] = status
    
    payments = list(payments_col.find(query, {"_id": 0}).sort("created_at", -1).skip(skip).limit(limit))
    total = payments_col.count_documents(query)
    
    for payment in payments:
        order = orders_col.find_one({"id": payment.get("order_id")}, {"_id": 0})
        if order:
            user = users_col.find_one({"telegram_id": order.get("telegram_user_id")}, {"_id": 0})
            payment["order"] = order
            payment["user"] = user
    
    return {"payments": payments, "total": total}


@app.put("/api/payments/{payment_id}/review")
async def review_payment(payment_id: str, review: PaymentReview, current_user: TokenData = Depends(require_admin)):
    payment = payments_col.find_one({"id": payment_id})
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    payments_col.update_one(
        {"id": payment_id},
        {"$set": {
            "status": review.status.value,
            "admin_note": review.admin_note,
            "reviewed_by": current_user.user_id,
            "reviewed_at": datetime.utcnow()
        }}
    )
    
    order = orders_col.find_one({"id": payment["order_id"]})
    
    if review.status == PaymentStatus.APPROVED:
        orders_col.update_one(
            {"id": payment["order_id"]},
            {"$set": {"status": OrderStatus.CONFIRMED.value, "confirmed_at": datetime.utcnow()}}
        )
        
        if order:
            plan = plans_col.find_one({"id": order["plan_id"]})
            if plan:
                subscription = {
                    "id": str(uuid.uuid4()),
                    "telegram_user_id": order["telegram_user_id"],
                    "order_id": order["id"],
                    "plan_id": plan["id"],
                    "server_id": order["server_id"],
                    "config_data": None,
                    "expires_at": datetime.utcnow() + timedelta(days=plan["duration_days"]),
                    "traffic_limit": plan.get("traffic_gb"),
                    "traffic_used": 0,
                    "is_active": True,
                    "created_at": datetime.utcnow()
                }
                subscriptions_col.insert_one(subscription)
                plans_col.update_one({"id": plan["id"]}, {"$inc": {"sales_count": 1}})
    
    elif review.status == PaymentStatus.REJECTED:
        orders_col.update_one(
            {"id": payment["order_id"]},
            {"$set": {"status": OrderStatus.CANCELLED.value}}
        )
    
    return {"message": "Payment reviewed"}


# ==================== DISCOUNT CODES ====================

@app.get("/api/discount-codes")
async def get_discount_codes(current_user: TokenData = Depends(require_admin)):
    codes = list(discounts_col.find({}, {"_id": 0}))
    return codes


@app.post("/api/discount-codes")
async def create_discount_code(code: DiscountCodeCreate, current_user: TokenData = Depends(require_admin)):
    if discounts_col.find_one({"code": code.code.upper()}):
        raise HTTPException(status_code=400, detail="کد تکراری است")
    
    new_code = {
        "id": str(uuid.uuid4()),
        **code.model_dump(),
        "code": code.code.upper(),
        "used_count": 0,
        "created_at": datetime.utcnow()
    }
    discounts_col.insert_one(new_code)
    return {k: v for k, v in new_code.items() if k != "_id"}


@app.put("/api/discount-codes/{code_id}")
async def update_discount_code(code_id: str, code_update: DiscountCodeUpdate, current_user: TokenData = Depends(require_admin)):
    code = discounts_col.find_one({"id": code_id})
    if not code:
        raise HTTPException(status_code=404, detail="Code not found")
    
    update_data = {k: v for k, v in code_update.model_dump().items() if v is not None}
    if "code" in update_data:
        update_data["code"] = update_data["code"].upper()
    
    if update_data:
        discounts_col.update_one({"id": code_id}, {"$set": update_data})
    
    return discounts_col.find_one({"id": code_id}, {"_id": 0})


@app.delete("/api/discount-codes/{code_id}")
async def delete_discount_code(code_id: str, current_user: TokenData = Depends(require_admin)):
    result = discounts_col.delete_one({"id": code_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Code not found")
    return {"message": "Code deleted"}


# ==================== DEPARTMENTS ====================

@app.get("/api/departments")
async def get_departments(current_user: TokenData = Depends(require_support)):
    departments = list(departments_col.find({}, {"_id": 0}).sort("sort_order", 1))
    return departments


@app.post("/api/departments")
async def create_department(dept: DepartmentCreate, current_user: TokenData = Depends(require_admin)):
    new_dept = {
        "id": str(uuid.uuid4()),
        **dept.model_dump(),
        "created_at": datetime.utcnow()
    }
    departments_col.insert_one(new_dept)
    return {k: v for k, v in new_dept.items() if k != "_id"}


@app.put("/api/departments/{dept_id}")
async def update_department(dept_id: str, dept_update: DepartmentUpdate, current_user: TokenData = Depends(require_admin)):
    dept = departments_col.find_one({"id": dept_id})
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    
    update_data = {k: v for k, v in dept_update.model_dump().items() if v is not None}
    if update_data:
        departments_col.update_one({"id": dept_id}, {"$set": update_data})
    
    return departments_col.find_one({"id": dept_id}, {"_id": 0})


@app.delete("/api/departments/{dept_id}")
async def delete_department(dept_id: str, current_user: TokenData = Depends(require_admin)):
    result = departments_col.delete_one({"id": dept_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Department not found")
    return {"message": "Department deleted"}


# ==================== TICKETS ====================

@app.get("/api/tickets")
async def get_tickets(
    status: Optional[str] = None,
    department_id: Optional[str] = None,
    limit: int = 50,
    skip: int = 0,
    current_user: TokenData = Depends(require_support)
):
    query = {}
    if status:
        query["status"] = status
    if department_id:
        query["department_id"] = department_id
    
    tickets = list(tickets_col.find(query, {"_id": 0}).sort("updated_at", -1).skip(skip).limit(limit))
    total = tickets_col.count_documents(query)
    
    for ticket in tickets:
        user = users_col.find_one({"telegram_id": ticket.get("telegram_user_id")}, {"_id": 0})
        dept = departments_col.find_one({"id": ticket.get("department_id")}, {"_id": 0})
        ticket["user"] = user
        ticket["department"] = dept
    
    return {"tickets": tickets, "total": total}


@app.get("/api/tickets/{ticket_id}")
async def get_ticket(ticket_id: str, current_user: TokenData = Depends(require_support)):
    ticket = tickets_col.find_one({"id": ticket_id}, {"_id": 0})
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    user = users_col.find_one({"telegram_id": ticket.get("telegram_user_id")}, {"_id": 0})
    dept = departments_col.find_one({"id": ticket.get("department_id")}, {"_id": 0})
    ticket["user"] = user
    ticket["department"] = dept
    
    return ticket


@app.post("/api/tickets/{ticket_id}/reply")
async def reply_ticket(ticket_id: str, reply: TicketReply, current_user: TokenData = Depends(require_support)):
    ticket = tickets_col.find_one({"id": ticket_id})
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    message = {
        "id": str(uuid.uuid4()),
        "message": reply.message,
        "is_admin": True,
        "admin_id": current_user.user_id,
        "admin_username": current_user.username,
        "created_at": datetime.utcnow()
    }
    
    tickets_col.update_one(
        {"id": ticket_id},
        {
            "$push": {"messages": message},
            "$set": {
                "status": TicketStatus.ANSWERED.value,
                "updated_at": datetime.utcnow(),
                "last_reply_by": "admin"
            }
        }
    )
    
    return {"message": "Reply sent"}


@app.put("/api/tickets/{ticket_id}")
async def update_ticket(ticket_id: str, ticket_update: TicketUpdate, current_user: TokenData = Depends(require_support)):
    ticket = tickets_col.find_one({"id": ticket_id})
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    update_data = {}
    if ticket_update.status:
        update_data["status"] = ticket_update.status.value
    if ticket_update.priority:
        update_data["priority"] = ticket_update.priority.value
    
    update_data["updated_at"] = datetime.utcnow()
    
    tickets_col.update_one({"id": ticket_id}, {"$set": update_data})
    return tickets_col.find_one({"id": ticket_id}, {"_id": 0})


# ==================== RESELLERS ====================

@app.get("/api/resellers")
async def get_resellers(current_user: TokenData = Depends(require_admin)):
    resellers = list(resellers_col.find({}, {"_id": 0}))
    for reseller in resellers:
        user = users_col.find_one({"telegram_id": reseller.get("telegram_user_id")}, {"_id": 0})
        reseller["user"] = user
    return resellers


@app.post("/api/resellers")
async def create_reseller(reseller: ResellerCreate, current_user: TokenData = Depends(require_admin)):
    if resellers_col.find_one({"telegram_user_id": reseller.telegram_user_id}):
        raise HTTPException(status_code=400, detail="این کاربر قبلاً نماینده است")
    
    user = users_col.find_one({"telegram_id": reseller.telegram_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="کاربر یافت نشد")
    
    new_reseller = {
        "id": str(uuid.uuid4()),
        **reseller.model_dump(),
        "balance": 0,
        "total_sales": 0,
        "created_at": datetime.utcnow()
    }
    resellers_col.insert_one(new_reseller)
    
    users_col.update_one(
        {"telegram_id": reseller.telegram_user_id},
        {"$set": {"is_reseller": True, "reseller_discount": reseller.discount_percent}}
    )
    
    return {k: v for k, v in new_reseller.items() if k != "_id"}


@app.put("/api/resellers/{reseller_id}")
async def update_reseller(reseller_id: str, reseller_update: ResellerUpdate, current_user: TokenData = Depends(require_admin)):
    reseller = resellers_col.find_one({"id": reseller_id})
    if not reseller:
        raise HTTPException(status_code=404, detail="Reseller not found")
    
    update_data = {k: v for k, v in reseller_update.model_dump().items() if v is not None}
    if update_data:
        resellers_col.update_one({"id": reseller_id}, {"$set": update_data})
        
        if "discount_percent" in update_data or "is_active" in update_data:
            users_col.update_one(
                {"telegram_id": reseller["telegram_user_id"]},
                {"$set": {
                    "is_reseller": update_data.get("is_active", reseller.get("is_active", True)),
                    "reseller_discount": update_data.get("discount_percent", reseller.get("discount_percent", 0))
                }}
            )
    
    return resellers_col.find_one({"id": reseller_id}, {"_id": 0})


@app.delete("/api/resellers/{reseller_id}")
async def delete_reseller(reseller_id: str, current_user: TokenData = Depends(require_admin)):
    reseller = resellers_col.find_one({"id": reseller_id})
    if not reseller:
        raise HTTPException(status_code=404, detail="Reseller not found")
    
    users_col.update_one(
        {"telegram_id": reseller["telegram_user_id"]},
        {"$set": {"is_reseller": False, "reseller_discount": 0}}
    )
    
    resellers_col.delete_one({"id": reseller_id})
    return {"message": "Reseller removed"}


# ==================== TELEGRAM USERS ====================

@app.get("/api/users")
async def get_telegram_users(
    search: Optional[str] = None,
    is_reseller: Optional[bool] = None,
    is_banned: Optional[bool] = None,
    limit: int = 50,
    skip: int = 0,
    current_user: TokenData = Depends(require_admin)
):
    query = {}
    if search:
        query["$or"] = [
            {"username": {"$regex": search, "$options": "i"}},
            {"first_name": {"$regex": search, "$options": "i"}},
            {"telegram_id": {"$regex": search, "$options": "i"}} if search.isdigit() else {}
        ]
    if is_reseller is not None:
        query["is_reseller"] = is_reseller
    if is_banned is not None:
        query["is_banned"] = is_banned
    
    users = list(users_col.find(query, {"_id": 0}).sort("created_at", -1).skip(skip).limit(limit))
    total = users_col.count_documents(query)
    
    return {"users": users, "total": total}


@app.put("/api/users/{telegram_id}/ban")
async def ban_user(telegram_id: int, current_user: TokenData = Depends(require_admin)):
    user = users_col.find_one({"telegram_id": telegram_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    new_status = not user.get("is_banned", False)
    users_col.update_one({"telegram_id": telegram_id}, {"$set": {"is_banned": new_status}})
    return {"is_banned": new_status}


@app.put("/api/users/{telegram_id}/wallet")
async def update_wallet(telegram_id: int, amount: float, current_user: TokenData = Depends(require_admin)):
    user = users_col.find_one({"telegram_id": telegram_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    users_col.update_one({"telegram_id": telegram_id}, {"$set": {"wallet_balance": amount}})
    return {"wallet_balance": amount}


# ==================== BOT SETTINGS ====================

@app.get("/api/settings")
async def get_settings(current_user: TokenData = Depends(require_admin)):
    settings = settings_col.find_one({"id": "bot_settings"}, {"_id": 0})
    return settings


@app.put("/api/settings")
async def update_settings(settings_update: BotSettingsUpdate, current_user: TokenData = Depends(require_super_admin)):
    update_data = {k: v for k, v in settings_update.model_dump().items() if v is not None}
    if update_data:
        settings_col.update_one({"id": "bot_settings"}, {"$set": update_data})
    return settings_col.find_one({"id": "bot_settings"}, {"_id": 0})


# ==================== BROADCAST ====================

@app.post("/api/broadcast")
async def send_broadcast(broadcast: BroadcastCreate, background_tasks: BackgroundTasks, current_user: TokenData = Depends(require_admin)):
    query = {}
    if broadcast.target == "users":
        query["is_reseller"] = False
    elif broadcast.target == "resellers":
        query["is_reseller"] = True
    
    users = list(users_col.find(query, {"telegram_id": 1}))
    
    return {
        "message": "Broadcast queued",
        "target_count": len(users),
        "target": broadcast.target
    }


# ==================== SUBSCRIPTIONS ====================

@app.get("/api/subscriptions")
async def get_subscriptions(
    is_active: Optional[bool] = None,
    limit: int = 50,
    skip: int = 0,
    current_user: TokenData = Depends(require_admin)
):
    query = {}
    if is_active is not None:
        query["is_active"] = is_active
    
    subs = list(subscriptions_col.find(query, {"_id": 0}).sort("created_at", -1).skip(skip).limit(limit))
    total = subscriptions_col.count_documents(query)
    
    for sub in subs:
        user = users_col.find_one({"telegram_id": sub.get("telegram_user_id")}, {"_id": 0})
        plan = plans_col.find_one({"id": sub.get("plan_id")}, {"_id": 0})
        sub["user"] = user
        sub["plan"] = plan
    
    return {"subscriptions": subs, "total": total}


# ==================== DASHBOARD ====================

@app.get("/api/dashboard/stats", response_model=DashboardStats)
async def get_dashboard_stats(current_user: TokenData = Depends(require_admin)):
    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    
    total_users = users_col.count_documents({})
    total_orders = orders_col.count_documents({})
    pending_payments = payments_col.count_documents({"status": PaymentStatus.PENDING.value})
    active_subs = subscriptions_col.count_documents({"is_active": True, "expires_at": {"$gt": datetime.utcnow()}})
    open_tickets = tickets_col.count_documents({"status": {"$in": [TicketStatus.OPEN.value, TicketStatus.WAITING.value]}})
    total_resellers = resellers_col.count_documents({})
    
    # Revenue
    confirmed_orders = list(orders_col.find({"status": OrderStatus.CONFIRMED.value}, {"final_price": 1, "confirmed_at": 1}))
    total_revenue = sum(o.get("final_price", 0) for o in confirmed_orders)
    today_revenue = sum(o.get("final_price", 0) for o in confirmed_orders if o.get("confirmed_at") and o["confirmed_at"] >= today)
    
    today_orders = orders_col.count_documents({"created_at": {"$gte": today}})
    today_users = users_col.count_documents({"created_at": {"$gte": today}})
    
    return DashboardStats(
        total_users=total_users,
        total_orders=total_orders,
        total_revenue=total_revenue,
        pending_payments=pending_payments,
        active_subscriptions=active_subs,
        open_tickets=open_tickets,
        total_resellers=total_resellers,
        today_revenue=today_revenue,
        today_orders=today_orders,
        today_users=today_users
    )


@app.get("/api/dashboard/chart")
async def get_dashboard_chart(days: int = 7, current_user: TokenData = Depends(require_admin)):
    data = []
    for i in range(days - 1, -1, -1):
        date = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=i)
        next_date = date + timedelta(days=1)
        
        orders = orders_col.count_documents({
            "created_at": {"$gte": date, "$lt": next_date}
        })
        confirmed = list(orders_col.find({
            "status": OrderStatus.CONFIRMED.value,
            "confirmed_at": {"$gte": date, "$lt": next_date}
        }, {"final_price": 1}))
        revenue = sum(o.get("final_price", 0) for o in confirmed)
        users = users_col.count_documents({"created_at": {"$gte": date, "$lt": next_date}})
        
        data.append({
            "date": date.strftime("%Y-%m-%d"),
            "orders": orders,
            "revenue": revenue,
            "users": users
        })
    
    return data


# ==================== HEALTH CHECK ====================

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
