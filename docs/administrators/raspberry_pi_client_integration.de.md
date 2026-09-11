# Raspberry Pi Client Integration - Dokumentation

## Übersicht

Das Raspberry Pi Client System wurde in das Scenario Management System integriert, um die automatische Bereitstellung und Verwaltung von Kiosk-Browsern für Carambus-Scoreboards zu ermöglichen.

Diese Seite ist die Referenz zu den Kiosk-Rake-Tasks. Den ganzen Weg von der SD-Karte bis zum Scoreboard
beschreibt die [Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md).

Nach dem Einschalten dauert es auf einem Pi mit lokalem Server rund **3 Minuten** bis zum Scoreboard:
Desktop nach etwa 1 Minute, dann wartet das Autostart-Skript, bis der lokale Server antwortet (Puma lädt
die Anwendung vor; das Skript wartet höchstens 300 s), danach startet Chromium.

## Architektur

### Komponenten

1. **Scenario-Konfiguration**: Raspberry Pi Client-Einstellungen in `config.yml`
2. **Rake Tasks**: Automatisierte Setup-, Deployment- und Verwaltungs-Tasks
3. **Systemd Service**: Kiosk-Modus als System-Service `scoreboard-kiosk`
4. **Autostart Script**: Vom Generator in `lib/tasks/scenarios.rake` erzeugtes Browser-Start-Script

### Funktionsweise

```
Scenario Config → Rake Task → SSH → Raspberry Pi
     ↓              ↓         ↓         ↓
  config.yml → deploy_raspberry_pi_client → SSH Commands → Kiosk Browser
```

## Scenario-Konfiguration

### Raspberry Pi Client Konfiguration

Jedes Scenario kann Raspberry Pi Client-Einstellungen enthalten. Für einen Pi, der per Ansible aufgesetzt
wurde (SSH nur noch als `www-data` auf Port 8910), sieht das so aus — wie in der
[Quickstart, Schritt 3.1](raspberry-pi-quickstart.md#31-szenario-konfigurieren):

```yaml
environments:
  production:
    webserver_host: <name>.local
    ssh_host: <name>.local
    webserver_port: 3131
    ssh_port: 8910
    # ... andere Konfigurationen ...
    raspberry_pi_client:
      enabled: true
      ip_address: <name>.local          # Gerätename, keine IP-Adresse
      ssh_user: www-data
      ssh_port: 8910
      kiosk_user: <imager-benutzer>     # der im Imager angelegte Benutzer (Autologin)
      local_server_enabled: true        # Hostet dieser Pi den Server selbst?
      local_server_port: 3131
```

### Konfigurationsoptionen

| Option | Beschreibung | Standard |
|--------|--------------|----------|
| `enabled` | Aktiviert Raspberry Pi Client für dieses Scenario | aus |
| `ip_address` | SSH-Ziel des Pi (Gerätename oder IP); steht auch in `config.hosts` | - |
| `ssh_user` | SSH-Benutzername (nach Ansible: `www-data`) | - |
| `ssh_password` | Leer lassen: Anmeldung per Schlüssel. Gesetzt: Anmeldung per `sshpass` | - |
| `ssh_port` | SSH-Port (nach Ansible: 8910) | `22` |
| `kiosk_user` | Benutzer, unter dem der Kiosk läuft — muss der Autologin-Benutzer der Desktop-Sitzung sein | - |
| `local_server_enabled` | Hostet dieser Pi den Server selbst? Dann zeigt die Scoreboard-URL auf `localhost` | aus |
| `local_server_port` | Port für `config.hosts` bei `local_server_enabled`; die Scoreboard-URL nimmt `webserver_port` | - |
| `sb_state` | Anfangszustand des Scoreboards in der URL | `welcome` |
| `autostart_enabled` | Wird derzeit nicht ausgewertet | - |
| `browser_restart_command` | Befehl zum Neustart des Browsers | `sudo systemctl restart scoreboard-kiosk` |

## Verfügbare Rake Tasks

### 1. Setup Raspberry Pi Client

```bash
bin/rails "scenario:setup_raspberry_pi_client[<szenario>]"
```

**Zweck**: Initiales Setup des Raspberry Pi für Kiosk-Modus

**Schritte**:
1. Testet SSH-Verbindung
2. Installiert `chromium` (Rückfall `chromium-browser`), `wmctrl` und `xdotool`
3. Legt `kiosk_user` per `useradd` an, falls er vom SSH-Benutzer abweicht und noch nicht existiert — ein
   so angelegter Benutzer hat keine Desktop-Sitzung; der Kiosk braucht den Autologin-Benutzer
4. Schritt „Autostart-Konfiguration“ — derzeit ohne Wirkung; der Autostart läuft über den Dienst
5. Erstellt den Systemd-Service `scoreboard-kiosk`

### 2. Deploy Raspberry Pi Client

```bash
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
```

**Zweck**: Deployment der Kiosk-Konfiguration auf den Raspberry Pi

**Schritte**:
1. Erzeugt die Scoreboard-URL aus der Location (siehe unten)
2. Legt die URL auf dem **Server** (`production.ssh_host`) unter `/var/www/<basename>/shared/config/scoreboard_url` ab
3. Erzeugt das Autostart-Script und installiert es auf dem Pi als `/usr/local/bin/autostart-scoreboard.sh`
4. Aktiviert `scoreboard-kiosk` und startet ihn neu — Änderungen greifen sofort

### 3. Restart Raspberry Pi Client

```bash
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"
```

**Zweck**: Neustart des Kiosk-Browsers via SSH

**Funktionalität**:
- Führt den konfigurierten Restart-Befehl aus
- Ermöglicht schnellen Neustart ohne Raspberry Pi-Neustart
- Spart Zeit bei Tests und Updates

### 4. Test Raspberry Pi Client

```bash
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

**Zweck**: Test der Raspberry Pi Client-Funktionalität

**Tests**:
1. SSH-Verbindung
2. Systemd-Service-Status
3. Scoreboard-URL-Datei
4. Browser-Prozess

### 5. Autostart-Script ansehen

```bash
bin/rails "scenario:preview_autostart_script[<szenario>]"
```

Gibt das Script aus, das `deploy_raspberry_pi_client` installieren würde, ohne etwas zu verändern.

## Scoreboard-URL-Generierung

### Automatische URL-Erstellung

Das System generiert automatisch die korrekte Scoreboard-URL:

```ruby
location_md5 = Location.find(location_id).md5
url_host = pi_config['local_server_enabled'] ? 'localhost' : webserver_host
sb_state = pi_config['sb_state'] || 'welcome'
scoreboard_url = "http://#{url_host}:#{webserver_port}/locations/#{location_md5}/scoreboard?sb_state=#{sb_state}&locale=de"
```

Der md5-Wert kommt aus der Location in der Datenbank, nicht aus einem Hash der `location_id`.

### Beispiel

Für einen Pi mit lokalem Server:
- URL: `http://localhost:3131/locations/<md5>/scoreboard?sb_state=welcome&locale=de`

Das Autostart-Script liest die Datei `scoreboard_url` nur bei `local_server_enabled: true` (auf einem
All-in-One-Pi ist der Server der Pi selbst); ohne lokalen Server nimmt es die beim Erzeugen eingebaute URL.

## Systemd-Service

### Service-Definition

```ini
[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target

[Service]
Type=simple
User=<kiosk_user aus config.yml>
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=3

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

Das Script entsteht in `generate_autostart_script_content` (`lib/tasks/scenarios.rake`); ansehen lässt es
sich mit `preview_autostart_script`. Nicht von Hand ändern — `deploy_raspberry_pi_client` überschreibt es.

### Script-Features

- **Desktop erkennen**: Steht in `/etc/lightdm/lightdm.conf` eine labwc-Sitzung (Raspberry Pi OS 13
  „trixie“), wartet das Script auf den Wayland-Socket des Kiosk-Benutzers und startet Chromium nativ unter
  Wayland im Kiosk-Modus (`--ozone-platform=wayland --kiosk`). Beendet sich Chromium, endet das Script,
  und systemd startet den Kiosk neu.
- **Andere Desktops** (wayfire, X11): Chromium mit `--start-fullscreen`. In diesem Zweig endet der
  Chromium-Aufruf wegen einer auskommentierten Zeile vorzeitig (bekannter Fehler im Generator):
  `--disable-gpu`, das Log und das nachträgliche Vollbild per `wmctrl` greifen derzeit nicht.
- **Auf den lokalen Server warten**: Bei `local_server_enabled` fragt das Script die Scoreboard-URL im
  Sekundentakt ab, bis sie antwortet (HTTP 2xx/3xx), höchstens 300 s; danach startet der Browser trotzdem.
- **Frisches Profil**: `/tmp/chromium-scoreboard-<benutzer>` wird bei jedem Start gelöscht und neu angelegt.
- **Browser**: `chromium`, sonst `chromium-browser`. Log des labwc-Zweigs: `/tmp/chromium-kiosk.log`.

## SSH-Authentifizierung

### SSH-Key-basierte Authentifizierung (Empfohlen)

Das System unterstützt sowohl SSH-Key- als auch Passwort-Authentifizierung:

```bash
# SSH-Key-Authentifizierung (passwordless)
ssh -p 8910 -o ConnectTimeout=10 -o StrictHostKeyChecking=no www-data@<name>.local 'command'

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

Zuerst das System des Pi per Ansible: `~/DEV/ansible/RUNBOOK`, Abschnitt „NEUEN CARAMBUS-PI AUFSETZEN“
(`host_vars` per `bin/rails "scenario:generate_host_vars[<szenario>]"`, ein Aufruf von `master.yml`). Danach
aus einem carambus-Checkout, in der Reihenfolge der [Quickstart, Schritt 3.2](raspberry-pi-quickstart.md#32-deployment-ausfuhren):

```bash
# 1. Configs, Verzeichnisse, Redis, Puma-Dienst, nginx, /etc/<basename>.env
bin/rails "scenario:prepare_deploy[<szenario>]"

# 2. Development-Datenbank auf dem Admin-Rechner aus der Authority ableiten
bin/rails "scenario:prepare_development[<szenario>,development]"

# 3. Produktions-Datenbank auf den Server bringen — DESTRUKTIV
bin/rails "scenario:reset_server_db[<szenario>]"

# 4. Server-Deployment
bin/rails "scenario:deploy[<szenario>]"

# 5. Raspberry Pi Client einrichten, ausliefern, testen
bin/rails "scenario:setup_raspberry_pi_client[<szenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

!!! warning "Was man dabei wissen muss"
    - **Schritt 2** holt die globalen Daten per SSH als `www-data` aus der **Produktions-Datenbank der
      Authority** (`api.carambus.de`). Diesen Zugang haben derzeit nur die Betreiber von Carambus; für die
      Erstbefüllung braucht ein Verein (noch) den Betreiber.
    - **Schritt 2** ersetzt die lokale `carambus_api_development`, wenn die Authority neuere Daten hat
      (vorher Sicherung, danach wieder gelöscht) — das betrifft jeden Checkout, der dieselbe Datenbank
      nutzt. Im Log stehen zahlreiche `ERROR: role "www_data" does not exist` und
      `invalid command \restrict` — beides ist erwartet, der Task meldet trotzdem ✅.
    - **Schritt 3** löscht die Produktions-Datenbank auf dem Server und spielt sie neu ein. Auf einem
      frischen Pi gibt es noch keine; ohne sie scheitert der Deploy.

### Schneller Browser-Neustart

```bash
# Browser neustarten (ohne Raspberry Pi-Neustart)
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"
```

### Troubleshooting

```bash
# Client-Status prüfen
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"

# Service-Status auf Raspberry Pi prüfen
ssh -p 8910 www-data@<name>.local "sudo systemctl status scoreboard-kiosk"

# Browser-Prozesse prüfen
ssh -p 8910 www-data@<name>.local "pgrep -fa chromium"
```

## Unterschiedliche Standort-Typen

### Standort mit lokalem Server (All-in-One-Pi)

- **Lokaler Server**: nginx auf `webserver_port` (z. B. 3131)
- **SSH-Zugriff**: Über www-data-Benutzer auf Port 8910
- **Scoreboard-URL**: `http://localhost:<webserver_port>/…`; das Script wartet, bis der Server antwortet

### Standort ohne lokalen Server (reiner Client)

- **Kein lokaler Server**: `local_server_enabled: false`
- **SSH-Zugriff**: Wie in `raspberry_pi_client` konfiguriert (nach Ansible: `www-data`, Port 8910)
- **Scoreboard-URL**: `http://<webserver_host>:<webserver_port>/…`, fest ins Script eingebaut

## Fehlerbehebung

### Häufige Probleme

1. **SSH-Verbindung fehlgeschlagen**
   - Prüfe `ip_address`, `ssh_user` und `ssh_port` in `config.yml` (ohne `ssh_port` wird Port 22 benutzt)
   - Prüfe SSH-Service-Status auf Raspberry Pi
   - Prüfe Firewall-Einstellungen

2. **Browser startet nicht**
   - Prüfe die Logs: `sudo journalctl -u scoreboard-kiosk` und `sudo tail -50 /tmp/chromium-kiosk.log`
   - Prüfe Chromium-Installation
   - Prüfe Scoreboard-URL-Datei

3. **Vollbild-Modus funktioniert nicht**
   - `deploy_raspberry_pi_client` erneut ausführen (startet den Kiosk mit dem aktuellen Script neu)
   - Prüfe die Desktop-Sitzung in `/etc/lightdm/lightdm.conf` (`user-session=`)
   - Prüfe Display-Auflösung

4. **Service startet nicht**
   - Prüfe Systemd-Service-Definition
   - Prüfe, ob `kiosk_user` der Autologin-Benutzer ist
   - Prüfe Logs: `sudo journalctl -u scoreboard-kiosk`

### Debug-Befehle

```bash
# Service-Logs anzeigen
sudo journalctl -u scoreboard-kiosk -f

# Browser-Prozesse anzeigen
pgrep -fa chromium

# Chromium-Log (gehört dem Kiosk-Benutzer)
sudo tail -50 /tmp/chromium-kiosk.log

# Desktop-Sitzung prüfen
grep -E '^(user-session|autologin)' /etc/lightdm/lightdm.conf

# Scoreboard-URL prüfen
cat /var/www/<basename>/shared/config/scoreboard_url
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

*Historischer Eintrag (Stand Oktober 2025). Den Kiosk richtet man heute auch auf trixie mit den
Rake-Tasks oben ein; `bin/setup-raspi-table-client.sh` erzeugt eine eigene, ältere Kiosk-Konfiguration
ohne labwc-Unterstützung.*

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

**Kompatibilität (Stand Oktober 2025):**

- ✅ Raspberry Pi OS (Debian Bullseye) - `chromium-browser` Fallback vorhanden
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primäre Unterstützung
- ✅ dhcpcd-basierte Netzwerkkonfiguration
- ✅ NetworkManager-basierte Konfiguration

**Aufruf des Scripts:**

```bash
bin/setup-raspi-table-client.sh <szenario> <current_ip> <tisch_nr> \
  --customer-ssid <SSID> --customer-password <PW> --customer-ip <statische_IP> \
  [--dev-ssid <SSID> --dev-password <PW>] [--ssh-port <N>] [--ssh-user <U>]
```

Das Script erkennt automatisch:
- Den richtigen Chromium-Package-Namen
- Das verwendete Netzwerk-Management-System (dhcpcd/NetworkManager)
- Konfiguriert entsprechend WLAN und statische IP
