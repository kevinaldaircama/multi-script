#!/bin/bash
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 🗑 ELIMINAR USUARIO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp "Usuario a borrar: " USER

userdel -f "$USER" 2>/dev/null

sed -i "/$USER/d" /etc/kevintech/usuarios.db

echo "✅ Usuario eliminado"
sleep 2
