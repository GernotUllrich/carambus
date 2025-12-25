# Raspberry Pi Client Integration - Documentation

## Overview

The Raspberry Pi Client System has been integrated into the Scenario Management System to enable automatic deployment and management of kiosk browsers for Carambus scoreboards.

## Architecture

### Components

1. **Scenario Configuration**: Raspberry Pi Client settings in `config.yml`
2. **Rake Tasks**: Automated setup, deployment, and management tasks
3. **Systemd Service**: Kiosk mode as system service
4. **Autostart Script**: Intelligent browser start script with display management

### How It Works

```
Scenario Config → Rake Task → SSH → Raspberry Pi
     ↓              ↓         ↓         ↓
  config.yml → deploy_raspberry_pi_client → SSH Commands → Kiosk Browser
```

## Scenario Configuration

### Raspberry Pi Client Configuration

Each scenario can contain Raspberry Pi Client settings:

```yaml
environments:
  production:
    # ... other configurations ...
    raspberry_pi_client:
      enabled: true
      ip_address: "192.168.178.92"  # Raspberry Pi IP
      ssh_user: "pi"
      ssh_password: "raspberry"
      kiosk_user: "pi"
      local_server_enabled: true  # Does this location host a local server?
      local_server_port: 8910
      autostart_enabled: true
      browser_restart_command: "sudo systemctl restart scoreboard-kiosk"
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enabled` | Enables Raspberry Pi Client for this scenario | `false` |
| `ip_address` | IP address of the Raspberry Pi | - |
| `ssh_user` | SSH username | `pi` |
| `ssh_password` | SSH password | `raspberry` |
| `kiosk_user` | User for kiosk mode | `pi` |
| `local_server_enabled` | Does this location host a local server? | `false` |
| `local_server_port` | Port of the local server | `8910` |
| `autostart_enabled` | Automatic start on boot | `true` |
| `browser_restart_command` | Command to restart the browser | `sudo systemctl restart scoreboard-kiosk` |

## Available Rake Tasks

### 1. Setup Raspberry Pi Client

```bash
rake scenario:setup_raspberry_pi_client[scenario_name]
```

**Purpose**: Initial setup of the Raspberry Pi for kiosk mode

**Steps**:
1. Tests SSH connection
2. Installs required packages (chromium-browser, wmctrl, xdotool)
3. Creates kiosk user (if required)
4. Sets up autostart configuration
5. Creates systemd service

**Example**:
```bash
rake scenario:setup_raspberry_pi_client[carambus_location_2459]
```

### 2. Deploy Raspberry Pi Client

```bash
rake scenario:deploy_raspberry_pi_client[scenario_name]
```

**Purpose**: Deployment of kiosk configuration to the Raspberry Pi

**Steps**:
1. Generates scoreboard URL based on location_id (MD5 hash)
2. Uploads scoreboard URL to Raspberry Pi
3. Uploads and installs autostart script
4. Enables and starts systemd service

**Example**:
```bash
rake scenario:deploy_raspberry_pi_client[carambus_location_2459]
```

### 3. Restart Raspberry Pi Client

```bash
rake scenario:restart_raspberry_pi_client[scenario_name]
```

**Purpose**: Restart kiosk browser via SSH

**Functionality**:
- Executes the configured restart command
- Enables quick restart without Raspberry Pi reboot
- Saves time for tests and updates

**Example**:
```bash
rake scenario:restart_raspberry_pi_client[carambus_location_2459]
```

### 4. Test Raspberry Pi Client

```bash
rake scenario:test_raspberry_pi_client[scenario_name]
```

**Purpose**: Test of Raspberry Pi Client functionality

**Tests**:
1. SSH connection
2. Systemd service status
3. Scoreboard URL file
4. Browser process

**Example**:
```bash
rake scenario:test_raspberry_pi_client[carambus_location_2459]
```

## Scoreboard URL Generation

### Automatic URL Creation

The system automatically generates the correct scoreboard URL:

```ruby
location_id = scenario_config['scenario']['location_id']
location_md5 = Digest::MD5.hexdigest(location_id.to_s)
scoreboard_url = "http://#{webserver_host}:#{webserver_port}/locations/#{location_md5}?sb_state=welcome"
```

### Example

For `location_id: 2459`:
- MD5 hash: `a1b2c3d4e5f6...`
- URL: `http://192.168.178.107:81/locations/a1b2c3d4e5f6...?sb_state=welcome`

## Systemd Service

### Service Definition

```ini
[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
```

### Service Management

```bash
# Enable service
sudo systemctl enable scoreboard-kiosk

# Start service
sudo systemctl start scoreboard-kiosk

# Restart service
sudo systemctl restart scoreboard-kiosk

# Check service status
sudo systemctl status scoreboard-kiosk
```

## Autostart Script

### Intelligent Browser Management

The generated autostart script provides:

1. **Display Management**: Waits for display readiness
2. **Panel Hiding**: Hides desktop panels for fullscreen mode
3. **Browser Optimization**: Special Chromium flags for kiosk mode
4. **Error Handling**: Robust handling of display issues

### Script Features

```bash
#!/bin/bash
# Carambus Scoreboard Autostart Script

# Set display environment
export DISPLAY=:0

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Get scoreboard URL
SCOREBOARD_URL=$(cat /etc/scoreboard_url)

# Start browser in fullscreen
/usr/bin/chromium-browser \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir=/tmp/chromium-scoreboard \
  --disable-features=VizDisplayCompositor \
  --disable-dev-shm-usage \
  --app="$SCOREBOARD_URL" \
  >/dev/null 2>&1 &

# Ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true
```

## SSH Authentication

### SSH Key-based Authentication (Recommended)

The system supports both SSH key and password authentication:

```bash
# SSH key authentication (passwordless)
ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no www-data@192.168.178.107 'command'

# Password authentication (if required)
sshpass -p 'password' ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no user@ip 'command'
```

### Security Notes

- **Prefer SSH keys**: Passwordless SSH is more secure and convenient
- **www-data user**: Specially configured for server management
- **Port 8910**: Non-standard port for additional security
- **Firewall**: Restrict SSH access to trusted IPs

## Workflow Examples

### Complete Setup Workflow

```bash
# 1. Prepare scenario for development
rake scenario:prepare_development[carambus_location_2459,development]

# 2. Prepare scenario for deployment
rake scenario:prepare_deploy[carambus_location_2459]

# 3. Server deployment
rake scenario:deploy[carambus_location_2459]

# 4. Raspberry Pi Client setup
rake scenario:setup_raspberry_pi_client[carambus_location_2459]

# 5. Raspberry Pi Client deployment
rake scenario:deploy_raspberry_pi_client[carambus_location_2459]

# 6. Test
rake scenario:test_raspberry_pi_client[carambus_location_2459]
```

### Quick Browser Restart

```bash
# Restart browser (without Raspberry Pi reboot)
rake scenario:restart_raspberry_pi_client[carambus_location_2459]
```

### Troubleshooting

```bash
# Check client status
rake scenario:test_raspberry_pi_client[carambus_location_2459]

# Check service status on Raspberry Pi
ssh pi@192.168.178.92 "sudo systemctl status scoreboard-kiosk"

# Check browser processes
ssh pi@192.168.178.92 "pgrep chromium-browser"
```

## Different Location Types

### Location with Local Server (e.g. carambus_location_2459)

- **Local Server**: Runs on port 8910
- **SSH Access**: Via www-data user
- **Scoreboard URL**: Points to local server

### Location without Local Server (e.g. carambus_location_2460)

- **No Local Server**: Connects to API server
- **SSH Access**: Via standard pi user
- **Scoreboard URL**: Points to API server

## Troubleshooting

### Common Problems

1. **SSH Connection Failed**
   - Check IP address and network connection
   - Check SSH service status on Raspberry Pi
   - Check firewall settings

2. **Browser Won't Start**
   - Check display environment (`echo $DISPLAY`)
   - Check Chromium installation
   - Check scoreboard URL file

3. **Fullscreen Mode Not Working**
   - Check wmctrl installation
   - Check desktop environment (LXDE)
   - Check display resolution

4. **Service Won't Start**
   - Check systemd service definition
   - Check user permissions
   - Check logs: `sudo journalctl -u scoreboard-kiosk`

### Debug Commands

```bash
# Show service logs
sudo journalctl -u scoreboard-kiosk -f

# Show browser processes
ps aux | grep chromium

# Check display environment
echo $DISPLAY
xrandr

# Check scoreboard URL
cat /etc/scoreboard_url
```

## Security Considerations

### Production Environment

1. **Use SSH keys**: Replace password authentication
2. **Configure firewall**: Restrict SSH access
3. **Regular updates**: Keep Raspberry Pi OS up to date
4. **Monitoring**: Monitor service status

### Network Security

1. **VLAN segmentation**: Isolate kiosk network
2. **VPN access**: For remote management
3. **Certificate validation**: For HTTPS connections

## Future Enhancements

### Planned Features

1. **SSH key authentication**: Replace password authentication
2. **Automatic updates**: OTA updates for Raspberry Pi
3. **Monitoring integration**: Health checks and alerting
4. **Multi-display support**: Support for multiple monitors
5. **Backup system**: Automatic configuration backups

### Performance Optimizations

1. **Browser caching**: Optimized cache settings
2. **Display optimization**: Automatic resolution adjustment
3. **Startup optimization**: Faster boot times

## Summary

The Raspberry Pi Client System provides:

✅ **Complete integration** into the Scenario Management System  
✅ **Automated deployment** of kiosk browsers  
✅ **SSH-based management** for remote operations  
✅ **Intelligent scoreboard URL generation** based on location_id  
✅ **Robust browser management** with systemd service  
✅ **Flexible configuration** for different location types  
✅ **Comprehensive test and debug tools**  

The system enables efficient management of Raspberry Pi-based kiosk clients and integration into the existing Carambus infrastructure.

---

## Change History

### 2025-10-17: Compatibility with Debian Trixie and Utility Scripts

**Changes:**

1. **Chromium Package Name Updated** (Commit: ca4c665)
   - Newer Raspberry Pi OS versions (Debian Trixie) use `chromium` instead of `chromium-browser`
   - `bin/setup-raspi-table-client.sh` adapted:
     - Installation: `chromium` instead of `chromium-browser`
     - Executable: `/usr/bin/chromium` instead of `/usr/bin/chromium-browser`
   - Fixes installation error: "Package chromium-browser is not available"

2. **New Utility Scripts Added** (Commit: c304d18)
   - **`bin/check-database-states.sh`**: Comprehensive analysis tool
     - Compares database states between Local, Production and API Server
     - Checks version IDs, table_locals, tournament_locals
     - Warns about unbumped IDs (< 50,000,000)
     - Shows ID ranges and local data
     - Usage: `./bin/check-database-states.sh <scenario_name>`
   
   - **`bin/puma-wrapper.sh`**: Systemd service wrapper
     - Initializes rbenv correctly for Puma service
     - Changes to the correct deployment directory
     - Usage: `puma-wrapper.sh <basename>` or via `PUMA_BASENAME` environment variable

3. **Scoreboard Menu Integration Completed**
   - Branch `scorebord_menu` successfully integrated into master
   - NetworkManager support in setup script present
   - Automatic detection of dhcpcd vs. NetworkManager

**Compatibility:**

- ✅ Raspberry Pi OS (Debian Bullseye) - `chromium-browser` fallback available
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primary support
- ✅ dhcpcd-based network configuration
- ✅ NetworkManager-based configuration

**Deployment Notes:**

When setting up on new Raspberry Pi with Debian Trixie:
```bash
sh bin/setup-raspi-table-client.sh carambus_bcw <current_ip> \
  <ssid> <password> <static_ip> <table_number> [ssh_port] [ssh_user] [server_ip]
```

The script automatically detects:
- The correct Chromium package name
- The network management system being used (dhcpcd/NetworkManager)
- Configures WLAN and static IP accordingly


