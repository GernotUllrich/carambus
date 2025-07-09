# Scoreboard Autostart Setup Guide

## Quick Start Guide (Begin Here)

### Step 1: Install required tools
```bash
sudo apt update
sudo apt install wmctrl
```

### Step 2: Configure the scoreboard URL
Edit the config file to set your scoreboard URL:
```bash
nano config/scoreboard_url
```

The default URL is:
```
http://localhost:3000/locations/1/scoreboard_reservations
```

Change it to your actual scoreboard URL if needed.

### Step 3: Make scripts executable
```bash
chmod +x bin/start-scoreboard.sh
chmod +x bin/exit-scoreboard.sh
chmod +x bin/restart-scoreboard.sh
```

### Step 4: Test the startup script manually
```bash
./bin/start-scoreboard.sh
```

### Step 5: If it works, add to autostart
```bash
nano ~/.config/lxsession/LXDE-pi/autostart
```

Add this line at the end (adjust path to your Rails app location):
```
@/path/to/your/rails/app/bin/autostart-scoreboard.sh
```

For example, if your Rails app is in `/var/www/carambus/current`:
```
@/var/www/carambus/current/bin/autostart-scoreboard.sh
```

**Note:** Use the `autostart-scoreboard.sh` wrapper script instead of `start-scoreboard.sh` directly for better autostart compatibility.

### Step 6: Reboot to test
```bash
sudo reboot
```

## Complete Setup (Advanced)

### Configure Keyboard Shortcuts (Optional)
```bash
nano ~/.config/labwc/rc.xml
```

Add inside `<keyboard>` section (adjust paths to your Rails app location):
```xml
<keybind key="F12">
  <action name="Execute">
    <command>/path/to/your/rails/app/bin/exit-scoreboard.sh</command>
  </action>
</keybind>

<keybind key="F11">
  <action name="Execute">
    <command>/path/to/your/rails/app/bin/restart-scoreboard.sh</command>
  </action>
</keybind>
```

For example, if your Rails app is in `/home/pi/carambus_gernot`:
```xml
<keybind key="F12">
  <action name="Execute">
    <command>/home/pi/carambus_gernot/bin/exit-scoreboard.sh</command>
  </action>
</keybind>

<keybind key="F11">
  <action name="Execute">
    <command>/home/pi/carambus_gernot/bin/restart-scoreboard.sh</command>
  </action>
</keybind>
```

## Alternative: Systemd User Service (Recommended)

If window manager autostart doesn't work, use systemd user service instead:

### Step 1: Create systemd user service for www-data user
```bash
# Switch to www-data user
sudo -u www-data bash

# Create systemd user directory in www-data's home
mkdir -p /var/www/.config/systemd/user
nano /var/www/.config/systemd/user/scoreboard.service
```

Add this content:
```ini
[Unit]
Description=Scoreboard Autostart
After=graphical-session.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/var/www/carambus/current/bin/autostart-scoreboard.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
```

### Step 2: Enable and start the service as www-data
```bash
# Still as www-data user
systemctl --user enable scoreboard.service
systemctl --user start scoreboard.service
```

### Step 3: Check service status
```bash
systemctl --user status scoreboard.service
```

### Step 4: Test autostart
```bash
sudo reboot
```

### Step 5: Check if it worked
```bash
# As www-data user
cat /tmp/scoreboard-autostart.log
systemctl --user status scoreboard.service
```

### Remote management as www-data user
```bash
# SSH as www-data user
ssh www-data@raspberrypi

# Then use systemctl commands
systemctl --user restart scoreboard.service
systemctl --user status scoreboard.service
systemctl --user stop scoreboard.service
systemctl --user start scoreboard.service

# View logs
cat /tmp/scoreboard-autostart.log
journalctl --user -u scoreboard.service
```

### Troubleshooting systemd service
```bash
# Check service logs (as www-data user)
journalctl --user -u scoreboard.service

# Restart service
systemctl --user restart scoreboard.service

# Disable service
systemctl --user disable scoreboard.service
```

## Alternative: System-wide Service (Recommended for www-data)

Since www-data user doesn't have display access, use a system-wide service instead:

### Step 1: Create system-wide service
```bash
sudo nano /etc/systemd/system/scoreboard.service
```

Add this content:
```ini
[Unit]
Description=Scoreboard Autostart
After=graphical-session.target

[Service]
Type=oneshot
User=pj
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pj/.Xauthority
Environment=HOME=/home/pj
ExecStartPre=/bin/bash -c "sleep 15"
ExecStart=/var/www/carambus/current/bin/autostart-scoreboard.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
```

### Step 2: Enable and start the service
```bash
sudo systemctl enable scoreboard.service
sudo systemctl start scoreboard.service
```

### Step 3: Check service status
```bash
sudo systemctl status scoreboard.service
```

### Step 4: Remote management as www-data
```bash
# SSH as www-data user
ssh www-data@raspberrypi

# Then use systemctl commands (with sudo)
sudo systemctl restart scoreboard.service
sudo systemctl status scoreboard.service
sudo systemctl stop scoreboard.service
sudo systemctl start scoreboard.service

# View logs
cat /tmp/scoreboard-autostart.log
sudo journalctl -u scoreboard.service
```

### Step 5: Test autostart
```bash
sudo reboot
```

This approach runs the service as the `pi` user (who has display access) but can be controlled by the `www-data` user via sudo.

### Troubleshooting system-wide service
```bash
# Check service status (as pi user or with sudo)
sudo systemctl status scoreboard.service

# Check detailed logs (as pi user or with sudo)
sudo journalctl -u scoreboard.service -f

# Check if the script works manually (as pi user)
sudo -u pi /var/www/carambus/current/bin/autostart-scoreboard.sh

# Check if www-data can run sudo commands
sudo -l

# Add www-data to sudoers if needed
sudo visudo
# Add this line: www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl
```

## Remote Management

The systemd user service enables powerful remote management capabilities:

### Remote commands
```bash
# Restart scoreboard remotely
ssh pi@raspberrypi 'systemctl --user restart scoreboard.service'

# Check status remotely
ssh pi@raspberrypi 'systemctl --user status scoreboard.service'

# View logs remotely
ssh pi@raspberrypi 'cat /tmp/scoreboard-autostart.log'

# Stop scoreboard for maintenance
ssh pi@raspberrypi 'systemctl --user stop scoreboard.service'

# Start scoreboard
ssh pi@raspberrypi 'systemctl --user start scoreboard.service'
```

## Exit Methods

The scoreboard runs in fullscreen mode, and there are several ways to exit:

### Primary Exit Methods
1. **Physical Keyboard:** ALT+F4 or ESC (most reliable)
2. **Remote SSH:** `systemctl --user restart scoreboard.service`

### Fallback Exit Method
3. **"Try Resize Window" Button:** 
   - Click the refresh/resize button in the top menu
   - This refreshes the Chromium window state
   - Restores the circled X button in the top-right corner
   - Click the X to exit to desktop

### Why This Works
- The "Try Resize Window" function refreshes the Chromium window state
- This restores window controls that get hidden during scoreboard interactions
- Provides a reliable mouse/touch-based exit method
- Works when other exit methods fail

### Button Location
- **Table Monitors:** Top-right refresh button
- **Scoreboard Pages:** Top-right refresh button
- **All scoreboard interfaces:** Consistent exit method

This gives users a reliable way to exit the scoreboard even without a keyboard!

## Troubleshooting

### Check if wmctrl is installed
```bash
which wmctrl
```

### Check if scripts are executable
```bash
ls -la bin/start-scoreboard.sh
ls -la bin/exit-scoreboard.sh
ls -la bin/restart-scoreboard.sh
```

### Check the scoreboard URL configuration
```bash
cat config/scoreboard_url
```

### Check autostart file
```bash
cat ~/.config/lxsession/LXDE-pi/autostart
```

### Check system logs
```bash
journalctl -u lxsession
```

### Test panel hiding manually
```bash
wmctrl -l
wmctrl -r "panel" -b add,hidden
wmctrl -r "panel" -b remove,hidden
```

### Check if browser starts correctly
```bash
ps aux | grep chromium
```

### Test scripts manually
```bash
# Test startup
./bin/start-scoreboard.sh

# Test exit (in another terminal)
./bin/exit-scoreboard.sh

# Test restart
./bin/restart-scoreboard.sh
```

### Check log files
```bash
# Debug test log (from test-startup.sh)
cat /tmp/scoreboard-debug.log

# Autostart wrapper log (from autostart-scoreboard.sh)
cat /tmp/scoreboard-autostart.log

# Chromium output (if you ran with nohup)
cat nohup.out

# LXDE autostart logs
tail -f ~/.cache/lxsession/LXDE-pi/run.log

# System logs
journalctl -u lxsession
```

### Troubleshooting for /var/www/carambus/current setup

If your Rails app is in `/var/www/carambus/current` and runs as `www-data`:

#### 1. Check script permissions
```bash
sudo ls -la /var/www/carambus/current/bin/start-scoreboard.sh
```

#### 2. Make scripts executable for all users
```bash
sudo chmod +x /var/www/carambus/current/bin/start-scoreboard.sh
sudo chmod +x /var/www/carambus/current/bin/exit-scoreboard.sh
sudo chmod +x /var/www/carambus/current/bin/restart-scoreboard.sh
```

#### 3. Check if the autostart user can read the config file
```bash
sudo ls -la /var/www/carambus/current/config/scoreboard_url
sudo chmod 644 /var/www/carambus/current/config/scoreboard_url
```

#### 4. Test the script manually as the autostart user
```bash
/var/www/carambus/current/bin/start-scoreboard.sh
```

#### 5. Check LXDE autostart logs
```bash
tail -f ~/.cache/lxsession/LXDE-pi/run.log
```

#### 6. Alternative: Use absolute paths in autostart
Edit the autostart file:
```bash
nano ~/.config/lxsession/LXDE-pi/autostart
```

Make sure it contains:
```
@/var/www/carambus/current/bin/start-scoreboard.sh
```

#### 7. Check if wmctrl is available for the autostart user
```bash
which wmctrl
sudo apt install wmctrl  # if not found
```

#### 8. Test with debug output
Create a test script to see what's happening:
```bash
sudo nano /var/www/carambus/current/bin/test-startup.sh
```

Content:
```bash
#!/bin/bash
echo "Starting test at $(date)" >> /tmp/scoreboard-debug.log
echo "Current user: $(whoami)" >> /tmp/scoreboard-debug.log
echo "Current directory: $(pwd)" >> /tmp/scoreboard-debug.log
echo "wmctrl available: $(which wmctrl)" >> /tmp/scoreboard-debug.log
echo "Config file content: $(cat /var/www/carambus/current/config/scoreboard_url)" >> /tmp/scoreboard-debug.log
/var/www/carambus/current/bin/start-scoreboard.sh
echo "Test completed at $(date)" >> /tmp/scoreboard-debug.log
```

Make executable:
```bash
sudo chmod +x /var/www/carambus/current/bin/test-startup.sh
```

Test it:
```bash
/var/www/carambus/current/bin/test-startup.sh
```

Check the debug log:
```bash
cat /tmp/scoreboard-debug.log
```

## Workflow

1. **Boot** → Panel hidden, scoreboard starts in fullscreen
2. **F12** → Exit to desktop (panel visible)
3. **F11** → Restart scoreboard (panel hidden again)

## Notes

- The scripts are now in your Rails app's `bin/` directory and tracked by git
- The scoreboard URL is configurable via `config/scoreboard_url`
- If the panel doesn't hide, try different panel names: `panel`, `lxpanel`, `lxpanel-pi`
- The `2>/dev/null || true` prevents errors if the window doesn't exist
- Make sure your Rails server is running before testing
- Update the paths in autostart and keyboard shortcuts to match your actual Rails app location 