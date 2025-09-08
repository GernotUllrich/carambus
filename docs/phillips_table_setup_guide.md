# Phillip's Table (Location 5101) - Raspberry Pi Setup Guide

## Current Status
- **Raspberry Pi IP**: 192.168.178.107 ✅ (reachable)
- **Local Server**: Running on port 8910 ✅
- **SSH**: Not enabled ❌ (needs to be enabled)
- **Touch Display**: Connected via HDMI (needs kiosk setup)

## Step 1: Enable SSH on Raspberry Pi

Since SSH is not currently enabled, you'll need to enable it directly on the Raspberry Pi:

### Option A: Using Raspberry Pi Desktop (if accessible)
1. Connect keyboard and mouse to the Raspberry Pi
2. Open Terminal
3. Run: `sudo systemctl enable ssh && sudo systemctl start ssh`
4. Verify: `sudo systemctl status ssh`

### Option B: Using SD Card (if desktop not accessible)
1. Remove SD card from Raspberry Pi
2. Insert into computer
3. Navigate to `/boot` partition
4. Create empty file named `ssh` (no extension)
5. Safely eject and reinsert SD card into Raspberry Pi
6. Reboot Raspberry Pi

### Option C: Using raspi-config (if accessible)
1. Connect keyboard and mouse to Raspberry Pi
2. Run: `sudo raspi-config`
3. Navigate to "Interfacing Options" → "SSH"
4. Select "Yes" to enable SSH
5. Reboot if prompted

## Step 2: Verify SSH Access

After enabling SSH, test the connection:

```bash
ssh pi@192.168.178.107
# Default password is usually "raspberry"
```

## Step 3: Install Required Packages

Once SSH is working, install the required packages for kiosk mode:

```bash
sudo apt update
sudo apt install -y chromium-browser wmctrl xdotool sshpass
```

## Step 4: Run Automated Setup

After SSH is enabled and packages are installed, run the automated setup:

```bash
# From your development machine:
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Setup Raspberry Pi client
rake scenario:setup_raspberry_pi_client[carambus_location_5101]

# Deploy kiosk configuration
rake scenario:deploy_raspberry_pi_client[carambus_location_5101]

# Test functionality
rake scenario:test_raspberry_pi_client[carambus_location_5101]
```

## Step 5: Verify Scoreboard Display

After setup, the touch display should:
1. Show the Carambus scoreboard for location 5101
2. Be in fullscreen kiosk mode
3. Automatically restart the browser if it crashes
4. Hide desktop panels for clean display

## Troubleshooting

### If SSH still doesn't work:
1. Check if SSH service is running: `sudo systemctl status ssh`
2. Check firewall settings: `sudo ufw status`
3. Verify SSH configuration: `sudo nano /etc/ssh/sshd_config`

### If browser doesn't start:
1. Check display: `echo $DISPLAY`
2. Test browser manually: `chromium-browser --version`
3. Check systemd service: `sudo systemctl status scoreboard-kiosk`

### If scoreboard URL is wrong:
1. Check generated URL: `cat /etc/scoreboard_url`
2. Verify location_id in config: Should be 5101
3. Test URL manually in browser

## Expected Scoreboard URL

For location_id 5101, the scoreboard URL should be:
```
http://192.168.178.107:82/locations/{md5_hash_of_5101}?sb_state=welcome
```

The MD5 hash of "5101" will be calculated automatically by the system.

## Next Steps After Setup

1. **Test browser restart**: `rake scenario:restart_raspberry_pi_client[carambus_location_5101]`
2. **Monitor service**: `ssh pi@192.168.178.107 "sudo systemctl status scoreboard-kiosk"`
3. **Check logs**: `ssh pi@192.168.178.107 "sudo journalctl -u scoreboard-kiosk -f"`

## Configuration Summary

- **Location ID**: 5101 (Phillip's Table)
- **Raspberry Pi IP**: 192.168.178.107
- **Local Server Port**: 8910 (SSH)
- **Web Server Port**: 82 (Scoreboard)
- **Touch Display**: HDMI-connected
- **Kiosk User**: pi
- **Autostart**: Enabled
