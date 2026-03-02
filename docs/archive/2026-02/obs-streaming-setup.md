# OBS Streaming Setup - Raspberry Pi → MacBook Pro

## 🎯 Ziel
Der Raspberry Pi streamt die Kamera an OBS auf dem MacBook Pro. OBS kann dann den Stream weiter zu YouTube senden oder lokal aufzeichnen.

## 📋 Voraussetzungen
- ✅ OBS Studio installiert auf MacBook Pro (`/Applications/OBS.app`)
- ✅ Raspberry Pi mit Kamera (192.168.2.217)
- ✅ Stream-Konfiguration erstellt (Tisch 7)

## 🔧 Setup-Optionen

### Option 1: RTMP-Server auf MacBook (Empfohlen)

#### Schritt 1: RTMP-Server installieren

**Mit Docker (einfachste Lösung):**

1. **Docker Desktop starten** (falls nicht läuft):
   - Öffne Docker Desktop App
   - Warte bis Docker läuft (Icon in Menüleiste)

2. **RTMP-Server starten:**
```bash
# RTMP-Server mit Docker starten
docker run -d \
  --name rtmp-server \
  -p 1935:1935 \
  -p 8080:8080 \
  alfg/nginx-rtmp

# Server läuft jetzt auf:
# RTMP: rtmp://192.168.2.1:1935/live
# HTTP: http://localhost:8080 (Status-Seite)

# Prüfen ob Server läuft:
curl http://localhost:8080/stat
```

**Ohne Docker (Homebrew):**
```bash
# Nginx mit RTMP-Modul installieren
brew tap denji/nginx
brew install nginx-full --with-rtmp-module

# Konfiguration erstellen (siehe unten)
```

#### Schritt 2: Stream-Konfiguration

Die Konfiguration ist bereits gesetzt:
- **RTMP URL:** `rtmp://192.168.2.1:1935/live`
- **Stream Key:** `stream_key_123`

#### Schritt 3: OBS konfigurieren

1. **OBS öffnen**
2. **Media Source hinzufügen:**
   - Rechtsklick auf "Sources" → "Add" → "Media Source"
   - Name: "Raspberry Pi Camera"
   - **Input:** `rtmp://192.168.2.1:1935/live/stream_key_123`
   - ✅ "Restart playback when source becomes active"
   - ✅ "Close file when inactive"

3. **Stream starten:**
   - Im Dashboard: "Start" klicken
   - Der Raspberry Pi sendet jetzt an OBS

### Option 2: Direkt zu YouTube (Alternative)

Falls kein RTMP-Server gewünscht ist, kann der Raspberry Pi direkt zu YouTube streamen:

1. YouTube Stream Key in Admin-Interface eintragen
2. Stream Destination auf "youtube" ändern
3. OBS parallel für Overlays/Produktion verwenden

## 🧪 Testen

### 1. RTMP-Server starten (wenn Option 1)
```bash
# Docker-Version
docker start rtmp-server

# Prüfen ob Server läuft
curl http://localhost:8080/stat
```

### 2. Stream vom Raspberry Pi starten
```bash
# Via Dashboard UI oder:
cd /Users/gullrich/carambus/carambus_bcw
rails runner "StreamConfiguration.find_by(table_id: 3).start_streaming"
```

### 3. In OBS prüfen
- Media Source sollte Video anzeigen
- Falls nicht: Logs in OBS prüfen (View → Log Files)

## 📊 Aktuelle Konfiguration

- **Table:** Tisch 7 (ID: 3)
- **Raspberry Pi:** 192.168.2.217
- **MacBook IP:** 192.168.2.1
- **RTMP URL:** `rtmp://192.168.2.1:1935/live/stream_key_123`
- **Kamera:** 640x480@30fps (MJPEG)

## 🔍 Troubleshooting

### Problem: "Connection refused" in FFmpeg-Logs
**Lösung:** RTMP-Server auf MacBook starten (siehe Option 1)

### Problem: OBS zeigt kein Video
**Lösung:**
1. Prüfe ob RTMP-Server läuft: `curl http://localhost:8080/stat`
2. Prüfe Firewall auf MacBook (Port 1935 muss offen sein)
3. Prüfe OBS-Logs: View → Log Files

### Problem: Stream ist verzögert
**Normal:** RTMP hat typisch 2-5 Sekunden Latenz. Für niedrigere Latenz: SRT-Protokoll verwenden (erfordert andere Konfiguration)

## 📝 Nächste Schritte

1. RTMP-Server auf MacBook starten
2. Stream vom Raspberry Pi starten
3. In OBS Media Source hinzufügen
4. Testen und dann zu YouTube streamen (via OBS)

