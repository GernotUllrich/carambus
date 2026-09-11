# 🚀 Installation Übersicht

## 📋 Verfügbare Installations-Guides

### 🎯 Raspberry Pi Quickstart (Empfohlen)
**[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: der am 2026-09-11 auf frischer Hardware gegangene Weg,
von der leeren SD-Karte bis zum Scoreboard im Vollbild. Diese Seite fasst ihn zusammen; die Einzelheiten stehen
dort.

### 🧰 Scenario Management
**[Scenario Management](../developers/scenario-management.md)**: das Deployment-System hinter allen
Carambus-Instanzen. Jede Instanz ist ein **Szenario** mit eigener `config.yml` unter
`carambus_data/scenarios/<szenario>/`.

**Beispiele aus dem Bestand:**
- **carambus_api**: die Authority (`api.carambus.de`)
- **carambus**: der öffentliche Server `carambus.de`
- **carambus_bcw**, **carambus_pbv**, **carambus_phat**: Vereinsserver (Raspberry Pi im Vereinslokal)

**Was das Scenario Management übernimmt:**
- ✅ Configs aus einer einzigen `config.yml` (plus `secrets.yml`)
- ✅ Puma-Dienst, nginx, Redis und `/etc/<basename>.env` auf dem Server
- ✅ Deployment per Capistrano
- ✅ Sequence-Verwaltung für lokale Daten

## 🏗️ Architektur-Übersicht

### Production-Szenarien
1. **Authority** (`carambus_api`)
   - Zentrale Datenquelle für alle Local-Server (globale Records, Versions-Sync)
   - Domain: api.carambus.de, Pfad `/var/www/carambus_api`, `cap_role: api`
   - Wird vom Betreiber deployt

2. **Local-Server** (z. B. `carambus_pbv`)
   - Server für Turniere, Spielbetrieb und Scoreboards eines Vereins
   - Holt globale Daten von der Authority, lokale Daten bleiben auf dem Server
   - `cap_role: local`, Pfad `/var/www/<basename>`

### Development-Modus
- Jedes Szenario hat einen eigenen Rails-Root `~/DEV/carambus/<szenario>`
- Die Rake-Tasks laufen aus einem beliebigen aktuellen carambus-Checkout

## 🔑 Wichtige Konfigurationen

### Standard-Account
- **User**: `www-data` (uid=33, gid=33)
- **Home-Verzeichnis**: `/var/www`
- **SSH-Port**: 8910
- **Sudo**: Über `wheel`-Gruppe

### Installationspfade
- **Anwendung**: `/var/www/<basename>` (Capistrano: `releases/`, `shared/`, `current`)
- **Secrets des Dienstes**: `/etc/<basename>.env` (Modus 600, root)

## ✅ Voraussetzungen

- **System**: Der Server ist per Ansible aufgesetzt (siehe Schritt 0).
- **Szenario-Konfiguration**: `carambus_data/scenarios/<szenario>/config.yml`, mit `cap_role: local`
  für einen Vereinsserver.
- **`carambus_data/secrets.yml`** (nicht versioniert):
  - `shared.database_password` für die Datenbankrolle
  - `shared.smtp` (`username`, `password`). Ohne SMTP-Daten bricht `prepare_deploy` ab. Ein Server
    ohne Mailversand setzt stattdessen `smtp_enabled: false` in der `config.yml`.
- **Credentials**: `production.key` und `production.yml.enc` unter
  `carambus_data/scenarios/<szenario>/production/credentials/`. `prepare_deploy` lädt sie hoch und bricht
  ohne sie ab.

!!! warning "Offene Fragen für einen neuen Verein"
    - **Erstbefüllung der Datenbank:** `prepare_development` holt die globalen Daten per SSH als
      `www-data` aus der Produktions-Datenbank der Authority (`api.carambus.de`). Diesen Zugang haben
      derzeit nur die Betreiber von Carambus.
    - **`production.key`:** Kein Task erzeugt ihn, und `carambus_data` versioniert ihn nicht. Woher ein
      fremder Verein seinen Schlüssel bekommt, ist noch nicht geregelt.

    Ein Verein kann das System (Schritt 0) selbst aufsetzen; für die Anwendung braucht er heute (noch)
    den Betreiber.

## 🚀 Schnellstart

### 0. System aufsetzen
Raspberry Pi per Ansible: **`~/DEV/ansible/RUNBOOK`, Abschnitt „NEUEN CARAMBUS-PI AUFSETZEN"**, ein
Aufruf von `master.yml`. Die `host_vars` entstehen per `bin/rails "scenario:generate_host_vars[<szenario>]"`
aus der `config.yml`. Einzelheiten: [Raspberry Pi Quickstart](raspberry-pi-quickstart.md), Schritt 1–2.

### 1. Szenario anlegen
Ein Vorlage-Verzeichnis gibt es nicht. Die `config.yml` eines bestehenden Szenarios (z. B.
`carambus_data/scenarios/carambus_pbv/config.yml`) nach `carambus_data/scenarios/<szenario>/` kopieren
und anpassen: `name`, `basename` (= Szenarioname), `location_id`, `club_id`, `region_id`, Hosts und
`cap_role: local`. Die Felder stehen in der [Quickstart](raspberry-pi-quickstart.md), Abschnitt 3.1.

!!! note "Nicht empfohlen: `scenario:create` und `scenario:create_rails_root`"
    `scenario:create` erzeugt derzeit eine `config.yml`, deren `basename` nicht zum Rails-Root passt und
    der `cap_role` fehlt. Ohne `cap_role` gilt das Szenario als Authority, und die Authority-Crons
    liefen auf dem Vereinsserver. `create_rails_root` löscht ein vorhandenes `~/DEV/carambus/<szenario>`
    ohne Rückfrage. Den Rails-Root legt `prepare_development` bei Bedarf selbst an.

### 2. Anwendung deployen
Alle Befehle aus einem carambus-Checkout, in **dieser Reihenfolge**:

```bash
# 1. Configs, Verzeichnisse, Redis, Puma-Dienst, nginx, /etc/<basename>.env auf dem Server
bin/rails "scenario:prepare_deploy[<szenario>]"

# 2. Development-Datenbank auf dem Admin-Rechner aus der Authority ableiten
bin/rails "scenario:prepare_development[<szenario>,development]"

# 3. Produktions-Datenbank auf den Server bringen: DESTRUKTIV
bin/rails "scenario:reset_server_db[<szenario>]"

# 4. Anwendung per Capistrano
bin/rails "scenario:deploy[<szenario>]"
```

Was man dabei wissen muss:

- **Schritt 2** vergleicht die lokale `carambus_api_development` mit der Produktion der Authority und
  **ersetzt sie**, wenn dort neuere Daten liegen. Das betrifft jeden Checkout, der dieselbe Datenbank
  nutzt. Die Meldungen `ERROR: role "www_data" does not exist` und `invalid command \restrict` im Log
  sind erwartet.
- **Schritt 3** löscht die Produktions-Datenbank auf dem Server und spielt sie aus
  `<szenario>_development` neu ein. `prepare_deploy` richtet keine Datenbank ein, das tut nur dieser
  Schritt.
- Für die Scoreboards folgen `setup_raspberry_pi_client`, `deploy_raspberry_pi_client` und
  `test_raspberry_pi_client`, siehe [Quickstart](raspberry-pi-quickstart.md), Schritt 3.2.

### 3. SSL
Das Scenario Management stellt keine Zertifikate aus. Bei `ssl_enabled: true` muss das Zertifikat vor
`prepare_deploy` auf dem Server liegen (z. B. per `bin/issue-letsencrypt-cert.sh`), sonst schlägt
`nginx -t` fehl. Vereinsserver im Lokal laufen ohne SSL auf Port 3131.

## 📖 Weitere Dokumentation

- **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: der gegangene Weg Schritt für Schritt
- **[Scenario Management](../developers/scenario-management.md)**: Vollständiger Deployment-Guide
- **[Entwicklerleitfaden](../developers/developer-guide.md)**: Entwicklerdokumentation
- **[API-Dokumentation](../reference/api.md)**: API-Referenz

## 🆘 Support

Bei Problemen (auf dem Server):
1. Anwendungs-Log: `tail -f /var/www/<basename>/shared/log/production.log`
2. Dienste: `systemctl is-active puma-<basename> redis-server nginx` (auf dem Pi zusätzlich `scoreboard-kiosk`)
3. Puma-Log: `sudo journalctl -u puma-<basename> -n 40 --no-pager`
4. Häufigste Ursache für *502 Bad Gateway*: `/etc/<basename>.env` fehlt, siehe
   [Quickstart, Fehlerbehebung](raspberry-pi-quickstart.md#fehlerbehebung)

---

**🎯 Ziel**: Eine nachvollziehbare Installation von Carambus über das Scenario Management, belegt am
gegangenen Weg der Quickstart.
