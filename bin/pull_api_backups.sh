#!/bin/bash
# Holt die naechtlichen DB-Dumps der Authority auf den lokalen Rechner.
#
# bin/pg_backup.sh legt sie auf derselben Platte ab wie die Datenbank und
# behaelt nur 3 Tagesstaende — das schuetzt nicht gegen Platten-/VM-Verlust.
# Dieses Skript ist der zweite Schritt: Kopie vom Host herunter, mit laengerer
# Aufbewahrung als auf dem Server.
#
# Quelle: api:/var/www/backups/daily/<stamp>/ (Host-Alias aus ~/.ssh/config)
# Ziel:   ~/Backups/carambus_api/daily/<stamp>/
# Aufbewahrung lokal: alle Staende KEEP_DAYS Tage, Sonntagsstaende KEEP_SUNDAY_DAYS Tage.
#
# Taeglich per launchd: ~/Library/LaunchAgents/de.carambus.pull-api-backups.plist

set -uo pipefail

HOST="${HOST:-api}"
SRC="${SRC:-/var/www/backups/daily/}"
DEST="${DEST:-$HOME/Backups/carambus_api/daily}"
KEEP_DAYS="${KEEP_DAYS:-30}"
KEEP_SUNDAY_DAYS="${KEEP_SUNDAY_DAYS:-180}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "$DEST" || { log "FEHLER: kann $DEST nicht anlegen"; exit 1; }

# Ohne --delete: was der Server wegrotiert, bleibt lokal liegen.
if ! rsync -a --partial -e "ssh -o BatchMode=yes -o ConnectTimeout=30" "$HOST:$SRC" "$DEST/"; then
  log "FEHLER: rsync von $HOST:$SRC fehlgeschlagen"
  exit 1
fi
log "Abgleich fertig: $(ls "$DEST" | wc -l | tr -d ' ') Staende in $DEST"

# Aufraeumen nach Datum im Verzeichnisnamen (YYYYMMDD_HHMMSS), nicht nach mtime.
now=$(date +%s)
for dir in "$DEST"/*; do
  name=$(basename "$dir")
  [[ "$name" =~ ^([0-9]{8})_[0-9]{6}$ ]] || continue
  day="${BASH_REMATCH[1]}"
  ts=$(date -j -f "%Y%m%d" "$day" +%s 2>/dev/null) || continue
  age=$(( (now - ts) / 86400 ))
  weekday=$(date -j -f "%Y%m%d" "$day" +%u)
  limit=$KEEP_DAYS
  [ "$weekday" = "7" ] && limit=$KEEP_SUNDAY_DAYS
  if [ "$age" -gt "$limit" ]; then
    rm -rf "$dir" && log "entfernt: $name (${age} Tage)"
  fi
done
