#!/bin/bash

while true; do
    clear
    echo "User Management Menu"
    echo "1) Add User"
    echo "2) Delete User"
    echo "3) Change User Password"
    echo "4) Add User to sudo group"
    echo "5) Remove User from sudo group"
    echo "6) Exit"
    read -p "Choose an option [1-6]: " option

    case $option in
        1)
            read -p "Enter the username to add: " username
            if id "$username" &>/dev/null; then
                echo "User '$username' already exists."
            else
                adduser "$username"
                echo "User '$username' added successfully."
            fi
            read -p "Press Enter to continue..."
            ;;

        2)
            read -p "Enter the username to delete: " username
            if id "$username" &>/dev/null; then
                deluser --remove-home "$username"
                echo "User '$username' deleted successfully."
            else
                echo "User '$username' does not exist."
            fi
            read -p "Press Enter to continue..."
            ;;

        3)
            read -p "Enter the username to change password: " username
            if id "$username" &>/dev/null; then
                passwd "$username"
            else
                echo "User '$username' does not exist."
            fi
            read -p "Press Enter to continue..."
            ;;

        4)
            read -p "Enter the username to add to sudo group: " username
            if id "$username" &>/dev/null; then
                usermod -aG sudo "$username"
                echo "User '$username' added to sudo group."
            else
                echo "User '$username' does not exist."
            fi
            read -p "Press Enter to continue..."
            ;;

        5)
            read -p "Enter the username to remove from sudo group: " username
            if id "$username" &>/dev/null; then
                deluser "$username" sudo
                echo "User '$username' removed from sudo group."
            else
                echo "User '$username' does not exist."
            fi
            read -p "Press Enter to continue..."
            ;;

        6)
            echo "Exiting..."
            break
            ;;

        *)
            echo "Invalid option. Please choose between 1 and 6."
            read -p "Press Enter to continue..."
            ;;
    esac
done
