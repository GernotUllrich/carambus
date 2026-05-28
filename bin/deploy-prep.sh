#!/bin/bash
# Plan 21-10: Re-Generate production config files for a scenario + copy stage file.
#
# Was es macht (genau 2 Schritte):
#   1. bundle exec rake "scenario:generate_configs[<scenario>,production]"
#   2. cp .../carambus_data/scenarios/<s>/production/deploy/production.rb
#         .../<s>/config/deploy/production.rb
#
# Rest macht der User danach im Scenario-Repo:
#   git pull && yarn build && yarn build:css && rails assets:precompile && \
#     rails db:migrate && cap production deploy
#
# Usage: bin/deploy-prep.sh <scenario_name>
# Example: bin/deploy-prep.sh carambus_bcw

set -e

SCENARIO="$1"

if [ -z "$SCENARIO" ]; then
  echo "Usage: $0 <scenario_name>"
  echo "Example: $0 carambus_bcw"
  echo ""
  echo "Available scenarios:"
  ls -1 "$(dirname "$0")/../../carambus_data/scenarios/" 2>/dev/null | grep "^carambus" | sed 's/^/  /'
  exit 1
fi

# Pfade auflösen: bin/deploy-prep.sh lebt in carambus_master/bin/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_DIR="$(cd "$MASTER_DIR/.." && pwd)"

DATA_DIR="$BASE_DIR/carambus_data"
SCENARIO_DIR="$DATA_DIR/scenarios/$SCENARIO"
TARGET_DIR="$BASE_DIR/$SCENARIO"

# Validierungen
if [ ! -d "$SCENARIO_DIR" ]; then
  echo "❌ Scenario-Config nicht gefunden: $SCENARIO_DIR"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Scenario-Repo nicht gefunden: $TARGET_DIR"
  echo "   (erwartet als Geschwister von carambus_master)"
  exit 1
fi

if [ ! -d "$TARGET_DIR/config/deploy" ]; then
  echo "❌ Ziel-Verzeichnis nicht gefunden: $TARGET_DIR/config/deploy"
  exit 1
fi

# Schritt 1: Re-Generate production configs (im carambus_master)
echo "📋 Step 1: Re-Generate production configs für $SCENARIO …"
cd "$MASTER_DIR"
bundle exec rake "scenario:generate_configs[$SCENARIO,production]"

# Schritt 2: Stage-File ins Scenario-Repo kopieren
SRC="$SCENARIO_DIR/production/deploy/production.rb"
DST="$TARGET_DIR/config/deploy/production.rb"

if [ ! -f "$SRC" ]; then
  echo "❌ Generated stage-file nicht gefunden: $SRC"
  echo "   (rake generate_configs hätte production/deploy/production.rb produzieren müssen)"
  exit 1
fi

echo ""
echo "📁 Step 2: Copy $SRC → $DST"
cp "$SRC" "$DST"

# Sanity-Check (NICHT Rails-config, sondern Capistrano-Stage-Syntax)
echo ""
echo "✅ Sanity-check des kopierten Stage-Files (sollte Capistrano-Syntax sein, NICHT Rails-config):"
if head -1 "$DST" | grep -q "Rails.application"; then
  echo "❌ FAIL: Datei beginnt mit Rails.application — falsche Quelle kopiert!"
  exit 1
fi
# Echte Werte zeigen (uncommented lines): server-Definition + set :basename + set :whenever_roles
grep -E "^server |^set :basename|^set :whenever_roles" "$DST" | sed 's/^/  /'

echo ""
echo "─────────────────────────────────────────────────────────"
echo "✅ Done — production.rb ist im Scenario-Repo aktualisiert."
echo ""
echo "Weiter im Scenario-Repo:"
echo "  cd $TARGET_DIR && git pull && yarn build && yarn build:css && \\"
echo "    rails assets:precompile && rails db:migrate && cap production deploy"
echo "─────────────────────────────────────────────────────────"
