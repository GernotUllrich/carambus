#!/usr/bin/env bash
# Startet einen statischen Webserver für die Turnier-SPA (ES-Module brauchen http://).
# Nutzung:  ./serve.sh [PORT]   (Default 8123)
set -euo pipefail
PORT="${1:-8123}"
cd "$(dirname "$0")"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo localhost)"
echo "Turnier-SPA wird ausgeliefert auf:"
echo "  → http://localhost:${PORT}/"
echo "  → http://${IP}:${PORT}/   (im LAN, z. B. für Tablets)"
echo "Beenden mit Strg-C."
exec python3 -m http.server "${PORT}" --bind 0.0.0.0
