#!/bin/bash

# =========================================================
# GESTOR HYSTERIA V1 - PRO UNIFICADO
# =========================================================

# --- Matriz de Colores ---
COLOR[0]='\033[1;37m' # Blanco
COLOR[1]='\e[93m'     # Amarillo claro
COLOR[2]='\e[32m'     # Verde
COLOR[3]='\e[31m'     # Rojo
COLOR[4]='\e[34m'     # Azul
COLOR[5]='\e[95m'     # Magenta
COLOR[6]='\033[1;97m' # Blanco brillante
COLOR[7]='\033[36m'   # Cian
NC='\e[0m'

CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="/etc/hysteria/config.json"
EXECUTABLE="/usr/local/bin/hysteria1"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria1-server.service"

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

mkdir -p "$BASE"
touch "$CONFIG"

config_set() {
    KEY="$1"
    VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG"
    else
        echo "${KEY}=${VALUE}" >> "$CONFIG"
    fi
}

config_get() {
    grep "^$1=" "$CONFIG" | cut -d= -f2-
}

# --- Crear comando permanente 'menuhy' ---
# Usamos un método más robusto para que el comando funcione siempre
if [[ ! -f "/usr/local/bin/menuhy" ]]; then
    echo "bash $(readlink -f "$0")" > /usr/local/bin/menuhy
    chmod +x /usr/local/bin/menuhy
fi

stop_hys() { systemctl stop hysteria1-server > /dev/null 2>&1; pkill -f hysteria1 > /dev/null 2>&1; }

# --- Función de Logs mejorada ---
show_logs() {
    echo -e "${COLOR[1]}Mostrando logs (Presiona Ctrl+C para detener la lectura)...${NC}"
    echo -e "${COLOR[7]}Una vez que te detengas, presiona Enter para volver al menú.${NC}"
    sleep 2
    journalctl -u hysteria1-server -n 50 -f
    echo -e "\n${COLOR[2]}Lectura de log finalizada.${NC}"
    read -p "Presione [Enter] para regresar al menú..."
}

# --- Función para mostrar configuración ---
show_config() {
    clear

    if systemctl is-active --quiet hysteria1-server; then
        STATUS="${COLOR[2]}● ACTIVO${NC}"
    else
        STATUS="${COLOR[3]}● DETENIDO${NC}"
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${COLOR[3]}No existe ninguna configuración instalada.${NC}"
        read -p "Presione Enter..."
        return
    fi

    IP=$(curl -s ipv4.icanhazip.com)
    PORT=$(grep -oP '"listen":\s*":\K[0-9]+' "$CONFIG_FILE")
    AUTH=$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE")
    OBFS=$(grep -oP '"obfs":\s*"\K[^"]+' "$CONFIG_FILE")

    echo -e "${COLOR[5]}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${COLOR[5]}║${NC}${COLOR[6]}           INFORMACIÓN DEL SERVIDOR UDP          ${NC}${COLOR[5]}║${NC}"
    echo -e "${COLOR[5]}╠══════════════════════════════════════════════════════╣${NC}"
    printf "${COLOR[5]}║${NC} %-18s %b\n" "Estado :" "$STATUS"
    printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}%s${NC}\n" "IP Pública :" "$IP"
    printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}%s${NC}\n" "Puerto UDP :" "$PORT"
    printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}%s${NC}\n" "AUTH :" "$AUTH"

    if [[ -n "$OBFS" ]]; then
        printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}%s${NC}\n" "OBFS :" "$OBFS"
    else
        printf "${COLOR[5]}║${NC} %-18s ${COLOR[3]}No configurado${NC}\n" "OBFS :"
    fi

    DOMAIN=$(config_get SERVER_DOMAIN)
if [[ -z "$DOMAIN" ]]; then
    echo
    echo -e "${COLOR[3]}No hay un dominio configurado.${NC}"
    echo -e "${COLOR[1]}Configura primero el dominio del servidor.${NC}"
    echo
    read -p "Presione Enter para continuar..."
    return
fi

printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}%s${NC}\n" "SNI :" "$DOMAIN"
    printf "${COLOR[5]}║${NC} %-18s ${COLOR[7]}h3${NC}\n" "ALPN :"

    echo -e "${COLOR[5]}╚══════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Presione Enter para volver..."
}

# --- Función de Modificación ---
modify_config() {
while true; do
    clear

    PORT=$(grep -oP '"listen":\s*":\K[0-9]+' "$CONFIG_FILE")
    AUTH=$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE")
    OBFS=$(grep -oP '"obfs":\s*"\K[^"]+' "$CONFIG_FILE")

    echo -e "${COLOR[5]}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${COLOR[5]}║${NC}${COLOR[6]}           PANEL DE CONFIGURACIÓN UDP          ${NC}${COLOR[5]}║${NC}"
    echo -e "${COLOR[5]}╠════════════════════════════════════════════════════╣${NC}"
    echo -e "${COLOR[5]}║${NC} Puerto : ${COLOR[7]}${PORT}${NC}"
    echo -e "${COLOR[5]}║${NC} AUTH   : ${COLOR[7]}${AUTH}${NC}"
    echo -e "${COLOR[5]}║${NC} OBFS   : ${COLOR[7]}${OBFS:-No configurado}${NC}"
    echo -e "${COLOR[5]}╠════════════════════════════════════════════════════╣${NC}"
    echo -e "${COLOR[5]}║${NC} ${COLOR[2]}1${NC}) Cambiar Puerto UDP"
    echo -e "${COLOR[5]}║${NC} ${COLOR[2]}2${NC}) Cambiar AUTH"
    echo -e "${COLOR[5]}║${NC} ${COLOR[2]}3${NC}) Cambiar OBFS"
    echo -e "${COLOR[5]}║${NC} ${COLOR[2]}4${NC}) Eliminar OBFS"
    echo -e "${COLOR[5]}║${NC} ${COLOR[2]}0${NC}) Volver"
    echo -e "${COLOR[5]}╚════════════════════════════════════════════════════╝${NC}"
    echo

    read -p "Seleccione: " opt

    case $opt in

    1)
        read -p "Nuevo Puerto: " NEW
        sed -i "s/\"listen\": \":.*/\"listen\": \":$NEW\",/g" "$CONFIG_FILE"
        ;;

    2)
        read -p "Nuevo AUTH: " NEW
        sed -i "s/\"password\": \".*\"/\"password\": \"$NEW\"/g" "$CONFIG_FILE"
        ;;

    3)
        read -p "Nuevo OBFS: " NEW

        if grep -q '"obfs"' "$CONFIG_FILE"; then
            sed -i "s/\"obfs\": \".*\"/\"obfs\": \"$NEW\"/g" "$CONFIG_FILE"
        else
            sed -i "3i\    \"obfs\": \"$NEW\"," "$CONFIG_FILE"
        fi
        ;;

    4)
        sed -i '/"obfs"/d' "$CONFIG_FILE"
        ;;

    0)
        return
        ;;

    *)
        echo -e "${COLOR[3]}Opción inválida.${NC}"
        sleep 1
        continue
        ;;
    esac

    systemctl restart hysteria1-server
config_set "HYSTERIA_PORT" "$(grep -oP '"listen":\s*":\K[0-9]+' "$CONFIG_FILE")"
config_set "HYSTERIA_AUTH" "$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE")"

OBFS=$(grep -oP '"obfs":\s*"\K[^"]+' "$CONFIG_FILE")
config_set "HYSTERIA_OBFS" "${OBFS:-OFF}"
    echo
    echo -e "${COLOR[2]}✔ Configuración actualizada correctamente.${NC}"
    sleep 2

done
}

# --- Proceso de Instalación ---
install_hys() {

clear
DOMAIN=$(config_get SERVER_DOMAIN)

if [[ -z "$DOMAIN" ]]; then
    echo
    echo -e "${COLOR[3]}No hay un dominio configurado.${NC}"
    echo -e "${COLOR[1]}Configura primero el dominio del servidor.${NC}"
    echo
    read -p "Presione Enter para continuar..."
    return
fi

echo -e "${COLOR[5]}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${COLOR[5]}║${NC}${COLOR[6]}         INSTALADOR HYSTERIA V1 PRO          ${NC}${COLOR[5]}║${NC}"
echo -e "${COLOR[5]}╚════════════════════════════════════════════════════╝${NC}"
echo

port=$(shuf -i 2000-65000 -n1)

read -p "AUTH [Enter=Aleatorio]: " auth_pass
[[ -z "$auth_pass" ]] && auth_pass=$(openssl rand -hex 6)

read -p "OBFS [Opcional]: " obfs_key

mkdir -p "$CONFIG_DIR"

progress() {
    echo -ne "\r${COLOR[2]}[$1]${NC} $2..."
}

progress "1/6" "Descargando Core"

ARCH=$(uname -m)

case "$ARCH" in
x86_64) FILE="hysteria-linux-amd64" ;;
aarch64|arm64) FILE="hysteria-linux-arm64" ;;
armv7l) FILE="hysteria-linux-arm" ;;
*) echo; echo "Arquitectura no soportada."; read; return ;;
esac

wget -qO "$EXECUTABLE" "https://github.com/apernet/hysteria/releases/download/v1.3.5/$FILE" || {
echo
echo "Error al descargar."
read
return
}

chmod +x "$EXECUTABLE"

progress "2/6" "Generando Certificados"

openssl ecparam -genkey -name prime256v1 -out "$CONFIG_DIR/private.key" >/dev/null 2>&1

openssl req -new -x509 \
-days 36500 \
-nodes \
-key "$CONFIG_DIR/private.key" \
-out "$CONFIG_DIR/cert.crt" \
-subj "/CN=$DOMAIN" >/dev/null 2>&1

progress "3/6" "Creando Configuración"

[[ -n "$obfs_key" ]] && OBFS="\"obfs\":\"$obfs_key\","

cat > "$CONFIG_FILE" <<EOF
{
"protocol":"udp",
"listen":":$port",
$OBFS
"cert":"$CONFIG_DIR/cert.crt",
"key":"$CONFIG_DIR/private.key",
"alpn":"h3",
"auth":{
"mode":"password",
"config":{
"password":"$auth_pass"
}
}
}
EOF

progress "4/6" "Creando Servicio"

cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Hysteria V1
After=network.target

[Service]
ExecStart=$EXECUTABLE -config $CONFIG_FILE server
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

progress "5/6" "Iniciando Servicio"

systemctl daemon-reload
systemctl enable hysteria1-server >/dev/null 2>&1
systemctl restart hysteria1-server

progress "6/6" "Finalizando"

sleep 1

clear

IP=$(curl -s ipv4.icanhazip.com)

echo -e "${COLOR[2]}"
echo "══════════════════════════════════════"
echo "      INSTALACIÓN FINALIZADA"
echo "══════════════════════════════════════"
echo -e "${NC}"

echo "IP      : $IP"
echo "Puerto  : $port"
echo "AUTH    : $auth_pass"
echo "OBFS    : ${obfs_key:-No configurado}"
echo "SNI     : $DOMAIN"
echo "ALPN    : h3"

config_set "HYSTERIA" "ON"
config_set "HYSTERIA_PORT" "$port"
config_set "HYSTERIA_AUTH" "$auth_pass"
config_set "HYSTERIA_OBFS" "${obfs_key:-OFF}"

echo
read -p "Presione Enter para continuar..."

}

# ==========================
# MENÚ PRINCIPAL PRO
# ==========================
while true; do
    clear

    if systemctl is-active --quiet hysteria1-server; then
        STATUS="${COLOR[2]}● ACTIVO${NC}"
    else
        STATUS="${COLOR[3]}● DETENIDO${NC}"
    fi

    PORT=$(grep -oP '"listen":\s*":\K[0-9]+' "$CONFIG_FILE" 2>/dev/null)
    AUTH=$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null)

    echo -e "${COLOR[5]}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${COLOR[5]}║${NC}${COLOR[6]}              HYSTERIA V1 - UDP MANAGER PRO             ${NC}${COLOR[5]}║${NC}"
    echo -e "${COLOR[5]}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${COLOR[5]}║${NC} Estado : $STATUS"
    echo -e "${COLOR[5]}║${NC} Puerto : ${COLOR[7]}${PORT:-No instalado}${NC}"
    echo -e "${COLOR[5]}║${NC} Auth   : ${COLOR[7]}${AUTH:-No disponible}${NC}"
    echo -e "${COLOR[5]}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e " ${COLOR[2]}[1]${NC} 🚀 Instalar Hysteria V1"
    echo -e " ${COLOR[2]}[2]${NC} 🗑️  Desinstalar Hysteria"
    echo -e " ${COLOR[2]}[3]${NC} 🔄 Gestionar Servicio"
    echo -e " ${COLOR[2]}[4]${NC} ⚙️  Modificar Configuración"
    echo -e " ${COLOR[2]}[5]${NC} 📄 Ver Configuración"
    echo -e " ${COLOR[2]}[6]${NC} 📜 Ver Logs"
    echo -e " ${COLOR[2]}[0]${NC} 🚪 Salir"
    echo
    echo -ne "${COLOR[7]}Seleccione una opción ➜ ${NC}"
    read menuInput

    case $menuInput in
        1) install_hys ;;
        2)
          stop_hys

systemctl disable hysteria1-server >/dev/null 2>&1

rm -rf "$CONFIG_DIR"
rm -f "$EXECUTABLE"
rm -f "$SYSTEMD_SERVICE"

systemctl daemon-reload

config_set "HYSTERIA" "OFF"
config_set "HYSTERIA_PORT" ""
config_set "HYSTERIA_AUTH" ""
config_set "HYSTERIA_OBFS" ""
            echo -e "${COLOR[2]}✔ Hysteria eliminado correctamente.${NC}"
            sleep 2
        ;;
        3)
            clear
            echo -e "${COLOR[6]}=========== GESTOR DEL SERVICIO ===========${NC}"
            echo
            echo " 1) Iniciar"
            echo " 2) Detener"
            echo " 3) Reiniciar"
            echo " 4) Estado"
            echo " 0) Volver"
            echo
            read -p "Seleccione: " srv

            case $srv in
                1) systemctl start hysteria1-server ;;
                2) systemctl stop hysteria1-server ;;
                3) systemctl restart hysteria1-server ;;
                4)
                    systemctl status hysteria1-server --no-pager
                    read -p "Enter para continuar..."
                ;;
            esac
        ;;
        4) modify_config ;;
        5) show_config ;;
        6) show_logs ;;
        0) exit 0 ;;
        *) echo -e "${COLOR[3]}Opción inválida${NC}"; sleep 1 ;;
    esac
done
