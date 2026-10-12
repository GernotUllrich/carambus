# Deployment Options for Carambus

A detailed comparison of all operating models with decision aids for different deployment scenarios.

## Overview of Deployment Options

Carambus offers three basic deployment models that differ in complexity, cost, and use case:

| Aspect | Cloud Hosting | On-Premise Server | Raspberry Pi All-in-One |
|--------|---------------|-------------------|-------------------------|
| **Ideal for** | Federations, Multi-location | Privacy-sensitive | Individual clubs |
| **Initial costs** | Low | Medium-High | Very low |
| **Running costs** | 10-50 EUR/month | Power + Internet | Power only (~2 EUR/month) |
| **IT skills** | Medium | High | Low |
| **Setup time** | 2-4 hours | 1-2 days | 30-60 minutes |
| **Internet required** | Yes (always) | No (optional) | No (optional) |
| **Maintenance effort** | Low | Medium | Very low |
| **Scalability** | Excellent | Good | Limited |
| **Data control** | With provider | Complete | Complete |

---

## Option 1: Cloud Hosting

### Description

The system is installed on a rented web server (VPS, cloud instance) and is accessible to all users via the internet. The operator doesn't need to worry about hardware but pays ongoing hosting fees.

### Technical Requirements

**Server Specifications (Minimum)**:
- **CPU**: 2 vCores
- **RAM**: 4 GB
- **Storage**: 20 GB SSD
- **Bandwidth**: 1 TB/month
- **OS**: Ubuntu 22.04 LTS or newer

**Recommended Specifications** (for 100+ concurrent users):
- **CPU**: 4 vCores
- **RAM**: 8 GB
- **Storage**: 50 GB SSD
- **Bandwidth**: Unlimited
- **Backup**: Daily snapshots

### Hosting Providers (Examples)

#### Budget Option: Hetzner Cloud
- **Model**: CPX21
- **Price**: ~8 EUR/month
- **Specs**: 3 vCPU, 4 GB RAM, 80 GB SSD
- **Location**: Germany (GDPR-compliant)
- **Suitable for**: Up to 50 concurrent users

#### Standard Option: DigitalOcean
- **Model**: Droplet 4GB
- **Price**: ~24 USD/month
- **Specs**: 2 vCPU, 4 GB RAM, 80 GB SSD
- **Location**: Frankfurt available
- **Suitable for**: Up to 100 concurrent users

#### Premium Option: AWS/Azure
- **Price**: From 30 EUR/month (variable)
- **Advantage**: Enterprise-grade, auto-scaling
- **Suitable for**: Large federations, critical applications

### Advantages

✅ **Central management**: One system for all clubs/locations  
✅ **Available everywhere**: Access from any location with internet  
✅ **No hardware**: No own server required  
✅ **Easy scaling**: Book more resources when needed  
✅ **Automatic backups**: Usually included in hosting package  
✅ **Professional infrastructure**: 99.9% uptime guarantee  
✅ **SSL certificates**: Free via Let's Encrypt  

### Disadvantages

❌ **Running costs**: Monthly fees  
❌ **Internet dependency**: Only works with internet connection  
❌ **Privacy**: Data resides with provider  
❌ **Shared resources**: Performance can fluctuate  

### Cost Calculation (36 months)

**Budget Setup (Hetzner CPX21)**:
- Hosting: 8 EUR × 36 = 288 EUR
- Domain: 10 EUR/year × 3 = 30 EUR
- **Total**: ~320 EUR

**Standard Setup (DigitalOcean)**:
- Hosting: 24 USD × 36 ≈ 760 EUR
- Domain: 10 EUR/year × 3 = 30 EUR
- Backup service: 5 USD × 36 ≈ 160 EUR
- **Total**: ~950 EUR

### Setup Process

1. **Book VPS** (30 minutes)
   - Create account with hosting provider
   - Select and start server instance
   - Set up SSH access

2. **Prepare system** (1 hour)
   - Install Ubuntu (usually pre-installed)
   - Configure firewall
   - Apply updates
   - Install PostgreSQL

3. **Install Carambus** (1-2 hours)
   - Install Ruby and Rails dependencies
   - Check out Carambus code via Git
   - Set up database
   - Compile assets

4. **Configure web server** (30 minutes)
   - Install and configure Nginx
   - SSL certificate via Let's Encrypt
   - Configure domain DNS

5. **Go live** (15 minutes)
   - Set up systemd service
   - Start server and test
   - Activate monitoring

**Total time required**: 3-4 hours (for experienced admins)

### Maintenance

**Regularly required**:
- Security updates: 1× monthly (15 minutes)
- Carambus updates: As needed (30 minutes)
- Backup checks: 1× weekly (5 minutes)
- Performance monitoring: Ongoing (automated)

**Estimated time required**: 2-3 hours/month

### Recommended for

- ✅ State or national federations with many clubs
- ✅ Clubs with multiple venues
- ✅ Tournaments with online registration from outside
- ✅ Scenarios where access is needed from everywhere
- ✅ Organizations with IT budget but without IT staff

---

## Option 2: On-Premise Server

### Description

The system runs on your own server in the clubhouse or data center. Full control over hardware and data, but also responsibility for operation and maintenance.

### Hardware Options

#### Budget: Raspberry Pi 4 (8GB) as Server
- **Cost**: ~100 EUR
- **Consumption**: ~5W (~1 EUR/month)
- **Performance**: Good for small clubs (<50 members)
- **Advantage**: Very cheap, silent, compact

#### Standard: Intel NUC / Mini PC
- **Cost**: 300-500 EUR
- **Specs**: Intel i3/i5, 8-16 GB RAM, 256 GB SSD
- **Consumption**: ~15W (~3 EUR/month)
- **Performance**: Very good for medium-sized clubs
- **Advantage**: Quiet, compact, reliable

#### Premium: Tower Server / NAS
- **Cost**: 800-2,000 EUR
- **Specs**: Xeon/Ryzen, 32+ GB RAM, RAID storage
- **Consumption**: ~50-100W (~10-20 EUR/month)
- **Performance**: Excellent, even for large federations
- **Advantage**: Professional, fail-safe (RAID), expandable

### Network Requirements

**Minimal**:
- LAN connection (100 Mbit/s)
- Access to local network
- Optional: Internet access for ClubCloud sync

**Recommended**:
- Gigabit LAN
- Static IP in local network
- UPS (Uninterruptible Power Supply)
- VPN for remote access

**For Internet Access** (optional):
- Static public IP or DynDNS
- Port forwarding in router (ports 80, 443)
- SSL certificate

### Advantages

✅ **Full data control**: All data stays in-house  
✅ **No running costs**: Only one-time hardware purchase  
✅ **Internet-independent**: Works even during outages  
✅ **Fast on LAN**: Best performance for local users  
✅ **GDPR-secure**: Ideal for privacy-sensitive environments  
✅ **Customizable**: Full control over configuration  

### Disadvantages

❌ **Hardware purchase**: Initial investment required  
❌ **Maintenance effort**: Perform updates, backups yourself  
❌ **IT knowledge**: Linux knowledge required  
❌ **Power costs**: Continuous operating costs  
❌ **Failure risk**: No professional hosting SLA  
❌ **No remote access**: Only in local network (except VPN)  

### Cost Calculation (36 months)

**Budget Setup (Raspberry Pi 4)**:
- Hardware: 100 EUR
- Power costs: 1 EUR × 36 = 36 EUR
- Backup (USB HDD): 50 EUR
- **Total**: ~186 EUR

**Standard Setup (Intel NUC)**:
- Hardware: 400 EUR
- Power costs: 3 EUR × 36 = 108 EUR
- UPS: 80 EUR
- Backup NAS: 150 EUR
- **Total**: ~738 EUR

**Premium Setup (Tower Server)**:
- Hardware: 1,500 EUR
- Power costs: 15 EUR × 36 = 540 EUR
- UPS: 200 EUR
- Network switch: 100 EUR
- **Total**: ~2,340 EUR

### Setup Process

1. **Procure hardware** (delivery time varies)
2. **Install operating system** (1 hour)
   - Install Ubuntu Server 22.04 LTS
   - Configure network
   - Set up SSH
3. **Harden system** (1 hour)
   - Activate firewall (ufw)
   - Install Fail2ban
   - Configure automatic updates
4. **Install Carambus** (2-3 hours)
   - Install dependencies
   - Set up PostgreSQL
   - Deploy Carambus
5. **Set up backup** (1 hour)
   - Daily database backups
   - Automate backup script

**Total time required**: 6-8 hours (for experienced Linux admins)

### Maintenance

**Regularly required**:
- Security updates: 1× weekly (10 minutes)
- Backup checks: 1× weekly (10 minutes)
- Hardware check: 1× monthly (30 minutes)
- Log monitoring: When problems occur

**Estimated time required**: 3-4 hours/month

### Recommended for

- ✅ Clubs with own IT infrastructure
- ✅ Privacy-sensitive environments
- ✅ Clubs with IT-savvy members
- ✅ Scenarios without reliable internet
- ✅ Long-term cost minimization desired

---

## Option 3: Raspberry Pi All-in-One

### Description

The most elegant solution for small to medium-sized clubs: A Raspberry Pi serves simultaneously as server AND kiosk display. Connected to a TV/monitor in the clubhouse, it permanently shows the tournament monitor or scoreboard. Other devices (tablets, smartphones) can connect on the local network.

### Hardware Setup

#### Basic Kit (~150 EUR)
- **Raspberry Pi 4 (8 GB)**: ~90 EUR
- **Power supply (USB-C, 3A)**: ~10 EUR
- **Micro SD card (64 GB)**: ~15 EUR
- **Case with fan**: ~15 EUR
- **HDMI cable**: ~10 EUR
- **Total**: ~140 EUR

#### Touch Display Setup (~350 EUR)
- Basic kit: ~140 EUR
- **Official 7" Touch Display**: ~80 EUR
- **Display mount**: ~20 EUR
- **Touch pen**: ~10 EUR
- Optional: Portable case: ~100 EUR
- **Total**: ~350 EUR

#### Professional Setup (~500 EUR)
- **Raspberry Pi 5 (8 GB)**: ~120 EUR
- Accessories: ~30 EUR
- **External touch display (10-15")**: ~250 EUR
- **Robust tablet case**: ~100 EUR
- **Total**: ~500 EUR

### Software Setup

**Pre-configured image available** (recommended):
- Download pre-configured image
- Flash to SD card (with Balena Etcher)
- One-time configuration (WiFi, club name)
- **Time required**: 30 minutes

**Manual installation**:
- Install Raspberry Pi OS Lite
- Run Carambus installation script
- Configure kiosk mode
- **Time required**: 2-3 hours

### Kiosk Mode Features

- **Automatic start**: System boots directly into Chromium browser
- **Fullscreen**: No menu bars or desktop visible
- **Auto-refresh**: On connection problems
- **Screensaver**: Dim after inactivity
- **Touch optimization**: Large buttons, gesture control
- **Remote maintenance**: SSH access for updates

### Advantages

✅ **Extremely cheap**: Lowest total cost of all options  
✅ **Plug & Play**: Pre-configured image available  
✅ **All-in-One**: Server + display in one device  
✅ **Power-efficient**: < 15W, ~2 EUR/month  
✅ **Compact**: Fits behind any monitor  
✅ **Silent**: No fans (with passive cooling)  
✅ **Touch-capable**: Direct operation on display  
✅ **Internet-optional**: Works completely offline  

### Disadvantages

❌ **Limited performance**: Not for > 100 members  
❌ **Single point of failure**: Device is server AND display  
❌ **SD card risk**: Can fail after years (avoidable with SSD)  
❌ **Not scalable**: Unsuitable for multi-location  

### Cost Calculation (36 months)

**Standard setup**:
- Hardware: 150 EUR (one-time)
- Power costs: 2 EUR × 36 = 72 EUR
- SD card replacement: 15 EUR (after 2 years)
- **Total**: ~237 EUR

**Amortization comparison**:
- **vs. Cloud (Hetzner)**: Amortization after 18 months
- **vs. Cloud (DigitalOcean)**: Amortization after 10 months

### Setup Process (with pre-configured image)

1. **Procure hardware** (online order, 3-5 days)
2. **Download image** (15 minutes)
   - Download from GitHub releases
   - Flash to SD card with Balena Etcher
3. **Set up Raspberry Pi** (15 minutes)
   - Insert SD card
   - Connect HDMI to monitor/TV
   - Connect power → starts automatically
4. **Initial setup** (10 minutes)
   - Configure WiFi (if no LAN)
   - Upload club name and logo
   - Create admin account
5. **Done!** System is ready for use

**Total time required**: 30-60 minutes

### Maintenance

**Very low maintenance**:
- Updates: 1× monthly via SSH (5 minutes)
- Backup: Automatically to USB stick (optional)
- Hardware: Occasionally remove dust

**Estimated time required**: < 1 hour/month

### Typical Use Cases

#### Scenario A: Table Monitor
- Raspberry Pi + 7" touch display
- Wall mount next to billiard table
- Shows current scoreboard
- Players can enter scores themselves

#### Scenario B: Tournament Display
- Raspberry Pi connected to existing TV/projector
- Central display in clubhouse
- Shows tournament monitor with all matches
- Automatic rotation between views

#### Scenario C: Mobile Referee Station
- Raspberry Pi + large tablet display (10-15")
- In portable case
- Referee carries to each table
- Records results directly on-site

### Recommended for

- ✅ Small clubs (< 100 members)
- ✅ Budget-conscious installations
- ✅ Simple, low-maintenance solution desired
- ✅ Single location (no multi-club operation)
- ✅ Primarily local use in clubhouse
- ✅ Quick start without IT knowledge

---

## Comparison Matrix: Extended

### Performance Comparison

| Metric | Cloud (Standard) | On-Premise (NUC) | Raspberry Pi 4 |
|--------|------------------|------------------|----------------|
| **Max concurrent users** | 100+ | 50-100 | 20-30 |
| **Page load time** | 300-500ms | 100-200ms | 500-800ms |
| **WebSocket latency** | 50-100ms | < 10ms | 10-30ms |
| **Database size** | Unlimited | Depends on disk | 32 GB practical |
| **Backup speed** | Fast | Very fast | Slow |

### Security Comparison

| Aspect | Cloud | On-Premise | Raspberry Pi |
|--------|-------|------------|--------------|
| **Physical security** | Professional | Medium | Low |
| **Network isolation** | Provider | Self | Self |
| **DDoS protection** | Included | Self | N/A |
| **Data privacy** | Provider | Complete | Complete |
| **Update frequency** | High | Medium | Medium |
| **Penetration testing** | Provider | Self | Self |

### Availability Comparison

| Criterion | Cloud | On-Premise | Raspberry Pi |
|-----------|-------|------------|--------------|
| **Uptime SLA** | 99.9% | N/A | N/A |
| **Redundancy** | Present | Optional | None |
| **Power outage** | UPS present | UPS recommended | Problematic |
| **Hardware failure** | Quick replacement | Self-procure | Replace SD card |
| **MTTR (Mean Time to Repair)** | < 1 hour | 1-24 hours | < 1 hour |

---

## Decision Aid: Which Option Fits Me?

### Flowchart

```
Do you have more than 200 members?
├─ YES → How many locations?
│   ├─ Multiple → **Cloud Hosting** (recommended)
│   └─ One → On-Premise Server (Premium)
│
└─ NO → Is your budget < 300 EUR?
    ├─ YES → **Raspberry Pi All-in-One** (recommended)
    └─ NO → Do you need external access?
        ├─ YES → Cloud Hosting or On-Premise + VPN
        └─ NO → Raspberry Pi or On-Premise
```

### Quick Check: Your Situation

**You should choose Cloud Hosting if**:
- You have multiple clubs/locations
- You need access from everywhere
- You have no IT staff
- You want to start quickly
- You need scalability

**You should choose On-Premise if**:
- You have strict privacy requirements
- You have IT staff or IT-savvy members
- You want to save costs long-term
- You want internet independence
- You need full control over all aspects

**You should choose Raspberry Pi if**:
- You are a small club (< 100 members)
- You have minimal budget
- You want to start quickly and easily
- You have primarily local use
- You want a low-maintenance solution

---

## Migration Paths

### From Raspberry Pi to Cloud

**When sensible**: Club grows, external access becomes important

**Process**:
1. Create database backup from Raspberry Pi
2. Set up cloud server
3. Import backup to cloud server
4. Switch DNS/URLs
5. Continue using Raspberry Pi as local display client

**Effort**: 2-3 hours, **no data loss**

### From Raspberry Pi to On-Premise

**When sensible**: Performance requirements increase

**Process**:
- Identical to above, only target is local server instead of cloud

### From Cloud to On-Premise

**When sensible**: Privacy requirements change, long-term cost reduction

**Process**:
1. Build on-premise server
2. Download database backup from cloud
3. Import to local server
4. Test in parallel operation
5. Switch and cancel cloud

**Effort**: 4-6 hours

---

## Summary

| Criterion | Cloud | On-Premise | Raspberry Pi |
|-----------|-------|------------|--------------|
| **Best choice for** | Federations | Privacy | Small clubs |
| **Cost (3 years)** | 320-950 EUR | 186-2,340 EUR | ~237 EUR |
| **Setup time** | 3-4 h | 6-8 h | 0.5-1 h |
| **Maintenance/month** | 2-3 h | 3-4 h | < 1 h |
| **IT skills** | Medium | High | Low |
| **Scalability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Simplicity** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

**Recommendation**: Most small to medium clubs are best served with the **Raspberry Pi All-in-One solution**. It's cost-effective, easy to install, and perfectly adequate for typical club operations.

---

*For individual consultation on your specific situation, contact us at gernot.ullrich@gmx.de*







