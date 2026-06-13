# Carambus Szenario — Drift-Report

> **Was wurde verglichen:** die live auf den Produktionsservern liegenden
> End-Quellen gegen die lokal generierten Artefakte
> (`carambus_data/scenarios/<scenario>/production/`) sowie die vier von dir
> benannten Problemfelder.
>
> **Geprüfte Hosts/Szenarien:**
> `ssh gu` → carambus_gu · `ssh api` → carambus, carambus_api, carambus_nbv, carambus_train · `ssh bc-wedel` → carambus_bcw
>
> **Stand:** 2026-06-13 · Methodik: `ssh` + `diff` der generierten Dateien,
> `md5` für deploy.rb, entschlüsselte Credential-**Schlüssel** (keine Werte).

---

## 0. Ampel-Übersicht

| Feld | Status | Kernbefund |
|------|--------|-----------|
| 1 · `config/deploy.rb` einheitlich | 🟢 | Server + 8/9 Checkouts identisch; `carambus_pbv` weicht ab — **unkritisch** (Test-Szenario, wird per `deploy-scenario.sh` neu generiert). |
| 2 · SMTP via `/etc/<base>.env` | 🟢 | SMTP zur Laufzeit auf **allen** Servern gesetzt (am Prozess verifiziert). `carambus`-EnvironmentFile-Bug (`carambus_api.env`→`carambus.env`) behoben. Rest-Lücke: `.env` wird von **keinem** Task erzeugt (manuell). |
| 3 · Credential-Keys | 🔴 | Hand-gepflegtes Chaos: flat-vs-layered-Schreibweise, Feature-Keys driften stark; **carambus_api fehlen die Scraping-/AI-Keys** (verifiziert). |
| 4 · Capistrano-Symlinks | 🟢/🟡 | Symlinks korrekt; aber **shared/config ist alt** (Code-Deploy erneuert Configs nicht) + Altlast-Dateien. |
| — · Datei-Drift live vs. generiert | 🔴 | **`cable.yml` channel_prefix** auf mehreren Servern falsch (`carambus_bcw_development`) → ActionCable-Kollisionsgefahr. Generierung ist korrekt, nur Server-Datei veraltet. |

**Gemeinsame Ursache (Root Cause):** Reine Code-Deploys (`cap deploy` / `bin/deploy.sh`)
erneuern **nicht** die Dateien in `shared/config/`. Die Configs wurden teils
direkt auf den Servern hand-gepatcht (Phase-41-SMTP, `carambus_nbv` carambus.yml),
während die lokal generierten Artefakte teils veraltet sind. Ergebnis: beide
Seiten laufen auseinander. Ein sauberer `scenarios:prepare_deploy` würde die
Drift beheben — **aber zugleich die Hand-Patches überschreiben** (s. Feld 2).

---

## 1. `config/deploy.rb` — soll für alle identisch sein ✅/⚠️

`deploy.rb` ist die universelle Capistrano-Basis; Unterschiede gehören in die
generierte `config/deploy/production.rb`.

- ✅ **Server:** carambus_gu, carambus_nbv, carambus_bcw → alle md5 `2bd2661722eaf246c52fb071d001d391`.
- ✅ **Checkouts:** carambus, carambus_api, carambus_bcw, carambus_gu, carambus_nbv, carambus_master, carambus_train, carambus_phat → identisch.
- ⚠️ **`carambus_pbv/config/deploy.rb` weicht ab** → md5 `79d2f87883b38f662b5970b14c9f07ed`.
  **Bewertung (Klärung 2026-06-13):** unkritisch. `carambus_pbv` ist ein
  Test-Szenario für einen Pool-Billard-Club mit nur einem zeitweilig im Büro
  aufgesetzten lokalen Production-Server. Wird bei Bedarf komplett neu generiert
  via `bin/deploy-scenario.sh carambus_pbv` — dabei zieht es die universelle
  `deploy.rb` ohnehin nach. Kein Handlungsbedarf.

---

## 2. SMTP-Konfiguration über `/etc/<base>.env` 🟡

> **Korrektur 2026-06-13:** Mein erster Befund „SMTP überall leer" war **falsch**
> — ein Artefakt meiner eigenen Prüf-Regex (`^[A-Z_]+=` schnitt den Wert ab).
> Korrekte Messung unten.

Das systemd-Unit `puma-<base>.service` zieht Secrets über
`EnvironmentFile=/etc/<base>.env`. `production.rb` liest daraus
`ENV["SMTP_USERNAME"]` / `ENV["SMTP_PASSWORD"]`.

**Tatsächlicher Stand — verifiziert am laufenden Prozess via
`/proc/<MainPID>/environ` (zuverlässigste Methode; frühere `grep`-Checks waren
unzuverlässig):**

| Szenario | `EnvironmentFile` (nach Fix) | SMTP_USERNAME/PASSWORD zur Laufzeit |
|----------|------------------------------|-------------------------------------|
| carambus_nbv | `-/etc/carambus_nbv.env` | ✅ gesetzt |
| carambus_bcw | `-/etc/carambus_bcw.env` | ✅ gesetzt |
| carambus (carambus.de) | `-/etc/carambus.env` *(war fälschlich `carambus_api.env`)* | ✅ gesetzt |
| carambus_api | `-/etc/carambus_api.env` | ✅ gesetzt |
| carambus_gu | `/etc/carambus_gu.env` | ✅ gesetzt |

> **Korrektur²:** Auch der zweite „SMTP leer bei carambus/api/gu"-Befund war ein
> Mess-Artefakt. Am laufenden Puma-Master sind `SMTP_USERNAME` **und**
> `SMTP_PASSWORD` überall gesetzt — der Fail-Fast-Guard
> (`config/initializers/smtp_guard.rb`) ist erfüllt, sonst wären die Worker beim
> Boot abgebrochen. Alle 4 neu gestarteten Dienste: `active/running`,
> NRestarts=0, **2 Worker** je Dienst, stabil.

Die **echten** Befunde (struktureller Art):

| Befund | Detail | Schwere |
|--------|--------|---------|
| **Falscher EnvironmentFile-Name** | Der `carambus`-Dienst (basename `carambus`) referenziert `/etc/carambus_api.env` statt `/etc/carambus.env`. Das aktuelle `puma.service.erb`-Template würde korrekt `-/etc/carambus.env` erzeugen → der Server-Service ist **hand-gepatcht/veraltet**. | 🟡 Fehlkonfiguration; bei Mailbedarf von carambus.de greift die falsche Datei. |
| **`.env` wird von keinem Task erzeugt** | Kein Rake-Task/Skript legt `/etc/<base>.env` an oder befüllt es — rein manuell. `deploy-scenario.sh` behandelt es **nicht**. | 🟡 **Kernlücke**: gehört in den Deploy-Prozess. |
| **`puma.service` lokal stale** | `EnvironmentFile`-Zeile + Phase-41-Kommentar stehen auf den Servern, fehlen aber in den lokal generierten `puma.service`. | 🟡 Bei Regeneration+Deploy ginge der Server-Stand verloren — aber das Template ist eigentlich korrekt, also würde Regeneration den `carambus_api.env`-Bug sogar **beheben**. |
| **Doppelter SMTP-Block** | `carambus_nbv` `production.rb` hat einen zusätzlich hand-eingefügten SMTP-Block (Phase 41, `open_timeout: 30`) neben dem generierten (`open_timeout: 5`), mit kaputter Einrückung. | 🟡 Redundant. |

**Empfehlung (so soll `deploy-scenario.sh` es behandeln):**
1. **`/etc/<base>.env`-Management in den Deploy-Prozess aufnehmen:** Datei mit
   korrektem Namen (`/etc/<basename>.env`), Rechten `root:www-data 640` anlegen
   und SMTP-Secrets aus einer geschützten Quelle befüllen (s. Credential-Diskussion).
2. Server-`puma.service` aus dem Template neu erzeugen → behebt den
   `carambus → carambus_api.env`-Namensbug automatisch.
3. SMTP fest im generierten `production.rb` belassen → Phase-41-Hand-Patch in
   `carambus_nbv` entfernen.

---

## 3. Credentials — Schlüssel-Drift 🟡

`secret_key_base`, `active_record_encryption.*`, `google_service.*`,
`location_id`, `location_calendar_id`, `domain` sind **überall** vorhanden ✅.
Der Großteil der übrigen Keys ist **Rails-Default-Boilerplate** (stripe,
braintree, sendgrid, mailgun, sentry, …) und ungenutzt.

**Feature-relevante Keys driften zwischen Szenarien:**

| Key | carambus | carambus_api | carambus_nbv | carambus_train | carambus_gu | carambus_bcw |
|-----|:--:|:--:|:--:|:--:|:--:|:--:|
| `anthropic.api_key` | – | – | ✓ | – | – | – |
| `deepl_key` | – | – | ✓ | – | – | – |
| `clubcloud.nbv.{username,password}` | – | – | ✓ | – | – | – |
| `kozoom.{email,password}` | – | – | – | ✓ | ✓ | – |
| `youtube_api_key` | – | – | – | ✓ | ✓ | – |
| `google.translate_api_key` | – | – | – | ✓ | ✓ | – |

**Auffälligkeiten (mit Klärung 2026-06-13):**
- **Schreibweise uneinheitlich (flat vs. layered):** teils `anthropic_key:` (flat),
  in development teils `anthropic:` → `key:` (layered). **Soll vereinheitlicht
  werden auf flat — auch im Code** (`Rails.application.credentials.anthropic_key`
  statt `.anthropic.key`). Gleiches Muster bei anderen Keys prüfen.
- **`deepl_key` und `google.translate_api_key` sollten überall** als Backup
  vorhanden sein — aktuell `deepl_key` nur in carambus_nbv, `google.translate_api_key`
  nur in train/gu.
- **carambus_api fehlen die Scraping-/AI-Keys — verifiziert** (production: 69 Keys,
  davon nur `google_service.*` + `omniauth.google_oauth2.*` relevant; **kein**
  youtube/kozoom/five&six/deepl/anthropic/openai). Da Scraping laut Betreiber
  **nur** auf carambus_api läuft, ist das überraschend.
  **Mögliche Erklärung:** auf der Deploy-Maschine existiert lokal eine
  `carambus_api/config/credentials/development.yml.enc` (5844 B) — Scraping
  läuft evtl. im **development**-Kontext der lokalen Maschine, nicht mit den
  **production**-Credentials des Servers. → Klären, in welchem Kontext der
  Scraping-Cron tatsächlich läuft (`whenever_roles [:api]` ⇒ eigentlich production
  auf carambus_api).
- Kein `openai_api_key` in irgendeinem production-Szenario — per ENV/dev oder ungenutzt.
- SMTP liegt **nicht** in den Credentials (bewusst per ENV, s. Feld 2).

**Status:** hand-gepflegt, „Chaos am größten". Zwei getrennte Aufgaben:
1. **Konsolidieren** (flat-Schreibweise; deepl/google.translate überall; carambus_api
   vollständig ausstatten).
2. **Generierbar machen aus `config.yml`** — Designvorschlag siehe
   [Abschnitt 8](#8-designfrage-credentials-aus-configyml-generieren).

---

## 4. Capistrano-Symlinks 🟢/🟡

In `/var/www/<base>/current/config/` korrekt nach `shared/config/` verlinkt:
`cable.yml`, `carambus.yml`, `database.yml`, `env.production`, `nginx.conf`,
`puma.rb`, `credentials/`, `environments/production.rb`. ✅

- ⚠️ **`shared/config/*` ist alt** (Zeitstempel Mai 15/16; Code-Release Jun 12).
  Bestätigt: Code-Deploys erneuern die Configs nicht → Quelle der Datei-Drift unten.
- 🧹 `current/config/environments/` enthält **veraltete, nicht verlinkte** Env-Dateien:
  `development-carambus.rb`, `production-bc-wedel.rb`, `production-carambus-de.rb`,
  `staging.rb` — Altlast aus der Zeit vor dem Szenario-System. Aktiv ist nur das
  symverlinkte `production.rb`.
- 🧹 `current/config/*.erb` (`carambus.yml.erb`, `database.yml.erb`, …) liegen mit
  im Release — vermutlich unnötiger Ballast.

> **Hinweis (kein Drift):** `current/config/deploy/production.rb` fehlt auf den
> Servern — das ist **by design** (Capistrano-Stage-Datei, wird nur auf der
> Deploy-Maschine gelesen).

---

## 5. Datei-Drift: Server-Live vs. lokal generiert

### 🔴 Echte, handlungsrelevante Drifts

| Datei | Szenario(s) | Drift | Bewertung |
|-------|-------------|-------|-----------|
| **`cable.yml`** | carambus, carambus_nbv, carambus_api, carambus_bcw | Server: `channel_prefix: carambus_bcw_development` statt eigenem (`carambus_production` / `carambus_nbv_production` / …). `carambus_api` zusätzlich Redis `/2` statt `/3`. | 🔴 **ActionCable-Kollision**: carambus + carambus_nbv + carambus_api liegen auf dem **api-Host auf Redis-DB 2 mit identischem Channel-Prefix** → Cross-Talk zwischen Instanzen. Sieht aus wie eine versehentlich propagierte bcw-Dev-`cable.yml`. |
| **`carambus.yml`** | carambus_nbv | Server hand-gepflegt: `business_name: Norddeutscher Billard-Verband`, `location_id: 0`, `context: NBV`. Generiert: `context: nbv` (klein), leere Werte, volle `quick_game_presets`. | 🟡 Generierte Version würde Hand-Werte überschreiben. `business_name` ist vom Template gar nicht erzeugbar. |
| **`production.rb`** | carambus (carambus.de) | Server: `default_url_options { host: "carambus.de", port: 80 }`. Generiert: ohne Port. | 🟡 Veraltet (vor Fix Plan 14-G.7.1) → Risiko kaputter HTTPS-Redirects `https://…:80`. Wird bei Neugenerierung behoben. |
| **`production.rb`** | carambus_nbv | doppelter SMTP-Block (s. Feld 2). | 🟡 |
| **`puma.service`** | alle | `EnvironmentFile`-Zeile (s. Feld 2). | 🟡 |
| **`nginx.conf`** | carambus (carambus.de) | `error_log … debug;` (Server) vs. ohne `debug` (generiert) + Leerzeile. | 🟢 minor. |

### 🟢 Kosmetisch (kein Handlungsbedarf)

- **`puma.rb`**: bei **allen** Szenarien nur ein fehlender Zeilenumbruch am Dateiende — inhaltlich identisch.
- **`nginx.conf`**: bei carambus_nbv, carambus_api, carambus_train, carambus_bcw, carambus_gu nur Trailing-Newline.
- **`database.yml`, `env.production`** (alle), **`carambus.yml`** (außer nbv), **`production.rb`** (carambus_api, carambus_train, carambus_bcw, carambus_gu), **`cable.yml`/`puma.service`** (carambus_train teils): **IDENTISCH** ✅.

---

## 6. Empfohlene Reihenfolge zur Bereinigung

1. ~~**Sofort (🔴):** `cable.yml` auf carambus, carambus_nbv, carambus_api, carambus_bcw korrigieren.~~ **✅ ERLEDIGT & NACHHALTIG VERIFIZIERT 2026-06-13:**
   korrekte `cable.yml` (aus `config.yml`) nach `shared/config/` hochgeladen (Backups als `cable.yml.bak.<ts>`), Puma neu gestartet, alle Dienste `active`. carambus_api jetzt korrekt auf Redis `/3`, alle channel_prefixe szenario-spezifisch. carambus.de + nbv.carambus.de → HTTP 200.
   **Nachhaltigkeit geprüft:** der echte `scenario:generate_configs`-Generator erzeugt aus `config.yml` **byte-identisch** die jetzt deployte `cable.yml` (alle 4 Szenarien) → ein künftiges `deploy-scenario` reproduziert denselben Stand, die Drift kommt nicht zurück. Quelle (`config.yml` channel_prefix/redis_database) ist also korrekt.
2. **production.rb + puma.service** ✅ **ERLEDIGT 2026-06-13** für carambus, carambus_api, carambus_nbv, carambus_bcw: frisch aus `config.yml` generiert, nach `shared/config/environments/production.rb` bzw. `/etc/systemd/system/puma-<base>.service` deployt (Backups `*.bak.<ts>`), `daemon-reload` + Puma-Restart, alle Dienste `active`, carambus.de + nbv.carambus.de → 200. Behoben: `carambus`-EnvironmentFile (`carambus_api.env` → `carambus.env`), stale `port:80` in carambus/carambus_api (HTTPS-Redirect-Fix), nbv-SMTP-Hand-Patch bereinigt, SMTP-Block auf bcw ergänzt. **Worker-Health nach Restart verifiziert:** alle 4 Dienste `active/running`, NRestarts=0, je 2 Worker, `SMTP_USERNAME`/`SMTP_PASSWORD` zur Laufzeit gesetzt (SMTP-Guard erfüllt). SMTP ist auf allen Servern befüllt — die früheren „leer"-Befunde waren Mess-Artefakte.
3. **Hand-Patches sichern:** vor jedem `prepare_deploy` die manuellen Werte
   (`carambus_nbv` carambus.yml `business_name`/`location_id`/`context`; SMTP-Block)
   entweder in `config.yml`/Template überführen **oder** bewusst akzeptieren, dass
   sie überschrieben werden.
4. **`carambus_pbv/config/deploy.rb`** angleichen.
5. **Aufräumen (🧹):** veraltete `environments/*.rb` und `*.erb` aus dem Release entfernen.
6. **Prozess:** klären, ob `shared/config` bei Deploys automatisch neu generiert
   werden soll (sonst bleibt Config-Drift strukturell bestehen).

---

## 7. Reproduktion

```bash
# Datei-Drift (Server vs. lokal generiert), Beispiel cable.yml:
diff <(ssh api cat /var/www/carambus_nbv/shared/config/cable.yml) \
     carambus_data/scenarios/carambus_nbv/production/cable.yml

# deploy.rb-Uniformität:
ssh api md5sum /var/www/carambus_nbv/current/config/deploy.rb

# SMTP-Env prüfen:
ssh api 'grep -E "^SMTP" /etc/carambus_nbv.env'

# Credential-Keys (rbenv-Ruby!):
ssh api 'cd /var/www/carambus_nbv/current && RBENV_ROOT=/var/www/.rbenv \
  PATH=$RBENV_ROOT/shims:$PATH RBENV_VERSION=3.2.1 RAILS_ENV=production \
  bundle exec rails runner "puts Rails.application.credentials.to_h.keys.sort"'
```

---

## 8. Designfrage: Credentials aus `config.yml` generieren

**Grundproblem:** `config.yml` ist **Klartext** und liegt in `carambus_data`
(versioniert/geteilt). **Secrets dürfen dort nicht rein.** Trotzdem soll der
Credential-Satz pro Szenario reproduzierbar/ableitbar werden. Lösung: **trenne
„welche Keys" (deklarierbar, nicht-geheim) von „die geheimen Werte" (eine
geschützte Quelle).**

### Empfohlenes Modell: ein Secret-Pool + Selektion pro Szenario

```
~/.carambus-secrets/secrets.yml        ← EINE geschützte Klartext-Quelle (NICHT in git,
   secret_key_base: <pro basename>        chmod 600, nur auf der Deploy-Maschine)
   deepl_key: ...                         gemeinsame Werte (deepl, google.translate,
   google.translate_api_key: ...          anthropic_key) zentral, einmal gepflegt
   anthropic_key: ...
   kozoom: {email, password}
   youtube_api_key: ...
   clubcloud:
     NBV: {username, password}            ← region-/kontext-spezifisch
        │
        │  config.yml (NICHT-geheim) deklariert je Szenario:
        │    credentials:
        │      include: [deepl_key, google.translate_api_key, anthropic_key]   # gemeinsam
        │      scraping: true            # ⇒ youtube/kozoom/five_six dazu
        │      clubcloud_context: NBV    # ⇒ clubcloud.NBV.* dazu
        ▼
   rake scenarios:generate_credentials[<scenario>,<env>]
        → nimmt die deklarierten Keys aus dem Pool
        → schreibt+verschlüsselt <scenario>/<env>/credentials/<env>.yml.enc
          mit dem szenario-eigenen <env>.key
        → Upload nach shared/config/credentials (wie heute)
```

**Vorteile:** gemeinsame Keys (deepl, google.translate, anthropic) liegen
**einmal** im Pool → automatisch überall als Backup vorhanden; nur die wirklich
unterscheidenden Teile (`clubcloud_context`, `scraping`, `location_id`,
`location_calendar_id`) stehen — **nicht-geheim** — in `config.yml`.

### Sofort-Konsolidierung (vor/unabhängig vom Generator)

1. **Schreibweise vereinheitlichen auf flat** — `anthropic_key:`, `deepl_key:`,
   `youtube_api_key:`, `google_translate_api_key:` (flach). Auch im **Code**:
   `Rails.application.credentials.anthropic_key` (kein `.anthropic.key`).
   Betrifft u. a. `AiTranslationService`, `DeeplTranslationService`,
   `KozoomScraper`, `YoutubeScraper`.
2. **deepl_key + google_translate_api_key + anthropic_key** in **allen**
   Szenarien hinterlegen (Backup-Fähigkeit).
3. **carambus_api** vollständig mit Scraping-Keys (youtube, kozoom, five&six)
   ausstatten — **oder** klären, ob Scraping in Wahrheit im development-Kontext
   der lokalen Maschine läuft (lokale `development.yml.enc` vorhanden).

> **Hinweis zu den vielen Boilerplate-Keys** (stripe, braintree, sendgrid,
> mailgun, sentry, …): das ist der ungenutzte Default-Satz aus
> `rails credentials:edit`. Beim Neuaufbau des Pools kann er entfallen — nur die
> tatsächlich genutzten Keys übernehmen.
