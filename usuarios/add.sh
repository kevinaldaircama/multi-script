#!/bin/bash

#=========================================================
# KevinTech Multi Script Premium
# Módulo: Crear Usuario SSH
# Versión: 3.4 Premium
#
# FUNCIONES:
# - Crear usuario SSH
# - Expiración automática / ilimitada
# - Límite IP por usuario
# - CheckUser dinámico
# - Integración ZiVPN
# - BHTTP 8088
# - Detección REAL de protocolos
# - BadVPN TCP UDPGW 7200/7300
#=========================================================

#========================#
#         COLORES
#========================#

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'
RESET='\e[0m'

#========================#
#      CONFIGURACIÓN
#========================#

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
LIMITS_FILE="$BASE/limits.conf"

LIMIT_SCRIPT="/usr/local/bin/kevintech-limit"
CHECKUSER_SCRIPT="/usr/local/bin/kevintech-checkuser"

mkdir -p "$BASE"

touch "$LIMITS_FILE"

chmod 600 "$LIMITS_FILE"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#=========================================================
# FUNCIONES GENERALES
#=========================================================

line() {

    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" \
        "$CYAN" "$RESET"
}

pause() {

    echo

    read -rp \
        "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
}

msg_ok() {

    echo -e "${GREEN}✔ $1${RESET}"
}

msg_error() {

    echo -e "${RED}✘ $1${RESET}"
}

msg_info() {

    echo -e "${CYAN}➜ $1${RESET}"
}

msg_warn() {

    echo -e "${YELLOW}⚠ $1${RESET}"
}

#=========================================================
# INSTALAR CHECKUSER DINÁMICO
#=========================================================

instalar_checkuser() {

    cat > "$CHECKUSER_SCRIPT" <<'EOF'
#!/bin/bash

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

USER_NAME="${USER:-${LOGNAME:-}}"

[[ -z "$USER_NAME" ]] && exit 0

id "$USER_NAME" >/dev/null 2>&1 || exit 0

LIMIT=$(awk -F: -v u="$USER_NAME" '
    $1 == u {
        print $2
        exit
}
' "$LIMITS_FILE" 2>/dev/null)

[[ -z "$LIMIT" ]] && LIMIT=0

IPS=$(
    who 2>/dev/null |
    awk -v u="$USER_NAME" '
        $1 == u {
            ip=$5
            gsub(/[()]/, "", ip)

            if (ip != "")
                print ip
        }
    ' |
    sort -u
)

if [[ -n "$IPS" ]]; then

    CONNECTIONS=$(printf '%s\n' "$IPS" | grep -c .)

else

    CONNECTIONS=0

fi

EXPIRATION=$(chage -l "$USER_NAME" 2>/dev/null |
    awk -F': ' '/Account expires/ {
        print $2
        exit
    }')

if [[ -z "$EXPIRATION" ||
      "$EXPIRATION" == "never" ||
      "$EXPIRATION" == "Nunca" ]]; then

    EXPIRATION="Ilimitada"
    DAYS="∞"

else

    EXP_DATE=$(date -d "$EXPIRATION" +%s 2>/dev/null)
    TODAY=$(date +%s)

    if [[ -n "$EXP_DATE" ]]; then

        DIFF=$(( (EXP_DATE - TODAY) / 86400 ))

        if (( DIFF < 0 )); then
            DAYS=0
        else
            DAYS=$DIFF
        fi

        EXPIRATION=$(date -d "$EXPIRATION" +"%d/%m/%Y")

    else

        DAYS="N/D"

    fi

fi

if (( LIMIT == 0 )); then

    LIMIT_TEXT="♾"

else

    LIMIT_TEXT="$LIMIT"

fi

printf '\n'
printf '%s\n' '═══════════════════════════════════════════════════'
printf '%s\n' '                    CHECK USER'
printf '%s\n' '═══════════════════════════════════════════════════'
printf '\n'
printf '👤 Usuario        : %s\n' "$USER_NAME"
printf '🔌 Conexiones     : %s/%s\n' "$CONNECTIONS" "$LIMIT_TEXT"
printf '📅 Expiración     : %s\n' "$EXPIRATION"
printf '⏳ Días restantes : %s\n' "$DAYS"
printf '\n'
printf '%s\n' '═══════════════════════════════════════════════════'
printf '\n'

exit 0
EOF

    chmod 755 "$CHECKUSER_SCRIPT"

    local SSHRC="/etc/ssh/sshrc"

    touch "$SSHRC"

    chmod 755 "$SSHRC"

    if ! grep -q "kevintech-checkuser" "$SSHRC" 2>/dev/null; then

        cat >> "$SSHRC" <<'EOF'

#=========================================================
# KevinTech Dynamic CheckUser
#=========================================================

if [[ -x /usr/local/bin/kevintech-checkuser ]]; then
    /usr/local/bin/kevintech-checkuser
fi

EOF

    fi

    local SSHD="/etc/ssh/sshd_config"

    if [[ -f "$SSHD" ]]; then

        if ! grep -qE '^[[:space:]]*UsePAM[[:space:]]+yes' "$SSHD"; then

            if grep -qE '^[[:space:]]*#?[[:space:]]*UsePAM' "$SSHD"; then

                sed -i \
                    's|^[[:space:]]*#\?[[:space:]]*UsePAM.*|UsePAM yes|' \
                    "$SSHD"

            else

                echo "UsePAM yes" >> "$SSHD"

            fi

        fi

    fi

    msg_ok "CheckUser dinámico instalado."
}

#=========================================================
# INSTALAR LIMITADOR REAL
#=========================================================

instalar_limitador() {

    cat > "$LIMIT_SCRIPT" <<'EOF'
#!/bin/bash

LIMITS_FILE="/etc/kevintech/limits.conf"

[[ ! -f "$LIMITS_FILE" ]] && exit 0

obtener_sesiones() {

    local USERNAME="$1"

    who 2>/dev/null |
    awk -v USERNAME="$USERNAME" '
        $1 == USERNAME {

            tty=$2
            ip=$5

            gsub(/[()]/, "", ip)

            if (tty != "" && ip != "")
                print tty "|" ip
        }
    '
}

while IFS=: read -r USERNAME LIMIT; do

    [[ -z "$USERNAME" ]] && continue
    [[ "$USERNAME" =~ ^# ]] && continue
    [[ ! "$LIMIT" =~ ^[0-9]+$ ]] && continue

    # 0 = ilimitado
    (( LIMIT == 0 )) && continue

    id "$USERNAME" >/dev/null 2>&1 || continue

    SESSIONS=$(obtener_sesiones "$USERNAME")

    [[ -z "$SESSIONS" ]] && continue

    IPS=$(
        echo "$SESSIONS" |
        cut -d'|' -f2 |
        awk '!seen[$0]++'
    )

    COUNT=0
    ALLOWED_IPS=""

    while IFS= read -r IP; do

        [[ -z "$IP" ]] && continue

        ((COUNT++))

        if (( COUNT <= LIMIT )); then

            ALLOWED_IPS="${ALLOWED_IPS}${IP}"$'\n'

        fi

    done <<< "$IPS"

    while IFS='|' read -r TTY IP; do

        [[ -z "$TTY" ]] && continue
        [[ -z "$IP" ]] && continue

        if ! echo "$ALLOWED_IPS" |
            grep -Fxq "$IP"; then

            pkill -KILL -t "$TTY" 2>/dev/null

        fi

    done <<< "$SESSIONS"

done < "$LIMITS_FILE"

exit 0
EOF

    chmod 755 "$LIMIT_SCRIPT"

    cat > /etc/systemd/system/kevintech-limit.service <<'EOF'
[Unit]
Description=KevinTech SSH IP Limit
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /usr/local/bin/kevintech-limit; sleep 2; done'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable kevintech-limit.service >/dev/null 2>&1

    systemctl restart kevintech-limit.service >/dev/null 2>&1

    if systemctl is-active --quiet kevintech-limit.service; then

        msg_ok "Sistema de límite IP activo."

    else

        msg_warn "El sistema de límite no pudo iniciarse."

    fi
}

#=========================================================
# SINCRONIZAR CONTRASEÑA CON ZIVPN
#=========================================================

sync_zivpn_password() {

    local PASS="$1"

    local ZIVPN_CONFIG="/etc/zivpn/config.json"

    [[ ! -f "$ZIVPN_CONFIG" ]] && return 0

    if ! command -v jq >/dev/null 2>&1; then

        msg_warn "ZiVPN está instalado pero jq no está disponible."

        return 1

    fi

    if ! jq empty "$ZIVPN_CONFIG" >/dev/null 2>&1; then

        msg_error "El archivo de configuración de ZiVPN no es válido."

        return 1

    fi

    if jq -e --arg pass "$PASS" \
        '.auth.config[]? | select(. == $pass)' \
        "$ZIVPN_CONFIG" >/dev/null 2>&1; then

        msg_info "La contraseña ya existe en ZiVPN."

        return 0

    fi

    local TMP

    TMP=$(mktemp)

    if jq --arg pass "$PASS" \
        '.auth.config += [$pass]' \
        "$ZIVPN_CONFIG" > "$TMP"; then

        chmod 600 "$TMP"

        mv "$TMP" "$ZIVPN_CONFIG"

        systemctl restart zivpn >/dev/null 2>&1

        if systemctl is-active --quiet zivpn; then

            msg_ok "Contraseña sincronizada con ZiVPN."

        else

            msg_warn "Contraseña agregada, pero ZiVPN no está activo."

        fi

    else

        rm -f "$TMP"

        msg_error "No se pudo agregar la contraseña a ZiVPN."

        return 1

    fi
}

#=========================================================
# TÍTULO
#=========================================================

titulo() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚜ KevinTech Multi Script ⚜                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}              CREAR USUARIO SSH PREMIUM                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

#=========================================================
# VARIABLES
#=========================================================

SERVER_DOMAIN="${SERVER_DOMAIN:-}"

#=========================================================
# OBTENER IP PÚBLICA
#=========================================================

obtener_ip() {

    IP=$(curl -4 -s --max-time 5 ifconfig.me)

    [[ -z "$IP" ]] &&
        IP=$(hostname -I | awk '{print $1}')

    [[ -z "$IP" ]] &&
        IP="0.0.0.0"
}

#=========================================================
# INSTALAR COMPONENTES
#=========================================================

instalar_componentes() {

    msg_info "Preparando sistema de límite IP..."

    instalar_limitador

    echo

    msg_info "Preparando CheckUser dinámico..."

    instalar_checkuser

    echo
}

#=========================================================
# DETECTAR PUERTOS TCP DE UN PROCESO
#=========================================================

detectar_tcp_proceso() {

    local PROCESO="$1"

    ss -H -ltnp 2>/dev/null |
        grep -i "$PROCESO" |
        sed -nE 's/.*:([0-9]+)[[:space:]].*/\1/p' |
        sort -nu |
        paste -sd "," -
}

#=========================================================
# DETECTAR PUERTOS UDP DE UN PROCESO
#=========================================================

detectar_udp_proceso() {

    local PROCESO="$1"

    ss -H -lunp 2>/dev/null |
        grep -i "$PROCESO" |
        sed -nE 's/.*:([0-9]+)[[:space:]].*/\1/p' |
        sort -nu |
        paste -sd "," -
}

#=========================================================
# DETECTAR BADVPN
#
# BadVPN UDPGW recibe conexiones de clientes por TCP.
# Por eso NO usamos ss -lunp.
#=========================================================

detectar_badvpn() {

    BADVPN_PORTS=""

    local PORTS=""

    # Método principal: detectar procesos BadVPN
    PORTS=$(detectar_tcp_proceso "badvpn-udpgw")

    # Método alternativo: detectar servicios systemd
    if [[ -z "$PORTS" ]]; then

        for PORT in 7200 7300; do

            if systemctl is-active \
                --quiet "badvpn-udpgw-$PORT" 2>/dev/null; then

                if ss -H -ltn 2>/dev/null |
                    awk '{print $4}' |
                    grep -qE ":${PORT}$"; then

                    if [[ -z "$PORTS" ]]; then
                        PORTS="$PORT"
                    else
                        PORTS="${PORTS},${PORT}"
                    fi

                fi

            fi

        done

    fi

    BADVPN_PORTS="$PORTS"
}

#=========================================================
# DETECTAR PROTOCOLOS
#=========================================================

#=========================================================
# DETECCIÓN REAL DE SERVICIOS Y DATOS CONFIGURADOS
#=========================================================

puerto_tcp_activo() {
    local PORT="$1"
    ss -H -ltn 2>/dev/null | awk '{print $4}' |
        grep -qE "(:|\])${PORT}$"
}

detectar_protocolos() {
    SSH_PORTS=$(ss -H -ltnp 2>/dev/null |
        awk '/sshd/ {split($4,a,":"); print a[length(a)]}' |
        sort -nu | paste -sd "," -)
    [[ -z "$SSH_PORTS" ]] && SSH_PORTS="22"

    DROPBEAR_PORTS=$(detectar_tcp_proceso "dropbear")
    HAPROXY_PORTS=$(detectar_tcp_proceso "haproxy")
    BADVPN_PORTS=""
    detectar_badvpn

    UDPCUSTOM_PORTS=$(ss -H -lunp 2>/dev/null |
        awk '/udp-custom|udpcustom/ {split($5,a,":"); print a[length(a)]}' |
        sort -nu | paste -sd "," -)

    HTTP_PORTS=""
    for PORT in 80 443 8080; do
        if puerto_tcp_activo "$PORT"; then
            HTTP_PORTS="${HTTP_PORTS}${PORT},"
        fi
    done
    HTTP_PORTS="${HTTP_PORTS%,}"

    # BHTTP: el script instala el servicio y el archivo del servidor.
    BHTTP_INSTALADO="NO"
    if [[ -f /etc/systemd/system/bhttp.service &&
          -f /usr/local/lib/bhttp/bhttp-server.py ]] &&
       systemctl is-active --quiet bhttp 2>/dev/null &&
       puerto_tcp_activo 8088; then
        BHTTP_INSTALADO="SI"
    fi

    # SQUID: puerto fijado por protocolos/squid.sh.
    SQUID_INSTALADO="NO"
    SQUID_PORT="3128"
    if [[ -f /etc/squid/squid.conf ]] &&
       systemctl is-active --quiet squid 2>/dev/null &&
       puerto_tcp_activo "$SQUID_PORT"; then
        SQUID_INSTALADO="SI"
    fi

    # HCR: puerto real guardado por protocolos/hcr-server.sh.
    HCR_INSTALADO="NO"
    HCR_PORT="$(awk -F= '/^HCR_PORT=/ {gsub(/["'\"']/,"",$2); print $2; exit}' "$CONFIG" 2>/dev/null)"
    [[ "$HCR_PORT" =~ ^[0-9]+$ ]] || HCR_PORT="8880"
    if systemctl is-active --quiet hcr-server 2>/dev/null &&
       puerto_tcp_activo "$HCR_PORT"; then
        HCR_INSTALADO="SI"
    fi

    # SLIPSTREAM: obtiene el dominio del parámetro -d del servicio real.
    SLIPSTREAM_INSTALADO="NO"
    SLIPSTREAM_NS=""
    if [[ -x /usr/bin/slipstream-server ]] &&
       systemctl is-active --quiet slipstream 2>/dev/null; then
        SLIPSTREAM_NS="$(systemctl show slipstream.service -p ExecStart --value 2>/dev/null |
            sed -nE 's/.*[[:space:]]-d[[:space:]]+([^ ;}]+).*/\1/p' | head -1)"
        [[ -n "$SLIPSTREAM_NS" ]] && SLIPSTREAM_INSTALADO="SI"
    fi

    # SLOWDNS: rutas y claves oficiales del instalador protocolos/slowdns.sh.
    SLOWDNS_INSTALADO="NO"
    SLOWDNS_NS=""
    SLOWDNS_KEY=""
    if [[ -s /etc/slowdns/domain.conf && -s /etc/slowdns/server.pub ]] &&
       { systemctl is-active --quiet slowdns 2>/dev/null ||
         systemctl is-active --quiet dnstt 2>/dev/null ||
         pgrep -af 'dnstt|slowdns' >/dev/null 2>&1; }; then
        SLOWDNS_INSTALADO="SI"
        SLOWDNS_NS="$(tr -d '\r\n' < /etc/slowdns/domain.conf)"
        SLOWDNS_KEY="$(tr -d '\r\n' < /etc/slowdns/server.pub)"
    fi

    # VAYDNS: usa /etc/kevintech/vaydns.conf y /etc/vaydns/server.pub.
    VAYDNS_INSTALADO="NO"
    VAYDNS_NS=""
    VAYDNS_KEY=""
    VAYDNS_CONFIG="/etc/kevintech/vaydns.conf"
    if [[ -s "$VAYDNS_CONFIG" && -s /etc/vaydns/server.pub ]] &&
       systemctl is-active --quiet vaydns.service 2>/dev/null; then
        VAYDNS_NS="$(sed -n 's/^DOMAIN=//p' "$VAYDNS_CONFIG" | head -1 | tr -d '"' | tr -d '\r')"
        VAYDNS_KEY="$(tr -d '\r\n' < /etc/vaydns/server.pub)"
        [[ -n "$VAYDNS_NS" && -n "$VAYDNS_KEY" ]] && VAYDNS_INSTALADO="SI"
    fi

    # ZiVPN: extrae el puerto desde el JSON de su configuración.
    ZIVPN_INSTALADO="NO"
    ZIVPN_PORT=""
    if [[ -s /etc/zivpn/config.json ]] &&
       { systemctl is-active --quiet zivpn 2>/dev/null ||
         pgrep -af '[z]ivpn' >/dev/null 2>&1; }; then
        ZIVPN_INSTALADO="SI"
        if command -v jq >/dev/null 2>&1 &&
           jq empty /etc/zivpn/config.json >/dev/null 2>&1; then
            ZIVPN_PORT="$(jq -r '.listen // empty' /etc/zivpn/config.json 2>/dev/null | tr -d ':')"
        fi
    fi
}

#=========================================================
# MOSTRAR CUENTA
#=========================================================

#=========================================================
# MOSTRAR RESULTADO DE LA CUENTA
#=========================================================

mostrar_cuenta() {
    clear

    printf '%b\n' "${YELLOW}══════════ DATOS DEL USUARIO ══════════${RESET}"
    printf ' %bHost/IP      : %b%s%b\n' "$WHITE" "$CYAN" "$HOST" "$RESET"

    if [[ "$SLIPSTREAM_INSTALADO" == "SI" ]]; then
        printf ' %bSLIPSTREAM   : %b%s%b\n' "$WHITE" "$GREEN" "$SLIPSTREAM_NS" "$RESET"
    fi

    printf ' %bUsuario      : %b%s%b\n' "$WHITE" "$GREEN" "$USER" "$RESET"
    printf ' %bContraseña   : %b%s%b\n' "$WHITE" "$GREEN" "$PASS" "$RESET"

    if [[ "$ILIMITADA" == "SI" ]]; then
        printf ' %bExpira       : %bIlimitada ♾%b\n' "$WHITE" "$GREEN" "$RESET"
    else
        printf ' %bExpira       : %b%s (%s días)%b\n' "$WHITE" "$GREEN" "$FECHA_MOSTRAR" "$DIAS" "$RESET"
    fi
    printf ' %bLímite IP    : %b%s%b\n' "$WHITE" "$GREEN" "$LIMITE_MOSTRAR" "$RESET"

    printf '%b\n' "${YELLOW}══════════ PROTOCOLOS DISPONIBLES ══════════${RESET}"
    [[ -n "$SSH_PORTS" ]] && printf ' %bSSH          : %b%s%b\n' "$WHITE" "$GREEN" "$SSH_PORTS" "$RESET"
    [[ -n "$DROPBEAR_PORTS" ]] && printf ' %bDropbear     : %b%s%b\n' "$WHITE" "$GREEN" "$DROPBEAR_PORTS" "$RESET"
    [[ -n "$HAPROXY_PORTS" ]] && printf ' %bSSL Tunnel   : %b%s%b\n' "$WHITE" "$GREEN" "$HAPROXY_PORTS" "$RESET"
    [[ -n "$BADVPN_PORTS" ]] && printf ' %bBadVPN       : %b%s%b\n' "$WHITE" "$GREEN" "$BADVPN_PORTS" "$RESET"
    [[ "$BHTTP_INSTALADO" == "SI" ]] && printf ' %bBHTTP        : %b8088%b\n' "$WHITE" "$GREEN" "$RESET"
    [[ "$SQUID_INSTALADO" == "SI" ]] && printf ' %bSQUID        : %b%s%b\n' "$WHITE" "$GREEN" "$SQUID_PORT" "$RESET"
    [[ "$HCR_INSTALADO" == "SI" ]] && printf ' %bHCR          : %b%s%b\n' "$WHITE" "$GREEN" "$HCR_PORT" "$RESET"

    if [[ "$SLOWDNS_INSTALADO" == "SI" ]]; then
        printf '%b\n' "${YELLOW}══════════ SLOWDNS (5300 - 22) ══════════${RESET}"
        printf ' %bNS          : %b%s%b\n' "$WHITE" "$GREEN" "$SLOWDNS_NS" "$RESET"
        printf ' %bKEY         : %b%s%b\n' "$WHITE" "$GREEN" "$SLOWDNS_KEY" "$RESET"
    fi

    if [[ "$VAYDNS_INSTALADO" == "SI" ]]; then
        printf '%b\n' "${YELLOW}══════════ VAYDNS (5301 - 443) ══════════${RESET}"
        printf ' %bNS          : %b%s%b\n' "$WHITE" "$GREEN" "$VAYDNS_NS" "$RESET"
        printf ' %bKEY         : %b%s%b\n' "$WHITE" "$GREEN" "$VAYDNS_KEY" "$RESET"
    fi

    if [[ "$ZIVPN_INSTALADO" == "SI" ]]; then
        printf '%b\n' "${YELLOW}══════════ ZIVPN UDP ══════════${RESET}"
        printf ' %bServidor     : %b%s:%s%b\n' "$WHITE" "$GREEN" "$HOST" "${ZIVPN_PORT:-N/D}" "$RESET"
        printf ' %bContraseña   : %b%s%b\n' "$WHITE" "$GREEN" "$PASS" "$RESET"
        printf ' %bPuerto UDP   : %b20000-29999%b\n' "$WHITE" "$GREEN" "$RESET"
    fi

    if [[ -n "$HTTP_PORTS" || -n "$UDPCUSTOM_PORTS" ]]; then
        printf '%b\n' "${YELLOW}══════════ conexión directa ══════════${RESET}"

        if puerto_tcp_activo 443; then
            printf ' 🙍 SSL/TLS(SNI) : %s:443@%s:%s\n' "$HOST" "$USER" "$PASS"
        fi

        if puerto_tcp_activo 80; then
            printf ' 🙍 Proxy(WS)    : %s:80@%s:%s\n' "$HOST" "$USER" "$PASS"
        fi

        if [[ -n "$UDPCUSTOM_PORTS" ]]; then
            printf ' 🙍 SSH UDP      : %s:1-65535@%s:%s\n' "$IP" "$USER" "$PASS"
        fi
    fi

    printf '%b\n' "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}          Presione ENTER para continuar...${RESET}")"

    if [[ -f "$BASE/usuarios/menu.sh" ]]; then
        exec bash "$BASE/usuarios/menu.sh"
    else
        break
    fi
}

#=========================================================
# INICIO
#=========================================================

while true; do

    titulo

    obtener_ip

    instalar_componentes

    echo

    #=====================================================
    # USUARIO
    #=====================================================

    while true; do

        read -rp \
            "$(echo -e "${GREEN}👤 Usuario               : ${RESET}")" USER

        USER=$(echo "$USER" | tr '[:upper:]' '[:lower:]')

        if [[ -z "$USER" ]]; then

            msg_error "Debe ingresar un nombre de usuario."

            continue

        fi

        if ! [[ "$USER" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then

            msg_error \
                "Solo letras, números, _ y -. Mínimo 3 caracteres."

            continue

        fi

        if id "$USER" &>/dev/null; then

            msg_error "El usuario ya existe."

            continue

        fi

        break

    done

    echo

    #=====================================================
    # CONTRASEÑA
    #=====================================================

    while true; do

        read -rsp \
            "$(echo -e "${GREEN}🔑 Contraseña            : ${RESET}")" PASS

        echo

        if [[ -z "$PASS" ]]; then

            msg_error "Debe ingresar una contraseña."

            continue

        fi

        if [[ ${#PASS} -lt 4 ]]; then

            msg_warn \
                "Se recomienda una contraseña de al menos 4 caracteres."

        fi

        break

    done

    echo

    #=====================================================
    # DURACIÓN
    #
    # ENTER = ILIMITADA
    #=====================================================

    while true; do

        read -rp \
            "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS

        # ENTER = ilimitada
        if [[ -z "$DIAS" ]]; then

            ILIMITADA="SI"
            DIAS="∞"

            break

        fi

        if ! [[ "$DIAS" =~ ^[0-9]+$ ]]; then

            msg_error "Debe ingresar un número o presionar ENTER para ilimitada."

            continue

        fi

        if (( DIAS <= 0 )); then

            msg_error "La duración debe ser mayor que 0."

            continue

        fi

        ILIMITADA="NO"

        break

    done

    echo

    #=====================================================
    # LÍMITE IP
    #=====================================================

    while true; do

        read -rp \
            "$(echo -e "${GREEN}👥 Límite (0=Ilimitado) : ${RESET}")" LIMITE

        [[ -z "$LIMITE" ]] && LIMITE=0

        if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then

            msg_error "El límite debe ser un número."

            continue

        fi

        break

    done

    #=====================================================
    # GUARDAR LÍMITE
    #=====================================================

    touch "$LIMITS_FILE"

    sed -i "/^${USER}:/d" "$LIMITS_FILE"

    echo "${USER}:${LIMITE}" >> "$LIMITS_FILE"

    chmod 600 "$LIMITS_FILE"

    #=====================================================
    # TEXTO LÍMITE
    #=====================================================

    if (( LIMITE == 0 )); then

        LIMITE_MOSTRAR="♾ Ilimitado"

    elif (( LIMITE == 1 )); then

        LIMITE_MOSTRAR="1 IP"

    else

        LIMITE_MOSTRAR="$LIMITE IPs"

    fi

    #=====================================================
    # FECHA
    #=====================================================

    if [[ "$ILIMITADA" == "SI" ]]; then

        FECHA=""
        FECHA_MOSTRAR="Ilimitada"

    else

        FECHA=$(date -d "+${DIAS} days" +"%Y-%m-%d")

        FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

    fi

    #=====================================================
    # CREAR USUARIO
    #=====================================================

    msg_info "Creando usuario SSH..."

    if [[ "$ILIMITADA" == "SI" ]]; then

        useradd \
            -M \
            -s /usr/sbin/nologin \
            "$USER"

    else

        useradd \
            -e "$FECHA" \
            -M \
            -s /usr/sbin/nologin \
            "$USER"

    fi

    if [[ $? -ne 0 ]]; then

        msg_error "No fue posible crear el usuario."

        sed -i "/^${USER}:/d" "$LIMITS_FILE"

        sleep 2

        continue

    fi

    #=====================================================
    # CONTRASEÑA
    #=====================================================

    echo "${USER}:${PASS}" | chpasswd

    if [[ $? -ne 0 ]]; then

        msg_error "No fue posible establecer la contraseña."

        userdel -f "$USER" &>/dev/null

        sed -i "/^${USER}:/d" "$LIMITS_FILE"

        sleep 2

        continue

    fi

    #=====================================================
    # ZIVPN
    #=====================================================

    sync_zivpn_password "$PASS"

    #=====================================================
    # ACTUALIZAR LIMITADOR
    #=====================================================

    instalar_limitador

    #=====================================================
    # ACTUALIZAR CHECKUSER
    #=====================================================

    instalar_checkuser

    msg_ok "Usuario creado correctamente."

    #=====================================================
    # BANNER AUTOMÁTICO
    #=====================================================

    BANNER_MANAGER="/etc/kevintech/usuarios/banner.sh"

    if [[ -x "$BANNER_MANAGER" ]]; then

        "$BANNER_MANAGER" \
            --auto-user "$USER" \
            >/dev/null 2>&1 || true

        if [[ -f "/etc/ssh_banners/$USER.banner" ]]; then

            msg_ok "Banner automático creado para $USER."

        fi

    fi

    HOST="${SERVER_DOMAIN:-$IP}"

    #=====================================================
    # DETECTAR PROTOCOLOS
    #=====================================================

    detectar_protocolos

    #=====================================================
    # MOSTRAR RESULTADO
    #=====================================================

    mostrar_cuenta

done
