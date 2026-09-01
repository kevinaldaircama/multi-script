#!/bin/bash

#=========================================================
# KevinTech Multi Script Premium
# Módulo: Crear Usuario SSH
# Versión: 3.3 Premium
# Autor: KevinTech
#
# FUNCIONES:
# - Crear usuario SSH
# - Expiración automática
# - Límite IP por usuario
# - CheckUser dinámico
# - Integración ZiVPN
# - BHTTP 8088
# - Detección real de protocolos
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

if [[ -z "$EXPIRATION" ]]; then

    EXPIRATION="Ilimitada"

fi

if [[ "$EXPIRATION" != "Ilimitada" &&
      "$EXPIRATION" != "never" &&
      "$EXPIRATION" != "Nunca" ]]; then

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

else

    DAYS="∞"

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
    echo -e "${CYAN}║${MAGENTA}               ⚜ KevinTech Multi Script ⚜                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}                 CREAR USUARIO SSH PREMIUM               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

#=========================================================
# VARIABLES
#=========================================================

SERVER_DOMAIN="${SERVER_DOMAIN:-}"

OPENSSH="${OPENSSH:-OFF}"
DROPBEAR="${DROPBEAR:-OFF}"
WEBSOCKET="${WEBSOCKET:-OFF}"
SSL="${SSL:-OFF}"
SLOWDNS="${SLOWDNS:-OFF}"

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
# DETECTAR PROTOCOLOS
#=========================================================

detectar_protocolos() {

    #=====================================================
    # SSH
    #=====================================================

    SSH_PORTS=$(
        ss -ltnp 2>/dev/null |
        awk '/sshd/ {
            split($4,a,":");
            print a[length(a)]
        }' |
        sort -nu |
        paste -sd "," -
    )

    [[ -z "$SSH_PORTS" ]] &&
        SSH_PORTS="22"


    #=====================================================
    # DROPBEAR
    #=====================================================

    DROPBEAR_PORTS=$(
        ss -ltnp 2>/dev/null |
        awk '/dropbear/ {
            split($4,a,":");
            print a[length(a)]
        }' |
        sort -nu |
        paste -sd "," -
    )


    #=====================================================
    # SSL / HAPROXY
    #=====================================================

    HAPROXY_PORTS=$(
        ss -ltnp 2>/dev/null |
        awk '/haproxy/ {
            split($4,a,":");
            print a[length(a)]
        }' |
        sort -nu |
        paste -sd "," -
    )


    #=====================================================
    # BADVPN
    #=====================================================

    BADVPN_PORTS=$(
        ss -lunp 2>/dev/null |
        awk '/badvpn/ {
            split($5,a,":");
            print a[length(a)]
        }' |
        sort -nu |
        paste -sd "," -
    )


    #=====================================================
    # UDP CUSTOM
    #=====================================================

    UDPCUSTOM_PORTS=$(
        ss -lunp 2>/dev/null |
        awk '/udp-custom|udpcustom/ {
            split($5,a,":");
            print a[length(a)]
        }' |
        sort -nu |
        paste -sd "," -
    )


    #=====================================================
    # SLOWDNS
    #=====================================================

    SLOWDNS_INSTALADO="NO"
    SLOWDNS_NS=""
    SLOWDNS_KEY=""

    if [[ -f /etc/slowdns/domain.conf &&
          -f /etc/slowdns/server.pub ]]; then

        if systemctl is-active --quiet slowdns 2>/dev/null ||
           systemctl is-active --quiet dnstt 2>/dev/null ||
           pgrep -af "dnstt|slowdns" >/dev/null 2>&1; then

            SLOWDNS_INSTALADO="SI"

            SLOWDNS_NS=$(cat /etc/slowdns/domain.conf 2>/dev/null)

            SLOWDNS_KEY=$(cat /etc/slowdns/server.pub 2>/dev/null)

        fi
    fi


    #=====================================================
    # BHTTP 8088
    #=====================================================

    BHTTP_INSTALADO="NO"

    if [[ -f /etc/systemd/system/bhttp.service &&
          -f /usr/local/lib/bhttp/bhttp-server.py ]]; then

        if systemctl is-active --quiet bhttp 2>/dev/null &&
           ss -H -ltn 2>/dev/null |
           awk '{print $4}' |
           grep -qE ':8088$'; then

            BHTTP_INSTALADO="SI"

        fi
    fi


    #=====================================================
    # HYSTERIA
    #=====================================================

    HYSTERIA_INSTALADO="NO"
    HYSTERIA_PORT=""
    HYSTERIA_OBFS=""

    if [[ -f /etc/hysteria/config.json ]]; then

        if systemctl is-active --quiet hysteria 2>/dev/null ||
           systemctl is-active --quiet hysteria-server 2>/dev/null ||
           systemctl is-active --quiet hysteria1-server 2>/dev/null ||
           pgrep -af hysteria >/dev/null 2>&1; then

            HYSTERIA_INSTALADO="SI"

            if command -v jq >/dev/null 2>&1 &&
               jq empty /etc/hysteria/config.json >/dev/null 2>&1; then

                HYSTERIA_PORT=$(
                    jq -r '.listen // empty' \
                    /etc/hysteria/config.json 2>/dev/null |
                    sed 's/^://'
                )

                HYSTERIA_OBFS=$(
                    jq -r '
                        .obfs.password //
                        .obfs //
                        empty
                    ' /etc/hysteria/config.json 2>/dev/null
                )

            else

                HYSTERIA_PORT=$(
                    grep -oP '"listen"\s*:\s*":\K[0-9]+' \
                    /etc/hysteria/config.json 2>/dev/null |
                    head -1
                )

                HYSTERIA_OBFS=$(
                    grep -oP '"obfs"\s*:\s*"\K[^"]+' \
                    /etc/hysteria/config.json 2>/dev/null |
                    head -1
                )

            fi

        fi
    fi


    #=====================================================
    # ZIVPN
    #=====================================================

    ZIVPN_INSTALADO="NO"
    ZIVPN_PORT=""

    if [[ -f /etc/zivpn/config.json ]]; then

        if systemctl is-active --quiet zivpn 2>/dev/null ||
           pgrep -af zivpn >/dev/null 2>&1; then

            ZIVPN_INSTALADO="SI"

            if command -v jq >/dev/null 2>&1 &&
               jq empty /etc/zivpn/config.json >/dev/null 2>&1; then

                ZIVPN_PORT=$(
                    jq -r '.listen // empty' \
                    /etc/zivpn/config.json 2>/dev/null |
                    tr -d ':'
                )

            fi

        fi
    fi


    #=====================================================
    # OPENVPN
    #=====================================================

    OPENVPN_INSTALADO="NO"
    OPENVPN_PORTS=""

    if systemctl is-active --quiet openvpn-server@server 2>/dev/null ||
       systemctl is-active --quiet openvpn 2>/dev/null ||
       pgrep -x openvpn >/dev/null 2>&1; then

        OPENVPN_PORTS=$(
            ss -ltnp 2>/dev/null |
            awk '/openvpn/ {
                split($4,a,":");
                print a[length(a)]
            }' |
            sort -nu |
            paste -sd "," -
        )

        OPENVPN_PORTS_UDP=$(
            ss -lunp 2>/dev/null |
            awk '/openvpn/ {
                split($5,a,":");
                print a[length(a)]
            }' |
            sort -nu |
            paste -sd "," -
        )

        if [[ -n "$OPENVPN_PORTS" &&
              -n "$OPENVPN_PORTS_UDP" ]]; then

            OPENVPN_PORTS="$OPENVPN_PORTS,$OPENVPN_PORTS_UDP"

        elif [[ -z "$OPENVPN_PORTS" ]]; then

            OPENVPN_PORTS="$OPENVPN_PORTS_UDP"

        fi

        if [[ -n "$OPENVPN_PORTS" ]]; then

            OPENVPN_INSTALADO="SI"

        fi

    fi


    #=====================================================
    # HTTP CUSTOM
    #=====================================================

    HTTP_PORTS=""

    for PORT in 80 443 8080; do

        if ss -H -ltn 2>/dev/null |
           awk '{print $4}' |
           grep -qE ":${PORT}$"; then

            HTTP_PORTS="${HTTP_PORTS}${PORT},"

        fi

    done

    HTTP_PORTS="${HTTP_PORTS%,}"

}

#=========================================================
# MOSTRAR CUENTA
#=========================================================

mostrar_cuenta() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚜ CUENTA SSH CREADA EXITOSAMENTE ⚜             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}══════════ DATOS DEL USUARIO ══════════${RESET}"

    echo -e " ${WHITE}Usuario      : ${GREEN}$USER${RESET}"
    echo -e " ${WHITE}Contraseña   : ${GREEN}$PASS${RESET}"
    echo -e " ${WHITE}Expira       : ${GREEN}$FECHA_MOSTRAR${RESET} ${GRAY}(${DIAS} días)${RESET}"
    echo -e " ${WHITE}Límite IP    : ${GREEN}$LIMITE_MOSTRAR${RESET}"

    echo

    echo -e "${YELLOW}══════════ INFORMACIÓN DEL SERVIDOR ══════════${RESET}"

    echo -e " ${WHITE}Host/IP      : ${CYAN}$HOST${RESET}"

    #=====================================================
    # SSH
    #=====================================================

    if [[ -n "$SSH_PORTS" ]]; then

        echo -e " ${WHITE}SSH          : ${GREEN}$SSH_PORTS${RESET}"

    fi


    #=====================================================
    # DROPBEAR
    #=====================================================

    if [[ -n "$DROPBEAR_PORTS" ]]; then

        echo -e " ${WHITE}Dropbear     : ${GREEN}$DROPBEAR_PORTS${RESET}"

    fi


    #=====================================================
    # SSL
    #=====================================================

    if [[ -n "$HAPROXY_PORTS" ]]; then

        echo -e " ${WHITE}SSL Tunnel   : ${GREEN}$HAPROXY_PORTS${RESET}"

    fi


    #=====================================================
    # BADVPN
    #=====================================================

    if [[ -n "$BADVPN_PORTS" ]]; then

        echo -e " ${WHITE}BadVPN       : ${GREEN}$BADVPN_PORTS${RESET}"

    fi


    #=====================================================
    # UDP CUSTOM
    #=====================================================

    if [[ -n "$UDPCUSTOM_PORTS" ]]; then

        echo -e " ${WHITE}UDP Custom   : ${GREEN}$UDPCUSTOM_PORTS${RESET}"

    fi


    #=====================================================
    # OPENVPN
    #=====================================================

    if [[ "$OPENVPN_INSTALADO" == "SI" &&
          -n "$OPENVPN_PORTS" ]]; then

        echo -e " ${WHITE}OpenVPN      : ${GREEN}$OPENVPN_PORTS${RESET}"

    fi


    #=====================================================
    # SLOWDNS
    #=====================================================

    if [[ "$SLOWDNS_INSTALADO" == "SI" ]]; then

        echo

        echo -e "${YELLOW}══════════ SLOWDNS (5300) ══════════${RESET}"

        echo -e " ${WHITE}NS          : ${GREEN}${SLOWDNS_NS}${RESET}"
        echo -e " ${WHITE}KEY         : ${GREEN}${SLOWDNS_KEY}${RESET}"

    fi


    #=====================================================
    # BHTTP
    # SIEMPRE DEBAJO DE SLOWDNS
    #=====================================================

    if [[ "$BHTTP_INSTALADO" == "SI" ]]; then

        echo

        echo -e "${YELLOW}══════════ BHTTP (8088) ══════════${RESET}"

        echo -e " ${WHITE}Servidor    : ${GREEN}${HOST}:8088${RESET}"
        echo -e " ${WHITE}Backend SSH : ${GREEN}127.0.0.1:22${RESET}"
        echo -e " ${WHITE}Estado      : ${GREEN}● ONLINE${RESET}"

    fi


    #=====================================================
    # HYSTERIA
    #=====================================================

    if [[ "$HYSTERIA_INSTALADO" == "SI" ]]; then

        echo

        echo -e "${YELLOW}══════════ HYSTERIA V1 ══════════${RESET}"

        echo -e " ${WHITE}Servidor     : ${GREEN}${HOST}:${HYSTERIA_PORT:-N/D}${RESET}"
        echo -e " ${WHITE}OBFS         : ${GREEN}${HYSTERIA_OBFS:-N/D}${RESET}"
        echo -e " ${WHITE}Credenciales : ${GREEN}${USER}:${PASS}${RESET}"

    fi


    #=====================================================
    # ZIVPN
    #=====================================================

    if [[ "$ZIVPN_INSTALADO" == "SI" ]]; then

        echo

        echo -e "${YELLOW}══════════ ZIVPN UDP ══════════${RESET}"

        echo -e " ${WHITE}Servidor     : ${GREEN}${HOST}:${ZIVPN_PORT:-N/D}${RESET}"
        echo -e " ${WHITE}Contraseña   : ${GREEN}${PASS}${RESET}"
        echo -e " ${WHITE}Puerto UDP   : ${GREEN}20000-29999${RESET}"

    fi


    #=====================================================
    # HTTP CUSTOM
    #=====================================================

    if [[ -n "$HTTP_PORTS" ]]; then

        echo

        echo -e "${YELLOW}══════════ HTTP CUSTOM ══════════${RESET}"

        IFS=',' read -ra HTTP_ARRAY <<< "$HTTP_PORTS"

        for PORT in "${HTTP_ARRAY[@]}"; do

            echo -e \
                " ${GREEN}${HOST}:${PORT}@${USER}:${PASS}${RESET}"

        done

    fi


    #=====================================================
    # UDP CUSTOM
    #=====================================================

    if [[ -n "$UDPCUSTOM_PORTS" ]]; then

        echo

        echo -e "${YELLOW}══════════ UDP CUSTOM ══════════${RESET}"

        echo -e \
            " ${GREEN}${HOST}:1-65535@${USER}:${PASS}${RESET}"

    fi


    echo

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}          Presione ENTER para continuar...${RESET}"

    read

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
    #=====================================================

    while true; do

        read -rp \
            "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS

        [[ -z "$DIAS" ]] && DIAS=30

        if ! [[ "$DIAS" =~ ^[0-9]+$ ]]; then

            msg_error "Debe ingresar un número."

            continue

        fi

        if (( DIAS <= 0 )); then

            msg_error "La duración debe ser mayor que 0."

            continue

        fi

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

    FECHA=$(date -d "+${DIAS} days" +"%Y-%m-%d")

    FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

    #=====================================================
    # CREAR USUARIO
    #=====================================================

    msg_info "Creando usuario SSH..."

    useradd \
        -e "$FECHA" \
        -M \
        -s /usr/sbin/nologin \
        "$USER"

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