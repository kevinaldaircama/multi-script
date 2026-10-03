#!/bin/bash

# ╔══════════════════════════════════════╗
# ║     KEVIN TECH - PAYLOAD GENERATOR   ║
# ╚══════════════════════════════════════╝

clear

while true; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "        ⚡ GENERADOR DE PAYLOADS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "1) HTTP GET"
    echo "2) HTTP POST"
    echo "3) WebSocket"
    echo "4) TCP"
    echo "5) UDP"
    echo "6) Payload personalizado"
    echo "7) Salir"
    echo
    read -rp "Selecciona una opción: " OPC

    case "$OPC" in

        1)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "             HTTP GET"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -rp "Host: " HOST
            read -rp "Ruta: " PATH

            [ -z "$PATH" ] && PATH="/"

            PAYLOAD="GET ${PATH} HTTP/1.1
Host: ${HOST}
User-Agent: KevinTech
Connection: keep-alive"

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s\n' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        2)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "             HTTP POST"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -rp "Host: " HOST
            read -rp "Ruta: " PATH
            read -rp "Datos: " DATA

            [ -z "$PATH" ] && PATH="/"

            PAYLOAD="POST ${PATH} HTTP/1.1
Host: ${HOST}
Content-Type: application/x-www-form-urlencoded
Content-Length: ${#DATA}
User-Agent: KevinTech
Connection: keep-alive

${DATA}"

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s\n' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        3)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "             WEBSOCKET"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -rp "Host: " HOST
            read -rp "Ruta: " PATH

            [ -z "$PATH" ] && PATH="/"

            PAYLOAD="GET ${PATH} HTTP/1.1
Host: ${HOST}
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Version: 13
User-Agent: KevinTech"

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s\n' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        4)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "                TCP"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -rp "Host: " HOST
            read -rp "Puerto: " PORT
            read -rp "Mensaje: " DATA

            PAYLOAD="TCP://${HOST}:${PORT}
${DATA}"

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s\n' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        5)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "                UDP"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -rp "Host: " HOST
            read -rp "Puerto: " PORT
            read -rp "Mensaje: " DATA

            PAYLOAD="UDP://${HOST}:${PORT}
${DATA}"

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s\n' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        6)
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "        PAYLOAD PERSONALIZADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Escribe tu payload."
            echo "Para terminar utiliza una línea con FIN."
            echo

            PAYLOAD=""

            while IFS= read -r LINEA; do
                [ "$LINEA" = "FIN" ] && break
                PAYLOAD="${PAYLOAD}${LINEA}"$'\n'
            done

            echo
            echo "📦 PAYLOAD GENERADO"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf '%s' "$PAYLOAD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        7)
            clear
            exit 0
            ;;

        *)
            echo
            echo "❌ Opción inválida."
            sleep 2
            ;;
    esac

    echo
    read -rp "Presiona ENTER para continuar..."
    clear
done