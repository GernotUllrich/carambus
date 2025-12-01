# Scraper Protection Guide

## Overview

This guide helps you identify and block scraping activity on your Carambus server.

## Quick Start - Finding Scraper IPs

### On Your Server

Log in to your server (as `www-data` user) and run these commands:

```bash
# Set your Rails root
RAILS_ROOT=/var/www/carambus_api/current

# 1. Find top IPs by request count
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | head -20

# 2. Find IPs with more than 100 requests
awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | sort | uniq -c | sort -rn | awk '$1 > 100 {print $1, $2}'

# 3. Identify bot user-agents
grep -iE "(bot|crawler|spider|scraper|python|curl|wget)" $RAILS_ROOT/log/nginx.access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -20

# 4. Block IP subnet (z.B. alle 47.79.x.x)
echo "deny 47.79.0.0/16;" | sudo tee -a /etc/nginx/conf.d/carambus_api_blocklist.conf
sudo nginx -t && sudo systemctl reload nginx
```

Replace `carambus_api` with your scenario name (e.g., `carambus_bcw`).

## Using the Analysis Script

We've created a helper script for comprehensive analysis:

```bash
# On your server, run from Rails root:
cd /var/www/carambus_api/current
./bin/analyze_scrapers.sh

# Or specify the Rails root explicitly:
./bin/analyze_scrapers.sh /var/www/carambus_api/current
```

The script will show you:
1. Top IP addresses by request count
2. Most common User-Agents
3. Who checked robots.txt
4. Most requested paths
5. Suspicious patterns
6. IPs violating robots.txt

## Blocking Scraper IPs

### Method 1: Using Nginx Blocklist File (Recommended)

This is the cleanest approach for managing multiple blocked IPs:

```bash
# On your server, create a blocklist file:
sudo tee /etc/nginx/conf.d/carambus_api_blocklist.conf << 'EOF'
# Blocked IPs - Updated $(date)
deny 123.45.67.89;
deny 98.76.54.32;
deny 11.22.33.0/24;  # Block entire subnet
EOF

# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

Then modify your nginx configuration to include this file. Add inside the `server { }` block:

```nginx
include /etc/nginx/conf.d/carambus_api_blocklist.conf;
```

### Method 2: Direct Nginx Configuration

Edit your nginx site configuration:

```bash
sudo nano /etc/nginx/sites-available/carambus_api
```

Add inside the `server { }` block (near the top):

```nginx
# Block scraper IPs
deny 123.45.67.89;
deny 98.76.54.32;
```

Then reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Advanced Protection

### 1. Rate Limiting

Add to nginx configuration to limit request rates:

```nginx
# In http block (outside server)
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

# In server block
location / {
    limit_req zone=general burst=20 nodelay;
    # ... rest of config
}

location /api/ {
    limit_req zone=api burst=50 nodelay;
    # ... rest of config
}
```

### 2. Better robots.txt with User-Agent Specific Rules

Your nginx config already returns a basic robots.txt. To make it more specific, you could create a static file at `public/robots.txt`:

```txt
User-agent: *
Disallow: /

# Allow specific good bots if needed
User-agent: Googlebot
Disallow: /admin/
Disallow: /api/

User-agent: Bingbot
Disallow: /admin/
Disallow: /api/
```

Note: Your nginx config currently overrides this with `location = /robots.txt`, so you might want to remove lines 52-55 and 129-132 from the nginx template to let the static file be served instead.

### 3. Blocking by User-Agent

Add to nginx configuration:

```nginx
# Block common scraper user-agents
if ($http_user_agent ~* (bot|crawler|spider|scraper|python-requests|curl|wget|scanner)) {
    return 403;
}

# Block empty user-agents
if ($http_user_agent = "") {
    return 403;
}
```

⚠️ **Warning**: `if` statements in nginx can be tricky. Use with caution.

### 4. Geo-Blocking (if needed)

If scraping comes from specific countries:

```bash
# Install GeoIP module
sudo apt-get install libnginx-mod-http-geoip

# In nginx http block:
geoip_country /usr/share/GeoIP/GeoIP.dat;

# In server block:
if ($geoip_country_code = CN) {
    return 403;
}
```

## Monitoring

### Check Block Effectiveness

```bash
# Monitor blocked requests
sudo tail -f /var/log/carambus_api/error.log | grep "access forbidden"

# Check if specific IP is being blocked
grep "123.45.67.89" /var/log/carambus_api/access.log | tail -20
```

### Regular Analysis

Set up a cron job to email you daily reports:

```bash
# Add to crontab (crontab -e)
0 9 * * * /var/www/carambus_api/current/bin/analyze_scrapers.sh carambus_api | mail -s "Daily Scraper Report" your@email.com
```

## Log Files Location

Die relevanten nginx access logs befinden sich in:

- **Main access log**: `RAILS_ROOT/log/nginx.access.log`
  - Z.B. `/var/www/carambus_api/current/log/nginx.access.log`
  - Z.B. `/var/www/carambus_bcw/current/log/nginx.access.log`
- **Nginx error log**: `/var/log/nginx/error.log`
- **Scenario-specific error log**: `/var/log/<scenario_name>/error.log` (optional, wenn konfiguriert)

## Common Scraper Patterns to Watch For

1. **High request rate** (>100 requests in short time)
2. **Sequential page crawling** (accessing URLs in order)
3. **Ignoring robots.txt**
4. **Suspicious User-Agents** (python-requests, curl, generic names)
5. **Empty User-Agent strings**
6. **Accessing non-existent URLs** (lots of 404s)
7. **Same IP hitting multiple endpoints rapidly**

## Helper Scripts

We've created several scripts to help:

- `bin/analyze_scrapers.sh` - Comprehensive log analysis
- `bin/extract_scraper_ips.sh` - Extract high-frequency IPs
- `bin/block_scraper_ips.sh` - Generate block configuration

## Example Workflow

1. **Identify scrapers**:
   ```bash
   cd /var/www/carambus_api/current
   ./bin/analyze_scrapers.sh
   ```

2. **Extract IPs to block** (>100 requests):
   ```bash
   RAILS_ROOT=/var/www/carambus_api/current
   awk '{print $1}' $RAILS_ROOT/log/nginx.access.log | \
     sort | uniq -c | sort -rn | \
     awk '$1 > 100 {print "deny "$2";"}' > /tmp/blocklist.txt
   
   # Add IP subnet blocks
   echo "deny 47.79.0.0/16;" >> /tmp/blocklist.txt
   ```

3. **Review the list**:
   ```bash
   cat /tmp/blocklist.txt
   ```

4. **Apply blocks**:
   ```bash
   sudo tee /etc/nginx/conf.d/carambus_api_blocklist.conf < /tmp/blocklist.txt
   sudo nginx -t
   sudo systemctl reload nginx
   ```

5. **Monitor**:
   ```bash
   tail -f /var/www/carambus_api/current/log/nginx.access.log
   ```

## Testing Blocks

Test if an IP is blocked:

```bash
# From another machine or using a proxy:
curl -I http://your-server.com

# Simulate a blocked IP (if using X-Forwarded-For):
curl -I http://your-server.com -H "X-Forwarded-For: 123.45.67.89"
```

## Notes

- Always run `sudo nginx -t` before reloading nginx to catch configuration errors
- Keep a backup of your nginx configuration before making changes
- Monitor your error logs after implementing blocks to ensure legitimate users aren't affected
- Some "scraping" might be legitimate monitoring tools - review before blocking
- Consider whitelisting your own IPs if you use monitoring services

## Further Reading

- [Nginx Rate Limiting](https://www.nginx.com/blog/rate-limiting-nginx/)
- [Nginx Access Control](https://docs.nginx.com/nginx/admin-guide/security-controls/controlling-access-proxied-http/)
- [robots.txt Specification](https://www.robotstxt.org/)

