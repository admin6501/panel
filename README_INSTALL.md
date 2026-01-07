# 🛡️ WireGuard Panel - Auto Install Script v3.0

[English](#english) | [فارسی](#فارسی)

---

## فارسی

### نصب سریع با یک دستور

این اسکریپت **همه چیز** را خودش از صفر ایجاد می‌کند و نصب می‌کند:

```bash
# دانلود و اجرا
wget -O setup.sh https://raw.githubusercontent.com/YOUR_REPO/setup.sh
chmod +x setup.sh
sudo bash setup.sh
```

یا اگر فایل را دارید:
```bash
sudo bash setup.sh
```

### در حین نصب از شما می‌پرسد:

1. **نام کاربری ادمین** - برای ورود به پنل (پیش‌فرض: admin)
2. **رمز عبور ادمین** - رمز ورود به پنل (پیش‌فرض: admin)
3. **پورت پنل** - پورت وب پنل (پیش‌فرض: 80)

### این اسکریپت چه کارهایی انجام می‌دهد:

✅ **نصب پیش‌نیازها:**
- Docker و Docker Compose
- WireGuard
- بسته‌های سیستمی مورد نیاز

✅ **ایجاد همه فایل‌ها از صفر:**
- بک‌اند کامل (Python FastAPI)
- فرانت‌اند کامل (React + TailwindCSS)
- تنظیمات Docker
- تنظیمات Nginx
- فایل‌های زبان فارسی و انگلیسی

✅ **راه‌اندازی خودکار:**
- اینترفیس WireGuard (wg0)
- IP Forwarding
- فایروال

✅ **شروع سرویس‌ها:**
- MongoDB
- Backend API
- Frontend Web

### بعد از نصب:

📌 **آدرس پنل:** `http://IP_سرور:پورت`

📌 **اطلاعات ورود:** یوزرنیم و پسوردی که در حین نصب وارد کردید

### دستورات مدیریت:

```bash
cd /opt/wireguard-panel

# شروع پنل
docker compose up -d

# توقف پنل
docker compose down

# ریستارت پنل
docker compose restart

# مشاهده لاگ‌ها
docker compose logs -f

# آپدیت پنل
docker compose up -d --build
```

### نیازمندی‌ها:

- سیستم‌عامل: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Rocky Linux 8+
- دسترسی root (sudo)
- پورت‌ها: 80 (وب)، 51820/UDP (WireGuard)
- حداقل 1GB RAM

---

## English

### Quick One-Command Install

This script creates **everything** from scratch and installs:

```bash
# Download and run
wget -O setup.sh https://raw.githubusercontent.com/YOUR_REPO/setup.sh
chmod +x setup.sh
sudo bash setup.sh
```

Or if you have the file:
```bash
sudo bash setup.sh
```

### During installation, you'll be asked for:

1. **Admin username** - for panel login (default: admin)
2. **Admin password** - panel password (default: admin)
3. **Panel port** - web panel port (default: 80)

### What this script does:

✅ **Installs prerequisites:**
- Docker & Docker Compose
- WireGuard
- Required system packages

✅ **Creates all files from scratch:**
- Complete Backend (Python FastAPI)
- Complete Frontend (React + TailwindCSS)
- Docker configurations
- Nginx configuration
- Persian & English language files

✅ **Auto-configures:**
- WireGuard interface (wg0)
- IP Forwarding
- Firewall rules

✅ **Starts services:**
- MongoDB database
- Backend API
- Frontend Web

### After installation:

📌 **Panel URL:** `http://YOUR_SERVER_IP:PORT`

📌 **Login:** Use the username and password you entered during installation

### Management commands:

```bash
cd /opt/wireguard-panel

# Start panel
docker compose up -d

# Stop panel
docker compose down

# Restart panel
docker compose restart

# View logs
docker compose logs -f

# Update panel
docker compose up -d --build
```

### Requirements:

- OS: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Rocky Linux 8+
- Root access (sudo)
- Ports: 80 (web), 51820/UDP (WireGuard)
- Minimum 1GB RAM

---

## 📝 Features

- ✅ Fully self-contained - no external file downloads
- ✅ Interactive installation with user input
- ✅ Persian & English interface
- ✅ Dark modern UI
- ✅ Client management with QR codes
- ✅ Auto-renewal support
- ✅ Subscription page for users
- ✅ Data & time limits
- ✅ Start timer on first connection
- ✅ Multi-user support with roles

## 📄 License

MIT License - Free to use and modify.
