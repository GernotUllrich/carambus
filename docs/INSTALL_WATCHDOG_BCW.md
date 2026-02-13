# Browser Watchdog Installation für BC-Wedel Server

## Server Info

- **Host:** bc-wedel.duckdns.org (192.168.2.210)
- **System:** Raspberry Pi 5 Model B
- **Service:** scoreboard-kiosk.service (bereits vorhanden!)
- **Display:** Große Übersichtstafel (table_scores)
- **SSH:** Port 8910, User: www-data

## Quick Installation (2 Minuten)

### 1. Git Pull

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/
git pull
```

### 2. Installation auf bc-wedel

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/

# WICHTIG: SSH-User für bc-wedel ist "www-data", nicht "pj"!
# Daher manuell installieren:

# Script anpassen für www-data user
./bin/install-browser-watchdog.sh bc-wedel.duckdns.org daily
```

**ODER manuell (wegen Custom SSH Port 8910):**

```bash
# 1. Scripts hochladen
scp -P 8910 bin/scoreboard-browser-restart.sh www-data@bc-wedel.duckdns.org:/tmp/
ssh -p 8910 www-data@bc-wedel.duckdns.org "sudo mv /tmp/scoreboard-browser-restart.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/scoreboard-browser-restart.sh"

# 2. Systemd files hochladen
scp -P 8910 systemd/scoreboard-browser-restart.timer www-data@bc-wedel.duckdns.org:/tmp/
scp -P 8910 systemd/scoreboard-browser-restart.service www-data@bc-wedel.duckdns.org:/tmp/
ssh -p 8910 www-data@bc-wedel.duckdns.org "sudo mv /tmp/scoreboard-browser-restart.* /etc/systemd/system/"

# 3. Timer aktivieren
ssh -p 8910 www-data@bc-wedel.duckdns.org "sudo systemctl daemon-reload && sudo systemctl enable scoreboard-browser-restart.timer && sudo systemctl start scoreboard-browser-restart.timer"

# 4. Status prüfen
ssh -p 8910 www-data@bc-wedel.duckdns.org "systemctl list-timers scoreboard-browser-restart.timer"
```

## Manueller Test

```bash
# SSH auf Server
ssh -p 8910 www-data@bc-wedel.duckdns.org

# Browser manuell neu starten (testet ob Script funktioniert)
sudo /usr/local/bin/scoreboard-browser-restart.sh

# Log prüfen
tail -f /var/log/scoreboard-browser-restart.log

# Timer-Status
systemctl status scoreboard-browser-restart.timer

# Nächster geplanter Run
systemctl list-timers scoreboard-browser-restart.timer
```

## Was passiert jetzt?

- **Jeden Morgen um 6:00 Uhr** (±5 Minuten):
  - Browser auf großer Übersichtstafel startet neu
  - Frische `table_scores` Seite
  - Aktive WebSocket-Verbindungen

- **Bei TV-Standby:**
  - TV kann beliebig lange aus sein
  - Morgens automatischer Browser-Neustart
  - Immer aktuelle Daten sichtbar

## Troubleshooting

### Timer läuft nicht

```bash
ssh -p 8910 www-data@bc-wedel.duckdns.org

# Timer starten
sudo systemctl start scoreboard-browser-restart.timer

# Timer enablen
sudo systemctl enable scoreboard-browser-restart.timer

# Status
systemctl status scoreboard-browser-restart.timer
```

### Log prüfen

```bash
# Direkt via SSH
ssh -p 8910 www-data@bc-wedel.duckdns.org "tail -50 /var/log/scoreboard-browser-restart.log"

# Journald
ssh -p 8910 www-data@bc-wedel.duckdns.org "journalctl -u scoreboard-browser-restart.service -n 50"
```

### Restart-Zeit ändern

```bash
ssh -p 8910 www-data@bc-wedel.duckdns.org

# Timer-Datei editieren
sudo nano /etc/systemd/system/scoreboard-browser-restart.timer

# Zeile ändern (z.B. 4:00 Uhr statt 6:00 Uhr):
OnCalendar=*-*-* 04:00:00

# Speichern und reload
sudo systemctl daemon-reload
sudo systemctl restart scoreboard-browser-restart.timer
```

## Bestehender Service

bc-wedel hat bereits den `scoreboard-kiosk` Service konfiguriert:

```yaml
# Aus config.yml:
browser_restart_command: sudo systemctl restart scoreboard-kiosk
kiosk_user: pi
sb_state: table_scores
```

Der Watchdog nutzt genau diesen Service und startet ihn automatisch neu!

## Ergebnis

- ✅ Große Übersichtstafel friert nicht mehr ein
- ✅ Automatischer Browser-Neustart täglich um 6:00 Uhr
- ✅ Kein manueller Eingriff mehr nötig
- ✅ Immer aktuelle Spieldaten sichtbar
