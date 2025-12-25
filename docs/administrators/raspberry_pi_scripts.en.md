# Raspberry Pi Management Scripts

This documentation describes all available scripts for managing Raspberry Pi clients in the Carambus system.

## Overview

The Raspberry Pi scripts are located in `carambus_master/bin/` and cover the following areas:
- **Setup & Installation**: Complete setup of new RasPi clients
- **Testing & Debugging**: Network scans and functionality checks
- **Scoreboard Management**: Kiosk mode and browser control
- **Utilities**: SSH setup, SD card preparation

---

## Setup & Installation

### `setup-raspberry-pi.sh`
**Purpose**: Complete setup of a Raspberry Pi as Carambus client

**Usage**:
```bash
cd carambus_master
./bin/setup-raspberry-pi.sh <scenario_name>
```

**What it does**:
1. ✅ Installs required packages (chromium, wmctrl, xdotool)
2. ✅ Creates kiosk user
3. ✅ Sets up systemd service
4. ✅ Configures autostart for scoreboard
5. ✅ Starts kiosk mode

**Prerequisites**:
- SSH access to Raspberry Pi
- Scenario configuration in `carambus_data/scenarios/<scenario_name>/config.yml`
- Raspberry Pi already running with OS

**Documented in**: [Client-Only Installation](raspberry-pi-client.en.md)

**Example**:
```bash
./bin/setup-raspberry-pi.sh carambus_location_5101
# Sets up RasPi for Location 5101
```

---

### `install-client-only.sh`
**Purpose**: Installation of a pure client system (without local server)

**Usage**:
```bash
./bin/install-client-only.sh <scenario_name>
```

**What it does**:
1. ✅ Configures browser kiosk mode
2. ✅ Sets up autostart for scoreboard
3. ✅ Connects to remote server (no local Puma)
4. ✅ Optimized for minimal resource usage

**Use Case**: Tablet or RasPi that only serves as display

**Documented in**: [Client-Only Installation](raspberry-pi-client.en.md)

---

### `install-scoreboard-client.sh`
**Purpose**: Installs scoreboard client software

**Usage**:
```bash
./bin/install-scoreboard-client.sh
```

**What it does**:
- Installs client dependencies
- Configures browser for fullscreen
- Sets up autostart

---

### `setup-phillips-table-ssh.sh`
**Purpose**: Set up SSH access for Phillips Table

**Usage**:
```bash
./bin/setup-phillips-table-ssh.sh
```

**What it does**:
1. ✅ Generates SSH keys
2. ✅ Copies public key to RasPi
3. ✅ Configures passwordless SSH
4. ✅ Tests connection

**Prerequisites**:
- Initial password for RasPi known
- Network access to RasPi

**Example**:
```bash
./bin/setup-phillips-table-ssh.sh
# Interactive: Asks for IP, port, password
```

---

## Testing & Debugging

### `find-raspberry-pi.sh`
**Purpose**: Finds Raspberry Pis in local network

**Usage**:
```bash
./bin/find-raspberry-pi.sh [subnet]
```

**What it does**:
- Scans network for RasPi hosts
- Shows IP addresses and hostnames
- Checks SSH availability

**Examples**:
```bash
# Standard scan in local network
./bin/find-raspberry-pi.sh

# Scan specific subnet
./bin/find-raspberry-pi.sh 192.168.178.0/24
```

**Output Example**:
```
Scanning for Raspberry Pis in 192.168.178.0/24...
Found: 192.168.178.107 (raspberrypi.local)
  SSH: Available (Port 8910)
  Service: puma-carambus_location_5101
```

---

### `test-raspberry-pi.sh`
**Purpose**: Comprehensive tests for RasPi functionality

**Usage**:
```bash
./bin/test-raspberry-pi.sh <scenario_name>
```

**What is tested**:
1. ✅ SSH connection
2. ✅ Puma service status
3. ✅ Nginx configuration
4. ✅ Database connectivity
5. ✅ Scoreboard accessibility
6. ✅ Browser kiosk mode

**Example**:
```bash
./bin/test-raspberry-pi.sh carambus_location_5101
# Runs all tests and shows results
```

---

### `test-raspberry-pi-restart.sh`
**Purpose**: Tests RasPi restart functionality

**Usage**:
```bash
./bin/test-raspberry-pi-restart.sh <scenario_name>
```

**What is tested**:
- Restart command works
- Services start correctly after reboot
- Scoreboard starts automatically

---

## Scoreboard Management

### `start-scoreboard.sh`
**Purpose**: Starts scoreboard in kiosk mode

**Usage**:
```bash
# On the RasPi:
./bin/start-scoreboard.sh [url]

# Remote from development machine:
ssh pi@raspberrypi.local '/path/to/start-scoreboard.sh'
```

**What it does**:
1. ✅ Starts Chromium in fullscreen mode
2. ✅ Opens scoreboard URL
3. ✅ Hides panel/taskbar
4. ✅ Disables screensaver

**Prerequisites**:
- X11 display available
- Chromium installed

---

### `autostart-scoreboard.sh`
**Purpose**: Scoreboard autostart configuration

**Usage**:
```bash
./bin/autostart-scoreboard.sh <scenario_name>
```

**What it does**:
- Creates systemd service
- Configures autostart on boot
- Waits for Puma server
- Starts browser automatically

**Documented in**: [Scoreboard Autostart Setup](scoreboard-autostart.en.md)

---

### `restart-scoreboard.sh`
**Purpose**: Restart scoreboard browser

**Usage**:
```bash
# Locally on RasPi:
./bin/restart-scoreboard.sh

# Remote via SSH:
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

**What it does**:
1. ✅ Terminates running Chromium processes
2. ✅ Cleans cache
3. ✅ Starts browser with scoreboard URL

**Use Cases**:
- Browser hangs or is slow
- After software update
- After change of scoreboard URL

---

### `exit-scoreboard.sh`
**Purpose**: Exits scoreboard kiosk mode cleanly

**Usage**:
```bash
./bin/exit-scoreboard.sh
```

**What it does**:
- Terminates Chromium processes
- Shows panel/taskbar again
- Cleans temporary files

---

### `cleanup-chromium.sh`
**Purpose**: Cleans Chromium cache and temporary files

**Usage**:
```bash
./bin/cleanup-chromium.sh
```

**What it does**:
- Deletes browser cache
- Removes cookies
- Cleans downloads
- Deletes crash reports

**Use Cases**:
- Browser becomes slow
- Too little disk space
- After long runtime

---

## Utilities

### `prepare-sd-card.sh`
**Purpose**: Prepares SD card for RasPi installation

**Usage**:
```bash
./bin/prepare-sd-card.sh [device]
```

**What it does**:
1. ⚠️ Formats SD card (WARNING: All data will be deleted!)
2. ✅ Installs Raspberry Pi OS
3. ✅ Configures SSH
4. ✅ Configures WLAN (optional)
5. ✅ Creates basic configuration

**Prerequisites**:
- SD card inserted
- Raspberry Pi OS image downloaded
- Admin rights (sudo)

**Example**:
```bash
# List available devices
diskutil list

# Prepare SD card
sudo ./bin/prepare-sd-card.sh /dev/disk2
```

**⚠️ WARNING**: Check device carefully! Wrong device leads to data loss.

---

## Legacy/Deprecated Scripts

### `quick-start-raspberry-pi.sh` ⚠️
**Status**: Obsolete (replaced by `setup-raspberry-pi.sh`)

### `auto-setup-raspberry-pi.sh` ⚠️
**Status**: Obsolete (replaced by `setup-raspberry-pi.sh`)

### `start_scoreboard` ⚠️
**Status**: Obsolete (replaced by `start-scoreboard.sh`)

### `start_scoreboard_delayed` ⚠️
**Status**: Obsolete (replaced by `autostart-scoreboard.sh`)

---

## Workflow Examples

### Setting up a New Raspberry Pi from Scratch

```bash
# 1. Prepare SD card
sudo ./bin/prepare-sd-card.sh /dev/disk2

# 2. Boot RasPi and find it in network
./bin/find-raspberry-pi.sh

# 3. Set up SSH access
./bin/setup-phillips-table-ssh.sh
# IP: 192.168.178.107
# Port: 22
# Password: [initial password]

# 4. Complete installation
./bin/setup-raspberry-pi.sh carambus_location_5101

# 5. Test
./bin/test-raspberry-pi.sh carambus_location_5101
```

### Fixing Browser Problems

```bash
# 1. Clean Chromium cache
ssh -p 8910 www-data@192.168.178.107 './bin/cleanup-chromium.sh'

# 2. Restart browser
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'

# 3. If still problems: Restart service
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart scoreboard-kiosk'
```

### Deploy Scenario Update to RasPi

```bash
# 1. Deployment from development machine
cd carambus_master
./bin/deploy-scenario.sh carambus_location_5101

# 2. Restart browser on RasPi (to load new assets)
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'

# 3. Test
./bin/test-raspberry-pi.sh carambus_location_5101
```

---

## Troubleshooting

### SSH Connection Fails
```bash
# Problem: "Connection refused"
# Solution: Enable SSH manually on RasPi
# 1. Connect monitor + keyboard to RasPi
# 2. sudo raspi-config
# 3. Interface Options → SSH → Enable

# Problem: "Permission denied (publickey)"
# Solution: Set up SSH keys again
./bin/setup-phillips-table-ssh.sh
```

### Browser Won't Start
```bash
# Problem: "Display not available"
# Solution: Check X11 display
ssh -p 8910 www-data@raspberrypi 'echo $DISPLAY'
# Should be ":0"

# If not set:
ssh -p 8910 www-data@raspberrypi 'export DISPLAY=:0 && ./bin/start-scoreboard.sh'
```

### Scoreboard Shows Old Version
```bash
# Clean cache and restart browser
ssh -p 8910 www-data@raspberrypi './bin/cleanup-chromium.sh && ./bin/restart-scoreboard.sh'

# If that doesn't help: Hard reload in browser
# Ctrl+Shift+R or systemctl restart
```

---

## Best Practices

### RasPi Setup
1. ✅ Always use `find-raspberry-pi.sh` first to determine IP
2. ✅ Set up SSH keys (passwordless) for automation
3. ✅ Restart browser after each deployment
4. ✅ Regularly clean Chromium cache

### Network
1. ✅ Use static IP for production RasPis
2. ✅ Change SSH port (standard: 8910 instead of 22)
3. ✅ Configure firewall on RasPi

### Maintenance
1. ✅ Weekly: Run `cleanup-chromium.sh`
2. ✅ Monthly: OS updates via `apt update && apt upgrade`
3. ✅ When problems arise: First browser restart, then service restart, then reboot

---

## See Also

- [Client-Only Installation](raspberry-pi-client.en.md) - Detailed installation guide
- [Scoreboard Autostart Setup](scoreboard-autostart.en.md) - Autostart configuration
- [Deployment Workflow](../developers/deployment-workflow.en.md) - Complete deployment process
- [Scenario Management](../developers/scenario-management.en.md) - Scenario system overview


