# 🚀 Ultimate All-In-One Linux VPN Server & Management Script

An enterprise-grade, high-performance VPN auto-installer and interactive management script designed for **Ubuntu VPS** servers. Built with **Xray-Core**, **SSH-WS (WebSocket CDN)**, **Dropbear**, **Stunnel4**, **SlowDNS (DNSTT)**, and **BadVPN UDPGW**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-orange.svg)](https://ubuntu.com)
[![Architecture](https://img.shields.io/badge/Architecture-x86__64%20%7C%20aarch64-green.svg)]()

---

## 📋 Table of Contents
- [Features & Supported Protocols](#-features--supported-protocols)
- [Default Port Allocation](#-default-port-allocation)
- [Prerequisites](#-prerequisites)
- [One-Click Installation](#-one-click-installation)
- [Post-Installation & Menu Command](#-post-installation--menu-command)
- [Menu Features Guide](#-menu-features-guide)
- [Client Configuration Payloads](#-client-configuration-payloads)
- [Backup & Restore Guide](#-backup--restore-guide)
- [Troubleshooting & FAQ](#-troubleshooting--faq)

---

## ✨ Features & Supported Protocols

- **⚡ Xray-Core (Latest Release):**
  - **VMess:** WebSocket + TLS, HTTPUpgrade (CloudFront bypass), and No-TLS (Port 80).
  - **VLESS:** WebSocket + TLS, HTTPUpgrade, and standard WS.
  - **Trojan:** WebSocket + TLS on Port 443.
- **🛡️ SSH & Dropbear:**
  - Standard OpenSSH on port 22.
  - Dropbear multi-port listener on ports 109 and 143.
  - Direct password authentication for tunneling.
- **🌐 SSH-WS (CDN WebSocket Proxy):**
  - Transparent HTTP WebSocket reverse proxy on ports **80** and **8880**.
  - Optimized for Cloudflare, Fastly, CloudFront, and ISP bug-host SNI payloads.
- **🔒 Stunnel4 (SSL/TLS Tunnel):**
  - Encrypted TLS wrappers on ports **447** and **777** forwarding to Dropbear and OpenSSH.
- **📡 SlowDNS / DNSTT:**
  - DNS tunneling on port **53** and **5300** for zero-balance or firewall-restricted networks.
  - Automated public/private keypair generation and rotation.
- **🎮 BadVPN UDPGW (Port 7300):**
  - Native UDP packet forwarding enabling WhatsApp voice/video calls and low-latency mobile online games.
- **🔐 Automatic SSL Certificates:**
  - Automated Let's Encrypt certificate issuance and renewal via Certbot.
- **🚀 TCP BBR Congestion Control:**
  - Automatically enabled in Linux kernel sysctl for maximum throughput and minimum latency.

---

## 🔌 Default Port Allocation

| Service | Port(s) | Protocol | Note |
|---|---|---|---|
| **OpenSSH** | `22` | TCP | Standard Linux SSH |
| **Dropbear** | `109`, `143` | TCP | Lightweight SSH for tunneling |
| **SSH-WS Proxy** | `80` | TCP / HTTP | WebSocket CDN proxy |
| **Custom SSH-WS** | `8880` | TCP / HTTP | Custom ISP Bug Bypass port |
| **Xray VLESS TLS** | `443` | TCP / TLS | Multiplexed with SNI fallback |
| **Xray VMess TLS** | `443` | TCP / TLS | Path `/vmess` & `/vmess-http` |
| **Xray Trojan TLS**| `443` | TCP / TLS | Path `/trojan-ws` |
| **Stunnel4 TLS** | `447`, `777` | TCP / TLS | Encrypted Dropbear / OpenSSH |
| **SlowDNS (DNSTT)**| `53`, `5300`| UDP | DNS Tunneling |
| **BadVPN UDPGW** | `7300` | UDP | VoIP WhatsApp & Gaming |
| **HTTP Proxy** | `8080` | TCP | Local HTTP proxy bridge |

---

## 🛠️ Prerequisites

Before installing, ensure you have:
1. A fresh VPS running **Ubuntu 20.04**, **22.04**, or **24.04** LTS (root access required).
2. A registered domain or subdomain pointed to your VPS public IPv4 address:
   - **Main Domain (A Record):** e.g., `vpn.yourdomain.com` pointing to `YOUR_VPS_IP`.
   - **NameServer (NS Record):** e.g., `ns.yourdomain.com` pointing to `vpn.yourdomain.com` (for SlowDNS).
3. Ensure ports `22, 80, 443, 109, 143, 447, 777, 8880, 8080, 53 (UDP), 7300 (UDP)` are opened in your Cloud Firewall (Oracle Cloud, AWS Security Groups, Azure, Google Cloud, etc.).

---

## 📥 One-Click Installation

Log into your VPS terminal as `root` and run:

```bash
wget -O install.sh https://raw.githubusercontent.com/abdulyusuf1471-art/VPN_SCRIPT/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

### What happens during installation:
1. The installer updates system repositories and installs all dependencies (`nginx`, `xray`, `dropbear`, `stunnel4`, `certbot`, `python3`, `iptables`, etc.).
2. You will be prompted to enter:
   - **Your VPS Domain** (e.g., `vpn.yourdomain.com`)
   - **Your NameServer (NS) Domain** (e.g., `ns.yourdomain.com`)
   - **Client / Owner Name** (e.g., `VPS` or your name)
3. Let's Encrypt generates a valid SSL certificate for your domain.
4. Services are configured, enabled, and started automatically.
5. The command `menu` is linked to `/usr/bin/menu`.

---

## 🖥️ Post-Installation & Menu Command

Once the installation finishes, simply type:

```bash
menu
```

The interactive dashboard will appear:

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    LICENSE INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Client       : VPS
 Expiry Date  : 2027-01-01
 Days Left    : Active
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     VPS INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Server Uptime    = 1 hour, 30 minutes
 Operating System = Ubuntu 24.04 LTS
 Current Domain   = vpn.yourdomain.com
 NS Domain        = ns.yourdomain.com
 Total Ram        = 3906 MB | Free: 2887 MB
 CPU Usage        = 4.5%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                   @VPN MANAGER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     SSH         VMESS        VLESS       TROJAN
      3           1            1           1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SSH:ON NGINX:OFF XRAY:ON DROPBEAR:ON SSH-WS:ON
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [01] SSH    [Menu]        [06] BACKUP
  [02] VMESS  [Menu]        [07] DOMAIN & SSL
  [03] VLESS  [Menu]        [08] CHECK RUNNING
  [04] TROJAN [Menu]        [00] EXIT SYSTEM
  [05] SETTING [Menu]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Select menu : 
```

---

## 📖 Menu Features Guide

### [01] SSH & OpenVPN Connection Manager
- **Create SSH Account:** Create accounts with custom validity (days) and multi-login limits.
- **Generate Trial SSH:** 1-click generation of 24-hour trial accounts.
- **Create Timed SSH (Minutes):** Temporary test accounts that automatically expire after a set number of minutes.
- **Renew / Delete Account:** Extend expiration date or delete users.
- **Check User Login:** View active connections and current logged-in users.
- **Autokill Multi-Login:** Automatically kicks users exceeding their connection limit.
- **Security & Lock Manager:** Lock/unlock accounts or block offending IP addresses.

### [02] VMess Manager
- Add VMess users and auto-generate client links:
  - `vmess://` TLS link (Cloudflare / Standard port 443)
  - `vmess://` HTTP-Upgrade link (AWS CloudFront bypass)
  - `vmess://` No-TLS link (Port 80)
- Auto-clean expired accounts.

### [03] VLESS Manager
- Add VLESS accounts and generate:
  - Standard `vless://` WebSocket TLS
  - CloudFront `vless://` HTTP-Upgrade
  - Port 80 direct No-TLS

### [04] Trojan Manager
- Manage Trojan-WS accounts with native TLS encryption on port 443.

### [05] System Settings & Utilities
- **Ookla Speedtest:** Test live VPS bandwidth and ping.
- **Port Inspector:** View all live listening ports.
- **Auto-Reboot Scheduler:** Schedule daily or interval reboots (e.g., every 6 hours to clear cache).
- **Restart Services:** 1-click restart for all VPN services.
- **Change Banner:** Customize the SSH login banner (`/etc/issue.net`).
- **SlowDNS Key Manager:** View and rotate public/private keys.

### [06] Backup & Restore
- **Manual Backup:** Tarball compression of `/etc/vpn-manager` and `/usr/local/etc/xray/config.json`.
- **Telegram Cloud Delivery:** Auto-send encrypted backup files to your Telegram Bot.
- **Auto-Backup Cron:** Set automated backups every 12 or 24 hours.
- **Restore from Link:** Restore user databases directly from a backup URL.

### [07] Domain & SSL Manager
- Update your server domain or SlowDNS NameServer anytime.
- Force-renew Let's Encrypt SSL certificates.

### [08] System Service Status
- Live color-coded health monitor showing real-time status of:
  `Xray-Core`, `Dropbear`, `Stunnel4`, `Nginx`, `SSH-WS`, `SlowDNS`, `BadVPN`, `Cron`.

---

## 📱 Client Configuration Payloads

### 1. SSH WebSocket (Port 80 - Cloudflare CDN)
```http
GET / HTTP/1.1[crlf]Host: vpn.yourdomain.com[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]
```

### 2. SSH WebSocket SSL (Port 443 - SNI Bug Host)
```http
GET wss://[BUG_HOST] [protocol][crlf]Host: vpn.yourdomain.com[crlf]Upgrade: websocket[crlf][crlf]
```
- **SNI / Server Name:** `[BUG_HOST]` or `vpn.yourdomain.com`

### 3. Custom Bypass (Port 8880)
```http
GET http://vpn.yourdomain.com:8880 HTTP/1.1[crlf]Host: [BUG_HOST][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]
```

---

## 🔒 Security Best Practices

1. **Firewall:** Only keep the necessary VPN ports open in your cloud provider's console.
2. **Backups:** Configure Telegram credentials under `Menu > [06] BACKUP` to receive automated database backups daily.
3. **Multi-Login Enforcement:** Keep `Autokill` enabled (`Menu > [01] > [09]`) to prevent account sharing and server congestion.

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
Feel free to customize, modify, and distribute.
