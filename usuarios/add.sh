#!/bin/bash
#=========================================================
# KevinTech Multi Script Premium
# Módulo: Crear Usuario SSH
# Límite real de IPs simultáneas
#=========================================================

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'
RESET='\e[0m'

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
LIMITS_FILE="$BASE/limits.conf"
LIMIT_SCRIPT="/usr/local/bin/kevintech-limit"

mkdir -p "$BASE"
touch "$LIMITS_FILE"
chmod 600 "$LIMITS_FILE"

[[ -f "$CONFIG" ]] && source "$CONFIG"

line() {
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" \
        "$CYAN" "$RESET"
}

pause() {
    echo
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
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

titulo() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}               ⚜ KevinTech Multi Script ⚜                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}                 CREAR USUARIO SSH PREMIUM               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

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
# INSTALAR CONTROLADOR DE LÍMITE
#=========================================================

install_limit_system() {

    msg_info "Instalando sistema de límite IP..."

    cat > "$LIMIT_SCRIPT" <<'LIMITEOF'
#!/bin/bash

#=========================================================
# KevinTech - Controlador de límite IP SSH
#=========================================================

LIMITS_FILE="/etc/kevintech/limits.conf"

[[ ! -f "$LIMITS_FILE" ]] && exit 0

#---------------------------------------------------------
# Obtener sesiones SSH del usuario
#---------------------------------------------------------

get_sessions() {

    local USERNAME="$1"

    who 2>/dev/null |
    awk -v user="$USERNAME" '
    $1 == user {
        tty=$2
        ip=$5

        gsub(/[()]/, "", ip)

        if (tty != "" && ip != "")
            print tty "|" ip
    }'
}

#---------------------------------------------------------
# Procesar cada usuario
#---------------------------------------------------------

while IFS=: read -r USER LIMIT; do

    # Ignorar líneas vacías
    [[ -z "$USER" ]] && continue

    # Ignorar comentarios
    [[ "$USER" =~ ^# ]] && continue

    # Validar límite
    [[ ! "$LIMIT" =~ ^[0-9]+$ ]] && continue

    # 0 = ilimitado
    (( LIMIT == 0 )) && continue

    # Verificar que el usuario exista
    id "$USER" >/dev/null 2>&1 || continue

    #-----------------------------------------------------
    # Obtener sesiones
    #-----------------------------------------------------

    SESSIONS=$(get_sessions "$USER")

    [[ -z "$SESSIONS" ]] && continue

    #-----------------------------------------------------
    # Obtener IPs únicas manteniendo el orden
    #-----------------------------------------------------

    IPS=$(echo "$SESSIONS" |
        cut -d'|' -f2 |
        awk '!seen[$0]++')

    COUNT=0

    ALLOWED_IPS=""

    while IFS= read -r IP; do

        [[ -z "$IP" ]] && continue

        ((COUNT++))

        if (( COUNT <= LIMIT )); then

            ALLOWED_IPS+="${IP}"$'\n'

        fi

    done <<< "$IPS"

    #-----------------------------------------------------
    # Expulsar sesiones de IPs que superan el límite
    #-----------------------------------------------------

    while IFS='|' read -r TTY IP; do

        [[ -z "$TTY" || -z "$IP" ]] && continue

        # Verificar si la IP está dentro de las permitidas
        if ! echo "$ALLOWED_IPS" |
            grep -Fxq "$IP"; then

            # Expulsar únicamente la sesión correspondiente
            pkill -KILL -t "$TTY" 2>/dev/null

        fi

    done <<< "$SESSIONS"

done < "$LIMITS_FILE"

exit 0
LIMITEOF

    chmod 755 "$LIMIT_SCRIPT"

    #=====================================================
    # SERVICE
    #=====================================================

    cat > /etc/systemd/system/kevintech-limit.service <<'SERVICEEOF'
[Unit]
Description=KevinTech SSH IP Limit
After=network.target ssh.service sshd.service

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /usr/local/bin/kevintech-limit; sleep 2; done'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload

    systemctl enable kevintech-limit.service >/dev/null 2>&1
    systemctl restart kevintech-limit.service >/dev/null 2>&1

    if systemctl is-active --quiet kevintech-limit.service; then
        msg_ok "Controlador de límite IP activo."
    else
        msg_error "No se pudo iniciar el controlador de límite."
    fi
}

#=========================================================
# INICIO
#=========================================================

while true; do

    titulo

    obtener_ip

    #=====================================================
    # USUARIO
    #=====================================================

    while true; do

        read -rp "$(echo -e "${GREEN}👤 Usuario               : ${RESET}")" USER

        USER=$(echo "$USER" | tr '[:upper:]' '[:lower:]')

        if [[ -z "$USER" ]]; then
            msg_error "Debe ingresar un nombre de usuario."
            continue
        fi

        if ! [[ "$USER" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
            msg_error "Solo letras, números, _ y -. Mínimo 3 caracteres."
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

        read -rsp "$(echo -e "${GREEN}🔑 Contraseña            : ${RESET}")" PASS
        echo

        if [[ -z "$PASS" ]]; then
            msg_error "Debe ingresar una contraseña."
            continue
        fi

        break
    done

    echo

    #=====================================================
    # DURACIÓN
    #=====================================================

    while true; do

        read -rp "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS

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
    # LÍMITE IP REAL
    #=====================================================

    while true; do

        read -rp "$(echo -e "${GREEN}👥 Límite IP (0=Ilimitado): ${RESET}")" LIMITE

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

    # Eliminar cualquier entrada anterior
    sed -i "/^${USER}:/d" "$LIMITS_FILE"

    # Guardar usuario y límite
    echo "${USER}:${LIMITE}" >> "$LIMITS_FILE"

    chmod 600 "$LIMITS_FILE"

    if (( LIMITE == 0 )); then
        LIMITE_MOSTRAR="♾ Ilimitado"
    elif (( LIMITE == 1 )); then
        LIMITE_MOSTRAR="1 IP"
    else
        LIMITE_MOSTRAR="${LIMITE} IPs"
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
    # INSTALAR CONTROLADOR
    #=====================================================

    install_limit_system

    #=====================================================
    # INFORMACIÓN
    #=====================================================

    msg_ok "Usuario creado correctamente."

    HOST="${SERVER_DOMAIN:-$IP}"

    echo

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚜ CUENTA SSH CREADA EXITOSAMENTE ⚜             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}══════════ DATOS DEL USUARIO ══════════${RESET}"

    echo -e " ${WHITE}Usuario      : ${GREEN}$USER${RESET}"
    echo -e " ${WHITE}Contraseña   : ${GREEN}$PASS${RESET}"
    echo -e " ${WHITE}Expira       : ${GREEN}$FECHA_MOSTRAR${RESET}"
    echo -e " ${WHITE}Duración     : ${GREEN}${DIAS} días${RESET}"
    echo -e " ${WHITE}Límite IP    : ${GREEN}${LIMITE_MOSTRAR}${RESET}"

    echo

    echo -e "${YELLOW}══════════ CONEXIONES ══════════${RESET}"

    echo -e " ${GREEN}${HOST}:22@${USER}:${PASS}${RESET}"
    echo -e " ${GREEN}${HOST}:80@${USER}:${PASS}${RESET}"
    echo -e " ${GREEN}${HOST}:443@${USER}:${PASS}${RESET}"
    echo -e " ${GREEN}${HOST}:8080@${USER}:${PASS}${RESET}"

    echo

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE} Límite configurado: ${GREEN}${LIMITE_MOSTRAR}${WHITE}                         ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE} Las IPs que superen el límite serán expulsadas. ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"

    exec bash "$BASE/usuarios/menu.sh"

done