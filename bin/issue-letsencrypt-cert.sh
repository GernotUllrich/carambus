#!/bin/bash
# Stellt ein Let's-Encrypt-Zertifikat fuer eine NEUE Szenario-Domain aus.
#
# PROBLEM, das dieses Skript loest (Henne-Ei):
# Die generierte nginx-Config eines Szenarios referenziert das Zertifikat, BEVOR es existiert.
#   - `nginx -t` schlaegt fehl  => kein Reload moeglich; ein nginx-Neustart wuerde ALLE Sites
#     mitreissen, weil die kaputte Config aktiviert ist.
#   - Port 80 macht nur `return 301 https://...`, die acme-challenge-Location sitzt im
#     443-Block => weder `certbot --nginx` noch `certbot --webroot` kommen durch.
#
# ABLAUF (ohne Ausfall der anderen Sites):
#   1. Ziel-Config deaktivieren  -> nginx wird wieder reload-faehig
#   2. temporaere HTTP-only-Config nur fuer die acme-challenge aktivieren
#   3. certbot certonly --webroot
#   4. echte Config zurueck, Test, Reload
#
# Usage:  bin/issue-letsencrypt-cert.sh carambus_tbv tbv.carambus.de
set -e

BASENAME="${1:?Usage: $0 <basename> <domain>   z.B. carambus_tbv tbv.carambus.de}"
DOMAIN="${2:?Usage: $0 <basename> <domain>   z.B. carambus_tbv tbv.carambus.de}"
SSH_HOST="${SSH_HOST:-carambus.de}"
SSH_PORT="${SSH_PORT:-8910}"
EMAIL="${EMAIL:-gernot.ullrich@gmx.de}"

# Neutrales Webroot, NICHT /var/www/<basename>/current/public:
# Bei einem noch nie deployten Szenario existiert `current` nicht — ein `mkdir -p` darauf
# wuerde ein echtes Verzeichnis anlegen, wo Capistrano spaeter einen Symlink erwartet, und
# den ersten Deploy zum Scheitern bringen. Ausserdem ueberlebt dieses Webroot Releasewechsel,
# was Renewals unabhaengig vom Deploy-Stand macht.
WEBROOT="${WEBROOT:-/var/www/letsencrypt}"

echo "Domain:   $DOMAIN"
echo "Basename: $BASENAME"
echo "Webroot:  $WEBROOT"
echo "Server:   $SSH_HOST:$SSH_PORT"
echo

ssh -p "$SSH_PORT" "www-data@$SSH_HOST" "sudo bash -s" <<REMOTE
set -e

echo "1/5 Ziel-Config deaktivieren (macht nginx wieder reload-faehig)..."
if [ -e /etc/nginx/sites-enabled/$BASENAME ]; then
  mv /etc/nginx/sites-enabled/$BASENAME /tmp/nginx-$BASENAME.disabled
  echo "    verschoben nach /tmp/nginx-$BASENAME.disabled"
else
  echo "    war nicht aktiviert"
fi

if ! nginx -t 2>/dev/null; then
  echo "❌ nginx -t ist AUCH OHNE die Ziel-Config rot — hier stimmt noch etwas anderes nicht."
  nginx -t || true
  # Zustand wiederherstellen, damit nichts halb Deaktiviertes zurueckbleibt
  [ -e /tmp/nginx-$BASENAME.disabled ] && mv /tmp/nginx-$BASENAME.disabled /etc/nginx/sites-enabled/$BASENAME
  exit 1
fi
echo "    ✅ nginx -t OK"

echo "2/5 Temporaere HTTP-only-Config fuer die acme-challenge..."
mkdir -p "$WEBROOT/.well-known/acme-challenge"
chown -R www-data:www-data "$WEBROOT/.well-known" 2>/dev/null || true
cat > /etc/nginx/sites-enabled/${BASENAME}_acme <<CONF
server {
    listen 80;
    server_name $DOMAIN;
    location ^~ /.well-known/acme-challenge/ {
        root $WEBROOT;
        default_type "text/plain";
        try_files \\\$uri =404;
    }
    location / { return 404; }
}
CONF
nginx -t
systemctl reload nginx
echo "    ✅ temporaere Config aktiv"

echo "3/5 Zertifikat anfordern..."
certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" \
  --non-interactive --agree-tos --email "$EMAIL" || CERT_FAILED=1

echo "4/5 Temporaere Config entfernen, echte Config zurueck..."
rm -f /etc/nginx/sites-enabled/${BASENAME}_acme
if [ -e /tmp/nginx-$BASENAME.disabled ]; then
  mv /tmp/nginx-$BASENAME.disabled /etc/nginx/sites-enabled/$BASENAME
fi

echo "5/5 Config testen und neu laden..."
if nginx -t; then
  systemctl reload nginx
  echo "    ✅ nginx neu geladen"
else
  echo "❌ nginx -t rot. Die Ziel-Config bleibt aktiviert, aber nginx wurde NICHT neu geladen."
  echo "   Der laufende nginx arbeitet weiter mit der alten Konfiguration."
  echo "   Zum Entschaerfen:  sudo rm /etc/nginx/sites-enabled/$BASENAME && sudo nginx -t"
  exit 1
fi

if [ -n "\$CERT_FAILED" ]; then
  echo "⚠️  certbot ist fehlgeschlagen — siehe Ausgabe oben und /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi
REMOTE

echo
echo "Gegenprobe:"
echo "  curl -sSI https://$DOMAIN | head -1"
