# Carambus Szenario-Parameter — Referenz-Verzeichnis

> **Nachschlagewerk.** Wie man Parameter pflegt (Abläufe): [scenario-parameter-howto.de.md](scenario-parameter-howto.de.md).

> **Zweck:** Übersicht im „Parameter-Dschungel". Für jeden Parameter, der ein
> Carambus-Szenario von einem anderen unterscheidet, ist hier dokumentiert:
> **Name**, **Bedeutung**, **Auftreten in `config.yml`** und **Auftreten in der
> generierten End-Quelle** (puma, nginx, database.yml, Environment-Dateien …).
>
> Parameter, die sich zwischen Szenarien unterscheiden, aber **nicht** aus
> `config.yml` abgeleitet werden (Credentials, SMTP-Secrets, master.key …), sind
> in [Abschnitt 5](#5-nicht-aus-configyml-abgeleitete-parameter) separat erfasst.
>
> Stand: 2026-06-13 · Quelle der Wahrheit: `carambus/lib/tasks/scenarios.rake`
> + `carambus_master/templates/`

---

## 1. Die Ableitungskette

Das **einzige** von Hand gepflegte Konfigurations-Artefakt pro Szenario ist
`carambus_data/scenarios/<scenario>/config.yml`. Alles andere wird daraus
generiert:

```
carambus_data/scenarios/<scenario>/config.yml          ← Single Source of Truth (Hand-gepflegt)
        │
        │  rake "scenarios:generate_configs[<scenario>,<env>]"
        │  → Code: carambus/lib/tasks/scenarios.rake  (def generate_configuration_files)
        │  → Templates: carambus_master/templates/**/*.erb  +  Inline-Heredocs in der .rake
        ▼
carambus_data/scenarios/<scenario>/<env>/              ← generierte End-Quellen (lokal)
        ├── carambus.yml          ├── puma.rb           ├── production.rb
        ├── database.yml          ├── puma.service      ├── env.production
        ├── nginx.conf            ├── cable.yml         ├── test.rb
        └── deploy/production.rb  └── (development.rb / env.development bei dev)
        │
        │  rake "scenarios:prepare_deploy[<scenario>]"  → Upload via scp
        ▼
Server: /var/www/<basename>/shared/{config,...}        ← shared-Verzeichnis
        │
        │  bin/deploy.sh  (Symlinks shared → release)
        ▼
/var/www/<basename>/current/config/*                   ← was die App zur Laufzeit liest
```

**Wichtig:** `bin/deploy.sh` *generiert nichts* aus `config.yml`. Es verlinkt nur
die bereits in `shared/` liegenden Dateien in den neuen Release. Die Generierung
passiert ausschließlich über die Rake-Tasks oben.

### Zwei getrennte Generatoren

| Tool | Liest | Erzeugt | Ziel |
|------|-------|---------|------|
| `scenarios.rake` (`generate_configs`) | `config.yml` | App-/Server-Configs (s. Abschnitt 2) | Rails-App auf dem Server |
| `carambus/bin/setup-table-raspi.sh` | `config.yml` → `environments.production.network.club_wlan` | WLAN-/Netzwerk-Config auf dem Raspberry-Pi-Client | Pi-Tisch-Client |

---

## 2. Generator → End-Quelle (welche Methode erzeugt welche Datei)

Alle Methoden liegen in `carambus/lib/tasks/scenarios.rake`. „Template" =
externe ERB-Datei unter `carambus_master/templates/`; „Heredoc" = inline im
Rake-Code.

| End-Quelle (Datei) | Generator-Methode (Zeile) | Vorlage | Env |
|--------------------|---------------------------|---------|-----|
| `carambus.yml` | `generate_carambus_yml` (578) | Template `carambus/carambus.yml.erb` | dev + prod |
| `database.yml` | `generate_database_yml` (606) | Template `database/database.yml.erb` | dev + prod |
| `nginx.conf` | `generate_nginx_conf` (623) | Template `nginx/nginx_conf.erb` | nur prod |
| `puma.service` | `generate_puma_service` (641) | Template `puma/puma.service.erb` | nur prod |
| `puma.rb` (prod) | `generate_puma_rb` (659) | Template `puma/puma_rb.erb` | nur prod |
| `puma.rb` (dev) | `restore_development_puma_rb` (678) | Heredoc | nur dev |
| `deploy/production.rb` | `generate_production_rb` (755) | Template `deploy/production_rb.erb` | nur prod |
| `cable.yml` | `generate_cable_yml` (778) | Heredoc | dev + prod |
| `development.rb` | `generate_development_rb` (805) | Heredoc | nur dev |
| `env.development` | `generate_env_development` (961) | Heredoc | nur dev |
| `production.rb` (Environment-Datei) | `generate_production_rb_env` (1001) | Heredoc | nur prod |
| `test.rb` | `generate_test_rb` (1198) | Heredoc (statisch) | immer |
| `env.production` | `generate_env_production` (1267) | Heredoc | nur prod |

> Hinweis: Es gibt **zwei** `production.rb`:
> – `deploy/production.rb` = Capistrano-Stage-Datei (Server/SSH/Whenever).
> – `production.rb` = Rails-Environment-Datei (`config/environments/production.rb`).

---

## 3. Parameter-Katalog (aus `config.yml` abgeleitet)

Legende **End-Quelle**: konkrete generierte Datei + Art der Verwendung.
„*nur Orchestrierung*" = Wert steuert den Deploy-Vorgang (rake), landet aber in
**keiner** generierten Laufzeit-Datei.

### 3.1 Abschnitt `scenario:` (szenario-global, environment-übergreifend)

| Parameter | Bedeutung | Auftreten in End-Quelle |
|-----------|-----------|-------------------------|
| `scenario.name` | Interner Szenario-Name (= Verzeichnisname) | `carambus.yml`: nur Sonderfall `business_name` (`name == 'carambus_api'` → „Ullrich IT Consulting" statt „PHAT Consulting"); `puma.rb`(dev): PID-Dateiname. Sonst nur Logging. |
| `scenario.description` | Klartext-Beschreibung (z. B. „Billardclub Wedel 61 e.V.") | **keine** — nur Anzeige/Logging. |
| `scenario.location_id` | Carambus-Location-ID des Standorts | `carambus.yml` → `location_id`; `env.production` → `LOCATION_CODE`; `deploy/production.rb` → `whenever_variables location_id`. |
| `scenario.region_id` | Region-ID | **keine generierte Datei** — steuert in `scenarios.rake` den **region-gefilterten DB-Dump** (`create_region_filtered_production_dump`, Z. 3470). Beeinflusst also den *Daten*-Inhalt, nicht eine Config-Datei. |
| `scenario.club_id` | Verein-ID | `carambus.yml` → `club_id` (default + env-Sektion). |
| `scenario.context` | Verband/Kontext-Kürzel (z. B. `NBV`, `API`) | `carambus.yml` → `context` (nur env-Sektion). |
| `scenario.api_url` | URL des zentralen API-Servers | `carambus.yml` → `carambus_api_url` (default + env). |
| `scenario.application_name` | Logischer App-Name (immer `carambus`) | `carambus.yml` → `application_name`; `puma.rb` → Kommentar-Header. |
| `scenario.basename` | Deploy-/Instanz-Name; bestimmt `/var/www/<basename>` | `nginx.conf` (upstream, root, Logs, Socket); `puma.service` (überall); `puma.rb` (Socket-Pfad); `carambus.yml` → `basename`; `deploy/production.rb` → `set :basename`. **Zentralster Parameter.** |
| `scenario.branch` | Git-Branch für Deployment | `deploy/production.rb` → `set :branch`. |
| `scenario.season_name` | Aktuelle Saison (z. B. `2025/2026`) | `carambus.yml` → `season_name` (default + env). |
| `scenario.is_main` | Markiert das „Haupt"-Szenario | **kein Verbraucher** im Generator/Template gefunden → derzeit rein informativ (siehe [Abschnitt 6 Waisen](#6-waisen--auffälligkeiten)). |

### 3.2 Abschnitt `environments.<env>:` — Web/DB/Netzwerk

`<env>` ist `development` oder `production`. Spalte „Quelle (prod)" nennt die in
**production** generierte Datei.

| Parameter | Bedeutung | Auftreten in End-Quelle (production) |
|-----------|-----------|--------------------------------------|
| `webserver_host` | Öffentlicher Hostname/IP der App | `nginx.conf` (`server_name`, SSL-Cert-Pfad); `production.rb` (`default_url_options`, `config.hosts`, ActionCable-Origins); `env.production` → `DOMAIN`; `carambus.yml` → `carambus_domain`. |
| `webserver_port` | Port, auf dem die App erreichbar ist | `nginx.conf` (HTTP-`listen`); `production.rb` (Port-Klausel, allowed hosts); `env.production` → `WEB_PORT`/`RAILS_PORT`; `deploy/production.rb` → `set :puma_port`; `carambus.yml` → `carambus_domain`. |
| `ssl_enabled` | HTTPS aktiv? | `nginx.conf` (HTTPS- vs. HTTP-Block, Let's-Encrypt); `production.rb` (HTTPS-Port-Klausel); `env.production` → `USE_HTTPS`. |
| `ssh_host` | SSH-Ziel für Deployment | `deploy/production.rb` → `server '<ssh_host>'`. Sonst Orchestrierung (Upload, Remote-Cmds). |
| `ssh_port` | SSH-Port | `deploy/production.rb` → `ssh_options: {port}`. Sonst Orchestrierung. |
| `cap_role` | Capistrano-Rolle: `api` oder `local` (Cron-Filter) | `deploy/production.rb` → Server-Rolle + `whenever_roles`. |
| `database_name` | Name der PostgreSQL-DB | `database.yml` → `database`; `env.production` → `DATABASE_NAME`. |
| `database_username` | DB-User (leer = Peer-Auth in dev) | `database.yml` → `username` (+ `host: localhost`, nur wenn gesetzt); `env.production` → `DATABASE_USER`. |
| `database_password` | DB-Passwort | `database.yml` → `password` (nur wenn gesetzt); `env.production` → `DATABASE_PASSWORD`. |
| `database_host` | Abweichender DB-Host (nur `carambus_location_2460`) | **kein Verbraucher** im Standard-Template (`database.yml.erb` setzt `host: localhost` fix) → Waise. |
| `redis_database` | Redis-DB-Nummer (Isolation der Instanzen) | `cable.yml` (`url` Redis-Index); `production.rb` (Session-Store-URL); `env.production` → `REDIS_DB`. |
| `actioncable_url` | WebSocket-URL fürs Frontend | `production.rb` → `config.action_cable.url`. (dev: `development.rb`) |
| `channel_prefix` | ActionCable-Channel-Präfix | `cable.yml` → `channel_prefix` (production-Sektion). |
| `bot_block_enabled` | Bot-Abweisung in nginx (Default `true`) | `nginx.conf` → `if ($carambus_block_bot)`-Block (Opt-Out via `false`). |
| `duckdns_domain` | DuckDNS-Domain für dyn. DNS | `production.rb` → zusätzliche `config.hosts`-Einträge. |
| `deploy_to` | Deploy-Zielpfad | **Redundant/Waise:** Capistrano berechnet `deploy_to` selbst als `/var/www/#{basename}` (`config/deploy.rb:6`); der `config.yml`-Wert wird nicht gelesen. |
| `puma_socket_path` | Puma-Unix-Socket-Pfad | **Waise:** wird nur beim Anlegen eines Szenarios als Default `/tmp/puma.sock` gesetzt (Z. 2929), aber von keinem Template gelesen. `puma.rb`/`nginx.conf` verwenden **hartkodiert** `/var/www/<basename>/shared/sockets/puma-production.sock`. |
| `mode`, `server_port` | nur `carambus_location_2460` | **kein Verbraucher** → Waisen/Altlasten. |

### 3.3 Unterabschnitt `environments.production.raspberry_pi_client:`

Steuert den Pi-Scoreboard-Client. Verbraucher: `production.rb` (allowed hosts)
sowie die Pi-Setup-Tasks (`setup_raspberry_pi_client` Z. 3829,
`deploy_raspberry_pi_client` Z. 3908, `generate_autostart_script` Z. 4975).

| Parameter | Bedeutung | Auftreten in End-Quelle |
|-----------|-----------|-------------------------|
| `enabled` | Pi-Client aktiv? | Gate für `production.rb` allowed-hosts + alle Pi-Tasks. |
| `ip_address` | LAN-IP des Pi | `production.rb` → `config.hosts << ip[:port]`; Pi-Tasks → SSH-Ziel. |
| `local_server_port` | Port des lokalen Pi-Servers | `production.rb` → allowed-host-Port (sonst `webserver_port`). |
| `local_server_enabled` | Läuft auf dem Pi ein lokaler Server? | wählt `local_server_port` vs. `webserver_port`; Autostart-Logik. |
| `ssh_user` / `ssh_password` / `ssh_port` | SSH-Zugang zum Pi | Pi-Setup/Deploy-Tasks (Orchestrierung; nicht in einer App-Config). |
| `kiosk_user` | Linux-User für Kiosk-Browser (`pi`) | systemd-Service / Autostart-Skript auf dem Pi. |
| `autostart_enabled` | Kiosk-Autostart einrichten? | Autostart-/systemd-Generierung. |
| `browser_restart_command` | Kommando zum Neustart des Kiosk | `restart_raspberry_pi_client`. |
| `touch_display` | Touch-Display vorhanden? | Pi-Autostart-Konfiguration. |
| `sb_state` | Initialer Scoreboard-Zustand (z. B. `table_scores`) | Pi-Autostart/Scoreboard-URL. |

### 3.4 Unterabschnitt `environments.production.network.club_wlan:`

> **Eigener Generator!** Diese Werte werden **nicht** von `scenarios.rake`
> verarbeitet, sondern ausschließlich von `carambus/bin/setup-table-raspi.sh`
> (via `config.dig('environments','production','network','club_wlan',…)`), das
> daraus die WLAN-/Netzwerk-Config (`wpa_supplicant`/`dhcpcd`) **auf dem Pi**
> erzeugt.

| Parameter | Bedeutung | Auftreten in End-Quelle |
|-----------|-----------|-------------------------|
| `ssid` | WLAN-SSID des Vereins | `setup-table-raspi.sh` → Pi-WLAN-Config. |
| `password` | WLAN-Passwort | `setup-table-raspi.sh` → Pi-WLAN-Config. |
| `priority` | WLAN-Priorität (Default 20) | `setup-table-raspi.sh`. |
| `gateway` | Gateway-IP (Default `192.168.2.1`) | `setup-table-raspi.sh`. |
| `subnet` | Subnetz (Default `/24`) | `setup-table-raspi.sh`. |
| `dns` | DNS-Server (Default `8.8.8.8`; nur `carambus_phat`) | `setup-table-raspi.sh`. |
| `static_ip` | Statische Pi-IP (nur `carambus_phat`) | `setup-table-raspi.sh`. |

### 3.5 Top-Level Sonstiges

| Parameter | Bedeutung | Auftreten in End-Quelle |
|-----------|-----------|-------------------------|
| `last_local_backup` | Pfad des letzten lokalen Backup-Dumps | **keine** — wird von `scenarios.rake` als Status zurückgeschrieben (Backup/Restore-Tasks, Z. 1752). Buchhaltungs-Feld, keine Config. |

---

## 4. Welche End-Quelle bezieht welche Parameter? (Rückwärts-Sicht)

| Generierte End-Quelle | Bezogene `config.yml`-Parameter |
|-----------------------|----------------------------------|
| **`carambus.yml`** | `scenario.{api_url, location_id, application_name, basename, name, context, season_name, club_id}`, `env.{webserver_host, webserver_port}` |
| **`database.yml`** | `env.{database_name, database_username, database_password}` |
| **`nginx.conf`** | `scenario.basename`, `env.{ssl_enabled, webserver_host, webserver_port, bot_block_enabled}` |
| **`puma.rb`** | `scenario.{basename, application_name}` |
| **`puma.service`** | `scenario.basename` (+ `/etc/<basename>.env` als EnvironmentFile, s. Abschnitt 5) |
| **`production.rb`** (Environment) | `env.{actioncable_url, redis_database, webserver_port, webserver_host, ssl_enabled, duckdns_domain, raspberry_pi_client.*}` |
| **`deploy/production.rb`** (Capistrano-Stage) | `scenario.{branch, basename, location_id}`, `env.{ssh_host, ssh_port, cap_role, webserver_port}` |
| **`cable.yml`** | `env.{redis_database, channel_prefix}` |
| **`env.production`** | `env.{database_name, database_username, database_password, redis_database, webserver_port, webserver_host, ssl_enabled}`, `scenario.location_id` |
| **`development.rb` / `env.development`** | `env.{actioncable_url, redis_database, webserver_port, database_name, …}` (dev) |
| **Pi-WLAN-Config** (via `setup-table-raspi.sh`) | `env.production.network.club_wlan.*` |

---

## 5. Nicht aus `config.yml` abgeleitete Parameter

Diese unterscheiden sich zwischen Szenarien (oder sind sensibel), werden aber
**bewusst außerhalb** von `config.yml` gehalten:

| Parameter / Quelle | Wo gepflegt | Wie auf den Server | Bemerkung |
|--------------------|-------------|--------------------|-----------|
| `secret_key_base` | `config/credentials/<env>.yml.enc` | Upload `credentials/` (Z. 3211 ff.) | gelesen in `production.rb` via `Rails.application.credentials.fetch(:secret_key_base)`. |
| `master.key` / `<env>.key` | `config/master.key`, `credentials/<env>.key` | Upload nach `shared/config/` (Z. 2642 ff.) | entschlüsselt die `.yml.enc`. **Nie** in `config.yml` oder Git. |
| `OPENAI_API_KEY`, `DEEPL_API_KEY`, Anthropic-Key | Rails-Credentials (`.yml.enc`) | wie Credentials oben | App-interne API-Keys. |
| Google-Service-Account (Calendar/YouTube/Translate) | Rails-Credentials (JSON) | wie Credentials oben | |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | **`/etc/<basename>.env`** (manuell auf Server) | systemd `EnvironmentFile=-/etc/<basename>.env` (`puma.service`) | `production.rb` liest `ENV["SMTP_USERNAME"]`/`ENV["SMTP_PASSWORD"]`. Leading `-` = optional. **Nicht generiert, nicht in `config.yml`.** |
| `region_shortname` | nur als ENV-Default in `scenarios.rake` (`'NBV'`, Z. 2347) | — | beim DB-Bootstrap, nicht aus `config.yml`. |
| Let's-Encrypt-Zertifikate | `/etc/letsencrypt/live/<host>/` (certbot) | auf Server | `nginx.conf` referenziert die Pfade, erzeugt sie aber nicht. |
| `carambus_bot_block.conf` (nginx-`map`) | einmalig pro Server in `/etc/nginx/conf.d/` | `rake scenarios:install_bot_block` (Z. 327); Vorlage `carambus_master/templates/nginx/carambus_bot_block.conf` | `nginx.conf` referenziert nur die `$carambus_block_bot`-Variable. |

---

## 6. Waisen & Auffälligkeiten

Parameter, die in `config.yml` (mancher Szenarien) stehen, aber von **keinem**
Generator/Template gelesen werden — Kandidaten zum Aufräumen oder Nachziehen:

| Parameter | Status | Empfehlung |
|-----------|--------|------------|
| `puma_socket_path` | Wird gesetzt, aber nie gelesen; echter Socket ist hartkodiert. | Entweder Template auf den Parameter umstellen **oder** Feld entfernen. |
| `deploy_to` | Redundant — Capistrano berechnet `/var/www/#{basename}` selbst. | Aus `config.yml` entfernen oder als reine Doku kennzeichnen. |
| `is_main` | Kein Verbraucher gefunden. | Klären, ob noch benötigt; sonst entfernen. |
| `database_host` (nur `carambus_location_2460`) | `database.yml.erb` setzt `host: localhost` fix. | Template anpassen, falls ein abweichender Host wirklich gebraucht wird. |
| `mode`, `server_port` (nur `carambus_location_2460`) | Keine Verbraucher. | Altlast — prüfen/entfernen. |

> **Inkonsistenz Heredoc vs. Template:** Die ERB-Templates verwenden
> `@scenario` / `@config`. Die Inline-Heredocs (`production.rb`, `env.production`,
> `cable.yml` …) verwenden lokale Variablen + `gsub`-Interpolation. Beim Pflegen
> beide Stellen beachten. Mittelfristig lohnt eine Vereinheitlichung auf reine
> ERB-Templates.

---

## 7. Szenario-Wertematrix (Anhang)

Schnellvergleich der wichtigsten unterscheidenden Werte (production), Stand
2026-06-13:

| Szenario | ctx | region | club | location | cap_role | ssl | webserver_host | port | ssh_port |
|----------|-----|--------|------|----------|----------|-----|----------------|------|----------|
| carambus | – | – | – | – | local | ✓ | carambus.de | 80 | 8910 |
| carambus_api | API | – | – | – | api | ✓ | api.carambus.de | 80 | 8910 |
| carambus_bcw | NBV | 1 | 357 | 1 | local | ✗ | bc-wedel.duckdns.org | 3131 | 8910 |
| carambus_gu | NBV | 1 | 357 | 2695 | local | ✗ | 192.168.178.84 | 3131 | 8910 |
| carambus_location_2460 | NBV | 1 | 2460 | 2460 | – | ✓ | – | – | – |
| carambus_location_5101 | NBV | 1 | 258 | 5101 | – | ✗ | 192.168.178.107 | 82 | 8910 |
| carambus_location_test | NBV | 1 | 9999 | 9999 | – | ✗ | 192.168.178.107 | 80 | 8910 |
| carambus_nbv | nbv | 1 | – | – | local | ✓ | nbv.carambus.de | 80 | 8910 |
| carambus_pbv | NBV | 1 | 3285 | 2368 | local | ✗ | 192.168.178.107 | 3131 | 8910 |
| carambus_phat | NBV | 1 | 357 | 2459 | local | ✗ | 192.168.178.163 | 3131 | 8910 |
| carambus_train | NBV | 1 | 357 | 2695 | local | ✓ | train.carambus.de | 80 | 8910 |

> `webserver_port: 80` bei `ssl_enabled: true` (carambus, carambus_nbv, train)
> bedeutet: App läuft hinter einem **HTTPS-Front-Proxy**; `production.rb` lässt
> dann die Port-Klausel weg (HTTPS-Default 443), siehe Kommentar `scenarios.rake:1008`.

---

## 8. Verifikation / Regeneration

```bash
# Configs für ein Szenario neu generieren (lokal, vor Upload):
cd carambus_master   # oder ein beliebiger carambus-Checkout
RAILS_ENV=development bundle exec rake "scenarios:generate_configs[carambus_bcw,production]"
# Ergebnis prüfen:
ls carambus_data/scenarios/carambus_bcw/production/

# Vollständiger Deploy-Vorlauf (Configs + DB + Upload + Server-Setup):
bundle exec rake "scenarios:prepare_deploy[carambus_bcw]"

# Reiner Code-Deploy auf dem Server (keine Config-Regeneration):
/var/www/carambus_bcw/current/bin/deploy.sh master
```
