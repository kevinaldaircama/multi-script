#!/bin/bash

# =====================================================
# KevinTech ZiVPN Manager
# UDP-ZIVPN 1.4.9
# =====================================================

ZIVPN_DIR="/etc/zivpn"
BIN="/usr/local/bin/zivpn"
SERVICE="/etc/systemd/system/zivpn.service"
CONFIG="$ZIVPN_DIR/config.json"
PORT_FILE="$ZIVPN_DIR/port"

GREEN="\e[1;32m"
RED="\e[1;31m"
YELLOW="\e[1;33m"
RESET="\e[0m"


msg(){
    echo -e "${GREEN}[ZiVPN]${RESET} $1"
}


error(){
    echo -e "${RED}[ERROR]${RESET} $1"
}


warning(){
    echo -e "${YELLOW}[AVISO]${RESET} $1"
}


check_root(){

if [ "$EUID" -ne 0 ]; then

    error "Ejecuta este script como root"

    exit 1

fi

}


install_dependencies(){

msg "Instalando dependencias..."

apt-get update -y

apt-get install -y \
curl \
openssl \
iptables \
jq \
libc6-i386


msg "Dependencias instaladas"

}


enable_forward(){

msg "Activando IPv4 Forward..."


sysctl -w net.ipv4.ip_forward=1 >/dev/null


if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf
then

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

fi


}
create_config(){

PORT=$1


msg "Creando configuración ZiVPN..."


mkdir -p "$ZIVPN_DIR"


cat > "$CONFIG" <<EOF
{
    "listen": ":$PORT",
    "cert": "$ZIVPN_DIR/zivpn.crt",
    "key": "$ZIVPN_DIR/zivpn.key",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": [
            "123456"
        ]
    }
}
EOF


echo "$PORT" > "$PORT_FILE"


chmod 644 "$CONFIG"


msg "Configuración creada"

}



create_service(){


msg "Creando servicio systemd..."


cat > "$SERVICE" <<EOF
[Unit]
Description=KevinTech ZiVPN UDP Server
After=network.target


[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn

ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json

Restart=always
RestartSec=3

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW


[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload


systemctl enable zivpn.service


systemctl restart zivpn.service


msg "Servicio ZiVPN iniciado"

}



check_service(){


sleep 2


if systemctl is-active --quiet zivpn.service

then

    msg "ZiVPN está funcionando correctamente"

else

    error "ZiVPN no inició"

    journalctl -u zivpn.service -n 20 --no-pager

fi


}



install_zivpn(){


read -p "Puerto UDP para ZiVPN: " PORT


if [ -z "$PORT" ]; then

PORT="7300"

fi


install_dependencies

enable_forward

detect_arch

install_binary

create_certificates

create_config "$PORT"

create_service

check_service


}
detect_arch(){

msg "Detectando arquitectura..."


ARCH=$(uname -m)


case "$ARCH" in

x86_64)

    ZIVPN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"

;;

aarch64|arm64)

    ZIVPN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"

;;

*)

    error "Arquitectura no soportada: $ARCH"

    exit 1

;;

esac


msg "Arquitectura compatible: $ARCH"

}



install_binary(){

if [ -f "$BIN" ]; then

    msg "Binario ZiVPN ya existe"

    return

fi


msg "Descargando ZiVPN..."


curl -L \
--fail \
-o "$BIN" \
"$ZIVPN_URL"


if [ ! -f "$BIN" ]; then

    error "No se pudo descargar ZiVPN"

    exit 1

fi


chmod +x "$BIN"


msg "Binario instalado correctamente"

}



create_certificates(){

msg "Generando certificados..."


mkdir -p "$ZIVPN_DIR"


openssl req \
-new \
-newkey rsa:4096 \
-days 3650 \
-nodes \
-x509 \
-subj "/C=US/ST=CA/L=LA/O=KevinTech/CN=zivpn" \
-keyout "$ZIVPN_DIR/zivpn.key" \
-out "$ZIVPN_DIR/zivpn.crt" \
>/dev/null 2>&1



if [ -f "$ZIVPN_DIR/zivpn.crt" ]; then

    msg "Certificado creado"

else

    error "Falló la creación del certificado"

    exit 1

fi


}
setup_iptables(){


PORT=$1


msg "Configurando reglas IPTables..."


DEV=$(ip -4 route show default | awk '{print $5}' | head -1)



if [ -z "$DEV" ]; then

    warning "No se detectó interfaz de red"

    return

fi



# Limpiar reglas antiguas ZiVPN

iptables -t nat -S PREROUTING | grep "6000:19999" |
sed 's/-A/-D/' |
while read RULE

do

iptables -t nat $RULE

done



iptables -S INPUT | grep "6000:19999" |
sed 's/-A/-D/' |
while read RULE

do

iptables $RULE

done



# Permitir puerto ZiVPN

iptables -I INPUT 1 \
-p udp \
--dport "$PORT" \
-j ACCEPT



# Permitir rango externo

iptables -I INPUT 1 \
-p udp \
--dport 6000:19999 \
-j ACCEPT



# Redirección UDP

iptables -t nat -I PREROUTING 1 \
-i "$DEV" \
-p udp \
--dport 6000:19999 \
-j REDIRECT \
--to-port "$PORT"



# NAT retorno

iptables -t nat -D POSTROUTING \
-o "$DEV" \
-j MASQUERADE 2>/dev/null



iptables -t nat -A POSTROUTING \
-o "$DEV" \
-j MASQUERADE



msg "IPTables configurado"

}



add_user(){


read -p "Nueva contraseña ZiVPN: " PASS


if [ -z "$PASS" ]; then

error "Contraseña vacía"

return

fi



jq ".auth.config += [\"$PASS\"] | .auth.config |= unique" \
"$CONFIG" \
> /tmp/zivpn.json



mv /tmp/zivpn.json "$CONFIG"



systemctl restart zivpn.service


msg "Usuario agregado: $PASS"

}



remove_user(){


read -p "Contraseña a eliminar: " PASS



jq ".auth.config -= [\"$PASS\"]" \
"$CONFIG" \
> /tmp/zivpn.json



mv /tmp/zivpn.json "$CONFIG"



systemctl restart zivpn.service


msg "Usuario eliminado"

}



list_users(){


echo

msg "Usuarios ZiVPN actuales:"


jq -r '.auth.config[]' "$CONFIG"


echo

}
restore_users(){


FILE="/etc/kevintech/usuarios/zivpn.txt"


if [ ! -f "$FILE" ]; then

    warning "No existe archivo de usuarios: $FILE"

    return

fi



while read -r PASS

do


if [ -n "$PASS" ]; then


jq ".auth.config += [\"$PASS\"] | .auth.config |= unique" \
"$CONFIG" \
> /tmp/zivpn.json


mv /tmp/zivpn.json "$CONFIG"


fi


done < "$FILE"



systemctl restart zivpn.service


msg "Usuarios restaurados"

}



remove_zivpn(){


msg "Eliminando ZiVPN..."


systemctl stop zivpn.service 2>/dev/null

systemctl disable zivpn.service 2>/dev/null



rm -f "$SERVICE"

rm -rf "$ZIVPN_DIR"

rm -f "$BIN"



systemctl daemon-reload



msg "ZiVPN eliminado correctamente"

}



status_zivpn(){


systemctl status zivpn.service --no-pager


}



menu(){


while true

do


clear


echo "
=================================
       KevinTech ZiVPN
=================================

1) Instalar ZiVPN

2) Configurar IPTables

3) Agregar usuario

4) Eliminar usuario

5) Lista usuarios

6) Restaurar usuarios

7) Estado ZiVPN

8) Desinstalar ZiVPN

0) Salir

=================================
"


read -p "Selecciona una opción: " OP



case $OP in


1)

install_zivpn

PORT=$(cat "$PORT_FILE" 2>/dev/null)

[ -n "$PORT" ] && setup_iptables "$PORT"

;;



2)

PORT=$(cat "$PORT_FILE")

setup_iptables "$PORT"

;;



3)

add_user

;;



4)

remove_user

;;



5)

list_users

;;



6)

restore_users

;;



7)

status_zivpn

;;



8)

remove_zivpn

;;



0)

exit

;;



*)

warning "Opción inválida"

;;

esac



echo

read -p "Presiona ENTER para continuar..."


done

}



# ==========================
# INICIO
# ==========================


check_root

menu
