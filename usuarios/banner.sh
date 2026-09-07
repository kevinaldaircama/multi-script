#!/bin/bash

#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# + CheckUser Dinámico
# Version: 3.1 PREMIUM
#==================================================

#==============================
# COLORES
#==============================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==============================
# CONFIGURACIÓN
#==============================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

BANNER="/etc/issue.net"
SSHD="/etc/ssh/sshd_config"
SSHRC="/etc/ssh/sshrc"
DROPBEAR="/etc/default/dropbear"

BACKUP_DIR="$BASE/banner-backups"

CHECKUSER="/usr/local/bin/kevintech-checkuser"
CHECKUSER_STATE="$BASE/checkuser.state"

mkdir -p "$BASE" "$BACKUP_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==============================
# ROOT
#==============================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

#==================================================
# FUNCIONES VISUALES
#==================================================

pause() {

    echo

    read -n1 -s -r \
        -p "Presione cualquier tecla para continuar..."

    echo
}

header() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             ⚜ KEVINTECH BANNER MANAGER ⚜                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}              SSH • DROPBEAR • CHECKUSER                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

line() {

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

#==================================================
# DETECTAR OPENSSH
#==================================================

ssh_installed() {

    [[ -f "$SSHD" ]] &&
    command -v sshd >/dev/null 2>&1
}

#==================================================
# DETECTAR DROPBEAR
#==================================================

dropbear_installed() {

    [[ -f "$DROPBEAR" ]]
}

#==================================================
# SERVICIO SSH
#==================================================

ssh_service() {

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^ssh.service"; then

        echo "ssh"

    elif systemctl list-unit-files 2>/dev/null |
        grep -q "^sshd.service"; then

        echo "sshd"

    fi
}

#==================================================
# ESTADO OPENSSH
#==================================================

service_status() {

    if ! ssh_installed; then

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"
        return

    fi

    local SERVICE

    SERVICE=$(ssh_service)

    if [[ -n "$SERVICE" ]] &&
       systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

        echo -e "${GREEN}✔ ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

    fi
}

#==================================================
# ESTADO DROPBEAR
#==================================================

dropbear_status() {

    if ! dropbear_installed; then

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"
        return

    fi

    if systemctl is-active --quiet dropbear 2>/dev/null; then

        echo -e "${GREEN}✔ ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

    fi
}

#==================================================
# CHECKUSER - CREAR SCRIPT
#==================================================

install_checkuser_script() {

    cat > "$CHECKUSER" <<'EOF'
#!/bin/bash

#==================================================
# KevinTech Dynamic CheckUser
#==================================================

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

USER_NAME="${USER:-${LOGNAME:-}}"

[[ -z "$USER_NAME" ]] && exit 0

id "$USER_NAME" >/dev/null 2>&1 || exit 0

#==================================================
# OBTENER LÍMITE
#==================================================

LIMIT=$(awk -F: -v u="$USER_NAME" '
    $1 == u {
        print $2
        exit
}
' "$LIMITS_FILE" 2>/dev/null)

[[ -z "$LIMIT" ]] && LIMIT=0

#==================================================
# OBTENER IPs
#==================================================

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

#==================================================
# EXPIRACIÓN
#==================================================

EXPIRATION=$(
    chage -l "$USER_NAME" 2>/dev/null |
    awk -F': ' '/Account expires/ {
        print $2
        exit
    }'
)

[[ -z "$EXPIRATION" ]] &&
    EXPIRATION="Ilimitada"

DAYS="∞"

if [[ "$EXPIRATION" != "Ilimitada" &&
      "$EXPIRATION" != "never" &&
      "$EXPIRATION" != "Nunca" ]]; then

    EXP_DATE=$(date -d "$EXPIRATION" +%s 2>/dev/null)
    TODAY=$(date +%s)

    if [[ -n "$EXP_DATE" ]]; then

        DIFF=$(( (EXP_DATE - TODAY) / 86400 ))

        (( DIFF < 0 )) &&
            DIFF=0

        DAYS="$DIFF"

        EXPIRATION=$(date \
            -d "$EXPIRATION" \
            +"%d/%m/%Y" 2>/dev/null)

    else

        DAYS="N/D"

    fi

fi

#==================================================
# TEXTO DEL LÍMITE
#==================================================

if (( LIMIT == 0 )); then

    LIMIT_TEXT="∞"

else

    LIMIT_TEXT="$LIMIT"

fi

#==================================================
# MOSTRAR CHECKUSER
#==================================================

printf '\n'
printf '%s\n' '════════════════════════════════════════════════════════════'
printf '%s\n' '                         CHECK USER'
printf '%s\n' '════════════════════════════════════════════════════════════'
printf '\n'

printf '👤 Usuario        : %s\n' "$USER_NAME"
printf '🔌 Conexiones     : %s/%s\n' "$CONNECTIONS" "$LIMIT_TEXT"
printf '📅 Expiración     : %s\n' "$EXPIRATION"
printf '⏳ Días restantes : %s\n' "$DAYS"

printf '\n'
printf '%s\n' '════════════════════════════════════════════════════════════'
printf '\n'

exit 0
EOF

    chmod 755 "$CHECKUSER"

    echo "1" > "$CHECKUSER_STATE"

    echo -e "${GREEN}✔ CheckUser instalado.${RESET}"
}

#==================================================
# CHECKUSER - ACTIVAR EN SSH
#==================================================

enable_checkuser() {

    if ! ssh_installed; then

        echo -e "${RED}✘ OpenSSH no está instalado.${RESET}"

        return 1
    fi

    install_checkuser_script

    # Crear sshrc si no existe
    touch "$SSHRC"

    chmod 755 "$SSHRC"

    #==================================================
    # ELIMINAR BLOQUE ANTERIOR
    #==================================================

    sed -i \
        '/# BEGIN KEVINTECH CHECKUSER/,/# END KEVINTECH CHECKUSER/d' \
        "$SSHRC"

    #==================================================
    # AGREGAR BLOQUE
    #==================================================

    cat >> "$SSHRC" <<'EOF'

# BEGIN KEVINTECH CHECKUSER

if [[ -x /usr/local/bin/kevintech-checkuser ]]; then
    /usr/local/bin/kevintech-checkuser
fi

# END KEVINTECH CHECKUSER

EOF

    echo "1" > "$CHECKUSER_STATE"

    echo
    echo -e "${GREEN}✔ CheckUser activado.${RESET}"
    echo -e "${GRAY}Se mostrará automáticamente después del banner SSH.${RESET}"
}

#==================================================
# CHECKUSER - DESACTIVAR
#==================================================

disable_checkuser() {

    if [[ -f "$SSHRC" ]]; then

        sed -i \
            '/# BEGIN KEVINTECH CHECKUSER/,/# END KEVINTECH CHECKUSER/d' \
            "$SSHRC"

    fi

    echo "0" > "$CHECKUSER_STATE"

    echo
    echo -e "${YELLOW}⚠ CheckUser desactivado.${RESET}"
}

#==================================================
# ESTADO CHECKUSER
#==================================================

checkuser_status() {

    if [[ -x "$CHECKUSER" ]] &&
       [[ "$(cat "$CHECKUSER_STATE" 2>/dev/null)" == "1" ]] &&
       grep -q "BEGIN KEVINTECH CHECKUSER" "$SSHRC" 2>/dev/null; then

        echo -e "${GREEN}✔ ACTIVO${RESET}"

    elif [[ -x "$CHECKUSER" ]]; then

        echo -e "${YELLOW}⚠ INSTALADO / DESACTIVADO${RESET}"

    else

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

    fi
}

#==================================================
# ESTADO GENERAL
#==================================================

show_status() {

    echo -e "${CYAN}ESTADO DEL SISTEMA${RESET}"

    line

    if [[ -f "$BANNER" ]]; then

        echo -e "Banner    : ${GREEN}✔ ACTIVO${RESET}"
        echo -e "Archivo   : ${WHITE}$BANNER${RESET}"

    else

        echo -e "Banner    : ${RED}✘ NO EXISTE${RESET}"

    fi

    echo -n "OpenSSH   : "
    service_status

    echo -n "Dropbear  : "
    dropbear_status

    echo -n "CheckUser : "
    checkuser_status

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

    [[ -f "$BANNER" ]] &&
        cp -a "$BANNER" "$DIR/issue.net"

    [[ -f "$SSHD" ]] &&
        cp -a "$SSHD" "$DIR/sshd_config"

    [[ -f "$DROPBEAR" ]] &&
        cp -a "$DROPBEAR" "$DIR/dropbear"

    [[ -f "$SSHRC" ]] &&
        cp -a "$SSHRC" "$DIR/sshrc"

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo
    echo -e "${GREEN}✔ Backup creado:${RESET}"
    echo -e "${WHITE}$DIR${RESET}"
}

#==================================================
# CONFIGURAR OPENSSH
#==================================================

configure_ssh() {

    if ! ssh_installed; then
        return 0
    fi

    # Eliminar Banner anteriores
    sed -i \
        '/^[[:space:]]*Banner[[:space:]]/d' \
        "$SSHD"

    echo "Banner $BANNER" >> "$SSHD"

    #==================================================
    # VALIDAR SSH
    #==================================================

    if ! sshd -t 2>/dev/null; then

        echo -e "${RED}✘ Error en la configuración de OpenSSH.${RESET}"

        local BACKUP

        BACKUP=$(cat "$BACKUP_DIR/latest" 2>/dev/null)

        if [[ -f "$BACKUP/sshd_config" ]]; then

            cp -a "$BACKUP/sshd_config" "$SSHD"

        fi

        return 1
    fi

    echo -e "${GREEN}✔ Configuración OpenSSH válida.${RESET}"

    local SERVICE

    SERVICE=$(ssh_service)

    if [[ -n "$SERVICE" ]]; then

        systemctl restart "$SERVICE"

        if systemctl is-active --quiet "$SERVICE"; then

            echo -e "${GREEN}✔ OpenSSH reiniciado correctamente.${RESET}"

        else

            echo -e "${RED}✘ OpenSSH no está activo.${RESET}"

            return 1

        fi

    fi

    return 0
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configure_dropbear() {

    if ! dropbear_installed; then
        return 0
    fi

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" \
            "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"

    fi

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^dropbear.service"; then

        systemctl restart dropbear

        if systemctl is-active --quiet dropbear; then

            echo -e "${GREEN}✔ Dropbear reiniciado correctamente.${RESET}"

        else

            echo -e "${YELLOW}⚠ Dropbear no está activo.${RESET}"

        fi

    fi
}

#==================================================
# APLICAR BANNER + CHECKUSER
#==================================================

apply_banner() {

    echo
    echo -e "${CYAN}Aplicando configuración...${RESET}"
    echo

    configure_ssh

    configure_dropbear

    #==================================================
    # CHECKUSER
    #==================================================

    if [[ "$(cat "$CHECKUSER_STATE" 2>/dev/null)" == "1" ]]; then

        enable_checkuser

    fi

    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${WHITE}             ✔ CONFIGURACIÓN APLICADA                      ${GREEN}║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
}

#==================================================
# CREAR BANNER
#==================================================

create_banner() {

    header

    echo -e "${MAGENTA}              CREAR NUEVO BANNER${RESET}"

    echo

    echo -e "${GREEN}[1]${WHITE} Usar plantilla"
    echo -e "${BLUE}[2]${WHITE} Banner personalizado"
    echo -e "${RED}[0]${WHITE} Cancelar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione:${RESET} ")" TYPE

    case "$TYPE" in

    1)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                 SELECCIONAR PLANTILLA                    ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

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

        echo

        echo -e "${GREEN}[1]${WHITE} Clásica"
        echo -e "${BLUE}[2]${WHITE} Premium"
        echo -e "${YELLOW}[3]${WHITE} Minimalista"
        echo -e "${RED}[0]${WHITE} Cancelar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Plantilla:${RESET} ")" TEMPLATE

        case "$TEMPLATE" in

        1)

            create_backup

            cat > "$BANNER" <<EOF
╔════════════════════════════════════════════════════╗
║                 $SERVER                            ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║ $PROMO                                             ║
║                                                    ║
║ 📢 Canal   : $CHANNEL                              ║
║ 👤 Soporte : $SUPPORT                              ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║              Gracias por usar el servicio          ║
╚════════════════════════════════════════════════════╝
EOF
            ;;

        2)

            create_backup

            cat > "$BANNER" <<EOF
╔════════════════════════════════════════════════════╗
║                                                    ║
║                 ★ $SERVER ★                       ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║              $PROMO                               ║
║                                                    ║
║        Telegram : $CHANNEL                         ║
║        Soporte  : $SUPPORT                         ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║              ★ SERVICIO PREMIUM ★                  ║
╚════════════════════════════════════════════════════╝
EOF
            ;;

        3)

            create_backup

            cat > "$BANNER" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                 $SERVER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$PROMO

Canal   : $CHANNEL
Soporte : $SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
            ;;

        0)
            return
            ;;

        *)

            error "Plantilla inválida."
            sleep 2
            return
            ;;

        esac

        ;;

    2)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                  BANNER PERSONALIZADO                    ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

        echo

        create_backup

        touch "$BANNER"

        if ! command -v nano >/dev/null 2>&1; then

            echo -e "${RED}✘ Nano no está instalado.${RESET}"

            pause

            return
        fi

        nano "$BANNER"

        ;;

    0)

        return
        ;;

    *)

        echo -e "${RED}Opción inválida.${RESET}"

        sleep 2

        return
        ;;

    esac

    echo

    echo -e "${GREEN}✔ Banner preparado correctamente.${RESET}"

    echo

    echo -e "${CYAN}VISTA PREVIA${RESET}"

    line

    cat "$BANNER"

    line

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar este banner? [S/N]: ${RESET}")" APPLY

    case "$APPLY" in

    s|S|si|SI|sí|Sí)

        apply_banner
        ;;

    *)

        echo -e "${YELLOW}Banner guardado, pero no aplicado.${RESET}"
        ;;

    esac

    sleep 2
}

#==================================================
# VER BANNER
#==================================================

view_banner() {

    header

    echo -e "${MAGENTA}                 BANNER ACTUAL${RESET}"

    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${RED}✘ No existe ningún banner.${RESET}"

        pause

        return
    fi

    echo -e "${GREEN}Archivo:${RESET} $BANNER"

    echo

    line

    cat "$BANNER"

    line

    pause
}

#==================================================
# EDITAR BANNER
#==================================================

edit_banner() {

    header

    echo -e "${MAGENTA}                 EDITAR BANNER${RESET}"

    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${YELLOW}No existe un banner.${RESET}"

        touch "$BANNER"
    fi

    create_backup

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}✘ Nano no está instalado.${RESET}"

        pause

        return
    fi

    nano "$BANNER"

    echo

    echo -e "${GREEN}✔ Banner editado.${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar cambios? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        apply_banner
        ;;

    *)

        echo -e "${YELLOW}Cambios guardados pero no aplicados.${RESET}"
        ;;

    esac

    sleep 2
}

#==================================================
# CONFIGURAR CHECKUSER
#==================================================

checkuser_manager() {

    while true; do

        header

        echo -e "${MAGENTA}              ⚡ CHECKUSER MANAGER ⚡${RESET}"

        echo

        echo -n "Estado actual : "
        checkuser_status

        echo

        line

        echo

        echo -e "${GREEN}[1]${WHITE} Instalar / Activar CheckUser"
        echo -e "${RED}[2]${WHITE} Desactivar CheckUser"
        echo -e "${BLUE}[3]${WHITE} Ver CheckUser"
        echo -e "${YELLOW}[4]${WHITE} Reparar integración SSH"
        echo -e "${GRAY}[0]${WHITE} Regresar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

        case "$OP" in

        1)

            install_checkuser_script
            enable_checkuser

            echo

            echo -e "${GREEN}✔ Listo.${RESET}"

            pause
            ;;

        2)

            disable_checkuser

            pause
            ;;

        3)

            header

            echo -e "${MAGENTA}              CHECKUSER INSTALADO${RESET}"

            echo

            if [[ -x "$CHECKUSER" ]]; then

                "$CHECKUSER"

            else

                echo -e "${RED}✘ CheckUser no está instalado.${RESET}"

            fi

            pause
            ;;

        4)

            install_checkuser_script
            enable_checkuser

            echo

            echo -e "${GREEN}✔ Integración reparada.${RESET}"

            pause
            ;;

        0)

            return
            ;;

        *)

            echo -e "${RED}✘ Opción inválida.${RESET}"

            sleep 1
            ;;

        esac

    done
}

#==================================================
# PRUEBA DE CONFIGURACIÓN
#==================================================

test_banner() {

    header

    echo -e "${MAGENTA}              🔎 DIAGNÓSTICO DEL SISTEMA${RESET}"

    echo

    line

    echo

    if [[ -f "$BANNER" ]]; then

        echo -e "${GREEN}✔${RESET} /etc/issue.net existe"

    else

        echo -e "${RED}✘${RESET} /etc/issue.net no existe"

    fi

    if ssh_installed; then

        if sshd -t 2>/dev/null; then

            echo -e "${GREEN}✔${RESET} Configuración OpenSSH válida"

        else

            echo -e "${RED}✘${RESET} Configuración OpenSSH inválida"

        fi

        if grep -qE \
            "^[[:space:]]*Banner[[:space:]]+$BANNER" \
            "$SSHD"; then

            echo -e "${GREEN}✔${RESET} OpenSSH apunta a $BANNER"

        else

            echo -e "${YELLOW}⚠${RESET} OpenSSH no apunta al banner"

        fi

    else

        echo -e "${GRAY}⚠${RESET} OpenSSH no instalado"

    fi

    if [[ -x "$CHECKUSER" ]]; then

        echo -e "${GREEN}✔${RESET} CheckUser existe"

    else

        echo -e "${RED}✘${RESET} CheckUser no existe"

    fi

    if grep -q \
        "BEGIN KEVINTECH CHECKUSER" \
        "$SSHRC" 2>/dev/null; then

        echo -e "${GREEN}✔${RESET} CheckUser integrado en sshrc"

    else

        echo -e "${YELLOW}⚠${RESET} CheckUser no está integrado"

    fi

    echo

    line

    pause
}

#==================================================
# ELIMINAR BANNER
#==================================================

delete_banner() {

    header

    echo -e "${MAGENTA}                 ELIMINAR BANNER${RESET}"

    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${RED}✘ No existe ningún banner.${RESET}"

        pause

        return
    fi

    echo -e "${YELLOW}Se creará un backup antes de eliminarlo.${RESET}"

    echo

    read -rp \
        "$(echo -e "${RED}¿Eliminar el banner? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        create_backup

        rm -f "$BANNER"

        if ssh_installed; then

            sed -i \
                '/^[[:space:]]*Banner[[:space:]]/d' \
                "$SSHD"

            if sshd -t 2>/dev/null; then

                SERVICE=$(ssh_service)

                [[ -n "$SERVICE" ]] &&
                    systemctl restart "$SERVICE"

            fi

        fi

        if dropbear_installed; then

            sed -i \
                '/^DROPBEAR_BANNER=/d' \
                "$DROPBEAR"

            systemctl restart dropbear 2>/dev/null

        fi

        echo

        echo -e "${GREEN}✔ Banner eliminado correctamente.${RESET}"

        ;;

    *)

        echo -e "${YELLOW}Operación cancelada.${RESET}"

        ;;

    esac

    sleep 2
}

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    header

    show_status

    line

    echo

    echo -e "${GREEN}[1]${WHITE} 🎨 Crear nuevo Banner"
    echo -e "${BLUE}[2]${WHITE} 👁  Ver Banner actual"
    echo -e "${YELLOW}[3]${WHITE} ✏  Editar Banner"
    echo -e "${CYAN}[4]${WHITE} ⚡ CheckUser Manager"
    echo -e "${MAGENTA}[5]${WHITE} 🔎 Diagnóstico"
    echo -e "${RED}[6]${WHITE} 🗑  Eliminar Banner"
    echo -e "${GRAY}[0]${WHITE} ↩  Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

    1)
        create_banner
        ;;

    2)
        view_banner
        ;;

    3)
        edit_banner
        ;;

    4)
        checkuser_manager
        ;;

    5)
        test_banner
        ;;

    6)
        delete_banner
        ;;

    0)

        clear
        exit 0
        ;;

    *)

        echo
        echo -e "${RED}✘ Opción inválida.${RESET}"

        sleep 1
        ;;

    esac

done