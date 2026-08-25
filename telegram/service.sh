#!/usr/bin/env bash
set -e
case "${1:-status}" in
 start) systemctl start kevintech-telegram ;;
 stop) systemctl stop kevintech-telegram ;;
 restart) systemctl restart kevintech-telegram ;;
 status) systemctl status kevintech-telegram --no-pager ;;
 logs) journalctl -u kevintech-telegram -n 100 --no-pager ;;
 *) echo "Uso: $0 {start|stop|restart|status|logs}"; exit 1 ;;
esac
