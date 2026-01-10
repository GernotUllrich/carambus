# YouTube Live Streaming - Setup & Operation

## 📋 Overview

The Carambus system supports live streaming of billiard games directly to YouTube. It uses the existing Scoreboard Raspberry Pis to cost-effectively stream each table individually.

### Architecture

```
┌─────────────────────────────────────────────┐
│  Scoreboard Raspi 4 (per table)            │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Display :0                           │  │
│  │  ↳ Chromium Kiosk → Scoreboard      │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Virtual Display :1                   │  │
│  │  ↳ Chromium Headless → Overlay      │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ USB Camera (Logitech C922)           │  │
│  │  ↳ /dev/video0 → FFmpeg              │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ FFmpeg Compositing                   │  │
│  │  Camera + Overlay → YouTube RTMP     │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 🛠️ Hardware Requirements

### Per Streamed Table

1. **USB Webcam: Logitech C922** (~$80-90)
   - 1280x720 @ 60fps (recommended for smooth movements)
   - Alternative: Logitech C920 (~$60-70, 30fps)
   - USB 2.0/3.0 connection

2. **Raspberry Pi 4** (already available as scoreboard)
   - Minimum 2GB RAM (4GB recommended)
   - OS: Raspberry Pi OS (Bullseye or newer)

3. **Camera Mount**
   - Tripod or wall mount
   - USB extension cable (if needed)
   - Position: Above the table, looking at playing surface

### Network Requirements

- **Upload bandwidth**: ~2-3 Mbit/s per stream at 720p60
- Example: 4 parallel streams = ~10-12 Mbit/s upload needed
- Stable LAN connection recommended (WiFi possible but not ideal)

---

## 🎬 YouTube Preparation

### 1. Setup YouTube Channel

1. Sign in to YouTube
2. Open YouTube Studio → [studio.youtube.com](https://studio.youtube.com)
3. Create channel (if not already existing)

### 2. Enable Live Streaming

1. YouTube Studio → **Content** → **Live**
2. First activation: 24 hour waiting period
3. After activation: Create stream keys

### 3. Generate Stream Key

1. YouTube Studio → **Settings** → **Stream**
2. **Create new stream key**
3. Name: e.g. "Table 1 - BC Hamburg"
4. Copy stream key (format: `xxxx-yyyy-zzzz-aaaa-bbbb`)

**Important**: Create separate stream key per table!

### 4. Get Channel ID (optional)

1. YouTube Studio → **Customization** → **Basic info**
2. Copy Channel ID (format: `UCxxxxxxxxxxxxxxxxxxxxxxxxx`)
3. Needed for direct link to live stream

---

## ⚙️ Software Installation

### 1. Prepare Raspberry Pi

On the **Location Server** (Raspi 5):

```bash
# Set SSH password as environment variable
export RASPI_SSH_USER=pi
export RASPI_SSH_PASSWORD=raspberry  # Replace with actual password!

# Run setup on Scoreboard Raspi
cd /path/to/carambus_master
rake streaming:setup[192.168.1.100]  # IP of Scoreboard Raspi
```

The setup script automatically installs:
- FFmpeg (video encoding)
- Xvfb (virtual framebuffer for overlay)
- Chromium (overlay rendering)
- v4l-utils (camera tools)
- Systemd service files

### 2. Test Installation

```bash
rake streaming:test[192.168.1.100]
```

All tests should pass with ✅.

---

## 📝 Configuration in Admin Interface

### 1. Create Stream Configuration

1. Open Carambus Admin Interface
2. Navigate → **YouTube Live Streaming** (or `/admin/stream_configurations`)
3. Click **New Stream Configuration**

### 2. Basic Settings

**Table:**
- Select location and table

**YouTube Configuration:**
- **Stream Key**: Copy from YouTube
- **Channel ID**: (optional) For direct link

### 3. Camera Settings

**Recommended values for Logitech C922:**
```
Device:      /dev/video0
Width:       1280
Height:      720
Framerate:   60 fps
```

**For Logitech C920:**
```
Framerate:   30 fps  (rest same)
```

### 4. Overlay Settings

```
Overlay enabled:  ✓
Position:         Bottom
Height:           200 px
```

The overlay shows:
- Player names
- Current score
- Tournament info (if available)
- Live indicator

### 5. Stream Quality

**Recommended values:**
```
Video bitrate:  2000 kbit/s  (720p60)
Audio bitrate:  128 kbit/s
```

**Adjustments based on upload:**
- More bandwidth: 2500 kbit/s
- Less bandwidth: 1500 kbit/s

### 6. Network

```
Raspi IP:       192.168.1.100  (automatically taken from table)
SSH port:       22
```

### 7. Save & Deploy

1. Click **Save**
2. Configuration is deployed to Scoreboard Raspi
3. Check status: Should be "Inactive"

---

## ▶️ Start Stream

### Via Admin Interface (recommended)

1. Open `/admin/stream_configurations`
2. Find desired stream
3. Click **Start**
4. Status changes to "Starting" → "Active"
5. On error: Error message is displayed

### Via SSH (manual)

```bash
ssh pi@192.168.1.100
sudo systemctl start carambus-stream@1.service

# Check status
sudo systemctl status carambus-stream@1.service

# View logs
sudo journalctl -u carambus-stream@1.service -f
```

### Via Rake Task

```bash
cd /path/to/carambus_master
rake streaming:status  # Show all streams
```

---

## 🔍 Monitoring & Troubleshooting

### Check Stream Status

**In Admin Interface:**
- Live status display
- Uptime counter
- Error messages
- Click **Health Check** for current diagnosis

**Via Rake Task:**
```bash
rake streaming:status
```

**Via SSH:**
```bash
ssh pi@192.168.1.100

# Service status
sudo systemctl status carambus-stream@1.service

# Live logs
sudo journalctl -u carambus-stream@1.service -f

# Check FFmpeg process
ps aux | grep ffmpeg

# Check camera
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

### Common Issues

#### Problem: "Camera device not found"

**Solution:**
```bash
# Show camera devices
ls -l /dev/video*

# If multiple cameras: Select correct one
v4l2-ctl --list-devices

# Adjust in configuration: /dev/video0, /dev/video1, etc.
```

#### Problem: "Cannot reach YouTube RTMP server"

**Causes:**
- No internet connection
- Firewall blocks port 1935 (RTMP)
- Router configuration

**Test:**
```bash
ping a.rtmp.youtube.com
telnet a.rtmp.youtube.com 1935
```

#### Problem: Stream starts but YouTube shows nothing

**Checklist:**
1. Stream key correct?
2. YouTube stream already "live"?
3. 24h waiting period after activation expired?
4. Check FFmpeg logs:
   ```bash
   tail -f /var/log/carambus/stream-table-1.log
   ```

#### Problem: "Stream runs but stutters"

**Causes:**
- Upload bandwidth too low
- Bitrate set too high
- CPU overload on Raspi

**Solutions:**
1. Reduce bitrate (e.g. to 1500k)
2. Reduce framerate (60 → 30 fps)
3. Stop other processes on Raspi
4. Check network quality

#### Problem: "Overlay not displayed"

**Checklist:**
1. Overlay enabled in configuration?
2. Chromium installed?
   ```bash
   which chromium-browser
   ```
3. Scoreboard URL reachable?
   ```bash
   curl http://localhost/locations/xxx/scoreboard_overlay?table=1
   ```
4. Xvfb running?
   ```bash
   ps aux | grep Xvfb
   ```

---

## 🔄 Automatic Restart

The systemd service automatically restarts on:
- FFmpeg crash
- Network problems
- Raspberry Pi reboot (optional)

**Enable automatic start after reboot:**
```bash
ssh pi@192.168.1.100
sudo systemctl enable carambus-stream@1.service
```

**Disable automatic restart:**
```bash
sudo systemctl disable carambus-stream@1.service
```

**Restart limit:**
- Maximum 5 restarts within 5 minutes
- After that: Service gives up → Health check shows error

---

## 📊 Optimization

### Reduce CPU Load

**Use hardware encoding:**
- Raspi 4 has hardware H.264 encoder
- Automatically used (`h264_v4l2m2m`)
- Much more efficient than software encoding

**Set CPU limit:**
```bash
# In systemd service (already configured)
CPUQuota=80%
```

### Improve Image Quality

**Camera positioning:**
- Height: ~2-3m above table
- Angle: Slightly diagonal from above
- Lighting: Even, no direct reflections

**Optimize FFmpeg parameters:**
```bash
# In /etc/carambus/stream-table-1.conf
VIDEO_BITRATE=2500  # Higher quality
CAMERA_FPS=60       # Smoother movements
```

### Save Bandwidth

**Lower resolution:**
- Not recommended for main stream
- OK for test streams or very weak upload

**Adaptive bitrate:**
- YouTube adapts automatically
- Client-side, not server-side

---

## 🔐 Security

### SSH Passwords

**Recommendation:** Use SSH keys instead of passwords

```bash
# On Location Server
ssh-keygen -t ed25519 -C "carambus-streaming"

# Copy public key to Raspi
ssh-copy-id pi@192.168.1.100

# Disable password login (optional)
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
sudo systemctl restart sshd
```

### Protect Stream Keys

- **Never** commit to git
- Use environment variables (already implemented)
- Encrypted in Rails Credentials (already implemented)
- On leak: Immediately invalidate in YouTube Studio

---

## 📈 Scaling

### Multiple Tables in Parallel

**Network planning:**
```
1 stream:  ~2.5 Mbit/s
2 streams: ~5 Mbit/s
4 streams: ~10 Mbit/s
8 streams: ~20 Mbit/s
```

**Per table:**
- Own Scoreboard Raspi
- Own USB camera
- Own YouTube stream key
- Independent control

### Load Balancing

- Each Raspi only streams its own table
- No central load on Location Server
- Horizontally scalable

---

## 🆘 Support

### Collect Logs

```bash
# On Scoreboard Raspi
ssh pi@192.168.1.100

# Service logs
sudo journalctl -u carambus-stream@1.service --no-pager > stream.log

# System info
uname -a >> stream.log
free -h >> stream.log
df -h >> stream.log

# Camera info
v4l2-ctl --device=/dev/video0 --all >> stream.log

# Network test
ping -c 10 a.rtmp.youtube.com >> stream.log
```

### Helpful for Support

- Log files (see above)
- Screenshot from Admin Interface
- YouTube Channel URL
- Network topology

---

## 📚 Further Documentation

### Internal Links

- [Quick Start Guide](streaming-quickstart.en.md)
- [Developer Architecture](../developers/streaming-architecture.en.md)
- [Server Architecture](server-architecture.en.md)
- [Scoreboard Setup](scoreboard-autostart.en.md)

### External Resources

**FFmpeg:**
- [FFmpeg H.264 Encoding](https://trac.ffmpeg.org/wiki/Encode/H.264)
- [FFmpeg Streaming Guide](https://trac.ffmpeg.org/wiki/StreamingGuide)
- [V4L2 Input](https://trac.ffmpeg.org/wiki/Capture/Webcam)

**Raspberry Pi:**
- [VideoCore Hardware Encoding](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [Raspberry Pi 4 Specs](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/)

**YouTube:**
- [YouTube Live Streaming API](https://developers.google.com/youtube/v3/live/getting-started)
- [RTMP Ingestion](https://support.google.com/youtube/answer/2907883)
- [Encoder Settings](https://support.google.com/youtube/answer/2853702)

---

## ✅ Quick Reference

### Most Important Commands

```bash
# Setup
rake streaming:setup[192.168.1.100]
rake streaming:test[192.168.1.100]

# Deployment
rake streaming:deploy[TABLE_ID]
rake streaming:deploy_all

# Monitoring
rake streaming:status

# Manual (on Raspi)
sudo systemctl start carambus-stream@1.service
sudo systemctl stop carambus-stream@1.service
sudo systemctl status carambus-stream@1.service
sudo journalctl -u carambus-stream@1.service -f
```

### Admin URLs

```
Stream Management:  /admin/stream_configurations
Overlay Preview:    /locations/:md5/scoreboard_overlay?table=1
```

### Files on Raspi

```
Script:         /usr/local/bin/carambus-stream.sh
Service:        /etc/systemd/system/carambus-stream@.service
Config:         /etc/carambus/stream-table-1.conf
Logs:           /var/log/carambus/stream-table-1.log
Overlay Image:  /tmp/carambus-overlay-table-1.png
```

---

**Version**: 1.0  
**Date**: December 2024  
**Author**: Carambus Development Team




