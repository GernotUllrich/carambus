#!/bin/bash
#
# Carambus Overlay PNG Updater
# Listens for HTTP triggers from browser and fetches PNG from server
#
# This script runs on the streaming Raspberry Pi and provides a simple
# HTTP endpoint that the browser can call when a teaser update occurs.
# When triggered, it fetches the latest PNG from the server.
#
# Usage:
#   carambus-overlay-updater.sh <table_id> <server_url>
#
# Example:
#   carambus-overlay-updater.sh 2 http://192.168.178.106:3000

set -e

TABLE_ID=${1:-1}
SERVER_URL=${2:-http://localhost:3000}
OUTPUT_FILE="/tmp/carambus-overlay-table-${TABLE_ID}.png"
PNG_URL="${SERVER_URL}/overlays/table-${TABLE_ID}.png"
PORT=8888

echo "🎨 Carambus Overlay PNG Updater"
echo "   Table ID: ${TABLE_ID}"
echo "   Server: ${SERVER_URL}"
echo "   PNG URL: ${PNG_URL}"
echo "   Output: ${OUTPUT_FILE}"
echo "   Listening on: http://localhost:${PORT}"
echo ""
echo "✨ Ready to receive update triggers from browser..."

# Fetch initial PNG
echo "📥 Fetching initial PNG..."
curl -sf -o "$OUTPUT_FILE" "$PNG_URL" && echo "✅ Initial PNG saved" || echo "⚠️  Initial PNG fetch failed"

# Listen for triggers and fetch PNG when called
while true; do
  # Listen for HTTP request on port 8888
  # nc (netcat) listens, accepts connection, sends OK response, closes
  echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\n\r\nOK" | \
    nc -l -p ${PORT} -q 0 > /dev/null 2>&1
  
  # When triggered, fetch PNG from server
  TIMESTAMP=$(date '+%H:%M:%S')
  curl -sf -o "$OUTPUT_FILE" "$PNG_URL" && \
    echo "[$TIMESTAMP] ✅ PNG updated ($(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null) bytes)" || \
    echo "[$TIMESTAMP] ❌ PNG fetch failed"
done

