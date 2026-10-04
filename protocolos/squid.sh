#!/bin/bash

#==================================================
# kevintech Network Premium
# Squid Proxy Manager — Proxy HTTP (puerto 3128)
# Gestión: instalar · desinstalar · estado · reiniciar
#==================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || { echo "❌ No existe $CONFIG"; exit 1; }
source "$CONFIG"


# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
WHITE="${MV_WHT:-\e[1;97m}"
RESET="${MV_R:-\e[0m}"

SQUID_PORT="${SQUID_PORT:-3128}"
SQUID_CONF="/etc/squid/squid.conf"

# Navegación
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

#--------------------------------------------------
# Puerto real configurado en squid (si existe)
#--------------------------------------------------
get_squid_port() {
    grep -oE '^[[:space:]]*http_port[[:space:]]+[0-9]+' "$SQUID_CONF" 2>/dev/null | grep -oE '[0-9]+' | head -1
}

#--------------------------------------------------
# Instalar
#--------------------------------------------------
install_squid() {
    clear
mv_brand_header "INSTALAR SQUID"
    anim_step "Instalando squid"
    anim_run "apt update" apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y squid 2>&1 | tail -2

    if command -v squid >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -q "^squid.service"; then
        systemctl enable squid >/dev/null 2>&1
        svc_restart_anim squid "Arrancando Squid"

        # Puerto real
        PORT_REAL=$(get_squid_port)
        [[ -z "$PORT_REAL" ]] && PORT_REAL="$SQUID_PORT"

        # Abrir firewall
        iptables -C INPUT -p tcp --dport "$PORT_REAL" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p tcp --dport "$PORT_REAL" -j ACCEPT
        if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "$PORT_REAL/tcp" >/dev/null 2>&1
        fi

        sed -i '/^SQUID=/d' "$CONFIG"
        echo "SQUID=ON" >> "$CONFIG"
        sed -i '/^SQUID_PORT=/d' "$CONFIG"
        echo "SQUID_PORT=$PORT_REAL" >> "$CONFIG"
        source "$CONFIG"

        echo ""
        echo -e "${GREEN}✅ Squid instalado (puerto $PORT_REAL).${RESET}"
        echo -e "${WHITE}   Usa el proxy como: IP-$PORT_REAL (HTTP)${RESET}"
    else
        echo -e "${RED}❌ Error instalando Squid.${RESET}"
    fi
    sleep 3
}

#--------------------------------------------------
# Desinstalar
#--------------------------------------------------
remove_squid() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🗑 ELIMINAR SQUID${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -rp "$(trx '¿Eliminar Squid? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "Desinstalando Squid"
    anim_run "Detener y deshabilitar" bash -c "systemctl stop squid 2>/dev/null; systemctl disable squid 2>/dev/null"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y squid >/dev/null 2>&1

    sed -i '/^SQUID=/d' "$CONFIG"
    echo "SQUID=OFF" >> "$CONFIG"
    sed -i '/^SQUID_PORT=/d' "$CONFIG"
    source "$CONFIG"

    echo ""
    echo "$(trx '✅ Squid eliminado.')"
    sleep 3
}

#--------------------------------------------------
# Reiniciar
#--------------------------------------------------
restart_squid() {
    svc_restart_anim squid "Reiniciando Squid"
    sleep 3
}

#--------------------------------------------------
# Cambiar puerto
#--------------------------------------------------
change_port() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🔀 CAMBIAR PUERTO SQUID${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -rp "$(trx ' Nuevo puerto HTTP: ')" NP
    [[ "$NP" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Puerto inválido.${RESET}"; sleep 2; return; }

    sed -i "s|^[[:space:]]*http_port[[:space:]]*[0-9]*|http_port $NP|" "$SQUID_CONF" 2>/dev/null
    # Si no existía http_port, agregarlo
    grep -q '^http_port' "$SQUID_CONF" 2>/dev/null || {
        sed -i '1i http_port '"$NP" "$SQUID_CONF"
    }

    systemctl restart squid

    # Abrir nuevo puerto en firewall, cerrar el anterior
    iptables -C INPUT -p tcp --dport "$NP" -j ACCEPT 2>/dev/null \
        || iptables -A INPUT -p tcp --dport "$NP" -j ACCEPT
    iptables -D INPUT -p tcp --dport "$SQUID_PORT" -j ACCEPT 2>/dev/null

    sed -i '/^SQUID_PORT=/d' "$CONFIG"
    echo "SQUID_PORT=$NP" >> "$CONFIG"
    source "$CONFIG"

    if systemctl is-active --quiet squid; then
        echo -e "${GREEN}✅ Puerto cambiado a $NP y abierto en firewall.${RESET}"
        echo -e "${WHITE}   Proxy: IP-$NP (HTTP)${RESET}"
    else
        echo -e "${RED}❌ Squid no levantó con el nuevo puerto. Revisa /etc/squid/squid.conf${RESET}"
    fi
    sleep 3
}

#--------------------------------------------------
# Estado
#--------------------------------------------------
status_squid() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          📊 ESTADO SQUID${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    systemctl status squid --no-pager 2>/dev/null | head -12
    echo ""
    echo -e " Puerto HTTP configurado : ${GREEN}$(get_squid_port || echo "$SQUID_PORT")${RESET}"
    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Modo CLI (automatización/headless)
#==================================================
case "${1:-}" in
    --install) install_squid; exit $? ;;
    ""|*) ;;
esac

#==================================================
# Menú Principal
#==================================================
while true; do

clear
source "$CONFIG"

if systemctl is-active --quiet squid; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DETENIDO${RESET}"
fi

mv_header "🌐 Squid Proxy" "$(trx 'Proxy HTTP · puerto ')$(get_squid_port || echo "$SQUID_PORT")" "v6.2"
kevintech_contacts 2>/dev/null || true

echo -e " Estado : $STATUS"
echo ""

if [[ "$SQUID" == "ON" ]]; then
    LBL=("Desinstalar Squid" "Reiniciar Servicio" "Cambiar Puerto" "Ver Estado")
else
    LBL=("Instalar Squid")
fi
SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
[[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
OP="$SEL"

case "$OP" in
1)
    if [[ "$SQUID" == "ON" ]]; then
        remove_squid
    else
        install_squid
    fi
;;
2)
    [[ "$SQUID" == "ON" ]] && restart_squid
;;
3)
    [[ "$SQUID" == "ON" ]] && change_port
;;
4)
    [[ "$SQUID" == "ON" ]] && status_squid
;;
0)
    exec bash "$BASE/protocolos/menu.sh"
;;
*)
    echo ""
    echo "$(trx '❌ Opción inválida.')"
    sleep 2
;;
esac

done