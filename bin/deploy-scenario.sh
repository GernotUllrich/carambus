#!/bin/bash
# Generic Carambus Scenario Deployment Workflow
# Usage: ./bin/deploy-scenario.sh <scenario_name> [-y]

set -e

# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/carambus_env.sh" ]; then
    source "$SCRIPT_DIR/lib/carambus_env.sh"
else
    echo "ERROR: carambus_env.sh not found"
    exit 1
fi

# Reduce Ruby warning noise in output
export RUBYOPT="${RUBYOPT:-} -W0"
export BUNDLE_SILENCE_DEPRECATIONS=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Parse command line arguments
SCENARIO_NAME=""
AUTO_CONFIRM=false
SKIP_CLEANUP=false
PRODUCTION_ONLY=false

show_usage() {
    echo "Usage: $0 <scenario_name> [-y] [--skip-cleanup] [--production-only]"
    echo ""
    echo "Arguments:"
    echo "  scenario_name       Name of the scenario to deploy (e.g., carambus_location_5101)"
    echo "  -y                  Auto-confirm all steps (skip interactive prompts)"
    echo "  --skip-cleanup      Skip Step 0 cleanup (useful for iterative deployments)"
    echo "  --production-only   Only regenerate production configs, preserve development"
    echo ""
    echo "Examples:"
    echo "  $0 carambus_location_5101"
    echo "  $0 carambus_location_5101 -y"
    echo "  $0 carambus_location_5101 --production-only       # Update production only"
    echo "  $0 carambus_location_5101 --skip-cleanup -y       # Skip cleanup step"
    echo ""
    echo "Workflow modes:"
    echo "  Default mode:"
    echo "    1. Clean up existing deployment"
    echo "    2. Prepare development environment"
    echo "    3. Prepare deployment configuration"
    echo "    4. Deploy to server"
    echo "    5. Prepare Raspberry Pi client"
    echo "    6. Deploy client configuration"
    echo "    7. Run final tests"
    echo ""
    echo "  Production-only mode (--production-only):"
    echo "    1. Skip cleanup (preserves development)"
    echo "    2. Skip development preparation (uses existing)"
    echo "    3. Prepare deployment configuration"
    echo "    4. Deploy to server"
    echo "    5. Prepare Raspberry Pi client"
    echo "    6. Deploy client configuration"
    echo "    7. Run final tests"
}

# Parse arguments
if [ $# -eq 0 ]; then
    error "No scenario name provided"
    show_usage
    exit 1
fi

# Check for help first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

SCENARIO_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --production-only)
            PRODUCTION_ONLY=true
            SKIP_CLEANUP=true  # Production-only implies skip cleanup
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate scenario name
if [ -z "$SCENARIO_NAME" ]; then
    error "Scenario name cannot be empty"
    exit 1
fi

# Confirmation function
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$AUTO_CONFIRM" = true ]; then
        log "Auto-confirming: $prompt"
        return 0
    fi
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get SSH config from scenario
get_ssh_config() {
    local scenario_name="$1"
    local config_file="$SCENARIOS_PATH/$scenario_name/config.yml"
    
    if [ ! -f "$config_file" ]; then
        error "Config file not found: $config_file"
        return 1
    fi
    
    # Extract SSH host and port from config.yml (ignore commented lines)
    SSH_HOST=$(grep -A 15 "production:" "$config_file" | grep -v "^\s*#" | grep "ssh_host:" | head -1 | awk '{print $2}')
    SSH_PORT=$(grep -A 15 "production:" "$config_file" | grep -v "^\s*#" | grep "ssh_port:" | head -1 | awk '{print $2}')
    
    if [ -z "$SSH_HOST" ] || [ -z "$SSH_PORT" ]; then
        error "Could not extract SSH config from $config_file"
        return 1
    fi
}

# Function to check if production database version is higher than development OR has local data
check_production_version() {
    local scenario_name="$1"
    
    # Get SSH config
    get_ssh_config "$scenario_name"
    
    # Get development database version
    local dev_version
    dev_version=$(psql -d "${scenario_name}_development" -t -c "SELECT last_version_id FROM schema_migrations ORDER BY version DESC LIMIT 1;" 2>/dev/null | xargs)
    
    # Check if production database exists on remote server
    if ! ssh -p $SSH_PORT www-data@$SSH_HOST "sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${scenario_name}_production" 2>/dev/null; then
        info "Production database ${scenario_name}_production does not exist on remote server"
        return 0  # Allow drop (nothing to drop)
    fi
    
    # Check for local data: official id>50M in core tables or any rows in extension tables
    info "Checking for local data (ID > 50,000,000 or extension tables present)..."
    local has_local_data
    local local_query
    local_query="SELECT (
      (SELECT COUNT(*) FROM (SELECT 1 FROM games WHERE id > 50000000 LIMIT 1) AS t1) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tournaments WHERE id > 50000000 LIMIT 1) AS t2) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tables WHERE id > 50000000 LIMIT 1) AS t3) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM users WHERE id > 50000000 LIMIT 1) AS t4) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM players WHERE id > 50000000 LIMIT 1) AS t5) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM table_locals LIMIT 1) AS t6) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tournament_locals LIMIT 1) AS t7)
    );"
    has_local_data=$(ssh -p $SSH_PORT www-data@$SSH_HOST "sudo -u postgres psql -d ${scenario_name}_production -t -c \"${local_query}\"" 2>/dev/null | xargs)
    
    if [ "$has_local_data" != "0" ]; then
        warning "Production database contains local data (ID > 50,000,000)"
        warning "Database will NOT be dropped in cleanup - local data will be preserved"
        info "Step 2 (prepare_deploy) will automatically backup and restore local data"
        return 1  # Don't drop - has local data
    fi
    
    # Get production database version from remote server
    local prod_version
    prod_version=$(ssh -p $SSH_PORT www-data@$SSH_HOST "sudo -u postgres psql -d ${scenario_name}_production -t -c \"SELECT last_version_id FROM schema_migrations ORDER BY version DESC LIMIT 1;\"" 2>/dev/null | xargs)
    
    # If either version is empty or not numeric, assume we should drop
    if [[ ! "$dev_version" =~ ^[0-9]+$ ]] || [[ ! "$prod_version" =~ ^[0-9]+$ ]]; then
        return 0  # Allow drop
    fi
    
    # Compare versions
    if [ "$prod_version" -gt "$dev_version" ]; then
        warning "Production database version ($prod_version) is higher than development ($dev_version)"
        return 1  # Don't drop - production is newer
    else
        info "Production database version ($prod_version) is same or lower than development ($dev_version)"
        return 0  # Allow drop - development is same or newer
    fi
}

# Step 0: Complete Cleanup
step_zero_cleanup() {
    log "🧹 Step 0: Complete Cleanup"
    log "=========================="
    
    warning "This will completely remove:"
    warning "  - Scenario root folder: $CARAMBUS_BASE/$SCENARIO_NAME (PRESERVED if it is a git checkout)"
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        warning "  - Database: ${SCENARIO_NAME}_development (SKIPPED - API server database)"
    else
        warning "  - Database: ${SCENARIO_NAME}_development"
    fi
    warning "  - Database: ${SCENARIO_NAME}_production (checked for local data & version)"
    warning "  - Raspberry Pi: Puma service, Nginx config, production database"
    info ""
    info "Note: Production database will NOT be dropped if:"
    info "  - It contains local data (ID > 50,000,000)"
    info "  - Its version is higher than development"
    info "  → In these cases, Step 2 (prepare_deploy) will handle data preservation"
    
    if ! confirm "Proceed with complete cleanup?"; then
        log "Cleanup cancelled"
        return 1
    fi
    
    # Clean up local scenario root folder
    #
    # IMPORTANT: A bare "rm -rf" only makes sense for a brand-new scenario.
    # An already-checked-out scenario folder may contain LOCAL, NON-REPO data
    # that must never be destroyed by a recreate:
    #   - .paul/ (Paul planning state + handoffs), paul/ (cloned tooling repo)
    #   - .idea/, .claude/worktrees, other untracked/ignored local files
    #   - local-only git branches that were never pushed
    # The development DB is still dropped/rebuilt below and prepare_development
    # refreshes configs + filtered data IN PLACE, so deleting the checkout is
    # unnecessary. Therefore: preserve any existing git checkout.
    local scenario_root="$CARAMBUS_BASE/$SCENARIO_NAME"
    if [ -d "$scenario_root/.git" ]; then
        warning "Scenario root is an existing git checkout - PRESERVING it."
        info "  Keeping local non-repo data (.paul/, paul/, .idea/, local branches, ...)."
        info "  Skipping 'rm -rf $scenario_root' (recreate-from-scratch only applies to new scenarios)."
        info "  Development DB is still rebuilt; prepare_development refreshes configs in place."
    elif [ -d "$scenario_root" ]; then
        info "Removing local scenario root folder (not a git checkout)..."
        rm -rf "$scenario_root"
        log "✅ Local scenario root folder removed"
    else
        info "Local scenario root folder not found (already clean)"
    fi
    
    # Drop development database (skip for carambus_api)
    info "Dropping development database..."
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        info "Skipping development database drop for carambus_api (API server database)"
    elif psql -lqt | cut -d \| -f 1 | grep -qw "${SCENARIO_NAME}_development"; then
        dropdb "${SCENARIO_NAME}_development"
        log "✅ Development database dropped"
    else
        info "Development database not found (already clean)"
    fi
    
    # Get SSH config for this scenario
    get_ssh_config "$SCENARIO_NAME"
    
    # Clean up Raspberry Pi
    info "Cleaning up Raspberry Pi..."
    
    # Stop and remove Puma service
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo systemctl stop puma-${SCENARIO_NAME}.service || true"
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo systemctl disable puma-${SCENARIO_NAME}.service || true"
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo rm -f /etc/systemd/system/puma-${SCENARIO_NAME}.service || true"
    log "✅ Puma service removed"
    
    # Remove Nginx configuration (exact match only, not substrings)
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo rm -f /etc/nginx/sites-enabled/${SCENARIO_NAME} || true"
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo rm -f /etc/nginx/sites-available/${SCENARIO_NAME} || true"
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo systemctl reload nginx || true"
    log "✅ Nginx configuration removed"
    
    # Drop production database (only if version check AND local data check pass)
    info "Checking production database (version and local data)..."
    if check_production_version "$SCENARIO_NAME"; then
        info "No conflicts detected - dropping database on remote server"
        if ssh -p $SSH_PORT www-data@$SSH_HOST "sudo -u postgres dropdb ${SCENARIO_NAME}_production 2>/dev/null"; then
            log "✅ Production database dropped"
        else
            info "Production database not found or already dropped"
        fi
    else
        log "✅ Production database preserved (has local data or newer version)"
        info "Step 2 (prepare_deploy) will handle database update with data preservation"
    fi
    
    # Remove deployment directory
    ssh -p $SSH_PORT www-data@$SSH_HOST "sudo rm -rf /var/www/${SCENARIO_NAME} || true"
    log "✅ Deployment directory removed"
    
    log "✅ Complete cleanup finished"
    echo ""
}

# Step 1: Prepare Development
step_one_prepare_development() {
    log "🔧 Step 1: Prepare Development Environment"
    log "========================================"
    
    info "This will:"
    info "  - Generate configuration files"
    info "  - Create Rails root folder"
    info "  - Check and sync with carambus_api_production if newer"
    info "  - Create development database from template"
    info "  - Apply region filtering"
    info "  - Set up development environment"
    
    if ! confirm "Proceed with prepare_development?"; then
        log "Development preparation cancelled"
        return 1
    fi
    
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        info "Special handling for carambus_api (API server):"
        info "  - Development environment will be created normally"
        info "  - Database operations are protected by rake task"
        info "  - No filtering, Version.sequence_reset, or settings manipulation"
        info "  - API sync step will be skipped (it is the source)"
        log "Running: rake scenario:prepare_development[$SCENARIO_NAME,development] (API mode)"
    else
        info "This scenario will sync with carambus_api_production if newer data is available"
        log "Running: rake scenario:prepare_development[$SCENARIO_NAME,development]"
    fi
    rake "scenario:prepare_development[$SCENARIO_NAME,development]"
    
    log "✅ Step 1 completed: Development environment prepared"
    echo ""
}

# Step 1.5: Vorbedingungen auf dem Server pruefen
#
# WARUM ZUSAMMEN UND WARUM HIER: Beim Aufsetzen von carambus_tbv (2026-07-22) sind drei
# Voraussetzungen NACHEINANDER aufgeschlagen — jede erst, nachdem der vorige Fehler behoben
# und minutenlang neu deployt war:
#   1. Production-DB fehlte        -> `deploy:migrate` bricht ab
#   2. Let's-Encrypt-Zertifikat    -> nginx wird REGLOAD-UNFAEHIG (betrifft ALLE Sites!)
#   3. /etc/<basename>.env (SMTP)  -> Puma-Crashloop, 502
# Gemeinsam ist ihnen: bei bestehenden Instanzen wurden sie irgendwann von Hand eingerichtet,
# bei einer Neuanlage fehlen sie. Dieser Schritt macht alle drei auf EINEN Blick sichtbar.
#
# Der Zeitpunkt ist bewusst VOR prepare_deploy: dort entsteht die nginx-Config, die ohne
# Zertifikat den Reload aller Sites blockiert. Die Datenbank dagegen kann erst DANACH angelegt
# werden (reset_server_db braucht die generierte Config) — sie wird hier nur gemeldet und in
# Schritt 2.5 behandelt.
step_one_five_check_preconditions() {
    log "🔍 Step 1.5: Vorbedingungen auf dem Server prüfen"
    log "================================================"

    local config_file="$CARAMBUS_DATA/scenarios/$SCENARIO_NAME/config.yml"
    if [ ! -f "$config_file" ]; then
        error "config.yml nicht gefunden: $config_file"
        return 1
    fi

    local prod_cfg="YAML.load_file('$config_file')['environments']['production']"
    local ssh_host=$(ruby -ryaml -e "puts $prod_cfg['ssh_host']" 2>/dev/null)
    local ssh_port=$(ruby -ryaml -e "puts $prod_cfg['ssh_port'] || 22" 2>/dev/null)
    local db_name=$(ruby -ryaml -e "puts $prod_cfg['database_name']" 2>/dev/null)
    local web_host=$(ruby -ryaml -e "puts $prod_cfg['webserver_host']" 2>/dev/null)
    local ssl_enabled=$(ruby -ryaml -e "puts($prod_cfg['ssl_enabled'] ? 'true' : 'false')" 2>/dev/null)
    local basename=$(ruby -ryaml -e "puts $prod_cfg['basename'] || '$SCENARIO_NAME'" 2>/dev/null)

    if [ -z "$ssh_host" ] || [ -z "$db_name" ]; then
        error "ssh_host oder database_name fehlen in $config_file"
        return 1
    fi

    # Erreichbarkeit ZUERST: eine fehlgeschlagene Verbindung darf nicht als "alles fehlt"
    # durchgehen — das wuerde im -y-Modus einen destruktiven DB-Reset ausloesen.
    if ! ssh -p "$ssh_port" -o ConnectTimeout=10 "www-data@$ssh_host" true 2>/dev/null; then
        error "Server $ssh_host:$ssh_port nicht erreichbar — Vorbedingungen nicht prüfbar."
        return 1
    fi

    local missing=0

    # (0) Namens-Konsistenz — faengt den KLON-FALLSTRICK ab.
    #
    # Ein neues Szenario entsteht meist als Kopie eines bestehenden. Bleiben dabei `name`,
    # `basename` oder `database_name` der Vorlage stehen, arbeitet der Deploy unter FREMDEM
    # Namen weiter — und `reset_server_db` ist dann sogar destruktiv am falschen Ort:
    # es dropt `database_name` und loescht `/var/www/<basename>`.
    # Live beobachtet an carambus_ebc (2026-07-22): name/basename/database_name zeigten
    # noch auf carambus_phat.
    local cfg_name=$(ruby -ryaml -e "puts YAML.load_file('$config_file')['scenario']['name']" 2>/dev/null)
    local cfg_basename=$(ruby -ryaml -e "puts YAML.load_file('$config_file')['scenario']['basename']" 2>/dev/null)
    local name_mismatch=0
    [ -n "$cfg_name" ] && [ "$cfg_name" != "$SCENARIO_NAME" ] && name_mismatch=1
    [ -n "$cfg_basename" ] && [ "$cfg_basename" != "$SCENARIO_NAME" ] && name_mismatch=1
    case "$db_name" in
      "${SCENARIO_NAME}_production") ;;
      *) name_mismatch=1 ;;
    esac

    if [ "$name_mismatch" -eq 1 ]; then
        warning "  ❌ Namen passen nicht zum Szenario '$SCENARIO_NAME':"
        warning "       scenario.name     = ${cfg_name:-<leer>}"
        warning "       scenario.basename = ${cfg_basename:-<leer>}"
        warning "       database_name     = $db_name"
        warning "     ⚠️  Sieht nach einer nicht angepassten KOPIE aus. reset_server_db würde"
        warning "        die Datenbank '$db_name' droppen und /var/www/${cfg_basename:-?} löschen"
        warning "        — also womöglich eine FREMDE Instanz treffen."
        missing=$((missing + 1))
    else
        info "  ✅ Namen konsistent ($SCENARIO_NAME)"
    fi

    # (1) Production-Datenbank
    if ssh -p "$ssh_port" "www-data@$ssh_host" 'sudo -u postgres psql -lqt' 2>/dev/null \
        | cut -d'|' -f1 | grep -qw "$db_name"; then
        info "  ✅ Datenbank $db_name"
    else
        warning "  ❌ Datenbank $db_name fehlt  → wird in Schritt 2.5 angelegt (reset_server_db)"
        missing=$((missing + 1))
    fi

    # (2) SSL-Zertifikat — nur wenn die Instanz ueberhaupt HTTPS fahren soll
    if [ "$ssl_enabled" = "true" ] && [ -n "$web_host" ]; then
        if ssh -p "$ssh_port" "www-data@$ssh_host" "sudo test -d /etc/letsencrypt/live/$web_host" 2>/dev/null; then
            info "  ✅ Zertifikat für $web_host"
        else
            warning "  ❌ Zertifikat für $web_host fehlt"
            warning "     ⚠️  OHNE ES MACHT prepare_deploy nginx REGLOAD-UNFÄHIG — das trifft ALLE Sites"
            warning "     Beheben:  bin/issue-letsencrypt-cert.sh $basename $web_host"
            missing=$((missing + 1))
        fi
    else
        info "  ⏭️  SSL nicht aktiviert (ssl_enabled=$ssl_enabled) — Zertifikat nicht nötig"
    fi

    # (3) EnvironmentFile mit den SMTP-Zugangsdaten
    if ssh -p "$ssh_port" "www-data@$ssh_host" "sudo test -f /etc/$basename.env" 2>/dev/null; then
        info "  ✅ /etc/$basename.env"
    else
        warning "  ❌ /etc/$basename.env fehlt  → Puma startet nicht (smtp_guard), 502"
        warning "     Beheben (übernimmt den SMTP-Absender einer laufenden Instanz):"
        warning "       ssh -p $ssh_port www-data@$ssh_host \"sudo cp -p /etc/carambus_nbv.env /etc/$basename.env\""
        warning "     Oder bewusst ohne Mailversand:  SKIP_SMTP_GUARD=1 in die Datei schreiben"
        missing=$((missing + 1))
    fi

    # (4) Zugang zum Region Server (Plan 29-05) — nur fuer Instanzen, die ihn BRAUCHEN:
    #
    #   Location Server (location_id gesetzt): meldet den Turnier-Abschluss an seinen
    #     Region Server  -> braucht dessen Kontext
    #   Authority (cap_role: api): holt die Meldelisten von N Region Servern
    #     -> braucht deren Kontexte
    #   Region Server (nur region_id): ist ZIEL, nicht Aufrufer -> braucht nichts
    #
    # Diese Luecke faellt sonst erst auf, wenn wirklich ein Turnier gespielt und abgeschlossen
    # wird — also im Ernstfall. Anders als (1)-(3) ist das rein lokal pruefbar.
    local location_id=$(ruby -ryaml -e "puts YAML.load_file('$config_file')['scenario']['location_id']" 2>/dev/null)
    local cap_role=$(ruby -ryaml -e "puts $prod_cfg['cap_role']" 2>/dev/null)

    if [ -n "$location_id" ] || [ "$cap_role" = "api" ]; then
        local rs_report=$(ruby -ryaml -e "
          decl = (YAML.load_file('$config_file')['scenario']['credentials'] || {})['region_server_contexts']
          ctxs = Array(decl).compact
          if ctxs.empty?
            puts 'MISSING_DECL'
          else
            pool_file = File.join('$CARAMBUS_DATA', 'secrets.yml')
            pool = File.exist?(pool_file) ? ((YAML.load_file(pool_file) || {})['shared'] || {})['region_server'] || {} : {}
            gaps = ctxs.reject { |c| pool.key?(c.to_s) || pool.key?(c.to_s.downcase) }
            puts gaps.empty? ? \"OK #{ctxs.join(',')}\" : \"NO_SECRET #{gaps.join(',')}\"
          end" 2>/dev/null)

        case "$rs_report" in
          OK*)
            info "  ✅ region_server_contexts: ${rs_report#OK }" ;;
          MISSING_DECL)
            warning "  ❌ region_server_contexts fehlt in der config.yml (scenario.credentials)"
            warning "     Diese Instanz meldet Ergebnisse an einen Region Server bzw. holt von dort."
            warning "     Ohne den Eintrag scheitert das erst beim Turnier-Abschluss."
            warning "     Beispiel:      region_server_contexts: [TBV]"
            missing=$((missing + 1)) ;;
          NO_SECRET*)
            warning "  ❌ Kein Zugang in secrets.yml für: ${rs_report#NO_SECRET }"
            warning "     Erwartet unter shared.region_server.<kontext>.username/password"
            warning "     Anlegen mit: rake \"service_accounts:create_carambus_app[<REGION>]\" AUF DEM REGION SERVER"
            missing=$((missing + 1)) ;;
          *)
            warning "  ⚠️  region_server_contexts nicht prüfbar (config.yml lesbar?)" ;;
        esac
    else
        info "  ⏭️  Region-Server-Zugang nicht nötig (Region Server ist Ziel, nicht Aufrufer)"
    fi

    if [ "$missing" -eq 0 ]; then
        log "✅ Alle Vorbedingungen erfüllt"
        echo ""
        return 0
    fi

    echo ""
    warning "$missing Vorbedingung(en) offen (siehe oben)."
    info "Die Datenbank erledigt Schritt 2.5 automatisch. Zertifikat und .env-Datei brauchen"
    info "die genannten Befehle — am besten JETZT, bevor prepare_deploy die nginx-Config schreibt."

    if ! confirm "Trotzdem mit prepare_deploy fortfahren?"; then
        log "Workflow angehalten. Nach dem Beheben einfach erneut starten."
        return 1
    fi
    echo ""
}

# Step 2: Prepare Deploy
step_two_prepare_deploy() {
    log "📦 Step 2: Prepare Deployment"
    log "============================"
    
    info "This will:"
    info "  - Generate production configuration files"
    info "  - Create production database from development dump"
    info "  - **AUTOMATICALLY** backup local data (id > 50,000,000) if present"
    info "  - **AUTOMATICALLY** restore local data after database replacement"
    info "  - Copy deployment files (nginx, puma, etc.)"
    info "  - Upload config files to server shared directory"
    info "  - Create systemd service and Nginx configuration on server"
    info "  - Prepare for server deployment"
    info ""
    info "Note: Local data preservation is automatic - no manual steps needed!"
    
    if ! confirm "Proceed with prepare_deploy?"; then
        log "Deployment preparation cancelled"
        return 1
    fi
    
    log "Running: rake scenario:prepare_deploy[$SCENARIO_NAME]"
    rake "scenario:prepare_deploy[$SCENARIO_NAME]"
    
    log "✅ Step 2 completed: Deployment prepared"
    echo ""
}

# Step 2.5: Ensure the production database exists on the server
#
# Bei einem NEU angelegten Szenario gibt es sie noch nicht — `deploy:migrate` scheitert dann mit
# "We could not find your database", nachdem der Deploy schon Minuten in bundle install gesteckt
# hat. `prepare_deploy` nennt reset_server_db selbst als naechsten Schritt, das Skript hat ihn aber
# nie ausgefuehrt.
#
# ⚠️ reset_server_db ist DESTRUKTIV (dropt die DB, loescht /var/www/<basename>). Deshalb laeuft er
# hier ausschliesslich, wenn die Datenbank nachweislich FEHLT. Ist sie da, passiert nichts.
step_two_five_ensure_database() {
    log "🗄️  Step 2.5: Production-Datenbank prüfen"
    log "========================================"

    local config_file="$CARAMBUS_DATA/scenarios/$SCENARIO_NAME/config.yml"
    if [ ! -f "$config_file" ]; then
        error "config.yml nicht gefunden: $config_file"
        return 1
    fi

    local prod_cfg="YAML.load_file('$config_file')['environments']['production']"
    local ssh_host=$(ruby -ryaml -e "puts $prod_cfg['ssh_host']" 2>/dev/null)
    local ssh_port=$(ruby -ryaml -e "puts $prod_cfg['ssh_port'] || 22" 2>/dev/null)
    local db_name=$(ruby -ryaml -e "puts $prod_cfg['database_name']" 2>/dev/null)

    if [ -z "$ssh_host" ] || [ -z "$db_name" ]; then
        error "ssh_host oder database_name fehlen in $config_file"
        return 1
    fi

    info "Server: $ssh_host:$ssh_port · Datenbank: $db_name"

    # Erreichbarkeit ZUERST pruefen: eine fehlgeschlagene SSH-Verbindung darf nicht als
    # "Datenbank fehlt" durchgehen — das wuerde im -y-Modus einen destruktiven Reset ausloesen.
    if ! ssh -p "$ssh_port" -o ConnectTimeout=10 "www-data@$ssh_host" true 2>/dev/null; then
        error "Server $ssh_host:$ssh_port nicht erreichbar — Datenbankstatus unbekannt."
        error "Abbruch, statt einen destruktiven Reset auf einer Vermutung zu starten."
        return 1
    fi

    if ssh -p "$ssh_port" "www-data@$ssh_host" 'sudo -u postgres psql -lqt' 2>/dev/null \
        | cut -d'|' -f1 | grep -qw "$db_name"; then
        log "✅ Datenbank $db_name existiert bereits — Schritt übersprungen"
        echo ""
        return 0
    fi

    warning "Datenbank $db_name existiert auf $ssh_host NICHT."
    info "Das ist bei einem neu angelegten Szenario normal. Ohne sie scheitert der Deploy"
    info "am db:migrate — erst nach mehreren Minuten bundle install."
    info ""
    info "reset_server_db legt sie an. Dabei wird ausserdem:"
    info "  - /var/www/<basename> entfernt (shared/ wird gesichert und zurückgespielt)"
    info "  - der Dump aus ${SCENARIO_NAME}_development erzeugt und eingespielt"

    if ! confirm "Production-Datenbank jetzt anlegen (reset_server_db)?" "y"; then
        error "Ohne Datenbank schlägt der folgende Deploy fehl. Abgebrochen."
        return 1
    fi

    log "Running: rake scenario:reset_server_db[$SCENARIO_NAME]"
    if ! rake "scenario:reset_server_db[$SCENARIO_NAME]"; then
        error "reset_server_db fehlgeschlagen - aborting workflow."
        return 1
    fi

    log "✅ Step 2.5 completed: Production-Datenbank angelegt"
    echo ""
}

# Step 3: Deploy
step_three_deploy() {
    log "🚀 Step 3: Deploy to Server"
    log "=========================="
    
    info "This will:"
    info "  - Execute pure Capistrano deployment"
    info "  - Automatically restart Puma service via Capistrano"
    info "  - Complete the application deployment"
    info "  - Database and config files already prepared by prepare_deploy"
    
    if ! confirm "Proceed with server deployment?"; then
        log "Server deployment cancelled"
        return 1
    fi
    
    log "Running: rake scenario:deploy[$SCENARIO_NAME]"
    if ! rake "scenario:deploy[$SCENARIO_NAME]"; then
        error "Server deployment (Capistrano) failed - aborting workflow."
        error "Fix the cause (e.g. transient 'No route to host'), then re-run:"
        error "  cd $CARAMBUS_BASE/$SCENARIO_NAME && cap production deploy"
        exit 1
    fi

    log "✅ Step 3 completed: Server deployment finished"
    echo ""
}

# Step 4: Prepare Client
step_four_prepare_client() {
    log "🍓 Step 4: Prepare Raspberry Pi Client"
    log "====================================="
    
    info "This will:"
    info "  - Install required packages (chromium, wmctrl, xdotool)"
    info "  - Create kiosk user"
    info "  - Setup systemd service"
    info "  - Prepare for kiosk mode"
    
    if ! confirm "Proceed with client preparation?"; then
        log "Client preparation cancelled"
        return 1
    fi
    
    log "Running: rake scenario:setup_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:setup_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Step 4 completed: Client prepared"
    echo ""
}

# Step 5: Deploy Client
step_five_deploy_client() {
    log "📱 Step 5: Deploy Client Configuration"
    log "====================================="
    
    info "This will:"
    info "  - Upload scoreboard URL"
    info "  - Install autostart script"
    info "  - Enable systemd service"
    info "  - Start kiosk mode"
    
    if ! confirm "Proceed with client deployment?"; then
        log "Client deployment cancelled"
        return 1
    fi
    
    log "Running: rake scenario:deploy_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:deploy_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Step 5 completed: Client deployed"
    echo ""
}

# Final Test
final_test() {
    log "🧪 Final Test"
    log "============"
    
    info "Testing complete functionality..."
    
    log "Running: rake scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "Testing browser restart functionality..."
    rake "scenario:restart_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Final test completed"
    echo ""
}

# Main workflow
main() {
    log "🎯 Complete Carambus Scenario Deployment Workflow"
    log "================================================"
    log "Scenario: $SCENARIO_NAME"
    if [ "$AUTO_CONFIRM" = true ]; then
        log "Mode: Auto-confirm (non-interactive)"
    else
        log "Mode: Interactive"
    fi
    if [ "$PRODUCTION_ONLY" = true ]; then
        warning "Mode: Production-only (preserving development environment)"
    fi
    if [ "$SKIP_CLEANUP" = true ] && [ "$PRODUCTION_ONLY" = false ]; then
        warning "Mode: Skip cleanup"
    fi
    echo ""
    
    # Step 0: Complete Cleanup (unless skipped)
    if [ "$SKIP_CLEANUP" = false ]; then
        step_zero_cleanup
        if [ $? -ne 0 ]; then
            log "Workflow cancelled at cleanup step"
            exit 1
        fi
    else
        log "⏭️  Step 0: Cleanup skipped (--skip-cleanup or --production-only)"
        echo ""
    fi
    
    # Step 1: Prepare Development (skip in production-only mode)
    if [ "$PRODUCTION_ONLY" = false ]; then
        step_one_prepare_development
        if [ $? -ne 0 ]; then
            log "Workflow cancelled at development preparation"
            exit 1
        fi
    else
        log "⏭️  Step 1: Development preparation skipped (--production-only)"
        info "Using existing development environment at $CARAMBUS_BASE/$SCENARIO_NAME"
        # Verify development environment exists
        if [ ! -d "$CARAMBUS_BASE/$SCENARIO_NAME" ]; then
            error "Development environment not found at $CARAMBUS_BASE/$SCENARIO_NAME"
            error "Run without --production-only first to create it"
            exit 1
        fi
        echo ""
    fi
    
    # Step 1.5: Vorbedingungen auf dem Server (DB, Zertifikat, .env) — alle auf einen Blick
    step_one_five_check_preconditions
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at precondition check"
        exit 1
    fi

    # Step 2: Prepare Deploy
    step_two_prepare_deploy
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at deployment preparation"
        exit 1
    fi
    
    # Step 2.5: Production-DB anlegen, falls sie fehlt (neues Szenario)
    step_two_five_ensure_database
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at database preparation"
        exit 1
    fi

    # Step 3: Deploy
    step_three_deploy
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at server deployment"
        exit 1
    fi
    
    # Step 4: Prepare Client
    step_four_prepare_client
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at client preparation"
        exit 1
    fi
    
    # Step 5: Deploy Client
    step_five_deploy_client
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at client deployment"
        exit 1
    fi
    
    # Final Test
    final_test
    
    log "🎉 COMPLETE WORKFLOW SUCCESSFUL!"
    log "================================"
    log "Scenario '$SCENARIO_NAME' is now fully deployed and operational"
    log ""
    # Read the configuration from scenario file (ignore commented lines)
    if [ -f "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" ]; then
        WEBSERVER_HOST=$(grep -A 15 "production:" "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" | grep -v "^\s*#" | grep "webserver_host:" | head -1 | awk '{print $2}')
        WEBSERVER_PORT=$(grep -A 15 "production:" "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" | grep -v "^\s*#" | grep "webserver_port:" | head -1 | awk '{print $2}')
        SSH_HOST=$(grep -A 15 "production:" "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" | grep -v "^\s*#" | grep "ssh_host:" | head -1 | awk '{print $2}')
        SSH_PORT=$(grep -A 15 "production:" "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" | grep -v "^\s*#" | grep "ssh_port:" | head -1 | awk '{print $2}')
    else
        WEBSERVER_HOST="localhost"
        WEBSERVER_PORT=3131
        SSH_HOST="localhost"
        SSH_PORT=8910
    fi
    
    log "Access Information:"
    log "  - Web Interface: http://$WEBSERVER_HOST:$WEBSERVER_PORT"
    log "  - SSH Access: ssh -p $SSH_PORT www-data@$SSH_HOST"
    log ""
    log "Management Commands:"
    log "  - Restart Browser: rake scenario:restart_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Test Client: rake scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Check Service: ssh -p $SSH_PORT www-data@$SSH_HOST 'sudo systemctl status scoreboard-kiosk'"
}

# Run main workflow
main "$@"
