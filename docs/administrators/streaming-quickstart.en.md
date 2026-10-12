# YouTube Streaming - Quick Start

## 🚀 Live Stream in 5 Steps

### 1. Prepare Hardware (5 Min)

- [ ] **Logitech C922 Webcam** purchased and unpacked
- [ ] Camera connected via USB to Scoreboard Raspi 4
- [ ] Camera positioned above table (tripod/mount)
- [ ] Raspi 4 running and reachable via SSH

**Test:**
```bash
ping <IP of the Scoreboard Pi>
```

---

### 2. Prepare YouTube (10 Min)

- [ ] Open YouTube Studio: [studio.youtube.com](https://studio.youtube.com)
- [ ] Navigate: **Settings** → **Stream**
- [ ] **Create new stream key**
  - Name: "Table 1 - My Location"
  - Copy key (e.g. `xxxx-yyyy-zzzz-aaaa-bbbb`)
- [ ] ⚠️ **Important:** Wait 24h after first activation!

---

### 3. Setup Raspi (5 Min)

On the **Location Server**, in the scenario's deploy directory (the tasks need its database):

```bash
cd /var/www/<basename>/current

# SSH access to the Scoreboard Pi (Pis set up with Ansible: www-data, port 8910)
export RASPI_SSH_USER=www-data
export RASPI_SSH_PORT=8910

# Run setup
RAILS_ENV=production bundle exec rake "streaming:setup[<IP of the Scoreboard Pi>]"

# Verify everything is OK
RAILS_ENV=production bundle exec rake "streaming:test[<IP of the Scoreboard Pi>]"
```

**Expectation:** All tests ✅

**Before the first start, once** (details: [Setup, section Prepare Raspberry Pi](streaming-setup.md#1-prepare-raspberry-pi)):

- [ ] `www-data` on the Location Server has an SSH key, and its public part is in `~/.ssh/authorized_keys` on
      the Scoreboard Pi. The Start button connects as the Carambus service; an `export` in the shell does
      not reach it
- [ ] `/etc/<basename>.env` contains `STREAMING_SERVER_URL=http://<IP of the Location Server>:<webserver_port>`,
      followed by `sudo systemctl restart puma-<basename>`. Without this entry the Pi fetches the overlay text
      from `http://localhost:3131`. That is only correct if the Scoreboard Pi is itself the server on port 3131

---

### 4. Configure Stream (3 Min)

1. **Open Carambus Admin Interface**
2. Admin navigation → **Stream Configurations** (page "YouTube Live Streaming")
3. **New Stream Configuration**

**Minimal inputs:**
```
Table:              [Select your table, grouped by location]
YouTube Stream Key: [Paste from YouTube]
Raspi IP:           <IP of the Scoreboard Pi>  (taken from the table)
SSH user:           www-data                   (form default: pi)
SSH port:           8910                       (form default: 22)
```

**Rest:** The defaults (640x360, 30 fps, 1000 kbit/s) are the recommended start for a Pi 4

4. Click **Save**. The configuration is now in the database; it reaches the Pi at the start
5. Check SSH access:
   ```bash
   RAILS_ENV=production bundle exec rake "streaming:ssh_test[<TABLE_ID>]"
   ```
   `<TABLE_ID>` is the database ID of the table (`Table.id`), not the number from "Tisch 1"

---

### 5. Start Stream (1 Min)

1. In overview: Find Table 1
2. Click **▶ Start**
3. Watch status: "Starting" → "Active"
4. Open YouTube Studio → Stream should be live!

---

## ✅ Success Check

### Stream runs correctly when:

- [ ] Status in Admin Interface: 🟢 **Active**
- [ ] Uptime counting up
- [ ] YouTube Studio shows "Live"
- [ ] Video shows billiard table
- [ ] Scoreboard overlay visible (player names, score)
- [ ] No error messages

---

## 🆘 Problems?

### "Stream won't start"

```bash
# Check logs (script and FFmpeg write to files, not to the journal)
ssh -p 8910 www-data@<IP of the Scoreboard Pi>
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
tail -f /var/log/carambus/stream-table-<TABLE_ID>-error.log
```

If the admin interface reports "Authentication failed": the SSH key of `www-data` is missing on the Pi (step 3).
If there is no user `pi` on the Pi, the service does not start: the unit hard-codes `User=pi`
(see [Setup](streaming-setup.md#1-prepare-raspberry-pi)).

### "Camera not found"

```bash
# Show camera devices
ssh -p 8910 www-data@<IP of the Scoreboard Pi>
ls -l /dev/video*
```

If `/dev/video1` instead of `video0`:
→ In Admin Interface configuration → Change camera device

### "Overlay only shows 'Loading...'"

- `STREAMING_SERVER_URL` set (step 3)?
- If the nginx bot block is active, it rejects the Pi's `curl` request. See
  [Setup, Overlay Settings](streaming-setup.md#4-overlay-settings)

### "YouTube shows nothing"

- Stream key copied correctly?
- 24h waiting period after activation expired?
- Firewall/Router blocking port 1935?

---

## 📖 More Information

Complete documentation:
- [Streaming Setup & Operation](streaming-setup.md)

Command reference (on the Location Server):
```bash
RAILS_ENV=production bundle exec rake streaming:help
```

---

## 🎉 Done!

Your billiard table is now streaming live on YouTube!

**Next steps:**
- Add more tables (repeat steps 4-5)
- Optimize camera position
- Adjust bitrate (if needed)
- Enable automatic start

**Good luck!** 🎱📹




