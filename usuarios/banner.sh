#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear + CheckUser
# Independiente de checkgestor
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
# CONFIG KEVINTECH
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

mkdir -p "$BASE"

#==================================================
# ARCHIVOS
#==================================================

BANNER_NORMAL="$BASE/banner-normal"
BANNER_CHECK="$BASE/banner-checkuser"

BANNER_ACTIVE="$BASE/banner-active"

LIMITS_FILE="$BASE/limits.conf"

CHECK_SCRIPT="$BASE/checkuser-banner.sh"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

#==================================================
# CREAR ARCHIVOS NECESARIOS
#==================================================

touch "$LIMITS_FILE"

chmod 600 "$LIMITS_FILE"

#==================================================
# MENSAJES
#==================================================

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

#==================================================
# CONFIGURAR BANNER OPENSSH
#==================================================

configurar_ssh_banner() {

    local ARCHIVO="$1"

    [[ ! -f "$SSHD" ]] && return 0

    # Eliminar Banner anterior
    sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

    # Agregar nuevo
    echo "Banner $ARCHIVO" >> "$SSHD"
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear_banner() {

    local ARCHIVO="$1"

    [[ ! -f "$DROPBEAR" ]] && return 0

    sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

    echo "DROPBEAR_BANNER=\"$ARCHIVO\"" >> "$DROPBEAR"
}

#==================================================
# REINICIAR SERVICIOS
#==================================================

reiniciar_servicios() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null
}

#==================================================
# OBTENER LÍMITE
#==================================================

obtener_limite() {

    local USERNAME="$1"
    local LIMITE="0"

    if [[ -f "$LIMITS_FILE" ]]; then

        LIMITE=$(
            awk -F: -v U="$USERNAME" '
                $1 == U {
                    print $2
                    exit
                }
            ' "$LIMITS_FILE"
        )

    fi

    [[ -z "$LIMITE" ]] && LIMITE="0"

    echo "$LIMITE"
}

#==================================================
# FORMATEAR LÍMITE
#==================================================

formatear_limite() {

    local LIMITE="$1"

    if [[ "$LIMITE" == "0" ]]; then

        echo "Ilimitado"

    elif [[ "$LIMITE" == "1" ]]; then

        echo "1 IP"

    else

        echo "$LIMITE IPs"

    fi
}

#==================================================
# OBTENER EXPIRACIÓN
#==================================================

obtener_expiracion() {

    local USERNAME="$1"
    local FECHA

    FECHA=$(
        chage -l "$USERNAME" 2>/dev/null |
        awk -F: '/Account expires/ {
            gsub(/^[ \t]+/, "", $2);
            print $2
        }'
    )

    if [[ -z "$FECHA" ||
          "$FECHA" == "never" ||
          "$FECHA" == "Nunca" ]]; then

        echo "Ilimitada"
        return

    fi

    local FECHA_FORMATO

    FECHA_FORMATO=$(date -d "$FECHA" +"%d/%m/%Y" 2>/dev/null)

    if [[ -n "$FECHA_FORMATO" ]]; then
        echo "$FECHA_FORMATO"
    else
        echo "$FECHA"
    fi
}

#==================================================
# OBTENER DÍAS RESTANTES
#==================================================

obtener_dias() {

    local USERNAME="$1"

    local FECHA
    local FECHA_EXP
    local HOY
    local DIAS

    FECHA=$(
        chage -l "$USERNAME" 2>/dev/null |
        awk -F: '/Account expires/ {
            gsub(/^[ \t]+/, "", $2);
            print $2
        }'
    )

    if [[ -z "$FECHA" ||
          "$FECHA" == "never" ||
          "$FECHA" == "Nunca" ]]; then

        echo "∞"
        return

    fi

    FECHA_EXP=$(date -d "$FECHA" +%s 2>/dev/null)

    if [[ -z "$FECHA_EXP" ]]; then
        echo "N/D"
        return
    fi

    HOY=$(date +%s)

    DIAS=$(( (FECHA_EXP - HOY) / 86400 ))

    (( DIAS < 0 )) && DIAS=0

    echo "$DIAS"
}

#==================================================
# CREAR CHECKUSER DINÁMICO
#==================================================

crear_checkuser() {

    cat > "$CHECK_SCRIPT" <<'EOF'
#!/bin/bash

#==================================================
# KevinTech CheckUser
# Independiente de checkgestor
#==================================================

USERNAME="${PAM_USER:-$USER}"

# Si no existe usuario, salir
id "$USERNAME" >/dev/null 2>&1 || exit 0

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

#==================================================
# OBTENER LÍMITE
#==================================================

LIMIT="0"

if [[ -f "$LIMITS_FILE" ]]; then

    LIMIT=$(
        awk -F: -v U="$USERNAME" '
            $1 == U {
                print $2
                exit
            }
        ' "$LIMITS_FILE"
    )

fi

[[ -z "$LIMIT" ]] && LIMIT="0"

#==================================================
# FORMATO LÍMITE
#==================================================

if [[ "$LIMIT" == "0" ]]; then

    LIMIT_TEXT="Ilimitado"

elif [[ "$LIMIT" == "1" ]]; then

    LIMIT_TEXT="1 IP"

else

    LIMIT_TEXT="${LIMIT} IPs"

fi

#==================================================
# EXPIRACIÓN
#==================================================

EXPIRATION=$(
    chage -l "$USERNAME" 2>/dev/null |
    awk -F: '/Account expires/ {
        gsub(/^[ \t]+/, "", $2);
        print $2
    }'
)

#==================================================
# DÍAS
#==================================================

if [[ -z "$EXPIRATION" ||
      "$EXPIRATION" == "never" ||
      "$EXPIRATION" == "Nunca" ]]; then

    DAYS="∞"
    EXPIRATION_TEXT="Ilimitada"

else

    EXPIRATION_SECONDS=$(date -d "$EXPIRATION" +%s 2>/dev/null)
    TODAY_SECONDS=$(date +%s)

    if [[ -n "$EXPIRATION_SECONDS" ]]; then

        DAYS=$(( (EXPIRATION_SECONDS - TODAY_SECONDS) / 86400 ))

        (( DAYS < 0 )) && DAYS=0

    else

        DAYS="N/D"

    fi

    EXPIRATION_TEXT=$(
        date -d "$EXPIRATION" +"%d/%m/%Y" 2>/dev/null
    )

    [[ -z "$EXPIRATION_TEXT" ]] &&
        EXPIRATION_TEXT="$EXPIRATION"

fi

#==================================================
# BANNER CHECKUSER
#==================================================

echo
echo -e "\033[1;96m╔════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;96m║\033[1;95m              ⚜ KEVINTECH CHECKUSER ⚜              \033[1;96m║\033[0m"
echo -e "\033[1;96m╠════════════════════════════════════════════════════╣\033[0m"
echo -e "\033[1;96m║\033[1;97m Usuario      : \033[1;92m${USERNAME}\033[1;96m                       ║\033[0m"
echo -e "\033[1;96m║\033[1;97m Días         : \033[1;92m${DAYS}\033[1;96m                           ║\033[0m"
echo -e "\033[1;96m║\033[1;97m Límite       : \033[1;92m${LIMIT_TEXT}\033[1;96m                     ║\033[0m"
echo -e "\033[1;96m║\033[1;97m Expiración   : \033[1;92m${EXPIRATION_TEXT}\033[1;96m                    ║\033[0m"
echo -e "\033[1;96m╚════════════════════════════════════════════════════╝\033[0m"
echo

exit 0
EOF

    chmod 755 "$CHECK_SCRIPT"
}

#==================================================
# INSTALAR PAM CHECKUSER
#==================================================

instalar_pam_checkuser() {

    local PAM_FILE="/etc/pam.d/sshd"

    [[ ! -f "$PAM_FILE" ]] && return 1

    # Quitar instalación anterior
    sed -i '/KevinTech CheckUser/d' "$PAM_FILE"
    sed -i '/kevintech\/checkuser-banner.sh/d' "$PAM_FILE"

    # Agregar solamente una vez
    cat >> "$PAM_FILE" <<EOF

# KevinTech CheckUser
session optional pam_exec.so stdout $CHECK_SCRIPT
EOF

    return 0
}

#==================================================
# DESINSTALAR PAM CHECKUSER
#==================================================

desinstalar_pam_checkuser() {

    local PAM_FILE="/etc/pam.d/sshd"

    [[ ! -f "$PAM_FILE" ]] && return 0

    sed -i '/KevinTech CheckUser/d' "$PAM_FILE"
    sed -i '/kevintech\/checkuser-banner.sh/d' "$PAM_FILE"
}

#==================================================
# CREAR BANNER NORMAL
#==================================================

crear_banner_normal() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             CREAR BANNER NORMAL                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    read -rp "$(echo -e "${GREEN}Nombre del Servidor:${RESET} ")" SERVER

    [[ -z "$SERVER" ]] &&
        SERVER="${SERVER_NAME:-KevinTech VPN}"

    read -rp "$(echo -e "${GREEN}Texto Promocional:${RESET} ")" PROMO

    [[ -z "$PROMO" ]] &&
        PROMO="🔥 Bienvenido a $SERVER 🔥"

    read -rp "$(echo -e "${GREEN}Canal Telegram:${RESET} ")" CHANNEL

    read -rp "$(echo -e "${GREEN}Soporte:${RESET} ")" SUPPORT

    #==================================================
    # BANNER DE TEXTO
    #==================================================

    cat > "$BANNER_NORMAL" <<EOF
${SERVER}
══════════════════════

${PROMO}

📢 Canal: ${CHANNEL}
👤 Soporte: ${SUPPORT}

══════════════════════
Gracias por usar nuestros servicios
EOF

    chmod 644 "$BANNER_NORMAL"

    # Activar banner normal
    configurar_ssh_banner "$BANNER_NORMAL"
    configurar_dropbear_banner "$BANNER_NORMAL"

    # Desactivar CheckUser
    desinstalar_pam_checkuser

    echo "normal" > "$BANNER_ACTIVE"

    reiniciar_servicios

    echo

    msg_ok "Banner normal creado y activado."

    sleep 2
}

#==================================================
# ACTIVAR CHECKUSER
#==================================================

activar_checkuser() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             ACTIVAR BANNER CHECKUSER             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "Primero debes crear el Banner normal."

        echo
        read -n1 -s -r -p "Presione cualquier tecla..."
        return

    fi

    #==================================================
    # CREAR CHECKUSER
    #==================================================

    crear_checkuser

    #==================================================
    # BANNER NORMAL
    #==================================================

    configurar_ssh_banner "$BANNER_NORMAL"
    configurar_dropbear_banner "$BANNER_NORMAL"

    #==================================================
    # ACTIVAR CHECKUSER DESPUÉS DEL LOGIN
    #==================================================

    if instalar_pam_checkuser; then

        echo "checkuser" > "$BANNER_ACTIVE"

        reiniciar_servicios

        echo

        msg_ok "Banner CheckUser activado."

        echo
        echo -e "${WHITE}El usuario verá:${RESET}"
        echo
        echo -e "${GRAY}Banner normal${RESET}"
        echo -e "${GRAY}        ↓${RESET}"
        echo -e "${GRAY}CheckUser dinámico${RESET}"

    else

        msg_error "No se pudo configurar PAM."

    fi

    echo

    read -n1 -s -r -p "Presione cualquier tecla para continuar..."
}

#==================================================
# VER BANNER ACTUAL
#==================================================

ver_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 BANNER ACTUAL                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    ACTIVO="ninguno"

    [[ -f "$BANNER_ACTIVE" ]] &&
        ACTIVO=$(cat "$BANNER_ACTIVE")

    if [[ "$ACTIVO" == "normal" ]]; then

        echo -e "${GREEN}✔ Banner normal ACTIVO${RESET}"

    elif [[ "$ACTIVO" == "checkuser" ]]; then

        echo -e "${GREEN}✔ Banner CheckUser ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ Sin banner activo${RESET}"

    fi

    echo

    if [[ -f "$BANNER_NORMAL" ]]; then

        echo -e "${YELLOW}══════════ BANNER NORMAL ══════════${RESET}"
        echo

        cat "$BANNER_NORMAL"

    else

        msg_warn "No existe Banner normal."

    fi

    if [[ "$ACTIVO" == "checkuser" ]]; then

        echo
        echo -e "${YELLOW}══════════ CHECKUSER ══════════${RESET}"
        echo
        echo -e "${WHITE}Usuario      : ${GREEN}<usuario conectado>${RESET}"
        echo -e "${WHITE}Días         : ${GREEN}<dinámico>${RESET}"
        echo -e "${WHITE}Límite       : ${GREEN}<desde limits.conf>${RESET}"
        echo -e "${WHITE}Expiración   : ${GREEN}<desde cuenta SSH>${RESET}"
    fi

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -n1 -s -r -p "Presione cualquier tecla para regresar..."
}

#==================================================
# EDITAR BANNER NORMAL
#==================================================

editar_banner_normal() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              EDITAR BANNER NORMAL                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "No existe el Banner normal."

        sleep 2
        return

    fi

    if ! command -v nano >/dev/null 2>&1; then

        msg_error "Nano no está instalado."

        sleep 2
        return

    fi

    nano "$BANNER_NORMAL"

    configurar_ssh_banner "$BANNER_NORMAL"
    configurar_dropbear_banner "$BANNER_NORMAL"

    reiniciar_servicios

    echo

    msg_ok "Banner normal actualizado."

    sleep 2
}

#==================================================
# ELIMINAR BANNER
#==================================================

eliminar_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 ELIMINAR BANNER                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}[1]${RESET} Eliminar Banner normal"
    echo -e "${WHITE}[2]${RESET} Eliminar Banner CheckUser"
    echo -e "${WHITE}[3]${RESET} Eliminar ambos"
    echo -e "${WHITE}[0]${RESET} Cancelar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)

            rm -f "$BANNER_NORMAL"

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD" 2>/dev/null

            [[ -f "$DROPBEAR" ]] &&
                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

            echo "none" > "$BANNER_ACTIVE"

            reiniciar_servicios

            msg_ok "Banner normal eliminado."

            ;;

        2)

            rm -f "$BANNER_CHECK"
            rm -f "$CHECK_SCRIPT"

            desinstalar_pam_checkuser

            # Si existe el banner normal,
            # volver a dejarlo activo.

            if [[ -f "$BANNER_NORMAL" ]]; then

                configurar_ssh_banner "$BANNER_NORMAL"
                configurar_dropbear_banner "$BANNER_NORMAL"

                echo "normal" > "$BANNER_ACTIVE"

            else

                sed -i '/^[[:space:]]*Banner[[:space:]]/d' \
                    "$SSHD" 2>/dev/null

                [[ -f "$DROPBEAR" ]] &&
                    sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

                echo "none" > "$BANNER_ACTIVE"

            fi

            reiniciar_servicios

            msg_ok "Banner CheckUser eliminado."

            ;;

        3)

            rm -f "$BANNER_NORMAL"
            rm -f "$BANNER_CHECK"
            rm -f "$CHECK_SCRIPT"

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' \
                "$SSHD" 2>/dev/null

            [[ -f "$DROPBEAR" ]] &&
                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

            desinstalar_pam_checkuser

            echo "none" > "$BANNER_ACTIVE"

            reiniciar_servicios

            msg_ok "Banner normal y CheckUser eliminados."

            ;;

        0)
            return
            ;;

        *)
            msg_error "Opción inválida."
            ;;

    esac

    sleep 2
}

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢            ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

    echo -e "${GREEN}[1]${WHITE} Crear Banner normal"
    echo -e "${BLUE}[2]${WHITE} Activar Banner CheckUser"
    echo -e "${CYAN}[3]${WHITE} Ver Banner actual"
    echo -e "${YELLOW}[4]${WHITE} Editar Banner normal"
    echo -e "${RED}[5]${WHITE} Eliminar banner (normal o CheckUser)"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)
            crear_banner_normal
            ;;

        2)
            activar_checkuser
            ;;

        3)
            ver_banner
            ;;

        4)
            editar_banner_normal
            ;;

        5)
            eliminar_banner
            ;;

        0)
            break
            ;;

        *)
            echo
            msg_error "Opción inválida."
            sleep 2
            ;;

    esac

done