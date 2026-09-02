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
 
Compatible con todas las versiones de Ubuntu soportadas oficialmente.      
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
| SlowDNS | ✅ |          
          
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
          
# 🔑 Generar Key
 
Para generar una Key de instalación, hazlo directamente desde el bot oficial de Telegram:
 
**@multiscriptkeygen_bot**
---          
          
# 👨‍💻 Autor          
          
**Kevin Aldair Camacho**          
          
- redes sociales: Kevin tech tutorials          
          
---          
          
<p align="center">          
Hecho con ❤️ por <b>KevinTech Tutorials</b>          
</p>     


## 🆕 Cambios de esta versión

### 🌎 Idiomas
El bot incorpora 8 idiomas:
- 🇪🇸 Español
- 🇺🇸 English
- 🇧🇷 Português
- 🇫🇷 Français
- 🇩🇪 Deutsch
- 🇮🇹 Italiano
- 🇷🇺 Русский
- 🇹🇷 Türkçe

Al cambiar el idioma se traducen también los nombres de los botones y menús principales.

### 🔄 Actualización del sistema
El botón de actualización ahora informa claramente cuando el proceso termina:
**🟢 ¡ACTUALIZACIÓN COMPLETADA!**
**🎉 El sistema fue actualizado correctamente y los cambios quedaron aplicados.**

### 💰 Monetización / Monetag
El flujo de configuración solicita:
1. SDK.
2. Rewarded Interstitial.
3. URL del bot.
4. Archivo personalizado **`monetization.html`** enviado directamente al bot.
5. URL pública donde estará alojado el HTML.

El archivo recibido debe llamarse exactamente `monetization.html`. El bot valida que sea HTML, guarda esa plantilla y coloca dentro los datos configurados. El archivo generado que se entrega al administrador también se llama **`monetization.html`**.

Durante la configuración existe un botón **❌ Cancelar** para salir del proceso.

### 🔗 Referidos
Con al menos 3 referidos válidos, el usuario puede realizar hasta **3 renovaciones dentro de una ventana de 24 horas**. Al cumplirse las 24 horas, el contador de renovaciones vuelve a **0/3** y puede utilizar nuevamente sus 3 renovaciones.

Si el referido tiene `@username`, la notificación muestra ese usuario. Si no tiene username, se muestra su nombre de Telegram.
