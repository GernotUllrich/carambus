# YouTube Live Streaming - Setup & Betrieb

## 📋 Übersicht

Das Carambus-System unterstützt Live-Streaming von Billard-Spielen. Dabei werden die bereits vorhandenen Scoreboard-Raspberry-Pis genutzt, um kostengünstig jeden Tisch einzeln zu streamen. Als Stream-Ziel (`stream_destination`) stehen drei Optionen zur Verfügung: **`youtube`** (direkt zu YouTube), **`local`** (lokaler RTMP-Server, z.B. für OBS-Integration) und **`custom`** (eigener RTMP-Endpunkt). Diese Anleitung beschreibt überwiegend den YouTube-Weg.

### Architektur

```
┌───────────────────────────────────────────────────────┐
│  Location-Server (Carambus, Port <webserver_port>)    │
│   /locations/<md5>/scoreboard_text?table_id=<ID>      │
└───────────────────────────▲───────────────────────────┘
                            │ curl, jede Sekunde
┌───────────────────────────┴───────────────────────────┐
│  Scoreboard-Raspi 4 (pro Tisch)                       │
│                                                       │
│  Display :0 → Chromium-Kiosk → Scoreboard             │
│  (Dienst scoreboard-kiosk, unabhängig vom Stream)     │
│                                                       │
│  carambus-stream@<TABLE_ID>.service                   │
│   USB-Kamera /dev/video0 ──┐                          │
│   Overlay-Text (Datei) ────┴→ FFmpeg: drawtext        │
│                               + libx264 → RTMP-Ziel   │
└───────────────────────────────────────────────────────┘
```

Das Overlay ist ein **Text**, den FFmpeg per `drawtext` unten links ins Kamerabild schreibt. Den Text
holt `carambus-stream.sh` jede Sekunde vom Location-Server (`bin/carambus-stream.sh`, Overlay-Zweig).
Ein Browser rendert dabei nichts: `streaming:setup` installiert zwar Xvfb und Chromium, der
Streaming-Pfad nutzt beide nicht. Der Chromium-Kiosk auf Display :0 ist das normale Scoreboard.

---

## 🛠️ Hardware-Anforderungen

### Pro gestreamtem Tisch

1. **USB-Webcam: Logitech C922** (~80-90€)
   - Standard-Konfiguration: 640x360 @ 30 fps (siehe [Kamera-Einstellungen](#3-kamera-einstellungen))
   - Alternativ: Logitech C920 (~60-70€)
   - USB 2.0/3.0 Anschluss

2. **Raspberry Pi 4** (bereits vorhanden als Scoreboard)
   - Minimum 2GB RAM (4GB empfohlen)
   - Betriebssystem: Raspberry Pi OS (Bullseye oder neuer)

3. **Kamera-Montage**
   - Stativ oder Wandhalterung
   - USB-Verlängerungskabel (falls nötig)
   - Positionierung: Über dem Tisch, Blick auf die Spielfläche

### Netzwerk-Anforderungen

- **Upload-Bandbreite**: etwa Video- plus Audio-Bitrate je Stream, mit Spitzen bis Video-Bitrate + 500 kbit/s
  (FFmpeg `-maxrate`). Bei den Standardwerten (1000 + 128 kbit/s) also rund 1,1–1,6 Mbit/s pro Stream
- Beispiel: 4 parallele Streams mit Standardwerten = ~5-7 Mbit/s Upload nötig
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

Alle Befehle dieses Abschnitts laufen auf dem **Location-Server**, im Deploy-Verzeichnis des Szenarios.
Die Streaming-Tasks brauchen dessen Datenbank (`StreamConfiguration` existiert nur auf lokalen Servern);
ein Entwickler-Checkout reicht nicht.

### 1. Raspberry Pi vorbereiten

**SSH-Zugang.** Start, Stopp und Health-Check im Admin-Interface laufen als Job im Carambus-Dienst
(`puma-<basename>`, Benutzer `www-data`). Der Job verbindet sich per SSH mit dem Scoreboard-Pi und nimmt:

1. `RASPI_SSH_PASSWORD`, falls in der **Umgebung des Dienstes** gesetzt,
2. sonst die Schlüssel aus `RASPI_SSH_KEYS` (kommagetrennte Pfade),
3. sonst `~/.ssh/id_rsa`, `id_ed25519`, `id_ecdsa` oder `id_dsa` des Dienstbenutzers.

Ein `export` in der Shell erreicht den Dienst nicht, er liest nur `/etc/<basename>.env`
(`EnvironmentFile=` in `templates/puma/puma.service.erb`). Der übliche Weg ist deshalb ein Schlüssel für
`www-data` auf dem Location-Server, dessen öffentlicher Teil auf dem Scoreboard-Pi hinterlegt ist:

```bash
# Auf dem Location-Server, als www-data
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "carambus-streaming"
cat ~/.ssh/id_ed25519.pub
# Diese Zeile auf dem Scoreboard-Pi in ~/.ssh/authorized_keys des SSH-Benutzers eintragen
```

Ist der Scoreboard-Pi zugleich der Server, gilt dasselbe: Der Job verbindet sich dann per SSH mit sich selbst.

**SSH-Benutzer und Port** kommen aus der Szenario-Config (`raspberry_pi_client`). Per Ansible eingerichtete
Pis nehmen SSH nur als `www-data` auf Port 8910 an (siehe [Raspberry Pi Quickstart](raspberry-pi-quickstart.md)).
Die Streaming-Tasks nehmen ohne Angabe `pi` und Port 22 an, deshalb:

```bash
cd /var/www/<basename>/current
export RASPI_SSH_USER=www-data
export RASPI_SSH_PORT=8910

# Setup auf dem Scoreboard-Raspi ausführen
RAILS_ENV=production bundle exec rake "streaming:setup[<IP des Scoreboard-Pis>]"
```

Das Setup installiert:
- FFmpeg (Video-Encoding), v4l-utils (Kamera-Tools), curl
- Xvfb, Chromium, ImageMagick, netcat (werden installiert, vom Streaming-Pfad derzeit nicht genutzt)
- `/usr/local/bin/carambus-stream.sh` und die systemd-Vorlage `carambus-stream@.service`
- `/usr/local/bin/carambus-overlay-updater.sh` und die Vorlage `carambus-overlay-updater@.service`
- die Verzeichnisse `/etc/carambus` und `/var/log/carambus`

!!! warning "Die Unit läuft als Benutzer `pi`"
    `bin/carambus-stream.service` setzt fest `User=pi` und `Group=pi`. Gibt es auf dem Scoreboard-Pi keinen
    Benutzer `pi`, verweigert systemd den Start des Dienstes. Das betrifft Pis, deren Imager-Benutzer anders
    heißt.

### 2. Installation testen

```bash
RAILS_ENV=production bundle exec rake "streaming:test[<IP des Scoreboard-Pis>]"
```

Alle Tests sollten mit ✅ bestanden werden.

---

## 📝 Konfiguration im Admin-Interface

### 1. Stream-Konfiguration erstellen

1. Carambus Admin-Interface öffnen
2. Admin-Navigation → **Stream-Konfigurationen** (Seite „YouTube Live Streaming“, `/admin/stream_configurations`)
3. **Neue Stream-Konfiguration** klicken

### 2. Basis-Einstellungen

**Tisch:**
- Tisch wählen (die Auswahl ist nach Location gruppiert; die Location wird aus dem Tisch übernommen)

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

**Standardwerte einer neuen Konfiguration** (seit Migration `20251231132304` auf Pi-4-Leistung gesenkt):
```
Gerät:      /dev/video0
Breite:     640
Höhe:       360
Framerate:  30 fps
```

Das ist der empfohlene Start. 1280x720 @ 30 fps nur, wenn CPU und Upload Reserve haben; 60 fps nicht
empfohlen. Kodiert wird in Software (siehe [Optimierung](#cpu-last-reduzieren)).

!!! note "Manuelle Kamera- und Perspektivwerte"
    Die Felder „Manuelle Kameraeinstellungen“ (Fokus, Belichtung, Helligkeit, Kontrast, Sättigung) und
    „Trapezkorrektur“ werden beim Speichern derzeit **nicht übernommen**: Sie fehlen in der Parameterliste
    des Controllers. Setzen lassen sie sich per `rake "streaming:camera_save[<TABLE_ID>]"` (liest die Werte
    vom Pi) bzw. `rake "streaming:perspective_set[<TABLE_ID>,<koordinaten>]"`.

### 4. Overlay-Einstellungen

```
Overlay aktiviert:  ✓
```

Die Felder **Position** und **Höhe** sind derzeit ohne Wirkung: Der Text steht immer unten links, die
Schriftgröße richtet sich nach der Kamerahöhe (16 px bei 360p, 24 px ab 720p, 32 px ab 1080p).

Das Overlay zeigt:
- Tischnummer und „LIVE“
- beide Spieler (Vorname) mit Spielstand, laufende Aufnahme in Klammern, der Spieler am Stoß markiert
- Turniername (falls vorhanden)
- ohne laufendes Spiel: Name der Location und „Kein Spiel“

!!! warning "Pflichtschritt: `STREAMING_SERVER_URL`"
    Der Pi holt den Text von der Adresse in `SERVER_URL` seiner Konfigurationsdatei. Diese schreibt der
    Job als `STREAMING_SERVER_URL` aus der Umgebung des Carambus-Dienstes, sonst `http://localhost:3131`
    (`app/jobs/stream_control_job.rb`). Der Standard stimmt nur, wenn der Scoreboard-Pi selbst der Server
    ist und dieser auf Port 3131 lauscht. In jedem anderen Fall holt der Pi den Text von sich selbst, und
    das Overlay bleibt bei „Loading...“.

    ```bash
    # Auf dem Location-Server
    sudo nano /etc/<basename>.env
    #   STREAMING_SERVER_URL=http://<IP des Location-Servers>:<webserver_port>
    sudo systemctl restart puma-<basename>
    ```

    Wirksam wird die Adresse beim nächsten Start des Streams, weil der Start die Konfiguration neu schreibt.

!!! warning "nginx-Bot-Block"
    Ist für das Szenario der nginx-Bot-Block aktiv (`bot_block_enabled`, Standard `true`), weist nginx den
    Abruf des Pis mit 403 ab: `curl` meldet sich als `curl/…`, und ausgenommen ist nur `/versions/`
    (`templates/nginx/carambus_bot_block.conf`). Auch dann bleibt das Overlay bei „Loading...“.
    Siehe [NGINX Bot-Block](nginx-bot-block.md).

### 5. Stream-Qualität

**Standardwerte:**
```
Video-Bitrate:  1000 kbit/s  (640x360 @ 30 fps)
Audio-Bitrate:  128 kbit/s
```

**Anpassungen je nach Upload:**
- 1280x720 @ 30 fps: etwa 2000 kbit/s
- Weniger Bandbreite: Bitrate senken, z.B. 800 kbit/s

### 6. Netzwerk

```
Raspi IP:   <IP des Scoreboard-Pis>  (wird automatisch vom Tisch übernommen)
SSH-User:   www-data                 (Formular-Standard: pi)
SSH-Port:   8910                     (Formular-Standard: 22)
```

Benutzer und Port müssen zum Pi passen, bei per Ansible eingerichteten Pis `www-data` und 8910. Prüfen
lässt sich der Zugang, sobald die Konfiguration gespeichert ist:

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake "streaming:ssh_test[<TABLE_ID>]"
```

Der Task zeigt den öffentlichen Schlüssel des Servers und sagt, ob er auf dem Pi hinterlegt ist. Scheitert
der Test, scheitert auch der Start-Knopf (Fehlermeldung „Authentication failed“).

### 7. Speichern & Deployen

1. **Speichern** klicken: Die Konfiguration steht jetzt nur in der Datenbank
2. Auf den Pi kommt sie beim ersten **Start**, per **Alle deployen** oder mit
   `rake "streaming:deploy[<TABLE_ID>]"`. Vor einem manuellen `systemctl start` muss sie deployt sein
3. Status prüfen: Sollte auf "Inactive" stehen

---

## ▶️ Stream starten

### Via Admin-Interface (empfohlen)

1. `/admin/stream_configurations` öffnen
2. Gewünschten Stream finden
3. **Start** klicken: Der Job schreibt die Konfiguration neu auf den Pi und startet den Dienst
4. Status wechselt auf "Starting" → "Active"
5. Bei Fehler: Error-Message wird angezeigt

**Neustart** (🔄) und **Speichern bei laufendem Stream** stoppen den Stream derzeit nur, sie starten ihn nicht
wieder (`StreamConfiguration#restart_streaming`). Danach **Start** klicken.

### Via SSH (manuell)

`<TABLE_ID>` ist die Datenbank-ID des Tischs (`Table.id`), nicht die Nummer aus „Tisch 7“. Die
Konfiguration muss vorher deployt sein (siehe oben).

```bash
ssh -p 8910 www-data@<IP des Scoreboard-Pis>
sudo systemctl start carambus-stream@<TABLE_ID>.service

# Status prüfen
sudo systemctl status carambus-stream@<TABLE_ID>.service

# Logs anzeigen (FFmpeg und Skript schreiben in Dateien, nicht ins Journal)
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
```

### Via Rake Task

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake streaming:status  # Alle Streams anzeigen
```

Wer per `rake streaming:deploy` deployt, sollte die Umgebung des Dienstes in die Shell laden, sonst errechnet
der Task die Server-Adresse selbst (auf einem lokalen Server `http://localhost:<port>`) und nutzt
`RASPI_SSH_PASSWORD` nicht:

```bash
set -a; eval "$(sudo cat /etc/<basename>.env)"; set +a
```

---

## 🔍 Monitoring & Troubleshooting

### Stream-Status prüfen

**Im Admin-Interface:**
- Live-Status-Anzeige
- Uptime-Counter
- Error-Messages
- **Health-Check** (❤️) klicken für aktuelle Diagnose; bei geöffneter Seite läuft er zusätzlich alle 30 Sekunden

**Via Rake Task:**
```bash
RAILS_ENV=production bundle exec rake streaming:status
```

**Via SSH:**
```bash
ssh -p 8910 www-data@<IP des Scoreboard-Pis>

# Service-Status (Start, Stopp, Neustarts)
sudo systemctl status carambus-stream@<TABLE_ID>.service

# Live-Logs von Skript und FFmpeg
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
tail -f /var/log/carambus/stream-table-<TABLE_ID>-error.log

# FFmpeg-Prozess prüfen
ps aux | grep ffmpeg

# Kamera prüfen
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

`journalctl -u carambus-stream@<TABLE_ID>` zeigt nur, wann systemd den Dienst gestartet oder gestoppt hat.

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
   tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
   ```

#### Problem: "Stream läuft, aber ruckelt"

**Ursachen:**
- Upload-Bandbreite zu niedrig
- Zu hohe Bitrate eingestellt
- CPU-Überlastung des Raspis

**Lösungen:**
1. Bitrate reduzieren (z.B. auf 800k)
2. Auflösung oder Framerate reduzieren (zurück auf 640x360 @ 30 fps)
3. Andere Prozesse auf Raspi beenden
4. Netzwerk-Qualität prüfen

#### Problem: "Overlay wird nicht angezeigt"

**Checkliste:**
1. Overlay in Konfiguration aktiviert?
2. Zeigt `SERVER_URL` auf den Location-Server?
   ```bash
   grep SERVER_URL /etc/carambus/stream-table-<TABLE_ID>.conf
   ```
   Steht dort `http://localhost:3131`, obwohl der Server ein anderer Rechner ist: `STREAMING_SERVER_URL`
   setzen (siehe [Overlay-Einstellungen](#4-overlay-einstellungen)) und den Stream neu starten.
3. Liefert der Endpunkt Text, so wie der Pi ihn abruft?
   ```bash
   curl -i "<SERVER_URL>/locations/<LOCATION_MD5>/scoreboard_text?table_id=<TABLE_ID>"
   ```
   `403 Forbidden` bedeutet: Der nginx-Bot-Block weist `curl` ab.
4. Die Textdatei selbst liegt im privaten `/tmp` des Dienstes (`PrivateTmp=true`) und ist aus einer
   SSH-Shell unter `/tmp` nicht zu sehen.

---

## 🔄 Automatischer Neustart

Der Systemd-Service startet automatisch neu bei:
- FFmpeg-Absturz
- Netzwerk-Problemen
- Raspberry Pi Neustart (optional)

**Automatischer Start nach Reboot aktivieren:**
```bash
ssh -p 8910 www-data@<IP des Scoreboard-Pis>
sudo systemctl enable carambus-stream@<TABLE_ID>.service
```

**Automatischer Neustart deaktivieren:**
```bash
sudo systemctl disable carambus-stream@<TABLE_ID>.service
```

**Restart-Limit:**
- Maximal 5 Neustarts innerhalb von 5 Minuten
- Danach: Service gibt auf → Health-Check zeigt Fehler

---

## 📊 Optimierung

### CPU-Last reduzieren

**Software-Encoding:**
- Kodiert wird mit `libx264` (Preset `veryfast`), nicht mit dem Hardware-Encoder des Pi 4
- Grund: Mit `h264_v4l2m2m` zeigte YouTube nur das Logo, nie das Bild (Kommentar in `bin/carambus-stream.sh`)
- Die CPU-Last steuert man deshalb über Auflösung, Framerate und Bitrate

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

**Qualität anpassen:**
- Bitrate, Auflösung und Framerate im Admin-Interface ändern
- `/etc/carambus/stream-table-<TABLE_ID>.conf` nicht von Hand bearbeiten: Jeder Start schreibt die Datei neu

### Bandbreite sparen

**Niedrigere Bitrate:**
- Die Standardauflösung 640x360 ist bereits niedrig
- Bei sehr schwachem Upload die Video-Bitrate senken

**Adaptive Bitrate:**
- YouTube passt automatisch an
- Client-seitig, nicht Server-seitig

---

## 🔐 Sicherheit

### SSH-Zugang

- Schlüssel statt Passwort: siehe [Raspberry Pi vorbereiten](#1-raspberry-pi-vorbereiten)
- Soll der Dienst doch per Passwort verbinden, gehört `RASPI_SSH_PASSWORD` in `/etc/<basename>.env`
  (Modus 600, Eigentümer root), nicht in eine Shell-Datei
- Per Ansible eingerichtete Pis nehmen SSH nur auf Port 8910 an

### Stream-Keys schützen

- **Niemals** in Git committen
- In der Datenbank verschlüsselt (Active Record Encryption, `encrypts :youtube_stream_key`)
- Auf dem Scoreboard-Pi steht der Key im Klartext in `/etc/carambus/stream-table-<TABLE_ID>.conf` (Teil von
  `RTMP_URL`; die Datei hat Modus 644 und ist für jeden Benutzer des Pis lesbar). Den Pi entsprechend absichern
- Bei Leak: Sofort in YouTube Studio invalidieren

---

## 📈 Skalierung

### Mehrere Tische parallel

**Netzwerk-Planung (Standardwerte 1000 + 128 kbit/s):**
```
1 Stream:  ~1,5 Mbit/s
2 Streams: ~3 Mbit/s
4 Streams: ~6 Mbit/s
8 Streams: ~12 Mbit/s
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
ssh -p 8910 www-data@<IP des Scoreboard-Pis>

# Stream-Logs
cat /var/log/carambus/stream-table-<TABLE_ID>.log > stream.log
cat /var/log/carambus/stream-table-<TABLE_ID>-error.log >> stream.log
sudo systemctl status carambus-stream@<TABLE_ID>.service --no-pager >> stream.log

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

### Interne Links

- [Quickstart](streaming-quickstart.md)
- [Entwickler-Architektur](../developers/streaming-architecture.md)
- [Server-Architektur](server-architecture.md)
- [Scoreboard-Kiosk](scoreboard-autostart.md)

### Externe Ressourcen

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

### Wichtigste Befehle

```bash
# Auf dem Location-Server: cd /var/www/<basename>/current, RAILS_ENV=production bundle exec …
# Setup
rake "streaming:setup[<IP>]"
rake "streaming:test[<IP>]"
rake "streaming:ssh_test[<TABLE_ID>]"

# Deployment
rake "streaming:deploy[<TABLE_ID>]"
rake streaming:deploy_all

# Monitoring
rake streaming:status

# Manuell (auf Raspi)
sudo systemctl start carambus-stream@<TABLE_ID>.service
sudo systemctl stop carambus-stream@<TABLE_ID>.service
sudo systemctl status carambus-stream@<TABLE_ID>.service
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
```

### Admin-URLs

```
Stream-Verwaltung:  /admin/stream_configurations
Overlay-Text (Pi):  /locations/:md5/scoreboard_text?table_id=<TABLE_ID>
Overlay (Browser):  /locations/:md5/scoreboard_overlay?table_id=<TABLE_ID>   (für OBS)
```

### Dateien auf Raspi

```
Script:         /usr/local/bin/carambus-stream.sh
Service:        /etc/systemd/system/carambus-stream@.service
Config:         /etc/carambus/stream-table-<TABLE_ID>.conf
Logs:           /var/log/carambus/stream-table-<TABLE_ID>.log
                /var/log/carambus/stream-table-<TABLE_ID>-error.log
Overlay-Text:   /tmp/carambus-overlay-text-table-<TABLE_ID>.txt  (im privaten /tmp des Dienstes)
```

---

**Version**: 1.1  
**Datum**: September 2026 (Abgleich mit dem Code, Phase 16)  
**Autor**: Carambus Development Team
