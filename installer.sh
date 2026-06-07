#!/usr/bin/env bash

set -o pipefail

CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
BOLD='\033[1m'
ENDCOLOR='\033[0m'

APP_NAME="Lifecloud Installer"
LOG_FILE="/tmp/lifecloud-installer-$(date +%Y%m%d-%H%M%S).log"
SUDO=""

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    SUDO="sudo"
fi

cleanup() {
    trap - INT TSTP EXIT
    printf '%b' "$ENDCOLOR"
}

info() {
    echo -e "${BLUE}[INFO]${ENDCOLOR} $*"
}

success() {
    echo -e "${GREEN}[OK]${ENDCOLOR} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${ENDCOLOR} $*"
}

fail() {
    echo -e "${RED}[ERROR]${ENDCOLOR} $*"
}

menu_interrupt() {
    echo
    warn "Use the menu Exit or Back option."
}

menu_suspend() {
    echo
    warn "Ctrl+Z is disabled in the menu. Use the menu Exit or Back option."
}

enable_menu_lock() {
    trap menu_interrupt INT
    trap menu_suspend TSTP
}

disable_menu_lock() {
    trap - INT
    trap - TSTP
}

pause() {
    echo
    read -r -p "Press Enter to return to the menu..."
}

confirm() {
    local prompt="$1"
    local answer

    read -r -p "$prompt [y/N]: " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

run_step() {
    local title="$1"
    shift

    info "$title"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local status=${PIPESTATUS[0]}

    if [[ $status -eq 130 ]]; then
        warn "Cancelled."
    elif [[ $status -ne 0 ]]; then
        fail "$title failed. See log: $LOG_FILE"
    fi

    return "$status"
}

run_action() {
    local action="$1"
    disable_menu_lock
    "$action"
    local status=$?

    if [[ $status -eq 130 ]]; then
        warn "Cancelled. Returning to menu..."
        sleep 1
    elif [[ $status -ne 0 ]]; then
        fail "Action failed with exit code $status."
        warn "Log file: $LOG_FILE"
        pause
    else
        success "Action completed."
        pause
    fi
}

show_intro_logo() {
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
}

show_menu_banner() {
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

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "Missing required command: $1"
        return 1
    fi
}

require_apt_system() {
    if ! command -v apt-get >/dev/null 2>&1; then
        fail "This option currently supports Debian/Ubuntu systems with apt-get."
        return 1
    fi
}

preflight() {
    require_command bash || return 1
    require_command curl || return 1
    require_command tee || return 1

    if [[ -n "$SUDO" ]]; then
        require_command sudo || return 1
        info "Checking sudo access..."
        sudo -v || return 1
    fi

    success "Preflight checks passed."
}

run_pterodactyl_installer_choice() {
    local upstream_choice="$1"
    local label="$2"
    local tmp_script

    preflight || return 1

    warn "This runs the external Pterodactyl installer from pterodactyl-installer.se."
    confirm "Continue with $label?" || return 0

    tmp_script="$(mktemp)"
    curl -fsSL -o "$tmp_script" https://pterodactyl-installer.se/ || {
        fail "Could not download the Pterodactyl installer."
        rm -f "$tmp_script"
        return 1
    }

    info "Opening $label. The first Pterodactyl option will be selected automatically."
    local status
    if [[ -r /dev/tty ]]; then
        { printf '%s\n' "$upstream_choice"; cat /dev/tty; } | bash "$tmp_script"
        status=${PIPESTATUS[1]}
    else
        printf '%s\n' "$upstream_choice" | bash "$tmp_script"
        status=${PIPESTATUS[1]}
    fi

    rm -f "$tmp_script"
    return "$status"
}

install_pterodactyl_panel() {
    run_pterodactyl_installer_choice "0" "Pterodactyl Panel only installation"
}

install_pterodactyl_wings() {
    run_pterodactyl_installer_choice "1" "Pterodactyl Wings only installation"
}

install_pterodactyl_panel_wings() {
    run_pterodactyl_installer_choice "2" "Pterodactyl Panel + Wings installation"
}

run_pterodactyl_uninstaller() {
    local label="$1"
    local guidance="$2"

    preflight || return 1

    warn "This opens the official Pterodactyl uninstaller."
    warn "$guidance"
    warn "Read every prompt carefully. Removing Wings can delete server data."
    confirm "Continue with $label?" || return 0

    bash -c '
        set -o pipefail
        export GITHUB_SOURCE="v1.2.0"
        export SCRIPT_RELEASE="v1.2.0"
        export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"
        curl -fsSL -o /tmp/lib.sh "$GITHUB_BASE_URL/master/lib/lib.sh"
        source /tmp/lib.sh
        update_lib_source
        run_ui uninstall
        rm -f /tmp/lib.sh
    '
}

delete_pterodactyl_panel() {
    run_pterodactyl_uninstaller \
        "Pterodactyl Panel deletion" \
        "When prompted: answer Y for panel removal and N for Wings removal."
}

delete_pterodactyl_wings() {
    run_pterodactyl_uninstaller \
        "Pterodactyl Wings deletion" \
        "When prompted: answer N for panel removal and Y for Wings removal."
}

delete_pterodactyl_panel_wings() {
    run_pterodactyl_uninstaller \
        "Pterodactyl Panel + Wings deletion" \
        "When prompted: answer Y for both panel removal and Wings removal."
}

install_cloudflared() {
    preflight || return 1
    require_apt_system || return 1

    run_step "Creating keyring directory" \
        $SUDO mkdir -p --mode=0755 /usr/share/keyrings || return 1

    run_step "Installing Cloudflare package key" \
        bash -c "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | $SUDO tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null" || return 1

    run_step "Adding Cloudflared apt repository" \
        bash -c "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | $SUDO tee /etc/apt/sources.list.d/cloudflared.list >/dev/null" || return 1

    run_step "Updating apt package lists" \
        $SUDO apt-get update || return 1

    run_step "Installing cloudflared" \
        $SUDO apt-get install -y cloudflared
}

install_playit() {
    preflight || return 1
    require_apt_system || return 1
    require_command gpg || return 1

    run_step "Removing old Playit repository file if present" \
        $SUDO rm -f /etc/apt/sources.list.d/playit-cloud.list || return 1

    run_step "Creating keyring directory" \
        $SUDO mkdir -p --mode=0755 /usr/share/keyrings || return 1

    run_step "Installing Playit package key" \
        bash -c "curl -fsSL https://packages.playit.gg/keys/playit.gpg | gpg --dearmor | $SUDO tee /usr/share/keyrings/playit.gpg >/dev/null" || return 1

    run_step "Fixing Playit key permissions" \
        $SUDO chmod 0644 /usr/share/keyrings/playit.gpg || return 1

    run_step "Adding Playit apt repository" \
        $SUDO curl -fsSL -o /etc/apt/sources.list.d/playit.list https://packages.playit.gg/repo-files/playit-debian.list || return 1

    run_step "Updating apt package lists" \
        $SUDO apt-get update || return 1

    run_step "Installing playit" \
        $SUDO apt-get install -y playit || return 1

    echo
    success "Playit installed."
    info "Run 'playit' for an interactive session, or 'playit setup' to claim the agent."
    if command -v systemctl >/dev/null 2>&1; then
        info "For background mode: sudo systemctl enable --now playit"
    fi
}

show_status() {
    echo -e "${BOLD}Installed tools:${ENDCOLOR}"

    if command -v cloudflared >/dev/null 2>&1; then
        cloudflared --version 2>/dev/null || true
    else
        warn "cloudflared is not installed."
    fi

    if command -v playit >/dev/null 2>&1; then
        playit --version 2>/dev/null || success "playit is installed."
    else
        warn "playit is not installed."
    fi

    echo
    info "Log file for this session: $LOG_FILE"
    pause
}

pterodactyl_menu() {
    while true; do
        clear
        show_menu_banner
        enable_menu_lock

        echo -e "${BOLD}Pterodactyl Options${ENDCOLOR}"
        echo -e "${GREEN}0) Install Panel only${ENDCOLOR}"
        echo -e "${GREEN}1) Install Panel + Wings${ENDCOLOR}"
        echo -e "${GREEN}2) Install Wings only${ENDCOLOR}"
        echo -e "${RED}3) Delete Panel + Wings${ENDCOLOR}"
        echo -e "${RED}4) Delete Panel only${ENDCOLOR}"
        echo -e "${RED}5) Delete Wings only${ENDCOLOR}"
        echo -e "${YELLOW}6) Back to main menu${ENDCOLOR}"
        echo
        read -r -p "Select an option [0-6]: " ptero_choice

        case "$ptero_choice" in
            0) run_action install_pterodactyl_panel ;;
            1) run_action install_pterodactyl_panel_wings ;;
            2) run_action install_pterodactyl_wings ;;
            3) run_action delete_pterodactyl_panel_wings ;;
            4) run_action delete_pterodactyl_panel ;;
            5) run_action delete_pterodactyl_wings ;;
            6)
                disable_menu_lock
                return 0
                ;;
            *)
                warn "Invalid option. Please select 0, 1, 2, 3, 4, 5, or 6."
                sleep 1
                ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        show_menu_banner
        enable_menu_lock

        echo -e "${GREEN}0) Pterodactyl Installer${ENDCOLOR}"
        echo -e "${YELLOW}1) Install Cloudflared${ENDCOLOR}"
        echo -e "${CYAN}2) Install Playit.gg${ENDCOLOR}"
        echo -e "${BLUE}3) Check installed tools${ENDCOLOR}"
        echo -e "${RED}4) Exit${ENDCOLOR}"
        echo
        read -r -p "Select an option [0-4]: " choice

        case "$choice" in
            0) disable_menu_lock; pterodactyl_menu ;;
            1) run_action install_cloudflared ;;
            2) run_action install_playit ;;
            3) disable_menu_lock; show_status ;;
            4)
                disable_menu_lock
                success "Goodbye."
                exit 0
                ;;
            *)
                warn "Invalid option. Please select 0, 1, 2, 3, or 4."
                sleep 1
                ;;
        esac
    done
}

trap cleanup EXIT
clear
show_intro_logo
sleep 2
main_menu
