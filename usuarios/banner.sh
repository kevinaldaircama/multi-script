#!/bin/bash
# KEVINTECH PER-USER BANNER MANAGER
# Usuarios exclusivamente desde /etc/kevintech/limits.conf
# No usa banner global /etc/issue.net

set -u

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"
CONFIG="$BASE/config.conf"
BANNER_DIR="/etc/ssh_banners"
SSHD_CONFIG="/etc/ssh/sshd_config"
START_MARK="# >>> KEVINTECH_PER_USER_BANNERS_START <<<"
END_MARK="# >>> KEVINTECH_PER_USER_BANNERS_END <<<"
BACKUP_DIR="$BASE/banner-backups"

# COLORES
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

[[ $EUID -eq 0 ]] || { echo -e "${RED}Ejecuta como root.${RESET}"; exit 1; }

mkdir -p "$BANNER_DIR" "$BACKUP_DIR"
chmod 700 "$BANNER_DIR"

pause(){ echo; read -rp "Presiona ENTER para continuar..."; }

header(){
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}       KEVINTECH PER-USER BANNER MANAGER          ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${GRAY}Usuarios: $LIMITS_FILE${RESET}"
    echo -e "${GRAY}Banners : $BANNER_DIR${RESET}"
    echo
}

load_config(){
    if [[ -f "$CONFIG" ]]; then
        set +u
        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null || true
        set -u
    fi
}
load_config

get_users(){
    [[ -f "$LIMITS_FILE" ]] || return 0
    awk -F: 'NF>=1 && $1!="" && $1 !~ /^[[:space:]]*#/ && $1 ~ /^[a-zA-Z0-9._-]+$/ {print $1}' "$LIMITS_FILE" | sort -u
}

user_exists(){
    local u="$1"
    [[ -f "$LIMITS_FILE" ]] && awk -F: -v u="$u" '$1==u{ok=1;exit} END{exit !ok}' "$LIMITS_FILE"
}

get_limit(){
    local u="$1" v
    v="$(awk -F: -v u="$u" '$1==u{print $2;exit}' "$LIMITS_FILE" 2>/dev/null || true)"
    [[ -n "$v" ]] && echo "$v" || echo "1"
}

get_expire(){
    local u="$1" v
    v="$(chage -l "$u" 2>/dev/null | awk -F: '/Account expires/{gsub(/^[ \t]+/,"",$2);print $2;exit}' || true)"
    [[ -n "$v" ]] && echo "$v" || echo "Nunca"
}

get_days(){
    local u="$1" exp ts now d
    exp="$(get_expire "$u")"
    [[ "$exp" == "Nunca" || "$exp" == "never" || "$exp" == "Never" ]] && { echo "Ilimitado"; return; }
    ts="$(date -d "$exp 23:59:59" +%s 2>/dev/null || true)"
    [[ -z "$ts" ]] && { echo "Desconocido"; return; }
    now="$(date +%s)"
    d=$(( (ts-now)/86400 ))
    ((d<0)) && echo "EXPIRADO" || echo "$d"
}

get_connected(){
    local u="$1" total ips
    total="$(who 2>/dev/null | awk -v u="$u" '$1==u{n++}END{print n+0}')"
    ips="$(who 2>/dev/null | awk -v u="$u" '$1==u && $5~/^\(/ {gsub(/[()]/,"",$5);print $5}' | sort -u | paste -sd, -)"
    [[ -z "$ips" ]] && ips="Sin conexión"
    echo "$total|$ips"
}

html_escape(){
    local s="${1:-}"
    s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"
    s="${s//\"/&quot;}"; s="${s//\'/&#39;}"
    printf '%s' "$s"
}

banner_type(){
    local u="$1" f="$BANNER_DIR/$u.banner"
    [[ -f "$f" ]] || { echo "Ninguno"; return; }
    grep -q 'data-kevintech-type="custom"' "$f" && { echo "Personalizado"; return; }
    grep -q 'data-kevintech-type="template"' "$f" && {
        sed -n 's/.*data-kevintech-template="\([^"]*\)".*/\1/p' "$f" | head -1
        return
    }
    echo "Configurado"
}

show_user_data(){
    local u="$1" c total ips
    c="$(get_connected "$u")"; total="${c%%|*}"; ips="${c#*|}"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${RESET}"
    echo -e "${WHITE}│ Usuario        : ${GREEN}$u${RESET}"
    echo -e "${WHITE}│ Expiración     : ${YELLOW}$(get_expire "$u")${RESET}"
    echo -e "${WHITE}│ Días restantes : ${YELLOW}$(get_days "$u")${RESET}"
    echo -e "${WHITE}│ Límite IP      : ${YELLOW}$(get_limit "$u")${RESET}"
    echo -e "${WHITE}│ Conectados     : ${GREEN}$total${RESET}"
    echo -e "${WHITE}│ IP(s)          : ${GRAY}$ips${RESET}"
    echo -e "${WHITE}│ Banner         : ${MAGENTA}$(banner_type "$u")${RESET}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${RESET}"
}

select_user(){
    local prompt="${1:-Seleccionar usuario}" u
    [[ -n "$(get_users)" ]] || { echo -e "${RED}No hay usuarios en $LIMITS_FILE.${RESET}"; return 1; }
    echo -e "${CYAN}$prompt${RESET}"; echo
    get_users | nl -w2 -s') '; echo
    read -rp "Usuario: " u
    user_exists "$u" || { echo -e "${RED}Usuario no encontrado en $LIMITS_FILE.${RESET}"; return 1; }
    SELECTED_USER="$u"
}

generate_banner(){
    local u="$1" title="$2" text="$3" template="$4" c total ips
    local expire days limit promo channel support bot
    expire="$(get_expire "$u")"; days="$(get_days "$u")"; limit="$(get_limit "$u")"
    c="$(get_connected "$u")"; total="${c%%|*}"; ips="${c#*|}"
    set +u
    promo="${BANNER_PROMO_TEXT:-}"; channel="${BANNER_PROMO_CHANNEL:-}"
    support="${BANNER_PROMO_SUPPORT:-}"; bot="${BANNER_PROMO_BOT_NAME:-}"
    set -u
    u="$(html_escape "$u")"; title="$(html_escape "$title")"; text="$(html_escape "$text")"
    expire="$(html_escape "$expire")"; days="$(html_escape "$days")"; limit="$(html_escape "$limit")"; ips="$(html_escape "$ips")"
    promo="$(html_escape "$promo")"; channel="$(html_escape "$channel")"; support="$(html_escape "$support")"; bot="$(html_escape "$bot")"

    cat <<EOF
<!-- data-kevintech-type="$([[ "$template" == "PERSONALIZADO" ]] && echo custom || echo template)" data-kevintech-template="$(html_escape "$template")" -->
<html><head><meta charset="UTF-8"><title>KevinTech - $u</title></head><body><center>
<font size="5"><b>$title</b></font><br><br>
<b>╔══════════════════════════════════════╗</b><br>
<b>║          CUENTA SSH KEVINTECH        ║</b><br>
<b>╠══════════════════════════════════════╣</b><br>
<b>║ Usuario        :</b> $u<br>
<b>║ Expiración     :</b> $expire<br>
<b>║ Días restantes :</b> $days<br>
<b>║ Límite IP      :</b> $limit<br>
<b>║ Conectados     :</b> $total<br>
<b>║ IP(s)          :</b> $ips<br>
<b>╚══════════════════════════════════════╝</b><br>
EOF

    [[ -n "$text" ]] && { echo "<br><b>$text</b><br>"; }
    case "$template" in
        CLASICA) echo "<br><b>KEVINTECH SSH</b><br>Gracias por utilizar nuestro servicio.<br>" ;;
        PREMIUM) echo "<br><b>★ KEVINTECH PREMIUM ★</b><br>Servicio activo y administrado por KevinTech.<br>" ;;
        MINIMAL) echo "<br><b>KEVINTECH</b><br>Cuenta autorizada.<br>" ;;
    esac
    [[ -n "$promo" ]] && echo "<br><b>$promo</b><br>"
    [[ -n "$channel" ]] && echo "<b>Canal:</b> $channel<br>"
    [[ -n "$support" ]] && echo "<b>Soporte:</b> $support<br>"
    [[ -n "$bot" ]] && echo "<b>Bot:</b> $bot<br>"
    echo "</center></body></html>"
}

choose_template(){
    echo; echo -e "${CYAN}Elige plantilla:${RESET}"
    echo -e "${WHITE}[1]${RESET} CLASICA"
    echo -e "${WHITE}[2]${RESET} PREMIUM"
    echo -e "${WHITE}[3]${RESET} MINIMAL"
    echo -e "${WHITE}[0]${RESET} Cancelar"; echo
    local o; read -rp "Opción: " o
    case "$o" in 1) echo CLASICA;;2) echo PREMIUM;;3) echo MINIMAL;;*) return 1;;esac
}

write_banner(){
    local u="$1" title="$2" text="$3" template="$4" f="$BANNER_DIR/$1.banner"
    generate_banner "$u" "$title" "$text" "$template" > "$f"
    chmod 644 "$f"; chown root:root "$f"
    echo -e "${GREEN}Banner guardado: $f${RESET}"
}

backup_sshd(){
    cp -a "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
}

remove_blocks(){
    [[ -f "$SSHD_CONFIG" ]] || return
    awk -v s="$START_MARK" -v e="$END_MARK" '$0==s{in=1;next}$0==e{in=0;next}!in{print}' "$SSHD_CONFIG" > "$SSHD_CONFIG.tmp"
    mv "$SSHD_CONFIG.tmp" "$SSHD_CONFIG"
}

sync_sshd(){
    local u f
    backup_sshd; remove_blocks
    {
        echo; echo "$START_MARK"
        while IFS= read -r u; do
            [[ -z "$u" ]] && continue
            f="$BANNER_DIR/$u.banner"
            [[ -f "$f" ]] || continue
            echo "Match User $u"
            echo "    Banner $f"
            echo
        done < <(get_users)
        echo "$END_MARK"
    } >> "$SSHD_CONFIG"

    if command -v sshd >/dev/null 2>&1 && ! sshd -t 2>/tmp/kevintech_sshd_error; then
        echo -e "${RED}Error en sshd_config:${RESET}"; cat /tmp/kevintech_sshd_error
        return 1
    fi
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
    echo -e "${GREEN}SSH sincronizado correctamente.${RESET}"
}

install_banner(){
    header
    select_user "Instalar banner para" || { pause; return; }
    local u="$SELECTED_USER" mode title text template
    echo; show_user_data "$u"; echo
    echo -e "${CYAN}[1]${RESET} Banner personalizado"
    echo -e "${CYAN}[2]${RESET} Elegir plantilla"
    echo -e "${CYAN}[0]${RESET} Cancelar"; echo
    read -rp "Opción: " mode
    case "$mode" in
        1)
            read -rp "Título: " title; [[ -z "$title" ]] && title="KEVINTECH SSH"
            echo "Escribe el banner. Termina con FINBANNER:"
            text=""
            while IFS= read -r line; do
                [[ "$line" == FINBANNER ]] && break
                [[ -n "$text" ]] && text+=$'\n'; text+="$line"
            done
            write_banner "$u" "$title" "$text" "PERSONALIZADO"; sync_sshd ;;
        2)
            template="$(choose_template)" || { pause; return; }
            write_banner "$u" "KEVINTECH $template" "" "$template"; sync_sshd ;;
        *) ;;
    esac
    pause
}

view_banner(){
    header
    select_user "Ver banner de" || { pause; return; }
    local u="$SELECTED_USER" f="$BANNER_DIR/$SELECTED_USER.banner"
    echo; show_user_data "$u"; echo
    [[ -f "$f" ]] || { echo -e "${YELLOW}No tiene banner instalado.${RESET}"; pause; return; }
    echo -e "${CYAN}━━━━━━━━━━━━ BANNER DE $u ━━━━━━━━━━━━${RESET}"; echo
    sed '/^<!-- data-kevintech-/d' "$f"
    echo; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    pause
}

delete_banner(){
    header
    select_user "Eliminar banner de" || { pause; return; }
    local u="$SELECTED_USER" f="$BANNER_DIR/$SELECTED_USER.banner" ans
    echo; show_user_data "$u"; echo
    [[ -f "$f" ]] || { echo -e "${YELLOW}No tiene banner instalado.${RESET}"; pause; return; }
    read -rp "¿Eliminar banner $(banner_type "$u")? [s/N]: " ans
    [[ "$ans" =~ ^[sS]$ ]] || { echo "Cancelado."; pause; return; }
    rm -f "$f"; sync_sshd
    echo -e "${GREEN}Banner eliminado.${RESET}"; pause
}

edit_banner(){
    header
    select_user "Editar banner de" || { pause; return; }
    local u="$SELECTED_USER" f="$BANNER_DIR/$SELECTED_USER.banner" mode title text template
    echo; show_user_data "$u"; echo
    [[ -f "$f" ]] || { echo -e "${YELLOW}No tiene banner. Usa [1] para instalarlo.${RESET}"; pause; return; }
    echo -e "${WHITE}[1]${RESET} Editar personalizado"
    echo -e "${WHITE}[2]${RESET} Cambiar plantilla"
    echo -e "${WHITE}[0]${RESET} Cancelar"; echo
    read -rp "Opción: " mode
    case "$mode" in
        1)
            read -rp "Nuevo título: " title; [[ -z "$title" ]] && title="KEVINTECH SSH"
            echo "Escribe el nuevo banner. Termina con FINBANNER:"
            text=""
            while IFS= read -r line; do
                [[ "$line" == FINBANNER ]] && break
                [[ -n "$text" ]] && text+=$'\n'; text+="$line"
            done
            write_banner "$u" "$title" "$text" "PERSONALIZADO"; sync_sshd
            ;;
        2)
            template="$(choose_template)" || { pause; return; }
            write_banner "$u" "KEVINTECH $template" "" "$template"; sync_sshd
            ;;
    esac
    echo -e "${GREEN}Banner actualizado.${RESET}"; pause
}

while true; do
    header
    echo -e "${GREEN}[1]${RESET} Instalar banner"
    echo -e "    ${GRAY}└─ Pedir banner personalizado o elegir plantilla${RESET}"
    echo
    echo -e "${GREEN}[2]${RESET} Ver banner"
    echo -e "    ${GRAY}└─ Ver banner personalizado o plantilla${RESET}"
    echo
    echo -e "${GREEN}[3]${RESET} Eliminar banner"
    echo -e "    ${GRAY}└─ Eliminar banner personalizado o plantilla${RESET}"
    echo
    echo -e "${GREEN}[4]${RESET} Editar banner"
    echo -e "    ${GRAY}└─ Editar personalizado o cambiar plantilla${RESET}"
    echo
    echo -e "${RED}[0]${RESET} Salir"
    echo
    read -rp "Selecciona una opción: " OPTION
    case "$OPTION" in
        1) install_banner;;
        2) view_banner;;
        3) delete_banner;;
        4) edit_banner;;
        0) exit 0;;
        *) echo -e "${RED}Opción inválida.${RESET}"; sleep 1;;
    esac
done
