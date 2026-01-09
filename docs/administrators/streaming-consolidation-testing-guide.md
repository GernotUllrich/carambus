# Stream Destination Testing Guide

## 🎯 Quick Test Scenarios

This guide walks you through testing all three streaming destinations.

---

## Prerequisites

### On Mac mini:
- Docker Desktop running
- RTMP server container running (from earlier setup)
- Rails server running: `rails s -p 3000`
- OBS Studio installed

### On Raspberry Pi:
- Streaming software installed (via `rake streaming:setup_raspi`)
- USB camera connected
- Network connectivity to Mac mini

---

## Test 1: Local RTMP to OBS (Recommended First Test)

This is the easiest to test since everything stays local.

### Step 1: Start RTMP Server on Mac mini

```bash
# Check if already running
docker ps | grep rtmp

# If not running, start it
docker run -d --name rtmp-server -p 1935:1935 -p 8080:8080 alfg/nginx-rtmp

# Find your Mac's IP
ifconfig | grep "inet " | grep -v 127.0.0.1
# Example output: inet 192.168.1.105
```

### Step 2: Create Stream Configuration

1. Open browser: `http://localhost:3000/admin/stream_configurations/new`

2. Fill in form:
   ```
   Tisch: [Select your test table]
   
   Stream-Ziel: Lokaler RTMP Server (Mac/OBS)
   RTMP Server IP-Adresse: 192.168.1.105  (your Mac IP)
   
   Kamera-Einstellungen:
   - Gerät: /dev/video0
   - Framerate: 30 FPS
   - Breite: 1280
   - Höhe: 720
   
   Overlay: ✓ Overlay aktiviert
   
   Netzwerk:
   - Raspberry Pi IP: [your Raspi IP, e.g., 192.168.1.100]
   - SSH-User: pi (or www-data for development)
   - SSH-Port: 22 (or 8910 for development)
   
   Stream-Qualität:
   - Video-Bitrate: 2000 kbit/s
   - Audio-Bitrate: 128 kbit/s
   ```

3. Click **Speichern**

### Step 3: Start the Stream

1. Go to: `http://localhost:3000/admin/stream_configurations`

2. Find your configuration card

3. Click **"▶ Start"**

4. Wait 5-10 seconds

5. Status should change: `⚪ Inactive` → `🟡 Starting` → `🟢 Active`

### Step 4: View Stream in OBS

**On Mac mini:**

1. Open OBS Studio

2. Add Source:
   - Click **"+"** in Sources
   - Select **"Media Source"**
   - Name: "Table 1 Stream"

3. Configure:
   - ❌ Uncheck "Local File"
   - Input: `rtmp://localhost:1935/live/table2` (use your table ID!)
   - ✓ Check "Restart playback when source becomes active"
   - ✓ Check "Close file when inactive"
   - Click **OK**

4. **Result:** You should see the camera feed in OBS preview! 🎉

### Step 5: Test Overlay Updates

1. On Raspberry Pi scoreboard, start a game

2. Change scores

3. After ~3 seconds, overlay in stream should update

4. **Expected:** Live score updates visible in OBS

### Troubleshooting Test 1

**Stream won't start:**
```bash
# On Mac, check Rails logs
tail -f log/development.log | grep Stream

# On Raspi, check service status
ssh pi@192.168.1.100 'systemctl status carambus-stream@1.service'

# Check for errors
ssh pi@192.168.1.100 'journalctl -u carambus-stream@1.service -n 50'
```

**No video in OBS:**
```bash
# Check if RTMP server received connection
docker logs rtmp-server

# Should see something like:
# 2025/01/09 21:00:00 [info] client connected '192.168.1.100'

# Test RTMP URL manually
ffplay rtmp://localhost:1935/live/table2
```

**Overlay not updating:**
```bash
# Check overlay URL is accessible
open http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=2

# Check Rails server is serving requests
tail -f log/development.log | grep scoreboard_overlay
```

---

## Test 2: YouTube Direct Stream

This tests the traditional YouTube streaming path.

### Step 1: Get YouTube Stream Key

1. Go to: https://studio.youtube.com

2. Click **"Create"** → **"Go live"**

3. Select **"Stream"** (not Webcam)

4. Copy **Stream key** (looks like: `xxxx-yyyy-zzzz-aaaa-bbbb`)

5. Set visibility to **"Unlisted"** (for testing)

### Step 2: Create/Edit Stream Configuration

1. Go to: `/admin/stream_configurations`

2. **Either:**
   - Edit existing config
   - Or create new one

3. Change settings:
   ```
   Stream-Ziel: YouTube Live
   Stream-Key: [paste your YouTube key]
   Channel-ID: (optional)
   
   [Rest same as Test 1]
   ```

4. Click **Speichern**

### Step 3: Start YouTube Stream

1. Click **"▶ Start"**

2. Wait ~30 seconds (YouTube ingestion takes time)

3. Go to YouTube Studio → Stream should show **"Live"**

### Step 4: Verify Stream Quality

1. In YouTube Studio:
   - Check **"Stream health"** → should be green
   - Check **"Latency"** → typically 10-30 seconds
   - Check **"Resolution"** → should match your config (720p30)

2. Open stream URL in browser (private window)

3. **Expected:** See camera feed with scoreboard overlay

### Troubleshooting Test 2

**YouTube rejects stream:**
```bash
# Check stream key is correct
ssh pi@192.168.1.100 'cat /etc/carambus/stream-table-1.conf | grep RTMP_URL'

# Common reasons:
# - Wrong stream key
# - Stream key already in use
# - Copyright strike on channel
# - Bitrate too low/high for YouTube
```

**Stream starts but no video in YouTube:**
```bash
# Check FFmpeg is encoding properly
ssh pi@192.168.1.100 'journalctl -u carambus-stream@1.service -n 100 | grep -i error'

# Verify camera works
ssh pi@192.168.1.100 'ffmpeg -f v4l2 -i /dev/video0 -frames:v 1 test.jpg'
```

---

## Test 3: Custom RTMP Server

This tests streaming to any RTMP server (e.g., your own streaming infrastructure).

### Step 1: Setup Test RTMP Server

**Option A: Use Docker on another machine**
```bash
# On a different machine/server
docker run -d -p 1935:1935 -p 8080:8080 alfg/nginx-rtmp
```

**Option B: Use free RTMP test server**
```
URL: rtmp://live.twitch.tv/app/
Key: [your Twitch stream key]
```

### Step 2: Configure Custom Stream

1. Go to: `/admin/stream_configurations/new`

2. Settings:
   ```
   Stream-Ziel: Eigener RTMP Server
   RTMP Server URL: rtmp://your-server-ip:1935/live
   Stream-Key: test-stream-123 (optional)
   
   [Rest same as before]
   ```

3. **Preview URL shown:** `rtmp://your-server-ip:1935/live/test-stream-123`

### Step 3: Start & Verify

1. Click **"▶ Start"**

2. Check server received connection:
   ```bash
   # On your RTMP server
   docker logs rtmp-server | grep connected
   ```

3. View stream (on server):
   ```bash
   # Using VLC or ffplay
   ffplay rtmp://localhost:1935/live/test-stream-123
   ```

---

## Test 4: Multiple Simultaneous Streams

Test streaming from multiple Raspberry Pis to OBS simultaneously.

### Setup: 2 Raspberry Pis → OBS (Multi-Camera)

**Configuration:**

| Raspi | Table | RTMP URL | OBS Source Name |
|-------|-------|----------|-----------------|
| 192.168.1.100 | Table 1 (ID: 2) | rtmp://192.168.1.105:1935/live/table2 | Camera Table 1 |
| 192.168.1.101 | Table 2 (ID: 3) | rtmp://192.168.1.105:1935/live/table3 | Camera Table 2 |

**Test Steps:**

1. Create 2 stream configurations (both destination: "Local")

2. Start both streams

3. In OBS, add both as Media Sources

4. Create scene with 2x1 layout:
   - Source 1: Position (0, 0), Size (960, 1080)
   - Source 2: Position (960, 0), Size (960, 1080)

5. **Expected:** See both cameras side-by-side in OBS

6. Add browser sources for overlays:
   - Overlay 1: `http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=2`
   - Overlay 2: `http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=3`

7. Position overlays at bottom of each camera feed

8. **Result:** Multi-table streaming setup! 🎬

---

## Performance Tests

### Test 5: Check CPU Usage on Raspberry Pi

```bash
# While stream is running
ssh pi@192.168.1.100

# Monitor CPU
top -b -n 1 | grep -E "Cpu|ffmpeg|chromium"

# Expected:
# CPU(s): 60-80% usage total
# ffmpeg: 40-50% (hardware encoding)
# chromium: 10-15% (overlay rendering)
```

**If CPU > 90%:**
- Reduce FPS (60 → 30)
- Reduce resolution (1280x720 → 640x480)
- Disable overlay temporarily

### Test 6: Check Network Bandwidth

```bash
# On Mac mini, monitor incoming streams
docker exec rtmp-server cat /tmp/rtmp-access.log | tail -20

# Or use iftop to monitor network
sudo iftop -i en0

# Expected per stream:
# ~2.5 Mbit/s (2000 kbit/s video + 128 kbit/s audio + overhead)
```

### Test 7: Stream Stability (Long-Running)

```bash
# Start stream
# Wait 30 minutes
# Check if still running

ssh pi@192.168.1.100 'systemctl status carambus-stream@1.service'

# Check for errors
ssh pi@192.168.1.100 'journalctl -u carambus-stream@1.service --since "30 minutes ago" | grep -i error'

# Check uptime in admin UI
open http://localhost:3000/admin/stream_configurations
```

**Expected:** Stream should run continuously without restarts

---

## Integration Tests

### Test 8: Start/Stop/Restart from Admin UI

1. **Start Stream**
   - Click "▶ Start"
   - Wait for 🟢 Active
   - Verify stream works

2. **Stop Stream**
   - Click "⏹ Stop"
   - Wait for ⚪ Inactive
   - Verify FFmpeg process stopped:
     ```bash
     ssh pi@192.168.1.100 'pgrep ffmpeg'
     # Should return empty
     ```

3. **Restart Stream**
   - Click "🔄 Restart"
   - Wait for 🟢 Active
   - Verify stream reconnected

4. **Expected:** All operations work smoothly, no hanging states

### Test 9: Update Configuration While Running

1. Start a stream

2. Click "Edit" on running configuration

3. Change bitrate: 2000 → 2500

4. Save

5. **Expected:** Admin UI prompts "Stream will restart"

6. Stream stops → deploys new config → restarts

7. Verify new bitrate in effect:
   ```bash
   ssh pi@192.168.1.100 'cat /etc/carambus/stream-table-1.conf | grep VIDEO_BITRATE'
   # Should show: VIDEO_BITRATE=2500
   ```

### Test 10: Error Recovery

**Simulate network issue:**

```bash
# On Raspi, block YouTube temporarily
ssh pi@192.168.1.100 'sudo iptables -A OUTPUT -d a.rtmp.youtube.com -j DROP'

# Wait 30 seconds

# Stream should mark as 'error' in admin UI

# Restore network
ssh pi@192.168.1.100 'sudo iptables -F'

# Click "▶ Start" again
# Should recover
```

---

## Acceptance Criteria

### ✅ Test 1 (Local/OBS) Passes If:
- Stream appears in OBS within 10 seconds
- Video is smooth (no stuttering)
- Overlay updates within 3 seconds of score change
- Can stop/start without issues

### ✅ Test 2 (YouTube) Passes If:
- Stream appears in YouTube Studio within 30 seconds
- Stream health is "Excellent" or "Good"
- Overlay is visible and positioned correctly
- Stream runs for 5+ minutes without drops

### ✅ Test 3 (Custom) Passes If:
- Custom server receives connection
- Stream plays back correctly
- Configuration is flexible (any URL works)

### ✅ Test 4 (Multi-Stream) Passes If:
- Multiple Raspis stream simultaneously
- No performance degradation
- OBS can composite all streams
- Each overlay tracks correct game

### ✅ Performance Tests Pass If:
- Raspi CPU < 85%
- No frame drops
- Bitrate stable at configured rate
- Stream runs 30+ minutes without restart

---

## Common Issues & Solutions

### Issue: "SSH Authentication Failed"

**Cause:** Raspberry Pi SSH keys not set up

**Solution:**
```bash
# Set SSH password in environment
export RASPI_SSH_PASSWORD=raspberry

# Or set up SSH keys
ssh-copy-id pi@192.168.1.100

# Update StreamConfiguration with correct SSH user
# Edit config → SSH-User: pi (or www-data)
```

### Issue: "Stream won't start - FFmpeg error"

**Cause:** Camera not found or permission issues

**Solution:**
```bash
# Check camera exists
ssh pi@192.168.1.100 'ls -l /dev/video*'

# Check camera works
ssh pi@192.168.1.100 'v4l2-ctl --list-formats-ext -d /dev/video0'

# Add pi user to video group
ssh pi@192.168.1.100 'sudo usermod -a -G video pi'
```

### Issue: "OBS shows black screen"

**Cause:** Wrong RTMP URL or stream not actually running

**Solution:**
```bash
# Verify stream is running
ssh pi@192.168.1.100 'systemctl status carambus-stream@1.service'

# Check FFmpeg process
ssh pi@192.168.1.100 'ps aux | grep ffmpeg'

# Test RTMP URL manually
ffplay rtmp://192.168.1.105:1935/live/table2

# If that works, issue is with OBS configuration
```

### Issue: "Overlay not updating"

**Cause:** Polling not working or ActionCable disconnected

**Solution:**
```bash
# Check Rails server logs
tail -f log/development.log | grep -i overlay

# Test overlay URL manually
open http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=2

# Check browser console in overlay page (F12)
# Should see: "[StreamingOverlay] Reloading for fresh data..."

# Verify polling interval in code
# app/javascript/controllers/streaming_overlay_controller.js
# Should reload every 3 seconds
```

---

## Rollback Plan

If tests fail catastrophically:

```bash
# Revert migrations
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rails db:rollback

# Revert to previous git commit
git log --oneline | head -5
git revert [commit-hash]
git push

# Existing YouTube-only configs will continue working
```

---

## Next Steps After Testing

Once all tests pass:

1. ✅ **Document production deployment**
   - Update production Raspberry Pis
   - Migrate existing YouTube configs
   - Train administrators on new UI

2. ✅ **Create video tutorial**
   - Screen recording of admin UI
   - OBS setup demonstration
   - Multi-camera configuration

3. ✅ **Update user documentation**
   - Consolidate streaming guides
   - Add destination selection guide
   - Document common workflows

4. ✅ **Production testing**
   - Test at real tournament
   - Gather feedback
   - Iterate on UI/UX

---

## Support Checklist

Before declaring "production ready":

- [ ] All 10 tests pass
- [ ] Performance is acceptable
- [ ] Error recovery works
- [ ] Admin UI is intuitive
- [ ] Documentation is complete
- [ ] Rollback plan tested
- [ ] Team trained on new features

---

**Version:** 1.0  
**Date:** January 2025  
**Status:** ✅ Ready for Testing  
**Estimated Testing Time:** 2-3 hours

