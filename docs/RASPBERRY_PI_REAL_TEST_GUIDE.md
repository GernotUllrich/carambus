# Raspberry Pi 4 Real Testing Guide

## 🎯 Übersicht

Dieses Dokument führt Sie durch das komplette Testing von Carambus auf einem echten Raspberry Pi 4. Wir werden Schritt für Schritt vorgehen und alle Aspekte der Installation und Konfiguration testen.

## 📋 Vorbereitung

### Hardware-Anforderungen
- **Raspberry Pi 4** (2GB RAM oder mehr empfohlen)
- **MicroSD-Karte** (32GB oder mehr, Class 10)
- **Netzwerk-Kabel** oder WLAN-Verbindung
- **Stromversorgung** (5V/3A USB-C)
- **Monitor/Display** (optional für direkten Zugriff)

### Software-Vorbereitung
- **Raspberry Pi Imager** herunterladen
- **Raspberry Pi OS** (32-bit) Image
- **SSH-Client** (Terminal, PuTTY, etc.)

## 🚀 Schritt 1: Raspberry Pi OS Installation

### 1.1 Image erstellen
```bash
# Raspberry Pi Imager öffnen
# "Raspberry Pi OS (32-bit)" auswählen
# MicroSD-Karte einlegen
# "Write" klicken
# Warten bis Schreibvorgang abgeschlossen
```

### 1.2 SSH aktivieren
```bash
# Auf MicroSD-Karte nach dem Schreiben:
# "ssh" Datei im Boot-Verzeichnis erstellen (leer)
# Oder über Raspberry Pi Imager: "Advanced Options" → "Enable SSH"
```

### 1.3 Netzwerk konfigurieren
```bash
# WLAN (optional):
# wpa_supplicant.conf im Boot-Verzeichnis erstellen:
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="IHR_WLAN_NAME"
    psk="IHR_WLAN_PASSWORT"
    key_mgmt=WPA-PSK
}
```

## 🔧 Schritt 2: Erste Konfiguration

### 2.1 Raspberry Pi starten
```bash
# MicroSD-Karte in Raspberry Pi einlegen
# Stromversorgung anschließen
# Warten bis Boot abgeschlossen (LED stoppt zu blinken)
```

### 2.2 IP-Adresse finden
```bash
# Option 1: Router-Interface
# Router-Admin-Interface öffnen
# Geräte-Liste durchsuchen

# Option 2: Netzwerk-Scan
nmap -sn 192.168.1.0/24

# Option 3: Raspberry Pi Finder
# https://www.raspberrypi.org/software/
```

### 2.3 SSH-Verbindung testen
```bash
# Standard-Zugriff
ssh pi@192.168.1.100

# Passwort: raspberry
# (oder das, was Sie im Imager gesetzt haben)
```

## 🛠️ Schritt 3: System-Setup

### 3.1 Repository klonen
```bash
# Auf Raspberry Pi ausführen
cd ~
git clone https://github.com/GernotUllrich/carambus.git
cd carambus
```

### 3.2 Setup-Script ausführen
```bash
# Script ausführbar machen
chmod +x bin/setup-raspberry-pi.sh

# Vollständiges Setup
./bin/setup-raspberry-pi.sh

# Oder mit Optionen
./bin/setup-raspberry-pi.sh --no-update
```

### 3.3 Neustart
```bash
# Nach Setup empfohlen
sudo reboot

# Nach Neustart wieder verbinden
ssh pi@192.168.1.100
```

## 🧪 Schritt 4: Carambus-Test

### 4.1 Repository aktualisieren
```bash
# Nach Neustart
cd ~/carambus
git pull origin master
```

### 4.2 Test-Script ausführen
```bash
# Vollständiger Test
./bin/test-raspberry-pi.sh

# Mit Custom-Verzeichnis
./bin/test-raspberry-pi.sh -d /home/pi/carambus-test

# Mit Cleanup
./bin/test-raspberry-pi.sh --cleanup
```

### 4.3 Test-Ausgabe überwachen
```bash
# Erwartete Ausgabe:
[2025-08-03 10:00:00] Starte Raspberry Pi 4 Test...
[2025-08-03 10:00:00] Prüfe Raspberry Pi Voraussetzungen...
[2025-08-03 10:00:00] ✅ ARM-Architektur erkannt: armv7l
[2025-08-03 10:00:00] ✅ Docker installiert: Docker version 20.10.5
[2025-08-03 10:00:00] ✅ Docker Compose installiert: docker-compose version 1.29.2
[2025-08-03 10:00:00] ✅ Ausreichend Speicherplatz: 25000000KB
[2025-08-03 10:00:00] ✅ Ausreichend RAM: 4096MB
[2025-08-03 10:00:00] Voraussetzungen erfüllt
[2025-08-03 10:00:00] Erstelle Test-Verzeichnis...
[2025-08-03 10:00:00] Test-Verzeichnis erstellt: /opt/carambus-test
[2025-08-03 10:00:00] Setup Docker-Images...
[2025-08-03 10:00:00] Generiere SSL-Zertifikat...
[2025-08-03 10:00:00] Baue Docker-Image für Raspberry Pi...
[2025-08-03 10:00:00] Starte Container...
[2025-08-03 10:00:00] ✅ Container erfolgreich gestartet
[2025-08-03 10:00:00] Führe Health-Checks durch...
[2025-08-03 10:00:00] ✅ Rails-App läuft
[2025-08-03 10:00:00] ✅ Nginx läuft
[2025-08-03 10:00:00] ✅ PostgreSQL läuft
[2025-08-03 10:00:00] ✅ Redis läuft
[2025-08-03 10:00:00] Führe Performance-Tests durch...
[2025-08-03 10:00:00] Response-Zeit: 0.045s
[2025-08-03 10:00:00] Führe Funktionalitäts-Tests durch...
[2025-08-03 10:00:00] ✅ Rails-Konsole funktioniert
[2025-08-03 10:00:00] ✅ Datenbank-Verbindung funktioniert
[2025-08-03 10:00:00] ✅ Redis-Verbindung funktioniert
[2025-08-03 10:00:00] Raspberry Pi 4 Test erfolgreich abgeschlossen!
```

## 🌐 Schritt 5: Web-Interface Test

### 5.1 Browser-Zugriff
```bash
# Im Browser öffnen:
http://192.168.1.100
https://192.168.1.100

# (IP-Adresse durch Ihre ersetzen)
```

### 5.2 Erwartete Anzeige
- **Carambus-Logo** sollte sichtbar sein
- **Navigation** sollte funktionieren
- **SSL-Warnung** (selbst-signiert) - "Erweitert" → "Trotzdem fortfahren"
- **Responsive Design** sollte auf verschiedenen Bildschirmgrößen funktionieren

### 5.3 Scoreboard-Test
```bash
# Scoreboard-URL testen
curl -f http://192.168.1.100/scoreboard

# Vollbild-Modus testen (im Browser)
# F11 drücken für Vollbild
```

## 📊 Schritt 6: Performance-Monitoring

### 6.1 System-Ressourcen überwachen
```bash
# CPU und RAM
htop

# Disk-Usage
df -h

# Docker-Container
docker stats

# Netzwerk
nload
```

### 6.2 Container-Logs analysieren
```bash
# Alle Container-Logs
docker-compose logs

# Spezifische Container-Logs
docker-compose logs app
docker-compose logs nginx
docker-compose logs db
docker-compose logs redis

# Live-Logs
docker-compose logs -f app
```

### 6.3 Performance-Metriken sammeln
```bash
# Response-Zeit testen
time curl -s http://192.168.1.100/health

# Load-Test (einfach)
for i in {1..10}; do
  curl -s http://192.168.1.100/health
  sleep 1
done
```

## 🔍 Schritt 7: Troubleshooting

### 7.1 Häufige Probleme

#### Docker-Build fehlschlägt
```bash
# Speicherplatz prüfen
df -h

# Docker-Cache löschen
docker system prune -a

# Build mit mehr RAM
docker build --memory=2g -f Dockerfile.raspberry-pi .
```

#### Container startet nicht
```bash
# Logs prüfen
docker-compose logs app

# Ports prüfen
netstat -tulpn | grep :3000

# Container neu starten
docker-compose restart
```

#### SSL-Fehler
```bash
# Zertifikat neu generieren
./bin/generate-ssl-cert.sh

# Nginx neu starten
docker-compose restart nginx
```

#### Performance-Probleme
```bash
# RAM prüfen
free -h

# Swap aktivieren
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### 7.2 Debug-Modi

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

## 📈 Schritt 8: Optimierung

### 8.1 System-Optimierung
```bash
# CPU-Governor optimieren
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# I/O-Scheduler optimieren
echo deadline | sudo tee /sys/block/mmcblk0/queue/scheduler

# TCP-Optimierung
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 8.2 Docker-Optimierung
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

# Docker-Service neu starten
sudo systemctl restart docker
```

## 📋 Schritt 9: Test-Checkliste

### Vor dem Test
- [ ] Raspberry Pi 4 bereit
- [ ] MicroSD-Karte (32GB+)
- [ ] Netzwerk-Verbindung
- [ ] SSH-Zugriff konfiguriert
- [ ] Repository geklont
- [ ] Setup-Script ausgeführt

### Während des Tests
- [ ] System-Voraussetzungen prüfen
- [ ] Docker-Images bauen
- [ ] Container starten
- [ ] Health-Checks durchführen
- [ ] Performance-Tests ausführen
- [ ] Funktionalitäts-Tests durchführen
- [ ] Web-Interface testen
- [ ] Scoreboard testen

### Nach dem Test
- [ ] Test-Report generieren
- [ ] Logs analysieren
- [ ] Performance-Metriken dokumentieren
- [ ] Probleme dokumentieren
- [ ] Optimierungen vorschlagen
- [ ] Backup erstellen

## 🎯 Schritt 10: Nächste Schritte

### 10.1 Lokalisierung
```bash
# Web-basiertes Setup-Interface entwickeln
# Region, Club, Location konfigurieren
# Spieltische definieren
# Benutzer anlegen
```

### 10.2 Production-Deployment
```bash
# SSL-Zertifikat von Let's Encrypt
# Domain konfigurieren
# Backup-Strategie implementieren
# Monitoring einrichten
```

### 10.3 Continuous Integration
```bash
# GitHub Actions für automatische Tests
# Docker Registry für Images
# Automated Deployment
# Monitoring Dashboard
```

## 📊 Erwartete Ergebnisse

### Performance-Metriken (Raspberry Pi 4 4GB)
- **Boot-Zeit**: 2-3 Minuten
- **Response-Zeit**: <100ms
- **Memory-Usage**: ~1.5GB
- **Disk-Usage**: ~5GB
- **CPU-Load**: <30% unter Last

### Container-Performance
```
CONTAINER ID   NAME              CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
abc123def456   carambus_app      2.5%      512.0MiB / 4GiB      12.5%     1.2MB / 856KB     0B / 0B           45
def456ghi789   carambus_db       1.8%      256.0MiB / 4GiB      6.3%      856KB / 1.2MB     0B / 0B           12
ghi789jkl012   carambus_redis    0.5%      64.0MiB / 4GiB       1.6%      128KB / 64KB      0B / 0B           5
jkl012mno345   carambus_nginx    0.3%      32.0MiB / 4GiB       0.8%      2.1MB / 1.8MB     0B / 0B           3
```

---

*Dieses Dokument wird kontinuierlich erweitert basierend auf Test-Ergebnissen und Feedback.* 