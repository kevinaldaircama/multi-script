#!/bin/bash      
#==================================================      
# KevinTech Multi Script      
# Módulo: Banner SSH / Dropbear      
# Banner Normal + CheckUser      
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
      
# Banner que realmente utilizarán SSH y Dropbear      
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
      
    [[ ! -f "$SSHD" ]] && return 0      
      
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
      
    [[ ! -f "$DROPBEAR" ]] && return 0      
      
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
      
    return 0      
}      
      
#==================================================      
# ACTIVAR AUTOMÁTICAMENTE      
# BANNER NORMAL + CHECKUSER      
#==================================================      
      
activar_banner_actual() {      
      
    # Si existe CheckUser, utilizarlo.      
    if [[ -f "$BANNER_CHECKUSER" ]]; then      
      
        if activar_banner "$BANNER_CHECKUSER"; then      
      
            msg_ok "Banner Normal + CheckUser activado."      
            return 0      
      
        fi      
      
    fi      
      
    # Si no existe CheckUser,      
    # utilizar únicamente Banner Normal.      
    if [[ -f "$BANNER_NORMAL" ]]; then      
      
        if activar_banner "$BANNER_NORMAL"; then      
      
            msg_ok "Banner Normal activado."      
            return 0      
      
        fi      
      
    fi      
      
    msg_error "No existe ningún banner para activar."      
      
    return 1      
}      
      
#==================================================      
# CREAR CHECKUSER      
#==================================================      
      
crear_checkuser() {      
      
    if [[ ! -f "$BANNER_NORMAL" ]]; then      
      
        msg_error "Primero debes crear el Banner Normal."      
      
        return 1      
      
    fi      
      
    #==================================================      
    # COPIAR BANNER NORMAL      
    #==================================================      
      
    cp -f "$BANNER_NORMAL" "$BANNER_CHECKUSER"      
      
    #==================================================      
    # AGREGAR CHECKUSER DEBAJO      
    #==================================================      
      
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
      
    return 0      
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
    # GUARDAR BANNER NORMAL      
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
        "$(echo -e "${YELLOW}¿Deseas incluir CheckUser? [S/N]: ${RESET}")" RESP      
      
    case "$RESP" in      
      
        s|S|si|SI|sí|Sí)      
      
            if crear_checkuser; then      
      
                echo      
                activar_banner_actual      
      
            fi      
      
            ;;      
      
        n|N|no|NO)      
      
            rm -f "$BANNER_CHECKUSER"      
      
            msg_ok "Banner creado sin CheckUser."      
      
            echo      
      
            activar_banner_actual      
      
            ;;      
      
        *)      
      
            rm -f "$BANNER_CHECKUSER"      
      
            msg_warn "Respuesta inválida. Se creó sin CheckUser."      
      
            echo      
      
            activar_banner_actual      
      
            ;;      
      
    esac      
      
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
      
            if crear_checkuser; then      
      
                echo      
                activar_banner_actual      
      
            fi      
      
            ;;      
      
        n|N|no|NO)      
      
            rm -f "$BANNER_CHECKUSER"      
      
            msg_ok "Plantilla sin CheckUser."      
      
            echo      
      
            activar_banner_actual      
      
            ;;      
      
        *)      
      
            rm -f "$BANNER_CHECKUSER"      
      
            msg_warn "Respuesta inválida. Se creó sin CheckUser."      
      
            echo      
      
            activar_banner_actual      
      
            ;;      
      
    esac      
      
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
# EDITAR BANNER NORMAL      
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
      
    #==================================================      
    # REGENERAR CHECKUSER      
    #==================================================      
      
    if [[ -f "$BANNER_CHECKUSER" ]]; then      
      
        crear_checkuser >/dev/null      
      
        msg_ok "Banner CheckUser actualizado."      
      
    fi      
      
    #==================================================      
    # ACTIVAR      
    #==================================================      
      
    activar_banner_actual      
      
    echo      
      
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
        echo -e "${MAGENTA}[2]${WHITE} Eliminar Banner CheckUser"      
        echo -e "${CYAN}[0]${WHITE} Regresar"      
      
        echo      
      
        read -rp \      
            "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OP      
      
        case "$OP" in      
      
            #==================================================      
            # ELIMINAR NORMAL      
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
                        rm -f "$BANNER_CHECKUSER"      
                        rm -f "$BANNER_ACTIVE"      
      
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
      
                        reiniciar_servicios      
      
                        msg_ok "Todos los banners fueron eliminados."      
      
                        ;;      
      
                    *)      
      
                        msg_warn "Operación cancelada."      
      
                        ;;      
      
                esac      
      
                sleep 2      
                ;;      
      
            #==================================================      
            # ELIMINAR CHECKUSER      
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
      
                        # Volver automáticamente      
                        # al Banner Normal      
      
                        if [[ -f "$BANNER_NORMAL" ]]; then      
      
                            activar_banner "$BANNER_NORMAL"      
      
                            msg_ok "Banner Normal restaurado."      
      
                        fi      
      
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