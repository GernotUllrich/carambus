# Carambus Client Installation Examples

## Quick Examples

### Example 1: Install carambus_bcw client

```bash
# Using the scenario-based script (recommended)
./bin/install-client-only.sh carambus_bcw 192.168.1.100

# This automatically uses:
# - Server: 192.168.178.107:3131 (from carambus_bcw config)
# - Location ID: 1 (from carambus_bcw config)
# - Scoreboard URL: http://192.168.178.107:3131/locations/1/scoreboard_reservations
```

### Example 2: Install with custom SSH configuration

```bash
# Custom SSH port and user
./bin/install-client-only.sh carambus_bcw 192.168.1.100 2222 admin
```

### Example 3: Standalone installation (no scenario config needed)

```bash
# Direct server configuration
./bin/install-scoreboard-client.sh 192.168.178.107 3131 1 192.168.1.100

# This creates:
# - Scoreboard URL: http://192.168.178.107:3131/locations/1/scoreboard_reservations
```

### Example 4: Multiple clients for same server

```bash
# Client 1
./bin/install-client-only.sh carambus_bcw 192.168.1.100

# Client 2
./bin/install-client-only.sh carambus_bcw 192.168.1.101

# Client 3
./bin/install-client-only.sh carambus_bcw 192.168.1.102
```

## Common Scenarios

### Scenario 1: New Installation

1. **Deploy the server first**:
   ```bash
   ./bin/deploy-scenario.sh carambus_bcw
   ```

2. **Install the client**:
   ```bash
   ./bin/install-client-only.sh carambus_bcw <CLIENT_IP>
   ```

3. **Verify the installation**:
   ```bash
   ssh pi@<CLIENT_IP> 'sudo systemctl status scoreboard-kiosk'
   ```

### Scenario 2: Client-only setup (server already running)

```bash
# Just install the client
./bin/install-client-only.sh carambus_bcw <CLIENT_IP>

# Or use standalone script if you know the exact configuration
./bin/install-scoreboard-client.sh <SERVER_IP> <SERVER_PORT> <LOCATION_ID> <CLIENT_IP>
```

### Scenario 3: Troubleshooting existing client

```bash
# SSH to the client
ssh pi@<CLIENT_IP>

# Check service status
sudo systemctl status scoreboard-kiosk

# Restart the service
sudo systemctl restart scoreboard-kiosk

# View logs
sudo journalctl -u scoreboard-kiosk -f
```

## Configuration Reference

### carambus_bcw Configuration
- **Server**: 192.168.178.107:3131
- **Location ID**: 1
- **Scoreboard URL**: http://192.168.178.107:3131/locations/1/scoreboard_reservations

### carambus_location_5101 Configuration
- **Server**: 192.168.178.107:82
- **Location ID**: 5101
- **Scoreboard URL**: http://192.168.178.107:82/locations/5101/scoreboard_reservations

## Management Commands

### Service Control
```bash
# Start service
sudo systemctl start scoreboard-kiosk

# Stop service
sudo systemctl stop scoreboard-kiosk

# Restart service
sudo systemctl restart scoreboard-kiosk

# Enable autostart
sudo systemctl enable scoreboard-kiosk

# Disable autostart
sudo systemctl disable scoreboard-kiosk
```

### Monitoring
```bash
# Check service status
sudo systemctl status scoreboard-kiosk

# View logs
sudo journalctl -u scoreboard-kiosk -f

# Check if browser is running
pgrep -f chromium-browser
```

### Manual Testing
```bash
# Test the autostart script manually
sudo -u pi /usr/local/bin/autostart-scoreboard.sh

# Test browser directly
chromium-browser --start-fullscreen --app="http://SERVER:PORT/locations/ID/scoreboard_reservations"
```

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check logs
   sudo journalctl -u scoreboard-kiosk --no-pager
   
   # Check if display is available
   echo $DISPLAY
   ```

2. **Scoreboard not loading**
   ```bash
   # Test network connectivity
   ping <SERVER_IP>
   
   # Test URL in regular browser
   chromium-browser http://SERVER:PORT/locations/ID/scoreboard_reservations
   ```

3. **SSH connection failed**
   ```bash
   # Test SSH manually
   ssh -p <PORT> <USER>@<CLIENT_IP>
   
   # Check SSH service on client
   sudo systemctl status ssh
   ```

### Debug Mode

To run the installation with more verbose output:

```bash
# Add debug flags to SSH
ssh -v -p <PORT> <USER>@<CLIENT_IP> 'echo test'
```

## Security Notes

- The scripts use SSH key authentication by default
- Ensure SSH keys are properly set up
- The client only displays data, doesn't store sensitive information
- Consider using a dedicated user account for the scoreboard client

## Integration with Existing Workflows

### Using with deploy-scenario.sh

```bash
# Complete deployment including client
./bin/deploy-scenario.sh carambus_bcw

# This will:
# 1. Deploy the server
# 2. Set up the Raspberry Pi client
# 3. Start the scoreboard service
```

### Manual client installation

```bash
# If you only want to install the client
./bin/install-client-only.sh carambus_bcw <CLIENT_IP>
```

The client installation scripts provide flexible options for both integrated and standalone deployments.


