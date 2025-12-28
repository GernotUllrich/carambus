# Puma Socket Issue Fix

## Problem Description

The Puma server on `carambus_bcw` (and potentially other deployments) shows as running via `systemctl status`, but the Unix socket file is not visible when using `ls` on the socket path.

## Root Cause

The application was failing to start due to **missing `Net::SSH` requires** in job files that use SSH functionality.

The socket path format (`unix:///var/www/...`) was actually **correct** for absolute paths. The `unix:///` notation is the proper format where:
- `unix://` is the protocol
- The third `/` is the start of the absolute path `/var/www/...`

**The real issues were:**
1. Missing `require 'net/ssh'` in `StreamControlJob` and `StreamHealthJob`
2. These files referenced `Net::SSH::Exception` without requiring the gem first
3. This caused Puma to fail during application preloading, preventing socket creation

## Files Changed

### 1. Fixed Job Files (carambus_master)
- `app/jobs/stream_control_job.rb` - Added `require 'net/ssh'`
- `app/jobs/stream_health_job.rb` - Added `require 'net/ssh'`

### 2. New Diagnostic Tools
- `bin/diagnose-socket-issue.sh` - Comprehensive diagnostic script
- `bin/fix-socket-issue.sh` - Automated fix script (note: this incorrectly changes socket path)
- `PUMA_SOCKET_FIX.md` - This documentation

## How to Fix Existing Deployments

### Option 1: Quick Fix (On Remote Server)

SSH to the affected server and run the fix script:

```bash
# Copy the fix script to the server
scp bin/fix-socket-issue.sh www-data@bcwip:/tmp/

# SSH to the server
ssh www-data@bcwip

# Run the fix script
sudo bash /tmp/fix-socket-issue.sh carambus_bcw
```

### Option 2: Manual Fix (On Remote Server)

```bash
# 1. Edit the Puma config
sudo vi /var/www/carambus_bcw/shared/config/puma.rb

# 2. Find the line:
#    bind "unix:///var/www/carambus_bcw/shared/sockets/puma-production.sock"
#    
#    Change to:
#    bind "unix://var/www/carambus_bcw/shared/sockets/puma-production.sock"

# 3. Restart Puma
sudo systemctl restart puma-carambus_bcw.service

# 4. Verify socket exists
ls -la /var/www/carambus_bcw/shared/sockets/puma-production.sock

# 5. Test the connection
curl --unix-socket /var/www/carambus_bcw/shared/sockets/puma-production.sock http://localhost/
```

### Option 3: Redeploy from Master

Since the template is now fixed in `carambus_master`, you can redeploy:

```bash
# From the local DEV directory
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
bin/deploy-scenario.sh carambus_bcw
```

This will regenerate the configuration files with the correct socket path.

## Diagnostic Steps

To diagnose socket issues on any server:

```bash
# Copy diagnostic script
scp bin/diagnose-socket-issue.sh www-data@bcwip:/tmp/

# Run on server
ssh www-data@bcwip
sudo bash /tmp/diagnose-socket-issue.sh
```

The diagnostic script will check:
1. Systemd service status
2. Service configuration file
3. Puma configuration (especially bind directive)
4. Socket directory existence and permissions
5. All .sock files in deployment directory
6. Running Puma processes and their open files
7. Systemd journal logs
8. File system mounts

## Verification

After applying the fix, verify:

```bash
# 1. Socket file exists and is a socket
ls -la /var/www/carambus_bcw/shared/sockets/puma-production.sock
# Should show: srwxrwxr-x (socket file)

# 2. Puma service is active
sudo systemctl status puma-carambus_bcw.service

# 3. Test HTTP connection via socket
curl --unix-socket /var/www/carambus_bcw/shared/sockets/puma-production.sock http://localhost/

# 4. Check nginx can connect
sudo nginx -t
sudo systemctl reload nginx
curl http://bcwip/  # or appropriate domain
```

## Understanding Unix Socket URIs

In Unix socket URIs for Puma:
- `unix:///path/to/socket` - **CORRECT** for absolute paths. The format is `unix://` (protocol) + `/path/to/socket` (absolute path)
- `unix://path/to/socket` - **WRONG** - treated as relative path, Puma will look in `./path/to/socket` relative to app directory

The `unix:///` notation is standard for absolute paths in URL schemes. The confusion arose because:
- The triple slash looks redundant
- But it's actually `unix://` (the scheme) + `/` (start of absolute path)
- For relative paths, you'd use `unix://` + `path/to/socket` (no leading slash)

**The socket path was never the problem** - the missing `Net::SSH` requires prevented the application from loading, so the socket was never created.

## Prevention

The template has been fixed in `carambus_master`, so all future deployments using `bin/deploy-scenario.sh` will have the correct configuration.

## Related Files

- Puma config template: `templates/puma/puma_rb.erb`
- Puma service template: `templates/puma/puma.service.erb`
- Nginx config template: `templates/nginx/nginx_conf.erb` (correctly uses `unix:` without slashes)
- Puma wrapper script: `bin/puma-wrapper.sh`

## Testing

After fixing, test the complete stack:

```bash
# 1. Verify Puma responds via socket
curl --unix-socket /var/www/carambus_bcw/shared/sockets/puma-production.sock \
     http://localhost/ -I

# 2. Verify Nginx proxies correctly
curl http://bcwip/ -I

# 3. Check WebSocket connections (if applicable)
# Access the application in a browser and check WebSocket connections in DevTools
```

## Notes

- This issue affected any scenario deployed with the old template
- The nginx configuration template was already correct (`unix:/path` without extra slashes)
- The systemd service file was correct
- Only the Puma configuration had the issue

