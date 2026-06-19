# Szenario-Parameter & Credentials — How-To (Ist-Zustand & Pflege)

> **Zweck:** Praktischer Leitfaden, *wie* man Szenario-Parameter und Credentials
> im laufenden Betrieb pflegt. Beschreibt den **gegenwärtigen Stand**, nicht die
> Entstehungsgeschichte.
>
> **Verwandt:**
> - [scenario-parameter-reference.de.md](scenario-parameter-reference.de.md) — Nachschlagewerk: jeder Parameter → End-Quelle
> - [scenario-management.de.md](scenario-management.de.md) — tiefer Deploy-/Datenbank-Workflow (Rake-Tasks)
> - [scenario-workflow.de.md](scenario-workflow.de.md) — Git-Regeln (Code nur in `carambus_master`)
> - [archive/](archive/) — Audit-/Entscheidungs-Historie (Hintergrund)

---

## 0. Was lebt wo? (Ist-Zustand)

| Artefakt | Ort | Rolle |
|----------|-----|-------|
| **`config.yml`** | `carambus_data/scenarios/<szenario>/config.yml` | **Single Source** für alle nicht-geheimen Parameter + Credential-**Deklaration** (`scenario.credentials.features`). Hand-gepflegt, versioniert. |
| **`secrets.yml`** | `carambus_data/secrets.yml` (**gitignored**, `chmod 600`) | Einzige Klartext-**Geheimquelle** (Pool). Vorlage: `secrets.yml.example`. |
| **Generierte Configs** | `carambus_data/scenarios/<szenario>/<env>/*` | Aus `config.yml` + Templates erzeugt (database.yml, nginx.conf, puma.*, production.rb, env.production, cable.yml …). |
| **Templates** | `carambus_master/templates/**/*.erb` + Heredocs in `lib/tasks/scenarios.rake` | Vorlagen der Generierung. |
| **Server: App-Configs** | `/var/www/<basename>/shared/config/*` → Symlink in `current/` | Was die App zur Laufzeit liest (via Capistrano `linked_files`). |
| **Server: nginx / systemd** | `/etc/nginx/sites-available/<basename>`, `/etc/systemd/system/puma-<basename>.service` | Aus generierter `nginx.conf`/`puma.service` installiert. |
| **Server: SMTP-Secrets** | `/etc/<basename>.env` (**manuell**, `root:www-data 640`) | `SMTP_USERNAME`/`SMTP_PASSWORD` via systemd `EnvironmentFile`. |
| **Credentials** | `<...>/credentials/<env>.yml.enc` — **maßgeblich auf den SERVERN** | Verschlüsselt; **Server sind die Quelle der Wahrheit** (s. §4). |
| **Code** | `carambus.git` (Branch `master`) | Deploy via Capistrano / `bin/deploy.sh`. |

**Generierungs-Kette:**
```
config.yml ── rake scenario:generate_configs ──► scenarios/<s>/<env>/*  ── upload ──► shared/  ── deploy.sh/cap ──► current/
secrets.yml ─┐
config.yml  ─┴ (features) ─ server-seitiger additiver Merge ─► Server-Credentials
config.yml (network.club_wlan) ── bin/setup-table-raspi.sh ──► Raspberry-Pi-WLAN
```

> **Faustregel:** Niemals generierte Dateien oder Server-Dateien direkt
> bearbeiten — immer `config.yml`/`secrets.yml` ändern und neu generieren.
> (Ausnahme dokumentiert: Credentials werden server-seitig gemergt, s. §4.)

---

## 1. Einen Parameter ändern (Port, Host, SSL, Redis, channel_prefix, …)

1. **`config.yml` editieren** — z. B. `environments.production.webserver_port`.
   (Welcher Parameter wohin wirkt: siehe [Parameter-Referenz](scenario-parameter-reference.de.md).)
2. **Generieren** (nur Config-Dateien, keine DB):
   ```bash
   cd carambus_master   # oder ein beliebiger Checkout
   bundle exec rake "scenario:generate_configs[<szenario>,production]"
   ls carambus_data/scenarios/<szenario>/production/
   ```
3. **Auf den Server bringen** — Variante je nach Datei:
   - **App-Configs** (database.yml, cable.yml, puma.rb, env.production, production.rb): via `scenario:prepare_deploy` (lädt nach `shared/config`) **oder** gezielt `scp` nach `/var/www/<basename>/shared/config/`.
   - **nginx**: `rake "scenario:sync_nginx_conf[<szenario>,production]"` (lädt + reload).
   - **puma.service**: wird von `prepare_deploy`/`create_puma_systemd_service` nach `/etc/systemd/system/` installiert (`daemon-reload` nötig).
4. **Aktivieren:** `sudo systemctl restart puma-<basename>` (App-Configs/cable/production.rb werden erst beim Boot gelesen) bzw. nginx-Reload.
5. **Verifizieren:** siehe §6.

> **Beispiel cable.yml `channel_prefix`:** in `config.yml` →
> `environments.production.channel_prefix`. Muss pro Szenario eindeutig sein
> (sonst ActionCable-Cross-Talk bei gemeinsamem Redis-Host).

### Sonderfall: Parameter ohne config.yml-Ableitung
Manche Werte stehen **nicht** in `config.yml` (z. B. SMTP → `/etc/<basename>.env`,
TLS-Zertifikate → certbot, `secret_key_base`/AR-Encryption → Credentials).
Siehe [Parameter-Referenz §5](scenario-parameter-reference.de.md) und §4/§5 hier.

---

## 2. Ein neues Szenario anlegen

1. **Grundgerüst:** `bundle exec rake "scenario:create[<name>,<location_id>,<context>]"`
   (oder `config.yml` aus einem bestehenden Szenario kopieren und anpassen).
2. **`config.yml` ausfüllen** — `scenario.*` (name, basename, location_id, club_id,
   region_id, context, api_url, branch …) + `environments.{development,production}.*`
   (webserver_host/port, ssl_enabled, database_*, redis_database, channel_prefix,
   ssh_*, cap_role, ggf. `raspberry_pi_client`, `network.club_wlan`).
3. **Credential-Features deklarieren** (§4): `scenario.credentials.features`.
4. **Secrets** im Pool ergänzen, falls neu (sonst greift `shared`): §4.
5. **Development vorbereiten** (legt dev-DB an — Vorsicht!):
   `rake "scenario:prepare_development[<name>,development]"`.
6. **Deployen:** `rake "scenario:prepare_deploy[<name>]"` dann `scenario:deploy` —
   Details in [scenario-management.de.md](scenario-management.de.md).
7. **Credentials** auf den neuen Server bringen (§4) + **SMTP** (§5) falls Mailversand.

---

## 3. Pi-Tisch-Client / WLAN

Die `environments.production.network.club_wlan.*`-Werte werden **nicht** vom
Config-Generator verarbeitet, sondern von **`carambus/bin/setup-table-raspi.sh`**
(erzeugt WLAN-/Netzwerk-Config auf dem Pi). `raspberry_pi_client.*` steuert den
Kiosk-Client (`scenario:setup_raspberry_pi_client` / `deploy_raspberry_pi_client`).

---

## 4. Credentials pflegen

### 4.1 Schema (layered) & Zugriff im Code
Einheitlich **layered**; Einzelwert-Keys werden über tolerante Helfer gelesen
(lesen nested-first, mit Fallback auf historische flache Schreibweise):

| Key | Code-Zugriff |
|-----|--------------|
| `anthropic.api_key` | `Carambus.anthropic_api_key` |
| `deepl.key` | `Carambus.deepl_key` |
| `youtube.api_key` | `Carambus.youtube_api_key` |
| `openai.api_key` | `credentials.dig(:openai, :api_key)` |
| `google.translate_api_key` | `credentials.dig(:google, :translate_api_key)` |
| `kozoom.{email,password}` | `credentials.dig(:kozoom, …)` |
| `clubcloud.<ctx>` | `Setting.get_cc_credentials` (⚠️ **kleingeschrieben**: `context.downcase` → `clubcloud.nbv`) |
| `google_service` | `credentials.dig(:google_service, …)` |
| `secret_key_base`, `active_record_encryption.*`, `devise_jwt_secret_key` | Rails-intern — **niemals rotieren** |

### 4.2 Secret-Pool `carambus_data/secrets.yml` (gitignored)
```yaml
shared:                 # fleet-weit identische Werte (Backup überall)
  anthropic: { api_key: ... }
  deepl:     { key: ... }
  google:    { translate_api_key: ... }
  youtube:   { api_key: ... }
  kozoom:    { email: ..., password: ... }
  google_service: { ... }
  clubcloud: { nbv: { username: ..., password: ... } }   # kleingeschrieben!
per_scenario:           # nur echte Abweichungen je Szenario (Override)
  <szenario>: { ... }
```
Anlegen: `cp carambus_data/secrets.yml.example carambus_data/secrets.yml` → echte
Werte eintragen → `chmod 600`. **Niemals committen.**

### 4.3 Deklaration in `config.yml`
```yaml
scenario:
  credentials:
    features: [ai, translation, scraping, clubcloud]
    clubcloud_context: NBV        # wird intern kleingeschrieben
```
> ⚠️ **Für ClubCloud beide Felder setzen:** `clubcloud` muss in `features` stehen **UND**
> `clubcloud_context` gesetzt sein. Fehlt der Context, überspringt der Generator clubcloud
> **still** (kein Fehler, .enc bleibt gleich groß) — der häufigste Stolperstein.

Feature → Keys: `ai`→anthropic(+openai) · `translation`→deepl+google.translate ·
`scraping`→youtube+kozoom · `clubcloud`→clubcloud.<ctx>. `google_service` immer.
Rollen-Konvention: `scraping` nur auf dem Scraper (carambus_api). `clubcloud` gehört auf
**jeden Local-Server, der die CC-Admin nutzt** — Local-Server schreiben heute
Turnierergebnisse direkt in die CC-Admin und betreiben das Sportwart-Chat-/MCP-Interface.
`clubcloud_context` = die Region, deren ClubCloud bedient wird (z. B. `NBV`). Sonderfall
**NBV-Local-Server**: bindet via carambus_app auch Spieler ohne eigenes Scoreboard/
Location-Server an.
*(Die frühere Regel „`clubcloud` nur Region-Szenarien, nicht club-only wie bcw/pbv" stammt
aus der Zeit reinen api-Scrapings und ist überholt.)*

### 4.4 ⚠️ Quelle der Wahrheit = die SERVER (nicht carambus_data)
Die `carambus_data/scenarios/*/.../credentials/*.yml.enc` sind veraltet/Template
und teilen einen `secret_key_base`/`active_record_encryption`-Satz, der zu **keinem**
Server passt. **Sie dürfen NICHT auf Server deployt werden** — das würde Sessions
ungültig machen und **verschlüsselte DB-Daten unentschlüsselbar** machen.

`rake scenario:generate_credentials` (Dry-Run-Default; `WRITE=true` zum Schreiben)
ist daher v. a. für **neue** Szenarien / lokale Stände gedacht. Für **bestehende
Server** gilt der additive Server-Merge unten.

### 4.5 Deploy-Gate (vor jedem Credential-Deploy PFLICHT)
Prüfen, dass `secret_key_base` UND `active_record_encryption.primary_key` mit dem
Server übereinstimmen — geheimnisfrei per serverseitigem Hash-Vergleich
(nur MATCH/MISMATCH zurück). Bei MISMATCH **nicht** deployen, sondern mergen (4.6).

### 4.6 Feature-Keys auf einem Server ergänzen (additiver Merge)
Empfohlenes, sicheres Verfahren — fügt nur fehlende Keys hinzu, bewahrt
`secret_key_base`/`active_record_encryption`/alles andere:

1. **Additions-Datei** lokal aus dem Pool bauen (nur die benötigten Gruppen), `chmod 600`.
2. **Backup** auf dem Server: `cp -a .../production.yml.enc .../production.yml.enc.bak.<ts>`.
3. **Upload** der Additions nach `/tmp` (600).
4. **Server-seitig** (rbenv-Ruby, `RAILS_ENV=production`): live-`<env>.yml.enc`
   entschlüsseln → `deep_merge(additions)` → `secret_key_base`/AR-Hash **vorher==nachher**
   prüfen → re-encrypten (`EncryptedConfiguration#write`).
5. **Additions löschen** (Server + lokal).
6. `sudo systemctl restart puma-<basename>` → §6 verifizieren.

> Vollständiges, erprobtes Skript-Muster siehe
> [archive/scenario-credentials.de.md](archive/scenario-credentials.de.md) §4 (Phase B / Server-Merge).

### 4.7 Volle Wirkung
`anthropic`/`clubcloud`/`google_service`/`google.translate` greifen sofort
(Code liest nested direkt). `deepl`/`youtube` **nested** brauchen die
`Carambus.*`-Helfer → erst nach **Code-Deploy** des aktuellen `master` aktiv.

---

## 5. SMTP einrichten (`/etc/<basename>.env`)

`puma-<basename>.service` lädt `EnvironmentFile=-/etc/<basename>.env`;
`production.rb` liest `ENV["SMTP_USERNAME"]`/`ENV["SMTP_PASSWORD"]`. Ein
**Fail-Fast-Guard** (`config/initializers/smtp_guard.rb`) bricht den
Production-Boot ab, wenn beide fehlen (Opt-out: `SKIP_SMTP_GUARD=1`).

```bash
ssh <host>
sudo install -o root -g www-data -m 640 /dev/stdin /etc/<basename>.env <<'ENV'
SMTP_USERNAME=...@gmail.com
SMTP_PASSWORD=...
ENV
sudo systemctl restart puma-<basename>
```
Der Datei-Name muss `<basename>.env` heißen (vom `puma.service`-Template erzeugt).
Diese Datei wird von **keinem** Rake-Task erzeugt — rein manuell.

---

## 6. Verifizieren & Troubleshooting

```bash
# Dienst-Health (active, kein Crash-Loop, 2 Worker):
ssh <host> 'systemctl show puma-<basename> -p ActiveState -p SubState -p NRestarts --value; \
  mpid=$(systemctl show puma-<basename> -p MainPID --value); pgrep -P $mpid | wc -l'

# HTTP (öffentliche Szenarien):
curl -s -o /dev/null -w "%{http_code}\n" https://<host>/      # 200 ok; 403 = Bot-Block (erwartet)

# Credential-Lesbarkeit (nur Boolean, kein Wert):
ssh <host> 'cd /var/www/<basename>/current && RBENV_ROOT=/var/www/.rbenv \
  PATH=$RBENV_ROOT/shims:$PATH RBENV_VERSION=3.2.1 RAILS_ENV=production \
  bundle exec rails runner "puts Carambus.deepl_key.present?"'

# Config-Drift (Server-live vs. frisch generiert):
diff <(ssh <host> cat /var/www/<basename>/shared/config/cable.yml) \
     carambus_data/scenarios/<szenario>/production/cable.yml
```

**Nach jedem Puma-Restart ~5–10 s warten** (eager_load) — ein 502 unmittelbar
danach ist meist nur Boot-Timing, kein Fehler.

> Tiefergehende Health-/Worker-Diagnose: über `systemctl` + `journalctl -u puma-<basename>`.
