# Raspberry Pi Client Integration - Dokumentation

## Übersicht

Das Raspberry Pi Client System wurde in das Scenario Management System integriert, um die automatische Bereitstellung und Verwaltung von Kiosk-Browsern für Carambus-Scoreboards zu ermöglichen.

## Architektur

### Komponenten

1. **Scenario-Konfiguration**: Raspberry Pi Client-Einstellungen in `config.yml`
2. **Rake Tasks**: Automatisierte Setup-, Deployment- und Verwaltungs-Tasks
3. **Systemd Service**: Kiosk-Modus als System-Service
4. **Autostart Script**: Intelligentes Browser-Start-Script mit Display-Management

### Funktionsweise

```
Scenario Config → Rake Task → SSH → Raspberry Pi
     ↓              ↓         ↓         ↓
  config.yml → deploy_raspberry_pi_client → SSH Commands → Kiosk Browser
```

## Scenario-Konfiguration

### Raspberry Pi Client Konfiguration

Jedes Scenario kann Raspberry Pi Client-Einstellungen enthalten:

```yaml
environments:
  production:
    # ... andere Konfigurationen ...
    raspberry_pi_client:
      enabled: true
      ip_address: "192.168.178.92"  # Raspberry Pi IP
      ssh_user: "pi"
      ssh_password: "raspberry"
      kiosk_user: "pi"
      local_server_enabled: true  # Hostet dieser Standort einen lokalen Server?
      local_server_port: 8910
      autostart_enabled: true
      browser_restart_command: "sudo systemctl restart scoreboard-kiosk"
```

### Konfigurationsoptionen

| Option | Beschreibung | Standard |
|--------|--------------|----------|
| `enabled` | Aktiviert Raspberry Pi Client für dieses Scenario | `false` |
| `ip_address` | IP-Adresse des Raspberry Pi | - |
| `ssh_user` | SSH-Benutzername | `pi` |
| `ssh_password` | SSH-Passwort | `raspberry` |
| `kiosk_user` | Benutzer für Kiosk-Modus | `pi` |
| `local_server_enabled` | Hostet dieser Standort einen lokalen Server? | `false` |
| `local_server_port` | Port des lokalen Servers | `8910` |
| `autostart_enabled` | Automatischer Start beim Boot | `true` |
| `browser_restart_command` | Befehl zum Neustart des Browsers | `sudo systemctl restart scoreboard-kiosk` |

## Verfügbare Rake Tasks

### 1. Setup Raspberry Pi Client

```bash
rake scenario:setup_raspberry_pi_client[scenario_name]
```

**Zweck**: Initiales Setup des Raspberry Pi für Kiosk-Modus

**Schritte**:
1. Testet SSH-Verbindung
2. Installiert erforderliche Pakete (chromium-browser, wmctrl, xdotool)
3. Erstellt Kiosk-Benutzer (falls erforderlich)
4. Richtet Autostart-Konfiguration ein
5. Erstellt Systemd-Service

**Beispiel**:
```bash
rake scenario:setup_raspberry_pi_client[carambus_location_2459]
```

### 2. Deploy Raspberry Pi Client

```bash
rake scenario:deploy_raspberry_pi_client[scenario_name]
```

**Zweck**: Deployment der Kiosk-Konfiguration auf den Raspberry Pi

**Schritte**:
1. Generiert Scoreboard-URL basierend auf location_id (MD5-Hash)
2. Lädt Scoreboard-URL auf Raspberry Pi hoch
3. Lädt und installiert Autostart-Script
4. Aktiviert und startet Systemd-Service

**Beispiel**:
```bash
rake scenario:deploy_raspberry_pi_client[carambus_location_2459]
```

### 3. Restart Raspberry Pi Client

```bash
rake scenario:restart_raspberry_pi_client[scenario_name]
```

**Zweck**: Neustart des Kiosk-Browsers via SSH

**Funktionalität**:
- Führt den konfigurierten Restart-Befehl aus
- Ermöglicht schnellen Neustart ohne Raspberry Pi-Neustart
- Spart Zeit bei Tests und Updates

**Beispiel**:
```bash
rake scenario:restart_raspberry_pi_client[carambus_location_2459]
```

### 4. Test Raspberry Pi Client

```bash
rake scenario:test_raspberry_pi_client[scenario_name]
```

**Zweck**: Test der Raspberry Pi Client-Funktionalität

**Tests**:
1. SSH-Verbindung
2. Systemd-Service-Status
3. Scoreboard-URL-Datei
4. Browser-Prozess

**Beispiel**:
```bash
rake scenario:test_raspberry_pi_client[carambus_location_2459]
```

## Scoreboard-URL-Generierung

### Automatische URL-Erstellung

Das System generiert automatisch die korrekte Scoreboard-URL:

```ruby
location_id = scenario_config['scenario']['location_id']
location_md5 = Digest::MD5.hexdigest(location_id.to_s)
scoreboard_url = "http://#{webserver_host}:#{webserver_port}/locations/#{location_md5}?sb_state=welcome"
```

### Beispiel

Für `location_id: 2459`:
- MD5-Hash: `a1b2c3d4e5f6...`
- URL: `http://192.168.178.107:81/locations/a1b2c3d4e5f6...?sb_state=welcome`

## Systemd-Service

### Service-Definition

```ini
[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
```

### Service-Management

```bash
# Service aktivieren
sudo systemctl enable scoreboard-kiosk

# Service starten
sudo systemctl start scoreboard-kiosk

# Service neustarten
sudo systemctl restart scoreboard-kiosk

# Service-Status prüfen
sudo systemctl status scoreboard-kiosk
```

## Autostart-Script

### Intelligentes Browser-Management

Das generierte Autostart-Script bietet:

1. **Display-Management**: Wartet auf Display-Bereitschaft
2. **Panel-Verstecken**: Versteckt Desktop-Panels für Vollbild-Modus
3. **Browser-Optimierung**: Spezielle Chromium-Flags für Kiosk-Modus
4. **Fehlerbehandlung**: Robuste Behandlung von Display-Problemen

### Script-Features

```bash
#!/bin/bash
# Carambus Scoreboard Autostart Script

# Set display environment
export DISPLAY=:0

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Get scoreboard URL
SCOREBOARD_URL=$(cat /etc/scoreboard_url)

# Start browser in fullscreen
/usr/bin/chromium-browser \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir=/tmp/chromium-scoreboard \
  --disable-features=VizDisplayCompositor \
  --disable-dev-shm-usage \
  --app="$SCOREBOARD_URL" \
  >/dev/null 2>&1 &

# Ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true
```

## SSH-Authentifizierung

### SSH-Key-basierte Authentifizierung (Empfohlen)

Das System unterstützt sowohl SSH-Key- als auch Passwort-Authentifizierung:

```bash
# SSH-Key-Authentifizierung (passwordless)
ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no www-data@192.168.178.107 'command'

# Passwort-Authentifizierung (falls erforderlich)
sshpass -p 'password' ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no user@ip 'command'
```

### Sicherheitshinweise

- **SSH-Keys bevorzugt**: Passwordless SSH ist sicherer und praktischer
- **www-data User**: Speziell für Server-Management konfiguriert
- **Port 8910**: Nicht-Standard-Port für zusätzliche Sicherheit
- **Firewall**: Beschränke SSH-Zugriff auf vertrauenswürdige IPs

## Workflow-Beispiele

### Vollständiger Setup-Workflow

```bash
# 1. Scenario für Development vorbereiten
rake scenario:prepare_development[carambus_location_2459,development]

# 2. Scenario für Deployment vorbereiten
rake scenario:prepare_deploy[carambus_location_2459]

# 3. Server-Deployment
rake scenario:deploy[carambus_location_2459]

# 4. Raspberry Pi Client Setup
rake scenario:setup_raspberry_pi_client[carambus_location_2459]

# 5. Raspberry Pi Client Deployment
rake scenario:deploy_raspberry_pi_client[carambus_location_2459]

# 6. Test
rake scenario:test_raspberry_pi_client[carambus_location_2459]
```

### Schneller Browser-Neustart

```bash
# Browser neustarten (ohne Raspberry Pi-Neustart)
rake scenario:restart_raspberry_pi_client[carambus_location_2459]
```

### Troubleshooting

```bash
# Client-Status prüfen
rake scenario:test_raspberry_pi_client[carambus_location_2459]

# Service-Status auf Raspberry Pi prüfen
ssh pi@192.168.178.92 "sudo systemctl status scoreboard-kiosk"

# Browser-Prozesse prüfen
ssh pi@192.168.178.92 "pgrep chromium-browser"
```

## Unterschiedliche Standort-Typen

### Standort mit lokalem Server (z.B. carambus_location_2459)

- **Lokaler Server**: Läuft auf Port 8910
- **SSH-Zugriff**: Über www-data-Benutzer
- **Scoreboard-URL**: Zeigt auf lokalen Server

### Standort ohne lokalen Server (z.B. carambus_location_2460)

- **Kein lokaler Server**: Verbindet sich mit API-Server
- **SSH-Zugriff**: Über Standard-pi-Benutzer
- **Scoreboard-URL**: Zeigt auf API-Server

## Fehlerbehebung

### Häufige Probleme

1. **SSH-Verbindung fehlgeschlagen**
   - Prüfe IP-Adresse und Netzwerk-Verbindung
   - Prüfe SSH-Service-Status auf Raspberry Pi
   - Prüfe Firewall-Einstellungen

2. **Browser startet nicht**
   - Prüfe Display-Umgebung (`echo $DISPLAY`)
   - Prüfe Chromium-Installation
   - Prüfe Scoreboard-URL-Datei

3. **Vollbild-Modus funktioniert nicht**
   - Prüfe wmctrl-Installation
   - Prüfe Desktop-Umgebung (LXDE)
   - Prüfe Display-Auflösung

4. **Service startet nicht**
   - Prüfe Systemd-Service-Definition
   - Prüfe Benutzer-Berechtigungen
   - Prüfe Logs: `sudo journalctl -u scoreboard-kiosk`

### Debug-Befehle

```bash
# Service-Logs anzeigen
sudo journalctl -u scoreboard-kiosk -f

# Browser-Prozesse anzeigen
ps aux | grep chromium

# Display-Umgebung prüfen
echo $DISPLAY
xrandr

# Scoreboard-URL prüfen
cat /etc/scoreboard_url
```

## Sicherheitsüberlegungen

### Produktionsumgebung

1. **SSH-Keys verwenden**: Ersetze Passwort-Authentifizierung
2. **Firewall konfigurieren**: Beschränke SSH-Zugriff
3. **Regelmäßige Updates**: Halte Raspberry Pi OS aktuell
4. **Monitoring**: Überwache Service-Status

### Netzwerk-Sicherheit

1. **VLAN-Segmentierung**: Isoliere Kiosk-Netzwerk
2. **VPN-Zugriff**: Für Remote-Management
3. **Zertifikat-Validierung**: Für HTTPS-Verbindungen

## Zukünftige Erweiterungen

### Geplante Features

1. **SSH-Key-Authentifizierung**: Ersetze Passwort-Authentifizierung
2. **Automatische Updates**: OTA-Updates für Raspberry Pi
3. **Monitoring-Integration**: Health-Checks und Alerting
4. **Multi-Display-Support**: Unterstützung für mehrere Monitore
5. **Backup-System**: Automatische Konfigurations-Backups

### Performance-Optimierungen

1. **Browser-Caching**: Optimierte Cache-Einstellungen
2. **Display-Optimierung**: Automatische Auflösungsanpassung
3. **Startup-Optimierung**: Schnellere Boot-Zeiten

## Zusammenfassung

Das Raspberry Pi Client System bietet:

✅ **Vollständige Integration** in das Scenario Management System  
✅ **Automatisierte Bereitstellung** von Kiosk-Browsern  
✅ **SSH-basierte Verwaltung** für Remote-Operationen  
✅ **Intelligente Scoreboard-URL-Generierung** basierend auf location_id  
✅ **Robuste Browser-Verwaltung** mit Systemd-Service  
✅ **Flexible Konfiguration** für verschiedene Standort-Typen  
✅ **Umfassende Test- und Debug-Tools**  

Das System ermöglicht es, Raspberry Pi-basierte Kiosk-Clients effizient zu verwalten und in die bestehende Carambus-Infrastruktur zu integrieren.

---

## Änderungshistorie

### 2025-10-17: Kompatibilität mit Debian Trixie und Utility-Scripts

**Änderungen:**

1. **Chromium-Package-Name aktualisiert** (Commit: ca4c665)
   - Neuere Raspberry Pi OS-Versionen (Debian Trixie) verwenden `chromium` statt `chromium-browser`
   - `bin/setup-raspi-table-client.sh` angepasst:
     - Installation: `chromium` statt `chromium-browser`
     - Executable: `/usr/bin/chromium` statt `/usr/bin/chromium-browser`
   - Behebt Installationsfehler: "Package chromium-browser is not available"

2. **Neue Utility-Scripts hinzugefügt** (Commit: c304d18)
   - **`bin/check-database-states.sh`**: Umfassendes Analyse-Tool
     - Vergleicht Datenbank-Zustände zwischen Local, Production und API Server
     - Prüft Version-IDs, table_locals, tournament_locals
     - Warnt bei unbumped IDs (< 50,000,000)
     - Zeigt ID-Bereiche und lokale Daten an
     - Usage: `./bin/check-database-states.sh <scenario_name>`
   
   - **`bin/puma-wrapper.sh`**: Systemd-Service-Wrapper
     - Initialisiert rbenv korrekt für Puma-Dienst
     - Wechselt ins richtige Deployment-Verzeichnis
     - Usage: `puma-wrapper.sh <basename>` oder via `PUMA_BASENAME` Environment-Variable

3. **Scoreboard-Menu-Integration abgeschlossen**
   - Branch `scorebord_menu` erfolgreich in master integriert
   - NetworkManager-Unterstützung im Setup-Script vorhanden
   - Automatische Erkennung von dhcpcd vs. NetworkManager

**Kompatibilität:**

- ✅ Raspberry Pi OS (Debian Bullseye) - `chromium-browser` Fallback vorhanden
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primäre Unterstützung
- ✅ dhcpcd-basierte Netzwerkkonfiguration
- ✅ NetworkManager-basierte Konfiguration

**Deployment-Hinweise:**

Beim Setup auf neuen Raspberry Pi mit Debian Trixie:
```bash
sh bin/setup-raspi-table-client.sh carambus_bcw <current_ip> \
  <ssid> <password> <static_ip> <table_number> [ssh_port] [ssh_user] [server_ip]
```

Das Script erkennt automatisch:
- Den richtigen Chromium-Package-Namen
- Das verwendete Netzwerk-Management-System (dhcpcd/NetworkManager)
- Konfiguriert entsprechend WLAN und statische IP
