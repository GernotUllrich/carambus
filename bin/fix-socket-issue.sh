#!/bin/bash
# Fix Puma Socket Issue for carambus_bcw
# This script fixes the socket path in the puma.rb configuration

set -e

SCENARIO="${1:-carambus_bcw}"
PUMA_CONFIG="/var/www/${SCENARIO}/shared/config/puma.rb"
SOCKET_DIR="/var/www/${SCENARIO}/shared/sockets"

echo "=========================================="
echo "Fixing Puma Socket Configuration"
echo "=========================================="
echo "Scenario: ${SCENARIO}"
echo ""

# Check if config exists
if [ ! -f "${PUMA_CONFIG}" ]; then
    echo "❌ Puma config not found: ${PUMA_CONFIG}"
    exit 1
fi

echo "1. Backing up current configuration..."
sudo cp "${PUMA_CONFIG}" "${PUMA_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"
echo ""

echo "2. Checking current bind configuration..."
echo "Current bind line:"
grep "bind" "${PUMA_CONFIG}" || echo "No bind directive found"
echo ""

echo "3. Fixing socket path (removing extra slash)..."
# Fix the triple slash issue: unix:/// -> unix://
sudo sed -i.bak 's|unix:///var/www/|unix://var/www/|g' "${PUMA_CONFIG}"
echo "✅ Socket path fixed"
echo ""

echo "4. Verifying new configuration..."
echo "New bind line:"
grep "bind" "${PUMA_CONFIG}"
echo ""

echo "5. Ensuring socket directory exists..."
sudo mkdir -p "${SOCKET_DIR}"
sudo chown www-data:www-data "${SOCKET_DIR}"
sudo chmod 755 "${SOCKET_DIR}"
echo "✅ Socket directory prepared"
echo ""

echo "6. Stopping Puma service..."
sudo systemctl stop "puma-${SCENARIO}.service" || true
sleep 2
echo "✅ Service stopped"
echo ""

echo "7. Cleaning up old sockets..."
sudo rm -f "${SOCKET_DIR}"/*.sock
echo "✅ Old sockets removed"
echo ""

echo "8. Starting Puma service..."
sudo systemctl start "puma-${SCENARIO}.service"
echo "✅ Service started"
echo ""

echo "9. Waiting for socket to be created..."
for i in {1..15}; do
    if sudo test -S "${SOCKET_DIR}/puma-production.sock"; then
        echo "✅ Socket created successfully!"
        sudo ls -la "${SOCKET_DIR}/puma-production.sock"
        break
    fi
    echo "   Waiting... ($i/15)"
    sleep 2
done
echo ""

echo "10. Checking service status..."
sudo systemctl status "puma-${SCENARIO}.service" --no-pager -l
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "To verify, run:"
echo "  ls -la ${SOCKET_DIR}/puma-production.sock"
echo "  curl --unix-socket ${SOCKET_DIR}/puma-production.sock http://localhost/"



