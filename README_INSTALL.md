# 🛡️ WireGuard Panel - Auto Install Script

[English](#english) | [فارسی](#فارسی)

---

## English

### Quick Install

Run this single command on your server:

```bash
sudo bash setup.sh
```

### What it does:

1. **Asks for configuration:**
   - Panel admin username (default: admin)
   - Panel admin password (default: admin)
   - Panel web port (default: 80)

2. **Installs prerequisites:**
   - Docker & Docker Compose
   - WireGuard
   - Required system packages

3. **Creates all files:**
   - Backend (Python FastAPI)
   - Frontend (React)
   - Docker configurations
   - Nginx config

4. **Sets up WireGuard:**
   - Creates wg0 interface
   - Configures IP forwarding
   - Generates server keys

5. **Starts the panel:**
   - MongoDB database
   - Backend API
   - Frontend web interface

### After Installation

Access the panel at: `http://YOUR_SERVER_IP:PORT`

### Management Commands

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

### Requirements

- Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Rocky Linux 8+
- Root access (sudo)
- Ports: 80 (web), 51820/UDP (WireGuard)

---

## فارسی

### نصب سریع

این دستور را روی سرور خود اجرا کنید:

```bash
sudo bash setup.sh
```

### این اسکریپت چه کاری انجام می‌دهد:

1. **پرسش تنظیمات:**
   - نام کاربری ادمین پنل (پیش‌فرض: admin)
   - رمز عبور ادمین پنل (پیش‌فرض: admin)
   - پورت وب پنل (پیش‌فرض: 80)

2. **نصب پیش‌نیازها:**
   - Docker و Docker Compose
   - WireGuard
   - بسته‌های سیستمی مورد نیاز

3. **ایجاد همه فایل‌ها:**
   - بک‌اند (Python FastAPI)
   - فرانت‌اند (React)
   - تنظیمات Docker
   - تنظیمات Nginx

4. **راه‌اندازی WireGuard:**
   - ایجاد اینترفیس wg0
   - پیکربندی IP forwarding
   - تولید کلیدهای سرور

5. **شروع پنل:**
   - دیتابیس MongoDB
   - API بک‌اند
   - رابط کاربری وب

### بعد از نصب

به پنل دسترسی پیدا کنید در: `http://IP_سرور:پورت`

### دستورات مدیریت

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

### نیازمندی‌ها

- Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Rocky Linux 8+
- دسترسی root (sudo)
- پورت‌ها: 80 (وب)، 51820/UDP (WireGuard)

---

## 📝 License

MIT License - Free to use and modify.

## 🤝 Support

For issues and feature requests, please open an issue on GitHub.
