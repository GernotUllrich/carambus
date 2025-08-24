# 🐳 Docker Installation für Carambus

## 📋 Übersicht

Dieses Dokument beschreibt die automatisierten Prozesse für:
1. **Neuinstallation** eines Carambus-Servers auf verschiedenen Plattformen
2. **Migration** bestehender Installationen zu neuen Hauptversionen
3. **Entwicklungsumgebung** für lokale Entwicklung auf einem Computer mit macOS

Das Ziel ist es, diese Prozesse so zu vereinfachen, dass ein lokaler System-Manager ohne tiefe technische Kenntnisse diese Aufgaben durchführen kann.

## 🏗️ Architektur-Übersicht

### Production-Modi (2 verschiedene Systeme)

#### 1. **API-Server** (newapi.carambus.de)
- **Zweck**: Zentrale API für alle Local-Server
- **Merkmale**: Ist der zentrale API-Server
- **Verwendung**: Produktions-API-Server
- **Domain**: newapi.carambus.de
- **Installationspfad**: `/var/www/carambus_api`

#### 2. **Local-Server** (lokale Installationen)
- **Zweck**: Lokale Server für Turniere/Clubs
- **Merkmale**: Hat eine Carambus API URL, die auf den API-Server verweist
- **Verwendung**: Raspberry Pi Scoreboards, lokale Server
- **Domain**: localhost oder lokale IP
- **API-URL**: Verweist auf newapi.carambus.de
- **Installationspfad**: `/var/www/carambus`

#### 3. **Kombinierte Installation** (API-Server + Local-Server)
- **Zweck**: API-Server mit zusätzlichem Local-Server für Hosting
- **Verwendung**: Für Locations ohne eigenen Server
- **Installationspfade**: 
  - API-Server: `/var/www/carambus_api`
  - Local-Server: `/var/www/carambus`
- **Vorteil**: Zentrale Verwaltung mit lokaler Hosting-Funktionalität

**Hinweis**: Beide Server-Typen können auf derselben Hardware laufen. Der API-Server kann auch als Hosting-Server für lokale Carambus-Instanzen fungieren, die keinen eigenen Server haben.

### Development-Modus (übergeordnet)
- **Zweck**: Beide Production-Modi können im Development-Modus getestet werden
- **Plattform**: Computer mit macOS für lokale Entwicklung
- **Vorteil**: Parallele Tests beider Modi möglich
- **Verwendung**: Inter-System-Kommunikation testen (Local-Server ↔ API-Server)

## 🚀 Installationstypen

### Docker-basierte Installation (Empfohlen)

#### Vorteile
- ✅ Konsistente Umgebung
- ✅ Einfache Migration
- ✅ Minimaler technischer Aufwand
- ✅ Reproduzierbare Installationen
- ✅ Automatische Updates

#### Prozess
1. **Automatische Konfiguration** beim ersten Boot
2. **Web-basierte Lokalisierung** (nur für lokale Server)
3. **Automatischer Scoreboard-Start** (nur für lokale Server)

## 📋 Installationsprozess (Docker-basiert)

### Phase 1: Vorbereitung

#### 1.1 Plattform-spezifische Voraussetzungen

**Raspberry Pi:**
- Raspberry Pi Imager mit Custom Image
- Optional: SSH-Konfiguration mit Standard-Account
- Optional: WLAN-Anbindung mit fester IP im Router

**Ubuntu Server (z.B. Hetzner):**
- Basis-Installation bereits durch Hoster erfolgt
- Netzwerkkonfiguration bereits durch Hoster erfolgt
- SSH-Zugang über Standard-Port 22

#### 1.2 www-data Account konfigurieren

**Wichtig**: Alle Carambus-Installationen verwenden den Standard-Account `www-data` (uid=33, gid=33), der bereits in beiden Betriebssystemen definiert ist:

```bash
# Der www-data User ist bereits vorhanden:
# www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin

# Shell für SSH-Zugang aktivieren (Home-Verzeichnis bleibt /var/www)
sudo chsh -s /bin/bash www-data

# wheel-Gruppe erstellen (falls nicht vorhanden)
sudo groupadd wheel

# wheel-Gruppe für passwortloses sudo konfigurieren
echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

# www-data zu wheel-Gruppe hinzufügen
sudo usermod -aG wheel www-data

# SSH-Schlüssel für passwortlosen Zugang einrichten
sudo mkdir -p /var/www/.ssh
sudo chown www-data:www-data /var/www/.ssh
sudo chmod 700 /var/www/.ssh
# Öffentlichen Schlüssel vom Entwicklungssystem kopieren
```

#### 1.3 SSH-Konfiguration

**Entwicklungssystem-Skripte** gehen immer von folgender SSH-Konfiguration aus:

```bash
# Standard-SSH-Zugang für alle Skripte
ssh -p 8910 www-data@host

# Kein direkter Root-Zugang möglich
# Kein passwortloser Root-Zugang möglich
# Von www-data aus ggf. per sudo su weiter
```

**SSH-Konfiguration auf dem Zielsystem:**

```bash
# /etc/ssh/sshd_config
Port 8910
PermitRootLogin no
# PasswordAuthentication no  # Auskommentiert für initiale Konfiguration
PubkeyAuthentication yes
AllowUsers www-data
```

**Hinweis**: Diese Konfiguration entspricht den Ansible-Regeln, die für das Deployment verwendet werden. Die `wheel`-Gruppe ermöglicht passwortloses sudo für den `www-data` User.

### Phase 2: Automatische Konfiguration

#### 2.1 Netzwerk-Konfiguration

**Hinweis**: Die Netzanbindung erfolgt bereits beim Laden des Basis-OS:
- **Raspberry Pi**: Optional SSH-Konfiguration und WLAN-Anbindung (vorzugsweise feste IP im Router)
- **Ubuntu Server**: Über die Administration des Hosters

Für die Docker-Installation ist in jedem Fall ein Account `www-data` vorhanden, über den auch die Rails-Anwendung läuft.

#### 2.2 Lokalisierung

**Wichtig**: Nur die lokalen Server haben eine Regionalisierung (region_id bzw. Kontext) zur Einstellung des Datenfilters.

```yaml
# config/localization.yml
location:
  id: "{location_id}"
  name: "{location_name}"
  timezone: "Europe/Berlin"
  region_id: "{region_id}"  # Nur für lokale Server relevant
```

**Lokalisierung ist nur notwendig für Scoreboards**, da diese einer Location zugeordnet sind, damit die entsprechende Tischauswahl für die Location gemacht werden kann.

**Hinweis**: Es gab beim `assets:precompile` Probleme, dass eine `location_id` vorgegeben sein musste. Das muss nochmal angeschaut und eliminiert werden.

#### 2.3 Carambus API URL konfigurieren

```yaml
# config/api.yml
carambus_api:
  url: "https://newapi.carambus.de"
  timeout: 30
  retry_attempts: 3
```

#### 2.4 Sprachkonfiguration

**Deutsch ist immer die Default-Locale**. Benutzer können über ihr Profil eine eigene Locale (DE oder EN) auswählen. Das Umschalten ist in der Webapp möglich und ist für die Installation irrelevant.

```yaml
# config/application.yml
default_locale: "de"
available_locales: ["de", "en"]
```

### Phase 3: Scoreboard-Setup (nur für lokale Server)

**Hinweis**: Desktop-Konfigurationen müssen wir nochmal gesondert anschauen. Wir hegen bei der Passivinstallation von einem Headless-Server aus.

## 🔧 Entwicklungsumgebung (Computer mit macOS)

### Lokale Entwicklung
```bash
# Einzelnes System starten
docker-compose -f docker-compose.development.local-server.yml up

# Alle Systeme parallel (für Inter-System-Tests)
./start-development-parallel.sh
```

### Parallele Systeme (Development-Modus)
```bash
# Alle drei Systeme gleichzeitig auf dem macOS-Computer
docker-compose -f docker-compose.development.parallel.yml up

# Ports:
# - API-Server: 3001 (PostgreSQL: 5433, Redis: 6380)
# - Local-Server: 3000 (PostgreSQL: 5432, Redis: 6379)
# - Web-Client: 3002 (PostgreSQL: 5434, Redis: 6381)

# Installationspfade:
# - API-Server: /var/www/carambus_api
# - Local-Server: /var/www/carambus
```

### Inter-System-Kommunikation testen
```bash
# Local-Server kommuniziert mit API-Server über Carambus API URL
# Für Region-Filter-Tests
# Für Synchronisierung-Tests
# Local-Server hat API-URL, die auf API-Server verweist
```

## 📊 Monitoring und Wartung

### System-Monitoring
```bash
# Container-Status
docker compose ps

# Ressourcen-Verbrauch
docker stats

# System-Ressourcen
htop
```

### Automatische Updates
```bash
# Crontab für automatische Updates
crontab -e

# Täglich um 2:00 Uhr aktualisieren
# Für Local-Server:
0 2 * * * cd /var/www/carambus && git pull && docker compose up -d --build
# Für API-Server:
# 0 2 * * * cd /var/www/carambus_api && git pull && docker compose up -d --build
```

### Backup-System
```bash
# Automatisches Backup der Lokalisierung
#!/bin/bash
# backup-localization.sh

LOCATION_ID=$(grep "LOCATION_ID" .env | cut -d'=' -f2)
BACKUP_DIR="/backup/localization"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
tar -czf "$BACKUP_DIR/localization_${LOCATION_ID}_${DATE}.tar.gz" \
  config/localization.yml \
  .env \
  storage/

# Für kombinierte Installationen (API-Server + Local-Server):
# Beide Verzeichnisse sichern
# tar -czf "$BACKUP_DIR/carambus_combined_${DATE}.tar.gz" \
#   /var/www/carambus_api \
#   /var/www/carambus
```

## 🚨 Troubleshooting

### Häufige Probleme

#### Container startet nicht
```bash
# Docker-Status prüfen
sudo systemctl status docker

# Logs anschauen
docker compose logs

# Container neu starten
docker compose restart
```

#### Scoreboard startet nicht (nur für lokale Server)
```bash
# Browser-Cache leeren
rm -rf ~/.cache/chromium

# Browser neu starten
pkill chromium
chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
```

#### Netzwerk-Probleme
```bash
# IP-Adresse prüfen
ip addr show

# Netzwerk neu starten
sudo systemctl restart networking
```

### Log-Analyse
```bash
# Alle Logs
docker compose logs -f

# Nur Rails-Logs
docker compose logs -f web

# Nur Datenbank-Logs
docker compose logs -f postgres
```

## 🔄 Migration von bestehenden Installationen

### Schritt 1: Backup erstellen
```bash
# Lokalisierung sichern
tar -czf localization_backup.tar.gz config/localization.yml .env

# Datenbank sichern
docker compose exec postgres pg_dump -U www_data carambus > carambus_backup.sql
```

### Schritt 2: Neue Installation
```bash
# Neues Deployment ausführen
# Für Local-Server:
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus
# Für API-Server:
# ./deploy-docker.sh carambus_api_server www-data@newapi.carambus.de:8910 /var/www/carambus_api
```

### Schritt 3: Daten wiederherstellen
```bash
# Lokalisierung wiederherstellen
tar -xzf localization_backup.tar.gz

# Datenbank wiederherstellen
docker compose exec -T postgres psql -U www_data carambus < carambus_backup.sql
```

## 📖 Weitere Dokumentation

- **[Installationsübersicht](installation_overview.md)** - Installationsübersicht
- **[Entwicklerleitfaden](DEVELOPER_GUIDE.md)** - Entwicklerdokumentation
- **[API-Dokumentation](API.md)** - API-Referenz

## 🆘 Support

Bei Problemen:
1. Prüfen Sie die **[Installationsübersicht](installation_overview.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`
4. System neu starten: `sudo reboot`

---

**🎉 Das ist alles! Mit diesem Guide können Sie Carambus einfach installieren und verwalten.**

**💡 Tipp**: Für die Entwicklung verwenden Sie die parallelen Docker-Systeme auf dem macOS-Computer, um Inter-System-Kommunikation zu testen!

**🏗️ Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL), beide im Development-Modus testbar!

**🔑 Wichtig**: Alle Installationen verwenden den Standard-Account `www-data` und sind über SSH-Port 8910 erreichbar. Lokalisierung ist nur für lokale Server mit Scoreboards relevant. API-Server und Local-Server können auf derselben Hardware laufen mit unterschiedlichen Installationspfaden (`/var/www/carambus_api` und `/var/www/carambus`).

**📝 Hinweis**: Alle Deploy-Skripte und Dokumentation wurden entsprechend angepasst. Bitte verwenden Sie die aktualisierten Befehle mit `www-data@` und den korrekten Pfaden. 