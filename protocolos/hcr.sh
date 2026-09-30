#!/usr/bin/env bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                       HCR MANAGER
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/hcr.sh
# Módulo  : HCR
# Puerto  : ALEATORIO
# Backend : SSH LOCAL
#
# USUARIOS:
# HCR utiliza directamente las cuentas creadas por:
# /etc/kevintech/usuarios/add.sh
#
# NO crea una base de usuarios propia.
# NO modifica otros protocolos.
# NO modifica otros puertos.
#
# ==============================================================

set -o pipefail

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

STATE="$BASE/hcr.conf"
DIR="/usr/local/lib/hcr"
BIN="$DIR/hcr-server"

UNIT="/etc/systemd/system/hcr.service"
SERVICE="hcr"

HCR_MIN_PORT=10000
HCR_MAX_PORT=60000

HCR_URL_BASE="https://raw.githubusercontent.com/JotchuaDevz/BHTTP-LIBS/refs/heads/main"

RESET="\e[0m"
BOLD="\e[1m"
CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

mkdir -p "$BASE"

[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null || true
[[ -f "$STATE" ]] && source "$STATE" 2>/dev/null || true

HCR_PORT="${HCR_PORT:-}"

# ==============================================================
# FUNCIONES GENERALES
# ==============================================================

line() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

header() {
    clear

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                    HCR MANAGER                              ║${RESET}"
    echo -e "${CYAN}${BOLD}║                  KEVINTECH MULTI SCRIPT                     ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

need_root() {

    if [[ $EUID -ne 0 ]]; then

        echo -e "${RED}${BOLD}✘ Este módulo requiere permisos de root.${RESET}"

        return 1
    fi

    return 0
}

valid_port() {

    [[ "$1" =~ ^[0-9]+$ ]] &&
    (( 1 <= 10#$1 && 10#$1 <= 65535 ))
}

# ==============================================================
# DETECTAR PUERTO EN USO
# ==============================================================

port_used() {

    local PORT="$1"

    if command -v ss >/dev/null 2>&1; then

        ss -H -ltn 2>/dev/null |
            awk -v p=":$PORT" '
                $4 ~ p"$" {
                    found=1
                }
                END {
                    exit found ? 0 : 1
                }
            '

        return $?

    fi

    if command -v netstat >/dev/null 2>&1; then

        netstat -ltn 2>/dev/null |
            awk -v p=":$PORT" '
                $4 ~ p"$" {
                    found=1
                }
                END {
                    exit found ? 0 : 1
                }
            '

        return $?
    fi

    return 1
}

# ==============================================================
# ELEGIR PUERTO ALEATORIO
# ==============================================================

random_port() {

    local PORT
    local INTENTOS=0

    while (( INTENTOS < 100 )); do

        PORT=$(shuf -i "${HCR_MIN_PORT}-${HCR_MAX_PORT}" -n 1 2>/dev/null)

        [[ -z "$PORT" ]] && continue

        if ! port_used "$PORT"; then

            echo "$PORT"

            return 0
        fi

        ((INTENTOS++))

    done

    return 1
}

# ==============================================================
# OBTENER PUERTO HCR
# ==============================================================

get_hcr_port() {

    if valid_port "${HCR_PORT:-}" &&
       ! port_used "$HCR_PORT"; then

        echo "$HCR_PORT"

        return 0
    fi

    HCR_PORT="$(random_port)" || {

        echo -e "${RED}✘ No se encontró un puerto libre.${RESET}"

        return 1
    }

    save_state

    echo "$HCR_PORT"
}

# ==============================================================
# GUARDAR ESTADO
# ==============================================================

save_state() {

    mkdir -p "$BASE"

    cat > "$STATE" <<EOF
# =========================================================
# KEVINTECH HCR
# =========================================================

HCR_PORT=$HCR_PORT
EOF

    chmod 600 "$STATE"
}

# ==============================================================
# ACTUALIZAR CONFIG PRINCIPAL
# ==============================================================

set_config_hcr() {

    [[ -f "$CONFIG" ]] || touch "$CONFIG"

    if grep -qE '^HCR=' "$CONFIG"; then

        sed -i "s/^HCR=.*/HCR=$1/" "$CONFIG"

    else

        echo "HCR=$1" >> "$CONFIG"
    fi
}

# ==============================================================
# ARQUITECTURA
# ==============================================================

get_arch() {

    case "$(uname -m)" in

        x86_64|amd64)
            echo "amd64"
            ;;

        aarch64|arm64)
            echo "arm64"
            ;;

        *)
            return 1
            ;;
    esac
}

# ==============================================================
# DESCARGAR HCR
# ==============================================================

download_hcr() {

    local ARCH
    ARCH="$(get_arch)" || {

        echo -e "${RED}✘ Arquitectura no soportada.${RESET}"

        return 1
    }

    mkdir -p "$DIR"

    local FILENAME
    FILENAME="hcr-server-linux-${ARCH}"

    local URL
    URL="${HCR_URL_BASE}/${FILENAME}"

    echo -e "${CYAN}▸ Descargando HCR para ${ARCH}...${RESET}"

    if command -v curl >/dev/null 2>&1; then

        curl -fsSL \
            --connect-timeout 10 \
            --max-time 300 \
            --retry 2 \
            -o "$BIN" \
            "$URL"

    else

        wget -q \
            --timeout=20 \
            --tries=3 \
            -O "$BIN" \
            "$URL"
    fi

    if [[ ! -s "$BIN" ]]; then

        echo -e "${RED}✘ No se pudo descargar HCR.${RESET}"

        rm -f "$BIN"

        return 1
    fi

    chmod 755 "$BIN"

    echo -e "${GREEN}✔ HCR descargado correctamente.${RESET}"

    return 0
}

# ==============================================================
# CREAR SERVICIO
# ==============================================================

create_service() {

    local SSH_PORT_CURRENT

    SSH_PORT_CURRENT="22"

    if [[ -f "$CONFIG" ]]; then

        if grep -qE '^SSH_PORT=' "$CONFIG"; then

            SSH_PORT_CURRENT="$(
                awk -F= '/^SSH_PORT=/ {
                    print $2
                    exit
                }' "$CONFIG"
            )"
        fi
    fi

    valid_port "$SSH_PORT_CURRENT" || SSH_PORT_CURRENT="22"

    cat > "$UNIT" <<EOF
[Unit]
Description=KevinTech HCR Server
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR

ExecStart=$BIN --listen :$HCR_PORT --target 127.0.0.1:$SSH_PORT_CURRENT --transport plain

Restart=always
RestartSec=3

KillMode=mixed
TimeoutStopSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=hcr

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$UNIT"

    systemctl daemon-reload

    echo -e "${GREEN}✔ Servicio HCR creado.${RESET}"
    echo -e "${GRAY}  HCR : 0.0.0.0:$HCR_PORT${RESET}"
    echo -e "${GRAY}  SSH : 127.0.0.1:$SSH_PORT_CURRENT${RESET}"
}

# ==============================================================
# FIREWALL
# ==============================================================

firewall_add() {

    command -v iptables >/dev/null 2>&1 || return 0

    iptables -C INPUT \
        -p tcp \
        --dport "$HCR_PORT" \
        -j ACCEPT \
        2>/dev/null ||

    iptables -I INPUT \
        -p tcp \
        --dport "$HCR_PORT" \
        -j ACCEPT \
        2>/dev/null || true
}

firewall_remove() {

    command -v iptables >/dev/null 2>&1 || return 0

    while iptables -C INPUT \
        -p tcp \
        --dport "$HCR_PORT" \
        -j ACCEPT \
        2>/dev/null; do

        iptables -D INPUT \
            -p tcp \
            --dport "$HCR_PORT" \
            -j ACCEPT \
            2>/dev/null || break
    done
}

# ==============================================================
# INSTALAR
# ==============================================================

install_hcr() {

    need_root || return 1

    header

    echo -e "${WHITE}${BOLD}🚀 INSTALAR HCR${RESET}"
    line
    echo

    echo -e "${CYAN}▸ Seleccionando puerto aleatorio...${RESET}"

    HCR_PORT="$(random_port)" || {

        echo -e "${RED}✘ No fue posible encontrar un puerto libre.${RESET}"

        pause

        return 1
    }

    echo -e "${GREEN}✔ Puerto HCR seleccionado: ${YELLOW}$HCR_PORT${RESET}"

    echo

    echo -e "${CYAN}▸ Instalando HCR...${RESET}"

    if [[ ! -x "$BIN" ]]; then

        download_hcr || {

            pause

            return 1
        }

    else

        echo -e "${GREEN}✔ HCR ya está descargado.${RESET}"
    fi

    echo

    save_state

    create_service || {

        pause

        return 1
    }

    firewall_add

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    echo

    echo -e "${CYAN}▸ Iniciando HCR...${RESET}"

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        set_config_hcr "ON"

        echo
        echo -e "${GREEN}${BOLD}✔ HCR INSTALADO Y ACTIVO${RESET}"
        echo
        echo -e "  Puerto HCR : ${YELLOW}$HCR_PORT${RESET}"
        echo -e "  Backend    : ${CYAN}SSH local${RESET}"
        echo -e "  Usuarios   : ${CYAN}usuarios/add.sh${RESET}"
        echo

        return 0

    fi

    echo
    echo -e "${RED}✘ HCR no pudo iniciar.${RESET}"
    echo

    journalctl -u "$SERVICE" -n 30 --no-pager -l

    return 1
}

# ==============================================================
# INICIAR
# ==============================================================

start_hcr() {

    need_root || return 1

    if [[ ! -f "$UNIT" ]]; then

        echo -e "${RED}✘ HCR no está instalado.${RESET}"

        return 1
    fi

    systemctl start "$SERVICE"

    sleep 1

    if systemctl is-active --quiet "$SERVICE"; then

        echo -e "${GREEN}✔ HCR iniciado.${RESET}"

        return 0
    fi

    echo -e "${RED}✘ HCR no pudo iniciar.${RESET}"

    return 1
}

# ==============================================================
# DETENER
# ==============================================================

stop_hcr() {

    need_root || return 1

    systemctl stop "$SERVICE" 2>/dev/null || true

    echo -e "${GREEN}✔ HCR detenido.${RESET}"
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_hcr() {

    need_root || return 1

    systemctl restart "$SERVICE"

    sleep 1

    if systemctl is-active --quiet "$SERVICE"; then

        echo -e "${GREEN}✔ HCR reiniciado.${RESET}"

        return 0
    fi

    echo -e "${RED}✘ HCR no pudo reiniciar.${RESET}"

    return 1
}

# ==============================================================
# ESTADO
# ==============================================================

status_hcr() {

    echo

    echo -e "${WHITE}${BOLD}ESTADO HCR${RESET}"

    line

    echo -e "Servicio : $(systemctl is-active "$SERVICE" 2>/dev/null || echo inactivo)"

    if [[ -f "$STATE" ]]; then

        echo -e "Puerto   : ${YELLOW}${HCR_PORT:-N/A}${RESET}"

    else

        echo -e "Puerto   : ${GRAY}No instalado${RESET}"
    fi

    echo

    systemctl status "$SERVICE" \
        --no-pager \
        -l \
        2>/dev/null
}

# ==============================================================
# USUARIOS DEL ADD.SH
# ==============================================================

list_users() {

    header

    echo -e "${WHITE}${BOLD}👥 USUARIOS HCR${RESET}"
    line
    echo

    if [[ ! -f "$BASE/limits.conf" ]]; then

        echo -e "${YELLOW}No existe $BASE/limits.conf${RESET}"

        pause

        return
    fi

    local COUNT=0
    local USERNAME
    local LIMIT
    local EXPIRATION

    while IFS=: read -r USERNAME LIMIT; do

        [[ -z "$USERNAME" ]] && continue
        [[ "$USERNAME" =~ ^# ]] && continue

        id "$USERNAME" >/dev/null 2>&1 || continue

        EXPIRATION="$(
            chage -l "$USERNAME" 2>/dev/null |
            awk -F': ' '/Account expires/ {
                print $2
                exit
            }'
        )"

        [[ -z "$EXPIRATION" ]] && EXPIRATION="Ilimitada"

        ((COUNT++))

        printf "  ${GREEN}%-20s${RESET}  Límite: ${YELLOW}%-4s${RESET}  Expira: ${CYAN}%s${RESET}\n" \
            "$USERNAME" \
            "${LIMIT:-0}" \
            "$EXPIRATION"

    done < "$BASE/limits.conf"

    echo

    if (( COUNT == 0 )); then

        echo -e "${YELLOW}No hay usuarios creados por add.sh.${RESET}"

    else

        echo -e "${GREEN}Total: $COUNT usuario(s)${RESET}"
    fi

    pause
}

# ==============================================================
# LOGS
# ==============================================================

logs_hcr() {

    header

    echo -e "${WHITE}${BOLD}📋 LOGS HCR${RESET}"

    line

    journalctl -u "$SERVICE" \
        -n 80 \
        --no-pager \
        -l

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_hcr() {

    need_root || return 1

    header

    echo -e "${RED}${BOLD}🗑️ DESINSTALAR HCR${RESET}"

    line

    echo

    echo -e "${YELLOW}Esto eliminará solamente HCR.${RESET}"
    echo -e "${GRAY}SSH, usuarios y los demás protocolos NO serán modificados.${RESET}"

    echo

    read -rp "Escribe SI para continuar: " CONFIRM

    [[ "$CONFIRM" == "SI" ]] || {

        echo -e "${YELLOW}Cancelado.${RESET}"

        pause

        return 0
    }

    echo

    echo -e "${CYAN}▸ Deteniendo HCR...${RESET}"

    systemctl stop "$SERVICE" 2>/dev/null || true

    systemctl disable "$SERVICE" 2>/dev/null || true

    echo -e "${CYAN}▸ Eliminando regla del firewall...${RESET}"

    firewall_remove

    echo -e "${CYAN}▸ Eliminando servicio...${RESET}"

    rm -f "$UNIT"

    echo -e "${CYAN}▸ Eliminando archivos HCR...${RESET}"

    rm -rf "$DIR"

    rm -f "$STATE"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE" 2>/dev/null || true

    set_config_hcr "OFF"

    echo

    echo -e "${GREEN}${BOLD}✔ HCR DESINSTALADO${RESET}"

    echo
    echo -e "${GRAY}SSH y los demás protocolos permanecen intactos.${RESET}"

    pause
}

# ==============================================================
# INSTALACIÓN AUTOMÁTICA
# ==============================================================

auto_install() {

    need_root || exit 1

    install_hcr

    exit $?
}

# ==============================================================
# MENÚ
# ==============================================================

menu() {

    while true; do

        header

        local STATE_SERVICE
        STATE_SERVICE="$(
            systemctl is-active "$SERVICE" 2>/dev/null ||
            echo "inactivo"
        )"

        if [[ "$STATE_SERVICE" == "active" ]]; then

            echo -e "Estado : ${GREEN}● ACTIVO${RESET}"

        else

            echo -e "Estado : ${RED}● INACTIVO${RESET}"
        fi

        echo -e "Puerto : ${YELLOW}${HCR_PORT:-N/A}${RESET}"

        echo

        line

        echo -e "${GREEN}[01]${RESET} 🚀 Instalar / Actualizar HCR"
        echo -e "${GREEN}[02]${RESET} ▶️  Iniciar HCR"
        echo -e "${GREEN}[03]${RESET} ⏹️  Detener HCR"
        echo -e "${GREEN}[04]${RESET} 🔄 Reiniciar HCR"
        echo -e "${GREEN}[05]${RESET} 👥 Ver usuarios de add.sh"
        echo -e "${GREEN}[06]${RESET} 📋 Ver estado"
        echo -e "${GREEN}[07]${RESET} 📜 Ver logs"
        echo -e "${RED}[08]${RESET} 🗑️  Desinstalar HCR"
        echo -e "${RED}[00]${RESET} 🔙 Volver"

        line

        echo

        read -rp "➜ Selecciona una opción: " OPTION

        case "$OPTION" in

            1)
                install_hcr
                pause
                ;;

            2)
                start_hcr
                pause
                ;;

            3)
                stop_hcr
                pause
                ;;

            4)
                restart_hcr
                pause
                ;;

            5)
                list_users
                ;;

            6)
                status_hcr
                pause
                ;;

            7)
                logs_hcr
                ;;

            8)
                uninstall_hcr
                ;;

            0|00)
                return 0
                ;;

            *)
                echo -e "${RED}✘ Opción inválida.${RESET}"
                sleep 1
                ;;
        esac

    done
}

# ==============================================================
# MAIN
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    auto_install
fi

need_root || exit 1

menu