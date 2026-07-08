#!/bin/bash
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 📝 AGREGAR USUARIO SSH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp "Usuario: " USER
read -rp "Días de duración: " DAYS

useradd -M -s /bin/false "$USER"

EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

echo "$USER:$EXP" >> /etc/kevintech/usuarios.db

echo ""
echo "✅ Usuario creado: $USER"
echo "📅 Vence: $EXP"

sleep 2
