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
Con al menos 3 referidos válidos, el usuario puede usar el botón **Cangear 7 días**. Debe indicar una de sus cuentas, confirmar los datos y, si la publicidad está configurada, completar el anuncio antes de recibir los **7 días**. Los administradores y el super admin no ven anuncios.

Si el referido tiene `@username`, se muestra ese usuario. Si no tiene username, se muestra su nombre de Telegram en lugar de su ID.

## 🆕 v13.3

- 🛠️ Corregida la consulta/eliminación de cuentas V2Ray que aparecían en la lista pero eran rechazadas como "Cuenta no encontrada".
- 💰 Monetag ya no solicita subir `monetization.html`: el bot lo genera automáticamente y lo envía después de completar la configuración.
- 🔄 La actualización informa explícitamente que terminó y muestra la versión instalada antes de reiniciar el servicio.


## v13.5 — Monetag Mini App

- El botón **Ver anuncio y continuar** abre `monetization.html` como **Telegram Mini App** mediante `web_app`.
- El token de publicidad viaja con la Mini App y se conserva al volver al bot, evitando el mensaje de enlace expirado por pérdida del token.
- `monetization.html` se envía una sola vez durante la configuración. Después de guardar la URL pública, el bot no vuelve a enviar el archivo.

## Monetización / Mini App

- La configuración de Monetag genera `telegram/monetization.html` automáticamente.
- El archivo se envía una sola vez al super admin durante la configuración.
- Después se solicita la URL pública donde quedó alojado el HTML.
- Cada vez que un usuario pulse **Ver anuncio**, el bot genera un token nuevo y abre la URL mediante un botón `web_app` de Telegram. Esto evita reutilizar enlaces de publicidad antiguos.
- El token dura 15 minutos y se consume una sola vez al completar el retorno al bot.
- Los mensajes/documentos temporales del asistente de configuración se eliminan después de 10 minutos.
- Los mensajes enviados por el bot se conservan como máximo 24 horas, manteniendo el último mensaje del bot en el chat.

> Telegram no permite que un bot borre arbitrariamente los mensajes enviados por el usuario en un chat privado. La limpieza automática se aplica a los mensajes enviados por el bot.

## Actualizaciones

Si una Key de actualización ya fue utilizada, el bot muestra **KEY YA UTILIZADA** en lugar de dejar únicamente el mensaje de operación iniciada.
