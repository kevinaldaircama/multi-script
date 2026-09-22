# 🛡️ KevinTech Multi Script — Premium Edition

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white">
  <img src="https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img src="https://img.shields.io/github/stars/kevinaldaircama/multi-script?style=for-the-badge">
  <img src="https://img.shields.io/github/forks/kevinaldaircama/multi-script?style=for-the-badge">
  <img src="https://img.shields.io/github/license/kevinaldaircama/multi-script?style=for-the-badge">
</p>

<p align="center">
Administrador completo para VPS Ubuntu con instalación, gestión de protocolos, herramientas, usuarios y bot de Telegram desde un único proyecto.
</p>

---

## ✨ ¿Qué funciona en el Script?

### 🔐 Protocolos y servicios
- ✅ OpenSSH
- ✅ Dropbear
- ✅ OpenVPN
- ✅ SSL/TLS + WebSocket
- ✅ BHTTP
- ✅ V2Ray / Xray
- ✅ SlowDNS
- ✅ BadVPN
- ✅ UDP Custom
- ✅ ZiVPN
- ✅ CheckUser / servicios internos

### 🛠️ Herramientas
- ✅ Firewall
- ✅ Optimización del VPS
- ✅ Speedtest
- ✅ Scanner
- ✅ Archivo Online
- ✅ Bloqueo de Torrent
- ✅ Bloqueo de Ads
- ✅ Reinicio de servicios
- ✅ Cambio de contraseña Root
- ✅ Información del VPS
- ✅ Backup y restauración

### 👥 Gestión de cuentas
- ✅ Crear usuarios SSH
- ✅ Editar cuentas
- ✅ Eliminar cuentas
- ✅ Cambiar contraseñas
- ✅ Límites por cuenta
- ✅ Fechas de vencimiento
- ✅ Lista de usuarios
- ✅ Registro de conexiones
- ✅ Herramientas de administración desde el menú

---

## 🤖 ¿Qué funciona en el Bot de Telegram?

El bot permite administrar las cuentas desde Telegram sin tener que entrar constantemente al VPS.

### 👤 Para usuarios
- ✅ Crear cuenta normal
- ✅ Crear cuenta V2Ray
- ✅ Consultar sus cuentas
- ✅ Consultar información de una cuenta
- ✅ Renovar una cuenta
- ✅ Eliminar una cuenta
- ✅ Ver cuentas y conexiones online
- ✅ Ver historial mediante `/me`
- ✅ Sistema de referidos
- ✅ Canje de 7 días
- ✅ Selección de idioma
- ✅ Comandos traducidos según el idioma seleccionado

### 👨‍💼 Para Super Admin
- ✅ Ver todas las cuentas creadas por los usuarios
- ✅ Ver propietarios de las cuentas
- ✅ Ver conexiones activas e IP de las sesiones SSH
- ✅ Ver cantidad total de conexiones
- ✅ Lista global de cuentas
- ✅ Las contraseñas se muestran como `xxx` y nunca se exponen en la lista
- ✅ Administrar administradores
- ✅ Banear y desbanear usuarios
- ✅ Gestionar cuotas
- ✅ Gestionar Monetag
- ✅ Backups y restauración
- ✅ Herramientas y protocolos
- ✅ Actualización del sistema
- ✅ Seguridad y control de acceso

---

## 🟢 Online — Nueva vista

El botón **Online** ya no muestra una lista confusa de nombres y propietarios.

Ahora funciona por cuenta:

```text
🟢 CUENTAS ONLINE

👥 Todas las cuentas
📡 Conectados: 3

🟢 Kevin — 1
   🌐 181.xxx.xxx.xxx

🟢 caca — 2
   🌐 190.xxx.xxx.xxx, 200.xxx.xxx.xxx

⚪ pepe — 0
```

- `1`, `2`, `3`... = cantidad de conexiones activas de esa cuenta.
- La IP mostrada corresponde a la conexión SSH detectada.
- El usuario normal solo puede consultar sus propias cuentas.
- El Super Admin puede consultar todas las cuentas y sus conexiones.

> Nota: una sesión puede aparecer sin IP cuando el sistema no entrega el origen de la conexión. La detección utiliza las conexiones SSH reales del VPS.

---

## 💰 Publicidad / Ads

La publicidad está integrada como una puerta de acceso antes de determinadas operaciones.

### Cantidad de anuncios

| Acción | Ads |
|---|:---:|
| 👤 Crear cuenta normal | **3** |
| 🚀 Crear cuenta V2Ray | **2** |
| 🎁 Canjear 7 días | **1** |
| ♻️ Renovar cuenta | **5** |
| ⏳ Aviso de vencimiento → renovar | **7** |

### 🔄 Rotación de publicidad
Cada paso genera un enlace/token nuevo de publicidad. Al completar un anuncio, el bot presenta automáticamente el siguiente hasta terminar la cantidad requerida.

El Super Admin y administradores autorizados no quedan bloqueados por la publicidad.

### ⏳ Avisos de vencimiento
Cuando una cuenta está próxima a vencer, el bot envía un aviso con un botón para renovar.

Ese botón utiliza el flujo especial de **7 anuncios** y, al completar todos los pasos, la cuenta se renueva automáticamente usando la cuota configurada.

---

## 📅 Renovaciones y cuotas

Los usuarios públicos **no tienen que escribir los días ni el límite de dispositivos**.

La renovación y creación utilizan automáticamente la cuota configurada por el Super Admin.

Esto evita errores como:
- escribir días incorrectos;
- superar el límite permitido;
- pedir datos técnicos innecesarios al usuario.

El Super Admin puede controlar las cuotas desde **Ajustes → Cuotas**.

---

## 🌎 Idiomas

El bot incluye:

- 🇪🇸 Español
- 🇺🇸 English
- 🇧🇷 Português
- 🇫🇷 Français
- 🇩🇪 Deutsch
- 🇮🇹 Italiano
- 🇷🇺 Русский
- 🇹🇷 Türkçe
- 🇨🇳 中文
- 🇯🇵 日本語
- 🇰🇷 한국어
- 🇮🇩 Bahasa Indonesia
- 🇸🇦 العربية

El comando `/me` también utiliza el idioma seleccionado para sus títulos y campos.

---

## 📚 Comandos principales

```text
/crear
/renovar
/lista
/online
/cuenta
/eliminar
/referidos
/idioma
/informacion
/me
/cmds
```

También existen alias traducidos para las funciones principales.

---

## 📥 Instalación

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/install.sh)
```

---

## ▶️ Acceder al Script

Después de instalar:

```bash
menu
```

---

## 🔄 Actualizar

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/update.sh)
```

---

## 🔑 Generar Key

La Key de instalación se genera desde el bot oficial de Telegram:

**@multiscriptkeygen_bot**

---

## 📂 Estructura principal

```text
multi-script/
├── install.sh
├── update.sh
├── menu.sh
├── protocolos/
├── herramientas/
├── usuarios/
└── telegram/
    └── bot.py
```

---

## 👨‍💻 Autor

**Kevin Aldair Camacho**

Proyecto y personalización: **KevinTech Tutorials**

---

<p align="center">
Hecho con ❤️ por <b>KevinTech Tutorials</b>
</p>
