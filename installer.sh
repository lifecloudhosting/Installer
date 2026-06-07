#!/usr/bin/env bash

# Color codes
CYAN='\e[36m'
YELLOW='\e[33m'
RED='\e[31m'
GREEN='\e[32m'
ENDCOLOR='\e[0m'
BOLD='\e[1m'

# Functions to control Ctrl+C / Ctrl+Z
enable_menu_lock() {
    # Disable Ctrl+C and Ctrl+Z (only for menu)
    trap '' INT
    trap '' TSTP
}

disable_menu_lock() {
    # Restore default behavior (Ctrl+C etc. works normally)
    trap - INT
    trap - TSTP
}

# Lifecloud Installer logo (shown for 2 seconds)
echo -e "${YELLOW}${BOLD}"
cat << "EOF"
 _       _________ _______  _______  _______  _        _______           ______
( \      \__   __/(  ____ \(  ____ \(  ____ \( \      (  ___  )|\     /|(  __  \
| (         ) (   | (    \/| (    \/| (    \/| (      | (   ) || )   ( || (  \  )
| |         | |   | (__    | (__    | |      | |      | |   | || |   | || |   ) |
| |         | |   |  __)   |  __)   | |      | |      | |   | || |   | || |   | |
| |         | |   | (      | (      | |      | |      | |   | || |   | || |   ) |
| (____/\___) (___| )      | (____/\| (____/\| (____/\| (___) || (___) || (__/  )
(_______/\_______/|/       (_______/(_______/(_______/(_______)(_______)(______/

_________ _        _______ _________ _______  _        _        _______  _______
\__   __/( (    /|(  ____ \\__   __/(  ___  )( \      ( \      (  ____ \(  ____ )
   ) (   |  \  ( || (    \/   ) (   | (   ) || (      | (      | (    \/| (    )|
   | |   |   \ | || (_____    | |   | (___) || |      | |      | (__    | (____)|
   | |   | (\ \) |(_____  )   | |   |  ___  || |      | |      |  __)   |     __)
   | |   | | \   |      ) |   | |   | (   ) || |      | |      | (      | (\ (
___) (___| )  \  |/\____) |   | |   | )   ( || (____/\| (____/\| (____/\| ) \ \__
\_______/|/    )_)\_______)   )_(   |/     \|(_______/(_______/(_______/|/   \__/
EOF
echo -e "${ENDCOLOR}"
sleep 2
clear

show_main_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
███╗   ███╗███████╗███╗   ██╗██╗   ██╗
████╗ ████║██╔════╝████╗  ██║██║   ██║
██╔████╔██║█████╗  ██╔██╗ ██║██║   ██║
██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║   ██║
██║ ╚═╝ ██║███████╗██║ ╚████║╚██████╔╝
╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝
EOF
    echo -e "${ENDCOLOR}"
}

show_main_banner

while true; do
    # Yahan sirf MENU ke liye Ctrl+C disable
    enable_menu_lock

    echo -e "${GREEN}0) Install Pterodactyl Panel + Wings${ENDCOLOR}"
    echo -e "${YELLOW}1) Install Cloudflared${ENDCOLOR}"
    echo -e "${CYAN}2) Install Playit.gg${ENDCOLOR}"
    echo -e "${RED}3) Exit${ENDCOLOR}"
    echo -e "${CYAN}Select an option [0-3]:${ENDCOLOR}"
    read -r choice

    # User ne choice select kar li -> ab installers ke liye Ctrl+C wapas normal
    disable_menu_lock

    case "$choice" in
        0)
            echo -e "${GREEN}Running Pterodactyl installation...${ENDCOLOR}"
            bash <(curl -s https://pterodactyl-installer.se/)
            # Installer se nikal ke wapas menu banner
            clear
            show_main_banner
            ;;

        1)
            echo -e "${YELLOW}${BOLD}Adding Cloudflare gpg key...${ENDCOLOR}"
            sudo mkdir -p --mode=0755 /usr/share/keyrings >/dev/null 2>&1
            curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
              | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null 2>&1

            echo -e "${YELLOW}Adding Cloudflared repo to your apt repositories...${ENDCOLOR}"
            echo "deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main" \
              | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null 2>&1

            echo -e "${YELLOW}Installing cloudflared...${ENDCOLOR}"
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y cloudflared >/dev/null 2>&1

            echo -e "${GREEN}${BOLD}Cloudflared installation completed!${ENDCOLOR}"
            sleep 2
            clear
            show_main_banner
            ;;

        2)
            echo -e "${YELLOW}Installing Playit.gg...${ENDCOLOR}"
            curl -SsL https://playit-cloud.github.io/ppa/key.gpg \
              | gpg --dearmor \
              | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
            echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" \
              | sudo tee /etc/apt/sources.list.d/playit-cloud.list >/dev/null

            sudo apt update >/dev/null 2>&1
            sudo apt install -y playit >/dev/null 2>&1

            echo -e "${GREEN}${BOLD}Playit.gg installation completed!${ENDCOLOR}"
            echo -e "${YELLOW}Starting Playit client...${ENDCOLOR}"
            # Yahan Ctrl+C allowed hai, user Playit se normal bahar aa sakta hai
            playit
            echo -e "${GREEN}${BOLD}Playit session finished. Returning to menu...${ENDCOLOR}"
            read -rp "Press Enter to continue..."
            clear
            show_main_banner
            ;;

        3)
            echo -e "${RED}Exiting.${ENDCOLOR}"
            exit 0
            ;;

        *)
            echo -e "${RED}Invalid option. Please select 0, 1, 2, or 3.${ENDCOLOR}"
            ;;
    esac
done
