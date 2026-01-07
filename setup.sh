#!/bin/bash

# ===========================================
# WireGuard Panel - Auto Install Script v4.0
# ===========================================
# This script creates all files and installs the panel
# یک اسکریپت که همه چیز را ایجاد و نصب می‌کند
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables
INSTALL_DIR="/opt/wireguard-panel"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
SCRIPT_VERSION="4.0"

# Default values - will be asked from user
PANEL_USERNAME="admin"
PANEL_PASSWORD="admin"
PANEL_PORT="80"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🛡️  WireGuard Panel Manager v${SCRIPT_VERSION}  🛡️              ║"
    echo "║                                                           ║"
    echo "║     A Modern VPN Management System                        ║"
    echo "║     پنل مدیریت وایرگارد                                   ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)"
        print_error "این اسکریپت باید با دسترسی root اجرا شود"
        exit 1
    fi
}

# Check if panel is installed
is_installed() {
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

# Show main menu
show_menu() {
    print_banner
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    Main Menu / منوی اصلی                  ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if is_installed; then
        echo -e "  ${GREEN}●${NC} Panel Status: ${GREEN}Installed${NC} / ${GREEN}نصب شده${NC}"
        echo ""
    else
        echo -e "  ${RED}●${NC} Panel Status: ${RED}Not Installed${NC} / ${RED}نصب نشده${NC}"
        echo ""
    fi
    
    echo -e "  ${CYAN}1)${NC} Install Panel          ${CYAN}نصب پنل${NC}"
    echo -e "  ${GREEN}2)${NC} Start Panel            ${GREEN}شروع پنل${NC}"
    echo -e "  ${YELLOW}3)${NC} Stop Panel             ${YELLOW}توقف پنل${NC}"
    echo -e "  ${BLUE}4)${NC} Restart Panel          ${BLUE}ری‌استارت پنل${NC}"
    echo -e "  ${PURPLE}5)${NC} Update Panel           ${PURPLE}آپدیت پنل (بدون حذف دیتا)${NC}"
    echo -e "  ${WHITE}6)${NC} View Logs              ${WHITE}مشاهده لاگ‌ها${NC}"
    echo -e "  ${WHITE}7)${NC} Panel Status           ${WHITE}وضعیت پنل${NC}"
    echo -e "  ${RED}8)${NC} Uninstall Panel        ${RED}حذف کامل پنل${NC}"
    echo -e "  ${NC}0)${NC} Exit                   ${NC}خروج${NC}"
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Start panel
start_panel_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        print_info "Please install the panel first (Option 1)"
        return 1
    fi
    
    print_info "Starting panel... / شروع پنل..."
    cd $INSTALL_DIR
    docker compose up -d
    
    sleep 3
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel started successfully! / پنل با موفقیت شروع شد!"
        show_panel_info
    else
        print_error "Failed to start panel / خطا در شروع پنل"
        print_info "Check logs with: docker compose logs"
    fi
}

# Stop panel
stop_panel_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    print_info "Stopping panel... / توقف پنل..."
    cd $INSTALL_DIR
    docker compose down
    print_success "Panel stopped successfully! / پنل با موفقیت متوقف شد!"
}

# Restart panel
restart_panel_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    print_info "Restarting panel... / ری‌استارت پنل..."
    cd $INSTALL_DIR
    docker compose restart
    
    sleep 3
    print_success "Panel restarted successfully! / پنل با موفقیت ری‌استارت شد!"
    show_panel_info
}

# Update panel (without removing data)
update_panel_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    print_warning "This will update the panel without removing your data."
    print_warning "این عملیات پنل را بدون حذف اطلاعات آپدیت می‌کند."
    echo ""
    echo -e "${YELLOW}Press Enter to continue or 'n' to cancel${NC}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        print_info "Update cancelled. / آپدیت لغو شد."
        return 0
    fi
    
    print_info "Updating panel... / آپدیت پنل..."
    cd $INSTALL_DIR
    
    # Stop containers
    docker compose down
    
    # Rebuild and start (keeps volumes/data)
    docker compose up -d --build
    
    sleep 5
    
    if docker ps | grep -q wireguard-panel-frontend; then
        print_success "Panel updated successfully! / پنل با موفقیت آپدیت شد!"
        print_success "Your data has been preserved. / اطلاعات شما حفظ شده است."
        show_panel_info
    else
        print_error "Update failed / آپدیت ناموفق بود"
        print_info "Check logs with: docker compose logs"
    fi
}

# View logs
view_logs_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    print_info "Showing logs (Press Ctrl+C to exit)... / نمایش لاگ‌ها..."
    cd $INSTALL_DIR
    docker compose logs -f --tail=100
}

# Panel status
panel_status_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    print_info "Panel Status / وضعیت پنل:"
    echo ""
    cd $INSTALL_DIR
    docker compose ps
    echo ""
    show_panel_info
}

# Show panel info
show_panel_info() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        source $INSTALL_DIR/.env 2>/dev/null || true
    fi
    
    SERVER_IP=$(get_server_ip)
    CURRENT_PORT=$(grep -oP '^\s*-\s*"\K[0-9]+(?=:80")' $INSTALL_DIR/docker-compose.yml 2>/dev/null || echo "80")
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Panel Information                       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Panel URL: ${GREEN}http://$SERVER_IP:$CURRENT_PORT${NC}"
    echo -e "  WireGuard Port: ${GREEN}51820/UDP${NC}"
    echo ""
}

# Uninstall panel
uninstall_panel_service() {
    if ! is_installed; then
        print_error "Panel is not installed! / پنل نصب نشده است!"
        return 1
    fi
    
    echo ""
    print_warning "⚠️  WARNING: This will completely remove the panel and ALL data!"
    print_warning "⚠️  هشدار: این عملیات پنل و تمام اطلاعات را حذف می‌کند!"
    echo ""
    echo -e "${RED}Type 'DELETE' to confirm / برای تأیید 'DELETE' تایپ کنید:${NC}"
    read -r CONFIRM
    
    if [ "$CONFIRM" != "DELETE" ]; then
        print_info "Uninstall cancelled. / حذف لغو شد."
        return 0
    fi
    
    print_info "Uninstalling panel... / حذف پنل..."
    
    cd $INSTALL_DIR
    
    # Stop and remove containers, volumes, networks
    docker compose down -v --remove-orphans 2>/dev/null || true
    
    # Remove images
    docker rmi wireguard-panel-frontend wireguard-panel-backend 2>/dev/null || true
    
    # Remove installation directory
    rm -rf $INSTALL_DIR
    
    print_success "Panel uninstalled successfully! / پنل با موفقیت حذف شد!"
    print_info "WireGuard interface (wg0) was NOT removed."
    print_info "To remove WireGuard: wg-quick down wg0"
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$SERVER_IP"
}

# Main menu loop
main_menu() {
    while true; do
        show_menu
        echo -e "${CYAN}Please select an option / لطفا یک گزینه انتخاب کنید:${NC}"
        read -p "> " choice
        
        case $choice in
            1)
                echo "Install functionality would be here..."
                read -p "Press Enter to continue..."
                ;;
            2)
                start_panel_service
                read -p "Press Enter to continue..."
                ;;
            3)
                stop_panel_service
                read -p "Press Enter to continue..."
                ;;
            4)
                restart_panel_service
                read -p "Press Enter to continue..."
                ;;
            5)
                update_panel_service
                read -p "Press Enter to continue..."
                ;;
            6)
                view_logs_service
                ;;
            7)
                panel_status_service
                read -p "Press Enter to continue..."
                ;;
            8)
                uninstall_panel_service
                read -p "Press Enter to continue..."
                ;;
            0)
                print_info "Goodbye! / خداحافظ!"
                exit 0
                ;;
            *)
                print_error "Invalid option / گزینه نامعتبر"
                sleep 2
                ;;
        esac
    done
}

# Check if running as root
check_root

# Start main menu
main_menu