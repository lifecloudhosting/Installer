#!/usr/bin/env bash

# Color codes
CYAN='\e[36m'
YELLOW='\e[33m'
RED='\e[31m'
GREEN='\e[32m'
ENDCOLOR='\e[0m'
BOLD='\e[1m'

# Functions to control Ctrl+C / Ctrl+Z
cleanup() {
    trap - INT TSTP EXIT
    printf '%b' "$ENDCOLOR"
}

menu_interrupt() {
    echo
    echo -e "${YELLOW}Use option 3 to exit from the menu.${ENDCOLOR}"
}

menu_suspend() {
    echo
    echo -e "${YELLOW}Ctrl+Z is disabled in the menu. Choose option 3 to exit.${ENDCOLOR}"
}

enable_menu_lock() {
    # Disable Ctrl+C and Ctrl+Z only for the menu.
    trap menu_interrupt INT
    trap menu_suspend TSTP
}

disable_menu_lock() {
    # Restore default behavior (Ctrl+C etc. works normally)
    trap - INT
    trap - TSTP
}

return_to_menu() {
    clear
    show_main_banner
}

run_with_normal_signals() {
    disable_menu_lock
    "$@"
    local status=$?

    if [[ $status -eq 130 ]]; then
        echo
        echo -e "${YELLOW}Cancelled. Returning to menu...${ENDCOLOR}"
        sleep 1
    fi

    return "$status"
}

install_pterodactyl() {
    echo -e "${GREEN}Running Pterodactyl installation...${ENDCOLOR}"
    bash <(curl -s https://pterodactyl-installer.se/)
}

install_cloudflared() {
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
}

install_playit() {
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
    playit
    echo -e "${GREEN}${BOLD}Playit session finished. Returning to menu...${ENDCOLOR}"
    read -rp "Press Enter to continue..."
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

trap cleanup EXIT

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
            run_with_normal_signals install_pterodactyl
            # Installer se nikal ke wapas menu banner
            return_to_menu
            ;;

        1)
            run_with_normal_signals install_cloudflared
            return_to_menu
            ;;

        2)
            run_with_normal_signals install_playit
            return_to_menu
            ;;

        3)
            disable_menu_lock
            echo -e "${RED}Exiting.${ENDCOLOR}"
            exit 0
            ;;

        *)
            echo -e "${RED}Invalid option. Please select 0, 1, 2, or 3.${ENDCOLOR}"
            ;;
    esac
done
