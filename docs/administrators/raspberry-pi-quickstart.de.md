# Schnellstart: Raspberry Pi Scoreboard Installation

Von der leeren SD-Karte bis zum Scoreboard im Vollbild — so, wie der Weg am 2026-09-10/11 auf
einem frischen Raspberry Pi tatsächlich gegangen wurde (Pi 5, 2 GB RAM, Raspberry Pi OS 13
„trixie"). Jeder Schritt unten ist dabei gelaufen; wo er nicht glatt lief, steht es dabei.

## Überblick

Die Einrichtung hat zwei Teile:

1. **System** (Schritt 1–2): Raspberry Pi OS, Härtung, Ruby, PostgreSQL, nginx — mit **einem**
   Aufruf von Ansible. Gemessen: gut 60 Minuten, überwiegend Paket-Updates.
2. **Anwendung** (Schritt 3–4): Carambus, Datenbank, Redis, Puma und der Scoreboard-Kiosk — mit
   einigen Rake-Tasks vom Admin-Rechner aus. Gemessen: rund 15 Minuten reine Laufzeit.

Danach startet der Pi von selbst ins Scoreboard. Beim Einschalten dauert das etwa **3 Minuten**
(Desktop nach rund 1 Minute) — der Pi ist in dieser Zeit nicht defekt.

!!! warning "Wer diesen Weg heute gehen kann"
    Schritt 3.2 befüllt die Datenbank aus der **Produktions-Datenbank der Authority**
    (`api.carambus.de`) und braucht dafür SSH-Zugang als `www-data` zu diesem Server. Den haben
    derzeit nur die Betreiber von Carambus. Ein Verein kann Schritt 1–2 selbst gehen; für die
    Erstbefüllung braucht er (noch) den Betreiber.

## Voraussetzungen

### Hardware
- Raspberry Pi 4 oder 5. **2 GB RAM funktionieren**, sind aber knapp (Kaltstart ~3 min bis zum
  Scoreboard); 4 GB oder mehr sind empfehlenswert
- MicroSD-Karte (mindestens 16 GB, empfohlen 32 GB+)
- Offizielles Netzteil, Monitor (HDMI), für die Einrichtung Tastatur und Maus
- Netzwerk: Kabel empfohlen; WLAN funktioniert

### Admin-Rechner (Mac oder Linux)
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- Ein beliebiger **carambus-Checkout** (z. B. `~/DEV/carambus/carambus_bcw`) — aus ihm laufen alle
  Rake-Tasks; ein ausgezeichneter „Master"-Checkout ist nicht nötig
- Der **Szenario-Checkout** `~/DEV/carambus/<szenario>` (Rails-Root des Szenarios, von hier aus
  deployt Capistrano) — **aktuell** halten: `git -C ~/DEV/carambus/<szenario> pull --ff-only`
- `~/DEV/carambus/carambus_data` (Szenario-`config.yml`, `secrets.yml`)
- `~/DEV/ansible` (Inventar und Playbooks für Schritt 1–2)
- `~/DEV/carambus/carambus_app`, falls das Szenario `serve_tournament_app: true` setzt
- Lokales PostgreSQL mit `carambus_api_development`
- SSH-Schlüssel (`~/.ssh/id_rsa.pub`)

### Tipp: SSH zu `*.local` beschleunigen
Der Pi meldet sich per mDNS auch mit seinen öffentlichen IPv6-Adressen; die Firewall lässt SSH
dort nicht durch, jede Verbindung wartet dann ~20 s, bevor sie auf IPv4 ausweicht. Abhilfe in
`~/.ssh/config` auf dem Admin-Rechner:

```
Host *.local
    AddressFamily inet
```

## Schritt 1–2: Den Pi aufsetzen (System)

Dieser Teil steht vollständig im Ansible-Repo: **`~/DEV/ansible/RUNBOOK`, Abschnitt „NEUEN
CARAMBUS-PI AUFSETZEN"**. Kurzfassung:

1. `carambus_data/scenarios/<szenario>/config.yml` um den Abschnitt `environments.production.ansible`
   ergänzen, den Pi in `~/DEV/ansible/hosts` eintragen (inklusive Gruppe `[carambus_pi]`),
   `bin/rails "scenario:generate_host_vars[<szenario>]"` ausführen
2. SD-Karte mit dem Raspberry Pi Imager schreiben: Hostname `<name>`, Benutzer mit Passwort,
   **SSH jedes Mal neu anhaken**, öffentlicher Schlüssel `~/.ssh/id_rsa.pub`
3. Pi starten; meldet er sich noch als `raspberrypi`, einmal neu starten
4. Vorab: `ssh -4 <benutzer>@<name>.local true` muss ohne Passwort durchgehen
   (sonst `ssh-copy-id <benutzer>@<name>.local`)
5. Ein Aufruf:
   `cd ~/DEV/ansible && ansible-playbook -i hosts master.yml --limit <name> -K`

Ergebnis: SSH nur noch auf Port 8910 als `www-data`, Firewall nur 3131 + 8910, Ruby 3.2.1 (rbenv),
Node 20, PostgreSQL, nginx. Die Gruppe `[carambus_pi]` verhindert, dass ClamAV und SpamAssassin
installiert werden — auf einem Pi mit 2 GB belegten sie sonst den halben Speicher.

## Schritt 3: Anwendung deployen

### 3.1 Szenario konfigurieren

Die Konfiguration steht in `carambus_data/scenarios/<szenario>/config.yml`. Ein Vorlage-Verzeichnis
gibt es nicht — ein bestehendes Szenario (z. B. `carambus_pbv`) dient als Muster. Die für den Pi
entscheidenden Felder:

```yaml
scenario:
  name: carambus_pbv
  location_id: 2368          # die Location des Vereins bei der Authority
  region_id: 1
  club_id: 3285

environments:
  production:
    webserver_host: carambus-pbv.local   # Gerätename, keine IP-Adresse
    ssh_host: carambus-pbv.local
    webserver_port: 3131
    ssh_port: 8910
    # smtp_enabled: false               # nur, wenn der Server keine Mails versenden soll
    raspberry_pi_client:
      enabled: true
      ip_address: carambus-pbv.local     # auch hier der Gerätename
      ssh_user: www-data
      ssh_port: 8910
      kiosk_user: gullrich               # der im Imager angelegte Benutzer (Autologin)
      local_server_enabled: true
      local_server_port: 3131
      autostart_enabled: true
```

Aufruf per IP-Adresse blockt die Anwendung (Rails `config.hosts` erlaubt nur die Namen aus der
Konfiguration) — im Browser also immer `http://<name>.local:3131`.

**Mail-Absender:** Puma startet in Produktion nur mit SMTP-Zugangsdaten (sonst bricht
`config/initializers/smtp_guard.rb` den Start ab — nginx meldet dann *502 Bad Gateway*). Die Daten
gehören in `carambus_data/secrets.yml` (nicht versioniert):

```yaml
shared:
  smtp:
    username: "...@gmail.com"
    password: "..."          # Gmail: App-Passwort, nicht das Kontopasswort
```

`prepare_deploy` legt daraus auf dem Pi `/etc/<basename>.env` an. Ein Server ohne Mailversand setzt
stattdessen `smtp_enabled: false` (siehe oben).

### 3.2 Deployment ausführen

Alle Befehle aus einem carambus-Checkout, in **dieser Reihenfolge**:

```bash
cd ~/DEV/carambus/carambus_bcw

# 1. Configs, Verzeichnisse, Redis, Puma-Dienst, nginx, /etc/<basename>.env   (~1 min)
bin/rails "scenario:prepare_deploy[carambus_pbv]"

# 2. Development-Datenbank auf dem Admin-Rechner aus der Authority ableiten   (~4 min)
bin/rails "scenario:prepare_development[carambus_pbv,development]"

# 3. Produktions-Datenbank auf den Pi bringen — DESTRUKTIV                    (~1 min)
bin/rails "scenario:reset_server_db[carambus_pbv]"

# 4. Anwendung per Capistrano                                               (~9 min)
bin/rails "scenario:deploy[carambus_pbv]"

# 5. Kiosk einrichten, ausliefern, prüfen                                   (je <1 min)
bin/rails "scenario:setup_raspberry_pi_client[carambus_pbv]"
bin/rails "scenario:deploy_raspberry_pi_client[carambus_pbv]"
bin/rails "scenario:test_raspberry_pi_client[carambus_pbv]"
```

Was man dabei wissen muss:

- **Schritt 2** vergleicht die lokale `carambus_api_development` mit der Produktion der Authority
  und **ersetzt sie**, wenn dort neuere Daten liegen (vorher Sicherung, danach wieder gelöscht) —
  das betrifft jeden Checkout, der dieselbe Datenbank nutzt. Im Log stehen dabei zahlreiche
  `ERROR: role "www_data" does not exist` und `invalid command \restrict` — beides ist erwartet,
  der Task meldet trotzdem ✅.
- **Schritt 3** ist als DESTRUKTIV markiert: er löscht die Produktions-Datenbank auf dem Pi und
  spielt sie neu ein. Auf einem frischen Pi gibt es noch keine. Ohne Schritt 2 bricht er mit
  `ActiveRecord::NoDatabaseError … carambus_pbv_development` ab — dann Schritt 2 nachholen, nicht
  `db:create`.
- **Schritt 1** darf wiederholt werden; eine vorhandene `/etc/<basename>.env` wird nie
  überschrieben.
- `deploy_raspberry_pi_client` startet den Kiosk neu — Änderungen am Kiosk greifen sofort.

## Schritt 4: Installation prüfen

### 4.1 Web-Interface

Im Browser auf dem Admin-Rechner: `http://<name>.local:3131`

Von der Kommandozeile (der Browser-User-Agent ist nötig, falls der nginx-Bot-Block aktiv ist —
`curl` wird sonst mit 403 abgewiesen):

```bash
curl -s -o /dev/null -w "%{http_code}\n" -A "Mozilla/5.0" http://carambus-pbv.local:3131/
```

### 4.2 Scoreboard am Pi

Der Monitor zeigt das Scoreboard **im Vollbild**, ohne Desktop. Nach dem Einschalten dauert das
rund 3 Minuten (Puma lädt die Anwendung vor, danach startet Chromium).

### 4.3 Dienste

```bash
ssh -p 8910 www-data@carambus-pbv.local \
  'systemctl is-active puma-carambus_pbv redis-server nginx scoreboard-kiosk'
ssh -p 8910 www-data@carambus-pbv.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@carambus-pbv.local 'sudo tail -50 /tmp/chromium-kiosk.log'
```

Das Kiosk-Log gehört dem Kiosk-Benutzer — als `www-data` nur mit `sudo` lesbar.

## Den Kiosk bedienen

- **Raspberry Pi OS 13 („trixie", Desktop labwc):** Chromium läuft im Kiosk-Modus. Der Button auf
  der Welcome-Seite führt dort **nicht** auf den Desktop. Zum Arbeiten am Desktop den Kiosk
  anhalten und danach wieder starten:
  ```bash
  ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl stop scoreboard-kiosk'
  ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl start scoreboard-kiosk'
  ```
  Wird Chromium beendet (Absturz, Alt+F4), startet der Kiosk nach wenigen Sekunden von selbst neu.
- **Raspberry Pi OS 12 („bookworm", Desktop wayfire):** Vollbild mit `--start-fullscreen`; der
  Button auf der Welcome-Seite schaltet das Vollbild um.

## Fehlerbehebung

#### 502 Bad Gateway nach dem Deploy
Puma startet nicht. Häufigste Ursache: `/etc/<basename>.env` fehlt.
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo journalctl -u puma-carambus_pbv -n 40 --no-pager'
```
Steht dort `FATAL: SMTP-ENV nicht gesetzt`: SMTP-Daten in `secrets.yml` eintragen (siehe 3.1) und
`prepare_deploy` erneut ausführen — Puma startet danach von selbst.

#### Scoreboard nicht im Vollbild
`deploy_raspberry_pi_client` erneut ausführen (startet den Kiosk mit dem aktuellen Skript neu).
Die Desktop-Sitzung steht in `/etc/lightdm/lightdm.conf` (`user-session=`).

#### Pi reagiert sehr langsam
Speicher prüfen: `ssh -p 8910 www-data@<name>.local 'free -m'`. Laufen ClamAV/SpamAssassin
(`systemctl is-active clamav-daemon spamd`), obwohl der Pi nicht in `[carambus_pi]` stand:
```bash
ssh -p 8910 www-data@<name>.local \
  'sudo systemctl disable --now clamav-daemon clamav-daemon.socket clamav-freshclam spamd'
```

## Management-Befehle

**Scoreboard-Browser neu starten:**
```bash
bin/rails "scenario:restart_raspberry_pi_client[carambus_pbv]"
```

**Rails-Anwendung neu starten:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl restart puma-carambus_pbv'
```

**Anwendungs-Logs anzeigen:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'tail -f /var/www/carambus_pbv/shared/log/production.log'
```

**Anwendungscode aktualisieren:**
```bash
bin/rails "scenario:deploy[carambus_pbv]"
```

**Raspberry Pi neu starten:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo reboot'
```

## Erweiterte Konfiguration

*Die folgenden Abschnitte wurden beim Durchlauf am 2026-09-11 nicht gegangen.*

### Benutzerdefinierte Port-Konfiguration

`config.yml` bearbeiten, um Ports zu ändern:
```yaml
environments:
  production:
    webserver_port: 3131  # Zu Ihrem bevorzugten Port ändern
    ssh_port: 8910        # SSH-Port bei Bedarf ändern
```

### Mehrere Standorte

Für mehrere Tische/Standorte in einem Club:
```yaml
scenario:
  location_id: 1  # Erster Tisch
  
# Separate Szenarien für jeden Tisch erstellen:
# - carambus_bcw_tisch1
# - carambus_bcw_tisch2
# - carambus_bcw_tisch3
```

### Headless-Setup (Ohne Monitor)

Für Remote-Zugriff ohne Kiosk-Modus:
```yaml
raspberry_pi_client:
  enabled: false  # Kiosk-Modus deaktivieren
```

## Architektur-Überblick

```
┌─────────────────────────────────────────────────┐
│         Raspberry Pi (All-in-One)               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │   Kiosk (Autologin-Benutzer aus Imager) │   │
│  │   - Chromium, Vollbild                  │   │
│  │   - Systemd Service: scoreboard-kiosk   │   │
│  └─────────────────────────────────────────┘   │
│                      ↓ HTTP (localhost:3131)    │
│  ┌─────────────────────────────────────────┐   │
│  │   Web-Server                            │   │
│  │   - nginx (Port 3131)                   │   │
│  │   - Puma: puma-<basename>               │   │
│  │   - Redis (ActionCable)                 │   │
│  └─────────────────────────────────────────┘   │
│                      ↓                          │
│  ┌─────────────────────────────────────────┐   │
│  │   PostgreSQL                            │   │
│  │   - <basename>_production               │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Erfolgs-Checkliste

- [ ] `ssh -p 8910 www-data@<name>.local` funktioniert
- [ ] `http://<name>.local:3131` antwortet im Browser
- [ ] `puma-<basename>`, `redis-server`, `nginx`, `scoreboard-kiosk` sind aktiv
- [ ] Scoreboard im Vollbild am Monitor
- [ ] Nach einem Neustart kommt das Scoreboard von selbst (nach ~3 min)
- [ ] Touch-Eingabe funktioniert (bei Touch-Display)

## Support

GitHub Issues: https://github.com/GernotUllrich/carambus/issues

---

**Letzte Aktualisierung:** 2026-09-11 (Durchlauf auf frischer Hardware, carambus_bcw Plan 15-03)
**Getestet auf:** Raspberry Pi 5 (2 GB), Raspberry Pi OS 13 „trixie" (64-bit, Desktop labwc)
**Frühere Fassung (Oktober 2025):** nannte Pi 4/5 und bookworm/trixie, wurde aber nie gegen einen
frischen Pi gegangen
