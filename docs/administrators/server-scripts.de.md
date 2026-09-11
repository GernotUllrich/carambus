# Server Management Scripts

Diese Dokumentation beschreibt die Scripts in `bin/` für die Verwaltung von Carambus-Servern
(Development, Production, API) — was sie heute tatsächlich tun und welche davon Altlasten sind.

!!! info "Einen Server aufsetzen"
    Ein neuer Server wird nicht mit einem Skript aus `bin/` eingerichtet, sondern per Ansible
    (`~/DEV/ansible/RUNBOOK`, Abschnitt „NEUEN CARAMBUS-PI AUFSETZEN“) und danach mit den Rake-Tasks
    der [Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md). Diese Seite beschreibt den Betrieb.

## Überblick

Die Scripts liegen in `bin/` jedes Carambus-Checkouts (`carambus_bcw`, `carambus_api`, …) und laufen aus
einem beliebigen aktuellen Checkout; `bin/lib/carambus_env.sh` ermittelt die Pfade dateirelativ. Die
Beispiele unten verwenden Platzhalter:

| Platzhalter | Bedeutung | Quelle |
|---|---|---|
| `<szenario>` | Szenario-Name, z. B. `carambus_pbv` | `carambus_data/scenarios/<szenario>/` |
| `<basename>` | Name des Deployments auf dem Server (Dienst `puma-<basename>`, `/var/www/<basename>`) | `config.yml`, `scenario.basename` |
| `<server>`, `<ssh_port>` | SSH-Ziel des Servers (Pis: `<name>.local`, Port 8910) | `config.yml`, `environments.production` |

Die Bereiche:
- **Development Server**: Lokale Entwicklungsumgebung starten
- **Production Server**: Dienst `puma-<basename>` verwalten
- **Rails Console**: Datenbank-Zugriff und Debugging
- **Asset Management**: JavaScript/CSS neu bauen, Aufräumen
- **Deployment**: Code auf den Server bringen
- **Altlasten**: Scripts, die noch in `bin/` liegen, aber nicht mehr zum heutigen Weg passen

---

## Development Server

Einen Szenario-Checkout startet man mit den Rails-Bordmitteln:

```bash
cd ~/DEV/carambus/<szenario>
bin/rails server -p <port>

# Bei JavaScript-/CSS-Änderungen zusätzlich (wie in Procfile.dev):
yarn build --watch
yarn build:css --watch
```

**Voraussetzung**: Die Development-Datenbank ist mit `prepare_development` angelegt (siehe
[Lokale Development-Session starten](#lokale-development-session-starten)).

Die Scripts `start-api-server.sh`, `start-local-server.sh` und `start-both-servers.sh` gehören zum
früheren API/LOCAL-Modus und nehmen kein Szenario — siehe [Altlasten](#altlasten).

---

## Production Server Management

Auf dem Server läuft die Anwendung als systemd-Dienst `puma-<basename>` (Vorlage
`templates/puma/puma.service.erb`, `Restart=always`). Der direkte Weg ist `systemctl`:

```bash
ssh -p <ssh_port> www-data@<server> 'sudo systemctl status puma-<basename>'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl stop puma-<basename>'
```

### `manage-puma.sh`
**Zweck**: Puma neu laden oder starten — so ruft Capistrano es beim Deploy auf
(`manage-puma.sh <basename>`, `config/deploy.rb`).

**Verwendung**:
```bash
# Auf dem Server, aus dem Deployment-Verzeichnis (Basename wird aus dem Pfad ermittelt):
cd /var/www/<basename>/current && ./bin/manage-puma.sh

# Oder mit Basename:
/var/www/<basename>/current/bin/manage-puma.sh <basename>
```

**Was wird gemacht**:
- Läuft `puma-<basename>`: `systemctl reload` (sendet USR1 an Puma); läuft der Dienst danach nicht,
  ein voller `restart`
- Läuft der Dienst nicht: `systemctl start`

Das erste Argument ist der **Basename**, keine Aktion. Aufrufe wie `manage-puma.sh restart` oder
`manage-puma.sh start` sprechen einen Dienst `puma-restart` bzw. `puma-start` an und scheitern.
Für Stop und Status `systemctl` verwenden (siehe oben).

---

### `manage-puma-api.sh`
**Zweck**: Wie `manage-puma.sh`, fest für den Dienst `puma-carambus_api`

**Verwendung** (ohne Argument):
```bash
./bin/manage-puma-api.sh
```

Läuft der Dienst, wird er neu gestartet (`restart`), sonst gestartet.

---

### `puma-wrapper.sh`
**Zweck**: Startskript des Dienstes `puma-<basename>` — `ExecStart` in
`templates/puma/puma.service.erb`. Wechselt nach `/var/www/<basename>/current`, initialisiert rbenv und
startet `bundle exec puma -C /var/www/<basename>/shared/config/puma.rb`.

Nicht von Hand aufrufen; Puma wird über den Dienst gesteuert.

---

## Rails Console

Es gibt kein eigenes Console-Wrapper-Script. Verwende die Standard-Rails-Console
(`bin/rails console`) im jeweiligen Scenario- oder API-Verzeichnis.

### Lokale / API-Console (Development)

**Verwendung**:
```bash
# Im API-Checkout
cd ~/DEV/carambus/carambus_api
bin/rails console

# In einem Scenario-Checkout
cd ~/DEV/carambus/<szenario>
bin/rails console
```

**Beispiel-Session**:
```ruby
> Player.count
=> 69082

> Version.last.id
=> 12227261

> Setting.key_get_value("last_version_id")
=> 12227261

# Lokale Daten prüfen (Datensätze mit id >= 50_000_000 sind lokal)
> Game.where('id > 50000000').count
=> 28

> TableLocal.count
=> 10
```

### Production-Console

**Verwendung**:
```bash
# Per SSH auf den Production-Server, dann Console im Deployment-Verzeichnis
ssh -p <ssh_port> www-data@<server>
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rails console
```

**⚠️ WARNUNG**: Production-Console! Vorsicht bei Änderungen!

**Beispiel**:
```ruby
> Rails.env
=> "production"

> Game.count
=> 280163
```

**Best Practice**:
- Niemals destruktive Operationen ohne Backup
- Nur lesende Operationen für Debugging
- Für Änderungen: Migration erstellen

---

## Asset Management

### `rebuild_js.sh`
**Zweck**: JavaScript im lokalen Checkout schnell neu bauen

**Verwendung** (im Checkout):
```bash
cd ~/DEV/carambus/<szenario>
./bin/rebuild_js.sh
```

**Was wird gemacht**:
1. Leert `tmp/cache/`
2. `yarn build` (esbuild)

CSS baut es nicht mit. Dafür zusätzlich `yarn build:css`; für die Sprockets-Assets
`bin/rails assets:precompile`.

**Nur lokal.** Auf dem Server baut Capistrano die Assets beim Deploy selbst
(`config/deploy.rb`, `deploy:assets:precompile`) — ein lokaler Rebuild vor dem Deploy ist nicht nötig.

---

### `cleanup_rails.sh`
**Zweck**: Hängengebliebene Rails-/Puma-Prozesse auf dem **Entwicklungsrechner** beenden

**Verwendung**:
```bash
./bin/cleanup_rails.sh
```

**Was wird gemacht**:
- `pkill -f "rails s"` und `pkill -f "puma"`
- Entfernt `tmp/pids/server.pid` und `tmp/pids/puma.pid`

Es löscht **keinen** Cache. **Nicht auf einem Server ausführen:** Als `www-data` beendet es dort die
laufende Produktions-Puma; systemd startet sie zwar wieder, die Scoreboards verlieren aber die Verbindung.
Den Rails-Cache leert `bin/rails tmp:cache:clear`.

---

### `cleanup_versions.sh`
**Zweck**: Überträgt `region_id` und `global_context` von den Datensätzen in ihre Einträge der
Versions-Tabelle (Wrapper um die Tasks `version_cleanup:*`)

**Verwendung** (im Rails-Root):
```bash
./bin/cleanup_versions.sh fast     # SQL-basiert (schnell)
./bin/cleanup_versions.sh safe     # über ActiveRecord (langsamer)
./bin/cleanup_versions.sh stats    # Statistik
./bin/cleanup_versions.sh verify   # Prüfung
```

Ohne Option zeigt es die Hilfe. Es löscht keine Versionen; eine Option `--dry-run` gibt es nicht
(`Unknown option`, Exit 1).

---

## Debug & Testing

Es gibt kein einzelnes `debug-production.sh` Script. Für einen beliebigen Server reichen die
Bordmittel — auf dem Server ausführen:

```bash
sudo systemctl status puma-<basename> nginx
sudo journalctl -u puma-<basename> -n 50 --no-pager
ls -la /var/www/<basename>/shared/sockets/
tail -100 /var/www/<basename>/shared/log/production.log
```

### `check-database-states.sh`
**Zweck**: Aktuelle Datenbank-Zustände für ein Scenario prüfen

**Verwendung**:
```bash
./bin/check-database-states.sh <szenario>
```

### Server-gebundene Diagnose-Scripts

Diese Scripts sind fest auf bestimmte Server geschrieben und auf anderen nur nach Anpassung brauchbar:

| Script | Fest auf |
|---|---|
| `diagnose-puma-carambus.sh` | `/var/www/carambus` (Server carambus.de) |
| `check-puma-logs.sh` | `/var/www/carambus` |
| `diagnose-socket-issue.sh` | Szenario `carambus_bcw` |
| `diagnose-nginx.sh` | API-Server (`carambus`/`carambus_api`) |

`check-actioncable-status.sh` (im Rails-Root) prüft `config/cable.yml` und die Erreichbarkeit von Redis.

---

## Setup & Installation

### Einen Server einrichten

Den Weg beschreiben das Ansible-RUNBOOK (System) und die
[Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md) (Anwendung). Die Ansible-`host_vars` entstehen aus
der Szenario-`config.yml`:

```bash
bin/rails "scenario:generate_host_vars[<szenario>]"
```

`carambus-install.sh` und `setup-local-dev.sh` gehören nicht mehr zu diesem Weg — siehe
[Altlasten](#altlasten).

---

### `generate-ssl-cert.sh`
**Zweck**: Selbst-signiertes SSL-Zertifikat für Development/Testing erzeugen

**Verwendung**:
```bash
./bin/generate-ssl-cert.sh -n <domain> [-d <tage>]
```

Das Script nimmt nur Optionen (u. a. `-n`/`--name` für den Common Name, `-d`/`--days`); ein Domainname
ohne `-n` endet mit `Unbekannte Option`.

**Was wird gemacht**:
- Generiert selbst-signiertes Zertifikat
- Erstellt Private Key
- Speichert in `ssl/` Verzeichnis

**Use Cases**:
- Lokales HTTPS-Testing
- Development mit SSL-Features
- Scoreboard-Testing mit sicherer Verbindung

**Beispiel**:
```bash
# Zertifikat für localhost
./bin/generate-ssl-cert.sh -n localhost

# Zertifikat für Custom-Domain
./bin/generate-ssl-cert.sh -n carambus.local
```

---

## Deployment

Für Code-Änderungen gibt es zwei Wege. Welcher passt, hängt davon ab, ob der Zielserver gerade per SSH
erreichbar ist. `deploy-scenario.sh` ist **kein** Update-Weg, sondern für den Neuaufbau eines Szenarios.

### `scenario:deploy` — vom Admin-Rechner aus

**Zweck**: Führt `cap production deploy` im Szenario-Checkout `~/DEV/carambus/<szenario>` aus; Capistrano
baut die Assets auf dem Server und lädt Puma neu.

**Verwendung** (aus einem beliebigen carambus-Checkout):
```bash
bin/rails "scenario:deploy[<szenario>]"
```

**Voraussetzung**: Der Code ist nach `origin/master` gepusht, und der Zielserver ist per SSH erreichbar —
bei Servern im Vereins- oder Firmennetz heißt das in der Regel: im selben Netz sitzen.

`bin/rails "scenario:quick_deploy[<szenario>]"` ist die Variante für iterative Arbeit: Sie prüft den
Szenario-Checkout auf lokale Änderungen, macht dort `git pull origin master`, baut die Frontend-Assets,
deployt per Capistrano und startet `puma-<basename>` neu.

### `bin/deploy.sh` — auf dem Server selbst

**Zweck**: Repliziert die Capistrano-Schritte für die Ausführung **auf dem Server**.
Der Server holt den Code selbst von GitHub, statt ihn zugeschickt zu bekommen.

**Verwendung** (auf dem Server, **nicht** mit `bundle exec`):
```bash
/var/www/<basename>/current/bin/deploy.sh            # Branch master
/var/www/<basename>/current/bin/deploy.sh master     # Branch explizit
/var/www/<basename>/current/bin/deploy.sh master abc123   # Branch + Revision
```

**Wann**: Wenn der Server nicht von außen erreichbar ist (kein Port-Forwarding, kein VPN)
oder niemand im lokalen Netz sitzt. Dann ist dies der einzige Weg.

**Voraussetzung — GitHub-Zugang je Server**: Das Skript klont bzw. aktualisiert per
`git@github.com:GernotUllrich/<application>.git` und prüft vorab `ssh -T git@github.com`.
Ohne hinterlegten Schlüssel bricht es mit `Permission denied (publickey)` ab.

Einrichtung (**einmal je Server**, empfohlen als **Deploy-Key ohne Schreibrecht**):

```bash
# 1. Auf dem Server: öffentlichen Schlüssel des Deploy-Users ausgeben
ssh -p <ssh_port> www-data@<server> 'cat ~/.ssh/id_rsa.pub'

# 2. Diesen Key im Repository hinterlegen:
#    Settings -> Deploy keys -> Add deploy key
#    Titel z. B. "carambus_phat (Pi 192.168.178.84, www-data)"
#    "Allow write access" NICHT ankreuzen - das Skript liest nur

# 3. Auf dem Server verifizieren
ssh -p <ssh_port> www-data@<server> 'ssh -T git@github.com'
#    Erwartet: "Hi <owner>/<repo>! You've successfully authenticated, ..."
```

Ein Deploy-Key gilt für genau ein Repository und lässt sich pro Server einzeln zurückziehen.
Jeder Server braucht seinen **eigenen** Key — derselbe Schlüssel kann nicht bei mehreren
Repositories als Deploy-Key liegen.

**Ergebnis prüfen**: In `/var/www/<basename>/revisions.log` steht der ausführende User.
Ein serverseitiger Lauf erscheint dort als `by www-data`, ein Capistrano-Deploy unter dem
Namen desjenigen, der ihn angestoßen hat.

### `deploy-scenario.sh` — Neuaufbau eines Szenarios

**Zweck**: Kompletter Neuaufbau eines Szenarios von der Entwicklungsmaschine aus (Aufräumen,
Vorbereitung, Capistrano)

**Verwendung**:
```bash
./bin/deploy-scenario.sh <szenario> [--skip-cleanup | --production-only] [-y]
```

!!! danger "Standardmodus räumt den Server ab"
    Ohne `--skip-cleanup` bzw. `--production-only` räumt Schritt 0 zuerst ab — nach einer einzigen
    Rückfrage, mit `-y` ohne:

    - lokal die Datenbank `<szenario>_development`
    - auf dem Server den Dienst `puma-<szenario>` (stop, disable) und die nginx-Konfiguration
    - auf dem Server das ganze Verzeichnis `/var/www/<szenario>` einschließlich `shared/`
    - die Produktions-Datenbank, sofern sie weder lokale Daten noch eine neuere Version trägt

    Das ist nur für einen Neuaufbau gedacht. Für Code-Änderungen `scenario:deploy` oder `bin/deploy.sh`
    verwenden.

---

## Altlasten

Diese Scripts liegen noch in `bin/`, passen aber nicht mehr zum heutigen Weg. Nicht verwenden.

| Script | Was es tatsächlich tut | Stattdessen |
|---|---|---|
| `start-api-server.sh` | Beendet einen Prozess auf Port 3000 (`kill -9`) und startet `rails server -e development-api` im Nachbar-Checkout `carambus_api` | `bin/rails server` im Checkout |
| `start-local-server.sh` | Startet `carambus_api` auf Port 3001 mit `-e development-local`; ein Szenario-Argument wird nicht ausgewertet | `bin/rails server -p <port>` im Szenario-Checkout |
| `start-both-servers.sh` | Startet die beiden obigen (Ports 3000/3001), auf macOS in zwei Terminal-Fenstern; kein Szenario-Argument | wie oben |
| `restart-carambus.sh` | Ruft `/etc/init.d/unicorn_carambus_production start` auf (Unicorn-Zeit); nichts installiert dieses Init-Skript | `sudo systemctl restart puma-<basename>` |
| `carambus-install.sh` | Docker-Installation auf einem Raspberry Pi (`/opt/carambus`, `docker-compose.yml`) — kein Ruby, kein www-data, kein SSL | Ansible-RUNBOOK + [Quickstart](raspberry-pi-quickstart.md) |
| `setup-local-dev.sh` | Für `carambus_local_hetzner`: überschreibt `config/database.yml` mit `config/database.development.yml` und legt eine leere DB mit Seeds an | `bin/rails "scenario:prepare_development[<szenario>,development]"` |

Die start-Scripts verwenden die Environments `development-api`/`development-local` aus dem früheren
Modus-System; ob sie damit heute noch starten, ist nicht geprüft.

Nicht mehr vorhanden (hier früher als obsolet geführt): `deploy-to-raspberry-pi.sh` und
`sync-carambus-folders.sh`. Einen Raspberry Pi richtet man per Ansible und Quickstart ein.

---

## Workflow-Beispiele

### Lokale Development-Session starten

```bash
# 1. Development-Umgebung vorbereiten (aus einem carambus-Checkout)
bin/rails "scenario:prepare_development[<szenario>,development]"

# 2. Server starten
cd ~/DEV/carambus/<szenario>
bin/rails server -p <port>
```

!!! warning "Was `prepare_development` voraussetzt und verändert"
    - Es holt die globalen Daten per SSH als `www-data` aus der **Produktions-Datenbank der Authority**
      (`api.carambus.de`). Diesen Zugang haben derzeit nur die Betreiber von Carambus.
    - Es vergleicht die lokale `carambus_api_development` mit der Authority und **ersetzt sie**, wenn
      dort neuere Daten liegen (vorher Sicherung, danach wieder gelöscht) — das betrifft jeden Checkout,
      der dieselbe Datenbank nutzt, auch `carambus_api`. Fehlt sie, wird sie angelegt.
    - Im Log stehen zahlreiche `ERROR: role "www_data" does not exist` und `invalid command \restrict` —
      beides ist erwartet, der Task meldet trotzdem ✅.

### Code-Änderung deployen

```bash
# 1. Code committen und pushen
git add <dateien>
git commit -m "Feature: XYZ"
git push origin master

# 2. Deployen (aus einem carambus-Checkout)
bin/rails "scenario:deploy[<szenario>]"

# 3. Optional: Scoreboard-Browser am Pi neu starten
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"
```

### Quick-Fix ohne Admin-Rechner

Ist der Server nicht erreichbar oder sitzt niemand im lokalen Netz, holt er den Code selbst:

```bash
# 1. Änderung pushen
git commit -am "Fix: typo"
git push origin master

# 2. Auf dem Server deployen
ssh -p <ssh_port> www-data@<server> '/var/www/<basename>/current/bin/deploy.sh'

# 3. Optional, wenn der Server zugleich der Scoreboard-Pi ist: Browser neu starten
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart scoreboard-kiosk'
```

Ein `git pull` in `/var/www/<basename>/current` funktioniert nicht: Releases sind entpackte Archive ohne
`.git`.

### Debugging Production-Problem

```bash
# 1. Status und Logs (auf dem Server)
ssh -p <ssh_port> www-data@<server>
sudo systemctl status puma-<basename> nginx
sudo journalctl -u puma-<basename> -n 100 --no-pager
tail -200 /var/www/<basename>/shared/log/production.log

# 2. Console öffnen (falls nötig)
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rails console

# 3. Quick-Fix anwenden
sudo systemctl restart puma-<basename>
```

---

## Fehlerbehebung

### Puma startet nicht

```bash
ssh -p <ssh_port> www-data@<server> 'sudo journalctl -u puma-<basename> -n 40 --no-pager'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
```

Häufigste Ursache nach einem Deploy ist eine fehlende `/etc/<basename>.env` (SMTP-Zugangsdaten) — siehe
[Quickstart, Fehlerbehebung](raspberry-pi-quickstart.md#502-bad-gateway-nach-dem-deploy). PID-Dateien
muss man nicht löschen: Die Puma-Konfiguration aus `templates/` legt keine an.

### Assets fehlen nach Deployment

Capistrano baut die Assets beim Deploy auf dem Server. Fehlen sie, das Deploy-Log prüfen und erneut
deployen:

```bash
bin/rails "scenario:deploy[<szenario>]"
```

### Datenbank-Verbindung schlägt fehl

```bash
# Problem: "could not connect to server"
# Lösung: PostgreSQL-Service prüfen
ssh -p <ssh_port> www-data@<server>
sudo systemctl status postgresql
sudo systemctl start postgresql

# Config prüfen
cat /var/www/<basename>/shared/config/database.yml
```

### Memory-Probleme

```bash
# Problem: "Cannot allocate memory"
ssh -p <ssh_port> www-data@<server> 'free -m'

# Puma neu starten
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
```

Auf einem Raspberry Pi zuerst prüfen, ob ClamAV oder SpamAssassin laufen — siehe
[Quickstart, Fehlerbehebung](raspberry-pi-quickstart.md#pi-reagiert-sehr-langsam).

---

## Best Practices

### Development
1. ✅ Nach JavaScript-Änderungen `rebuild_js.sh` oder `yarn build --watch`
2. ✅ Console nutzen für schnelle Datenbank-Checks
3. ✅ Hängengebliebene lokale Prozesse mit `cleanup_rails.sh` beenden — nur auf dem Entwicklungsrechner

### Production
1. ✅ Puma über den Dienst steuern (`systemctl … puma-<basename>`), nicht über Prozesse
2. ✅ Console nur für Debugging, nicht für Daten-Änderungen
3. ✅ Bei Problemen: zuerst `systemctl status` und `journalctl -u puma-<basename>`
4. ✅ Logs regelmäßig prüfen

### Deployment
1. ✅ Code-Änderungen vom Admin-Rechner: `scenario:deploy`
2. ✅ Server nicht erreichbar oder niemand im lokalen Netz: `bin/deploy.sh` auf dem Server
3. ✅ `deploy-scenario.sh` nur für einen Neuaufbau — der Standardmodus räumt den Server ab
4. ✅ Vor Deployment: Lokales Testing durchführen

---

## Monitoring & Wartung

### Tägliche Checks

```bash
# Service-Status
ssh -p <ssh_port> www-data@<server> 'systemctl status puma-<basename>'

# Disk-Space
ssh -p <ssh_port> www-data@<server> 'df -h'

# Logs (Fehler)
ssh -p <ssh_port> www-data@<server> 'tail -100 /var/www/<basename>/shared/log/production.log | grep ERROR'
```

### Wöchentliche Wartung

```bash
# Disk-Space und Log-Größe prüfen
ssh -p <ssh_port> www-data@<server> 'df -h; du -sh /var/www/<basename>/shared/log'
```

Eine Log-Rotation für `production.log` wird derzeit weder von Ansible noch von den Rake-Tasks eingerichtet;
das Log wächst, bis man es von Hand kürzt.

### Monatliche Wartung

```bash
# 1. System-Updates
ssh -p <ssh_port> www-data@<server>
sudo apt update && sudo apt upgrade -y

# 2. Services neustarten
sudo systemctl restart puma-<basename>
sudo systemctl restart nginx
```

Gem- und Node-Updates gehören ins Repository und kommen per Deploy; ein `bundle update` im Release ändert
nur die Kopie auf dem Server und wird beim nächsten Deploy überschrieben.

---

## Siehe auch

- [Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md) - Einrichtung eines Servers, Management-Befehle
- [Deployment Workflow](../developers/deployment-workflow.md) - Vollständiger Deployment-Prozess
- [Scenario Management](../developers/scenario-management.md) - Scenario-System-Übersicht
- [Raspberry Pi Scripts](raspberry_pi_scripts.md) - RasPi-Client-Management
- [Database Syncing](../developers/database-partitioning.md) - Datenbank-Synchronisation
