#!/bin/bash
# =============================================================
# KEVINTECH MULTI SCRIPT INSTALLER v4.0
# Premium Server Edition | Ubuntu
# =============================================================
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="4.0"
BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
LICENSE_CONF="$BASE/license.conf"
TMP="/tmp/kevintech_install_$$"
REPO="https://github.com/kevinaldaircama/multi-script.git"
LICENSE_API="https://usa.socialstreaming.xyz"
LICENSE_BOT="@multiscriptkeygen_bot"
SSHD_CFG="/etc/ssh/sshd_config"

INSTALL_KEY="${INSTALL_KEY:-}"
SERVER_DOMAIN=""
SERVER_IP=""
DOMAIN_IP=""
DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"
LICENSE_OWNER=""
LICENSE_RESELLER=""
LICENSE_TYPE="normal"
LICENSE_DELETE_AT=""

RESET="\e[0m"; BOLD="\e[1m"
RED="\e[1;91m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"
WHITE="\e[1;97m"; GRAY="\e[1;90m"
PINK="\e[38;5;213m"; PURPLE="\e[38;5;141m"; SKY="\e[38;5;117m"; GOLD="\e[38;5;220m"

cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

ok(){ echo -e " ${GREEN}✔${RESET} $1"; }
info(){ echo -e " ${CYAN}◆${RESET} $1"; }
warn(){ echo -e " ${YELLOW}⚠${RESET} $1"; }
fail(){ echo -e " ${RED}✖${RESET} $1"; }
line(){ echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
section(){ echo; echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"; echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD} $1${RESET}"; echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"; echo; }
loading(){ local t="$1"; echo -ne " ${CYAN}${t}${RESET} "; for _ in 1 2 3; do echo -ne "${PURPLE}●${RESET}"; sleep .12; done; echo; }
fatal(){ fail "$1"; exit 1; }

header(){
 clear 2>/dev/null || true
 echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
 echo -e "${CYAN}║${RESET} ${PINK}${BOLD}                 KEVINTECH MULTI SCRIPT${RESET}              ${CYAN}║${RESET}"
 echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                 PREMIUM INSTALLER v${VERSION}${RESET}              ${CYAN}║${RESET}"
 echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
 echo -e "${SKY}              🚀  S E R V E R   E D I T I O N  🚀${RESET}"
 echo
}

require_root(){ [[ $EUID -eq 0 ]] || fatal "Debes ejecutar este instalador como root."; }
require_ubuntu(){
 [[ -f /etc/os-release ]] || fatal "No se pudo detectar el sistema operativo."
 # shellcheck disable=SC1091
 source /etc/os-release
 [[ "${ID:-}" == "ubuntu" ]] || fatal "Este instalador requiere Ubuntu."
 case "${VERSION_ID:-}" in 22.04|24.04) ;; *) warn "Ubuntu ${VERSION_ID:-desconocido}; se recomienda 22.04/24.04." ;; esac
}

install_dependencies(){
 section "📦 PASO 0 • DEPENDENCIAS"
 export DEBIAN_FRONTEND=noninteractive
 loading "Actualizando repositorios"
 apt-get update -y >/dev/null 2>&1 || fatal "APT update falló."
 ok "Repositorios actualizados."
 loading "Instalando herramientas"
 apt-get install -y curl wget git jq ca-certificates dnsutils sudo openssl unzip zip tar nano cron net-tools lsof screen bc socat openssh-server ufw fail2ban iproute2 iptables iptables-persistent >/dev/null 2>&1 || fatal "No se pudieron instalar las dependencias."
 update-ca-certificates >/dev/null 2>&1 || true
 ok "Dependencias instaladas."
}

license_health(){
 local r h b
 r=$(curl -fsS -4 --connect-timeout 5 --max-time 15 -w '\n%{http_code}' "$LICENSE_API/health" 2>/dev/null) || return 1
 h=$(printf '%s\n' "$r" | tail -n1); b=$(printf '%s\n' "$r" | sed '$d')
 [[ "$h" == 200 ]] && echo "$b" | jq -e '.ok==true' >/dev/null 2>&1
}

validate_license(){
 section "🔐 PASO 1 • LICENCIA"
 echo -e "${WHITE}Bot oficial:${RESET} ${PINK}${BOLD}${LICENSE_BOT}${RESET}"
 license_health || fatal "El servidor de licencias no está disponible."
 ok "Sistema de licencias operativo."
 while :; do
  [[ -n "$INSTALL_KEY" ]] || { read -r -s -p "$(echo -e "${GOLD}🔑 Key: ${RESET}")" INSTALL_KEY; echo; }
  INSTALL_KEY=$(printf '%s' "$INSTALL_KEY" | tr -d '[:space:]')
  [[ -n "$INSTALL_KEY" ]] || { fail "La Key está vacía."; continue; }
  local req r h b valid err
  req=$(jq -n --arg key "$INSTALL_KEY" '{key:$key}')
  loading "Verificando licencia"
  r=$(curl -fsS -4 --connect-timeout 5 --max-time 15 -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' --data "$req" "$LICENSE_API/api/public/validate" 2>/dev/null) || { fail "No se pudo conectar con la API."; INSTALL_KEY=""; continue; }
  h=$(printf '%s\n' "$r" | tail -n1); b=$(printf '%s\n' "$r" | sed '$d')
  [[ "$h" =~ ^2 ]] || { fail "API respondió HTTP $h."; INSTALL_KEY=""; continue; }
  echo "$b" | jq empty >/dev/null 2>&1 || { fail "Respuesta JSON inválida."; INSTALL_KEY=""; continue; }
  valid=$(echo "$b" | jq -r '.ok // false'); err=$(echo "$b" | jq -r '.error // empty')
  if [[ "$valid" != true ]]; then
   case "$err" in key_not_found) fail "KEY NO ENCONTRADA";; key_used) fail "KEY YA UTILIZADA";; key_expired) warn "KEY EXPIRADA";; *) fail "KEY NO VÁLIDA";; esac
   INSTALL_KEY=""; continue
  fi
  LICENSE_OWNER=$(echo "$b" | jq -r '.owner // "Desconocido"')
  LICENSE_RESELLER=$(echo "$b" | jq -r '.reseller // "Desconocido"')
  LICENSE_TYPE=$(echo "$b" | jq -r '.type // "normal"')
  LICENSE_DELETE_AT=$(echo "$b" | jq -r '.deleteAt // empty')
  echo -e "${GREEN}✔ LICENCIA VÁLIDA${RESET} • ${WHITE}$LICENSE_OWNER${RESET} • ${CYAN}$LICENSE_TYPE${RESET}"
  break
 done
}

get_public_ip(){ curl -fsS -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null || true; }

configure_domain(){
 section "🌐 PASO 2 • DOMINIO"
 read -r -p "$(echo -e "${CYAN}🌐 Dominio del VPS: ${RESET}")" SERVER_DOMAIN
 SERVER_DOMAIN=$(printf '%s' "$SERVER_DOMAIN" | tr -d '[:space:]')
 [[ "$SERVER_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fatal "Dominio inválido."
 SERVER_IP=$(get_public_ip); [[ -n "$SERVER_IP" ]] || SERVER_IP="Desconocida"
 loading "Comprobando DNS"
 DOMAIN_IP=$(dig +short A "$SERVER_DOMAIN" 2>/dev/null | grep -E '^[0-9]+(\.[0-9]+){3}$' | head -n1 || true)
 if [[ -n "$DOMAIN_IP" && "$DOMAIN_IP" == "$SERVER_IP" ]]; then DOMAIN_IP_MATCH="YES"; ok "DNS apunta al VPS."; else warn "DNS aún no coincide con la IP del VPS."; fi
 local ns; ns=$(dig +short NS "$SERVER_DOMAIN" 2>/dev/null | tr '\n' ' ' || true)
 if echo "$ns" | grep -qi cloudflare; then DNS_PROVIDER="Cloudflare"; elif echo "$ns" | grep -Eqi 'awsdns|route53'; then DNS_PROVIDER="AWS Route 53"; elif echo "$ns" | grep -qi google; then DNS_PROVIDER="Google Cloud DNS"; elif echo "$ns" | grep -qi azure; then DNS_PROVIDER="Azure DNS"; elif echo "$ns" | grep -qi godaddy; then DNS_PROVIDER="GoDaddy"; elif echo "$ns" | grep -qi namecheap; then DNS_PROVIDER="Namecheap"; fi
 echo -e " ${GRAY}DNS:${RESET} ${SKY}$DNS_PROVIDER${RESET}"
 echo -e " ${GRAY}VPS:${RESET} ${CYAN}$SERVER_IP${RESET}"
}

configure_firewall(){
 section "🛡️ PASO 3 • FIREWALL"
 # No resetear UFW: evita borrar reglas ajenas.
 ufw default deny incoming >/dev/null 2>&1 || true
 ufw default allow outgoing >/dev/null 2>&1 || true
 ufw allow 22/tcp >/dev/null 2>&1 || true
 ufw allow 80/tcp >/dev/null 2>&1 || true
 ufw allow 443/tcp >/dev/null 2>&1 || true
 if [[ -f /etc/default/ufw ]]; then sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw; fi
 if [[ -f /etc/ufw/sysctl.conf ]]; then sed -i 's/^#\?[[:space:]]*net\/ipv4\/ip_forward=.*/net\/ipv4\/ip_forward=1/' /etc/ufw/sysctl.conf; fi
 ufw --force enable >/dev/null 2>&1 || true
 ok "Firewall base configurado. Los módulos deben abrir sus propios puertos."
}

configure_ssh(){
 section "🔐 PASO 4 • SSH + FAIL2BAN"
 systemctl enable ssh >/dev/null 2>&1 || true
 systemctl restart ssh >/dev/null 2>&1 || fatal "OpenSSH no pudo iniciar."
 if [[ -f "$SSHD_CFG" ]]; then
  cp -a "$SSHD_CFG" "${SSHD_CFG}.kevintech.backup"
  sed -i '/^[[:space:]]*#\?[[:space:]]*MaxAuthTries[[:space:]]/d;/^[[:space:]]*#\?[[:space:]]*ClientAliveInterval[[:space:]]/d;/^[[:space:]]*#\?[[:space:]]*ClientAliveCountMax[[:space:]]/d' "$SSHD_CFG"
  printf '\n# KevinTech\nMaxAuthTries 3\nClientAliveInterval 300\nClientAliveCountMax 2\n' >> "$SSHD_CFG"
  if sshd -t >/dev/null 2>&1; then systemctl restart ssh; else cp -a "${SSHD_CFG}.kevintech.backup" "$SSHD_CFG"; systemctl restart ssh || true; warn "SSH restaurado por configuración inválida."; fi
 fi
 mkdir -p /etc/fail2ban
 cat > /etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
backend = systemd
F2B
 systemctl enable fail2ban >/dev/null 2>&1 || true
 systemctl restart fail2ban >/dev/null 2>&1 || warn "Fail2Ban no pudo iniciar."
 ok "SSH y Fail2Ban listos."
}

install_repository(){
 section "📥 PASO 5 • KEVINTECH"
 rm -rf "$TMP"; mkdir -p "$TMP"
 loading "Clonando repositorio"
 git clone --depth 1 "$REPO" "$TMP" >/dev/null 2>&1 || fatal "No se pudo descargar el repositorio."
 mkdir -p "$BASE"
 cp -a "$TMP"/. "$BASE"/ || fatal "No se pudieron copiar los archivos."
 mkdir -p "$BASE/protocolos" "$BASE/usuarios" "$BASE/sistema" "$BASE/logs" "$BASE/herramientas"
 find "$BASE" -type f -name '*.sh' -exec chmod 755 {} +
 ok "Archivos instalados."
}

write_config(){
 cat > "$CONFIG" <<CFG
# KevinTech Multi Script
SERVER_DOMAIN="$SERVER_DOMAIN"
SERVER_IP="$SERVER_IP"
DNS_PROVIDER="$DNS_PROVIDER"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
LICENSE_API="$LICENSE_API"
OPENSSH=ON
DROPBEAR=OFF
SSL=OFF
BADVPN=OFF
UDP_CUSTOM=OFF
HYSTERIA=OFF
SLOWDNS=OFF
XRAY=OFF
V2RAY=OFF
OPENVPN=OFF
ZIPVPN=OFF
ZIVPN=OFF
WEBSOCKET=OFF
TROJAN=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF
SYSTEMDNS=OFF
SQUID=OFF
WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF
AUTO_START=OFF
CFG
 cat > "$LICENSE_CONF" <<LC
LICENSE_OWNER="$LICENSE_OWNER"
LICENSE_RESELLER="$LICENSE_RESELLER"
LICENSE_TYPE="$LICENSE_TYPE"
LICENSE_DELETE_AT="$LICENSE_DELETE_AT"
LICENSE_API="$LICENSE_API"
LICENSE_STATUS="VALIDATING"
LICENSE_BOT="$LICENSE_BOT"
LC
 chmod 640 "$CONFIG"; chmod 600 "$LICENSE_CONF"
 ok "config.conf y license.conf creados."
}

write_menu(){
 cat > /usr/local/bin/menu <<'MENU'
#!/bin/bash
BASE="/etc/kevintech"
[[ -f "$BASE/menu.sh" ]] && exec bash "$BASE/menu.sh" "$@"
echo "❌ No se encontró $BASE/menu.sh"
exit 1
MENU
 chmod 755 /usr/local/bin/menu
 ok "Comando menu instalado."
}

module_on(){ grep -q "^$1=ON$" "$CONFIG" 2>/dev/null; }
run_module(){
 local name="$1" file="$2" var="$3"
 echo; echo -e "${PURPLE}▶ $name${RESET}"
 if [[ ! -f "$file" ]]; then warn "No disponible: $(basename "$file")"; return 2; fi
 chmod 755 "$file"
 if bash "$file" --auto; then
  module_on "$var" && ok "$name → ON" || warn "$name terminó sin marcar $var=ON"
 else fail "$name → ERROR"; fi
}

install_modules(){
 section "🚀 PASO 6 • PROTOCOLOS"
 run_module "Dropbear" "$BASE/protocolos/dropbear.sh" DROPBEAR || true
 run_module "SSL Tunnel" "$BASE/protocolos/ssl.sh" SSL || true
 if [[ -f "$BASE/protocolos/xray.sh" ]]; then run_module "Xray" "$BASE/protocolos/xray.sh" XRAY || true; elif [[ -f "$BASE/protocolos/v2ray.sh" ]]; then run_module "V2Ray" "$BASE/protocolos/v2ray.sh" V2RAY || true; else warn "Xray/V2Ray no disponible."; fi
 run_module "UDP Custom" "$BASE/protocolos/udpcustom.sh" UDP_CUSTOM || true
 run_module "BadVPN" "$BASE/protocolos/badvpn.sh" BADVPN || true
 run_module "ZiVPN" "$BASE/protocolos/zivpn.sh" ZIPVPN || true
 run_module "SlowDNS" "$BASE/protocolos/slowdns.sh" SLOWDNS || true
 run_module "OpenVPN" "$BASE/protocolos/openvpn.sh" OPENVPN || true
}

write_banner(){
 section "🎨 PASO 7 • BANNER"
 cat > /etc/profile.d/kevintech-banner.sh <<'BANNER'
#!/bin/bash
[[ $- != *i* ]] && return
BASE="/etc/kevintech"; CONFIG="$BASE/config.conf"
CYAN="\e[1;96m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"; MAGENTA="\e[1;95m"; PINK="\e[38;5;213m"; PURPLE="\e[38;5;141m"; SKY="\e[38;5;117m"; WHITE="\e[1;97m"; RESET="\e[0m"
SERVER=$(hostname); DOMAIN="-"; [[ -f "$CONFIG" ]] && { source "$CONFIG" 2>/dev/null || true; DOMAIN="${SERVER_DOMAIN:--}"; }
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || true); RAM=$(free -h 2>/dev/null | awk '/Mem:/ {print $3 "/" $2}' || true); LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^ //' || true)
echo
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${PINK}${BOLD}             🚀 KEVINTECH MULTI SCRIPT 🚀${RESET}           ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET} ${PURPLE}                    SERVER PANEL${RESET}                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo -e " ${WHITE}🖥 Servidor:${RESET} ${SKY}$SERVER${RESET}"
echo -e " ${WHITE}🌐 Dominio :${RESET} ${MAGENTA}$DOMAIN${RESET}"
echo -e " ${WHITE}⏱ Uptime  :${RESET} ${GREEN}${UPTIME:-?}${RESET}"
echo -e " ${WHITE}💾 RAM     :${RESET} ${GREEN}${RAM:-?}${RESET}"
echo -e " ${WHITE}⚡ Carga   :${RESET} ${YELLOW}${LOAD:-?}${RESET}"
echo
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                       ⭐ CRÉDITOS ⭐${RESET}                   ${PURPLE}║${RESET}"
echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}║${RESET} Proyecto : ${PINK}KevinTech Multi Script${RESET}"
echo -e "${PURPLE}║${RESET} Autor    : ${WHITE}Kevin tech tutorials${RESET}"
echo -e "${PURPLE}║${RESET} Soporte  : ${MAGENTA}@multiscriptkeygen_bot${RESET}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo -e " ${GREEN}👑 Usuario:${RESET} ${WHITE}$(whoami)${RESET}"
echo -e " ${CYAN}👉 Panel:${RESET} ${WHITE}menu${RESET}"; echo
BANNER
 chmod 755 /etc/profile.d/kevintech-banner.sh
 ok "Banner configurado."
}

activate_license(){
 section "🔐 PASO 8 • ACTIVACIÓN"
 local ip host os now req r h b good id
 ip=$(get_public_ip); [[ -n "$ip" ]] || ip="Desconocida"; host=$(hostname); os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2); now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
 req=$(jq -n --arg key "$INSTALL_KEY" --arg ip "$ip" --arg hostname "$host" --arg os "$os" --arg date "$now" '{key:$key,ip:$ip,hostname:$hostname,os:$os,date:$date}')
 loading "Registrando licencia"
 r=$(curl -fsS -4 --connect-timeout 5 --max-time 15 -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' --data "$req" "$LICENSE_API/api/public/activate" 2>/dev/null) || fatal "No se pudo conectar con activación."
 h=$(printf '%s\n' "$r" | tail -n1); b=$(printf '%s\n' "$r" | sed '$d'); [[ "$h" =~ ^2 ]] || fatal "Activación HTTP $h."; echo "$b" | jq empty >/dev/null 2>&1 || fatal "Respuesta de activación inválida."
 good=$(echo "$b" | jq -r '.ok // false'); [[ "$good" == true ]] || fatal "Activación rechazada: $(echo "$b" | jq -r '.error // "desconocido"')"
 id=$(echo "$b" | jq -r '.activationId // empty'); sed -i 's/^LICENSE_STATUS=.*/LICENSE_STATUS="ACTIVE"/' "$LICENSE_CONF"; chmod 600 "$LICENSE_CONF"; ok "Licencia activada."; [[ -n "$id" ]] && echo -e " ${GRAY}ID:${RESET} ${CYAN}$id${RESET}"
}

summary(){
 section "📊 RESUMEN"
 local v; for v in OPENSSH DROPBEAR SSL UDP_CUSTOM BADVPN ZIPVPN SLOWDNS OPENVPN XRAY V2RAY; do if module_on "$v"; then echo -e " ${GREEN}●${RESET} $(printf '%-12s' "$v") ${GREEN}ACTIVO${RESET}"; else echo -e " ${GRAY}○${RESET} $(printf '%-12s' "$v") ${GRAY}NO INSTALADO${RESET}"; fi; done
 echo; echo -e " ${GRAY}Dominio:${RESET} ${SKY}${SERVER_DOMAIN:--}${RESET}"; echo -e " ${GRAY}IP:${RESET} ${CYAN}${SERVER_IP:--}${RESET}"; echo -e " ${GRAY}DNS:${RESET} ${MAGENTA}$DNS_PROVIDER${RESET}"
}

main(){
 require_root; require_ubuntu; header
 echo -e "${GREEN}● SISTEMA COMPATIBLE DETECTADO${RESET} ${WHITE}${PRETTY_NAME}${RESET}"; echo
 install_dependencies
 validate_license
 configure_domain
 configure_firewall
 configure_ssh
 install_repository
 write_config
 write_menu
 install_modules
 write_banner
 activate_license
 summary
 chmod 755 "$BASE"; find "$BASE" -type d -exec chmod 755 {} +; find "$BASE" -type f -name '*.sh' -exec chmod 755 {} +; chmod 640 "$CONFIG"; chmod 600 "$LICENSE_CONF"
 unset INSTALL_KEY
 echo; line; echo -e "${GREEN}${BOLD}🎉 INSTALACIÓN COMPLETADA${RESET}"; echo -e "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel.${RESET}"; echo
 read -r -p "$(echo -e "${YELLOW}¿Reiniciar servidor? [y/N]: ${RESET}")" r; r=$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')
 if [[ "$r" == y || "$r" == yes ]]; then for i in 5 4 3 2 1; do echo -ne "\r${CYAN}Reinicio en ${WHITE}$i${CYAN}...${RESET}"; sleep 1; done; echo; reboot; else ok "Instalación finalizada sin reiniciar."; fi
}
main "$@"
