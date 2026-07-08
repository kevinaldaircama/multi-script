#!/bin/bash

echo "📥 Actualizando KevinTech Multi Script..."

TMP="/tmp/kevintech_update"

rm -rf "$TMP"

git clone https://github.com/kevinaldaircama/multi-script.git "$TMP" || {
    echo "❌ Error al descargar la actualización."
    exit 1
}

cp -rf "$TMP"/. /etc/kevintech/

chmod -R +x /etc/kevintech

rm -rf "$TMP"

echo "✅ Actualización completada."

exec /etc/kevintech/menu.sh
