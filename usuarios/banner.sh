#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# Version: 4.0
#
# Sistema:
# - Banners individuales por usuario
# - /etc/ssh_banners/
# - Match User en sshd_config
# - CheckUser integrado en el banner
# - Expiración por usuario
# - Límite IP por usuario
# - Backups
# - OpenSSH
# - Dropbear
#==================================================

#==================================================
# COLORES
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==================================================
# CONFIGURACIÓN
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

# Directorio de banners individuales
BANNER_DIR="/etc/ssh_banners"

# Configuración SSH
SSHD="/etc/ssh/sshd_config"

# Dropbear
DROPBEAR="/etc/default/dropbear"

# Límites
LIMITS_FILE="$BASE/limits.conf"

# Backups
BACKUP_DIR="$BASE/banner-backups"

# Marcadores de sshd_config
MARKER_START="# >>> KEVINTECH_USER_BANNERS_START <<<"
MARKER_END="# >>> KEVINTECH_USER_BANNERS_END <<<"

mkdir -p "$BASE"
mkdir -p "$BANNER_DIR"
mkdir -p "$BACKUP_DIR"

touch "$LIMITS_FILE"

chmod 600 "$LIMITS_FILE"
chmod 755 "$BANNER_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==================================================
# ROOT
#==================================================

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"

    exit 1

fi

#==================================================
# FUNCIONES GENERALES
#==================================================

pause() {

    echo

    read -n1 -s -r -p \
        "$(echo -e "${YELLOW}Presione cualquier tecla para continuar...${RESET}")"

    echo

}

header() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          KEVINTECH BANNER MANAGER                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}          SSH BANNERS + CHECK USER                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

}

#==================================================
# COMPROBAR OPENSSH
#==================================================

ssh_installed() {

    [[ -f "$SSHD" ]] || return 1

    command -v sshd >/dev/null 2>&1

}

#==================================================
# COMPROBAR DROPBEAR
#==================================================

dropbear_installed() {

    [[ -f "$DROPBEAR" ]] || return 1

}

#==================================================
# OBTENER SERVICIO SSH
#==================================================

get_ssh_service() {

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^ssh.service"; then

        echo "ssh"

    elif systemctl list-unit-files 2>/dev/null |
        grep -q "^sshd.service"; then

        echo "sshd"

    fi

}

#==================================================
# ESTADO SSH
#==================================================

service_status() {

    if ssh_installed; then

        if systemctl is-active --quiet ssh 2>/dev/null ||
           systemctl is-active --quiet sshd 2>/dev/null; then

            echo -e "${GREEN}✔ ACTIVO${RESET}"

        else

            echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

        fi

    else

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

    fi

}

#==================================================
# ESTADO DROPBEAR
#==================================================

dropbear_status() {

    if dropbear_installed; then

        if systemctl is-active --quiet dropbear 2>/dev/null; then

            echo -e "${GREEN}✔ ACTIVO${RESET}"

        else

            echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

        fi

    else

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

    fi

}

#==================================================
# CONTAR BANNERS
#==================================================

count_banners() {

    if [[ -d "$BANNER_DIR" ]]; then

        find "$BANNER_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.banner" |
            wc -l

    else

        echo "0"

    fi

}

#==================================================
# ESTADO
#==================================================

show_status() {

    echo -e "${CYAN}Estado del sistema${RESET}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e "Directorio : ${WHITE}$BANNER_DIR${RESET}"

    echo -e "Banners    : ${GREEN}$(count_banners) usuarios${RESET}"

    echo -n "OpenSSH    : "
    service_status

    echo -n "Dropbear   : "
    dropbear_status

    echo

}

#==================================================
# BACKUP
#==================================================

create_backup() {

    local DATE
    DATE=$(date +"%Y%m%d_%H%M%S")

    local DIR="$BACKUP_DIR/$DATE"

    mkdir -p "$DIR"

    # Backup sshd_config
    [[ -f "$SSHD" ]] &&
        cp -a "$SSHD" "$DIR/sshd_config"

    # Backup Dropbear
    [[ -f "$DROPBEAR" ]] &&
        cp -a "$DROPBEAR" "$DIR/dropbear"

    # Backup banners
    if [[ -d "$BANNER_DIR" ]]; then

        mkdir -p "$DIR/ssh_banners"

        cp -a "$BANNER_DIR"/. "$DIR/ssh_banners/" 2>/dev/null

    fi

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo -e "${GREEN}✔ Backup creado:${RESET} $DIR"

}

#==================================================
# OBTENER LÍMITE DEL USUARIO
#==================================================

get_user_limit() {

    local USERNAME="$1"

    local LIMIT

    LIMIT=$(
        awk -F: -v u="$USERNAME" '
            $1 == u {
                print $2
                exit
            }
        ' "$LIMITS_FILE" 2>/dev/null
    )

    # Si no existe en limits.conf,
    # intentar /etc/security/limits.conf
    if [[ -z "$LIMIT" ]]; then

        LIMIT=$(
            awk -v u="$USERNAME" '
                $1 == u &&
                $2 == "hard" &&
                $3 == "maxlogins" {
                    print $4
                    exit
                }
            ' /etc/security/limits.conf 2>/dev/null
        )

    fi

    [[ -z "$LIMIT" ]] && LIMIT=0

    echo "$LIMIT"

}

#==================================================
# OBTENER EXPIRACIÓN
#==================================================

get_user_expiration() {

    local USERNAME="$1"

    local EXP

    EXP=$(
        chage -l "$USERNAME" 2>/dev/null |
        awk -F': ' '
            /Account expires/ {
                print $2
                exit
            }
        '
    )

    if [[ -z "$EXP" ||
          "$EXP" == "never" ||
          "$EXP" == "Nunca" ]]; then

        echo "Ilimitada"

        return

    fi

    local DATE

    DATE=$(date -d "$EXP" +"%Y-%m-%d" 2>/dev/null)

    if [[ -n "$DATE" ]]; then

        echo "$DATE"

    else

        echo "$EXP"

    fi

}

#==================================================
# DÍAS RESTANTES
#==================================================

get_days_left() {

    local EXP="$1"

    if [[ "$EXP" == "Ilimitada" ||
          "$EXP" == "never" ||
          "$EXP" == "Nunca" ]]; then

        echo "∞"

        return

    fi

    local EXP_DATE
    local TODAY
    local DIFF

    EXP_DATE=$(date -d "$EXP" +%s 2>/dev/null)
    TODAY=$(date +%s)

    if [[ -z "$EXP_DATE" ]]; then

        echo "N/D"

        return

    fi

    DIFF=$(( (EXP_DATE - TODAY) / 86400 ))

    (( DIFF < 0 )) && DIFF=0

    echo "$DIFF"

}

#==================================================
# IPs ACTUALES
#==================================================

get_user_ips() {

    local USERNAME="$1"

    who 2>/dev/null |
    awk -v u="$USERNAME" '
        $1 == u {

            ip=$5

            gsub(/[()]/, "", ip)

            if (ip != "" &&
                ip != "-" &&
                ip != "localhost")
                print ip
        }
    ' |
    sort -u

}

#==================================================
# CONEXIONES ACTUALES
#==================================================

get_user_connections() {

    local USERNAME="$1"

    local IPS

    IPS=$(get_user_ips "$USERNAME")

    if [[ -z "$IPS" ]]; then

        echo "0"

    else

        printf '%s\n' "$IPS" |
            grep -c .

    fi

}

#==================================================
# GENERAR CHECKUSER
#==================================================

generate_checkuser() {

    local USERNAME="$1"
    local TITLE="$2"
    local LIMIT="$3"
    local EXPIRATION="$4"

    local DAYS

    DAYS=$(get_days_left "$EXPIRATION")

    local LIMIT_TEXT

    if (( LIMIT <= 0 )); then

        LIMIT_TEXT="∞ Ilimitado"

    elif (( LIMIT == 1 )); then

        LIMIT_TEXT="1 IP"

    else

        LIMIT_TEXT="${LIMIT} IPs"

    fi

    local CONNECTIONS

    CONNECTIONS=$(get_user_connections "$USERNAME")

    cat <<EOF
╠════════════════════════════════════════════════════╣
║                  CHECK USER                        ║
╠════════════════════════════════════════════════════╣
║ 👤 Usuario        : $USERNAME
║ 🔌 Conexiones     : $CONNECTIONS/$LIMIT
║ 📅 Expiración     : $EXPIRATION
║ ⏳ Días restantes : $DAYS
║ 👥 Límite IP      : $LIMIT_TEXT
╚════════════════════════════════════════════════════╝
EOF

}

#==================================================
# GENERAR BANNER INDIVIDUAL
#==================================================

generate_user_banner() {

    local USERNAME="$1"
    local SERVER="$2"
    local PROMO="$3"
    local CHANNEL="$4"
    local SUPPORT="$5"

    local LIMIT
    LIMIT=$(get_user_limit "$USERNAME")

    local EXPIRATION
    EXPIRATION=$(get_user_expiration "$USERNAME")

    local DAYS
    DAYS=$(get_days_left "$EXPIRATION")

    local LIMIT_TEXT

    if (( LIMIT <= 0 )); then

        LIMIT_TEXT="∞ Ilimitado"

    elif (( LIMIT == 1 )); then

        LIMIT_TEXT="1 IP"

    else

        LIMIT_TEXT="${LIMIT} IPs"

    fi

    cat <<EOF
╔════════════════════════════════════════════════════╗
║                 $SERVER
╠════════════════════════════════════════════════════╣
║                                                    ║
║ $PROMO
║                                                    ║
║ 📢 Canal   : $CHANNEL
║ 👤 Soporte : $SUPPORT
║                                                    ║
╠════════════════════════════════════════════════════╣
║                  CHECK USER                        ║
╠════════════════════════════════════════════════════╣
║ 👤 Usuario        : $USERNAME
║ 🔌 Conexiones     : 0/$LIMIT
║ 📅 Expiración     : $EXPIRATION
║ ⏳ Días restantes : $DAYS
║ 👥 Límite IP      : $LIMIT_TEXT
╚════════════════════════════════════════════════════╝
EOF

}

#==================================================
# CREAR BANNER DE USUARIO
#==================================================

create_user_banner() {

    header

    echo -e "${MAGENTA}              CREAR BANNER DE USUARIO${RESET}"

    echo

    read -rp \
        "$(echo -e "${GREEN}Usuario Linux:${RESET} ")" USERNAME

    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

    if [[ -z "$USERNAME" ]]; then

        echo -e "${RED}✘ Usuario vacío.${RESET}"

        pause

        return

    fi

    if ! id "$USERNAME" >/dev/null 2>&1; then

        echo -e "${RED}✘ El usuario no existe.${RESET}"

        pause

        return

    fi

    echo

    read -rp \
        "$(echo -e "${GREEN}Nombre del servidor:${RESET} ")" SERVER

    [[ -z "$SERVER" ]] &&
        SERVER="KevinTech VPN"

    read -rp \
        "$(echo -e "${GREEN}Texto promocional:${RESET} ")" PROMO

    [[ -z "$PROMO" ]] &&
        PROMO="🔥 Bienvenido a $SERVER 🔥"

    read -rp \
        "$(echo -e "${GREEN}Canal Telegram:${RESET} ")" CHANNEL

    [[ -z "$CHANNEL" ]] &&
        CHANNEL="@KevinTech"

    read -rp \
        "$(echo -e "${GREEN}Soporte:${RESET} ")" SUPPORT

    [[ -z "$SUPPORT" ]] &&
        SUPPORT="@KevinSupport"

    local USER_BANNER="$BANNER_DIR/${USERNAME}.banner"

    create_backup

    generate_user_banner \
        "$USERNAME" \
        "$SERVER" \
        "$PROMO" \
        "$CHANNEL" \
        "$SUPPORT" \
        > "$USER_BANNER"

    chmod 644 "$USER_BANNER"

    echo

    echo -e "${GREEN}✔ Banner creado:${RESET}"
    echo "$USER_BANNER"

    echo

    echo -e "${CYAN}Vista previa:${RESET}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$USER_BANNER"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar a OpenSSH? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        sync_ssh_banners

        ;;

    *)

        echo -e "${YELLOW}Banner guardado pero no aplicado.${RESET}"

        ;;

    esac

    sleep 2

}

#==================================================
# SINCRONIZAR SSH
#==================================================

sync_ssh_banners() {

    if ! ssh_installed; then

        echo -e "${RED}✘ OpenSSH no está instalado.${RESET}"

        return 1

    fi

    create_backup

    local TMP

    TMP=$(mktemp)

    #------------------------------------------
    # Eliminar bloque anterior
    #------------------------------------------

    awk -v start="$MARKER_START" \
        -v end="$MARKER_END" '
        $0 == start {
            inside=1
            next
        }

        $0 == end {
            inside=0
            next
        }

        !inside {
            print
        }
    ' "$SSHD" > "$TMP"

    #------------------------------------------
    # Construir nuevo bloque
    #------------------------------------------

    {
        cat "$TMP"

        echo
        echo "$MARKER_START"
        echo

        for BANNER in "$BANNER_DIR"/*.banner; do

            [[ -f "$BANNER" ]] || continue

            USERNAME=$(basename "$BANNER" .banner)

            # Validar usuario
            if ! id "$USERNAME" >/dev/null 2>&1; then
                continue
            fi

            echo "Match User $USERNAME"
            echo "    Banner $BANNER"
            echo

        done

        echo "$MARKER_END"

    } > "${TMP}.new"

    #------------------------------------------
    # Validar antes de instalar
    #------------------------------------------

    if ! sshd -t -f "${TMP}.new" 2>/dev/null; then

        echo -e "${RED}✘ sshd_config generado no es válido.${RESET}"

        rm -f "$TMP" "${TMP}.new"

        return 1

    fi

    cp -a "${TMP}.new" "$SSHD"

    rm -f "$TMP" "${TMP}.new"

    echo -e "${GREEN}✔ sshd_config actualizado.${RESET}"

    local SERVICE

    SERVICE=$(get_ssh_service)

    if [[ -n "$SERVICE" ]]; then

        if systemctl reload "$SERVICE" 2>/dev/null; then

            echo -e "${GREEN}✔ OpenSSH recargado correctamente.${RESET}"

        else

            echo -e "${YELLOW}⚠ No se pudo recargar OpenSSH.${RESET}"

        fi

    fi

    return 0

}

#==================================================
# REGENERAR TODOS LOS BANNERS
#==================================================

refresh_all_banners() {

    header

    echo -e "${MAGENTA}              ACTUALIZAR BANNERS${RESET}"

    echo

    if [[ ! -d "$BANNER_DIR" ]]; then

        echo -e "${RED}✘ No existe $BANNER_DIR${RESET}"

        pause

        return

    fi

    local COUNT=0

    for BANNER in "$BANNER_DIR"/*.banner; do

        [[ -f "$BANNER" ]] || continue

        USERNAME=$(basename "$BANNER" .banner)

        if ! id "$USERNAME" >/dev/null 2>&1; then

            echo -e "${YELLOW}⚠ Usuario inexistente: $USERNAME${RESET}"

            continue

        fi

        # Leer información existente del banner
        SERVER="KevinTech VPN"
        PROMO="🔥 Bienvenido a KevinTech VPN 🔥"
        CHANNEL="@KevinTech"
        SUPPORT="@KevinSupport"

        generate_user_banner \
            "$USERNAME" \
            "$SERVER" \
            "$PROMO" \
            "$CHANNEL" \
            "$SUPPORT" \
            > "$BANNER"

        chmod 644 "$BANNER"

        ((COUNT++))

    done

    echo

    echo -e "${GREEN}✔ $COUNT banners actualizados.${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Sincronizar sshd_config? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            sync_ssh_banners

            ;;

    esac

    pause

}

#==================================================
# LISTAR BANNERS
#==================================================

list_banners() {

    header

    echo -e "${MAGENTA}                 BANNERS DE USUARIOS${RESET}"

    echo

    if [[ ! -d "$BANNER_DIR" ]]; then

        echo -e "${RED}✘ No existe el directorio.${RESET}"

        pause

        return

    fi

    local COUNT=0

    for BANNER in "$BANNER_DIR"/*.banner; do

        [[ -f "$BANNER" ]] || continue

        USERNAME=$(basename "$BANNER" .banner)

        LIMIT=$(get_user_limit "$USERNAME")
        EXPIRATION=$(get_user_expiration "$USERNAME")
        DAYS=$(get_days_left "$EXPIRATION")

        ((COUNT++))

        echo -e "${CYAN}[$COUNT]${RESET} ${GREEN}$USERNAME${RESET}"
        echo -e "    Límite      : $LIMIT"
        echo -e "    Expiración  : $EXPIRATION"
        echo -e "    Días        : $DAYS"
        echo -e "    Archivo     : $BANNER"

        echo

    done

    if (( COUNT == 0 )); then

        echo -e "${YELLOW}No existen banners de usuarios.${RESET}"

    fi

    pause

}

#==================================================
# VER BANNER
#==================================================

view_banner() {

    header

    echo -e "${MAGENTA}                 VER BANNER${RESET}"

    echo

    read -rp \
        "$(echo -e "${GREEN}Usuario:${RESET} ")" USERNAME

    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

    local USER_BANNER="$BANNER_DIR/${USERNAME}.banner"

    if [[ ! -f "$USER_BANNER" ]]; then

        echo -e "${RED}✘ No existe banner para $USERNAME.${RESET}"

        pause

        return

    fi

    echo

    echo -e "${GREEN}Archivo:${RESET} $USER_BANNER"

    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$USER_BANNER"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    pause

}

#==================================================
# EDITAR BANNER
#==================================================

edit_banner() {

    header

    echo -e "${MAGENTA}                 EDITAR BANNER${RESET}"

    echo

    read -rp \
        "$(echo -e "${GREEN}Usuario:${RESET} ")" USERNAME

    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

    local USER_BANNER="$BANNER_DIR/${USERNAME}.banner"

    if [[ ! -f "$USER_BANNER" ]]; then

        echo -e "${YELLOW}No existe el banner de $USERNAME.${RESET}"

        pause

        return

    fi

    create_backup

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}✘ Nano no está instalado.${RESET}"

        pause

        return

    fi

    nano "$USER_BANNER"

    echo

    echo -e "${GREEN}✔ Banner editado.${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar cambios a OpenSSH? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            sync_ssh_banners

            ;;

        *)

            echo -e "${YELLOW}Cambios guardados pero no aplicados.${RESET}"

            ;;

    esac

    sleep 2

}

#==================================================
# ELIMINAR BANNER
#==================================================

delete_banner() {

    header

    echo -e "${MAGENTA}                 ELIMINAR BANNER${RESET}"

    echo

    read -rp \
        "$(echo -e "${GREEN}Usuario:${RESET} ")" USERNAME

    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

    local USER_BANNER="$BANNER_DIR/${USERNAME}.banner"

    if [[ ! -f "$USER_BANNER" ]]; then

        echo -e "${RED}✘ No existe banner para $USERNAME.${RESET}"

        pause

        return

    fi

    echo

    cat "$USER_BANNER"

    echo

    read -rp \
        "$(echo -e "${RED}¿Eliminar banner de $USERNAME? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            create_backup

            rm -f "$USER_BANNER"

            echo

            echo -e "${GREEN}✔ Banner eliminado.${RESET}"

            sync_ssh_banners

            ;;

        *)

            echo -e "${YELLOW}Operación cancelada.${RESET}"

            ;;

    esac

    sleep 2

}

#==================================================
# PROBAR CONFIGURACIÓN
#==================================================

test_configuration() {

    header

    echo -e "${MAGENTA}                 PRUEBA DEL SISTEMA${RESET}"

    echo

    #------------------------------------------
    # Directorio
    #------------------------------------------

    if [[ -d "$BANNER_DIR" ]]; then

        echo -e "${GREEN}✔ Directorio existe:${RESET}"
        echo "$BANNER_DIR"

    else

        echo -e "${RED}✘ Directorio no existe.${RESET}"

    fi

    echo

    #------------------------------------------
    # SSH
    #------------------------------------------

    if ssh_installed; then

        echo -e "${GREEN}✔ OpenSSH instalado${RESET}"

        if sshd -t 2>/dev/null; then

            echo -e "${GREEN}✔ sshd_config válido${RESET}"

        else

            echo -e "${RED}✘ sshd_config inválido${RESET}"

        fi

        if grep -qF "$MARKER_START" "$SSHD" 2>/dev/null; then

            echo -e "${GREEN}✔ Bloque KevinTech encontrado${RESET}"

        else

            echo -e "${YELLOW}⚠ Bloque KevinTech no encontrado${RESET}"

        fi

    else

        echo -e "${GRAY}⚠ OpenSSH no instalado${RESET}"

    fi

    echo

    #------------------------------------------
    # Banners
    #------------------------------------------

    echo -e "${CYAN}Banners encontrados:${RESET}"

    for BANNER in "$BANNER_DIR"/*.banner; do

        [[ -f "$BANNER" ]] || continue

        USERNAME=$(basename "$BANNER" .banner)

        if id "$USERNAME" >/dev/null 2>&1; then

            echo -e "${GREEN}✔${RESET} $USERNAME → $BANNER"

        else

            echo -e "${YELLOW}⚠${RESET} $USERNAME → usuario no existe"

        fi

    done

    echo

    #------------------------------------------
    # Dropbear
    #------------------------------------------

    if dropbear_installed; then

        echo -e "${GREEN}✔ Dropbear instalado${RESET}"

        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

            echo -e "${GREEN}✔ Dropbear tiene banner configurado${RESET}"

        else

            echo -e "${YELLOW}⚠ Dropbear no tiene banner configurado${RESET}"

        fi

    else

        echo -e "${GRAY}⚠ Dropbear no instalado${RESET}"

    fi

    pause

}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configure_dropbear() {

    if ! dropbear_installed; then

        echo -e "${YELLOW}⚠ Dropbear no está instalado.${RESET}"

        return

    fi

    # Dropbear utiliza un banner global.
    # Usamos el primer banner disponible.

    local FIRST_BANNER

    FIRST_BANNER=$(find "$BANNER_DIR" \
        -maxdepth 1 \
        -type f \
        -name "*.banner" |
        sort |
        head -1)

    if [[ -z "$FIRST_BANNER" ]]; then

        echo -e "${YELLOW}⚠ No existen banners para Dropbear.${RESET}"

        return

    fi

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$FIRST_BANNER\"|" \
            "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$FIRST_BANNER\"" >> "$DROPBEAR"

    fi

    systemctl restart dropbear 2>/dev/null

    if systemctl is-active --quiet dropbear; then

        echo -e "${GREEN}✔ Dropbear reiniciado correctamente.${RESET}"

    else

        echo -e "${YELLOW}⚠ Dropbear no está activo.${RESET}"

    fi

}

#==================================================
# RESTAURAR BACKUP
#==================================================

restore_backup() {

    header

    echo -e "${MAGENTA}                 RESTAURAR BACKUP${RESET}"

    echo

    if [[ ! -f "$BACKUP_DIR/latest" ]]; then

        echo -e "${RED}✘ No existe ningún backup.${RESET}"

        pause

        return

    fi

    local BACKUP

    BACKUP=$(cat "$BACKUP_DIR/latest")

    echo -e "${GREEN}Último backup:${RESET}"
    echo "$BACKUP"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Restaurar este backup? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        #------------------------------------------
        # SSHD
        #------------------------------------------

        if [[ -f "$BACKUP/sshd_config" ]]; then

            cp -a \
                "$BACKUP/sshd_config" \
                "$SSHD"

        fi

        #------------------------------------------
        # Dropbear
        #------------------------------------------

        if [[ -f "$BACKUP/dropbear" ]]; then

            cp -a \
                "$BACKUP/dropbear" \
                "$DROPBEAR"

        fi

        #------------------------------------------
        # Banners
        #------------------------------------------

        if [[ -d "$BACKUP/ssh_banners" ]]; then

            rm -rf "$BANNER_DIR"

            mkdir -p "$BANNER_DIR"

            cp -a \
                "$BACKUP/ssh_banners"/. \
                "$BANNER_DIR/"

        fi

        echo

        echo -e "${GREEN}✔ Backup restaurado.${RESET}"

        #------------------------------------------
        # Validar SSH
        #------------------------------------------

        if ssh_installed &&
           sshd -t 2>/dev/null; then

            local SERVICE

            SERVICE=$(get_ssh_service)

            [[ -n "$SERVICE" ]] &&
                systemctl reload "$SERVICE"

        fi

        systemctl restart dropbear 2>/dev/null

        ;;

    *)

        echo -e "${YELLOW}Operación cancelada.${RESET}"

        ;;

    esac

    sleep 2

}

#==================================================
# SINCRONIZAR TODOS LOS USUARIOS EXISTENTES
#==================================================

sync_existing_users() {

    header

    echo -e "${MAGENTA}        CREAR BANNERS PARA USUARIOS SSH${RESET}"

    echo

    echo -e "${GRAY}Se buscarán usuarios Linux con shell relacionada a SSH.${RESET}"

    echo

    local COUNT=0

    while IFS=: read -r USERNAME _ UID GID HOME SHELL; do

        # UID normales
        if (( UID < 1000 )); then
            continue
        fi

        # Ignorar usuarios sin shell
        if [[ "$SHELL" == "/usr/sbin/nologin" ||
              "$SHELL" == "/bin/false" ||
              "$SHELL" == "/usr/bin/false" ]]; then

            # Aun así permitimos usuarios de túnel
            :
        fi

        local BANNER="$BANNER_DIR/${USERNAME}.banner"

        if [[ ! -f "$BANNER" ]]; then

            generate_user_banner \
                "$USERNAME" \
                "KevinTech VPN" \
                "🔥 Bienvenido a KevinTech VPN 🔥" \
                "@KevinTech" \
                "@KevinSupport" \
                > "$BANNER"

            chmod 644 "$BANNER"

            echo -e "${GREEN}✔ Creado:${RESET} $USERNAME"

            ((COUNT++))

        fi

    done < /etc/passwd

    echo

    echo -e "${GREEN}✔ $COUNT nuevos banners creados.${RESET}"

    echo

    sync_ssh_banners

    pause

}

#==================================================
# MENÚ
#==================================================

while true; do

    header

    show_status

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    echo -e "${GREEN}[1]${WHITE} Crear Banner para usuario"
    echo -e "${BLUE}[2]${WHITE} Ver Banner de usuario"
    echo -e "${YELLOW}[3]${WHITE} Editar Banner de usuario"
    echo -e "${CYAN}[4]${WHITE} Listar Banners"
    echo -e "${MAGENTA}[5]${WHITE} Sincronizar usuarios existentes"
    echo -e "${MAGENTA}[6]${WHITE} Actualizar Banners"
    echo -e "${CYAN}[7]${WHITE} Probar configuración"
    echo -e "${BLUE}[8]${WHITE} Sincronizar OpenSSH"
    echo -e "${YELLOW}[9]${WHITE} Restaurar último Backup"
    echo -e "${RED}[10]${WHITE} Eliminar Banner"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

    1)
        create_user_banner
        ;;

    2)
        view_banner
        ;;

    3)
        edit_banner
        ;;

    4)
        list_banners
        ;;

    5)
        sync_existing_users
        ;;

    6)
        refresh_all_banners
        ;;

    7)
        test_configuration
        ;;

    8)
        sync_ssh_banners
        pause
        ;;

    9)
        restore_backup
        ;;

    10)
        delete_banner
        ;;

    0)
        break
        ;;

    *)
        echo
        echo -e "${RED}✘ Opción inválida.${RESET}"
        sleep 2
        ;;

    esac

done