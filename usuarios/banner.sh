#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear
# Banner Normal + CheckUser Dinámico
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
# CONFIGURAR BANNER SSH
#==================================================

configurar_ssh() {

    local ARCHIVO="$1"

    [[ ! -f "$SSHD" ]] && return

    # Eliminar Banner anteriores
    sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

    # Agregar banner
    echo "Banner $ARCHIVO" >> "$SSHD"
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear() {

    local ARCHIVO="$1"

    [[ ! -f "$DROPBEAR" ]] && return

    sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

    echo "DROPBEAR_BANNER=\"$ARCHIVO\"" >> "$DROPBEAR"
}

#==================================================
# REINICIAR SERVICIOS
#==================================================

reiniciar() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null
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
    # TEXTO PLANO
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

    # Activar normal
    configurar_ssh "$BANNER_NORMAL"
    configurar_dropbear "$BANNER_NORMAL"

    echo "normal" > "$BANNER_ACTIVE"

    reiniciar

    echo
    msg_ok "Banner normal creado y activado."

    sleep 2
}

#==================================================
# CREAR CHECKUSER DINÁMICO
#==================================================

crear_checkuser_script() {

    cat > "$CHECK_SCRIPT" <<'EOF'
#!/bin/bash

#==================================================
# KevinTech CheckUser
#==================================================

USER_NAME="${PAM_USER:-$USER}"

[[ -z "$USER_NAME" ]] && exit 0

id "$USER_NAME" >/dev/null 2>&1 || exit 0

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

#==================================================
# OBTENER LÍMITE
#==================================================

LIMIT="0"

if [[ -f "$LIMITS_FILE" ]]; then

    LIMIT=$(
        awk -F: -v U="$USER_NAME" '
            $1 == U {
                print $2
                exit
            }
        ' "$LIMITS_FILE"
    )

fi

[[ -z "$LIMIT" ]] && LIMIT="0"

if [[ "$LIMIT" == "0" ]]; then

    LIMIT_TEXT="Ilimitado"

elif [[ "$LIMIT" == "1" ]]; then

    LIMIT_TEXT="1 IP"

else

    LIMIT_TEXT="${LIMIT} IPs"

fi

#==================================================
# OBTENER EXPIRACIÓN
#==================================================

EXPIRATION=$(
    chage -l "$USER_NAME" 2>/dev/null |
    awk -F: '/Account expires/ {
        gsub(/^[ \t]+/, "", $2);
        print $2
    }'
)

#==================================================
# DÍAS RESTANTES
#==================================================

if [[ -z "$EXPIRATION" ||
      "$EXPIRATION" == "never" ||
      "$EXPIRATION" == "Nunca" ]]; then

    DAYS="∞"
    EXPIRATION_TEXT="Ilimitada"

else

    EXP_SECONDS=$(date -d "$EXPIRATION" +%s 2>/dev/null)
    NOW_SECONDS=$(date +%s)

    if [[ -n "$EXP_SECONDS" ]]; then

        DAYS=$(( (EXP_SECONDS - NOW_SECONDS) / 86400 ))

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
# CHECKUSER
#==================================================

echo

echo -e "\033[1;96m╔════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;96m║\033[1;95m              ⚜ KEVINTECH CHECKUSER ⚜              \033[1;96m║\033[0m"
echo -e "\033[1;96m╠════════════════════════════════════════════════════╣\033[0m"

printf "\033[1;96m║\033[1;97m Usuario      : \033[1;92m%-36s\033[1;96m║\033[0m\n" "$USER_NAME"
printf "\033[1;96m║\033[1;97m Días         : \033[1;92m%-36s\033[1;96m║\033[0m\n" "$DAYS"
printf "\033[1;96m║\033[1;97m Límite       : \033[1;92m%-36s\033[1;96m║\033[0m\n" "$LIMIT_TEXT"
printf "\033[1;96m║\033[1;97m Expiración   : \033[1;92m%-36s\033[1;96m║\033[0m\n" "$EXPIRATION_TEXT"

echo -e "\033[1;96m╚════════════════════════════════════════════════════╝\033[0m"

echo

exit 0
EOF

    chmod 755 "$CHECK_SCRIPT"
}

#==================================================
# INSTALAR CHECKUSER
#==================================================

activar_checkuser() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             ACTIVAR BANNER CHECKUSER             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "Primero crea el Banner normal."

        sleep 2
        return

    fi

    # Crear CheckUser
    crear_checkuser_script

    #==================================================
    # CREAR ARCHIVO CHECKUSER
    #==================================================

    cat > "$BANNER_CHECK" <<EOF
# KevinTech CheckUser
# Generado automáticamente
EOF

    #==================================================
    # CONFIGURAR BANNER NORMAL
    #==================================================

    configurar_ssh "$BANNER_NORMAL"
    configurar_dropbear "$BANNER_NORMAL"

    #==================================================
    # PAM SSH
    #==================================================

    PAM="/etc/pam.d/sshd"

    if [[ -f "$PAM" ]]; then

        # Evitar duplicados
        sed -i '/KevinTech CheckUser/d' "$PAM"
        sed -i '/checkuser-banner.sh/d' "$PAM"

        cat >> "$PAM" <<EOF

# KevinTech CheckUser
session optional pam_exec.so stdout $CHECK_SCRIPT
EOF

    fi

    echo "checkuser" > "$BANNER_ACTIVE"

    reiniciar

    echo

    msg_ok "Banner CheckUser activado."

    echo
    echo -e "${WHITE}El banner normal continuará apareciendo primero.${RESET}"
    echo -e "${WHITE}Después del login aparecerá el CheckUser.${RESET}"

    echo

    read -n1 -s -r -p "Presione cualquier tecla para continuar..."
}

#==================================================
# VER BANNER
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

    case "$ACTIVO" in

        normal)
            echo -e "${GREEN}✔ Banner normal activo${RESET}"
            ;;

        checkuser)
            echo -e "${GREEN}✔ Banner CheckUser activo${RESET}"
            ;;

        *)
            echo -e "${YELLOW}⚠ Sin banner activo${RESET}"
            ;;

    esac

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
        echo -e "${YELLOW}══════════ CHECKUSER DINÁMICO ══════════${RESET}"
        echo
        echo -e "${WHITE}Usuario      : ${GREEN}usuario conectado${RESET}"
        echo -e "${WHITE}Días         : ${GREEN}calculado automáticamente${RESET}"
        echo -e "${WHITE}Límite       : ${GREEN}desde limits.conf${RESET}"
        echo -e "${WHITE}Expiración   : ${GREEN}desde la cuenta SSH${RESET}"

    fi

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -n1 -s -r -p "Presione cualquier tecla para regresar..."
}

#==================================================
# EDITAR BANNER NORMAL
#==================================================

editar_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              EDITAR BANNER NORMAL                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "No existe Banner normal."

        sleep 2
        return

    fi

    if ! command -v nano >/dev/null 2>&1; then

        msg_error "Nano no está instalado."

        sleep 2
        return

    fi

    nano "$BANNER_NORMAL"

    configurar_ssh "$BANNER_NORMAL"
    configurar_dropbear "$BANNER_NORMAL"

    reiniciar

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

            reiniciar

            msg_ok "Banner normal eliminado."

            ;;

        2)

            rm -f "$BANNER_CHECK"
            rm -f "$CHECK_SCRIPT"

            PAM="/etc/pam.d/sshd"

            if [[ -f "$PAM" ]]; then

                sed -i '/KevinTech CheckUser/d' "$PAM"
                sed -i '/checkuser-banner.sh/d' "$PAM"

            fi

            # Si existe banner normal,
            # volver a dejarlo activo.

            if [[ -f "$BANNER_NORMAL" ]]; then

                configurar_ssh "$BANNER_NORMAL"
                configurar_dropbear "$BANNER_NORMAL"

                echo "normal" > "$BANNER_ACTIVE"

            else

                sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD" 2>/dev/null

                [[ -f "$DROPBEAR" ]] &&
                    sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

                echo "none" > "$BANNER_ACTIVE"

            fi

            reiniciar

            msg_ok "Banner CheckUser eliminado."

            ;;

        3)

            rm -f "$BANNER_NORMAL"
            rm -f "$BANNER_CHECK"
            rm -f "$CHECK_SCRIPT"

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD" 2>/dev/null

            [[ -f "$DROPBEAR" ]] &&
                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

            PAM="/etc/pam.d/sshd"

            if [[ -f "$PAM" ]]; then

                sed -i '/KevinTech CheckUser/d' "$PAM"
                sed -i '/checkuser-banner.sh/d' "$PAM"

            fi

            echo "none" > "$BANNER_ACTIVE"

            reiniciar

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
# MENÚ
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
            editar_banner
            ;;

        5)
            eliminar_banner
            ;;

        0)
            break
            ;;

        *)
            msg_error "Opción inválida."
            sleep 2
            ;;

    esac

done