    # 🍓 Raspberry Pi 4 Setup für Carambus

## 📋 Voraussetzungen

- **Raspberry Pi 4** (2GB RAM minimum, 4GB empfohlen)
- **SD-Karte** (32GB minimum, Class 10 empfohlen)
- **Netzwerkverbindung** (Ethernet oder WiFi)
- **SSH-Zugang** zum Raspberry Pi

## 🚀 Schnellstart

### 1. Raspberry Pi OS installieren

1. **Raspberry Pi Imager** herunterladen: https://www.raspberrypi.com/software/
2. **Raspberry Pi OS Lite** auswählen (ohne Desktop)
3. **SD-Karte** einlegen und **Schreiben** starten
4. **SSH aktivieren** (Advanced Options → Enable SSH)
5. **SD-Karte** in Raspberry Pi einlegen und starten

### 2. SSH-Verbindung herstellen

```bash
# Finde die IP-Adresse deines Pi
ssh pi@192.168.178.XX  # Ersetze XX mit der IP deines Pi

# Standard-Passwort: raspberry
```

### 3. Automatisches Setup ausführen

```bash
# Setup-Skript herunterladen
wget https://raw.githubusercontent.com/your-repo/carambus_api/main/setup_raspberry_pi.sh

# Ausführbar machen
chmod +x setup_raspberry_pi.sh

# Als root ausführen
sudo ./setup_raspberry_pi.sh
```

**Das Skript macht automatisch:**
- ✅ System Update
- ✅ Docker Installation
- ✅ Repository Klonen
- ✅ Container Starten
- ✅ Firewall Konfiguration
- ✅ SSH Sicherung

## 🔧 Manuelles Setup (falls automatisch nicht funktioniert)

### 1. System vorbereiten

```bash
# Update System
sudo apt update && sudo apt upgrade -y

# Notwendige Pakete installieren
sudo apt install -y curl wget git vim htop
```

### 2. Docker installieren

```bash
# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# User zur docker Gruppe hinzufügen
sudo usermod -aG docker $USER

# Neustart für Gruppen-Änderungen
sudo reboot
```

### 3. Docker Compose installieren

```bash
# Docker Compose herunterladen
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Ausführbar machen
sudo chmod +x /usr/local/bin/docker-compose
```

### 4. Carambus installieren

```bash
# Repository klonen
git clone https://github.com/your-repo/carambus_api.git
cd carambus_api

# Umgebungsvariablen konfigurieren
cp env.example .env
nano .env  # Bearbeite die Werte
```

### 5. Container starten

```bash
# Container bauen und starten
docker-compose up -d

# Status prüfen
docker-compose ps
```

## 📝 Konfiguration

### .env Datei bearbeiten

```bash
nano .env
```

**Wichtige Werte:**
```bash
POSTGRES_PASSWORD=dein_sicheres_passwort
RAILS_MASTER_KEY=dein_rails_master_key
```

### Datenbank einrichten

**Option A: Mit SQL-Datei**
```bash
# SQL-Datei kopieren
cp carambus_api_development_20250803_084807.sql.gz db/init/

# Container neu starten
docker-compose restart postgres
```

**Option B: Mit Rails Migrations**
```bash
# Migrationen ausführen
docker-compose exec web bundle exec rails db:migrate
```

## 🔧 Nützliche Befehle

Das Setup-Skript erstellt automatisch nützliche Aliase:

```bash
carambus-status    # Container-Status anzeigen
carambus-logs      # Logs anzeigen
carambus-restart   # Container neu starten
carambus-stop      # Container stoppen
carambus-start     # Container starten
carambus-shell     # Rails-Shell öffnen
carambus-db        # PostgreSQL-Shell öffnen
```

## 🌐 Zugriff auf die Anwendung

Nach dem Setup ist die Anwendung erreichbar unter:

- **HTTP:** http://PI_IP_ADRESSE:80
- **HTTPS:** https://PI_IP_ADRESSE:443
- **Rails:** http://PI_IP_ADRESSE:3000

## 🔒 Sicherheit

Das Setup-Skript konfiguriert automatisch:

- ✅ **SSH-Sicherung** (kein Root-Login, nur Key-Authentifizierung)
- ✅ **Firewall** (nur notwendige Ports offen)
- ✅ **Docker-Isolation** (Container laufen isoliert)

## 🚨 Troubleshooting

### Docker startet nicht
```bash
# Docker Service Status prüfen
sudo systemctl status docker

# Docker Service starten
sudo systemctl start docker
```

### Container starten nicht
```bash
# Logs anzeigen
docker-compose logs

# Container neu starten
docker-compose restart
```

### Ports sind belegt
```bash
# Andere Ports in docker-compose.yml verwenden
nano docker-compose.yml
# Ändere z.B. "80:80" zu "8080:80"
```

### Speicherplatz voll
```bash
# Docker-Images aufräumen
docker system prune -a

# Logs aufräumen
docker-compose logs --tail=100
```

## 📊 Monitoring

### System-Ressourcen prüfen
```bash
htop
```

### Docker-Ressourcen prüfen
```bash
docker stats
```

### Logs überwachen
```bash
# Alle Logs
docker-compose logs -f

# Nur Rails-Logs
docker-compose logs -f web
```

## 🔄 Updates

### Carambus aktualisieren
```bash
# Repository aktualisieren
git pull

# Container neu bauen und starten
docker-compose down
docker-compose up -d --build
```

### System aktualisieren
```bash
sudo apt update && sudo apt upgrade -y
```

## 📞 Support

Bei Problemen:

1. **Logs prüfen:** `docker-compose logs`
2. **Status prüfen:** `docker-compose ps`
3. **Container neu starten:** `docker-compose restart`
4. **System neu starten:** `sudo reboot`

---

**🎉 Das ist alles! Dein Raspberry Pi läuft jetzt mit Carambus in Docker!** 
