#!/usr/bin/env bash

# ==============================================================
#                  🌐 KEVINTECH BHTTP 🌐
#                    PREMIUM PROTOCOL
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/bhttp.sh
# Servicio: bhttp.service
# BHTTP    : 8088
# SSH      : 22
# Versión  : 3.4 Premium
#
# ==============================================================
#                    KEVINTECH / PRIVANOX
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN FIJA
# ==============================================================

BASE="/etc/kevintech"

BHTTP_DIR="/usr/local/lib/bhttp"
SERVER_PY="$BHTTP_DIR/bhttp-server.py"

UNIT="/etc/systemd/system/bhttp.service"
SERVICE="bhttp"

CONFIG="$BASE/bhttp.conf"

BHTTP_HOST="0.0.0.0"
BHTTP_PORT="8088"

SSH_HOST="127.0.0.1"
SSH_PORT="22"

VERSION="3.4"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# SEGURIDAD
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este módulo requiere permisos de root.${RESET}"
    echo

    exit 1
fi

mkdir -p "$BASE"

# ==============================================================
# UTILIDADES
# ==============================================================

line() {

    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

pause() {

    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

msg_ok() {

    echo -e "${GREEN}✔ $1${RESET}"
}

msg_error() {

    echo -e "${RED}✘ $1${RESET}"
}

msg_info() {

    echo -e "${CYAN}➜ $1${RESET}"
}

msg_warn() {

    echo -e "${YELLOW}⚠ $1${RESET}"
}

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

crear_config() {

    mkdir -p "$BASE"

    cat > "$CONFIG" <<EOF
BHTTP_HOST=0.0.0.0
BHTTP_PORT=8088
SSH_HOST=127.0.0.1
SSH_PORT=22
BHTTP=ON
EOF

    chmod 600 "$CONFIG"
}

# ==============================================================
# ESTADO
# ==============================================================

servicio_instalado() {

    [[ -f "$UNIT" && -f "$SERVER_PY" ]]
}

servicio_online() {

    systemctl is-active --quiet "$SERVICE" 2>/dev/null
}

servicio_habilitado() {

    systemctl is-enabled --quiet "$SERVICE" 2>/dev/null
}

puerto_escuchando() {

    local PORT="$1"

    ss -H -ltn 2>/dev/null |
        awk '{print $4}' |
        grep -qE ":${PORT}$"
}

# ==============================================================
# ESTADO VISUAL
# ==============================================================

estado_bhttp() {

    if ! servicio_instalado; then

        echo -e "${GRAY}● NO INSTALADO${RESET}"

        return
    fi

    if servicio_online &&
       puerto_escuchando "$BHTTP_PORT"; then

        echo -e "${GREEN}● ONLINE${RESET}"

    elif servicio_online; then

        echo -e "${YELLOW}● SERVICIO ACTIVO / PUERTO NO DETECTADO${RESET}"

    else

        echo -e "${RED}● OFFLINE${RESET}"

    fi
}

# ==============================================================
# SERVIDOR BHTTP
# ==============================================================

instalar_servidor() {

    mkdir -p "$BHTTP_DIR"

    cat > "$SERVER_PY" <<'PYEOF'
#!/usr/bin/env python3

import argparse
import asyncio
import hashlib
import sys

MAGIC = b"BHP1"
LONGPOLL = 2.0


def log(msg):
    sys.stderr.write("[bhttp] %s\n" % msg)
    sys.stderr.flush()


def keystream(sess, mode, seq, direction, length):

    base = hashlib.sha256(
        sess +
        bytes([mode]) +
        seq.to_bytes(8, "big") +
        bytes([direction])
    )

    output = bytearray()
    counter = 0

    while len(output) < length:

        h = base.copy()
        h.update(counter.to_bytes(4, "big"))

        output += h.digest()

        counter += 1

    return bytes(output[:length])


def mask(data, sess, mode, seq, direction):

    stream = keystream(
        sess,
        mode,
        seq,
        direction,
        len(data)
    )

    return bytes(
        a ^ b
        for a, b in zip(data, stream)
    )


def probe_reply(mode, size):

    length = (
        size
        if mode == 2 and size >= 10
        else 10
    )

    output = bytearray(
        MAGIC +
        bytes([1, mode]) +
        size.to_bytes(4, "big")
    )

    for i in range(10, length):
        output.append((i * 31) & 255)

    return bytes(output)


class Session:

    def __init__(self, session_id, backend):

        self.session_id = session_id
        self.backend = backend

        self.condition = asyncio.Condition()

        self.upload_next = 0
        self.upload_pending = {}

        self.download_raw = bytearray()
        self.download_chunks = {}
        self.download_assign = 0

        self.eof = False
        self.closed = False

        self.reader = None
        self.writer = None

    async def connect(self):

        host, port = self.backend

        self.reader, self.writer = (
            await asyncio.open_connection(
                host,
                port
            )
        )

        log(
            "sesion %s: conectada al backend %s:%d"
            % (
                self.session_id.hex()[:8],
                host,
                port
            )
        )

        asyncio.create_task(
            self.backend_reader()
        )

    async def backend_reader(self):

        total = 0

        try:

            while True:

                data = await self.reader.read(
                    65536
                )

                if not data:
                    break

                total += len(data)

                async with self.condition:

                    self.download_raw += data

                    self.condition.notify_all()

        except Exception as error:

            log(
                "sesion %s: error backend: %s"
                % (
                    self.session_id.hex()[:8],
                    error
                )
            )

        finally:

            log(
                "sesion %s: backend cerrado (%d B)"
                % (
                    self.session_id.hex()[:8],
                    total
                )
            )

            async with self.condition:

                self.eof = True
                self.condition.notify_all()

    async def upload(self, sequence, data):

        async with self.condition:

            if data:

                self.upload_pending[
                    sequence
                ] = data

            while (
                self.upload_next
                in self.upload_pending
            ):

                chunk = self.upload_pending.pop(
                    self.upload_next
                )

                try:

                    self.writer.write(chunk)

                    await self.writer.drain()

                except Exception:

                    self.closed = True

                self.upload_next += 1

    async def download(
        self,
        sequence,
        maximum,
        deadline
    ):

        if maximum <= 0:
            maximum = 1399

        loop = asyncio.get_running_loop()

        async with self.condition:

            while True:

                if sequence < self.download_assign:

                    return self.download_chunks.get(
                        sequence,
                        b""
                    )

                if sequence == self.download_assign:

                    if self.download_raw:

                        chunk = bytes(
                            self.download_raw[:maximum]
                        )

                        del self.download_raw[:maximum]

                        self.download_chunks[
                            self.download_assign
                        ] = chunk

                        self.download_assign += 1

                        self.condition.notify_all()

                        return chunk

                    if self.eof:

                        self.download_assign += 1

                        self.condition.notify_all()

                        return b""

                if (
                    not self.eof
                    and
                    loop.time() < deadline
                ):

                    try:

                        await asyncio.wait_for(
                            self.condition.wait(),
                            timeout=max(
                                0.01,
                                deadline - loop.time()
                            )
                        )

                    except asyncio.TimeoutError:

                        pass

                    continue

                while (
                    self.download_assign <= sequence
                ):

                    self.download_assign += 1

                self.condition.notify_all()

                return b""

    async def acknowledge(self, sequence):

        async with self.condition:

            for key in list(
                self.download_chunks.keys()
            ):

                if key <= sequence:

                    del self.download_chunks[key]

    async def close(self):

        async with self.condition:

            self.closed = True
            self.condition.notify_all()

        try:
            self.writer.close()
        except Exception:
            pass


class Server:

    def __init__(self, host, port, backend):

        self.host = host
        self.port = port
        self.backend = backend

        self.sessions = {}
        self.session_lock = asyncio.Lock()

    async def get_session(self, session_id):

        async with self.session_lock:

            session = self.sessions.get(
                session_id
            )

            if (
                session is None
                or
                session.closed
            ):

                for (
                    old_id,
                    old_session
                ) in list(
                    self.sessions.items()
                ):

                    if old_id != session_id:

                        await old_session.close()

                        del self.sessions[
                            old_id
                        ]

                session = Session(
                    session_id,
                    self.backend
                )

                await session.connect()

                self.sessions[
                    session_id
                ] = session

                log(
                    "sesion %s: registrada (sesiones vivas: %d)"
                    % (
                        session_id.hex()[:8],
                        len(self.sessions)
                    )
                )

            return session

    async def handle(self, reader, writer):

        try:

            while True:

                header = await reader.readexactly(
                    29
                )

                mode = header[0]

                session_id = header[1:17]

                sequence = int.from_bytes(
                    header[17:25],
                    "big"
                )

                length = int.from_bytes(
                    header[25:29],
                    "big"
                )

                payload = b""

                if (
                    length
                    and
                    mode in (0, 1, 2, 3)
                ):

                    raw = await reader.readexactly(
                        length
                    )

                    payload = mask(
                        raw,
                        session_id,
                        mode,
                        sequence,
                        0
                    )

                if payload[:4] == MAGIC:

                    size = (
                        int.from_bytes(
                            payload[6:10],
                            "big"
                        )
                        if len(payload) >= 10
                        else 0
                    )

                    probe_mode = (
                        payload[5]
                        if len(payload) >= 6
                        else mode
                    )

                    reply = mask(
                        probe_reply(
                            probe_mode,
                            size
                        ),
                        session_id,
                        mode,
                        sequence,
                        1
                    )

                    writer.write(
                        bytes([0]) +
                        len(reply).to_bytes(
                            4,
                            "big"
                        ) +
                        reply
                    )

                    await writer.drain()

                    continue

                session = await self.get_session(
                    session_id
                )

                if mode == 1:

                    await session.upload(
                        sequence,
                        payload
                    )

                    writer.write(
                        bytes([0]) +
                        (0).to_bytes(4, "big")
                    )

                    await writer.drain()

                elif mode == 2:

                    chunk = await session.download(
                        sequence,
                        length
                        if length > 0
                        else 1399,
                        asyncio.get_running_loop().time()
                        + LONGPOLL
                    )

                    self.send_data(
                        writer,
                        session_id,
                        mode,
                        sequence,
                        chunk
                    )

                    await writer.drain()

                elif mode == 3:

                    if len(payload) >= 6:

                        chunk_size = int.from_bytes(
                            payload[0:4],
                            "big"
                        )

                        count = payload[5]

                    else:

                        chunk_size = 1399
                        count = 1

                    if chunk_size <= 0:
                        chunk_size = 1399

                    if count <= 0:
                        count = 1

                    deadline = (
                        asyncio.get_running_loop().time()
                        + LONGPOLL
                    )

                    for index in range(count):

                        chunk = await session.download(
                            sequence + index,
                            chunk_size,
                            deadline
                        )

                        self.send_data(
                            writer,
                            session_id,
                            mode,
                            sequence + index,
                            chunk
                        )

                    await writer.drain()

                elif mode == 4:

                    await session.acknowledge(
                        sequence
                    )

                    writer.write(
                        bytes([0]) +
                        (0).to_bytes(4, "big")
                    )

                    await writer.drain()

                else:

                    return

        except (
            asyncio.IncompleteReadError,
            ConnectionError,
            OSError
        ):

            pass

        except Exception as error:

            log(
                "handle: error inesperado: %r"
                % error
            )

        finally:

            try:
                writer.close()
            except Exception:
                pass

    def send_data(
        self,
        writer,
        session_id,
        mode,
        sequence,
        data
    ):

        real_length = len(data)

        encrypted = (
            mask(
                data,
                session_id,
                mode,
                sequence,
                1
            )
            if data
            else b""
        )

        body = (
            real_length.to_bytes(
                4,
                "big"
            )
            +
            encrypted
        )

        writer.write(
            bytes([2]) +
            len(body).to_bytes(
                4,
                "big"
            ) +
            body
        )

    async def serve(self):

        server = await asyncio.start_server(
            self.handle,
            self.host,
            self.port,
            backlog=512
        )

        print(
            "BHTTP escuchando en %s:%d -> backend %s:%d"
            % (
                self.host,
                self.port,
                self.backend[0],
                self.backend[1]
            ),
            flush=True
        )

        async with server:

            await server.serve_forever()


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--host",
        default="0.0.0.0"
    )

    parser.add_argument(
        "--port",
        type=int,
        required=True
    )

    parser.add_argument(
        "--backend-host",
        default="127.0.0.1"
    )

    parser.add_argument(
        "--backend-port",
        type=int,
        default=22
    )

    args = parser.parse_args()

    asyncio.run(
        Server(
            args.host,
            args.port,
            (
                args.backend_host,
                args.backend_port
            )
        ).serve()
    )


if __name__ == "__main__":

    main()

PYEOF

    chmod 755 "$SERVER_PY"
}

# ==============================================================
# SYSTEMD
# ==============================================================

crear_servicio() {

    local PYTHON

    PYTHON="$(command -v python3)"

    [[ -z "$PYTHON" ]] && return 1

    cat > "$UNIT" <<EOF
[Unit]
Description=KevinTech BHTTP Server
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BHTTP_DIR
ExecStart=$PYTHON $SERVER_PY --host 0.0.0.0 --port 8088 --backend-host 127.0.0.1 --backend-port 22
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$UNIT"

    return 0
}

# ==============================================================
# VERIFICAR SSH
# ==============================================================

verificar_ssh() {

    if ss -H -ltn 2>/dev/null |
        awk '{print $4}' |
        grep -qE ':22$'; then

        return 0

    fi

    return 1
}

# ==============================================================
# INSTALAR / ACTUALIZAR
# ==============================================================

instalar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                    🌐 KEVINTECH BHTTP                      ║"
    echo "║                                                              ║"
    echo "║                   INSTALAR / ACTUALIZAR                    ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${WHITE}Configuración automática${RESET}"
    line

    echo -e "  Puerto BHTTP : ${CYAN}8088${RESET}"
    echo -e "  Backend SSH  : ${CYAN}127.0.0.1:22${RESET}"
    echo -e "  Listener     : ${CYAN}0.0.0.0:8088${RESET}"

    echo

    # ==========================================================
    # PYTHON
    # ==========================================================

    if ! command -v python3 >/dev/null 2>&1; then

        msg_info "Python3 no está instalado."
        msg_info "Instalando Python3..."

        apt-get update -qq >/dev/null 2>&1

        apt-get install -y python3 >/dev/null 2>&1

        if ! command -v python3 >/dev/null 2>&1; then

            msg_error "No se pudo instalar Python3."

            pause

            return 1
        fi

        msg_ok "Python3 instalado."
    fi

    # ==========================================================
    # SSH
    # ==========================================================

    if ! verificar_ssh; then

        msg_warn "No se detecta SSH escuchando en el puerto 22."
        echo -e "${GRAY}BHTTP se instalará, pero el backend SSH debe estar activo.${RESET}"
        echo

    else

        msg_ok "SSH detectado en el puerto 22."
    fi

    # ==========================================================
    # DETENER VERSIÓN ANTERIOR
    # ==========================================================

    if [[ -f "$UNIT" ]]; then

        msg_info "Deteniendo versión anterior..."

        systemctl stop "$SERVICE" 2>/dev/null || true

    fi

    # ==========================================================
    # ELIMINAR CONFIGURACIÓN ANTIGUA
    # ==========================================================

    msg_info "Aplicando configuración fija 8088/22..."

    rm -f "$UNIT"

    # ==========================================================
    # INSTALAR SERVIDOR
    # ==========================================================

    msg_info "Instalando servidor BHTTP..."

    if ! instalar_servidor; then

        msg_error "No se pudo instalar el servidor BHTTP."

        pause

        return 1
    fi

    msg_ok "Servidor BHTTP instalado."

    # ==========================================================
    # CREAR SERVICIO
    # ==========================================================

    msg_info "Configurando servicio systemd..."

    if ! crear_servicio; then

        msg_error "No se pudo crear bhttp.service."

        pause

        return 1
    fi

    msg_ok "Servicio systemd configurado."

    # ==========================================================
    # CONFIG
    # ==========================================================

    cat > "$CONFIG" <<EOF
BHTTP_HOST=0.0.0.0
BHTTP_PORT=8088
SSH_HOST=127.0.0.1
SSH_PORT=22
BHTTP=ON
EOF

    chmod 600 "$CONFIG"

    # ==========================================================
    # SYSTEMD
    # ==========================================================

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    msg_ok "Inicio automático activado."

    # ==========================================================
    # ARRANQUE
    # ==========================================================

    msg_info "Iniciando BHTTP..."

    systemctl restart "$SERVICE"

    local OK=0

    for ((i=1; i<=10; i++)); do

        if servicio_online &&
           puerto_escuchando "8088"; then

            OK=1
            break

        fi

        sleep 1

    done

    echo

    if [[ "$OK" == "1" ]]; then

        msg_ok "BHTTP iniciado correctamente."

        echo

        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                                                              ║"
        echo "║                 🌐 BHTTP ONLINE 🌐                          ║"
        echo "║                                                              ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo -e "║  Estado       : ${GREEN}● ONLINE${CYAN}                                 ║"
        echo -e "║  Puerto       : ${WHITE}8088${CYAN}                                     ║"
        echo -e "║  SSH Backend  : ${WHITE}127.0.0.1:22${CYAN}                            ║"
        echo -e "║  Listener     : ${GREEN}0.0.0.0:8088${CYAN}                            ║"
        echo -e "║  AutoInicio   : ${GREEN}✔ ACTIVADO${CYAN}                               ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RESET}"

    else

        echo -e "${RED}${BOLD}✘ BHTTP no pudo iniciar correctamente.${RESET}"

        echo

        echo -e "${YELLOW}Estado del servicio:${RESET}"

        systemctl status "$SERVICE" \
            --no-pager \
            -l \
            2>/dev/null

        echo

        echo -e "${YELLOW}Últimos logs:${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 15 \
            --no-pager \
            -l \
            2>/dev/null

        pause

        return 1
    fi

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

reiniciar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🔄 REINICIAR BHTTP                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    msg_info "Reiniciando BHTTP..."

    systemctl restart "$SERVICE"

    sleep 2

    if servicio_online &&
       puerto_escuchando "8088"; then

        echo
        msg_ok "BHTTP reiniciado correctamente."

        echo
        echo -e "  Puerto : ${GREEN}8088${RESET}"
        echo -e "  SSH    : ${GREEN}22${RESET}"
        echo -e "  Estado : ${GREEN}● ONLINE${RESET}"

    else

        echo
        msg_error "BHTTP no pudo reiniciarse."

        echo

        journalctl \
            -u "$SERVICE" \
            -n 15 \
            --no-pager \
            -l \
            2>/dev/null

    fi

    pause
}

# ==============================================================
# PRUEBA
# ==============================================================

probar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     🧪 PRUEBA BHTTP                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo

    echo -e "${WHITE}Servicio${RESET}"
    line

    if servicio_online; then

        echo -e "  Estado : ${GREEN}● ONLINE${RESET}"

    else

        echo -e "  Estado : ${RED}● OFFLINE${RESET}"

    fi

    echo
    echo -e "${WHITE}Puerto${RESET}"
    line

    if puerto_escuchando "8088"; then

        echo -e "  8088 : ${GREEN}✔ ESCUCHANDO${RESET}"

    else

        echo -e "  8088 : ${RED}✘ NO ESCUCHA${RESET}"

    fi

    echo
    echo -e "${WHITE}SSH Backend${RESET}"
    line

    if verificar_ssh; then

        echo -e "  22 : ${GREEN}✔ ESCUCHANDO${RESET}"

    else

        echo -e "  22 : ${RED}✘ NO DETECTADO${RESET}"

    fi

    echo
    echo -e "${WHITE}Listener${RESET}"
    line

    ss -ltnp 2>/dev/null |
        grep ':8088' ||
        echo -e "${GRAY}No se encontró listener.${RESET}"

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostico() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🔎 DIAGNÓSTICO BHTTP                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${WHITE}SERVICIO${RESET}"
    line

    echo -e "  Servicio : $(estado_bhttp)"

    if servicio_habilitado; then

        echo -e "  AutoInicio : ${GREEN}✔ ACTIVADO${RESET}"

    else

        echo -e "  AutoInicio : ${RED}✘ DESACTIVADO${RESET}"

    fi

    echo
    echo -e "${WHITE}CONFIGURACIÓN${RESET}"
    line

    echo -e "  Host       : ${CYAN}0.0.0.0${RESET}"
    echo -e "  Puerto     : ${CYAN}8088${RESET}"
    echo -e "  Backend    : ${CYAN}127.0.0.1:22${RESET}"

    echo
    echo -e "${WHITE}PUERTOS${RESET}"
    line

    if puerto_escuchando "8088"; then

        echo -e "  BHTTP : ${GREEN}✔ 8088 escuchando${RESET}"

    else

        echo -e "  BHTTP : ${RED}✘ 8088 no escucha${RESET}"

    fi

    if verificar_ssh; then

        echo -e "  SSH   : ${GREEN}✔ 22 escuchando${RESET}"

    else

        echo -e "  SSH   : ${RED}✘ 22 no detectado${RESET}"

    fi

    echo
    echo -e "${WHITE}PROCESO${RESET}"
    line

    ps aux |
        grep '[b]http-server.py' ||
        echo -e "${GRAY}No hay proceso BHTTP activo.${RESET}"

    echo
    echo -e "${WHITE}ÚLTIMOS LOGS${RESET}"
    line

    journalctl \
        -u "$SERVICE" \
        -n 15 \
        --no-pager \
        -l \
        2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

ver_logs() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      📜 BHTTP LOGS                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 50 \
        --no-pager \
        -l \
        2>/dev/null

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

desinstalar_bhttp() {

    clear

    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🗑️ DESINSTALAR BHTTP                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${YELLOW}Se eliminará:${RESET}"
    echo
    echo -e "  • BHTTP"
    echo -e "  • bhttp.service"
    echo -e "  • Configuración BHTTP"
    echo -e "  • Inicio automático"
    echo
    echo -e "${GRAY}SSH y las cuentas de usuarios NO serán modificados.${RESET}"

    echo

    read -rp \
        "$(echo -e "${RED}¿Confirmar desinstalación? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|sí|y|yes)

            ;;

        *)

            echo
            echo -e "${GRAY}Operación cancelada.${RESET}"

            pause

            return
            ;;

    esac

    echo

    msg_info "Deteniendo BHTTP..."

    systemctl stop "$SERVICE" 2>/dev/null || true

    sleep 1

    msg_info "Deshabilitando inicio automático..."

    systemctl disable "$SERVICE" 2>/dev/null || true

    msg_info "Eliminando servicio systemd..."

    rm -f "$UNIT"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE" 2>/dev/null || true

    msg_info "Eliminando servidor BHTTP..."

    rm -rf "$BHTTP_DIR"

    msg_info "Eliminando configuración..."

    rm -f "$CONFIG"

    echo

    msg_ok "BHTTP desinstalado correctamente."

    echo
    echo -e "${WHITE}Servicio    :${RESET} ${GRAY}eliminado${RESET}"
    echo -e "${WHITE}Servidor    :${RESET} ${GRAY}eliminado${RESET}"
    echo -e "${WHITE}Configuración:${RESET} ${GRAY}eliminada${RESET}"
    echo -e "${WHITE}Puerto      :${RESET} ${GRAY}8088 liberado${RESET}"

    pause
}

# ==============================================================
# MENÚ
# ==============================================================

mostrar_menu() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                 🌐 KEVINTECH BHTTP 🌐                      ║"
    echo "║                                                              ║"
    echo "║                    PREMIUM PROTOCOL                         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${GRAY}  Protocolo BHTTP • KevinTech Multi Script v${VERSION}${RESET}"

    echo
    echo -e "${WHITE}  ESTADO DEL SERVICIO${RESET}"

    line

    echo -e "  Servicio : $(estado_bhttp)"
    echo -e "  Puerto   : ${CYAN}8088${RESET}"
    echo -e "  SSH      : ${CYAN}22${RESET}"

    echo
    echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN BHTTP${RESET}"

    line

    echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar / Actualizar"
    echo -e "  ${GREEN}${BOLD}[02]${RESET} 🔄 Reiniciar BHTTP"
    echo -e "  ${GREEN}${BOLD}[03]${RESET} 🧪 Probar BHTTP"
    echo -e "  ${GREEN}${BOLD}[04]${RESET} 🔎 Diagnóstico"
    echo -e "  ${GREEN}${BOLD}[05]${RESET} 📜 Ver logs"

    echo
    echo -e "  ${RED}${BOLD}[06]${RESET} 🗑️  Desinstalar BHTTP"

    echo
    line

    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Volver"

    echo
    echo -e "${GRAY}  Puerto fijo: 8088 • Backend SSH: 22${RESET}"
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN${RESET}"

    echo
}

# ==============================================================
# CTRL+C
# ==============================================================

trap '

    echo
    echo -e "${YELLOW}⚠️  Regresando...${RESET}"
    sleep 1
    clear
    exit 0

' INT TERM

# ==============================================================
# ARGUMENTOS
# ==============================================================

case "${1:-}" in

    --install|-i)

        instalar_bhttp
        exit $?
        ;;

    --restart)

        reiniciar_bhttp
        exit $?
        ;;

    --probe)

        probar_bhttp
        exit $?
        ;;

    --diag)

        diagnostico
        exit $?
        ;;

    --logs)

        ver_logs
        exit $?
        ;;

    --desinstalar|--uninstall)

        desinstalar_bhttp
        exit $?
        ;;

    --status)

        clear
        mostrar_menu
        exit 0
        ;;

esac

# ==============================================================
# BUCLE PRINCIPAL
# ==============================================================

while true; do

    mostrar_menu

    read -rp \
        "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1|01)

            instalar_bhttp
            ;;

        2|02)

            reiniciar_bhttp
            ;;

        3|03)

            probar_bhttp
            ;;

        4|04)

            diagnostico
            ;;

        5|05)

            ver_logs
            ;;

        6|06)

            desinstalar_bhttp
            ;;

        0|00)

            clear
            exit 0
            ;;

        "")

            ;;

        *)

            echo
            echo -e "${RED}${BOLD}✘ Opción inválida.${RESET}"
            sleep 1
            ;;

    esac

done