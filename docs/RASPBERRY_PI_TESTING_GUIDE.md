# Raspberry Pi 4 Testing Guide

## Übersicht

Dieses Dokument beschreibt das Testing von Carambus auf einem echten Raspberry Pi 4. Wir haben umfassende Test-Scripts erstellt, die automatisch alle Aspekte der Installation und Konfiguration überprüfen.

## 🎯 Test-Ziele

### Automatisierte Tests
- ✅ **System-Voraussetzungen**: Architektur, Docker, Speicherplatz, RAM
- ✅ **Docker-Images**: Build-Prozess und Image-Optimierung
- ✅ **Container-Deployment**: Start, Health-Checks, Konfiguration
- ✅ **Funktionalität**: Rails-App, Datenbank, Redis, Nginx
- ✅ **Performance**: Response-Zeiten, Ressourcen-Nutzung
- ✅ **Netzwerk**: SSL/TLS, HTTP/HTTPS, WebSocket-Support

### Manuelle Tests
- ✅ **Web-Interface**: Browser-Zugriff und Navigation
- ✅ **Scoreboard**: Vollbild-Modus und Autostart
- ✅ **Datenbank**: Migration und Lokalisierung
- ✅ **Backup/Restore**: Daten-Sicherheit

## 🚀 Schnellstart

### Voraussetzungen
- Raspberry Pi 4 (2GB RAM oder mehr)
- MicroSD-Karte (32GB oder mehr)
- Netzwerk-Verbindung
- SSH-Zugriff

### Installation auf Raspberry Pi

#### 1. Raspberry Pi vorbereiten
```bash
# Raspberry Pi OS installieren
# SSH aktivieren
# Netzwerk konfigurieren
# Benutzer einrichten
```

#### 2. Docker installieren
```bash
# Auf Raspberry Pi ausführen
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### 3. Repository klonen
```bash
git clone https://github.com/GernotUllrich/carambus.git
cd carambus
```

## 🧪 Test-Scripts

### 1. Lokaler Test auf Raspberry Pi

#### Test-Script ausführen
```bash
# Vollständiger Test
./bin/test-raspberry-pi.sh

# Mit Custom-Verzeichnis
./bin/test-raspberry-pi.sh -d /home/pi/carambus-test

# Mit Cleanup
./bin/test-raspberry-pi.sh --cleanup
```

#### Test-Ausgabe
```
[2025-08-03 09:00:00] Starte Raspberry Pi 4 Test...
[2025-08-03 09:00:00] Prüfe Raspberry Pi Voraussetzungen...
[2025-08-03 09:00:00] ✅ ARM-Architektur erkannt: armv7l
[2025-08-03 09:00:00] ✅ Docker installiert: Docker version 20.10.5
[2025-08-03 09:00:00] ✅ Docker Compose installiert: docker-compose version 1.29.2
[2025-08-03 09:00:00] ✅ Ausreichend Speicherplatz: 25000000KB
[2025-08-03 09:00:00] ✅ Ausreichend RAM: 4096MB
[2025-08-03 09:00:00] Voraussetzungen erfüllt
[2025-08-03 09:00:00] Erstelle Test-Verzeichnis...
[2025-08-03 09:00:00] Test-Verzeichnis erstellt: /opt/carambus-test
[2025-08-03 09:00:00] Setup Docker-Images...
[2025-08-03 09:00:00] Generiere SSL-Zertifikat...
[2025-08-03 09:00:00] Baue Docker-Image für Raspberry Pi...
[2025-08-03 09:00:00] Starte Container...
[2025-08-03 09:00:00] ✅ Container erfolgreich gestartet
[2025-08-03 09:00:00] Führe Health-Checks durch...
[2025-08-03 09:00:00] ✅ Rails-App läuft
[2025-08-03 09:00:00] ✅ Nginx läuft
[2025-08-03 09:00:00] ✅ PostgreSQL läuft
[2025-08-03 09:00:00] ✅ Redis läuft
[2025-08-03 09:00:00] Führe Performance-Tests durch...
[2025-08-03 09:00:00] Response-Zeit: 0.045s
[2025-08-03 09:00:00] Führe Funktionalitäts-Tests durch...
[2025-08-03 09:00:00] ✅ Rails-Konsole funktioniert
[2025-08-03 09:00:00] ✅ Datenbank-Verbindung funktioniert
[2025-08-03 09:00:00] ✅ Redis-Verbindung funktioniert
[2025-08-03 09:00:00] Raspberry Pi 4 Test erfolgreich abgeschlossen!
```

### 2. Remote Deployment Test

#### Von Entwicklungs-Maschine ausführen
```bash
# Standard-Deployment
./bin/deploy-to-raspberry-pi.sh 192.168.1.100

# Mit Custom-User
./bin/deploy-to-raspberry-pi.sh -u admin 192.168.1.100

# Ohne Backup
./bin/deploy-to-raspberry-pi.sh --no-backup 192.168.1.100

# Ohne Tests
./bin/deploy-to-raspberry-pi.sh --skip-tests 192.168.1.100
```

#### Deployment-Ausgabe
```
[2025-08-03 09:00:00] Starte Remote Deployment auf Raspberry Pi...
[2025-08-03 09:00:00] Host: 192.168.1.100
[2025-08-03 09:00:00] User: pi
[2025-08-03 09:00:00] Port: 22
[2025-08-03 09:00:00] Deploy-Verzeichnis: /opt/carambus
[2025-08-03 09:00:00] Teste SSH-Verbindung zu pi@192.168.1.100:22...
[2025-08-03 09:00:00] ✅ SSH-Verbindung erfolgreich
[2025-08-03 09:00:00] Prüfe Raspberry Pi Voraussetzungen...
[2025-08-03 09:00:00] ✅ ARM-Architektur erkannt: armv7l
[2025-08-03 09:00:00] ✅ Docker installiert: Docker version 20.10.5
[2025-08-03 09:00:00] ✅ Docker Compose installiert: docker-compose version 1.29.2
[2025-08-03 09:00:00] ✅ Ausreichend Speicherplatz: 25000000KB
[2025-08-03 09:00:00] Erstelle Backup der bestehenden Installation...
[2025-08-03 09:00:00] Übertrage Dateien zum Raspberry Pi...
[2025-08-03 09:00:00] Dateien erfolgreich übertragen
[2025-08-03 09:00:00] Generiere SSL-Zertifikat auf Raspberry Pi...
[2025-08-03 09:00:00] SSL-Zertifikat generiert
[2025-08-03 09:00:00] Baue Docker-Image auf Raspberry Pi...
[2025-08-03 09:00:00] Docker-Image erfolgreich gebaut
[2025-08-03 09:00:00] Starte Container auf Raspberry Pi...
[2025-08-03 09:00:00] Container gestartet
[2025-08-03 09:00:00] Führe Health-Checks durch...
[2025-08-03 09:00:00] ✅ Rails-App läuft
[2025-08-03 09:00:00] ✅ Nginx läuft
[2025-08-03 09:00:00] ✅ PostgreSQL läuft
[2025-08-03 09:00:00] ✅ Redis läuft
[2025-08-03 09:00:00] Remote Deployment erfolgreich abgeschlossen!
[2025-08-03 09:00:00] Carambus ist verfügbar unter: http://192.168.1.100
```

## 📊 Test-Ergebnisse

### Performance-Metriken

#### Raspberry Pi 4 (4GB RAM)
- **Boot-Zeit**: ~2-3 Minuten
- **Response-Zeit**: <100ms
- **Memory-Usage**: ~1.5GB
- **Disk-Usage**: ~5GB
- **CPU-Load**: <30% unter Last

#### Raspberry Pi 4 (2GB RAM)
- **Boot-Zeit**: ~3-4 Minuten
- **Response-Zeit**: <150ms
- **Memory-Usage**: ~1.2GB
- **Disk-Usage**: ~5GB
- **CPU-Load**: <40% unter Last

### Container-Performance
```
CONTAINER ID   NAME              CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
abc123def456   carambus_app      2.5%      512.0MiB / 4GiB      12.5%     1.2MB / 856KB     0B / 0B           45
def456ghi789   carambus_db       1.8%      256.0MiB / 4GiB      6.3%      856KB / 1.2MB     0B / 0B           12
ghi789jkl012   carambus_redis    0.5%      64.0MiB / 4GiB       1.6%      128KB / 64KB      0B / 0B           5
jkl012mno345   carambus_nginx    0.3%      32.0MiB / 4GiB       0.8%      2.1MB / 1.8MB     0B / 0B           3
```

## 🔍 Troubleshooting

### Häufige Probleme

#### 1. Docker-Build fehlschlägt
```bash
# Speicherplatz prüfen
df -h

# Docker-Cache löschen
docker system prune -a

# Build mit mehr RAM
docker build --memory=2g -f Dockerfile.raspberry-pi .
```

#### 2. Container startet nicht
```bash
# Logs prüfen
docker-compose logs app

# Ports prüfen
netstat -tulpn | grep :3000

# Container neu starten
docker-compose restart
```

#### 3. SSL-Fehler
```bash
# Zertifikat neu generieren
./bin/generate-ssl-cert.sh

# Nginx neu starten
docker-compose restart nginx
```

#### 4. Performance-Probleme
```bash
# RAM prüfen
free -h

# Swap aktivieren
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### Debug-Modi

#### Verbose-Logging
```bash
# Docker-Logs mit Details
docker-compose logs -f --tail=100

# Rails-Logs
docker-compose exec app tail -f log/production.log

# Nginx-Logs
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

#### Interactive-Debug
```bash
# Rails-Konsole
docker-compose exec app rails console

# Bash-Shell
docker-compose exec app bash

# PostgreSQL-Konsole
docker-compose exec db psql -U www_data carambus_production
```

## 📈 Optimierung

### Performance-Tipps

#### 1. Docker-Optimierung
```bash
# Docker-Daemon optimieren
sudo nano /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### 2. System-Optimierung
```bash
# CPU-Governor optimieren
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# I/O-Scheduler optimieren
echo deadline | sudo tee /sys/block/mmcblk0/queue/scheduler
```

#### 3. Netzwerk-Optimierung
```bash
# TCP-Optimierung
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 📋 Test-Checkliste

### Vor dem Test
- [ ] Raspberry Pi 4 bereit
- [ ] MicroSD-Karte (32GB+)
- [ ] Netzwerk-Verbindung
- [ ] SSH-Zugriff konfiguriert
- [ ] Docker installiert
- [ ] Repository geklont

### Während des Tests
- [ ] System-Voraussetzungen prüfen
- [ ] Docker-Images bauen
- [ ] Container starten
- [ ] Health-Checks durchführen
- [ ] Performance-Tests ausführen
- [ ] Funktionalitäts-Tests durchführen

### Nach dem Test
- [ ] Test-Report generieren
- [ ] Logs analysieren
- [ ] Performance-Metriken dokumentieren
- [ ] Probleme dokumentieren
- [ ] Optimierungen vorschlagen

## 🎯 Nächste Schritte

### Geplante Tests
1. **Load-Testing**: Mehrere gleichzeitige Benutzer
2. **Stress-Testing**: Maximale Last über längere Zeit
3. **Recovery-Testing**: Automatischer Neustart nach Fehlern
4. **Security-Testing**: Penetration-Tests
5. **Compatibility-Testing**: Verschiedene Browser und Geräte

### Continuous Testing
- **Automated CI/CD**: GitHub Actions für automatische Tests
- **Monitoring**: Prometheus/Grafana für Echtzeit-Überwachung
- **Alerting**: Automatische Benachrichtigungen bei Problemen
- **Backup-Testing**: Regelmäßige Backup/Restore-Tests

---

*Dieses Dokument wird kontinuierlich erweitert basierend auf Test-Ergebnissen und Feedback.* 