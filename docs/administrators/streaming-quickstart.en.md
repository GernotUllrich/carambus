# YouTube Streaming - Quick Start

## 🚀 Live Stream in 5 Steps

### 1. Prepare Hardware (5 Min)

- [ ] **Logitech C922 Webcam** purchased and unpacked
- [ ] Camera connected via USB to Scoreboard Raspi 4
- [ ] Camera positioned above table (tripod/mount)
- [ ] Raspi 4 running and reachable via SSH

**Test:**
```bash
ping 192.168.1.100  # Replace with your Raspi IP
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

On the **Location Server** (Raspi 5):

```bash
cd /path/to/carambus_master

# Set SSH password
export RASPI_SSH_PASSWORD=raspberry  # Your actual password!

# Run setup
rake streaming:setup[192.168.1.100]  # Your Raspi IP

# Verify everything is OK
rake streaming:test[192.168.1.100]
```

**Expectation:** All tests ✅

---

### 4. Configure Stream (3 Min)

1. **Open Carambus Admin Interface**
2. Navigate → **YouTube Live Streaming**
3. **New Stream Configuration**

**Minimal inputs:**
```
Table:              [Select your table]
YouTube Stream Key: [Paste from YouTube]
Raspi IP:           192.168.1.100
```

**Rest:** Default values OK for C922

4. Click **Save**

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
# Check logs
ssh pi@192.168.1.100
sudo journalctl -u carambus-stream@1.service -f
```

### "Camera not found"

```bash
# Show camera devices
ssh pi@192.168.1.100
ls -l /dev/video*
```

If `/dev/video1` instead of `video0`:
→ In Admin Interface configuration → Change camera device

### "YouTube shows nothing"

- Stream key copied correctly?
- 24h waiting period after activation expired?
- Firewall/Router blocking port 1935?

---

## 📖 More Information

Complete documentation:
- [docs/administrators/streaming-setup.en.md](streaming-setup.md)

Command reference:
```bash
rake streaming:help
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




