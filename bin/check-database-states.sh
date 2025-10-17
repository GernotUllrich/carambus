#!/bin/bash
# Script to check current database states for deploy-scenario analysis
# Usage: ./bin/check-database-states.sh carambus_bcw

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCENARIO_NAME="${1:-carambus_bcw}"

# Get script directory and carambus base path for config file lookups
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CARAMBUS_BASE="$(dirname "$SCRIPT_DIR")"

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}DATABASE STATE ANALYSIS FOR: ${SCENARIO_NAME}${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# ==============================================================================
# LOCAL DATABASES (Mac Development Machine)
# ==============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}LOCAL DATABASES (Mac)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check carambus_api_development
echo -e "${GREEN}[1] carambus_api_development${NC}"
if psql -lqt | cut -d \| -f 1 | grep -qw "carambus_api_development"; then
    echo "    Status: EXISTS"
    
    # Get Version.last.id
    VERSION_ID=$(psql carambus_api_development -t -c "SELECT COALESCE(MAX(id), 0) FROM versions;" 2>/dev/null | xargs)
    echo "    Version.last.id: ${VERSION_ID}"
    
    # Get official version count (id < 50000000)
    OFFICIAL_VERSION_COUNT=$(psql carambus_api_development -t -c "SELECT COUNT(*) FROM versions WHERE id < 50000000;" 2>/dev/null | xargs)
    echo "    Official versions (id < 50M): ${OFFICIAL_VERSION_COUNT}"
    
    # Get local version count (id >= 50000000)
    LOCAL_VERSION_COUNT=$(psql carambus_api_development -t -c "SELECT COUNT(*) FROM versions WHERE id >= 50000000;" 2>/dev/null | xargs)
    echo "    Local versions (id >= 50M): ${LOCAL_VERSION_COUNT}"
else
    echo -e "    Status: ${RED}DOES NOT EXIST${NC}"
fi
echo ""

# Check carambus_bcw_development  
echo -e "${GREEN}[2] ${SCENARIO_NAME}_development${NC}"
if psql -lqt | cut -d \| -f 1 | grep -qw "${SCENARIO_NAME}_development"; then
    echo "    Status: EXISTS"
    
    # Get Setting.first.data["last_version_id"] (nested as {"Integer":"12239577"})
    LAST_VERSION_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COALESCE((data::jsonb)->'last_version_id'->>'Integer', '0') FROM settings LIMIT 1;" 2>/dev/null | xargs)
    if [ -z "$LAST_VERSION_ID" ] || [ "$LAST_VERSION_ID" = "NULL" ]; then
        LAST_VERSION_ID="0"
    fi
    echo "    Setting[last_version_id]: ${LAST_VERSION_ID}"
    
    # Get Version.last.id
    VERSION_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COALESCE(MAX(id), 0) FROM versions;" 2>/dev/null | xargs)
    echo "    Version.last.id: ${VERSION_ID}"
    
    # Get version count
    VERSION_COUNT=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM versions;" 2>/dev/null | xargs)
    echo "    Total versions: ${VERSION_COUNT}"
    
    # Check table_locals
    TABLE_LOCALS_COUNT=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM table_locals;" 2>/dev/null | xargs)
    echo "    table_locals count: ${TABLE_LOCALS_COUNT}"
    
    if [ "${TABLE_LOCALS_COUNT}" -gt 0 ]; then
        TABLE_LOCALS_MIN_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT MIN(id) FROM table_locals;" 2>/dev/null | xargs)
        TABLE_LOCALS_MAX_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT MAX(id) FROM table_locals;" 2>/dev/null | xargs)
        TABLE_LOCALS_UNBUMPED=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM table_locals WHERE id < 50000000;" 2>/dev/null | xargs)
        echo "    table_locals ID range: ${TABLE_LOCALS_MIN_ID} - ${TABLE_LOCALS_MAX_ID}"
        if [ "${TABLE_LOCALS_UNBUMPED}" -gt 0 ]; then
            echo -e "    ${YELLOW}⚠️  UNBUMPED table_locals: ${TABLE_LOCALS_UNBUMPED} records with id < 50M${NC}"
        else
            echo "    ✅ All table_locals IDs are >= 50M"
        fi
    fi
    
    # Check tournament_locals
    TOURNAMENT_LOCALS_COUNT=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM tournament_locals;" 2>/dev/null | xargs)
    echo "    tournament_locals count: ${TOURNAMENT_LOCALS_COUNT}"
    
    if [ "${TOURNAMENT_LOCALS_COUNT}" -gt 0 ]; then
        TOURNAMENT_LOCALS_MIN_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT MIN(id) FROM tournament_locals;" 2>/dev/null | xargs)
        TOURNAMENT_LOCALS_MAX_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT MAX(id) FROM tournament_locals;" 2>/dev/null | xargs)
        TOURNAMENT_LOCALS_UNBUMPED=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM tournament_locals WHERE id < 50000000;" 2>/dev/null | xargs)
        echo "    tournament_locals ID range: ${TOURNAMENT_LOCALS_MIN_ID} - ${TOURNAMENT_LOCALS_MAX_ID}"
        if [ "${TOURNAMENT_LOCALS_UNBUMPED}" -gt 0 ]; then
            echo -e "    ${YELLOW}⚠️  UNBUMPED tournament_locals: ${TOURNAMENT_LOCALS_UNBUMPED} records with id < 50M${NC}"
        else
            echo "    ✅ All tournament_locals IDs are >= 50M"
        fi
    fi
    
    # Check for other local data (id > 50M)
    LOCAL_DATA_COUNT=$(psql ${SCENARIO_NAME}_development -t -c "SELECT 
        (SELECT COUNT(*) FROM games WHERE id > 50000000) +
        (SELECT COUNT(*) FROM tournaments WHERE id > 50000000) +
        (SELECT COUNT(*) FROM tables WHERE id > 50000000) +
        (SELECT COUNT(*) FROM users WHERE id > 50000000) +
        (SELECT COUNT(*) FROM players WHERE id > 50000000);" 2>/dev/null | xargs)
    echo "    Other local data (id > 50M): ${LOCAL_DATA_COUNT} records"
    
else
    echo -e "    Status: ${RED}DOES NOT EXIST${NC}"
fi
echo ""

# ==============================================================================
# REMOTE DATABASES (Production Server from Scenario Config)
# ==============================================================================

# Get production server details from scenario config
SCENARIO_CONFIG_FILE="${CARAMBUS_BASE}/../carambus_data/scenarios/${SCENARIO_NAME}/config.yml"

if [ ! -f "$SCENARIO_CONFIG_FILE" ]; then
    # Try alternative path (if running from different location)
    SCENARIO_CONFIG_FILE="/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_data/scenarios/${SCENARIO_NAME}/config.yml"
fi

if [ -f "$SCENARIO_CONFIG_FILE" ]; then
    PROD_SSH_HOST=$(grep -A 20 "production:" "$SCENARIO_CONFIG_FILE" | grep "ssh_host:" | head -1 | awk '{print $2}')
    PROD_SSH_PORT=$(grep -A 20 "production:" "$SCENARIO_CONFIG_FILE" | grep "ssh_port:" | head -1 | awk '{print $2}')
    
    if [ -z "$PROD_SSH_HOST" ]; then
        PROD_SSH_HOST="unknown"
        PROD_SSH_PORT="unknown"
    fi
else
    PROD_SSH_HOST="unknown (config not found)"
    PROD_SSH_PORT="unknown"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}REMOTE DATABASES (Production: ${PROD_SSH_HOST}:${PROD_SSH_PORT})${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check carambus_bcw_production
echo -e "${GREEN}[3] ${SCENARIO_NAME}_production${NC}"
if [ "$PROD_SSH_HOST" = "unknown" ] || [ "$PROD_SSH_HOST" = "unknown (config not found)" ]; then
    echo -e "    Status: ${RED}CANNOT CHECK - Scenario config not found or invalid${NC}"
elif ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw ${SCENARIO_NAME}_production" 2>/dev/null; then
    echo "    Status: EXISTS"
    
    # Get Setting.first.data["last_version_id"] (nested as {"Integer":"12239577"})
    LAST_VERSION_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COALESCE((data::jsonb)->'last_version_id'->>'Integer', '0') FROM settings LIMIT 1;\"" 2>/dev/null | xargs)
    if [ -z "$LAST_VERSION_ID" ] || [ "$LAST_VERSION_ID" = "NULL" ]; then
        LAST_VERSION_ID="0"
    fi
    echo "    Setting[last_version_id]: ${LAST_VERSION_ID}"
    
    # Get Version.last.id
    VERSION_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions;\"" 2>/dev/null | xargs)
    echo "    Version.last.id: ${VERSION_ID}"
    
    # Get version count
    VERSION_COUNT=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COUNT(*) FROM versions;\"" 2>/dev/null | xargs)
    echo "    Total versions: ${VERSION_COUNT}"
    
    # Check table_locals
    TABLE_LOCALS_COUNT=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COUNT(*) FROM table_locals;\"" 2>&1 | xargs)
    echo "    table_locals count: ${TABLE_LOCALS_COUNT}"
    
    # Debug: Show actual IDs
    TABLE_LOCALS_IDS=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT array_agg(id ORDER BY id) FROM table_locals;\"" 2>/dev/null | xargs)
    if [ -n "$TABLE_LOCALS_IDS" ] && [ "$TABLE_LOCALS_IDS" != "NULL" ]; then
        echo "    table_locals IDs: ${TABLE_LOCALS_IDS}"
    fi
    
    if [ "${TABLE_LOCALS_COUNT}" -gt 0 ] 2>/dev/null; then
        TABLE_LOCALS_MIN_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT MIN(id) FROM table_locals;\"" 2>/dev/null | xargs)
        TABLE_LOCALS_MAX_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT MAX(id) FROM table_locals;\"" 2>/dev/null | xargs)
        TABLE_LOCALS_UNBUMPED=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COUNT(*) FROM table_locals WHERE id < 50000000;\"" 2>/dev/null | xargs)
        echo "    table_locals ID range: ${TABLE_LOCALS_MIN_ID} - ${TABLE_LOCALS_MAX_ID}"
        if [ "${TABLE_LOCALS_UNBUMPED}" -gt 0 ]; then
            echo -e "    ${RED}❌ UNBUMPED table_locals: ${TABLE_LOCALS_UNBUMPED} records with id < 50M${NC}"
        else
            echo "    ✅ All table_locals IDs are >= 50M"
        fi
    fi
    
    # Check tournament_locals
    TOURNAMENT_LOCALS_COUNT=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COUNT(*) FROM tournament_locals;\"" 2>&1 | xargs)
    echo "    tournament_locals count: ${TOURNAMENT_LOCALS_COUNT}"
    
    # Debug: Show actual IDs
    TOURNAMENT_LOCALS_IDS=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT array_agg(id ORDER BY id) FROM tournament_locals;\"" 2>/dev/null | xargs)
    if [ -n "$TOURNAMENT_LOCALS_IDS" ] && [ "$TOURNAMENT_LOCALS_IDS" != "NULL" ]; then
        echo "    tournament_locals IDs: ${TOURNAMENT_LOCALS_IDS}"
    fi
    
    if [ "${TOURNAMENT_LOCALS_COUNT}" -gt 0 ] 2>/dev/null; then
        TOURNAMENT_LOCALS_MIN_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT MIN(id) FROM tournament_locals;\"" 2>/dev/null | xargs)
        TOURNAMENT_LOCALS_MAX_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT MAX(id) FROM tournament_locals;\"" 2>/dev/null | xargs)
        TOURNAMENT_LOCALS_UNBUMPED=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COUNT(*) FROM tournament_locals WHERE id < 50000000;\"" 2>/dev/null | xargs)
        echo "    tournament_locals ID range: ${TOURNAMENT_LOCALS_MIN_ID} - ${TOURNAMENT_LOCALS_MAX_ID}"
        if [ "${TOURNAMENT_LOCALS_UNBUMPED}" -gt 0 ]; then
            echo -e "    ${RED}❌ UNBUMPED tournament_locals: ${TOURNAMENT_LOCALS_UNBUMPED} records with id < 50M${NC}"
        else
            echo "    ✅ All tournament_locals IDs are >= 50M"
        fi
    fi
    
    # Check for other local data (id > 50M)
    LOCAL_DATA_COUNT=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT 
        (SELECT COUNT(*) FROM games WHERE id > 50000000) +
        (SELECT COUNT(*) FROM tournaments WHERE id > 50000000) +
        (SELECT COUNT(*) FROM tables WHERE id > 50000000) +
        (SELECT COUNT(*) FROM users WHERE id > 50000000) +
        (SELECT COUNT(*) FROM players WHERE id > 50000000);\"" 2>/dev/null | xargs)
    echo "    Other local data (id > 50M): ${LOCAL_DATA_COUNT} records"
    
else
    echo -e "    Status: ${RED}DOES NOT EXIST${NC}"
fi
echo ""

# ==============================================================================
# REMOTE API SERVER DATABASES
# ==============================================================================

# Get API server details from config
API_CONFIG_FILE="${CARAMBUS_BASE}/../carambus_data/scenarios/carambus_api/config.yml"

if [ -f "$API_CONFIG_FILE" ]; then
    API_SSH_HOST=$(grep -A 20 "production:" "$API_CONFIG_FILE" | grep "ssh_host:" | head -1 | awk '{print $2}')
    API_SSH_PORT=$(grep -A 20 "production:" "$API_CONFIG_FILE" | grep "ssh_port:" | head -1 | awk '{print $2}')
    
    if [ -z "$API_SSH_HOST" ]; then
        API_SSH_HOST="unknown"
        API_SSH_PORT="unknown"
    fi
else
    API_SSH_HOST="unknown (config not found)"
    API_SSH_PORT="unknown"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}REMOTE API SERVER DATABASES (${API_SSH_HOST}:${API_SSH_PORT})${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}[4] carambus_api_production (on API server)${NC}"
if [ "$API_SSH_HOST" = "unknown" ] || [ "$API_SSH_HOST" = "unknown (config not found)" ]; then
    echo -e "    Status: ${RED}CANNOT CHECK - API config not found or invalid${NC}"
elif ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw carambus_api_production" 2>/dev/null; then
    echo "    Status: EXISTS"
    
    # Get Version.last.id
    VERSION_ID=$(ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -d carambus_api_production -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions;\"" 2>/dev/null | xargs)
    echo "    Version.last.id: ${VERSION_ID}"
    
    # Get official version count (id < 50000000)
    OFFICIAL_VERSION_COUNT=$(ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -d carambus_api_production -t -c \"SELECT COUNT(*) FROM versions WHERE id < 50000000;\"" 2>/dev/null | xargs)
    echo "    Official versions (id < 50M): ${OFFICIAL_VERSION_COUNT}"
    
    # Get local version count (id >= 50000000)
    LOCAL_VERSION_COUNT=$(ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -d carambus_api_production -t -c \"SELECT COUNT(*) FROM versions WHERE id >= 50000000;\"" 2>/dev/null | xargs)
    echo "    Local versions (id >= 50M): ${LOCAL_VERSION_COUNT}"
else
    echo -e "    Status: ${RED}DOES NOT EXIST or CANNOT CONNECT${NC}"
fi
echo ""

# ==============================================================================
# COMPARISON AND RECOMMENDATIONS
# ==============================================================================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}ANALYSIS AND RECOMMENDATIONS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Compare carambus_api versions
if [ "$API_SSH_HOST" != "unknown" ] && [ "$API_SSH_HOST" != "unknown (config not found)" ] && \
   psql -lqt | cut -d \| -f 1 | grep -qw "carambus_api_development" && \
   ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw carambus_api_production" 2>/dev/null; then
    
    LOCAL_API_VERSION=$(psql carambus_api_development -t -c "SELECT COALESCE(MAX(id), 0) FROM versions WHERE id < 50000000;" 2>/dev/null | xargs)
    REMOTE_API_VERSION=$(ssh -p ${API_SSH_PORT} www-data@${API_SSH_HOST} "sudo -u postgres psql -d carambus_api_production -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions WHERE id < 50000000;\"" 2>/dev/null | xargs)
    
    echo "[API Database Comparison]"
    echo "  Local carambus_api_development (official): ${LOCAL_API_VERSION}"
    echo "  Remote carambus_api_production (official): ${REMOTE_API_VERSION}"
    
    if [ "${REMOTE_API_VERSION}" -gt "${LOCAL_API_VERSION}" ]; then
        echo -e "  ${YELLOW}⚠️  Remote API production is NEWER - will sync in Step 1${NC}"
    elif [ "${REMOTE_API_VERSION}" -eq "${LOCAL_API_VERSION}" ]; then
        echo "  ✅ API databases are IN SYNC"
    else
        echo "  ✅ Local API development is NEWER or EQUAL"
    fi
    echo ""
fi

# Compare BCW databases if both exist
if psql -lqt | cut -d \| -f 1 | grep -qw "${SCENARIO_NAME}_development" && \
   ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw ${SCENARIO_NAME}_production" 2>/dev/null; then
    
    DEV_VERSION=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COALESCE((data::jsonb)->'last_version_id'->>'Integer', '0') FROM settings LIMIT 1;" 2>/dev/null | xargs)
    PROD_VERSION=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COALESCE((data::jsonb)->'last_version_id'->>'Integer', '0') FROM settings LIMIT 1;\"" 2>/dev/null | xargs)
    
    # Handle empty values
    if [ -z "$DEV_VERSION" ]; then
        DEV_VERSION="0"
    fi
    if [ -z "$PROD_VERSION" ]; then
        PROD_VERSION="0"
    fi
    
    echo "[BCW Database Comparison]"
    echo "  Scrape Version Comparison (Setting[last_version_id]):"
    echo "    Local ${SCENARIO_NAME}_development: ${DEV_VERSION}"
    echo "    Remote ${SCENARIO_NAME}_production: ${PROD_VERSION}"
    
    if [ "${PROD_VERSION}" -gt "${DEV_VERSION}" ]; then
        echo -e "  ${RED}❌ Remote production has NEWER scrape data${NC}"
        echo -e "  ${RED}   This is unexpected - production should not have newer API sync data${NC}"
        echo -e "  ${RED}   Action: Extract local data from production before next prepare_development${NC}"
    elif [ "${PROD_VERSION}" -eq "${DEV_VERSION}" ]; then
        if [ "${DEV_VERSION}" = "0" ] && [ "${PROD_VERSION}" = "0" ]; then
            echo -e "  ${YELLOW}⚠️  Both databases have NO last_version_id set (using Version.last.id instead)${NC}"
            
            # Fall back to comparing Version.last.id
            DEV_VER_ID=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COALESCE(MAX(id), 0) FROM versions;" 2>/dev/null | xargs)
            PROD_VER_ID=$(ssh -p ${PROD_SSH_PORT} www-data@${PROD_SSH_HOST} "sudo -u postgres psql -d ${SCENARIO_NAME}_production -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions;\"" 2>/dev/null | xargs)
            
            echo "  Comparing Version.last.id instead:"
            echo "    Local development: ${DEV_VER_ID}"
            echo "    Remote production: ${PROD_VER_ID}"
            
            if [ "${PROD_VER_ID}" -gt "${DEV_VER_ID}" ]; then
                echo -e "    ${RED}❌ Remote production has NEWER version${NC}"
            elif [ "${PROD_VER_ID}" -eq "${DEV_VER_ID}" ]; then
                echo "    ✅ BCW databases have SAME version"
            else
                echo -e "    ${YELLOW}ℹ️  Local development has NEWER version${NC}"
            fi
        else
            echo "  ✅ BCW databases have SAME scrape version"
        fi
    else
        echo -e "  ${GREEN}✅ Development has NEWER scrape data (${DEV_VERSION} vs ${PROD_VERSION})${NC}"
        echo -e "  ${GREEN}   This is expected after prepare_development syncs from API${NC}"
        
        # Check if local data exists in development (indicating it was restored)
        DEV_LOCAL_COUNT=$(psql ${SCENARIO_NAME}_development -t -c "SELECT COUNT(*) FROM table_locals;" 2>/dev/null | xargs)
        if [ "${DEV_LOCAL_COUNT}" -gt 0 ]; then
            echo -e "  ${GREEN}✅ Production local data was preserved (${DEV_LOCAL_COUNT} table_locals)${NC}"
        else
            echo -e "  ${YELLOW}⚠️  No local data found in development - may need to extract from production${NC}"
        fi
    fi
    echo ""
fi

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}END OF DATABASE STATE ANALYSIS${NC}"
echo -e "${CYAN}================================================${NC}"

