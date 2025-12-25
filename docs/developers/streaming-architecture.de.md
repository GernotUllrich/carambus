# YouTube Live Streaming - Technische Architektur

## 📐 Übersicht

Diese Dokumentation beschreibt die technische Implementierung des YouTube-Live-Streaming-Systems im Carambus-Projekt. Das System nutzt vorhandene Scoreboard-Raspberry-Pis als dezentrale Streaming-Einheiten und ermöglicht tischbezogenes Live-Streaming mit dynamischen Overlays.

---

## 🏗️ Architektur-Prinzipien

### Design-Philosophie

1. **Dezentralisierung**: Jeder Raspberry Pi streamt autonom - keine zentrale Videoverarbeitung
2. **Ressourcen-Effizienz**: Nutzung vorhandener Hardware (Scoreboard-Raspis)
3. **Fail-Safe**: Scoreboard-Betrieb bleibt unabhängig vom Streaming
4. **Skalierbarkeit**: Linear horizontal skalierbar (N Tische = N unabhängige Streams)
5. **Zero-Downtime**: Streaming und Scoreboard können unabhängig neu gestartet werden

### Architektur-Diagramm

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LOCATION SERVER (Raspi 5)                     │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ Rails Application (carambus_master)                           │  │
│  │                                                                │  │
│  │  • StreamConfiguration Model (PostgreSQL)                     │  │
│  │  • Admin Interface (Tailwind CSS)                             │  │
│  │  • Background Jobs (StreamControlJob, StreamHealthJob)        │  │
│  │  • ActionCable (Live-Updates für Overlay)                     │  │
│  │  • Scoreboard Overlay Route (/locations/:md5/scoreboard_...)│  │
│  │                                                                │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                   │                                   │
│                                   │ SSH (Control)                     │
│                                   │ HTTP (Overlay-URL)                │
│                                   ↓                                   │
└───────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ↓                           ↓                           ↓
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│ RASPI 4 (Tisch 1)│      │ RASPI 4 (Tisch 2)│      │ RASPI 4 (Tisch N)│
│                  │      │                  │      │                  │
│ ┌──────────────┐ │      │ ┌──────────────┐ │      │ ┌──────────────┐ │
│ │ Display :0   │ │      │ │ Display :0   │ │      │ │ Display :0   │ │
│ │ Chromium     │ │      │ │ Chromium     │ │      │ │ Chromium     │ │
│ │ KIOSK        │ │      │ │ KIOSK        │ │      │ │ KIOSK        │ │
│ │ (Scoreboard) │ │      │ │ (Scoreboard) │ │      │ │ (Scoreboard) │ │
│ └──────────────┘ │      │ └──────────────┘ │      │ └──────────────┘ │
│                  │      │                  │      │                  │
│ ┌──────────────┐ │      │ ┌──────────────┐ │      │ ┌──────────────┐ │
│ │ Display :1   │ │      │ │ Display :1   │ │      │ │ Display :1   │ │
│ │ Xvfb         │ │      │ │ Xvfb         │ │      │ │ Xvfb         │ │
│ │ Chromium     │ │      │ │ Chromium     │ │      │ │ Chromium     │ │
│ │ HEADLESS     │ │      │ │ HEADLESS     │ │      │ │ HEADLESS     │ │
│ │ (Overlay PNG)│ │      │ │ (Overlay PNG)│ │      │ │ (Overlay PNG)│ │
│ └──────────────┘ │      │ └──────────────┘ │      │ └──────────────┘ │
│        │         │      │        │         │      │        │         │
│        ↓         │      │        ↓         │      │        ↓         │
│ ┌──────────────┐ │      │ ┌──────────────┐ │      │ ┌──────────────┐ │
│ │   FFmpeg     │ │      │ │   FFmpeg     │ │      │ │   FFmpeg     │ │
│ │              │ │      │ │              │ │      │ │              │ │
│ │ Camera ──┐   │ │      │ │ Camera ──┐   │ │      │ │ Camera ──┐   │ │
│ │ Overlay ─┼─→ │ │      │ │ Overlay ─┼─→ │ │      │ │ Overlay ─┼─→ │ │
│ │ Composite│   │ │      │ │ Composite│   │ │      │ │ Composite│   │ │
│ │          │   │ │      │ │          │   │ │      │ │          │   │ │
│ │  RTMP ───┘   │ │      │ │  RTMP ───┘   │ │      │ │  RTMP ───┘   │ │
│ └──────────────┘ │      │ └──────────────┘ │      │ └──────────────┘ │
│        │         │      │        │         │      │        │         │
└────────┼─────────┘      └────────┼─────────┘      └────────┼─────────┘
         │                         │                         │
         └─────────────────────────┼─────────────────────────┘
                                   ↓
                         ┌──────────────────┐
                         │  YouTube RTMP    │
                         │  a.rtmp.youtube  │
                         │  .com:1935       │
                         └──────────────────┘
```

---

## 🧩 Software-Komponenten

### 1. Rails Backend

#### 1.1 Datenbank-Schema

**Tabelle: `stream_configurations`**

```ruby
# db/migrate/XXXXXX_create_stream_configurations.rb
create_table :stream_configurations do |t|
  # Beziehungen
  t.references :table, null: false, foreign_key: true, index: false
  t.references :location, null: false, foreign_key: true, index: false
  
  # YouTube
  t.string :youtube_stream_key      # encrypted!
  t.string :youtube_channel_id
  
  # Kamera
  t.string :camera_device, default: '/dev/video0'
  t.integer :camera_width, default: 1280
  t.integer :camera_height, default: 720
  t.integer :camera_fps, default: 60
  
  # Overlay
  t.boolean :overlay_enabled, default: true
  t.string :overlay_position, default: 'bottom'
  t.integer :overlay_height, default: 200
  
  # Status
  t.string :status, default: 'inactive'
  t.datetime :last_started_at
  t.datetime :last_stopped_at
  t.text :error_message
  t.integer :restart_count, default: 0
  
  # Netzwerk
  t.string :raspi_ip
  t.integer :raspi_ssh_port, default: 22
  
  # Qualität
  t.integer :video_bitrate, default: 2000
  t.integer :audio_bitrate, default: 128
  
  t.timestamps
end

# Indizes
add_index :stream_configurations, :table_id, unique: true
add_index :stream_configurations, :location_id
add_index :stream_configurations, :status
```

**Wichtige Constraints:**
- `table_id` unique: Nur ein Stream pro Tisch
- `youtube_stream_key` verschlüsselt via Rails 7 `encrypts`
- Status-Maschine: `inactive → starting → active → stopping → inactive|error`

#### 1.2 Model-Layer

**`app/models/stream_configuration.rb`**

```ruby
class StreamConfiguration < ApplicationRecord
  # Verschlüsselung
  encrypts :youtube_stream_key, deterministic: false
  
  # Beziehungen
  belongs_to :table
  belongs_to :location
  
  # Status-Helpers
  def inactive?; status == 'inactive'; end
  def active?; status == 'active'; end
  def starting?; status == 'starting'; end
  # ...
  
  # Streaming-Operationen
  def start_streaming
    update(status: 'starting')
    StreamControlJob.perform_later(id, 'start')
  end
  
  def stop_streaming
    update(status: 'stopping')
    StreamControlJob.perform_later(id, 'stop')
  end
  
  # URL-Generierung
  def scoreboard_overlay_url
    # Generiert: http://localhost:80/locations/:md5/scoreboard_overlay?table=N
  end
  
  def rtmp_url
    # Generiert: rtmp://a.rtmp.youtube.com/live2/:stream_key
  end
end
```

**Design-Entscheidungen:**
- Asynchrone Job-Ausführung (verhindert HTTP-Timeouts bei langsamen SSH-Operationen)
- URL-Generierung im Model (Single Source of Truth)
- Deterministic false encryption (höhere Sicherheit, keine Suche nach Keys möglich)

#### 1.3 Controller-Layer

**`app/controllers/admin/stream_configurations_controller.rb`**

Standard CRUD + Custom Actions:

```ruby
# Custom Actions
POST /admin/stream_configurations/:id/start       # Stream starten
POST /admin/stream_configurations/:id/stop        # Stream stoppen
POST /admin/stream_configurations/:id/restart     # Neustart
POST /admin/stream_configurations/:id/health_check # Health-Check
POST /admin/stream_configurations/deploy_all      # Alle deployen
```

**`app/controllers/locations_controller.rb`**

```ruby
def scoreboard_overlay
  # Minimales Layout ohne UI-Chrome
  # Wird von FFmpeg als PNG captured
  @minimal = true
  render layout: 'streaming_overlay'
end
```

**Design-Entscheidungen:**
- Admin-Namespace (nur für authentifizierte Admins)
- Custom Actions als POST (nicht idempotent, state-changing)
- Overlay als separate Action (könnte auch separater Controller sein)

#### 1.4 Job-Layer

**`app/jobs/stream_control_job.rb`**

Zuständig für SSH-basierte Stream-Steuerung:

```ruby
class StreamControlJob < ApplicationJob
  def perform(stream_config_id, action)
    case action
    when 'start'
      handle_start   # Deploy Config → Start Service
    when 'stop'
      handle_stop    # Stop Service
    when 'restart'
      handle_restart # Stop → Wait → Start
    end
  end
  
  private
  
  def deploy_config_file
    # Generiert /etc/carambus/stream-table-N.conf
    # Upload via SSH
  end
  
  def execute_ssh_command(command)
    Net::SSH.start(@raspi_ip, ssh_user, ssh_options) do |ssh|
      ssh.exec!(command)
    end
  end
end
```

**`app/jobs/stream_health_job.rb`**

Periodisches Monitoring:

```ruby
class StreamHealthJob < ApplicationJob
  def perform(stream_config_id)
    # Check: systemctl is-active
    # Check: pgrep ffmpeg
    # Check: journalctl für Errors
    
    # Bei Fehler: Auto-Restart (max 5x)
    # Bei zu vielen Restarts: mark_failed!
  end
end
```

**Design-Entscheidungen:**
- Retry-Mechanismus mit exponential backoff
- Separate Jobs für Control vs. Health (Single Responsibility)
- Health-Job kann manuell oder per Cron getriggert werden
- SSH-Timeouts (10s) verhindern hängende Jobs

#### 1.5 View-Layer

**Admin-Interface (`app/views/admin/stream_configurations/`)**

- `index.html.erb`: Karten-basierte Übersicht, gruppiert nach Location
- `_form.html.erb`: Vollständiges Konfigurationsformular
- `new.html.erb`, `edit.html.erb`: Standard CRUD-Views

**Overlay-View (`app/views/locations/scoreboard_overlay.html.erb`)**

```erb
<% if @game.present? %>
  <div class="overlay-container">
    <div class="player-section">
      <%= @game.player_a.display_name %>
      <%= @game.score_a %>
    </div>
    <div class="vs-section">VS</div>
    <div class="player-section">
      <%= @game.player_b.display_name %>
      <%= @game.score_b %>
    </div>
  </div>
<% else %>
  <div class="no-game">Kein aktives Spiel</div>
<% end %>
```

**Layout: `app/views/layouts/streaming_overlay.html.erb`**

```erb
<html>
<head>
  <style>
    body { background: rgba(0, 0, 0, 0.75); }
    /* Fixed 1920x200 Overlay-Dimensionen */
  </style>
</head>
<body><%= yield %></body>
</html>
```

**Design-Entscheidungen:**
- Fixed Dimensions (1920x200): FFmpeg erwartet konsistente Größe
- Transparenter Hintergrund (alpha channel)
- Inline CSS (keine External Assets, schnelleres Rendering)
- Kein JavaScript im Overlay (statische Captures alle 2s)

#### 1.6 Frontend (Stimulus)

**`app/javascript/controllers/streaming_overlay_controller.js`**

```javascript
export default class extends Controller {
  connect() {
    this.subscribeToTableMonitor()
  }
  
  subscribeToTableMonitor() {
    consumer.subscriptions.create(
      { channel: "TableMonitorChannel" },
      {
        received: (data) => {
          if (data.type === "score_update") {
            this.updateScores(data)
          }
        }
      }
    )
  }
  
  updateScores(data) {
    // Animierte Score-Updates
    // Flash-Effekt bei Änderung
  }
}
```

**Design-Entscheidungen:**
- ActionCable für Echtzeit-Updates
- Nur im Browser-Overlay aktiv (nicht in FFmpeg-Captures)
- Fallback auf Page-Reload bei größeren Änderungen (Spielerwechsel)

---

### 2. Raspberry Pi Software-Stack

#### 2.1 Streaming-Script

**`/usr/local/bin/carambus-stream.sh`**

Haupt-Script, läuft als Systemd-Service:

```bash
#!/bin/bash

# 1. Konfiguration laden
source /etc/carambus/stream-table-${TABLE_NUMBER}.conf

# 2. Xvfb starten (virtueller Framebuffer)
Xvfb :${TABLE_NUMBER} -screen 0 ${CAMERA_WIDTH}x${OVERLAY_HEIGHT}x24 &
XVFB_PID=$!

# 3. Overlay-Update-Loop starten (Hintergrund)
while true; do
  chromium-browser \
    --headless \
    --screenshot=${OVERLAY_IMAGE} \
    --window-size=${CAMERA_WIDTH},${OVERLAY_HEIGHT} \
    ${OVERLAY_URL}
  sleep 2
done &
OVERLAY_PID=$!

# 4. FFmpeg starten (Hauptprozess)
ffmpeg \
  -f v4l2 -i ${CAMERA_DEVICE} \
  -loop 1 -i ${OVERLAY_IMAGE} \
  -filter_complex "[0:v][1:v]overlay=x=0:y=main_h-overlay_h" \
  -c:v h264_v4l2m2m \
  -f flv rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY}

# 5. Cleanup
kill $OVERLAY_PID $XVFB_PID
```

**Prozess-Hierarchie:**

```
systemd
 └─ carambus-stream.sh (PID 1234)
     ├─ Xvfb :1 (PID 1235)
     ├─ Overlay-Loop (PID 1236)
     │   └─ chromium-browser --headless (PID 1237, restart alle 2s)
     └─ ffmpeg (PID 1238, Hauptprozess)
```

**Signal-Handling:**
- `SIGTERM` → Graceful Shutdown (Cleanup)
- `SIGINT` → Sofortiger Stop
- `EXIT trap` → Cleanup-Funktion

#### 2.2 Systemd-Service

**`/etc/systemd/system/carambus-stream@.service`**

```ini
[Unit]
Description=Carambus YouTube Stream for Table %i
After=network-online.target graphical.target

[Service]
Type=simple
User=pi
EnvironmentFile=/etc/carambus/stream-table-%i.conf
ExecStart=/usr/local/bin/carambus-stream.sh %i

# Auto-Restart
Restart=on-failure
RestartSec=10
StartLimitBurst=5

# Resource-Limits
CPUQuota=80%
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```

**Template-Parameter:**
- `%i`: Table Number (z.B. `carambus-stream@1.service` → `%i = 1`)
- Ermöglicht: `systemctl start carambus-stream@{1,2,3}.service`

**Resource-Limits:**
- `CPUQuota=80%`: Verhindert CPU-Starvation des Scoreboards
- `MemoryMax=1G`: Verhindert OOM bei Memory-Leaks

#### 2.3 Konfigurationsdatei

**`/etc/carambus/stream-table-1.conf`**

```bash
# Generiert von StreamControlJob
YOUTUBE_KEY=xxxx-yyyy-zzzz-aaaa-bbbb
CAMERA_DEVICE=/dev/video0
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FPS=60
OVERLAY_ENABLED=true
OVERLAY_URL=http://localhost:80/locations/abc123/scoreboard_overlay?table=1
OVERLAY_POSITION=bottom
OVERLAY_HEIGHT=200
VIDEO_BITRATE=2000
AUDIO_BITRATE=128
TABLE_NUMBER=1
```

**Security:**
- Nur root und pi lesbar: `chmod 640`
- YouTube-Key wird nicht in Logs gezeigt

---

## 🔧 Hardware-Komponenten

### 1. Raspberry Pi 4 (Scoreboard)

**Technische Spezifikationen:**
- CPU: Broadcom BCM2711 (Quad-Core Cortex-A72, 1.5GHz)
- RAM: 2-4GB LPDDR4
- Video: H.264 Hardware-Encoder (1080p30 oder 720p60)
- USB: 2x USB 3.0, 2x USB 2.0
- Network: Gigabit Ethernet

**Ressourcen-Nutzung (typisch):**
```
Process              CPU    Memory
--------------------------------------
Scoreboard (Chromium) 15%    300 MB
FFmpeg (Encoding)     45%    150 MB
Xvfb                   5%     50 MB
Overlay (Chromium)    10%    200 MB
System                 5%    100 MB
--------------------------------------
Total                 80%    800 MB
```

**Kritische Punkte:**
- CPU wird hauptsächlich von FFmpeg genutzt (Video-Encoding)
- Hardware-Encoder (`h264_v4l2m2m`) ist essentiell - Software-Encoding würde 200%+ CPU brauchen
- 2GB RAM ist Minimum, 4GB empfohlen

### 2. USB-Webcam (Logitech C922)

**Spezifikationen:**
- Sensor: 1/2.7" CMOS
- Auflösung: 1920x1080 @ 30fps, 1280x720 @ 60fps
- Interface: USB 2.0 (High Speed, 480 Mbit/s)
- Video-Codec: MJPEG oder H.264 (abhängig von Treiber)
- UVC-Kompatibel (USB Video Class)

**V4L2-Integration:**
```bash
# Kamera detektieren
v4l2-ctl --list-devices

# Formate auflisten
v4l2-ctl --device=/dev/video0 --list-formats-ext

# Typischer Output:
# [0]: 'MJPG' (Motion-JPEG, compressed)
#      Size: Discrete 1280x720
#        Interval: (1/60) = 60.000 fps
```

**Warum C922 und nicht C920?**
- C922: 720p @ **60 fps** (flüssige Bewegungen bei Billard wichtig)
- C920: 720p @ 30 fps (ruckelt bei schnellen Stößen)
- C922: Bessere Low-Light-Performance
- Preisdifferenz: ~20€

### 3. Netzwerk-Infrastruktur

**Anforderungen:**
- Upload pro Stream: ~2.5 Mbit/s (bei 720p60, 2000 kbit/s)
- Latenz unkritisch (Live-Streaming toleriert 5-10s Delay)
- Paket-Loss kritisch (TCP: RTMP bricht bei >5% Loss ab)

**Typisches Setup:**
```
Internet (50 Mbit/s Down, 10 Mbit/s Up)
    ↓
Router/Firewall (Port 1935 offen)
    ↓
Switch (Gigabit)
    ├─ Location Server (Raspi 5)
    ├─ Scoreboard Raspi 1 (Tisch 1) → YouTube Stream 1
    ├─ Scoreboard Raspi 2 (Tisch 2) → YouTube Stream 2
    └─ Scoreboard Raspi N (Tisch N) → YouTube Stream N
```

**Bandbreiten-Berechnung:**
```
Streams: 4 Tische
Pro Stream: 2.5 Mbit/s
Total: 4 × 2.5 = 10 Mbit/s Upload
Empfehlung: 15 Mbit/s Upload (50% Overhead)
```

---

## ⚙️ Technische Details

### 1. Video-Pipeline

#### FFmpeg Command Breakdown

```bash
ffmpeg \
  # === INPUT: Kamera ===
  -f v4l2 \                    # Format: Video4Linux2
  -input_format h264 \         # Codec vom Device (wenn verfügbar)
  -video_size 1280x720 \       # Auflösung
  -framerate 60 \              # Framerate
  -i /dev/video0 \             # Input-Device
  
  # === INPUT: Overlay ===
  -loop 1 \                    # Loop PNG infinitely
  -framerate 1 \               # Update nur 1x/s (reicht für Overlay)
  -i /tmp/overlay.png \        # Overlay-Image
  
  # === FILTER: Composite ===
  -filter_complex "\
    [0:v]scale=1280:720[cam];\     # Scale Camera (falls nötig)
    [cam][1:v]overlay=\            # Overlay on Camera
      x=0:\                        # Position X
      y=main_h-overlay_h:\         # Position Y (bottom)
      shortest=1\                  # Stop when shortest ends
    [out]" \
  
  # === OUTPUT: YouTube ===
  -map "[out]" \               # Map filtered stream
  -c:v h264_v4l2m2m \          # Hardware-Encoder (Raspi 4)
  -b:v 2000k \                 # Video-Bitrate
  -maxrate 2500k \             # Max-Bitrate (Buffer)
  -bufsize 5000k \             # Buffer-Größe
  -pix_fmt yuv420p \           # Pixel-Format (YouTube-kompatibel)
  -g 120 \                     # GOP-Size (Keyframe alle 2s bei 60fps)
  -keyint_min 120 \            # Min Keyframe-Interval
  -sc_threshold 0 \            # Disable Scene-Change-Detection
  -f flv \                     # Format: Flash Video (RTMP-Container)
  rtmp://a.rtmp.youtube.com/live2/STREAM_KEY
```

**Wichtige Parameter erklärt:**

- **`h264_v4l2m2m`**: Hardware-Encoder des Raspi 4
  - Nutzt VideoCore VI GPU
  - 10x effizienter als Software-Encoding
  - Limitation: Max 1080p30 oder 720p60

- **GOP-Size (`-g 120`)**: Keyframe-Interval
  - Bei 60fps: 120 Frames = 2 Sekunden
  - YouTube empfiehlt: 2-4s Keyframe-Interval
  - Kürzere Intervale: Höhere Bitrate, bessere Seek-Performance
  - Längere Intervale: Niedrigere Bitrate, schlechteres Seek

- **Buffer-Size (`-bufsize`)**: 2x Video-Bitrate
  - Smoothed Bitrate-Spitzen
  - Bei Netzwerk-Schwankungen wichtig

#### Video-Latenz-Analyse

```
Component                    Latency
─────────────────────────────────────
Kamera → USB                 33ms    (1 Frame @ 30fps)
USB → V4L2                   10ms    (Kernel-Buffer)
V4L2 → FFmpeg                20ms    (User-Space-Buffer)
FFmpeg Encoding              50ms    (Hardware-Encoder)
RTMP → YouTube Ingest       500ms    (Network + Processing)
YouTube Transcoding        2000ms    (Multiple Renditions)
YouTube CDN → Viewer       3000ms    (Buffering)
─────────────────────────────────────
Total Latency              ~6s      (Typisch)
```

**Optimierung für niedrigere Latenz:**
- Ultra-Low-Latency-Mode: `-tune zerolatency` (nicht mit Hardware-Encoder)
- Reduzierte GOP-Size: `-g 60` (1s Keyframes)
- Trade-Off: Höhere Bitrate nötig

### 2. Overlay-Rendering

#### Chromium Headless

**Render-Pipeline:**

```
1. HTTP Request → Rails Server
   GET /locations/:md5/scoreboard_overlay?table=1
   
2. Rails Controller
   locations_controller.rb#scoreboard_overlay
   - Lädt @game, @table_monitor, @tournament
   - Rendert streaming_overlay Layout
   
3. HTML + CSS Rendering (Chromium)
   - Layout-Engine: Blink
   - Rendering auf Xvfb Display :1
   - Kein GPU-Rendering (--disable-gpu)
   
4. Screenshot-Capture
   - Via --screenshot Flag
   - Format: PNG mit Alpha-Channel
   - Auflösung: 1920x200px
   
5. Output: /tmp/carambus-overlay-table-1.png
```

**Performance-Optimierung:**

```bash
chromium-browser \
  --headless \
  --disable-gpu \              # Kein GPU (nicht verfügbar in Xvfb)
  --screenshot=/tmp/out.png \
  --window-size=1920,200 \
  --virtual-time-budget=2000 \ # Max 2s Render-Zeit
  --hide-scrollbars \          # Clean Output
  URL
```

**`--virtual-time-budget`**: Wichtig!
- Setzt Timeout für Rendering
- Verhindert hängende Prozesse
- 2000ms = 2 Sekunden reichen für statisches HTML/CSS

#### Xvfb (X Virtual Framebuffer)

**Warum Xvfb?**
- Chromium braucht X11-Display (auch headless)
- Physical Display :0 ist vom Scoreboard belegt
- Xvfb emuliert Display ohne Hardware

**Resource-Footprint:**
```
Memory: ~50 MB
CPU: ~5% (nur während Chromium-Rendering)
```

**Alternatives: Wayland?**
- Chromium unterstützt Wayland-Headless
- Noch experimentell (Stand 2024)
- Xvfb ist stabiler für Production

### 3. SSH-based Control

#### Net::SSH Implementation

```ruby
# app/jobs/stream_control_job.rb
def execute_ssh_command(command)
  Net::SSH.start(
    @raspi_ip,
    ssh_user,
    password: ENV['RASPI_SSH_PASSWORD'],
    port: @raspi_port,
    timeout: 10,
    non_interactive: true,
    verify_host_key: :never  # Nur für lokale Netzwerke!
  ) do |ssh|
    output = ssh.exec!(command)
    exit_code = ssh.exec!("echo $?").strip.to_i
    
    OpenStruct.new(
      success?: exit_code.zero?,
      output: output,
      exit_code: exit_code
    )
  end
end
```

**Security-Considerations:**

❌ **Nicht Production-Ready:**
- Passwort-Auth (sollte Key-Auth sein)
- `verify_host_key: :never` (MITM-Risiko)

✅ **OK für lokale Netzwerke:**
- Raspis sind nur im LAN erreichbar
- Keine Internet-Exposition
- Trade-Off: Convenience vs. Security

**Bessere Alternative (TODO):**

```ruby
# 1. SSH-Key generieren auf Location Server
ssh-keygen -t ed25519 -f /home/carambus/.ssh/streaming_rsa

# 2. Public Key auf Raspis deployen
ssh-copy-id -i /home/carambus/.ssh/streaming_rsa.pub pi@192.168.1.100

# 3. Key-based Auth in Job
Net::SSH.start(
  @raspi_ip,
  ssh_user,
  keys: ['/home/carambus/.ssh/streaming_rsa'],
  timeout: 10
)
```

---

## 🔄 Operational Flow

### Stream-Lifecycle

#### 1. Start-Sequence

```
User clicks "Start" in Admin UI
  ↓
POST /admin/stream_configurations/:id/start
  ↓
StreamConfigurationsController#start
  config.start_streaming
  ↓
StreamConfiguration#start_streaming
  update(status: 'starting')
  StreamControlJob.perform_later(id, 'start')
  ↓
StreamControlJob#perform
  ↓
StreamControlJob#handle_start
  1. Check if already running
  2. Deploy config file via SSH
  3. systemctl start carambus-stream@N.service
  4. Wait 2s
  5. Verify running
  ↓
StreamConfiguration#mark_started!
  update(status: 'active', last_started_at: Time.current)
  ↓
Admin UI updates via Turbo/Reflex
  Status badge: 🟢 Active
```

#### 2. Runtime-Monitoring

```
Cron/Sidekiq schedules StreamHealthJob.perform_later(id)
  ↓
StreamHealthJob#perform
  1. check_service_active
     systemctl is-active carambus-stream@N.service
  
  2. check_ffmpeg_running
     pgrep -f 'ffmpeg.*table.*N'
  
  3. check_for_errors
     journalctl -u carambus-stream@N.service -n 50 | grep -i error
  
  4. Decision:
     - All OK → Do nothing
     - Service down → mark_failed!
     - FFmpeg dead → restart (max 5x)
     - Errors → log & alert
```

#### 3. Stop-Sequence

```
User clicks "Stop"
  ↓
POST /admin/stream_configurations/:id/stop
  ↓
config.stop_streaming
  ↓
StreamControlJob.perform_later(id, 'stop')
  ↓
StreamControlJob#handle_stop
  1. systemctl stop carambus-stream@N.service
  2. Wait 1s
  3. Verify stopped (pgrep returns empty)
  ↓
StreamConfiguration#mark_stopped!
  update(status: 'inactive', last_stopped_at: Time.current)
```

### Error-Handling

#### Retry-Strategie

```ruby
class StreamControlJob < ApplicationJob
  # Netzwerk-Fehler: Exponential Backoff
  retry_on Net::SSH::Exception, 
    wait: :exponentially_longer,
    attempts: 3
  
  # Host unreachable: Feste Wartezeit
  retry_on Errno::EHOSTUNREACH,
    wait: 10.seconds,
    attempts: 3
end
```

**Retry-Schedule:**
```
Attempt 1: Immediate
Attempt 2: Wait 3s  (exponential: 2^1 + jitter)
Attempt 3: Wait 9s  (exponential: 2^2 + jitter)
Failed: Mark as error
```

#### Circuit-Breaker (Too Many Restarts)

```ruby
def handle_ffmpeg_failure
  if @config.restart_count < 5
    @config.increment!(:restart_count)
    @config.restart_streaming
  else
    @config.mark_failed!("Too many restarts")
    # Alert Admin (TODO: Email/Slack Notification)
  end
end
```

**Rationale:**
- FFmpeg kann aus vielen Gründen crashen
- Network-Issues, Camera-Problems, YouTube-Rejects
- Nach 5 Restarts: Wahrscheinlich kein temporäres Problem
- Manual Intervention required

---

## 🔒 Security-Considerations

### 1. Stream-Key Protection

**Encryption:**
```ruby
class StreamConfiguration < ApplicationRecord
  encrypts :youtube_stream_key, deterministic: false
end
```

- Rails 7 Active Record Encryption
- AES-256-GCM
- Key-Rotation unterstützt
- Key-Storage: `config/credentials.yml.enc`

**Key-Derivation:**
```ruby
# config/credentials.yml.enc
active_record_encryption:
  primary_key: <%= 32 Bytes Random %>
  deterministic_key: <%= 32 Bytes Random %>
  key_derivation_salt: <%= 32 Bytes Random %>
```

**Decryption nur in:**
- StreamControlJob (für SSH-Upload)
- Admin-Interface (mit Asterisken maskiert)

### 2. SSH-Authentication

**Current State (Development):**
- ❌ Password-based
- ❌ `verify_host_key: :never`

**Production Recommendations:**
1. SSH-Keys mit Passphrase
2. Separate Key pro Environment
3. `authorized_keys` restrictions:
   ```
   command="/usr/local/bin/streaming-control.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
   ```
4. Fail2ban für SSH-Brute-Force-Protection

### 3. YouTube-API-Rate-Limits

**RTMP-Limits (per Channel):**
- Concurrent Streams: 1 (per Stream-Key)
- Max Stream Duration: 12 Stunden (dann automatischer Reconnect)
- Bitrate: Max 51 Mbit/s (weit über unseren 2-3 Mbit/s)

**Monitoring:**
- YouTube kann Stream ablehnen bei:
  - Falscher Stream-Key
  - Copyright-Strikes auf Channel
  - Community-Guidelines-Violations
  - Technical Issues (zu niedriger Bitrate, falsches Format)

**Error-Handling:**
- FFmpeg loggt YouTube-Reject-Reasons
- Parsing in StreamHealthJob möglich
- Auto-Notification an Admin

---

## 📊 Performance & Scalability

### Bottlenecks

#### 1. Raspberry Pi CPU

**Limit:** ~80% CPU (CPUQuota=80% in Systemd)

**Breakdown bei 1 Stream:**
```
FFmpeg (Hardware-Encoding): 45%
Chromium (Scoreboard):      15%
Chromium (Overlay):         10%
Xvfb:                        5%
System:                      5%
────────────────────────────────
Total:                      80%
```

**Wenn CPU > 90%:**
- Frame-Drops in FFmpeg
- Stuttering im Scoreboard
- System wird unresponsive

**Mitigation:**
- Hardware-Encoding essentiell
- Nice-Level für FFmpeg: `nice -n 5` (niedrigere Priorität als Scoreboard)
- CPU-Governor: `performance` (kein Throttling)

#### 2. Network-Upload

**Berechnung:**
```
Tables: N
Bitrate: B kbit/s
Upload required: N × B

Beispiel: 4 Tische × 2500 kbit/s = 10 Mbit/s
Reserve: +50% = 15 Mbit/s
```

**Wenn Upload zu niedrig:**
- FFmpeg-Buffer läuft voll
- Stream-Disconnect
- Automatischer Reconnect (aber Viewer-Unterbrechung)

**Monitoring:**
```bash
# Bandwidth-Test
speedtest-cli --simple

# RTMP-Connection-Status
journalctl -u carambus-stream@1.service | grep "Connection refused"
```

#### 3. Rails Background-Jobs

**Concurrency:**
- Sidekiq: 25 Threads (default)
- Pro Job ~1-5s (SSH-Operation)
- Max Load: ~300 Operations/Minute

**Wenn zu viele Streams:**
- Job-Queue läuft voll
- Start/Stop-Operationen verzögert
- User-Experience leidet

**Scaling:**
```ruby
# config/sidekiq.yml
:concurrency: 50  # Erhöhen bei vielen Streams

:queues:
  - [streaming_control, 2]  # Höhere Priorität
  - [default, 1]
```

### Horizontal Scalability

**Pro Location:**
- Max Streams: Begrenzt durch Upload-Bandbreite
- Typisch: 4-8 Tische = 4-8 Streams
- Location-Server (Raspi 5): Verkraftet 20+ Streams (nur SSH-Control, kein Video-Processing)

**Multi-Location:**
- Jede Location hat eigenen Server
- Keine zentrale Video-Verarbeitung
- Perfekt horizontal skalierbar

**Beispiel: 10 Locations, je 4 Tische:**
```
Total Streams: 40
Per Location Server: 4 Streams Control
Video-Processing: 100% dezentral (auf den 40 Scoreboard-Raspis)
Central Load: Nur Rails-App + DB (vernachlässigbar)
```

---

## 🧪 Testing-Strategie

### Unit-Tests

```ruby
# spec/models/stream_configuration_spec.rb
RSpec.describe StreamConfiguration do
  it "generates correct RTMP URL" do
    config = create(:stream_configuration, youtube_stream_key: "test-key")
    expect(config.rtmp_url).to eq("rtmp://a.rtmp.youtube.com/live2/test-key")
  end
  
  it "transitions status correctly" do
    config = create(:stream_configuration, status: 'inactive')
    config.start_streaming
    expect(config.status).to eq('starting')
  end
end
```

### Integration-Tests

```ruby
# spec/jobs/stream_control_job_spec.rb
RSpec.describe StreamControlJob do
  it "deploys config and starts service" do
    config = create(:stream_configuration)
    
    expect_any_instance_of(Net::SSH::Connection::Session)
      .to receive(:exec!).with(/systemctl start/).and_return("")
    
    described_class.new.perform(config.id, 'start')
    
    expect(config.reload.status).to eq('active')
  end
end
```

### System-Tests (E2E)

```ruby
# spec/system/admin/streaming_spec.rb
RSpec.describe "Admin Streaming", type: :system do
  it "admin can start stream" do
    config = create(:stream_configuration)
    
    visit admin_stream_configurations_path
    click_button "Start"
    
    expect(page).to have_content("Starting")
    # WebMock: Mock SSH-Call
    # Eventually: have_content("Active")
  end
end
```

### Manual Testing-Checklist

**Auf Entwicklungsmaschine:**
- [ ] Migration läuft durch
- [ ] Model-Validierungen greifen
- [ ] Admin-Interface erreichbar
- [ ] Form-Validierung funktioniert

**Auf Test-Raspi:**
- [ ] SSH-Connection funktioniert
- [ ] Script-Upload klappt
- [ ] Systemd-Service startet
- [ ] FFmpeg greift Kamera
- [ ] Xvfb + Chromium laufen
- [ ] Overlay-Image wird generiert
- [ ] RTMP-Connection zu YouTube

**Auf YouTube:**
- [ ] Stream erscheint in Studio
- [ ] Video zeigt Kamera-Bild
- [ ] Overlay ist sichtbar
- [ ] Latenz akzeptabel (<10s)
- [ ] Stream läuft stabil (>5 Min)

---

## 🚀 Deployment

### Setup-Prozess (Neue Installation)

**1. Location-Server (Raspi 5):**

```bash
cd /path/to/carambus_master

# Migration
rails db:migrate

# Assets kompilieren (falls Overlay-Styles geändert)
yarn build
yarn build:css
rails assets:precompile
```

**2. Scoreboard-Raspi (pro Tisch):**

```bash
# Via Rake-Task (vom Location-Server aus)
export RASPI_SSH_PASSWORD=raspberry
rake streaming:setup[192.168.1.100]

# Oder manuell:
ssh pi@192.168.1.100

# Pakete installieren
sudo apt-get update
sudo apt-get install -y ffmpeg xvfb v4l-utils chromium-browser

# Directories anlegen
sudo mkdir -p /etc/carambus /var/log/carambus /usr/local/bin

# Script + Service uploaden (via SCP)
scp bin/carambus-stream.sh pi@192.168.1.100:/tmp/
scp bin/carambus-stream.service pi@192.168.1.100:/tmp/

# Installieren
ssh pi@192.168.1.100
sudo mv /tmp/carambus-stream.sh /usr/local/bin/
sudo mv /tmp/carambus-stream.service /etc/systemd/system/carambus-stream@.service
sudo chmod +x /usr/local/bin/carambus-stream.sh
sudo systemctl daemon-reload
```

### Update-Prozess (Code-Änderungen)

**Overlay-View geändert:**
```bash
# Kein Deployment nötig - Rails rendert Live
# Nur assets:precompile bei CSS-Änderungen
```

**FFmpeg-Script geändert:**
```bash
# Auf Location-Server:
cd carambus_master

# Script auf alle Raspis deployen:
for ip in 192.168.1.{100,101,102,103}; do
  scp bin/carambus-stream.sh pi@$ip:/tmp/
  ssh pi@$ip "sudo mv /tmp/carambus-stream.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/carambus-stream.sh"
  ssh pi@$ip "sudo systemctl restart carambus-stream@1.service"
done
```

**Model/Job geändert:**
```bash
# Standard Rails-Deployment
git pull
bundle install
rails db:migrate
sudo systemctl restart carambus  # Rails-App
```

---

## 🐛 Debugging

### Log-Locations

**Location-Server:**
```bash
# Rails-Log
tail -f log/production.log | grep -i stream

# Sidekiq-Log
tail -f log/sidekiq.log
```

**Scoreboard-Raspi:**
```bash
# Systemd-Service-Log
sudo journalctl -u carambus-stream@1.service -f

# FFmpeg-Log
tail -f /var/log/carambus/stream-table-1.log

# Error-Log
tail -f /var/log/carambus/stream-table-1-error.log
```

### Debug-Levels

**FFmpeg Verbose-Mode:**
```bash
# In carambus-stream.sh ändern:
ffmpeg -loglevel debug \  # statt default
  ...
```

**Rails-Logger:**
```ruby
# In StreamControlJob
Rails.logger.debug "[StreamControl] SSH Command: #{command}"
Rails.logger.debug "[StreamControl] SSH Output: #{output}"
```

### Common Issues & Solutions

**Issue: "relation already exists" bei Migration**
```bash
# Index manuell droppen
rails runner "ActiveRecord::Base.connection.execute('DROP INDEX IF EXISTS index_stream_configurations_on_table_id')"
rails db:migrate
```

**Issue: FFmpeg findet Kamera nicht**
```bash
# Kamera-Devices auflisten
ls -l /dev/video*

# UVC-Treiber laden
sudo modprobe uvcvideo

# Kamera neu einstecken
# Oder Raspi rebooten
```

**Issue: Overlay zeigt nur schwarzes Bild**
```bash
# Chromium manuell testen
DISPLAY=:1 chromium-browser \
  --headless \
  --screenshot=/tmp/test.png \
  --window-size=1920,200 \
  "http://localhost/locations/xxx/scoreboard_overlay?table=1"

# PNG anschauen (auf Desktop-PC)
scp pi@192.168.1.100:/tmp/test.png .
open test.png
```

**Issue: SSH-Connection failed**
```bash
# Timeout erhöhen
Net::SSH.start(..., timeout: 30)  # statt 10

# Verbose-Mode
Net::SSH.start(..., verbose: :debug)

# Netzwerk testen
ping 192.168.1.100
telnet 192.168.1.100 22
```

---

## 📚 Weiterführende Dokumentation

### Internal Links

- [Administratoren-Handbuch](../administrators/streaming-setup.de.md)
- [Schnellstart-Guide](../administrators/streaming-quickstart.de.md)
- [Server-Architektur](../administrators/server-architecture.de.md)
- [Scoreboard-Setup](../administrators/scoreboard-autostart.de.md)

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

**Rails:**
- [Active Record Encryption](https://edgeguides.rubyonrails.org/active_record_encryption.html)
- [ActiveJob](https://guides.rubyonrails.org/active_job_basics.html)
- [ActionCable](https://guides.rubyonrails.org/action_cable_overview.html)

---

## 🔮 Future Enhancements

### Short-Term (Next Release)

- [ ] Email-Notifications bei Stream-Fehlern
- [ ] Stream-Thumbnails (Preview-Images im Admin-Interface)
- [ ] Bandwidth-Monitoring (Upload-Usage-Tracking)
- [ ] Multi-Camera-Support (Picture-in-Picture)

### Mid-Term

- [ ] WebRTC-based Preview (Live-Vorschau im Browser ohne YouTube)
- [ ] Automatic Bitrate-Adjustment (bei Netzwerk-Schwankungen)
- [ ] Recording-Feature (lokale Aufzeichnung parallel zum Stream)
- [ ] Multi-Language-Overlays (EN/DE switchen)

### Long-Term

- [ ] Cloud-Streaming (Offload von Raspi auf Cloud-Encoder)
- [ ] AI-basierte Kamera-Steuerung (automatisches Zoom/Pan)
- [ ] Multi-Platform-Streaming (Twitch, Facebook gleichzeitig)
- [ ] Analytics-Dashboard (Viewer-Zahlen, Watch-Time, etc.)

---

**Version**: 1.0  
**Datum**: Dezember 2024  
**Autor**: Carambus Development Team  
**Lizenz**: Proprietär

