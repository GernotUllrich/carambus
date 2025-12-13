# Quick Guide: Find and Block Scraper IPs

## Log File Location

Die nginx access logs befinden sich in: **`RAILS_ROOT/log/nginx.access.log`**

Z.B.:
- `/var/www/carambus_api/current/log/nginx.access.log`
- `/var/www/carambus_bcw/current/log/nginx.access.log`

## IP Management mit WHITELIST/BLACKLIST

Das System unterstützt `/root/WHITELIST` und `/root/BLACKLIST` Dateien zur IP-Klassifizierung.

**Verwendung des Unclassified IPs Finders:**
```bash
# Findet IPs, die weder in WHITELIST noch BLACKLIST sind
cd /var/www/carambus_api/current
./bin/find_unclassified_ips.sh

# Mit Mindestanzahl von Requests (Standard: 10)
./bin/find_unclassified_ips.sh 50  # nur IPs mit ≥50 Requests
```

## Step 1: Find Scraper IPs

SSH to your server as `www-data` user and run these commands:

```bash
# Set your Rails root path
RAILS_ROOT=/var/www/carambus_api/current

# Show top 20 IPs by request count
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -20
```

This will show output like:
```
   1523 123.45.67.89
    876 98.76.54.32
    654 11.22.33.44
    ...
```

The first column is the number of requests, the second is the IP address.

## Step 2: Identify Suspicious IPs

Look for:
- **Very high request counts** (>100 requests might be suspicious)
- **Bot user-agents** - check with:

```bash
grep -iE '(bot|crawler|spider|scraper|python|curl|wget)' $RAILS_ROOT/log/nginx.access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -20
```

## Step 3: Generate Block List

Get all IPs with more than 100 requests and format them for nginx:

```bash
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '$1 > 100 {print "deny "$2";"}' > /tmp/scrapers_to_block.conf
```

### Block Entire IP Ranges

To block all IPs starting with `47.79.`:

```bash
echo "deny 47.79.0.0/16;" >> /tmp/scrapers_to_block.conf
```

Review the file:
```bash
cat /tmp/scrapers_to_block.conf
```

## Step 4: Apply Blocks

Copy the blocklist to nginx configuration directory:

```bash
SCENARIO=carambus_api  # Your scenario name
sudo cp /tmp/scrapers_to_block.conf /etc/nginx/conf.d/${SCENARIO}_blocklist.conf
```

Edit your nginx site configuration to include the blocklist:

```bash
sudo nano /etc/nginx/sites-available/$SCENARIO
```

Add this line inside the `server {` block (near the top, after `root` line):

```nginx
include /etc/nginx/conf.d/carambus_api_blocklist.conf;
```

Test the configuration:

```bash
sudo nginx -t
```

If test passes, reload nginx:

```bash
sudo systemctl reload nginx
```

## Step 5: Monitor

Watch the access log to see if blocks are working:

```bash
tail -f $RAILS_ROOT/log/nginx.access.log
```

Check nginx error log for blocked attempts:

```bash
sudo tail -f /var/log/nginx/error.log
```

## Quick One-Liners

```bash
# Set your Rails root
RAILS_ROOT=/var/www/carambus_api/current
```

**Show only IPs with >100 requests:**
```bash
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '$1 > 100'
```

**Show recent high-frequency IPs (last 1000 requests):**
```bash
tail -1000 $RAILS_ROOT/log/nginx.access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -15
```

**Count total unique IPs:**
```bash
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort -u | wc -l
```

**See what paths are being scraped:**
```bash
awk '{print $7}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -30
```

**Block IP subnet (z.B. alle 47.79.x.x IPs):**
```bash
echo "deny 47.79.0.0/16;" | sudo tee -a /etc/nginx/conf.d/carambus_api_blocklist.conf
sudo nginx -t && sudo systemctl reload nginx
```

## Manual Block (Alternative to blocklist file)

If you prefer to block individual IPs directly in the nginx config:

```bash
sudo nano /etc/nginx/sites-available/carambus_api
```

Add inside `server {` block:
```nginx
deny 123.45.67.89;
deny 98.76.54.32;
```

Then:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Unblock an IP

Edit the blocklist file:
```bash
sudo nano /etc/nginx/conf.d/carambus_api_blocklist.conf
```

Remove or comment out the line with the IP:
```nginx
# deny 123.45.67.89;  # Unblocked on 2025-11-30
```

Reload nginx:
```bash
sudo systemctl reload nginx
```

## Managing WHITELIST and BLACKLIST

**WHITELIST Format** (`/root/WHITELIST`):
```
# Trusted IPs and networks - one per line
# Supports single IPs and CIDR notation
192.168.2.0/24  # Local network (192.168.2.0 - 192.168.2.255)
10.0.0.0/8      # Private network (10.0.0.0 - 10.255.255.255)
172.16.0.0/12   # Private network range
123.45.67.89    # Office static IP
11.22.33.44     # Monitoring service
```

**BLACKLIST Format** (`/root/BLACKLIST`):
```
# Blocked IPs and subnets - one per line
# Supports single IPs and CIDR notation
47.79.0.0/16    # Scraper subnet (47.79.0.0 - 47.79.255.255)
12.34.56.78     # Known bad actor
185.220.0.0/14  # Known scraper network
```

**CIDR Notation Beispiele:**
- `192.168.1.0/24` = alle IPs von 192.168.1.0 bis 192.168.1.255 (256 IPs)
- `192.168.0.0/16` = alle IPs von 192.168.0.0 bis 192.168.255.255 (65.536 IPs)
- `10.0.0.0/8` = alle IPs von 10.0.0.0 bis 10.255.255.255 (16.777.216 IPs)
- `47.79.0.0/16` = alle IPs von 47.79.0.0 bis 47.79.255.255

**Add to WHITELIST:**
```bash
# Einzelne IP
echo "123.45.67.89  # Office IP" | sudo tee -a /root/WHITELIST

# Lokales Netzwerk (alle 192.168.2.x IPs)
echo "192.168.2.0/24  # Local network" | sudo tee -a /root/WHITELIST

# Alle privaten 10.x.x.x IPs
echo "10.0.0.0/8  # Private network" | sudo tee -a /root/WHITELIST
```

**Add to BLACKLIST:**
```bash
# Einzelne IP
echo "12.34.56.78  # Bad actor" | sudo tee -a /root/BLACKLIST

# IP-Subnet blocken (alle 47.79.x.x IPs)
echo "47.79.0.0/16  # Scraper subnet" | sudo tee -a /root/BLACKLIST
```

## Helper Scripts

- `bin/find_unclassified_ips.sh` - Find IPs not in WHITELIST or BLACKLIST
- `bin/analyze_scrapers.sh` - Comprehensive log analysis
- `bin/extract_scraper_ips.sh` - Extract high-frequency IPs
- `bin/block_scraper_ips.sh` - Generate nginx block configs

## Notes

- Replace `carambus_api` with your actual scenario name (`carambus_bcw`, etc.)
- You can adjust the threshold (100 requests) based on your traffic patterns
- Some high-frequency IPs might be legitimate (monitoring services, CDNs) - review before blocking
- Use WHITELIST to protect legitimate IPs from accidental blocking
- Keep backups of your nginx configuration before making changes
- Monitor logs after blocking to ensure legitimate users aren't affected

