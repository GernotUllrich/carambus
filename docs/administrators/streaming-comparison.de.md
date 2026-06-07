# Streaming-Optionen Vergleich: Raspberry Pi vs. MacBook/iPhone

## Übersicht

Das Carambus-System bietet verschiedene Streaming-Ansätze, die je nach Turniergröße, Budget und technischer Ausstattung unterschiedlich gut geeignet sind.

## Die drei Optionen

### Option 1: Raspberry Pi (Aktuell implementiert)

**Hardware pro Tisch:**
- Raspberry Pi 4 (bereits vorhanden als Scoreboard)
- USB-Webcam (Logitech C922 oder ähnlich)
- Kein zusätzlicher Computer notwendig

**Wie es funktioniert:**
```
Raspberry Pi (pro Tisch)
├─ Display :0 → Scoreboard (Chromium Kiosk)
├─ Display :1 → Overlay-Rendering (Xvfb + Chromium headless)
└─ FFmpeg → Camera + Overlay → YouTube RTMP
```

**Vorteile:**
- ✅ Vollautomatisch (kein manueller Eingriff nötig)
- ✅ Skaliert perfekt (N Tische = N unabhängige Streams)
- ✅ 24/7-Betrieb möglich
- ✅ Nutzt vorhandene Hardware (Scoreboard-Raspis)
- ✅ Kein zusätzliches Personal nötig

**Nachteile:**
- ⚠️ Fixe Kamera-Position pro Tisch
- ⚠️ Keine Szenen-Wechsel
- ⚠️ 720p60 Maximum (Hardware-Limit Raspi 4)
- ⚠️ Setup-Aufwand pro Raspi (~2h initial)

**Kosten:**
- Kamera: ~80€ pro Tisch
- Software: 0€ (Open Source)
- **Total: 80€ pro Tisch** (Raspi bereits vorhanden)

**Best für:**
- Permanente Installation
- Große Turniere (8+ Tische)
- Unbeaufsichtigter Betrieb
- Regelmäßiges Streaming

---

### Option 2: MacBook Pro + OBS (Neu!)

**Hardware:**
- MacBook Pro (bereits vorhanden bei Turnierleitung)
- 1-4 iPhones als Kameras (oft bereits vorhanden)
- Optional: USB-Kameras

**Wie es funktioniert:**
```
MacBook Pro
└─ OBS Studio
   ├─ Video: iPhone(s), USB-Kameras, MacBook-Webcam
   ├─ Overlay: Browser Source → Rails HTML/CSS
   ├─ Szenen: Tisch 1, Multi-Table, Nahaufnahme, Kommentar
   └─ Stream → YouTube RTMP
```

**Vorteile:**
- ✅ Professionelle Szenen (mehrere Ansichten)
- ✅ Flexibles Kamera-Positionieren
- ✅ Bessere Bildqualität (1080p60+, bessere Kameras)
- ✅ Multi-Table-View (2x2 Grid)
- ✅ Picture-in-Picture möglich
- ✅ Lower Thirds, Grafiken, Transitions
- ✅ Geringere Setup-Zeit (30 Min vs. 2h pro Raspi)
- ✅ Keine zusätzliche Hardware nötig

**Nachteile:**
- ⚠️ Benötigt Person am MacBook (Szenen-Wechsel)
- ⚠️ MacBook muss während Turnier verfügbar sein
- ⚠️ Begrenzt auf 2-4 Tische gleichzeitig (1 Stream)
- ⚠️ Nicht 24/7-fähig

**Kosten:**
- OBS Studio: 0€ (Open Source)
- Hardware: 0€ (bereits vorhanden)
- **Total: 0€**

**Best für:**
- Kleinere Turniere (1-4 Tische)
- Gelegentliches Streaming
- Professionelle Präsentation gewünscht
- Budget-freundlich

---

### Option 3: Hybrid-Ansatz

**Kombination aus beiden Welten:**
```
Hauptstream (MacBook + OBS):
├─ Szenen mit iPhone-Kameras
├─ Multi-Table-View aller Tische
├─ Kommentar, Interviews, Präsentation
└─ → YouTube Kanal 1 (Hauptkanal)

Zusätzliche Tisch-Streams (Raspberry Pi):
├─ Tisch 1 → YouTube Kanal 2
├─ Tisch 2 → YouTube Kanal 3
└─ Etc. (automatisch, unbeaufsichtigt)
```

**Vorteile:**
- ✅ **Beste aus beiden Welten**
- ✅ Professioneller Hauptstream (MacBook)
- ✅ Zusätzliche Detailstreams (Raspis)
- ✅ Zuschauer wählen ihre Ansicht
- ✅ Skalierbar für große Events

**Nachteile:**
- ⚠️ Höhere Komplexität
- ⚠️ Mehr Upload-Bandbreite nötig

**Kosten:**
- Kombination aus Option 1 + 2
- **Total: 80€ × Anzahl Raspi-Tische**

**Best für:**
- Große Events (8+ Tische)
- Professionelle Produktion
- Mehrere simultane Streams gewünscht

---

## Detaillierter Vergleich

| Kriterium | Raspberry Pi | MacBook + OBS | Hybrid |
|-----------|--------------|---------------|--------|
| **Setup-Zeit** | 2h pro Raspi (einmalig) | 30 Min | 2h + 30 Min |
| **Laufende Kosten** | 0€ | 0€ | 0€ |
| **Hardware-Kosten** | 80€ pro Tisch | 0€ | 80€ × N |
| **Maximale Auflösung** | 720p60 | 1080p60 | Beide |
| **Kamera-Qualität** | Logitech C922 (gut) | iPhone (exzellent) | Beste |
| **Szenen-Wechsel** | ❌ Nein | ✅ Ja | ✅ Ja |
| **Multi-Table-View** | ❌ Nein | ✅ 2x2 Grid | ✅ Ja |
| **Automatischer Betrieb** | ✅ 24/7 | ❌ Manual | Hybrid |
| **Personal-Bedarf** | Niemand | 1 Person | 1 Person |
| **Gleichzeitige Tische** | Unbegrenzt | 2-4 | Unbegrenzt |
| **Unabhängige Streams** | ✅ Pro Tisch | ❌ 1 Stream | ✅ Pro Tisch |
| **Bandwidth (Upload)** | 2.5 Mbit/s × N | 4-6 Mbit/s | Summe beider |
| **Overlay-System** | Chromium PNG | Browser Source | Beide |
| **ActionCable Updates** | ✅ Ja | ✅ Ja | ✅ Ja |
| **Wartungsaufwand** | Niedrig | Sehr niedrig | Mittel |

---

## Szenarien & Empfehlungen

### Szenario 1: Kleiner Verein (1-2 Tische)

**Turnier-Häufigkeit:** 1-2x pro Jahr

**Empfehlung:** **MacBook + OBS** ⭐

**Begründung:**
- Keine zusätzlichen Kosten
- MacBook bereits vorhanden
- Setup in 30 Minuten
- Professionelle Optik
- iPhones als Kameras (höhere Qualität)

**Umsetzung:**
1. OBS Studio auf MacBook installieren
2. iPhone(s) per Continuity Camera verbinden
3. Browser Source: Carambus Overlay-URL
4. Stream zu YouTube

---

### Szenario 2: Mittlerer Verein (4-6 Tische)

**Turnier-Häufigkeit:** 4-6x pro Jahr

**Empfehlung:** **MacBook + OBS für Hauptstream** + **Optional 1-2 Raspis für Detailstreams** ⭐⭐

**Begründung:**
- Hauptstream (MacBook): Multi-Table-View, Szenen-Wechsel
- Detail-Streams (Raspis): Top-2-Tische mit dediziertem Stream
- Budget-freundlich (nur 2 Kameras kaufen)
- Flexibel: MacBook für Turniere, Raspis für regulären Spielbetrieb

**Umsetzung:**
1. MacBook + OBS für Hauptstream
   - 2x2 Grid aller Tische
   - Szenen für Kommentar, Interviews
2. Raspberry Pi für Top-Tische
   - Automatische Streams für wichtigste Spiele
   - Kein Personal nötig

---

### Szenario 3: Großer Verein (8+ Tische)

**Turnier-Häufigkeit:** Wöchentlich/Monatlich

**Empfehlung:** **Hybrid-Ansatz** ⭐⭐⭐

**Begründung:**
- Skalierung auf viele Tische
- Professioneller Hauptstream
- Automatische Detailstreams
- 24/7-Streaming möglich

**Umsetzung:**
1. **MacBook + OBS:** Hauptstream
   - Turnierübersicht (Multi-Table)
   - Kommentar, Präsentation
   - Highlight-Szenen
   
2. **Raspberry Pi (8x):** Pro Tisch
   - Automatische Individual-Streams
   - Unbeaufsichtigt
   - Zuschauer wählen ihren Tisch

3. **Upload-Bandwidth:**
   - Hauptstream: 6 Mbit/s
   - 8 Tisch-Streams: 8 × 2.5 = 20 Mbit/s
   - **Total: 26 Mbit/s Upload nötig**

---

### Szenario 4: Deutsche Meisterschaft (16+ Tische)

**Turnier-Häufigkeit:** 1x pro Jahr, großes Event

**Empfehlung:** **Full Professional Setup** ⭐⭐⭐⭐

**Hardware:**
- 2x MacBook Pro (Backup!)
- 4x iPhone (Kameras)
- 16x Raspberry Pi (pro Tisch)
- Professional Switcher/Mixer (optional)

**Streams:**
1. **Hauptkanal (MacBook 1):**
   - Professionelle Moderation
   - Multi-Table-View
   - Interviews, Siegerehrung
   
2. **Kommentar-Kanal (MacBook 2):**
   - Live-Kommentar
   - Taktische Analysen
   - Picture-in-Picture

3. **16 Tisch-Kanäle (Raspis):**
   - Jeder Tisch eigener Stream
   - Automatisch, 24/7
   - Zuschauer wählen Favoriten

**Kosten:**
- 16 Kameras: 16 × 80€ = 1.280€
- Software: 0€
- **Total: 1.280€**

**Upload:**
- 3 MacBook-Streams: 3 × 6 = 18 Mbit/s
- 16 Raspi-Streams: 16 × 2.5 = 40 Mbit/s
- **Total: 58 Mbit/s Upload** (Glasfaser empfohlen!)

---

## iPhone-Spezifika

### iPhone als Kamera für MacBook

#### Option A: Continuity Camera (macOS Ventura+)

**Voraussetzungen:**
- macOS Ventura 13.0+
- iOS 16+
- Gleiche Apple-ID

**Setup:**
```bash
1. iPhone in Nähe von MacBook
2. OBS → Video Capture Device → iPhone auswählen
3. Fertig!
```

**Eigenschaften:**
- ✅ Kabellos (WLAN)
- ✅ Automatische Erkennung
- ✅ Mehrere iPhones gleichzeitig
- ⚠️ Latenz: 1-2 Sekunden
- ⚠️ Akku-Verbrauch (Laden nötig)

#### Option B: USB-Verbindung (NDI HX)

**Setup:**
```bash
1. "NDI HX Camera" App auf iPhone
2. USB-Kabel MacBook ↔ iPhone
3. OBS NDI-Plugin installieren
4. OBS → NDI Source → iPhone
```

**Eigenschaften:**
- ✅ Niedrige Latenz (<500ms)
- ✅ Kein Akku-Problem (lädt via USB)
- ✅ Bessere Qualität
- ⚠️ Kabel-gebunden

**Empfehlung:** USB für Hauptkamera, Continuity für zusätzliche Kameras

---

## OBS-Setup für Carambus

### Browser Source Konfiguration

**URL-Format:**
```
http://localhost:3000/locations/[LOCATION_MD5]/scoreboard_overlay?table_id=[TABLE_ID]
```

**Beispiel:**
```
http://localhost:3000/locations/0819bf0d7893e629200c20497ef9cfff/scoreboard_overlay?table_id=2
```

**OBS Browser Source Settings:**
```
Width: 1920
Height: 200  (für Bottom-Overlay)
       oder
Height: 1080 (für Fullscreen-Overlay)

✅ Shutdown source when not visible (CPU sparen)
✅ Refresh browser when scene becomes active
❌ Use custom frame rate (Standard 30 FPS reicht)
```

### Multi-Table Overlay

**Für 2x2 Grid:**
```html
<!-- Neue View erstellen: app/views/locations/scoreboard_overlay_multi.html.erb -->
<div class="grid grid-cols-2 gap-4 p-4 bg-black/80 h-screen">
  <% @location.tables.limit(4).each do |table| %>
    <div class="border-2 border-white/20 rounded-lg overflow-hidden">
      <%= render partial: 'scoreboard_compact', locals: { table: table } %>
    </div>
  <% end %>
</div>
```

**OBS Browser Source:**
```
http://localhost:3000/locations/[MD5]/scoreboard_overlay_multi
Width: 1920
Height: 1080
```

---

## Bandwidth-Rechner

### Formel

```
Upload (Mbit/s) = Anzahl Streams × Bitrate pro Stream × 1.2 (Overhead)
```

### Beispiel-Rechnungen

**1 MacBook-Stream (1080p60):**
```
1 × 6 Mbit/s × 1.2 = 7.2 Mbit/s
```

**4 Raspberry Pi Streams (720p30):**
```
4 × 2.5 Mbit/s × 1.2 = 12 Mbit/s
```

**Hybrid (1 MacBook + 4 Raspis):**
```
7.2 + 12 = 19.2 Mbit/s Upload nötig
```

### Empfohlene Upload-Geschwindigkeiten

| Setup | Minimum | Empfohlen |
|-------|---------|-----------|
| 1 MacBook | 8 Mbit/s | 12 Mbit/s |
| 1-2 Raspis | 6 Mbit/s | 10 Mbit/s |
| 4 Raspis | 12 Mbit/s | 20 Mbit/s |
| 8 Raspis | 24 Mbit/s | 35 Mbit/s |
| Hybrid (1+4) | 20 Mbit/s | 30 Mbit/s |

**Testen:**
```bash
speedtest-cli --simple
```

---

## Migration: Von Raspi zu MacBook

Falls bereits Raspberry Pi im Einsatz und Wechsel zu MacBook gewünscht:

### Schritt 1: OBS parallel testen

```bash
# Bestehende Raspi-Streams laufen weiter
# MacBook zusätzlich für Test-Stream

# Auf MacBook:
brew install --cask obs
# OBS konfigurieren (siehe streaming-obs-setup.de.md)
# Test mit privatem YouTube-Stream
```

### Schritt 2: Overlay-URLs wiederverwenden

```bash
# Gleiche Overlay-URLs wie Raspis:
http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=X

# In OBS als Browser Source
# ActionCable funktioniert identisch
```

### Schritt 3: Parallel-Betrieb (optional)

```bash
# Während Umstellung:
# - Raspi-Streams für Backup
# - MacBook für Hauptstream
# - Vergleich Qualität/Zuverlässigkeit
```

### Schritt 4: Vollständiger Wechsel (falls gewünscht)

```bash
# Raspis nur noch für Scoreboard
# MacBook übernimmt Streaming
# Kameras an USB statt Raspis
```

---

## Troubleshooting

### MacBook wird zu heiß

**Symptome:**
- Lüfter laut
- Throttling (Stream ruckelt)
- MacBook fühlt sich heiß an

**Lösungen:**
1. Hardware-Encoder verwenden: Apple VT H264
2. Auflösung senken: 720p statt 1080p
3. FPS senken: 30 statt 60
4. Externe Kühlung (Laptop-Stand mit Lüfter)
5. Nicht auf weichen Unterlagen (Sofa, Bett)

### iPhone verbindet nicht

**Continuity Camera:**
```bash
# Checkliste:
- Gleiche Apple-ID?
- Bluetooth aktiviert (beide Geräte)?
- WLAN aktiviert (beide Geräte)?
- Handoff aktiviert?
- iPhone in Nähe (<3m)?

# Reset:
1. iPhone neu starten
2. Bluetooth off/on
3. MacBook neu starten
```

**NDI:**
```bash
# Checkliste:
- NDI App läuft im Vordergrund?
- "Diesem Computer vertrauen" bestätigt?
- OBS NDI-Plugin installiert?

# Reset:
1. NDI App schließen/neu öffnen
2. USB-Kabel ab/an
3. OBS neu starten
```

### Overlay zeigt alte Daten

**OBS Browser Source:**
```bash
# Rechtsklick auf Browser Source
→ "Refresh Cache"
→ "Restart Interaction"

# Oder: Overlay-URL im normalen Browser testen
open http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=1
```

### Stream bricht ab

**Diagnose:**
```bash
# OBS → Ansicht → Stats
# Prüfen:
- "Dropped Frames (Network)" → Upload zu langsam
- "Dropped Frames (Rendering)" → CPU überlastet
- "Dropped Frames (Encoding)" → Encoder überlastet
```

**Fixes:**
```bash
# Network:
- Bitrate reduzieren
- Andere Geräte offline
- QoS im Router (Gaming/Streaming priorisieren)

# Rendering:
- Quellen reduzieren
- Preview deaktivieren
- FPS senken

# Encoding:
- Hardware-Encoder
- Auflösung senken
- Preset anpassen
```

---

## Nächste Schritte

### Für MacBook + OBS (Empfohlen als Start)

1. ✅ **Dokumentation lesen**
   - `docs/administrators/streaming-obs-setup.de.md`

2. ✅ **OBS installieren**
   ```bash
   brew install --cask obs
   ```

3. ✅ **Test-Setup (30 Min)**
   - 1 iPhone als Kamera
   - 1 Browser Source (Overlay)
   - Privater YouTube-Stream

4. 🎨 **Anpassen**
   - Overlay-Farben
   - Szenen erstellen
   - Hotkeys definieren

5. 🚀 **Live-Test bei Turnier**
   - Mit Backup-Plan
   - Feedback sammeln
   - Iterieren

### Für Raspberry Pi (Bestehend)

1. ✅ **Weitermachen wie bisher**
   - System funktioniert
   - Stabil und automatisch

2. 🔧 **Optimierungen (optional)**
   - Overlay-Design anpassen
   - Kamera-Positionen verbessern
   - Bitrate optimieren

3. 🔄 **Hybrid erwägen**
   - MacBook für Hauptstream
   - Raspis für Detailstreams
   - Beste aus beiden Welten

---

## Support & Ressourcen

**Carambus-Dokumentation:**
- `docs/developers/streaming-architecture.de.md` - Technische Details (inkl. Overlay-System)
- `docs/administrators/streaming-obs-setup.de.md` - OBS-Setup

**Externe Ressourcen:**
- [OBS Studio Dokumentation](https://obsproject.com/wiki/)
- [YouTube Live Best Practices](https://support.google.com/youtube/answer/2853702)
- [NDI HX Camera App](https://apps.apple.com/app/ndi-hx-camera/id1501247274)

**Community:**
- OBS Forums: https://obsproject.com/forum/
- YouTube Creator Support: https://support.google.com/youtube

---

**Version:** 1.0  
**Datum:** Januar 2025  
**Autor:** Carambus Development Team



