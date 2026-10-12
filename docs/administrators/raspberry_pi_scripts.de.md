# Raspberry Pi Management Scripts

Diese Dokumentation beschreibt, wie Raspberry Pi Clients im Carambus-System heute eingerichtet und bedient
werden — und was die älteren Raspi-Scripts in `bin/` tatsächlich tun.

## Überblick

Ein Raspberry Pi wird heute nicht mehr mit den Scripts aus `bin/` eingerichtet:

- **System**: per Ansible — `~/DEV/ansible/RUNBOOK`, Abschnitt „NEUEN CARAMBUS-PI AUFSETZEN“
- **Anwendung und Kiosk**: mit den Rake-Tasks der [Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md)
  (Referenz der Kiosk-Tasks: [Raspberry Pi Client Integration](raspberry_pi_client_integration.md))
- **Bedienung**: über den systemd-Dienst `scoreboard-kiosk`

Die Raspi-Scripts liegen in `bin/` jedes Carambus-Checkouts (z. B. `~/DEV/carambus/carambus_bcw/bin/`). Sie
stammen aus der Zeit vor diesem Weg und passen nicht mehr dazu — siehe [Altlasten](#altlasten). Die
Rake-Tasks laufen aus einem beliebigen aktuellen Checkout; `<szenario>` steht für den Szenario-Namen,
`<name>` für den Gerätenamen des Pi.

---

## Der heutige Weg

### Einen neuen Raspberry Pi einrichten

Vollständig in der [Quickstart](raspberry-pi-quickstart.md) beschrieben und am Gerät gegangen:

1. SD-Karte mit dem Raspberry Pi Imager schreiben (Raspberry Pi OS mit Desktop, Benutzer mit Autologin,
   SSH mit Schlüssel)
2. System per Ansible — ein Aufruf von `master.yml`; danach SSH nur noch als `www-data` auf Port 8910
3. Anwendung und Kiosk per Rake-Tasks (Quickstart, Schritt 3)

### Den Kiosk bedienen

```bash
# Browser neu starten (vom Admin-Rechner)
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"

# Oder direkt am Dienst
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'

# Zum Desktop (Kiosk anhalten) und zurück
ssh -p 8910 www-data@<name>.local 'sudo systemctl stop scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo systemctl start scoreboard-kiosk'

# Prüfen
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

### Ein Update auf den Pi bringen

```bash
bin/rails "scenario:deploy[<szenario>]"
```

`deploy-scenario.sh` ist dafür nicht gedacht: Sein Standardmodus räumt das Server-Deployment ab und ggf.
die Produktions-Datenbank — siehe [Server Management Scripts](server-scripts.md).

---

## Altlasten

Diese Scripts liegen noch in `bin/`, passen aber nicht mehr zum heutigen Weg. Nicht verwenden.

### Setup & Installation

| Script | Was es tatsächlich tut | Stattdessen |
|---|---|---|
| `setup-raspberry-pi.sh` | Bereitet einen Raspberry Pi 4 für eine Docker-Installation vor; nimmt nur Optionen, kein Szenario (`Unbekannte Option`) | Ansible-RUNBOOK + Quickstart |
| `install-client-only.sh <scenario_name> <client_ip> [ssh_port] [ssh_user]` | Installiert per SSH `chromium-browser` ohne Rückfall auf `chromium` (auf trixie gibt es das Paket nicht) und eine eigene Autostart-Konfiguration ohne labwc-Zweig | Rake-Tasks mit `local_server_enabled: false`, siehe [Raspberry Pi als Client](raspberry-pi-client.md) |
| `setup-phillips-table-ssh.sh` | Standortspezifisch: feste IP und Benutzer `pi`; prüft per `nmap` die Ports 22/8910 und gibt Anleitungen aus — erzeugt und kopiert keine Schlüssel | SSH-Schlüssel im Imager bzw. `ssh-copy-id <benutzer>@<name>.local` |
| `prepare-sd-card.sh [OPTIONS] SD_CARD_PATH` | Legt auf einer bereits beschriebenen Karte nur `ssh` und `wpa_supplicant.conf` in der Boot-Partition an — formatiert nichts, installiert nichts | Raspberry Pi Imager (RUNBOOK) |

### Testing & Debugging

| Script | Was es tatsächlich tut | Stattdessen |
|---|---|---|
| `find-raspberry-pi.sh --network <netz> [--ssh-test]` | Scannt ein Netz (Standard `192.168.1.0/24`) nach Pis; der SSH-Test läuft als `pi` auf Port 22 | Pis per Gerätename ansprechen (`<name>.local`) |
| `test-raspberry-pi.sh` | Testet eine Docker-Installation (Optionen `-d`/`-c`/`--cleanup`); nimmt kein Szenario | `bin/rails "scenario:test_raspberry_pi_client[<szenario>]"` |
| `test-raspberry-pi-restart.sh <scenario_name>` | Testet den Restart-Befehl per `sshpass`; einen Reboot testet es nicht | `bin/rails "scenario:test_raspberry_pi_client[<szenario>]"` |

### Scoreboard Management

Diese Scripts stammen aus der LXDE-/X11-Zeit. Neben dem Dienst `scoreboard-kiosk` gestartet, öffnen sie einen
zweiten Browser.

| Script | Was es tatsächlich tut | Stattdessen |
|---|---|---|
| `start-scoreboard.sh` | Startet fest `/usr/bin/chromium-browser` (auf trixie nicht vorhanden) mit der URL aus `../config/scoreboard_url`; ein Argument wird ignoriert | Dienst `scoreboard-kiosk` |
| `autostart-scoreboard.sh` | Veraltete Zweitkopie der Kiosk-Logik mit festen Werten (`carambus_location_5101`, `chromium-browser`); legt keinen Dienst an | Das generierte `/usr/local/bin/autostart-scoreboard.sh` — erzeugt von `deploy_raspberry_pi_client`, ansehen mit `bin/rails "scenario:preview_autostart_script[<szenario>]"` |
| `restart-scoreboard.sh` | Beendet `pcmanfm` und ruft `start-scoreboard.sh` auf; beendet Chromium nicht | `sudo systemctl restart scoreboard-kiosk` bzw. `scenario:restart_raspberry_pi_client` |
| `exit-scoreboard.sh` | `pkill chromium-browser` (trifft `chromium` auf trixie nicht), blendet das LXDE-Panel ein, startet `pcmanfm` | `sudo systemctl stop scoreboard-kiosk` (zurück mit `start`) |
| `cleanup-chromium.sh` | Beendet `chromium-browser` und löscht mit `sudo` `/tmp/chromium*` und `/tmp/.X*` — also auch das Profil des laufenden Kiosks und die X11-Sockets der laufenden Desktop-Sitzung | Nicht nötig: Der Kiosk legt sein Profil bei jedem Start neu an; bei Problemen `sudo systemctl restart scoreboard-kiosk` |

### Nicht mehr vorhanden

Früher hier als obsolet geführt, inzwischen aus `bin/` entfernt: `quick-start-raspberry-pi.sh`,
`auto-setup-raspberry-pi.sh`, `start_scoreboard`, `start_scoreboard_delayed`.

---

## Workflow-Beispiele

### Neuer Raspberry Pi komplett einrichten

Siehe [Quickstart](raspberry-pi-quickstart.md): Imager, dann Ansible, dann aus einem carambus-Checkout:

```bash
bin/rails "scenario:prepare_deploy[<szenario>]"
bin/rails "scenario:prepare_development[<szenario>,development]"
bin/rails "scenario:reset_server_db[<szenario>]"        # DESTRUKTIV
bin/rails "scenario:deploy[<szenario>]"
bin/rails "scenario:setup_raspberry_pi_client[<szenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

Was diese Schritte voraussetzen (u. a. SSH-Zugang zur Authority für `prepare_development`) und verändern,
steht in der Quickstart unter Schritt 3.2.

### Browser-Probleme beheben

```bash
# 1. Kiosk neu starten
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'

# 2. Logs ansehen
ssh -p 8910 www-data@<name>.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'

# 3. Kiosk-Script neu ausliefern (startet den Kiosk mit dem aktuellen Script neu)
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
```

### Scenario-Update auf RasPi deployen

```bash
# 1. Deployment vom Admin-Rechner
bin/rails "scenario:deploy[<szenario>]"

# 2. Optional: Browser neu starten
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"

# 3. Testen
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

---

## Fehlerbehebung

### SSH-Verbindung schlägt fehl
```bash
# Nach Ansible: nur noch www-data auf Port 8910
ssh -p 8910 www-data@<name>.local true

# Vor Ansible: der im Imager angelegte Benutzer auf Port 22
ssh <benutzer>@<name>.local true

# Problem: "Permission denied (publickey)" — Schlüssel nachtragen (vor Ansible)
ssh-copy-id <benutzer>@<name>.local
```

„Connection refused“ vor dem ersten Ansible-Lauf heißt meist: SSH wurde im Imager nicht angehakt. Den
Haken muss man bei jedem Schreiben der Karte neu setzen.

### Browser startet nicht
```bash
ssh -p 8910 www-data@<name>.local 'sudo systemctl status scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

Weitere Ursachen und Abhilfen: [Raspberry Pi Client Integration, Fehlerbehebung](raspberry_pi_client_integration.md#fehlerbehebung).

### Scoreboard zeigt alte Version
```bash
# Kiosk neu starten — das Browser-Profil wird dabei neu angelegt
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'
```

---

## Best Practices

### RasPi-Setup
1. ✅ Pis per Gerätename (`<name>.local`) ansprechen, nicht per IP
2. ✅ SSH-Schlüssel schon im Imager hinterlegen
3. ✅ Zeigt das Scoreboard nach einem Deployment die alte Fassung: Kiosk neu starten

### Netzwerk
1. ✅ SSH-Port 8910 und Firewall (nur 3131 + 8910) setzt Ansible
2. ✅ Netzwerk per Kabel empfohlen; WLAN funktioniert

### Wartung
1. ✅ Monatlich: OS-Updates via `sudo apt update && sudo apt upgrade`
2. ✅ Bei Problemen: zuerst Kiosk-Neustart (`scoreboard-kiosk`), dann Reboot

---

## Siehe auch

- [Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md) - Einrichtung von der SD-Karte bis zum Scoreboard
- [Raspberry Pi Client Integration](raspberry_pi_client_integration.md) - Referenz der Kiosk-Rake-Tasks
- [Client-Only Installation](raspberry-pi-client.md) - Pi als reines Display
- [Scoreboard Autostart](scoreboard-autostart.md) - Wie der Kiosk startet
- [Server Management Scripts](server-scripts.md) - Scripts für den Server
