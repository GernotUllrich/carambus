#!/bin/bash
# Diagnose Script for nginx configuration issues on Hetzner API server

echo "=========================================="
echo "Nginx Configuration Diagnosis"
echo "=========================================="
echo ""

echo "1. Checking nginx service status:"
sudo systemctl status nginx --no-pager
echo ""

echo "2. Testing nginx configuration:"
sudo nginx -t
echo ""

echo "3. Checking enabled sites:"
echo "Sites in /etc/nginx/sites-enabled/:"
ls -la /etc/nginx/sites-enabled/
echo ""

echo "4. Checking if our configurations exist:"
echo ""
echo "--- api.carambus.de config ---"
if [ -f /etc/nginx/sites-enabled/api.carambus.de ]; then
    echo "✅ api.carambus.de exists"
    echo "First 30 lines:"
    head -30 /etc/nginx/sites-enabled/api.carambus.de
else
    echo "❌ api.carambus.de MISSING"
fi
echo ""

echo "--- carambus config ---"
if [ -f /etc/nginx/sites-enabled/carambus ]; then
    echo "✅ carambus exists"
    echo "First 30 lines:"
    head -30 /etc/nginx/sites-enabled/carambus
else
    echo "❌ carambus MISSING"
fi
echo ""

echo "5. Checking for port conflicts:"
sudo netstat -tlnp | grep ':80\|:443\|:3000\|:3001'
echo ""

echo "6. Checking nginx error logs (last 20 lines):"
if [ -f /var/log/nginx/error.log ]; then
    echo "--- Main error log ---"
    sudo tail -20 /var/log/nginx/error.log
fi
echo ""

if [ -f /var/log/nginx/api.carambus.de_error.log ]; then
    echo "--- api.carambus.de error log ---"
    sudo tail -20 /var/log/nginx/api.carambus.de_error.log
fi
echo ""

if [ -f /var/log/nginx/carambus.de_error.log ]; then
    echo "--- carambus.de error log ---"
    sudo tail -20 /var/log/nginx/carambus.de_error.log
fi
echo ""

echo "7. Checking Puma processes:"
ps aux | grep puma | grep -v grep
echo ""

echo "8. Checking if Puma sockets/ports are listening:"
if [ -S /var/www/carambus/shared/sockets/puma-production.sock ]; then
    echo "✅ Puma socket /var/www/carambus/shared/sockets/puma-production.sock exists"
    ls -la /var/www/carambus/shared/sockets/puma-production.sock
else
    echo "❌ Puma socket /var/www/carambus/shared/sockets/puma-production.sock MISSING"
fi
echo ""
if [ -S /var/www/carambus_api/shared/sockets/puma-production.sock ]; then
    echo "✅ Puma socket /var/www/carambus_api/shared/sockets/puma-production.sock exists"
    ls -la /var/www/carambus_api/shared/sockets/puma-production.sock
else
    echo "❌ Puma socket /var/www/carambus_api/shared/sockets/puma-production.sock MISSING"
fi
echo ""

echo "9. Checking systemd services:"
echo "--- puma-carambus_api service ---"
sudo systemctl status puma-carambus_api --no-pager | head -15
echo ""

echo "--- puma-carambus service ---"
sudo systemctl status puma-carambus --no-pager | head -15
echo ""

echo "=========================================="
echo "Diagnosis complete"
echo "=========================================="
