# Schnellstart: Raspberry Pi Scoreboard Installation

Komplette Installationsanleitung von leerer SD-Karte bis zu funktionierendem Scoreboard in unter 30 Minuten.

## Überblick

Diese Anleitung führt Sie durch die komplette Einrichtung eines Carambus Scoreboards auf einem Raspberry Pi, inklusive:

- ✅ Raspberry Pi OS Installation
- ✅ Ansible Konfiguration
- ✅ Server Deployment
- ✅ Client/Kiosk Einrichtung
- ✅ Automatischer Browser-Start

## Voraussetzungen

### Hardware
- Raspberry Pi 4 oder 5 (empfohlen: 4GB+ RAM)
- MicroSD-Karte (mindestens 16GB, empfohlen 32GB+)
- Netzteil (offizielles Raspberry Pi Netzteil empfohlen)
- Monitor mit HDMI-Anschluss
- Tastatur und Maus (für initiale Einrichtung)
- Netzwerkverbindung (Ethernet empfohlen, WiFi unterstützt)

### Software
- Computer mit SD-Kartenleser
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

### Erforderliche Kenntnisse
- Grundlegende Kommandozeilen-Erfahrung
- Verständnis von SSH-Verbindungen
- Grundlegende Netzwerk-Konfiguration

## Schritt 1: SD-Karte vorbereiten (5 Minuten)

### 1.1 Raspberry Pi Imager herunterladen und installieren

Download unter: https://www.raspberrypi.com/software/

### 1.2 Raspberry Pi OS flashen

1. SD-Karte in Computer einlegen
2. Raspberry Pi Imager starten
3. **Gerät auswählen:** Ihr Raspberry Pi Modell wählen
4. **Betriebssystem auswählen:** 
   - Raspberry Pi OS (64-bit) - Empfohlen
   - Oder: Raspberry Pi OS Lite (64-bit) für Headless-Setup
5. **Speicher auswählen:** Ihre SD-Karte wählen
6. **Einstellungen konfigurieren** (Zahnrad-Symbol ⚙️ klicken):
   ```
   Hostname: raspberrypi (oder Ihr bevorzugter Name)
   Benutzername: pi
   Passwort: [Ihr-sicheres-Passwort]
   WLAN: [konfigurieren falls benötigt]
   Sprache: [Ihre Zeitzone und Tastatur-Layout]
   
   ✅ SSH aktivieren
   ☐ Passwort-Authentifizierung verwenden (empfohlen für initiales Setup)
   ```
7. **Schreiben** klicken und auf Fertigstellung warten

### 1.3 Erster Start

1. SD-Karte in Raspberry Pi einlegen
2. Monitor, Tastatur und Netzwerkkabel anschließen
3. Einschalten
4. Auf Boot warten (erster Start kann 2-3 Minuten dauern)
5. IP-Adresse notieren (auf Bildschirm angezeigt oder Router prüfen)

**SSH-Zugriff überprüfen:**
```bash
ssh pi@raspberrypi.local
# oder
ssh pi@<IP-ADRESSE>
```

## Schritt 2: Ansible Konfiguration (10 Minuten)

### 2.1 Initiales Server-Setup

Die Basis-Provisionierung des Raspberry Pi (Pakete, Ruby/rbenv, PostgreSQL, Nginx, www-data-Benutzer) erfolgt über das Setup-Skript bzw. die Ansible-Rollen im `carambus_master`-Checkout:

```bash
cd carambus_master

# Variante A: Setup-Skript direkt auf dem Raspberry Pi ausführen
#   (vorher per scp/git auf den Pi übertragen)
sh bin/setup-raspberry-pi.sh

# Variante B: Ansible-Rollen aus dem ansible/-Verzeichnis
#   Hosts in ansible/hosts eintragen, dann:
cd ansible
ansible-playbook -i hosts master.yml
```

> Hinweis: Die genaue Provisionierungs-Prozedur (SSH-Härtung, rbenv, PostgreSQL,
> Nginx) ist in `ansible/RUNBOOK` dokumentiert. Es gibt **kein**
> `ansible/playbooks/raspberry_pi_server.yml` und **kein**
> `ansible/inventory/production.yml`; das Inventar liegt in `ansible/hosts`,
> die Playbooks in `ansible/master.yml` / `ansible/migrate.yml`.

Dies wird:
- ✅ System-Pakete aktualisieren
- ✅ Ruby, Rails, PostgreSQL, Nginx installieren
- ✅ PostgreSQL konfigurieren
- ✅ www-data Benutzer anlegen
- ✅ Verzeichnisstrukturen einrichten
- ✅ Firewall konfigurieren

**Dauer:** ~10 Minuten (abhängig von Netzwerkgeschwindigkeit)

## Schritt 3: Szenario deployen (10 Minuten)

### 3.1 Szenario-Konfiguration erstellen

Falls noch nicht vorhanden, Szenario-Konfiguration erstellen:

```bash
cd carambus_data/scenarios
cp -r carambus_location_template carambus_bcw  # Beispiel-Name
cd carambus_bcw
```

`config.yml` bearbeiten:
```yaml
scenario:
  name: carambus_bcw
  description: "Billardclub Wedel"
  location_id: 1
  context: NBV
  region_id: 1
  club_id: 357

environments:
  production:
    webserver_host: 192.168.178.107  # Ihre Raspberry Pi IP
    ssh_host: 192.168.178.107
    webserver_port: 3131
    ssh_port: 8910
    database_name: carambus_bcw_production
    database_username: www_data
    database_password: [sicheres-passwort]
    
    raspberry_pi_client:
      enabled: true
      ip_address: "192.168.178.107"  # Gleich wie Server (All-in-One)
      ssh_user: "www-data"
      ssh_port: 8910
      kiosk_user: "pi"
      local_server_enabled: true
      autostart_enabled: true
```

### 3.2 Vollständiges Deployment ausführen

Den Deployment-Workflow Schritt für Schritt ausführen. Es gibt **keine** einzelne `deploy_complete`-Aufgabe; das Deployment setzt sich aus den folgenden Rake-Tasks zusammen:

```bash
cd carambus_master

# 1. Deployment-Dateien vorbereiten (Configs, Credentials, Nginx/Puma)
rake "scenario:prepare_deploy[carambus_bcw]"

# 2. Server-Deployment (Capistrano + Datenbank-Restore + Service-Management)
rake "scenario:deploy[carambus_bcw]"

# 3. Raspberry Pi Client einrichten (Pakete, Kiosk-Benutzer, Systemd-Service)
rake "scenario:setup_raspberry_pi_client[carambus_bcw]"

# 4. Client-Konfiguration deployen (Scoreboard-URL, Autostart, Kiosk-Service)
rake "scenario:deploy_raspberry_pi_client[carambus_bcw]"

# 5. Client testen
rake "scenario:test_raspberry_pi_client[carambus_bcw]"
```

Diese Aufgaben erledigen zusammen:

1. **Konfigurationsdateien generieren** (Datenbank, Nginx, Puma, Credentials)
2. **Auf Server deployen** (Anwendungscode via Capistrano, Datenbank-Restore)
3. **Raspberry Pi Client einrichten** (Chromium, wmctrl, xdotool; Kiosk-Benutzer; Systemd-Service)
4. **Client-Konfiguration deployen** (Scoreboard-URL, Autostart-Skript, Kiosk-Service aktivieren/starten)
5. **Alles testen** (SSH-Verbindung, Systemd-Service, Browser-Ausführung)

**Dauer:** ~10 Minuten

Nach erfolgreichem Deployment:

```
Zugriffsinformationen:
  - Web-Interface: http://192.168.178.107:3131
  - SSH-Zugriff: ssh -p 8910 www-data@192.168.178.107

Management-Befehle:
  - Browser neustarten: rake scenario:restart_raspberry_pi_client[carambus_bcw]
  - Client testen: rake scenario:test_raspberry_pi_client[carambus_bcw]
  - Service prüfen: ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status scoreboard-kiosk'
```

## Schritt 4: Installation überprüfen (2 Minuten)

### 4.1 Web-Interface prüfen

Browser auf anderem Computer öffnen:
```
http://192.168.178.107:3131
```

### 4.2 Scoreboard-Anzeige überprüfen

Der Raspberry Pi Monitor sollte zeigen:
- ✅ Vollbild Chromium Browser
- ✅ Carambus Scoreboard Willkommensbildschirm
- ✅ Kein Desktop sichtbar (Kiosk-Modus)

### 4.3 Test von Kommandozeile

```bash
# Service-Status prüfen
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status scoreboard-kiosk'

# Browser-Prozess prüfen
ssh -p 8910 www-data@192.168.178.107 'pgrep -fa chromium'

# Logs anzeigen
ssh -p 8910 www-data@192.168.178.107 'tail -50 /tmp/chromium-kiosk.log'
```

## Fehlerbehebung

### Häufige Probleme

#### Browser startet nicht

**Logs prüfen:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo journalctl -u scoreboard-kiosk.service -n 50'
ssh -p 8910 www-data@192.168.178.107 'cat /tmp/chromium-kiosk.log'
```

**Service neu starten:**
```bash
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

#### Web-Interface nicht erreichbar

**Puma Service prüfen:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status puma-carambus_bcw'
```

**Nginx prüfen:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status nginx'
```

**Datenbankverbindung prüfen:**
```bash
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_bcw/current && RAILS_ENV=production bundle exec rails runner "puts Region.count"'
```

#### Berechtigungsfehler

Falls Berechtigungsfehler für Chromium-Profilverzeichnis auftreten:
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo rm -rf /tmp/chromium-scoreboard*'
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

## Management-Befehle

### Täglicher Betrieb

**Scoreboard-Browser neu starten:**
```bash
rake "scenario:restart_raspberry_pi_client[carambus_bcw]"
```

**Rails-Anwendung neu starten:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart puma-carambus_bcw'
```

**Anwendungs-Logs anzeigen:**
```bash
ssh -p 8910 www-data@192.168.178.107 'tail -f /var/www/carambus_bcw/shared/log/production.log'
```

**Raspberry Pi neu starten:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo reboot'
```

### Updates und Wartung

**Anwendungscode aktualisieren:**
```bash
cd carambus_master
rake "scenario:deploy[carambus_bcw]"
```

**System-Pakete aktualisieren:**
```bash
ssh -p 8910 www-data@192.168.178.107 'sudo apt update && sudo apt upgrade -y'
```

**Datenbank sichern:**
```bash
rake "scenario:create_database_dump[carambus_bcw,production]"
```

**Datenbank wiederherstellen:**
```bash
rake "scenario:restore_database_dump[carambus_bcw,production]"
```

## Erweiterte Konfiguration

### Benutzerdefinierte Port-Konfiguration

`config.yml` bearbeiten, um Ports zu ändern:
```yaml
environments:
  production:
    webserver_port: 3131  # Zu Ihrem bevorzugten Port ändern
    ssh_port: 8910        # SSH-Port bei Bedarf ändern
```

### Mehrere Standorte

Für mehrere Tische/Standorte in einem Club:
```yaml
scenario:
  location_id: 1  # Erster Tisch
  
# Separate Szenarien für jeden Tisch erstellen:
# - carambus_bcw_tisch1
# - carambus_bcw_tisch2
# - carambus_bcw_tisch3
```

### Headless-Setup (Ohne Monitor)

Für Remote-Zugriff ohne Kiosk-Modus:
```yaml
raspberry_pi_client:
  enabled: false  # Kiosk-Modus deaktivieren
```

## Architektur-Überblick

```
┌─────────────────────────────────────────────────┐
│         Raspberry Pi (All-in-One)               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │   Kiosk-Modus (Benutzer: pi)            │   │
│  │   - Chromium Browser (Vollbild)         │   │
│  │   - Systemd Service: scoreboard-kiosk   │   │
│  └─────────────────────────────────────────┘   │
│                      ↓ HTTP                     │
│  ┌─────────────────────────────────────────┐   │
│  │   Web-Server                            │   │
│  │   - Nginx (Port 3131)                   │   │
│  │   - Puma App-Server                     │   │
│  │   - Rails-Anwendung                     │   │
│  └─────────────────────────────────────────┘   │
│                      ↓                          │
│  ┌─────────────────────────────────────────┐   │
│  │   Datenbank                             │   │
│  │   - PostgreSQL                          │   │
│  │   - Datenbank: carambus_bcw_production  │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Erfolgs-Checkliste

Nach Abschluss aller Schritte überprüfen:

- [ ] Raspberry Pi startet erfolgreich
- [ ] SSH-Zugriff funktioniert
- [ ] Web-Interface aus Netzwerk erreichbar
- [ ] PostgreSQL-Datenbank läuft
- [ ] Rails-Anwendung antwortet
- [ ] Nginx-Proxy funktioniert
- [ ] Scoreboard wird auf Monitor angezeigt
- [ ] Browser startet automatisch nach Neustart
- [ ] Touch-Eingabe funktioniert (bei Touch-Display)
- [ ] Keine Fehlermeldungen in Logs

## Support

Falls Sie auf Probleme stoßen:

1. Überprüfen Sie System-Logs
2. Verifizieren Sie Netzwerk-Konfiguration
3. Prüfen Sie GitHub Issues: https://github.com/GernotUllrich/carambus/issues

## Credits

Dieser Installationsprozess wurde durch umfangreiche Tests und Automatisierung optimiert. Der komplette Workflow - von leerer SD-Karte bis zu funktionierendem Scoreboard - dauert typischerweise 25-30 Minuten.

**Schlüssel-Technologien:**
- Raspberry Pi OS (Debian)
- Ruby on Rails 7.2
- PostgreSQL 15
- Nginx
- Puma
- Chromium (Kiosk-Modus)
- Ansible
- Capistrano

---

**Letzte Aktualisierung:** Oktober 2025  
**Getestet auf:** Raspberry Pi 4 Model B (4GB), Raspberry Pi 5 (8GB)  
**OS-Version:** Raspberry Pi OS (Bookworm/Trixie, 64-bit)

