# Raspberry Pi Management Scripts

Diese Dokumentation beschreibt alle verfügbaren Scripts für die Verwaltung von Raspberry Pi Clients im Carambus-System.

## Überblick

Die Raspberry Pi Scripts befinden sich in `carambus_master/bin/` und decken folgende Bereiche ab:
- **Setup & Installation**: Vollständige Einrichtung neuer RasPi-Clients
- **Testing & Debugging**: Netzwerk-Scans und Funktionsprüfungen
- **Scoreboard Management**: Kiosk-Mode und Browser-Steuerung
- **Utilities**: SSH-Setup, SD-Karten-Vorbereitung

---

## Setup & Installation

### `setup-raspberry-pi.sh`
**Zweck**: Vollständige Einrichtung eines Raspberry Pi als Carambus-Client

**Verwendung**:
```bash
cd carambus_master
./bin/setup-raspberry-pi.sh <scenario_name>
```

**Was wird gemacht**:
1. ✅ Installiert erforderliche Pakete (chromium, wmctrl, xdotool)
2. ✅ Erstellt Kiosk-Benutzer
3. ✅ Richtet systemd-Service ein
4. ✅ Konfiguriert Autostart für Scoreboard
5. ✅ Startet Kiosk-Mode

**Voraussetzungen**:
- SSH-Zugang zum Raspberry Pi
- Scenario-Konfiguration in `carambus_data/scenarios/<scenario_name>/config.yml`
- Raspberry Pi läuft bereits mit OS

**Dokumentiert in**: [Client-Only Installation](raspberry-pi-client.de.md)

**Beispiel**:
```bash
./bin/setup-raspberry-pi.sh carambus_location_5101
# Richtet RasPi für Location 5101 ein
```

---

### `install-client-only.sh`
**Zweck**: Installation eines reinen Client-Systems (ohne lokalen Server)

**Verwendung**:
```bash
./bin/install-client-only.sh <scenario_name>
```

**Was wird gemacht**:
1. ✅ Konfiguriert Browser-Kiosk-Mode
2. ✅ Richtet Autostart für Scoreboard ein
3. ✅ Verbindet mit Remote-Server (kein lokaler Puma)
4. ✅ Optimiert für minimale Ressourcennutzung

**Use Case**: Tablet oder RasPi, das nur als Display dient

**Dokumentiert in**: [Client-Only Installation](raspberry-pi-client.de.md)

---

### `install-scoreboard-client.sh`
**Zweck**: Installiert Scoreboard-Client-Software

**Verwendung**:
```bash
./bin/install-scoreboard-client.sh
```

**Was wird gemacht**:
- Installiert Client-Dependencies
- Konfiguriert Browser für Fullscreen
- Richtet Autostart ein

---

### `setup-phillips-table-ssh.sh`
**Zweck**: SSH-Zugang für Phillips Table einrichten

**Verwendung**:
```bash
./bin/setup-phillips-table-ssh.sh
```

**Was wird gemacht**:
1. ✅ Generiert SSH-Schlüssel
2. ✅ Kopiert Public Key zum RasPi
3. ✅ Konfiguriert passwordless SSH
4. ✅ Testet Verbindung

**Voraussetzungen**:
- Initiales Passwort für RasPi bekannt
- Netzwerkzugriff auf RasPi

**Beispiel**:
```bash
./bin/setup-phillips-table-ssh.sh
# Interaktiv: Fragt nach IP, Port, Passwort
```

---

## Testing & Debugging

### `find-raspberry-pi.sh`
**Zweck**: Findet Raspberry Pis im lokalen Netzwerk

**Verwendung**:
```bash
./bin/find-raspberry-pi.sh [subnet]
```

**Was wird gemacht**:
- Scannt Netzwerk nach RasPi-Hosts
- Zeigt IP-Adressen und Hostnamen
- Prüft SSH-Verfügbarkeit

**Beispiele**:
```bash
# Standard-Scan im lokalen Netzwerk
./bin/find-raspberry-pi.sh

# Spezifisches Subnetz scannen
./bin/find-raspberry-pi.sh 192.168.178.0/24
```

**Output-Beispiel**:
```
Scanning for Raspberry Pis in 192.168.178.0/24...
Found: 192.168.178.107 (raspberrypi.local)
  SSH: Available (Port 8910)
  Service: puma-carambus_location_5101
```

---

### `test-raspberry-pi.sh`
**Zweck**: Umfassende Tests für RasPi-Funktionalität

**Verwendung**:
```bash
./bin/test-raspberry-pi.sh <scenario_name>
```

**Was wird getestet**:
1. ✅ SSH-Verbindung
2. ✅ Puma-Service-Status
3. ✅ Nginx-Konfiguration
4. ✅ Datenbank-Konnektivität
5. ✅ Scoreboard-Erreichbarkeit
6. ✅ Browser-Kiosk-Mode

**Beispiel**:
```bash
./bin/test-raspberry-pi.sh carambus_location_5101
# Führt alle Tests aus und zeigt Ergebnisse
```

---

### `test-raspberry-pi-restart.sh`
**Zweck**: Testet RasPi-Restart-Funktionalität

**Verwendung**:
```bash
./bin/test-raspberry-pi-restart.sh <scenario_name>
```

**Was wird getestet**:
- Restart-Command funktioniert
- Services starten korrekt nach Reboot
- Scoreboard startet automatisch

---

## Scoreboard Management

### `start-scoreboard.sh`
**Zweck**: Startet Scoreboard im Kiosk-Mode

**Verwendung**:
```bash
# Auf dem RasPi:
./bin/start-scoreboard.sh [url]

# Remote von Development-Rechner:
ssh pi@raspberrypi.local '/path/to/start-scoreboard.sh'
```

**Was wird gemacht**:
1. ✅ Startet Chromium im Fullscreen-Mode
2. ✅ Öffnet Scoreboard-URL
3. ✅ Versteckt Panel/Taskbar
4. ✅ Deaktiviert Screensaver

**Voraussetzungen**:
- X11-Display verfügbar
- Chromium installiert

---

### `autostart-scoreboard.sh`
**Zweck**: Scoreboard-Autostart-Konfiguration

**Verwendung**:
```bash
./bin/autostart-scoreboard.sh <scenario_name>
```

**Was wird gemacht**:
- Erstellt systemd-Service
- Konfiguriert Autostart bei Boot
- Wartet auf Puma-Server
- Startet Browser automatisch

**Dokumentiert in**: [Scoreboard Autostart Setup](scoreboard-autostart.de.md)

---

### `restart-scoreboard.sh`
**Zweck**: Neustart des Scoreboard-Browsers

**Verwendung**:
```bash
# Lokal auf RasPi:
./bin/restart-scoreboard.sh

# Remote via SSH:
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

**Was wird gemacht**:
1. ✅ Beendet laufende Chromium-Prozesse
2. ✅ Bereinigt Cache
3. ✅ Startet Browser neu mit Scoreboard-URL

**Use Cases**:
- Browser hängt oder ist langsam
- Nach Software-Update
- Nach Änderung der Scoreboard-URL

---

### `exit-scoreboard.sh`
**Zweck**: Beendet Scoreboard-Kiosk-Mode sauber

**Verwendung**:
```bash
./bin/exit-scoreboard.sh
```

**Was wird gemacht**:
- Beendet Chromium-Prozesse
- Zeigt Panel/Taskbar wieder
- Bereinigt temporäre Dateien

---

### `cleanup-chromium.sh`
**Zweck**: Bereinigt Chromium-Cache und temporäre Dateien

**Verwendung**:
```bash
./bin/cleanup-chromium.sh
```

**Was wird gemacht**:
- Löscht Browser-Cache
- Entfernt Cookies
- Bereinigt Downloads
- Löscht Crash-Reports

**Use Cases**:
- Browser wird langsam
- Zu wenig Speicherplatz
- Nach längerer Laufzeit

---

## Utilities

### `prepare-sd-card.sh`
**Zweck**: Bereitet SD-Karte für RasPi-Installation vor

**Verwendung**:
```bash
./bin/prepare-sd-card.sh [device]
```

**Was wird gemacht**:
1. ⚠️ Formatiert SD-Karte (ACHTUNG: Alle Daten werden gelöscht!)
2. ✅ Installiert Raspberry Pi OS
3. ✅ Konfiguriert SSH
4. ✅ Konfiguriert WLAN (optional)
5. ✅ Erstellt Basis-Konfiguration

**Voraussetzungen**:
- SD-Karte eingelegt
- Raspberry Pi OS Image heruntergeladen
- Admin-Rechte (sudo)

**Beispiel**:
```bash
# Liste verfügbare Devices
diskutil list

# Bereite SD-Karte vor
sudo ./bin/prepare-sd-card.sh /dev/disk2
```

**⚠️ WARNUNG**: Überprüfen Sie das Device sorgfältig! Falsches Device führt zu Datenverlust.

---

## Legacy/Deprecated Scripts

### `quick-start-raspberry-pi.sh` ⚠️
**Status**: Obsolet (durch `setup-raspberry-pi.sh` ersetzt)

### `auto-setup-raspberry-pi.sh` ⚠️
**Status**: Obsolet (durch `setup-raspberry-pi.sh` ersetzt)

### `start_scoreboard` ⚠️
**Status**: Obsolet (durch `start-scoreboard.sh` ersetzt)

### `start_scoreboard_delayed` ⚠️
**Status**: Obsolet (durch `autostart-scoreboard.sh` ersetzt)

---

## Workflow-Beispiele

### Neuer Raspberry Pi komplett einrichten

```bash
# 1. SD-Karte vorbereiten
sudo ./bin/prepare-sd-card.sh /dev/disk2

# 2. RasPi booten und im Netzwerk finden
./bin/find-raspberry-pi.sh

# 3. SSH-Zugang einrichten
./bin/setup-phillips-table-ssh.sh
# IP: 192.168.178.107
# Port: 22
# Password: [initiales Passwort]

# 4. Vollständige Installation
./bin/setup-raspberry-pi.sh carambus_location_5101

# 5. Testen
./bin/test-raspberry-pi.sh carambus_location_5101
```

### Browser-Probleme beheben

```bash
# 1. Chromium-Cache bereinigen
ssh -p 8910 www-data@192.168.178.107 './bin/cleanup-chromium.sh'

# 2. Browser neustarten
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'

# 3. Falls immer noch Probleme: Service neustarten
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart scoreboard-kiosk'
```

### Scenario-Update auf RasPi deployen

```bash
# 1. Deployment von Development-Rechner
cd carambus_master
./bin/deploy-scenario.sh carambus_location_5101

# 2. Browser auf RasPi neustarten (um neue Assets zu laden)
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'

# 3. Testen
./bin/test-raspberry-pi.sh carambus_location_5101
```

---

## Fehlerbehebung

### SSH-Verbindung schlägt fehl
```bash
# Problem: "Connection refused"
# Lösung: SSH manuell auf RasPi aktivieren
# 1. Monitor + Tastatur an RasPi anschließen
# 2. sudo raspi-config
# 3. Interface Options → SSH → Enable

# Problem: "Permission denied (publickey)"
# Lösung: SSH-Keys neu einrichten
./bin/setup-phillips-table-ssh.sh
```

### Browser startet nicht
```bash
# Problem: "Display not available"
# Lösung: X11-Display prüfen
ssh -p 8910 www-data@raspberrypi 'echo $DISPLAY'
# Sollte ":0" sein

# Falls nicht gesetzt:
ssh -p 8910 www-data@raspberrypi 'export DISPLAY=:0 && ./bin/start-scoreboard.sh'
```

### Scoreboard zeigt alte Version
```bash
# Cache bereinigen und Browser neustarten
ssh -p 8910 www-data@raspberrypi './bin/cleanup-chromium.sh && ./bin/restart-scoreboard.sh'

# Falls das nicht hilft: Hard-Reload im Browser
# Strg+Shift+R oder systemctl restart
```

---

## Best Practices

### RasPi-Setup
1. ✅ Immer zuerst `find-raspberry-pi.sh` verwenden, um IP zu ermitteln
2. ✅ SSH-Keys einrichten (passwordless) für Automatisierung
3. ✅ Nach jedem Deployment Browser neustarten
4. ✅ Regelmäßig Chromium-Cache bereinigen

### Netzwerk
1. ✅ Statische IP für Production-RasPis verwenden
2. ✅ SSH-Port ändern (Standard: 8910 statt 22)
3. ✅ Firewall auf RasPi konfigurieren

### Wartung
1. ✅ Wöchentlich: `cleanup-chromium.sh` ausführen
2. ✅ Monatlich: OS-Updates via `apt update && apt upgrade`
3. ✅ Bei Problemen: Zuerst Browser-Restart, dann Service-Restart, dann Reboot

---

## Siehe auch

- [Client-Only Installation](raspberry-pi-client.de.md) - Detaillierte Installationsanleitung
- [Scoreboard Autostart Setup](scoreboard-autostart.de.md) - Autostart-Konfiguration
- [Deployment Workflow](../developers/deployment-workflow.de.md) - Vollständiger Deployment-Prozess
- [Scenario Management](../developers/scenario-management.de.md) - Scenario-System-Übersicht






