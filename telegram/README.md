# KevinTech Telegram Bot - Full

Bot integrado con `/etc/kevintech`.

## Instalación

Desde la raíz del proyecto:

```bash
sudo bash telegram/install.sh
```

Pide Token + Telegram ID del dueño y crea un servicio systemd permanente.

## Usuarios

La creación por Telegram usa la misma lógica esencial de `usuarios/add.sh`:
- useradd con expiración
- contraseña
- límite en `/etc/kevintech/limits`
- sincronización ZiVPN si existe
- limitador cron
- entrega de credenciales y datos del servidor

Renovar, cambiar contraseña, eliminar, bloquear y desbloquear se ejecutan directamente desde el bot.

## Seguridad

`telegram/.env` nunca debe subirse a GitHub.
