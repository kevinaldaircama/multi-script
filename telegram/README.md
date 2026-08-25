# KEVINTECH Telegram Bot

Bot integrado para Multi Script.

## Instalar

Desde la raíz del proyecto:

```bash
sudo bash telegram/install.sh
```

El instalador pide Token + Telegram ID del dueño, crea el servicio systemd y lo mantiene activo.

## Estado

```bash
systemctl status kevintech-telegram --no-pager
journalctl -u kevintech-telegram -f
```

No subas `telegram/.env` a GitHub.
