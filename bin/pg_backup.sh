#!/bin/bash
# Carambus PostgreSQL Backup
# Naechtlicher Dump aller Produktions-Datenbanken des Clusters.
#
# Bewusst ohne Rails: laeuft rein ueber pg_dump, damit ein Backup auch dann
# entsteht, wenn die Anwendung nicht bootet.
#
# Auswahl: alle Datenbanken mit Endung "_production". Das trifft genau die
# echten Instanz-DBs und laesst Altkopien wie "carambus_api_production_backup"
# oder "carambus_api_production_20260505_1048" aussen vor. Neue Szenarien
# werden automatisch mitgesichert.
#
# ⚠️ Dieses Skript legt die Dumps auf DERSELBEN Platte ab wie die Datenbank.
# Das schuetzt gegen versehentliches Loeschen und fehlerhafte Migrationen,
# NICHT gegen Platten-/VM-Verlust. Die Kopie vom Host herunter ist der
# zweite, unverzichtbare Schritt (siehe KEEP_DAILY/README).

set -uo pipefail
# Absichtlich kein "set -e": schlaegt eine Datenbank fehl, sollen die uebrigen
# trotzdem gesichert werden. Fehler werden gezaehlt und am Ende quittiert.

BACKUP_DIR="${BACKUP_DIR:-/var/www/backups}"
KEEP_DAILY="${KEEP_DAILY:-3}"          # bewusst knapp: Platte ist eng
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"        # Sonntagslaeufe, als Hardlink (kostet nichts extra)
MIN_FREE_MB="${MIN_FREE_MB:-3000}"     # darunter wird gar nicht erst gedumpt
MIN_DUMP_BYTES="${MIN_DUMP_BYTES:-10000}"

log()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
fail() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] BACKUP-FEHLER: $*" >&2; }

stamp="$(date +'%Y%m%d_%H%M%S')"
run_dir="$BACKUP_DIR/daily/$stamp"

# --- Platten-Wache -----------------------------------------------------------
# Ohne diese Pruefung fuellt das Backup im Fehlerfall die Platte und legt alle
# Instanzen auf derselben Maschine lahm. Lieber kein Backup als ein volles /.
mkdir -p "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" || { fail "kann $BACKUP_DIR nicht anlegen"; exit 1; }
free_mb="$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')"
if [ "${free_mb:-0}" -lt "$MIN_FREE_MB" ]; then
  fail "nur ${free_mb} MB frei (Minimum ${MIN_FREE_MB} MB) — Lauf abgebrochen, nichts gedumpt"
  exit 1
fi
log "Start — ${free_mb} MB frei, Ziel $run_dir"

databases="$(sudo -n -u postgres psql -tAc \
  "SELECT datname FROM pg_database WHERE datname LIKE '%\\_production' AND NOT datistemplate ORDER BY datname;")"
if [ -z "$databases" ]; then
  fail "keine Datenbank gefunden (psql-Zugriff pruefen) — Lauf abgebrochen"
  exit 1
fi

mkdir -p "$run_dir" || { fail "kann $run_dir nicht anlegen"; exit 1; }
errors=0

for db in $databases; do
  target="$run_dir/$db.dump"

  # -Fc: komprimiertes Custom-Format, erlaubt selektives Restore einzelner Tabellen.
  # Dump laeuft als postgres, die Datei entsteht durch die Umlenkung als www-data.
  if ! sudo -n -u postgres pg_dump -Fc --no-owner --no-privileges "$db" > "$target"; then
    fail "$db: pg_dump fehlgeschlagen"
    rm -f "$target"
    errors=$((errors + 1))
    continue
  fi

  # Verifikation statt Vertrauen: der 0-Byte-Dump vom 2026-07-15 lag einen Monat
  # unbemerkt herum. Groessen-Untergrenze faengt den leeren Fall, pg_restore -l
  # liest das Inhaltsverzeichnis und faengt zusaetzlich abgeschnittene Archive.
  size="$(stat -c %s "$target" 2>/dev/null || echo 0)"
  if [ "$size" -lt "$MIN_DUMP_BYTES" ]; then
    fail "$db: Dump nur ${size} Byte — verworfen"
    rm -f "$target"
    errors=$((errors + 1))
    continue
  fi
  if ! sudo -n -u postgres pg_restore -l "$target" > /dev/null 2>&1; then
    fail "$db: Archiv nicht lesbar (pg_restore -l) — verworfen"
    rm -f "$target"
    errors=$((errors + 1))
    continue
  fi

  log "$db: $(numfmt --to=iec "$size" 2>/dev/null || echo "$size B") ok"
done

# --- Wochenkopie -------------------------------------------------------------
# Hardlinks statt Kopien: gleiche Datei, zweiter Name. Der Sonntagsstand
# ueberlebt damit die Tages-Rotation, ohne den Platz ein zweites Mal zu belegen.
if [ "$(date +%u)" = "7" ] && [ "$errors" -eq 0 ]; then
  if cp -al "$run_dir" "$BACKUP_DIR/weekly/$stamp" 2>/dev/null; then
    log "Wochenkopie angelegt: weekly/$stamp"
  else
    fail "Wochenkopie fehlgeschlagen (Hardlink ueber Dateisystemgrenze?)"
  fi
fi

# --- Rotation ----------------------------------------------------------------
# Nach Anzahl, nicht nach Alter: bleibt vorhersagbar, auch wenn Laeufe ausfallen.
prune() {
  local dir="$1" keep="$2"
  ls -1t "$dir" 2>/dev/null | tail -n "+$((keep + 1))" | while read -r old; do
    rm -rf "${dir:?}/$old" && log "rotiert: $(basename "$dir")/$old"
  done
}
prune "$BACKUP_DIR/daily" "$KEEP_DAILY"
prune "$BACKUP_DIR/weekly" "$KEEP_WEEKLY"

total="$(du -sh "$run_dir" 2>/dev/null | cut -f1)"
if [ "$errors" -gt 0 ]; then
  fail "Lauf beendet mit $errors fehlgeschlagenen Datenbanken — $run_dir ($total)"
  exit 1
fi
log "Fertig — $run_dir ($total), $(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}') MB frei"
