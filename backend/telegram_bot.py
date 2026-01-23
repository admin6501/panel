"""
Telegram Bot for V2Ray Config Sales
This file contains the bot logic that runs separately from the FastAPI server
"""

import os
import asyncio
from datetime import datetime, timedelta
from typing import Optional
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, ReplyKeyboardMarkup, KeyboardButton
from telegram.ext import (
    Application, CommandHandler, MessageHandler, CallbackQueryHandler,
    ConversationHandler, ContextTypes, filters
)
from pymongo import MongoClient

# MongoDB Connection
MONGO_URL = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = os.environ.get("DB_NAME", "v2ray_bot")
mongo_client = MongoClient(MONGO_URL)
db = mongo_client[DB_NAME]

# Collections
users_col = db["telegram_users"]
plans_col = db["plans"]
orders_col = db["orders"]
payments_col = db["payments"]
tickets_col = db["tickets"]
departments_col = db["departments"]
settings_col = db["bot_settings"]
subscriptions_col = db["subscriptions"]
servers_col = db["servers"]
discounts_col = db["discount_codes"]

# Conversation States
SELECTING_PLAN, SELECTING_SERVER, ENTERING_DISCOUNT, CONFIRMING_ORDER = range(4)
UPLOADING_RECEIPT = 10
SELECTING_DEPARTMENT, ENTERING_TICKET_SUBJECT, ENTERING_TICKET_MESSAGE, REPLYING_TICKET = range(20, 24)
ENTERING_WALLET_AMOUNT = 30


def get_settings():
    """Get bot settings from database"""
    return settings_col.find_one({"id": "bot_settings"}) or {}


def get_or_create_user(telegram_user) -> dict:
    """Get or create telegram user"""
    user = users_col.find_one({"telegram_id": telegram_user.id})
    if not user:
        user = {
            "telegram_id": telegram_user.id,
            "username": telegram_user.username,
            "first_name": telegram_user.first_name,
            "last_name": telegram_user.last_name,
            "phone": None,
            "wallet_balance": 0,
            "is_banned": False,
            "is_reseller": False,
            "reseller_discount": 0,
            "referred_by": None,
            "referral_earnings": 0,
            "created_at": datetime.utcnow()
        }
        users_col.insert_one(user)
    return user


def format_price(price: float) -> str:
    """Format price in Toman"""
    return f"{price:,.0f} تومان"


def format_traffic(gb: float) -> str:
    """Format traffic in GB"""
    return f"{gb:.1f} GB" if gb else "نامحدود"


# ==================== MAIN MENU ====================

def get_main_keyboard(user: dict) -> ReplyKeyboardMarkup:
    """Generate main menu keyboard"""
    keyboard = [
        [KeyboardButton("🛒 خرید اشتراک"), KeyboardButton("👤 حساب کاربری")],
        [KeyboardButton("💰 کیف پول"), KeyboardButton("🎫 پشتیبانی")],
        [KeyboardButton("📋 اشتراک‌های من"), KeyboardButton("📞 ارتباط با ما")]
    ]
    
    if user.get("is_reseller"):
        keyboard.insert(2, [KeyboardButton("🏪 پنل نمایندگی")])
    
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = get_or_create_user(update.effective_user)
    
    if user.get("is_banned"):
        await update.message.reply_text("⛔ حساب شما مسدود شده است.")
        return
    
    settings = get_settings()
    welcome = settings.get("welcome_message", "به ربات فروش V2Ray خوش آمدید! 🎉")
    
    # Check referral
    if context.args and context.args[0].startswith("ref_"):
        try:
            referrer_id = int(context.args[0][4:])
            if referrer_id != user["telegram_id"] and not user.get("referred_by"):
                users_col.update_one(
                    {"telegram_id": user["telegram_id"]},
                    {"$set": {"referred_by": referrer_id}}
                )
        except:
            pass
    
    await update.message.reply_text(
        f"سلام {update.effective_user.first_name}! 👋\n\n{welcome}",
        reply_markup=get_main_keyboard(user)
    )


# ==================== BUY SUBSCRIPTION ====================

async def buy_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show available plans"""
    user = get_or_create_user(update.effective_user)
    
    if user.get("is_banned"):
        await update.message.reply_text("⛔ حساب شما مسدود شده است.")
        return ConversationHandler.END
    
    plans = list(plans_col.find({"is_active": True, "is_test": False}, {"_id": 0}).sort("sort_order", 1))
    
    if not plans:
        await update.message.reply_text("❌ در حال حاضر پلنی موجود نیست.")
        return ConversationHandler.END
    
    keyboard = []
    for plan in plans:
        price = plan["price"]
        if user.get("is_reseller") and user.get("reseller_discount"):
            price = price * (1 - user["reseller_discount"] / 100)
        
        text = f"📦 {plan['name']} | {plan['duration_days']} روز | {format_traffic(plan.get('traffic_gb'))} | {format_price(price)}"
        keyboard.append([InlineKeyboardButton(text, callback_data=f"plan_{plan['id']}")])
    
    keyboard.append([InlineKeyboardButton("❌ انصراف", callback_data="cancel")])
    
    await update.message.reply_text(
        "🛒 **لیست پلن‌های موجود:**\n\nپلن مورد نظر خود را انتخاب کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return SELECTING_PLAN


async def select_plan(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle plan selection"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "cancel":
        await query.edit_message_text("❌ خرید لغو شد.")
        return ConversationHandler.END
    
    plan_id = query.data.replace("plan_", "")
    plan = plans_col.find_one({"id": plan_id})
    
    if not plan:
        await query.edit_message_text("❌ پلن یافت نشد.")
        return ConversationHandler.END
    
    context.user_data["selected_plan"] = plan
    
    # Get available servers for this plan
    servers = list(servers_col.find({"is_active": True, "id": {"$in": plan.get("server_ids", [])}}, {"_id": 0}))
    
    if not servers:
        servers = list(servers_col.find({"is_active": True}, {"_id": 0}))
    
    if not servers:
        await query.edit_message_text("❌ سرور فعالی موجود نیست.")
        return ConversationHandler.END
    
    keyboard = []
    for server in servers:
        keyboard.append([InlineKeyboardButton(f"🌐 {server['name']}", callback_data=f"server_{server['id']}")])
    
    keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data="back_to_plans")])
    
    await query.edit_message_text(
        f"📦 **پلن انتخابی:** {plan['name']}\n"
        f"⏱ مدت: {plan['duration_days']} روز\n"
        f"📊 حجم: {format_traffic(plan.get('traffic_gb'))}\n\n"
        "🌐 سرور مورد نظر خود را انتخاب کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return SELECTING_SERVER


async def select_server(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle server selection"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "back_to_plans":
        return await buy_subscription_callback(update, context)
    
    server_id = query.data.replace("server_", "")
    server = servers_col.find_one({"id": server_id})
    
    if not server:
        await query.edit_message_text("❌ سرور یافت نشد.")
        return ConversationHandler.END
    
    context.user_data["selected_server"] = server
    
    keyboard = [
        [InlineKeyboardButton("🎁 وارد کردن کد تخفیف", callback_data="enter_discount")],
        [InlineKeyboardButton("✅ ادامه بدون کد تخفیف", callback_data="no_discount")],
        [InlineKeyboardButton("🔙 بازگشت", callback_data="back_to_servers")]
    ]
    
    await query.edit_message_text(
        "🎁 آیا کد تخفیف دارید؟",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )
    return ENTERING_DISCOUNT


async def handle_discount(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle discount code entry"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "back_to_servers":
        return await select_plan(update, context)
    
    if query.data == "no_discount":
        context.user_data["discount"] = None
        return await show_order_summary(update, context)
    
    if query.data == "enter_discount":
        await query.edit_message_text("🎁 کد تخفیف خود را وارد کنید:")
        return ENTERING_DISCOUNT


async def process_discount_code(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Process entered discount code"""
    code = update.message.text.strip().upper()
    
    discount = discounts_col.find_one({
        "code": code,
        "is_active": True,
        "$or": [
            {"valid_until": None},
            {"valid_until": {"$gt": datetime.utcnow()}}
        ]
    })
    
    if not discount:
        await update.message.reply_text(
            "❌ کد تخفیف نامعتبر است.\n\n"
            "کد دیگری وارد کنید یا /cancel برای انصراف:",
        )
        return ENTERING_DISCOUNT
    
    if discount.get("max_uses") and discount.get("used_count", 0) >= discount["max_uses"]:
        await update.message.reply_text("❌ این کد تخفیف به حداکثر استفاده رسیده است.")
        return ENTERING_DISCOUNT
    
    context.user_data["discount"] = discount
    
    # Create a fake callback query to show summary
    return await show_order_summary_message(update, context)


async def show_order_summary(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show order summary with callback query"""
    query = update.callback_query
    user = get_or_create_user(query.from_user)
    
    plan = context.user_data.get("selected_plan")
    server = context.user_data.get("selected_server")
    discount = context.user_data.get("discount")
    
    price = plan["price"]
    
    # Apply reseller discount
    if user.get("is_reseller") and user.get("reseller_discount"):
        price = price * (1 - user["reseller_discount"] / 100)
    
    # Apply discount code
    discount_amount = 0
    if discount:
        if discount.get("discount_percent"):
            discount_amount = price * discount["discount_percent"] / 100
        elif discount.get("discount_amount"):
            discount_amount = discount["discount_amount"]
    
    final_price = max(0, price - discount_amount)
    context.user_data["final_price"] = final_price
    context.user_data["original_price"] = plan["price"]
    context.user_data["discount_amount"] = discount_amount
    
    summary = (
        "📋 **خلاصه سفارش:**\n\n"
        f"📦 پلن: {plan['name']}\n"
        f"🌐 سرور: {server['name']}\n"
        f"⏱ مدت: {plan['duration_days']} روز\n"
        f"📊 حجم: {format_traffic(plan.get('traffic_gb'))}\n"
        f"👥 تعداد کاربر: {plan.get('user_limit', 1)}\n\n"
        f"💵 قیمت: {format_price(plan['price'])}\n"
    )
    
    if discount_amount > 0:
        summary += f"🎁 تخفیف: {format_price(discount_amount)}\n"
    
    summary += f"💰 **قیمت نهایی: {format_price(final_price)}**"
    
    keyboard = [
        [InlineKeyboardButton("💳 پرداخت کارت به کارت", callback_data="pay_card")],
        [InlineKeyboardButton("💰 پرداخت از کیف پول", callback_data="pay_wallet")],
        [InlineKeyboardButton("❌ انصراف", callback_data="cancel")]
    ]
    
    await query.edit_message_text(
        summary,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return CONFIRMING_ORDER


async def show_order_summary_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show order summary with message"""
    user = get_or_create_user(update.effective_user)
    
    plan = context.user_data.get("selected_plan")
    server = context.user_data.get("selected_server")
    discount = context.user_data.get("discount")
    
    price = plan["price"]
    
    if user.get("is_reseller") and user.get("reseller_discount"):
        price = price * (1 - user["reseller_discount"] / 100)
    
    discount_amount = 0
    if discount:
        if discount.get("discount_percent"):
            discount_amount = price * discount["discount_percent"] / 100
        elif discount.get("discount_amount"):
            discount_amount = discount["discount_amount"]
    
    final_price = max(0, price - discount_amount)
    context.user_data["final_price"] = final_price
    context.user_data["original_price"] = plan["price"]
    context.user_data["discount_amount"] = discount_amount
    
    summary = (
        "📋 **خلاصه سفارش:**\n\n"
        f"📦 پلن: {plan['name']}\n"
        f"🌐 سرور: {server['name']}\n"
        f"⏱ مدت: {plan['duration_days']} روز\n"
        f"📊 حجم: {format_traffic(plan.get('traffic_gb'))}\n"
        f"👥 تعداد کاربر: {plan.get('user_limit', 1)}\n\n"
        f"💵 قیمت: {format_price(plan['price'])}\n"
    )
    
    if discount_amount > 0:
        summary += f"🎁 تخفیف ({discount['code']}): {format_price(discount_amount)}\n"
    
    summary += f"💰 **قیمت نهایی: {format_price(final_price)}**"
    
    keyboard = [
        [InlineKeyboardButton("💳 پرداخت کارت به کارت", callback_data="pay_card")],
        [InlineKeyboardButton("💰 پرداخت از کیف پول", callback_data="pay_wallet")],
        [InlineKeyboardButton("❌ انصراف", callback_data="cancel")]
    ]
    
    await update.message.reply_text(
        summary,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return CONFIRMING_ORDER


async def confirm_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle order confirmation and payment method"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "cancel":
        await query.edit_message_text("❌ سفارش لغو شد.")
        return ConversationHandler.END
    
    user = get_or_create_user(query.from_user)
    plan = context.user_data.get("selected_plan")
    server = context.user_data.get("selected_server")
    discount = context.user_data.get("discount")
    final_price = context.user_data.get("final_price", 0)
    
    import uuid
    order_id = str(uuid.uuid4())
    
    order = {
        "id": order_id,
        "telegram_user_id": user["telegram_id"],
        "plan_id": plan["id"],
        "server_id": server["id"],
        "discount_code": discount["code"] if discount else None,
        "original_price": context.user_data.get("original_price", plan["price"]),
        "discount_amount": context.user_data.get("discount_amount", 0),
        "final_price": final_price,
        "status": "pending",
        "created_at": datetime.utcnow()
    }
    orders_col.insert_one(order)
    
    if discount:
        discounts_col.update_one({"id": discount["id"]}, {"$inc": {"used_count": 1}})
    
    context.user_data["order_id"] = order_id
    
    if query.data == "pay_wallet":
        if user.get("wallet_balance", 0) >= final_price:
            # Deduct from wallet and confirm
            users_col.update_one(
                {"telegram_id": user["telegram_id"]},
                {"$inc": {"wallet_balance": -final_price}}
            )
            
            orders_col.update_one(
                {"id": order_id},
                {"$set": {"status": "confirmed", "payment_method": "wallet", "confirmed_at": datetime.utcnow()}}
            )
            
            # Create subscription
            subscription = {
                "id": str(uuid.uuid4()),
                "telegram_user_id": user["telegram_id"],
                "order_id": order_id,
                "plan_id": plan["id"],
                "server_id": server["id"],
                "config_data": "CONFIG_PLACEHOLDER",
                "expires_at": datetime.utcnow() + timedelta(days=plan["duration_days"]),
                "traffic_limit": plan.get("traffic_gb"),
                "traffic_used": 0,
                "is_active": True,
                "created_at": datetime.utcnow()
            }
            subscriptions_col.insert_one(subscription)
            
            plans_col.update_one({"id": plan["id"]}, {"$inc": {"sales_count": 1}})
            
            await query.edit_message_text(
                "✅ **پرداخت موفق!**\n\n"
                "اشتراک شما با موفقیت فعال شد.\n"
                "برای مشاهده کانفیگ به بخش «اشتراک‌های من» مراجعه کنید.",
                parse_mode="Markdown"
            )
            return ConversationHandler.END
        else:
            await query.edit_message_text(
                f"❌ موجودی کیف پول شما کافی نیست.\n\n"
                f"💰 موجودی فعلی: {format_price(user.get('wallet_balance', 0))}\n"
                f"💵 مبلغ مورد نیاز: {format_price(final_price)}"
            )
            return ConversationHandler.END
    
    # Card to card payment
    settings = get_settings()
    card_number = settings.get("card_number", "XXXX-XXXX-XXXX-XXXX")
    card_holder = settings.get("card_holder", "نام صاحب حساب")
    timeout = settings.get("payment_timeout_minutes", 30)
    
    await query.edit_message_text(
        "💳 **پرداخت کارت به کارت**\n\n"
        f"💵 مبلغ: **{format_price(final_price)}**\n\n"
        f"🔢 شماره کارت:\n`{card_number}`\n\n"
        f"👤 به نام: {card_holder}\n\n"
        f"⏱ مهلت پرداخت: {timeout} دقیقه\n\n"
        "📸 پس از پرداخت، تصویر رسید را ارسال کنید:",
        parse_mode="Markdown"
    )
    return UPLOADING_RECEIPT


async def receive_receipt(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Receive payment receipt"""
    order_id = context.user_data.get("order_id")
    
    if not order_id:
        await update.message.reply_text("❌ خطا در پردازش سفارش.")
        return ConversationHandler.END
    
    photo = update.message.photo[-1] if update.message.photo else None
    
    if not photo:
        await update.message.reply_text("❌ لطفاً تصویر رسید پرداخت را ارسال کنید.")
        return UPLOADING_RECEIPT
    
    file = await photo.get_file()
    file_id = photo.file_id
    
    import uuid
    payment = {
        "id": str(uuid.uuid4()),
        "order_id": order_id,
        "amount": context.user_data.get("final_price", 0),
        "receipt_file_id": file_id,
        "status": "pending",
        "created_at": datetime.utcnow()
    }
    payments_col.insert_one(payment)
    
    orders_col.update_one({"id": order_id}, {"$set": {"status": "paid"}})
    
    await update.message.reply_text(
        "✅ **رسید دریافت شد!**\n\n"
        "پرداخت شما در صف بررسی قرار گرفت.\n"
        "پس از تأیید، اشتراک شما فعال خواهد شد.\n\n"
        "⏱ زمان تقریبی بررسی: ۵ تا ۳۰ دقیقه",
        parse_mode="Markdown"
    )
    return ConversationHandler.END


# ==================== USER ACCOUNT ====================

async def user_account(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show user account info"""
    user = get_or_create_user(update.effective_user)
    
    subs_count = subscriptions_col.count_documents({"telegram_user_id": user["telegram_id"], "is_active": True})
    orders_count = orders_col.count_documents({"telegram_user_id": user["telegram_id"]})
    
    text = (
        "👤 **حساب کاربری**\n\n"
        f"🆔 شناسه: `{user['telegram_id']}`\n"
        f"👤 نام: {user.get('first_name', '-')} {user.get('last_name', '')}\n"
        f"📱 یوزرنیم: @{user.get('username', '-')}\n\n"
        f"💰 موجودی کیف پول: {format_price(user.get('wallet_balance', 0))}\n"
        f"📦 اشتراک‌های فعال: {subs_count}\n"
        f"🛒 کل سفارشات: {orders_count}\n"
    )
    
    if user.get("is_reseller"):
        text += f"\n🏪 **نماینده:** بله (تخفیف {user.get('reseller_discount', 0)}%)"
    
    settings = get_settings()
    if settings.get("referral_enabled"):
        text += f"\n\n🔗 **لینک دعوت:**\n`https://t.me/{settings.get('bot_username', 'bot')}?start=ref_{user['telegram_id']}`"
    
    await update.message.reply_text(text, parse_mode="Markdown")


# ==================== WALLET ====================

async def wallet(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show wallet info"""
    user = get_or_create_user(update.effective_user)
    
    keyboard = [
        [InlineKeyboardButton("💳 شارژ کیف پول", callback_data="charge_wallet")],
        [InlineKeyboardButton("📜 تاریخچه تراکنش‌ها", callback_data="wallet_history")]
    ]
    
    await update.message.reply_text(
        f"💰 **کیف پول**\n\n"
        f"موجودی فعلی: **{format_price(user.get('wallet_balance', 0))}**\n\n"
        "با شارژ کیف پول، خریدهای بعدی سریع‌تر انجام می‌شود.",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


# ==================== SUBSCRIPTIONS ====================

async def my_subscriptions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show user's subscriptions"""
    user = get_or_create_user(update.effective_user)
    
    subs = list(subscriptions_col.find(
        {"telegram_user_id": user["telegram_id"]},
        {"_id": 0}
    ).sort("created_at", -1).limit(10))
    
    if not subs:
        await update.message.reply_text("❌ شما هنوز اشتراکی ندارید.")
        return
    
    keyboard = []
    for sub in subs:
        plan = plans_col.find_one({"id": sub["plan_id"]})
        status = "✅" if sub.get("is_active") else "❌"
        expires = sub.get("expires_at")
        if expires and isinstance(expires, datetime):
            days_left = (expires - datetime.utcnow()).days
            if days_left < 0:
                status = "⏰"
            text = f"{status} {plan['name'] if plan else 'نامشخص'} ({days_left} روز)"
        else:
            text = f"{status} {plan['name'] if plan else 'نامشخص'}"
        
        keyboard.append([InlineKeyboardButton(text, callback_data=f"sub_{sub['id']}")])
    
    await update.message.reply_text(
        "📋 **اشتراک‌های شما:**\n\nبرای مشاهده جزئیات روی هر کدام کلیک کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


async def show_subscription_detail(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show subscription details"""
    query = update.callback_query
    await query.answer()
    
    sub_id = query.data.replace("sub_", "")
    sub = subscriptions_col.find_one({"id": sub_id})
    
    if not sub:
        await query.edit_message_text("❌ اشتراک یافت نشد.")
        return
    
    plan = plans_col.find_one({"id": sub["plan_id"]})
    server = servers_col.find_one({"id": sub["server_id"]})
    
    expires = sub.get("expires_at")
    if expires and isinstance(expires, datetime):
        days_left = (expires - datetime.utcnow()).days
        expire_text = f"{expires.strftime('%Y-%m-%d')} ({days_left} روز مانده)"
    else:
        expire_text = "نامحدود"
    
    traffic_used = sub.get("traffic_used", 0)
    traffic_limit = sub.get("traffic_limit")
    if traffic_limit:
        traffic_text = f"{traffic_used:.2f} / {traffic_limit} GB"
    else:
        traffic_text = f"{traffic_used:.2f} GB (نامحدود)"
    
    text = (
        "📦 **جزئیات اشتراک:**\n\n"
        f"📋 پلن: {plan['name'] if plan else 'نامشخص'}\n"
        f"🌐 سرور: {server['name'] if server else 'نامشخص'}\n"
        f"📅 انقضا: {expire_text}\n"
        f"📊 مصرف: {traffic_text}\n"
        f"✅ وضعیت: {'فعال' if sub.get('is_active') else 'غیرفعال'}\n"
    )
    
    keyboard = [
        [InlineKeyboardButton("📱 دریافت کانفیگ", callback_data=f"config_{sub_id}")],
        [InlineKeyboardButton("📊 QR Code", callback_data=f"qr_{sub_id}")],
        [InlineKeyboardButton("🔙 بازگشت", callback_data="back_to_subs")]
    ]
    
    await query.edit_message_text(
        text,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


# ==================== SUPPORT / TICKETS ====================

async def support(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show support menu"""
    departments = list(departments_col.find({"is_active": True}, {"_id": 0}).sort("sort_order", 1))
    
    keyboard = []
    for dept in departments:
        keyboard.append([InlineKeyboardButton(f"📁 {dept['name']}", callback_data=f"dept_{dept['id']}")])
    
    keyboard.append([InlineKeyboardButton("📋 تیکت‌های من", callback_data="my_tickets")])
    
    await update.message.reply_text(
        "🎫 **پشتیبانی**\n\n"
        "برای ارسال تیکت جدید، دپارتمان مورد نظر را انتخاب کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return SELECTING_DEPARTMENT


async def select_department(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle department selection"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "my_tickets":
        return await show_my_tickets(update, context)
    
    dept_id = query.data.replace("dept_", "")
    dept = departments_col.find_one({"id": dept_id})
    
    if not dept:
        await query.edit_message_text("❌ دپارتمان یافت نشد.")
        return ConversationHandler.END
    
    context.user_data["selected_department"] = dept
    
    await query.edit_message_text(
        f"📁 دپارتمان: **{dept['name']}**\n\n"
        "📝 موضوع تیکت را وارد کنید:",
        parse_mode="Markdown"
    )
    return ENTERING_TICKET_SUBJECT


async def enter_ticket_subject(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle ticket subject entry"""
    context.user_data["ticket_subject"] = update.message.text
    
    await update.message.reply_text(
        "📝 حالا متن پیام خود را وارد کنید:"
    )
    return ENTERING_TICKET_MESSAGE


async def enter_ticket_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle ticket message and create ticket"""
    user = get_or_create_user(update.effective_user)
    dept = context.user_data.get("selected_department")
    subject = context.user_data.get("ticket_subject")
    message = update.message.text
    
    import uuid
    ticket_id = str(uuid.uuid4())
    
    ticket = {
        "id": ticket_id,
        "telegram_user_id": user["telegram_id"],
        "department_id": dept["id"],
        "subject": subject,
        "status": "open",
        "priority": "medium",
        "messages": [{
            "id": str(uuid.uuid4()),
            "message": message,
            "is_admin": False,
            "created_at": datetime.utcnow()
        }],
        "last_reply_by": "user",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    tickets_col.insert_one(ticket)
    
    await update.message.reply_text(
        f"✅ **تیکت شما ثبت شد!**\n\n"
        f"🔢 شماره تیکت: `{ticket_id[:8]}`\n"
        f"📁 دپارتمان: {dept['name']}\n"
        f"📋 موضوع: {subject}\n\n"
        "منتظر پاسخ کارشناسان باشید.",
        parse_mode="Markdown"
    )
    return ConversationHandler.END


async def show_my_tickets(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show user's tickets"""
    query = update.callback_query
    user = get_or_create_user(query.from_user)
    
    tickets = list(tickets_col.find(
        {"telegram_user_id": user["telegram_id"]},
        {"_id": 0}
    ).sort("updated_at", -1).limit(10))
    
    if not tickets:
        await query.edit_message_text("❌ شما هنوز تیکتی ندارید.")
        return ConversationHandler.END
    
    keyboard = []
    for ticket in tickets:
        status_icon = {"open": "🟢", "answered": "🔵", "waiting": "🟡", "closed": "⚫"}.get(ticket["status"], "⚪")
        keyboard.append([InlineKeyboardButton(
            f"{status_icon} {ticket['subject'][:30]}",
            callback_data=f"ticket_{ticket['id']}"
        )])
    
    keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data="back_to_support")])
    
    await query.edit_message_text(
        "📋 **تیکت‌های شما:**",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return SELECTING_DEPARTMENT


# ==================== CONTACT ====================

async def contact(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show contact info"""
    settings = get_settings()
    
    text = "📞 **ارتباط با ما**\n\n"
    
    if settings.get("support_username"):
        text += f"👤 پشتیبانی: @{settings['support_username']}\n"
    if settings.get("channel_username"):
        text += f"📢 کانال: @{settings['channel_username']}\n"
    
    await update.message.reply_text(text, parse_mode="Markdown")


# ==================== RESELLER PANEL ====================

async def reseller_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Show reseller panel"""
    user = get_or_create_user(update.effective_user)
    
    if not user.get("is_reseller"):
        await update.message.reply_text("❌ شما نماینده نیستید.")
        return
    
    from pymongo import MongoClient
    resellers_col = db["resellers"]
    reseller = resellers_col.find_one({"telegram_user_id": user["telegram_id"]})
    
    if not reseller:
        await update.message.reply_text("❌ اطلاعات نمایندگی یافت نشد.")
        return
    
    sales = orders_col.count_documents({
        "telegram_user_id": user["telegram_id"],
        "status": "confirmed"
    })
    
    text = (
        "🏪 **پنل نمایندگی**\n\n"
        f"💰 موجودی: {format_price(reseller.get('balance', 0))}\n"
        f"🎁 تخفیف شما: {reseller.get('discount_percent', 0)}%\n"
        f"📊 کل فروش: {reseller.get('total_sales', 0)}\n"
        f"💳 اعتبار: {format_price(reseller.get('credit_limit', 0))}\n"
    )
    
    keyboard = [
        [InlineKeyboardButton("📊 گزارش فروش", callback_data="reseller_report")],
        [InlineKeyboardButton("💰 برداشت موجودی", callback_data="reseller_withdraw")]
    ]
    
    await update.message.reply_text(
        text,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


# ==================== CANCEL HANDLER ====================

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Cancel conversation"""
    user = get_or_create_user(update.effective_user)
    await update.message.reply_text(
        "❌ عملیات لغو شد.",
        reply_markup=get_main_keyboard(user)
    )
    return ConversationHandler.END


# ==================== CALLBACK FOR BUY ====================

async def buy_subscription_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle buy subscription from callback"""
    query = update.callback_query
    user = get_or_create_user(query.from_user)
    
    plans = list(plans_col.find({"is_active": True, "is_test": False}, {"_id": 0}).sort("sort_order", 1))
    
    if not plans:
        await query.edit_message_text("❌ در حال حاضر پلنی موجود نیست.")
        return ConversationHandler.END
    
    keyboard = []
    for plan in plans:
        price = plan["price"]
        if user.get("is_reseller") and user.get("reseller_discount"):
            price = price * (1 - user["reseller_discount"] / 100)
        
        text = f"📦 {plan['name']} | {plan['duration_days']} روز | {format_traffic(plan.get('traffic_gb'))} | {format_price(price)}"
        keyboard.append([InlineKeyboardButton(text, callback_data=f"plan_{plan['id']}")])
    
    keyboard.append([InlineKeyboardButton("❌ انصراف", callback_data="cancel")])
    
    await query.edit_message_text(
        "🛒 **لیست پلن‌های موجود:**\n\nپلن مورد نظر خود را انتخاب کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )
    return SELECTING_PLAN


# ==================== MESSAGE HANDLER ====================

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle text messages"""
    text = update.message.text
    
    if text == "🛒 خرید اشتراک":
        return await buy_subscription(update, context)
    elif text == "👤 حساب کاربری":
        return await user_account(update, context)
    elif text == "💰 کیف پول":
        return await wallet(update, context)
    elif text == "🎫 پشتیبانی":
        return await support(update, context)
    elif text == "📋 اشتراک‌های من":
        return await my_subscriptions(update, context)
    elif text == "📞 ارتباط با ما":
        return await contact(update, context)
    elif text == "🏪 پنل نمایندگی":
        return await reseller_panel(update, context)


def main():
    """Run the bot"""
    settings = get_settings()
    token = settings.get("bot_token")
    
    if not token:
        print("❌ Bot token not set! Please set it in the admin panel.")
        return
    
    application = Application.builder().token(token).build()
    
    # Buy conversation handler
    buy_handler = ConversationHandler(
        entry_points=[
            MessageHandler(filters.Regex("^🛒 خرید اشتراک$"), buy_subscription),
            CallbackQueryHandler(buy_subscription_callback, pattern="^back_to_plans$")
        ],
        states={
            SELECTING_PLAN: [CallbackQueryHandler(select_plan)],
            SELECTING_SERVER: [CallbackQueryHandler(select_server)],
            ENTERING_DISCOUNT: [
                CallbackQueryHandler(handle_discount),
                MessageHandler(filters.TEXT & ~filters.COMMAND, process_discount_code)
            ],
            CONFIRMING_ORDER: [CallbackQueryHandler(confirm_order)],
            UPLOADING_RECEIPT: [MessageHandler(filters.PHOTO, receive_receipt)]
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True
    )
    
    # Support conversation handler
    support_handler = ConversationHandler(
        entry_points=[MessageHandler(filters.Regex("^🎫 پشتیبانی$"), support)],
        states={
            SELECTING_DEPARTMENT: [CallbackQueryHandler(select_department)],
            ENTERING_TICKET_SUBJECT: [MessageHandler(filters.TEXT & ~filters.COMMAND, enter_ticket_subject)],
            ENTERING_TICKET_MESSAGE: [MessageHandler(filters.TEXT & ~filters.COMMAND, enter_ticket_message)]
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True
    )
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(buy_handler)
    application.add_handler(support_handler)
    application.add_handler(CallbackQueryHandler(show_subscription_detail, pattern="^sub_"))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    print("🤖 Bot started!")
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
