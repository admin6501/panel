# 🛡️ WireGuard Panel

یک پنل مدیریت WireGuard VPN کامل با قابلیت‌های پیشرفته

## ✨ ویژگی‌ها

### 🔐 سیستم احراز هویت
- سه سطح دسترسی: Super Admin، Admin، Viewer
- مدیریت چندین کاربر با سطوح مختلف
- احراز هویت JWT امن

### 👥 مدیریت کلاینت‌ها
- ایجاد، ویرایش، حذف کلاینت‌ها
- محدودیت حجم دانلود (Data Limit)
- محدودیت زمانی (Expiry Date)
- تولید QR Code برای اسکن با اپ WireGuard
- دانلود فایل کانفیگ
- فعال/غیرفعال کردن کلاینت‌ها
- **ریست مصرف داده**
- **تمدید زمان (۳۰ روز)**
- **حذف محدودیت زمان**

### 📊 داشبورد
- نمایش آمار کلی کلاینت‌ها
- وضعیت آنلاین/آفلاین
- مصرف کل داده
- وضعیت سیستم و WireGuard

### 🌍 دو زبانه
- فارسی (RTL)
- انگلیسی (LTR)

### 📱 ریسپانسیو
- طراحی کاملاً ریسپانسیو برای موبایل، تبلت و دسکتاپ

### 🔒 SSL Support
- پشتیبانی از SSL با Let's Encrypt
- نصب خودکار SSL
- Redirect از HTTP به HTTPS

## 🚀 نصب سریع

### پیش‌نیازها
- سرور با Ubuntu 20.04+ یا Debian 10+ یا CentOS 7+
- دسترسی Root
- (اختیاری) دامنه برای SSL

### نصب با یک دستور

```bash
bash <(curl -Ls https://raw.githubusercontent.com/your-repo/wireguard-panel/main/install.sh)
```

یا دانلود و اجرا:

```bash
wget -O install.sh https://raw.githubusercontent.com/your-repo/wireguard-panel/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### مراحل نصب

1. اسکریپت از شما می‌پرسد آیا دامنه دارید یا خیر
2. اگر دامنه دارید، وارد کنید تا SSL گرفته شود
3. WireGuard به صورت خودکار نصب و کانفیگ می‌شود
4. Endpoint پیش‌فرض در پنل تنظیم می‌شود
5. پنل با Docker بالا می‌آید

## 🐳 نصب دستی با Docker

### 1. کلون کردن پروژه

```bash
git clone https://github.com/your-repo/wireguard-panel.git
cd wireguard-panel
```

### 2. اجرای اسکریپت نصب

```bash
chmod +x install.sh
sudo ./install.sh
```

## ⚙️ تنظیمات

### متغیرهای محیطی

| متغیر | توضیح | پیش‌فرض |
|-------|-------|---------|
| MONGO_URL | آدرس MongoDB | mongodb://localhost:27017 |
| DB_NAME | نام دیتابیس | wireguard_panel |
| JWT_SECRET | کلید رمزنگاری JWT | - |
| WG_INTERFACE | نام اینترفیس WireGuard | wg0 |
| WG_PORT | پورت WireGuard | 51820 |
| WG_NETWORK | شبکه WireGuard | 10.0.0.0/24 |
| DEFAULT_ENDPOINT | آدرس سرور | - |
| SERVER_PUBLIC_KEY | کلید عمومی سرور | - |

## 📝 استفاده

### اولین ورود

1. به آدرس پنل بروید: `http://your-server-ip` یا `https://your-domain`
2. با اطلاعات پیش‌فرض وارد شوید:
   - نام کاربری: `admin`
   - رمز عبور: `admin`
3. **فوراً رمز عبور را تغییر دهید!**

### مدیریت کلاینت‌ها

| عملیات | توضیح |
|--------|-------|
| افزودن کلاینت | ساخت کلاینت جدید با محدودیت دلخواه |
| دانلود کانفیگ | دریافت فایل .conf |
| نمایش QR | اسکن با اپ موبایل |
| ریست مصرف داده | صفر کردن مصرف |
| تمدید ۳۰ روز | افزودن ۳۰ روز به تاریخ انقضا |
| حذف محدودیت زمان | حذف تاریخ انقضا |
| غیرفعال/فعال | قطع/وصل دسترسی |

## 🔧 دستورات مفید

### مشاهده لاگ‌ها

```bash
cd /opt/wireguard-panel
docker compose logs -f
```

### ریستارت

```bash
cd /opt/wireguard-panel
docker compose restart
```

### بروزرسانی

```bash
cd /opt/wireguard-panel
docker compose pull
docker compose up -d --build
```

### وضعیت WireGuard

```bash
wg show
```

### تمدید SSL

```bash
certbot renew
```

## 🏗️ ساختار پروژه

```
wireguard-panel/
├── backend/
│   ├── server.py        # FastAPI main app
│   ├── models.py        # Data models
│   ├── auth.py          # Authentication
│   ├── wireguard.py     # WireGuard manager
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/  # React components
│   │   ├── pages/       # Page components
│   │   ├── contexts/    # React contexts
│   │   ├── i18n/        # Translations
│   │   └── utils/       # Utility functions
│   └── package.json
├── docker/
│   ├── Dockerfile.backend
│   ├── Dockerfile.frontend
│   ├── nginx.conf
│   └── docker-compose.yml
└── install.sh           # Auto installer with SSL support
```

## 🔒 امنیت

- همه رمزهای عبور با bcrypt هش می‌شوند
- توکن‌های JWT با الگوریتم HS256 رمزنگاری می‌شوند
- SSL/TLS با Let's Encrypt
- دسترسی‌ها بر اساس نقش کاربر کنترل می‌شوند

## 📄 API Documentation

### Authentication

```bash
# Login
POST /api/auth/login
Body: {"username": "admin", "password": "admin"}

# Get current user
GET /api/auth/me
Header: Authorization: Bearer <token>
```

### Clients

```bash
# List clients
GET /api/clients

# Create client
POST /api/clients
Body: {"name": "...", "data_limit": 1073741824, "expiry_date": "2025-02-01"}

# Reset data usage
POST /api/clients/{id}/reset-data

# Extend expiry
POST /api/clients/{id}/reset-expiry?days=30

# Remove expiry
POST /api/clients/{id}/remove-expiry
```

## 📞 پشتیبانی

در صورت بروز مشکل، یک Issue در GitHub ایجاد کنید.

---

ساخته شده با ❤️
