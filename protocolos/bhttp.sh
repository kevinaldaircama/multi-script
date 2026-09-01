#!/usr/bin/env bash

# ==============================================================
#                  🌐 KEVINTECH BHTTP
#                    PREMIUM MODULE
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/bhttp.sh
# Config  : /etc/kevintech/bhttp.conf
# Servicio: bhttp.service
# Versión : 3.2 Premium
#
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"
BHTTP_DIR="/usr/local/lib/bhttp"
SERVER_PY="$BHTTP_DIR/bhttp-server.py"
UNIT="/etc/systemd/system/bhttp.service"
SERVICE="bhttp"
CONFIG="$BASE/bhttp.conf"

BHTTP_HOST="0.0.0.0"
BHTTP_PORT="8080"

SSH_HOST="127.0.0.1"
SSH_PORT="22"

CANDIDATOS=(
    8080
    80
    8443
    443
    2082
    2095
    8880
    2052
    3128
)

# ==============================================================
# COLORES KEVINTECH
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
# CONFIGURACIÓN
# ==============================================================

crear_config() {

    if [[ ! -f "$CONFIG" ]]; then

        cat > "$CONFIG" <<EOF
BHTTP_PORT=8080
BHTTP_HOST=0.0.0.0
SSH_PORT=22
SSH_HOST=127.0.0.1
BHTTP=OFF
EOF

    fi
}

cargar_config() {

    crear_config

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null || true

    BHTTP_PORT="${BHTTP_PORT:-8080}"
    BHTTP_HOST="${BHTTP_HOST:-0.0.0.0}"

    SSH_PORT="${SSH_PORT:-22}"
    SSH_HOST="${SSH_HOST:-127.0.0.1}"
}

guardar_config() {

    cat > "$CONFIG" <<EOF
BHTTP_PORT=$BHTTP_PORT
BHTTP_HOST=$BHTTP_HOST
SSH_PORT=$SSH_PORT
SSH_HOST=$SSH_HOST
BHTTP=$BHTTP
EOF

}

cargar_config

# ==============================================================
# UTILIDADES
# ==============================================================

pause() {

    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

line() {

    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

separator() {

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

valid_port() {

    [[ "$1" =~ ^[0-9]+$ ]] &&
    (( "$1" >= 1 )) &&
    (( "$1" <= 65535 ))
}

# ==============================================================
# PUERTOS
# ==============================================================

puertos_ocupados() {

    if command -v ss >/dev/null 2>&1; then

        ss -H -tln 2>/dev/null |
            awk '{print $4}' |
            sed 's/.*://'

    elif command -v netstat >/dev/null 2>&1; then

        netstat -tln 2>/dev/null |
            awk '/^tcp/ {print $4}' |
            sed 's/.*://'

    fi |
        grep -E '^[0-9]+$' |
        sort -u
}

puerto_libre() {

    local PORT="$1"

    ! puertos_ocupados | grep -qx "$PORT"
}

primer_puerto_libre() {

    local P

    for P in "${CANDIDATOS[@]}"; do

        if puerto_libre "$P"; then
            echo "$P"
            return
        fi

    done

    echo "8080"
}

puerto_escuchando() {

    local PORT="$1"

    if command -v ss >/dev/null 2>&1; then

        ss -H -tln 2>/dev/null |
            awk '{print $4}' |
            grep -qE ":${PORT}$"

    else

        return 1

    fi
}

# ==============================================================
# ESTADO
# ==============================================================

servicio_instalado() {

    [[ -f "$UNIT" ]] &&
    [[ -f "$SERVER_PY" ]]
}

servicio_online() {

    systemctl is-active --quiet "$SERVICE" 2>/dev/null
}

mostrar_estado_simple() {

    if ! servicio_instalado; then

        echo -e "${GRAY}● NO INSTALADO${RESET}"

    elif servicio_online; then

        echo -e "${GREEN}● ONLINE${RESET}"

    elif systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then

        echo -e "${YELLOW}● STOPPED${RESET}"

    else

        echo -e "${RED}● OFF${RESET}"

    fi
}

# ==============================================================
# CREAR USUARIO SSH
# ==============================================================

crear_usuario() {

    local USERNAME="$1"
    local PASSWORD="$2"

    if [[ -z "$USERNAME" ]]; then

        echo
        read -rp "$(echo -e "${CYAN}Usuario SSH: ${RESET}")" USERNAME

    fi

    if [[ -z "$USERNAME" ]]; then

        echo -e "${RED}✘ Usuario vacío.${RESET}"
        return 1

    fi

    if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then

        echo -e "${RED}✘ Nombre de usuario inválido.${RESET}"
        return 1

    fi

    if id "$USERNAME" >/dev/null 2>&1; then

        echo -e "${YELLOW}⚠ El usuario ya existe.${RESET}"

    else

        useradd -M -s /bin/bash "$USERNAME"

        if [[ $? -ne 0 ]]; then

            echo -e "${RED}✘ No se pudo crear el usuario.${RESET}"
            return 1

        fi

        echo -e "${GREEN}✔ Usuario creado.${RESET}"

    fi

    if [[ -z "$PASSWORD" ]]; then

        PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 12)

    fi

    if [[ -z "$PASSWORD" ]]; then

        PASSWORD="kt$(date +%s)"

    fi

    echo "$USERNAME:$PASSWORD" | chpasswd

    if [[ $? -ne 0 ]]; then

        echo -e "${RED}✘ No se pudo establecer la contraseña.${RESET}"
        return 1

    fi

    echo
    echo -e "${GREEN}${BOLD}✔ CUENTA SSH LISTA${RESET}"
    line
    echo -e "${WHITE}Usuario :${RESET} ${CYAN}$USERNAME${RESET}"
    echo -e "${WHITE}Clave   :${RESET} ${CYAN}$PASSWORD${RESET}"
    echo -e "${WHITE}SSH     :${RESET} ${CYAN}$SSH_PORT${RESET}"
    line

    pause
}

# ==============================================================
# DIAGNÓSTICO SSH
# ==============================================================

diagnostico() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🔎 BHTTP DIAGNÓSTICO                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${WHITE}Servicio${RESET}"
    line

    if servicio_online; then
        echo -e "  Estado       : ${GREEN}ONLINE${RESET}"
    else
        echo -e "  Estado       : ${RED}OFFLINE${RESET}"
    fi

    echo
    echo -e "${WHITE}Configuración${RESET}"
    line

    echo -e "  Host BHTTP   : ${CYAN}$BHTTP_HOST${RESET}"
    echo -e "  Puerto BHTTP : ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "  Backend SSH  : ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"

    echo
    echo -e "${WHITE}SSH${RESET}"
    line

    if systemctl is-active --quiet ssh 2>/dev/null ||
       systemctl is-active --quiet sshd 2>/dev/null; then

        echo -e "  SSH          : ${GREEN}ACTIVO${RESET}"

    else

        echo -e "  SSH          : ${RED}INACTIVO${RESET}"

    fi

    if puerto_escuchando "$SSH_PORT"; then

        echo -e "  Puerto SSH   : ${GREEN}ESCUCHANDO${RESET}"

    else

        echo -e "  Puerto SSH   : ${RED}NO DETECTADO${RESET}"

    fi

    echo
    echo -e "${WHITE}BHTTP${RESET}"
    line

    if puerto_escuchando "$BHTTP_PORT"; then

        echo -e "  Puerto $BHTTP_PORT : ${GREEN}ESCUCHANDO${RESET}"

    else

        echo -e "  Puerto $BHTTP_PORT : ${RED}NO ESCUCHA${RESET}"

    fi

    echo
    echo -e "${WHITE}Últimos registros${RESET}"
    line

    journalctl \
        -u "$SERVICE" \
        -n 8 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# ESCRIBIR SERVIDOR PYTHON
# ==============================================================

instalar_servidor_python() {

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

    length = size if mode == 2 and size >= 10 else 10

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

        self.reader, self.writer = await asyncio.open_connection(
            host,
            port
        )

        log(
            "sesion %s: conectada al backend %s:%d"
            % (
                self.session_id.hex()[:8],
                host,
                port
            )
        )

        asyncio.create_task(self.backend_reader())

    async def backend_reader(self):

        total = 0

        try:

            while True:

                data = await self.reader.read(65536)

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

                self.upload_pending[sequence] = data

            while self.upload_next in self.upload_pending:

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

                while self.download_assign <= sequence:

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

    def __init__(
        self,
        host,
        port,
        backend
    ):

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

            if session is None or session.closed:

                for old_id, old_session in list(
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

    async def handle(
        self,
        reader,
        writer
    ):

        try:

            while True:

                header = await reader.readexactly(29)

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
                        len(reply).to_bytes(4, "big") +
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
                        length if length > 0 else 1399,
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
            real_length.to_bytes(4, "big")
            +
            encrypted
        )

        writer.write(
            bytes([2]) +
            len(body).to_bytes(4, "big") +
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

    chmod +x "$SERVER_PY"
}

# ==============================================================
# CREAR SYSTEMD
# ==============================================================

crear_servicio() {

    local PYTHON

    PYTHON=$(command -v python3)

    if [[ -z "$PYTHON" ]]; then

        echo -e "${RED}✘ Python3 no está instalado.${RESET}"
        return 1

    fi

    cat > "$UNIT" <<EOF
[Unit]
Description=KevinTech BHTTP Server
After=network.target ssh.service

[Service]
Type=simple
User=root
ExecStart=$PYTHON $SERVER_PY --host $BHTTP_HOST --port $BHTTP_PORT --backend-host $SSH_HOST --backend-port $SSH_PORT
Restart=always
RestartSec=3
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

}

# ==============================================================
# VERIFICACIÓN REAL DEL PROTOCOLO
# ==============================================================

verificar_bhttp() {

    python3 - "$BHTTP_PORT" <<'PY'
import hashlib
import os
import socket
import sys

PORT = int(sys.argv[1])

MAGIC = b"BHP1"

SESSION = os.urandom(16)


def stream(mode, sequence, direction, length):

    output = b""
    counter = 0

    while len(output) < length:

        data = (
            SESSION +
            bytes([mode]) +
            sequence.to_bytes(8, "big") +
            bytes([direction]) +
            counter.to_bytes(4, "big")
        )

        output += hashlib.sha256(data).digest()

        counter += 1

    return output[:length]


def mask(data, mode, sequence, direction):

    key = stream(
        mode,
        sequence,
        direction,
        len(data)
    )

    return bytes(
        a ^ b
        for a, b in zip(data, key)
    )


def recv_all(sock, size):

    data = b""

    while len(data) < size:

        part = sock.recv(
            size - len(data)
        )

        if not part:
            raise RuntimeError(
                "conexion cerrada"
            )

        data += part

    return data


try:

    sock = socket.create_connection(
        ("127.0.0.1", PORT),
        timeout=5
    )

    payload = (
        MAGIC +
        bytes([1, 0]) +
        (0).to_bytes(4, "big")
    )

    encrypted = mask(
        payload,
        0,
        0,
        0
    )

    header = (
        bytes([0]) +
        SESSION +
        (0).to_bytes(8, "big") +
        len(encrypted).to_bytes(4, "big")
    )

    sock.sendall(
        header +
        encrypted
    )

    status = recv_all(
        sock,
        1
    )[0]

    length = int.from_bytes(
        recv_all(sock, 4),
        "big"
    )

    body = (
        recv_all(sock, length)
        if length
        else b""
    )

    sock.close()

    if status != 0:
        raise RuntimeError(
            "status=%d" % status
        )

    decoded = mask(
        body,
        0,
        0,
        1
    )

    if decoded[:4] != MAGIC:
        raise RuntimeError(
            "respuesta BHP1 inválida"
        )

    print("OK")

except Exception as error:

    print(
        "ERROR:%s" % error
    )

PY
}

# ==============================================================
# INSTALAR
# ==============================================================

instalar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🌐 INSTALAR BHTTP                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    cargar_config

    if ! command -v python3 >/dev/null 2>&1; then

        echo -e "${YELLOW}▸ Instalando Python3...${RESET}"

        apt-get update -qq >/dev/null 2>&1
        apt-get install -y python3 >/dev/null 2>&1

        if ! command -v python3 >/dev/null 2>&1; then

            echo -e "${RED}✘ No se pudo instalar Python3.${RESET}"
            pause
            return 1

        fi

        echo -e "${GREEN}✔ Python3 instalado.${RESET}"

    fi

    echo
    echo -e "${WHITE}Configuración del servidor${RESET}"
    line

    local DEFAULT_PORT

    DEFAULT_PORT="$BHTTP_PORT"

    if [[ ! "$DEFAULT_PORT" =~ ^[0-9]+$ ]]; then

        DEFAULT_PORT=$(primer_puerto_libre)

    fi

    read -rp "$(echo -e "${CYAN}Puerto BHTTP [${DEFAULT_PORT}]: ${RESET}")" NEW_PORT

    [[ -z "$NEW_PORT" ]] && NEW_PORT="$DEFAULT_PORT"

    if ! valid_port "$NEW_PORT"; then

        echo -e "${RED}✘ Puerto inválido.${RESET}"
        pause
        return 1

    fi

    # Si el puerto ya pertenece al BHTTP, se permite reinstalar.
    if puerto_escuchando "$NEW_PORT"; then

        if ! servicio_online ||
           [[ "$NEW_PORT" != "$BHTTP_PORT" ]]; then

            echo
            echo -e "${RED}✘ El puerto $NEW_PORT ya está ocupado.${RESET}"
            echo
            echo -e "${GRAY}Puertos sugeridos:${RESET}"

            primer_puerto_libre

            pause

            return 1

        fi

    fi

    BHTTP_PORT="$NEW_PORT"

    read -rp "$(echo -e "${CYAN}Puerto SSH backend [${SSH_PORT}]: ${RESET}")" NEW_SSH

    [[ -z "$NEW_SSH" ]] && NEW_SSH="$SSH_PORT"

    if ! valid_port "$NEW_SSH"; then

        echo -e "${RED}✘ Puerto SSH inválido.${RESET}"
        pause
        return 1

    fi

    SSH_PORT="$NEW_SSH"

    BHTTP_HOST="0.0.0.0"
    SSH_HOST="127.0.0.1"

    BHTTP="ON"

    guardar_config

    echo
    echo -e "${MAGENTA}${BOLD}▸ Instalando servidor BHTTP...${RESET}"

    instalar_servidor_python || {

        echo -e "${RED}✘ No se pudo escribir el servidor.${RESET}"

        pause

        return 1
    }

    crear_servicio || {

        echo -e "${RED}✘ No se pudo crear el servicio.${RESET}"

        pause

        return 1
    }

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    systemctl restart "$SERVICE"

    echo
    echo -e "${GRAY}▸ Verificando servicio...${RESET}"

    local ONLINE=0

    for ((i=1; i<=10; i++)); do

        if servicio_online; then

            ONLINE=1
            break

        fi

        sleep 1

    done

    # ==========================================================
    # CORRECCIÓN DEL FALSO ERROR
    # ==========================================================

    if [[ "$ONLINE" != "1" ]]; then

        echo
        echo -e "${RED}${BOLD}✘ BHTTP no pudo iniciar.${RESET}"
        echo

        systemctl status "$SERVICE" \
            --no-pager \
            -l \
            2>/dev/null

        echo
        echo -e "${YELLOW}Últimos registros:${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

        pause

        return 1

    fi

    # ==========================================================
    # VERIFICAR PUERTO
    # ==========================================================

    if ! puerto_escuchando "$BHTTP_PORT"; then

        echo
        echo -e "${RED}✘ El servicio está activo pero el puerto no escucha.${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

        pause

        return 1

    fi

    echo
    echo -e "${GREEN}${BOLD}✔ BHTTP está ONLINE${RESET}"

    echo
    echo -e "${GRAY}▸ Verificando protocolo BHP1...${RESET}"

    local TEST

    TEST=$(verificar_bhttp 2>/dev/null)

    if [[ "$TEST" == "OK" ]]; then

        echo -e "${GREEN}✔ Protocolo BHTTP responde correctamente.${RESET}"

    else

        echo -e "${YELLOW}⚠ Servicio activo, pero no se pudo completar la prueba BHP1.${RESET}"
        echo -e "${GRAY}Esto no significa necesariamente que el servicio esté detenido.${RESET}"

    fi

    guardar_config

    echo
    mostrar_resumen

    pause
}

# ==============================================================
# RESUMEN
# ==============================================================

mostrar_resumen() {

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     🌐 BHTTP STATUS                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${WHITE}Servicio :${RESET} $(mostrar_estado_simple)"
    echo -e "${WHITE}Unidad   :${RESET} ${GRAY}$UNIT${RESET}"
    echo -e "${WHITE}Servidor :${RESET} ${GRAY}$SERVER_PY${RESET}"
    echo -e "${WHITE}Puerto   :${RESET} ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "${WHITE}SSH      :${RESET} ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"

    if puerto_escuchando "$BHTTP_PORT"; then
        echo -e "${WHITE}Listener :${RESET} ${GREEN}0.0.0.0:$BHTTP_PORT${RESET}"
    else
        echo -e "${WHITE}Listener :${RESET} ${RED}NO ESCUCHANDO${RESET}"
    fi

    if puerto_escuchando "$SSH_PORT"; then
        echo -e "${WHITE}SSH      :${RESET} ${GREEN}✔ SSH activo${RESET}"
    else
        echo -e "${WHITE}SSH      :${RESET} ${RED}✘ SSH no detectado${RESET}"
    fi
}

# ==============================================================
# INICIAR
# ==============================================================

iniciar_bhttp() {

    if ! servicio_instalado; then

        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return
    fi

    systemctl start "$SERVICE"

    sleep 1

    if servicio_online; then

        echo -e "${GREEN}✔ BHTTP iniciado correctamente.${RESET}"

    else

        echo -e "${RED}✘ No se pudo iniciar BHTTP.${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 15 \
            --no-pager

    fi

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

reiniciar_bhttp() {

    if ! servicio_instalado; then

        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return
    fi

    systemctl restart "$SERVICE"

    sleep 1

    if servicio_online; then

        echo -e "${GREEN}✔ BHTTP reiniciado correctamente.${RESET}"

    else

        echo -e "${RED}✘ BHTTP no pudo reiniciar.${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 15 \
            --no-pager

    fi

    pause
}

# ==============================================================
# DETENER
# ==============================================================

detener_bhttp() {

    if ! servicio_instalado; then

        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return
    fi

    systemctl stop "$SERVICE"

    if ! servicio_online; then

        BHTTP="OFF"

        guardar_config

        echo -e "${GREEN}✔ BHTTP detenido.${RESET}"

    else

        echo -e "${RED}✘ No se pudo detener BHTTP.${RESET}"

    fi

    pause
}

# ==============================================================
# CAMBIAR PUERTO
# ==============================================================

cambiar_puerto() {

    if ! servicio_instalado; then

        echo -e "${RED}✘ Primero instala BHTTP.${RESET}"

        pause

        return
    fi

    echo
    echo -e "${WHITE}Puerto actual:${RESET} ${CYAN}$BHTTP_PORT${RESET}"

    read -rp "$(echo -e "${CYAN}Nuevo puerto: ${RESET}")" NEW_PORT

    if ! valid_port "$NEW_PORT"; then

        echo -e "${RED}✘ Puerto inválido.${RESET}"

        pause

        return
    fi

    if [[ "$NEW_PORT" != "$BHTTP_PORT" ]] &&
       puerto_escuchando "$NEW_PORT"; then

        echo -e "${RED}✘ El puerto $NEW_PORT está ocupado.${RESET}"

        pause

        return
    fi

    systemctl stop "$SERVICE"

    BHTTP_PORT="$NEW_PORT"

    guardar_config

    crear_servicio

    systemctl daemon-reload

    systemctl restart "$SERVICE"

    sleep 2

    if servicio_online &&
       puerto_escuchando "$BHTTP_PORT"; then

        echo
        echo -e "${GREEN}${BOLD}✔ Puerto cambiado correctamente.${RESET}"
        echo
        echo -e "${WHITE}Nuevo puerto:${RESET} ${CYAN}$BHTTP_PORT${RESET}"

    else

        echo
        echo -e "${RED}✘ No se pudo cambiar el puerto.${RESET}"

        journalctl \
            -u "$SERVICE" \
            -n 15 \
            --no-pager

    fi

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
        -n 40 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# PRUEBA BHTTP
# ==============================================================

probar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🧪 PRUEBA BHTTP                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    if ! servicio_online; then

        echo -e "${RED}✘ BHTTP está detenido.${RESET}"

        pause

        return
    fi

    echo
    echo -e "${GRAY}Puerto :${RESET} ${CYAN}$BHTTP_PORT${RESET}"
    echo

    local RESULT

    RESULT=$(verificar_bhttp 2>/dev/null)

    if [[ "$RESULT" == "OK" ]]; then

        echo -e "${GREEN}${BOLD}✔ HANDSHAKE BHTTP OK${RESET}"
        echo
        echo -e "${GREEN}El servidor respondió correctamente.${RESET}"

    else

        echo -e "${RED}${BOLD}✘ HANDSHAKE FALLIDO${RESET}"
        echo
        echo -e "${GRAY}Revisa los logs del servicio.${RESET}"

    fi

    pause
}

# ==============================================================
# CREAR USUARIO DESDE MENÚ
# ==============================================================

menu_usuario() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    👤 CUENTA SSH                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    local USERNAME
    local PASSWORD

    read -rp "$(echo -e "${CYAN}Usuario: ${RESET}")" USERNAME

    read -rsp "$(echo -e "${CYAN}Contraseña [ENTER = automática]: ${RESET}")" PASSWORD

    echo

    crear_usuario "$USERNAME" "$PASSWORD"
}

# ==============================================================
# DESINSTALAR
# ==============================================================

desinstalar_bhttp() {

    clear

    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   🗑️  DESINSTALAR BHTTP                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${YELLOW}Esta acción eliminará:${RESET}"
    echo
    echo -e "  • Servicio BHTTP"
    echo -e "  • Servidor Python"
    echo -e "  • Configuración BHTTP"
    echo
    read -rp "$(echo -e "${RED}¿Continuar? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|y|yes)

            ;;

        *)

            echo
            echo -e "${GRAY}Operación cancelada.${RESET}"
            pause

            return
            ;;

    esac

    systemctl stop "$SERVICE" 2>/dev/null
    systemctl disable "$SERVICE" 2>/dev/null

    rm -f "$UNIT"
    rm -rf "$BHTTP_DIR"
    rm -f "$CONFIG"

    systemctl daemon-reload

    BHTTP="OFF"

    echo
    echo -e "${GREEN}${BOLD}✔ BHTTP desinstalado correctamente.${RESET}"

    pause
}

# ==============================================================
# MENÚ PRINCIPAL BHTTP
# ==============================================================

mostrar_menu() {

    clear

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║              🌐  KEVINTECH BHTTP  🌐                       ║"
    echo "║                                                              ║"
    echo "║                 PREMIUM PROTOCOL                            ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${GRAY}  Protocolo BHTTP • KevinTech Multi Script v3.2${RESET}"
    echo

    echo -e "${WHITE}  ESTADO DEL SERVICIO${RESET}"
    line

    echo -e "  Servicio : $(mostrar_estado_simple)"
    echo -e "  Puerto   : ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "  SSH      : ${CYAN}$SSH_PORT${RESET}"

    echo
    echo -e "${BLUE}${BOLD}  ⚙️  ADMINISTRACIÓN BHTTP${RESET}"
    line

    echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar / Actualizar"
    echo -e "  ${GREEN}${BOLD}[02]${RESET} ▶️  Iniciar BHTTP"
    echo -e "  ${GREEN}${BOLD}[03]${RESET} 🔄 Reiniciar BHTTP"
    echo -e "  ${GREEN}${BOLD}[04]${RESET} ⏹️  Detener BHTTP"
    echo -e "  ${GREEN}${BOLD}[05]${RESET} 🔌 Cambiar puerto"
    echo -e "  ${GREEN}${BOLD}[06]${RESET} 👤 Crear cuenta SSH"
    echo -e "  ${GREEN}${BOLD}[07]${RESET} 🧪 Probar BHTTP"
    echo -e "  ${GREEN}${BOLD}[08]${RESET} 🔎 Diagnóstico"
    echo -e "  ${GREEN}${BOLD}[09]${RESET} 📜 Ver logs"

    echo
    echo -e "${RED}${BOLD}  [10] 🗑️  Desinstalar BHTTP${RESET}"

    echo
    line

    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Volver"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN${RESET}"
    echo
}

# ==============================================================
# ARGUMENTOS DIRECTOS
# ==============================================================

case "${1:-}" in

    --install|-i)

        if [[ -n "${2:-}" ]]; then
            BHTTP_PORT="$2"
            BHTTP="ON"
            guardar_config
        fi

        instalar_bhttp
        exit $?
        ;;

    --start)

        iniciar_bhttp
        exit $?
        ;;

    --restart)

        reiniciar_bhttp
        exit $?
        ;;

    --stop)

        detener_bhttp
        exit $?
        ;;

    --port|-p)

        if [[ -n "${2:-}" ]]; then

            BHTTP_PORT="$2"

            guardar_config

            crear_servicio

            systemctl daemon-reload
            systemctl restart "$SERVICE"

        else

            cambiar_puerto

        fi

        exit $?
        ;;

    --status)

        mostrar_resumen
        exit 0
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
        exit 0
        ;;

    --crear-usuario)

        crear_usuario "${2:-}" "${3:-}"
        exit $?
        ;;

    --desinstalar|--uninstall)

        desinstalar_bhttp
        exit $?
        ;;

    --help|-h)

        echo
        echo "KevinTech BHTTP 3.2"
        echo
        echo "Uso:"
        echo
        echo "  bash bhttp.sh"
        echo "  bash bhttp.sh --install 8080"
        echo "  bash bhttp.sh --start"
        echo "  bash bhttp.sh --restart"
        echo "  bash bhttp.sh --stop"
        echo "  bash bhttp.sh --port 8080"
        echo "  bash bhttp.sh --status"
        echo "  bash bhttp.sh --probe"
        echo "  bash bhttp.sh --diag"
        echo "  bash bhttp.sh --logs"
        echo "  bash bhttp.sh --crear-usuario usuario clave"
        echo "  bash bhttp.sh --desinstalar"
        echo
        exit 0
        ;;

esac

# ==============================================================
# BUCLE PRINCIPAL
# ==============================================================

trap '
    echo
    echo -e "${YELLOW}⚠️  Regresando...${RESET}"
    sleep 1
    clear
    exit 0
' INT TERM

while true; do

    mostrar_menu

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1|01)

            instalar_bhttp

            ;;

        2|02)

            iniciar_bhttp

            ;;

        3|03)

            reiniciar_bhttp

            ;;

        4|04)

            detener_bhttp

            ;;

        5|05)

            cambiar_puerto

            ;;

        6|06)

            menu_usuario

            ;;

        7|07)

            probar_bhttp

            ;;

        8|08)

            diagnostico

            ;;

        9|09)

            ver_logs

            ;;

        10)

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