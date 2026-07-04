#!/bin/bash

BASE="/etc/kevintech"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      CAMBIAR CONTRASEÑA ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar que sea root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Debes ejecutar el script como usuario root."
    echo ""
    echo "Ejecuta:"
    echo "sudo -i"
    echo ""
    read -n1 -r -p "Presiona una tecla para regresar..."
    exec bash "$BASE/protocolos/menu.sh"
fi

read -rsp "🔑 Nueva contraseña: " PASS1
echo
read -rsp "🔑 Confirmar contraseña: " PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo ""
    echo "❌ Las contraseñas no coinciden."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
fi

echo "root:$PASS1" | chpasswd

if [[ $? -eq 0 ]]; then
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   ✅ CONTRASEÑA CAMBIADA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Usuario      : root"
    echo "Contraseña   : $PASS1"
    echo ""
else
    echo ""
    echo "❌ No se pudo cambiar la contraseña."
fi

echo ""
read -n1 -r -p "Presiona una tecla para regresar..."

exec bash "$BASE/protocolos/menu.sh"
