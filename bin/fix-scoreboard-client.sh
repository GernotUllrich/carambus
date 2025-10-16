#!/bin/bash
# Script to fix Chromium crashes on Raspberry Pi scoreboard client
# Usage: ./fix-scoreboard-client.sh <pi_ip> <scoreboard_url> [ssh_port] [ssh_user]

PI_IP="$1"
SCOREBOARD_URL="$2"
SSH_PORT="${3:-22}"
SSH_USER="${4:-pi}"

if [ -z "$PI_IP" ] || [ -z "$SCOREBOARD_URL" ]; then
    echo "Usage: $0 <pi_ip> <scoreboard_url> [ssh_port] [ssh_user]"
    echo "Example: $0 192.168.2.210 'http://192.168.2.210:80/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=welcome' 8910 pj"
    exit 1
fi

echo "🔧 Fixing Chromium crashes on Raspberry Pi"
echo "=========================================="
echo "Pi IP: $PI_IP"
echo "SSH Port: $SSH_PORT"
echo "SSH User: $SSH_USER"
echo "Scoreboard URL: $SCOREBOARD_URL"
echo ""

# Create improved autostart script with stable Chromium flags for Pi
AUTOSTART_SCRIPT='#!/bin/bash
# Carambus Scoreboard Autostart Script
# Optimized for Raspberry Pi stability

export DISPLAY=:0
export XAUTHORITY=/home/'"$SSH_USER"'/.Xauthority

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Clean up old chromium data
rm -rf /tmp/chromium-scoreboard 2>/dev/null || true

# Scoreboard URL
SCOREBOARD_URL="'"$SCOREBOARD_URL"'"

echo "Starting Chromium with URL: $SCOREBOARD_URL"

# Start browser with Pi-optimized flags
# Try chromium first, fall back to chromium-browser
CHROMIUM_BIN="/usr/bin/chromium"
if [ ! -f "$CHROMIUM_BIN" ]; then
    CHROMIUM_BIN="/usr/bin/chromium-browser"
fi

$CHROMIUM_BIN \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --disable-restore-session-state \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --check-for-update-interval=31536000 \
  --user-data-dir=/tmp/chromium-scoreboard \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-background-networking \
  --disable-sync \
  --disable-translate \
  --disable-features=VizDisplayCompositor \
  "$SCOREBOARD_URL" 2>&1 | logger -t chromium-scoreboard &

# Wait and ensure fullscreen/kiosk
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true

echo "Chromium started"

# Keep script running to prevent systemd restart
while true; do
  # Check if Chromium is still running
  if ! pgrep -f chromium > /dev/null; then
    echo "Chromium crashed, restarting..."
    sleep 5
    exec "$0"
  fi
  sleep 10
done
'

echo "📤 Uploading fixed autostart script..."
echo "$AUTOSTART_SCRIPT" | ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "cat > /tmp/autostart-scoreboard.sh"

echo "📝 Installing script..."
ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "chmod +x /tmp/autostart-scoreboard.sh && sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh"

echo "🔄 Restarting scoreboard service..."
ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo systemctl restart scoreboard-kiosk"

echo ""
echo "✅ Fix applied!"
echo ""
echo "To check status:"
echo "  ssh -p $SSH_PORT $SSH_USER@$PI_IP 'sudo systemctl status scoreboard-kiosk'"
echo ""
echo "To view logs:"
echo "  ssh -p $SSH_PORT $SSH_USER@$PI_IP 'sudo journalctl -u scoreboard-kiosk -f'"
echo ""
echo "To view Chromium logs:"
echo "  ssh -p $SSH_PORT $SSH_USER@$PI_IP 'sudo journalctl -t chromium-scoreboard -f'"

