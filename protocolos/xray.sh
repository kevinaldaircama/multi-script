#!/bin/bash

#==================================================
# KevinTech Multi Script
# Xray / V2Ray Manager
# Compatible Ubuntu 18.04 / 20.04 / 22.04 / 24.04
# Parte 1/10
#==================================================


BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="$XRAY_DIR/config.json"

V2RAY_DIR="$BASE/v2ray"
USERS_DB="$V2RAY_DIR/users.db"


#==============================
# COLORES
#==============================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
RESET="\e[0m"



#==============================
# ROOT
#==============================

if [[ $EUID -ne 0 ]]; then

echo -e "${RED}Ejecuta como root${RESET}"
exit 1

fi



#==============================
# CARGAR CONFIG
#==============================

if [[ ! -f "$CONFIG" ]]; then

echo "❌ No existe configuración KevinTech"
exit 1

fi


source "$CONFIG"



#==============================
# DIRECTORIOS
#==============================

mkdir -p "$V2RAY_DIR"
mkdir -p "$XRAY_DIR"



touch "$USERS_DB"



#==============================
# INSTALAR DEPENDENCIAS
#==============================

install_dependencies(){

echo -e "${CYAN}Instalando dependencias...${RESET}"


apt update -y


apt install -y \
curl \
wget \
uuid-runtime \
jq \
nginx \
certbot \
openssl



echo -e "${GREEN}✔ Dependencias listas${RESET}"

}



#==============================
# INSTALAR XRAY CORE
#==============================

install_xray(){


if command -v xray >/dev/null 2>&1
then

echo "Xray ya está instalado"

return

fi



echo -e "${CYAN}Instalando Xray Core...${RESET}"


bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install



systemctl enable xray



echo -e "${GREEN}✔ Xray instalado${RESET}"


}



#==============================
# ESTADO
#==============================

xray_status(){


if systemctl is-active --quiet xray
then

echo -e "${GREEN}🟢 ACTIVO${RESET}"

else

echo -e "${RED}🔴 DETENIDO${RESET}"

fi


}
#==============================
# CONFIGURAR SSL XRAY
# NGINX + LET'S ENCRYPT
#==============================

install_ssl_xray(){


echo -e "${CYAN}Configurando certificado SSL...${RESET}"


if [[ -z "$SERVER_DOMAIN" ]]; then

echo -e "${RED}❌ No hay dominio configurado${RESET}"

return

fi



# Verificar dominio

IP=$(curl -4 -s ifconfig.me)

DOMAIN_IP=$(dig +short "$SERVER_DOMAIN" | head -n1)


if [[ "$DOMAIN_IP" != "$IP" ]]; then

echo -e "${RED}❌ El dominio no apunta a esta VPS${RESET}"

echo "Dominio : $SERVER_DOMAIN"
echo "IP VPS  : $IP"
echo "DNS     : $DOMAIN_IP"

return

fi



echo -e "${GREEN}✔ Dominio correcto${RESET}"



echo "Generando certificado..."



certbot certonly \
--nginx \
-d "$SERVER_DOMAIN" \
--non-interactive \
--agree-tos \
-m admin@"$SERVER_DOMAIN"



if [[ $? -ne 0 ]]; then

echo -e "${RED}❌ Error generando SSL${RESET}"

return

fi



echo -e "${GREEN}✔ Certificado creado${RESET}"



#==============================
# NGINX SSL
#==============================


cat > /etc/nginx/conf.d/vmess.conf <<EOF
server {

    listen 443 ssl http2;

    server_name $SERVER_DOMAIN;


    ssl_certificate /etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem;

    ssl_certificate_key /etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem;



    location /vmess {


        proxy_redirect off;


        proxy_pass http://127.0.0.1:10000;


        proxy_http_version 1.1;


        proxy_set_header Upgrade \$http_upgrade;


        proxy_set_header Connection "upgrade";


        proxy_set_header Host \$host;


        proxy_set_header X-Real-IP \$remote_addr;


    }


}



server {

    listen 80;

    server_name $SERVER_DOMAIN;


    return 301 https://\$host\$request_uri;

}

EOF



nginx -t


if [[ $? -eq 0 ]]; then


systemctl restart nginx


sed -i '/^V2RAY=/d' "$CONFIG"
echo "V2RAY=ON" >> "$CONFIG"


echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ SSL XRAY ACTIVO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Dominio : $SERVER_DOMAIN"
echo "Puerto  : 443"
echo "Path    : /vmess"
echo "TLS     : ON"


else


echo -e "${RED}❌ Error configurando Nginx SSL${RESET}"


fi


}
#==============================
# CREAR CONFIG XRAY
# VMESS + WEBSOCKET
#==============================

create_xray_config(){


echo -e "${CYAN}Creando configuración Xray...${RESET}"


cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [

    {
      "listen": "127.0.0.1",
      "port": 10000,

      "protocol": "vmess",

      "settings": {

        "clients": []

      },

      "streamSettings": {

        "network": "ws",

        "security": "none",

        "wsSettings": {

          "path": "/vmess"

        }

      }
    }

  ],


  "outbounds": [

    {
      "protocol": "freedom"
    },

    {
      "protocol": "blackhole",
      "tag": "block"
    }

  ]
}
EOF



mkdir -p /var/log/xray

touch /var/log/xray/access.log
touch /var/log/xray/error.log


chmod 644 "$XRAY_CONFIG"



systemctl daemon-reload

systemctl restart xray



if systemctl is-active --quiet xray
then

echo -e "${GREEN}✔ Xray iniciado correctamente${RESET}"

else

echo -e "${RED}❌ Error iniciando Xray${RESET}"

journalctl -u xray -n 20 --no-pager

fi


}




#==============================
# CONFIGURAR NGINX
# WEBSOCKET /VMESS
#==============================

create_nginx_config(){


echo -e "${CYAN}Configurando Nginx...${RESET}"



cat > /etc/nginx/conf.d/vmess.conf <<EOF
server {

    listen 80;

    server_name ${SERVER_DOMAIN};


    location /vmess {


        proxy_redirect off;

        proxy_pass http://127.0.0.1:10000;


        proxy_http_version 1.1;


        proxy_set_header Upgrade \$http_upgrade;

        proxy_set_header Connection "upgrade";


        proxy_set_header Host \$host;


        proxy_set_header X-Real-IP \$remote_addr;


        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;


    }


}
EOF



nginx -t


if [[ $? -eq 0 ]]
then

systemctl restart nginx

echo -e "${GREEN}✔ Nginx configurado${RESET}"

else

echo -e "${RED}❌ Error en configuración Nginx${RESET}"

fi


}
#==============================
# CREAR USUARIO VMESS
#==============================

create_vmess_user(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          👤 CREAR CUENTA VMESS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


read -rp "➤ Usuario: " USER


if [[ -z "$USER" ]]; then

echo -e "${RED}Usuario vacío${RESET}"

sleep 2

return

fi



# Verificar si existe

if grep -q "^$USER|" "$USERS_DB"; then

echo -e "${RED}El usuario ya existe${RESET}"

sleep 2

return

fi



read -rp "➤ Días de duración [30]: " DAYS


[[ -z "$DAYS" ]] && DAYS=30



UUID=$(uuidgen)



EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")



# Guardar usuario

echo "$USER|$UUID|$EXP" >> "$USERS_DB"



# Agregar usuario a Xray


python3 <<PYTHON

import json


config="$XRAY_CONFIG"


with open(config) as f:
    data=json.load(f)


clients=data["inbounds"][0]["settings"]["clients"]


clients.append({

    "id":"$UUID",

    "level":0,

    "email":"$USER"

})


with open(config,"w") as f:
    json.dump(data,f,indent=2)

PYTHON



systemctl restart xray



IP=$(curl -4 -s ifconfig.me)



echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${GREEN}       ✅ CUENTA VMESS CREADA${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo

echo -e "${WHITE}Usuario : ${GREEN}$USER"

echo -e "${WHITE}UUID    : ${GREEN}$UUID"

echo -e "${WHITE}Expira  : ${GREEN}$EXP"

echo -e "${WHITE}Dominio : ${GREEN}$SERVER_DOMAIN"

echo -e "${WHITE}Puerto  : ${GREEN}443"

echo -e "${WHITE}Path    : ${GREEN}/vmess"

echo -e "${WHITE}TLS     : ${GREEN}ON"


echo

echo -e "${YELLOW}Compatible:${RESET}"

echo "✔ HTTP Injector"

echo "✔ HTTP Custom"

echo "✔ v2rayNG"

echo "✔ NekoBox"



echo

read -n1 -r -p "Presiona una tecla..."

}
#==============================
# GENERAR LINK VMESS
#==============================

generate_vmess_link(){


USER="$1"


DATA=$(grep "^$USER|" "$USERS_DB")


if [[ -z "$DATA" ]]; then

echo -e "${RED}Usuario no encontrado${RESET}"

return

fi



UUID=$(echo "$DATA" | cut -d "|" -f2)

EXP=$(echo "$DATA" | cut -d "|" -f3)



VMESS_JSON=$(cat <<EOF
{
"v":"2",
"ps":"$USER",
"add":"$SERVER_DOMAIN",
"port":"443",
"id":"$UUID",
"aid":"0",
"scy":"auto",
"net":"ws",
"type":"none",
"host":"$SERVER_DOMAIN",
"path":"/vmess",
"tls":"tls",
"sni":"$SERVER_DOMAIN"
}
EOF
)



LINK=$(echo -n "$VMESS_JSON" | base64 -w 0)



IP=$(curl -4 -s ifconfig.me)



clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}          🔐 DATOS DE CONEXIÓN VMESS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo

echo -e "${WHITE}DOMINIO  : ${GREEN}$SERVER_DOMAIN"

echo -e "${WHITE}IP VPS   : ${GREEN}$IP"

echo -e "${WHITE}USUARIO  : ${GREEN}$USER"

echo -e "${WHITE}UUID     : ${GREEN}$UUID"

echo -e "${WHITE}PUERTO   : ${GREEN}443"

echo -e "${WHITE}PATH     : ${GREEN}/vmess"

echo -e "${WHITE}TLS      : ${GREEN}SI"

echo -e "${WHITE}EXPIRA   : ${GREEN}$EXP"



echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${YELLOW}VMESS LINK:${RESET}"

echo

echo "vmess://$LINK"



echo

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e "${YELLOW}Configuración manual:${RESET}"

echo

echo "Host/SNI : $SERVER_DOMAIN"

echo "WS Path  : /vmess"

echo "TLS      : Activado"

echo "Puerto   : 443"


echo

echo -e "${CYAN}Apps compatibles:${RESET}"

echo "✔ HTTP Injector"

echo "✔ HTTP Custom"

echo "✔ v2rayNG"

echo "✔ NapsternetV"

echo "✔ TLS Tunnel"



echo

read -n1 -r -p "Presiona una tecla..."

}
#==============================
# LISTAR USUARIOS VMESS
#==============================

list_vmess_users(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          📋 CUENTAS VMESS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


if [[ ! -s "$USERS_DB" ]]; then

echo -e "${YELLOW}No hay usuarios creados${RESET}"

sleep 2

return

fi



NUM=1


while IFS="|" read -r USER UUID EXP

do


echo

echo -e "${GREEN}$NUM)${RESET} Usuario : $USER"

echo "   UUID   : $UUID"

echo "   Expira : $EXP"


NUM=$((NUM+1))


done < "$USERS_DB"



echo

read -n1 -r -p "Presiona una tecla..."

}





#==============================
# ELIMINAR USUARIO VMESS
#==============================

delete_vmess_user(){


clear


read -rp "Usuario a eliminar: " USER



if ! grep -q "^$USER|" "$USERS_DB"; then

echo -e "${RED}Usuario no existe${RESET}"

sleep 2

return

fi



UUID=$(grep "^$USER|" "$USERS_DB" | cut -d "|" -f2)



# Eliminar del archivo DB

grep -v "^$USER|" "$USERS_DB" > /tmp/users.db

mv /tmp/users.db "$USERS_DB"



# Eliminar de Xray

python3 <<PYTHON

import json


file="$XRAY_CONFIG"


with open(file) as f:
    data=json.load(f)


clients=data["inbounds"][0]["settings"]["clients"]


data["inbounds"][0]["settings"]["clients"]=[

c for c in clients

if c.get("id") != "$UUID"

]


with open(file,"w") as f:
    json.dump(data,f,indent=2)

PYTHON



systemctl restart xray



echo

echo -e "${GREEN}✔ Usuario eliminado correctamente${RESET}"

sleep 3


}





#==============================
# BUSCAR USUARIO
#==============================

search_vmess_user(){


clear


read -rp "Buscar usuario: " USER



DATA=$(grep "^$USER|" "$USERS_DB")



if [[ -z "$DATA" ]]; then

echo -e "${RED}Usuario no encontrado${RESET}"

else


UUID=$(echo "$DATA" | cut -d "|" -f2)

EXP=$(echo "$DATA" | cut -d "|" -f3)



echo

echo "Usuario : $USER"

echo "UUID    : $UUID"

echo "Expira  : $EXP"



fi


sleep 3


}




#==============================
# MENU VMESS
#==============================

vmess_panel(){


while true

do


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}          🚀 VMESS PANEL${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo

echo "[1] Crear cuenta VMess"

echo "[2] Ver cuentas"

echo "[3] Generar link VMess"

echo "[4] Buscar usuario"

echo "[5] Eliminar usuario"

echo "[0] Salir"


echo

read -rp "Opción: " OP



case "$OP" in


1)

create_vmess_user

;;


2)

list_vmess_users

;;


3)

read -rp "Usuario: " USER

generate_vmess_link "$USER"

;;


4)

search_vmess_user

;;


5)

delete_vmess_user

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
#==============================
# INSTALAR XRAY CORE
#==============================

install_xray_core(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        📦 INSTALANDO XRAY CORE${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



if command -v xray >/dev/null 2>&1
then

echo -e "${GREEN}✔ Xray ya está instalado${RESET}"

else


echo "Descargando instalador oficial..."



bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install



if command -v xray >/dev/null 2>&1
then

echo -e "${GREEN}✔ Xray instalado correctamente${RESET}"

else

echo -e "${RED}❌ Error instalando Xray${RESET}"

return 1

fi


fi




#==============================
# CREAR DIRECTORIOS
#==============================


mkdir -p /usr/local/etc/xray

mkdir -p /var/log/xray

mkdir -p "$BASE/v2ray"

touch "$USERS_DB"



chmod 755 /usr/local/etc/xray

chmod 755 /var/log/xray





#==============================
# CONFIGURACIÓN INICIAL
#==============================


if [[ ! -f "$XRAY_CONFIG" ]]
then


echo "Creando configuración inicial..."

create_xray_config


else

echo "Configuración existente encontrada"


fi




#==============================
# SERVICIO SYSTEMD
#==============================


mkdir -p /etc/systemd/system/xray.service.d



cat > /etc/systemd/system/xray.service.d/restart.conf <<EOF
[Service]

Restart=always

RestartSec=5

EOF



systemctl daemon-reload


systemctl enable xray


systemctl restart xray





if systemctl is-active --quiet xray

then


echo

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${GREEN}   ✅ XRAY ACTIVO${RESET}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


else


echo -e "${RED}❌ Xray no pudo iniciar${RESET}"

journalctl -u xray -n 20 --no-pager


fi


sleep 3


}





#==============================
# VERIFICAR XRAY
#==============================

status_xray(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}        ESTADO XRAY${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



systemctl status xray --no-pager



echo

echo "Puerto VMess interno: 10000"

echo "WebSocket Path: /vmess"


echo

read -n1 -r -p "Presiona una tecla..."

}





#==============================
# REINICIAR XRAY
#==============================


restart_xray(){


systemctl restart xray


sleep 2



if systemctl is-active --quiet xray

then

echo -e "${GREEN}✔ Xray reiniciado${RESET}"

else

echo -e "${RED}❌ Error reiniciando Xray${RESET}"

fi


sleep 2


}
#==============================
# DESINSTALAR XRAY
#==============================

remove_xray(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        🗑️ ELIMINAR XRAY${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


read -rp "¿Eliminar Xray completamente? (s/n): " R



if [[ ! "$R" =~ ^[Ss]$ ]]
then

echo "Cancelado"

sleep 2

return

fi



systemctl stop xray 2>/dev/null

systemctl disable xray 2>/dev/null



bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove



rm -rf /usr/local/etc/xray

rm -rf /var/log/xray

rm -rf "$BASE/v2ray"



sed -i '/^V2RAY=/d' "$CONFIG"

echo "V2RAY=OFF" >> "$CONFIG"



echo

echo -e "${GREEN}✔ Xray eliminado${RESET}"

sleep 3


}





#==============================
# MENU V2RAY MANAGER
#==============================


v2ray_manager(){


while true

do


clear


source "$CONFIG"



if systemctl is-active --quiet xray

then

STATUS="${GREEN}🟢 ACTIVO${RESET}"

else

STATUS="${RED}🔴 DETENIDO${RESET}"

fi



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}             🚀 V2RAY MANAGER${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e " Estado : $STATUS"

echo -e " Dominio: ${SERVER_DOMAIN:-NO CONFIGURADO}"

echo -e " Puerto : 443"

echo -e " WS     : /vmess"

echo


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



cat <<EOF

 [1] ➮ Instalar Xray Core

 [2] ➮ Crear cuenta VMess

 [3] ➮ Ver cuentas

 [4] ➮ Generar Link VMess

 [5] ➮ Buscar usuario

 [6] ➮ Eliminar usuario

 [7] ➮ Estado Xray

 [8] ➮ Reiniciar Xray

 [9] ➮ Desinstalar Xray

 [0] ➮ Regresar

EOF



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


read -rp " ► Opción: " OP



case "$OP" in


1)

install_xray_core

;;



2)

create_vmess_user

;;



3)

list_vmess_users

;;



4)

read -rp "Usuario: " USER

generate_vmess_link "$USER"

;;



5)

search_vmess_user

;;



6)

delete_vmess_user

;;



7)

status_xray

;;



8)

restart_xray

;;



9)

remove_xray

;;



0)

break

;;



*)

echo "❌ Opción inválida"

sleep 2

;;


esac


done


}
