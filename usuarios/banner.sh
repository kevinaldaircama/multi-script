#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear
# Banner Normal + Banner CheckUser
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

mkdir -p "$BASE"

[[ -f "$CONFIG" ]] && source "$CONFIG"

BANNER_DIR="$BASE/banners"

BANNER_NORMAL="$BANNER_DIR/banner_normal"
BANNER_CHECKUSER="$BANNER_DIR/banner_checkuser"

BANNER="/etc/issue.net"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

mkdir -p "$BANNER_DIR"

#==================================================
# FUNCIONES
#==================================================

reiniciar_servicios() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

}

configurar_banner() {

    local ARCHIVO="$1"

    [[ ! -f "$ARCHIVO" ]] && return 1

    cp -f "$ARCHIVO" "$BANNER"

    #----------------------------------------------
    # OPENSSH
    #----------------------------------------------

    if grep -qE "^[[:space:]]*Banner[[:space:]]" "$SSHD"; then

        sed -i "s|^[[:space:]]*Banner[[:space:]].*|Banner $BANNER|" "$SSHD"

    else

        echo "Banner $BANNER" >> "$SSHD"

    fi

    #----------------------------------------------
    # DROPBEAR
    #----------------------------------------------

    if [[ -f "$DROPBEAR" ]]; then

        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

            sed -i \
                "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" \
                "$DROPBEAR"

        else

            echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"

        fi

    fi

    reiniciar_servicios

}

crear_banner_normal() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 BANNER NORMAL                    ${CYAN}║${RESET}"
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

    #----------------------------------------------
    # BANNER NORMAL
    #----------------------------------------------

    cat > "$BANNER_NORMAL" <<EOF

════════════════════════════════════════════════════

              $SERVER

════════════════════════════════════════════════════

$PROMO

📢 Canal   : $CHANNEL
👤 Soporte : $SUPPORT

════════════════════════════════════════════════════

          Gracias por usar nuestros servicios

════════════════════════════════════════════════════

EOF

    chmod 644 "$BANNER_NORMAL"

    #----------------------------------------------
    # CREAR CHECKUSER BASADO EN EL NORMAL
    #----------------------------------------------

    cat > "$BANNER_CHECKUSER" <<EOF

$(cat "$BANNER_NORMAL")

════════════════════════════════════════════════════
                 CHECK USER
════════════════════════════════════════════════════

👤 Usuario       : %USERNAME%
🌐 IP            : %IP%
📱 Dispositivo   : %DEVICE%
🔌 Conexiones    : %CONNECTIONS%
📅 Expiración    : %EXPIRATION%
⏳ Días restantes: %DAYS%

════════════════════════════════════════════════════

EOF

    chmod 644 "$BANNER_CHECKUSER"

    #----------------------------------------------
    # ACTIVAR NORMAL
    #----------------------------------------------

    configurar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Banner normal creado correctamente.${RESET}"
    echo -e "${GREEN}✔ Banner CheckUser preparado.${RESET}"
    echo

    sleep 2
}

editar_banner_normal() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 EDITAR BANNER                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        echo -e "${YELLOW}No existe un Banner Normal.${RESET}"
        echo -e "${CYAN}Primero debes crearlo.${RESET}"

        sleep 2
        return

    fi

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}Nano no está instalado.${RESET}"
        sleep 2
        return

    fi

    nano "$BANNER_NORMAL"

    #----------------------------------------------
    # ACTUALIZAR CHECKUSER
    #----------------------------------------------

    cat > "$BANNER_CHECKUSER" <<EOF

$(cat "$BANNER_NORMAL")

════════════════════════════════════════════════════
                 CHECK USER
════════════════════════════════════════════════════

👤 Usuario       : %USERNAME%
🌐 IP            : %IP%
📱 Dispositivo   : %DEVICE%
🔌 Conexiones    : %CONNECTIONS%
📅 Expiración    : %EXPIRATION%
⏳ Días restantes: %DAYS%

════════════════════════════════════════════════════

EOF

    chmod 644 "$BANNER_CHECKUSER"

    # Mantener banner normal activo
    configurar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Banner actualizado.${RESET}"

    sleep 2
}

editar_banner_checkuser() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              BANNER CHECKUSER                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_CHECKUSER" ]]; then

        echo -e "${YELLOW}No existe el Banner CheckUser.${RESET}"

        if [[ -f "$BANNER_NORMAL" ]]; then

            echo -e "${CYAN}Creándolo desde tu Banner Normal...${RESET}"

            cat > "$BANNER_CHECKUSER" <<EOF

$(cat "$BANNER_NORMAL")

════════════════════════════════════════════════════
                 CHECK USER
════════════════════════════════════════════════════

👤 Usuario       : %USERNAME%
🌐 IP            : %IP%
📱 Dispositivo   : %DEVICE%
🔌 Conexiones    : %CONNECTIONS%
📅 Expiración    : %EXPIRATION%
⏳ Días restantes: %DAYS%

════════════════════════════════════════════════════

EOF

        else

            echo -e "${RED}Primero crea un Banner Normal.${RESET}"
            sleep 2
            return

        fi

    fi

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}Nano no está instalado.${RESET}"
        sleep 2
        return

    fi

    nano "$BANNER_CHECKUSER"

    echo
    echo -e "${GREEN}✔ Banner CheckUser actualizado.${RESET}"

    sleep 2
}

ver_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 BANNERS GUARDADOS                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}══════════ BANNER NORMAL ══════════${RESET}"

    if [[ -f "$BANNER_NORMAL" ]]; then

        echo -e "${GREEN}Ruta:${RESET} $BANNER_NORMAL"
        echo
        cat "$BANNER_NORMAL"

    else

        echo -e "${RED}No existe.${RESET}"

    fi

    echo

    echo -e "${YELLOW}══════════ BANNER CHECKUSER ══════════${RESET}"

    if [[ -f "$BANNER_CHECKUSER" ]]; then

        echo -e "${GREEN}Ruta:${RESET} $BANNER_CHECKUSER"
        echo
        cat "$BANNER_CHECKUSER"

    else

        echo -e "${RED}No existe.${RESET}"

    fi

    echo
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"

    read -n1 -s -r -p "Presione cualquier tecla para regresar..."

}

activar_normal() {

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        echo -e "${RED}No existe el Banner Normal.${RESET}"
        sleep 2
        return

    fi

    configurar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Banner Normal activado.${RESET}"

    sleep 2
}

activar_checkuser() {

    if [[ ! -f "$BANNER_CHECKUSER" ]]; then

        echo -e "${RED}No existe el Banner CheckUser.${RESET}"
        sleep 2
        return

    fi

    configurar_banner "$BANNER_CHECKUSER"

    echo
    echo -e "${GREEN}✔ Banner CheckUser activado.${RESET}"

    sleep 2
}

eliminar_banners() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}               ELIMINAR BANNERS                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    read -rp "$(echo -e "${YELLOW}¿Eliminar todos los banners? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|Sí|sí)

            rm -f "$BANNER_NORMAL"
            rm -f "$BANNER_CHECKUSER"
            rm -f "$BANNER"

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

            if [[ -f "$DROPBEAR" ]]; then

                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

            fi

            reiniciar_servicios

            echo
            echo -e "${GREEN}✔ Banners eliminados correctamente.${RESET}"

            ;;

        *)

            echo
            echo -e "${YELLOW}Operación cancelada.${RESET}"

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

    echo -e "${GREEN}[1]${WHITE} Crear Banner Normal"
    echo -e "${BLUE}[2]${WHITE} Ver Banners"
    echo -e "${YELLOW}[3]${WHITE} Editar Banner Normal"
    echo -e "${CYAN}[4]${WHITE} Editar Banner CheckUser"
    echo -e "${GREEN}[5]${WHITE} Activar Banner Normal"
    echo -e "${MAGENTA}[6]${WHITE} Activar Banner CheckUser"
    echo -e "${RED}[7]${WHITE} Eliminar Banners"
    echo -e "${CYAN}[0]${WHITE} Regresar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)
            crear_banner_normal
            ;;

        2)
            ver_banner
            ;;

        3)
            editar_banner_normal
            ;;

        4)
            editar_banner_checkuser
            ;;

        5)
            activar_normal
            ;;

        6)
            activar_checkuser
            ;;

        7)
            eliminar_banners
            ;;

        0)
            break
            ;;

        *)
            echo
            echo -e "${RED}Opción inválida.${RESET}"
            sleep 2
            ;;

    esac

done