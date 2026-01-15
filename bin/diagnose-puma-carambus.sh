#!/bin/bash
# Detailed diagnosis for carambus (carambus.de) Puma connection issues

echo "=========================================="
echo "Puma Diagnosis for carambus.de"
echo "=========================================="
echo ""

echo "1. Checking Puma socket path:"
SOCKET_PATH="/var/www/carambus/shared/sockets/puma-production.sock"
if [ -S "$SOCKET_PATH" ]; then
    echo "✅ Socket exists: $SOCKET_PATH"
    ls -la "$SOCKET_PATH"
    echo "Socket permissions and owner:"
    stat "$SOCKET_PATH"
else
    echo "❌ Socket NOT found: $SOCKET_PATH"
fi
echo ""

echo "2. Checking if socket directory exists:"
SOCKET_DIR="/var/www/carambus/shared/sockets"
if [ -d "$SOCKET_DIR" ]; then
    echo "✅ Socket directory exists: $SOCKET_DIR"
    ls -la "$SOCKET_DIR"
else
    echo "❌ Socket directory NOT found: $SOCKET_DIR"
    echo "Creating directory..."
    sudo mkdir -p "$SOCKET_DIR"
    sudo chown -R www-data:www-data "$SOCKET_DIR"
fi
echo ""

echo "3. Checking Puma processes for carambus:"
ps aux | grep -E "puma.*carambus[^_]|puma.*new\.carambus" | grep -v grep
echo ""

echo "4. Checking all Puma-related processes:"
ps aux | grep puma | grep -v grep
echo ""

echo "5. Checking Puma configuration:"
PUMA_CONFIG="/var/www/carambus/shared/config/puma.rb"
if [ -f "$PUMA_CONFIG" ]; then
    echo "✅ Puma config exists: $PUMA_CONFIG"
    echo "Content:"
    cat "$PUMA_CONFIG"
else
    echo "❌ Puma config NOT found: $PUMA_CONFIG"
fi
echo ""

echo "6. Checking for Puma PID file:"
PID_FILE="/var/www/carambus/shared/pids/puma.pid"
if [ -f "$PID_FILE" ]; then
    echo "✅ PID file exists: $PID_FILE"
    PID=$(cat "$PID_FILE")
    echo "PID: $PID"
    if ps -p "$PID" > /dev/null; then
        echo "✅ Process is running"
        ps -fp "$PID"
    else
        echo "❌ Process is NOT running (stale PID file)"
    fi
else
    echo "⚠️  PID file not found: $PID_FILE"
fi
echo ""

echo "7. Checking Puma state file:"
STATE_FILE="/var/www/carambus/shared/pids/puma.state"
if [ -f "$STATE_FILE" ]; then
    echo "✅ State file exists: $STATE_FILE"
    cat "$STATE_FILE"
else
    echo "⚠️  State file not found: $STATE_FILE"
fi
echo ""

echo "8. Checking recent Puma log:"
LOG_FILE="/var/www/carambus/shared/log/puma.log"
if [ -f "$LOG_FILE" ]; then
    echo "✅ Log file exists: $LOG_FILE"
    echo "Last 30 lines:"
    tail -30 "$LOG_FILE"
else
    echo "❌ Log file not found: $LOG_FILE"
fi
echo ""

echo "9. Checking production log:"
PROD_LOG="/var/www/carambus/current/log/production.log"
if [ -f "$PROD_LOG" ]; then
    echo "✅ Production log exists"
    echo "Last 20 lines:"
    tail -20 "$PROD_LOG"
else
    echo "⚠️  Production log not found: $PROD_LOG"
fi
echo ""

echo "10. Checking nginx error log for carambus.de:"
NGINX_ERROR="/var/log/carambus/error.log"
if [ -f "$NGINX_ERROR" ]; then
    echo "✅ Nginx error log exists"
    echo "Last 30 lines:"
    tail -30 "$NGINX_ERROR"
else
    echo "⚠️  Nginx error log not found: $NGINX_ERROR"
fi
echo ""

echo "11. Testing socket connection:"
if [ -S "$SOCKET_PATH" ]; then
    echo "Attempting to connect to socket..."
    timeout 2 bash -c "echo 'GET / HTTP/1.0' | nc -U $SOCKET_PATH" 2>&1 || echo "⚠️  Connection test inconclusive"
fi
echo ""

echo "12. Checking deployment status:"
if [ -d "/var/www/carambus/current" ]; then
    echo "✅ Current deployment exists"
    ls -la /var/www/carambus/
    echo ""
    echo "Current symlink points to:"
    readlink -f /var/www/carambus/current
else
    echo "❌ No current deployment found"
fi
echo ""

echo "=========================================="
echo "Diagnosis complete"
echo "=========================================="
echo ""
echo "Next steps if socket is missing:"
echo "  1. Check Puma configuration in shared/config/puma.rb"
echo "  2. Restart Puma: cd /var/www/carambus/current && bundle exec puma -C shared/config/puma.rb -d"
echo "  3. Or use systemd if configured: sudo systemctl restart carambus"





