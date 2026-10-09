# KevinTech Web Panel 4.0

Panel web responsive para KevinTech Multi Script.

## Cambios principales
- Menú hamburguesa lateral a la izquierda, compatible con móvil, con submenús por rol.
- `/`, `/index` y `/index.html` llevan al inicio/login; rutas inexistentes muestran `404` y existe `web/404.html`.
- Registro sin campo visible de código de referido; el código llega oculto desde `?ref=`.
- Referidos: el nuevo usuario recibe 1 punto y el propietario del enlace recibe 2 puntos; el administrador también tiene enlace y contador propios.
- Enlaces de referido con dominio completo: `https://dominio.tld/register?ref=CODIGO`.
- Creación de cuentas SSH y V2Ray/VMess.
- Días y límite IP se toman de Configuración → Cuotas de creación; la creación pasa por publicidad si está activada y configurada.
- Visualización de cuenta con datos del VPS y configuración correspondiente.
- Protocolos filtrables: todos, activos e inactivos.
- Consola disponible únicamente para administrador.
- Perfil aparece solo en Configuración (sin duplicado en Inicio). Eliminar cuenta está disponible para el propietario y admin; renovar cuenta es solo para admin.
- Ajuste general para títulos/descripciones de secciones y textos de About.
- About con Sobre nosotros, privacidad, cookies y términos; el administrador puede editar.
- Diseño responsive para móvil y escritorio.

El formulario de creación no ofrece campo de propietario web ni permite editar días/límite; se aplican las cuotas configuradas.

## Instalación
Usa `installer.sh` para instalar/actualizar la web en el VPS.
