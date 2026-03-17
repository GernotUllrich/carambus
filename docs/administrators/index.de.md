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
**Setup-Zeit**: 30-60 Minuten  
**Schwierigkeit**: ⭐ Einfach

➡️ **[Raspberry Pi Quickstart-Anleitung](raspberry-pi-quickstart.md)**

### Option 2: Cloud-Hosting (Empfohlen für Verbände)
**Setup-Zeit**: 2-4 Stunden  
**Schwierigkeit**: ⭐⭐ Mittel

➡️ **[Installations-Übersicht - Cloud-Setup](installation-overview.de.md#cloud-hosting)**

### Option 3: On-Premise Server
**Setup-Zeit**: 1-2 Tage  
**Schwierigkeit**: ⭐⭐⭐ Anspruchsvoll

➡️ **[Installations-Übersicht - On-Premise](installation-overview.de.md#on-premise)**

## 📚 Hauptthemen

### 1. Installation

**Grundlegende Installation**:
- Systemanforderungen
- Betriebssystem-Setup (Ubuntu)
- Dependencies installieren
- Carambus deployen
- Erste Konfiguration

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
- Automatischer Start beim Booten
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
- Log-Rotation
- Performance-Monitoring

**Backup & Restore**:
- Datenbank-Backups
- Datei-Backups (Uploads, Logs)
- Restore-Prozeduren
- Disaster Recovery

### 5. Sicherheit

**System-Härtung**:
- Firewall-Konfiguration (ufw)
- Fail2ban gegen Brute-Force
- SSL/TLS-Zertifikate (Let's Encrypt)
- Sichere Credential-Verwaltung
- Zugriffskontrollen

**Best Practices**:
- Regelmäßige Security-Updates
- Starke Passwörter erzwingen
- 2FA aktivieren (optional)
- Log-Monitoring
- Penetration-Tests

➡️ **[Sicherheits-Best-Practices](installation-overview.de.md#sicherheit)**

### 6. Monitoring & Troubleshooting

**Performance-Monitoring**:
- CPU/RAM-Auslastung
- Datenbank-Performance
- WebSocket-Verbindungen
- Request-Zeiten
- Error-Rates

**Log-Analyse**:
- Application-Logs
- Nginx/Apache-Logs
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
- FFmpeg Hardware-Encoding
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
- Raspberry Pi 4 (8GB RAM empfohlen) oder Raspberry Pi 5
- Micro-SD-Karte (64 GB, Class 10)
- Netzteil (USB-C, 3A)
- HDMI-Kabel
- Optional: Touch-Display (7" oder größer)

**Software-Setup**:
1. **Image herunterladen**: Vorkonfiguriertes Carambus-Image
2. **SD-Karte flashen**: Mit Balena Etcher oder Raspberry Pi Imager
3. **Erste Konfiguration**: WLAN, Vereinsname, Admin-Account
4. **Fertig!**: System bootet in Kiosk-Modus

**Vorteile**:
- ✅ Extrem schnelle Installation (< 1 Stunde)
- ✅ Keine Linux-Kenntnisse erforderlich
- ✅ Sehr kostengünstig (~150 EUR)
- ✅ Geringer Wartungsaufwand

**Nachteile**:
- ❌ Begrenzte Performance (für kleine Vereine ausreichend)
- ❌ SD-Karte kann ausfallen (regelmäßige Backups!)

➡️ **[Detaillierte Raspberry Pi-Anleitung](raspberry-pi-quickstart.md)**

### Cloud-Hosting (VPS)

**Provider-Empfehlungen**:
- **Hetzner Cloud**: 8 EUR/Monat (CPX21: 3 vCPU, 4 GB RAM)
- **DigitalOcean**: 24 USD/Monat (4 GB Droplet)
- **AWS/Azure**: Ab 30 EUR/Monat (variable Kosten)

**Installations-Schritte**:
1. **VPS buchen und starten**
2. **Ubuntu 22.04 LTS installieren** (meist vorinstalliert)
3. **Basis-System härten**: Firewall, Fail2ban, Updates
4. **Dependencies installieren**: Ruby, Rails, PostgreSQL, Node.js, Yarn
5. **Carambus deployen**: Via Git checkout oder Capistrano
6. **Webserver konfigurieren**: Nginx + Passenger oder Puma
7. **SSL einrichten**: Let's Encrypt Zertifikat
8. **Systemd-Service**: Automatischer Start
9. **Backup konfigurieren**: Tägliche Datenbank-Backups
10. **Monitoring einrichten**: Optional (z.B. UptimeRobot)

**Zeitaufwand**: 3-4 Stunden (für erfahrene Linux-Admins)

**Vorteile**:
- ✅ Von überall erreichbar
- ✅ Professionelle Infrastruktur
- ✅ Einfach skalierbar
- ✅ Automatische Backups verfügbar

**Nachteile**:
- ❌ Laufende Kosten
- ❌ Internet-Abhängigkeit
- ❌ Höherer initialer Setup-Aufwand

➡️ **[Cloud-Installations-Guide](installation-overview.de.md#cloud-hosting)**

### On-Premise Server

**Hardware-Optionen**:
- **Budget**: Raspberry Pi 4 als reiner Server (~100 EUR)
- **Standard**: Intel NUC oder Mini-PC (~400 EUR)
- **Premium**: Tower-Server mit RAID (~1.500 EUR)

**Installations-Schritte**:
1. **Hardware beschaffen und aufbauen**
2. **Ubuntu Server 22.04 LTS installieren**
3. **Netzwerk konfigurieren**: Statische IP, ggf. Port-Forwarding
4. **System härten**: Wie bei Cloud, aber zusätzlich physische Sicherheit
5. **Dependencies installieren**
6. **Carambus installieren**
7. **Webserver einrichten**: Nginx (für interne Nutzung kein SSL zwingend)
8. **Backup auf externes Medium**: USB-HDD oder NAS
9. **USV empfohlen**: Gegen Stromausfälle
10. **VPN-Zugriff** (optional): Für Remote-Administration

**Zeitaufwand**: 1-2 Tage (inkl. Hardware-Setup)

**Vorteile**:
- ✅ Volle Datenkontrolle
- ✅ Keine laufenden Hosting-Kosten
- ✅ Internet-unabhängig
- ✅ Schnell im lokalen Netz

**Nachteile**:
- ❌ Hardware-Anschaffung
- ❌ Selbst für Wartung verantwortlich
- ❌ Höherer Setup-Aufwand

➡️ **[On-Premise-Installations-Guide](installation-overview.de.md#on-premise)**

## ⚙️ Wichtige Konfigurationsdateien

### Rails-Konfiguration

**config/database.yml**:
```yaml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  database: carambus_production
  username: carambus
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: localhost
```

**config/credentials.yml.enc**:
- Verschlüsselte Credentials
- Öffnen mit: `EDITOR=nano rails credentials:edit --environment production`
- Enthält: Secret Keys, API-Keys, Passwörter

**config/puma.rb**:
- Puma-Webserver-Konfiguration
- Workers und Threads
- Port-Bindung

### Nginx-Konfiguration

**Standort**: `/etc/nginx/sites-available/carambus`

Beispiel-Konfiguration:
```nginx
upstream puma {
  server unix:///var/www/carambus/shared/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name carambus.example.com;
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name carambus.example.com;
  
  ssl_certificate /etc/letsencrypt/live/carambus.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/carambus.example.com/privkey.pem;
  
  root /var/www/carambus/current/public;
  
  location / {
    proxy_pass http://puma;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
  
  # WebSocket support
  location /cable {
    proxy_pass http://puma;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

### Systemd-Service

**Standort**: `/etc/systemd/system/carambus.service`

```ini
[Unit]
Description=Carambus Rails Application
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/carambus/current
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

Befehle:
```bash
sudo systemctl enable carambus
sudo systemctl start carambus
sudo systemctl status carambus
sudo systemctl restart carambus
```

## 🔧 Wartungs-Checkliste

### Täglich (automatisiert)
- ✅ Datenbank-Backup
- ✅ Log-Rotation
- ✅ Monitoring-Checks

### Wöchentlich
- 🔍 Backup-Integrität prüfen
- 🔍 Logs auf Fehler durchsehen
- 🔍 Disk-Space prüfen
- 🔍 Performance-Metriken ansehen

### Monatlich
- 🔄 System-Updates einspielen (Security)
- 🔄 Carambus-Updates prüfen und installieren
- 🔄 SSL-Zertifikat-Ablauf prüfen (auto-renewal sollte aktiv sein)
- 🔄 Backup-Restore testen

### Vierteljährlich
- 📊 Performance-Analyse
- 📊 Kapazitäts-Planung
- 📊 Security-Audit
- 📊 Dokumentation aktualisieren

### Jährlich
- 🔒 Penetration-Test (optional)
- 🔒 Disaster-Recovery-Test
- 🔒 Hardware-Zustand prüfen
- 🔒 Lizenz-Reviews

## 🆘 Troubleshooting-Guide

### Problem: Application startet nicht

**Symptome**: Systemd-Service fehlgeschlagen, Error-Meldungen in Logs

**Debugging**:
```bash
# Service-Status prüfen
sudo systemctl status carambus

# Logs ansehen
sudo journalctl -u carambus -n 100

# Manuell starten für detaillierte Fehler
cd /var/www/carambus/current
bundle exec puma -C config/puma.rb
```

**Häufige Ursachen**:
- Database nicht erreichbar
- Fehlende Credentials
- Port bereits belegt
- Fehlende Dependencies

### Problem: WebSockets funktionieren nicht

**Symptome**: Scoreboards aktualisieren sich nicht in Echtzeit

**Checks**:
```bash
# Nginx WebSocket-Konfiguration prüfen
sudo nginx -t

# Action Cable Logs
tail -f log/production.log | grep Cable

# Redis läuft? (falls verwendet)
redis-cli ping
```

**Lösungen**:
- Nginx WebSocket-Proxy korrekt konfigurieren
- Firewall für WebSocket-Ports öffnen
- Redis-Server starten (falls konfiguriert)

### Problem: Langsame Performance

**Diagnose**:
```bash
# CPU/RAM Auslastung
htop

# Datenbank-Verbindungen
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Slow Queries
# In config/database.yml: log_min_duration_statement: 1000
tail -f /var/log/postgresql/postgresql-14-main.log
```

**Optimierungen**:
- Datenbank-Indizes prüfen
- Query-Optimierung
- Mehr RAM/CPU
- Caching aktivieren (Redis)

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
# Alte Logs löschen
sudo journalctl --vacuum-time=7d

# Rails Logs rotieren
cd /var/www/carambus/current
rails log:clear

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

*Tipp: Dokumentieren Sie Ihre spezifische Installation (Server-Details, Passwörter, Besonderheiten) in einem separaten, sicheren Dokument.*




