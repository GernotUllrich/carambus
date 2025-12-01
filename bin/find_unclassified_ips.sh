#!/bin/bash
# Script to find IPs that are not in WHITELIST or BLACKLIST
# Usage: ./bin/find_unclassified_ips.sh [rails_root_path] [min_requests]

set -e

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
TMP_WHITELIST="/tmp/whitelist_$$.txt"
TMP_BLACKLIST="/tmp/blacklist_$$.txt"
TMP_UNCLASSIFIED="/tmp/unclassified_$$.txt"

# Extract all IPs from log with request counts (filter by min_requests)
echo "Extracting IPs from log (minimum $MIN_REQUESTS requests)..."
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | awk -v min=$MIN_REQUESTS '$1 >= min {print $2, $1}' > "$TMP_ALL_IPS"

TOTAL_IPS=$(wc -l < "$TMP_ALL_IPS" | tr -d ' ')
echo "Found $TOTAL_IPS unique IPs with at least $MIN_REQUESTS requests"
echo ""

# Prepare whitelist (extract IPs, handle comments and CIDR notation)
if [ -f "$WHITELIST" ]; then
    # Extract IPs from whitelist, remove comments, handle CIDR
    grep -v '^#' "$WHITELIST" 2>/dev/null | grep -v '^[[:space:]]*$' | awk '{print $1}' | sed 's|/.*||' > "$TMP_WHITELIST" || touch "$TMP_WHITELIST"
    WHITELIST_COUNT=$(wc -l < "$TMP_WHITELIST" | tr -d ' ')
    echo "Loaded $WHITELIST_COUNT entries from WHITELIST"
else
    touch "$TMP_WHITELIST"
    echo "Warning: WHITELIST not found at $WHITELIST"
fi

# Prepare blacklist (extract IPs, handle comments and CIDR notation)
if [ -f "$BLACKLIST" ]; then
    # Extract IPs from blacklist, remove comments, handle CIDR
    grep -v '^#' "$BLACKLIST" 2>/dev/null | grep -v '^[[:space:]]*$' | awk '{print $1}' | sed 's|/.*||' > "$TMP_BLACKLIST" || touch "$TMP_BLACKLIST"
    BLACKLIST_COUNT=$(wc -l < "$TMP_BLACKLIST" | tr -d ' ')
    echo "Loaded $BLACKLIST_COUNT entries from BLACKLIST"
else
    touch "$TMP_BLACKLIST"
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
    # Check if IP is in whitelist or blacklist
    IN_WHITELIST=$(grep -Fx "$ip" "$TMP_WHITELIST" 2>/dev/null || true)
    IN_BLACKLIST=$(grep -Fx "$ip" "$TMP_BLACKLIST" 2>/dev/null || true)
    
    if [ -z "$IN_WHITELIST" ] && [ -z "$IN_BLACKLIST" ]; then
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
    echo "Whitelisted IPs: $WHITELIST_COUNT"
    echo "Blacklisted IPs: $BLACKLIST_COUNT"
    echo "Unclassified IPs: $UNCLASSIFIED_COUNT"
    echo ""
    
    # Show user-agents for unclassified IPs
    echo "========================================="
    echo "User-Agents of Unclassified IPs:"
    echo "========================================="
    echo ""
    
    while read -r ip count; do
        echo "--- IP: $ip ($count requests) ---"
        grep "^$ip " "$LOG_FILE" | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -3
        echo ""
    done < "$TMP_UNCLASSIFIED" | head -50
    
    echo ""
    echo "========================================="
    echo "Suggested Actions:"
    echo "========================================="
    echo ""
    echo "To add IPs to WHITELIST:"
    echo "  echo 'IP_ADDRESS  # comment' | sudo tee -a $WHITELIST"
    echo ""
    echo "To add IPs to BLACKLIST:"
    echo "  echo 'IP_ADDRESS  # comment' | sudo tee -a $BLACKLIST"
    echo ""
    echo "To add IP ranges (CIDR notation):"
    echo "  echo '47.79.0.0/16  # Block entire subnet' | sudo tee -a $BLACKLIST"
    echo ""
    echo "To export unclassified IPs:"
    echo "  $0 $RAILS_ROOT $MIN_REQUESTS > /tmp/unclassified_report.txt"
    echo ""
else
    echo "No unclassified IPs found."
    echo ""
    echo "All IPs in the log are either whitelisted or blacklisted."
fi

# Cleanup
rm -f "$TMP_ALL_IPS" "$TMP_WHITELIST" "$TMP_BLACKLIST" "$TMP_UNCLASSIFIED"

echo "========================================="
echo "Analysis complete!"
echo "========================================="

