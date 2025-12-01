#!/bin/bash
# Script to help block scraper IPs in nginx
# Usage: ./bin/block_scraper_ips.sh <scenario_name> <ip_address>

set -e

SCENARIO=${1}
IP_TO_BLOCK=${2}

if [ -z "$SCENARIO" ] || [ -z "$IP_TO_BLOCK" ]; then
    echo "Usage: $0 <scenario_name> <ip_address>"
    echo "Example: $0 carambus_api 123.45.67.89"
    echo ""
    echo "This script generates nginx configuration to block an IP."
    echo "You need to add it to your nginx config and reload nginx."
    exit 1
fi

NGINX_CONF="/etc/nginx/sites-available/${SCENARIO}"
BLOCKLIST_FILE="/etc/nginx/conf.d/${SCENARIO}_blocklist.conf"

echo "========================================="
echo "IP Blocking Configuration Generator"
echo "========================================="
echo "Scenario: $SCENARIO"
echo "IP to block: $IP_TO_BLOCK"
echo ""

echo "Add this to your nginx configuration:"
echo ""
echo "# --- Configuration to add ---"
echo ""
echo "# Option 1: Add to $BLOCKLIST_FILE"
echo "# Create or append to the file:"
cat << EOF
# Blocked IPs for $SCENARIO
deny $IP_TO_BLOCK;
EOF

echo ""
echo "# Then include it in your nginx config's server block:"
echo "# Add this line inside the server { } block:"
echo "include /etc/nginx/conf.d/${SCENARIO}_blocklist.conf;"
echo ""
echo "# Option 2: Add directly to nginx config at $NGINX_CONF"
echo "# Add this inside the server { } block:"
echo "deny $IP_TO_BLOCK;"
echo ""
echo "# After making changes, test and reload nginx:"
echo "sudo nginx -t"
echo "sudo systemctl reload nginx"
echo ""
echo "========================================="

# Create a template blocklist configuration
cat << EOF

# To create the blocklist file on the server, run:
# sudo tee $BLOCKLIST_FILE << 'ENDBLOCK'
# Blocked IPs for $SCENARIO - $(date)
deny $IP_TO_BLOCK;
# ENDBLOCK

# To block entire networks:
# deny 123.45.0.0/16;

# To check if IP is blocked:
# curl -I http://your-server.com -H "X-Forwarded-For: $IP_TO_BLOCK"
EOF

