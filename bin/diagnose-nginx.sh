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
echo "--- newapi.carambus.de config ---"
if [ -f /etc/nginx/sites-enabled/newapi.carambus.de ]; then
    echo "✅ newapi.carambus.de exists"
    echo "First 30 lines:"
    head -30 /etc/nginx/sites-enabled/newapi.carambus.de
else
    echo "❌ newapi.carambus.de MISSING"
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

if [ -f /var/log/nginx/newapi.carambus.de_error.log ]; then
    echo "--- newapi.carambus.de error log ---"
    sudo tail -20 /var/log/nginx/newapi.carambus.de_error.log
fi
echo ""

if [ -f /var/log/nginx/new.carambus.de_error.log ]; then
    echo "--- new.carambus.de error log ---"
    sudo tail -20 /var/log/nginx/new.carambus.de_error.log
fi
echo ""

echo "7. Checking Puma processes:"
ps aux | grep puma | grep -v grep
echo ""

echo "8. Checking if Puma sockets/ports are listening:"
if [ -S /tmp/puma.sock ]; then
    echo "✅ Puma socket /tmp/puma.sock exists"
    ls -la /tmp/puma.sock
else
    echo "❌ Puma socket /tmp/puma.sock MISSING"
fi
echo ""

echo "9. Checking systemd services:"
echo "--- carambus_api service ---"
sudo systemctl status carambus_api --no-pager | head -15
echo ""

echo "--- carambus service ---"
sudo systemctl status carambus --no-pager | head -15
echo ""

echo "=========================================="
echo "Diagnosis complete"
echo "=========================================="

