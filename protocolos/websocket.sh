#!/bin/bash

#═══════════════════════════════════════════════
# KevinTech Multi Script
# WebSocket Manager
#═══════════════════════════════════════════════

set -e

GREEN="\e[1;92m"
RED="\e[1;91m"
CYAN="\e[1;96m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

BASE="/etc/kevintech"
WS_DIR="$BASE/websocket"
CONFIG="$BASE/config.conf"

SERVICE="kevintech-websocket.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE"

[[ -f "$CONFIG" ]] || {
    echo "No existe $CONFIG"
    exit 1
}

source "$CONFIG"

WS_PORT=${WS_PORT:-80}
SSH_PORT=${SSH_PORT:-22}
WEBSOCKET=${WEBSOCKET:-OFF}

#═══════════════════════════════════════════════
# INSTALAR WEBSOCKET
#═══════════════════════════════════════════════

instalar_ws(){

clear

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ejecuta como root${RESET}"
    exit 1
fi

echo -e "${CYAN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " KevinTech WebSocket"
echo " Instalador Universal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${RESET}"

source /etc/os-release

echo -e "${WHITE}Sistema:${RESET} $PRETTY_NAME"

ARCH=$(uname -m)

case "$ARCH" in
x86_64)
CPU="amd64"
;;

aarch64|arm64)
CPU="arm64"
;;

armv7*)
CPU="arm"
;;

*)
CPU="$ARCH"
;;
esac

echo -e "${WHITE}Arquitectura:${RESET} $ARCH"
echo -e "${WHITE}CPU:${RESET} $CPU"

echo
echo -e "${CYAN}Instalando dependencias...${RESET}"

apt update -y

apt install -y \
python3 \
python3-pip \
curl \
wget \
net-tools \
procps \
openssh-server \
lsof

mkdir -p "$WS_DIR"

if ! grep -q "^WEBSOCKET=" "$CONFIG"; then
echo "WEBSOCKET=OFF" >> "$CONFIG"
fi

if ! grep -q "^WS_PORT=" "$CONFIG"; then
echo "WS_PORT=80" >> "$CONFIG"
fi

if ! grep -q "^SSH_PORT=" "$CONFIG"; then
echo "SSH_PORT=22" >> "$CONFIG"
fi

echo
echo -e "${GREEN}✔ Dependencias instaladas${RESET}"
echo -e "${GREEN}✔ Directorios creados${RESET}"
echo -e "${GREEN}✔ Configuración preparada${RESET}"
#═══════════════════════════════════════════════
# CREAR PROXY PYTHON
#═══════════════════════════════════════════════

PROXY="$WS_DIR/proxy.py"

cat > "$PROXY" <<'PYEOF'
#!/usr/bin/env python3

import asyncio
import sys

BUFFER = 65535

WS_RESPONSE = (
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n"
    b"\r\n"
)

CONNECT_RESPONSE = (
    b"HTTP/1.1 200 Connection Established\r\n"
    b"\r\n"
)

async def pipe(reader, writer):
    try:
        while True:
            data = await reader.read(BUFFER)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except:
        pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except:
            pass

async def handler(client_reader, client_writer):

    ssh_writer = None

    try:

        payload = await asyncio.wait_for(
            client_reader.read(BUFFER),
            timeout=10
        )

        if not payload:
            client_writer.close()
            return

        text = payload.decode(
            "utf-8",
            errors="ignore"
        ).upper()

        if "WEBSOCKET" in text or "UPGRADE" in text:
            client_writer.write(WS_RESPONSE)

        elif text.startswith("CONNECT"):
            client_writer.write(CONNECT_RESPONSE)

        else:
            client_writer.write(WS_RESPONSE)

        await client_writer.drain()

        ssh_reader, ssh_writer = await asyncio.open_connection(
            "127.0.0.1",
            SSH_PORT
        )

        await asyncio.gather(
            pipe(client_reader, ssh_writer),
            pipe(ssh_reader, client_writer)
        )

    except Exception as e:
        print(e)

    finally:
        try:
            client_writer.close()
        except:
            pass

        if ssh_writer:
            try:
                ssh_writer.close()
            except:
                pass

async def start(port):

    server = await asyncio.start_server(
        handler,
        "0.0.0.0",
        port
    )

    print(f"KevinTech WebSocket activo en puerto {port}")

    async with server:
        await server.serve_forever()

if __name__ == "__main__":

    if len(sys.argv) != 3:
        print("Uso: proxy.py PUERTO SSH_PORT")
        sys.exit(1)

    PORT = int(sys.argv[1])
    SSH_PORT = int(sys.argv[2])

    asyncio.run(start(PORT))

PYEOF

chmod +x "$PROXY"

echo -e "${GREEN}✔ Proxy WebSocket creado${RESET}"
#═══════════════════════════════════════════════
# CREAR SERVICIO SYSTEMD
#═══════════════════════════════════════════════

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech Universal WebSocket SSH
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $PROXY $WS_PORT $SSH_PORT
Restart=always
RestartSec=3
User=root

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1
systemctl restart "$SERVICE"

sleep 2

#═══════════════════════════════════════════════
# VERIFICAR SERVICIO
#═══════════════════════════════════════════════

if systemctl is-active --quiet "$SERVICE"; then

    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=ON/' "$CONFIG" 2>/dev/null

    # Si no existe la variable, la crea
    grep -q "^WEBSOCKET=" "$CONFIG" || echo "WEBSOCKET=ON" >> "$CONFIG"

    source "$CONFIG"

    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}     ✅ WEBSOCKET ACTIVO${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}Puerto SSH : ${GREEN}$SSH_PORT${RESET}"
    echo -e "${WHITE}Puerto WS  : ${GREEN}$WS_PORT${RESET}"

else

    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG" 2>/dev/null

    grep -q "^WEBSOCKET=" "$CONFIG" || echo "WEBSOCKET=OFF" >> "$CONFIG"

    echo
    echo -e "${RED}❌ Error iniciando WebSocket${RESET}"
    echo

    journalctl -u "$SERVICE" -n 20 --no-pager

fi

echo
read -n1 -r -p "Presiona una tecla para continuar..."
}
#═══════════════════════════════════════════════
# ESTADO DEL WEBSOCKET
#═══════════════════════════════════════════════

estado_ws(){

clear

source "$CONFIG"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}      ESTADO WEBSOCKET${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

if systemctl is-active --quiet "$SERVICE"; then
    echo -e "Estado : ${GREEN}🟢 ACTIVO${RESET}"
else
    echo -e "Estado : ${RED}🔴 DETENIDO${RESET}"
fi

echo
echo "Servicio : $SERVICE"
echo "Puerto WS: $WS_PORT"
echo "Puerto SSH: $SSH_PORT"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl status "$SERVICE" --no-pager

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PUERTOS"

ss -tulpn | grep ":$WS_PORT"

echo
read -n1 -r -p "Presiona una tecla..."
}

#═══════════════════════════════════════════════
# REINICIAR WEBSOCKET
#═══════════════════════════════════════════════

reiniciar_ws(){

clear

echo -e "${CYAN}Reiniciando WebSocket...${RESET}"

systemctl restart "$SERVICE"

sleep 2

if systemctl is-active --quiet "$SERVICE"; then

    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=ON/' "$CONFIG"

    echo -e "${GREEN}✔ WebSocket reiniciado correctamente${RESET}"

else

    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG"

    echo -e "${RED}❌ No fue posible reiniciar el servicio${RESET}"

fi

sleep 2
}

#═══════════════════════════════════════════════
# DESINSTALAR WEBSOCKET
#═══════════════════════════════════════════════

desinstalar_ws(){

clear

echo -e "${RED}Se eliminará WebSocket completamente.${RESET}"
echo

read -rp "¿Deseas continuar? [S/N]: " RESP

case "$RESP" in
s|S|si|SI|Sí|sí)

systemctl stop "$SERVICE" 2>/dev/null
systemctl disable "$SERVICE" 2>/dev/null

rm -f "$SERVICE_FILE"
rm -rf "$WS_DIR"

systemctl daemon-reload

sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG"

echo
echo -e "${GREEN}✔ WebSocket eliminado correctamente${RESET}"
sleep 3
;;

*)
echo
echo "Cancelado."
sleep 2
;;
esac

}
#═══════════════════════════════════════════════
# MENÚ WEBSOCKET
#═══════════════════════════════════════════════

menu_ws(){

while true
do

clear

source "$CONFIG"

if systemctl is-active --quiet "$SERVICE"; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=ON/' "$CONFIG" 2>/dev/null
else
    STATUS="${RED}🔴 OFF${RESET}"
    sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG" 2>/dev/null
fi

source "$CONFIG"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}      🌐 KevinTech WebSocket${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo -e "${WHITE}Estado     : $STATUS"
echo -e "${WHITE}Puerto WS  : ${GREEN}${WS_PORT}${RESET}"
echo -e "${WHITE}Puerto SSH : ${GREEN}${SSH_PORT}${RESET}"
echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo " [1] ➮ Instalar WebSocket"
echo " [2] ➮ Estado del Servicio"
echo " [3] ➮ Reiniciar Servicio"
echo " [4] ➮ Desinstalar WebSocket"
echo " [0] ➮ Regresar"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

read -rp " ► Opción: " OP

case "$OP" in

1)
    instalar_ws
    ;;

2)
    estado_ws
    ;;

3)
    reiniciar_ws
    ;;

4)
    desinstalar_ws
    ;;

0)
    exec bash "$BASE/protocolos/menu.sh"
    ;;

*)
    echo
    echo "❌ Opción inválida."
    sleep 2
    ;;
esac

done

}

#═══════════════════════════════════════════════
# INICIAR MENÚ
#═══════════════════════════════════════════════

menu_ws
