#!/bin/bash
# Fix Raspberry Pi Network Stability Issues
# Run this script on the Raspberry Pi to prevent network disconnections

set -e

echo "🔧 Fixing Raspberry Pi Network Stability"
echo "========================================"

# 1. Disable WLAN Power Management
echo ""
echo "1️⃣ Disabling WLAN Power Management..."
sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF

# Alternative method for non-NetworkManager systems
sudo tee /etc/rc.local.d/disable-wifi-powersave.sh > /dev/null << 'EOF'
#!/bin/bash
# Disable WiFi power management
iwconfig wlan0 power off 2>/dev/null || true
exit 0
EOF
sudo chmod +x /etc/rc.local.d/disable-wifi-powersave.sh 2>/dev/null || true

# 2. SSH Keep-Alive (Server-Side)
echo ""
echo "2️⃣ Configuring SSH Keep-Alive..."
if ! grep -q "ClientAliveInterval" /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 60" | sudo tee -a /etc/ssh/sshd_config
    echo "ClientAliveCountMax 3" | sudo tee -a /etc/ssh/sshd_config
    sudo systemctl restart sshd
    echo "   ✅ SSH Keep-Alive configured"
else
    echo "   ✅ SSH Keep-Alive already configured"
fi

# 3. Network Watchdog - Auto-reconnect on failure
echo ""
echo "3️⃣ Setting up Network Watchdog..."
sudo tee /usr/local/bin/network-watchdog.sh > /dev/null << 'WATCHDOG'
#!/bin/bash
# Network Watchdog - Restarts networking if connection is lost

PING_HOST="8.8.8.8"
PING_COUNT=3
INTERFACE="wlan0"

if ! ping -c $PING_COUNT $PING_HOST > /dev/null 2>&1; then
    echo "$(date): Network down, attempting restart..."
    
    # Try to restart interface
    sudo ip link set $INTERFACE down
    sleep 2
    sudo ip link set $INTERFACE up
    sleep 5
    
    # If still down, restart NetworkManager or dhcpcd
    if ! ping -c $PING_COUNT $PING_HOST > /dev/null 2>&1; then
        sudo systemctl restart NetworkManager 2>/dev/null || sudo systemctl restart dhcpcd 2>/dev/null
        echo "$(date): Network service restarted"
    fi
fi
WATCHDOG

sudo chmod +x /usr/local/bin/network-watchdog.sh

# Create systemd service for watchdog
sudo tee /etc/systemd/system/network-watchdog.service > /dev/null << 'SERVICE'
[Unit]
Description=Network Watchdog
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/network-watchdog.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable network-watchdog.service
sudo systemctl start network-watchdog.service
echo "   ✅ Network Watchdog installed and started"

# 4. Disable IPv6 (optional, can cause issues)
echo ""
echo "4️⃣ Disabling IPv6 (optional)..."
if ! grep -q "ipv6.disable=1" /boot/cmdline.txt 2>/dev/null; then
    sudo sed -i '1s/$/ ipv6.disable=1/' /boot/cmdline.txt 2>/dev/null || \
    sudo sed -i '1s/$/ ipv6.disable=1/' /boot/firmware/cmdline.txt 2>/dev/null || \
    echo "   ⚠️  Could not disable IPv6 (file not found)"
    echo "   ✅ IPv6 disabled (requires reboot)"
else
    echo "   ✅ IPv6 already disabled"
fi

# 5. Increase network buffer sizes
echo ""
echo "5️⃣ Optimizing network buffers..."
sudo tee /etc/sysctl.d/99-network-tuning.conf > /dev/null << 'SYSCTL'
# Network buffer tuning for better stability
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
SYSCTL

sudo sysctl -p /etc/sysctl.d/99-network-tuning.conf
echo "   ✅ Network buffers optimized"

# 6. Check current WLAN power management status
echo ""
echo "6️⃣ Current WLAN Status:"
iwconfig wlan0 2>/dev/null | grep -i power || echo "   (iwconfig not available or no WLAN)"

echo ""
echo "========================================"
echo "✅ Network stability fixes applied!"
echo ""
echo "⚠️  REBOOT REQUIRED for all changes to take effect"
echo ""
echo "To reboot now: sudo reboot"
echo ""
echo "After reboot, verify with:"
echo "  iwconfig wlan0 | grep Power"
echo "  (should show 'Power Management:off')"

