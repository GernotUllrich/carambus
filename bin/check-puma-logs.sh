#!/bin/bash
# Check Puma logs for carambus

echo "=========================================="
echo "Puma Logs for new.carambus.de"
echo "=========================================="
echo ""

echo "1. Checking puma-error.log:"
if [ -f "/var/www/carambus/shared/log/puma-error.log" ]; then
    echo "=== Last 50 lines of puma-error.log ==="
    tail -50 /var/www/carambus/shared/log/puma-error.log
else
    echo "❌ File not found: /var/www/carambus/shared/log/puma-error.log"
fi
echo ""
echo ""

echo "2. Checking puma.log:"
if [ -f "/var/www/carambus/shared/log/puma.log" ]; then
    echo "=== Last 50 lines of puma.log ==="
    tail -50 /var/www/carambus/shared/log/puma.log
else
    echo "❌ File not found: /var/www/carambus/shared/log/puma.log"
fi
echo ""
echo ""

echo "3. Checking production.log:"
if [ -f "/var/www/carambus/current/log/production.log" ]; then
    echo "=== Last 50 lines of production.log ==="
    tail -50 /var/www/carambus/current/log/production.log
else
    echo "❌ File not found: /var/www/carambus/current/log/production.log"
fi
echo ""
echo ""

echo "4. Checking nohup.out:"
if [ -f "$HOME/nohup.out" ]; then
    echo "=== nohup.out ==="
    cat "$HOME/nohup.out"
else
    echo "❌ File not found: nohup.out"
fi
echo ""
echo ""

echo "5. Checking current Puma processes:"
ps aux | grep "puma.*carambus" | grep -v grep
echo ""

echo "6. Checking socket status:"
if [ -S "/var/www/carambus/shared/sockets/puma-production.sock" ]; then
    echo "✅ Socket exists"
    ls -la /var/www/carambus/shared/sockets/puma-production.sock
else
    echo "❌ Socket does not exist"
fi
echo ""

echo "=========================================="
echo "Log check complete"
echo "=========================================="


