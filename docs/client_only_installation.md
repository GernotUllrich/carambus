# Carambus Client-Only Installation Guide

This guide explains how to set up a Raspberry Pi as a Carambus scoreboard client without installing the full Carambus server.

## Overview

The client-only installation allows you to:
- Set up a Raspberry Pi to display a Carambus scoreboard
- Connect to an existing Carambus server (like carambus_bcw)
- Automatically start the scoreboard in kiosk mode
- Manage the client via systemctl commands

## Prerequisites

### Raspberry Pi Setup
- Raspberry Pi with 64-bit desktop OS installed
- SSH enabled
- Network connectivity to the Carambus server
- Display connected (HDMI recommended)

### Server Requirements
- Carambus server must be running (e.g., carambus_bcw)
- Server must be accessible from the Raspberry Pi
- Scoreboard URL must be known

## Quick Start

### 1. Basic Installation

```bash
# From your Carambus development machine
./bin/install-client-only.sh carambus_bcw <RASPBERRY_PI_IP>
```

### 2. Custom SSH Configuration

```bash
# If using custom SSH port or user
./bin/install-client-only.sh carambus_bcw <RASPBERRY_PI_IP> 22 pi
```

### 3. Start the Scoreboard

```bash
# SSH to the Raspberry Pi
ssh pi@<RASPBERRY_PI_IP>

# Start the scoreboard service
sudo systemctl start scoreboard-kiosk
```

## Installation Process

The installation script performs these steps:

1. **SSH Connection Test**: Verifies connectivity to the Raspberry Pi
2. **Package Installation**: Installs required packages (chromium-browser, wmctrl, xdotool)
3. **Autostart Script**: Creates and installs the scoreboard autostart script
4. **Systemd Service**: Creates and enables the scoreboard-kiosk systemd service
5. **Service Start**: Starts the scoreboard service
6. **Verification**: Checks that everything is working correctly

## Configuration Details

### Scoreboard URL Generation

The script automatically generates the scoreboard URL from the scenario configuration:

- **carambus_bcw**: `http://192.168.178.107:3131/locations/1/scoreboard_reservations`
- **carambus_location_5101**: `http://192.168.178.107:82/locations/5101/scoreboard_reservations`

### Systemd Service

The service is configured as:
- **Service Name**: `scoreboard-kiosk.service`
- **User**: `pi` (or specified SSH user)
- **Auto-restart**: Enabled with 10-second delay
- **Autostart**: Enabled for graphical.target

## Management Commands

### Service Management

```bash
# Check service status
sudo systemctl status scoreboard-kiosk

# Start the service
sudo systemctl start scoreboard-kiosk

# Stop the service
sudo systemctl stop scoreboard-kiosk

# Restart the service
sudo systemctl restart scoreboard-kiosk

# Enable autostart
sudo systemctl enable scoreboard-kiosk

# Disable autostart
sudo systemctl disable scoreboard-kiosk
```

### Logs and Debugging

```bash
# View service logs
sudo journalctl -u scoreboard-kiosk -f

# View recent logs
sudo journalctl -u scoreboard-kiosk --since "1 hour ago"

# Check if Chromium is running
pgrep -f chromium-browser
```

### Manual Browser Control

```bash
# Exit fullscreen (if needed for debugging)
wmctrl -r "Chromium" -b remove,fullscreen

# Show panel (for desktop access)
wmctrl -r "panel" -b remove,hidden

# Hide panel again
wmctrl -r "panel" -b add,hidden
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Ensure SSH is enabled on the Raspberry Pi
   - Check IP address and port
   - Verify SSH key authentication or enable password auth

2. **Service Won't Start**
   - Check service status: `sudo systemctl status scoreboard-kiosk`
   - View logs: `sudo journalctl -u scoreboard-kiosk`
   - Ensure display is connected and working

3. **Scoreboard Not Loading**
   - Verify network connectivity to Carambus server
   - Check if the server is running
   - Test the scoreboard URL in a regular browser

4. **Display Issues**
   - Ensure HDMI display is connected
   - Check display resolution settings
   - Verify X11 is running: `echo $DISPLAY`

### Manual Testing

```bash
# Test the autostart script manually
sudo -u pi /usr/local/bin/autostart-scoreboard.sh

# Test browser with scoreboard URL
chromium-browser --start-fullscreen --app="http://SERVER:PORT/locations/ID/scoreboard_reservations"
```

## Security Considerations

- The script uses SSH key authentication by default
- The scoreboard runs in a restricted Chromium environment
- No sensitive data is stored on the client
- The client only displays information from the server

## Integration with Existing Systems

### Using with carambus_bcw

```bash
# Deploy the full carambus_bcw scenario first
./bin/deploy-scenario.sh carambus_bcw

# Then install the client on a separate Raspberry Pi
./bin/install-client-only.sh carambus_bcw <CLIENT_IP>
```

### Multiple Clients

You can install multiple clients pointing to the same server:

```bash
# Install client 1
./bin/install-client-only.sh carambus_bcw 192.168.1.100

# Install client 2
./bin/install-client-only.sh carambus_bcw 192.168.1.101

# Install client 3
./bin/install-client-only.sh carambus_bcw 192.168.1.102
```

## Advanced Configuration

### Custom Scoreboard URL

If you need a custom scoreboard URL, you can modify the autostart script after installation:

```bash
# SSH to the client
ssh pi@<CLIENT_IP>

# Edit the autostart script
sudo nano /usr/local/bin/autostart-scoreboard.sh

# Change the SCOREBOARD_URL variable to your custom URL
# Restart the service
sudo systemctl restart scoreboard-kiosk
```

### Display Rotation

For rotated displays, you can modify the Chromium flags in the autostart script:

```bash
# Add display rotation flags
/usr/bin/chromium-browser \
  --start-fullscreen \
  --display-rotation=90 \
  # ... other flags
```

## Support

For issues or questions:
1. Check the service logs first
2. Verify network connectivity
3. Test the scoreboard URL in a regular browser
4. Check the Carambus server status

The client-only installation provides a lightweight, reliable way to deploy Carambus scoreboards on multiple Raspberry Pi devices.


