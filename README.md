# 🛡️ KevinTech Multi Script

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white">
  <img src="https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img src="https://img.shields.io/github/stars/kevinaldaircama/multi-script?style=for-the-badge">
  <img src="https://img.shields.io/github/forks/kevinaldaircama/multi-script?style=for-the-badge">
  <img src="https://img.shields.io/github/license/kevinaldaircama/multi-script?style=for-the-badge">
</p>

<p align="center">
Administrador completo para VPS Ubuntu con instalación automática de protocolos VPN, herramientas y servicios desde un único panel.
</p>

---

# ✨ Características

- 🚀 Instalación automática
- 🔐 OpenSSH
- 🌐 System DNS
- 🔄 WebSocket
- 📦 ZIPVPN
- 🛡️ Dropbear
- 🔒 SSL/TLS
- ⚡ BadVPN
- 🚀 UDP Custom
- 🌐 V2Ray / Xray
- 🔥 Firewall
- 📊 Speedtest
- 📁 Archivo Online
- 🚫 Block Torrent
- 🚫 Block Ads
- 🔄 Reinicio de servicios
- 👥 Gestión de usuarios
- 🔑 Cambio de contraseña Root
- 📋 Información del VPS

---

# 💻 Compatibilidad

todas las versiones de Ubuntu 
---

# 📥 Instalación

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh)
```

---

# ▶ Acceder al Script

Una vez finalizada la instalación, ejecuta:

```bash
menu
```

---

# 📦 Protocolos Disponibles

| Protocolo | Estado | Tipo |
|-----------|:------:|------|
| OpenSSH | ✅ | Cuenta Linux |
| Hysteria | ✅ | **Individual por cuenta** |
| Shadowsocks | ✅ | **Individual por cuenta** |
| BTun | ✅ | **Individual por cuenta** |
| SOCKS5 | ✅ | **Individual por cuenta** |
| System DNS | ✅ | Compartido |
| WebSocket | ✅ | Compartido |
| ZIPVPN | ✅ | Compartido |
| Dropbear | ✅ | Compartido |
| SSL/TLS | ✅ | Compartido |
| BadVPN | ✅ | Compartido |
| UDP Custom | ✅ | Compartido |
| V2Ray / Xray | ✅ | Compartido |
| SlowDNS | ✅ | Compartido |

> ⚡ **Hysteria, Shadowsocks, BTun y SOCKS5** crean **recurso propio (puerto/credencial) por cada cuenta**, igual que el bot. Ya no se comparten entre usuarios.

---

# ✨ Cuentas con Protocolos Independientes

Al crear un usuario con `add.sh`, si el protocolo está activo (`HYSTERIA=ON`, `SHADOWSOCKS=ON`, `BTUN=ON`, `SOCKS5=ON` en `config.conf`), se entrega lo siguiente por cuenta:

| Protocolo | Recurso individual | Dónde se registra |
|-----------|--------------------|--------------------|
| Hysteria | Puerto UDP propio + auth + obfs | `/etc/hysteria/config.<puerto>.json` + `bot_ssh/cuentas_extra.conf` |
| Shadowsocks | Puerto TCP+UDP propio + password | `/etc/shadowsocks-libev/<puerto>.json` + `bot_ssh/cuentas_extra.conf` |
| BTun | Usuario/password propio | `/etc/btun/users` + `bot_ssh/cuentas_extra.conf` |
| SOCKS5 | Usuario/password propio (puerto 1080) | Usuario Linux + `bot_ssh/cuentas_extra.conf` |

### Uso directo (no interactivo)

```bash
# Crear cuenta SSH
$BASE/usuarios/account.sh add_ssh usuario pass dias limite

# Crear protocolos individuales
$BASE/usuarios/account.sh hysteria_add usuario
$BASE/usuarios/account.sh ss_add usuario
$BASE/usuarios/account.sh btun_add usuario
$BASE/usuarios/account.sh socks5_add usuario [pass]

# Eliminar
$BASE/usuarios/account.sh delete_ssh usuario
$BASE/usuarios/account.sh hysteria_del usuario
$BASE/usuarios/account.sh ss_del usuario
$BASE/usuarios/account.sh btun_del usuario
$BASE/usuarios/account.sh socks5_del usuario
```

`delete.sh` limpia automáticamente los recursos individuales del usuario al eliminarlo.

---

# 🛠 Herramientas

- 🔥 Firewall
- 📊 Speedtest
- 📁 Archivo Online
- 🚫 Block Torrent
- 🚫 Block Ads
- 🔄 Reiniciar Servicios
- 📋 Información del VPS
- 🔑 Cambiar contraseña Root

---

# 🔄 Actualizar

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/update.sh)
```

---

## Seguridad

El instalador configura automáticamente:

• Fail2Ban
  - Protección para SSH y Dropbear.
  - Bloqueo automático después de 3 intentos fallidos.
  - Tiempo de baneo: 1 hora.
  - Recidiva: 1 semana.

• RKHunter
  - Escaneo de rootkits.
  - Verificación de binarios modificados.
  - Base de datos actualizada automáticamente.

• Chkrootkit
  - Detección de rootkits conocidos.
  - Escaneo rápido del sistema.

• Lynis
  - Auditoría completa de seguridad.
  - Recomendaciones de hardening.
  - Índice de seguridad del servidor.

• Monitoreo de Consumo
  - Snapshot automático cada minuto mediante Cron y Systemd.
  - Registro del consumo de red.
  - Base de datos:
    /etc/kevintech/sistema/network_state.conf

Los límites de consumo pueden configurarse desde:

Herramientas
 └── [10] Consumo de Red
      └── [3] Configurar límites (GB)

# 🤝 Contribuciones

Las contribuciones son bienvenidas.

1. Haz un Fork.
2. Crea una rama para tus cambios.
3. Realiza tus modificaciones.
4. Envía un Pull Request.

---

# ⭐ Apoya el proyecto

Si este proyecto te fue útil:

- ⭐ Dale una estrella al repositorio.
- 🍴 Haz un Fork.
- 📢 Compártelo con otros usuarios.

---

# 👨‍💻 Autor

**Kevin Aldair Camacho**

- redes sociales: Kevin tech tutorials

---

<p align="center">
Hecho con ❤️ por <b>KevinTech Tutorials</b>
</p>
