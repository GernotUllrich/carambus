#!/bin/bash
# Fix Puma configuration - remove problematic TCP bind on port 81

echo "=========================================="
echo "Fixing Puma Configuration"
echo "=========================================="
echo ""

PUMA_CONFIG="/var/www/carambus/shared/config/puma.rb"

echo "1. Backing up current configuration..."
cp "$PUMA_CONFIG" "$PUMA_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"
echo ""

echo "2. Removing TCP bind on port 81..."
# Comment out or remove the TCP bind line
sed -i '/bind "tcp:\/\/127.0.0.1:81"/d' "$PUMA_CONFIG"
echo "✅ TCP bind removed"
echo ""

echo "3. Verifying configuration..."
echo "=== Current Puma Configuration ==="
cat "$PUMA_CONFIG"
echo ""

echo "4. Stopping current Puma process..."
PUMA_PID=$(ps aux | grep "puma.*carambus/shared" | grep -v grep | awk '{print $2}' | head -1)
if [ -n "$PUMA_PID" ]; then
    kill -TERM "$PUMA_PID" 2>/dev/null || kill -9 "$PUMA_PID" 2>/dev/null || true
    sleep 3
    echo "✅ Puma stopped"
else
    echo "ℹ️  No running Puma process found"
fi
echo ""

echo "5. Cleaning up socket..."
rm -f /var/www/carambus/shared/sockets/puma-production.sock
echo "✅ Socket cleaned"
echo ""

echo "6. Starting Puma with fixed configuration..."
cd /var/www/carambus/current
export RAILS_ENV=production
export RACK_ENV=production

# Start Puma in background
nohup bundle exec puma -C "$PUMA_CONFIG" >> /var/www/carambus/shared/log/puma.log 2>> /var/www/carambus/shared/log/puma-error.log &
PUMA_PID=$!
echo "✅ Puma started (PID: $PUMA_PID)"
echo ""

echo "7. Waiting for socket to be created..."
for i in {1..15}; do
    if [ -S /var/www/carambus/shared/sockets/puma-production.sock ]; then
        echo "✅ Socket created successfully!"
        ls -la /var/www/carambus/shared/sockets/puma-production.sock
        break
    fi
    echo "   Waiting... ($i/15)"
    sleep 2
done
echo ""

echo "8. Checking Puma process..."
ps aux | grep "puma.*carambus/shared" | grep -v grep
echo ""

echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "Please test: https://new.carambus.de"



