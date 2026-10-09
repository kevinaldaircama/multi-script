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


## Cambios v4.2
- Modo claro/oscuro global guardado en el navegador.
- Preferencia de idioma por usuario (español, inglés y portugués; traducción de navegación y etiquetas principales).
- Cuota configurable de cuentas por usuario (por defecto 2).
- Los usuarios necesitan 3 puntos por cuenta; se descuentan 3 puntos al crearla.
- Publicidad configurada para creación y eliminación de cuentas de usuarios; el administrador no ve anuncios y no tiene límite de cantidad de cuentas.


## v4.3
- Renovación de cuentas disponible en Inicio para admin; usuarios pueden renovar cuentas propias con los puntos configurados (4 por defecto) y el flujo de anuncios si está habilitado.
- Aviso modal de vencimiento 3 días antes.
- Sección de planes con edición de planes y registro de solicitudes/historial. PayPal queda como método seleccionado, pero requiere credenciales e integración de comercio para procesar pagos reales.
- Cambio de tema con un solo botón.

## Actualización web 4.7
- Alineación izquierda consistente en los títulos y textos de las secciones.
- Datos de pago manual organizados dentro del modal de solicitud de plan.
- Moneda local sincronizada entre Ajuste general y Configuración de planes (por defecto S/).
- Generador de payloads con formulario web propio; ya no intenta ejecutar el script interactivo de terminal.
- Detalles VPS y Speedtest con pantallas web; las herramientas de terminal restantes no se ejecutan automáticamente desde una visita web.
