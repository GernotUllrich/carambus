#!/bin/bash
# Script to analyze scraping activity from nginx access logs
# Usage: ./bin/analyze_scrapers.sh [rails_root_path]

set -e

# Determine RAILS_ROOT
if [ -n "$1" ]; then
    RAILS_ROOT="$1"
elif [ -d "/var/www/carambus_api/current" ]; then
    RAILS_ROOT="/var/www/carambus_api/current"
elif [ -d "/var/www/carambus_bcw/current" ]; then
    RAILS_ROOT="/var/www/carambus_bcw/current"
else
    # Try to detect from script location
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    RAILS_ROOT="$(dirname "$SCRIPT_DIR")"
fi

LOG_FILE="${RAILS_ROOT}/log/nginx.access.log"
TOP_N=${2:-20}

echo "========================================="
echo "Scraping Activity Analysis"
echo "========================================="
echo "Rails Root: $RAILS_ROOT"
echo "Log file: $LOG_FILE"
echo ""

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found at $LOG_FILE"
    echo ""
    echo "This script analyzes nginx.access.log in RAILS_ROOT/log/"
    echo ""
    echo "Usage examples:"
    echo "  ./bin/analyze_scrapers.sh /var/www/carambus_api/current"
    echo "  ./bin/analyze_scrapers.sh /var/www/carambus_bcw/current"
    echo ""
    echo "Or run commands manually on your server:"
    echo ""
    cat << 'EOF'
# Replace RAILS_ROOT with your actual path (e.g., /var/www/carambus_api/current)

# 1. Top IP addresses by request count
echo "Top IP addresses by request count:"
awk '{print $1}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -20

# 2. Top User-Agents (to identify bots)
echo -e "\nTop User-Agents:"
awk -F'"' '{print $6}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -20

# 3. Requests to robots.txt (who's checking it?)
echo -e "\nRequests to robots.txt:"
grep "robots.txt" RAILS_ROOT/log/nginx.access.log | awk '{print $1}' | sort | uniq -c | sort -rn

# 4. Most requested paths (to see what they're scraping)
echo -e "\nMost requested paths:"
awk '{print $7}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -30

# 5. Suspicious patterns (high frequency requests)
echo -e "\nIPs with more than 100 requests:"
awk '{print $1}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '$1 > 100 {print $1, $2}'

# 6. Requests by HTTP method
echo -e "\nRequests by HTTP method:"
awk '{print $6}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn

# 7. Response codes (lots of 404s might indicate scanning)
echo -e "\nResponse codes:"
awk '{print $9}' RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn

# 8. Identify common bot patterns (adjust as needed)
echo -e "\nKnown bot User-Agents:"
grep -iE "(bot|crawler|spider|scraper|python|curl|wget|http)" RAILS_ROOT/log/nginx.access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -20

# 9. IPs that ignore robots.txt (accessed site without checking robots.txt first)
echo -e "\nAnalyzing robots.txt compliance..."
echo "IPs that accessed robots.txt:"
grep "robots.txt" RAILS_ROOT/log/nginx.access.log | awk '{print $1}' | sort -u > /tmp/robots_checked.txt
echo "Total unique IPs that checked robots.txt: $(wc -l < /tmp/robots_checked.txt)"

echo -e "\nAll unique IPs:"
awk '{print $1}' RAILS_ROOT/log/nginx.access.log | sort -u > /tmp/all_ips.txt
echo "Total unique IPs: $(wc -l < /tmp/all_ips.txt)"

echo -e "\nIPs that did NOT check robots.txt (potential violators):"
comm -23 /tmp/all_ips.txt /tmp/robots_checked.txt | head -30

# 10. Recent activity (last 1000 lines)
echo -e "\nRecent high-frequency IPs (last 1000 lines):"
tail -1000 RAILS_ROOT/log/nginx.access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -15

# 11. Time-based analysis (requests per hour)
echo -e "\nRequests by hour (today):"
grep "$(date +%d/%b/%Y)" RAILS_ROOT/log/nginx.access.log | awk '{print $4}' | cut -d: -f2 | sort | uniq -c

# To block an IP or subnet, add to nginx config:
# deny IP_ADDRESS;
# deny 47.79.0.0/16;

EOF
    
    echo ""
    exit 1
fi

# If running locally with access to logs, execute the analysis
echo "=== 1. Top IP addresses by request count ==="
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -${TOP_N}

echo ""
echo "=== 2. Top User-Agents ==="
awk -F'"' '{print $6}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -${TOP_N}

echo ""
echo "=== 3. Requests to robots.txt ==="
grep "robots.txt" "$LOG_FILE" 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn || echo "No robots.txt requests found"

echo ""
echo "=== 4. Most requested paths ==="
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -30

echo ""
echo "=== 5. IPs with more than 100 requests ==="
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | awk '$1 > 100 {print $1, $2}'

echo ""
echo "=== 6. Known bot User-Agents ==="
grep -iE "(bot|crawler|spider|scraper|python|curl|wget|http)" "$LOG_FILE" 2>/dev/null | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -${TOP_N} || echo "No obvious bots found"

echo ""
echo "========================================="
echo "Analysis complete!"
echo "========================================="

