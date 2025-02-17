#!/bin/bash

# Update and upgrade system
apt update -y && apt upgrade -y

while true; do
    clear
    echo "====================="
    echo "   Server Management Menu"
    echo "====================="
    echo "1) Install X-UI Panel (Sanaei)"
    echo "2) Install Hysteria 2 Panel"
    echo "3) Get SSL Certificate"
    echo "4) Install SUI Panel (Alireza)"
    echo "5) Install Marzban Panel"
    echo "6) Exit"
    echo "====================="
    read -p "Please choose an option [1-6]: " choice

    case $choice in
        1)
            echo "Installing X-UI Panel..."
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
            ;;
        2)
            echo "Installing Hysteria 2 Panel..."
            bash <(curl https://raw.githubusercontent.com/ReturnFI/Hysteria2/main/install.sh)
            ;;
        3)
            read -p "Enter your domain name (e.g., example.com): " domain
            apt install certbot -y
            certbot certonly --standalone -d "$domain"
            ;;
        4)
            echo "Installing SUI Panel (Alireza)..."
            bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)
            ;;
        5)
            echo "Installing Marzban Panel..."
            sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option! Please choose between 1 and 6."
            sleep 2
            ;;
    esac
done
