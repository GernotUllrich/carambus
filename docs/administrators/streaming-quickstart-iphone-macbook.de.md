# Quick Start: iPhone & MacBook für Streaming

## 🎯 Schnelleinstieg in 30 Minuten

Verwenden Sie bereits vorhandenes MacBook und iPhone(s) für professionelles Turnier-Streaming mit Carambus-Overlays.

---

## ✅ Was Sie brauchen

**Hardware:**
- ✅ MacBook Pro (bereits vorhanden, Turnierleitung)
- ✅ 1-2 iPhones (bereits vorhanden)
- ✅ Stabile Internet-Verbindung (8+ Mbit/s Upload)
- Optional: USB-Kameras für zusätzliche Ansichten

**Software:**
- ✅ OBS Studio (kostenlos)
- ✅ Carambus Rails-Server (läuft bereits)

**Kosten: 0€** 🎉

---

## 📋 Setup in 5 Schritten

### Schritt 1: OBS Studio installieren (5 Min)

```bash
# Terminal öffnen und ausführen:
brew install --cask obs
```

**Oder:** Download von https://obsproject.com/

---

### Schritt 2: YouTube Stream-Key holen (2 Min)

1. YouTube Studio öffnen: https://studio.youtube.com
2. "Erstellen" → "Livestream starten"
3. "Stream-Schlüssel" kopieren (z.B. `xxxx-yyyy-zzzz-aaaa`)
4. Zwischenspeichern für Schritt 4

---

### Schritt 3: iPhone als Kamera verbinden (3 Min)

**Option A: Continuity Camera (Kabellos)**

1. iPhone und MacBook mit gleicher Apple-ID anmelden
2. Bluetooth + WLAN auf beiden Geräten aktivieren
3. iPhone in Nähe von MacBook platzieren (< 3 Meter)
4. Fertig! iPhone erscheint automatisch in OBS

**Option B: USB-Verbindung (Bessere Qualität)**

1. "NDI HX Camera" App auf iPhone installieren (gratis)
2. iPhone per USB an MacBook anschließen
3. OBS NDI-Plugin installieren:
   ```bash
   brew install --cask obs-ndi
   ```
4. In OBS: Tools → NDI Source → iPhone auswählen

---

### Schritt 3b: Lokaler RTMP Server (Optional, 5 Min)

**Nur nötig wenn Sie Raspberry Pi Streams in OBS integrieren wollen!**

Der RTMP Server empfängt Streams von Raspberry Pi Kameras und macht sie für OBS verfügbar.

**3b.1 Docker Desktop starten:**

```bash
open -a Docker
```

Warten bis das Docker-Icon in der Menüleiste erscheint (ca. 10-20 Sekunden).

**3b.2 RTMP Server erstellen (nur beim ersten Mal):**

```bash
docker run -d --name rtmp-server -p 1935:1935 -p 8080:8080 alfg/nginx-rtmp
```

**3b.3 Server starten (bei jedem Mac-Neustart):**

```bash
# Checken ob läuft:
docker ps

# Falls nicht läuft, starten:
docker start rtmp-server
```

**3b.4 Mac IP-Adresse notieren:**

```bash
# WLAN:
ipconfig getifaddr en0

# Oder Ethernet:
ipconfig getifaddr en1
```

Diese IP brauchen Sie in der Carambus Admin UI für die Stream-Konfiguration!

---

### Schritt 4: OBS konfigurieren (10 Min)

**4.1 Stream-Einstellungen:**

1. OBS öffnen
2. Datei → Einstellungen → Stream
   - Dienst: **YouTube - RTMP**
   - Stream-Schlüssel: *[aus Schritt 2 einfügen]*
   - OK klicken

**4.2 Video-Einstellungen:**

1. Datei → Einstellungen → Video
   - Basisauflösung: **1920x1080**
   - Ausgangsauflösung: **1920x1080** (oder 1280x720 für weniger Bandbreite)
   - FPS: **30** (empfohlen für Billard)
   - OK klicken

**4.3 Ausgabe-Einstellungen:**

1. Datei → Einstellungen → Ausgabe
   - Encoder: **Apple VT H264 Hardware Encoder** (wichtig!)
   - Bitrate: **4500 kbps** (für 1080p30)
   - Keyframe-Intervall: **2**
   - OK klicken

---

### Schritt 5: Szene mit Overlay erstellen (10 Min)

**5.1 Video-Quelle hinzufügen:**

**Option A: iPhone als Kamera**

1. In OBS: Quellen → "+" → **Video Capture Device**
2. Name: "iPhone Kamera Tisch 1"
3. Gerät: iPhone auswählen
4. OK
5. Quelle auf Vollbild ziehen (Rand anfassen und ziehen)

**Option B: Raspberry Pi Stream (wenn Schritt 3b gemacht)**

1. In OBS: Quellen → "+" → **Media Source**
2. Name: "Raspi Stream Tisch 6"
3. ☑ **Lokale Datei** deaktivieren
4. Eingabe: `rtmp://localhost:1935/stream/table2`
   - Format: `rtmp://localhost:1935/stream/table<TABLE_ID>`
   - TABLE_ID ist die Rails-Tabellen-ID (nicht table.number!)
5. ☑ **Neustart der Wiedergabe wenn Quelle aktiv wird** aktivieren
6. OK
7. Quelle positionieren und skalieren

**5.2 Overlay hinzufügen:**

1. Quellen → "+" → **Browser**
2. Name: "Scoreboard Overlay Tisch 1"
3. URL: Ihre Overlay-URL eintragen
   ```
   http://localhost:3000/locations/[LOCATION_MD5]/scoreboard_overlay?table_id=[TABLE_ID]
   ```
   
   **Ihre Werte finden:**
   - LOCATION_MD5: In Rails Console: `Location.first.md5`
   - TABLE_ID: In Rails Console: `Table.find_by(number: 1).id`
   
   **Beispiel:**
   ```
   http://localhost:3000/locations/0819bf0d7893e629200c20497ef9cfff/scoreboard_overlay?table_id=2
   ```

4. Breite: **1920**
5. Höhe: **200**
6. ✅ **Shutdown source when not visible**
7. ✅ **Refresh browser when scene becomes active**
8. OK

**5.3 Overlay positionieren:**

1. Overlay-Quelle in Liste anklicken
2. An untere Kante ziehen
3. ALT-Taste gedrückt halten → Zuschneiden auf gewünschte Höhe

**Fertig!** 🎉

---

## 🚀 Streaming starten

**Test-Stream (privat):**

1. YouTube Studio → Stream-Einstellungen
2. Sichtbarkeit: **Nicht gelistet** (für Test)
3. In OBS: **"Streaming starten"** klicken
4. Nach ~10 Sekunden: Video erscheint in YouTube Studio
5. Scoreboard im Carambus aktualisieren → Overlay ändert sich automatisch!

**Live-Stream (öffentlich):**

1. YouTube Studio → Stream-Einstellungen
2. Sichtbarkeit: **Öffentlich**
3. Titel, Beschreibung setzen
4. In OBS: **"Streaming starten"**
5. Fertig! 🎉

---

## 🎨 Erweiterte Szenen

### Multi-Table-View (2x2 Grid)

**Für 4 Tische gleichzeitig:**

1. Neue Szene erstellen: "Multi-Table"
2. 4 Video-Quellen hinzufügen:
   - Kamera 1 (iPhone 1)
   - Kamera 2 (iPhone 2)
   - Kamera 3 (USB-Kamera 1)
   - Kamera 4 (USB-Kamera 2)
3. Jede Quelle transformieren:
   - Position: (0,0), (960,0), (0,540), (960,540)
   - Größe: 960x540
4. 4 Browser-Overlays hinzufügen (je Tisch 1)

**Hotkey definieren:**

1. Datei → Einstellungen → Hotkeys
2. "Multi-Table" Szene → F2 zuweisen
3. OK

**Szenen-Wechsel:**
- F1: Tisch 1 (Detail)
- F2: Multi-Table (Übersicht)
- F3: Tisch 2 (Detail)
- Etc.

---

### Nahaufnahme (Spieler-Fokus)

**Für Close-up eines Spielers:**

1. Neue Szene: "Nahaufnahme"
2. Video: iPhone mit Zoom auf Spieler
3. Overlay: Minimal (nur Score, kleiner)

**Minimales Overlay (optional):**

Neue Browser-Source mit Parameter:
```
http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=[ID]&layout=minimal
```

(Hinweis: `layout=minimal` Parameter muss noch im Controller implementiert werden)

---

### Lower Third (Spieler-Info)

**Namen/Info einblenden:**

1. Neue Quelle: Text (FreeType 2)
2. Text: "Max Mustermann • Durchschnitt: 1.234"
3. Schriftart: Arial Bold, 32px
4. Position: Unten links
5. Hintergrund: Halbtransparent

**Oder:** Browser Source mit dynamischem HTML:
```html
http://localhost:3000/players/[PLAYER_ID]/lower_third
```

(Hinweis: Noch zu implementieren)

---

## 📊 Qualität & Performance

### Video-Qualität anpassen

**Bei langsamem Upload:**

```
Auflösung: 1920x1080 → 1280x720
Bitrate: 4500 kbps → 2500 kbps
FPS: 30 → 30 (beibehalten)
```

**Bei MacBook-Überhitzung:**

```
Encoder: Apple VT H264 (Hardware!)
FPS: 30 (nicht 60)
CPU-Voreinstellung: veryfast
```

**Bei ruckelndem Stream:**

1. OBS → Ansicht → Stats öffnen
2. "Dropped Frames" prüfen:
   - Network: Upload zu langsam → Bitrate senken
   - Rendering: CPU überlastet → Quellen reduzieren
   - Encoding: Encoder überlastet → Hardware-Encoder aktivieren

---

## 🔧 Troubleshooting

### Overlay lädt nicht

**Fix:**
```bash
# 1. Rails-Server läuft?
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rails s -p 3000

# 2. URL im Browser testen
open http://localhost:3000/locations/[MD5]/scoreboard_overlay?table_id=[ID]

# 3. In OBS: Rechtsklick auf Browser Source → "Refresh Cache"
```

---

### iPhone wird nicht erkannt

**Continuity Camera:**
1. Bluetooth/WLAN prüfen (beide Geräte)
2. Gleiche Apple-ID?
3. iPhone entsperren
4. Näher zum MacBook (<3m)
5. iPhone neu starten

**NDI:**
1. App läuft im Vordergrund?
2. "Diesem Computer vertrauen" bestätigt?
3. USB-Kabel funktioniert? (Anderes probieren)
4. OBS NDI-Plugin installiert?

---

### Overlay zeigt alte Daten

**Fix:**
1. Scoreboard aktualisieren
2. In OBS: Rechtsklick auf Browser → "Interact"
3. F5 im Browser-Fenster drücken
4. Oder: Browser Source entfernen/neu hinzufügen

---

### Stream bricht ab / ruckelt

**Diagnose:**
```bash
# Upload-Speed testen
speedtest-cli --simple
# Oder: https://fast.com

# Minimum: 8 Mbit/s Upload
# Empfohlen: 12 Mbit/s Upload
```

**Fixes:**
- Andere Geräte vom WLAN trennen
- Ethernet statt WLAN für MacBook
- Bitrate in OBS senken
- Auflösung reduzieren (720p)

---

## 📈 Von einfach zu professionell

### Level 1: Basis (Was Sie jetzt haben) ✅

```
1 iPhone → MacBook → OBS → YouTube
         └─ Browser Overlay
```

**Ergebnis:** 1 Tisch mit Live-Scoreboard

---

### Level 2: Multi-Kamera 📹

```
2 iPhones → MacBook → OBS → YouTube
           └─ 2 Szenen (Übersicht + Nahaufnahme)
           └─ Browser Overlays
```

**Ergebnis:** Flexibles Streaming mit Szenen-Wechsel

---

### Level 3: Multi-Table 🎬

```
2 iPhones    ┐
2 USB-Cams   ├→ MacBook → OBS → YouTube
4 Overlays   ┘         └─ 2x2 Grid
```

**Ergebnis:** 4 Tische gleichzeitig, professionell

---

### Level 4: Hybrid 🚀

```
MacBook + OBS → YouTube Kanal 1 (Hauptstream)
  └─ Multi-Table-View

4× Raspberry Pi → YouTube Kanäle 2-5 (Detail-Streams)
  └─ Pro Tisch eigener Stream
```

**Ergebnis:** Zuschauer wählen ihre Ansicht

---

## 💡 Tipps & Tricks

### iPhone-Positionierung

**Stativ-Alternativen:**
- Gorilla-Pod (flexibel, ~20€)
- Smartphone-Halter mit Klemme (~15€)
- Magic Arm (variabel, ~30€)

**Kamera-Position:**
- Leicht erhöht (45° Winkel)
- Gesamter Tisch sichtbar
- Kein Gegenlicht (Fenster hinter Tisch vermeiden)

---

### Lighting

**Problem:** Dunkle Szenen, verrauschtes Bild

**Lösung:**
- LED-Panels aufstellen (~50€/Stück)
- Bestehende Beleuchtung verstärken
- iPhone: Nachtmodus aktivieren (in NDI-App)

---

### Audio

**Derzeit:** Nur Umgebungsgeräusche

**Upgrade-Option 1:** Kommentar-Mikrofon
```
USB-Mikro → MacBook → OBS → Stream
(z.B. Blue Yeti, ~120€)
```

**Upgrade-Option 2:** Tisch-Mikrofon
```
Ansteck-Mikro an iPhone → Audio im Stream
(z.B. Rode SmartLav+, ~60€)
```

---

### Branding

**Grafiken einblenden:**

1. Logo erstellen (PNG mit Transparenz)
2. In OBS: Quellen → Bild → Logo auswählen
3. Position: Oben rechts (klein)
4. Opacity: 70-80%

**Turnier-Info:**

1. Quellen → Text → "Deutsche Meisterschaft 2025"
2. Position: Oben links
3. Hintergrund: Gradient (schwarz→transparent)

---

## 🎓 Weiterführende Ressourcen

**Carambus-Dokumentation:**
- `docs/administrators/streaming-obs-setup.de.md` - Vollständiges OBS-Setup
- `docs/administrators/streaming-comparison.de.md` - Raspberry Pi vs. MacBook
- `docs/developers/streaming-architecture.de.md` - Technische Details

**OBS Studio:**
- [Offizielle Tutorials](https://obsproject.com/wiki/OBS-Studio-Quickstart)
- [YouTube OBS Guides](https://www.youtube.com/results?search_query=obs+studio+tutorial)

**YouTube:**
- [Live Streaming Best Practices](https://support.google.com/youtube/answer/2853702)

---

## 🚀 Nächste Schritte

1. ✅ **Setup durchführen** (30 Min, siehe oben)
2. 🎨 **Test-Stream** (privat auf YouTube)
3. 📊 **Qualität prüfen** (Overlay sichtbar? Flüssig?)
4. 🎬 **Szenen erweitern** (Multi-Table, Nahaufnahme)
5. 🚀 **Live-Test bei Turnier** (mit Backup-Plan!)

---

## ❓ Fragen?

**Problem mit Setup?**
→ Siehe Troubleshooting oben

**Technische Details?**
→ `docs/administrators/streaming-obs-setup.de.md`

**Raspberry Pi stattdessen?**
→ `docs/administrators/streaming-comparison.de.md`

**Overlay anpassen?**
→ `STREAMING_OVERLAY_README.md`

---

**Version:** 1.0  
**Datum:** Januar 2025  
**Status:** ✅ Ready to Use  
**Kosten:** 0€  
**Setup-Zeit:** 30 Minuten  
**Ergebnis:** Professionelles Streaming 🎉



