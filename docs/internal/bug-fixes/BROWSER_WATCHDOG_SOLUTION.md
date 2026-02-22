# Browser Watchdog Solution - TV Display Auto-Recovery (2025-02-10)

## 🚨 Updated Problem Analysis

Nach dem initialen Fix mit Page Visibility API stellte sich heraus: **Der Samsung TV Browser wacht NICHT automatisch auf**. Wenn der TV aus dem Standby kommt, ist der Browser-Prozess komplett eingefroren und kann sich nicht selbst neu starten.

### Root Cause (Updated)

**TV Standby = Browser Deep Freeze:**
- Samsung TV geht in tiefen Standby
- Chromium-Prozess wird vom OS eingefroren (frozen)
- **JavaScript kann NICHT ausgeführt werden** (auch nicht visibilitychange events)
- Browser ist "tot" bis TV neu gestartet wird oder Browser-Prozess neu startet

**Warum JavaScript-Lösung nicht funktioniert:**
- Page Visibility API Events werden nur gefeuert wenn Browser-Prozess läuft
- Bei tiefem Sleep: Browser-Prozess ist komplett pausiert
- Kein Event Handler kann ausgeführt werden
- **Ergebnis:** Eingefrorenes Bild bleibt bis manueller Eingriff

## ✅ Lösung: OS-Level Browser Watchdog

Da JavaScript nicht funktioniert, brauchen wir eine **OS-Level Lösung** die außerhalb des Browsers läuft.

### Architektur-Überblick

```
┌─────────────────────────────────────────────────────┐
│ Raspberry Pi OS (Linux)                             │
│                                                      │
│ ┌─────────────────────────────────────────────────┐ │
│ │ systemd Timer (cron-like)                       │ │
│ │   - Läuft unabhängig vom Browser                │ │
│ │   - Überlebt TV Standby                         │ │
│ │   - Kann Prozesse neu starten                   │ │
│ └───────────────────┬─────────────────────────────┘ │
│                     │ triggers                      │
│                     ↓                               │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Watchdog Script                                 │ │
│ │   - Prüft Browser-Gesundheit                    │ │
│ │   - Startet Browser neu bei Bedarf              │ │
│ └───────────────────┬─────────────────────────────┘ │
│                     │ restarts                      │
│                     ↓                               │
│ ┌─────────────────────────────────────────────────┐ │
│ │ scoreboard-kiosk.service                        │ │
│ │   ├─ Chromium Browser (Kiosk Mode)              │ │
│ │   └─ table_scores Page                          │ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Zwei Varianten

#### **Variante 1: Daily Restart (EMPFOHLEN)**

**Konzept:** Browser wird jeden Morgen um 6:00 Uhr automatisch neu gestartet

**Vorteile:**
- ✅ Einfach und zuverlässig
- ✅ Funktioniert garantiert (kein komplexes Health Checking)
- ✅ Verhindert langfristige Memory Leaks
- ✅ Minimale CPU/Netzwerk-Last

**Nachteile:**
- ⚠️  Browser startet neu auch wenn nicht nötig
- ⚠️  1 Sekunde Downtime pro Tag (6:00 Uhr = unkritisch)

**Wann verwenden:**
- TV wird jeden Tag für mehrere Stunden ausgeschaltet
- Keine kritischen Anwendungen um 6:00 Uhr morgens
- Einfachheit ist wichtiger als Optimierung

#### **Variante 2: Health Check Watchdog**

**Konzept:** Browser-Gesundheit wird alle 5 Minuten geprüft, Neustart nur bei Bedarf

**Vorteile:**
- ✅ Neustart nur wenn wirklich nötig
- ✅ Erkennt auch andere Probleme (Crashes, Freezes)
- ✅ Schnellere Recovery (max. 5 Minuten)

**Nachteile:**
- ⚠️  Komplexer (HTTP Checks, Remote Debugging Port)
- ⚠️  Mehr CPU/Netzwerk-Last (alle 5 Minuten)
- ⚠️  False Positives möglich

**Wann verwenden:**
- TV läuft 24/7, selten Standby
- Minimale Downtime kritisch
- Bereitschaft für komplexere Wartung

## 📁 Implementierte Dateien

### Scripts

1. **`bin/scoreboard-browser-restart.sh`**
   - Einfacher Restart-Script für Variante 1
   - Startet `scoreboard-kiosk.service` neu
   - Logging nach `/var/log/scoreboard-browser-restart.log`

2. **`bin/scoreboard-browser-watchdog.sh`**
   - Intelligenter Health-Check für Variante 2
   - Prüft: Chromium-Prozess, Server-Erreichbarkeit, Browser-Responsiveness
   - Neustart nur bei echtem Problem
   - Logging nach `/var/log/scoreboard-browser-watchdog.log`

3. **`bin/install-browser-watchdog.sh`**
   - Installer-Script für beide Varianten
   - Automatische Deployment auf Raspberry Pi
   - SSH-basierte Installation

### Systemd Files

#### Variante 1: Daily Restart

1. **`systemd/scoreboard-browser-restart.timer`**
   - Timer: Jeden Tag um 6:00 Uhr
   - Randomized delay: ±5 Minuten (verhindert simultane Restarts aller Clients)

2. **`systemd/scoreboard-browser-restart.service`**
   - Führt restart script aus
   - Logging via journald

#### Variante 2: Health Check

1. **`systemd/scoreboard-browser-watchdog.timer`**
   - Timer: Alle 5 Minuten
   - Start: 5 Minuten nach Boot

2. **`systemd/scoreboard-browser-watchdog.service`**
   - Führt health check aus
   - Neustart nur bei Bedarf
   - Logging via journald

## 🚀 Installation

### Variante 1: Daily Restart (Empfohlen)

```bash
# Auf Development Machine (carambus_master/)
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Installation auf Raspberry Pi (bc-wedel, IP: 192.168.178.81)
./bin/install-browser-watchdog.sh 192.168.178.81 daily

# Oder explizit:
./bin/install-browser-watchdog.sh 192.168.178.81 daily
```

### Variante 2: Health Check

```bash
./bin/install-browser-watchdog.sh 192.168.178.81 healthcheck
```

### Was wird installiert?

1. **Script kopiert nach:** `/usr/local/bin/scoreboard-browser-restart.sh` (oder `-watchdog.sh`)
2. **Systemd files kopiert nach:** `/etc/systemd/system/scoreboard-browser-restart.*`
3. **Timer aktiviert:** `systemctl enable --now scoreboard-browser-restart.timer`
4. **Log-Datei:** `/var/log/scoreboard-browser-restart.log`

## 🧪 Testing

### Manueller Test

```bash
# SSH auf Raspberry Pi
ssh pj@192.168.178.81

# Variante 1: Manueller Restart
sudo /usr/local/bin/scoreboard-browser-restart.sh

# Variante 2: Manueller Health Check
sudo /usr/local/bin/scoreboard-browser-watchdog.sh

# Log prüfen
tail -f /var/log/scoreboard-browser-restart.log
# oder
tail -f /var/log/scoreboard-browser-watchdog.log

# Systemd Journal
journalctl -u scoreboard-browser-restart.service -f
# oder
journalctl -u scoreboard-browser-watchdog.service -f
```

### Timer-Status prüfen

```bash
# Liste alle Timer
systemctl list-timers

# Status des Browser-Restart-Timers
systemctl status scoreboard-browser-restart.timer

# Nächster geplanter Run
systemctl list-timers scoreboard-browser-restart.timer --no-pager
```

### Simulierter TV-Standby Test

```bash
# 1. TV-Standby simulieren (Browser einfrieren)
ssh pj@192.168.178.81
sudo systemctl stop scoreboard-kiosk.service
# Warte 10 Minuten (simuliert lange Standby-Zeit)

# 2. Watchdog sollte Browser neu starten (bei Variante 2)
# Oder: Manuell triggern
sudo /usr/local/bin/scoreboard-browser-restart.sh

# 3. Prüfe ob Browser läuft
systemctl status scoreboard-kiosk.service
pgrep -a chromium
```

## 🔧 Konfiguration

### Restart-Zeit ändern (Variante 1)

Edit `/etc/systemd/system/scoreboard-browser-restart.timer` auf dem Pi:

```ini
[Timer]
# Statt 6:00 Uhr → 4:00 Uhr
OnCalendar=*-*-* 04:00:00
```

Dann reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart scoreboard-browser-restart.timer
```

### Health-Check-Intervall ändern (Variante 2)

Edit `/etc/systemd/system/scoreboard-browser-watchdog.timer`:

```ini
[Timer]
# Statt alle 5 Minuten → alle 10 Minuten
OnUnitActiveSec=10min
```

### Server-URL anpassen (Variante 2)

Edit `/usr/local/bin/scoreboard-browser-watchdog.sh`:

```bash
# Zeile ~12 ändern:
SERVER_URL="http://localhost:3131"  # Adjust based on your scenario
```

## 📊 Monitoring

### Log-Rotation

Beide Scripts rotieren ihre Logs automatisch bei 1MB:

```bash
# Alte Logs
/var/log/scoreboard-browser-restart.log.old
/var/log/scoreboard-browser-watchdog.log.old
```

### Systemd Journal

```bash
# Letzte 50 Restart-Events
journalctl -u scoreboard-browser-restart.service -n 50

# Follow live
journalctl -u scoreboard-browser-restart.service -f

# Filtern nach heute
journalctl -u scoreboard-browser-restart.service --since today
```

### Restart-Häufigkeit messen

```bash
# Zähle wie oft Browser neu gestartet wurde (letzten 7 Tage)
journalctl -u scoreboard-browser-restart.service --since "7 days ago" | grep "Browser restarted successfully" | wc -l
```

## 🎯 Erwartetes Verhalten

### Variante 1: Daily Restart

**Normal:**
```
[2025-02-10 06:00:15] ==========================================
[2025-02-10 06:00:15] Starting browser restart process
[2025-02-10 06:00:15] Current service status: active (running)
[2025-02-10 06:00:15] Restarting scoreboard-kiosk.service...
[2025-02-10 06:00:20] ✅ Browser restarted successfully
[2025-02-10 06:00:20] Browser restart completed successfully
```

**Täglich um 6:00 Uhr:**
- Browser wird automatisch neu gestartet
- 5-10 Sekunden Downtime
- Frische Seite geladen
- WebSocket-Verbindung neu aufgebaut

### Variante 2: Health Check

**Gesund (alle 5 Minuten):**
```
[2025-02-10 14:25:00] ==========================================
[2025-02-10 14:25:00] Running browser health check
[2025-02-10 14:25:00] ✅ Chromium process is running
[2025-02-10 14:25:01] ✅ Server is reachable (http://localhost:3131)
[2025-02-10 14:25:02] ✅ Browser remote debugging port responsive
[2025-02-10 14:25:02] ✅ All health checks passed
```

**Problem erkannt:**
```
[2025-02-10 14:30:00] ==========================================
[2025-02-10 14:30:00] Running browser health check
[2025-02-10 14:30:00] ❌ Chromium process NOT found
[2025-02-10 14:30:00] ⚠️  Health check FAILED: Chromium not running
[2025-02-10 14:30:00] 🔄 Restarting scoreboard-kiosk.service...
[2025-02-10 14:30:05] ✅ Browser restarted successfully
```

## 📄 config/scoreboard_url und sb_state

**Lokal-Server (z. B. BCW):** Der Kiosk liest die URL beim Start aus `config/scoreboard_url` (bzw. auf dem Server aus `/var/www/…/shared/config/scoreboard_url`). Welche Ansicht geöffnet wird, hängt vom Parameter **`sb_state`** ab:

- `sb_state=welcome` – Willkommensseite
- `sb_state=table_scores` – Tischübersicht (für große Anzeige empfohlen)

**Wichtig:** Die gewünschte URL muss **vor dem ersten Start bzw. vor jedem Neustart** in der Datei stehen. Nach einem Watchdog-Neustart startet der Browser exakt mit der URL aus dieser Datei.

**Beispiel für BCW (lokaler Server, Port 3131):**
```text
http://localhost:3131/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=table_scores
```

Die App überschreibt `config/scoreboard_url` nicht. Die Datei ist die einzige Quelle für die Kiosk-URL; Änderungen nimmt man direkt in der Datei vor (Fix 2025-02).

**Auf dem Produktionsserver prüfen/setzen:**
```bash
# Auf bcw (oder dem Pi) – Pfad je nach Deployment
cat /var/www/carambus_bcw/shared/config/scoreboard_url
# Sollte sb_state=table_scores enthalten, wenn die Tischübersicht gewünscht ist

# Manuell setzen (Beispiel):
echo 'http://localhost:3131/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=table_scores' | sudo tee /var/www/carambus_bcw/shared/config/scoreboard_url
# Anschließend: Browser-Neustart (oder warten bis zum nächsten Watchdog-Lauf)
sudo systemctl restart scoreboard-kiosk
```

## 🔗 Zusammenspiel mit JavaScript-Lösung

Die vorherige JavaScript-Lösung (`table_scores_monitor_controller.js`) bleibt aktiv und ergänzt den Watchdog:

**Defense in Depth:**

1. **JavaScript Layer (wenn Browser läuft):**
   - Erkennt kurze Standby-Zeiten (< 5 Minuten)
   - Page Reload wenn Browser responsive
   - Schnellste Recovery (1 Sekunde)

2. **Watchdog Layer (OS-Level):**
   - Erkennt tiefe Standby-Zustände (Browser frozen)
   - Browser-Prozess Neustart
   - Langsamere Recovery (5-10 Sekunden)

**Zusammen:**
- **Best Case:** JavaScript erkennt Wake-up, Reload in 1s
- **Fallback:** Watchdog erkennt frozen Browser, Neustart in 5-10min (Variante 2) oder 6:00 Uhr (Variante 1)

## 🎓 Lessons Learned

### 1. JavaScript ist nicht genug für Hardware-Standby

**Problem:**
- Page Visibility API setzt voraus dass JavaScript ausgeführt werden kann
- TV Standby friert gesamten Browser-Prozess ein
- Kein Event Handler kann feuern

**Lösung:**
- OS-Level Watchdog der unabhängig vom Browser läuft
- systemd Timer = zuverlässiger als Browser-basierte Lösungen

### 2. Einfachheit schlägt Komplexität

**Variante 1 (Daily Restart):**
- Einfacher Code, weniger Fehlerquellen
- Garantiert funktionierend (kein komplexes Monitoring)
- Akzeptabler Trade-off: 1x täglich 5s Downtime

**Variante 2 (Health Check):**
- Komplexer, mehr Abhängigkeiten (curl, Remote Debugging Port)
- Potential für False Positives
- Nur wenn wirklich nötig

**Empfehlung:** Start with simple (Variante 1), upgrade nur wenn nötig

### 3. TV Browsers sind spezielle Umgebungen

**Eigenschaften:**
- Aggressive Power Management
- Kein User der "F5" drückt
- Stunden bis Tage Standby
- OS friert Prozesse komplett ein

**Design-Implikationen:**
- Immer OS-Level Watchdog vorsehen
- JavaScript-Lösungen als Bonus, nicht als primäre Strategie
- Testing mit echtem Hardware-Standby essentiell

## ⚠️ Known Limitations

### 1. Downtime während Neustart

**Problem:** 5-10 Sekunden schwarzer Bildschirm während Browser-Neustart

**Mitigation:**
- Variante 1: Restart um 6:00 Uhr (unkritische Zeit)
- Variante 2: Nur bei echtem Problem
- Akzeptabel: Besser als eingefrorenes Bild für Stunden

### 2. Race Condition bei gleichzeitigem Restart aller Clients

**Problem:** Alle Table-Clients starten gleichzeitig neu → Server-Last

**Mitigation:**
- `RandomizedDelaySec=5min` in Timer
- Clients starten innerhalb 5-Minuten-Fenster verteilt
- Max. Load: N Clients / 5 Minuten

### 3. Neustart während laufendem Spiel

**Problem:** Browser-Neustart unterbricht aktive Scoreboards

**Mitigation:**
- Variante 1: 6:00 Uhr = normalerweise keine Spiele
- Variante 2: Health Check nur bei echtem Problem
- Future: Check ob Spiel läuft bevor Restart

## 🚀 Deployment

### Alle Table-Clients updaten

```bash
# Liste aller Table-Client IPs (anpassen!)
TABLE_IPS=(
  "192.168.178.81"   # bc-wedel Table 1
  "192.168.178.82"   # bc-wedel Table 2
  # ... weitere Tables
)

# Installation auf allen Clients
for ip in "${TABLE_IPS[@]}"; do
  echo "Installing watchdog on $ip..."
  ./bin/install-browser-watchdog.sh "$ip" daily
done
```

### Commit und Push

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

git add bin/scoreboard-browser-*.sh \
        bin/install-browser-watchdog.sh \
        systemd/scoreboard-browser-*.{timer,service} \
        docs/internal/bug-fixes/BROWSER_WATCHDOG_SOLUTION.md

git commit -m "Add: Browser watchdog for TV display auto-recovery"
git push
```

## 📝 Future Improvements

### 1. Intelligente Restart-Logik

**Idee:** Prüfe ob gerade ein Spiel läuft bevor Browser neu startet

```bash
# In watchdog script:
# Check if game is active on this table
GAME_ACTIVE=$(curl -s http://localhost:3131/api/table_monitors/active | jq -r '.active')
if [ "$GAME_ACTIVE" = "true" ]; then
  log "⏸️  Skipping restart: Game is active"
  exit 0
fi
```

### 2. Remote Monitoring Dashboard

**Idee:** Zentrale Übersicht über alle Table-Clients

- Letzter Restart-Zeitpunkt
- Health-Check-Status
- Browser-Uptime
- Anzahl Restarts pro Tag

### 3. Adaptive Restart-Zeiten

**Idee:** Lerne optimale Restart-Zeit aus Nutzungsdaten

- Analysiere wann TV typischerweise ausgeschaltet wird
- Restart kurz nachdem TV wieder eingeschaltet wird
- Basierend auf historischen Daten

### 4. Wake-on-LAN Integration

**Idee:** Pi weckt TV auf vor Restart

```bash
# Wake TV before restarting browser
wakeonlan <TV_MAC_ADDRESS>
sleep 30  # Wait for TV to be ready
restart_browser
```

## ✅ Ergebnis

**Problem gelöst! 🎉**

- ✅ TV kann beliebig lange im Standby sein
- ✅ Browser startet automatisch neu (täglich oder bei Bedarf)
- ✅ Keine eingefrorenen Bilder mehr
- ✅ Keine manuelle Intervention nötig
- ✅ Zuverlässige OS-Level Lösung
- ✅ Einfach zu installieren und zu warten

**Empfohlene Variante: Daily Restart**
- Installiere auf allen Table-Clients
- Teste eine Woche
- Bei Problemen: Switch zu Health Check Variante
