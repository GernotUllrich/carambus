# YouTube Streaming - Schnellstart

## 🚀 In 5 Schritten zum Live-Stream

### 1. Hardware vorbereiten (5 Min)

- [ ] **Logitech C922 Webcam** gekauft und ausgepackt
- [ ] Kamera über USB an Scoreboard-Raspi 4 angeschlossen
- [ ] Kamera über dem Tisch positioniert (Stativ/Halterung)
- [ ] Raspi 4 läuft und ist per SSH erreichbar

**Test:**
```bash
ping 192.168.1.100  # Ersetze durch deine Raspi-IP
```

---

### 2. YouTube vorbereiten (10 Min)

- [ ] YouTube Studio öffnen: [studio.youtube.com](https://studio.youtube.com)
- [ ] Navigation: **Einstellungen** → **Stream**
- [ ] **Neuen Stream-Key erstellen**
  - Name: "Tisch 1 - Meine Location"
  - Key kopieren (z.B. `xxxx-yyyy-zzzz-aaaa-bbbb`)
- [ ] ⚠️ **Wichtig:** Bei erster Aktivierung 24h warten!

---

### 3. Raspi einrichten (5 Min)

Auf dem **Location-Server** (Raspi 5):

```bash
cd /path/to/carambus_master

# SSH-Passwort setzen
export RASPI_SSH_PASSWORD=raspberry  # Dein echtes Passwort!

# Setup ausführen
rake streaming:setup[192.168.1.100]  # Deine Raspi-IP

# Prüfen ob alles OK
rake streaming:test[192.168.1.100]
```

**Erwartung:** Alle Tests ✅

---

### 4. Stream konfigurieren (3 Min)

1. **Carambus Admin-Interface** öffnen
2. Navigation → **YouTube Live Streaming**
3. **Neue Stream-Konfiguration**

**Minimal-Eingaben:**
```
Location:           [Deine Location wählen]
Tisch:              [Tisch 1]
YouTube Stream-Key: [Von YouTube kopieren]
Raspi IP:           192.168.1.100
```

**Rest:** Standard-Werte OK für C922

4. **Speichern** klicken

---

### 5. Stream starten (1 Min)

1. In der Übersicht: Tisch 1 finden
2. **▶ Start** klicken
3. Status beobachten: "Starting" → "Active"
4. YouTube Studio öffnen → Stream sollte live sein!

---

## ✅ Erfolgskontrolle

### Stream läuft korrekt wenn:

- [ ] Status im Admin-Interface: 🟢 **Active**
- [ ] Uptime zählt hoch
- [ ] YouTube Studio zeigt "Live"
- [ ] Video zeigt Billardtisch
- [ ] Scoreboard-Overlay sichtbar (Spielernamen, Score)
- [ ] Keine Fehlermeldungen

---

## 🆘 Probleme?

### "Stream startet nicht"

```bash
# Logs prüfen
ssh pi@192.168.1.100
sudo journalctl -u carambus-stream@1.service -f
```

### "Kamera nicht gefunden"

```bash
# Kamera-Geräte anzeigen
ssh pi@192.168.1.100
ls -l /dev/video*
```

Falls `/dev/video1` statt `video0`:
→ In Admin-Interface Konfiguration → Kamera-Gerät ändern

### "YouTube zeigt nichts"

- Stream-Key korrekt kopiert?
- 24h Wartezeit nach Aktivierung abgelaufen?
- Firewall/Router blockiert Port 1935?

---

## 📖 Weiterführend

Vollständige Dokumentation:
- [docs/administrators/streaming-setup.de.md](streaming-setup.md)

Befehls-Referenz:
```bash
rake streaming:help
```

---

## 🎉 Fertig!

Dein Billard-Tisch streamt jetzt live auf YouTube!

**Nächste Schritte:**
- Weitere Tische hinzufügen (repeat steps 4-5)
- Kamera-Position optimieren
- Bitrate anpassen (bei Bedarf)
- Automatischen Start aktivieren

**Viel Erfolg!** 🎱📹




