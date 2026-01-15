#!/bin/bash
# Script to fix nginx configurations on the API server
# Repairs /etc/nginx/sites-enabled/carambus and /etc/nginx/sites-enabled/carambus_api

set -e

SSH_HOST="api.carambus.de"
SSH_PORT="8910"
SSH_USER="www-data"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCENARIOS_DIR="$PROJECT_ROOT/../carambus_data/scenarios"

echo "🔧 Fixing nginx configurations on $SSH_HOST..."

# Function to deploy nginx config
deploy_nginx_config() {
    local scenario_name=$1
    local basename=$2
    
    echo ""
    echo "📋 Processing $scenario_name (basename: $basename)..."
    
    local nginx_conf_path="$SCENARIOS_DIR/$scenario_name/production/nginx.conf"
    
    if [ ! -f "$nginx_conf_path" ]; then
        echo "   ❌ nginx.conf not found at $nginx_conf_path"
        return 1
    fi
    
    echo "   ✅ Found nginx.conf for $scenario_name"
    
    # Upload nginx config to temporary location
    local temp_nginx_path="/tmp/nginx-${basename}.conf"
    echo "   📤 Uploading nginx config to temporary location..."
    if ! scp -P "$SSH_PORT" "$nginx_conf_path" "${SSH_USER}@${SSH_HOST}:${temp_nginx_path}"; then
        echo "   ❌ Failed to upload nginx config"
        return 1
    fi
    
    # Move to sites-available with sudo
    echo "   📁 Moving config to /etc/nginx/sites-available/${basename}..."
    if ! ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "sudo mv ${temp_nginx_path} /etc/nginx/sites-available/${basename} && sudo chown root:root /etc/nginx/sites-available/${basename}"; then
        echo "   ❌ Failed to move nginx config to sites-available"
        return 1
    fi
    
    # Create necessary directories and enable site
    echo "   🔗 Creating symlink and testing configuration..."
    local enable_cmd="sudo mkdir -p /var/www/${basename}/shared/log /var/log/${basename} && sudo chown -R www-data:www-data /var/www/${basename}/shared/log && sudo chown -R www-data:www-data /var/log/${basename} && sudo ln -sf /etc/nginx/sites-available/${basename} /etc/nginx/sites-enabled/${basename} && sudo nginx -t"
    
    if ! ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "$enable_cmd"; then
        echo "   ❌ Failed to enable nginx site or nginx test failed"
        return 1
    fi
    
    echo "   ✅ Successfully configured nginx for $basename"
    return 0
}

# Deploy both configurations
deploy_nginx_config "carambus_api" "carambus_api"
deploy_nginx_config "carambus" "carambus"

# Reload nginx
echo ""
echo "🔄 Reloading nginx..."
if ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "sudo systemctl reload nginx"; then
    echo "   ✅ Nginx reloaded successfully"
else
    echo "   ❌ Failed to reload nginx"
    exit 1
fi

echo ""
echo "✅ All nginx configurations have been fixed and reloaded!"
echo ""
echo "📊 Current nginx status:"
ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "sudo systemctl status nginx --no-pager -l | head -20"









