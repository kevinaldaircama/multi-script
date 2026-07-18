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

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Arquitectura x86_64 / AMD64

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

| Protocolo | Estado |
|-----------|:------:|
| OpenSSH | ✅ |
| System DNS | ✅ |
| WebSocket | ✅ |
| ZIPVPN | ✅ |
| Dropbear | ✅ |
| SSL/TLS | ✅ |
| BadVPN | ✅ |
| UDP Custom | ✅ |
| V2Ray / Xray | ✅ |
| SlowDNS | ❌ En desarrollo |

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

# 🩹 Solución de errores

Si algún módulo muestra un error similar a:

```text
warning: here-document delimited by end-of-file (wanted `EOF`)
syntax error: unexpected end of file
```

Ejecuta:

```bash
sed -i 's/[[:space:]]*$//' /etc/kevintech/protocolos/ssl.sh
bash -n /etc/kevintech/protocolos/ssl.sh
```

Si el problema ocurre en otro módulo, reemplaza `ssl.sh` por el nombre correspondiente, por ejemplo:

```bash
sed -i 's/[[:space:]]*$//' /etc/kevintech/protocolos/v2ray.sh
bash -n /etc/kevintech/protocolos/v2ray.sh
```

Si `bash -n` no muestra ningún mensaje, el script no tiene errores de sintaxis.

---

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

GitHub: https://github.com/kevinaldaircama

Repositorio: https://github.com/kevinaldaircama/multi-script

---

<p align="center">
Hecho con ❤️ por <b>KevinTech Tutorials</b>
</p>
