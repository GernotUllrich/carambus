#!/bin/bash
# Quick commands to find scraper IPs
# Copy individual commands to your server and run them
# Replace RAILS_ROOT with your actual path (e.g., /var/www/carambus_api/current)

RAILS_ROOT="/var/www/carambus_api/current"  # Change this to your Rails root
SCENARIO="carambus_api"  # Change this to your scenario name for nginx config

echo "=== SCRAPER IP ANALYSIS COMMANDS ==="
echo "Rails Root: $RAILS_ROOT"
echo "Log file: $RAILS_ROOT/log/nginx.access.log"
echo ""

echo "1. TOP 20 IPs BY REQUEST COUNT:"
echo "awk '{print \$1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -20"
echo ""

echo "2. IPs WITH MORE THAN 100 REQUESTS:"
echo "awk '{print \$1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '\$1 > 100 {print \$1, \$2}'"
echo ""

echo "3. SUSPICIOUS USER-AGENTS (BOTS):"
echo "grep -iE '(bot|crawler|spider|scraper|python|curl|wget)' $RAILS_ROOT/log/nginx.access.log | awk -F'\"' '{print \$6}' | sort | uniq -c | sort -rn | head -20"
echo ""

echo "4. MOST REQUESTED PATHS:"
echo "awk '{print \$7}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -30"
echo ""

echo "5. RECENT ACTIVITY (LAST 1000 REQUESTS):"
echo "tail -1000 $RAILS_ROOT/log/nginx.access.log | awk '{print \$1}' | sort | uniq -c | sort -rn | head -15"
echo ""

echo "6. GENERATE NGINX DENY RULES (>100 requests):"
echo "awk '{print \$1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '\$1 > 100 {print \"deny \"\$2\";\"}'"
echo ""

echo "7. CHECK ROBOTS.TXT COMPLIANCE:"
echo "# IPs that checked robots.txt:"
echo "grep 'robots.txt' $RAILS_ROOT/log/nginx.access.log | awk '{print \$1}' | sort -u | wc -l"
echo ""
echo "# Total unique IPs:"
echo "awk '{print \$1}' $RAILS_ROOT/log/nginx.access.log | sort -u | wc -l"
echo ""

echo "8. RESPONSE CODE DISTRIBUTION:"
echo "awk '{print \$9}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn"
echo ""

echo "9. TODAY'S ACTIVITY BY HOUR:"
echo "grep \"\$(date +%d/%b/%Y)\" $RAILS_ROOT/log/nginx.access.log | awk '{print \$4}' | cut -d: -f2 | sort | uniq -c"
echo ""

echo "10. SAVE HIGH-FREQUENCY IPs TO FILE (for blocking):"
echo "awk '{print \$1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '\$1 > 100 {print \"deny \"\$2\";\"}' > /tmp/scrapers_to_block.conf"
echo ""

echo "11. BLOCK IP SUBNET (e.g., 47.79.x.x):"
echo "echo 'deny 47.79.0.0/16;' | sudo tee -a /etc/nginx/conf.d/${SCENARIO}_blocklist.conf"
echo ""

echo "=== TO APPLY BLOCKS ==="
echo "sudo cp /tmp/scrapers_to_block.conf /etc/nginx/conf.d/${SCENARIO}_blocklist.conf"
echo "# Or append to existing blocklist:"
echo "cat /tmp/scrapers_to_block.conf | sudo tee -a /etc/nginx/conf.d/${SCENARIO}_blocklist.conf"
echo ""
echo "# Test and reload nginx:"
echo "sudo nginx -t"
echo "sudo systemctl reload nginx"
echo ""

