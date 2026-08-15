#!/bin/bash
# Einmal-Reparatur (2026-07-22): stellt das Passwort der GETEILTEN PostgreSQL-Rolle www_data
# aus carambus_data/secrets.yml (shared.database_password) wieder her.
#
# HINTERGRUND: `scenario:reset_server_db` erzwingt bedingungslos
#   ALTER ROLE www_data WITH PASSWORD '<database_password aus config.yml>';
# Dieses Feld ist seit der Secret-Bereinigung in allen config.yml LEER — der Wert lebt in
# secrets.yml. Ein Lauf fuer carambus_tbv hat damit das Passwort der geteilten Rolle auf ""
# gesetzt und alle Instanzen (api, nbv, train, carambus) gleichzeitig ausgesperrt.
#
# Das Passwort wird NICHT ausgegeben und geht ueber stdin an psql — es steht damit weder im
# Terminal noch in der Prozessliste des Servers.
#
# Usage:  bin/restore-www-data-password.sh
#         SSH_HOST=... SSH_PORT=... SECRETS=... bin/restore-www-data-password.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_HOST="${SSH_HOST:-carambus.de}"
SSH_PORT="${SSH_PORT:-8910}"
SECRETS="${SECRETS:-$HOME/DEV/carambus/carambus_data/secrets.yml}"
ROLE="${ROLE:-www_data}"

echo "Rolle:   $ROLE"
echo "Server:  $SSH_HOST:$SSH_PORT"
echo "Quelle:  $SECRETS (shared.database_password)"
echo

ruby "$SCRIPT_DIR/lib/build_role_password_sql.rb" "$SECRETS" "$ROLE" \
  | ssh -p "$SSH_PORT" "www-data@$SSH_HOST" "sudo -u postgres psql -f -"

echo
echo "Gegenprobe:"
echo "  ssh -p $SSH_PORT www-data@$SSH_HOST \"cd carambus_api/current && RAILS_ENV=production bundle exec rails runner 'puts Tournament.count'\""
echo
echo "Falls eine Instanz weiter zickt (offene Verbindungen merken die Aenderung nicht):"
echo "  sudo systemctl restart puma-carambus_api"
