# Systemadministrator-Dokumentation

Willkommen zur Carambus-Dokumentation für Systemadministratoren! Hier finden Sie alle Informationen zur Installation, Konfiguration und Wartung des Systems.

## 🎯 Ihre Rolle als Systemadministrator

Als Systemadministrator sind Sie verantwortlich für:
- 🖥️ **Installation**: System aufsetzen und in Betrieb nehmen
- ⚙️ **Konfiguration**: System an Ihre Anforderungen anpassen
- 🔐 **Sicherheit**: System absichern und Backups verwalten
- 📊 **Monitoring**: Performance überwachen und Probleme erkennen
- 🔄 **Updates**: System aktuell und sicher halten
- 🆘 **Support**: Technische Probleme für Benutzer lösen

## 🚀 Schnellstart nach Deployment-Option

Wählen Sie Ihre Deployment-Variante:

### Option 1: Raspberry Pi All-in-One (Empfohlen für Einzelvereine)
**Setup-Zeit**: ca. 1,5 Stunden (gemessen: System ~60 min, Anwendung ~15 min)  
**Schwierigkeit**: ⭐⭐ Mittel (Linux- und SSH-Grundkenntnisse nötig)

➡️ **[Raspberry Pi Quickstart-Anleitung](raspberry-pi-quickstart.md)**

!!! warning "Erstbefüllung der Datenbank"
    Die Erstbefüllung braucht derzeit SSH-Zugang zur Authority (`api.carambus.de`). Dafür ist der
    Betreiber von Carambus nötig, siehe [Installations-Übersicht](installation-overview.md#voraussetzungen).

### Option 2: Cloud-Hosting (Verbände)
**Stand**: nicht als Weg belegt. Die Ansible-Rollen und die Quickstart sind für den Raspberry Pi
gegangen; ein frischer Cloud-Server ist bisher nicht so aufgesetzt worden.

➡️ **[Installations-Übersicht](installation-overview.md)**

### Option 3: On-Premise Server
**Stand**: nicht als Weg belegt (wie Option 2). Ein Raspberry Pi als reiner Server folgt dem Weg aus
Option 1.

➡️ **[Installations-Übersicht](installation-overview.md)**

## 📚 Hauptthemen

### 1. Installation

**Grundlegende Installation**:
- Systemanforderungen
- System per Ansible aufsetzen (`~/DEV/ansible`, RUNBOOK)
- Szenario-Konfiguration in `carambus_data`
- Carambus per Scenario Management deployen

➡️ **[Vollständige Installationsanleitung](installation-overview.md)**

**Spezielle Installationen**:
- **[Raspberry Pi Setup](raspberry-pi-quickstart.md)**: All-in-One Kiosk-System
- **[Raspberry Pi Client](raspberry-pi-client.md)**: Nur als Display/Scoreboard
- **[Datenbank-Setup](database-setup.md)**: PostgreSQL konfigurieren

### 2. Konfiguration

**System-Einstellungen**:
- Vereinsdaten konfigurieren
- E-Mail-Server einrichten
- SSL/TLS-Zertifikate
- Backup-Strategien

➡️ **[Email-Konfiguration](email-configuration.md)**

**Scoreboard-Setup**:
- Automatischer Start beim Booten (nach dem Einschalten rund 3 Minuten bis zum Scoreboard, Desktop nach ~1 Minute)
- Kiosk-Modus konfigurieren
- Multiple Displays verwalten

➡️ **[Scoreboard Autostart-Setup](scoreboard-autostart.md)**

### 3. Server-Architektur

**System-Übersicht**:
- Komponenten-Architektur
- Rails-Application-Stack
- Datenbank-Design
- WebSocket-Kommunikation
- Caching-Strategien

➡️ **[Server-Architektur-Dokumentation](server-architecture.md)**

### 4. Wartung & Updates

**Regelmäßige Wartung**:
- System-Updates einspielen
- Carambus-Updates durchführen
- Backup-Checks
- Log-Größen prüfen
- Performance-Monitoring

**Backup & Restore**:
- Datenbank-Backups
- Datei-Backups (Uploads, Logs)
- Restore-Prozeduren
- Disaster Recovery

### 5. Sicherheit

**System-Härtung** (bei Raspberry Pis per Ansible):
- Firewall mit `iptables-persistent`: nur Port 3131 (Web) und 8910 (SSH) offen
- SSH nur noch auf Port 8910 als `www-data`
- Sperrliste gegen auffällige Adressen (Kette `carambus-blocklist`)
- SSL/TLS-Zertifikate (Let's Encrypt) für öffentlich erreichbare Server
- Secrets außerhalb des Deploy-Baums (`/etc/<basename>.env`, Modus 600)

**Best Practices**:
- Regelmäßige Security-Updates
- Starke Passwörter erzwingen
- Log-Monitoring

### 6. Monitoring & Troubleshooting

**Performance-Monitoring**:
- CPU/RAM-Auslastung
- Datenbank-Performance
- WebSocket-Verbindungen
- Request-Zeiten
- Error-Rates

**Log-Analyse**:
- Application-Logs
- Nginx-Logs
- PostgreSQL-Logs
- Systemd-Logs

**Häufige Probleme**:
- WebSocket-Verbindungen brechen ab
- Slow Queries in Datenbank
- Speicherplatz voll
- SSL-Zertifikat abgelaufen

### 7. Tischreservierung & Heizungssteuerung

**Hardware-Integration**:
- Heizungssteuerung anbinden
- GPIO-Pins (Raspberry Pi)
- Relais-Module
- Zeitschaltuhren

➡️ **[Tischreservierung & Heizungssteuerung](../managers/table-reservation.md)**

### 8. YouTube Live Streaming

**Turnier-Streaming mit vorhandenen Scoreboards**:
- Nutzt vorhandene Scoreboard-Raspberry-Pis
- USB-Webcam pro Tisch (~80€)
- FFmpeg (Software-Encoding, `libx264`)
- Automatisches Scoreboard-Overlay
- Zentrale Verwaltung im Admin-Interface

**Dokumentation**:
- 🚀 **[Quick Start (5 Schritte)](streaming-quickstart.md)** - In 5 Minuten zum ersten Stream
- 📖 **[Vollständige Setup-Anleitung](streaming-setup.md)** - Hardware, YouTube-Setup, Konfiguration, Troubleshooting
- 💻 **[Entwickler-Architektur](../developers/streaming-architecture.md)** - Technische Details für Entwickler

**Features**:
- ✅ Tischbezogenes Streaming (jeder Tisch unabhängig)
- ✅ Live-Overlays (Spielernamen, Scores, Turnierinfo)
- ✅ Auto-Restart bei Fehlern
- ✅ Health-Monitoring
- ✅ Sehr kostengünstig (~80€ Kamera pro Tisch)

## 🛠️ Installations-Szenarien im Detail

### Raspberry Pi All-in-One

**Hardware-Anforderungen**:
- Raspberry Pi 4 oder 5. 2 GB RAM funktionieren, sind aber knapp; 4 GB oder mehr sind empfehlenswert
- MicroSD-Karte (mindestens 16 GB, empfohlen 32 GB+)
- Offizielles Netzteil
- HDMI-Kabel und Monitor
- Optional: Touch-Display (7" oder größer)

**Software-Setup** (Einzelheiten in der [Quickstart](raspberry-pi-quickstart.md)):
1. **SD-Karte schreiben**: Raspberry Pi Imager, Standard-Raspberry-Pi-OS mit Desktop, SSH-Schlüssel hinterlegen
2. **System aufsetzen**: ein Ansible-Aufruf (`master.yml`, ~60 min)
3. **Anwendung deployen**: Rake-Tasks vom Admin-Rechner (~15 min)
4. **Fertig**: Der Pi startet von selbst ins Scoreboard (nach dem Einschalten ~3 min)

**Vorteile**:
- ✅ Belegter Weg, auf frischer Hardware gegangen
- ✅ Sehr kostengünstig (~150 EUR)
- ✅ Server und Scoreboard auf einem Gerät

**Nachteile**:
- ❌ Begrenzte Performance (für kleine Vereine ausreichend)
- ❌ SD-Karte kann ausfallen, und **ein automatisches Datenbank-Backup ist für neue Vereins-Pis nicht
  eingerichtet** (siehe Wartungs-Checkliste)

➡️ **[Detaillierte Raspberry Pi-Anleitung](raspberry-pi-quickstart.md)**

### Cloud-Hosting (VPS)

**Provider-Beispiele**:
- **Hetzner Cloud**: 8 EUR/Monat (CPX21: 3 vCPU, 4 GB RAM)
- **DigitalOcean**: 24 USD/Monat (4 GB Droplet)
- **AWS/Azure**: Ab 30 EUR/Monat (variable Kosten)

**Installations-Schritte** (Anwendungsteil wie beim Pi, Systemteil nicht belegt):
1. **VPS buchen und starten**
2. **System aufsetzen**: Die Ansible-Rollen sind für den Raspberry Pi gegangen; ob `master.yml` einen frischen
   Cloud-Server gleichwertig einrichtet, ist nicht geprüft
3. **Szenario anlegen** in `carambus_data` (siehe [Installations-Übersicht](installation-overview.md))
4. **Anwendung deployen**: `prepare_deploy` → `prepare_development` → `reset_server_db` → `deploy`
5. **SSL einrichten**: Zertifikat vor `prepare_deploy` ausstellen (`ssl_enabled: true`)
6. **Backup konfigurieren**: siehe Wartungs-Checkliste
7. **Monitoring einrichten**: Optional (z.B. UptimeRobot)

**Vorteile**:
- ✅ Von überall erreichbar
- ✅ Professionelle Infrastruktur

**Nachteile**:
- ❌ Laufende Kosten
- ❌ Internet-Abhängigkeit
- ❌ Systemteil nicht als Weg belegt

➡️ **[Installations-Übersicht](installation-overview.md)**

### On-Premise Server

**Hardware-Optionen**:
- **Budget**: Raspberry Pi als reiner Server (Weg wie Option 1)
- **Standard**: Intel NUC oder Mini-PC
- **Premium**: Tower-Server mit RAID

**Installations-Schritte**: wie Cloud-Hosting. Zusätzlich: statische Adresse bzw. Gerätename im lokalen Netz,
Backup auf ein externes Medium (USB-HDD oder NAS), USV gegen Stromausfälle.

**Vorteile**:
- ✅ Volle Datenkontrolle
- ✅ Keine laufenden Hosting-Kosten
- ✅ Schnell im lokalen Netz

**Nachteile**:
- ❌ Hardware-Anschaffung
- ❌ Selbst für Wartung verantwortlich

➡️ **[Installations-Übersicht](installation-overview.md)**

## ⚙️ Wichtige Konfigurationsdateien

Die Konfiguration eines Servers wird **nicht von Hand** gepflegt. Sie entsteht aus
`carambus_data/scenarios/<szenario>/config.yml` und `carambus_data/secrets.yml`; `prepare_deploy` erzeugt
die Dateien und lädt sie hoch.

| Datei auf dem Server | Entsteht aus | Ändern über |
|---|---|---|
| `shared/config/database.yml` | `templates/database/database.yml.erb` (Rolle `www_data`, Passwort aus `secrets.yml` `shared.database_password`) | `config.yml` / `secrets.yml`, dann `prepare_deploy` |
| `shared/config/puma.rb` | `templates/puma/puma_rb.erb` (Socket `/var/www/<basename>/shared/sockets/puma-production.sock`) | `prepare_deploy` |
| `/etc/nginx/sites-available/<basename>` | `templates/nginx/nginx_conf.erb` | `bin/rails "scenario:sync_nginx_conf[<szenario>]"` |
| `/etc/systemd/system/puma-<basename>.service` | `templates/puma/puma.service.erb` | `prepare_deploy` (nicht von Hand editieren, wird neu geschrieben) |
| `/etc/<basename>.env` | `secrets.yml` `smtp` (bzw. `smtp_enabled: false`) | von Hand, wird nie überschrieben |
| `shared/config/credentials/production.key` / `production.yml.enc` | `carambus_data/scenarios/<szenario>/production/credentials/` | `WRITE=true bin/rails "scenario:generate_credentials[<szenario>]"` (ohne `WRITE=true` nur Probelauf), dann `prepare_deploy` |

Alle Pfade ohne `/` am Anfang liegen unter `/var/www/<basename>/`.

!!! note "Credentials"
    Auf dem Server nicht mit `rails credentials:edit` bearbeiten: `prepare_deploy` lädt die Dateien aus
    `carambus_data` hoch und überschreibt Änderungen am Server. Woher ein neuer Verein seinen
    `production.key` bekommt, ist noch nicht geregelt (siehe
    [Installations-Übersicht](installation-overview.md#voraussetzungen)).

Dienste auf dem Server:
```bash
sudo systemctl status puma-<basename>
sudo systemctl restart puma-<basename>
systemctl is-active puma-<basename> redis-server nginx
```

## 🔧 Wartungs-Checkliste

### Täglich (automatisiert)
- ✅ Datenbank-Backup **nur** für die Authority und für die in `STANDALONE_BACKUP_SCENARIOS`
  (`config/schedule.rb`) eingetragenen Standorte (derzeit `carambus_bcw`, Ziel `/mnt/backup`)
- ⚠️ Für einen neuen Vereins-Pi gibt es **kein automatisches Backup**: das Szenario in
  `STANDALONE_BACKUP_SCENARIOS` aufnehmen und einen USB-Stick unter `/mnt/backup` einhängen, oder
  `bin/pg_backup.sh` selbst per Cron einrichten

### Wöchentlich
- 🔍 Backup-Integrität prüfen
- 🔍 Logs auf Fehler durchsehen
- 🔍 Disk-Space prüfen (`production.log` wird nicht automatisch rotiert)
- 🔍 Performance-Metriken ansehen

### Monatlich
- 🔄 System-Updates einspielen (Security)
- 🔄 Carambus-Updates prüfen und installieren (`bin/rails "scenario:deploy[<szenario>]"`)
- 🔄 SSL-Zertifikat-Ablauf prüfen (bei öffentlich erreichbaren Servern)
- 🔄 Backup-Restore testen

### Vierteljährlich
- 📊 Performance-Analyse
- 📊 Kapazitäts-Planung
- 📊 Security-Audit
- 📊 Dokumentation aktualisieren

### Jährlich
- 🔒 Disaster-Recovery-Test
- 🔒 Hardware-Zustand prüfen

## 🆘 Troubleshooting-Guide

### Problem: Application startet nicht

**Symptome**: *502 Bad Gateway*, Dienst `puma-<basename>` startet immer wieder neu

**Debugging**:
```bash
# Service-Status prüfen
sudo systemctl status puma-<basename>

# Logs ansehen
sudo journalctl -u puma-<basename> -n 100 --no-pager
```

**Häufige Ursachen**:
- `/etc/<basename>.env` fehlt (`FATAL: SMTP-ENV nicht gesetzt`), siehe [Email-Konfiguration](email-configuration.md)
- Database nicht erreichbar
- Fehlende Credentials

### Problem: WebSockets funktionieren nicht

**Symptome**: Scoreboards aktualisieren sich nicht in Echtzeit

**Checks**:
```bash
# Nginx WebSocket-Konfiguration prüfen
sudo nginx -t

# Action Cable Logs
tail -f /var/www/<basename>/shared/log/production.log | grep Cable

# Redis ist Pflicht (ActionCable)
systemctl is-active redis-server
redis-cli ping
```

**Lösungen**:
- nginx-Konfiguration per `scenario:sync_nginx_conf` neu erzeugen
- Redis-Server starten: `sudo systemctl start redis-server`

### Problem: Langsame Performance

**Diagnose**:
```bash
# CPU/RAM Auslastung
htop
free -m

# Datenbank-Verbindungen
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

**Optimierungen**:
- Speicher prüfen: laufen ClamAV/SpamAssassin auf dem Pi, siehe [Quickstart, Fehlerbehebung](raspberry-pi-quickstart.md#fehlerbehebung)
- Datenbank-Indizes prüfen
- Mehr RAM/CPU

### Problem: Speicherplatz voll

**Diagnose**:
```bash
# Disk-Usage
df -h

# Größte Verzeichnisse finden
du -sh /var/* | sort -h
```

**Lösungen**:
```bash
# Alte Journal-Einträge löschen
sudo journalctl --vacuum-time=7d

# Rails-Log leeren
cd /var/www/<basename>/current && RAILS_ENV=production bin/rails log:clear

# Alte Backups löschen (manuell prüfen!)
```

### Problem: SSL-Zertifikat abgelaufen

**Symptome**: Browser-Warnung, HTTPS funktioniert nicht

**Lösung**:
```bash
# Certbot erneuern
sudo certbot renew

# Nginx neu laden
sudo systemctl reload nginx

# Auto-Renewal prüfen
sudo systemctl status certbot.timer
```

## 📞 Support-Ressourcen

### Dokumentation

- **[Installations-Übersicht](installation-overview.md)**: Alle Deployment-Optionen
- **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: RasPi-Setup
- **[Raspberry Pi Client](raspberry-pi-client.md)**: RasPi als Display
- **[Server-Architektur](server-architecture.md)**: System-Überblick
- **[Datenbank-Setup](database-setup.md)**: PostgreSQL konfigurieren
- **[Email-Konfiguration](email-configuration.md)**: SMTP einrichten
- **[Scoreboard Autostart](scoreboard-autostart.md)**: Kiosk-Modus

### Community & Hilfe

**GitHub**:
- Repository: [https://github.com/GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
- Issues: Bugs melden, Feature-Requests
- Discussions: Fragen stellen

**Kontakt**:
- Email: gernot.ullrich@gmx.de
- Bei kritischen Problemen: Detaillierte Fehlerbeschreibung mit Logs

### Weiterführende Informationen

**Rails-Dokumentation**:
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Rails API Docs](https://api.rubyonrails.org/)

**PostgreSQL**:
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)

**Nginx**:
- [Nginx Docs](https://nginx.org/en/docs/)
- [WebSocket Proxying](https://nginx.org/en/docs/http/websocket.html)

## 🔗 Alle Administrator-Dokumente

1. **[Installations-Übersicht](installation-overview.md)** - Alle Deployment-Optionen
2. **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)** - All-in-One Setup
3. **[Raspberry Pi Client](raspberry-pi-client.md)** - Nur Display/Scoreboard
4. **[Scoreboard Autostart](scoreboard-autostart.md)** - Kiosk-Modus einrichten
5. **[Server-Architektur](server-architecture.md)** - System-Komponenten
6. **[Email-Konfiguration](email-configuration.md)** - SMTP einrichten
7. **[Datenbank-Setup](database-setup.md)** - PostgreSQL konfigurieren
8. **[Tischreservierung & Heizung](../managers/table-reservation.md)** - Hardware-Integration

---

**Viel Erfolg bei der Administration! 🖥️**

*Tipp: Dokumentieren Sie Ihre spezifische Installation (Server-Details, Besonderheiten) in einem separaten, sicheren Dokument. Zugangsdaten gehören in `carambus_data/secrets.yml`, nicht in die Doku.*
