#!/bin/bash
set -u

# ============================================================
# KEVINTECH WEB INSTALLER
# Version: 3.7
# Panel HTTPS aislado de los protocolos VPN/Proxy
# ============================================================

BASE="/etc/kevintech"
WEB="$BASE/web"
DATA="$WEB/data"

SERVICE="kevintech-web.service"
ACME_SERVICE="kevintech-acme.service"

PORT=18080
ACME_PORT=18081

HAPROXY="/etc/haproxy/haproxy.cfg"
PEM="/etc/haproxy/kevintech-panel.pem"
DOMAIN_FILE="/etc/haproxy/kevintech-panel-domain"

ACME_ROOT="/var/www/letsencrypt"
HOOK="/etc/letsencrypt/renewal-hooks/deploy/kevintech-panel.sh"

CONFIG="$BASE/config.conf"

red='\e[1;91m'
green='\e[1;92m'
cyan='\e[1;96m'
yellow='\e[1;93m'
reset='\e[0m'

# ============================================================
# ROOT
# ============================================================

root_check() {
    [[ $EUID -eq 0 ]] || {
        echo -e "${red}Ejecuta como root.${reset}"
        exit 1
    }
}

# ============================================================
# DOMAIN
# ============================================================

valid_domain() {
    [[ "$1" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ &&
       "$1" != *".."* ]]
}

configured_domain() {
    local d=""

    [[ -f "$CONFIG" ]] &&
        d="$(awk -F'=' '/^SERVER_DOMAIN=/ {
            gsub(/^"|"$/,"",$2)
            print $2
            exit
        }' "$CONFIG" 2>/dev/null)"

    printf '%s' "$d"
}

current_domain() {
    [[ -f "$DOMAIN_FILE" ]] &&
        tr -d '[:space:]' < "$DOMAIN_FILE" ||
        true
}

write_domain_config() {
    printf '%s\n' "$1" > "$DOMAIN_FILE"
    chmod 600 "$DOMAIN_FILE"
}

# ============================================================
# SYSTEMD WEB
# ============================================================

write_service() {

    cat > "/etc/systemd/system/$SERVICE" <<EOF2
[Unit]
Description=KevinTech Web Panel
After=network-online.target haproxy.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

WorkingDirectory=$WEB

Environment=PYTHONUNBUFFERED=1
Environment=KEVINTECH_WEB_PORT=$PORT
Environment=KEVINTECH_WEB_PREFIX=/

ExecStart=/usr/bin/python3 $WEB/server.py

Restart=on-failure
RestartSec=5

TimeoutStartSec=30
TimeoutStopSec=20

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF2

    systemctl daemon-reload
    systemctl enable "$SERVICE" >/dev/null 2>&1 || true
}

# ============================================================
# ACME SERVICE
# ============================================================

write_acme_service() {

    mkdir -p "$ACME_ROOT/.well-known/acme-challenge"

    cat > "/etc/systemd/system/$ACME_SERVICE" <<EOF2
[Unit]
Description=KevinTech ACME webroot helper
After=network.target

[Service]
Type=simple
User=root

WorkingDirectory=$ACME_ROOT

ExecStart=/usr/bin/python3 -m http.server $ACME_PORT \
--directory $ACME_ROOT \
--bind 127.0.0.1

Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF2

    systemctl daemon-reload

    systemctl enable "$ACME_SERVICE" >/dev/null 2>&1 || true

    systemctl restart "$ACME_SERVICE"
}

# ============================================================
# CERTIFICATE RENEW HOOK
# ============================================================

write_renew_hook() {

    mkdir -p /etc/letsencrypt/renewal-hooks/deploy

    cat > "$HOOK" <<'EOF2'
#!/bin/sh

set -eu

domain_file="/etc/haproxy/kevintech-panel-domain"
pem="/etc/haproxy/kevintech-panel.pem"
cfg="/etc/haproxy/haproxy.cfg"

[ -s "$domain_file" ] || exit 0

domain=$(tr -d '[:space:]' < "$domain_file")

cat \
    "/etc/letsencrypt/live/$domain/fullchain.pem" \
    "/etc/letsencrypt/live/$domain/privkey.pem" \
    > "$pem"

chmod 600 "$pem"

haproxy -c -f "$cfg" >/dev/null 2>&1 &&
systemctl reload haproxy
EOF2

    chmod 700 "$HOOK"
}

# ============================================================
# TEMPORARY CERTIFICATE
# ============================================================

make_temp_cert() {

    local d="$1"

    mkdir -p "$(dirname "$PEM")"

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 1 \
        -subj "/CN=$d" \
        -keyout /tmp/kt-panel.key \
        -out /tmp/kt-panel.crt \
        >/dev/null 2>&1

    cat \
        /tmp/kt-panel.crt \
        /tmp/kt-panel.key \
        > "$PEM"

    chmod 600 "$PEM"

    rm -f \
        /tmp/kt-panel.key \
        /tmp/kt-panel.crt
}

# ============================================================
# HAPROXY
#
# IMPORTANTE:
#
# El panel NO usa el frontend TLS general.
#
# Se crea:
#
#   multiport_frontend
#          |
#          | SNI panel
#          v
#   panel_tls_backend
#          |
#          v
#   panel_tls_frontend
#          |
#          | HTTP/1.1
#          v
#   127.0.0.1:18080
#
# Esto evita el problema HTTP/2 que afectaba al panel.
# ============================================================

patch_haproxy() {

    local domain="$1"

    [[ -f "$HAPROXY" ]] || {
        echo -e "${red}No existe $HAPROXY${reset}"
        return 1
    }

    cp -a \
        "$HAPROXY" \
        "$HAPROXY.kevintech-web.bak"

    DOMAIN="$domain" \
    PEM="$PEM" \
    PORT="$PORT" \
    ACME_PORT="$ACME_PORT" \
    HAPROXY="$HAPROXY" \
    python3 - <<'PY'

import os
import subprocess
import shutil

from pathlib import Path


p = Path(os.environ["HAPROXY"])

s = p.read_text(errors="ignore")

domain = os.environ["DOMAIN"]
pem = os.environ["PEM"]
port = os.environ["PORT"]
acme_port = os.environ["ACME_PORT"]


# ============================================================
# BLOQUES KEVINTECH A ELIMINAR
#
# Esto permite actualizar varias veces sin duplicar bloques.
# ============================================================

blocks_to_remove = {
    "frontend panel_tls_frontend",
    "backend panel_tls_backend",
    "backend kevintech_web",
    "backend acme_backend",
}


def strip_named_blocks(text):

    lines = text.splitlines(True)

    out = []

    skip = False

    for line in lines:

        st = line.strip()

        # Inicio de bloque KevinTech
        if (
            not line.startswith((" ", "\t"))
            and st in blocks_to_remove
        ):
            skip = True
            continue

        if skip:

            # Nuevo bloque HAProxy
            if (
                line
                and not line[0].isspace()
                and st
            ):
                skip = False

            else:
                continue

        out.append(line)

    return "".join(out)


s = strip_named_blocks(s)


# ============================================================
# ELIMINAR REGLAS ANTIGUAS DEL PANEL
#
# Incluye el parche anterior que enviaba el panel a
# recir_https_backend.
# ============================================================

remove_fragments = (

    "acl acl_panel_sni ",

    "use_backend kevintech_web if acl_panel_sni",

    "use_backend recir_https_backend if acl_panel_sni",

    "acl acl_acme path_beg /.well-known/acme-challenge/",

    "use_backend acme_backend if acl_acme",
)


lines = s.splitlines(True)

s = "".join(
    line
    for line in lines
    if not any(
        fragment in line
        for fragment in remove_fragments
    )
)


# ============================================================
# QUITAR CERTIFICADO DEL FRONTEND GENERAL
#
# El certificado del panel será utilizado únicamente por
# panel_tls_frontend.
# ============================================================

lines = s.splitlines(True)

clean = []

for line in lines:

    if (
        pem in line
        and line.strip().startswith(
            "bind abns@haproxy-https"
        )
    ):
        continue

    clean.append(line)

s = "".join(clean)


# ============================================================
# ROUTING DEL PANEL EN :443
#
# Detectamos:
#
# frontend multiport_frontend
#
# y colocamos la regla ANTES del primer use_backend.
# ============================================================

lines = s.splitlines(True)

out = []

in_multi = False
inserted_panel = False


for line in lines:

    st = line.strip()


    if st.startswith("frontend "):

        in_multi = (
            st == "frontend multiport_frontend"
        )


    elif st.startswith(
        (
            "backend ",
            "listen ",
            "global",
            "defaults"
        )
    ):

        in_multi = False


    if (
        in_multi
        and st.startswith("use_backend ")
        and not inserted_panel
    ):

        out.append(
            f"    acl acl_panel_sni req.ssl_sni -i {domain}\n"
        )

        out.append(
            "    use_backend panel_tls_backend if acl_panel_sni\n"
        )

        inserted_panel = True


    out.append(line)


# ============================================================
# FALLBACK:
# Si no encontramos use_backend, insertar al final del
# frontend multiport_frontend.
# ============================================================

if not inserted_panel:

    out2 = []

    in_multi = False

    for line in out:

        st = line.strip()


        if st.startswith("frontend "):

            in_multi = (
                st == "frontend multiport_frontend"
            )


        elif st.startswith(
            (
                "backend ",
                "listen ",
                "global",
                "defaults"
            )
        ):

            if in_multi and not inserted_panel:

                out2.append(
                    f"    acl acl_panel_sni req.ssl_sni -i {domain}\n"
                )

                out2.append(
                    "    use_backend panel_tls_backend if acl_panel_sni\n"
                )

                inserted_panel = True

            in_multi = False


        out2.append(line)


    out = out2


if not inserted_panel:

    raise SystemExit(
        "No se encontró frontend multiport_frontend para enrutar el panel."
    )


s = "".join(out)


# ============================================================
# ACME
#
# Se mantiene dentro del frontend ssl_frontend.
# ============================================================

lines = s.splitlines(True)

out = []

in_ssl = False
inserted_acme = False


for line in lines:

    st = line.strip()


    if st.startswith("frontend "):

        in_ssl = (
            st == "frontend ssl_frontend"
        )


    elif st.startswith(
        (
            "backend ",
            "listen ",
            "global",
            "defaults"
        )
    ):

        in_ssl = False


    if (
        in_ssl
        and st.startswith("use_backend ")
        and not inserted_acme
    ):

        out.append(
            "    acl acl_acme path_beg /.well-known/acme-challenge/\n"
        )

        out.append(
            "    use_backend acme_backend if acl_acme\n"
        )

        inserted_acme = True


    out.append(line)


if not inserted_acme:

    raise SystemExit(
        "No se encontró frontend ssl_frontend para ACME."
    )


s = "".join(out)


# ============================================================
# FRONTEND EXCLUSIVO DEL PANEL
#
# HTTP/1.1 solamente.
#
# NO se anuncia:
#
#     alpn h2,http/1.1
#
# porque el panel no necesita HTTP/2.
#
# Esto evita que el navegador negocie HTTP/2 con el
# frontend TCP general y posteriormente HAProxy intente
# entregar frames HTTP/2 al backend HTTP.
# ============================================================

s = s.rstrip() + f"""

# ============================================================
# KevinTech Web Panel
# Dedicated TLS Frontend
# HTTP/1.1 ONLY
# ============================================================

frontend panel_tls_frontend

    mode http

    bind abns@kevintech-panel accept-proxy ssl crt {pem} alpn http/1.1

    option http-server-close
    option forwardfor

    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Host %[req.hdr(host)]

    default_backend kevintech_web


# ============================================================
# PANEL TLS ROUTER
# ============================================================

backend panel_tls_backend

    mode tcp

    server panel_tls abns@kevintech-panel send-proxy-v2 check


# ============================================================
# ACME
# ============================================================

backend acme_backend

    mode http

    option http-server-close

    server acme_server 127.0.0.1:{acme_port} check


# ============================================================
# KEVINTECH WEB
# ============================================================

backend kevintech_web

    mode http

    option http-server-close
    option forwardfor

    server kevintech_web 127.0.0.1:{port} check
"""


p.write_text(s)


# ============================================================
# VALIDAR HAPROXY
# ============================================================

r = subprocess.run(
    [
        "haproxy",
        "-c",
        "-f",
        str(p)
    ],
    capture_output=True,
    text=True
)


if r.returncode:

    shutil.copy2(
        str(p) + ".kevintech-web.bak",
        p
    )

    print(
        r.stdout +
        r.stderr
    )

    raise SystemExit(3)


# ============================================================
# RECARGAR HAPROXY
# ============================================================

r = subprocess.run(
    [
        "systemctl",
        "reload",
        "haproxy"
    ],
    capture_output=True,
    text=True
)


if r.returncode:

    print(
        r.stdout +
        r.stderr
    )

    raise SystemExit(4)

PY
}

# ============================================================
# COPIAR WEB
# ============================================================

copy_web_files() {

    local src
    local dst

    src="$(cd "$(dirname "$0")" && pwd)"

    mkdir -p "$WEB/templates"


    for f in \
        server.py \
        requirements.txt \
        version.txt \
        README.md
    do

        if [[ -f "$src/$f" ]]; then

            dst="$WEB/$f"

            [[
                "$(readlink -f "$src/$f")" ==
                "$(readlink -f "$dst" 2>/dev/null || true)"
            ]] || cp -f "$src/$f" "$dst"

        fi

    done


    for f in "$src/templates"/*.html; do

        [[ -f "$f" ]] || continue

        dst="$WEB/templates/$(basename "$f")"

        [[
            "$(readlink -f "$f")" ==
            "$(readlink -f "$dst" 2>/dev/null || true)"
        ]] || cp -f "$f" "$dst"

    done


    mkdir -p "$DATA"
}

# ============================================================
# GUARDAR CREDENCIALES
# ============================================================

save_credentials() {

    python3 \
        - "$DATA/config.json" \
        "$1" \
        "$2" \
        "$3" \
        <<'PY'

import json
import sys
import hashlib
import base64
import secrets
import os


p, u, pw, domain = sys.argv[1:]


os.makedirs(
    os.path.dirname(p),
    exist_ok=True
)


try:

    d = json.load(
        open(p)
    )

except:

    d = {}


salt = secrets.token_bytes(16)

h = hashlib.scrypt(
    pw.encode(),
    salt=salt,
    n=2**14,
    r=8,
    p=1
)


d.setdefault(
    "secret",
    secrets.token_hex(32)
)


d["admin_username"] = u

d["admin_password_hash"] = (
    "scrypt$"
    + base64.urlsafe_b64encode(salt).decode()
    + "$"
    + base64.urlsafe_b64encode(h).decode()
)


d.pop(
    "initial_admin_password",
    None
)


d.setdefault(
    "ads_enabled",
    True
)


d.setdefault(
    "ad_provider",
    "monetag"
)


d.setdefault(
    "monetag_zone",
    "11217882"
)


d.setdefault(
    "ads",
    {
        "create": 3,
        "delete": 1,
        "renew": 3
    }
)


d["server_domain"] = domain

d["server_prefix"] = "/"


json.dump(
    d,
    open(p, "w"),
    indent=2,
    ensure_ascii=False
)


os.chmod(
    p,
    0o600
)

PY
}

# ============================================================
# DATOS INICIALES
# ============================================================

prompt_fresh() {

    echo

    read -rp \
        "Usuario administrador [admin]: " \
        WEB_ADMIN_USER

    WEB_ADMIN_USER="${WEB_ADMIN_USER:-admin}"


    while [[ ! "$WEB_ADMIN_USER" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; do

        read -rp \
            "Usuario inválido: " \
            WEB_ADMIN_USER

    done


    while true; do

        read -rsp \
            "Contraseña administrador (mín. 8): " \
            WEB_ADMIN_PASS

        echo

        [[
            ${#WEB_ADMIN_PASS}
            -ge 8
        ]] && break

    done


    local old

    old="$(configured_domain)"

    old="${old:-$(current_domain)}"


    if [[ -n "$old" ]]; then

        read -rp \
            "Dominio HTTPS [ENTER = $old]: " \
            WEB_DOMAIN

        WEB_DOMAIN="${WEB_DOMAIN:-$old}"

    else

        read -rp \
            "Dominio HTTPS: " \
            WEB_DOMAIN

    fi


    WEB_DOMAIN="$(
        echo "$WEB_DOMAIN" |
        tr -d '[:space:]'
    )"


    valid_domain "$WEB_DOMAIN" || {

        echo -e \
            "${red}Dominio inválido.${reset}"

        return 1
    }


    export \
        WEB_ADMIN_USER \
        WEB_ADMIN_PASS \
        WEB_DOMAIN
}

# ============================================================
# CERTIFICADO
# ============================================================

ensure_cert() {

    local domain="$1"
    local email


    mkdir -p \
        "$ACME_ROOT/.well-known/acme-challenge"


    systemctl restart \
        "$ACME_SERVICE"


    echo "KEVINTECH-ACME-OK" \
        > "$ACME_ROOT/.well-known/acme-challenge/installer-test"


    sleep 1


    if ! curl \
        -fsS \
        --max-time 15 \
        "http://$domain/.well-known/acme-challenge/installer-test" |
        grep -q KEVINTECH-ACME-OK
    then

        echo -e \
            "${red}✘ El dominio no está llegando al ACME de HAProxy.${reset}"

        echo \
            "Prueba DNS/puerto 80 antes de solicitar el certificado."

        return 1
    fi


    if [[
        -s "/etc/letsencrypt/live/$domain/fullchain.pem"
        &&
        -s "/etc/letsencrypt/live/$domain/privkey.pem"
    ]]; then

        :

    else

        command -v certbot >/dev/null 2>&1 || {

            apt-get update -y &&
            apt-get install -y certbot ||
            return 1

        }


        read -rp \
            "Correo para Let's Encrypt: " \
            email


        [[ -n "$email" ]] || return 1


        certbot certonly \
            --webroot \
            -w "$ACME_ROOT" \
            -d "$domain" \
            --non-interactive \
            --agree-tos \
            --no-eff-email \
            -m "$email" ||
            return 1

    fi


    cat \
        "/etc/letsencrypt/live/$domain/fullchain.pem" \
        "/etc/letsencrypt/live/$domain/privkey.pem" \
        > "$PEM"


    chmod 600 "$PEM"


    write_domain_config "$domain"

    write_renew_hook


    haproxy \
        -c \
        -f "$HAPROXY" \
        >/dev/null ||
        return 1


    systemctl reload haproxy
}

# ============================================================
# INSTALAR / ACTUALIZAR
# ============================================================

install_or_update() {

    root_check


    copy_web_files ||
        return 1


    mkdir -p \
        "$DATA" \
        "$WEB/templates" \
        "$ACME_ROOT/.well-known/acme-challenge"


    local existing_domain

    existing_domain="$(
        python3 \
            - "$DATA/config.json" \
            <<'PY'

import json
import sys

try:

    print(
        json.load(
            open(sys.argv[1])
        ).get(
            "server_domain",
            ""
        )
    )

except:

    print("")

PY
    )"


    existing_domain="${existing_domain:-$(current_domain)}"


    if [[ -z "$existing_domain" ]]; then

        prompt_fresh ||
            return 1


        save_credentials \
            "$WEB_ADMIN_USER" \
            "$WEB_ADMIN_PASS" \
            "$WEB_DOMAIN" ||
            return 1

    else

        WEB_DOMAIN="$existing_domain"

        echo -e \
            "${cyan}Actualizando: se conservan usuario, contraseña y dominio.${reset}"

    fi


    write_service

    write_acme_service


    # Certificado temporal para que HAProxy pueda cargar
    # mientras se obtiene/usa el certificado real.
    make_temp_cert "$WEB_DOMAIN"


    patch_haproxy "$WEB_DOMAIN" ||
        return 1


    ensure_cert "$WEB_DOMAIN" ||
        return 1


    systemctl daemon-reload


    systemctl enable \
        "$SERVICE" \
        "$ACME_SERVICE" \
        >/dev/null 2>&1 || true


    systemctl restart "$SERVICE"


    sleep 1


    if systemctl is-active --quiet "$SERVICE"; then

        echo

        echo -e \
            "${green}╔══════════════════════════════════════════════════════════════╗${reset}"

        echo -e \
            "${green}║       ✔ KEVINTECH WEB INSTALADA / ACTUALIZADA             ║${reset}"

        echo -e \
            "${green}╚══════════════════════════════════════════════════════════════╝${reset}"

        echo

        echo -e \
            "${cyan}✔ Panel:${reset} https://$WEB_DOMAIN/login"

        echo -e \
            "${cyan}✔ Backend:${reset} 127.0.0.1:$PORT"

        echo -e \
            "${cyan}✔ ACME:${reset} 127.0.0.1:$ACME_PORT"

        echo -e \
            "${cyan}✔ TLS del panel:${reset} HTTP/1.1"

        echo -e \
            "${cyan}✔ Panel aislado de los demás protocolos.${reset}"

        echo

    else

        journalctl \
            -u "$SERVICE" \
            -n 40 \
            --no-pager

        return 1

    fi
}

# ============================================================
# CAMBIAR DATOS
# ============================================================

change_data() {

    root_check


    [[ -f "$DATA/config.json" ]] || {

        echo -e \
            "${red}Web no instalada. Primero usa opción 1.${reset}"

        return 1
    }


    local oldu
    local olddomain
    local u
    local p
    local domain


    oldu="$(
        python3 \
            - "$DATA/config.json" \
            <<'PY2'

import json
import sys

try:

    print(
        json.load(
            open(sys.argv[1])
        ).get(
            "admin_username",
            "admin"
        )
    )

except:

    print("admin")

PY2
    )"


    olddomain="$(
        python3 \
            - "$DATA/config.json" \
            <<'PY2'

import json
import sys

try:

    print(
        json.load(
            open(sys.argv[1])
        ).get(
            "server_domain",
            ""
        )
    )

except:

    print("")

PY2
    )"


    olddomain="${olddomain:-$(current_domain)}"


    read -rp \
        "Nuevo usuario admin [ENTER = $oldu]: " \
        u

    u="${u:-$oldu}"


    read -rsp \
        "Nueva contraseña [ENTER = conservar]: " \
        p

    echo


    [[ "$u" =~ ^[A-Za-z0-9_.-]{3,32}$ ]] || {

        echo "Usuario inválido"

        return 1
    }


    read -rp \
        "Nuevo dominio HTTPS [ENTER = $olddomain]: " \
        domain


    domain="${domain:-$olddomain}"


    domain="$(
        echo "$domain" |
        tr -d '[:space:]'
    )"


    valid_domain "$domain" || {

        echo "Dominio inválido"

        return 1
    }


    python3 \
        - "$DATA/config.json" \
        "$u" \
        "$p" \
        "$domain" \
        <<'PY2'

import json
import sys
import hashlib
import base64
import secrets
import os


p, u, pw, domain = sys.argv[1:]


d = json.load(
    open(p)
)


d["admin_username"] = u

d["server_domain"] = domain


if pw:

    if len(pw) < 8:

        raise SystemExit(
            "Contraseña demasiado corta"
        )


    salt = secrets.token_bytes(16)

    h = hashlib.scrypt(
        pw.encode(),
        salt=salt,
        n=2**14,
        r=8,
        p=1
    )


    d["admin_password_hash"] = (
        "scrypt$"
        + base64.urlsafe_b64encode(salt).decode()
        + "$"
        + base64.urlsafe_b64encode(h).decode()
    )


json.dump(
    d,
    open(p, "w"),
    indent=2,
    ensure_ascii=False
)


os.chmod(
    p,
    0o600
)

PY2


    WEB_DOMAIN="$domain"


    write_domain_config "$domain"


    make_temp_cert "$domain"


    patch_haproxy "$domain" ||
        return 1


    ensure_cert "$domain" ||
        return 1


    systemctl restart "$SERVICE"


    echo

    echo -e \
        "${green}✔ Datos actualizados.${reset}"

    echo -e \
        "${cyan}✔ Panel: https://$domain/login${reset}"
}

# ============================================================
# LOGS
# ============================================================

show_logs() {

    root_check

    journalctl \
        -u "$SERVICE" \
        -f \
        -n 80 \
        --no-pager
}

# ============================================================
# DESINSTALAR
# ============================================================

remove_web() {

    root_check


    systemctl stop \
        "$SERVICE" \
        2>/dev/null || true


    systemctl disable \
        "$SERVICE" \
        2>/dev/null || true


    systemctl stop \
        "$ACME_SERVICE" \
        2>/dev/null || true


    systemctl disable \
        "$ACME_SERVICE" \
        2>/dev/null || true


    rm -f \
        "/etc/systemd/system/$SERVICE" \
        "/etc/systemd/system/$ACME_SERVICE" \
        "$HOOK" \
        "$PEM" \
        "$DOMAIN_FILE"


    local old_domain=""

    [[ -f "$DATA/config.json" ]] &&
        old_domain="$(
            python3 \
                - "$DATA/config.json" \
                <<'PY2'

import json
import sys

try:

    print(
        json.load(
            open(sys.argv[1])
        ).get(
            "server_domain",
            ""
        )
    )

except:

    print("")

PY2
        )"


    if [[
        -n "$old_domain"
    ]] &&
    command -v certbot >/dev/null 2>&1
    then

        certbot delete \
            --cert-name "$old_domain" \
            --non-interactive \
            >/dev/null 2>&1 ||
            true

    fi


    if [[ -f "$HAPROXY" ]]; then

        HAPROXY="$HAPROXY" \
        PEM="$PEM" \
        python3 - <<'PY2'

from pathlib import Path

import os
import subprocess
import shutil


p = Path(
    os.environ["HAPROXY"]
)

s = p.read_text(
    errors="ignore"
)


bak = (
    str(p)
    + ".kevintech-web-remove.bak"
)


shutil.copy2(
    p,
    bak
)


# ============================================================
# BLOQUES NUEVOS Y ANTIGUOS DEL PANEL
# ============================================================

blocks_to_remove = {
    "frontend panel_tls_frontend",
    "backend panel_tls_backend",
    "backend kevintech_web",
    "backend acme_backend",
}


lines = s.splitlines(True)

out = []

skip = False


for line in lines:

    st = line.strip()


    if (
        not line.startswith((" ", "\t"))
        and st in blocks_to_remove
    ):

        skip = True

        continue


    if skip:

        if (
            line
            and not line[0].isspace()
            and st
        ):

            skip = False

        else:

            continue


    out.append(line)


s = "".join(out)


# ============================================================
# REGLAS DEL PANEL
# ============================================================

remove_fragments = (

    "acl acl_panel_sni ",

    "use_backend kevintech_web if acl_panel_sni",

    "use_backend panel_tls_backend if acl_panel_sni",

    "use_backend recir_https_backend if acl_panel_sni",

    "acl acl_acme path_beg /.well-known/acme-challenge/",

    "use_backend acme_backend if acl_acme",

)


lines = s.splitlines(True)

s = "".join(
    line
    for line in lines
    if not any(
        fragment in line
        for fragment in remove_fragments
    )
)


# ============================================================
# CERTIFICADO DEL PANEL
# ============================================================

lines = s.splitlines(True)

s = "".join(
    line
    for line in lines
    if not (
        os.environ["PEM"] in line
        and line.strip().startswith(
            "bind abns@haproxy-https"
        )
    )
)


p.write_text(s)


# ============================================================
# VALIDAR
# ============================================================

r = subprocess.run(
    [
        "haproxy",
        "-c",
        "-f",
        str(p)
    ],
    capture_output=True,
    text=True
)


if r.returncode:

    shutil.copy2(
        bak,
        p
    )

    print(
        r.stdout +
        r.stderr
    )

else:

    subprocess.run(
        [
            "systemctl",
            "reload",
            "haproxy"
        ],
        check=False
    )

PY2

    fi


    systemctl daemon-reload


    rm -rf "$WEB"


    echo

    echo -e \
        "${green}✔ KevinTech Web desinstalada completamente.${reset}"

    echo -e \
        "${cyan}✔ Servicios, HAProxy, certificado y archivos de la web eliminados.${reset}"

    echo -e \
        "${cyan}✔ No se tocaron usuarios/, protocolos/, herramientas/ ni telegram/.${reset}"
}

# ============================================================
# MENU
# ============================================================

menu() {

    root_check


    while true; do

        clear


        echo -e \
            "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"

        echo -e \
            "${cyan}║${reset}              KEVINTECH WEB INSTALLER                 ${cyan}║${reset}"

        echo -e \
            "${cyan}║${reset}                    VERSION 3.7                       ${cyan}║${reset}"

        echo -e \
            "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"


        echo


        echo -e \
            "${green}[1]${reset} Instalar / Actualizar web"

        echo -e \
            "${yellow}[2]${reset} Cambiar datos de acceso"

        echo -e \
            "${cyan}[3]${reset} Ver logs"

        echo -e \
            "${red}[4]${reset} Desinstalar web"

        echo

        echo "[0] Salir"

        echo


        read -rp \
            "Opción: " \
            op


        case "$op" in

            1)

                install_or_update

                read -rp \
                    "ENTER para continuar..." _

                ;;


            2)

                change_data

                read -rp \
                    "ENTER para continuar..." _

                ;;


            3)

                show_logs

                ;;


            4)

                read -rp \
                    "Escribe DESINSTALAR para confirmar: " \
                    x

                if [[ "$x" == "DESINSTALAR" ]]; then

                    remove_web

                else

                    echo \
                        "Desinstalación cancelada."

                fi

                read -rp \
                    "ENTER para continuar..." _

                ;;


            0)

                exit 0

                ;;


            *)

                echo \
                    "Opción inválida"

                sleep 1

                ;;

        esac

    done
}

# ============================================================
# ARGUMENTOS
# ============================================================

case "${1:-menu}" in

    install|update)

        install_or_update

        ;;


    change)

        change_data

        ;;


    logs)

        show_logs

        ;;


    remove|stop)

        remove_web

        ;;


    menu)

        menu

        ;;


    *)

        echo \
            "Uso: $0 {install|update|change|logs|remove|menu}"

        exit 1

        ;;

esac