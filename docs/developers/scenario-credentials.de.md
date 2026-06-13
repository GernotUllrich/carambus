# Carambus Credentials — Inventur & Konsolidierungsplan

> Begleitdokument zu [scenario-parameter-reference.de.md](scenario-parameter-reference.de.md)
> und [scenario-drift-report.de.md](scenario-drift-report.de.md), Abschnitt 8.
>
> **Ziel:** Die hand-gepflegten, uneinheitlichen Rails-Credentials auf eine
> **einheitlich layered** Schreibweise bringen (Code + Daten) und mittelfristig
> **aus `<scenario>/config.yml` generierbar** machen — ohne Geheimnisse in die
> (Klartext-)`config.yml` zu legen.
>
> Stand: 2026-06-13

---

## 1. Sicherheitsfrage: Credentials aus `config.yml` generieren?

**Kurz:** Geheime Werte dürfen **nie** in `config.yml` (Klartext, in
`carambus_data`-git, geteilt). Das wäre ein echtes Security-Issue.

**Sicher** ist die Trennung:
- `config.yml` deklariert **nicht-geheim**, *welche* Keys/Features ein Szenario
  braucht (z. B. `scraping: true`, `clubcloud_context: NBV`).
- Die **Werte** liegen in einem geschützten Secret-Pool **außerhalb** von git
  (z. B. `~/.carambus-secrets/secrets.yml`, `chmod 600`, nur auf der
  Deploy-Maschine).
- Ein Generator kombiniert beides und schreibt die **verschlüsselten**
  `<env>.yml.enc` pro Szenario.

So entsteht kein Klartext-Geheimnis im Repo. (Design siehe Abschnitt 5.)

---

## 2. Inventur (2026-06-13)

Entschlüsselt aus den Checkout-Credentials (`<checkout>/config/credentials/`),
nur **Schlüsselpfade + Präsenz**, keine Werte.

### development (alle 9 Checkouts ~identisch)

```
google_service              (nested, Service-Account-JSON)
clubcloud.nbv.username      (nested; fehlt bei carambus_bcw, carambus_pbv = club-only)
clubcloud.nbv.password
deepl_key                   ← FLAT
youtube_api_key             ← FLAT
google.translate_api_key    (nested)
anthropic_key               ← FLAT
openai.api_key              (nested)
kozoom.email                (nested)
kozoom.password             (nested)
```

### production (alle 9 Checkouts identisch, kleiner)

```
google_service
youtube_api_key             ← FLAT
google.translate_api_key    (nested)
kozoom.email / kozoom.password
# KEIN anthropic, deepl, openai, clubcloud
```

### Befunde

1. **Gemischte Schreibweise:** `anthropic_key`, `deepl_key`, `youtube_api_key`
   sind **flat**; `openai.api_key`, `google.translate_api_key`, `kozoom.*`,
   `google_service`, `clubcloud.*` sind **nested**.
2. **🔴 Code-Bug `anthropic`:** Code liest `anthropic` **6×** als
   `.dig(:anthropic, :api_key)` (nested), die Daten haben aber `anthropic_key`
   (flat). Folge: `ai_search_service`, `ai_translation_service`,
   `anthropic_translation_service`, `spielleiter_chat_service` erhalten `nil`;
   nur `translation_service` (flat `fetch(:anthropic_key)`) funktioniert.
3. **dev ≠ prod:** production hat **keine** anthropic/deepl/openai-Keys →
   KI-Übersetzung läuft in production nicht. Scraping-Keys (youtube/kozoom) sind
   vorhanden.
4. **Checkout ≠ Server:** Server `carambus_nbv` (prod) wurde von Hand um
   `anthropic.api_key` (nested!) + `deepl_key` ergänzt — divergiert vom
   Checkout-prod. Hand-Drift.
5. **`carambus_data/scenarios/*/production/credentials/` ist stale** (enthält bei
   `carambus_nbv` nur `google_service`).

### Wie der Code die Keys liest (Soll-Referenz)

| Logisch | Code-Zugriff | Fundstellen |
|---|---|---|
| anthropic | `.dig(:anthropic, :api_key)` (6×) **+** `.fetch(:anthropic_key)` (2×) | ai_search_service:111,413 · ai_translation_service:33 · anthropic_translation_service:8,28 · spielleiter_chat_service:32 · **translation_service:3,158** |
| openai | `.dig(:openai, :api_key)` | metadata_extractor:90 · ai_docs_service:373 · openai_translation_service:16 · openai.rb:15,17 |
| deepl | `.fetch(:deepl_key)` | deepl_glossary_service:296 · deepl_translation_service:41 |
| youtube | `.youtube_api_key` | youtube_scraper:25 |
| google.translate | `.dig(:google, :translate_api_key)` | video_translation_service:154 |
| google_service | `.dig(:google_service, …)` | google_calendar_service:52 · table_reservation_service:134 |
| kozoom | `.dig(:kozoom, :email/:password)` | daily_international_scrape_job:46,47 · kozoom_scraper:11,12 |
| clubcloud | `.clubcloud[context]` | setting.rb:74,75 |

---

## 3. Ziel-Schema: einheitlich **layered**

Begründung (Entscheidung 2026-06-13): zusammengehörige Infos derselben Quelle
bleiben in der Hierarchie übersichtlich; Mehrheit + Code nutzen ohnehin nested.

```yaml
anthropic:
  api_key: ...
openai:
  api_key: ...
deepl:
  key: ...
google:
  translate_api_key: ...
youtube:
  api_key: ...
kozoom:
  email: ...
  password: ...
google_service:        # Service-Account-JSON, bleibt strukturiert
  ...
clubcloud:             # region-keyed, bleibt strukturiert
  NBV: { username: ..., password: ... }
secret_key_base: ...
devise_jwt_secret_key: ...
location_id: ...
location_calendar_id: ...
```

---

## 4. Umsetzungsplan

### Phase A — Code auf layered vereinheitlichen ✅ ERLEDIGT 2026-06-13

> **Hinweis:** Die `anthropic`-Vereinheitlichung war bereits durch Phase 37-02
> (`Carambus.anthropic_api_key`, Commit 6fecee4a) erledigt. Verbleibend waren nur
> deepl (2×) + youtube (1×) — umgesetzt analog als Helper
> `Carambus.deepl_key` / `Carambus.youtube_api_key` (nested-first, flat-Fallback),
> Commit `d0a40aee` (master, gepusht). openai wird im aktuellen Code nicht mehr
> genutzt. Helper sind tolerant → Code ist unabhängig von der Daten-Migration korrekt.

Ursprünglich abweichende Stellen vom layered-Ziel:

| Datei:Zeile | von | nach |
|---|---|---|
| translation_service.rb:3 | `credentials.fetch(:anthropic_key)` | `credentials.dig(:anthropic, :api_key)` |
| translation_service.rb:158 | `credentials.fetch(:anthropic_key)` | `credentials.dig(:anthropic, :api_key)` |
| deepl_glossary_service.rb:296 | `credentials.fetch(:deepl_key)` | `credentials.dig(:deepl, :key)` |
| deepl_translation_service.rb:41 | `credentials.fetch(:deepl_key)` | `credentials.dig(:deepl, :key)` |
| youtube_scraper.rb:25 | `credentials.youtube_api_key` | `credentials.dig(:youtube, :api_key)` |

> Achtung `fetch` → `dig`: `fetch` wirft bei fehlendem Key, `dig` gibt `nil`.
> Wo bewusst hart fehlschlagen gewünscht ist, `fetch(:anthropic).fetch(:api_key)`
> verwenden; sonst `dig` + Nil-Behandlung (die Aufrufer prüfen meist `.present?`).

### Phase B — Credentials-Daten migrieren

Pro Szenario/Env die flachen Keys in nested umschreiben **und** fehlende Keys
(anthropic/deepl/openai in production, überall deepl+google.translate+anthropic
als Backup) ergänzen:

```
anthropic_key: X      →  anthropic: { api_key: X }
deepl_key: X          →  deepl: { key: X }
youtube_api_key: X    →  youtube: { api_key: X }
```

Sensibel (Master-Keys, Re-Encryption). Optionen: manuell via
`rails credentials:edit --environment <env>` ODER kontrolliertes Migrationsskript
(entschlüsseln → umschreiben → re-encrypten), Master-Keys bleiben lokal.

### Phase C — Generator aus `config.yml` + Secret-Pool (Design)

Entscheidungen (2026-06-13): Pool **in `carambus_data/` (gitignored)**,
Deklaration über **Feature-Flags**, KI-/Übersetzungs-Keys **überall inkl. prod**.

#### C.1 Secret-Pool (einzige Klartext-Geheimquelle)

Datei `carambus_data/secrets.yml` — **gitignored** (Pflicht: Eintrag in
`carambus_data/.gitignore`). Rechte `chmod 600`. Struktur:

```yaml
shared:                       # überall verfügbar (Backup-Fähigkeit)
  anthropic: { api_key: "..." }
  deepl:     { key: "..." }
  google:    { translate_api_key: "..." }
  youtube:   { api_key: "..." }
  kozoom:    { email: "...", password: "..." }
per_scenario:                 # scenario-/region-spezifisch
  carambus_nbv:
    clubcloud: { NBV: { username: "...", password: "..." } }
    google_service: { ... }   # Service-Account-JSON
  carambus_bcw:
    google_service: { ... }
```

> **Sicherheit:** `secrets.yml` enthält die einzigen Klartext-Geheimnisse und
> darf **niemals** committet werden. `config.yml` bleibt geheimnisfrei.

#### C.2 Deklaration in `config.yml` (nicht-geheim)

```yaml
scenario:
  ...
  credentials:
    features: [ai, translation, scraping, clubcloud]
    clubcloud_context: NBV     # nur wenn 'clubcloud' aktiv; wählt per_scenario.clubcloud.<ctx>
```

Feature → Key-Gruppen-Mapping (im Generator hinterlegt):

| Feature | Keys aus `shared` |
|---------|-------------------|
| `ai` | `anthropic.api_key` (+ `openai.api_key`, falls je reaktiviert) |
| `translation` | `deepl.key`, `google.translate_api_key` |
| `scraping` | `youtube.api_key`, `kozoom.email`, `kozoom.password` |
| `clubcloud` | `clubcloud.<clubcloud_context>` aus `per_scenario.<name>` |

Default ohne `credentials.features`: `[ai, translation]` (Backup überall).
`google_service`, `location_id`, `location_calendar_id` sind **immer** dabei
(aus `per_scenario` bzw. bestehender Datei).

#### C.3 Generator-Logik (MERGE, nicht Regenerate)

```
rake "scenario:generate_credentials[<scenario>,<env>]"
```

1. **Bestehende** `<env>.yml.enc` mit `<env>.key` entschlüsseln (oder `{}` wenn neu).
2. **Bewahren** (nie überschreiben/neu würfeln): `secret_key_base`,
   `active_record_encryption.*`, `devise_jwt_secret_key`.
3. Aus `config.yml.credentials.features` die Key-Gruppen bestimmen, Werte aus
   `secrets.yml` (`shared` + `per_scenario.<name>`) im **nested**-Schema einmergen.
4. Re-encrypten mit `<env>.key`, schreiben.
5. `--dry-run` zeigt nur die resultierende **Key-Struktur** (keine Werte).

**Eigenschaften:** idempotent (gleiche Inputs → gleiches Ergebnis); verlustfrei
für stabile Keys; vereinheitlicht zugleich Checkout / Server / `carambus_data`,
wenn überall neu generiert + deployt wird.

#### C.4 Integration & Detailpunkte (entschieden 2026-06-13)

- ✅ **Einbindung in `prepare_deploy`:** `generate_credentials` läuft im
  `prepare_deploy`-Ablauf **vor** dem Credential-Upload (Default; manueller
  Aufruf bleibt möglich).
- ✅ **`secret_key_base` bei Neuanlage:** bestehende Werte werden **bewahrt**.
  Fehlt der Key (neues Szenario), wird er **einmalig generiert**
  (`SecureRandom.hex(64)`) — und sollte in den Pool (`per_scenario`)
  zurückgeschrieben/notiert werden, damit er stabil bleibt.
- ✅ **Historische flache Leaves entfernen:** beim Merge werden
  `anthropic_key` / `deepl_key` / `youtube_api_key` aus den Credentials gelöscht
  (das nested Schema ersetzt sie). Die `Carambus.*`-Helper lesen ab dann nested.

---

## 5. Status & erledigte Entscheidungen

- ✅ **Schreibweise:** layered (Code via tolerante `Carambus.*`-Helper; Daten-Ziel nested).
- ✅ **Phase A** (Code) erledigt & gepusht (`d0a40aee`).
- ✅ **prod-Key-Satz:** anthropic/deepl/(openai) sollen **überall inkl. production**.
- ✅ **Pool:** `carambus_data/secrets.yml` (gitignored). **Deklaration:** Feature-Flags.
- ✅ **Phase C implementiert** (2026-06-13): `rake "scenario:generate_credentials[<s>,<env>]"`
  in `lib/tasks/scenarios.rake` — Merge-Logik, Dry-Run-Default (Schreiben mit `WRITE=true`).
  Per Dry-Run an carambus_nbv verifiziert: nested-Merge von anthropic/deepl/google/youtube/kozoom/clubcloud.NBV,
  `secret_key_base` bewahrt. Pool-Schutz: `carambus_data/.gitignore` (secrets.yml) +
  `carambus_data/secrets.yml.example`. Adoption-Beispiel: `features`-Block in
  `scenarios/carambus_nbv/config.yml`.
- ⬜ **Phase B** wird durch Phase-C-`WRITE=true` miterledigt (echten Pool `secrets.yml` befüllen, dann je Szenario/Env schreiben + deployen).
- ⬜ **Rollout:** `features`-Block in alle Szenario-`config.yml`; Generator-Code committen/pushen; ggf. in `prepare_deploy` einhängen.
- ✅ **`fetch` vs `dig`**: Helper liefern `nil` statt Exception — Aufrufer prüfen `.present?` (ok).
