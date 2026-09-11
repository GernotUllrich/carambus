# Raspberry Pi Client Integration - Documentation

## Overview

The Raspberry Pi Client System has been integrated into the Scenario Management System to enable automatic deployment and management of kiosk browsers for Carambus scoreboards.

This page is the reference for the kiosk rake tasks. The complete path from the SD card to the scoreboard
is described in the [Raspberry Pi quickstart](raspberry-pi-quickstart.md).

After power-on, a Pi with a local server takes about **3 minutes** to show the scoreboard: the desktop
after about 1 minute, then the autostart script waits until the local server answers (Puma preloads the
application; the script waits at most 300 s), after that Chromium starts.

## Architecture

### Components

1. **Scenario configuration**: Raspberry Pi client settings in `config.yml`
2. **Rake tasks**: Automated setup, deployment and management tasks
3. **Systemd service**: Kiosk mode as the system service `scoreboard-kiosk`
4. **Autostart script**: Browser start script generated in `lib/tasks/scenarios.rake`

### How It Works

```
Scenario Config → Rake Task → SSH → Raspberry Pi
     ↓              ↓         ↓         ↓
  config.yml → deploy_raspberry_pi_client → SSH Commands → Kiosk Browser
```

## Scenario Configuration

### Raspberry Pi Client Configuration

Each scenario can contain Raspberry Pi client settings. For a Pi set up with Ansible (SSH only as
`www-data` on port 8910) it looks like this — as in the
[quickstart, step 3.1](raspberry-pi-quickstart.md#31-configure-the-scenario):

```yaml
environments:
  production:
    webserver_host: <name>.local
    ssh_host: <name>.local
    webserver_port: 3131
    ssh_port: 8910
    # ... other configurations ...
    raspberry_pi_client:
      enabled: true
      ip_address: <name>.local          # device name, not an IP address
      ssh_user: www-data
      ssh_port: 8910
      kiosk_user: <imager-user>         # the user created in the Imager (autologin)
      local_server_enabled: true        # Does this Pi host the server itself?
      local_server_port: 3131
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enabled` | Enables the Raspberry Pi client for this scenario | off |
| `ip_address` | SSH target of the Pi (device name or IP); also added to `config.hosts` | - |
| `ssh_user` | SSH username (after Ansible: `www-data`) | - |
| `ssh_password` | Leave empty: key-based login. Set: login via `sshpass` | - |
| `ssh_port` | SSH port (after Ansible: 8910) | `22` |
| `kiosk_user` | User the kiosk runs as — must be the autologin user of the desktop session | - |
| `local_server_enabled` | Does this Pi host the server itself? Then the scoreboard URL points to `localhost` | off |
| `local_server_port` | Port for `config.hosts` with `local_server_enabled`; the scoreboard URL uses `webserver_port` | - |
| `sb_state` | Initial scoreboard state in the URL | `welcome` |
| `autostart_enabled` | Currently not evaluated | - |
| `browser_restart_command` | Command to restart the browser | `sudo systemctl restart scoreboard-kiosk` |

## Available Rake Tasks

### 1. Setup Raspberry Pi Client

```bash
bin/rails "scenario:setup_raspberry_pi_client[<scenario>]"
```

**Purpose**: Initial setup of the Raspberry Pi for kiosk mode

**Steps**:
1. Tests the SSH connection
2. Installs `chromium` (fallback `chromium-browser`), `wmctrl` and `xdotool`
3. Creates `kiosk_user` via `useradd` if it differs from the SSH user and does not exist yet — a user
   created this way has no desktop session; the kiosk needs the autologin user
4. Step "autostart configuration" — currently without effect; autostart runs through the service
5. Creates the systemd service `scoreboard-kiosk`

### 2. Deploy Raspberry Pi Client

```bash
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
```

**Purpose**: Deploy the kiosk configuration to the Raspberry Pi

**Steps**:
1. Generates the scoreboard URL from the location (see below)
2. Stores the URL on the **server** (`production.ssh_host`) as `/var/www/<basename>/shared/config/scoreboard_url`
3. Generates the autostart script and installs it on the Pi as `/usr/local/bin/autostart-scoreboard.sh`
4. Enables `scoreboard-kiosk` and restarts it — changes take effect immediately

### 3. Restart Raspberry Pi Client

```bash
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"
```

**Purpose**: Restart the kiosk browser via SSH

**Functionality**:
- Executes the configured restart command
- Allows a quick restart without rebooting the Raspberry Pi
- Saves time during tests and updates

### 4. Test Raspberry Pi Client

```bash
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

**Purpose**: Test the Raspberry Pi client functionality

**Tests**:
1. SSH connection
2. Systemd service status
3. Scoreboard URL file
4. Browser process

### 5. View the autostart script

```bash
bin/rails "scenario:preview_autostart_script[<scenario>]"
```

Prints the script that `deploy_raspberry_pi_client` would install, without changing anything.

## Scoreboard URL Generation

### Automatic URL Creation

The system automatically generates the correct scoreboard URL:

```ruby
location_md5 = Location.find(location_id).md5
url_host = pi_config['local_server_enabled'] ? 'localhost' : webserver_host
sb_state = pi_config['sb_state'] || 'welcome'
scoreboard_url = "http://#{url_host}:#{webserver_port}/locations/#{location_md5}/scoreboard?sb_state=#{sb_state}&locale=de"
```

The md5 value comes from the location in the database, not from a hash of the `location_id`.

### Example

For a Pi with a local server:
- URL: `http://localhost:3131/locations/<md5>/scoreboard?sb_state=welcome&locale=de`

The autostart script reads the `scoreboard_url` file only with `local_server_enabled: true` (on an
all-in-one Pi the server is the Pi itself); without a local server it uses the URL built in at generation time.

## Systemd Service

### Service Definition

```ini
[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target

[Service]
Type=simple
User=<kiosk_user from config.yml>
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=3

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

The script is produced by `generate_autostart_script_content` (`lib/tasks/scenarios.rake`); view it with
`preview_autostart_script`. Do not edit it by hand — `deploy_raspberry_pi_client` overwrites it.

### Script Features

- **Detect the desktop**: If `/etc/lightdm/lightdm.conf` names a labwc session (Raspberry Pi OS 13
  "trixie"), the script waits for the kiosk user's Wayland socket and starts Chromium natively under
  Wayland in kiosk mode (`--ozone-platform=wayland --kiosk`). If Chromium exits, the script ends and
  systemd restarts the kiosk.
- **Other desktops** (wayfire, X11): Chromium with `--start-fullscreen`. In this branch the Chromium call
  ends early because of a commented-out line (known bug in the generator): `--disable-gpu`, the log and
  the subsequent full screen via `wmctrl` currently have no effect.
- **Wait for the local server**: With `local_server_enabled`, the script polls the scoreboard URL every
  second until it answers (HTTP 2xx/3xx), at most 300 s; after that the browser starts anyway.
- **Fresh profile**: `/tmp/chromium-scoreboard-<user>` is deleted and recreated on every start.
- **Browser**: `chromium`, otherwise `chromium-browser`. Log of the labwc branch: `/tmp/chromium-kiosk.log`.

## SSH Authentication

### SSH Key-based Authentication (Recommended)

The system supports both SSH key and password authentication:

```bash
# SSH key authentication (passwordless)
ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no www-data@<name>.local 'command'

# Password authentication (if required)
sshpass -p 'password' ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no user@ip 'command'
```

### Security Notes

- **SSH keys preferred**: Passwordless SSH is more secure and practical
- **www-data user**: Specifically configured for server management
- **Port 8910**: Non-standard port for additional security
- **Firewall**: Restrict SSH access to trusted IPs

## Workflow Examples

### Complete Setup Workflow

First the Pi's system via Ansible: `~/DEV/ansible/RUNBOOK`, section "NEUEN CARAMBUS-PI AUFSETZEN"
(`host_vars` via `bin/rails "scenario:generate_host_vars[<scenario>]"`, one run of `master.yml`). Then
from a carambus checkout, in the order of the [quickstart, step 3.2](raspberry-pi-quickstart.md#32-run-the-deployment):

```bash
# 1. Configs, directories, Redis, Puma service, nginx, /etc/<basename>.env
bin/rails "scenario:prepare_deploy[<scenario>]"

# 2. Derive the development database on the admin computer from the Authority
bin/rails "scenario:prepare_development[<scenario>,development]"

# 3. Put the production database on the server — DESTRUCTIVE
bin/rails "scenario:reset_server_db[<scenario>]"

# 4. Server deployment
bin/rails "scenario:deploy[<scenario>]"

# 5. Set up, deliver and test the Raspberry Pi client
bin/rails "scenario:setup_raspberry_pi_client[<scenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

!!! warning "What you need to know"
    - **Step 2** fetches the global data via SSH as `www-data` from the **Authority's production
      database** (`api.carambus.de`). Currently only the Carambus operators have this access; for the
      initial data load a club (still) needs the operator.
    - **Step 2** replaces the local `carambus_api_development` if the Authority has newer data (backup
      first, deleted again afterwards) — this affects every checkout that uses the same database. The log
      shows many `ERROR: role "www_data" does not exist` and `invalid command \restrict` — both are
      expected, the task still reports ✅.
    - **Step 3** deletes the production database on the server and loads it again. A fresh Pi has none
      yet; without it the deploy fails.

### Quick Browser Restart

```bash
# Restart browser (without rebooting Raspberry Pi)
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"
```

### Troubleshooting

```bash
# Check client status
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"

# Check service status on Raspberry Pi
ssh -p 8910 www-data@<name>.local "sudo systemctl status scoreboard-kiosk"

# Check browser processes
ssh -p 8910 www-data@<name>.local "pgrep -fa chromium"
```

## Different Location Types

### Location with a local server (all-in-one Pi)

- **Local server**: nginx on `webserver_port` (e.g. 3131)
- **SSH access**: Via www-data user on port 8910
- **Scoreboard URL**: `http://localhost:<webserver_port>/…`; the script waits until the server answers

### Location without a local server (pure client)

- **No local server**: `local_server_enabled: false`
- **SSH access**: As configured in `raspberry_pi_client` (after Ansible: `www-data`, port 8910)
- **Scoreboard URL**: `http://<webserver_host>:<webserver_port>/…`, built into the script

## Troubleshooting

### Common Issues

1. **SSH connection failed**
   - Check `ip_address`, `ssh_user` and `ssh_port` in `config.yml` (without `ssh_port`, port 22 is used)
   - Check SSH service status on Raspberry Pi
   - Check firewall settings

2. **Browser doesn't start**
   - Check the logs: `sudo journalctl -u scoreboard-kiosk` and `sudo tail -50 /tmp/chromium-kiosk.log`
   - Check Chromium installation
   - Check scoreboard URL file

3. **Fullscreen mode doesn't work**
   - Run `deploy_raspberry_pi_client` again (restarts the kiosk with the current script)
   - Check the desktop session in `/etc/lightdm/lightdm.conf` (`user-session=`)
   - Check display resolution

4. **Service doesn't start**
   - Check systemd service definition
   - Check that `kiosk_user` is the autologin user
   - Check logs: `sudo journalctl -u scoreboard-kiosk`

### Debug Commands

```bash
# Show service logs
sudo journalctl -u scoreboard-kiosk -f

# Show browser processes
pgrep -fa chromium

# Chromium log (owned by the kiosk user)
sudo tail -50 /tmp/chromium-kiosk.log

# Check the desktop session
grep -E '^(user-session|autologin)' /etc/lightdm/lightdm.conf

# Check scoreboard URL
cat /var/www/<basename>/shared/config/scoreboard_url
```

## Security Considerations

### Production Environment

1. **Use SSH keys**: Replace password authentication
2. **Configure firewall**: Restrict SSH access
3. **Regular updates**: Keep Raspberry Pi OS current
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

*Historical entry (as of October 2025). Today the kiosk is set up with the rake tasks above, on trixie
as well; `bin/setup-raspi-table-client.sh` produces its own, older kiosk configuration without labwc
support.*

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

**Compatibility (as of October 2025):**

- ✅ Raspberry Pi OS (Debian Bullseye) - `chromium-browser` fallback available
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primary support
- ✅ dhcpcd-based network configuration
- ✅ NetworkManager-based configuration

**Calling the script:**

```bash
bin/setup-raspi-table-client.sh <scenario> <current_ip> <table_no> \
  --customer-ssid <SSID> --customer-password <PW> --customer-ip <static_IP> \
  [--dev-ssid <SSID> --dev-password <PW>] [--ssh-port <N>] [--ssh-user <U>]
```

The script automatically detects:
- The correct Chromium package name
- The network management system being used (dhcpcd/NetworkManager)
- Configures WLAN and static IP accordingly
