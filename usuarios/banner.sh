#!/bin/bash
#==================================================
# KevinTech Multi Script
# Módulo: Banner SSH / Dropbear
# Banner Normal
# CheckUser dinámico separado
# Versión: Premium
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

CHECKUSER_SCRIPT="/usr/local/bin/kevintech-checkuser"

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

    [[ ! -f "$SSHD" ]] && return 0

    # Eliminar todas las directivas Banner anteriores
    sed -i \
        '/^[[:space:]]*#\?[[:space:]]*Banner[[:space:]]/d' \
        "$SSHD"

    # Agregar nuestro Banner
    echo "Banner $BANNER_ACTIVE" >> "$SSHD"
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_dropbear() {

    [[ ! -f "$DROPBEAR" ]] && return 0

    # Eliminar configuración anterior
    sed -i \
        '/^DROPBEAR_BANNER=/d' \
        "$DROPBEAR"

    # Agregar banner actual
    echo "DROPBEAR_BANNER=\"$BANNER_ACTIVE\"" >> "$DROPBEAR"
}

#==================================================
# LIMPIAR VARIABLES ANTIGUAS
#==================================================

limpiar_variables_checkuser() {

    local ARCHIVO="$1"

    [[ ! -f "$ARCHIVO" ]] && return 0

    sed -i \
        -e '/%USERNAME%/d' \
        -e '/%CONNECTIONS%/d' \
        -e '/%LIMIT%/d' \
        -e '/%EXPIRATION%/d' \
        -e '/%DAYS%/d' \
        "$ARCHIVO"
}

#==================================================
# ACTIVAR BANNER NORMAL
#==================================================

activar_banner() {

    local ARCHIVO="$1"

    if [[ ! -f "$ARCHIVO" ]]; then

        msg_error "El banner no existe."

        return 1

    fi

    #==================================================
    # IMPORTANTE:
    # El Banner SSH debe ser estático.
    # No colocamos variables dinámicas aquí.
    #==================================================

    limpiar_variables_checkuser "$ARCHIVO"

    cp -f "$ARCHIVO" "$BANNER_ACTIVE"

    chmod 644 "$BANNER_ACTIVE"

    configurar_openssh
    configurar_dropbear

    #==================================================
    # Comprobar configuración SSH antes de reiniciar
    #==================================================

    if command -v sshd >/dev/null 2>&1; then

        if ! sshd -t 2>/dev/null; then

            msg_error "La configuración de OpenSSH tiene un error."

            return 1

        fi

    fi

    reiniciar_servicios

    msg_ok "Banner activado correctamente."

    return 0
}

#==================================================
# CREAR CHECKUSER
#==================================================

crear_checkuser() {

    #==================================================
    # CheckUser YA NO SE METE EN /etc/issue.net
    #==================================================

    cat > "$CHECKUSER_SCRIPT" <<'EOF'
#!/bin/bash

#==================================================
# KevinTech CheckUser
# Datos dinámicos del usuario SSH
#==================================================

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

USER_NAME="${USER:-${LOGNAME:-}}"

[[ -z "$USER_NAME" ]] && exit 0

id "$USER_NAME" >/dev/null 2>&1 || exit 0

#==================================================
# OBTENER LÍMITE
#==================================================

LIMIT=$(
    awk -F: -v U="$USER_NAME" '
        $1 == U {
            print $2
            exit
        }
    ' "$LIMITS_FILE" 2>/dev/null
)

[[ -z "$LIMIT" ]] && LIMIT=0

#==================================================
# OBTENER IPs
#==================================================

IPS=$(
    who 2>/dev/null |
    awk -v U="$USER_NAME" '
        $1 == U {
            IP=$5
            gsub(/[()]/, "", IP)

            if (IP != "")
                print IP
        }
    ' |
    sort -u
)

#==================================================
# CONTAR IPs
#==================================================

if [[ -n "$IPS" ]]; then

    CONNECTIONS=$(
        printf '%s\n' "$IPS" |
        grep -c .
    )

else

    CONNECTIONS=0

fi

#==================================================
# EXPIRACIÓN
#==================================================

EXPIRATION=$(
    chage -l "$USER_NAME" 2>/dev/null |
    awk -F': ' '
        /Account expires/ {
            print $2
            exit
        }
    '
)

#==================================================
# CALCULAR DÍAS
#==================================================

if [[ -z "$EXPIRATION" ||
      "$EXPIRATION" == "never" ||
      "$EXPIRATION" == "Nunca" ]]; then

    EXPIRATION="Ilimitada"
    DAYS="∞"

else

    EXP_DATE=$(date -d "$EXPIRATION" +%s 2>/dev/null)
    NOW=$(date +%s)

    if [[ -n "$EXP_DATE" ]]; then

        DAYS=$(( (EXP_DATE - NOW) / 86400 ))

        (( DAYS < 0 )) && DAYS=0

        EXPIRATION=$(date \
            -d "$EXPIRATION" \
            +"%d/%m/%Y" \
            2>/dev/null)

    else

        EXPIRATION="N/D"
        DAYS="N/D"

    fi

fi

#==================================================
# LÍMITE MOSTRAR
#==================================================

if (( LIMIT == 0 )); then

    LIMIT_SHOW="♾"

else

    LIMIT_SHOW="$LIMIT"

fi

#==================================================
# MOSTRAR CHECKUSER
#==================================================

echo
echo "═══════════════════════════════════════════════════"
echo "                    CHECK USER"
echo "═══════════════════════════════════════════════════"
echo
echo "👤 Usuario        : $USER_NAME"
echo "🔌 Conexiones     : $CONNECTIONS/$LIMIT_SHOW"
echo "📅 Expiración     : $EXPIRATION"
echo "⏳ Días restantes : $DAYS"
echo
echo "═══════════════════════════════════════════════════"
echo

exit 0
EOF

    chmod 755 "$CHECKUSER_SCRIPT"

    #==================================================
    # ARCHIVO PARA VISUALIZACIÓN
    #==================================================

    cat > "$BANNER_CHECKUSER" <<'EOF'
#==================================================
# CHECK USER DINÁMICO
#
# Este archivo NO se utiliza como /etc/issue.net.
#
# El Banner SSH es estático.
# Los datos del usuario se generan dinámicamente
# mediante:
#
# /usr/local/bin/kevintech-checkuser
#==================================================
EOF

    chmod 644 "$BANNER_CHECKUSER"

    msg_ok "CheckUser dinámico preparado."

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
    echo -e "${GRAY}Cuando termines escribe FIN en una línea nueva.${RESET}"
    echo

    local TEMP
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

    #==================================================
    # LIMPIAR VARIABLES VIEJAS
    #==================================================

    limpiar_variables_checkuser "$TEMP"

    #==================================================
    # GUARDAR
    #==================================================

    cp -f "$TEMP" "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    rm -f "$TEMP"

    msg_ok "Banner Normal guardado."

    echo

    #==================================================
    # CHECKUSER
    #==================================================

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas activar CheckUser dinámico? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser

            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"
            rm -f "$CHECKUSER_SCRIPT"

            msg_ok "CheckUser desactivado."

            ;;

        *)

            rm -f "$BANNER_CHECKUSER"
            rm -f "$CHECKUSER_SCRIPT"

            msg_warn "Respuesta inválida. CheckUser desactivado."

            ;;

    esac

    echo

    activar_banner "$BANNER_NORMAL"

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
    # CREAR BANNER
    #==================================================

    cat > "$BANNER_NORMAL" <<EOF
═══════════════════════════════════════════════════
              $SERVER ★
═══════════════════════════════════════════════════

$PROMO

📢 Canal   : $CHANNEL
👤 Soporte : $SUPPORT

═══════════════════════════════════════════════════
       Gracias por usar nuestros servicios
═══════════════════════════════════════════════════
EOF

    chmod 644 "$BANNER_NORMAL"

    msg_ok "Banner Normal creado."

    echo

    #==================================================
    # CHECKUSER
    #==================================================

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas activar CheckUser dinámico? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            crear_checkuser

            ;;

        n|N|no|NO)

            rm -f "$BANNER_CHECKUSER"
            rm -f "$CHECKUSER_SCRIPT"

            msg_ok "Plantilla sin CheckUser."

            ;;

        *)

            rm -f "$BANNER_CHECKUSER"
            rm -f "$CHECKUSER_SCRIPT"

            msg_warn "Respuesta inválida. CheckUser desactivado."

            ;;

    esac

    echo

    activar_banner "$BANNER_NORMAL"

    sleep 2
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

    echo -e "${YELLOW}══════════ CHECKUSER ══════════${RESET}"
    echo

    if [[ -x "$CHECKUSER_SCRIPT" ]]; then

        echo -e "${GREEN}✔ CheckUser dinámico instalado${RESET}"
        echo
        echo -e "${GRAY}Archivo:${RESET} $CHECKUSER_SCRIPT"

    else

        echo -e "${GRAY}CheckUser dinámico no instalado.${RESET}"

    fi

    echo

    pausa
}

#==================================================
# EDITAR BANNER
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

    #==================================================
    # ELIMINAR VARIABLES ANTIGUAS
    #==================================================

    limpiar_variables_checkuser "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    #==================================================
    # RECREAR CHECKUSER
    #==================================================

    if [[ -x "$CHECKUSER_SCRIPT" ]]; then

        crear_checkuser

    fi

    #==================================================
    # ACTIVAR
    #==================================================

    activar_banner "$BANNER_NORMAL"

    msg_ok "Banner actualizado."

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
        echo -e "${MAGENTA}[2]${WHITE} Eliminar CheckUser"
        echo -e "${CYAN}[0]${WHITE} Regresar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OP

        case "$OP" in

            #==================================================
            # NORMAL
            #==================================================

            1)

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar Banner Normal? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_NORMAL"
                        rm -f "$BANNER_CHECKUSER"
                        rm -f "$BANNER_ACTIVE"

                        if [[ -f "$SSHD" ]]; then

                            sed -i \
                                '/^[[:space:]]*#\?[[:space:]]*Banner[[:space:]]/d' \
                                "$SSHD"

                        fi

                        if [[ -f "$DROPBEAR" ]]; then

                            sed -i \
                                '/^DROPBEAR_BANNER=/d' \
                                "$DROPBEAR"

                        fi

                        reiniciar_servicios

                        msg_ok "Banner eliminado."

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

                echo

                read -rp \
                    "$(echo -e "${YELLOW}¿Eliminar CheckUser? [S/N]: ${RESET}")" RESP

                case "$RESP" in

                    s|S|si|SI|sí|Sí)

                        rm -f "$BANNER_CHECKUSER"
                        rm -f "$CHECKUSER_SCRIPT"

                        msg_ok "CheckUser eliminado."

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
            pegar_banner
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