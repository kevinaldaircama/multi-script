#!/bin/bash
#==================================================
# KevinTech Multi Script
# Módulo: Banner SSH / Dropbear
# Banner Normal + CheckUser
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

[[ -f "$CONFIG" ]] && source "$CONFIG"

BANNER_DIR="$BASE/banners"

BANNER_NORMAL="$BANNER_DIR/banner_normal"
BANNER_CHECKUSER="$BANNER_DIR/banner_checkuser"

BANNER_ACTIVE="/etc/issue.net"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

mkdir -p "$BASE"
mkdir -p "$BANNER_DIR"

#==================================================
# FUNCIONES
#==================================================

pausa() {
    echo
    read -n1 -s -r -p \
        "$(echo -e "${YELLOW}Presione cualquier tecla para continuar...${RESET}")"
    echo
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

#==================================================
# REINICIAR SERVICIOS
#==================================================

reiniciar_servicios() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

}

#==================================================
# CONFIGURAR OPENSSH
#==================================================

configurar_openssh() {

    [[ ! -f "$SSHD" ]] && return

    if grep -qE "^[[:space:]]*Banner[[:space:]]" "$SSHD"; then

        sed -i \
            "s|^[[:space:]]*Banner[[:space:]].*|Banner $BANNER_ACTIVE|" \
            "$SSHD"

    else

        echo "Banner $BANNER_ACTIVE" >> "$SSHD"

    fi
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear() {

    [[ ! -f "$DROPBEAR" ]] && return

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER_ACTIVE\"|" \
            "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$BANNER_ACTIVE\"" >> "$DROPBEAR"

    fi
}

#==================================================
# ACTIVAR BANNER
#==================================================

activar_banner() {

    local ARCHIVO="$1"

    if [[ ! -f "$ARCHIVO" ]]; then
        msg_error "El banner no existe."
        return 1
    fi

    cp -f "$ARCHIVO" "$BANNER_ACTIVE"

    chmod 644 "$BANNER_ACTIVE"

    configurar_openssh
    configurar_dropbear

    reiniciar_servicios

}

#==================================================
# CREAR CHECKUSER
#==================================================

crear_checkuser() {

    if [[ ! -f "$BANNER_NORMAL" ]]; then
        msg_error "Primero debes crear el Banner Normal."
        return 1
    fi

    # Copiar banner normal
    cp -f "$BANNER_NORMAL" "$BANNER_CHECKUSER"

    # Agregar CheckUser
    cat >> "$BANNER_CHECKUSER" <<'EOF'

════════════════════════════════════════════════════
                    CHECK USER
════════════════════════════════════════════════════

👤 Usuario        : %USERNAME%
🔌 Conexiones     : %CONNECTIONS%/%LIMIT%
📅 Expiración     : %EXPIRATION%
⏳ Días restantes : %DAYS%

════════════════════════════════════════════════════
EOF

    chmod 644 "$BANNER_CHECKUSER"

    msg_ok "Banner CheckUser creado."

}

#==================================================
# PEGAR BANNER PERSONALIZADO
#==================================================

pegar_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}       PEGAR BANNER PERSONALIZADO                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${YELLOW}Pega tu banner completo.${RESET}"
    echo -e "${GRAY}Puedes utilizar varias líneas.${RESET}"
    echo -e "${GRAY}Cuando termines escribe FIN en una línea nueva.${RESET}"
    echo

    TEMP=$(mktemp)

    while IFS= read -r LINEA; do

        [[ "$LINEA" == "FIN" ]] && break

        printf '%s\n' "$LINEA" >> "$TEMP"

    done

    if [[ ! -s "$TEMP" ]]; then

        rm -f "$TEMP"

        msg_error "El banner está vacío."
        sleep 2
        return

    fi

    cp -f "$TEMP" "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    rm -f "$TEMP"

    msg_ok "Banner Normal guardado."

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas incluir CheckUser? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser
            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"

            msg_ok "Banner creado sin CheckUser."
            ;;

        *)

            rm -f "$BANNER_CHECKUSER"

            msg_warn "Respuesta inválida. Se creó sin CheckUser."
            ;;

    esac

    activar_banner "$BANNER_NORMAL"

    msg_ok "Banner Normal activado."

    sleep 2
}

#==================================================
# CREAR PLANTILLA
#==================================================

crear_plantilla() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             CREAR UNA PLANTILLA                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    read -rp \
        "$(echo -e "${GREEN}Nombre del Servidor: ${RESET}")" SERVER

    [[ -z "$SERVER" ]] &&
        SERVER="${SERVER_NAME:-KevinTech VPN}"

    read -rp \
        "$(echo -e "${GREEN}Texto Promocional: ${RESET}")" PROMO

    [[ -z "$PROMO" ]] &&
        PROMO="🔥 Bienvenido a $SERVER 🔥"

    read -rp \
        "$(echo -e "${GREEN}Canal: ${RESET}")" CHANNEL

    read -rp \
        "$(echo -e "${GREEN}Soporte: ${RESET}")" SUPPORT

    #==================================================
    # BANNER NORMAL
    #==================================================

    cat > "$BANNER_NORMAL" <<EOF
════════════════════════════════════════════════════
              $SERVER ★
════════════════════════════════════════════════════

$PROMO

📢 Canal   : $CHANNEL
👤 Soporte : $SUPPORT

════════════════════════════════════════════════════
       Gracias por usar nuestros servicios
════════════════════════════════════════════════════
EOF

    chmod 644 "$BANNER_NORMAL"

    msg_ok "Banner Normal creado."

    echo

    #==================================================
    # PREGUNTAR CHECKUSER
    #==================================================

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas incluir CheckUser? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser
            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"

            msg_ok "Plantilla sin CheckUser."
            ;;

        *)

            rm -f "$BANNER_CHECKUSER"

            msg_warn "Respuesta inválida. Se creó sin CheckUser."
            ;;

    esac

    activar_banner "$BANNER_NORMAL"

    msg_ok "Banner activado."

    sleep 2
}

#==================================================
# SUBMENÚ CREAR BANNER
#==================================================

crear_banner() {

    while true; do

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                  CREAR BANNER                     ${CYAN}║${RESET}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

        echo -e "${GREEN}[1]${WHITE} Pegar Banner Personalizado"
        echo -e "${BLUE}[2]${WHITE} Crear una Plantilla"
        echo -e "${CYAN}[0]${WHITE} Regresar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OP

        case "$OP" in

            1)
                pegar_banner
                ;;

            2)
                crear_plantilla
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
}

#==================================================
# VER BANNER
#==================================================

ver_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                    VER BANNER                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}══════════ BANNER NORMAL ══════════${RESET}"
    echo

    if [[ -f "$BANNER_NORMAL" ]]; then

        cat "$BANNER_NORMAL"

    else

        echo -e "${RED}No existe Banner Normal.${RESET}"

    fi

    echo

    if [[ -f "$BANNER_CHECKUSER" ]]; then

        echo -e "${YELLOW}══════════ BANNER CHECKUSER ══════════${RESET}"
        echo

        cat "$BANNER_CHECKUSER"

    else

        echo -e "${GRAY}No existe Banner CheckUser.${RESET}"

    fi

    echo

    pausa
}

#==================================================
# EDITAR SOLO BANNER NORMAL
#==================================================

editar_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              EDITAR BANNER NORMAL                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "No existe Banner Normal."

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

    activar_banner "$BANNER_NORMAL"

    echo
    msg_ok "Banner Normal actualizado."
    echo -e "${GRAY}El Banner CheckUser no fue modificado.${RESET}"

    sleep 2
}

#==================================================
# ELIMINAR BANNER
#==================================================

eliminar_banner() {

    while true; do

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                ELIMINAR BANNER                    ${CYAN}║${RESET}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

        echo -e "${RED}[1]${WHITE} Eliminar Banner Normal"
        echo -e "${MAGENTA}[2]${WHITE} Eliminar Banner CheckUser"
        echo -e "${CYAN}[0]${WHITE} Regresar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OP

        case "$OP" in

            #==================================================
            # NORMAL
            #==================================================

            1)

                if [[ ! -f "$BANNER_NORMAL" ]]; then

                    msg_error "No existe Banner Normal."

                    sleep 2
                    continue

                fi

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar Banner Normal? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_NORMAL"

                        if [[ -f "$SSHD" ]]; then

                            sed -i \
                                '/^[[:space:]]*Banner[[:space:]]/d' \
                                "$SSHD"

                        fi

                        if [[ -f "$DROPBEAR" ]]; then

                            sed -i \
                                '/^DROPBEAR_BANNER=/d' \
                                "$DROPBEAR"

                        fi

                        rm -f "$BANNER_ACTIVE"

                        reiniciar_servicios

                        msg_ok "Banner Normal eliminado."

                        ;;

                    *)

                        msg_warn "Operación cancelada."

                        ;;

                esac

                sleep 2
                ;;

            #==================================================
            # CHECKUSER
            #==================================================

            2)

                if [[ ! -f "$BANNER_CHECKUSER" ]]; then

                    msg_error "No existe Banner CheckUser."

                    sleep 2
                    continue

                fi

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar Banner CheckUser? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_CHECKUSER"

                        msg_ok "Banner CheckUser eliminado."

                        ;;

                    *)

                        msg_warn "Operación cancelada."

                        ;;

                esac

                sleep 2
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
}

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢            ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

    echo -e "${GREEN}[1]${WHITE} Crear Banner"
    echo -e "${BLUE}[2]${WHITE} Ver Banner"
    echo -e "${YELLOW}[3]${WHITE} Editar Banner"
    echo -e "${RED}[4]${WHITE} Eliminar Banner"
    echo -e "${CYAN}[0]${WHITE} Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)
            crear_banner
            ;;

        2)
            ver_banner
            ;;

        3)
            editar_banner
            ;;

        4)
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