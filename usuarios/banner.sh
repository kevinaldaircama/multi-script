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

#==================================================
# ARCHIVOS
#==================================================

BANNER_NORMAL="/etc/issue.net"
BANNER_CHECK="/etc/kevintech/banner-checkuser"
BANNER_ACTIVE="/etc/kevintech/banner-active"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"
LIMITS_FILE="/etc/kevintech/limits.conf"

mkdir -p "$BASE"

touch "$LIMITS_FILE"

#==================================================
# FUNCIONES
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
# CONFIGURAR OPENSSH
#==================================================

configurar_ssh_banner() {

    local ARCHIVO="$1"

    [[ ! -f "$SSHD" ]] && return 1

    if grep -qE "^[[:space:]]*Banner[[:space:]]" "$SSHD"; then

        sed -i "s|^[[:space:]]*Banner[[:space:]].*|Banner $ARCHIVO|" "$SSHD"

    else

        echo "Banner $ARCHIVO" >> "$SSHD"

    fi

    return 0
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear_banner() {

    local ARCHIVO="$1"

    [[ ! -f "$DROPBEAR" ]] && return 0

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$ARCHIVO\"|" "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$ARCHIVO\"" >> "$DROPBEAR"

    fi
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
# OBTENER LÍMITE DEL USUARIO
#==================================================

obtener_limite() {

    local USERNAME="$1"

    local LIMITE

    if [[ -f "$LIMITS_FILE" ]]; then

        LIMITE=$(
            awk -F: -v user="$USERNAME" '
                $1 == user {
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
# OBTENER FECHA DE EXPIRACIÓN
#==================================================

obtener_expiracion() {

    local USERNAME="$1"

    local FECHA

    FECHA=$(chage -l "$USERNAME" 2>/dev/null |
        awk -F: '/Account expires/ {
            gsub(/^[ \t]+/, "", $2);
            print $2
        }')

    if [[ -z "$FECHA" ]]; then
        echo "Ilimitada"
        return
    fi

    if [[ "$FECHA" == "never" ||
          "$FECHA" == "Nunca" ||
          "$FECHA" == "never" ]]; then

        echo "Ilimitada"
        return
    fi

    # Intentar convertir la fecha
    local FECHA_NUM

    FECHA_NUM=$(date -d "$FECHA" +"%d/%m/%Y" 2>/dev/null)

    if [[ -n "$FECHA_NUM" ]]; then
        echo "$FECHA_NUM"
    else
        echo "$FECHA"
    fi
}

#==================================================
# OBTENER DÍAS RESTANTES
#==================================================

obtener_dias() {

    local USERNAME="$1"

    local EXPIRA
    local HOY
    local RESTANTES

    EXPIRA=$(chage -l "$USERNAME" 2>/dev/null |
        awk -F: '/Account expires/ {
            gsub(/^[ \t]+/, "", $2);
            print $2
        }')

    if [[ -z "$EXPIRA" ||
          "$EXPIRA" == "never" ||
          "$EXPIRA" == "Nunca" ]]; then

        echo "∞"
        return
    fi

    local FECHA_EXP

    FECHA_EXP=$(date -d "$EXPIRA" +%s 2>/dev/null)

    if [[ -z "$FECHA_EXP" ]]; then
        echo "N/D"
        return
    fi

    HOY=$(date +%s)

    RESTANTES=$(
        echo $(( (FECHA_EXP - HOY) / 86400 ))
    )

    (( RESTANTES < 0 )) && RESTANTES=0

    echo "$RESTANTES"
}

#==================================================
# FORMATO DEL LÍMITE
#==================================================

formatear_limite() {

    local LIMITE="$1"

    if [[ "$LIMITE" == "0" ]]; then

        echo "Ilimitado"

    elif [[ "$LIMITE" == "1" ]]; then

        echo "1 IP"

    else

        echo "${LIMITE} IPs"

    fi
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

    cat > "$BANNER_NORMAL" <<EOF
<html>

<center>

<font color="#00ff00"><b>$SERVER</b></font><br>

<font color="#29b6f6">
══════════════════════
</font>

<br><br>

<font color="#ffffff">
$PROMO
</font>

<br><br>

<font color="#ffff00">
📢 Canal: $CHANNEL
</font>

<br>

<font color="#00ffff">
👤 Soporte: $SUPPORT
</font>

<br><br>

<font color="#29b6f6">
══════════════════════
</font>

<br>

<font color="#00ff00">
Gracias por usar nuestros servicios
</font>

</center>

</html>
EOF

    configurar_ssh_banner "$BANNER_NORMAL"
    configurar_dropbear_banner "$BANNER_NORMAL"

    # Activar normal
    echo "normal" > "$BANNER_ACTIVE"

    reiniciar_servicios

    echo

    msg_ok "Banner normal creado y activado."

    sleep 2
}

#==================================================
# CREAR BANNER CHECKUSER
#==================================================

crear_banner_checkuser() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}            ACTIVAR BANNER CHECKUSER              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "Primero debes crear un Banner normal."

        echo
        read -n1 -s -r -p "Presione cualquier tecla..."
        return

    fi

    #==================================================
    # CREAR PLANTILLA CHECKUSER
    #==================================================

    cat > "$BANNER_CHECK" <<'EOF'
#==================================================
# KevinTech CheckUser
# Este archivo es generado automáticamente
#==================================================

EOF

    #==================================================
    # ACTIVAR CHECKUSER
    #==================================================

    echo "checkuser" > "$BANNER_ACTIVE"

    #==================================================
    # CREAR ARCHIVO DE INFORMACIÓN DINÁMICA
    #==================================================

    CHECK_SCRIPT="/etc/kevintech/checkuser-banner.sh"

    cat > "$CHECK_SCRIPT" <<'CHECKEOF'
#!/bin/bash

#==================================================
# KevinTech CheckUser
# Banner dinámico por usuario
#==================================================

USER_NAME="${PAM_USER:-$USER}"

[[ -z "$USER_NAME" ]] && exit 0

# Verificar usuario
id "$USER_NAME" >/dev/null 2>&1 || exit 0

LIMITS_FILE="/etc/kevintech/limits.conf"
NORMAL="/etc/issue.net"

#==================================================
# LÍMITE
#==================================================

LIMIT="0"

if [[ -f "$LIMITS_FILE" ]]; then

    LIMIT=$(
        awk -F: -v user="$USER_NAME" '
            $1 == user {
                print $2
                exit
            }
        ' "$LIMITS_FILE"
    )

fi

[[ -z "$LIMIT" ]] && LIMIT="0"

if (( LIMIT == 0 )); then
    LIMIT_TEXT="Ilimitado"
elif (( LIMIT == 1 )); then
    LIMIT_TEXT="1 IP"
else
    LIMIT_TEXT="${LIMIT} IPs"
fi

#==================================================
# EXPIRACIÓN
#==================================================

EXPIRA=$(
    chage -l "$USER_NAME" 2>/dev/null |
    awk -F: '/Account expires/ {
        gsub(/^[ \t]+/, "", $2);
        print $2
    }'
)

if [[ -z "$EXPIRA" ||
      "$EXPIRA" == "never" ||
      "$EXPIRA" == "Nunca" ]]; then

    EXPIRA_TEXT="Ilimitada"
    DIAS="∞"

else

    EXPIRA_NUM=$(date -d "$EXPIRA" +%s 2>/dev/null)
    HOY=$(date +%s)

    if [[ -n "$EXPIRA_NUM" ]]; then

        DIAS=$(( (EXPIRA_NUM - HOY) / 86400 ))

        (( DIAS < 0 )) && DIAS=0

    else

        DIAS="N/D"

    fi

    EXPIRA_TEXT=$(date -d "$EXPIRA" +"%d/%m/%Y" 2>/dev/null)

    [[ -z "$EXPIRA_TEXT" ]] &&
        EXPIRA_TEXT="$EXPIRA"

fi

#==================================================
# MOSTRAR CHECKUSER
#==================================================

echo
echo -e "\033[1;96m╔════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;96m║\033[1;95m              ⚜ KEVINTECH CHECKUSER ⚜              \033[1;96m║\033[0m"
echo -e "\033[1;96m╠════════════════════════════════════════════════════╣\033[0m"

echo -e "\033[1;97m║ Usuario      : \033[1;92m${USER_NAME}\033[1;96m                       ║\033[0m"
echo -e "\033[1;97m║ Días         : \033[1;92m${DIAS}\033[1;96m                           ║\033[0m"
echo -e "\033[1;97m║ Límite       : \033[1;92m${LIMIT_TEXT}\033[1;96m                     ║\033[0m"
echo -e "\033[1;97m║ Expiración   : \033[1;92m${EXPIRA_TEXT}\033[1;96m                    ║\033[0m"

echo -e "\033[1;96m╚════════════════════════════════════════════════════╝\033[0m"
echo

exit 0
CHECKEOF

    chmod 755 "$CHECK_SCRIPT"

    #==================================================
    # PAM
    #==================================================
    #
    # Se agrega solamente una vez.
    #
    # IMPORTANTE:
    # Esto muestra CheckUser después de autenticarse.
    #==================================================

    PAM_FILE="/etc/pam.d/sshd"

    if [[ -f "$PAM_FILE" ]]; then

        if ! grep -q "kevintech-checkuser-banner.sh" "$PAM_FILE"; then

            echo "" >> "$PAM_FILE"
            echo "# KevinTech CheckUser Banner" >> "$PAM_FILE"
            echo "session optional pam_exec.so stdout /etc/kevintech/checkuser-banner.sh" >> "$PAM_FILE"

        fi

    fi

    reiniciar_servicios

    echo

    msg_ok "Banner CheckUser activado."
    msg_info "El CheckUser se genera automáticamente por usuario."

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

    ACTIVO="normal"

    [[ -f "$BANNER_ACTIVE" ]] &&
        ACTIVO=$(cat "$BANNER_ACTIVE")

    echo -e "${WHITE}Estado:${RESET}"

    if [[ "$ACTIVO" == "checkuser" ]]; then

        echo -e "${GREEN}✔ Banner CheckUser ACTIVO${RESET}"

    elif [[ "$ACTIVO" == "normal" ]]; then

        echo -e "${GREEN}✔ Banner normal ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ Sin banner seleccionado${RESET}"

    fi

    echo

    if [[ "$ACTIVO" == "normal" ]]; then

        if [[ -f "$BANNER_NORMAL" ]]; then

            echo -e "${GREEN}Archivo:${RESET} $BANNER_NORMAL"
            echo
            cat "$BANNER_NORMAL"

        else

            msg_error "No existe el Banner normal."

        fi

    elif [[ "$ACTIVO" == "checkuser" ]]; then

        if [[ -f "$BANNER_NORMAL" ]]; then

            echo -e "${YELLOW}BANNER NORMAL + CHECKUSER${RESET}"
            echo
            cat "$BANNER_NORMAL"

            echo
            echo -e "${CYAN}════════════ CHECKUSER DINÁMICO ════════════${RESET}"
            echo
            echo -e "${WHITE}Usuario      : ${GREEN}<usuario conectado>${RESET}"
            echo -e "${WHITE}Días         : ${GREEN}<calculado automáticamente>${RESET}"
            echo -e "${WHITE}Límite       : ${GREEN}<desde limits.conf>${RESET}"
            echo -e "${WHITE}Expiración   : ${GREEN}<desde cuenta SSH>${RESET}"

        else

            msg_error "No existe el Banner normal."

        fi

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

        msg_error "No existe un Banner normal."

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
    echo -e "${CYAN}║${MAGENTA}              ELIMINAR BANNER                     ${CYAN}║${RESET}"
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

            if [[ -f "$DROPBEAR" ]]; then
                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
            fi

            echo "none" > "$BANNER_ACTIVE"

            reiniciar_servicios

            msg_ok "Banner normal eliminado."

            ;;

        2)

            rm -f "$BANNER_CHECK"
            rm -f "/etc/kevintech/checkuser-banner.sh"

            if [[ -f "/etc/pam.d/sshd" ]]; then

                sed -i '/kevintech-checkuser-banner.sh/d' \
                    "/etc/pam.d/sshd"

            fi

            # Volver a utilizar banner normal si existe
            if [[ -f "$BANNER_NORMAL" ]]; then

                configurar_ssh_banner "$BANNER_NORMAL"
                configurar_dropbear_banner "$BANNER_NORMAL"

                echo "normal" > "$BANNER_ACTIVE"

            else

                sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD" 2>/dev/null

                if [[ -f "$DROPBEAR" ]]; then
                    sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
                fi

                echo "none" > "$BANNER_ACTIVE"

            fi

            reiniciar_servicios

            msg_ok "Banner CheckUser eliminado."

            ;;

        3)

            rm -f "$BANNER_NORMAL"
            rm -f "$BANNER_CHECK"
            rm -f "/etc/kevintech/checkuser-banner.sh"

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' \
                "$SSHD" 2>/dev/null

            if [[ -f "$DROPBEAR" ]]; then
                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
            fi

            if [[ -f "/etc/pam.d/sshd" ]]; then

                sed -i '/kevintech-checkuser-banner.sh/d' \
                    "/etc/pam.d/sshd"

            fi

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
            crear_banner_checkuser
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
            echo
            msg_error "Opción inválida."
            sleep 2
            ;;

    esac

done