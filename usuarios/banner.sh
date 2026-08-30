#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear
# Sistema:
#   - Banner Normal
#   - Banner CheckUser
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

BANNER_DIR="$BASE/banners"

BANNER_NORMAL="$BANNER_DIR/banner_normal"
BANNER_CHECKUSER="$BANNER_DIR/banner_checkuser"

BANNER="/etc/issue.net"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

mkdir -p "$BASE"
mkdir -p "$BANNER_DIR"

#==================================================
# FUNCIONES GENERALES
#==================================================

pausa() {

    echo
    read -n1 -s -r -p \
        "$(echo -e "${YELLOW}Presione cualquier tecla para continuar...${RESET}")"

}

reiniciar_servicios() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

}

#==================================================
# APLICAR BANNER
#==================================================

aplicar_banner() {

    local ARCHIVO="$1"

    if [[ ! -f "$ARCHIVO" ]]; then

        echo -e "${RED}✘ El banner no existe.${RESET}"
        return 1

    fi

    #----------------------------------------------
    # COPIAR BANNER ACTIVO
    #----------------------------------------------

    cp -f "$ARCHIVO" "$BANNER"

    chmod 644 "$BANNER"

    #----------------------------------------------
    # OPENSSH
    #----------------------------------------------

    if grep -qE "^[[:space:]]*Banner[[:space:]]" "$SSHD"; then

        sed -i \
            "s|^[[:space:]]*Banner[[:space:]].*|Banner $BANNER|" \
            "$SSHD"

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

#==================================================
# CREAR BANNER PERSONALIZADO
#==================================================

pegar_banner() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}           PEGAR BANNER PERSONALIZADO             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${YELLOW}Pega tu banner completo.${RESET}"
    echo -e "${YELLOW}Cuando termines escribe: FIN${RESET}"
    echo

    TEMP=$(mktemp)

    while IFS= read -r LINEA; do

        [[ "$LINEA" == "FIN" ]] && break

        echo "$LINEA" >> "$TEMP"

    done

    if [[ ! -s "$TEMP" ]]; then

        rm -f "$TEMP"

        echo
        echo -e "${RED}✘ No se ingresó ningún banner.${RESET}"

        sleep 2
        return

    fi

    #----------------------------------------------
    # GUARDAR BANNER NORMAL
    #----------------------------------------------

    cp "$TEMP" "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    rm -f "$TEMP"

    echo
    echo -e "${GREEN}✔ Banner Normal guardado.${RESET}"

    #----------------------------------------------
    # PREGUNTAR CHECKUSER
    #----------------------------------------------

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas incluir CheckUser? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser_desde_normal

            echo
            echo -e "${GREEN}✔ CheckUser agregado al banner.${RESET}"

            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"

            echo
            echo -e "${GREEN}✔ Banner creado sin CheckUser.${RESET}"

            ;;

        *)

            echo
            echo -e "${YELLOW}Respuesta no válida. Se creará sin CheckUser.${RESET}"

            rm -f "$BANNER_CHECKUSER"

            ;;

    esac

    #----------------------------------------------
    # ACTIVAR BANNER NORMAL
    #----------------------------------------------

    aplicar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Banner Normal activado.${RESET}"

    sleep 2
}

#==================================================
# CREAR PLANTILLA
#==================================================

crear_plantilla() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              CREAR UNA PLANTILLA                 ${CYAN}║${RESET}"
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
        "$(echo -e "${GREEN}Canal Telegram: ${RESET}")" CHANNEL

    read -rp \
        "$(echo -e "${GREEN}Soporte: ${RESET}")" SUPPORT

    #----------------------------------------------
    # CREAR BANNER NORMAL
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

    echo

    #----------------------------------------------
    # PREGUNTAR CHECKUSER
    #----------------------------------------------

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas incluir CheckUser? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser_desde_normal

            echo
            echo -e "${GREEN}✔ CheckUser incluido.${RESET}"

            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"

            echo
            echo -e "${GREEN}✔ Plantilla creada sin CheckUser.${RESET}"

            ;;

        *)

            rm -f "$BANNER_CHECKUSER"

            echo
            echo -e "${YELLOW}Respuesta no válida. Se creará sin CheckUser.${RESET}"

            ;;

    esac

    #----------------------------------------------
    # ACTIVAR
    #----------------------------------------------

    aplicar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Plantilla creada correctamente.${RESET}"

    sleep 2
}

#==================================================
# CREAR CHECKUSER
#==================================================

crear_checkuser_desde_normal() {

    if [[ ! -f "$BANNER_NORMAL" ]]; then
        return 1
    fi

    cat "$BANNER_NORMAL" > "$BANNER_CHECKUSER"

    cat >> "$BANNER_CHECKUSER" <<'EOF'

════════════════════════════════════════════════════
                    CHECK USER
════════════════════════════════════════════════════

👤 Usuario        : %USERNAME%
🌐 IP             : %IP%
📱 Dispositivo    : %DEVICE%
🔌 Conexiones     : %CONNECTIONS%
📅 Expiración     : %EXPIRATION%
⏳ Días restantes : %DAYS%

════════════════════════════════════════════════════
EOF

    chmod 644 "$BANNER_CHECKUSER"

}

#==================================================
# SUBMENÚ CREAR
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
                echo
                echo -e "${RED}✘ Opción inválida.${RESET}"
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
    echo -e "${CYAN}║${MAGENTA}                    BANNER                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ -f "$BANNER_NORMAL" ]]; then

        echo -e "${YELLOW}══════════ BANNER NORMAL ══════════${RESET}"
        echo

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
    echo -e "${CYAN}║${MAGENTA}              EDITAR BANNER NORMAL                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        echo -e "${RED}✘ No existe Banner Normal.${RESET}"
        sleep 2
        return

    fi

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}✘ Nano no está instalado.${RESET}"
        sleep 2
        return

    fi

    nano "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    #----------------------------------------------
    # IMPORTANTE:
    #
    # NO SE TOCA BANNER_CHECKUSER
    #----------------------------------------------

    aplicar_banner "$BANNER_NORMAL"

    echo
    echo -e "${GREEN}✔ Banner Normal actualizado.${RESET}"
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

            #------------------------------------------
            # NORMAL
            #------------------------------------------

            1)

                if [[ ! -f "$BANNER_NORMAL" ]]; then

                    echo
                    echo -e "${RED}✘ No existe Banner Normal.${RESET}"
                    sleep 2
                    continue

                fi

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar Banner Normal? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_NORMAL"

                        # Quitar configuración SSH
                        sed -i \
                            '/^[[:space:]]*Banner[[:space:]]/d' \
                            "$SSHD"

                        # Quitar Dropbear
                        if [[ -f "$DROPBEAR" ]]; then

                            sed -i \
                                '/^DROPBEAR_BANNER=/d' \
                                "$DROPBEAR"

                        fi

                        rm -f "$BANNER"

                        reiniciar_servicios

                        echo
                        echo -e "${GREEN}✔ Banner Normal eliminado.${RESET}"

                        ;;

                    *)

                        echo
                        echo -e "${YELLOW}Operación cancelada.${RESET}"

                        ;;

                esac

                sleep 2
                ;;

            #------------------------------------------
            # CHECKUSER
            #------------------------------------------

            2)

                if [[ ! -f "$BANNER_CHECKUSER" ]]; then

                    echo
                    echo -e "${RED}✘ No existe Banner CheckUser.${RESET}"

                    sleep 2
                    continue

                fi

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar Banner CheckUser? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_CHECKUSER"

                        echo
                        echo -e "${GREEN}✔ Banner CheckUser eliminado.${RESET}"

                        ;;

                    *)

                        echo
                        echo -e "${YELLOW}Operación cancelada.${RESET}"

                        ;;

                esac

                sleep 2
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
            echo
            echo -e "${RED}✘ Opción inválida.${RESET}"
            sleep 2
            ;;

    esac

done