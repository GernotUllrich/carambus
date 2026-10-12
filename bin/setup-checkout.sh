#!/bin/bash
#
# Richtet einen frisch geklonten Carambus-Checkout so ein, dass die Testsuite laeuft.
#
# HINTERGRUND (2026-09-04): Vier Konfigurationsdateien sind gitignored und werden von
# keinem Setup erzeugt. Fehlen sie, ist die Suite rot — mit Fehlerbildern, die nach
# Logikfehlern aussehen und es nicht sind:
#
#   config/credentials/        fehlt   -> 6 Errors "Missing Active Record encryption
#                                         credential: active_record_encryption.primary_key"
#   config/carambus.yml        fehlt   -> 10 Failures (jwt_expiration_days nil,
#                                         quick_game_presets fehlen)
#   config/cable.yml           fehlt   -> JEDER Test bricht ab mit
#                                         "undefined method 'fetch' for nil" in
#                                         ActionCable::Server::Configuration#pubsub_adapter
#   config/database.yml        fehlt   -> kein DB-Zugriff
#
# Das Skript ist idempotent: vorhandene Dateien bleiben unangetastet (ausser mit --force).
# Es fasst NICHTS an, was im Repo getrackt ist.
#
# Verwendung:
#   bin/setup-checkout.sh            # fehlende Dateien anlegen
#   bin/setup-checkout.sh --force    # vorhandene ueberschreiben (fragt vorher)
#   bin/setup-checkout.sh --check    # nur pruefen, nichts schreiben
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CHECKOUT="$(basename "$ROOT")"

FORCE=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unbekannte Option: $arg (--force, --check, --help)"; exit 1 ;;
  esac
done

if [ ! -f Gemfile ] || [ ! -f config/carambus.yml.erb ]; then
  echo "FEHLER: bitte aus einem Carambus-Checkout heraus aufrufen." >&2
  exit 1
fi

created=0
skipped=0
missing=0

note()  { printf '  %s\n' "$1"; }
have()  { skipped=$((skipped + 1)); note "vorhanden   $1"; }
made()  { created=$((created + 1)); note "angelegt    $1"; }
lacks() { missing=$((missing + 1)); note "FEHLT       $1"; }

# Entscheidet, ob eine Datei geschrieben werden soll. Rueckgabe 0 = schreiben.
should_write() {
  local target="$1"
  if [ ! -e "$target" ]; then return 0; fi
  if [ "$CHECK_ONLY" = "1" ]; then have "$target"; return 1; fi
  if [ "$FORCE" = "1" ]; then
    read -r -p "  $target existiert — ueberschreiben? [j/N] " answer
    case "$answer" in [jJyY]) return 0 ;; *) have "$target"; return 1 ;; esac
  fi
  have "$target"
  return 1
}

echo "Carambus-Checkout einrichten: $CHECKOUT"
[ "$CHECK_ONLY" = "1" ] && echo "(--check: es wird nichts geschrieben)"
echo

# ---------------------------------------------------------------------------
# 1. Credentials — koennen NICHT erzeugt werden, nur aus einem Schwester-Checkout
#    uebernommen werden. Ohne den passenden Key sind die .enc-Dateien wertlos.
# ---------------------------------------------------------------------------
echo "Credentials (config/credentials/)"
if [ -f config/credentials/test.key ] && [ -f config/credentials/test.yml.enc ]; then
  have "config/credentials/test.{key,yml.enc}"
elif [ "$CHECK_ONLY" = "1" ]; then
  lacks "config/credentials/test.{key,yml.enc}"
else
  donor=""
  for candidate in "$ROOT"/../carambus_*; do
    [ "$candidate" = "$ROOT" ] && continue
    if [ -f "$candidate/config/credentials/test.key" ]; then donor="$candidate"; break; fi
  done
  if [ -n "$donor" ]; then
    mkdir -p config/credentials
    for f in test.key test.yml.enc development.key development.yml.enc; do
      [ -f "$donor/config/credentials/$f" ] || continue
      cp "$donor/config/credentials/$f" "config/credentials/$f"
      case "$f" in *.key) chmod 600 "config/credentials/$f" ;; esac
    done
    made "config/credentials/ (aus $(basename "$donor"))"
  else
    lacks "config/credentials/ — kein Schwester-Checkout mit test.key gefunden"
    note "            von einem eingerichteten Rechner kopieren; ohne den Key"
    note "            laesst sich die .enc-Datei nicht entschluesseln."
  fi
fi
echo

# ---------------------------------------------------------------------------
# 2. carambus.yml — aus dem repo-eigenen Template rendern.
#
#    Der test-Block ist NICHT kosmetisch. Beide Keys stellen Annahmen her, auf denen
#    die Suite beruht (ermittelt 2026-09-04 beim Gruenziehen):
#
#    carambus_api_url leer -> `local_server?` ist false (application_record.rb:76), die
#                             Testinstanz laeuft als AUTHORITY. Gesetzt waere sie ein
#                             Region-/Location-Server; TournamentMonitorT06,
#                             Api::GameResultsController und die RegionServer-Importer
#                             erwarten die Authority-Rolle.
#    location_id 0         -> unter local_server? die Region-Server-Rolle. Tests, die
#                             local_server? selbst einschalten (Tournaments::
#                             RankingsControllerTest), brauchen das.
#    context NICHT gesetzt -> die MCP-Tools- und Admin-Picker-Tests pruefen ausdruecklich
#                             das Verhalten OHNE Region-Kontext. Mit `nbv` schlagen 16 fehl.
# ---------------------------------------------------------------------------
echo "Anwendungs-Konfiguration (config/carambus.yml)"
if should_write config/carambus.yml; then
  if [ "$CHECK_ONLY" = "1" ]; then
    lacks "config/carambus.yml"
  else
    ruby -e '
      # encoding explizit: das Template enthaelt Umlaute, und ohne UTF-8 liest Ruby es je
      # nach Locale als US-ASCII und bricht in gsub mit "invalid byte sequence" ab.
      src = File.read("config/carambus.yml.erb", encoding: "UTF-8")
      {
        "application_name" => "carambus",
        "basename"         => "carambus",
        "carambus_api_url" => "https://api.carambus.de",
        "carambus_domain"  => "localhost:3000",
        "club_id"          => "357",
        "context"          => "nbv",
        "location_id"      => "1",
        "season_name"      => "2025/2026"
      }.each { |k, v| src = src.gsub(/<%=\s*#{k}\s*%>/, v) }
      abort("unaufgeloeste Template-Variablen: #{src.scan(/<%=.*?%>/).uniq}") if src =~ /<%=/
      src = src.rstrip + <<~TEST

        # Von bin/setup-checkout.sh erzeugt. Begruendung der beiden Keys steht dort.
        test:
          carambus_api_url:
          location_id: 0
      TEST
      File.write("config/carambus.yml", src, encoding: "UTF-8")
    '
    made "config/carambus.yml (aus config/carambus.yml.erb + test-Block)"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 3. cable.yml — ohne sie bricht JEDER Test ab. `test: adapter: test` ist der Kern;
#    derselbe fehlende Eintrag legte am 2026-09-02 auch die Scoreboards im Verein lahm,
#    weil die Datei dort als Capistrano-linked_file aus shared/ kommt.
# ---------------------------------------------------------------------------
echo "Action Cable (config/cable.yml)"
if should_write config/cable.yml; then
  if [ "$CHECK_ONLY" = "1" ]; then
    lacks "config/cable.yml"
  else
    cat > config/cable.yml <<CABLE
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>
  channel_prefix: ${CHECKOUT}_production
CABLE
    made "config/cable.yml"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 4. database.yml — aus dem Template, Datenbanknamen nach dem Checkout benannt.
#    Die Datenbanken selbst legt das Skript NICHT an: ein Checkout haengt sich oft
#    bewusst an eine bestehende DB (in carambus_bcw ist die Entwicklungs-DB eine
#    Produktionskopie). Das bleibt eine bewusste Entscheidung.
# ---------------------------------------------------------------------------
echo "Datenbank (config/database.yml)"
if should_write config/database.yml; then
  if [ "$CHECK_ONLY" = "1" ]; then
    lacks "config/database.yml"
  else
    ruby -e '
      checkout = ARGV[0]
      src = File.read("config/database.yml.erb", encoding: "UTF-8")
      src = src.gsub(/carambus_api_(development|test|production)/) { "#{checkout}_#{$1}" }
      File.write("config/database.yml", src, encoding: "UTF-8")
    ' "$CHECKOUT"
    made "config/database.yml (Datenbanken: ${CHECKOUT}_{development,test,production})"
    note "            Datenbanken anlegen: bin/rails db:create db:schema:load"
  fi
fi
echo

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------
echo "────────────────────────────────────────"
if [ "$CHECK_ONLY" = "1" ]; then
  if [ "$missing" -gt 0 ]; then
    echo "$missing Datei(en) fehlen — ohne --check anlegen lassen."
    exit 1
  fi
  echo "Alle Konfigurationsdateien vorhanden."
  exit 0
fi

echo "$created angelegt, $skipped bereits vorhanden."
if [ "$missing" -gt 0 ]; then
  echo "$missing konnten nicht erzeugt werden (siehe oben)."
fi
echo
echo "Naechste Schritte:"
echo "  bundle install && yarn install"
echo "  bin/rails db:create db:schema:load   # nur bei frischer Datenbank"
echo "  bin/rails test                       # muss gruen sein (0 failures, 0 errors)"
[ "$missing" -gt 0 ] && exit 1
exit 0
