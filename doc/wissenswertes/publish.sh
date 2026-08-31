#!/usr/bin/env bash
#
# Veroeffentlicht die Wissenswertes-Seiten auf einer oder mehreren Instanzen.
#
#   ./publish.sh bcw            # nur Wedel
#   ./publish.sh gu phat        # mehrere auf einmal
#
# Hintergrund: public/wissenswertes ist ein Capistrano-linked_dir. Der Inhalt liegt
# NICHT in git, sondern pro Server unter shared/public/wissenswertes/. Capistrano legt
# das Verzeichnis beim Deploy an und ruehrt den Inhalt danach nie wieder an — einmal
# hochgeladen bleibt er ueber alle weiteren Deploys hinweg stehen.
#
# ⚠️ Namensfalle: Der ssh-Alias "gu" zeigt auf die Maschine, auf der zurzeit die Instanz
# carambus_PHAT laeuft. Die Instanz carambus_gu liegt dagegen auf 192.168.178.29.
# Die erste Spalte unten ist die INSTANZ, nicht der ssh-Alias.
#
# Bewusst kein bash-4-Feature (assoziative Arrays): macOS liefert bash 3.2 aus.
set -euo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
SCOREBOARD="/locations/1?sb_state=welcome"

[ $# -gt 0 ] || { echo "Aufruf: $0 <instanz> [<instanz> ...]   (bcw | gu | phat)" >&2; exit 2; }

# --- Schritt 1: eigenstaendiges Dokument aus dem Fragment bauen -----------------------
#
# ⚠️ Warum der Wrapper: neu-im-august.html stammt aus einem Artifact. Die Plattform steuert
# <!doctype>/<head> selbst bei, das Fragment traegt deshalb kein <meta charset>. nginx sendet
# "Content-Type: text/html" OHNE charset (nirgends konfiguriert) — ohne die Angabe raet der
# Browser, landet bei Latin-1 und zerlegt die Umlaute.
#
# ⚠️ KEIN eigenes <head>/<body>: das Fragment enthaelt beides gemischt. HTML5 erlaubt das
# Weglassen der Tags — der Parser sortiert korrekt. Das <meta charset> muss nur innerhalb der
# ersten 1024 Bytes stehen, deshalb ganz vorn.
#
# ⚠️ Der Rueckweg zum Scoreboard wird NUR HIER eingefuegt, nicht ins Fragment: in der
# Artifact-Fassung auf claude.ai zeigte "/locations/1" ins Leere.
BAU="$(mktemp -t wissenswertes)"
trap 'rm -f "$BAU"' EXIT

RUECKWEG="  <a href=\"${SCOREBOARD}\" style=\"color:#E8B93A;border-color:#22493F\">&#8592; Scoreboard</a>"
{
  echo '<!doctype html>'
  echo '<html lang="de">'
  echo '<meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  # Rueckweg als erster Eintrag in die klebende Sprungleiste
  awk -v rw="$RUECKWEG" '{ print; if ($0 == "<nav>") print rw }' "$HIER/neu-im-august.html"
  echo '</html>'
} > "$BAU"

grep -q "sb_state=welcome" "$BAU" \
  || { echo "FEHLER: Rueckweg nicht eingefuegt — <nav> im Fragment nicht gefunden?" >&2; exit 1; }

# --- Schritt 2: auf die Instanzen verteilen -------------------------------------------
for INSTANZ in "$@"; do
  case "$INSTANZ" in
    bcw)  ZIEL="bc-wedel";                BASENAME="carambus_bcw";  PORT=""
          PRUEF="http://bc-wedel.duckdns.org:3131/wissenswertes/" ;;
    gu)   ZIEL="www-data@192.168.178.29"; BASENAME="carambus_gu";   PORT="8910"
          PRUEF="http://192.168.178.29:3131/wissenswertes/" ;;
    phat) ZIEL="gu";                      BASENAME="carambus_phat"; PORT=""
          PRUEF="http://192.168.178.84:3131/wissenswertes/" ;;
    *)    echo "Unbekannte Instanz: $INSTANZ  (bekannt: bcw gu phat)" >&2; exit 2 ;;
  esac

  VERZ="/var/www/$BASENAME/shared/public/wissenswertes"
  SSH_OPT=(); SCP_OPT=()
  [ -n "$PORT" ] && { SSH_OPT=(-p "$PORT"); SCP_OPT=(-P "$PORT"); }

  # Fehlt das Verzeichnis, wurde der linked_dir dort noch nie deployt (Commit 3ed8e41c).
  # Ohne diese Pruefung legt scp still eine DATEI mit dem Verzeichnisnamen an.
  ssh "${SSH_OPT[@]}" "$ZIEL" "test -d '$VERZ'" 2>/dev/null || {
    echo "FEHLER [$INSTANZ]: $VERZ fehlt — dort erst 'cap production deploy' laufen lassen." >&2
    exit 1
  }

  scp -q "${SCP_OPT[@]}" "$BAU"              "$ZIEL:$VERZ/neu-im-august.html"
  scp -q "${SCP_OPT[@]}" "$HIER/index.html"  "$ZIEL:$VERZ/index.html"
  echo "[$INSTANZ] abgelegt: /wissenswertes/ und /wissenswertes/neu-im-august.html"

  # --- Schritt 3: nachsehen, ob die Seite auch wirklich ausgeliefert wird ---
  #
  # ⚠️ Die Browser-Kennung ist PFLICHT, kein Zierrat: nginx wertet auf allen Instanzen
  # $carambus_deny aus (/etc/nginx/conf.d/carambus_bot_block.conf) und weist curls
  # Standardkennung mit "403 Forbidden" ab. Ohne -A sieht eine funktionierende Seite
  # aus wie eine kaputte.
  UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  CODE="$(curl -s -A "$UA" -o /dev/null -w "%{http_code}" --max-time 25 "$PRUEF" || echo "000")"
  if [ "$CODE" = "200" ]; then
    echo "[$INSTANZ] geprueft: $PRUEF liefert HTTP 200"
  else
    echo "[$INSTANZ] WARNUNG: $PRUEF liefert HTTP $CODE — Seite ist nicht erreichbar." >&2
  fi
done
