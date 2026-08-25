#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-status}" in
 start) systemctl start kevintech-telegram;; stop) systemctl stop kevintech-telegram;; restart) systemctl restart kevintech-telegram;; status) systemctl --no-pager --full status kevintech-telegram;; logs) journalctl -u kevintech-telegram -f;; *) echo 'Uso: service.sh {start|stop|restart|status|logs}'; exit 1;; esac
