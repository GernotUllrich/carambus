# Trapezkorrektur (Perspective Correction) - Interaktive Kalibrierung

## Übersicht

Die Trapezkorrektur ermöglicht es, Verzerrungen im Kamerabild zu korrigieren, die entstehen, wenn die Kamera nicht perfekt gerade auf das Spielfeld ausgerichtet ist.

## Schnellstart

### Interaktive Kalibrierung

```bash
rake 'streaming:perspective_calibrate[TABLE_ID]'
```

Dies startet einen interaktiven Wizard, der Sie durch die Einstellung führt:

1. **Aktuelle Werte anzeigen** - Zeigt die aktuellen Koordinaten und eine visuelle Darstellung
2. **Einzelne Koordinaten setzen** - Passen Sie jede Ecke einzeln an
3. **Presets verwenden** - Verwenden Sie vordefinierte Anpassungen
4. **Werte testen** - Speichern Sie temporär und testen Sie im Stream
5. **In Datenbank speichern** - Speichern Sie die finalen Werte

### Direktes Setzen

```bash
rake 'streaming:perspective_set[3,50:20:W-50:20:W-30:H-30:30:H-30]'
```

## Koordinaten-Format

Das Format ist: `x0:y0:x1:y1:x2:y2:x3:y3`

- **x0, y0**: Oben-links (Top-left)
- **x1, y1**: Oben-rechts (Top-right)
- **x2, y2**: Unten-rechts (Bottom-right)
- **x3, y3**: Unten-links (Bottom-left)

### Spezielle Werte

- `W` = Breite (wird automatisch durch die Kamerabreite ersetzt)
- `H` = Höhe (wird automatisch durch die Kamerahöhe ersetzt)
- `W-50` = Breite minus 50 Pixel
- `H-30` = Höhe minus 30 Pixel

### Beispiele

**Keine Korrektur (Standard):**
```
0:0:W:0:W:H:0:H
```

**Leichte Korrektur oben (oben schmaler):**
```
50:0:W-50:0:W:H:0:H
```

**Leichte Korrektur unten (unten schmaler):**
```
0:0:W:0:W-50:H:50:H
```

**Pixel-Werte (für 1280x720):**
```
0:0:1280:0:1280:720:0:720
```

## Interaktiver Workflow

### Schritt 1: Kalibrierung starten

```bash
rake 'streaming:perspective_calibrate[3]'
```

### Schritt 2: Aktuelle Werte prüfen

Das Tool zeigt:
- Aktuelle Koordinaten
- Visuelle Darstellung der Ecken
- Werte in Pixeln

### Schritt 3: Werte anpassen

**Option 1: Einzelne Koordinaten setzen**
- Wählen Sie Option 1
- Geben Sie für jede Ecke neue x/y-Werte ein
- Das Tool zeigt die aktualisierten Werte

**Option 2: Presets verwenden**
- Wählen Sie Option 2
- Wählen Sie ein Preset:
  - Keine Korrektur
  - Oben schmaler (5% Crop)
  - Unten schmaler (5% Crop)
  - Links schmaler (5% Crop)
  - Rechts schmaler (5% Crop)
  - Benutzerdefinierter Prozentsatz

### Schritt 4: Testen

1. Wählen Sie Option 3 (Testen)
2. Die Werte werden temporär gespeichert
3. Deployen Sie die Konfiguration:
   ```bash
   rake 'streaming:deploy[3]'
   ```
4. Starten Sie den Stream neu
5. Beobachten Sie das Ergebnis in OBS

### Schritt 5: Speichern

Wenn Sie mit den Werten zufrieden sind:
1. Wählen Sie Option 4 (Speichern)
2. Die Werte werden dauerhaft in der Datenbank gespeichert
3. Deployen Sie die Konfiguration:
   ```bash
   rake 'streaming:deploy[3]'
   ```

## Tipps für die Kalibrierung

### 1. Ausgangssituation analysieren

- Starten Sie den Stream ohne Trapezkorrektur
- Beobachten Sie, welche Verzerrungen sichtbar sind
- Notieren Sie, welche Ecken korrigiert werden müssen

### 2. Schrittweise anpassen

- Beginnen Sie mit kleinen Anpassungen (5-10% Crop)
- Testen Sie nach jeder Änderung
- Passen Sie schrittweise an, bis das Ergebnis stimmt

### 3. Häufige Probleme

**Problem: Oben schmaler als unten**
- Lösung: Oben-links und oben-rechts nach innen verschieben
- Beispiel: `50:0:W-50:0:W:H:0:H`

**Problem: Unten schmaler als oben**
- Lösung: Unten-links und unten-rechts nach innen verschieben
- Beispiel: `0:0:W:0:W-50:H:50:H`

**Problem: Links schmaler als rechts**
- Lösung: Oben-links und unten-links nach innen verschieben
- Beispiel: `0:50:W:0:W:H-50:0:H`

**Problem: Rechts schmaler als links**
- Lösung: Oben-rechts und unten-rechts nach innen verschieben
- Beispiel: `0:0:W:50:W:H-50:0:H`

### 4. Best Practices

- **Kleine Anpassungen**: Beginnen Sie mit 5-10% Crop
- **Symmetrie**: Versuchen Sie, symmetrische Korrekturen zu machen
- **Testen**: Testen Sie immer im Stream, nicht nur in der Konfiguration
- **Lichtverhältnisse**: Berücksichtigen Sie, dass sich die Verzerrung bei verschiedenen Blickwinkeln ändern kann

## Beispiel-Workflow

```bash
# 1. Kalibrierung starten
rake 'streaming:perspective_calibrate[3]'

# 2. Preset "Oben schmaler" auswählen (Option 2, dann 2)
# 3. Werte testen (Option 3)
# 4. Konfiguration deployen
rake 'streaming:deploy[3]'

# 5. Stream neu starten und Ergebnis prüfen
# 6. Wenn zufrieden: Speichern (Option 4)
# 7. Nochmal deployen
rake 'streaming:deploy[3]'
```

## Direktes Setzen (für fortgeschrittene Benutzer)

Wenn Sie die Koordinaten bereits kennen:

```bash
# Beispiel: Oben 50 Pixel schmaler
rake 'streaming:perspective_set[3,50:0:W-50:0:W:H:0:H]'

# Beispiel: Unten 30 Pixel schmaler
rake 'streaming:perspective_set[3,0:0:W:0:W-30:H:30:H]'

# Dann deployen
rake 'streaming:deploy[3]'
```

## Technische Details

### FFmpeg Perspective Filter

Die Trapezkorrektur verwendet den FFmpeg `perspective` Filter:

```
perspective=x0:y0:x1:y1:x2:y2:x3:y3
```

Die Koordinaten definieren, welche Bereiche des Quellbildes auf die 4 Ecken des Ausgabebildes gemappt werden.

### Koordinaten-System

- **Ursprung (0,0)**: Oben-links
- **X-Achse**: Nach rechts (0 bis Breite)
- **Y-Achse**: Nach unten (0 bis Höhe)

### Beispiel-Berechnung

Für eine 1280x720 Kamera:
- `0:0:1280:0:1280:720:0:720` = Keine Korrektur (volle Breite/Höhe)
- `50:0:1230:0:1280:720:0:720` = Oben 50 Pixel schmaler
- `0:0:1280:0:1230:720:50:720` = Unten 50 Pixel schmaler

## Troubleshooting

**Problem: Koordinaten werden nicht angewendet**
- Prüfen Sie, ob `perspective_enabled` auf `true` gesetzt ist
- Prüfen Sie die Konfigurationsdatei: `ssh pi@RASPI_IP 'cat /etc/carambus/stream-table-X.conf'`
- Stellen Sie sicher, dass die Konfiguration deployed wurde

**Problem: Verzerrung wird schlimmer**
- Setzen Sie die Werte zurück auf `0:0:W:0:W:H:0:H`
- Beginnen Sie mit kleineren Anpassungen

**Problem: Bild wird abgeschnitten**
- Die Koordinaten dürfen nicht außerhalb des Bildes liegen
- Stellen Sie sicher, dass alle Werte zwischen 0 und Breite/Höhe liegen

## Weitere Informationen

- [FFmpeg Perspective Filter Documentation](https://ffmpeg.org/ffmpeg-filters.html#perspective)
- [Camera Calibration Guide](./camera-calibration.md)

