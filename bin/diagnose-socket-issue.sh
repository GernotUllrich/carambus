#!/bin/bash
# Diagnose Puma Socket Issue for carambus_bcw
# This script helps identify why the socket file isn't visible

SCENARIO="carambus_bcw"
SOCKET_DIR="/var/www/${SCENARIO}/shared/sockets"
SOCKET_FILE="${SOCKET_DIR}/puma-production.sock"

echo "=========================================="
echo "Puma Socket Diagnostic for ${SCENARIO}"
echo "=========================================="
echo ""

echo "1. Checking systemd service status:"
echo "-----------------------------------"
sudo systemctl status "puma-${SCENARIO}.service" | head -20
echo ""

echo "2. Checking service configuration:"
echo "---------------------------------"
echo "Service file: /etc/systemd/system/puma-${SCENARIO}.service"
if [ -f "/etc/systemd/system/puma-${SCENARIO}.service" ]; then
    cat "/etc/systemd/system/puma-${SCENARIO}.service"
else
    echo "❌ Service file not found!"
fi
echo ""

echo "3. Checking Puma configuration:"
echo "------------------------------"
PUMA_CONFIG="/var/www/${SCENARIO}/shared/config/puma.rb"
echo "Puma config: ${PUMA_CONFIG}"
if [ -f "${PUMA_CONFIG}" ]; then
    echo "--- Content: ---"
    cat "${PUMA_CONFIG}"
    echo ""
    echo "--- Socket bind line: ---"
    grep -n "bind" "${PUMA_CONFIG}" || echo "No bind directive found"
else
    echo "❌ Puma config not found!"
fi
echo ""

echo "4. Checking socket directory:"
echo "----------------------------"
echo "Directory: ${SOCKET_DIR}"
if [ -d "${SOCKET_DIR}" ]; then
    echo "✅ Directory exists"
    ls -la "${SOCKET_DIR}"
    echo ""
    echo "Directory permissions:"
    stat "${SOCKET_DIR}" 2>/dev/null || ls -ld "${SOCKET_DIR}"
else
    echo "❌ Directory does not exist!"
fi
echo ""

echo "5. Searching for socket files:"
echo "-----------------------------"
echo "Looking in /var/www/${SCENARIO}/ for any .sock files:"
find "/var/www/${SCENARIO}/" -name "*.sock" -ls 2>/dev/null || echo "No socket files found"
echo ""

echo "6. Checking Puma process:"
echo "------------------------"
PUMA_PIDS=$(pgrep -f "puma.*${SCENARIO}" || true)
if [ -n "$PUMA_PIDS" ]; then
    echo "✅ Puma processes found:"
    ps aux | grep "[p]uma.*${SCENARIO}"
    echo ""
    echo "Open files by Puma process:"
    for pid in $PUMA_PIDS; do
        echo "--- PID: $pid ---"
        sudo lsof -p "$pid" 2>/dev/null | grep -E "\.sock|unix" || echo "No socket files open"
    done
else
    echo "❌ No Puma process found!"
fi
echo ""

echo "7. Checking systemd journal (last 50 lines):"
echo "-------------------------------------------"
sudo journalctl -u "puma-${SCENARIO}.service" -n 50 --no-pager
echo ""

echo "8. Checking file system mounts:"
echo "------------------------------"
df -h "/var/www/${SCENARIO}/shared"
echo ""

echo "9. Testing socket creation manually:"
echo "----------------------------------"
echo "Attempting to check if socket path is valid..."
SOCKET_TEST_DIR=$(dirname "${SOCKET_FILE}")
if [ -d "$SOCKET_TEST_DIR" ] && [ -w "$SOCKET_TEST_DIR" ]; then
    echo "✅ Socket directory is writable"
else
    echo "❌ Socket directory is not writable or doesn't exist"
    echo "Permissions:"
    ls -ld "$SOCKET_TEST_DIR" 2>/dev/null || echo "Cannot stat directory"
fi
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="

