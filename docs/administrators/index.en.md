# System Administrator Documentation

Welcome to the Carambus documentation for system administrators! Here you'll find all information for installing, configuring, and maintaining the system.

## 🎯 Your Role as System Administrator

As a system administrator, you are responsible for:
- 🖥️ **Installation**: Set up and commission the system
- ⚙️ **Configuration**: Adapt system to your requirements
- 🔐 **Security**: Secure system and manage backups
- 📊 **Monitoring**: Monitor performance and detect problems
- 🔄 **Updates**: Keep system current and secure
- 🆘 **Support**: Solve technical problems for users

## 🚀 Quick Start by Deployment Option

Choose your deployment variant:

### Option 1: Raspberry Pi All-in-One (Recommended for Individual Clubs)
**Setup time**: about 1.5 hours (measured: system ~60 min, application ~15 min)  
**Difficulty**: ⭐⭐ Medium (basic Linux and SSH knowledge required)

➡️ **[Raspberry Pi Quickstart Guide](raspberry-pi-quickstart.md)**

!!! warning "Initial database load"
    The initial load currently requires SSH access to the Authority (`api.carambus.de`). This needs the
    Carambus operator, see [Installation Overview](installation-overview.md#prerequisites).

### Option 2: Cloud Hosting (Federations)
**Status**: not a proven path. The Ansible roles and the Quickstart have been walked for the Raspberry Pi;
a fresh cloud server has not been set up this way so far.

➡️ **[Installation Overview](installation-overview.md)**

### Option 3: On-Premise Server
**Status**: not a proven path (as option 2). A Raspberry Pi used purely as a server follows the path of
option 1.

➡️ **[Installation Overview](installation-overview.md)**

## 📚 Main Topics

### 1. Installation

**Basic installation**:
- System requirements
- Set up the system with Ansible (`~/DEV/ansible`, RUNBOOK)
- Scenario configuration in `carambus_data`
- Deploy Carambus via Scenario Management

➡️ **[Complete Installation Guide](installation-overview.md)**

**Special installations**:
- **[Raspberry Pi Setup](raspberry-pi-quickstart.md)**: All-in-One kiosk system
- **[Raspberry Pi Client](raspberry-pi-client.md)**: Display/Scoreboard only
- **[Database Setup](database-setup.md)**: Configure PostgreSQL

### 2. Configuration

**System settings**:
- Configure club data
- Set up email server
- SSL/TLS certificates
- Backup strategies

➡️ **[Email Configuration](email-configuration.md)**

**Scoreboard setup**:
- Automatic start on boot (about 3 minutes from power-on to the scoreboard, desktop after ~1 minute)
- Configure kiosk mode
- Manage multiple displays

➡️ **[Scoreboard Autostart Setup](scoreboard-autostart.md)**

### 3. Server Architecture

**System overview**:
- Component architecture
- Rails application stack
- Database design
- WebSocket communication
- Caching strategies

➡️ **[Server Architecture Documentation](server-architecture.md)**

### 4. Maintenance & Updates

**Regular maintenance**:
- Apply system updates
- Perform Carambus updates
- Backup checks
- Check log sizes
- Performance monitoring

**Backup & Restore**:
- Database backups
- File backups (uploads, logs)
- Restore procedures
- Disaster recovery

### 5. Security

**System hardening** (on Raspberry Pis via Ansible):
- Firewall with `iptables-persistent`: only port 3131 (web) and 8910 (SSH) open
- SSH only on port 8910 as `www-data`
- Block list against suspicious addresses (chain `carambus-blocklist`)
- SSL/TLS certificates (Let's Encrypt) for publicly reachable servers
- Secrets outside the deploy tree (`/etc/<basename>.env`, mode 600)

**Best practices**:
- Regular security updates
- Enforce strong passwords
- Log monitoring

### 6. Monitoring & Troubleshooting

**Performance monitoring**:
- CPU/RAM utilization
- Database performance
- WebSocket connections
- Request times
- Error rates

**Log analysis**:
- Application logs
- Nginx logs
- PostgreSQL logs
- Systemd logs

**Common problems**:
- WebSocket connections drop
- Slow queries in database
- Disk space full
- SSL certificate expired

### 7. Table Reservation & Heating Control

**Hardware integration**:
- Connect heating control
- GPIO pins (Raspberry Pi)
- Relay modules
- Timer switches

➡️ **[Table Reservation & Heating Control](../managers/table-reservation.md)**

### 8. YouTube Live Streaming

**Tournament streaming with existing scoreboards**:
- Uses existing Scoreboard Raspberry Pis
- USB webcam per table (~$80)
- FFmpeg (software encoding, `libx264`)
- Automatic scoreboard overlay
- Central management in admin interface

**Documentation**:
- 🚀 **[Quick Start (5 Steps)](streaming-quickstart.md)** - Get your first stream in 5 minutes
- 📖 **[Complete Setup Guide](streaming-setup.md)** - Hardware, YouTube setup, configuration, troubleshooting
- 💻 **[Developer Architecture](../developers/streaming-architecture.md)** - Technical details for developers

**Features**:
- ✅ Table-based streaming (each table independent)
- ✅ Live overlays (player names, scores, tournament info)
- ✅ Auto-restart on errors
- ✅ Health monitoring
- ✅ Very cost-effective (~$80 camera per table)

## 🛠️ Installation Scenarios in Detail

### Raspberry Pi All-in-One

**Hardware requirements**:
- Raspberry Pi 4 or 5. 2 GB RAM works but is tight; 4 GB or more is recommended
- MicroSD card (at least 16 GB, 32 GB+ recommended)
- Official power supply
- HDMI cable and monitor
- Optional: Touch display (7" or larger)

**Software setup** (details in the [Quickstart](raspberry-pi-quickstart.md)):
1. **Write the SD card**: Raspberry Pi Imager, standard Raspberry Pi OS with desktop, add your SSH key
2. **Set up the system**: one Ansible run (`master.yml`, ~60 min)
3. **Deploy the application**: rake tasks from the admin machine (~15 min)
4. **Done**: The Pi boots into the scoreboard on its own (~3 min after power-on)

**Advantages**:
- ✅ Proven path, walked on fresh hardware
- ✅ Very cost-effective (~150 EUR)
- ✅ Server and scoreboard on one device

**Disadvantages**:
- ❌ Limited performance (sufficient for small clubs)
- ❌ SD card can fail, and **no automatic database backup is set up for new club Pis** (see maintenance
  checklist)

➡️ **[Detailed Raspberry Pi Guide](raspberry-pi-quickstart.md)**

### Cloud Hosting (VPS)

**Provider examples**:
- **Hetzner Cloud**: 8 EUR/month (CPX21: 3 vCPU, 4 GB RAM)
- **DigitalOcean**: 24 USD/month (4 GB Droplet)
- **AWS/Azure**: From 30 EUR/month (variable costs)

**Installation steps** (application part as on the Pi, system part not proven):
1. **Book and start a VPS**
2. **Set up the system**: The Ansible roles have been walked for the Raspberry Pi; whether `master.yml` sets up
   a fresh cloud server equivalently has not been checked
3. **Create the scenario** in `carambus_data` (see [Installation Overview](installation-overview.md))
4. **Deploy the application**: `prepare_deploy` → `prepare_development` → `reset_server_db` → `deploy`
5. **Set up SSL**: issue the certificate before `prepare_deploy` (`ssl_enabled: true`)
6. **Configure backup**: see maintenance checklist
7. **Set up monitoring**: optional (e.g. UptimeRobot)

**Advantages**:
- ✅ Accessible from anywhere
- ✅ Professional infrastructure

**Disadvantages**:
- ❌ Ongoing costs
- ❌ Internet dependency
- ❌ System part not a proven path

➡️ **[Installation Overview](installation-overview.md)**

### On-Premise Server

**Hardware options**:
- **Budget**: Raspberry Pi as a pure server (path as option 1)
- **Standard**: Intel NUC or mini PC
- **Premium**: Tower server with RAID

**Installation steps**: as cloud hosting. Additionally: a static address or device name on the local
network, backup to an external medium (USB HDD or NAS), UPS against power failures.

**Advantages**:
- ✅ Full data control
- ✅ No ongoing hosting costs
- ✅ Fast on the local network

**Disadvantages**:
- ❌ Hardware purchase
- ❌ Responsible for maintenance yourself

➡️ **[Installation Overview](installation-overview.md)**

## ⚙️ Important Configuration Files

A server's configuration is **not maintained by hand**. It is derived from
`carambus_data/scenarios/<scenario>/config.yml` and `carambus_data/secrets.yml`; `prepare_deploy` generates
the files and uploads them.

| File on the server | Generated from | Change via |
|---|---|---|
| `shared/config/database.yml` | `templates/database/database.yml.erb` (role `www_data`, password from `secrets.yml` `shared.database_password`) | `config.yml` / `secrets.yml`, then `prepare_deploy` |
| `shared/config/puma.rb` | `templates/puma/puma_rb.erb` (socket `/var/www/<basename>/shared/sockets/puma-production.sock`) | `prepare_deploy` |
| `/etc/nginx/sites-available/<basename>` | `templates/nginx/nginx_conf.erb` | `bin/rails "scenario:sync_nginx_conf[<scenario>]"` |
| `/etc/systemd/system/puma-<basename>.service` | `templates/puma/puma.service.erb` | `prepare_deploy` (do not edit by hand, it is rewritten) |
| `/etc/<basename>.env` | `secrets.yml` `smtp` (or `smtp_enabled: false`) | by hand, never overwritten |
| `shared/config/credentials/production.key` / `production.yml.enc` | `carambus_data/scenarios/<scenario>/production/credentials/` | `WRITE=true bin/rails "scenario:generate_credentials[<scenario>]"` (dry run without `WRITE=true`), then `prepare_deploy` |

All paths without a leading `/` are under `/var/www/<basename>/`.

!!! note "Credentials"
    Do not edit them on the server with `rails credentials:edit`: `prepare_deploy` uploads the files from
    `carambus_data` and overwrites changes made on the server. How a new club obtains its `production.key`
    is not settled yet (see [Installation Overview](installation-overview.md#prerequisites)).

Services on the server:
```bash
sudo systemctl status puma-<basename>
sudo systemctl restart puma-<basename>
systemctl is-active puma-<basename> redis-server nginx
```

## 🔧 Maintenance Checklist

### Daily (automated)
- ✅ Database backup **only** for the Authority and for the sites listed in `STANDALONE_BACKUP_SCENARIOS`
  (`config/schedule.rb`) (currently `carambus_bcw`, target `/mnt/backup`)
- ⚠️ A new club Pi has **no automatic backup**: add the scenario to `STANDALONE_BACKUP_SCENARIOS` and mount a
  USB stick at `/mnt/backup`, or set up `bin/pg_backup.sh` in cron yourself

### Weekly
- 🔍 Check backup integrity
- 🔍 Review logs for errors
- 🔍 Check disk space (`production.log` is not rotated automatically)
- 🔍 View performance metrics

### Monthly
- 🔄 Apply system updates (security)
- 🔄 Check and install Carambus updates (`bin/rails "scenario:deploy[<scenario>]"`)
- 🔄 Check SSL certificate expiration (for publicly reachable servers)
- 🔄 Test backup restore

### Quarterly
- 📊 Performance analysis
- 📊 Capacity planning
- 📊 Security audit
- 📊 Update documentation

### Annually
- 🔒 Disaster recovery test
- 🔒 Check hardware condition

## 🆘 Troubleshooting Guide

### Problem: Application won't start

**Symptoms**: *502 Bad Gateway*, service `puma-<basename>` keeps restarting

**Debugging**:
```bash
# Check service status
sudo systemctl status puma-<basename>

# View logs
sudo journalctl -u puma-<basename> -n 100 --no-pager
```

**Common causes**:
- `/etc/<basename>.env` missing (`FATAL: SMTP-ENV nicht gesetzt`), see [Email Configuration](email-configuration.md)
- Database not reachable
- Missing credentials

### Problem: WebSockets not working

**Symptoms**: Scoreboards don't update in real-time

**Checks**:
```bash
# Check nginx WebSocket configuration
sudo nginx -t

# Action Cable logs
tail -f /var/www/<basename>/shared/log/production.log | grep Cable

# Redis is required (ActionCable)
systemctl is-active redis-server
redis-cli ping
```

**Solutions**:
- Regenerate the nginx configuration with `scenario:sync_nginx_conf`
- Start Redis: `sudo systemctl start redis-server`

### Problem: Slow performance

**Diagnosis**:
```bash
# CPU/RAM utilization
htop
free -m

# Database connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

**Optimizations**:
- Check memory: are ClamAV/SpamAssassin running on the Pi, see [Quickstart, Troubleshooting](raspberry-pi-quickstart.md#troubleshooting)
- Check database indexes
- More RAM/CPU

### Problem: Disk space full

**Diagnosis**:
```bash
# Disk usage
df -h

# Find largest directories
du -sh /var/* | sort -h
```

**Solutions**:
```bash
# Delete old journal entries
sudo journalctl --vacuum-time=7d

# Clear the Rails log
cd /var/www/<basename>/current && RAILS_ENV=production bin/rails log:clear

# Delete old backups (check manually!)
```

### Problem: SSL certificate expired

**Symptoms**: Browser warning, HTTPS doesn't work

**Solution**:
```bash
# Renew with certbot
sudo certbot renew

# Reload nginx
sudo systemctl reload nginx

# Check auto-renewal
sudo systemctl status certbot.timer
```

## 📞 Support Resources

### Documentation

- **[Installation Overview](installation-overview.md)**: All deployment options
- **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: RasPi setup
- **[Raspberry Pi Client](raspberry-pi-client.md)**: RasPi as display
- **[Server Architecture](server-architecture.md)**: System overview
- **[Database Setup](database-setup.md)**: Configure PostgreSQL
- **[Email Configuration](email-configuration.md)**: Set up SMTP
- **[Scoreboard Autostart](scoreboard-autostart.md)**: Kiosk mode

### Community & Help

**GitHub**:
- Repository: [https://github.com/GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
- Issues: Report bugs, feature requests
- Discussions: Ask questions

**Contact**:
- Email: gernot.ullrich@gmx.de
- For critical problems: detailed error description with logs

### Further Information

**Rails documentation**:
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Rails API Docs](https://api.rubyonrails.org/)

**PostgreSQL**:
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)

**Nginx**:
- [Nginx Docs](https://nginx.org/en/docs/)
- [WebSocket Proxying](https://nginx.org/en/docs/http/websocket.html)

## 🔗 All Administrator Documents

1. **[Installation Overview](installation-overview.md)** - All deployment options
2. **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)** - All-in-One setup
3. **[Raspberry Pi Client](raspberry-pi-client.md)** - Display/Scoreboard only
4. **[Scoreboard Autostart](scoreboard-autostart.md)** - Set up kiosk mode
5. **[Server Architecture](server-architecture.md)** - System components
6. **[Email Configuration](email-configuration.md)** - Set up SMTP
7. **[Database Setup](database-setup.md)** - Configure PostgreSQL
8. **[Table Reservation & Heating](../managers/table-reservation.md)** - Hardware integration

---

**Good luck with administration! 🖥️**

*Tip: Document your specific installation (server details, specifics) in a separate, secure document. Credentials belong in `carambus_data/secrets.yml`, not in the documentation.*
