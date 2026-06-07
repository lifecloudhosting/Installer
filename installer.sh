#!/usr/bin/env bash

set -o pipefail

# Color codes
CYAN='\e[36m'
YELLOW='\e[33m'
RED='\e[31m'
GREEN='\e[32m'
ENDCOLOR='\e[0m'
BOLD='\e[1m'

MENU_LOCKED=0

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
    MENU_LOCKED=1
    trap menu_interrupt INT
    trap menu_suspend TSTP
}

disable_menu_lock() {
    MENU_LOCKED=0
    trap - INT
    trap - TSTP
}

return_to_menu() {
    echo
    read -r -p "Press Enter to return to the menu..."
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
    elif [[ $status -ne 0 ]]; then
        echo
        echo -e "${RED}Command failed with exit code ${status}.${ENDCOLOR}"
    fi

    return "$status"
}

show_main_banner() {
    echo -e "${CYAN}${BOLD}"
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
}

install_pterodactyl() {
    echo -e "${GREEN}Running Pterodactyl installation...${ENDCOLOR}"
    bash <(curl -fsSL https://pterodactyl-installer.se/)
}

install_cloudflared() {
    echo -e "${YELLOW}${BOLD}Adding Cloudflare gpg key...${ENDCOLOR}"
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
        | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

    echo -e "${YELLOW}Adding Cloudflared repo to your apt repositories...${ENDCOLOR}"
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
        | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

    echo -e "${YELLOW}Installing cloudflared...${ENDCOLOR}"
    sudo apt-get update
    sudo apt-get install -y cloudflared

    echo -e "${GREEN}${BOLD}Cloudflared installation completed!${ENDCOLOR}"
}

install_playit() {
    echo -e "${YELLOW}Installing Playit.gg...${ENDCOLOR}"
    sudo rm -f /etc/apt/sources.list.d/playit-cloud.list
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://packages.playit.gg/keys/playit.gpg \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/playit.gpg >/dev/null
    sudo chmod 0644 /usr/share/keyrings/playit.gpg

    sudo curl -fsSL -o /etc/apt/sources.list.d/playit.list \
        https://packages.playit.gg/repo-files/playit-debian.list

    sudo apt-get update
    sudo apt-get install -y playit

    echo -e "${GREEN}${BOLD}Playit.gg installation completed!${ENDCOLOR}"
    echo -e "${YELLOW}Starting Playit client. Press Ctrl+C to stop it and return here.${ENDCOLOR}"
    playit
    echo -e "${GREEN}${BOLD}Playit session finished.${ENDCOLOR}"
}

trap cleanup EXIT
clear
show_main_banner

while true; do
    enable_menu_lock

    echo -e "${GREEN}0) Install Pterodactyl Panel + Wings${ENDCOLOR}"
    echo -e "${YELLOW}1) Install Cloudflared${ENDCOLOR}"
    echo -e "${CYAN}2) Install Playit.gg${ENDCOLOR}"
    echo -e "${RED}3) Exit${ENDCOLOR}"
    echo -e "${CYAN}Select an option [0-3]:${ENDCOLOR}"

    if ! read -r choice; then
        echo
        continue
    fi

    case "$choice" in
        0)
            run_with_normal_signals install_pterodactyl
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
            echo
            ;;
    esac
done
