# 🛡️ KevinTech Multi Script

<p align="center">"Ubuntu" (https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
"Shell" (https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
"License" (https://img.shields.io/github/license/kevinaldaircama/multi-script?style=for-the-badge)
"Stars" (https://img.shields.io/github/stars/kevinaldaircama/multi-script?style=for-the-badge)
"Forks" (https://img.shields.io/github/forks/kevinaldaircama/multi-script?style=for-the-badge)

</p><p align="center">
Administrador completo para VPS Ubuntu enfocado en la instalación y gestión de protocolos VPN, servicios SSH y herramientas de administración desde un único menú interactivo.
</p>---

✨ Características

- ✅ Instalación automática
- ✅ Menú completamente interactivo
- ✅ Compatible con Ubuntu 22.04 y 24.04
- ✅ Gestión de usuarios SSH
- ✅ Instalación y administración de protocolos
- ✅ Reinicio automático de servicios
- ✅ Firewall integrado
- ✅ Herramientas para administración del VPS
- ✅ Interfaz limpia y sencilla
- ✅ Actualizaciones fáciles desde GitHub

---

📦 Protocolos incluidos

Estado| Protocolo
✅| OpenSSH
✅| System DNS
✅| WebSocket
✅| ZIPVPN
✅| Dropbear
✅| SSL/TLS
✅| BadVPN
✅| UDP Custom
✅| SlowDNS

---

🛠 Herramientas

- Firewall
- Speedtest
- Archivo Online
- Block Torrent
- Block Ads
- Reiniciar Servicios
- Información del VPS
- Cambio de contraseña Root
- Gestión de usuarios

---

💻 Requisitos

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Arquitectura AMD64 / x86_64
- Acceso Root
- Conexión a Internet

---

🚀 Instalación

Instala el script con un solo comando:

bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh)

o utilizando wget:

wget -O install.sh https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh
chmod +x install.sh
bash install.sh

---

▶ Ejecutar el Panel

Después de la instalación:

menu

Si el comando no existe:

bash /etc/kevintech/menu.sh

---

🔄 Actualizar

cd /etc/kevintech
git pull

---

📂 Estructura del Proyecto

multi-script/
│
├── install.sh
├── README.md
│
├── protocolos/
│   ├── openssh.sh
│   ├── websocket.sh
│   ├── dropbear.sh
│   ├── ssl.sh
│   ├── badvpn.sh
│   ├── udpcustom.sh
│   ├── slowdns.sh
│   ├── zipvpn.sh
│   └── menu.sh
│
├── herramientas/
│   ├── firewall.sh
│   ├── speedtest.sh
│   ├── blockads.sh
│   ├── blocktorrent.sh
│   ├── archivoonline.sh
│   ├── reiniciar.sh
│   └── detalles.sh
│
└── usuarios/

---

📸 Vista previa

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        🛡️ KevinTech Multi Script 🛡️

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[01] OpenSSH
[02] System DNS
[03] WebSocket
[04] ZIPVPN
[05] Dropbear
[06] SSL/TLS
[07] BadVPN
[08] UDP Custom
[09] SlowDNS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

---

❤️ Contribuciones

Las contribuciones son bienvenidas.

1. Haz un Fork.
2. Crea una rama.
3. Realiza tus cambios.
4. Envía un Pull Request.

---

⭐ Apoya el Proyecto

Si este proyecto te ha sido útil:

- ⭐ Dale una estrella al repositorio.
- 🍴 Haz un Fork.
- 📢 Compártelo con otras personas.

---

👨‍💻 Autor

Kevin Aldair Camacho

GitHub:
https://github.com/kevinaldaircama

Repositorio:
https://github.com/kevinaldaircama/multi-script

---

<p align="center">Hecho con ❤️ por <b>KevinTech Tutorials</b>

</p>
