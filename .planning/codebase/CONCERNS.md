# Codebase Concerns

**Stand:** 2026-09-02 · **Verifiziert gegen HEAD `90da7562`** (alle Zeilenangaben an diesem Tag geprüft)
**Vorgänger:** Audit vom 2026-04-09 — letzte Fassung in der Historie:
`git show 1b8dbe8c:.planning/codebase/CONCERNS.md`

---

## Zum Umgang mit diesem Dokument

Jeder Punkt hier wurde gegen den laufenden Code geprüft und trägt einen Beleg (Datei:Zeile oder
Messwert). Was sich nicht belegen ließ, steht nicht drin.

**Warum die Neufassung:** Das Vorgänger-Audit war nach 2.248 Commits weitgehend überholt — von
~44 geprüften Aussagen war rund ein Drittel erledigt oder schlicht falsch, ein weiteres Drittel
nur teilweise gültig. Fast jede Zeilenangabe stimmte nicht mehr, eine referenzierte Datei
existierte gar nicht. Die Liste der widerlegten Aussagen steht am Ende — damit sie niemand
erneut aufwirft.

**Regel für die Zukunft:** Vor Arbeit an einem Punkt gegen den aktuellen Code verifizieren.
Nicht nur die genannte Datei prüfen — Zeilennummern veralten, und der Fix kann woanders liegen.

---

## Sicherheit

### ActionCable: Forgery-Protection abgeschaltet
- **Beleg:** `config/application.rb:200-201` — `disable_request_forgery_protection = true`
- **Kern:** Das Flag macht `allowed_request_origins` zu **totem Code** (actionpack
  `connection/base.rb` kehrt vorher zurück). Die dort stehenden Regexe `/http:\/\/*/` sind
  ohnehin falsch formuliert (unverankert, „`http:` + null-oder-mehr `/`") und wirken auch als
  Whitelist nicht.
- **Entwarnung:** `allow_same_origin_as_host = true` deckt den Normalfall ab; der Client nutzt
  die relative URL `/cable`. Eine Whitelist wird vermutlich gar nicht gebraucht.
- **Stand:** Ausgearbeiteter Task mit Testplan liegt vor:
  `.planning/tasks/TASK-actioncable-origin-hardening.md`. Die Dry-Run-Messung auf der Authority
  ergab **0 Rejects**; Raspi-im-Vereins-LAN und OBS-Session sind **ungemessen** — daran hängt es.

### Per-User-CC-Zugänge fallen aus jeder Rotation heraus
- **Beleg:** `users.cc_password` (`encrypts`, `app/models/user.rb:38`); `PRESERVE_KEYS` in
  `lib/tasks/scenarios.rake:686` schließt sie nicht ein, weil sie gar nicht in den Credentials liegen.
- **Wirkung:** Ändert ein Nutzer sein CC-Passwort im Portal, verfällt sein hinterlegter Zugang
  still — seine Schreibvorgänge scheitern am CC-Login, keine Routine bemerkt das.
- **Empfehlung:** Health-Check, der die hinterlegten Zugänge prüft und Betroffene benachrichtigt.

### Der geteilte ClubCloud-Zugang ist ein persönliches Konto
- **Beleg:** `credentials.clubcloud[:nbv]`, Username identisch mit dem `operator` im
  `McpAuditTrail`; genutzt von `region_cc/tournament_syncer.rb:44`, `tournament_cc.rb:349`,
  `tournaments_controller.rb:450`, `cc_session.rb:337`, `lib/tasks/cc.rake`.
- **Wirkung:** Automatik (Scrape/Sync) und persönliche Aktionen sind in der CC-Historie nicht
  unterscheidbar; ein Passwortwechsel des Kontoinhabers legt das Scraping still.
- **Empfehlung:** Eigenes CC-Dienstkonto beim Verband beantragen, `shared.clubcloud.nbv` darauf
  umstellen. **Nicht entfernen** — Lesen, Scraping und Sync hängen daran (nur *Schreiben*
  angemeldeter Nutzer läuft über deren eigene Zugänge, D-39-6/8).

### Kein Rate-Limiting
- **Beleg:** kein `rack-attack`; kein `rate_limit`-Aufruf in `app/controllers/`;
  nginx `limit_req` auskommentiert (`config/deploy/templates/nginx_conf.erb:40`).
- **Billiger als gedacht:** Rails 7.2 bringt `ActionController::RateLimiting` **mit** — keine
  neue Abhängigkeit nötig, nur ungenutzt.

### Ungegatetes Logging in Production
- **Beleg:** **45** ungegatete `logger.info` mit Emoji in `app/` (enge Emoji-Auswahl; mit allen
  Unicode-Bereichen deutlich mehr). Hotspots: `app/jobs/table_monitor_job.rb`, `app/models/table_monitor.rb`.
- **Wirkung:** aufgeblähte Logs, potenziell Spielernamen/Ergebnisse im Klartext.

### Keine Schema-Validierung für gescrapte Fremddaten
- **Beleg:** `app/services/umb/*` und `seeding_list_extractor.rb` haben durchgängig `rescue`-Blöcke
  und eine Plausibilitätsprüfung (`seeding_list_extractor.rb:398`), aber keine Validierung vor dem
  DB-Insert.
- **Einordnung:** „keine Validierung" wäre zu hart — Fehlerbehandlung existiert. Was fehlt, ist
  eine systematische Prüfung.

---

## Fehler und Fallen

### `prepare_deploy` überschreibt Server-Credentials mit veraltetem Stand
- **Beleg:** `scenario:push_credentials` merged **ausschließlich serverseitig**
  (`push_credentials_to_server`, `lib/tasks/scenarios.rake:881`); die lokalen
  `carambus_data/scenarios/*/production/credentials/*.enc` werden dabei nie angefasst.
  `prepare_deploy` lädt aber genau diese lokalen Dateien hoch (`scenarios.rake:3626-3639`).
- **Wirkung:** Nach jeder serverseitigen Credential-Änderung ist ein `prepare_deploy` eine
  scharfe Waffe — es spielt alte Secrets und alte Schlüssel zurück.
- **Gegenmittel:** Nach jedem `push_credentials` lokal nachziehen:
  `WRITE=true rake scenario:generate_credentials[<name>]`.

### DB-Zugriff zur Klassenladezeit
- **Beleg:** `app/models/setting.rb:38` — `SETTING = Setting.first || Setting.create!`
  (ein **INSERT** beim Boot); `app/models/league.rb:84` — `DBU_ID = Region.find_by_shortname("DBU")&.id`
- **Wirkung:** bricht `db:migrate`/`assets:precompile` auf frischer Datenbank; `DBU_ID` bleibt
  dauerhaft `nil`, wenn die Tabelle beim Laden leer war.

### `google_service`: irreführende Feldnamen, PEM am falschen Ast
- **Beleg:** `google_calendar_service.rb:56` nutzt `google_service[:public_key]` als Fallback für
  `private_key_id` — das Feld ist also **nicht** ein öffentlicher Schlüssel, sondern die Key-ID.
  Im Pool lag das PEM fälschlich unter `shared.region_server.private_key`.
- **Falle bei Rotation:** Wird nur die Key-ID erneuert, während das alte PEM stehen bleibt,
  passen `kid` und Signatur nicht mehr zusammen → Kalender-Auth bricht. Beide Felder gehören
  immer zusammen erneuert.
- **Nicht-Befund:** Das PEM ist einzeilig mit literalen `\n` gespeichert — das ist **beabsichtigt**,
  `google_calendar_service.rb:39` wandelt es um (`gsub('\n', "\n")`).

### Zwei konkrete N+1
- `app/views/players/_players_list.html.erb:12` — `find_by` auf einer Association geht pro Zeile
  an die DB und hebelt das `includes` aus `players_controller.rb:10` aus.
- `app/views/parties/_parties_table.html.erb:28` — `party.league.organizer` (polymorph) ist in
  `parties_controller.rb:10` nicht vorgeladen.
- **Einordnung:** Die pauschale N+1-Warnung des Alt-Audits trifft nicht mehr zu — die Controller
  nutzen `includes`. Diese beiden Stellen heben es in der View wieder auf.

---

## Wartbarkeit

### Callback-Dichte in TableMonitor
- **Beleg:** **ein** `after_update_commit`-Lambda über `app/models/table_monitor.rb:130` ff.
  (rund 130 Zeilen) mit 7 `perform_later`-Pfaden, 2 Early-Returns und einer doppelten
  `begin/rescue`-Kaskade; dazu 10 Emoji-Logzeilen im Hot Path.
- **Einordnung:** Der einzige `after_*_commit` der Klasse. Kandidat für die bereits deferrte
  Lifecycle-Extraktion (D-53-2/D-55-1), nicht für einen Schnellschuss.

### `table_monitor.rb` wächst wieder
- **Messung:** 2026-07-15 nach dem Refactoring **1996** Zeilen → 2026-08-16 **2007** → heute **2215**.
- **Einordnung:** Der Gewinn aus dem TableMonitor-Refactoring (Extraktion von `InningsEditor` und
  `PanelPresenter`) ist binnen sieben Wochen wieder aufgezehrt. Kein akutes Problem, aber ein
  Hinweis, dass die Extraktion ohne eine Regel „neue Logik gehört in einen Kollaborator" nicht hält.

### PDF-Verarbeitung ohne Streaming und ohne Größenlimit
- **Beleg:** `umb/http_client.rb:65` (`StringIO` über den vollen Body),
  `seeding_list_extractor.rb:25-26`, Upload-Pfad `tournaments_controller.rb:858`
  (`File.binwrite(..., uploaded_file.read)`) — nirgends ein Size-Check.

### `andand` (610 Verwendungen in 103 Dateien)
- Durch Rubys `&.` überflüssig, aber **kein Quick-Win**: `.andand` und `&.` verhalten sich bei
  `false` unterschiedlich, also nicht mechanisch ersetzbar. Nur als eigenständiges,
  schrittweises Refactoring sinnvoll — oder gar nicht.

### Verbliebene YAML-serialisierte Spalten
- 31 `serialize`-Aufrufe, davon 25 mit `coder: JSON`; **6 YAML**:
  `table_monitor.rb:48/49` (`gps`, `options`), `party.rb:69` (`remarks`),
  `league.rb:50` (`game_parameters`), `region.rb:56` (`scrape_data`).
- Niedrige Priorität — die Migration ist überwiegend erfolgt.

---

## Betrieb und Skalierung

### ActionCable streamt global statt raum-bezogen
- **Beleg:** `app/channels/table_monitor_channel.rb:11` streamt aus `"table-monitor-stream"` —
  jeder Scoreboard-Client erhält jeden Tisch-Broadcast. `location_channel.rb:9` und
  `tournament_channel.rb:5` machen es dagegen richtig mit ID-Scoping.
- **Einordnung:** Der valide Kern des alten „Broadcast-Ineffizienz"-Punkts. Drosselung existiert
  bereits (`skip_cable_ready_updates` an 20+ Stellen, `suppress_broadcast`,
  `TournamentStatusUpdateJob.set(wait: 2.seconds)`), die Raum-Trennung fehlt.

### Scraper laufen synchron aus Controllern
- **Beleg:** `regions_controller.rb:66-113,134`, `leagues_controller.rb:65,74,82`,
  `clubs_controller.rb:69,78`, `tournaments_controller.rb:277`, `versions_controller.rb:77-101`;
  im ganzen `app/controllers` nur **zwei** `perform_later`.
- **Wichtig:** Der naheliegende Rat „auf Sidekiq umstellen" ist **irreführend** — der
  ActiveJob-Adapter ist überall `:async` (in-process, `config/carambus.yml:11,56`). `perform_later`
  verlagert nur in denselben Puma-Prozess: behebt das Request-Timeout, nicht den Speicherdruck.
  Eine echte Entkopplung wäre erst eine eigene Entscheidung (Sidekiq + Redis-Queue).

### Kein Error-Tracking
- Kein Sentry/Rollbar/Honeybadger/Bugsnag/AppSignal in `Gemfile`, `Gemfile.lock` oder `config/`.
- **Einordnung:** Der wohl größte Hebel dieser Liste — mehrere Fehler dieser Codebasis wurden
  über Monate nur durch Zufall entdeckt.

### Backup ohne Off-Host-Kopie und ohne Restore-Test
- **Vorhanden:** `bin/pg_backup.sh` (119 Z.) + `config/schedule.rb:203-205` (nächtlich, `roles: [:api]`)
  + `:228-232` (eigenständige Standorte). Der Concern „keine Backup-Strategie" ist **erledigt**.
- **Offen und im Code selbst annotiert:** Die Dumps liegen auf derselben Platte/SD-Karte wie die
  DB; ein automatisierter Restore-Test fehlt. Für einen Raspi ist genau das der Ausfall, gegen den
  man sichert.

### Keine Feature-Flags, kein Circuit Breaker für externe Quellen
- **Beleg:** kein Flipper; `retry_on` existiert nur in den CC-**Push**-Jobs
  (`game_result_sync_job.rb:27`, `entry_list_sync_job.rb:17`, …), **nicht** in den Scrape-Jobs
  (`scrape_umb_job.rb`, `daily_international_scrape_job.rb`, …) — dort nur `rescue`+Log.

### Datenbank-Pool
- `config/database.yml:5` = 5, aber die deployten Templates nutzen
  `ENV.fetch("RAILS_MAX_THREADS") { 5 }` und sind an die Puma-Threadzahl gekoppelt.
  Es fehlt kein Mechanismus — es fehlt ein gesetztes `RAILS_MAX_THREADS`.

---

## Test-Lücken

| Bereich | Stand | Beleg |
|---|---|---|
| **PDF-/OCR-Extraktion** | **0 Tests** | kein Treffer für `SeedingListExtractor` in `test/`; die Datei hat 534 Zeilen. Die vorhandenen PDF-Tests (`test/services/umb/pdf_parser/`) decken einen anderen Pfad ab. |
| **Übersetzungen/i18n** | **0 Tests** | keine Testdatei mit i18n/locale-Bezug; kein `translation_missing`/`available_locales` in `test/` |
| CC-Sync-Recovery | teilweise | 11 Syncer-Tests unter `test/services/region_cc/`, aber Ausfall *mitten im Lauf* und Inkonsistenz-Auflösung ungetestet |
| Reflex-Concurrency | teilweise | Race-Guards in `game_protocol_reflex_test.rb:137-164`, `CONC-02` in `table_monitor_isolation_test.rb:372`; echte Thread-Races werden nicht simuliert |
| API-Parameter-Validierung | teilweise | 11 Dateien unter `test/controllers/api/**`; nicht jeder Controller hat einen Test |

**Gesamtumfang zum Vergleich:** 391 Testdateien, 4.119 Tests.

---

## Blinder Fleck

**Der MCP-Server kommt in keinem Audit vor.** `lib/mcp_server/tools` ist mit 361 Änderungen seit
April 2026 der zweitaktivste Bereich der Codebasis — Tool-Verträge, Rollen-Scoping, CC-Identität,
Audit-Trail. Weder das Alt-Audit noch diese Fassung enthalten eine systematische Durchsicht
davon. Das ist die größte bekannte Lücke dieses Dokuments.

---

## Behoben (2026-08-16)

- **TLS-Verifikation** — 15 unbedingte `VERIFY_NONE` (darunter der Auth0-Token-Endpoint und der
  Authority-Sync mit zusätzlich `verify_hostname = false`) → `Carambus.ssl_verify_mode`,
  Default `VERIFY_PEER`, Notausstieg `CARAMBUS_TLS_INSECURE=1`. Alle fünf genutzten Hosts liefern
  gültige Zertifikate (Ruby-seitig gemessen). Commit `70012a2a`.
- **Master-Keys lagen öffentlich** — `config/credentials/*.key` seit `44cd1b75` (2025-08-13) im
  öffentlichen Repo; damit war jede `.yml.enc` lesbar. Alle Secrets rotiert (Anbieter-Keys,
  `secret_key_base`, ActiveRecord-Encryption, Master-Key) auf allen 7 Servern sowie Dev/Test;
  Credentials aus dem Repo genommen. Commits `f8174dc2`, `6260afa6`.
- **`scrape_clubs`-Kwargs-Bug** — drei Aufrufstellen übergaben `player_details:` als positionales
  `season`; „Reload mit Details" verhielt sich wie „Reload ohne Details". Commit `d0ee80f5`.
- Totes `openai` aus der Credential-Pipeline (`4e1389c0`), totes `_search_field`-Partial (`d66826d6`).

---

## Geprüft und NICHT (mehr) gültig

Damit diese Punkte nicht erneut aufgeworfen werden:

| Alt-Befund | Realität (2026-08-16) |
|---|---|
| „Mehrere Modelle über 2000 Zeilen" | `table_monitor.rb` **2215**, `league.rb` **583**, `tournament.rb` **725**, `region_cc.rb` **500** — nur eines über 2000 |
| `region_cc.rb` = 2728 Zeilen | 500 Z., zerlegt in 11 Syncer (`a510f3f5`, **einen Tag nach** dem Audit-Datum) |
| Doppelte UMB-Scraper | `umb_scraper_v2.rb` gelöscht (`d239e9b1`); `umb_scraper.rb` = 175-Z.-Fassade über `app/services/umb/` |
| UMB-Timeouts unbehandelt | zentral gelöst (`umb/http_client.rb:15,32,33,53`); offen ist nur Retry/Backoff |
| `database.yml` Syntaxfehler | Falsch-Positiv — parst sauber, keine Duplikate |
| ActionCable auth als `User.first` | behoben — `connection.rb:47` nutzt `env["warden"]&.user`; anonyme Verbindungen bewusst erlaubt (`67dfa40f`), 7 Tests |
| „Credentials kürzlich geändert" | Momentaufnahme-Artefakt ohne Aussagewert |
| Rails 7.2.0.beta2 | stabil (`~> 7.2.2`) |
| `ruby-openai` als Risiko | entfernt; einzige AI-Integration ist `anthropic` |
| `.ruby-version` nicht gepinnt | `3.2.1` exakt, `Gemfile` liest die Datei, Bundler gepinnt |
| „Keine Backup-Strategie" | implementiert (siehe oben); offen nur Off-Host + Restore-Test |
| TableMonitor kaum getestet | 15 einschlägige Testdateien inkl. Concurrency-Test |
| Scraper-Resilienz ungetestet | `test/scraping/scraping_smoke_test.rb` testet leer/HTTP-Fehler/Timeout/malformed/Netzfehler |
| `global_context`-Nutzung „unklar" | dokumentiert (`club.rb:58-60`), zentrales Scoping über `Scopable`/`ScopeResolver`/`SearchService#apply_scope`; der Rat „`default_scope` einführen" **widerspricht** der Architektur |
| `skip_update_callbacks` als „gefährlicher Workaround" | existiert nicht (0 Treffer); real ist das enger gefasste `suppress_broadcast` |
| „50+ Gems" | 79 Deklarationen, 299 aufgelöste Specs |
| Audit-Logging fehlt | PaperTrail-`whodunnit` global gesetzt (`application_controller.rb:24`), deckt auch alle Administrate-Controller; was fehlt, ist eine Auswertungs-**Ansicht** |

---

*Neufassung: 2026-09-02 · Belege gegen HEAD `90da7562` geprüft*
