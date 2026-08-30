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

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==================================================
# ARCHIVOS
#==================================================

BANNER_NORMAL="$BASE/banner_normal"
BANNER_CHECKUSER="$BASE/banner_checkuser"

# Banner SSH tradicional
BANNER="/etc/issue.net"

SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

LIMITS_FILE="$BASE/limits.conf"

mkdir -p "$BASE"

touch "$LIMITS_FILE"

chmod 600 "$LIMITS_FILE"

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
# CONFIGURAR BANNER SSH
#==================================================

configurar_banner_ssh() {

    if grep -qE '^[[:space:]]*Banner[[:space:]]+' "$SSHD"; then

        sed -i \
            "s|^[[:space:]]*Banner[[:space:]].*|Banner $BANNER|" \
            "$SSHD"

    else

        echo "Banner $BANNER" >> "$SSHD"

    fi
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configurar_banner_dropbear() {

    if [[ ! -f "$DROPBEAR" ]]; then
        return
    fi

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" \
            "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"

    fi
}

#==================================================
# REINICIAR SERVICIOS
#==================================================

reiniciar_ssh() {

    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null
}

#==================================================
# COPIAR BANNER NORMAL
#==================================================

aplicar_banner_normal() {

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "No existe un Banner normal."

        return 1
    fi

    cp -f "$BANNER_NORMAL" "$BANNER"

    chmod 644 "$BANNER"

    configurar_banner_ssh
    configurar_banner_dropbear

    reiniciar_ssh
}

#==================================================
# CREAR SCRIPT CHECKUSER
#
# ESTE ARCHIVO NO SE EDITA DESDE EL MENÚ.
#==================================================

crear_checkuser() {

    mkdir -p "$BASE"

    cat > "$BANNER_CHECKUSER" <<'CHECKEOF'
#!/bin/bash

#==================================================
# KevinTech CheckUser
# Independiente de checkgestor
#==================================================

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

USER_NAME="${USER:-$(id -un 2>/dev/null)}"

#----------------------------------------------
# Verificar usuario
#----------------------------------------------

[[ -z "$USER_NAME" ]] && exit 0

#----------------------------------------------
# Obtener fecha de expiración
#----------------------------------------------

EXPIRACION="N/D"

if command -v chage >/dev/null 2>&1; then

    EXPIRACION=$(chage -l "$USER_NAME" 2>/dev/null |
        awk -F': ' '/Account expires/ {
            print $2
        }')

fi

[[ -z "$EXPIRACION" ]] &&
    EXPIRACION="N/D"

#----------------------------------------------
# Convertir fecha a formato
#----------------------------------------------

EXP_NUM="N/D"
DIAS="N/D"

if [[ "$EXPIRACION" != "N/D" &&
      "$EXPIRACION" != "never" &&
      "$EXPIRACION" != "Nunca" ]]; then

    EXP_TIMESTAMP=$(date -d "$EXPIRACION" +%s 2>/dev/null)
    NOW_TIMESTAMP=$(date +%s)

    if [[ "$EXP_TIMESTAMP" =~ ^[0-9]+$ ]]; then

        DIAS=$(( (EXP_TIMESTAMP - NOW_TIMESTAMP) / 86400 ))

        (( DIAS < 0 )) && DIAS=0

        EXP_NUM=$(date -d "$EXPIRACION" +"%d/%m/%Y" 2>/dev/null)

    fi

else

    EXP_NUM="Ilimitado"
    DIAS="Ilimitado"

fi

#----------------------------------------------
# Obtener límite
#----------------------------------------------

LIMITE="0"

if [[ -f "$LIMITS_FILE" ]]; then

    LIMITE=$(
        awk -F: -v user="$USER_NAME" '
            $1 == user {
                print $2
                exit
            }
        ' "$LIMITS_FILE"
    )

fi

[[ -z "$LIMITE" ]] && LIMITE=0

if [[ "$LIMITE" == "0" ]]; then

    LIMITE_MOSTRAR="Ilimitado"

elif [[ "$LIMITE" == "1" ]]; then

    LIMITE_MOSTRAR="1 IP"

else

    LIMITE_MOSTRAR="${LIMITE} IPs"

fi

#----------------------------------------------
# Mostrar CheckUser
#----------------------------------------------

printf '\n'
printf '\033[1;96m╔════════════════════════════════════════════════════╗\033[0m\n'
printf '\033[1;96m║\033[1;95m                 CHECKUSER                         \033[1;96m║\033[0m\n'
printf '\033[1;96m╠════════════════════════════════════════════════════╣\033[0m\n'

printf '\033[1;97m║ Usuario      : \033[1;92m%-30s\033[1;96m║\033[0m\n' "$USER_NAME"
printf '\033[1;97m║ Días         : \033[1;92m%-30s\033[1;96m║\033[0m\n' "$DIAS"
printf '\033[1;97m║ Límite       : \033[1;92m%-30s\033[1;96m║\033[0m\n' "$LIMITE_MOSTRAR"
printf '\033[1;97m║ Expiración   : \033[1;92m%-30s\033[1;96m║\033[0m\n' "$EXP_NUM"

printf '\033[1;96m╚════════════════════════════════════════════════════╝\033[0m\n'
printf '\n'

exit 0
CHECKEOF

    chmod 755 "$BANNER_CHECKUSER"

    msg_ok "Módulo CheckUser generado."
}

#==================================================
# INSTALAR CHECKUSER EN SSH
#
# Se usa ~/.ssh/rc de cada usuario.
# No depende de checkgestor.
#==================================================

activar_checkuser_ssh() {

    crear_checkuser

    local RC="/etc/ssh/sshrc"

    cat > "$RC" <<'SSHRCEOF'
#!/bin/bash

#==================================================
# KevinTech SSHRC
# Banner CheckUser
#==================================================

CHECKUSER="/etc/kevintech/banner_checkuser"

if [[ -x "$CHECKUSER" ]]; then

    "$CHECKUSER"

fi

exit 0
SSHRCEOF

    chmod 755 "$RC"

    msg_ok "CheckUser activado para las sesiones SSH."

    configurar_banner_ssh
    configurar_banner_dropbear

    reiniciar_ssh
}

#==================================================
# DESACTIVAR CHECKUSER
#
# NO BORRA EL CHECKUSER.
# Solamente deja de mostrarlo.
#==================================================

desactivar_checkuser() {

    local RC="/etc/ssh/sshrc"

    if [[ -f "$RC" ]]; then

        if grep -q "KevinTech SSHRC" "$RC"; then

            rm -f "$RC"

        fi

    fi

}

#==================================================
# TÍTULO
#==================================================

titulo() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢            ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

}

#==================================================
# MENÚ
#==================================================

while true; do

    titulo

    echo
    echo -e "${GREEN}[1]${WHITE} Crear Banner normal"
    echo -e "${BLUE}[2]${WHITE} Crear Banner CheckUser"
    echo -e "${CYAN}[3]${WHITE} Ver Banner actual"
    echo -e "${YELLOW}[4]${WHITE} Editar Banner"
    echo -e "${RED}[5]${WHITE} Eliminar banner"
    echo -e "${CYAN}[0]${WHITE} Regresar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

#==================================================
# 1 CREAR BANNER NORMAL
#==================================================

1)

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

    read -rp "$(echo -e "${GREEN}Canal Telegram (ej. @KevinTech):${RESET} ")" CHANNEL

    read -rp "$(echo -e "${GREEN}Soporte (ej. @KevinSupport):${RESET} ")" SUPPORT

    #----------------------------------------------
    # Guardar Banner Normal
    #----------------------------------------------

    cat > "$BANNER_NORMAL" <<EOF
<html>

<center>

<font color="#00ff00"><b>$SERVER</b></font><br>
<font color="#29b6f6">══════════════════════</font><br><br>

<font color="#ffffff">$PROMO</font><br><br>

<font color="#ffff00">📢 Canal: $CHANNEL</font><br>
<font color="#00ffff">👤 Soporte: $SUPPORT</font><br><br>

<font color="#29b6f6">══════════════════════</font><br>
<font color="#00ff00">Gracias por usar nuestros servicios</font>

</center>

</html>
EOF

    chmod 644 "$BANNER_NORMAL"

    #----------------------------------------------
    # Aplicar Banner Normal
    #----------------------------------------------

    aplicar_banner_normal

    echo

    msg_ok "Banner normal creado correctamente."

    sleep 2

;;

#==================================================
# 2 CREAR / ACTIVAR CHECKUSER
#==================================================

2)

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              BANNER CHECKUSER                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    #----------------------------------------------
    # Verificar Banner Normal
    #----------------------------------------------

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        msg_error "Primero debes crear el Banner normal."

        echo
        read -rp "Presione ENTER para continuar..."

        continue

    fi

    #----------------------------------------------
    # Crear CheckUser
    #----------------------------------------------

    crear_checkuser

    #----------------------------------------------
    # Activar
    #----------------------------------------------

    activar_checkuser_ssh

    echo

    echo -e "${GREEN}✔ Banner CheckUser activado.${RESET}"

    echo

    echo -e "${WHITE}El CheckUser mostrará automáticamente:${RESET}"
    echo -e " ${GREEN}•${WHITE} Usuario"
    echo -e " ${GREEN}•${WHITE} Días restantes"
    echo -e " ${GREEN}•${WHITE} Límite"
    echo -e " ${GREEN}•${WHITE} Expiración número"

    echo

    echo -e "${GRAY}El CheckUser no se puede editar ni eliminar desde este menú.${RESET}"

    sleep 4

;;

#==================================================
# 3 VER BANNER ACTUAL
#==================================================

3)

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 BANNER ACTUAL                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    #----------------------------------------------
    # Banner Normal
    #----------------------------------------------

    if [[ -f "$BANNER_NORMAL" ]]; then

        echo -e "${GREEN}══════════ BANNER NORMAL ══════════${RESET}"

        echo

        cat "$BANNER_NORMAL"

        echo

    else

        echo -e "${RED}No existe Banner normal.${RESET}"

    fi

    echo

    #----------------------------------------------
    # Estado CheckUser
    #----------------------------------------------

    if [[ -f "$BANNER_CHECKUSER" ]]; then

        echo -e "${GREEN}══════════ CHECKUSER ══════════${RESET}"

        if [[ -f "/etc/ssh/sshrc" ]] &&
           grep -q "KevinTech SSHRC" /etc/ssh/sshrc; then

            echo -e "${GREEN}Estado: ACTIVADO${RESET}"

        else

            echo -e "${YELLOW}Estado: CREADO PERO NO ACTIVADO${RESET}"

        fi

        echo
        echo -e "${GRAY}El CheckUser es generado automáticamente.${RESET}"

    else

        echo -e "${GRAY}CheckUser: No creado${RESET}"

    fi

    echo

    read -n1 -s -r -p "Presione cualquier tecla para regresar..."

;;

#==================================================
# 4 EDITAR BANNER NORMAL
#==================================================

4)

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 EDITAR BANNER                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${GREEN}Solo se puede editar el Banner normal.${RESET}"
    echo -e "${GRAY}El Banner CheckUser está protegido.${RESET}"

    echo

    #----------------------------------------------
    # Crear Banner si no existe
    #----------------------------------------------

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        cat > "$BANNER_NORMAL" <<EOF
<html>

<center>

<font color="#00ff00"><b>${SERVER_NAME:-KevinTech VPN}</b></font><br>
<font color="#ffffff">Bienvenido a nuestro servidor</font>

</center>

</html>
EOF

    fi

    #----------------------------------------------
    # Nano
    #----------------------------------------------

    if ! command -v nano >/dev/null 2>&1; then

        msg_error "Nano no está instalado."

        sleep 2

        continue

    fi

    #----------------------------------------------
    # Editar Banner Normal
    #----------------------------------------------

    nano "$BANNER_NORMAL"

    chmod 644 "$BANNER_NORMAL"

    #----------------------------------------------
    # Aplicar
    #----------------------------------------------

    aplicar_banner_normal

    echo

    msg_ok "Banner normal actualizado correctamente."

    sleep 2

;;

#==================================================
# 5 ELIMINAR BANNER
#==================================================

5)

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}               ELIMINAR BANNER                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}Esta opción elimina solamente el Banner normal.${RESET}"
    echo -e "${GRAY}El CheckUser no será eliminado.${RESET}"

    echo

    if [[ ! -f "$BANNER_NORMAL" ]]; then

        echo -e "${RED}No existe ningún Banner normal.${RESET}"

        sleep 2

        continue

    fi

    read -rp "$(echo -e "${YELLOW}¿Desea eliminar el Banner normal? [S/N]: ${RESET}")" RESP

    case "$RESP" in

        s|S|si|SI|Sí|sí)

            #--------------------------------------
            # Eliminar Banner Normal
            #--------------------------------------

            rm -f "$BANNER_NORMAL"

            #--------------------------------------
            # Crear Banner vacío
            # para evitar errores de SSH
            #--------------------------------------

            : > "$BANNER"

            chmod 644 "$BANNER"

            #--------------------------------------
            # Quitar Banner de OpenSSH
            #--------------------------------------

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

            #--------------------------------------
            # Quitar Dropbear
            #--------------------------------------

            if [[ -f "$DROPBEAR" ]]; then

                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"

            fi

            #--------------------------------------
            # IMPORTANTE:
            #
            # NO eliminar BANNER_CHECKUSER
            #--------------------------------------

            echo

            msg_ok "Banner normal eliminado."

            echo
            echo -e "${GRAY}El módulo CheckUser permanece protegido.${RESET}"

            reiniciar_ssh

        ;;

        *)

            echo
            echo -e "${YELLOW}Operación cancelada.${RESET}"

        ;;

    esac

    sleep 2

;;

#==================================================
# 0 REGRESAR
#==================================================

0)

    break

;;

#==================================================
# OPCIÓN INVÁLIDA
#==================================================

*)

    echo

    echo -e "${RED}Opción inválida.${RESET}"

    sleep 2

;;

esac

done