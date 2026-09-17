# KevinTech Web Panel

Panel web independiente para KevinTech Multi Script.

- Se instala en `/etc/kevintech/web/`.
- No reemplaza ni edita los módulos `usuarios/`, `protocolos/`, `herramientas/` ni `telegram/`.
- Usa `kevintech-web.service` con `Restart=always`.
- Backend local en `127.0.0.1:18080`.
- Si HAProxy está instalado y existe `SERVER_DOMAIN`, crea una ruta HTTPS por SNI para ese dominio y conserva los puertos 80/8080 del túnel existente.
- La consola web requiere autenticación de administrador.

## Instalación independiente

```bash
bash /etc/kevintech/web/install.sh
```

También se ejecuta automáticamente desde el instalador principal después de instalar los módulos.

## Acceso

Con el dominio configurado y HAProxy activo:

```text
https://TU-DOMINIO/
```

El certificado utilizado es el certificado que ya tenga HAProxy (`/etc/haproxy/yha.pem`). Si ese certificado es autofirmado, el navegador mostrará una advertencia; para producción conviene usar un certificado público válido.
