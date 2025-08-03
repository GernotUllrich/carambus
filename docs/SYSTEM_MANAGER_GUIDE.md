# Carambus System-Manager Anleitung

## Übersicht

Diese Anleitung richtet sich an lokale System-Manager, die Carambus-Server installieren und warten müssen, ohne tiefe technische Kenntnisse zu haben. Alle Prozesse sind so weit wie möglich automatisiert.

## 🚀 Schnellstart: Neue Installation

### Voraussetzungen
- Raspberry Pi 4 (4GB RAM empfohlen)
- Micro SD-Karte (32GB oder größer)
- Netzwerk-Anschluss (LAN oder WLAN)
- Monitor/TV für Scoreboard-Anzeige

### Installation in 3 Schritten

#### Schritt 1: Raspberry Pi vorbereiten
1. **Raspberry Pi Imager** herunterladen: https://www.raspberrypi.com/software/
2. **Raspberry Pi OS (32-bit)** auswählen
3. **SD-Karte** einlegen und Image schreiben
4. **SD-Karte** in Raspberry Pi einlegen und starten

#### Schritt 2: Automatische Installation
```bash
# Nach dem ersten Boot des Raspberry Pi:
sudo apt update
sudo apt install -y curl

# Carambus-Installation starten
curl -fsSL https://raw.githubusercontent.com/GernotUllrich/carambus/main/bin/carambus-install.sh | bash
```

#### Schritt 3: Lokalisierung konfigurieren
1. **Browser öffnen**: http://localhost:3000/setup
2. **Region auswählen** (z.B. "Schleswig-Holstein")
3. **Club auswählen** (z.B. "Billard Club Wedel")
4. **Location konfigurieren** (Name, Adresse, etc.)
5. **Tische definieren** (Anzahl und Typ)
6. **Benutzer anlegen** (Admin und Scoreboard)
7. **Konfiguration speichern**

### Automatischer Scoreboard-Start
Das Scoreboard startet automatisch beim nächsten Boot und zeigt:
- Aktuelle Reservierungen
- Turnier-Informationen
- Live-Scores

## 🔄 Migration zu neuer Version

### Vor der Migration: Backup erstellen
```bash
# Backup der aktuellen Konfiguration erstellen
sudo /opt/carambus/bin/backup-localization.sh

# Backup-Datei sichern (auf USB-Stick oder Cloud)
cp /opt/carambus/backup/carambus_localization_*.tar.gz /media/usb/
```

### Migration durchführen
```bash
# Neue Version installieren
curl -fsSL https://raw.githubusercontent.com/GernotUllrich/carambus/main/bin/carambus-install.sh | bash

# Backup wiederherstellen
sudo /opt/carambus/bin/restore-localization.sh /media/usb/carambus_localization_*.tar.gz
```

### Nach der Migration: Testen
1. **Web-Interface prüfen**: http://localhost:3000
2. **Scoreboard testen**: Automatischer Start beim Boot
3. **Benutzer-Login testen**: Admin und Scoreboard
4. **Tisch-Konfiguration prüfen**: Alle Tische vorhanden

## 🛠️ Wartung und Troubleshooting

### Häufige Probleme

#### Problem: Scoreboard startet nicht
```bash
# Diagnose
sudo systemctl status scoreboard
journalctl -u scoreboard -f

# Lösung
sudo systemctl restart scoreboard
```

#### Problem: Web-Interface nicht erreichbar
```bash
# Diagnose
curl -I http://localhost:3000

# Lösung
sudo systemctl restart carambus
```

#### Problem: Datenbank-Fehler
```bash
# Diagnose
sudo docker-compose logs db

# Lösung
sudo docker-compose restart db
```

### Regelmäßige Wartung

#### Tägliche Checks
- Scoreboard funktioniert
- Web-Interface erreichbar
- Automatische Updates laufen

#### Wöchentliche Checks
- Backup erstellen
- Log-Dateien prüfen
- Speicherplatz kontrollieren

#### Monatliche Checks
- System-Updates
- Sicherheits-Patches
- Performance-Optimierung

## 📊 Monitoring und Status

### System-Status prüfen
```bash
# Vollständigen Status anzeigen
sudo /opt/carambus/bin/status.sh

# Nur kritische Services
sudo /opt/carambus/bin/health-check.sh
```

### Log-Dateien einsehen
```bash
# Carambus-Logs
sudo tail -f /opt/carambus/log/production.log

# Scoreboard-Logs
sudo tail -f /tmp/scoreboard-autostart.log

# System-Logs
sudo journalctl -u carambus -f
```

## 🔧 Erweiterte Konfiguration

### Netzwerk-Konfiguration
```bash
# Statische IP-Adresse setzen
sudo nano /etc/dhcpcd.conf

# Beispiel:
# interface eth0
# static ip_address=192.168.178.100/24
# static routers=192.168.178.1
# static domain_name_servers=8.8.8.8
```

### WLAN-Konfiguration
```bash
# WLAN-Netzwerk hinzufügen
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Beispiel:
# network={
#     ssid="Ihr-WLAN-Name"
#     psk="Ihr-WLAN-Passwort"
# }
```

### Firewall-Konfiguration
```bash
# Standard-Ports freigeben
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw allow 3000  # Carambus
```

## 📱 Remote-Management

### SSH-Zugang
```bash
# SSH aktivieren
sudo systemctl enable ssh
sudo systemctl start ssh

# Passwort ändern
sudo passwd pi
```

### Remote-Zugriff
```bash
# Von einem anderen Computer:
ssh pi@192.168.178.100

# Dateien übertragen:
scp backup.tar.gz pi@192.168.178.100:/home/pi/
```

## 🔒 Sicherheit

### Standard-Sicherheitsmaßnahmen
- **Passwort ändern**: `sudo passwd pi`
- **SSH-Schlüssel verwenden**: Statt Passwort-Login
- **Firewall aktivieren**: `sudo ufw enable`
- **Regelmäßige Updates**: `sudo apt update && sudo apt upgrade`

### Backup-Strategie
- **Tägliche Backups**: Automatisch um 2:00 Uhr
- **Wöchentliche Backups**: Auf externem Speicher
- **Monatliche Backups**: Auf Cloud-Speicher

## 📞 Support

### Bei Problemen
1. **Logs prüfen**: Siehe Abschnitt "Monitoring"
2. **Backup wiederherstellen**: Falls nötig
3. **Support kontaktieren**: gernot.ullrich@gmx.de

### Nützliche Befehle
```bash
# System-Informationen
uname -a
df -h
free -h

# Service-Status
sudo systemctl status carambus
sudo systemctl status scoreboard
sudo docker-compose ps

# Netzwerk-Status
ip addr show
ping 8.8.8.8
```

## 📚 Zusätzliche Ressourcen

### Dokumentation
- **Entwickler-Dokumentation**: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
- **API-Dokumentation**: [API.md](API.md)
- **Scoreboard-Setup**: [scoreboard_autostart_setup.md](scoreboard_autostart_setup.md)

### Community
- **GitHub Issues**: Bug-Reports und Feature-Requests
- **GitHub Discussions**: Fragen und Community-Support
- **E-Mail Support**: gernot.ullrich@gmx.de

---

*Diese Anleitung wird kontinuierlich erweitert. Für Fragen oder Verbesserungsvorschläge kontaktieren Sie den Support.* 