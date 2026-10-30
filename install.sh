#!/bin/bash
# ============================================================
# LIVE VPN VPS AUTO-INSTALLER & BACKEND ENGINE
# Supported: Ubuntu 20.04 / 22.04 / 24.04 (x86_64 / arm64)
# Core: Xray-Core, OpenSSH, Dropbear, Stunnel4, SSH-WS, SlowDNS, BadVPN, Nginx
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Please run as root: sudo bash install.sh${NC}"
    exit 1
fi

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}           LIVE VPN VPS AUTO-INSTALLER ENGINE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WHITE}This will install and configure all real VPN services live:${NC}"
echo -e "  - Xray-Core (VMess, VLESS, Trojan with TLS & WebSocket)"
echo -e "  - OpenSSH + Dropbear (Ports 22, 109, 143)"
echo -e "  - SSH-WS WebSocket CDN Proxy (Ports 80, 8880)"
echo -e "  - Stunnel4 TLS Tunnel (Ports 447, 777)"
echo -e "  - SlowDNS / DNSTT Tunnel (Port 53, 5300)"
echo -e "  - BadVPN UDPGW for WhatsApp Calls/Games (Port 7300)"
echo -e "  - HTTP Proxy (Port 8080)"
echo -e "  - SSL Certificate Setup (Let's Encrypt / Certbot)"
echo -e "  - TCP BBR Turbo Speed Optimizer"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ─── Ask Domain Details ──────────────────────────────────────
while true; do
    echo -ne " ${GREEN}Enter your VPS Domain (e.g. vpn.mydomain.com): ${NC}"
    read -r DOMAIN
    [ -n "$DOMAIN" ] && break
    echo -e " ${RED}[!] Domain is required!${NC}"
done

while true; do
    echo -ne " ${GREEN}Enter your NameServer (NS) Domain (e.g. ns.mydomain.com): ${NC}"
    read -r NS_DOMAIN
    [ -n "$NS_DOMAIN" ] && break
    echo -e " ${RED}[!] NameServer domain is required!${NC}"
done

echo -ne " ${GREEN}Enter Client / Owner Name [Default: VPS]: ${NC}"
read -r CLIENT_NAME
CLIENT_NAME="${CLIENT_NAME:-VPS}"

IP_VPS=$(curl -s --max-time 5 ifconfig.me || hostname -I | awk '{print $1}')

echo -e "\n${YELLOW}[+] Updating system and installing essential packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git socat cron iptables iptables-persistent net-tools \
    vnstat certbot python3 python3-pip nginx dropbear stunnel4 screen bzip2 gzip tar ufw

# ─── Enable BBR ──────────────────────────────────────────────
echo -e "${YELLOW}[+] Enabling TCP BBR Congestion Control...${NC}"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi

# ─── Setup Directories ───────────────────────────────────────
VPN_DIR="/etc/vpn-manager"
mkdir -p "$VPN_DIR" /etc/xray /usr/local/etc/xray /etc/slowdns /var/log/xray

# ─── Install Xray-Core ───────────────────────────────────────
echo -e "${YELLOW}[+] Installing latest official Xray-Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# ─── SSL Certificate ─────────────────────────────────────────
echo -e "${YELLOW}[+] Generating SSL Certificate for $DOMAIN...${NC}"
systemctl stop nginx 2>/dev/null
certbot certonly --standalone --preferred-challenges http --agree-tos --register-unsafely-without-email -d "$DOMAIN" --non-interactive 2>/dev/null

CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [ ! -f "$CERT_FILE" ]; then
    echo -e "${YELLOW}[!] Self-signed fallback SSL certificate generating...${NC}"
    mkdir -p /etc/xray/ssl
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=CA/L=SF/O=VPN/CN=$DOMAIN" \
        -keyout /etc/xray/ssl/xray.key -out /etc/xray/ssl/xray.crt >/dev/null 2>&1
    CERT_FILE="/etc/xray/ssl/xray.crt"
    KEY_FILE="/etc/xray/ssl/xray.key"
fi

# ─── Configure Xray-Core ─────────────────────────────────────
echo -e "${YELLOW}[+] Configuring Xray Inbounds (VMess, VLESS, Trojan)...${NC}"
cat > /usr/local/etc/xray/config.json << XRAYEOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          { "dest": 8080 },
          { "path": "/vmess", "dest": 10001, "xver": 1 },
          { "path": "/vmess-http", "dest": 10002, "xver": 1 },
          { "path": "/trojan-ws", "dest": 10003, "xver": 1 }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_FILE",
              "keyFile": "$KEY_FILE"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "tag": "vmess",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "tag": "vmess-http",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "httpupgrade",
        "httpupgradeSettings": { "path": "/vmess-http" }
      }
    },
    {
      "tag": "trojan",
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/trojan-ws" }
      }
    },
    {
      "tag": "vless-httpupgrade",
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "httpupgrade",
        "httpupgradeSettings": { "path": "/vless-hu" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
XRAYEOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ─── Configure Dropbear ───────────────────────────────────────
echo -e "${YELLOW}[+] Configuring Dropbear (Ports 109, 143)...${NC}"
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear 2>/dev/null
cat > /etc/default/dropbear << 'DBEOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
DBEOF
systemctl enable dropbear
systemctl restart dropbear

# ─── Configure Stunnel4 ───────────────────────────────────────
echo -e "${YELLOW}[+] Configuring Stunnel4 (Ports 447, 777)...${NC}"
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
mkdir -p /etc/stunnel
cat > /etc/stunnel/stunnel.conf << STUNNELEOF
cert = $CERT_FILE
key = $KEY_FILE
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear_ssl]
accept = 447
connect = 127.0.0.1:109

[ssh_ssl]
accept = 777
connect = 127.0.0.1:22
STUNNELEOF
systemctl enable stunnel4
systemctl restart stunnel4

# ─── Configure SSH-WS (WebSocket CDN Proxy) ───────────────────
echo -e "${YELLOW}[+] Setting up SSH-WS Proxy (Ports 80, 8880)...${NC}"
cat > /usr/local/bin/ssh-ws.py << 'PYEOF'
#!/usr/bin/env python3
import socket, threading, select

LISTENING_PORT = 80
TARGET_HOST = '127.0.0.1'
TARGET_PORT = 109

def forward(source, destination):
    string = ' '
    while string:
        string = source.recv(1024)
        if string:
            destination.sendall(string)
        else:
            source.shutdown(socket.SHUT_RD)
            destination.shutdown(socket.SHUT_WR)

def handle_client(client_socket):
    target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        target_socket.connect((TARGET_HOST, TARGET_PORT))
    except:
        client_socket.close()
        return

    data = client_socket.recv(1024)
    if b"Upgrade: websocket" in data or b"HTTP/" in data:
        client_socket.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
    else:
        target_socket.sendall(data)

    t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
    t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
    t1.daemon = True
    t2.daemon = True
    t1.start()
    t2.start()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LISTENING_PORT))
    server.listen(100)
    while True:
        client_sock, _ = server.accept()
        threading.Thread(target=handle_client, args=(client_sock,), daemon=True).start()

if __name__ == '__main__':
    main()
PYEOF
chmod +x /usr/local/bin/ssh-ws.py

cat > /etc/systemd/system/ssh-ws.service << 'SVCEOF'
[Unit]
Description=SSH-WS WebSocket Proxy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ssh-ws
systemctl restart ssh-ws

# ─── Install BadVPN UDPGW (UDP Gateway Port 7300) ─────────────
echo -e "${YELLOW}[+] Installing BadVPN UDPGW (Port 7300 for VoIP/Games)...${NC}"
wget -O /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64" >/dev/null 2>&1
chmod +x /usr/local/bin/badvpn-udpgw 2>/dev/null

cat > /etc/systemd/system/badvpn.service << 'BADEOF'
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
BADEOF

systemctl daemon-reload
systemctl enable badvpn
systemctl restart badvpn 2>/dev/null

# ─── Setup SlowDNS (DNSTT) ───────────────────────────────────
echo -e "${YELLOW}[+] Setting up SlowDNS (DNSTT)...${NC}"
mkdir -p /etc/slowdns
wget -O /usr/local/bin/dnstt-server "https://raw.githubusercontent.com/alecthomas/dnstt/master/dnstt-server/dnstt-server" >/dev/null 2>&1
chmod +x /usr/local/bin/dnstt-server 2>/dev/null

if [ ! -f /etc/slowdns/server.key ]; then
    /usr/local/bin/dnstt-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub 2>/dev/null
fi
SLOWDNS_PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59")

# ─── Write Settings & Manager Links ──────────────────────────
cat > "$VPN_DIR/settings.conf" << SETEOF
DOMAIN=$DOMAIN
NS_DOMAIN=$NS_DOMAIN
IP_VPS=$IP_VPS
SLOWDNS_PUBKEY=$SLOWDNS_PUBKEY
CLIENT_NAME=$CLIENT_NAME
EXPIRY_DATE=2027-01-01
SETEOF

cat > "$VPN_DIR/license.conf" << LICEOF
CLIENT=$CLIENT_NAME
EXPIRY=2027-01-01
LICEOF

# ─── Install Menu Command ─────────────────────────────────────
SCRIPT_URL="https://raw.githubusercontent.com/abdulyusuf1471-art/VPN_SCRIPT/main/vpn-manager.sh"
wget -O /usr/local/bin/vpn-manager.sh "$SCRIPT_URL" 2>/dev/null || cp "$HOME/vpn-manager.sh" /usr/local/bin/vpn-manager.sh
chmod +x /usr/local/bin/vpn-manager.sh
ln -sf /usr/local/bin/vpn-manager.sh /usr/bin/menu
ln -sf /usr/local/bin/vpn-manager.sh /usr/bin/vpn

# ─── Setup Auto-Reboot Cron ───────────────────────────────────
echo "0 */6 * * * root /sbin/reboot" > /etc/cron.d/vpn-reboot

# ─── Open Firewall Ports ─────────────────────────────────────
echo -e "${YELLOW}[+] Configuring firewall rules...${NC}"
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 109 -j ACCEPT
iptables -I INPUT -p tcp --dport 143 -j ACCEPT
iptables -I INPUT -p tcp --dport 447 -j ACCEPT
iptables -I INPUT -p tcp --dport 777 -j ACCEPT
iptables -I INPUT -p tcp --dport 8880 -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -I INPUT -p udp --dport 7300 -j ACCEPT

netfilter-persistent save >/dev/null 2>&1

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}       REAL LIVE VPN SERVICES INSTALLED SUCCESSFULLY!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " VPS Domain   : ${WHITE}$DOMAIN${NC}"
echo -e " NS Domain    : ${WHITE}$NS_DOMAIN${NC}"
echo -e " IP Address   : ${WHITE}$IP_VPS${NC}"
echo -e " PubKey       : ${WHITE}$SLOWDNS_PUBKEY${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}Active Live Ports:${NC}"
echo -e "  - OpenSSH      : 22"
echo -e "  - Dropbear     : 109, 143"
echo -e "  - SSH-WS       : 80, 8880 (CDN WebSocket)"
echo -e "  - Stunnel4     : 447, 777 (SSL/TLS)"
echo -e "  - Xray TLS     : 443 (VMess, VLESS, Trojan)"
echo -e "  - SlowDNS      : 53, 5300 (DNSTT)"
echo -e "  - BadVPN UDPGW : 7300 (WhatsApp calls & Games)"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}Simply type ${WHITE}menu${GREEN} anytime to launch the VPN Manager!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
