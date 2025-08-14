# Scoreboard Autostart Einrichtung

## Schnellstart-Anleitung (Hier beginnen)

### Schritt 1: Benötigte Tools installieren
```bash
sudo apt update
sudo apt install wmctrl
```

### Schritt 2: Scoreboard-URL konfigurieren
Bearbeite die Konfigurationsdatei, um deine Scoreboard-URL zu setzen:
```bash
nano config/scoreboard_url
```

Die Standard-URL ist:
```
http://localhost:3000/locations/1/scoreboard_reservations
```

Ändere sie bei Bedarf zu deiner tatsächlichen Scoreboard-URL.

### Schritt 3: Skripte ausführbar machen
```bash
chmod +x bin/start-scoreboard.sh
chmod +x bin/exit-scoreboard.sh
chmod +x bin/restart-scoreboard.sh
```

### Schritt 4: Startskript manuell testen
```bash
./bin/start-scoreboard.sh
```

### Schritt 5: Bei Erfolg zum Autostart hinzufügen
```bash
nano ~/.config/lxsession/LXDE-pi/autostart
```

Füge diese Zeile am Ende hinzu (passe den Pfad zu deinem Rails-App-Standort an):
```
@/path/to/your/rails/app/bin/autostart-scoreboard.sh
```

Zum Beispiel, wenn deine Rails-App in `/var/www/carambus/current` ist:
```
@/var/www/carambus/current/bin/autostart-scoreboard.sh
```

**Hinweis:** Verwende das `autostart-scoreboard.sh` Wrapper-Skript anstatt `start-scoreboard.sh` direkt für bessere Autostart-Kompatibilität.

### Schritt 6: Neustart zum Testen
```bash
sudo reboot
```

## Vollständige Einrichtung (Fortgeschritten)

### Tastenkürzel konfigurieren (Optional)
```bash
nano ~/.config/labwc/rc.xml
```

Füge innerhalb des `<keyboard>` Abschnitts hinzu (passe Pfade zu deinem Rails-App-Standort an):
```xml
<keybind key="F12">
  <action name="Execute">
    <command>/path/to/your/rails/app/bin/exit-scoreboard.sh</command>
  </action>
</keybind>

<keybind key="F11">
  <action name="Execute">
    <command>/path/to/your/rails/app/bin/restart-scoreboard.sh</command>
  </action>
</keybind>
```

Zum Beispiel, wenn deine Rails-App in `/home/pi/carambus_gernot` ist:
```xml
<keybind key="F12">
  <action name="Execute">
    <command>/home/pi/carambus_gernot/bin/exit-scoreboard.sh</command>
  </action>
</keybind>

<keybind key="F11">
  <action name="Execute">
    <command>/home/pi/carambus_gernot/bin/restart-scoreboard.sh</command>
  </action>
</keybind>
```

## Alternative: Systemd User Service (Empfohlen)

Falls der Window Manager Autostart nicht funktioniert, verwende stattdessen den systemd User Service:

### Schritt 1: Systemd User Service für www-data Benutzer erstellen
```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/scoreboard.service
```

Füge folgenden Inhalt hinzu (passe den Pfad an):
```ini
[Unit]
Description=Carambus Scoreboard
After=network.target

[Service]
Type=simple
ExecStart=/path/to/your/rails/app/bin/start-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

### Schritt 2: Service aktivieren und starten
```bash
systemctl --user daemon-reload
systemctl --user enable scoreboard.service
systemctl --user start scoreboard.service
```

### Schritt 3: Status überprüfen
```bash
systemctl --user status scoreboard.service
```

## Fehlerbehebung

### Scoreboard startet nicht
- Überprüfe die Scoreboard-URL in `config/scoreboard_url`
- Stelle sicher, dass der Rails-Server läuft
- Überprüfe die Logs: `journalctl --user -u scoreboard.service`

### Scoreboard schließt sich automatisch
- Überprüfe die Browser-Einstellungen
- Stelle sicher, dass der Vollbildmodus aktiviert ist
- Überprüfe die Window Manager Konfiguration

### Tastenkürzel funktionieren nicht
- Überprüfe die rc.xml Konfiguration
- Stelle sicher, dass der Window Manager die Tastenkürzel unterstützt
- Teste die Skripte manuell

## Nützliche Befehle

### Scoreboard manuell starten
```bash
./bin/start-scoreboard.sh
```

### Scoreboard beenden
```bash
./bin/exit-scoreboard.sh
```

### Scoreboard neu starten
```bash
./bin/restart-scoreboard.sh
```

### Service-Status anzeigen
```bash
systemctl --user status scoreboard.service
```

### Service-Logs anzeigen
```bash
journalctl --user -u scoreboard.service -f
``` 