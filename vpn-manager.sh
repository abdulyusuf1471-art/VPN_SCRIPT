#!/bin/bash
# ============================================================
# VPN MANAGER SCRIPT
# Compatible with Ubuntu 20.04 / 22.04 / 24.04
# Services: Xray-Core, OpenSSH, Dropbear, Stunnel4, Nginx
# ============================================================

# ─── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ─── Config Paths ─────────────────────────────────────────────
VPN_DIR="/etc/vpn-manager"
SSH_DB="$VPN_DIR/ssh-users.db"
VMESS_DB="$VPN_DIR/vmess-users.db"
VLESS_DB="$VPN_DIR/vless-users.db"
TROJAN_DB="$VPN_DIR/trojan-users.db"
SETTINGS="$VPN_DIR/settings.conf"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
LICENSE_FILE="$VPN_DIR/license.conf"

# ─── First Time Setup Wizard ──────────────────────────────────
first_time_setup() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           VPN MANAGER - FIRST TIME SETUP WIZARD${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${WHITE}Welcome! Please configure your server details below.${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    while true; do
        echo -ne " ${GREEN}Enter your Main Domain (e.g. vpn.mydomain.com): ${NC}"
        read -r INPUT_DOMAIN
        [ -n "$INPUT_DOMAIN" ] && break
        echo -e " ${RED}[!] Domain cannot be empty!${NC}"
    done

    while true; do
        echo -ne " ${GREEN}Enter your NameServer / NS Domain (e.g. ns.mydomain.com): ${NC}"
        read -r INPUT_NS
        [ -n "$INPUT_NS" ] && break
        echo -e " ${RED}[!] NS Domain cannot be empty!${NC}"
    done

    echo -ne " ${GREEN}Enter Client / Owner Name [Default: VPS]: ${NC}"
    read -r INPUT_CLIENT
    INPUT_CLIENT="${INPUT_CLIENT:-VPS}"

    RAND_PUBKEY=$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 64 || echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59")
    echo -ne " ${GREEN}SlowDNS Public Key [Press Enter to auto-generate]: ${NC}"
    read -r INPUT_KEY
    INPUT_KEY="${INPUT_KEY:-$RAND_PUBKEY}"

    cat > "$SETTINGS" <<EOF
DOMAIN=$INPUT_DOMAIN
NS_DOMAIN=$INPUT_NS
BOT_TOKEN=
CHAT_ID=
SLOWDNS_PUBKEY=$INPUT_KEY
CLIENT_NAME=$INPUT_CLIENT
EXPIRY_DATE=2027-01-01
EOF

    cat > "$LICENSE_FILE" <<EOF
CLIENT=$INPUT_CLIENT
EXPIRY=2027-01-01
EOF

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}[✓] Setup complete! Saved Domain: $INPUT_DOMAIN and NS: $INPUT_NS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 2
}

# ─── Init ─────────────────────────────────────────────────────
init_dirs() {
    mkdir -p "$VPN_DIR"
    [ ! -f "$SSH_DB" ]    && touch "$SSH_DB"
    [ ! -f "$VMESS_DB" ]  && touch "$VMESS_DB"
    [ ! -f "$VLESS_DB" ]  && touch "$VLESS_DB"
    [ ! -f "$TROJAN_DB" ] && touch "$TROJAN_DB"
    if [ ! -f "$SETTINGS" ]; then
        first_time_setup
    fi
}

# ─── Load Settings ────────────────────────────────────────────
load_settings() {
    [ -f "$SETTINGS" ] && source "$SETTINGS"
    IP_VPS=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
}

# ─── Helpers ──────────────────────────────────────────────────
press_any_key() {
    echo -e "\n${YELLOW}Press any key to return...${NC}"
    read -n1 -s
}

gen_uuid() {
    cat /proc/sys/kernel/random/uuid
}

get_uptime() {
    uptime -p | sed 's/up //'
}

get_ram_info() {
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    USED_RAM=$(free -m  | awk '/^Mem:/{print $3}')
    FREE_RAM=$(free -m  | awk '/^Mem:/{print $4}')
}

get_cpu_usage() {
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
}

count_users() {
    SSH_COUNT=$(grep -c '.' "$SSH_DB"    2>/dev/null || echo 0)
    VMESS_COUNT=$(grep -c '.' "$VMESS_DB"  2>/dev/null || echo 0)
    VLESS_COUNT=$(grep -c '.' "$VLESS_DB"  2>/dev/null || echo 0)
    TROJAN_COUNT=$(grep -c '.' "$TROJAN_DB" 2>/dev/null || echo 0)
}

svc_status() {
    systemctl is-active --quiet "$1" 2>/dev/null \
        && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
}

get_license_info() {
    [ -f "$LICENSE_FILE" ] && source "$LICENSE_FILE"
    CLIENT="${CLIENT:-VPS}"
    EXPIRY="${EXPIRY:-N/A}"
    TODAY=$(date +%Y-%m-%d)
    if [ "$EXPIRY" != "N/A" ]; then
        DAYS_LEFT=$(( ( $(date -d "$EXPIRY" +%s) - $(date -d "$TODAY" +%s) ) / 86400 ))
    else
        DAYS_LEFT="N/A"
    fi
}

# ─── Header ───────────────────────────────────────────────────
print_header() {
    load_settings; get_ram_info; get_cpu_usage; get_license_info; count_users
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    LICENSE INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Client       : ${WHITE}$CLIENT${NC}"
    echo -e " Expiry Date  : ${WHITE}$EXPIRY${NC}"
    echo -e " Days Left    : ${WHITE}$DAYS_LEFT Days${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                     VPS INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Server Uptime    = ${WHITE}$(get_uptime)${NC}"
    echo -e " Current Time     = ${WHITE}$(date '+%d-%m-%Y | %H:%M:%S')${NC}"
    echo -e " Operating System = ${WHITE}$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')${NC}"
    echo -e " Current Domain   = ${WHITE}$DOMAIN${NC}"
    echo -e " NS Domain        = ${WHITE}$NS_DOMAIN${NC}"
    echo -e " Total Ram        = ${WHITE}${TOTAL_RAM} MB${NC}"
    echo -e " Total Used Ram   = ${WHITE}${USED_RAM} MB${NC}"
    echo -e " Total Free Ram   = ${WHITE}${FREE_RAM} MB${NC}"
    echo -e " CPU Usage        = ${WHITE}${CPU_USAGE}%${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# MAIN MENU
# ============================================================
main_menu() {
    while true; do
        clear
        print_header
        echo -e "${PURPLE}                   @VPN MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  Use Core : ${WHITE}Xray-Core${NC}          IP-VPS : ${WHITE}$IP_VPS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "     SSH         VMESS        VLESS       TROJAN"
        echo -e "      ${GREEN}$SSH_COUNT${NC}           ${GREEN}$VMESS_COUNT${NC}            ${GREEN}$VLESS_COUNT${NC}           ${GREEN}$TROJAN_COUNT${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  SSH:$(svc_status ssh) NGINX:$(svc_status nginx) XRAY:$(svc_status xray) DROPBEAR:$(svc_status dropbear) SSH-WS:$(svc_status ssh-ws)"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} SSH    [Menu]        ${WHITE}[06]${NC} BACKUP"
        echo -e "  ${WHITE}[02]${NC} VMESS  [Menu]        ${WHITE}[07]${NC} DOMAIN & SSL"
        echo -e "  ${WHITE}[03]${NC} VLESS  [Menu]        ${WHITE}[08]${NC} CHECK RUNNING"
        echo -e "  ${WHITE}[04]${NC} TROJAN [Menu]        ${WHITE}[00]${NC} EXIT SYSTEM"
        echo -e "  ${WHITE}[05]${NC} SETTING [Menu]"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "
        read -r opt
        case $opt in
            1|01) ssh_menu ;;
            2|02) vmess_menu ;;
            3|03) vless_menu ;;
            4|04) trojan_menu ;;
            5|05) settings_menu ;;
            6|06) backup_menu ;;
            7|07) domain_ssl_menu ;;
            8|08) check_running ;;
            0|00) echo -e "\n${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
# SSH MANAGER
# ============================================================
ssh_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}           SSH & OPENVPN CONNECTION MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Create SSH Account"
        echo -e "  ${WHITE}[02]${NC} Generate Trial SSH"
        echo -e "  ${WHITE}[03]${NC} Create Timed SSH (Mins)"
        echo -e "  ${WHITE}[04]${NC} Renew SSH Account"
        echo -e "  ${WHITE}[05]${NC} Delete SSH Account"
        echo -e "  ${WHITE}[06]${NC} Check User Login"
        echo -e "  ${WHITE}[07]${NC} List Member SSH"
        echo -e "  ${WHITE}[08]${NC} Delete Expired Users"
        echo -e "  ${WHITE}[09]${NC} Setup Autokill"
        echo -e "  ${WHITE}[10]${NC} Check Multi-Login"
        echo -e "  ${WHITE}[11]${NC} Security & Lock Manager"
        echo -e "  ${WHITE}[12]${NC} Show OpenVPN Config"
        echo -e "  ${WHITE}[13]${NC} Modify User Login Limit"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) create_ssh ;;
            2|02) trial_ssh ;;
            3|03) timed_ssh ;;
            4|04) renew_ssh ;;
            5|05) delete_ssh ;;
            6|06) check_user_login ;;
            7|07) list_ssh_members ;;
            8|08) delete_expired_ssh ;;
            9|09) setup_autokill ;;
            10)   check_multi_login ;;
            11)   security_manager ;;
            12)   show_ovpn_config ;;
            13)   modify_login_limit ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

create_ssh() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                CREATE SSH ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username      : "; read -r USERNAME
    echo -ne " Password      : "; read -r PASSWORD
    echo -ne " Expiry (days) : "; read -r DAYS
    echo -ne " Max Logins    : "; read -r MAX_LOGIN
    MAX_LOGIN="${MAX_LOGIN:-1}"
    if id "$USERNAME" &>/dev/null; then
        echo -e "${RED}[!] User already exists!${NC}"; press_any_key; return
    fi
    EXPIRY_ISO=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    useradd -M -s /bin/false -e "$EXPIRY_ISO" "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME|$PASSWORD|$EXPIRY_ISO|$MAX_LOGIN" >> "$SSH_DB"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            PREMIUM SSH WS ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Username    : ${WHITE}$USERNAME${NC}"
    echo -e " Password    : ${WHITE}$PASSWORD${NC}"
    echo -e " Max Login   : ${WHITE}$MAX_LOGIN Connection(s)${NC}"
    echo -e " Expired On  : ${WHITE}$(date -d "$EXPIRY_ISO" '+%b %d, %Y')${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}            SERVER INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " IP          : ${WHITE}$IP_VPS${NC}"
    echo -e " Host        : ${WHITE}$DOMAIN${NC}"
    echo -e " NS Domain   : ${WHITE}$NS_DOMAIN${NC}"
    echo -e " OpenSSH     : ${WHITE}22${NC}"
    echo -e " SSH-WS      : ${WHITE}80${NC}"
    echo -e " Custom SSH  : ${WHITE}8880${NC}"
    echo -e " SSH-SSL-WS  : ${WHITE}443${NC}"
    echo -e " Dropbear    : ${WHITE}109, 143${NC}"
    echo -e " SSL/TLS     : ${WHITE}447, 777${NC}"
    echo -e " UDPGW       : ${WHITE}7100-7300${NC}"
    echo -e " SOCKS5      : ${WHITE}1080${NC}"
    echo -e " HTTP Proxy  : ${WHITE}8080${NC}"
    echo -e " OVPN TCP    : ${WHITE}http://$DOMAIN:85/client-tcp.ovpn${NC}"
    echo -e " OVPN UDP    : ${WHITE}http://$DOMAIN:85/client-udp.ovpn${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " SSH-80    : ${WHITE}$DOMAIN:80@$USERNAME:$PASSWORD${NC}"
    echo -e " SSH-8880  : ${WHITE}$DOMAIN:8880@$USERNAME:$PASSWORD${NC}"
    echo -e " SSH-443   : ${WHITE}$DOMAIN:443@$USERNAME:$PASSWORD${NC}"
    echo -e " SOCKS5    : ${WHITE}$DOMAIN:1080:$USERNAME:$PASSWORD${NC}"
    echo -e " HTTP Proxy: ${WHITE}$DOMAIN:8080:$USERNAME:$PASSWORD${NC}"
    echo -e ""
    echo -e " (Payload WSS)"
    echo -e " ${WHITE}GET wss://bug.com [protocol][crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e ""
    echo -e " (Payload WS - Port 80)"
    echo -e " ${WHITE}GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e ""
    echo -e " (Payload Custom Bypass - Port 8880)"
    echo -e " ${WHITE}GET http://$DOMAIN:8880 HTTP/1.1[crlf]Host: [ISP_BUG_HOST][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_any_key
}

trial_ssh() {
    clear; load_settings
    RAND=$(tr -dc 'a-z0-9' < /dev/urandom | head -c4)
    USERNAME="TRIAL-$RAND"
    PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c8)
    EXPIRY_ISO=$(date -d "+1 day" +"%Y-%m-%d")
    useradd -M -s /bin/false -e "$EXPIRY_ISO" "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME|$PASSWORD|$EXPIRY_ISO|1" >> "$SSH_DB"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}           TRIAL SSH ACCOUNT CREATED${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Username   : ${WHITE}$USERNAME${NC}"
    echo -e " Password   : ${WHITE}$PASSWORD${NC}"
    echo -e " Expired On : ${WHITE}24 Hours (Trial)${NC}"
    echo -e " Host       : ${WHITE}$DOMAIN${NC}"
    echo -e " IP         : ${WHITE}$IP_VPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_any_key
}

timed_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           CREATE TIMED SSH (MINUTES)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username       : "; read -r USERNAME
    echo -ne " Password       : "; read -r PASSWORD
    echo -ne " Duration (min) : "; read -r MINS
    EXPIRY_ISO=$(date -d "+1 day" +"%Y-%m-%d")
    useradd -M -s /bin/false -e "$EXPIRY_ISO" "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "$USERNAME|$PASSWORD|$EXPIRY_ISO|1" >> "$SSH_DB"
    ( sleep $(( MINS * 60 )); userdel -r "$USERNAME" 2>/dev/null; sed -i "/^$USERNAME|/d" "$SSH_DB" ) &
    echo -e "${GREEN}[✓] Timed SSH created for ${MINS} minutes!${NC}"
    echo -e " Username : ${WHITE}$USERNAME${NC}"
    echo -e " Password : ${WHITE}$PASSWORD${NC}"
    press_any_key
}

renew_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              RENEW SSH ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username  : "; read -r USERNAME
    echo -ne " Add days  : "; read -r DAYS
    if ! grep -q "^$USERNAME|" "$SSH_DB" 2>/dev/null; then
        echo -e "${RED}[!] User not found!${NC}"; press_any_key; return
    fi
    OLD=$(grep "^$USERNAME|" "$SSH_DB")
    PASS=$(echo "$OLD" | cut -d'|' -f2)
    CUR=$(echo "$OLD"  | cut -d'|' -f3)
    ML=$(echo "$OLD"   | cut -d'|' -f4)
    NEW_EXP=$(date -d "$CUR +${DAYS} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${DAYS} days" +"%Y-%m-%d")
    chage -E "$NEW_EXP" "$USERNAME" 2>/dev/null
    sed -i "/^$USERNAME|/d" "$SSH_DB"
    echo "$USERNAME|$PASS|$NEW_EXP|$ML" >> "$SSH_DB"
    echo -e "${GREEN}[✓] Account renewed!${NC}"
    echo -e " Username   : ${WHITE}$USERNAME${NC}"
    echo -e " New Expiry : ${WHITE}$(date -d "$NEW_EXP" '+%b %d, %Y')${NC}"
    press_any_key
}

delete_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              DELETE SSH ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username : "; read -r USERNAME
    userdel -r "$USERNAME" 2>/dev/null
    sed -i "/^$USERNAME|/d" "$SSH_DB"
    echo -e "${GREEN}[✓] User $USERNAME deleted!${NC}"
    press_any_key
}

check_user_login() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              ACTIVE USER LOGINS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    who | awk '{print " User: "$1"  Terminal: "$2"  Since: "$3" "$4}'
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    TOTAL=$(ss -tnp 2>/dev/null | grep ':22' | wc -l)
    echo -e " Total SSH connections : ${WHITE}$TOTAL${NC}"
    press_any_key
}

list_ssh_members() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                SSH MEMBER LIST${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf " %-16s %-14s %-12s %-8s\n" "USERNAME" "PASSWORD" "EXPIRY" "MAX"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    while IFS='|' read -r u p e m; do
        printf " %-16s %-14s %-12s %-8s\n" "$u" "$p" "$e" "$m"
    done < "$SSH_DB"
    press_any_key
}

delete_expired_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           DELETING EXPIRED SSH USERS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    TODAY=$(date +%Y-%m-%d); DELETED=0
    while IFS='|' read -r u p e m; do
        if [[ "$e" < "$TODAY" ]]; then
            userdel -r "$u" 2>/dev/null
            sed -i "/^$u|/d" "$SSH_DB"
            echo -e " ${RED}[✗] Deleted:${NC} $u (expired: $e)"
            ((DELETED++))
        fi
    done < <(cat "$SSH_DB")
    echo -e " ${GREEN}Total deleted: $DELETED user(s)${NC}"
    press_any_key
}

setup_autokill() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                SETUP AUTOKILL${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Enable Autokill (kill multi-login every minute)"
    echo -e " [2] Disable Autokill"
    echo -ne " Select: "; read -r ch
    case $ch in
        1)
            cat > /usr/local/bin/vpn-autokill.sh << 'AKEOF'
#!/bin/bash
DB="/etc/vpn-manager/ssh-users.db"
while IFS='|' read -r user pass exp ml; do
    COUNT=$(who | grep -c "^$user " 2>/dev/null || echo 0)
    [ "$COUNT" -gt "${ml:-1}" ] && pkill -u "$user" 2>/dev/null
done < "$DB"
AKEOF
            chmod +x /usr/local/bin/vpn-autokill.sh
            (crontab -l 2>/dev/null | grep -v "vpn-autokill"; echo "* * * * * /usr/local/bin/vpn-autokill.sh") | crontab -
            echo -e "${GREEN}[✓] Autokill enabled!${NC}" ;;
        2)
            crontab -l 2>/dev/null | grep -v "vpn-autokill" | crontab -
            echo -e "${GREEN}[✓] Autokill disabled!${NC}" ;;
    esac
    press_any_key
}

check_multi_login() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}               MULTI-LOGIN CHECK${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf " %-16s %-8s %-8s %s\n" "USERNAME" "ACTIVE" "MAX" "STATUS"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    while IFS='|' read -r u p e m; do
        CNT=$(who | grep -c "^$u " 2>/dev/null || echo 0)
        [ "$CNT" -gt "${m:-1}" ] 2>/dev/null && ST="${RED}[OVERLIMIT]${NC}" || ST="${GREEN}[OK]${NC}"
        printf " %-16s %-8s %-8s " "$u" "$CNT" "$m"; echo -e "$ST"
    done < "$SSH_DB"
    press_any_key
}

security_manager() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           SECURITY & LOCK MANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Lock User Account"
    echo -e " [2] Unlock User Account"
    echo -e " [3] Block IP Address"
    echo -e " [4] Unblock IP Address"
    echo -ne " Select: "; read -r ch
    case $ch in
        1) echo -ne " Username: "; read -r u; usermod -L "$u" && echo -e "${GREEN}[✓] $u locked${NC}" ;;
        2) echo -ne " Username: "; read -r u; usermod -U "$u" && echo -e "${GREEN}[✓] $u unlocked${NC}" ;;
        3) echo -ne " IP: "; read -r ip; iptables -A INPUT -s "$ip" -j DROP && echo -e "${GREEN}[✓] $ip blocked${NC}" ;;
        4) echo -ne " IP: "; read -r ip; iptables -D INPUT -s "$ip" -j DROP && echo -e "${GREEN}[✓] $ip unblocked${NC}" ;;
    esac
    press_any_key
}

show_ovpn_config() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              OPENVPN CONFIG LINKS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " OVPN TCP : ${WHITE}http://$DOMAIN:85/client-tcp.ovpn${NC}"
    echo -e " OVPN UDP : ${WHITE}http://$DOMAIN:85/client-udp.ovpn${NC}"
    press_any_key
}

modify_login_limit() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           MODIFY USER LOGIN LIMIT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username  : "; read -r USERNAME
    echo -ne " New Limit : "; read -r NEW_LIMIT
    if grep -q "^$USERNAME|" "$SSH_DB" 2>/dev/null; then
        OLD=$(grep "^$USERNAME|" "$SSH_DB")
        P=$(echo "$OLD" | cut -d'|' -f2)
        E=$(echo "$OLD" | cut -d'|' -f3)
        sed -i "/^$USERNAME|/d" "$SSH_DB"
        echo "$USERNAME|$P|$E|$NEW_LIMIT" >> "$SSH_DB"
        echo -e "${GREEN}[✓] Login limit updated to $NEW_LIMIT for $USERNAME${NC}"
    else
        echo -e "${RED}[!] User not found!${NC}"
    fi
    press_any_key
}

# ============================================================
# XRAY HELPERS
# ============================================================
xray_add_user() {
    local TYPE="$1" USER="$2" UUID="$3"
    [ ! -f "$XRAY_CONFIG" ] && return
    python3 -c "
import json
try:
    with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
    for ib in cfg.get('inbounds',[]):
        if ib.get('tag')=='$TYPE':
            cls=ib.get('settings',{}).get('clients',[])
            cls.append({'id':'$UUID','email':'$USER','alterId':0})
            ib['settings']['clients']=cls
    with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
except: pass
" 2>/dev/null
    systemctl restart xray 2>/dev/null
}

xray_del_user() {
    local TYPE="$1" USER="$2"
    [ ! -f "$XRAY_CONFIG" ] && return
    python3 -c "
import json
try:
    with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
    for ib in cfg.get('inbounds',[]):
        if ib.get('tag')=='$TYPE':
            cls=ib.get('settings',{}).get('clients',[])
            ib['settings']['clients']=[c for c in cls if c.get('email')!='$USER']
    with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
except: pass
" 2>/dev/null
    systemctl restart xray 2>/dev/null
}

# ─── Xray Link Generator ──────────────────────────────────────
print_xray_links() {
    local TYPE="$1" PS="$2" UUID="$3" HOST="$4"
    case $TYPE in
        vmess)
            TLS_J="{\"add\":\"$HOST\",\"aid\":\"0\",\"host\":\"$HOST\",\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/vmess\",\"port\":\"443\",\"ps\":\"$PS\",\"scy\":\"auto\",\"sni\":\"$HOST\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
            HU_J="{\"add\":\"$HOST\",\"aid\":\"0\",\"host\":\"$HOST\",\"id\":\"$UUID\",\"net\":\"httpupgrade\",\"path\":\"/vmess-http\",\"port\":\"443\",\"ps\":\"$PS (CloudFront)\",\"scy\":\"auto\",\"sni\":\"$HOST\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
            NT_J="{\"add\":\"$HOST\",\"aid\":\"0\",\"host\":\"\",\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/vmess\",\"port\":\"80\",\"ps\":\"$PS\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}"
            echo -e " ${YELLOW}LINK TLS :${NC}"
            echo -e " vmess://$(echo -n "$TLS_J" | base64 -w0)"
            echo -e ""
            echo -e " ${YELLOW}LINK HTTP-UPGRADE (CloudFront Bypass) :${NC}"
            echo -e " vmess://$(echo -n "$HU_J" | base64 -w0)"
            echo -e ""
            echo -e " ${YELLOW}LINK NO-TLS :${NC}"
            echo -e " vmess://$(echo -n "$NT_J" | base64 -w0)"
            ;;
        vless)
            echo -e " ${YELLOW}LINK TLS (Cloudflare/Standard) :${NC}"
            echo -e " vless://$UUID@$HOST:443?path=/vless&security=tls&encryption=none&type=ws#$PS"
            echo -e ""
            echo -e " ${YELLOW}LINK HTTP-UPGRADE (CloudFront Bypass) :${NC}"
            echo -e " vless://$UUID@$HOST:443?path=/vless-hu&security=tls&encryption=none&type=httpupgrade#${PS}_CloudFront"
            echo -e ""
            echo -e " ${YELLOW}LINK NO-TLS (Port 80) :${NC}"
            echo -e " vless://$UUID@$HOST:80?path=/vless&encryption=none&type=ws#$PS"
            ;;
        trojan)
            echo -e " ${YELLOW}LINK TLS (WS) :${NC}"
            echo -e " trojan://$UUID@$HOST:443?path=%2Ftrojan-ws&security=tls&host=$HOST&type=ws&sni=$HOST#$PS"
            ;;
    esac
}

# ─── Shared Xray Account Functions ────────────────────────────
xray_create() {
    local TYPE="$1" LABEL="$2" DB="$3"
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           CREATE $LABEL ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Remarks   : "; read -r REMARKS
    echo -ne " Exp (days): "; read -r DAYS
    UUID=$(gen_uuid)
    EXPIRY_ISO=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    EXPIRY_FMT=$(date -d "+${DAYS} days" "+%b %d, %Y")
    echo "$REMARKS|$UUID|$EXPIRY_ISO" >> "$DB"
    xray_add_user "$TYPE" "$REMARKS" "$UUID"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}           $LABEL ACCOUNT CREATED${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Remarks    : ${WHITE}$REMARKS${NC}"
    echo -e " Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e " User ID    : ${WHITE}$UUID${NC}"
    echo -e " Expired On : ${WHITE}$EXPIRY_FMT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_xray_links "$TYPE" "$REMARKS" "$UUID" "$DOMAIN"
    press_any_key
}

xray_trial() {
    local TYPE="$1" LABEL="$2" DB="$3"
    clear; load_settings
    RAND=$(tr -dc 'a-z0-9' < /dev/urandom | head -c4)
    REMARKS="TRIAL-$RAND"
    UUID=$(gen_uuid)
    EXPIRY_ISO=$(date -d "+1 day" +"%Y-%m-%d")
    echo "$REMARKS|$UUID|$EXPIRY_ISO" >> "$DB"
    xray_add_user "$TYPE" "$REMARKS" "$UUID"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}           TRIAL $LABEL CREATED${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Remarks    : ${WHITE}$REMARKS${NC}"
    echo -e " Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e " User ID    : ${WHITE}$UUID${NC}"
    echo -e " Expired On : ${WHITE}24 Hours (Trial)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_xray_links "$TYPE" "$REMARKS" "$UUID" "$DOMAIN"
    press_any_key
}

xray_timed() {
    local TYPE="$1" LABEL="$2" DB="$3"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}        CREATE TIMED $LABEL (MINUTES)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Remarks       : "; read -r REMARKS
    echo -ne " Duration (min): "; read -r MINS
    UUID=$(gen_uuid)
    EXPIRY_ISO=$(date -d "+1 day" +"%Y-%m-%d")
    echo "$REMARKS|$UUID|$EXPIRY_ISO" >> "$DB"
    xray_add_user "$TYPE" "$REMARKS" "$UUID"
    ( sleep $(( MINS * 60 )); sed -i "/^$REMARKS|/d" "$DB"; xray_del_user "$TYPE" "$REMARKS" ) &
    echo -e "${GREEN}[✓] Timed $LABEL account created for ${MINS} minutes!${NC}"
    press_any_key
}

xray_extend() {
    local TYPE="$1" DB="$2"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              EXTEND ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Remarks  : "; read -r REMARKS
    echo -ne " Add days : "; read -r DAYS
    if grep -q "^$REMARKS|" "$DB" 2>/dev/null; then
        CUR=$(grep "^$REMARKS|" "$DB" | cut -d'|' -f3)
        UUID=$(grep "^$REMARKS|" "$DB" | cut -d'|' -f2)
        NEW=$(date -d "$CUR +${DAYS} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${DAYS} days" +"%Y-%m-%d")
        sed -i "/^$REMARKS|/d" "$DB"
        echo "$REMARKS|$UUID|$NEW" >> "$DB"
        echo -e "${GREEN}[✓] Extended! New expiry: $(date -d "$NEW" '+%b %d, %Y')${NC}"
    else
        echo -e "${RED}[!] User not found!${NC}"
    fi
    press_any_key
}

xray_delete() {
    local TYPE="$1" DB="$2"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              DELETE ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Remarks : "; read -r REMARKS
    xray_del_user "$TYPE" "$REMARKS"
    sed -i "/^$REMARKS|/d" "$DB"
    echo -e "${GREEN}[✓] Account $REMARKS deleted!${NC}"
    press_any_key
}

xray_check_login() {
    local TYPE="$1"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}         $TYPE ONLINE USERS (Recent Log)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    LOG="/var/log/xray/access.log"
    if [ -f "$LOG" ]; then
        grep "accepted" "$LOG" | tail -20
    else
        echo -e " ${YELLOW}[i] Log not found. Check xray log path in config.json${NC}"
    fi
    press_any_key
}

xray_list() {
    local LABEL="$1" DB="$2"
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              $LABEL MEMBER LIST${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf " %-20s %-38s %-12s\n" "REMARKS" "UUID" "EXPIRY"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    while IFS='|' read -r r u e; do
        printf " %-20s %-38s %-12s\n" "$r" "$u" "$e"
    done < "$DB"
    press_any_key
}

xray_clean_expired() {
    local TYPE="$1" DB="$2"
    clear
    TODAY=$(date +%Y-%m-%d); DELETED=0
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}         CLEANING EXPIRED $TYPE ACCOUNTS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    while IFS='|' read -r r u e; do
        if [[ "$e" < "$TODAY" ]]; then
            xray_del_user "$TYPE" "$r"
            sed -i "/^$r|/d" "$DB"
            echo -e " ${RED}[✗] Deleted:${NC} $r (expired: $e)"
            ((DELETED++))
        fi
    done < <(cat "$DB")
    echo -e " ${GREEN}Total deleted: $DELETED account(s)${NC}"
    press_any_key
}

# ============================================================
# VMESS MANAGER
# ============================================================
vmess_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                XRAY VMESS MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Create VMess Account"
        echo -e "  ${WHITE}[02]${NC} Create Trial Account"
        echo -e "  ${WHITE}[03]${NC} Create Timed VMess (Mins)"
        echo -e "  ${WHITE}[04]${NC} Extend VMess Account"
        echo -e "  ${WHITE}[05]${NC} Delete VMess Account"
        echo -e "  ${WHITE}[06]${NC} Check User Login"
        echo -e "  ${WHITE}[07]${NC} List VMess Members"
        echo -e "  ${WHITE}[08]${NC} Clean Expired Users (Manual)"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) xray_create "vmess" "VMess" "$VMESS_DB" ;;
            2|02) xray_trial  "vmess" "VMess" "$VMESS_DB" ;;
            3|03) xray_timed  "vmess" "VMess" "$VMESS_DB" ;;
            4|04) xray_extend "vmess" "$VMESS_DB" ;;
            5|05) xray_delete "vmess" "$VMESS_DB" ;;
            6|06) xray_check_login "vmess" ;;
            7|07) xray_list "VMess" "$VMESS_DB" ;;
            8|08) xray_clean_expired "vmess" "$VMESS_DB" ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
# VLESS MANAGER
# ============================================================
vless_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                XRAY VLESS MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Create VLESS Account"
        echo -e "  ${WHITE}[02]${NC} Create Trial Account"
        echo -e "  ${WHITE}[03]${NC} Create Timed VLESS (Mins)"
        echo -e "  ${WHITE}[04]${NC} Extend VLESS Account"
        echo -e "  ${WHITE}[05]${NC} Delete VLESS Account"
        echo -e "  ${WHITE}[06]${NC} Check User Login"
        echo -e "  ${WHITE}[07]${NC} List VLESS Members"
        echo -e "  ${WHITE}[08]${NC} Clean Expired Users (Manual)"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) xray_create "vless" "VLESS" "$VLESS_DB" ;;
            2|02) xray_trial  "vless" "VLESS" "$VLESS_DB" ;;
            3|03) xray_timed  "vless" "VLESS" "$VLESS_DB" ;;
            4|04) xray_extend "vless" "$VLESS_DB" ;;
            5|05) xray_delete "vless" "$VLESS_DB" ;;
            6|06) xray_check_login "vless" ;;
            7|07) xray_list "VLESS" "$VLESS_DB" ;;
            8|08) xray_clean_expired "vless" "$VLESS_DB" ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
# TROJAN MANAGER
# ============================================================
trojan_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                XRAY TROJAN MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Create Trojan Account"
        echo -e "  ${WHITE}[02]${NC} Create Trial Account"
        echo -e "  ${WHITE}[03]${NC} Create Timed Trojan (Mins)"
        echo -e "  ${WHITE}[04]${NC} Extend Trojan Account"
        echo -e "  ${WHITE}[05]${NC} Delete Trojan Account"
        echo -e "  ${WHITE}[06]${NC} Check User Login"
        echo -e "  ${WHITE}[07]${NC} List Trojan Members"
        echo -e "  ${WHITE}[08]${NC} Clean Expired Users (Manual)"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) xray_create "trojan" "Trojan" "$TROJAN_DB" ;;
            2|02) xray_trial  "trojan" "Trojan" "$TROJAN_DB" ;;
            3|03) xray_timed  "trojan" "Trojan" "$TROJAN_DB" ;;
            4|04) xray_extend "trojan" "$TROJAN_DB" ;;
            5|05) xray_delete "trojan" "$TROJAN_DB" ;;
            6|06) xray_check_login "trojan" ;;
            7|07) xray_list "Trojan" "$TROJAN_DB" ;;
            8|08) xray_clean_expired "trojan" "$TROJAN_DB" ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
# CHECK RUNNING SERVICES
# ============================================================
check_running() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              SYSTEM SERVICE STATUS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    _row() {
        if systemctl is-active --quiet "$2" 2>/dev/null; then
            printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "$1"
        else
            printf " %-35s: [ ${RED}STOPPED${NC} ]\n" "$1"
        fi
    }
    _row "Xray Core (VMess/VLESS/Trojan)" "xray"
    _row "Dropbear SSH"                   "dropbear"
    _row "Stunnel4 TLS"                   "stunnel4"
    _row "Nginx WebServer"                "nginx"
    _row "SSH-WS Proxy"                   "ssh-ws"
    _row "SlowDNS (DNSTT)"               "slowdns"
    _row "HTTP Proxy (Port 8080)"         "3proxy"
    _row "Cron Scheduler"                 "cron"
    _row "OpenVPN"                        "openvpn"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    get_ram_info
    echo -e " Server Uptime : ${WHITE}$(get_uptime)${NC}"
    echo -e " RAM Usage     : ${WHITE}${USED_RAM} MB / ${TOTAL_RAM} MB${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_any_key
}

# ============================================================
# SETTINGS MENU
# ============================================================
settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}              SYSTEM SETTINGS MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Speedtest VPS"
        echo -e "  ${WHITE}[02]${NC} Info Port"
        echo -e "  ${WHITE}[03]${NC} Set Auto Reboot (Interval)"
        echo -e "  ${WHITE}[04]${NC} Set Auto Reboot (Specific Time)"
        echo -e "  ${WHITE}[05]${NC} View Server Reboot Log"
        echo -e "  ${WHITE}[06]${NC} Restart All Services"
        echo -e "  ${WHITE}[07]${NC} Change Banner"
        echo -e "  ${WHITE}[08]${NC} Check Bandwidth"
        echo -e "  ${WHITE}[09]${NC} Server Health Check"
        echo -e "  ${WHITE}[10]${NC} SlowDNS Key Manager"
        echo -e "  ${WHITE}[11]${NC} Pull Updates (OTA)"
        echo -e "  ${WHITE}[12]${NC} Toggle OpenVPN (ON/OFF) (RAM Saver)"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) run_speedtest ;;
            2|02) show_ports ;;
            3|03) set_reboot_interval ;;
            4|04) set_reboot_time ;;
            5|05) view_reboot_log ;;
            6|06) restart_all_services ;;
            7|07) change_banner ;;
            8|08) check_bandwidth ;;
            9|09) server_health_check ;;
            10)   slowdns_manager ;;
            11)   ota_update ;;
            12)   toggle_openvpn ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

run_speedtest() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                  OOKLA SPEEDTEST${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if command -v speedtest &>/dev/null; then speedtest
    elif command -v speedtest-cli &>/dev/null; then speedtest-cli
    else
        echo -e " ${YELLOW}Installing speedtest-cli...${NC}"
        pip3 install speedtest-cli -q 2>/dev/null && speedtest-cli || \
        echo -e " ${RED}[!] Install: pip3 install speedtest-cli${NC}"
    fi
    press_any_key
}

show_ports() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}               SYSTEM PORTS & INFO${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${WHITE}>> Service & Port List${NC}"
    echo -e "  - OpenSSH              : 22"
    echo -e "  - Dropbear             : 109, 143"
    echo -e "  - Stunnel4             : 447, 777"
    echo -e "  - SSH-WS (HTTP)        : 80"
    echo -e "  - Custom SSH (HTTP)    : 8880"
    echo -e "  - Xray VLESS TLS       : 443"
    echo -e "  - Xray VMess TLS       : 443"
    echo -e "  - Xray Trojan TLS      : 443"
    echo -e "  - Nginx Multiplexer    : 81, 443"
    echo -e "  - SlowDNS (DNSTT)      : 53, 5300"
    echo -e "  - BadVPN UDPGW         : 7300"
    echo -e "  - SOCKS5 Proxy         : 1080"
    echo -e "  - HTTP Proxy           : 8080"
    echo -e "  - OpenVPN TCP          : 1194"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${WHITE}>> Server Status${NC}"
    echo -e "  - IP Address : ${WHITE}$IP_VPS${NC}"
    echo -e "  - Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e "  - NS Domain  : ${WHITE}$NS_DOMAIN${NC}"
    press_any_key
}

set_reboot_interval() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}        AUTO-REBOOT SETTINGS (INTERVAL)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Every 1 Hour"
    echo -e " [2] Every 6 Hours"
    echo -e " [3] Every 12 Hours"
    echo -e " [4] Every 24 Hours (Daily)"
    echo -e " [5] Turn OFF Auto-Reboot"
    echo -ne " Select: "; read -r ch
    case $ch in
        1) echo "0 * * * * root /sbin/reboot"    > /etc/cron.d/vpn-reboot; echo -e "${GREEN}[✓] Every 1 hour${NC}" ;;
        2) echo "0 */6 * * * root /sbin/reboot"  > /etc/cron.d/vpn-reboot; echo -e "${GREEN}[✓] Every 6 hours${NC}" ;;
        3) echo "0 */12 * * * root /sbin/reboot" > /etc/cron.d/vpn-reboot; echo -e "${GREEN}[✓] Every 12 hours${NC}" ;;
        4) echo "0 0 * * * root /sbin/reboot"    > /etc/cron.d/vpn-reboot; echo -e "${GREEN}[✓] Daily${NC}" ;;
        5) rm -f /etc/cron.d/vpn-reboot; echo -e "${GREEN}[✓] Auto-reboot disabled!${NC}" ;;
    esac
    press_any_key
}

set_reboot_time() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}     AUTO-REBOOT SETTINGS (SPECIFIC TIME)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Example: 0 = Midnight, 13 = 1 PM, 23 = 11 PM"
    echo -ne " Input hour (0-23): "; read -r HOUR
    if [[ "$HOUR" =~ ^[0-9]+$ ]] && [ "$HOUR" -ge 0 ] && [ "$HOUR" -le 23 ]; then
        echo "0 $HOUR * * * root /sbin/reboot" > /etc/cron.d/vpn-reboot
        echo -e "${GREEN}[✓] Auto-reboot set at $(printf '%02d:00' $HOUR) daily!${NC}"
    else
        echo -e "${RED}[!] Invalid hour!${NC}"
    fi
    press_any_key
}

view_reboot_log() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                SERVER REBOOT LOG${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Current Uptime: ${WHITE}$(get_uptime)${NC}"
    echo ""
    echo -e " Displaying last 10 reboots:"
    echo ""
    last reboot | head -10
    press_any_key
}

restart_all_services() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                RESTARTING SERVICES${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    _rsvc() {
        systemctl restart "$2" 2>/dev/null
        systemctl is-active --quiet "$2" 2>/dev/null \
            && printf " %-30s[ ${GREEN}RESTARTED${NC} ]\n" "$1" \
            || printf " %-30s[ ${YELLOW}SKIPPED${NC} ]\n" "$1"
    }
    _rsvc "Dropbear SSH"    "dropbear"
    _rsvc "Stunnel4 TLS"    "stunnel4"
    _rsvc "Xray Core"       "xray"
    _rsvc "Nginx WebServer" "nginx"
    _rsvc "SlowDNS (DNSTT)" "slowdns"
    _rsvc "SSH-WS Proxy"    "ssh-ws"
    _rsvc "Cron Scheduler"  "cron"
    _rsvc "HTTP Proxy"      "3proxy"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}All Services Restarted Successfully!${NC}"
    press_any_key
}

change_banner() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                  CHANGE BANNER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Current /etc/issue.net:"
    cat /etc/issue.net 2>/dev/null || echo -e " ${YELLOW}[i] No banner set${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Edit with nano? [y/N]: "; read -r ch
    [[ "$ch" =~ ^[Yy]$ ]] && nano /etc/issue.net
    press_any_key
}

check_bandwidth() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}               BANDWIDTH MONITOR${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Live Traffic"
    echo -e " [2] Daily Usage"
    echo -e " [3] Monthly Usage"
    echo -ne " Select: "; read -r ch
    case $ch in
        1)
            if command -v ifstat &>/dev/null; then
                echo -e " Monitoring eth0... (Ctrl+C to stop)"; ifstat -i eth0 1
            elif command -v nload &>/dev/null; then nload eth0
            else echo -e " ${YELLOW}[i] Install ifstat: apt install ifstat${NC}"; fi ;;
        2) command -v vnstat &>/dev/null && vnstat -d || echo -e " ${YELLOW}[i] Install: apt install vnstat${NC}" ;;
        3) command -v vnstat &>/dev/null && vnstat -m || echo -e " ${YELLOW}[i] Install: apt install vnstat${NC}" ;;
    esac
    press_any_key
}

server_health_check() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           SERVER HEALTH & STATUS CHECK${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ping -c1 -W2 "$DOMAIN" &>/dev/null \
        && echo -e " Domain         : [${GREEN}OK${NC}] $DOMAIN" \
        || echo -e " Domain         : [${RED}UNREACHABLE${NC}] $DOMAIN"
    [ -f "$XRAY_CONFIG" ] \
        && echo -e " Xray Config    : [${GREEN}Found${NC}]" \
        || echo -e " Xray Config    : [${RED}Not Found${NC}]"
    for svc in xray ssh nginx dropbear stunnel4; do
        systemctl is-active --quiet "$svc" 2>/dev/null \
            && echo -e " $svc              : [${GREEN}RUNNING${NC}]" \
            || echo -e " $svc              : [${RED}STOPPED${NC}]"
    done
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           SCRIPT INTEGRITY CHECK${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for db in "$SSH_DB" "$VMESS_DB" "$VLESS_DB" "$TROJAN_DB" "$SETTINGS"; do
        BN=$(basename "$db")
        [ -f "$db" ] && echo -e " $BN : [${GREEN}OK${NC}]" || echo -e " $BN : [${YELLOW}MISSING${NC}]"
    done
    press_any_key
}

slowdns_manager() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              SLOWDNS KEY MANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Current PubKey : ${WHITE}${SLOWDNS_PUBKEY:-Not Set}${NC}"
    echo ""
    echo -e " [1] Set Custom Public Key"
    echo -e " [2] Generate New Key Pair"
    echo -e " [0] Back"
    echo -ne " Select: "; read -r ch
    case $ch in
        1)
            echo -ne " Enter PubKey: "; read -r NK
            sed -i "s/^SLOWDNS_PUBKEY=.*/SLOWDNS_PUBKEY=$NK/" "$SETTINGS"
            echo -e "${GREEN}[✓] Key updated!${NC}" ;;
        2)
            if command -v dnstt-server &>/dev/null; then
                mkdir -p /etc/slowdns
                dnstt-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub 2>/dev/null
                NK=$(cat /etc/slowdns/server.pub 2>/dev/null)
                sed -i "s/^SLOWDNS_PUBKEY=.*/SLOWDNS_PUBKEY=$NK/" "$SETTINGS"
                echo -e "${GREEN}[✓] New key pair generated!${NC}"
                echo -e " PubKey: ${WHITE}$NK${NC}"
            else
                echo -e "${RED}[!] dnstt-server not installed${NC}"
            fi ;;
    esac
    press_any_key
}

ota_update() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}               SYSTEM UPDATER (OTA)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " 🔄 Connecting to update server..."
    echo -e " ⬇️  Synchronizing & upgrading packages..."
    apt-get update -qq 2>/dev/null && apt-get upgrade -y -qq 2>/dev/null
    echo -e " ✅ ${GREEN}System updated successfully!${NC}"
    press_any_key
}

toggle_openvpn() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}            OPENVPN SERVICE TOGGLE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if systemctl is-active --quiet openvpn 2>/dev/null; then
        echo -e " Current Status : ${GREEN}ONLINE (Running)${NC}"
        echo -e " This will free up ~40MB of RAM."
        echo -ne " Disable OpenVPN? [y/N]: "; read -r ch
        [[ "$ch" =~ ^[Yy]$ ]] && systemctl stop openvpn && systemctl disable openvpn 2>/dev/null \
            && echo -e "${GREEN}[✓] OpenVPN disabled!${NC}"
    else
        echo -e " Current Status : ${RED}OFFLINE (Stopped)${NC}"
        echo -ne " Enable OpenVPN? [y/N]: "; read -r ch
        [[ "$ch" =~ ^[Yy]$ ]] && systemctl start openvpn && systemctl enable openvpn 2>/dev/null \
            && echo -e "${GREEN}[✓] OpenVPN enabled!${NC}"
    fi
    press_any_key
}

# ============================================================
# BACKUP MANAGER
# ============================================================
backup_menu() {
    while true; do
        clear
        BK_STATUS="OFF"
        crontab -l 2>/dev/null | grep -q "vpn-backup" && BK_STATUS="ON"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}              SYSTEM BACKUP MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e " Auto-Backup Status: [${GREEN}$BK_STATUS${NC}]"
        echo ""
        echo -e "  ${WHITE}[01]${NC} Run Manual Backup Now"
        echo -e "  ${WHITE}[02]${NC} Set Auto-Backup (Every 12 Hours)"
        echo -e "  ${WHITE}[03]${NC} Set Auto-Backup (Every 24 Hours)"
        echo -e "  ${WHITE}[04]${NC} Turn OFF Auto-Backup"
        echo -e "  ${WHITE}[05]${NC} Set Telegram Credentials"
        echo -e "  ${WHITE}[06]${NC} View Telegram Credentials"
        echo -e "  ${WHITE}[07]${NC} Restore From Backup Link"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) run_backup ;;
            2|02) set_auto_backup "0 */12 * * *" "12 hours" ;;
            3|03) set_auto_backup "0 0 * * *" "24 hours" ;;
            4|04) crontab -l 2>/dev/null | grep -v "vpn-backup" | crontab -
                  echo -e "${GREEN}[✓] Auto-backup disabled!${NC}"; sleep 1 ;;
            5|05) set_telegram_creds ;;
            6|06) view_telegram_creds ;;
            7|07) restore_backup ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

run_backup() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                  RUNNING BACKUP${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    BK="/tmp/vpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e " [+] Compiling portable user & system data..."
    tar -czf "$BK" "$VPN_DIR" "$XRAY_CONFIG" 2>/dev/null
    echo -e " [+] Backup saved: ${WHITE}$BK${NC}"
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        echo -e " [+] Sending to Telegram..."
        curl -s -F "document=@$BK" -F "chat_id=$CHAT_ID" \
             -F "caption=VPN Backup - $(date)" \
             "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" > /dev/null \
             && echo -e " ${GREEN}[✓] Sent to Telegram!${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}BACKUP COMPLETED!${NC}"
    press_any_key
}

set_auto_backup() {
    local CRON="$1" LABEL="$2"
    SC="/usr/local/bin/vpn-backup.sh"
    cat > "$SC" << 'BKEOF'
#!/bin/bash
source /etc/vpn-manager/settings.conf
BK="/tmp/vpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BK" /etc/vpn-manager /usr/local/etc/xray/config.json 2>/dev/null
if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s -F "document=@$BK" -F "chat_id=$CHAT_ID" \
         -F "caption=Auto Backup - $(date)" \
         "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" > /dev/null
fi
rm -f "$BK"
BKEOF
    chmod +x "$SC"
    (crontab -l 2>/dev/null | grep -v "vpn-backup"; echo "$CRON $SC") | crontab -
    echo -e "${GREEN}[✓] Auto-backup every $LABEL enabled!${NC}"; sleep 1
}

set_telegram_creds() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           SET TELEGRAM CREDENTIALS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Bot Token : "; read -r NT
    echo -ne " Chat ID   : "; read -r NCI
    sed -i "s/^BOT_TOKEN=.*/BOT_TOKEN=$NT/" "$SETTINGS"
    sed -i "s/^CHAT_ID=.*/CHAT_ID=$NCI/" "$SETTINGS"
    echo -e "${GREEN}[✓] Credentials saved!${NC}"
    press_any_key
}

view_telegram_creds() {
    clear; load_settings
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}          CURRENT TELEGRAM CREDENTIALS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " BOT TOKEN : ${WHITE}${BOT_TOKEN:-Not Set}${NC}"
    echo -e " CHAT ID   : ${WHITE}${CHAT_ID:-Not Set}${NC}"
    press_any_key
}

restore_backup() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}             SYSTEM RESTORE MANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Hint: Paste your Google Drive or direct download link."
    echo -ne " Paste Backup Link : "; read -r LINK
    echo -e " [+] Downloading backup..."
    curl -sL "$LINK" -o /tmp/restore.tar.gz
    if [ -f /tmp/restore.tar.gz ]; then
        tar -xzf /tmp/restore.tar.gz -C /
        rm -f /tmp/restore.tar.gz
        echo -e " ${GREEN}[✓] Restore completed!${NC}"
    else
        echo -e " ${RED}[!] Failed to download backup!${NC}"
    fi
    press_any_key
}

# ============================================================
# DOMAIN & SSL MANAGER
# ============================================================
domain_ssl_menu() {
    while true; do
        clear; load_settings
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}              DOMAIN & SSL MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e " Current Domain : ${WHITE}$DOMAIN${NC}"
        echo -e " Current NS     : ${WHITE}$NS_DOMAIN${NC}"
        echo ""
        echo -e "  ${WHITE}[01]${NC} Change VPS Domain (Host)"
        echo -e "  ${WHITE}[02]${NC} Change NameServer (SlowDNS NS)"
        echo -e "  ${WHITE}[03]${NC} Force Renew SSL Certificate (Crucial!)"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01)
                echo -ne " New Domain: "; read -r ND
                sed -i "s/^DOMAIN=.*/DOMAIN=$ND/" "$SETTINGS"
                echo -e "${GREEN}[✓] Domain updated to $ND${NC}"; sleep 1 ;;
            2|02)
                echo -ne " New NS Domain: "; read -r NNS
                sed -i "s/^NS_DOMAIN=.*/NS_DOMAIN=$NNS/" "$SETTINGS"
                echo -e "${GREEN}[✓] NS updated to $NNS${NC}"; sleep 1 ;;
            3|03)
                echo -e " ${YELLOW}Renewing SSL for $DOMAIN...${NC}"
                if command -v certbot &>/dev/null; then
                    certbot renew --force-renewal
                elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
                    "$HOME/.acme.sh/acme.sh" --renew -d "$DOMAIN" --force
                else
                    echo -e " ${RED}[!] certbot or acme.sh not found!${NC}"
                fi
                sleep 2 ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================================
# ENTRY POINT
# ============================================================
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] This script must be run as root:${NC}"
    echo -e "    sudo bash vpn-manager.sh"
    exit 1
fi

init_dirs
main_menu
