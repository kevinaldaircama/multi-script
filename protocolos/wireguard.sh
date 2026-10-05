#!/bin/bash
#==================================================
# kevintech Network Premium v5.7 - WIREGUARD MANAGER
# Protocolo premium: servidor wg0 + peers por usuario
#   · Instalación automática (wireguard + qrencode)
#   · Pool de IPs 10.66.66.2-254 · NAT masquerade
#   · Config cliente + QR para móvil
#   · Estado online por handshake (<180s)
# Reglas iptables etiquetadas comment kevintech-WG
#==================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/kevintech"


CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_SRV_CONF="$WG_DIR/${WG_IF}.conf"
PEERS_DIR="$BASE/wg-peers"
WG_NET="10.66.66"
WG_PORT="${WG_PORT:-51820}"

CYAN="${MV_CYN:-\e[1;96m}"; GREEN="${MV_GRN:-\e[1;92m}"; RED="${MV_RED:-\e[1;91m}"
GOLD="${MV_GLD:-\e[1;93m}"; MAGENTA="${MV_MAG:-\e[1;95m}"; WHITE="${MV_WHT:-\e[1;97m}"; GRAY="${MV_DIM:-\e[1;90m}"; RESET="${MV_R:-\e[0m}"
#==================================================
# FUNCIONES INTERNAS — SIN LIBRERÍAS EXTERNAS
#==================================================

anim_init() {
    return 0
}

anim_step() {
    echo ""
    echo -e "${CYAN}➜ $1${RESET}"
}

anim_run() {
    local LABEL="$1"
    shift

    echo -ne "${CYAN}➜ ${LABEL}...${RESET} "

    if "$@" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${RESET}"
        return 0
    else
        echo -e "${RED}ERROR${RESET}"
        return 1
    fi
}

anim_done() {
    echo -e "${GREEN}✅ $1${RESET}"
}

anim_fail() {
    echo -e "${RED}❌ $1${RESET}"
}

mv_brand_header() {
    local TITLE="${1:-WIREGUARD}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🛡 ${TITLE}${RESET}"
    echo -e "${GRAY}             KevinTech WireGuard${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

mv_deliv_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        $1${RESET}"
    [[ -n "$2" ]] && echo -e "${GRAY}        $2${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

mv_deliv_sec() {
    echo -e "${CYAN}➜ $1${RESET}"
}

mv_dcard_top() {
    echo -e "${CYAN}┌──────────────────────────────────────────┐${RESET}"
}

mv_dcard_row() {
    printf "${CYAN}│${RESET} %s %-12s : ${WHITE}%s${RESET}\n" "$1" "$2" "$3"
}

mv_dcard_bot() {
    echo -e "${CYAN}└──────────────────────────────────────────┘${RESET}"
}

mv_deliv_pie() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

mv_tick() {
    printf '%s' "$1"
}

fmt_ago() {
    local S="${1:-0}"
    local M H D

    (( S < 0 )) && S=0

    M=$((S / 60))
    H=$((M / 60))
    D=$((H / 24))

    if (( D > 0 )); then
        echo "${D}d"
    elif (( H > 0 )); then
        echo "${H}h"
    else
        echo "${M}m"
    fi
}

mkdir -p "$PEERS_DIR"

pub_ip(){
    if [[ -s "$BASE/sistema/.pub_ip" ]]; then
        tr -d '[:space:]' < "$BASE/sistema/.pub_ip"
    else
        curl -4 -s --max-time 5 ifconfig.me || echo ""
    fi
}

deps_ok(){
    local MISS=0
    for C in wg wg-quick qrencode; do
        command -v "$C" >/dev/null 2>&1 || MISS=1
    done
    (( MISS )) || return 0
    anim_step "Instalando WireGuard"
    anim_run "apt update" apt-get update -qq
    anim_run "Instalar wireguard-tools" apt-get install -y wireguard qrencode
    command -v wg >/dev/null 2>&1 && modprobe wireguard 2>/dev/null
}

server_up(){
    [[ -f "$WG_SRV_CONF" ]] && { systemctl is-active --quiet "wg-quick@${WG_IF}" && return 0; }
    deps_ok || { echo -e "${RED}❌ No se pudo instalar wireguard${RESET}"; sleep 3; return 1; }
    umask 077
    mkdir -p "$WG_DIR"
    WG_PRIV=$(wg genkey)
    WG_PUB=$(echo "$WG_PRIV" | wg pubkey)
    IFACE=$(ip route | awk '/default/{print $5; exit}')
    cat > "$WG_SRV_CONF" <<EOF
[Interface]
Address = ${WG_NET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${WG_PRIV}
PostUp = iptables -A FORWARD -i ${WG_IF} -j ACCEPT -m comment --comment kevintech-WG; iptables -A FORWARD -o ${WG_IF} -j ACCEPT -m comment --comment kevintech-WG; iptables -t nat -A POSTROUTING -o ${IFACE} -j MASQUERADE -m comment --comment kevintech-WG
PostDown = iptables -D FORWARD -i ${WG_IF} -j ACCEPT -m comment --comment kevintech-WG; iptables -D FORWARD -o ${WG_IF} -j ACCEPT -m comment --comment kevintech-WG; iptables -t nat -D POSTROUTING -o ${IFACE} -j MASQUERADE -m comment --comment kevintech-WG
EOF
    # ip forward persistente
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || \
        echo "$(trx 'net.ipv4.ip_forward=1')" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    sed -i '/^WG=/d; /^WG_PORT=/d' "$CONFIG"
    { echo "WG=ON"; echo "WG_PORT=$WG_PORT"; } >> "$CONFIG"
    chmod 600 "$WG_SRV_CONF"
    systemctl enable "wg-quick@${WG_IF}" >/dev/null 2>&1
    if ! anim_run "Activar servicio wg-quick@${WG_IF}" systemctl start "wg-quick@${WG_IF}"; then
        anim_fail "No se pudo iniciar WireGuard"
    fi
    sleep 1
    return 0
}

next_ip(){
    local USED="" F IP N
    for F in "$PEERS_DIR"/*.conf; do
        [[ -f "$F" ]] || continue
        IP=$(grep -m1 "^Address" "$F" | grep -oE "${WG_NET}\.[0-9]+" | cut -d. -f4)
        USED+=" $IP "
    done
    for N in $(seq 2 254); do
        [[ "$USED" != *" $N "* ]] && { echo "${WG_NET}.${N}"; return 0; }
    done
    return 1
}

add_peer(){
    clear
mv_brand_header "WIREGUARD · NUEVO PEER"
    read -rp "$(trx ' ► Nombre del usuario/dispositivo: ')" NAME
    [[ -z "$NAME" ]] && return
    NAME=$(echo "$NAME" | tr -c 'a-zA-Z0-9._-' '_')
    [[ -f "$PEERS_DIR/$NAME.conf" ]] && {
        echo -e " ${GOLD}⚠ Ya existe un peer '$NAME'${RESET}"; sleep 2; return; }
    IPNEW=$(next_ip) || { echo -e "${RED}❌ Pool agotado (253 peers)${RESET}"; sleep 2; return; }

            echo -e "${YELLOW}← $(trx 'Cancelado')${RESET}"
            return 1
        fi
        DUR_TS_EXP="${DUR_TS:-0}"
        DUR_MOSTRAR_EXP="${DUR_MOSTRAR:-♾️ Ilimitado}"
    else
       #==================================================
# DURACIÓN DEL PEER
#==================================================

read -rp "$(trx '📅 Duración en días (Enter = ilimitado): ')" D

if [[ -n "$D" && "$D" =~ ^[0-9]+$ && "$D" -gt 0 ]]; then
    DUR_TS_EXP=$(date -d "+${D} days" +%s)
    DUR_MOSTRAR_EXP=$(date -d "+${D} days" +"%d/%m/%Y %H:%M" 2>/dev/null)
else
    DUR_TS_EXP=0
    DUR_MOSTRAR_EXP="♾️ Ilimitado"
fi
 
    server_up || return
    umask 077
    PPRIV=$(wg genkey); PPUB=$(echo "$PPRIV" | wg pubkey)
    SPRIV=$(grep '^PrivateKey' "$WG_SRV_CONF" | awk '{print $3}')
    SPUB=$(echo "$SPRIV" | wg pubkey)
    EP="${SERVER_DOMAIN:-$(pub_ip)}:$WG_PORT"

    # peer -> server
    cat >> "$WG_SRV_CONF" <<EOF

[Peer]
# name = $NAME
PublicKey = ${PPUB}
AllowedIPs = ${IPNEW}/32
EOF
    # config cliente
    cat > "$PEERS_DIR/$NAME.conf" <<EOF
[Interface]
PrivateKey = ${PPRIV}
Address = ${IPNEW}/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = ${SPUB}
Endpoint = ${EP}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
    chmod 600 "$PEERS_DIR/$NAME.conf"
    systemctl reload "wg-quick@${WG_IF}" 2>/dev/null || \
        wg syncconf "$WG_IF" <(wg-quick strip "$WG_SRV_CONF") 2>/dev/null
    echo
    mv_deliv_header "$(trx '🎉 PEER WIREGUARD CREADO')" "$(trx 'Configuración cliente + QR')"
    echo
    mv_deliv_sec "$(trx '📲 CONFIGURACIÓN DE CONEXIÓN')"
    mv_dcard_top
    mv_dcard_row "👤" "$(trx 'Usuario')" "$NAME"
    mv_dcard_row "🌐" "$(trx 'IP VPN')" "$IPNEW"
    mv_dcard_row "🔑" "$(trx 'Endpoint')" "$(mv_tick "$EP")"
    mv_dcard_row "⏳" "$(trx 'Expira')" "$DUR_MOSTRAR_EXP"
    mv_dcard_bot
    echo
    mv_deliv_sec "$(trx '📱 QR PARA MÓVIL')"
    qrencode -t ansiutf8 -m 2 < "$PEERS_DIR/$NAME.conf"
    echo
    mv_deliv_sec "$(trx '✅ INSTRUCCIONES')"
    echo -e "${GREEN}✔ $(trx 'Escanea el QR en la app WireGuard: + → Crear desde QR.')${RESET}"
    echo -e "${GREEN}✔ $(trx 'O importa el archivo .conf desde:')${RESET} ${CYAN}$PEERS_DIR/$NAME.conf${RESET}"
    echo
    mv_deliv_pie
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
}

list_peers(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       📋 WIREGUARD · PEERS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    local N=0 NOW=$(date +%s) F NAME HS HS_AGO ST IPADDR
    while IFS= read -r LINE; do
        PK=$(echo "$LINE" | awk '{print $1}')
        HS=$(echo "$LINE" | awk '{print $5}')
        NAME=$(grep -B2 "PublicKey = $PK" "$WG_SRV_CONF" 2>/dev/null | \
               grep "# name =" | head -1 | awk '{print $NF}')
        [[ -z "$NAME" ]] && NAME=$(basename "$(grep -l "$PK" "$PEERS_DIR"/*.conf 2>/dev/null | head -1)" .conf 2>/dev/null)
        [[ -z "$NAME" ]] && NAME="${PK:0:12}..."
        IPADDR=$(grep -A1 "PublicKey = $PK" "$WG_SRV_CONF" 2>/dev/null | grep AllowedIPs | awk '{print $3}' | head -1)
        N=$((N+1))
        if [[ -n "$HS" && "$HS" != "0" ]]; then
            HS_AGO=$(( NOW - HS ))
            if (( HS_AGO < 180 )); then ST="${GREEN}● ONLINE${RESET}"; else ST="${GRAY}○ idle $(fmt_ago $HS_AGO)${RESET}"; fi
        else
            ST="${GRAY}○ nunca conectó${RESET}"
        fi
        printf " %2d) ${WHITE}%-16s${RESET} %-14s %b\n" "$N" "$NAME" "${IPADDR:-?}" "$ST"
    done < <(wg show "$WG_IF" peers 2>/dev/null | while read -r PK; do wg show "$WG_IF" latest-handshakes | grep "^$PK"; done)
    (( N == 0 )) && echo -e " ${GRAY}(sin peers aún — crea uno con [2])${RESET}"
    TOTAL_RX=$(wg show "$WG_IF" transfer 2>/dev/null | awk '{s+=$2+$3} END{printf "%.1f MiB", s/1048576}')
    [[ -n "$TOTAL_RX" ]] && echo -e "\n ${GRAY}Transferencia total peers: $TOTAL_RX${RESET}"
    echo ""
    read -n1 -r -p "$(trx ' Presione una tecla...')"
}

fmt_ago(){ local S=$1 M H D; M=$((S/60)); H=$((M/60)); D=$((H/24))
    (( D > 0 )) && echo "${D}d" || { (( H > 0 )) && echo "${H}h" || echo "${M}m"; }; }

show_peer_qr() {

    clear

    echo
    mv_deliv_header "$(trx '📱 CONFIG CLIENTE + QR')" "$(trx 'WireGuard peer')"
    echo
    mv_deliv_sec "$(trx '📲 CONFIGURACIÓN DE CONEXIÓN')"
    mv_dcard_top
    mv_dcard_row "👤" "$(trx 'Usuario')" "$NAME"
    mv_dcard_row "🌐" "$(trx 'IP VPN')" "$(grep '^Address' "$PEERS_DIR/$NAME.conf" | awk '{print $3}')"
    mv_dcard_row "🔑" "$(trx 'Endpoint')" "$(mv_tick "$(grep '^Endpoint' "$PEERS_DIR/$NAME.conf" | awk '{print $3}')")"
    mv_dcard_row "🔐" "$(trx 'DNS')" "1.1.1.1, 8.8.8.8"
    mv_dcard_bot
    echo
    mv_deliv_sec "$(trx '📱 QR PARA MÓVIL')"
    qrencode -t ansiutf8 -m 2 < "$PEERS_DIR/$NAME.conf"
    echo
    mv_deliv_sec "$(trx '📄 ARCHIVO DE CONFIGURACIÓN')"
    grep -v PrivateKey "$PEERS_DIR/$NAME.conf" | sed 's/^/    /'
    echo
    mv_deliv_pie
    read -n1 -r -p "$(trx 'Presione cualquier tecla para continuar...')"
}


del_peer(){
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}       🗑 ELIMINAR PEER${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    local FILES=""
    for F in "$PEERS_DIR"/*.conf; do [[ -f "$F" ]] && echo -e "   $(basename "$F" .conf)"; done
    read -rp "$(trx ' ► Nombre a eliminar: ')" NAME
    [[ -f "$PEERS_DIR/$NAME.conf" ]] || { echo -e " ${RED}❌ no existe${RESET}"; sleep 2; return; }
    read -rp " ► Confirmar eliminación de '$NAME'? (s/N): " R
    [[ "$R" =~ ^[sS]$ ]] || return
    PPUB=$(grep '^PublicKey' "$PEERS_DIR/$NAME.conf" | awk '{print $3}')
    # quitar bloque [Peer] del server conf
    awk -v pk="$PPUB" '
        /^\[Peer\]/{buf=$0"\n"; inp=1; next}
        inp{buf=buf $0"\n"; if ($0 ~ /^$/) {if (buf !~ pk) printf "%s", buf; buf=""; inp=0; next}}
        !inp{print}
    ' "$WG_SRV_CONF" > "${WG_SRV_CONF}.tmp" && mv "${WG_SRV_CONF}.tmp" "$WG_SRV_CONF"
    rm -f "$PEERS_DIR/$NAME.conf"
    wg syncconf "$WG_IF" <(wg-quick strip "$WG_SRV_CONF") 2>/dev/null
    echo -e " ${GREEN}✅ Peer '$NAME' eliminado${RESET}"
    sleep 2
}

toggle_server(){
    if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
        anim_run "Detener WireGuard" systemctl stop "wg-quick@${WG_IF}"
        sed -i '/^WG=/d' "$CONFIG"; echo "WG=OFF" >> "$CONFIG"
        echo -e " ${GOLD}⚠ Servidor WireGuard DETENIDO${RESET}"
    else
        server_up && echo -e " ${GREEN}✅ Servidor WireGuard ACTIVO${RESET}"
    fi
    sleep 2
}

uninstall_wg(){
    clear
    read -rp "$(trx ' ► Desinstalar WireGuard por completo? (s/N): ')" R
    [[ "$R" =~ ^[sS]$ ]] || return

    anim_init 3
    anim_step "Desinstalando WireGuard"
    anim_run "Detener servicio" systemctl disable --now "wg-quick@${WG_IF}"
    IFACE=$(ip route | awk '/default/{print $5; exit}')
    anim_run "Limpiar reglas iptables" bash -c "iptables -D FORWARD -i \"$WG_IF\" -j ACCEPT -m comment --comment kevintech-WG 2>/dev/null; iptables -D FORWARD -o \"$WG_IF\" -j ACCEPT -m comment --comment kevintech-WG 2>/dev/null; iptables -t nat -D POSTROUTING -o \"$IFACE\" -j MASQUERADE -m comment --comment kevintech-WG 2>/dev/null"
    anim_run "Eliminar configuración" rm -f "$WG_SRV_CONF"
    sed -i '/^WG=/d; /^WG_PORT=/d' "$CONFIG"; echo "WG=OFF" >> "$CONFIG"
    anim_done "WireGuard desinstalado (confs de peers conservados en $PEERS_DIR)"
    sleep 3
}

# ── CLI headless: bash wireguard.sh --install
if [[ "${1:-}" == "--install" ]]; then
    server_up
    exit $?
fi

#──────────────────────────────────────────────
# MENÚ PRINCIPAL
#──────────────────────────────────────────────
while true
do
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}          🛡 WIREGUARD MANAGER v5.7${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if systemctl is-active --quiet "wg-quick@${WG_IF}" 2>/dev/null; then
        SRV_S="${GREEN}● SERVIDOR ACTIVO${RESET} ${GRAY}[UDP $WG_PORT] · ${WG_NET}.1/24${RESET}"
    elif [[ -f "$WG_SRV_CONF" ]]; then
        SRV_S="${RED}● DETENIDO${RESET}"
    else
        SRV_S="${GRAY}○ SIN INSTALAR${RESET}"
    fi
    NP=$(ls "$PEERS_DIR"/*.conf 2>/dev/null | wc -l)

cat <<EOF

 $SRV_S
 Peers registrados: ${WHITE}$NP${RESET}

 [1] ➮ Instalar/Iniciar Servidor
 [2] ➮ Nuevo Peer (+QR)
 [3] ➮ Listar Peers (online/idle)
 [4] ➮ Ver Config+QR de un Peer
 [5] ➮ Eliminar Peer
 [6] ➮ Detener / Iniciar Servidor
 [7] ➮ Cambiar Puerto UDP
 [8] ➮ Desinstalar

 [0] ➮ Regresar

EOF
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "$(trx ' ► Opcion: ')" OP
    case "$OP" in
        1) server_up && { clear; echo -e " ${GREEN}✅ WireGuard activo en UDP $WG_PORT${RESET}"; sleep 2; } ;;
        2) add_peer ;;
        3) list_peers ;;
        4) show_peer_qr ;;
        5) del_peer ;;
        6) toggle_server ;;
        7)
            read -rp " ► Nuevo puerto UDP [$WG_PORT]: " NEWP
            if [[ "$NEWP" =~ ^[0-9]+$ ]] && (( NEWP >= 1024 && NEWP <= 65535 )); then
                WAS_ACTIVE=0; systemctl is-active --quiet "wg-quick@${WG_IF}" && WAS_ACTIVE=1
                systemctl stop "wg-quick@${WG_IF}" 2>/dev/null
                WG_PORT=$NEWP
                [[ -f "$WG_SRV_CONF" ]] && {
                    sed -i "s/^ListenPort = .*/ListenPort = $NEWP/" "$WG_SRV_CONF"
                    sed -i "/^WG_PORT=/d" "$CONFIG"; echo "WG_PORT=$NEWP" >> "$CONFIG"
                }
                (( WAS_ACTIVE )) && { server_up; echo -e " ${GREEN}✅ Puerto cambiado a $NEWP${RESET}"; }
                sleep 2
            else
                echo -e "${RED}❌ inválido${RESET}"; sleep 2
            fi ;;
        8) uninstall_wg ;;
        0) exec bash "$BASE/protocolos/menu.sh" ;;
        *) echo -e "${RED}❌ Opcion invalida.${RESET}"; sleep 1 ;;
    esac
done
