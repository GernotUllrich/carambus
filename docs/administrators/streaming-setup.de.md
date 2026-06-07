# YouTube Live Streaming - Setup & Betrieb

## 📋 Übersicht

Das Carambus-System unterstützt Live-Streaming von Billard-Spielen. Dabei werden die bereits vorhandenen Scoreboard-Raspberry-Pis genutzt, um kostengünstig jeden Tisch einzeln zu streamen. Als Stream-Ziel (`stream_destination`) stehen drei Optionen zur Verfügung: **`youtube`** (direkt zu YouTube), **`local`** (lokaler RTMP-Server, z.B. für OBS-Integration) und **`custom`** (eigener RTMP-Endpunkt). Diese Anleitung beschreibt überwiegend den YouTube-Weg.

### Architektur

```
┌─────────────────────────────────────────────┐
│  Scoreboard Raspi 4 (pro Tisch)            │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Display :0                           │  │
│  │  ↳ Chromium Kiosk → Scoreboard      │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Virtuelles Display :1                │  │
│  │  ↳ Chromium Headless → Overlay      │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ USB-Kamera (Logitech C922)           │  │
│  │  ↳ /dev/video0 → FFmpeg              │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ FFmpeg Compositing                   │  │
│  │  Kamera + Overlay → YouTube RTMP     │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 🛠️ Hardware-Anforderungen

### Pro gestreamtem Tisch

1. **USB-Webcam: Logitech C922** (~80-90€)
   - 1280x720 @ 60fps (empfohlen für flüssige Bewegungen)
   - Alternativ: Logitech C920 (~60-70€, 30fps)
   - USB 2.0/3.0 Anschluss

2. **Raspberry Pi 4** (bereits vorhanden als Scoreboard)
   - Minimum 2GB RAM (4GB empfohlen)
   - Betriebssystem: Raspberry Pi OS (Bullseye oder neuer)

3. **Kamera-Montage**
   - Stativ oder Wandhalterung
   - USB-Verlängerungskabel (falls nötig)
   - Positionierung: Über dem Tisch, Blick auf die Spielfläche

### Netzwerk-Anforderungen

- **Upload-Bandbreite**: ~2-3 Mbit/s pro Stream bei 720p60
- Beispiel: 4 parallele Streams = ~10-12 Mbit/s Upload nötig
- Stabile LAN-Verbindung empfohlen (WLAN möglich, aber nicht ideal)

---

## 🎬 YouTube-Vorbereitung

### 1. YouTube-Kanal einrichten

1. Bei YouTube anmelden
2. YouTube Studio öffnen → [studio.youtube.com](https://studio.youtube.com)
3. Kanal erstellen (falls noch nicht vorhanden)

### 2. Live-Streaming aktivieren

1. YouTube Studio → **Inhalte** → **Live**
2. Erstmalige Aktivierung: Wartezeit von 24 Stunden
3. Nach Freischaltung: Stream-Keys erstellen

### 3. Stream-Key generieren

1. YouTube Studio → **Einstellungen** → **Stream**
2. **Neuen Stream-Key erstellen**
3. Name: z.B. "Tisch 1 - BC Hamburg"
4. Stream-Key kopieren (Format: `xxxx-yyyy-zzzz-aaaa-bbbb`)

**Wichtig**: Pro Tisch einen eigenen Stream-Key erstellen!

### 4. Channel-ID ermitteln (optional)

1. YouTube Studio → **Anpassung** → **Basisinformationen**
2. Channel-ID kopieren (Format: `UCxxxxxxxxxxxxxxxxxxxxxxxxx`)
3. Wird für direkten Link zum Live-Stream benötigt

---

## ⚙️ Software-Installation

### 1. Raspberry Pi vorbereiten

Auf dem **Location-Server** (Raspi 5):

```bash
# SSH-Passwort als Environment-Variable setzen
export RASPI_SSH_USER=pi
export RASPI_SSH_PASSWORD=raspberry  # Durch echtes Passwort ersetzen!

# Setup auf Scoreboard-Raspi ausführen
cd /path/to/carambus_master
rake streaming:setup[192.168.1.100]  # IP des Scoreboard-Raspis
```

Das Setup-Script installiert automatisch:
- FFmpeg (Video-Encoding)
- Xvfb (Virtueller Framebuffer für Overlay)
- Chromium (Overlay-Rendering)
- v4l-utils (Kamera-Tools)
- Systemd Service-Dateien

### 2. Installation testen

```bash
rake streaming:test[192.168.1.100]
```

Alle Tests sollten mit ✅ bestanden werden.

---

## 📝 Konfiguration im Admin-Interface

### 1. Stream-Konfiguration erstellen

1. Carambus Admin-Interface öffnen
2. Navigation → **YouTube Live Streaming** (oder `/admin/stream_configurations`)
3. **Neue Stream-Konfiguration** klicken

### 2. Basis-Einstellungen

**Location & Tisch:**
- Location auswählen
- Tisch auswählen

**Stream-Ziel (`stream_destination`):**
- **`youtube`**: Direkt zu YouTube (Standard)
- **`local`**: Lokaler RTMP-Server (z.B. Mac mini/Laptop mit Docker, für OBS-Integration)
- **`custom`**: Eigener RTMP-Endpunkt

**YouTube-Konfiguration (bei `stream_destination = youtube`):**
- **Stream-Key**: Von YouTube kopieren
- **Channel-ID**: (optional) Für direkten Link

**Lokaler RTMP-Server (bei `stream_destination = local`):**
- **RTMP-Server-IP**: IP des Rechners mit dem RTMP-Server (z.B. `192.168.2.150`)
- Stream-URL wird automatisch erzeugt: `rtmp://<IP>:1935/stream/table<TABLE_ID>`

**Eigener RTMP-Endpunkt (bei `stream_destination = custom`):**
- **Custom RTMP-URL**: Vollständige Basis-URL des RTMP-Servers
- **Custom RTMP-Key**: (optional) Wird an die URL angehängt

### 3. Kamera-Einstellungen

**Empfohlene Werte für Logitech C922:**
```
Gerät:      /dev/video0
Breite:     1280
Höhe:       720
Framerate:  60 fps
```

**Für Logitech C920:**
```
Framerate:  30 fps  (Rest gleich)
```

### 4. Overlay-Einstellungen

```
Overlay aktiviert:  ✓
Position:           Unten
Höhe:               200 px
```

Das Overlay zeigt:
- Spielernamen
- Aktueller Spielstand
- Turnierinfo (falls vorhanden)
- Live-Indicator

### 5. Stream-Qualität

**Empfohlene Werte:**
```
Video-Bitrate:  2000 kbit/s  (720p60)
Audio-Bitrate:  128 kbit/s
```

**Anpassungen je nach Upload:**
- Mehr Bandbreite: 2500 kbit/s
- Weniger Bandbreite: 1500 kbit/s

### 6. Netzwerk

```
Raspi IP:       192.168.1.100  (wird automatisch vom Tisch übernommen)
SSH-Port:       22
```

### 7. Speichern & Deployen

1. **Speichern** klicken
2. Konfiguration wird auf den Scoreboard-Raspi deployed
3. Status prüfen: Sollte auf "Inactive" stehen

---

## ▶️ Stream starten

### Via Admin-Interface (empfohlen)

1. `/admin/stream_configurations` öffnen
2. Gewünschten Stream finden
3. **Start** klicken
4. Status wechselt auf "Starting" → "Active"
5. Bei Fehler: Error-Message wird angezeigt

### Via SSH (manuell)

```bash
ssh pi@192.168.1.100
sudo systemctl start carambus-stream@1.service

# Status prüfen
sudo systemctl status carambus-stream@1.service

# Logs anzeigen
sudo journalctl -u carambus-stream@1.service -f
```

### Via Rake Task

```bash
cd /path/to/carambus_master
rake streaming:status  # Alle Streams anzeigen
```

---

## 🔍 Monitoring & Troubleshooting

### Stream-Status prüfen

**Im Admin-Interface:**
- Live-Status-Anzeige
- Uptime-Counter
- Error-Messages
- **Health-Check** klicken für aktuelle Diagnose

**Via Rake Task:**
```bash
rake streaming:status
```

**Via SSH:**
```bash
ssh pi@192.168.1.100

# Service-Status
sudo systemctl status carambus-stream@1.service

# Live-Logs
sudo journalctl -u carambus-stream@1.service -f

# FFmpeg-Prozess prüfen
ps aux | grep ffmpeg

# Kamera prüfen
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

### Häufige Probleme

#### Problem: "Camera device not found"

**Lösung:**
```bash
# Kamera-Geräte anzeigen
ls -l /dev/video*

# Falls mehrere Kameras: Richtige auswählen
v4l2-ctl --list-devices

# In Konfiguration anpassen: /dev/video0, /dev/video1, etc.
```

#### Problem: "Cannot reach YouTube RTMP server"

**Ursachen:**
- Keine Internetverbindung
- Firewall blockiert Port 1935 (RTMP)
- Router-Konfiguration

**Test:**
```bash
ping a.rtmp.youtube.com
telnet a.rtmp.youtube.com 1935
```

#### Problem: Stream startet, aber YouTube zeigt nichts

**Checkliste:**
1. Stream-Key korrekt?
2. YouTube-Stream schon "live geschaltet"?
3. 24h Wartezeit nach Aktivierung abgelaufen?
4. FFmpeg-Logs prüfen:
   ```bash
   tail -f /var/log/carambus/stream-table-1.log
   ```

#### Problem: "Stream läuft, aber ruckelt"

**Ursachen:**
- Upload-Bandbreite zu niedrig
- Zu hohe Bitrate eingestellt
- CPU-Überlastung des Raspis

**Lösungen:**
1. Bitrate reduzieren (z.B. auf 1500k)
2. Framerate reduzieren (60 → 30 fps)
3. Andere Prozesse auf Raspi beenden
4. Netzwerk-Qualität prüfen

#### Problem: "Overlay wird nicht angezeigt"

**Checkliste:**
1. Overlay in Konfiguration aktiviert?
2. Chromium installiert?
   ```bash
   which chromium-browser
   ```
3. Scoreboard-URL erreichbar?
   ```bash
   curl http://localhost/locations/xxx/scoreboard_overlay?table_id=1
   ```
4. Xvfb läuft?
   ```bash
   ps aux | grep Xvfb
   ```

---

## 🔄 Automatischer Neustart

Der Systemd-Service startet automatisch neu bei:
- FFmpeg-Absturz
- Netzwerk-Problemen
- Raspberry Pi Neustart (optional)

**Automatischer Start nach Reboot aktivieren:**
```bash
ssh pi@192.168.1.100
sudo systemctl enable carambus-stream@1.service
```

**Automatischer Neustart deaktivieren:**
```bash
sudo systemctl disable carambus-stream@1.service
```

**Restart-Limit:**
- Maximal 5 Neustarts innerhalb von 5 Minuten
- Danach: Service gibt auf → Health-Check zeigt Fehler

---

## 📊 Optimierung

### CPU-Last reduzieren

**Hardware-Encoding nutzen:**
- Raspi 4 hat Hardware-H.264-Encoder
- Wird automatisch verwendet (`h264_v4l2m2m`)
- Deutlich effizienter als Software-Encoding

**CPU-Limit setzen:**
```bash
# In systemd service (bereits konfiguriert)
CPUQuota=80%
```

### Bildqualität verbessern

**Kamera-Positionierung:**
- Höhe: ~2-3m über Tisch
- Winkel: Leicht schräg von oben
- Beleuchtung: Gleichmäßig, keine direkten Reflektionen

**FFmpeg-Parameter optimieren:**
```bash
# In /etc/carambus/stream-table-1.conf
VIDEO_BITRATE=2500  # Höhere Qualität
CAMERA_FPS=60       # Flüssigere Bewegungen
```

### Bandbreite sparen

**Niedrigere Auflösung:**
- Nicht empfohlen für Hauptstream
- OK für Test-Streams oder bei sehr schwachem Upload

**Adaptive Bitrate:**
- YouTube passt automatisch an
- Client-seitig, nicht Server-seitig

---

## 🔐 Sicherheit

### SSH-Passwörter

**Empfehlung:** SSH-Keys statt Passwörter verwenden

```bash
# Auf Location-Server
ssh-keygen -t ed25519 -C "carambus-streaming"

# Public Key auf Raspi kopieren
ssh-copy-id pi@192.168.1.100

# Passwort-Login deaktivieren (optional)
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
sudo systemctl restart sshd
```

### Stream-Keys schützen

- **Niemals** in Git committen
- Environment-Variablen nutzen (bereits implementiert)
- Verschlüsselt in Rails Credentials (bereits implementiert)
- Bei Leak: Sofort in YouTube Studio invalidieren

---

## 📈 Skalierung

### Mehrere Tische parallel

**Netzwerk-Planung:**
```
1 Stream:  ~2.5 Mbit/s
2 Streams: ~5 Mbit/s
4 Streams: ~10 Mbit/s
8 Streams: ~20 Mbit/s
```

**Pro Tisch:**
- Eigener Scoreboard-Raspi
- Eigene USB-Kamera
- Eigener YouTube-Stream-Key
- Unabhängige Steuerung

### Load-Balancing

- Jeder Raspi streamt nur seinen eigenen Tisch
- Keine zentrale Last auf Location-Server
- Horizontal skalierbar

---

## 🆘 Support

### Logs sammeln

```bash
# Auf Scoreboard-Raspi
ssh pi@192.168.1.100

# Service-Logs
sudo journalctl -u carambus-stream@1.service --no-pager > stream.log

# System-Info
uname -a >> stream.log
free -h >> stream.log
df -h >> stream.log

# Kamera-Info
v4l2-ctl --device=/dev/video0 --all >> stream.log

# Netzwerk-Test
ping -c 10 a.rtmp.youtube.com >> stream.log
```

### Hilfreich für Support

- Log-Dateien (siehe oben)
- Screenshot aus Admin-Interface
- YouTube-Channel-URL
- Netzwerk-Topologie

---

## 📚 Weiterführende Links

- [FFmpeg H.264 Streaming Guide](https://trac.ffmpeg.org/wiki/EncodingForStreamingSites)
- [YouTube Live Streaming API](https://developers.google.com/youtube/v3/live/getting-started)
- [Raspberry Pi Camera Documentation](https://www.raspberrypi.com/documentation/accessories/camera.html)
- [V4L2 User Guide](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html)

---

## ✅ Quick Reference

### Wichtigste Befehle

```bash
# Setup
rake streaming:setup[192.168.1.100]
rake streaming:test[192.168.1.100]

# Deployment
rake streaming:deploy[TABLE_ID]
rake streaming:deploy_all

# Monitoring
rake streaming:status

# Manuell (auf Raspi)
sudo systemctl start carambus-stream@1.service
sudo systemctl stop carambus-stream@1.service
sudo systemctl status carambus-stream@1.service
sudo journalctl -u carambus-stream@1.service -f
```

### Admin-URLs

```
Stream-Verwaltung:  /admin/stream_configurations
Overlay-Vorschau:   /locations/:md5/scoreboard_overlay?table_id=1
```

### Dateien auf Raspi

```
Script:         /usr/local/bin/carambus-stream.sh
Service:        /etc/systemd/system/carambus-stream@.service
Config:         /etc/carambus/stream-table-1.conf
Logs:           /var/log/carambus/stream-table-1.log
Overlay-Image:  /tmp/carambus-overlay-table-1.png
```

---

**Version**: 1.0  
**Datum**: Dezember 2024  
**Autor**: Carambus Development Team




