#!/bin/bash
# ==========================================================
# KEVINTECH VPN — Slipstream Server
# Adaptación Bash del instalador Go proporcionado
# Soporta: amd64 / arm64
# ==========================================================
set -u
SERVICE="slipstream"; BIN="/usr/bin/slipstream-server"; DIR="/etc/slipstream"; CERT="$DIR/cert.pem"; KEY="$DIR/key.pem"; SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"; TMP_DIR="/tmp/slipstream"; LISTEN_PORT="5302"
CYAN='\033[1;96m'; GREEN='\033[1;92m'; RED='\033[1;91m'; YELLOW='\033[1;93m'; WHITE='\033[1;97m'; GRAY='\033[1;90m'; RESET='\033[0m'
ok(){ echo -e "${GREEN}✔ $*${RESET}"; }; info(){ echo -e "${CYAN}➜ $*${RESET}"; }; warn(){ echo -e "${YELLOW}⚠ $*${RESET}"; }; err(){ echo -e "${RED}✖ $*${RESET}"; }
require_root(){ [[ $EUID -eq 0 ]] || { err "Ejecuta este script como root."; exit 1; }; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }
install_dependencies(){ export DEBIAN_FRONTEND=noninteractive; info "Instalando dependencias..."; apt-get update -y >/dev/null 2>&1 && apt-get install -y curl tar openssl iptables iproute2 ca-certificates >/dev/null 2>&1 || { err "No se pudieron instalar las dependencias."; return 1; }; ok "Dependencias instaladas."; }
detect_arch(){ case "$(uname -m)" in x86_64|amd64) ARCH=amd64; FOLDER_ARCH=x86_64; URL="https://github.com/Mygod/slipstream-rust/releases/download/v0.1.1/slipstream-linux-x86_64.tar.gz";; aarch64|arm64) ARCH=arm64; FOLDER_ARCH=arm64; URL="https://github.com/Mygod/slipstream-rust/releases/download/v0.1.1/slipstream-linux-arm64.tar.gz";; *) err "Arquitectura no soportada: $(uname -m)"; return 1;; esac; }
download_binary(){ detect_arch || return 1; info "Descargando Slipstream para $ARCH..."; rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"; curl -fL --retry 3 --connect-timeout 15 -o "$TMP_DIR/slip.tar.gz" "$URL" || { err "Error descargando Slipstream."; rm -rf "$TMP_DIR"; return 1; }; tar -xzf "$TMP_DIR/slip.tar.gz" -C "$TMP_DIR" || { err "Error extrayendo Slipstream."; rm -rf "$TMP_DIR"; return 1; }; local src="$TMP_DIR/slipstream-linux-${FOLDER_ARCH}/slipstream-server"; [[ -f "$src" ]] || src="$(find "$TMP_DIR" -type f -name slipstream-server -print -quit)"; [[ -n "$src" && -f "$src" ]] || { err "No se encontró slipstream-server."; rm -rf "$TMP_DIR"; return 1; }; install -m 0755 "$src" "$BIN" || { err "No se pudo instalar el binario."; rm -rf "$TMP_DIR"; return 1; }; rm -rf "$TMP_DIR"; ok "Binario instalado: $BIN"; }
generate_cert(){ local domain="$1"; mkdir -p "$DIR"; chmod 700 "$DIR"; [[ -s "$CERT" && -s "$KEY" ]] && { ok "Certificado TLS existente."; return 0; }; info "Generando certificado TLS..."; openssl req -x509 -newkey rsa:4096 -nodes -keyout "$KEY" -out "$CERT" -days 3650 -subj "/CN=${domain}" >/dev/null 2>&1 || { err "No se pudo generar el certificado TLS."; return 1; }; chmod 600 "$KEY"; chmod 644 "$CERT"; ok "Certificado TLS creado."; }
remove_rule(){ local ipt="$1" port="$2"; while "$ipt" -t nat -D PREROUTING -p udp --dport "$port" -j REDIRECT --to-ports "$LISTEN_PORT" >/dev/null 2>&1; do :; done; }
add_rule(){ local ipt="$1" port="$2"; "$ipt" -t nat -C PREROUTING -p udp --dport "$port" -j REDIRECT --to-ports "$LISTEN_PORT" >/dev/null 2>&1 || "$ipt" -t nat -A PREROUTING -p udp --dport "$port" -j REDIRECT --to-ports "$LISTEN_PORT"; }
configure_iptables(){ info "Configurando redirecciones UDP..."; command_exists iptables && { remove_rule iptables 53; remove_rule iptables 443; add_rule iptables 53; add_rule iptables 443; }; command_exists ip6tables && { remove_rule ip6tables 53; remove_rule ip6tables 443; add_rule ip6tables 53; add_rule ip6tables 443; }; ok "Reglas UDP configuradas."; }
remove_iptables(){ info "Eliminando reglas de firewall..."; command_exists iptables && { remove_rule iptables 53 || true; remove_rule iptables 443 || true; }; command_exists ip6tables && { remove_rule ip6tables 53 || true; remove_rule ip6tables 443 || true; }; ok "Reglas eliminadas."; }
create_service(){ local domain="$1" port="$2"; [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || { err "Dominio inválido."; return 1; }; [[ "$port" =~ ^[0-9]+$ ]] && ((port>=1&&port<=65535)) || { err "Puerto inválido."; return 1; }; mkdir -p "$DIR"; cat > "$SERVICE_FILE" <<UNIT
[Unit]
Description=KevinTech Slipstream Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${DIR}
ExecStart=${BIN} -l ${LISTEN_PORT} -c ${CERT} -k ${KEY} -d ${domain} -a 127.0.0.1:${port}
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1 || { err "No se pudo habilitar el servicio."; return 1; }; systemctl restart "$SERVICE" || { err "Slipstream no pudo iniciar."; return 1; }; sleep 1; systemctl is-active --quiet "$SERVICE" && { ok "Servicio Slipstream activo."; return 0; }; err "El servicio no quedó activo."; journalctl -u "$SERVICE" -n 30 --no-pager; return 1; }
get_vps_ip(){ local ip=""; ip="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"; [[ -z "$ip" ]] && ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; echo "${ip:-No disponible}"; }
install_slipstream(){ require_root; local default_domain domain port; default_domain="$(get_vps_ip)"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${WHITE}       KEVINTECH SLIPSTREAM VPN${RESET}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; read -rp "🌐 Dominio/IP del servidor [${default_domain}]: " domain; domain="${domain:-$default_domain}"; read -rp "🔌 Puerto de destino local [443]: " port; port="${port:-443}"; [[ "$port" =~ ^[0-9]+$ ]] && ((port>=1&&port<=65535)) || { err "Puerto inválido."; return 1; }; install_dependencies || return 1; download_binary || return 1; generate_cert "$domain" || return 1; configure_iptables; create_service "$domain" "$port" || return 1; echo; ok "Slipstream instalado correctamente."; echo -e "${GRAY}Dominio: $domain${RESET}"; echo -e "${GRAY}UDP 53/443 → $LISTEN_PORT | destino 127.0.0.1:$port${RESET}"; }
remove_slipstream(){ require_root; read -rp "⚠️ ¿Eliminar Slipstream completamente? [s/N]: " answer; [[ "${answer,,}" == s ]] || { info "Operación cancelada."; return 0; }; systemctl stop "$SERVICE" >/dev/null 2>&1 || true; systemctl disable "$SERVICE" >/dev/null 2>&1 || true; rm -f "$SERVICE_FILE"; systemctl daemon-reload; remove_iptables; rm -rf "$DIR"; rm -f "$BIN"; ok "Slipstream eliminado completamente."; }
status_slipstream(){ echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${WHITE}         ESTADO SLIPSTREAM${RESET}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; [[ -x "$BIN" ]] && ok "Binario instalado" || err "Binario no instalado"; systemctl is-active --quiet "$SERVICE" && ok "Servicio ACTIVO" || err "Servicio INACTIVO"; [[ -f "$CERT" && -f "$KEY" ]] && ok "TLS configurado" || warn "TLS no configurado"; systemctl --no-pager --full status "$SERVICE" 2>/dev/null | sed -n '1,12p' || true; }
restart_slipstream(){ require_root; systemctl restart "$SERVICE" || { err "No se pudo reiniciar Slipstream."; return 1; }; systemctl is-active --quiet "$SERVICE" && ok "Slipstream reiniciado." || err "Slipstream quedó inactivo."; }
logs_slipstream(){ journalctl -u "$SERVICE" -n 50 --no-pager; }
show_info(){ echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${WHITE}          DATOS SLIPSTREAM${RESET}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo "🌐 IP VPS      : $(get_vps_ip)"; echo "📡 UDP entrada : 53"; echo "📡 UDP entrada : 443"; echo "🔀 Redirección : $LISTEN_PORT"; echo "🎯 Destino     : 127.0.0.1:<puerto>"; echo "🔐 Certificado : $CERT"; echo "⚙️ Servicio    : $SERVICE"; }
menu(){ require_root; while true; do clear; echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"; echo -e "${CYAN}║${WHITE}          KEVINTECH SLIPSTREAM VPN           ${CYAN}║${RESET}"; echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"; echo -e "${CYAN}║${RESET} [01] 🚀 Instalar / Actualizar              ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [02] 📊 Ver Estado                         ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [03] 🔄 Reiniciar Servicio                 ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [04] 📜 Ver Logs                            ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [05] ℹ️  Datos de Conexión                  ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [06] 🗑️  Desinstalar                        ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} [00] ↩️  Regresar                            ${CYAN}║${RESET}"; echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"; echo; read -rp "Selecciona una opción: " option; case "$option" in 1|01) install_slipstream; read -rp "Enter para continuar...";; 2|02) status_slipstream; read -rp "Enter para continuar...";; 3|03) restart_slipstream; read -rp "Enter para continuar...";; 4|04) logs_slipstream; read -rp "Enter para continuar...";; 5|05) show_info; read -rp "Enter para continuar...";; 6|06) remove_slipstream; read -rp "Enter para continuar...";; 0|00) return 0;; *) warn "Opción inválida."; sleep 1;; esac; done; }
case "${1:-menu}" in --install|install) install_slipstream;; --remove|remove|uninstall) remove_slipstream;; --status|status) status_slipstream;; --restart|restart) restart_slipstream;; --logs|logs) logs_slipstream;; --info|info) show_info;; --help|-h) echo "Uso: $0 [--install|--remove|--status|--restart|--logs|--info]";; *) menu;; esac
