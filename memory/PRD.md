# V2Ray Sales Bot - PRD

## Problem Statement
ساخت ربات تلگرام فروش کانفیگ V2Ray با پنل مدیریت وب - درگاه کارت به کارت با تأیید دستی - اتصال به پنل سنایی - سیستم تیکت با دپارتمان - سیستم نمایندگی کامل - کد تخفیف - کلیه قابلیت‌های پیشرفته

## Architecture
- **Backend**: FastAPI + MongoDB
- **Frontend**: React + Tailwind CSS
- **Telegram Bot**: python-telegram-bot library
- **Database**: MongoDB

## User Personas
1. **Admin/Super Admin**: مدیر کل سیستم - دسترسی کامل به همه بخش‌ها
2. **Support**: پشتیبانی - دسترسی به تیکت‌ها و مشاهده کاربران
3. **Telegram User**: کاربر ربات تلگرام - خرید، پشتیبانی، کیف پول
4. **Reseller**: نماینده - خرید با تخفیف، پنل نمایندگی

## Core Requirements (Static)
- [x] پنل مدیریت وب با رابط کاربری فارسی RTL
- [x] سیستم احراز هویت JWT
- [x] مدیریت سرورها (اتصال به پنل سنایی)
- [x] مدیریت پلن‌ها و قیمت‌گذاری
- [x] سیستم سفارشات
- [x] درگاه کارت به کارت با تأیید دستی
- [x] کدهای تخفیف
- [x] سیستم تیکت با دپارتمان‌ها
- [x] سیستم نمایندگی کامل
- [x] داشبورد با آمار و نمودار

## What's Been Implemented (Jan 23, 2026)

### Backend (FastAPI)
- Auth endpoints (login, me, change-password)
- Admin management CRUD
- Server management CRUD + test connection
- Plan management CRUD
- Order management with filters
- Payment management with approve/reject
- Discount codes CRUD
- Department CRUD
- Ticket system with replies and status
- Reseller management CRUD
- User management (ban, wallet)
- Bot settings management
- Dashboard stats and charts
- Telegram bot handlers (buy, support, wallet, account)

### Frontend (React)
- Login page with dark theme
- Dashboard with stats cards and charts (revenue, orders)
- Users list with search and filters
- Servers management
- Plans management
- Orders list
- Payments with approve/reject modal
- Discount codes management
- Tickets with conversation view
- Resellers management
- Settings with 5 tabs (bot, payment, messages, referral, departments)

### Telegram Bot
- /start command with welcome message
- Buy subscription flow (plan → server → discount → payment)
- Card-to-card payment with receipt upload
- User account info
- Wallet management
- Support ticket system with departments
- Reseller panel

## Prioritized Backlog

### P0 (Critical)
- ✅ Core functionality implemented

### P1 (Important)
- [ ] Integration with actual Sanei Panel API for config generation
- [ ] File upload for payment receipts storage
- [ ] Broadcast messages to users
- [ ] Subscription link and QR code generation

### P2 (Nice to Have)
- [ ] Advanced analytics and reports
- [ ] Export data to Excel
- [ ] Automated payment verification (SMS parsing)
- [ ] Multi-language support
- [ ] User verification (phone number)

## Next Tasks
1. Test with real Telegram bot token
2. Integrate with actual Sanei Panel for config creation
3. Add file storage for payment receipts
4. Implement broadcast messaging
5. Add subscription status page for users
