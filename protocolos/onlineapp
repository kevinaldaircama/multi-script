#!/bin/bash
# ==========================================================
#        KevinTech Multi Script - Online App Service
# ==========================================================
# Actualiza los usuarios conectados para la aplicación web
# Autor: KevinTech
# ==========================================================

WEB_DIR="/var/www/html/server"
TXT_FILE="${WEB_DIR}/online"
JSON_FILE="${WEB_DIR}/online_app"
LIMIT="1500"

mkdir -p "$WEB_DIR"

get_online_users() {

    # SSH
    SSH_ONLINE=$(ps -x | grep "sshd:" | grep "priv" | grep -v grep | wc -l)

    # OpenVPN
    if [[ -f /etc/openvpn/openvpn-status.log ]]; then
        OVPN_ONLINE=$(grep -c "10.8.0" /etc/openvpn/openvpn-status.log)
    else
        OVPN_ONLINE=0
    fi

    # Dropbear
    if pgrep dropbear >/dev/null; then
        DROPBEAR_ONLINE=$(( $(pgrep -fc dropbear) - 1 ))
        [[ $DROPBEAR_ONLINE -lt 0 ]] && DROPBEAR_ONLINE=0
    else
        DROPBEAR_ONLINE=0
    fi

    TOTAL_ONLINE=$((SSH_ONLINE + OVPN_ONLINE + DROPBEAR_ONLINE))
}

save_online_files() {

    echo "$TOTAL_ONLINE" > "$TXT_FILE"

    cat > "$JSON_FILE" <<EOF
{
    "script":"KevinTech Multi Script",
    "status":"online",
    "online":"$TOTAL_ONLINE",
    "limit":"$LIMIT",
    "updated":"$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

}

while true; do
    get_online_users
    save_online_files
    sleep 15
done
