#!/bin/bash
# Database Synchronization Check (generalized)
# Usage: check_database_sync.sh <scenario_name>
# - Reads configuration from carambus_data/scenarios/<scenario>/config.yml and carambus_api/config.yml
# - Compares versions and key counts between local dev DBs and remote production DBs

set -euo pipefail

SCENARIO_NAME=${1:-}
if [ -z "$SCENARIO_NAME" ]; then
  echo "Usage: $0 <scenario_name>"
  echo "Example: $0 carambus_bcw"
  exit 1
fi

# Resolve carambus_data directory (allow override via env)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CARAMBUS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CARAMBUS_DATA_DIR_DEFAULT="$(cd "$CARAMBUS_ROOT/.." && pwd)/carambus_data"
CARAMBUS_DATA_DIR="${CARAMBUS_DATA_DIR:-$CARAMBUS_DATA_DIR_DEFAULT}"

if [ ! -d "$CARAMBUS_DATA_DIR" ]; then
  echo "❌ carambus_data not found at: $CARAMBUS_DATA_DIR"
  echo "   Set CARAMBUS_DATA_DIR=/path/to/carambus_data and retry."
  exit 1
fi

API_CONFIG="$CARAMBUS_DATA_DIR/scenarios/carambus_api/config.yml"
SCENARIO_CONFIG="$CARAMBUS_DATA_DIR/scenarios/$SCENARIO_NAME/config.yml"

if [ ! -f "$API_CONFIG" ]; then
  echo "❌ API config not found: $API_CONFIG"
  exit 1
fi
if [ ! -f "$SCENARIO_CONFIG" ]; then
  echo "❌ Scenario config not found: $SCENARIO_CONFIG"
  exit 1
fi

# Helper to read YAML at path a.b.c using Ruby (no external yq dependency)
get_yaml_value() {
  local file=$1
  local path=$2
  ruby -ryaml -e "puts YAML.load_file('$file').dig(*'$path'.split('.'))" 2>/dev/null
}

# Read API endpoints
API_SSH_HOST=$(get_yaml_value "$API_CONFIG" "environments.production.ssh_host")
API_SSH_PORT=$(get_yaml_value "$API_CONFIG" "environments.production.ssh_port")
[ -z "$API_SSH_PORT" ] && API_SSH_PORT=22

# Read scenario endpoints
SC_SSH_HOST=$(get_yaml_value "$SCENARIO_CONFIG" "environments.production.ssh_host")
SC_SSH_PORT=$(get_yaml_value "$SCENARIO_CONFIG" "environments.production.ssh_port")
SC_PROD_DB=$(get_yaml_value "$SCENARIO_CONFIG" "environments.production.database_name")
[ -z "$SC_SSH_PORT" ] && SC_SSH_PORT=22
[ -z "$SC_PROD_DB" ] && SC_PROD_DB="${SCENARIO_NAME}_production"

# Local DB names
API_DEV_DB="carambus_api_development"
SC_DEV_DB="${SCENARIO_NAME}_development"

echo "═══════════════════════════════════════════════════════════════"
echo "Database Synchronization Check"
echo "Scenario: $SCENARIO_NAME"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Configuration:"
echo "  API Server: $API_SSH_HOST:$API_SSH_PORT (prod: carambus_api_production)"
echo "  Scenario Server: $SC_SSH_HOST:$SC_SSH_PORT (prod: $SC_PROD_DB)"
echo "  Local dev DBs: $API_DEV_DB, $SC_DEV_DB"
echo ""

# 1) API versions (official < 50M)
API_VERSION=$(psql "$API_DEV_DB" -t -c "SELECT COALESCE(MAX(id), 0) FROM versions WHERE id < 50000000;" 2>/dev/null | xargs || true)
API_PROD_VERSION=$(ssh -p "$API_SSH_PORT" "www-data@$API_SSH_HOST" "sudo -u postgres psql -d carambus_api_production -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions WHERE id < 50000000;\"" 2>/dev/null | xargs || true)

echo "1. API Server ($API_SSH_HOST)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Development (local):"
echo "     Version: $API_VERSION"
echo "   Production (remote):"
echo "     Version: $API_PROD_VERSION"
if [ "$API_VERSION" = "$API_PROD_VERSION" ]; then
  echo "   ✅ API dev and prod synchronized"
else
  echo "   ⚠️  API version mismatch: dev=$API_VERSION, prod=$API_PROD_VERSION"
fi
echo ""

# 2) Scenario Development (local)
SC_DEV_LAST_VERSION=$(psql "$SC_DEV_DB" -t -c "SELECT data::json->'last_version_id'->>'Integer' FROM settings WHERE id = 14;" 2>/dev/null | xargs || true)
SC_DEV_GAMES=$(psql "$SC_DEV_DB" -t -c "SELECT COUNT(*) FROM games;" 2>/dev/null | xargs || true)
SC_DEV_LOCAL_GAMES=$(psql "$SC_DEV_DB" -t -c "SELECT COUNT(*) FROM games WHERE id > 50000000;" 2>/dev/null | xargs || true)
SC_DEV_PLAYERS=$(psql "$SC_DEV_DB" -t -c "SELECT COUNT(*) FROM players WHERE id < 50000000;" 2>/dev/null | xargs || true)
SC_DEV_TOURNAMENTS=$(psql "$SC_DEV_DB" -t -c "SELECT COUNT(*) FROM tournaments WHERE id < 50000000;" 2>/dev/null | xargs || true)

echo "2. Scenario Development (local)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   last_version_id: $SC_DEV_LAST_VERSION"
echo "   Games (total): $SC_DEV_GAMES"
echo "   Games (local, id>50M): $SC_DEV_LOCAL_GAMES"
echo "   Players (official): $SC_DEV_PLAYERS"
echo "   Tournaments (official): $SC_DEV_TOURNAMENTS"
if [ "$SC_DEV_LAST_VERSION" = "$API_VERSION" ]; then
  echo "   ✅ last_version_id matches API version"
else
  echo "   ⚠️  last_version_id ($SC_DEV_LAST_VERSION) != API version ($API_VERSION)"
fi
echo ""

# 3) Scenario Production (remote)
SC_PROD_LAST_VERSION=$(ssh -p "$SC_SSH_PORT" "www-data@$SC_SSH_HOST" "sudo -u postgres psql -d $SC_PROD_DB -t -c \"SELECT data::json->'last_version_id'->>'Integer' FROM settings WHERE id = 14;\"" 2>/dev/null | xargs || true)
SC_PROD_GAMES=$(ssh -p "$SC_SSH_PORT" "www-data@$SC_SSH_HOST" "sudo -u postgres psql -d $SC_PROD_DB -t -c \"SELECT COUNT(*) FROM games;\"" 2>/dev/null | xargs || true)
SC_PROD_LOCAL_GAMES=$(ssh -p "$SC_SSH_PORT" "www-data@$SC_SSH_HOST" "sudo -u postgres psql -d $SC_PROD_DB -t -c \"SELECT COUNT(*) FROM games WHERE id > 50000000;\"" 2>/dev/null | xargs || true)
SC_PROD_PLAYERS=$(ssh -p "$SC_SSH_PORT" "www-data@$SC_SSH_HOST" "sudo -u postgres psql -d $SC_PROD_DB -t -c \"SELECT COUNT(*) FROM players WHERE id < 50000000;\"" 2>/dev/null | xargs || true)
SC_PROD_TOURNAMENTS=$(ssh -p "$SC_SSH_PORT" "www-data@$SC_SSH_HOST" "sudo -u postgres psql -d $SC_PROD_DB -t -c \"SELECT COUNT(*) FROM tournaments WHERE id < 50000000;\"" 2>/dev/null | xargs || true)

echo "3. Scenario Production ($SC_SSH_HOST)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   last_version_id: $SC_PROD_LAST_VERSION"
echo "   Games (total): $SC_PROD_GAMES"
echo "   Games (local, id>50M): $SC_PROD_LOCAL_GAMES"
echo "   Players (official): $SC_PROD_PLAYERS"
echo "   Tournaments (official): $SC_PROD_TOURNAMENTS"
if [ "$SC_PROD_LAST_VERSION" = "$API_VERSION" ]; then
  echo "   ✅ last_version_id matches API version"
else
  echo "   ⚠️  last_version_id ($SC_PROD_LAST_VERSION) != API version ($API_VERSION)"
fi
echo ""

# 4) Summary
echo "4. Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ALL_OK=true

if [ "$SC_DEV_LAST_VERSION" = "$API_VERSION" ] && [ "$SC_PROD_LAST_VERSION" = "$API_VERSION" ]; then
  echo "✅ All databases have matching last_version_id ($API_VERSION)"
else
  echo "⚠️  Version mismatch detected"
  ALL_OK=false
fi

if [ "$SC_DEV_GAMES" = "$SC_PROD_GAMES" ]; then
  echo "✅ Scenario dev/prod games synchronized ($SC_DEV_GAMES games total)"
else
  echo "⚠️  Scenario games differ: dev=$SC_DEV_GAMES, prod=$SC_PROD_GAMES"
  ALL_OK=false
fi

if [ "$SC_DEV_LOCAL_GAMES" = "$SC_PROD_LOCAL_GAMES" ]; then
  echo "✅ Scenario local games synchronized ($SC_DEV_LOCAL_GAMES local games)"
else
  echo "⚠️  Scenario local games differ: dev=$SC_DEV_LOCAL_GAMES, prod=$SC_PROD_LOCAL_GAMES"
  ALL_OK=false
fi

if [ "$SC_DEV_PLAYERS" = "$SC_PROD_PLAYERS" ]; then
  echo "✅ Scenario players synchronized ($SC_DEV_PLAYERS players)"
else
  echo "⚠️  Scenario players differ: dev=$SC_DEV_PLAYERS, prod=$SC_PROD_PLAYERS"
  ALL_OK=false
fi

if [ "$SC_DEV_TOURNAMENTS" = "$SC_PROD_TOURNAMENTS" ]; then
  echo "✅ Scenario tournaments synchronized ($SC_DEV_TOURNAMENTS tournaments)"
else
  echo "⚠️  Scenario tournaments differ: dev=$SC_DEV_TOURNAMENTS, prod=$SC_PROD_TOURNAMENTS"
  ALL_OK=false
fi

echo ""
echo "Note: Players and tournaments are typically filtered by region (e.g. NBV only)."
echo "      Official data (id < 50M) should match. Local data (id > 50M) is preserved."
echo ""
if [ "$ALL_OK" = true ]; then
  echo "🎉 All databases are properly synchronized!"
else
  echo "⚠️  Some synchronization issues detected (see above)"
fi
echo "═══════════════════════════════════════════════════════════════"




