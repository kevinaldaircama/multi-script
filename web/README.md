# KevinTech Web Panel

Panel web independiente para KevinTech Multi Script.

- Instala en `/etc/kevintech/web/`.
- Backend local: `127.0.0.1:18080`.
- No reemplaza ni modifica los directorios `usuarios/`, `protocolos/`, `herramientas/` ni `telegram/`.
- Usuarios web: registro, perfil, cuentas SSH/V2Ray, crear, eliminar, renovar, online, ads y referidos.
- Administradores: funciones de administración y consola web.
- El instalador ofrece: instalar/actualizar, cambiar datos y eliminar.

## Publicación con HAProxy

El instalador intenta añadir una ruta segura `/kevintech-web/` al frontend HTTPS existente de HAProxy sin cambiar los puertos 80/443/8080. Si no puede hacerlo automáticamente, deja el fragmento en `haproxy-snippet.cfg`.
