#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# VPN MANAGER - DEMO / PREVIEW MODE (FOR TERMUX / NON-ROOT)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

VPN_DIR="$HOME/.vpn-manager-demo"
SSH_DB="$VPN_DIR/ssh-users.db"
VMESS_DB="$VPN_DIR/vmess-users.db"
VLESS_DB="$VPN_DIR/vless-users.db"
TROJAN_DB="$VPN_DIR/trojan-users.db"
SETTINGS="$VPN_DIR/settings.conf"
LICENSE_FILE="$VPN_DIR/license.conf"

init_demo_data() {
    mkdir -p "$VPN_DIR"
    if [ ! -f "$SETTINGS" ]; then
        cat > "$SETTINGS" << 'SET'
DOMAIN=kudex1.kudextech.com.ng
NS_DOMAIN=ns-kudex1.kudextech.com.ng
IP_VPS=20.164.216.47
SLOWDNS_PUBKEY=7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59
CLIENT=VPS
EXPIRY=2026-11-14
SET
    fi
    if [ ! -s "$SSH_DB" ]; then
        echo "tif|1|2026-12-21|100" >> "$SSH_DB"
        echo "john|pass123|2026-11-30|2" >> "$SSH_DB"
        echo "sarah|vpn2026|2026-12-05|1" >> "$SSH_DB"
    fi
    if [ ! -s "$VMESS_DB" ]; then
        echo "3444|9376ea1e-8ba1-4d4e-83e4-c5781124ef5d|2026-11-07" >> "$VMESS_DB"
    fi
    if [ ! -s "$VLESS_DB" ]; then
        echo "345|69863720-6488-42cc-94c7-78999db01f20|2026-10-28" >> "$VLESS_DB"
    fi
    if [ ! -s "$TROJAN_DB" ]; then
        echo "45yy|84f25529-2949-4be0-b013-3f35af541324|2026-10-20" >> "$TROJAN_DB"
    fi
}

load_settings() {
    [ -f "$SETTINGS" ] && source "$SETTINGS"
    IP_VPS="${IP_VPS:-20.164.216.47}"
    DOMAIN="${DOMAIN:-kudex1.kudextech.com.ng}"
    NS_DOMAIN="${NS_DOMAIN:-ns-kudex1.kudextech.com.ng}"
}

press_any_key() {
    echo -e "\n${YELLOW}Press ENTER to return...${NC}"
    read -r
}

gen_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "1c371969-fc0e-401b-8311-b965a5cb59d9"
}

count_users() {
    SSH_COUNT=$(grep -c '.' "$SSH_DB" 2>/dev/null || echo 0)
    VMESS_COUNT=$(grep -c '.' "$VMESS_DB" 2>/dev/null || echo 0)
    VLESS_COUNT=$(grep -c '.' "$VLESS_DB" 2>/dev/null || echo 0)
    TROJAN_COUNT=$(grep -c '.' "$TROJAN_DB" 2>/dev/null || echo 0)
}

print_header() {
    load_settings
    count_users
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    LICENSE INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Client       : ${WHITE}VPS${NC}"
    echo -e " Expiry Date  : ${WHITE}14-11-2026${NC}"
    echo -e " Days Left    : ${WHITE}36 Days${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                     VPS INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Server Uptime    = ${WHITE}1 hour, 30 minutes${NC}"
    echo -e " Current Time     = ${WHITE}$(date '+%d-%m-%Y | %H:%M:%S')${NC}"
    echo -e " Operating System = ${WHITE}Ubuntu 24.04.5 LTS (Simulated Demo)${NC}"
    echo -e " Current Domain   = ${WHITE}$DOMAIN${NC}"
    echo -e " NS Domain        = ${WHITE}$NS_DOMAIN${NC}"
    echo -e " Total Ram        = ${WHITE}3906 MB${NC}"
    echo -e " Total Used Ram   = ${WHITE}1019 MB${NC}"
    echo -e " Total Free Ram   = ${WHITE}2887 MB${NC}"
    echo -e " CPU Usage        = ${WHITE}4.5%${NC}"
    echo -e " Time Reboot VPS  = ${WHITE}Every 6 Hours${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main_menu() {
    while true; do
        clear
        print_header
        echo -e "${PURPLE}                   @VPN MANAGER (DEMO)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  Use Core : ${WHITE}Xray-Core 2023${NC}          IP-VPS : ${WHITE}$IP_VPS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "     SSH         VMESS        VLESS       TROJAN"
        echo -e "      ${GREEN}$SSH_COUNT${NC}           ${GREEN}$VMESS_COUNT${NC}            ${GREEN}$VLESS_COUNT${NC}           ${GREEN}$TROJAN_COUNT${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  SSH:${GREEN}ON${NC} NGINX:${RED}OFF${NC} XRAY:${GREEN}ON${NC} DROPBEAR:${GREEN}ON${NC} SSH-WS:${GREEN}ON${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} SSH    [Menu]        ${WHITE}[06]${NC} BACKUP"
        echo -e "  ${WHITE}[02]${NC} VMESS  [Menu]        ${WHITE}[07]${NC} DOMAIN & SSL"
        echo -e "  ${WHITE}[03]${NC} VLESS  [Menu]        ${WHITE}[08]${NC} CHECK RUNNING"
        echo -e "  ${WHITE}[04]${NC} TROJAN [Menu]        ${WHITE}[00]${NC} EXIT DEMO"
        echo -e "  ${WHITE}[05]${NC} SETTING [Menu]"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  MONITORING BANDWIDTH${NC}"
        echo -e "  BANDWIDTH USED TODAY       = 241.41 MiB"
        echo -e "  BANDWIDTH USED YESTERDAY   = 1.60 GiB"
        echo -e "  TOTAL BANDWIDTH THIS MONTH = 15.14 GiB"
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
            0|00) echo -e "\n${GREEN}Exiting Demo. Have a nice day!${NC}\n"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

ssh_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}           SSH & OPENVPN CONNECTION MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${WHITE}[01]${NC} Create SSH Account"
        echo -e "  ${WHITE}[02]${NC} Generate Trial SSH"
        echo -e "  ${WHITE}[03]${NC} List Member SSH"
        echo -e "  ${WHITE}[04]${NC} Show OpenVPN Config"
        echo -e "  ${WHITE}[00]${NC} Back to Main Menu"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne " Select menu : "; read -r opt
        case $opt in
            1|01) create_ssh ;;
            2|02) trial_ssh ;;
            3|03) list_ssh ;;
            4|04) show_ovpn ;;
            0|00) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

create_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                CREATE SSH ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne " Username      : "; read -r USERNAME
    echo -ne " Password      : "; read -r PASSWORD
    echo -ne " Expiry (days) : "; read -r DAYS
    echo -ne " Max Logins    : "; read -r MAX_LOGIN
    MAX_LOGIN="${MAX_LOGIN:-100}"
    EXPIRY_ISO=$(date -d "+${DAYS:-30} days" +"%Y-%m-%d" 2>/dev/null || echo "2026-12-21")
    echo "$USERNAME|$PASSWORD|$EXPIRY_ISO|$MAX_LOGIN" >> "$SSH_DB"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            PREMIUM SSH WS ACCOUNT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Username    : ${WHITE}$USERNAME${NC}"
    echo -e " Password    : ${WHITE}$PASSWORD${NC}"
    echo -e " Max Login   : ${WHITE}$MAX_LOGIN Connection(s)${NC}"
    echo -e " Expired On  : ${WHITE}$EXPIRY_ISO${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}            SERVER INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " IP          : ${WHITE}$IP_VPS${NC}"
    echo -e " Host        : ${WHITE}$DOMAIN${NC}"
    echo -e " Nameserver  : ${WHITE}$NS_DOMAIN${NC}"
    echo -e " PubKey      : ${WHITE}7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59${NC}"
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
    clear
    RAND=$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c4 || echo "1cb6")
    USERNAME="TRIAL-$RAND"
    PASSWORD="1"
    echo "$USERNAME|$PASSWORD|2026-10-31|1" >> "$SSH_DB"
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

list_ssh() {
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

show_ovpn() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              OPENVPN CONFIG LINKS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " OVPN TCP : ${WHITE}http://$DOMAIN:85/client-tcp.ovpn${NC}"
    echo -e " OVPN UDP : ${WHITE}http://$DOMAIN:85/client-udp.ovpn${NC}"
    press_any_key
}

vmess_menu() {
    clear
    UUID=$(gen_uuid)
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            VMESS ACCOUNT CREATED (SAMPLE)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Remarks    : ${WHITE}3444${NC}"
    echo -e " Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e " User ID    : ${WHITE}$UUID${NC}"
    echo -e " Expired On : ${WHITE}Nov 07, 2026${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${YELLOW}LINK TLS (Cloudflare/Standard) :${NC}"
    echo -e " vmess://eyJaddIjoi$DOMAINIiwicG9ydCI6IjQ0MyIsInBzIjoiMzQ0NCIsInNjeSI6ImF1dG8ifQ=="
    echo -e ""
    echo -e " ${YELLOW}LINK HTTP-UPGRADE (CloudFront Bypass) :${NC}"
    echo -e " vmess://eyJaddIjoi$DOMAINIiwicG9ydCI6IjQ0MyIsInBzIjoiMzQ0NCAoQ2xvdWRGcm9udCkiLCJzY3kiOiJhdXRvIn0="
    echo -e ""
    echo -e " ${YELLOW}LINK NO-TLS (Port 80) :${NC}"
    echo -e " vmess://eyJaddIjoi$DOMAINIiwicG9ydCI6IjgwIiwicHMiOiIzNDQ0Iiwic2N5IjoiYXV0byJ9"
    press_any_key
}

vless_menu() {
    clear
    UUID=$(gen_uuid)
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            VLESS ACCOUNT CREATED (SAMPLE)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Remarks    : ${WHITE}345${NC}"
    echo -e " Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e " User ID    : ${WHITE}$UUID${NC}"
    echo -e " Expired On : ${WHITE}Oct 28, 2026${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${YELLOW}LINK TLS (Cloudflare/Standard) :${NC}"
    echo -e " vless://$UUID@$DOMAIN:443?path=/vless&security=tls&encryption=none&type=ws#345"
    echo -e ""
    echo -e " ${YELLOW}LINK HTTP-UPGRADE (CloudFront Bypass) :${NC}"
    echo -e " vless://$UUID@$DOMAIN:443?path=/vless-hu&security=tls&encryption=none&type=httpupgrade#345_CloudFront"
    echo -e ""
    echo -e " ${YELLOW}LINK NO-TLS (Port 80) :${NC}"
    echo -e " vless://$UUID@$DOMAIN:80?path=/vless&encryption=none&type=ws#345"
    press_any_key
}

trojan_menu() {
    clear
    UUID=$(gen_uuid)
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            PREMIUM TROJAN ACCOUNT (SAMPLE)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Username   : ${WHITE}45yy${NC}"
    echo -e " Key/UUID   : ${WHITE}$UUID${NC}"
    echo -e " Expired On : ${WHITE}Oct 20, 2026${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${YELLOW}LINK TLS (WS) :${NC}"
    echo -e " trojan://$UUID@$DOMAIN:443?path=%2Ftrojan-ws&security=tls&host=$DOMAIN&type=ws&sni=$DOMAIN#45yy"
    press_any_key
}

check_running() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              SYSTEM SERVICE STATUS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "Xray Core (VMess/VLESS/Trojan)"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "Dropbear SSH"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "Stunnel4 TLS"
    printf " %-35s: [ ${RED}STOPPED${NC} ]\n" "Nginx WebServer"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "SSH-WS Proxy"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "SlowDNS (DNSTT)"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "HTTP Proxy (Port 8080)"
    printf " %-35s: [ ${GREEN}RUNNING${NC} ]\n" "Cron Scheduler"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Server Uptime : ${WHITE}1 hour, 34 minutes${NC}"
    echo -e " RAM Usage     : ${WHITE}1014 MB / 3906 MB${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_any_key
}

settings_menu() {
    clear
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${WHITE}>> Server Status${NC}"
    echo -e "  - IP Address : ${WHITE}$IP_VPS${NC}"
    echo -e "  - Domain     : ${WHITE}$DOMAIN${NC}"
    echo -e "  - NS Domain  : ${WHITE}$NS_DOMAIN${NC}"
    press_any_key
}

backup_menu() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              SYSTEM BACKUP MANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Auto-Backup Status: [${GREEN}ON${NC}]"
    echo ""
    echo -e "  [+] Compiling portable user & system data..."
    echo -e "  [+] Sending to Telegram / Google Drive..."
    echo -e ""
    echo -e "  ${GREEN}BACKUP COMPLETED!${NC}"
    echo -e "  Telegram Bot: Successfully delivered to chat."
    press_any_key
}

domain_ssl_menu() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}              DOMAIN & SSL MANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Current Domain : ${WHITE}$DOMAIN${NC}"
    echo -e " Current NS     : ${WHITE}$NS_DOMAIN${NC}"
    echo ""
    echo -e "  ${WHITE}[01]${NC} Change VPS Domain (Host)"
    echo -e "  ${WHITE}[02]${NC} Change NameServer (SlowDNS NS)"
    echo -e "  ${WHITE}[03]${NC} Force Renew SSL Certificate"
    press_any_key
}

init_demo_data
main_menu
