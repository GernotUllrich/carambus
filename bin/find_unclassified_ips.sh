#!/bin/bash
# Script to find IPs that are not in WHITELIST or BLACKLIST
# Supports CIDR notation (e.g., 192.168.2.0/24)
# Usage: ./bin/find_unclassified_ips.sh [rails_root_path] [min_requests]

set -e

# Function to check if an IP is in a CIDR range
ip_in_cidr() {
    local ip=$1
    local cidr=$2
    
    # If no CIDR notation, do exact match
    if [[ ! "$cidr" =~ / ]]; then
        [ "$ip" = "$cidr" ] && return 0 || return 1
    fi
    
    # Use ipcalc if available, otherwise use python
    if command -v ipcalc >/dev/null 2>&1; then
        ipcalc -c "$ip" "$cidr" >/dev/null 2>&1 && return 0 || return 1
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import ipaddress
import sys
try:
    ip_obj = ipaddress.ip_address('$ip')
    network = ipaddress.ip_network('$cidr', strict=False)
    sys.exit(0 if ip_obj in network else 1)
except:
    sys.exit(1)
" && return 0 || return 1
    else
        # Fallback: simple subnet matching for /24, /16, /8
        local network="${cidr%/*}"
        local prefix="${cidr#*/}"
        
        case $prefix in
            8)
                [ "${ip%%.*}" = "${network%%.*}" ] && return 0
                ;;
            16)
                local ip_first_two="${ip%.*.*}"
                local net_first_two="${network%.*.*}"
                [ "$ip_first_two" = "$net_first_two" ] && return 0
                ;;
            24)
                local ip_first_three="${ip%.*}"
                local net_first_three="${network%.*}"
                [ "$ip_first_three" = "$net_first_three" ] && return 0
                ;;
            32)
                [ "$ip" = "$network" ] && return 0
                ;;
        esac
        return 1
    fi
}

# Function to check if IP matches any entry in a list file
ip_matches_list() {
    local ip=$1
    local list_file=$2
    
    while IFS= read -r entry; do
        # Skip empty lines and comments
        [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
        
        # Extract just the IP/CIDR (first field)
        local cidr=$(echo "$entry" | awk '{print $1}')
        
        # Check if IP matches
        if ip_in_cidr "$ip" "$cidr"; then
            return 0
        fi
    done < "$list_file"
    
    return 1
}

# Determine RAILS_ROOT
if [ -n "$1" ] && [ -d "$1" ]; then
    RAILS_ROOT="$1"
    MIN_REQUESTS=${2:-10}
elif [ -d "/var/www/carambus_api/current" ]; then
    RAILS_ROOT="/var/www/carambus_api/current"
    MIN_REQUESTS=${1:-10}
elif [ -d "/var/www/carambus_bcw/current" ]; then
    RAILS_ROOT="/var/www/carambus_bcw/current"
    MIN_REQUESTS=${1:-10}
else
    # Try to detect from script location
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    RAILS_ROOT="$(dirname "$SCRIPT_DIR")"
    MIN_REQUESTS=${1:-10}
fi

LOG_FILE="${RAILS_ROOT}/log/nginx.access.log"
WHITELIST="/root/WHITELIST"
BLACKLIST="/root/BLACKLIST"

echo "========================================="
echo "Unclassified IP Address Finder"
echo "========================================="
echo "Rails Root: $RAILS_ROOT"
echo "Log file: $LOG_FILE"
echo "Whitelist: $WHITELIST"
echo "Blacklist: $BLACKLIST"
echo "Min requests threshold: $MIN_REQUESTS"
echo ""

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found at $LOG_FILE"
    echo ""
    echo "Usage:"
    echo "  ./bin/find_unclassified_ips.sh [rails_root_path] [min_requests]"
    echo ""
    echo "Examples:"
    echo "  ./bin/find_unclassified_ips.sh /var/www/carambus_api/current 10"
    echo "  ./bin/find_unclassified_ips.sh 20  # uses auto-detected RAILS_ROOT"
    exit 1
fi

# Create temporary files
TMP_ALL_IPS="/tmp/all_ips_$$.txt"
TMP_UNCLASSIFIED="/tmp/unclassified_$$.txt"

# Extract all IPs from log with request counts (filter by min_requests)
echo "Extracting IPs from log (minimum $MIN_REQUESTS requests)..."
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | awk -v min=$MIN_REQUESTS '$1 >= min {print $2, $1}' > "$TMP_ALL_IPS"

TOTAL_IPS=$(wc -l < "$TMP_ALL_IPS" | tr -d ' ')
echo "Found $TOTAL_IPS unique IPs with at least $MIN_REQUESTS requests"
echo ""

# Check if whitelist exists
WHITELIST_COUNT=0
if [ -f "$WHITELIST" ]; then
    WHITELIST_COUNT=$(grep -v '^#' "$WHITELIST" 2>/dev/null | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
    echo "Loaded $WHITELIST_COUNT entries from WHITELIST"
else
    echo "Warning: WHITELIST not found at $WHITELIST"
fi

# Check if blacklist exists
BLACKLIST_COUNT=0
if [ -f "$BLACKLIST" ]; then
    BLACKLIST_COUNT=$(grep -v '^#' "$BLACKLIST" 2>/dev/null | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
    echo "Loaded $BLACKLIST_COUNT entries from BLACKLIST"
else
    echo "Warning: BLACKLIST not found at $BLACKLIST"
fi

echo ""
echo "========================================="
echo "Unclassified IPs (not in WHITELIST or BLACKLIST):"
echo "========================================="
echo ""

# Find IPs not in either list
> "$TMP_UNCLASSIFIED"

while read -r ip count; do
    IN_WHITELIST=false
    IN_BLACKLIST=false
    
    # Check whitelist
    if [ -f "$WHITELIST" ]; then
        if ip_matches_list "$ip" "$WHITELIST"; then
            IN_WHITELIST=true
        fi
    fi
    
    # Check blacklist
    if [ -f "$BLACKLIST" ]; then
        if ip_matches_list "$ip" "$BLACKLIST"; then
            IN_BLACKLIST=true
        fi
    fi
    
    # If not in either list, add to unclassified
    if [ "$IN_WHITELIST" = false ] && [ "$IN_BLACKLIST" = false ]; then
        echo "$ip $count" >> "$TMP_UNCLASSIFIED"
    fi
done < "$TMP_ALL_IPS"

# Display results
if [ -s "$TMP_UNCLASSIFIED" ]; then
    UNCLASSIFIED_COUNT=$(wc -l < "$TMP_UNCLASSIFIED" | tr -d ' ')
    echo "Found $UNCLASSIFIED_COUNT unclassified IPs:"
    echo ""
    printf "%-20s %s\n" "IP Address" "Request Count"
    printf "%-20s %s\n" "--------------------" "-------------"
    
    while read -r ip count; do
        printf "%-20s %s\n" "$ip" "$count"
    done < "$TMP_UNCLASSIFIED"
    
    echo ""
    echo "========================================="
    echo "Summary:"
    echo "========================================="
    echo "Total IPs in log (>=$MIN_REQUESTS req): $TOTAL_IPS"
    echo "Whitelisted entries: $WHITELIST_COUNT"
    echo "Blacklisted entries: $BLACKLIST_COUNT"
    echo "Unclassified IPs: $UNCLASSIFIED_COUNT"
    echo ""
    
    # Show user-agents for unclassified IPs
    echo "========================================="
    echo "User-Agents of Unclassified IPs:"
    echo "========================================="
    echo ""
    
    local count=0
    while read -r ip req_count; do
        if [ $count -ge 15 ]; then
            echo "... (showing first 15 IPs only, $((UNCLASSIFIED_COUNT - 15)) more)"
            break
        fi
        echo "--- IP: $ip ($req_count requests) ---"
        grep "^$ip " "$LOG_FILE" | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -3
        echo ""
        count=$((count + 1))
    done < "$TMP_UNCLASSIFIED"
    
    echo ""
    echo "========================================="
    echo "Suggested Actions:"
    echo "========================================="
    echo ""
    echo "To add IPs to WHITELIST (for trusted sources):"
    echo "  echo '192.168.2.0/24  # Local network' | sudo tee -a $WHITELIST"
    echo "  echo '123.45.67.89    # Office IP' | sudo tee -a $WHITELIST"
    echo ""
    echo "To add IPs to BLACKLIST (for blockers):"
    echo "  echo '47.79.0.0/16    # Scraper subnet' | sudo tee -a $BLACKLIST"
    echo "  echo '12.34.56.78     # Bad actor' | sudo tee -a $BLACKLIST"
    echo ""
    echo "CIDR notation examples:"
    echo "  192.168.1.0/24    # All IPs from 192.168.1.0 to 192.168.1.255"
    echo "  10.0.0.0/8        # All IPs from 10.0.0.0 to 10.255.255.255"
    echo "  172.16.0.0/12     # Private network range"
    echo "  47.79.0.0/16      # Block 47.79.0.0 to 47.79.255.255"
    echo ""
    echo "After updating BLACKLIST, apply to nginx:"
    echo "  grep -v '^#' $BLACKLIST | grep -v '^\$' | awk '{print \"deny \"\$1\";\"}' | sudo tee /etc/nginx/conf.d/carambus_api_blocklist.conf"
    echo "  sudo nginx -t && sudo systemctl reload nginx"
    echo ""
else
    echo "No unclassified IPs found."
    echo ""
    echo "All IPs in the log are either whitelisted or blacklisted."
    echo ""
    echo "Summary:"
    echo "  Total IPs in log: $TOTAL_IPS"
    echo "  Whitelisted entries: $WHITELIST_COUNT"
    echo "  Blacklisted entries: $BLACKLIST_COUNT"
fi

# Cleanup
rm -f "$TMP_ALL_IPS" "$TMP_UNCLASSIFIED"

echo "========================================="
echo "Analysis complete!"
echo "========================================="
