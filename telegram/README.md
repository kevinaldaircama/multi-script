# 🤖 KevinTech Telegram Bot V4 Premium

Integrado con `/etc/kevintech`.

## V4
- Instalador seguro: si se ejecuta desde `/etc/kevintech/telegram`, no copia un archivo sobre sí mismo.
- `.env` se conserva en las actualizaciones.
- setup valida el token con Telegram.
- service con restart/status/logs/errors/health.
- health verifica systemd, permisos y Python.
- operaciones pesadas se ejecutan en segundo plano.
- crear/renovar muestran ficha detallada inspirada en `usuarios/add.sh`.

## Instalar
`bash telegram/install.sh`

También: `cd /etc/kevintech/telegram && bash install.sh`

## Servicio
`bash /etc/kevintech/telegram/service.sh status`
`bash /etc/kevintech/telegram/service.sh logs`
`bash /etc/kevintech/telegram/service.sh health`

No subas `.env`, `logs/` ni `offset` a GitHub.
