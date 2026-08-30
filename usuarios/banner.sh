#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear + CheckUser
# Independiente de CheckGestor
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

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"
LIMITS_FILE="$BASE/limits.conf"

CHECKUSER_SCRIPT="$BASE/checkuser-banner.sh"

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

pause() {
    echo
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
}

#==================================================
# CONFIGURAR OPENSSH
#==================================================

configurar_ssh() {

    local ARCHIVO="$1"

    [[ ! -f "$SSHD" ]] && return 0

    if grep -qE '^[[:space:]]*Banner[[:space:]]' "$SSHD"; then

        sed -i \
            "s|^[[:space:]]*Banner[[:space:]].*|Banner $ARCHIVO|" \
            "$SSHD"

    else

        echo "Banner $ARCHIVO" >> "$SSHD"

    fi
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear() {

    local ARCHIVO="$1"

    [[ ! -f "$DROPBEAR" ]] && return 0

    if grep -q '^DROPBEAR_BANNER=' "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$ARCHIVO\"|" \
            "$DROPBEAR"

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
# CREAR CHECKUSER
#==================================================

crear_checkuser() {

    cat > "$CHECKUSER_SCRIPT" <<'CHECKEOF'
#!/bin/bash
#==================================================
# KevinTech CheckUser
# Banner dinámico después del login
#==================================================

# Usuario autenticado
USERNAME="${PAM_USER:-}"

# Si PAM no entrega usuario, salir
[[ -z "$USERNAME" ]] && exit 0

# Verificar usuario
id "$USERNAME" >/dev/null 2>&1 || exit 0

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

#==================================================
# OBTENER LÍMITE
#==================================================

LIMIT="0"

if [[ -f "$LIMITS_FILE" ]]; then

    LIMIT=$(
        awk -F: -v user="$USERNAME" '
            $1 == user {
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
    chage -l "$USERNAME" 2>/dev/null |
    awk -F: '
        /Account expires/ {
            gsub(/^[ \t]+/, "", $2)
            print $2
        }
    '
)

#==================================================
# CUENTA SIN EXPIRACIÓN
#==================================================

if [[ -z "$EXPIRATION" ||
      "$EXPIRATION" == "never" ||
      "$EXPIRATION" == "Nunca" ]]; then

    EXPIRATION_TEXT="Ilimitada"
    DAYS="∞"

else

    # Convertir fecha
    EXPIRATION_TS=$(date -d "$EXPIRATION" +%s 2>/dev/null)

    TODAY_TS=$(date +%s)

    if [[ -n "$EXPIRATION_TS" ]]; then

        DAYS=$(
            echo $(( (EXPIRATION_TS - TODAY_TS) / 86400 ))
        )

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
# COLORES
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

#==================================================
# CHECKUSER
#==================================================

printf "\n"

printf "${CYAN}╔════════════════════════════════════════════════════╗${RESET}\n"
printf "${CYAN}║${MAGENTA}              ⚜ KEVINTECH CHECKUSER ⚜             ${CYAN}║${RESET}\n"
printf "${CYAN}╠════════════════════════════════════════════════════╣${RESET}\n"

printf "${CYAN}║${RESET} ${WHITE}Usuario      :${RESET} ${GREEN}%-34s${RESET} ${CYAN}║${RESET}\n" "$USERNAME"
printf "${CYAN}║${RESET} ${WHITE}Días         :${RESET} ${GREEN}%-34s${RESET} ${CYAN}║${RESET}\n" "$DAYS"
printf "${CYAN}║${RESET} ${WHITE}Límite       :${RESET} ${GREEN}%-34s${RESET} ${CYAN}║${RESET}\n" "$LIMIT_TEXT"
printf "${CYAN}║${RESET} ${WHITE}Expiración   :${RESET} ${GREEN}%-34s${RESET} ${CYAN}║${RESET}\n" "$EXPIRATION_TEXT"

printf "${CYAN}╚════════════════════════════════════════════════════╝${RESET}\n"

printf "\n"

exit 0
CHECKEOF

    chmod 755 "$CHECKUSER_SCRIPT"
}

#==================================================
# ACTIVAR CHECKUSER EN SSH
#==================================================

activar_checkuser() {

    crear_checkuser

    PAM_FILE="/etc/pam.d/sshd"

    if [[ -f "$PAM_FILE" ]]; then

        # Evitar duplicados
        sed -i \
            '/# KEVINTECH CHECKUSER START/,/# KEVINTECH CHECKUSER END/d' \
            "$PAM_FILE"

        cat >> "$PAM_FILE" <<EOF

# KEVINTECH CHECKUSER START
session optional pam_exec.so stdout $CHECKUSER_SCRIPT
# KEVINTECH CHECKUSER END
EOF

    else

        msg_error "No existe $PAM_FILE"
        return 1

    fi

    #==================================================
    # Banner normal primero
    #==================================================

    if [[ -f "$BANNER_NORMAL" ]]; then

        configurar_ssh "$BANNER_NORMAL"
        configurar_dropbear "$BANNER_NORMAL"

    fi

    echo "checkuser" > "$BANNER_ACTIVE"

    reiniciar_servicios

    msg_ok "Banner CheckUser activado."
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
    # BANNER TEXTO ANSI
    #==================================================

    cat > "$BANNER_NORMAL" <<EOF
\033[1;96m╔════════════════════════════════════════════════════╗\033[0m
\033[1;96m║\033[1;95m              ⚜ $SERVER ⚜                         \033[1;96m║\033[0m
\033[1;96m╠════════════════════════════════════════════════════╣\033[0m

\033[1;97m                 $PROMO\033[0m

\033[1;96m📢 Canal:\033[0m \033[1;93m$CHANNEL\033[0m
\033[1;96m👤 Soporte:\033[0m \033[1;92m$SUPPORT\033[0m

\033[1;96m══════════════════════════════════════════════════════\033[0m

\033[1;92m        Gracias por usar nuestros servicios\033[0m

\033[1;96m╚════════════════════════════════════════════════════╝\033[0m
EOF

    chmod 644 "$BANNER_NORMAL"

    #==================================================
    # ACTIVAR BANNER NORMAL
    #==================================================

    configurar_ssh "$BANNER_NORMAL"
    configurar_dropbear "$BANNER_NORMAL"

    # Si estaba CheckUser, se mantiene activo
    # Si no, queda normal
    if [[ ! -f "$BANNER_ACTIVE" ||
          "$(cat "$BANNER_ACTIVE" 2>/dev/null)" != "checkuser" ]]; then

        echo "normal" > "$BANNER_ACTIVE"

    fi

    reiniciar_servicios

    echo

    msg_ok "Banner normal creado correctamente."

    sleep 2
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

    echo -e "${WHITE}Estado:${RESET}"

    case "$ACTIVO" in

        normal)

            echo -e "${GREEN}✔ Banner normal activo${RESET}"

            ;;

        checkuser)

            echo -e "${GREEN}✔ Banner normal + CheckUser activo${RESET}"

            ;;

        *)

            echo -e "${YELLOW}⚠ No hay banner activo${RESET}"

            ;;

    esac

    echo

    if [[ -f "$BANNER_NORMAL" ]]; then

        echo -e "${CYAN}════════════ BANNER NORMAL ════════════${RESET}"
        echo

        cat "$BANNER_NORMAL"

    else

        echo -e "${RED}No existe Banner normal.${RESET}"

    fi

    if [[ "$ACTIVO" == "checkuser" ]]; then

        echo
        echo -e "${CYAN}════════════ CHECKUSER ════════════${RESET}"
        echo
        echo -e "${WHITE}El CheckUser se muestra automáticamente después del login.${RESET}"
        echo -e "${GRAY}Los datos son obtenidos de la cuenta SSH conectada.${RESET}"

    fi

    echo

    read -n1 -s -r \
        -p "Presione cualquier tecla para regresar..."

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

    chmod 644 "$BANNER_NORMAL"

    configurar_ssh "$BANNER_NORMAL"
    configurar_dropbear "$BANNER_NORMAL"

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

    echo -e "${GREEN}[1]${WHITE} Eliminar Banner normal"
    echo -e "${RED}[2]${WHITE} Eliminar Banner CheckUser"
    echo -e "${YELLOW}[3]${WHITE} Eliminar ambos"
    echo -e "${GRAY}[0]${WHITE} Cancelar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)

            rm -f "$BANNER_NORMAL"

            # Si CheckUser está activo,
            # dejamos el CheckUser funcionando.
            if [[ "$(cat "$BANNER_ACTIVE" 2>/dev/null)" == "checkuser" ]]; then

                # Sin banner normal no hay banner previo.
                # Se elimina el Banner de SSH.
                sed -i \
                    '/^[[:space:]]*Banner[[:space:]]/d' \
                    "$SSHD" 2>/dev/null

                if [[ -f "$DROPBEAR" ]]; then

                    sed -i \
                        '/^DROPBEAR_BANNER=/d' \
                        "$DROPBEAR"

                fi

            else

                sed -i \
                    '/^[[:space:]]*Banner[[:space:]]/d' \
                    "$SSHD" 2>/dev/null

                if [[ -f "$DROPBEAR" ]]; then

                    sed -i \
                        '/^DROPBEAR_BANNER=/d' \
                        "$DROPBEAR"

                fi

                echo "none" > "$BANNER_ACTIVE"

            fi

            reiniciar_servicios

            msg_ok "Banner normal eliminado."

            ;;

        2)

            # Eliminar únicamente CheckUser
            rm -f "$BANNER_CHECK"
            rm -f "$CHECKUSER_SCRIPT"

            PAM_FILE="/etc/pam.d/sshd"

            if [[ -f "$PAM_FILE" ]]; then

                sed -i \
                    '/# KEVINTECH CHECKUSER START/,/# KEVINTECH CHECKUSER END/d' \
                    "$PAM_FILE"

            fi

            # Volver al banner normal
            if [[ -f "$BANNER_NORMAL" ]]; then

                configurar_ssh "$BANNER_NORMAL"
                configurar_dropbear "$BANNER_NORMAL"

                echo "normal" > "$BANNER_ACTIVE"

            else

                sed -i \
                    '/^[[:space:]]*Banner[[:space:]]/d' \
                    "$SSHD" 2>/dev/null

                if [[ -f "$DROPBEAR" ]]; then

                    sed -i \
                        '/^DROPBEAR_BANNER=/d' \
                        "$DROPBEAR"

                fi

                echo "none" > "$BANNER_ACTIVE"

            fi

            reiniciar_servicios

            msg_ok "Banner CheckUser eliminado."

            ;;

        3)

            rm -f "$BANNER_NORMAL"
            rm -f "$BANNER_CHECK"
            rm -f "$CHECKUSER_SCRIPT"

            sed -i \
                '/^[[:space:]]*Banner[[:space:]]/d' \
                "$SSHD" 2>/dev/null

            if [[ -f "$DROPBEAR" ]]; then

                sed -i \
                    '/^DROPBEAR_BANNER=/d' \
                    "$DROPBEAR"

            fi

            PAM_FILE="/etc/pam.d/sshd"

            if [[ -f "$PAM_FILE" ]]; then

                sed -i \
                    '/# KEVINTECH CHECKUSER START/,/# KEVINTECH CHECKUSER END/d' \
                    "$PAM_FILE"

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
            crear_checkuser
            activar_checkuser
            sleep 2
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
            msg_error "Opción inválida."
            sleep 2
            ;;

    esac

done