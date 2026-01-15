#!/bin/bash
# Fix nginx configuration on Hetzner API server

set -e

echo "=========================================="
echo "Nginx Configuration Fix Script"
echo "=========================================="
echo ""

# Check if we're running as www-data
if [ "$USER" != "www-data" ]; then
    echo "⚠️  Warning: This script should be run as www-data user"
    echo "Please run: ssh -p 8910 www-data@carambus.de"
fi

echo "1. Copying nginx configurations from docker-trial/nginx-host-config..."
echo ""

# Define the base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_DIR="$(dirname "$SCRIPT_DIR")"
NGINX_CONFIG_DIR="$MASTER_DIR/docker-trial/nginx-host-config"

# Check if nginx config directory exists
if [ ! -d "$NGINX_CONFIG_DIR" ]; then
    echo "❌ Error: nginx-host-config directory not found at $NGINX_CONFIG_DIR"
    echo "Please make sure you're running this from the correct location"
    exit 1
fi

# Copy api.carambus.de configuration
echo "Copying api.carambus.de configuration..."
if [ -f "$NGINX_CONFIG_DIR/api.carambus.de" ]; then
    sudo cp "$NGINX_CONFIG_DIR/api.carambus.de" /etc/nginx/sites-available/api.carambus.de
    sudo ln -sf /etc/nginx/sites-available/api.carambus.de /etc/nginx/sites-enabled/api.carambus.de
    echo "✅ api.carambus.de configuration installed"
else
    echo "❌ api.carambus.de configuration not found"
fi
echo ""

# Copy carambus.de configuration (for carambus scenario)
echo "Copying carambus.de configuration..."
if [ -f "$NGINX_CONFIG_DIR/carambus.de" ]; then
    sudo cp "$NGINX_CONFIG_DIR/carambus.de" /etc/nginx/sites-available/carambus
    sudo ln -sf /etc/nginx/sites-available/carambus /etc/nginx/sites-enabled/carambus
    echo "✅ carambus.de (carambus) configuration installed"
else
    echo "❌ carambus.de configuration not found"
fi
echo ""

echo "2. Creating necessary directories..."
sudo mkdir -p /var/www/carambus_api/shared/log
sudo mkdir -p /var/www/carambus/shared/log
sudo mkdir -p /var/log/carambus_api
sudo mkdir -p /var/log/carambus
sudo chown -R www-data:www-data /var/www/carambus_api/shared/log
sudo chown -R www-data:www-data /var/www/carambus/shared/log
sudo chown -R www-data:www-data /var/log/carambus_api
sudo chown -R www-data:www-data /var/log/carambus
echo "✅ Directories created and permissions set"
echo ""

echo "3. Testing nginx configuration..."
if sudo nginx -t; then
    echo "✅ Nginx configuration test passed"
else
    echo "❌ Nginx configuration test failed"
    echo "Please check the error messages above"
    exit 1
fi
echo ""

echo "4. Reloading nginx..."
if sudo systemctl reload nginx; then
    echo "✅ Nginx reloaded successfully"
else
    echo "❌ Failed to reload nginx"
    echo "Trying restart instead..."
    if sudo systemctl restart nginx; then
        echo "✅ Nginx restarted successfully"
    else
        echo "❌ Failed to restart nginx"
        exit 1
    fi
fi
echo ""

echo "5. Checking nginx status..."
sudo systemctl status nginx --no-pager | head -10
echo ""

echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "Please verify that the sites are accessible:"
echo "  - https://api.carambus.de"
echo "  - https://carambus.de"
echo ""
echo "If they're still not working, check:"
echo "  1. Are the Puma services running?"
echo "     sudo systemctl status carambus_api"
echo "     sudo systemctl status carambus"
echo ""
echo "  2. Check the logs:"
echo "     sudo tail -f /var/log/nginx/api.carambus.de_error.log"
echo "     sudo tail -f /var/log/nginx/carambus.de_error.log"





