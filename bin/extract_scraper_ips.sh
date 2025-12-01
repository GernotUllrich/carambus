#!/bin/bash
# Quick script to extract likely scraper IPs from nginx logs
# Usage: ./bin/extract_scraper_ips.sh [rails_root_path] [min_requests]

# Determine RAILS_ROOT
if [ -n "$1" ] && [ -d "$1" ]; then
    RAILS_ROOT="$1"
    MIN_REQUESTS=${2:-100}
elif [ -d "/var/www/carambus_api/current" ]; then
    RAILS_ROOT="/var/www/carambus_api/current"
    MIN_REQUESTS=${1:-100}
elif [ -d "/var/www/carambus_bcw/current" ]; then
    RAILS_ROOT="/var/www/carambus_bcw/current"
    MIN_REQUESTS=${1:-100}
else
    # Try to detect from script location
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    RAILS_ROOT="$(dirname "$SCRIPT_DIR")"
    MIN_REQUESTS=${1:-100}
fi

LOG_FILE="${RAILS_ROOT}/log/nginx.access.log"

echo "Extracting IPs with more than $MIN_REQUESTS requests"
echo "Rails Root: $RAILS_ROOT"
echo "Log file: $LOG_FILE"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found at $LOG_FILE"
    echo ""
    echo "Usage:"
    echo "  ./bin/extract_scraper_ips.sh [rails_root_path] [min_requests]"
    echo ""
    echo "Examples:"
    echo "  ./bin/extract_scraper_ips.sh /var/www/carambus_api/current 100"
    echo "  ./bin/extract_scraper_ips.sh 150  # uses auto-detected RAILS_ROOT"
    echo ""
    echo "Or run this command on your server:"
    echo ""
    echo "awk '{print \$1}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '\$1 > $MIN_REQUESTS {print \$2, \"(\"\$1\" requests)\"}'"
    echo ""
    echo "To save to a file for blocking:"
    echo "awk '{print \$1}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '\$1 > $MIN_REQUESTS {print \"deny \"\$2\";\"}' > /tmp/blocklist.conf"
    exit 1
fi

# Extract high-frequency IPs
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | awk -v min=$MIN_REQUESTS '$1 > min {print $2, "("$1" requests)"}'

echo ""
echo "To generate nginx deny rules, run:"
echo "awk '{print \$1}' $LOG_FILE | sort | uniq -c | sort -rn | awk '\$1 > $MIN_REQUESTS {print \"deny \"\$2\";\"}'"

