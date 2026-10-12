# YouTube Streaming - Schnellstart

## 🚀 In 5 Schritten zum Live-Stream

### 1. Hardware vorbereiten (5 Min)

- [ ] **Logitech C922 Webcam** gekauft und ausgepackt
- [ ] Kamera über USB an Scoreboard-Raspi 4 angeschlossen
- [ ] Kamera über dem Tisch positioniert (Stativ/Halterung)
- [ ] Raspi 4 läuft und ist per SSH erreichbar

**Test:**
```bash
ping <IP des Scoreboard-Pis>
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

Auf dem **Location-Server**, im Deploy-Verzeichnis des Szenarios (die Tasks brauchen dessen Datenbank):

```bash
cd /var/www/<basename>/current

# SSH-Zugang zum Scoreboard-Pi (per Ansible eingerichtete Pis: www-data, Port 8910)
export RASPI_SSH_USER=www-data
export RASPI_SSH_PORT=8910

# Setup ausführen
RAILS_ENV=production bundle exec rake "streaming:setup[<IP des Scoreboard-Pis>]"

# Prüfen ob alles OK
RAILS_ENV=production bundle exec rake "streaming:test[<IP des Scoreboard-Pis>]"
```

**Erwartung:** Alle Tests ✅

**Vor dem ersten Start, einmalig** (Details: [Setup, Abschnitt Raspberry Pi vorbereiten](streaming-setup.md#1-raspberry-pi-vorbereiten)):

- [ ] `www-data` auf dem Location-Server hat einen SSH-Schlüssel, und dessen öffentlicher Teil steht auf dem
      Scoreboard-Pi in `~/.ssh/authorized_keys`. Der Start-Knopf verbindet sich als Carambus-Dienst; ein
      `export` in der Shell erreicht ihn nicht
- [ ] In `/etc/<basename>.env` steht `STREAMING_SERVER_URL=http://<IP des Location-Servers>:<webserver_port>`,
      danach `sudo systemctl restart puma-<basename>`. Ohne diesen Eintrag holt der Pi den Overlay-Text von
      `http://localhost:3131`. Das ist nur richtig, wenn der Scoreboard-Pi selbst der Server auf Port 3131 ist

---

### 4. Stream konfigurieren (3 Min)

1. **Carambus Admin-Interface** öffnen
2. Admin-Navigation → **Stream-Konfigurationen** (Seite „YouTube Live Streaming“)
3. **Neue Stream-Konfiguration**

**Minimal-Eingaben:**
```
Tisch:              [Tisch wählen, nach Location gruppiert]
YouTube Stream-Key: [Von YouTube kopieren]
Raspi IP:           <IP des Scoreboard-Pis>  (wird vom Tisch übernommen)
SSH-User:           www-data                 (Standard im Formular: pi)
SSH-Port:           8910                     (Standard im Formular: 22)
```

**Rest:** Standard-Werte (640x360, 30 fps, 1000 kbit/s) sind der empfohlene Start für einen Pi 4

4. **Speichern** klicken. Die Konfiguration steht jetzt in der Datenbank; auf den Pi kommt sie beim Start
5. SSH-Zugang prüfen:
   ```bash
   RAILS_ENV=production bundle exec rake "streaming:ssh_test[<TABLE_ID>]"
   ```
   `<TABLE_ID>` ist die Datenbank-ID des Tischs (`Table.id`), nicht die Nummer aus „Tisch 1“

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
# Logs prüfen (Skript und FFmpeg schreiben in Dateien, nicht ins Journal)
ssh -p 8910 www-data@<IP des Scoreboard-Pis>
tail -f /var/log/carambus/stream-table-<TABLE_ID>.log
tail -f /var/log/carambus/stream-table-<TABLE_ID>-error.log
```

Meldet das Admin-Interface „Authentication failed“: SSH-Schlüssel von `www-data` fehlt auf dem Pi (Schritt 3).
Gibt es auf dem Pi keinen Benutzer `pi`, startet der Dienst nicht: Die Unit setzt fest `User=pi`
(siehe [Setup](streaming-setup.md#1-raspberry-pi-vorbereiten)).

### "Kamera nicht gefunden"

```bash
# Kamera-Geräte anzeigen
ssh -p 8910 www-data@<IP des Scoreboard-Pis>
ls -l /dev/video*
```

Falls `/dev/video1` statt `video0`:
→ In Admin-Interface Konfiguration → Kamera-Gerät ändern

### "Overlay zeigt nur „Loading...“"

- `STREAMING_SERVER_URL` gesetzt (Schritt 3)?
- Ist der nginx-Bot-Block aktiv, weist er den `curl`-Abruf des Pis ab. Siehe
  [Setup, Overlay-Einstellungen](streaming-setup.md#4-overlay-einstellungen)

### "YouTube zeigt nichts"

- Stream-Key korrekt kopiert?
- 24h Wartezeit nach Aktivierung abgelaufen?
- Firewall/Router blockiert Port 1935?

---

## 📖 Weiterführend

Vollständige Dokumentation:
- [Streaming Setup & Betrieb](streaming-setup.md)

Befehls-Referenz (auf dem Location-Server):
```bash
RAILS_ENV=production bundle exec rake streaming:help
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




