# Quick Start: Browser Watchdog Installation

## Problem
Samsung TV zeigt eingefrorenes Bild nach Standby - Browser kann sich nicht selbst aufwecken.

## Lösung
Automatischer Browser-Neustart via systemd Timer (OS-Level, funktioniert auch wenn Browser eingefroren ist).

## Installation (5 Minuten)

### 1. Git Pull in carambus_bcw

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/
git pull
```

### 2. Installation auf Raspberry Pi (bc-wedel)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/

# IP des Raspberry Pi anpassen!
./bin/install-browser-watchdog.sh 192.168.178.81 daily
```

**Das wars!** 🎉

## Was passiert jetzt?

- **Jeden Morgen um 6:00 Uhr** startet der Browser automatisch neu
- **±5 Minuten Randomisierung** (verhindert dass alle Clients gleichzeitig neu starten)
- **5-10 Sekunden Downtime** (schwarzer Bildschirm)
- **Frische Seite** mit aktiven WebSocket-Verbindungen

## Testen

### Option 1: Manueller Test (sofort)

```bash
# SSH auf Raspberry Pi
ssh pj@192.168.178.81

# Browser manuell neu starten
sudo /usr/local/bin/scoreboard-browser-restart.sh

# Log prüfen
tail -f /var/log/scoreboard-browser-restart.log
```

### Option 2: Timer-Test (warte bis 6:00 Uhr)

```bash
# SSH auf Raspberry Pi
ssh pj@192.168.178.81

# Timer-Status prüfen
systemctl status scoreboard-browser-restart.timer

# Nächster geplanter Run
systemctl list-timers scoreboard-browser-restart.timer

# Log morgen früh prüfen (nach 6:00 Uhr)
tail -50 /var/log/scoreboard-browser-restart.log
```

## Troubleshooting

### Timer läuft nicht

```bash
# Timer starten
sudo systemctl start scoreboard-browser-restart.timer

# Timer enablen (autostart)
sudo systemctl enable scoreboard-browser-restart.timer

# Status prüfen
systemctl status scoreboard-browser-restart.timer
```

### Log leer

```bash
# Manuell ausführen um zu sehen ob Script funktioniert
sudo /usr/local/bin/scoreboard-browser-restart.sh

# Journald Log prüfen
journalctl -u scoreboard-browser-restart.service -n 50
```

## Anpassungen

### Andere Restart-Zeit (nicht 6:00 Uhr)

```bash
# Auf Raspberry Pi
sudo nano /etc/systemd/system/scoreboard-browser-restart.timer

# Zeile ändern:
OnCalendar=*-*-* 04:00:00    # z.B. 4:00 Uhr statt 6:00 Uhr

# Speichern (Ctrl+O, Enter, Ctrl+X)

# Timer neu laden
sudo systemctl daemon-reload
sudo systemctl restart scoreboard-browser-restart.timer
```

### Health-Check statt Daily (wenn daily nicht ausreicht)

```bash
# Auf Development Machine
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/

# Health-Check Variante installieren
./bin/install-browser-watchdog.sh 192.168.178.81 healthcheck

# Prüft alle 5 Minuten ob Browser responsive ist
# Neustart nur bei echtem Problem
```

## Weitere Table-Clients

Wenn ihr mehrere Table-Raspis habt:

```bash
# Liste erstellen (IPs anpassen!)
TABLE_IPS=(
  "192.168.178.81"   # Table 1
  "192.168.178.82"   # Table 2
  "192.168.178.83"   # Table 3
)

# Installation auf allen Clients
for ip in "${TABLE_IPS[@]}"; do
  echo "Installing on $ip..."
  ./bin/install-browser-watchdog.sh "$ip" daily
done
```

## Dokumentation

Vollständige Dokumentation: `docs/internal/bug-fixes/BROWSER_WATCHDOG_SOLUTION.md`

## Support

Bei Problemen:
1. Log prüfen: `tail -f /var/log/scoreboard-browser-restart.log`
2. Timer-Status: `systemctl status scoreboard-browser-restart.timer`
3. Manuell testen: `sudo /usr/local/bin/scoreboard-browser-restart.sh`
