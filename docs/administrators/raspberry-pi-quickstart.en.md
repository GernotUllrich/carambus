# Quick Start: Raspberry Pi Scoreboard Installation

Complete installation guide from blank SD card to functioning scoreboard in under 30 minutes.

## Overview

This guide walks you through the complete setup of a Carambus Scoreboard on a Raspberry Pi, including:

- ✅ Raspberry Pi OS installation
- ✅ Ansible configuration
- ✅ Server deployment
- ✅ Client/Kiosk setup
- ✅ Automatic browser start

## Prerequisites

### Hardware
- Raspberry Pi 4 or 5 (recommended: 4GB+ RAM)
- MicroSD card (minimum 16GB, recommended 32GB+)
- Power supply (official Raspberry Pi power adapter recommended)
- Monitor with HDMI connection
- Keyboard and mouse (for initial setup)
- Network connection (Ethernet recommended, WiFi supported)

### Software
- Computer with SD card reader
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

### Knowledge Requirements
- Basic command line experience
- Understanding of SSH connections
- Basic network configuration knowledge

## Step 1: Prepare SD Card (5 minutes)

### 1.1 Download and Install Raspberry Pi Imager

Download from: https://www.raspberrypi.com/software/

### 1.2 Flash Raspberry Pi OS

1. Insert SD card into computer
2. Launch Raspberry Pi Imager
3. **Choose Device:** Select your Raspberry Pi model
4. **Choose OS:** 
   - Raspberry Pi OS (64-bit) - Recommended
   - Or: Raspberry Pi OS Lite (64-bit) for headless setup
5. **Choose Storage:** Select your SD card
6. **Configure Settings** (click gear icon ⚙️):
   ```
   Hostname: raspberrypi (or your preferred name)
   Username: pi
   Password: [your-secure-password]
   WiFi: [configure if needed]
   Locale: [your timezone and keyboard layout]
   
   ✅ Enable SSH
   ☐ Use password authentication (recommended for initial setup)
   ```
7. Click **Write** and wait for completion

### 1.3 First Boot

1. Insert SD card into Raspberry Pi
2. Connect monitor, keyboard, and network cable
3. Power on
4. Wait for boot (first boot may take 2-3 minutes)
5. Note the IP address (shown on screen or check your router)

**Verify SSH Access:**
```bash
ssh pi@raspberrypi.local
# or
ssh pi@<IP-ADDRESS>
```

## Step 2: Ansible Configuration (10 minutes)

### 2.1 Initial Server Setup

Base provisioning of the Raspberry Pi (packages, Ruby/rbenv, PostgreSQL, Nginx, www-data user) is done via the setup script or the Ansible roles in the `carambus_master` checkout:

```bash
cd carambus_master

# Option A: run the setup script directly on the Raspberry Pi
#   (copy it to the Pi first via scp/git)
sh bin/setup-raspberry-pi.sh

# Option B: Ansible roles from the ansible/ directory
#   Add your host to ansible/hosts, then:
cd ansible
ansible-playbook -i hosts master.yml
```

> Note: The exact provisioning procedure (SSH hardening, rbenv, PostgreSQL,
> Nginx) is documented in `ansible/RUNBOOK`. There is **no**
> `ansible/playbooks/raspberry_pi_server.yml` and **no**
> `ansible/inventory/production.yml`; the inventory lives in `ansible/hosts`,
> and the playbooks are `ansible/master.yml` / `ansible/migrate.yml`.

This will:
- ✅ Update system packages
- ✅ Install Ruby, Rails, PostgreSQL, Nginx
- ✅ Configure PostgreSQL
- ✅ Create www-data user
- ✅ Set up directory structures
- ✅ Configure firewall

**Duration:** ~10 minutes (depending on network speed)

## Step 3: Deploy Scenario (10 minutes)

### 3.1 Create Scenario Configuration

If not already exists, create a scenario configuration:

```bash
cd carambus_data/scenarios
cp -r carambus_location_template carambus_bcw  # Example name
cd carambus_bcw
```

Edit `config.yml`:
```yaml
scenario:
  name: carambus_bcw
  description: "Billardclub Wedel"
  location_id: 1
  context: NBV
  region_id: 1
  club_id: 357

environments:
  production:
    webserver_host: 192.168.178.107  # Your Raspberry Pi IP
    ssh_host: 192.168.178.107
    webserver_port: 3131
    ssh_port: 8910
    database_name: carambus_bcw_production
    database_username: www_data
    database_password: [secure-password]
    
    raspberry_pi_client:
      enabled: true
      ip_address: "192.168.178.107"  # Same as server (all-in-one)
      ssh_user: "www-data"
      ssh_port: 8910
      kiosk_user: "pi"
      local_server_enabled: true
      autostart_enabled: true
```

### 3.2 Run Complete Deployment

Run the deployment workflow step by step. There is **no** single `deploy_complete` task; deployment is composed of the following rake tasks:

```bash
cd carambus_master

# 1. Prepare deployment files (configs, credentials, Nginx/Puma)
rake "scenario:prepare_deploy[carambus_bcw]"

# 2. Server deployment (Capistrano + database restore + service management)
rake "scenario:deploy[carambus_bcw]"

# 3. Set up Raspberry Pi client (packages, kiosk user, systemd service)
rake "scenario:setup_raspberry_pi_client[carambus_bcw]"

# 4. Deploy client configuration (scoreboard URL, autostart, kiosk service)
rake "scenario:deploy_raspberry_pi_client[carambus_bcw]"

# 5. Test the client
rake "scenario:test_raspberry_pi_client[carambus_bcw]"
```

Together these tasks will:

1. **Generate Configuration Files** (database, Nginx, Puma, credentials)
2. **Deploy to Server** (application code via Capistrano, database restore)
3. **Set up Raspberry Pi Client** (Chromium, wmctrl, xdotool; kiosk user; systemd service)
4. **Deploy Client Configuration** (scoreboard URL, autostart script, enable/start kiosk service)
5. **Test Everything** (SSH connection, systemd service, browser is running)

**Duration:** ~10 minutes

After a successful deployment:

```
Access Information:
  - Web Interface: http://192.168.178.107:3131
  - SSH Access: ssh -p 8910 www-data@192.168.178.107

Management Commands:
  - Restart Browser: rake scenario:restart_raspberry_pi_client[carambus_bcw]
  - Test Client: rake scenario:test_raspberry_pi_client[carambus_bcw]
  - Check Service: ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status scoreboard-kiosk'
```

## Step 4: Verify Installation (2 minutes)

### 4.1 Check Web Interface

Open browser on another computer:
```
http://192.168.178.107:3131
```

### 4.2 Verify Scoreboard Display

The Raspberry Pi monitor should show:
- ✅ Fullscreen Chromium browser
- ✅ Carambus Scoreboard welcome screen
- ✅ No desktop visible (kiosk mode)

### 4.3 Test from Command Line

```bash
# Check service status
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status scoreboard-kiosk'

# Check browser process
ssh -p 8910 www-data@192.168.178.107 'pgrep -fa chromium'

# View logs
ssh -p 8910 www-data@192.168.178.107 'tail -50 /tmp/chromium-kiosk.log'
```

## Troubleshooting

### Common Issues

#### Browser Not Starting

**Check logs:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo journalctl -u scoreboard-kiosk.service -n 50'
ssh -p 8910 www-data@192.168.178.107 'cat /tmp/chromium-kiosk.log'
```

**Restart service:**
```bash
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

#### Web Interface Not Accessible

**Check Puma service:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status puma-carambus_bcw'
```

**Check Nginx:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status nginx'
```

**Check database connection:**
```bash
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_bcw/current && RAILS_ENV=production bundle exec rails runner "puts Region.count"'
```

#### Permission Errors

If you see permission errors for Chromium profile directory:
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo rm -rf /tmp/chromium-scoreboard*'
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

## Management Commands

### Daily Operations

**Restart Scoreboard Browser:**
```bash
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

**Restart Rails Application:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart puma-carambus_bcw'
```

**View Application Logs:**
```bash
ssh -p 8910 www-data@192.168.178.107 'tail -f /var/www/carambus_bcw/shared/log/production.log'
```

**Reboot Raspberry Pi:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo reboot'
```

### Updates and Maintenance

**Update Application Code:**
```bash
cd carambus_master
rake "scenario:deploy[carambus_bcw]"
```

**Update System Packages:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo apt update && sudo apt upgrade -y'
```

**Backup Database:**
```bash
rake "scenario:create_database_dump[carambus_bcw,production]"
```

**Restore Database:**
```bash
rake "scenario:restore_database_dump[carambus_bcw,production]"
```

## Advanced Configuration

### Custom Port Configuration

Edit `config.yml` to change ports:
```yaml
environments:
  production:
    webserver_port: 3131  # Change to your preferred port
    ssh_port: 8910        # Change SSH port if needed
```

### Multiple Locations

For multiple tables/locations in one club:
```yaml
scenario:
  location_id: 1  # First table
  
# Create separate scenarios for each table:
# - carambus_bcw_table1
# - carambus_bcw_table2
# - carambus_bcw_table3
```

### Headless Setup (No Monitor)

For remote-only access without kiosk mode:
```yaml
raspberry_pi_client:
  enabled: false  # Disable kiosk mode
```

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Raspberry Pi (All-in-One)               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │   Kiosk Mode (User: pi)                 │   │
│  │   - Chromium Browser (Fullscreen)       │   │
│  │   - Systemd Service: scoreboard-kiosk   │   │
│  └─────────────────────────────────────────┘   │
│                      ↓ HTTP                     │
│  ┌─────────────────────────────────────────┐   │
│  │   Web Server                            │   │
│  │   - Nginx (Port 3131)                   │   │
│  │   - Puma App Server                     │   │
│  │   - Rails Application                   │   │
│  └─────────────────────────────────────────┘   │
│                      ↓                          │
│  ┌─────────────────────────────────────────┐   │
│  │   Database                              │   │
│  │   - PostgreSQL                          │   │
│  │   - Database: carambus_bcw_production   │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Success Checklist

After completing all steps, verify:

- [ ] Raspberry Pi boots successfully
- [ ] SSH access works
- [ ] Web interface accessible from network
- [ ] PostgreSQL database running
- [ ] Rails application responding
- [ ] Nginx proxy working
- [ ] Scoreboard displays on monitor
- [ ] Browser starts automatically after reboot
- [ ] Touch input working (if touch display)
- [ ] No error messages in logs

## Support

If you encounter issues:

1. Review system logs
2. Verify network configuration
3. Check GitHub issues: https://github.com/GernotUllrich/carambus/issues

## Credits

This installation process has been streamlined through extensive testing and automation. The complete workflow - from blank SD card to functioning scoreboard - typically takes 25-30 minutes.

**Key Technologies:**
- Raspberry Pi OS (Debian)
- Ruby on Rails 7.2
- PostgreSQL 15
- Nginx
- Puma
- Chromium (Kiosk Mode)
- Ansible
- Capistrano

---

**Last Updated:** October 2025  
**Tested On:** Raspberry Pi 4 Model B (4GB), Raspberry Pi 5 (8GB)  
**OS Version:** Raspberry Pi OS (Bookworm/Trixie, 64-bit)

