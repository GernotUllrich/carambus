# SD-Karten-Vorbereitung für Raspberry Pi 4

## 🎯 Übersicht

Diese Anleitung führt Sie durch die Vorbereitung der 32GB SD-Karte für Ihren Raspberry Pi 4. Wir werden das Raspberry Pi OS Image erstellen und SSH/WLAN konfigurieren.

## 📋 Vorbereitung

### Benötigte Software
- **Raspberry Pi Imager** (bereits heruntergeladen)
- **32GB MicroSD-Karte** (Class 10 empfohlen)
- **SD-Karten-Reader** (falls nicht im Computer)

### System-Anforderungen
- **macOS, Windows oder Linux**
- **Mindestens 8GB freier Speicherplatz**
- **Internet-Verbindung** für Image-Download

## 🚀 Schritt 1: Raspberry Pi Imager öffnen

### 1.1 Imager starten
```bash
# Raspberry Pi Imager öffnen
# Sollte bereits installiert sein
```

### 1.2 OS auswählen
```bash
# "Choose OS" klicken
# "Raspberry Pi OS (32-bit)" auswählen
# (NICHT 64-bit für bessere Kompatibilität)
```

### 1.3 SD-Karte auswählen
```bash
# "Choose Storage" klicken
# 32GB SD-Karte auswählen
# WICHTIG: Richtige Karte auswählen!
```

## 🔧 Schritt 2: Image erstellen

### 2.1 Schreibvorgang starten
```bash
# "Write" klicken
# Bestätigung: "Yes"
# Warten bis Schreibvorgang abgeschlossen (5-10 Minuten)
```

### 2.2 Erwartete Ausgabe
```
Writing Raspberry Pi OS to SD card...
- Downloading image...
- Verifying image...
- Writing image...
- Verifying write...
Write successful!
```

## 🔐 Schritt 3: SSH aktivieren

### 3.1 Boot-Verzeichnis öffnen
```bash
# Nach erfolgreichem Schreiben:
# SD-Karte im Finder/Explorer öffnen
# "boot" Verzeichnis öffnen
```

### 3.2 SSH-Datei erstellen
```bash
# Leere Datei "ssh" erstellen (ohne Erweiterung)
# macOS: Terminal → touch /Volumes/boot/ssh
# Windows: Rechtsklick → Neu → Textdatei → "ssh" (ohne .txt)
# Linux: touch /media/boot/ssh
```

### 3.3 Alternative: Imager Advanced Options
```bash
# Im Raspberry Pi Imager:
# "Advanced Options" → "Enable SSH"
# "Set username and password" (optional)
```

## 📡 Schritt 4: WLAN konfigurieren (optional)

### 4.1 WLAN-Datei erstellen
```bash
# Datei "wpa_supplicant.conf" im Boot-Verzeichnis erstellen
# Inhalt:
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="IHR_WLAN_NAME"
    psk="IHR_WLAN_PASSWORT"
    key_mgmt=WPA-PSK
}
```

### 4.2 Automatische WLAN-Konfiguration
```bash
# Mit unserem Script:
chmod +x bin/prepare-sd-card.sh
./bin/prepare-sd-card.sh --wifi-ssid "IHR_WLAN" --wifi-password "IHR_PASSWORT" /dev/disk2
```

## 🔍 Schritt 5: SD-Karte prüfen

### 5.1 Dateien überprüfen
```bash
# Im Boot-Verzeichnis sollten vorhanden sein:
# - cmdline.txt
# - config.txt
# - kernel.img
# - ssh (leere Datei)
# - wpa_supplicant.conf (falls WLAN konfiguriert)
```

### 5.2 Automatische Prüfung
```bash
# Mit unserem Script:
./bin/prepare-sd-card.sh /dev/disk2
```

## 📋 Schritt 6: SD-Karte vorbereiten

### 6.1 SD-Karte sicher entfernen
```bash
# macOS: SD-Karte auswerfen
# Windows: Sicher entfernen
# Linux: umount /dev/sdX
```

### 6.2 SD-Karte in Raspberry Pi einlegen
```bash
# 1. Raspberry Pi ausschalten (falls an)
# 2. SD-Karte in Slot einlegen
# 3. Stromversorgung anschließen
# 4. Warten bis Boot abgeschlossen (LED stoppt zu blinken)
```

## 🌐 Schritt 7: Netzwerk-Verbindung

### 7.1 IP-Adresse finden
```bash
# Option 1: Router-Interface
# Router-Admin öffnen (meist 192.168.1.1)
# Geräte-Liste → "raspberrypi" suchen

# Option 2: Netzwerk-Scan
nmap -sn 192.168.1.0/24

# Option 3: Raspberry Pi Finder
# https://www.raspberrypi.org/software/
```

### 7.2 SSH-Verbindung testen
```bash
# Standard-Zugriff
ssh pi@192.168.1.100

# Passwort: raspberry
# Erwartete Ausgabe: pi@raspberrypi:~ $
```

## 🛠️ Schritt 8: Automatische Installation

### 8.1 Quick-Start Script ausführen
```bash
# Auf Ihrem Computer:
cd ~/carambus
chmod +x bin/quick-start-raspberry-pi.sh
./bin/quick-start-raspberry-pi.sh 192.168.1.100
```

### 8.2 Erwartete Ausgabe
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

## 🔍 Schritt 9: Troubleshooting

### 9.1 SD-Karte nicht erkannt
```bash
# 1. SD-Karte neu einlegen
# 2. Anderen SD-Karten-Slot versuchen
# 3. SD-Karte in Computer testen
# 4. Andere SD-Karte verwenden
```

### 9.2 SSH-Verbindung fehlschlägt
```bash
# 1. IP-Adresse prüfen
ping 192.168.1.100

# 2. SSH-Service prüfen
ssh -v pi@192.168.1.100

# 3. SSH-Datei prüfen
# SD-Karte in Computer → Boot-Verzeichnis → "ssh" Datei vorhanden?
```

### 9.3 WLAN-Verbindung funktioniert nicht
```bash
# 1. wpa_supplicant.conf prüfen
# 2. Ländercode anpassen
# 3. WLAN-Name und Passwort prüfen
# 4. Netzwerk-Kabel als Alternative
```

### 9.4 Boot-Probleme
```bash
# 1. LED-Verhalten beobachten
# 2. SD-Karte neu formatieren
# 3. Image neu schreiben
# 4. Andere SD-Karte verwenden
```

## 📋 Schritt 10: Checkliste

### Vor der Installation
- [ ] Raspberry Pi Imager installiert
- [ ] 32GB SD-Karte bereit
- [ ] SD-Karten-Reader verfügbar
- [ ] Internet-Verbindung verfügbar
- [ ] WLAN-Daten bereit (optional)

### Während der Installation
- [ ] Raspberry Pi OS Image erstellt
- [ ] SSH aktiviert
- [ ] WLAN konfiguriert (optional)
- [ ] SD-Karte in Raspberry Pi eingelegt
- [ ] Stromversorgung angeschlossen
- [ ] Boot abgeschlossen
- [ ] IP-Adresse gefunden
- [ ] SSH-Verbindung getestet

### Nach der Installation
- [ ] Quick-Start Script ausgeführt
- [ ] Setup abgeschlossen
- [ ] Test erfolgreich
- [ ] Web-Interface getestet
- [ ] Performance dokumentiert

## 🎯 Nächste Schritte

### 8.1 Web-Interface testen
```bash
# Im Browser öffnen:
http://192.168.1.100
https://192.168.1.100

# Scoreboard testen:
http://192.168.1.100/scoreboard
```

### 8.2 Performance optimieren
```bash
# SSH zum Raspberry Pi
ssh pi@192.168.1.100

# System-Status prüfen
htop
df -h
docker stats
```

### 8.3 Lokalisierung
```bash
# Web-basiertes Setup-Interface entwickeln
# Region, Club, Location konfigurieren
# Spieltische definieren
# Benutzer anlegen
```

---

*Diese Anleitung wird kontinuierlich erweitert basierend auf Installations-Ergebnissen und Feedback.* 