#!/bin/bash

# ═══════════════════════════════════════════════
# KevinTech WebSocket Universal Installer
# Compatible Ubuntu 18.04 / 20.04 / 22.04 / 24.04
# Parte 1/4
# ═══════════════════════════════════════════════

set -e

# Colores
GREEN="\e[1;92m"
RED="\e[1;91m"
CYAN="\e[1;96m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"


BASE="/etc/kevintech"
WS_DIR="$BASE/websocket"
CONFIG="$BASE/config.conf"


# ===============================
# ROOT
# ===============================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ejecuta este script como root${RESET}"
    exit 1
fi


# ===============================
# DETECTAR UBUNTU
# ===============================

clear

echo -e "${CYAN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  KevinTech WebSocket"
echo "  Instalador Universal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${RESET}"


if [[ -f /etc/os-release ]]; then

    source /etc/os-release

    echo -e "${WHITE}Sistema:${RESET} $PRETTY_NAME"

else

    echo -e "${RED}No se pudo detectar el sistema${RESET}"
    exit 1

fi


if [[ "$ID" != "ubuntu" ]]; then

    echo -e "${YELLOW}Advertencia: No es Ubuntu${RESET}"
    echo "Intentando continuar..."

fi


# ===============================
# ARQUITECTURA
# ===============================

ARCH=$(uname -m)

echo -e "${WHITE}Arquitectura:${RESET} $ARCH"


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
    CPU="unknown"
;;

esac


echo -e "${WHITE}CPU:${RESET} $CPU"


# ===============================
# INSTALAR DEPENDENCIAS
# ===============================

echo ""
echo -e "${CYAN}Instalando dependencias...${RESET}"


apt update -y >/dev/null 2>&1


apt install -y \
python3 \
python3-pip \
curl \
wget \
net-tools \
procps \
openssh-server \
lsof \
>/dev/null 2>&1



echo -e "${GREEN}✔ Dependencias instaladas${RESET}"


# ===============================
# CREAR DIRECTORIOS
# ===============================

mkdir -p "$WS_DIR"


# ===============================
# CREAR CONFIG
# ===============================

if [[ ! -f "$CONFIG" ]]; then

cat > "$CONFIG" <<EOF

# KevinTech WebSocket Config

WEBSOCKET=OFF

WS_PORT=80

SSH_PORT=22

DOMAIN=

EOF

fi


echo -e "${GREEN}✔ Configuración creada${RESET}"


echo ""
echo -e "${CYAN}Base instalada correctamente.${RESET}"
echo ""
echo "Siguiente parte:"
echo "→ Crear motor WebSocket Python compatible con cualquier payload"

sleep 3
# ===============================
# CREAR PROXY WEBSOCKET PYTHON
# COMPATIBLE CON PAYLOADS PERSONALIZADOS
# ===============================

PROXY="$WS_DIR/proxy.py"


cat > "$PROXY" <<'PYEOF'
#!/usr/bin/env python3

import asyncio
import signal
import sys


BUFFER = 65535

connections = 0


# Respuesta WebSocket
WS_RESPONSE = (
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n"
    b"\r\n"
)


# Respuesta CONNECT
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


    except Exception:
        pass


    finally:

        try:
            writer.close()
            await writer.wait_closed()
        except:
            pass




async def handler(client_reader, client_writer):

    global connections

    connections += 1

    ssh_writer = None


    try:


        # Leer payload inicial

        try:

            payload = await asyncio.wait_for(
                client_reader.read(BUFFER),
                timeout=10
            )

        except:

            client_writer.close()
            return



        if not payload:

            client_writer.close()
            return



        text = payload.decode(
            "utf-8",
            errors="ignore"
        ).upper()



        # Aceptar cualquier payload

        if (
            "UPGRADE" in text
            or "WEBSOCKET" in text
        ):

            client_writer.write(
                WS_RESPONSE
            )


        elif text.startswith("CONNECT"):

            client_writer.write(
                CONNECT_RESPONSE
            )


        else:

            client_writer.write(
                WS_RESPONSE
            )


        await client_writer.drain()



        # Conectar SSH limpio

        ssh_reader, ssh_writer = await asyncio.open_connection(
            "127.0.0.1",
            SSH_PORT
        )


        print(
            "[+] SSH conectado"
        )


        # IMPORTANTE:
        # NO enviar payload HTTP a SSH
        # Solo pasa tráfico nuevo


        await asyncio.gather(

            pipe(
                client_reader,
                ssh_writer
            ),

            pipe(
                ssh_reader,
                client_writer
            )

        )



    except Exception as e:

        print(
            "[ERROR]",
            e
        )


    finally:


        connections -= 1


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


    print(
        f"KevinTech WebSocket activo : {port}"
    )


    async with server:

        await server.serve_forever()




if __name__ == "__main__":


    if len(sys.argv) < 3:

        print(
            "Uso: proxy.py PUERTO SSH_PORT"
        )

        sys.exit(1)



    PORT = int(sys.argv[1])

    SSH_PORT = int(sys.argv[2])



    asyncio.run(
        start(PORT)
    )

PYEOF


chmod +x "$PROXY"
# ===============================
# CREAR SERVICIO SYSTEMD
# ===============================

SERVICE="/etc/systemd/system/kevintech-websocket.service"


cat > "$SERVICE" <<EOF
[Unit]
Description=KevinTech Universal WebSocket SSH
After=network.target ssh.service sshd.service
Wants=ssh.service


[Service]
Type=simple

ExecStart=/usr/bin/python3 $WS_DIR/proxy.py 80 22

Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal


[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload



echo -e "${GREEN}✔ Servicio creado${RESET}"



# ===============================
# ACTIVAR SERVICIO
# ===============================


systemctl enable kevintech-websocket.service \
>/dev/null 2>&1



systemctl restart kevintech-websocket.service



sleep 2



# ===============================
# VERIFICAR ESTADO
# ===============================


if systemctl is-active --quiet kevintech-websocket.service

then


echo -e "${GREEN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo " WebSocket ACTIVO"
echo " Puerto : 80"
echo " SSH    : 22"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${RESET}"


sed -i \
's/^WEBSOCKET=.*/WEBSOCKET=ON/' \
"$CONFIG"



else


echo -e "${RED}"
echo "Error iniciando WebSocket"
echo -e "${RESET}"


journalctl \
-u kevintech-websocket.service \
-n 20 \
--no-pager



fi
# ===============================
# FUNCIONES DEL MENU
# ===============================


estado_ws(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ESTADO WEBSOCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl status kevintech-websocket \
--no-pager


echo ""

ss -tulpn | grep :80 || \
echo "Puerto 80 no activo"


read -n1 -r -p "Presiona una tecla..."

}



reiniciar_ws(){

clear

echo "Reiniciando WebSocket..."

systemctl restart kevintech-websocket


sleep 2


if systemctl is-active --quiet kevintech-websocket
then
echo "✅ Reiniciado correctamente"
else
echo "❌ Error al reiniciar"
fi


sleep 2

}



desinstalar_ws(){


clear


read -rp "¿Eliminar WebSocket? (s/n): " R


if [[ "$R" =~ ^[Ss]$ ]]

then


systemctl stop kevintech-websocket 2>/dev/null

systemctl disable kevintech-websocket 2>/dev/null


rm -f /etc/systemd/system/kevintech-websocket.service

rm -rf "$WS_DIR"


systemctl daemon-reload



sed -i \
's/^WEBSOCKET=.*/WEBSOCKET=OFF/' \
"$CONFIG"



echo "✅ WebSocket eliminado"


else

echo "Cancelado"

fi


sleep 2

}





menu_ws(){


while true

do


clear


source "$CONFIG"



if [[ "$WEBSOCKET" == "ON" ]]

then

STATUS="🟢 ACTIVO"

else

STATUS="🔴 OFF"

fi



echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 KevinTech WebSocket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Estado : $STATUS"
echo "Puerto : $WS_PORT"
echo "SSH    : $SSH_PORT"

echo ""

echo "[1] Instalar"
echo "[2] Estado"
echo "[3] Reiniciar"
echo "[4] Desinstalar"
echo "[0] Salir"

echo ""

read -rp "Opción: " OP



case $OP in


1)

bash "$0" install

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

break

;;


*)

echo "Opción inválida"
sleep 2

;;


esac


done

}



# Ejecutar menú

menu_ws
