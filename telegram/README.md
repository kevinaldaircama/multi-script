# KEVINTECH Telegram Bot

Módulo inicial del bot de Telegram para integrarse dentro de `multi-script-main`.

## Configuración

Desde el VPS:

```bash
bash telegram/setup.sh
```

El token y los IDs se guardan en:

```text
/etc/kevintech/telegram/.env
```

El archivo queda con permisos `600` y no debe subirse a GitHub.

## Dependencias

Ubuntu/Debian:

```bash
apt update
apt install -y curl jq
```

## Ejecutar

```bash
bash telegram/bot.sh
```

El bot usa Telegram Bot API mediante `curl`, por lo que no necesita instalar un framework de Python.

## Comandos

- `/start`
- `/menu`
- `/id`

La arquitectura está preparada para conectar progresivamente los botones con los módulos existentes de Multi Script.
