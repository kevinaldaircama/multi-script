# KevinTech Web Panel

- Un solo instalador: `installer.sh`.
- URL pública: `https://TU_DOMINIO/login`.
- Backend: `127.0.0.1:18080`.
- Opción 1: instalación nueva si no existe; actualización si ya existe, conservando credenciales y dominio.
- Opción 2: cambia usuario, contraseña y dominio; ENTER conserva cada valor.
- Opción 3: logs.
- Opción 4: desinstala la web, servicios, integración HAProxy, certificado y archivos de la web.
- Después de desinstalar, opción 1 vuelve a pedir todos los datos y hace una instalación nueva.
- No toca `usuarios/`, `protocolos/`, `herramientas/` ni `telegram/`.
- Todas las páginas HTML están separadas en `templates/*.html`.
