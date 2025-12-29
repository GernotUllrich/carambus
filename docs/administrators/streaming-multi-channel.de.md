# YouTube Streaming - Mehrkanal-Setup

## Übersicht

Diese Anleitung beschreibt, wie Sie mehrere YouTube-Kanäle für simultanes Streaming von verschiedenen Tischen einrichten.

## Strategie: Ein Google-Account, mehrere Brand Accounts

### Vorteile
- ✅ Zentrale Verwaltung über einen Google-Account
- ✅ Jeder Tisch kann gleichzeitig streamen
- ✅ Klare Trennung der Streams
- ✅ Einfaches Wechseln zwischen Kanälen
- ✅ Kostenlos

### Herausforderung: Telefonnummer-Verifizierung

⚠️ **YouTube-Limit**: Nur 2 Kanal-Verifizierungen pro Telefonnummer pro Jahr

## Schritt-für-Schritt Anleitung

### Phase 1: Erster Kanal (bereits erledigt)

```yaml
Kanal: "BC Wedel - Tisch 1"
Google Account: bcwedel61@gmail.com
Telefon: Ihre Hauptnummer
Status: ✅ Verifiziert und einsatzbereit
```

### Phase 2: Weitere Kanäle erstellen

Für jeden zusätzlichen Tisch:

#### 1. Neuen Brand Account erstellen

```
1. YouTube → Profilbild → "Kanal wechseln"
2. "Kanal erstellen"
3. "Marke oder anderer Name verwenden"
4. Name: "BC Wedel - Tisch [Nummer]"
5. "Erstellen"
```

Direkter Link: https://www.youtube.com/channel_switcher

#### 2. Live-Streaming aktivieren

```
1. Zu neuem Kanal wechseln
2. YouTube Studio → "Erstellen" → "Live übertragen"
3. Live-Streaming aktivieren
4. Telefonnummer verifizieren
```

**Wichtig:** Verwenden Sie eine **andere Telefonnummer** als für die ersten beiden Kanäle!

#### 3. Telefonnummern-Quellen

Mögliche Telefonnummern für Verifizierung:

```yaml
Kanal 1 (Tisch 1): Hauptnummer Club
Kanal 2 (Tisch 2): Handynummer Vorstand/Mitglied 1
Kanal 3 (Tisch 3): Handynummer Vorstand/Mitglied 2
Kanal 4 (Tisch 4): Festnetznummer Club (falls vorhanden)
```

**Hinweise:**
- Telefonnummer wird nur für Verifizierung benötigt
- Nach Verifizierung kann Nummer normal weiterverwendet werden
- Festnetznummern funktionieren auch (SMS oder Anruf)
- Clubmitglieder können ihre Nummern zur Verfügung stellen

#### 4. Stream-Key auslesen

Für jeden neuen Kanal:

```
1. Zu Kanal wechseln (Profilbild → Kanal wechseln)
2. YouTube Studio → studio.youtube.com
3. "Erstellen" → "Live übertragen"
4. Runterscrollen zu "Stream-Einstellungen"
5. Stream-Key kopieren
```

### Phase 3: Carambus StreamConfiguration erstellen

Für jeden Kanal eine separate StreamConfiguration:

#### Admin-Interface

```
URL: /admin/stream_configurations/new

Tisch 1:
  Table: Tisch 1
  YouTube Stream Key: [Key von Kanal "BC Wedel - Tisch 1"]
  Raspi IP: 192.168.1.101

Tisch 2:
  Table: Tisch 2
  YouTube Stream Key: [Key von Kanal "BC Wedel - Tisch 2"]
  Raspi IP: 192.168.1.102

Tisch 3:
  Table: Tisch 3
  YouTube Stream Key: [Key von Kanal "BC Wedel - Tisch 3"]
  Raspi IP: 192.168.1.103

Tisch 4:
  Table: Tisch 4
  YouTube Stream Key: [Key von Kanal "BC Wedel - Tisch 4"]
  Raspi IP: 192.168.1.104
```

## Verwaltung der Kanäle

### Zwischen Kanälen wechseln

**Im Browser:**
```
YouTube → Profilbild → "Kanal wechseln"
Gewünschten Kanal auswählen
```

**Alle Kanäle verwalten:**
```
https://www.youtube.com/channel_switcher
```

### Stream-Keys verwalten

Übersichts-Tabelle erstellen und sicher aufbewahren:

```
| Tisch | Kanal-Name           | Stream-Key        | Raspi IP      |
|-------|---------------------|-------------------|---------------|
| 1     | BC Wedel - Tisch 1  | xxxx-xxxx-xxxx   | 192.168.1.101 |
| 2     | BC Wedel - Tisch 2  | yyyy-yyyy-yyyy   | 192.168.1.102 |
| 3     | BC Wedel - Tisch 3  | zzzz-zzzz-zzzz   | 192.168.1.103 |
| 4     | BC Wedel - Tisch 4  | aaaa-aaaa-aaaa   | 192.168.1.104 |
```

⚠️ **Sicherheit:** Stream-Keys sind sensibel! Nicht öffentlich teilen.

### Weitere Manager hinzufügen

Sie können andere Clubmitglieder als Manager hinzufügen:

```
1. YouTube Studio → Einstellungen
2. "Berechtigungen"
3. "Berechtigungen verwalten"
4. E-Mail-Adresse hinzufügen
5. Rolle: "Manager" oder "Editor"
```

So können mehrere Personen die Streams verwalten, ohne Zugriff auf Ihren Google-Account zu haben.

## Simultanes Streaming

Mit mehreren Kanälen können Sie **alle Tische gleichzeitig** streamen:

```
Tisch 1 → Kanal "BC Wedel - Tisch 1" → Stream läuft
Tisch 2 → Kanal "BC Wedel - Tisch 2" → Stream läuft
Tisch 3 → Kanal "BC Wedel - Tisch 3" → Stream läuft
Tisch 4 → Kanal "BC Wedel - Tisch 4" → Stream läuft
```

Alle parallel auf YouTube sichtbar!

## Kanal-Einstellungen (Empfohlen)

Für jeden Kanal:

### Basisinformationen
```
Name: BC Wedel - Tisch [Nummer]
Beschreibung: 
  "Live-Übertragung der Billard-Spiele von Tisch [Nummer]
   im Billardclub Wedel.
   
   Hier sehen Sie spannende Carambol-Partien live!"

Kanal-URL: Kann personalisiert werden (ab 100 Abonnenten)
```

### Stream-Einstellungen
```
Kategorie: Sport
Tags: Billard, Carambol, BC Wedel, Live, Tisch [Nummer]
Standard-Stream-Titel: "BC Wedel Tisch [Nummer] - Live"
Sprache: Deutsch
```

### Datenschutz
```
Standard: Öffentlich (für alle sichtbar)
Alternativ: Nicht gelistet (nur mit Link sichtbar)
```

### Thumbnail
```
Erstellen Sie ein einheitliches Thumbnail für alle Kanäle:
- Logo BC Wedel
- "Tisch [Nummer]"
- Einheitliches Design
```

## Zuschauer-Links

Teilen Sie die Links für jeden Kanal:

```
Tisch 1: https://youtube.com/@bcwedel-tisch1/live
Tisch 2: https://youtube.com/@bcwedel-tisch2/live
Tisch 3: https://youtube.com/@bcwedel-tisch3/live
Tisch 4: https://youtube.com/@bcwedel-tisch4/live
```

Oder auf Ihrer Club-Website:
```html
<h2>Live-Streams</h2>
<ul>
  <li><a href="...">Tisch 1 Live</a></li>
  <li><a href="...">Tisch 2 Live</a></li>
  <li><a href="...">Tisch 3 Live</a></li>
  <li><a href="...">Tisch 4 Live</a></li>
</ul>
```

## Troubleshooting

### Problem: "Telefonnummer bereits verwendet"

**Lösung:**
- Verwenden Sie eine andere Telefonnummer
- Oder warten Sie 12 Monate (Limit wird zurückgesetzt)
- Maximal 2 Verifizierungen pro Nummer pro Jahr

### Problem: "Live-Streaming nicht verfügbar"

**Lösung:**
- Kanal muss 24h alt sein
- Telefonnummer muss verifiziert sein
- Keine Verstöße gegen Community-Richtlinien

### Problem: "Stream-Key funktioniert nicht"

**Lösung:**
- Überprüfen Sie, dass Sie den richtigen Kanal ausgewählt haben
- Stream-Key neu generieren in YouTube Studio
- Carambus StreamConfiguration aktualisieren

## Best Practices

### 1. Konsistente Namensgebung
```
✅ "BC Wedel - Tisch 1"
✅ "BC Wedel - Tisch 2"
❌ "Tisch1", "BCW T2" (inkonsistent)
```

### 2. Dokumentation führen
```
Excel/Google Sheet mit:
- Kanal-Name
- Stream-Key (verschlüsselt!)
- Verifikations-Telefonnummer
- Raspi IP
- Erstellungsdatum
```

### 3. Regelmäßige Tests
```
- Vor Turnier: Test-Stream auf jedem Kanal
- Qualität prüfen
- Audio/Video-Sync testen
```

### 4. Backup-Plan
```
- Was wenn ein Stream ausfällt?
- Alternative Kamera bereit?
- Kontakt zu YouTube-Support?
```

## Kosten

**Gesamt: 0 €**

Alles komplett kostenlos:
- ✅ YouTube-Kanäle: kostenlos
- ✅ Live-Streaming: kostenlos
- ✅ Unbegrenzte Streaming-Zeit: kostenlos
- ✅ Unbegrenzte Zuschauer: kostenlos

Einzige Kosten: Hardware (Kameras, Raspberry Pis)

## Nächste Schritte

1. ✅ Erster Kanal eingerichtet ("BC Wedel - Tisch 1")
2. ⏳ StreamConfiguration in Carambus erstellen
3. ⏳ Ersten Test-Stream durchführen
4. ⏳ Bei Erfolg: Weitere Kanäle mit anderen Telefonnummern
5. ⏳ Alle Tische ausrüsten
6. ⏳ Simultanes Multi-Tisch-Streaming!

## Siehe auch

- [Streaming Setup](streaming-setup.de.md)
- [Streaming Quickstart](streaming-quickstart.de.md)
- [Streaming Development Setup](../developers/streaming-dev-setup.de.md)

