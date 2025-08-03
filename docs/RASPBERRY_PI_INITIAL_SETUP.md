# Raspberry Pi 4 Initial Setup Guide

## 🎯 Übersicht

Diese Anleitung führt Sie durch die komplette initiale Installation von Carambus auf Ihrem Raspberry Pi 4 mit der 32GB SD-Karte.

## 📋 Hardware-Checkliste

### Vorbereitung
- [ ] **Raspberry Pi 4** (2GB RAM oder mehr)
- [ ] **32GB MicroSD-Karte** (Class 10 empfohlen)
- [ ] **Stromversorgung** (5V/3A USB-C)
- [ ] **Netzwerk-Kabel** oder WLAN-Zugang
- [ ] **Computer** für Image-Erstellung
- [ ] **SD-Karten-Reader** (falls nicht im Computer)

## 🚀 Schritt 1: Raspberry Pi OS Installation

### 1.1 Raspberry Pi Imager herunterladen
```bash
# Download von: https://www.raspberrypi.com/software/
# Für macOS, Windows oder Linux verfügbar
```

### 1.2 Image erstellen
1. **Raspberry Pi Imager** öffnen
2. **"Choose OS"** → **"Raspberry Pi OS (32-bit)"**
3. **"Choose Storage"** → **32GB SD-Karte auswählen**
4. **"Write"** klicken
5. **Warten** bis Schreibvorgang abgeschlossen (5-10 Minuten)

### 1.3 SSH aktivieren
```bash
# Nach dem Schreiben auf SD-Karte:
# Boot-Verzeichnis öffnen
# Leere Datei "ssh" erstellen (ohne Erweiterung)
# Oder über Imager: "Advanced Options" → "Enable SSH"
```

### 1.4 WLAN konfigurieren (optional)
```bash
# Datei "wpa_supplicant.conf" im Boot-Verzeichnis erstellen:
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="IHR_WLAN_NAME"
    psk="IHR_WLAN_PASSWORT"
    key_mgmt=WPA-PSK
}
```

## 🔧 Schritt 2: Raspberry Pi starten

### 2.1 Hardware verbinden
```bash
# 1. SD-Karte in Raspberry Pi einlegen
# 2. Netzwerk-Kabel anschließen (oder WLAN konfiguriert)
# 3. Stromversorgung anschließen
# 4. Warten bis Boot abgeschlossen (LED stoppt zu blinken)
```

### 2.2 IP-Adresse finden
```bash
# Option 1: Router-Interface
# Router-Admin-Interface öffnen (meist 192.168.1.1)
# Geräte-Liste durchsuchen nach "raspberrypi"

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

# Erwartete Ausgabe:
# pi@raspberrypi:~ $
```

## 🛠️ Schritt 3: Quick-Start Installation

### 3.1 Quick-Start Script ausführen
```bash
# Auf Ihrem Computer (nicht Raspberry Pi):
cd ~/carambus  # oder wo Ihr Repository ist

# Script ausführbar machen
chmod +x bin/quick-start-raspberry-pi.sh

# Vollständige Installation (IP-Adresse anpassen)
./bin/quick-start-raspberry-pi.sh 192.168.1.100
```

### 3.2 Erwartete Ausgabe
```
[2025-08-03 10:00:00] Starte Quick-Start für Raspberry Pi 4...
[2025-08-03 10:00:00] IP-Adresse: 192.168.1.100
[2025-08-03 10:00:00] Teste SSH-Verbindung zu pi@192.168.1.100...
[2025-08-03 10:00:00] ✅ SSH-Verbindung erfolgreich
[2025-08-03 10:00:00] Klone Repository auf Raspberry Pi...
[2025-08-03 10:00:00] ✅ Repository bereit
[2025-08-03 10:00:00] Führe Setup auf Raspberry Pi aus...
[2025-08-03 10:00:00] ✅ Setup abgeschlossen
[2025-08-03 10:00:00] Neustart empfohlen...
Raspberry Pi neustarten? (j/n): j
[2025-08-03 10:00:00] Starte Raspberry Pi neu...
[2025-08-03 10:00:00] Warte auf Neustart...
[2025-08-03 10:00:00] ✅ Raspberry Pi wieder online
[2025-08-03 10:00:00] Führe Test auf Raspberry Pi aus...
[2025-08-03 10:00:00] ✅ Test abgeschlossen
[2025-08-03 10:00:00] Teste Web-Interface...
[2025-08-03 10:00:00] ✅ HTTP-Interface erreichbar
[2025-08-03 10:00:00] ✅ HTTPS-Interface erreichbar
[2025-08-03 10:00:00] ✅ Scoreboard erreichbar
[2025-08-03 10:00:00] Quick-Start erfolgreich abgeschlossen!
```

## 🌐 Schritt 4: Web-Interface Test

### 4.1 Browser-Zugriff
```bash
# Im Browser öffnen:
http://192.168.1.100
https://192.168.1.100

# (IP-Adresse durch Ihre ersetzen)
```

### 4.2 SSL-Zertifikat bestätigen
```bash
# Bei HTTPS-Warnung:
# 1. "Erweitert" klicken
# 2. "Trotzdem fortfahren" klicken
# 3. "Sicherheit" → "Zertifikat anzeigen" → "Vertrauen"
```

### 4.3 Erwartete Anzeige
- **Carambus-Logo** sollte sichtbar sein
- **Navigation** sollte funktionieren
- **Responsive Design** sollte auf verschiedenen Bildschirmgrößen funktionieren
- **Scoreboard** sollte im Vollbild-Modus funktionieren

## 📊 Schritt 5: Performance-Check

### 5.1 System-Ressourcen prüfen
```bash
# SSH-Verbindung zum Raspberry Pi
ssh pi@192.168.1.100

# System-Status
htop

# Speicherplatz
df -h

# Docker-Container
docker stats
```

### 5.2 Erwartete Performance
```bash
# Raspberry Pi 4 (4GB RAM):
# - CPU-Load: <30%
# - Memory-Usage: ~1.5GB
# - Disk-Usage: ~5GB
# - Response-Zeit: <100ms

# Raspberry Pi 4 (2GB RAM):
# - CPU-Load: <40%
# - Memory-Usage: ~1.2GB
# - Disk-Usage: ~5GB
# - Response-Zeit: <150ms
```

## 🔍 Schritt 6: Troubleshooting

### 6.1 Häufige Probleme

#### SSH-Verbindung fehlschlägt
```bash
# 1. IP-Adresse prüfen
ping 192.168.1.100

# 2. SSH-Service prüfen
ssh -v pi@192.168.1.100

# 3. Passwort zurücksetzen
# SD-Karte in Computer einlegen
# /etc/ssh/sshd_config bearbeiten
```

#### Docker-Build fehlschlägt
```bash
# Speicherplatz prüfen
df -h

# Docker-Cache löschen
docker system prune -a

# Build mit mehr RAM
docker build --memory=2g -f Dockerfile.raspberry-pi .
```

#### Web-Interface nicht erreichbar
```bash
# Container-Status prüfen
docker-compose ps

# Logs analysieren
docker-compose logs app
docker-compose logs nginx

# Ports prüfen
netstat -tulpn | grep :3000
```

### 6.2 Debug-Modi

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

## 📋 Schritt 7: Test-Checkliste

### Vor der Installation
- [ ] Raspberry Pi 4 bereit
- [ ] 32GB SD-Karte bereit
- [ ] Stromversorgung bereit
- [ ] Netzwerk-Verbindung verfügbar
- [ ] Computer für Image-Erstellung bereit
- [ ] SSH-Client installiert

### Während der Installation
- [ ] Raspberry Pi OS Image erstellt
- [ ] SSH aktiviert
- [ ] WLAN konfiguriert (optional)
- [ ] Raspberry Pi gestartet
- [ ] IP-Adresse gefunden
- [ ] SSH-Verbindung getestet
- [ ] Quick-Start Script ausgeführt
- [ ] Setup abgeschlossen
- [ ] Test erfolgreich
- [ ] Web-Interface getestet

### Nach der Installation
- [ ] Performance-Metriken dokumentiert
- [ ] Logs analysiert
- [ ] Probleme dokumentiert
- [ ] Optimierungen notiert
- [ ] Backup erstellt

## 🎯 Schritt 8: Nächste Schritte

### 8.1 Lokalisierung
```bash
# Web-basiertes Setup-Interface entwickeln
# Region, Club, Location konfigurieren
# Spieltische definieren
# Benutzer anlegen
```

### 8.2 Production-Deployment
```bash
# SSL-Zertifikat von Let's Encrypt
# Domain konfigurieren
# Backup-Strategie implementieren
# Monitoring einrichten
```

### 8.3 Continuous Integration
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

*Diese Anleitung wird kontinuierlich erweitert basierend auf Installations-Ergebnissen und Feedback.* 