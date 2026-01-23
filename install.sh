#!/bin/bash

# V2Ray Sales Bot - Automatic Installation Script
# This script installs and configures the V2Ray sales bot with admin panel

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           ربات فروش V2Ray - اسکریپت نصب خودکار              ║"
echo "║                  V2Ray Sales Bot Installer                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}[۱/۶] بررسی پیش‌نیازها...${NC}"

# Check Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d ' ' -f 2)
    echo -e "${GREEN}✓ Python نصب شده: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 یافت نشد. در حال نصب...${NC}"
    apt-get update && apt-get install -y python3 python3-pip python3-venv
fi

# Check Node.js
if command_exists node; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js نصب شده: $NODE_VERSION${NC}"
else
    echo -e "${RED}✗ Node.js یافت نشد. در حال نصب...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Check MongoDB
if command_exists mongod; then
    echo -e "${GREEN}✓ MongoDB نصب شده${NC}"
else
    echo -e "${RED}✗ MongoDB یافت نشد. در حال نصب...${NC}"
    apt-get install -y gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update && apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
fi

# Get configuration from user
echo ""
echo -e "${YELLOW}[۲/۶] دریافت اطلاعات پیکربندی...${NC}"

read -p "نام دامنه یا IP سرور (مثال: panel.example.com): " DOMAIN
read -p "پورت پنل وب (پیش‌فرض: 3000): " WEB_PORT
WEB_PORT=${WEB_PORT:-3000}
read -p "پورت API (پیش‌فرض: 8001): " API_PORT
API_PORT=${API_PORT:-8001}
read -p "توکن ربات تلگرام (می‌توانید بعداً از پنل وارد کنید): " BOT_TOKEN
read -p "شماره کارت برای پرداخت: " CARD_NUMBER
read -p "نام صاحب حساب: " CARD_HOLDER

# Create installation directory
echo ""
echo -e "${YELLOW}[۳/۶] ایجاد پوشه‌ها و فایل‌ها...${NC}"

INSTALL_DIR="/opt/v2ray-bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Create backend directory and files
mkdir -p backend frontend

# Create backend .env
cat > backend/.env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=v2ray_bot
JWT_SECRET=$(openssl rand -hex 32)
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24
BOT_TOKEN=$BOT_TOKEN
EOF

echo -e "${GREEN}✓ فایل تنظیمات بک‌اند ایجاد شد${NC}"

# Create frontend .env
cat > frontend/.env << EOF
REACT_APP_BACKEND_URL=http://$DOMAIN:$API_PORT
EOF

echo -e "${GREEN}✓ فایل تنظیمات فرانت‌اند ایجاد شد${NC}"

# Install Python dependencies
echo ""
echo -e "${YELLOW}[۴/۶] نصب وابستگی‌های پایتون...${NC}"

cd backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn pymongo python-jose passlib python-multipart pydantic python-dotenv httpx python-telegram-bot

echo -e "${GREEN}✓ وابستگی‌های پایتون نصب شدند${NC}"

# Create systemd service for backend
echo ""
echo -e "${YELLOW}[۵/۶] پیکربندی سرویس‌ها...${NC}"

cat > /etc/systemd/system/v2ray-bot-api.service << EOF
[Unit]
Description=V2Ray Bot API
After=network.target mongodb.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/backend
Environment=PATH=$INSTALL_DIR/backend/venv/bin
ExecStart=$INSTALL_DIR/backend/venv/bin/uvicorn server:app --host 0.0.0.0 --port $API_PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/v2ray-telegram-bot.service << EOF
[Unit]
Description=V2Ray Telegram Bot
After=network.target mongodb.service v2ray-bot-api.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/backend
Environment=PATH=$INSTALL_DIR/backend/venv/bin
ExecStart=$INSTALL_DIR/backend/venv/bin/python telegram_bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable v2ray-bot-api
systemctl start v2ray-bot-api

echo -e "${GREEN}✓ سرویس API راه‌اندازی شد${NC}"

# Update bot settings in database
echo ""
echo -e "${YELLOW}[۶/۶] ذخیره تنظیمات در دیتابیس...${NC}"

python3 << PYTHON
from pymongo import MongoClient
client = MongoClient("mongodb://localhost:27017")
db = client["v2ray_bot"]
db.bot_settings.update_one(
    {"id": "bot_settings"},
    {"\$set": {
        "bot_token": "$BOT_TOKEN",
        "card_number": "$CARD_NUMBER",
        "card_holder": "$CARD_HOLDER"
    }},
    upsert=True
)
print("Settings saved to database")
PYTHON

echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              نصب با موفقیت انجام شد!                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${BLUE}اطلاعات دسترسی:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "پنل مدیریت: ${GREEN}http://$DOMAIN:$WEB_PORT${NC}"
echo -e "API: ${GREEN}http://$DOMAIN:$API_PORT${NC}"
echo -e "نام کاربری: ${YELLOW}admin${NC}"
echo -e "رمز عبور: ${YELLOW}admin${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}توجه: لطفاً رمز عبور پیش‌فرض را تغییر دهید!${NC}"
echo ""
echo -e "${BLUE}دستورات مفید:${NC}"
echo "systemctl status v2ray-bot-api    # وضعیت API"
echo "systemctl restart v2ray-bot-api   # ری‌استارت API"
echo "journalctl -u v2ray-bot-api -f    # مشاهده لاگ‌ها"
echo ""
