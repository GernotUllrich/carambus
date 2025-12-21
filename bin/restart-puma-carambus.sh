#!/bin/bash
# Restart Puma for carambus (new.carambus.de)

set -e

echo "=========================================="
echo "Restarting Puma for new.carambus.de"
echo "=========================================="
echo ""

PUMA_PID=$(ps aux | grep "puma.*carambus/shared" | grep -v grep | awk '{print $2}' | head -1)

if [ -n "$PUMA_PID" ]; then
    echo "1. Stopping existing Puma process (PID: $PUMA_PID)..."
    kill -TERM "$PUMA_PID" 2>/dev/null || kill -9 "$PUMA_PID" 2>/dev/null || true
    sleep 3
    
    # Check if still running
    if ps -p "$PUMA_PID" > /dev/null 2>&1; then
        echo "⚠️  Process still running, forcing kill..."
        kill -9 "$PUMA_PID" || true
        sleep 2
    fi
    echo "✅ Old process stopped"
else
    echo "ℹ️  No running Puma process found"
fi
echo ""

echo "2. Cleaning up old socket..."
SOCKET="/var/www/carambus/shared/sockets/puma-production.sock"
if [ -S "$SOCKET" ]; then
    rm -f "$SOCKET"
    echo "✅ Socket removed"
fi
echo ""

echo "3. Checking directory structure..."
mkdir -p /var/www/carambus/shared/log
mkdir -p /var/www/carambus/shared/pids
mkdir -p /var/www/carambus/shared/sockets
chown -R www-data:www-data /var/www/carambus/shared
echo "✅ Directories verified"
echo ""

echo "4. Starting Puma..."
cd /var/www/carambus/current

# Check if bundle is available
if [ ! -d "/var/www/carambus/shared/bundle" ]; then
    echo "❌ Bundle directory not found. Running bundle install..."
    bundle install --deployment --without development test
fi

# Set environment
export RAILS_ENV=production
export RACK_ENV=production

# Start Puma (using bundle exec pumactl for daemon mode)
echo "Starting Puma with config: /var/www/carambus/shared/config/puma.rb"

# Create a wrapper script to start Puma in the background
cat > /tmp/start_puma_carambus.sh << 'PUMA_SCRIPT'
#!/bin/bash
cd /var/www/carambus/current
export RAILS_ENV=production
export RACK_ENV=production
exec bundle exec puma -C /var/www/carambus/shared/config/puma.rb >> /var/www/carambus/shared/log/puma.log 2>> /var/www/carambus/shared/log/puma-error.log
PUMA_SCRIPT

chmod +x /tmp/start_puma_carambus.sh

# Start Puma in the background
nohup /tmp/start_puma_carambus.sh &

echo "✅ Puma start command executed (PID: $!)"
echo ""

echo "5. Waiting for Puma to start..."
sleep 5

# Check if socket was created
if [ -S "$SOCKET" ]; then
    echo "✅ Socket created successfully"
else
    echo "❌ Socket NOT created!"
    echo "Checking error log..."
    if [ -f "/var/www/carambus/shared/log/puma-error.log" ]; then
        tail -50 /var/www/carambus/shared/log/puma-error.log
    fi
    exit 1
fi
echo ""

echo "6. Checking Puma process..."
ps aux | grep "puma.*carambus/shared" | grep -v grep
echo ""

echo "7. Testing socket connection..."
sleep 2
if timeout 3 bash -c "echo 'GET / HTTP/1.0' | nc -U $SOCKET" > /dev/null 2>&1; then
    echo "✅ Socket is responding!"
else
    echo "⚠️  Socket connection test failed, but this might be normal"
    echo "Checking logs for errors..."
    if [ -f "/var/www/carambus/shared/log/puma-error.log" ]; then
        echo "=== Last 30 lines of puma-error.log ==="
        tail -30 /var/www/carambus/shared/log/puma-error.log
    fi
    if [ -f "/var/www/carambus/current/log/production.log" ]; then
        echo "=== Last 30 lines of production.log ==="
        tail -30 /var/www/carambus/current/log/production.log
    fi
fi
echo ""

echo "=========================================="
echo "Restart complete!"
echo "=========================================="
echo ""
echo "Please test: https://new.carambus.de"
echo ""
echo "If still having issues, check logs:"
echo "  tail -f /var/www/carambus/shared/log/puma.log"
echo "  tail -f /var/www/carambus/shared/log/puma-error.log"
echo "  tail -f /var/www/carambus/current/log/production.log"

