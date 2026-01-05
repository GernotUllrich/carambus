# OBS Studio Streaming Setup für MacBook/iPhone

## Übersicht

Anstatt Raspberry Pis als Streaming-Einheiten zu verwenden, kann das bereits vorhandene MacBook Pro (Turnierleitung) oder iPhones für professionelles Streaming mit mehreren Ansichten genutzt werden.

## Vorteile gegenüber Raspberry Pi

### MacBook Pro + OBS
- ✅ **Mehrere Kameras gleichzeitig** (USB, iPhone, Webcam)
- ✅ **Professionelle Szenen-Wechsel** (Tischansicht, Nahaufnahme, Multi-Table)
- ✅ **Einfaches Overlay-Management** (Browser-Source in OBS)
- ✅ **Höhere Qualität** (bessere Encoder, höhere Auflösung)
- ✅ **Flexiblere Layouts** (Picture-in-Picture, Splitscreen)
- ✅ **Bereits vorhanden** (keine zusätzliche Hardware)

### iPhone
- ✅ **Exzellente Kamera-Qualität** (besser als Logitech C922)
- ✅ **Mobil und flexibel** (einfach positionierbar)
- ✅ **Gute Low-Light-Performance**
- ✅ **Bereits vorhanden**

## Hardware-Anforderungen

### Minimal (1 Stream)
- MacBook Pro (2017+, i5 oder besser)
- 8GB RAM (16GB empfohlen)
- Stabile Internet-Verbindung (5 Mbit/s Upload minimum)

### Erweitert (Multi-Kamera)
- Wie oben, plus:
- 1-2 iPhones (iPhone X oder neuer für beste Qualität)
- USB-Kameras (optional, für zusätzliche Ansichten)
- USB-Hub (powered, für mehrere Kameras)

## Software-Installation

### 1. OBS Studio installieren

```bash
# Via Homebrew
brew install --cask obs

# Oder Download von https://obsproject.com/
```

### 2. OBS Plugins (optional)

```bash
# Advanced Scene Switcher
brew install --cask obs-advanced-scene-switcher

# Virtual Camera (für Zoom/Meet)
# Bereits in OBS Studio 26+ enthalten
```

### 3. iPhone als Kamera (macOS Ventura+)

**Continuity Camera** ist bereits in macOS integriert:
1. iPhone und Mac mit gleichem Apple-ID anmelden
2. Bluetooth und WLAN aktivieren
3. iPhone in Nähe von Mac platzieren
4. In OBS: iPhone erscheint als Videoquelle

**Alternative: USB-Verbindung**
```bash
# NDI HX Camera App auf iPhone installieren (gratis)
# Oder: Epoccam, Camo Studio (kostenpflichtig, bessere Qualität)
```

## OBS Konfiguration

### Ausgabe-Einstellungen

**Datei → Einstellungen → Ausgabe**

```
Modus: Erweitert
Encoder: Apple VT H264 Hardware-Encoder (empfohlen)
        oder x264 (höhere CPU-Last)

Bitrate: 4500 kbps (1080p30)
        6000 kbps (1080p60)
        2500 kbps (720p30)

Keyframe-Intervall: 2 Sekunden
CPU-Voreinstellung: veryfast (für Software-Encoder)
Profil: high
Tune: zerolatency
```

### Video-Einstellungen

**Datei → Einstellungen → Video**

```
Basis (Leinwand) Auflösung: 1920x1080
Ausgabe (skaliert): 1920x1080 (oder 1280x720 für niedrigere Bandbreite)
FPS: 30 (empfohlen für Billard)
     60 (bei ausreichend Upload)
```

### Stream-Einstellungen

**Datei → Einstellungen → Stream**

```
Dienst: YouTube - RTMP
Server: Primary YouTube ingest server
Stream-Schlüssel: [von YouTube Live Dashboard]
```

**YouTube Stream-Key finden:**
1. YouTube Studio → Livestream erstellen
2. "Stream-Einstellungen" → "Stream-Schlüssel" kopieren

## Szenen-Setup

### Szene 1: Einzeltisch (Hauptansicht)

**Quellen:**
1. **Video Capture Device** → iPhone/USB-Kamera
   - Name: "Kamera Tisch 1"
   - Position: Vollbild
   
2. **Browser Source** → Carambus Overlay
   - URL: `http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=1`
   - Breite: 1920
   - Höhe: 200
   - Position: Unten (0, 880)
   - ✅ "Shutdown source when not visible" (Performance)
   - ✅ "Refresh browser when scene becomes active"

3. **Text (Optional)** → Turnier-Info
   - Text: "Deutscher Meister 2025 - Runde 3"
   - Position: Oben links
   - Schriftart: Arial Bold, 24px

### Szene 2: Multi-Table (4 Tische)

**Layout: 2x2 Grid**

**Quellen:**
1. **Gruppe: Tisch 1 (oben links)**
   - Video: iPhone 1
   - Browser: Overlay Table 1
   - Position: (0, 0) → (960x540)

2. **Gruppe: Tisch 2 (oben rechts)**
   - Video: iPhone 2
   - Browser: Overlay Table 2
   - Position: (960, 0) → (960x540)

3. **Gruppe: Tisch 3 (unten links)**
   - Video: USB-Kamera 1
   - Browser: Overlay Table 3
   - Position: (0, 540) → (960x540)

4. **Gruppe: Tisch 4 (unten rechts)**
   - Video: USB-Kamera 2
   - Browser: Overlay Table 4
   - Position: (960, 540) → (960x540)

**Overlay-URL für Multi-Table:**
```erb
<!-- In app/views/locations/scoreboard_overlay_multi.html.erb -->
<div class="grid grid-cols-2 gap-2 text-xs">
  <% [1, 2, 3, 4].each do |table_id| %>
    <div class="p-2 bg-gray-900/90 rounded">
      <%= render partial: 'scoreboard_mini', locals: { table_id: table_id } %>
    </div>
  <% end %>
</div>
```

### Szene 3: Nahaufnahme (Spieler-Fokus)

**Quellen:**
1. **Video Capture Device** → iPhone (Close-up)
   - Zoom auf Spieler-Gesicht/Haltung
   
2. **Browser Source** → Minimales Overlay
   - Nur aktueller Score
   - Position: Oben rechts (klein)

### Szene 4: Kommentar/Interview

**Quellen:**
1. **Video Capture Device** → MacBook Webcam
   - Kommentator/Moderator
   
2. **Video Capture Device** → Picture-in-Picture
   - Tisch-Ansicht (klein, Ecke)
   
3. **Browser Source** → Lower Third
   - Name des Kommentators
   - Aktueller Spielstand

## Overlay-Anpassungen für OBS

### Neue Controller-Action für OBS-Overlays

```ruby
# app/controllers/locations_controller.rb

def streaming_overlay_obs
  @table_id = params[:table_id]
  @table = Table.find(@table_id)
  @table_monitor = @table.table_monitor
  @game = @table_monitor&.current_game
  @layout_mode = params[:layout] || 'full'  # 'full', 'minimal', 'multi'
  
  render layout: 'streaming_overlay'
end
```

**Routes:**
```ruby
# config/routes.rb
get 'locations/:md5/streaming_overlay_obs', to: 'locations#streaming_overlay_obs'
```

### Layout-Modi

**1. Full (Standard)**
```
http://localhost:3000/locations/[MD5]/streaming_overlay_obs?table_id=1&layout=full
```
- Kompletter Scoreboard (200px Höhe)
- Spieler, Score, Durchschnitt, Höchste Serie

**2. Minimal (für Nahaufnahmen)**
```
http://localhost:3000/locations/[MD5]/streaming_overlay_obs?table_id=1&layout=minimal
```
- Nur Score (80px Höhe)
- Spielername + Punkte

**3. Multi (für 2x2 Grid)**
```
http://localhost:3000/locations/[MD5]/streaming_overlay_obs?layout=multi
```
- Alle Tische gleichzeitig
- Kompakte Darstellung

## iPhone Setup

### Option 1: Continuity Camera (macOS Ventura+)

**Voraussetzungen:**
- macOS Ventura (13.0) oder neuer
- iOS 16 oder neuer
- Gleiche Apple-ID auf Mac und iPhone

**Setup:**
1. iPhone mit Stativ/Halterung positionieren
2. iPhone entsperren (muss nicht offen sein)
3. OBS → Video Capture Device → iPhone auswählen
4. Fertig! 🎉

**Vorteile:**
- Kabellos (WLAN)
- Automatische Erkennung
- Gute Qualität

**Nachteile:**
- Höhere Latenz (~1-2 Sekunden)
- Batterieverbrauch (iPhone muss geladen werden)

### Option 2: USB-Verbindung (NDI HX)

**App installieren:**
1. "NDI HX Camera" im App Store (gratis)
2. iPhone per USB an MacBook anschließen
3. App öffnen, NDI aktivieren

**OBS Plugin:**
```bash
brew install --cask obs-ndi
```

**OBS-Einstellungen:**
- Tools → NDI Output Settings
- NDI Source → iPhone auswählen

**Vorteile:**
- Niedrige Latenz (<500ms)
- Keine Batterie-Probleme
- Bessere Qualität

**Nachteile:**
- USB-Kabel erforderlich
- Plugin-Installation

### Option 3: Larix Broadcaster (Eigenständig)

Wenn MacBook nicht verfügbar → iPhone kann direkt zu YouTube streamen:

**App installieren:**
1. "Larix Broadcaster" im App Store (gratis)
2. RTMP-Einstellungen konfigurieren
3. Browser-Overlay parallel anzeigen (kompliziert)

**Nicht empfohlen**, da:
- Kein natives Overlay-Compositing
- Schwierig, HTML-Overlay einzubinden
- Besser: iPhone als Kamera → MacBook/OBS → Stream

## Workflow während Turnier

### Vorbereitung (30 Min vor Start)

```bash
# 1. Rails-Server starten (falls noch nicht läuft)
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rails s -p 3000

# 2. Overlay-URLs testen
open http://localhost:3000/locations/[MD5]/streaming_overlay_obs?table_id=1

# 3. OBS starten
# 4. Kameras verbinden (iPhone, USB)
# 5. Stream-Test (privater YouTube-Stream)
```

### Während Turnier

**Szenen-Wechsel:**
- **Hotkeys definieren** (Datei → Einstellungen → Hotkeys)
  - F1: Szene "Tisch 1"
  - F2: Szene "Multi-Table"
  - F3: Szene "Nahaufnahme"
  - F4: Szene "Kommentar"

**Overlay-Updates:**
- Laufen automatisch via ActionCable
- Keine manuelle Aktion erforderlich

**Stream-Monitoring:**
- YouTube Studio → Livestream-Dashboard
- Zuschauerzahlen, Chat, Health-Status

### Nach Turnier

```bash
# 1. Stream beenden (OBS)
# 2. Video in YouTube Studio prüfen
# 3. Video archivieren/highlighten
# 4. OBS beenden
```

## Performance-Optimierung

### MacBook wird heiß

**Lösungen:**
1. Hardware-Encoder nutzen (Apple VT H264)
2. Auflösung reduzieren (720p statt 1080p)
3. FPS reduzieren (30 statt 60)
4. Externe Kühlung (Laptop-Lüfter)

### Latenz zu hoch

**Maßnahmen:**
1. USB statt WLAN für iPhone
2. Encoder: "zerolatency" Tune
3. Keyframe-Intervall: 1 Sekunde
4. Netzwerk-QoS (Gaming/Streaming priorisieren)

### Stream ruckelt

**Diagnose:**
OBS → Ansicht → Stats
- "Dropped Frames (Network)" → Upload zu langsam
- "Dropped Frames (Rendering)" → CPU überlastet
- "Dropped Frames (Encoding)" → Encoder überlastet

**Fixes:**
- Network: Bitrate reduzieren
- Rendering: Quellen reduzieren, Vorschau deaktivieren
- Encoding: Hardware-Encoder, niedrigere Auflösung

## Vergleich: Raspberry Pi vs. MacBook

| Aspekt | Raspberry Pi | MacBook + OBS |
|--------|--------------|---------------|
| **Hardware-Kosten** | 150€ pro Tisch | 0€ (bereits vorhanden) |
| **Setup-Zeit** | 2h pro Raspi | 30 Min einmalig |
| **Flexibilität** | 1 Tisch = 1 Stream | Mehrere Ansichten, Szenen |
| **Qualität** | 720p30 (Hardware-Limit) | 1080p60 möglich |
| **Kamera-Qualität** | Logitech C922 (gut) | iPhone (exzellent) |
| **Szenen-Wechsel** | Nicht möglich | Einfach (Hotkeys) |
| **Multi-Table** | Nicht möglich | 2x2 Grid easy |
| **Wartung** | Pro Raspi separat | Zentral |
| **Skalierung** | Linear (N Raspis) | 1 MacBook für 2-4 Tische |

**Empfehlung:**
- **Kleine Turniere (1-2 Tische):** MacBook + OBS + iPhone(s)
- **Große Turniere (8+ Tische):** Hybrid (MacBook für Hauptstream, Raspis für zusätzliche Tische)
- **Permanente Installation:** Raspberry Pi (unbeaufsichtigt)

## Erweiterte Features

### 1. Picture-in-Picture

**Spieler-Nahaufnahme während Hauptansicht:**
```
Szene: "Tisch 1 mit PiP"
- Quelle 1: USB-Kamera (Tisch, Vollbild)
- Quelle 2: iPhone (Spieler, 320x180, Ecke)
- Quelle 3: Browser (Overlay)
```

### 2. Lower Thirds

**Spieler-Info einblenden:**
```html
<!-- app/views/streaming/lower_third.html.erb -->
<div class="fixed bottom-20 left-10 bg-gradient-to-r from-blue-900/90 to-transparent pr-20 pl-6 py-4 rounded-r-full">
  <div class="text-2xl font-bold"><%= @player.name %></div>
  <div class="text-sm opacity-80">
    <%= @player.club %> | Ø <%= @player.current_average %>
  </div>
</div>
```

**OBS Browser Source:**
```
URL: http://localhost:3000/streaming/lower_third?player_id=123
Breite: 1920, Höhe: 1080
Transparenter Hintergrund: ✅
```

### 3. Turnier-Tabelle (Zwischenstand)

**Zwischen Spielen einblenden:**
```html
<!-- app/views/streaming/standings.html.erb -->
<div class="p-10 bg-gray-900/95 rounded-lg">
  <h1 class="text-4xl mb-6">Zwischenstand</h1>
  <table class="w-full text-2xl">
    <% @tournament.rankings.each do |player| %>
      <tr>
        <td><%= player.rank %></td>
        <td><%= player.name %></td>
        <td><%= player.points %></td>
      </tr>
    <% end %>
  </table>
</div>
```

### 4. Chat-Integration

**YouTube-Chat im Stream einblenden:**
- OBS → Browser Source
- URL: YouTube Live Chat Embed URL
- Position: Rechts (Sidebar)

## Automatisierung

### Stream-Auto-Start

```bash
#!/bin/bash
# bin/obs-auto-start.sh

# Rails-Server starten
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rails s -p 3000 -d

# Warten bis Server ready
sleep 10

# OBS mit Profil starten
open -a "OBS" --args --profile "Carambus Tournament" --collection "4 Tables" --startstreaming
```

### Szenen-Wechsel via Hotkeys/Script

**OBS WebSocket Plugin:**
```bash
brew install --cask obs-websocket
```

**Ruby-Client:**
```ruby
# lib/obs_control.rb
require 'obswebsocket'

client = OBSWebSocket::Client.new(host: 'localhost', port: 4455)
client.connect(password: ENV['OBS_PASSWORD'])

# Szene wechseln
client.set_current_scene(scene_name: 'Tisch 1')

# Quelle ein/ausblenden
client.set_source_visibility(source_name: 'Overlay Table 1', visible: true)
```

## Troubleshooting

### Overlay lädt nicht

```bash
# Browser-Cache in OBS leeren
# Rechtsklick auf Browser Source → "Refresh Cache"

# Oder URL testen im normalen Browser
open http://localhost:3000/locations/[MD5]/streaming_overlay_obs?table_id=1
```

### iPhone wird nicht erkannt

**Continuity Camera:**
1. Bluetooth/WLAN prüfen
2. Gleiche Apple-ID auf beiden Geräten
3. Handoff aktiviert (Systemeinstellungen → Allgemein)
4. iPhone neu starten

**USB/NDI:**
1. iPhone "diesem Computer vertrauen"
2. NDI App läuft im Vordergrund
3. OBS-Plugin installiert

### Stream ruckelt/bricht ab

**Diagnose:**
```bash
# Upload-Speed testen
speedtest-cli --simple

# OBS-Log anschauen
# Hilfe → Log-Dateien → Aktuelles Log anzeigen
```

**Häufige Ursachen:**
- Upload zu langsam (< 5 Mbit/s)
- CPU überlastet (> 80%)
- Falscher Encoder (Software statt Hardware)
- Zu hohe Bitrate

### Overlay zeigt alte Daten

**Fix:**
1. Scoreboard aktualisieren
2. Browser Source in OBS refreshen
3. ActionCable-Verbindung prüfen:
   ```bash
   rails c
   ActionCable.server.broadcast('table_monitor_channel', { test: true })
   ```

## Nächste Schritte

1. ✅ **OBS installieren und konfigurieren**
2. ✅ **Test-Stream mit 1 Tisch** (privater YouTube-Stream)
3. 🎨 **Overlays anpassen** (Layout, Farben)
4. 📱 **iPhone-Integration testen** (Continuity Camera)
5. 🎬 **Szenen erstellen** (Multi-Table, Nahaufnahme)
6. 🚀 **Live-Test bei Turnier** (mit Backup-Plan)

## Support & Ressourcen

**OBS Studio:**
- [Offizielle Dokumentation](https://obsproject.com/wiki/)
- [OBS Forums](https://obsproject.com/forum/)
- [YouTube Tutorials](https://www.youtube.com/results?search_query=obs+studio+tutorial)

**NDI:**
- [NDI HX Camera App](https://apps.apple.com/app/ndi-hx-camera/id1501247274)
- [OBS NDI Plugin](https://github.com/obs-ndi/obs-ndi)

**YouTube:**
- [Live Streaming Best Practices](https://support.google.com/youtube/answer/2853702)
- [Stream Settings](https://support.google.com/youtube/answer/2853702)

---

**Version:** 1.0  
**Datum:** Januar 2025  
**Status:** ✅ Ready for Testing

