# Kamera-Kalibrierung für Streaming

## Übersicht

Um optimale Stream-Qualität zu erreichen, sollten die Kameraeinstellungen (Fokus, Belichtung, etc.) im manuellen Modus kalibriert werden. Dies verhindert, dass die Kamera sich automatisch anpasst, wenn jemand durch das Bild läuft.

## Schnellstart

1. **Aktuelle Werte anzeigen:**
   ```bash
   rake streaming:camera_calibrate[TABLE_ID]
   ```

2. **Werte interaktiv testen:**
   ```bash
   # Auto-Fokus deaktivieren
   rake streaming:camera_set[TABLE_ID,focus_automatic_continuous,0]
   
   # Auto-Belichtung deaktivieren
   rake streaming:camera_set[TABLE_ID,auto_exposure,1]
   
   # Fokus-Wert setzen (0-250, Schritt: 5)
   rake streaming:camera_set[TABLE_ID,focus_absolute,125]
   
   # Belichtungs-Wert setzen (3-2047, Standard: 250)
   rake streaming:camera_set[TABLE_ID,exposure_time_absolute,250]
   ```

3. **Aktuelle Werte in Datenbank speichern:**
   ```bash
   rake streaming:camera_save[TABLE_ID]
   ```

4. **Konfiguration deployen:**
   ```bash
   rake streaming:deploy[TABLE_ID]
   ```

## Detaillierte Anleitung

### Schritt 1: Ausgangssituation analysieren

Führen Sie die Kalibrierung aus, um die aktuellen Werte zu sehen:

```bash
rake streaming:camera_calibrate[3]
```

Dies zeigt:
- Aktuelle Auto-Fokus und Auto-Belichtung Einstellungen
- Aktuelle Werte für Fokus, Belichtung, Helligkeit, Kontrast, Sättigung
- Verfügbare Wertebereiche und Schritte

### Schritt 2: Auto-Modus testen

Lassen Sie die Kamera zunächst im Auto-Modus laufen und beobachten Sie den Stream in OBS:

1. Starten Sie den Stream
2. Beobachten Sie, wie die Kamera sich anpasst
3. Notieren Sie sich die Werte, die die Kamera wählt

### Schritt 3: Manuellen Modus aktivieren

Deaktivieren Sie Auto-Fokus und Auto-Belichtung:

```bash
rake streaming:camera_set[3,focus_automatic_continuous,0]
rake streaming:camera_set[3,auto_exposure,1]
```

### Schritt 4: Werte optimieren

Passen Sie die Werte schrittweise an, während Sie den Stream beobachten:

**Fokus (0-250, Schritt: 5):**
- Niedrige Werte (0-50): Nah fokussiert
- Mittlere Werte (100-150): Standard für Tisch-Aufnahmen
- Hohe Werte (200-250): Weit fokussiert

```bash
# Beispiel: Fokus auf 125 setzen
rake streaming:camera_set[3,focus_absolute,125]
```

**Belichtung (3-2047, Standard: 250):**
- Niedrige Werte (3-100): Sehr dunkel, für sehr helle Umgebungen
- Standard (250): Guter Ausgangspunkt
- Hohe Werte (500-2047): Heller, für dunkle Umgebungen

```bash
# Beispiel: Belichtung auf 300 setzen
rake streaming:camera_set[3,exposure_time_absolute,300]
```

**Helligkeit (0-255, Standard: 128):**
```bash
rake streaming:camera_set[3,brightness,140]
```

**Kontrast (0-255, Standard: 128):**
```bash
rake streaming:camera_set[3,contrast,135]
```

**Sättigung (0-255, Standard: 128):**
```bash
rake streaming:camera_set[3,saturation,130]
```

### Schritt 5: Werte speichern

Wenn Sie mit den Einstellungen zufrieden sind, speichern Sie sie in der Datenbank:

```bash
rake streaming:camera_save[3]
```

Dies liest die aktuellen Werte vom Raspberry Pi und speichert sie in der Datenbank.

### Schritt 6: Konfiguration deployen

Deployen Sie die Konfiguration, damit die Werte beim nächsten Stream-Start verwendet werden:

```bash
rake streaming:deploy[3]
```

### Schritt 7: Stream neu starten

Starten Sie den Stream neu, damit die neuen Einstellungen aktiv werden.

## Tipps

1. **Lichtverhältnisse berücksichtigen:**
   - Tageslicht: Niedrigere Belichtungswerte
   - Kunstlicht: Höhere Belichtungswerte
   - Gemischtes Licht: Mittelwerte

2. **Fokus einstellen:**
   - Stellen Sie sicher, dass der Tisch scharf ist
   - Testen Sie verschiedene Werte, während jemand am Tisch steht
   - Der Fokus sollte nicht nachjustieren, wenn jemand durchs Bild läuft

3. **Belichtung optimieren:**
   - Starten Sie mit dem Standardwert (250)
   - Erhöhen Sie bei zu dunklen Bildern
   - Verringern Sie bei zu hellen/überbelichteten Bildern

4. **Feintuning:**
   - Verwenden Sie OBS oder einen anderen Stream-Viewer zum Testen
   - Nehmen Sie Screenshots bei verschiedenen Einstellungen
   - Vergleichen Sie die Ergebnisse

## Troubleshooting

**Problem: Werte werden nicht gesetzt**
- Prüfen Sie, ob die Kamera erreichbar ist: `v4l2-ctl --list-devices`
- Prüfen Sie, ob der Control-Name korrekt ist: `v4l2-ctl --list-ctrls`

**Problem: Werte werden beim Stream-Start zurückgesetzt**
- Stellen Sie sicher, dass die Konfiguration deployed wurde: `rake streaming:deploy[TABLE_ID]`
- Prüfen Sie die Konfigurationsdatei: `ssh pi@RASPI_IP 'cat /etc/carambus/stream-table-X.conf'`

**Problem: Auto-Modus wird nicht deaktiviert**
- Prüfen Sie die Control-Namen Ihrer Kamera: `v4l2-ctl --list-ctrls`
- Manche Kameras verwenden andere Control-Namen (z.B. `focus_auto` statt `focus_automatic_continuous`)

## Beispiel-Workflow

```bash
# 1. Aktuelle Werte anzeigen
rake streaming:camera_calibrate[3]

# 2. Auto-Modus deaktivieren
rake streaming:camera_set[3,focus_automatic_continuous,0]
rake streaming:camera_set[3,auto_exposure,1]

# 3. Fokus einstellen (beobachten Sie den Stream)
rake streaming:camera_set[3,focus_absolute,125]

# 4. Belichtung anpassen
rake streaming:camera_set[3,exposure_time_absolute,300]

# 5. Helligkeit/Kontrast/Sättigung feintunen
rake streaming:camera_set[3,brightness,140]
rake streaming:camera_set[3,contrast,135]

# 6. Werte speichern
rake streaming:camera_save[3]

# 7. Deployen
rake streaming:deploy[3]

# 8. Stream neu starten
```

## Verfügbare Controls (Logitech C922)

- `focus_automatic_continuous`: 0=manual, 1=auto
- `focus_absolute`: 0-250 (Schritt: 5)
- `auto_exposure`: 1=manual, 3=auto
- `exposure_time_absolute`: 3-2047 (Standard: 250)
- `brightness`: 0-255 (Standard: 128)
- `contrast`: 0-255 (Standard: 128)
- `saturation`: 0-255 (Standard: 128)

## Weitere Informationen

- [FFmpeg v4l2 Documentation](https://ffmpeg.org/ffmpeg-devices.html#v4l2)
- [V4L2 Controls](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html)

