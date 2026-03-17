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
**Setup time**: 30-60 minutes  
**Difficulty**: ⭐ Easy

➡️ **[Raspberry Pi Quickstart Guide](raspberry-pi-quickstart.md)**

### Option 2: Cloud Hosting (Recommended for Federations)
**Setup time**: 2-4 hours  
**Difficulty**: ⭐⭐ Medium

➡️ **[Installation Overview - Cloud Setup](installation-overview.en.md#cloud-hosting)**

### Option 3: On-Premise Server
**Setup time**: 1-2 days  
**Difficulty**: ⭐⭐⭐ Demanding

➡️ **[Installation Overview - On-Premise](installation-overview.en.md#on-premise)**

## 📚 Main Topics

### 1. Installation

**Basic installation**:
- System requirements
- Operating system setup (Ubuntu)
- Install dependencies
- Deploy Carambus
- Initial configuration

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
- Automatic start on boot
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
- Log rotation
- Performance monitoring

**Backup & Restore**:
- Database backups
- File backups (uploads, logs)
- Restore procedures
- Disaster recovery

### 5. Security

**System hardening**:
- Firewall configuration (ufw)
- Fail2ban against brute force
- SSL/TLS certificates (Let's Encrypt)
- Secure credential management
- Access controls

**Best practices**:
- Regular security updates
- Enforce strong passwords
- Enable 2FA (optional)
- Log monitoring
- Penetration tests

➡️ **[Security Best Practices](installation-overview.en.md#security)**

### 6. Monitoring & Troubleshooting

**Performance monitoring**:
- CPU/RAM utilization
- Database performance
- WebSocket connections
- Request times
- Error rates

**Log analysis**:
- Application logs
- Nginx/Apache logs
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
- FFmpeg hardware encoding
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
- Raspberry Pi 4 (8GB RAM recommended) or Raspberry Pi 5
- Micro SD card (64 GB, Class 10)
- Power supply (USB-C, 3A)
- HDMI cable
- Optional: Touch display (7" or larger)

**Software setup**:
1. **Download image**: Pre-configured Carambus image
2. **Flash SD card**: With Balena Etcher or Raspberry Pi Imager
3. **Initial configuration**: WiFi, club name, admin account
4. **Done!**: System boots in kiosk mode

➡️ **[Detailed Raspberry Pi Guide](raspberry-pi-quickstart.md)**

### Cloud Hosting (VPS)

**Provider recommendations**:
- **Hetzner Cloud**: 8 EUR/month (CPX21: 3 vCPU, 4 GB RAM)
- **DigitalOcean**: 24 USD/month (4 GB Droplet)
- **AWS/Azure**: From 30 EUR/month (variable costs)

**Installation steps**:
1. Book and start VPS
2. Install Ubuntu 22.04 LTS
3. Harden base system
4. Install dependencies
5. Deploy Carambus
6. Configure web server
7. Set up SSL
8. Configure systemd service
9. Configure backup
10. Set up monitoring

➡️ **[Cloud Installation Guide](installation-overview.en.md#cloud-hosting)**

### On-Premise Server

**Hardware options**:
- **Budget**: Raspberry Pi 4 as server only (~100 EUR)
- **Standard**: Intel NUC or mini PC (~400 EUR)
- **Premium**: Tower server with RAID (~1,500 EUR)

➡️ **[On-Premise Installation Guide](installation-overview.en.md#on-premise)**

## 🔧 Maintenance Checklist

### Daily (automated)
- ✅ Database backup
- ✅ Log rotation
- ✅ Monitoring checks

### Weekly
- 🔍 Check backup integrity
- 🔍 Review logs for errors
- 🔍 Check disk space
- 🔍 View performance metrics

### Monthly
- 🔄 Apply system updates (security)
- 🔄 Check and install Carambus updates
- 🔄 Check SSL certificate expiration
- 🔄 Test backup restore

### Quarterly
- 📊 Performance analysis
- 📊 Capacity planning
- 📊 Security audit
- 📊 Update documentation

### Annually
- 🔒 Penetration test (optional)
- 🔒 Disaster recovery test
- 🔒 Check hardware condition
- 🔒 License reviews

## 🆘 Troubleshooting Guide

### Problem: Application won't start

**Debugging**:
```bash
sudo systemctl status carambus
sudo journalctl -u carambus -n 100
```

**Common causes**:
- Database not reachable
- Missing credentials
- Port already in use
- Missing dependencies

### Problem: WebSockets not working

**Symptoms**: Scoreboards don't update in real-time

**Checks**:
```bash
sudo nginx -t
tail -f log/production.log | grep Cable
redis-cli ping  # if using Redis
```

### Problem: Slow performance

**Diagnosis**:
```bash
htop
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

### Problem: Disk space full

**Solution**:
```bash
df -h
sudo journalctl --vacuum-time=7d
rails log:clear
```

## 📞 Support Resources

### Documentation

- **[Installation Overview](installation-overview.md)**: All deployment options
- **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: RasPi setup
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

*Tip: Document your specific installation (server details, passwords, specifics) in a separate, secure document.*




