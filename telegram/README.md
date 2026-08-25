# KEVINTECH Telegram Bot — integrado

Este módulo está diseñado para colocarse dentro de `multi-script-main/telegram/`.

## Instalación

Desde la raíz del proyecto:

```bash
sudo bash telegram/install.sh
```

El instalador:
- instala `curl` y `jq`;
- copia el bot a `/etc/kevintech/telegram`;
- pide el token y los Telegram ID;
- crea un servicio systemd;
- inicia el bot automáticamente.

## Comprobar

```bash
systemctl status kevintech-telegram --no-pager
journalctl -u kevintech-telegram -f
```

## Configuración

Las credenciales están únicamente en:

```text
/etc/kevintech/telegram/.env
```

No se deben subir a GitHub.

## Integración

El bot busca módulos existentes dentro de `/etc/kevintech` y los ejecuta cuando corresponda. No reemplaza ni modifica los módulos existentes.

Nota: los módulos interactivos que requieren muchas preguntas en terminal necesitarán handlers específicos para convertir ese flujo en botones/pasos de Telegram. El bot base ya está preparado para esa ampliación.
