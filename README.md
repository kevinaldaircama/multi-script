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
- 🐌 SlowDNS
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
- x86_64 / AMD64

---

# 📥 Instalación

## Instalación rápida

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh)
```

o

```bash
wget -O install.sh https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh
chmod +x install.sh
bash install.sh
```

---

# ▶ Ejecutar el panel

```bash
menu
```

o

```bash
bash /etc/kevintech/menu.sh
```

---

# 📦 Protocolos soportados

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
| SlowDNS | ✅ |

---

# 🛠 Herramientas

- Firewall
- Speedtest
- Archivo Online
- Block Torrent
- Block Ads
- Reiniciar Servicios
- Información del VPS
- Cambio de contraseña Root

---

# 📂 Estructura

```
multi-script
│
├── install.sh
├── menu.sh
├── README.md
│
├── protocolos
│   ├── openssh.sh
│   ├── websocket.sh
│   ├── zipvpn.sh
│   ├── dropbear.sh
│   ├── ssl.sh
│   ├── badvpn.sh
│   ├── udpcustom.sh
│   ├── slowdns.sh
│   └── menu.sh
│
├── herramientas
│   ├── firewall.sh
│   ├── speedtest.sh
│   ├── archivoonline.sh
│   ├── blockads.sh
│   ├── blocktorrent.sh
│   ├── reiniciar.sh
│   ├── detalles.sh
│   └── menu.sh
│
└── usuarios
```

---

# 📸 Vista previa

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🛡️ KevinTech Multi Script 🛡️
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[01] OpenSSH
[02] System DNS
[03] WebSocket
[04] ZIPVPN
[05] Dropbear
[06] SSL/TLS
[07] BadVPN
[08] UDP Custom
[09] SlowDNS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

# 🔄 Actualizar

```bash
cd /etc/kevintech
git pull
```

---

# 🤝 Contribuciones

Las contribuciones son bienvenidas.

1. Haz un Fork.
2. Crea una rama.
3. Realiza tus cambios.
4. Envía un Pull Request.

---

# ⭐ Apoya el proyecto

Si este proyecto te fue útil:

⭐ Dale una estrella al repositorio.

🍴 Haz un Fork.

📢 Compártelo con otros usuarios.

---

# 👨‍💻 Autor

**Kevin Aldair Camacho**

GitHub: https://github.com/kevinaldaircama

Repositorio: https://github.com/kevinaldaircama/multi-script

---

<p align="center">
Hecho con ❤️ por <b>KevinTech Tutorials</b>
</p>
