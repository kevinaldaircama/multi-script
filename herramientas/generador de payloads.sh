#!/bin/bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                    PAYLOAD GENERATOR
# ==============================================================
# Archivo: /etc/kevintech/herramientas/generador de payloads.sh
# ==============================================================

VERSION="2.0"

# ==============================================================
# COLORES
# ==============================================================

RESET="\033[0m"
BOLD="\033[1m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# ==============================================================
# LIMPIAR PANTALLA
# No depende del comando "clear"
# ==============================================================

limpiar() {
    printf '\033c'
}

# ==============================================================
# PAUSA
# ==============================================================

pausa() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

# ==============================================================
# CABECERA
# ==============================================================

cabecera() {
    limpiar

    echo -e "${CYAN}${BOLD}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🛡️ KEVINTECH MULTI SCRIPT"
    echo "                 ⚡ PAYLOAD GENERATOR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RESET}"
}

# ==============================================================
# TITULO
# ==============================================================

titulo() {
    echo -e "${CYAN}${BOLD}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RESET}"
}

# ==============================================================
# RESULTADO
# ==============================================================

mostrar_payload() {
    local tipo="$1"
    local payload="$2"

    echo
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║              📦 PAYLOAD GENERADO                ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${YELLOW}Tipo:${RESET} ${WHITE}${tipo}${RESET}"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    printf '%s\n' "$payload"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ==============================================================
# VALIDAR HOST
# ==============================================================

validar_host() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ El Host no puede estar vacío.${RESET}"
        return 1
    fi

    return 0
}

# ==============================================================
# HTTP GET
# ==============================================================

http_get() {
    cabecera
    titulo "🌐 HTTP GET"

    echo -e "${WHITE}Genera una petición HTTP GET.${RESET}"
    echo

    read -rp "🌐 Host: " HOST
    validar_host "$HOST" || {
        pausa
        return
    }

    read -rp "📁 Ruta [/]: " RUTA

    [ -z "$RUTA" ] && RUTA="/"

    # Añadir "/" automáticamente si el usuario escribe "api"
    case "$RUTA" in
        /*) ;;
        *) RUTA="/$RUTA" ;;
    esac

    PAYLOAD="GET ${RUTA} HTTP/1.1
Host: ${HOST}
User-Agent: KevinTech
Connection: keep-alive"

    mostrar_payload "HTTP GET" "$PAYLOAD"

    pausa
}

# ==============================================================
# HTTP POST
# ==============================================================

http_post() {
    cabecera
    titulo "📨 HTTP POST"

    echo -e "${WHITE}Genera una petición HTTP POST.${RESET}"
    echo

    read -rp "🌐 Host: " HOST
    validar_host "$HOST" || {
        pausa
        return
    }

    read -rp "📁 Ruta [/]: " RUTA
    [ -z "$RUTA" ] && RUTA="/"

    case "$RUTA" in
        /*) ;;
        *) RUTA="/$RUTA" ;;
    esac

    read -rp "📝 Datos POST: " DATA

    LENGTH=${#DATA}

    PAYLOAD="POST ${RUTA} HTTP/1.1
Host: ${HOST}
User-Agent: KevinTech
Content-Type: application/x-www-form-urlencoded
Content-Length: ${LENGTH}
Connection: keep-alive

${DATA}"

    mostrar_payload "HTTP POST" "$PAYLOAD"

    pausa
}

# ==============================================================
# WEBSOCKET
# ==============================================================

websocket() {
    cabecera
    titulo "🔌 WEBSOCKET"

    echo -e "${WHITE}Genera los encabezados de una solicitud WebSocket.${RESET}"
    echo

    read -rp "🌐 Host: " HOST
    validar_host "$HOST" || {
        pausa
        return
    }

    read -rp "📁 Ruta [/]: " RUTA
    [ -z "$RUTA" ] && RUTA="/"

    case "$RUTA" in
        /*) ;;
        *) RUTA="/$RUTA" ;;
    esac

    PAYLOAD="GET ${RUTA} HTTP/1.1
Host: ${HOST}
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Version: 13
User-Agent: KevinTech"

    mostrar_payload "WebSocket" "$PAYLOAD"

    pausa
}

# ==============================================================
# TCP
# ==============================================================

tcp_payload() {
    cabecera
    titulo "🔗 TCP"

    echo -e "${WHITE}Genera una plantilla de datos TCP.${RESET}"
    echo

    read -rp "🌐 Host: " HOST
    validar_host "$HOST" || {
        pausa
        return
    }

    read -rp "🔢 Puerto: " PORT
    read -rp "📝 Datos: " DATA

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}❌ Puerto inválido.${RESET}"
        pausa
        return
    fi

    PAYLOAD="TCP://${HOST}:${PORT}
${DATA}"

    mostrar_payload "TCP" "$PAYLOAD"

    pausa
}

# ==============================================================
# UDP
# ==============================================================

udp_payload() {
    cabecera
    titulo "📡 UDP"

    echo -e "${WHITE}Genera una plantilla de datos UDP.${RESET}"
    echo

    read -rp "🌐 Host: " HOST
    validar_host "$HOST" || {
        pausa
        return
    }

    read -rp "🔢 Puerto: " PORT
    read -rp "📝 Datos: " DATA

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}❌ Puerto inválido.${RESET}"
        pausa
        return
    fi

    PAYLOAD="UDP://${HOST}:${PORT}
${DATA}"

    mostrar_payload "UDP" "$PAYLOAD"

    pausa
}

# ==============================================================
# PERSONALIZADO
# ==============================================================

personalizado() {
    cabecera
    titulo "🛠️ PAYLOAD PERSONALIZADO"

    echo -e "${WHITE}Escribe el contenido del payload.${RESET}"
    echo -e "${YELLOW}Escribe FIN en una línea independiente para terminar.${RESET}"
    echo

    PAYLOAD=""

    while IFS= read -r LINEA; do
        [ "$LINEA" = "FIN" ] && break
        PAYLOAD="${PAYLOAD}${LINEA}"$'\n'
    done

    if [ -z "$PAYLOAD" ]; then
        echo -e "${RED}❌ No introdujiste ningún payload.${RESET}"
        pausa
        return
    fi

    mostrar_payload "Personalizado" "$PAYLOAD"

    pausa
}

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

payloads() {
    while true; do

        cabecera

        echo -e "${WHITE}${BOLD}Herramientas disponibles:${RESET}"
        echo

        echo -e " ${CYAN}[1]${RESET} 🌐 HTTP GET"
        echo -e " ${CYAN}[2]${RESET} 📨 HTTP POST"
        echo -e " ${CYAN}[3]${RESET} 🔌 WebSocket"
        echo -e " ${CYAN}[4]${RESET} 🔗 TCP"
        echo -e " ${CYAN}[5]${RESET} 📡 UDP"
        echo -e " ${CYAN}[6]${RESET} 🛠️  Payload personalizado"
        echo -e " ${RED}[0]${RESET} 🚪 Salir"

        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

        read -rp "➜ Selecciona una opción: " OPCION

        case "$OPCION" in

            1)
                http_get
                ;;

            2)
                http_post
                ;;

            3)
                websocket
                ;;

            4)
                tcp_payload
                ;;

            5)
                udp_payload
                ;;

            6)
                personalizado
                ;;

            0)
                limpiar
                echo -e "${GREEN}✓ Saliendo del Generador de Payloads...${RESET}"
                echo
                exit 0
                ;;

            *)
                echo
                echo -e "${RED}❌ Opción inválida.${RESET}"
                sleep 1
                ;;

        esac
    done
}

# ==============================================================
# INICIO
# ==============================================================

payloads
