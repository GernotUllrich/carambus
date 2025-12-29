# Raspberry Pi - Netzwerk-Stabilität verbessern

## Problem

SSH-Verbindungen zum Raspberry Pi brechen nach einiger Zeit ab. Der Raspberry Pi reagiert nicht mehr auf Ping. Ein Neustart ist erforderlich.

## Häufigste Ursache: WLAN Power Management

Der Raspberry Pi schaltet das WLAN-Modul standardmäßig in den Energiesparmodus, was zu Verbindungsabbrüchen führt.

## 🔧 Schnelle Lösung

### Nach Raspi-Neustart ausführen:

```bash
# 1. Script auf Raspi kopieren
scp -P 8910 bin/fix-raspi-network.sh www-data@192.168.178.29:/tmp/

# 2. Auf Raspi ausführen
ssh -p 8910 www-data@192.168.178.29 'bash /tmp/fix-raspi-network.sh'

# 3. Raspi neu starten
ssh -p 8910 www-data@192.168.178.29 'sudo reboot'

# 4. Nach Neustart testen (2 Minuten warten)
ssh -p 8910 www-data@192.168.178.29 'iwconfig wlan0 | grep Power'
# Sollte zeigen: "Power Management:off"
```

## 🎯 Was das Script macht

### 1. WLAN Power Management deaktivieren
```bash
# NetworkManager
sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF

# Alternative (für Systeme ohne NetworkManager)
sudo iwconfig wlan0 power off
```

### 2. SSH Keep-Alive konfigurieren
```bash
# Server-seitig in /etc/ssh/sshd_config
ClientAliveInterval 60
ClientAliveCountMax 3
```

### 3. Network Watchdog installieren
- Überwacht Netzwerkverbindung alle 60 Sekunden
- Startet Netzwerk bei Ausfall automatisch neu
- Läuft als systemd-Service

### 4. IPv6 deaktivieren (optional)
- IPv6 kann manchmal Probleme verursachen
- Wird in `/boot/cmdline.txt` deaktiviert

### 5. Netzwerk-Buffer optimieren
- TCP Keep-Alive Einstellungen
- Größere Netzwerk-Buffer
- Bessere Stabilität bei längeren Verbindungen

## 🔍 Diagnose

### WLAN Power Management prüfen
```bash
ssh -p 8910 www-data@192.168.178.29 'iwconfig wlan0 | grep Power'

# Sollte sein: Power Management:off
# Problem:     Power Management:on
```

### SSH-Verbindung testen
```bash
# Keep-Alive Test (bleibt 5 Minuten offen)
ssh -o ServerAliveInterval=30 -p 8910 www-data@192.168.178.29
# Warten Sie 5 Minuten - sollte nicht abbrechen
```

### Netzwerk-Logs ansehen
```bash
ssh -p 8910 www-data@192.168.178.29 'sudo journalctl -u NetworkManager -n 50'
# Oder:
ssh -p 8910 www-data@192.168.178.29 'sudo journalctl -u dhcpcd -n 50'
```

### Network Watchdog Status
```bash
ssh -p 8910 www-data@192.168.178.29 'sudo systemctl status network-watchdog'
```

## 🖥️ Client-Seite (Ihr Mac)

SSH-Config anpassen (`~/.ssh/config`):

```bash
Host bc-wedel 192.168.178.29
  User www-data
  Port 8910
  Hostname 192.168.178.29
  ServerAliveInterval 30
  ServerAliveCountMax 3
  TCPKeepAlive yes
  ConnectTimeout 10
```

Dann anwenden:
```bash
# Bearbeiten
nano ~/.ssh/config

# Oder anhängen
cat >> ~/.ssh/config << 'EOF'
Host raspi-bcw
  User www-data
  Port 8910
  Hostname 192.168.178.29
  ServerAliveInterval 30
  ServerAliveCountMax 3
  TCPKeepAlive yes
EOF

# Testen
ssh raspi-bcw 'uptime'
```

## 🔌 Hardware-Lösungen

### Ethernet statt WLAN (beste Lösung!)

Falls möglich:
- ✅ Ethernet-Kabel zum Raspi
- ✅ 100% stabile Verbindung
- ✅ Keine Power-Management-Probleme
- ✅ Bessere Streaming-Qualität

### WLAN-Verbesserungen

Falls Ethernet nicht möglich:
- 🔧 Raspi näher an Router
- 🔧 Bessere WLAN-Antenne (USB-WLAN-Stick)
- 🔧 5GHz statt 2.4GHz (weniger Störungen)
- 🔧 WLAN-Kanal im Router optimieren

## 📊 Monitoring

### Verbindung überwachen
```bash
# Dauerhaft Ping laufen lassen
while true; do
  date
  ping -c 1 192.168.178.29 && echo "✅ OK" || echo "❌ FAIL"
  sleep 60
done
```

### Uptime prüfen
```bash
ssh -p 8910 www-data@192.168.178.29 'uptime'
```

### Netzwerk-Statistiken
```bash
ssh -p 8910 www-data@192.168.178.29 'cat /proc/net/wireless'
```

## 🚨 Troubleshooting

### Problem: Script funktioniert nicht

**Lösung 1: Manuell WLAN Power Management deaktivieren**
```bash
ssh -p 8910 www-data@192.168.178.29 'sudo iwconfig wlan0 power off'
# Dauerhaft in /etc/rc.local eintragen
```

**Lösung 2: NetworkManager neu konfigurieren**
```bash
ssh -p 8910 www-data@192.168.178.29
sudo nmcli connection modify <connection-name> wifi.powersave 2
sudo systemctl restart NetworkManager
```

### Problem: Verbindung bricht immer noch ab

**Test: Ist es wirklich WLAN?**
```bash
# Ethernet-Kabel testweise anschließen
# Wenn Problem weg ist → WLAN-Problem
# Wenn Problem bleibt → Router/Firewall-Problem
```

**Router-Einstellungen prüfen:**
- DHCP-Lease-Zeit verlängern
- Firewall-Timeout erhöhen
- UPnP aktivieren/deaktivieren testen

### Problem: Nach Reboot immer noch Power Management an

**Verschiedene Methoden testen:**

```bash
# Methode 1: rc.local
sudo nano /etc/rc.local
# Vor "exit 0" hinzufügen:
iwconfig wlan0 power off

# Methode 2: udev-Regel
sudo tee /etc/udev/rules.d/70-wifi-powersave.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/sbin/iwconfig %k power off"
EOF

# Methode 3: cron @reboot
sudo crontab -e
# Hinzufügen:
@reboot /sbin/iwconfig wlan0 power off
```

## ✅ Erfolgs-Checkliste

Nach Anwendung der Fixes sollte gelten:

- ✅ `iwconfig wlan0 | grep Power` zeigt "off"
- ✅ SSH-Verbindung bleibt >30 Minuten stabil
- ✅ Ping läuft ohne Unterbrechung
- ✅ Network-Watchdog-Service läuft
- ✅ Streaming funktioniert ohne Abbrüche

## 🎬 Für Streaming besonders wichtig

Instabile Netzwerkverbindung = Stream-Abbrüche!

**Vor dem ersten richtigen Stream:**
1. ✅ Network-Fixes anwenden
2. ✅ 24h Stabilitätstest
3. ✅ Während Test: mehrfach SSH-Verbindung testen
4. ✅ Test-Stream auf YouTube (30+ Minuten)

## 📚 Siehe auch

- [Streaming Setup](streaming-setup.de.md)
- [Streaming Development Setup](../developers/streaming-dev-setup.de.md)
- [Raspberry Pi Official Documentation](https://www.raspberrypi.org/documentation/)

