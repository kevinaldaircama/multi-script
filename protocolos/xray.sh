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
