# YouTube Live Streaming - Setup & Operation

## 📋 Overview

The Carambus system supports live streaming of billiard games. It uses the existing Scoreboard Raspberry Pis to cost-effectively stream each table individually. Three stream destinations (`stream_destination`) are available: **`youtube`** (directly to YouTube), **`local`** (local RTMP server, e.g. for OBS integration) and **`custom`** (custom RTMP endpoint). This guide mostly describes the YouTube path.

### Architecture

```
┌───────────────────────────────────────────────────────┐
│  Location Server (Carambus, port <webserver_port>)    │
│   /locations/<md5>/scoreboard_text?table_id=<ID>      │
└───────────────────────────▲───────────────────────────┘
                            │ curl, every second
┌───────────────────────────┴───────────────────────────┐
│  Scoreboard Raspi 4 (per table)                       │
│                                                       │
│  Display :0 → Chromium kiosk → Scoreboard             │
│  (service scoreboard-kiosk, independent of the stream)│
│                                                       │
│  carambus-stream@<TABLE_ID>.service                   │
│   USB camera /dev/video0 ──┐                          │
│   Overlay text (file) ─────┴→ FFmpeg: drawtext        │
│                               + libx264 → RTMP target │
└───────────────────────────────────────────────────────┘
```

The overlay is **text** that FFmpeg writes into the bottom left of the camera image via `drawtext`.
`carambus-stream.sh` fetches the text from the Location Server every second (`bin/carambus-stream.sh`,
overlay branch). No browser renders anything: `streaming:setup` does install Xvfb and Chromium, but the
streaming path uses neither. The Chromium kiosk on display :0 is the normal scoreboard.

---

## 🛠️ Hardware Requirements

### Per Streamed Table

1. **USB Webcam: Logitech C922** (~$80-90)
   - Default configuration: 640x360 @ 30 fps (see [Camera Settings](#3-camera-settings))
   - Alternative: Logitech C920 (~$60-70)
   - USB 2.0/3.0 connection

2. **Raspberry Pi 4** (already available as scoreboard)
   - Minimum 2GB RAM (4GB recommended)
   - OS: Raspberry Pi OS (Bullseye or newer)

3. **Camera Mount**
   - Tripod or wall mount
   - USB extension cable (if needed)
   - Position: Above the table, looking at playing surface

### Network Requirements

- **Upload bandwidth**: roughly video plus audio bitrate per stream, with peaks up to video bitrate + 500 kbit/s
  (FFmpeg `-maxrate`). With the defaults (1000 + 128 kbit/s) that is about 1.1–1.6 Mbit/s per stream
- Example: 4 parallel streams with defaults = ~5-7 Mbit/s upload needed
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

All commands in this section run on the **Location Server**, in the scenario's deploy directory. The
streaming tasks need its database (`StreamConfiguration` only exists on local servers); a developer
checkout is not enough.

### 1. Prepare Raspberry Pi

**SSH access.** Start, stop and health check in the admin interface run as a job inside the Carambus
service (`puma-<basename>`, user `www-data`). The job connects to the Scoreboard Pi via SSH and uses:

1. `RASPI_SSH_PASSWORD`, if set in the **service environment**,
2. otherwise the keys from `RASPI_SSH_KEYS` (comma-separated paths),
3. otherwise `~/.ssh/id_rsa`, `id_ed25519`, `id_ecdsa` or `id_dsa` of the service user.

An `export` in the shell does not reach the service; it only reads `/etc/<basename>.env`
(`EnvironmentFile=` in `templates/puma/puma.service.erb`). The usual way is therefore a key for `www-data`
on the Location Server whose public part is stored on the Scoreboard Pi:

```bash
# On the Location Server, as www-data
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "carambus-streaming"
cat ~/.ssh/id_ed25519.pub
# Add this line to ~/.ssh/authorized_keys of the SSH user on the Scoreboard Pi
```

If the Scoreboard Pi is the server itself, the same applies: the job then connects to itself via SSH.

**SSH user and port** come from the scenario config (`raspberry_pi_client`). Pis set up with Ansible accept
SSH only as `www-data` on port 8910 (see [Raspberry Pi Quickstart](raspberry-pi-quickstart.md)). Without
settings, the streaming tasks assume `pi` and port 22, hence:

```bash
cd /var/www/<basename>/current
export RASPI_SSH_USER=www-data
export RASPI_SSH_PORT=8910

# Run setup on the Scoreboard Raspi
RAILS_ENV=production bundle exec rake "streaming:setup[<IP of the Scoreboard Pi>]"
```

The setup installs:
- FFmpeg (video encoding), v4l-utils (camera tools), curl
- Xvfb, Chromium, ImageMagick, netcat (installed, currently not used by the streaming path)
- `/usr/local/bin/carambus-stream.sh` and the systemd template `carambus-stream@.service`
- `/usr/local/bin/carambus-overlay-updater.sh` and the template `carambus-overlay-updater@.service`
- the directories `/etc/carambus` and `/var/log/carambus`

!!! warning "The unit runs as user `pi`"
    `bin/carambus-stream.service` hard-codes `User=pi` and `Group=pi`. If there is no user `pi` on the
    Scoreboard Pi, systemd refuses to start the service. This affects Pis whose Imager user has a different
    name.

### 2. Test Installation

```bash
RAILS_ENV=production bundle exec rake "streaming:test[<IP of the Scoreboard Pi>]"
```

All tests should pass with ✅.

---

## 📝 Configuration in Admin Interface

### 1. Create Stream Configuration

1. Open Carambus Admin Interface
2. Admin navigation → **Stream Configurations** (page "YouTube Live Streaming", `/admin/stream_configurations`)
3. Click **New Stream Configuration**

### 2. Basic Settings

**Table:**
- Select the table (the list is grouped by location; the location is taken from the table)

**Stream Destination (`stream_destination`):**
- **`youtube`**: Stream directly to YouTube (default)
- **`local`**: Local RTMP server (e.g. Mac mini/laptop with Docker, for OBS integration)
- **`custom`**: Custom RTMP endpoint

**YouTube Configuration (when `stream_destination = youtube`):**
- **Stream Key**: Copy from YouTube
- **Channel ID**: (optional) For direct link

**Local RTMP Server (when `stream_destination = local`):**
- **RTMP Server IP**: IP of the machine running the RTMP server (e.g. `192.168.2.150`)
- Stream URL is generated automatically: `rtmp://<IP>:1935/stream/table<TABLE_ID>`

**Custom RTMP Endpoint (when `stream_destination = custom`):**
- **Custom RTMP URL**: Full base URL of the RTMP server
- **Custom RTMP Key**: (optional) Appended to the URL

### 3. Camera Settings

**Defaults of a new configuration** (lowered to Pi 4 capacity since migration `20251231132304`):
```
Device:      /dev/video0
Width:       640
Height:      360
Framerate:   30 fps
```

This is the recommended start. 1280x720 @ 30 fps only if CPU and upload have headroom; 60 fps is not
recommended. Encoding is done in software (see [Optimization](#reduce-cpu-load)).

!!! note "Manual camera and perspective values"
    The fields "Manual camera settings" (focus, exposure, brightness, contrast, saturation) and
    "Perspective correction" are currently **not saved**: they are missing from the controller's parameter
    list. They can be set via `rake "streaming:camera_save[<TABLE_ID>]"` (reads the values from the Pi) or
    `rake "streaming:perspective_set[<TABLE_ID>,<coords>]"`.

### 4. Overlay Settings

```
Overlay enabled:  ✓
```

The **Position** and **Height** fields currently have no effect: the text always sits in the bottom left,
the font size follows the camera height (16 px at 360p, 24 px from 720p, 32 px from 1080p).

The overlay shows:
- Table number and "LIVE"
- both players (first name) with score, current inning in parentheses, the player at the table marked
- Tournament name (if available)
- without a running game: name of the location and "Kein Spiel"

!!! warning "Required step: `STREAMING_SERVER_URL`"
    The Pi fetches the text from the address in `SERVER_URL` of its configuration file. The job writes it as
    `STREAMING_SERVER_URL` from the environment of the Carambus service, otherwise `http://localhost:3131`
    (`app/jobs/stream_control_job.rb`). The default is only correct if the Scoreboard Pi is the server itself
    and it listens on port 3131. In every other case the Pi fetches the text from itself, and the overlay
    stays at "Loading...".

    ```bash
    # On the Location Server
    sudo nano /etc/<basename>.env
    #   STREAMING_SERVER_URL=http://<IP of the Location Server>:<webserver_port>
    sudo systemctl restart puma-<basename>
    ```

    The address takes effect at the next stream start, because the start rewrites the configuration.

!!! warning "nginx bot block"
    If the nginx bot block is active for the scenario (`bot_block_enabled`, default `true`), nginx rejects the
    Pi's request with 403: `curl` identifies itself as `curl/…`, and only `/versions/` is exempt
    (`templates/nginx/carambus_bot_block.conf`). The overlay then also stays at "Loading...".
    See [NGINX Bot Block](nginx-bot-block.md).

### 5. Stream Quality

**Defaults:**
```
Video bitrate:  1000 kbit/s  (640x360 @ 30 fps)
Audio bitrate:  128 kbit/s
```

**Adjustments based on upload:**
- 1280x720 @ 30 fps: about 2000 kbit/s
- Less bandwidth: lower the bitrate, e.g. 800 kbit/s

### 6. Network

```
Raspi IP:   <IP of the Scoreboard Pi>  (automatically taken from table)
SSH user:   www-data                   (form default: pi)
SSH port:   8910                       (form default: 22)
```

User and port must match the Pi; for Pis set up with Ansible that is `www-data` and 8910. Access can be
tested as soon as the configuration is saved:

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake "streaming:ssh_test[<TABLE_ID>]"
```

The task shows the server's public key and tells whether it is stored on the Pi. If the test fails, the
Start button fails too (error message "Authentication failed").

### 7. Save & Deploy

1. Click **Save**: the configuration now only exists in the database
2. It reaches the Pi at the first **Start**, via **Alle deployen** (deploy all), or with
   `rake "streaming:deploy[<TABLE_ID>]"`. Before a manual `systemctl start` it must be deployed
3. Check status: Should be "Inactive"

---

## ▶️ Start Stream

### Via Admin Interface (recommended)

1. Open `/admin/stream_configurations`
2. Find desired stream
3. Click **Start**: the job rewrites the configuration on the Pi and starts the service
4. Status changes to "Starting" → "Active"
5. On error: Error message is displayed

**Restart** (🔄) and **saving while the stream is running** currently only stop the stream; they do not start
it again (`StreamConfiguration#restart_streaming`). Click **Start** afterwards.

### Via SSH (manual)

`<TABLE_ID>` is the database ID of the table (`Table.id`), not the number from "Tisch 7". The configuration
must be deployed first (see above).

```bash
ssh -p 8910 www-data@<IP of the Scoreboard Pi>
sudo systemctl start carambus-stream@<TABLE_ID>.service

# Check status
sudo systemctl status carambus-stream@<TABLE_ID>.service

# View logs (FFmpeg and the script write to files, not to the journal)
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
```

### Via Rake Task

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake streaming:status  # Show all streams
```

When deploying via `rake streaming:deploy`, load the service environment into the shell first; otherwise
the task computes the server address itself (on a local server `http://localhost:<port>`) and does not use
`RASPI_SSH_PASSWORD`:

```bash
set -a; eval "$(sudo cat /etc/<basename>.env)"; set +a
```

---

## 🔍 Monitoring & Troubleshooting

### Check Stream Status

**In Admin Interface:**
- Live status display
- Uptime counter
- Error messages
- Click **Health Check** (❤️) for current diagnosis; while the page is open it also runs every 30 seconds

**Via Rake Task:**
```bash
RAILS_ENV=production bundle exec rake streaming:status
```

**Via SSH:**
```bash
ssh -p 8910 www-data@<IP of the Scoreboard Pi>

# Service status (start, stop, restarts)
sudo systemctl status carambus-stream@<TABLE_ID>.service

# Live logs of script and FFmpeg
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
tail -f /var/log/carambus/stream-table-<TABLE_ID>-error.log

# Check FFmpeg process
ps aux | grep ffmpeg

# Check camera
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

`journalctl -u carambus-stream@<TABLE_ID>` only shows when systemd started or stopped the service.

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
   tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
   ```

#### Problem: "Stream runs but stutters"

**Causes:**
- Upload bandwidth too low
- Bitrate set too high
- CPU overload on Raspi

**Solutions:**
1. Reduce bitrate (e.g. to 800k)
2. Reduce resolution or framerate (back to 640x360 @ 30 fps)
3. Stop other processes on Raspi
4. Check network quality

#### Problem: "Overlay not displayed"

**Checklist:**
1. Overlay enabled in configuration?
2. Does `SERVER_URL` point to the Location Server?
   ```bash
   grep SERVER_URL /etc/carambus/stream-table-<TABLE_ID>.conf
   ```
   If it says `http://localhost:3131` although the server is a different machine: set
   `STREAMING_SERVER_URL` (see [Overlay Settings](#4-overlay-settings)) and restart the stream.
3. Does the endpoint return text, the way the Pi requests it?
   ```bash
   curl -i "<SERVER_URL>/locations/<LOCATION_MD5>/scoreboard_text?table_id=<TABLE_ID>"
   ```
   `403 Forbidden` means: the nginx bot block rejects `curl`.
4. The text file itself lives in the service's private `/tmp` (`PrivateTmp=true`) and is not visible under
   `/tmp` from an SSH shell.

---

## 🔄 Automatic Restart

The systemd service automatically restarts on:
- FFmpeg crash
- Network problems
- Raspberry Pi reboot (optional)

**Enable automatic start after reboot:**
```bash
ssh -p 8910 www-data@<IP of the Scoreboard Pi>
sudo systemctl enable carambus-stream@<TABLE_ID>.service
```

**Disable automatic restart:**
```bash
sudo systemctl disable carambus-stream@<TABLE_ID>.service
```

**Restart limit:**
- Maximum 5 restarts within 5 minutes
- After that: Service gives up → Health check shows error

---

## 📊 Optimization

### Reduce CPU Load

**Software encoding:**
- Encoding uses `libx264` (preset `veryfast`), not the Pi 4 hardware encoder
- Reason: with `h264_v4l2m2m` YouTube only showed the logo, never the picture (comment in `bin/carambus-stream.sh`)
- CPU load is therefore controlled via resolution, framerate and bitrate

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

**Adjust quality:**
- Change bitrate, resolution and framerate in the admin interface
- Do not edit `/etc/carambus/stream-table-<TABLE_ID>.conf` by hand: every start rewrites the file

### Save Bandwidth

**Lower bitrate:**
- The default resolution 640x360 is already low
- With very weak upload, lower the video bitrate

**Adaptive bitrate:**
- YouTube adapts automatically
- Client-side, not server-side

---

## 🔐 Security

### SSH Access

- Keys instead of passwords: see [Prepare Raspberry Pi](#1-prepare-raspberry-pi)
- If the service should connect with a password after all, `RASPI_SSH_PASSWORD` belongs in
  `/etc/<basename>.env` (mode 600, owner root), not in a shell file
- Pis set up with Ansible accept SSH only on port 8910

### Protect Stream Keys

- **Never** commit to git
- Encrypted in the database (Active Record Encryption, `encrypts :youtube_stream_key`)
- On the Scoreboard Pi the key is stored in plain text in `/etc/carambus/stream-table-<TABLE_ID>.conf` (part of
  `RTMP_URL`; the file has mode 644 and is readable by every user on the Pi). Secure the Pi accordingly
- On leak: Immediately invalidate in YouTube Studio

---

## 📈 Scaling

### Multiple Tables in Parallel

**Network planning (defaults 1000 + 128 kbit/s):**
```
1 stream:  ~1.5 Mbit/s
2 streams: ~3 Mbit/s
4 streams: ~6 Mbit/s
8 streams: ~12 Mbit/s
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
ssh -p 8910 www-data@<IP of the Scoreboard Pi>

# Stream logs
cat /var/log/carambus/stream-table-<TABLE_ID>.log > stream.log
cat /var/log/carambus/stream-table-<TABLE_ID>-error.log >> stream.log
sudo systemctl status carambus-stream@<TABLE_ID>.service --no-pager >> stream.log

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

- [Quick Start Guide](streaming-quickstart.md)
- [Developer Architecture](../developers/streaming-architecture.md)
- [Server Architecture](server-architecture.md)
- [Scoreboard Kiosk](scoreboard-autostart.md)

### External Resources

**FFmpeg:**
- [FFmpeg H.264 Encoding](https://trac.ffmpeg.org/wiki/Encode/H.264)
- [FFmpeg Streaming Guide](https://trac.ffmpeg.org/wiki/StreamingGuide)
- [V4L2 Input](https://trac.ffmpeg.org/wiki/Capture/Webcam)

**Raspberry Pi:**
- [Raspberry Pi 4 Specs](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/)

**YouTube:**
- [YouTube Live Streaming API](https://developers.google.com/youtube/v3/live/getting-started)
- [RTMP Ingestion](https://support.google.com/youtube/answer/2907883)
- [Encoder Settings](https://support.google.com/youtube/answer/2853702)

---

## ✅ Quick Reference

### Most Important Commands

```bash
# On the Location Server: cd /var/www/<basename>/current, RAILS_ENV=production bundle exec …
# Setup
rake "streaming:setup[<IP>]"
rake "streaming:test[<IP>]"
rake "streaming:ssh_test[<TABLE_ID>]"

# Deployment
rake "streaming:deploy[<TABLE_ID>]"
rake streaming:deploy_all

# Monitoring
rake streaming:status

# Manual (on Raspi)
sudo systemctl start carambus-stream@<TABLE_ID>.service
sudo systemctl stop carambus-stream@<TABLE_ID>.service
sudo systemctl status carambus-stream@<TABLE_ID>.service
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
```

### Admin URLs

```
Stream Management:   /admin/stream_configurations
Overlay text (Pi):   /locations/:md5/scoreboard_text?table_id=<TABLE_ID>
Overlay (browser):   /locations/:md5/scoreboard_overlay?table_id=<TABLE_ID>   (for OBS)
```

### Files on Raspi

```
Script:         /usr/local/bin/carambus-stream.sh
Service:        /etc/systemd/system/carambus-stream@.service
Config:         /etc/carambus/stream-table-<TABLE_ID>.conf
Logs:           /var/log/carambus/stream-table-<TABLE_ID>.log
                /var/log/carambus/stream-table-<TABLE_ID>-error.log
Overlay text:   /tmp/carambus-overlay-text-table-<TABLE_ID>.txt  (in the service's private /tmp)
```

---

**Version**: 1.1  
**Date**: September 2026 (checked against the code, Phase 16)  
**Author**: Carambus Development Team
