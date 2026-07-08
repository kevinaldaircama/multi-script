#!/bin/bash

BASE="/etc/kevintech"

while true; do

clear

RAM=$(free -h | awk '/Mem:/ {print $7}')
CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); print 100-a[length(a)]"%"}')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      =====>>►► 🪧 Kevin Tech 💥 Multi Script 🪧 ◄◄<<====="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 🔐 ADMINISTRADOR DE USUARIOS SSH | SSL | DROPBEAR 🔐"
echo " ▸ M LIBRE: $RAM   ▸ USO DE CPU: $CPU"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo " [01] ➮ AGREGAR USUARIO (HWID/NORMAL/TOKEN)"
echo " [02] ➮ BORRAR 1/TODOS LOS USUARIOS"
echo " [03] ➮ EDITAR / RENOVAR USUARIOS"
echo " [04] ➮ MOSTRAR USUARIOS REGISTRADOS"
echo " [05] ➮ MOSTRAR USUARIOS CONECTADOS"
echo " [06] ➮ ADD / REMOVE BANNER"
echo " [07] ➮ LOG DE CONSUMO"
echo " [08] ➮ BLOQUEAR / DESBLOQUEAR USUARIOS"
echo " [09] ➮ BACKUP USUARIOS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [0] ➮ REGRESAR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo
read -rp " ► Opción: " op

case "$op" in
1)
    bash "$BASE/usuarios/add.sh"
;;
2)
    bash "$BASE/usuarios/delete.sh"
;;
3)
    bash "$BASE/usuarios/edit.sh"
;;
4)
    bash "$BASE/usuarios/list.sh"
;;
5)
    bash "$BASE/usuarios/online.sh"
;;
6)
    bash "$BASE/usuarios/banner.sh"
;;
7)
    bash "$BASE/usuarios/log.sh"
;;
8)
    bash "$BASE/usuarios/block.sh"
;;
9)
    bash "$BASE/usuarios/backup.sh"
;;
0)
    exec bash "$BASE/menu.sh"
;;
*)
    echo "❌ Opción inválida."
    sleep 2
;;
esac

done
