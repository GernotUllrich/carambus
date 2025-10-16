#!/bin/bash
# Diagnostic script for scoreboard issues
# Usage: ./diagnose-scoreboard.sh <server_ip> <server_port> <client_ip>

SERVER_IP="${1:-192.168.2.210}"
SERVER_PORT="${2:-8910}"
CLIENT_IP="${3:-192.168.2.214}"

echo "🔍 Scoreboard Diagnostic Report"
echo "================================"
echo "Server: $SERVER_IP:$SERVER_PORT"
echo "Client: $CLIENT_IP"
echo ""

echo "1. Checking if scoreboard user exists in database..."
ssh -p "$SERVER_PORT" www-data@"$SERVER_IP" "cd /var/www/carambus_bcw/current && RAILS_ENV=production bundle exec rails runner \"puts User.find_by(email: 'scoreboard@carambus.de') ? '✅ Scoreboard user exists' : '❌ Scoreboard user NOT found'\""
echo ""

echo "2. Checking sidebar_controller.js on server..."
ssh -p "$SERVER_PORT" www-data@"$SERVER_IP" "grep -A 3 'isScoreboard' /var/www/carambus_bcw/current/app/javascript/controllers/sidebar_controller.js || echo '❌ isScoreboard check NOT found in source'"
echo ""

echo "3. Checking built JavaScript asset..."
ssh -p "$SERVER_PORT" www-data@"$SERVER_IP" "ls -lh /var/www/carambus_bcw/current/app/assets/builds/application.js"
echo ""

echo "4. Checking if built JS contains scoreboard logic..."
ssh -p "$SERVER_PORT" www-data@"$SERVER_IP" "grep 'scoreboard@carambus.de' /var/www/carambus_bcw/current/app/assets/builds/application.js && echo '✅ Scoreboard check found in built JS' || echo '❌ Scoreboard check NOT in built JS'"
echo ""

echo "5. Checking Chromium status on client..."
ssh -p 22 pi@"$CLIENT_IP" "pgrep -a chromium | head -1 || echo '❌ Chromium not running'"
echo ""

echo "6. Checking scoreboard service status..."
ssh -p 22 pi@"$CLIENT_IP" "sudo systemctl is-active scoreboard-kiosk && echo '✅ Service active' || echo '❌ Service not active'"
echo ""

echo "7. Checking browser cache on client..."
ssh -p 22 pi@"$CLIENT_IP" "ls -lh /tmp/chromium-scoreboard/ 2>/dev/null | head -5 || echo '❌ No cache directory'"
echo ""

echo "📋 Suggestions:"
echo "- If scoreboard user missing: Create it in Rails console"
echo "- If JS not built correctly: Run 'yarn build' on server"
echo "- If cache issues: Clear with 'ssh pi@$CLIENT_IP \"rm -rf /tmp/chromium-scoreboard && sudo systemctl restart scoreboard-kiosk\"'"
echo "- Check browser console: Add logging to see what userEmail is being detected"

