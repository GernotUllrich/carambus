---
phase: quick-260507-njl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/mcp_server/cc_session.rb
  - lib/mcp_server/tools/base_tool.rb
  - .mcp.json.example
  - docs/managers/clubcloud-mcp-setup.de.md
  - docs/developers/clubcloud-mcp-server.de.md
  - test/mcp_server/cc_session_test.rb
  - test/mcp_server/tools/cc_fed_id_env_default_test.rb
autonomous: true
requirements:
  - QUICK-260507-NJL
must_haves:
  truths:
    - "client_for raised KEINEN RuntimeError mehr wenn CC_USERNAME/CC_PASSWORD unset sind (Mock-Mode-bootbar ohne ENV)"
    - "default_fed_id liefert ENV-Wert wenn CC_FED_ID gesetzt (Override-Pfad), sonst Region-Lookup über CC_REGION/Setting context, sonst NBV-Default"
    - "default_fed_id rescued StandardError und liefert nil wenn DB nicht verfügbar (Mock-Smoke ohne DB darf nicht crashen)"
    - ".mcp.json.example zeigt nur 3 ENV-Vars (RAILS_ENV, CC_REGION, CARAMBUS_MCP_MOCK) — kein CC_USERNAME/CC_PASSWORD/CC_FED_ID mehr"
    - "Manager-Doku erwähnt CC_FED_ID/CC_USERNAME/CC_PASSWORD nicht mehr als zu setzende ENV-Vars"
    - "Developer-Doku Section 5 zeigt Rails-Credentials-Setup statt ENV-Vars für Live-Mode"
    - "Section 11 hat einen neuen Closure-Block für quick-260507-njl"
    - "Section 6 BaseTool.default_fed_id-Eintrag beschreibt Region-Lookup statt ENV-Lookup"
    - "Alle Tests grün: bin/rails test test/mcp_server/"
    - "public/docs/ rebuild + commit (mkdocs:build)"
  artifacts:
    - path: "lib/mcp_server/cc_session.rb"
      provides: "client_for ohne require_env!-Wächter"
      contains: "ENV[\"CC_USERNAME\"]"
    - path: "lib/mcp_server/tools/base_tool.rb"
      provides: "Region-basierter default_fed_id mit ENV-Override + rescue"
      contains: "Region.find_by(shortname:"
    - path: ".mcp.json.example"
      provides: "3-ENV-Vorlage"
      contains: "CC_REGION"
    - path: "docs/managers/clubcloud-mcp-setup.de.md"
      provides: "Manager-Doku ohne ENV-Credential-Sektion"
    - path: "docs/developers/clubcloud-mcp-server.de.md"
      provides: "Developer-Doku mit Rails-Credentials-Setup + Section-11-Closure"
    - path: "test/mcp_server/tools/cc_fed_id_env_default_test.rb"
      provides: "Erweiterte Tests für Region-Lookup-Pfad + rescue-Pfad"
  key_links:
    - from: "lib/mcp_server/tools/base_tool.rb#default_fed_id"
      to: "Region.find_by(shortname:).region_cc.cc_id"
      via: "DB-Lookup mit CC_REGION/Setting context"
      pattern: "region_cc&\\.cc_id"
    - from: "lib/mcp_server/cc_session.rb#client_for"
      to: "Setting.login_to_cc"
      via: "Lazy-Login delegiert; nil-Credentials zur Konstruktion erlaubt"
      pattern: "ENV\\[.CC_USERNAME.\\]"
---

<objective>
Drei zusammengehörige Aufräumarbeiten am MCP-Server (Phase 40 Closure):

1. Tote `require_env!`-Wächter in `cc_session.rb#client_for` entfernen — der echte Login läuft seit Phase 40 über `Setting.login_to_cc` (Rails-Credentials), die ENV-Vars `CC_USERNAME`/`CC_PASSWORD` waren nur tote Konstruktor-Parameter, die den Boot ohne Credentials unnötig blockiert haben.

2. `BaseTool.default_fed_id` von ENV-Lookup auf Region-Lookup umstellen — `Region.find_by(shortname: CC_REGION).region_cc.cc_id` ist die kanonische Quelle (BVBW=999, NBV=20, DBU=10, etc.). `CC_FED_ID` bleibt als ENV-Override höchste Priorität, defensives `rescue` für Mock-Smoke ohne DB.

3. `.mcp.json.example` + Manager-Doku + Developer-Doku auf das schlanke 3-ENV-Schema reduzieren (`RAILS_ENV`, `CC_REGION`, `CARAMBUS_MCP_MOCK`). Credentials liegen ab sofort ausschließlich in Rails Credentials. Auf carambus_bcw production sind sie bereits konfiguriert — kein User-Setup nötig.

Purpose: Klartext-Credentials raus aus `.mcp.json`, redundante ENV-Var (`CC_FED_ID`) raus aus dem Setup, Doku in Sync mit Realität.

Output: 7 modifizierte Files, 3 neue Tests, mkdocs-rebuild, ein Commit + push.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

# Quelldateien (zu ändern)
@lib/mcp_server/cc_session.rb
@lib/mcp_server/tools/base_tool.rb
@.mcp.json.example
@docs/managers/clubcloud-mcp-setup.de.md
@docs/developers/clubcloud-mcp-server.de.md
@test/mcp_server/cc_session_test.rb
@test/mcp_server/tools/cc_fed_id_env_default_test.rb
@app/models/setting.rb

<interfaces>
<!-- Kanonisch verifizierte Verträge — direkt verwenden, nicht erneut explorieren -->

# RegionCc::ClubCloudClient — Konstruktor akzeptiert nil ohne Validierung
# (app/services/region_cc/club_cloud_client.rb:424-430)
```ruby
attr_reader :base_url, :username, :userpw

def initialize(base_url:, username:, userpw:)
  @base_url = base_url
  @username = username
  @userpw = userpw
end
```
→ nil-Werte für username/userpw sind okay; echte Authentifizierung läuft ohnehin über Setting.login_to_cc.

# Setting.get_cc_credentials(context) — Rails-Credentials-Quelle
# (app/models/setting.rb:70-102)
# Liest Rails.application.credentials.clubcloud[context_key], Format:
#   clubcloud:
#     nbv:
#       username: "..."
#       password: "..."
#     bcw:
#       username: "..."
#       password: "..."
# → carambus_bcw production credentials.yml.enc trägt bereits diese Struktur.

# Setting.login_to_cc — kanonischer Login-Flow
# (app/models/setting.rb:104+)
# Liest opts[:context] via RegionCcAction.get_base_opts_from_environment,
# holt Region + RegionCc, ruft get_cc_credentials(context),
# POSTet an /login/checkUser.php mit MD5-Passwort + call_police-Hidden,
# extrahiert PHPSESSID, persistiert via Setting.key_set_value("session_id", ...).
# Ignoriert ENV CC_USERNAME/CC_PASSWORD vollständig.

# Region → RegionCc → cc_id (= ClubCloud federation id)
# Region.find_by(shortname: "NBV").region_cc.cc_id == 20  (verifiziert in DB)
# BVBW=999, NBV=20, DBU=10
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Code + Tests — client_for entwächterten + default_fed_id auf Region-Lookup umstellen + Test-Erweiterungen</name>
  <files>lib/mcp_server/cc_session.rb, lib/mcp_server/tools/base_tool.rb, test/mcp_server/cc_session_test.rb, test/mcp_server/tools/cc_fed_id_env_default_test.rb</files>
  <action>
**Step 1: lib/mcp_server/cc_session.rb#client_for — Wächter entfernen**

Ersetze den Block bei Zeilen 30-33:

```ruby
base_url = Carambus.config.cc_base_url || "https://www.club-cloud.de"
username = require_env!("CC_USERNAME")
password = require_env!("CC_PASSWORD")
RegionCc::ClubCloudClient.new(base_url: base_url, username: username, userpw: password)
```

durch:

```ruby
base_url = Carambus.config.cc_base_url || "https://www.club-cloud.de"
# ENV-Vars sind optional — der echte Login läuft über Setting.login_to_cc
# (Rails Credentials), das ENV CC_USERNAME/CC_PASSWORD ohnehin ignoriert.
# Konstruktor akzeptiert nil; Live-Login wird in #login! über Setting.login_to_cc geholt.
username = ENV["CC_USERNAME"].presence
password = ENV["CC_PASSWORD"].presence
RegionCc::ClubCloudClient.new(base_url: base_url, username: username, userpw: password)
```

`require_env!`-Methode (Zeile 101-103) bleibt vorerst stehen (nicht mehr aufgerufen, aber kein Code-Müll-Cleanup im Quick-Scope; falls 0 weitere Caller, kann sie verschwinden — grep prüfen):

```bash
grep -rn "require_env!" lib/mcp_server/ test/mcp_server/
```

Wenn nur die Definition selbst übrig ist (keine Aufrufer): Methode entfernen. Wenn andere Caller existieren: stehen lassen.

**Step 2: lib/mcp_server/tools/base_tool.rb#default_fed_id — Region-Lookup**

Ersetze die Methode (Zeile 47-49):

```ruby
def self.default_fed_id
  ENV["CC_FED_ID"]&.to_i
end
```

durch:

```ruby
# Liefert die ClubCloud federation_id als Default-Fallback für Tools.
# Priorität:
#   1. ENV["CC_FED_ID"] (expliziter Override — höchste Prio)
#   2. Region-Lookup via CC_REGION-ENV oder Setting context (kanonisch)
#   3. nil — bestehender "Missing required parameter: fed_id"-Fehler bleibt erhalten
#
# Defensiv: rescued StandardError, damit Mock-Smoke-Tests ohne DB nicht crashen.
def self.default_fed_id
  return ENV["CC_FED_ID"].to_i if ENV["CC_FED_ID"].present?

  context = ENV["CC_REGION"].presence ||
            (defined?(Setting) ? Setting.key_get_value("context").presence : nil) ||
            "NBV"
  region = Region.find_by(shortname: context.upcase)
  region&.region_cc&.cc_id
rescue StandardError => e
  Rails.logger.warn "[BaseTool.default_fed_id] Region lookup failed: #{e.class}"
  nil
end
```

**Step 3: test/mcp_server/cc_session_test.rb — "missing CC_USERNAME raises clear error"-Test ersetzen**

Der Test bei Zeile 35-41 prüft RuntimeError bei `ENV["CC_USERNAME"] = nil`. Diese Bahn ist nun zulässig (Ziel: ENV-frei bootbar). Ersetze diesen Test durch:

```ruby
test "missing CC_USERNAME and CC_PASSWORD: client_for darf ENV-frei booten (Login läuft über Setting.login_to_cc)" do
  ENV["CARAMBUS_MCP_MOCK"] = nil
  ENV["CC_USERNAME"] = nil
  ENV["CC_PASSWORD"] = nil
  client = nil
  assert_nothing_raised do
    client = McpServer::CcSession.client_for
  end
  assert_instance_of RegionCc::ClubCloudClient, client
  assert_nil client.username, "username should be nil — Setting.login_to_cc holt Credentials aus Rails Credentials"
  assert_nil client.userpw, "userpw should be nil — siehe oben"
end
```

(Übrige Tests bleiben unverändert.)

**Step 4: test/mcp_server/tools/cc_fed_id_env_default_test.rb — Region-Lookup-Tests ergänzen**

Ergänze am Ende der Klasse (vor `end` der Klassendefinition) drei neue Tests:

```ruby
# ===== Region-Lookup-Pfad (CC_FED_ID unset → Region.find_by(shortname:CC_REGION).region_cc.cc_id) =====
test "default_fed_id: ENV CC_FED_ID unset + CC_REGION=NBV → Region-Lookup liefert cc_id" do
  ENV["CC_FED_ID"] = nil
  ENV["CC_REGION"] = "NBV"

  fake_cc   = Struct.new(:cc_id).new(20)
  fake_reg  = Struct.new(:region_cc).new(fake_cc)
  Region.stub(:find_by, ->(args) { args == { shortname: "NBV" } ? fake_reg : nil }) do
    assert_equal 20, McpServer::Tools::BaseTool.default_fed_id
  end
ensure
  ENV["CC_REGION"] = nil
end

test "default_fed_id: CC_FED_ID-Override beats CC_REGION-Lookup" do
  ENV["CC_FED_ID"] = "999"
  ENV["CC_REGION"] = "NBV"

  # Region.find_by darf NICHT aufgerufen werden — Override-Pfad
  Region.stub(:find_by, ->(_args) { raise "Region.find_by should not be called when CC_FED_ID is set" }) do
    assert_equal 999, McpServer::Tools::BaseTool.default_fed_id
  end
ensure
  ENV["CC_FED_ID"] = nil
  ENV["CC_REGION"] = nil
end

test "default_fed_id: defensives rescue — DB-Fehler liefert nil ohne Exception" do
  ENV["CC_FED_ID"] = nil
  ENV["CC_REGION"] = "NBV"

  Region.stub(:find_by, ->(_args) { raise ActiveRecord::ConnectionNotEstablished, "no DB in mock-smoke" }) do
    result = nil
    assert_nothing_raised { result = McpServer::Tools::BaseTool.default_fed_id }
    assert_nil result
  end
ensure
  ENV["CC_REGION"] = nil
end
```

setup/teardown der Datei kümmert sich bereits um `ENV["CC_FED_ID"] = nil` (Zeile 17), aber `ENV["CC_REGION"]` muss in den neuen Tests selbst zurückgesetzt werden (siehe ensure-Blocks oben).

**Step 5: Test-Lauf**

```bash
bin/rails test test/mcp_server/cc_session_test.rb test/mcp_server/tools/cc_fed_id_env_default_test.rb
```

Erwartung: alle Tests grün. Falls `Setting.key_get_value("context")` in Test-Env wirft (z.B. weil Setting-Tabelle leer): `defined?(Setting)`-Guard erlaubt fall-through; und falls Setting da ist aber kein context-Wert, `&.presence` → nil → `"NBV"`-Default.

**Step 6: Volle MCP-Test-Suite**

```bash
bin/rails test test/mcp_server/
```

Erwartung: keine Regressionen.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/</automated>
  </verify>
  <done>
- cc_session.rb#client_for nutzt ENV[..].presence statt require_env!
- base_tool.rb#default_fed_id implementiert Region-Lookup mit ENV-Override + rescue
- cc_session_test.rb: "missing CC_USERNAME"-Test ersetzt durch ENV-frei-bootbar-Test
- cc_fed_id_env_default_test.rb: 3 neue Tests (Region-Pfad, Override-Pfad, rescue-Pfad)
- bin/rails test test/mcp_server/ — alle Tests grün, keine Regressionen
  </done>
</task>

<task type="auto">
  <name>Task 2: Doku + .mcp.json.example aufräumen + mkdocs:build + commit + push</name>
  <files>.mcp.json.example, docs/managers/clubcloud-mcp-setup.de.md, docs/developers/clubcloud-mcp-server.de.md</files>
  <action>
**Step 1: .mcp.json.example — auf 3 ENV-Vars reduzieren**

Ersetze den `env`-Block. Komplette Datei wird:

```json
{
  "_comment": "Phase 40 MCP-Server Konfigurationsvorlage. Kopiere diese Datei nach .mcp.json (Claude Code Konvention). CC-Credentials liegen in Rails Credentials (config/credentials/<env>.yml.enc), NICHT in dieser Datei. Die Variable-Expansion ${VAR} und ${VAR:-default} wird von Claude Code unterstuetzt.",
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "${PWD}/bin/mcp-server",
      "args": [],
      "env": {
        "RAILS_ENV": "${RAILS_ENV:-production}",
        "CC_REGION": "${CC_REGION:-NBV}",
        "CARAMBUS_MCP_MOCK": "${CARAMBUS_MCP_MOCK:-0}"
      }
    }
  }
}
```

**Step 2: docs/managers/clubcloud-mcp-setup.de.md — ENV-Credentials-Sektion entfernen**

(a) "Voraussetzungen"-Liste (Zeile 22-29): Zeile **"- Verbandsnummer (`CC_FED_ID`, z.B. `20` für BCW)"** komplett ENTFERNEN. Zeile **"- Eigene CC-Zugangsdaten (deine ClubCloud-E-Mail-Adresse + Passwort)"** durch folgenden Hinweis ersetzen:

```
- **CC-Zugangsdaten** sind auf Production-Servern (z.B. carambus_bcw) bereits in Rails Credentials konfiguriert.
  Für lokale Entwicklung siehe Abschnitt "Lokales Debug" unten.
```

(b) Schritt 3.3 (Zeile 60-87): Den `claude_desktop_config.json`-JSON-Block ersetzen durch:

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "/Users/<DEIN-USER>/DEV/carambus/carambus_api/bin/mcp-server",
      "args": [],
      "env": {
        "RAILS_ENV": "production",
        "CC_REGION": "NBV",
        "CARAMBUS_MCP_MOCK": "0"
      }
    }
  }
}
```

Den begleitenden Text **"Wichtig: Ersetze /Users/<DEIN-USER>/ ... und trage deine echten CC-Zugangsdaten ein."** ändern zu:

```
**Wichtig:** Ersetze `/Users/<DEIN-USER>/` durch deinen tatsächlichen Benutzernamen.
Die CC-Zugangsdaten liegen in Rails Credentials (auf Production-Servern bereits konfiguriert) —
es müssen keine Credentials in `claude_desktop_config.json` eingetragen werden.

Setze `CC_REGION` auf den Verbands-Shortname deiner Region (z.B. `NBV`, `BCW`, `DBU`).
Die ClubCloud-Verbandsnummer (`fed_id`) wird automatisch aus `Region.find_by(shortname: CC_REGION).region_cc.cc_id` ermittelt.
```

(c) Neue Sub-Sektion **"Lokales Debug — Rails Credentials einrichten"** vor "Schritt 3.4 — Claude Desktop neu starten" einfügen:

```markdown
### Schritt 3.3a — (nur lokales Debug) Rails Credentials für CC einrichten

Auf Production-Servern (z.B. carambus_bcw) sind die CC-Credentials in
`config/credentials/production.yml.enc` bereits hinterlegt — du musst nichts tun.

Nur falls du lokal auf deinem Mac den MCP-Server **gegen ein echtes ClubCloud** laufen lassen willst:

```bash
EDITOR=vi bundle exec rails credentials:edit --environment development
```

Trage folgende YAML-Struktur ein (Beispiel für NBV-Kontext):

```yaml
clubcloud:
  nbv:
    username: deine-cc-email@example.com
    password: dein-cc-passwort
```

Speichern und schließen — der MCP-Server liest beim nächsten Start automatisch
über `Setting.login_to_cc` aus den Credentials.

**Empfehlung für lokales Debug ohne CC-Account:** Setze stattdessen `CARAMBUS_MCP_MOCK=1` —
dann werden keine Credentials benötigt.
```

(d) Troubleshooting-Sektion **'CC login failed / "CC_USERNAME env var not set"'** (Zeile 147-155):
Header umbenennen zu **`"CC login failed" / "ClubCloud username not configured"`**, und die Ursachen-Beschreibung ersetzen durch:

```
**Ursache:** Rails Credentials für die Region nicht eingerichtet (oder falsche Region in `CC_REGION`).

**Sofortlösung:** Mock-Mode aktivieren, um die MCP-Verbindung zu testen:
```json
"CARAMBUS_MCP_MOCK": "1"
```

**Permanente Lösung:** Auf Production-Servern sind Credentials bereits konfiguriert — prüfe `RAILS_ENV=production`.
Für lokales Debug siehe "Schritt 3.3a — Rails Credentials einrichten" oben.
```

**Step 3: docs/developers/clubcloud-mcp-server.de.md — drei Sektionen aktualisieren**

(a) **Section 5 "Live-Mode" (Zeile 304-316):** Block

```bash
CC_USERNAME="dein@email.de" \
CC_PASSWORD="dein-passwort" \
CC_FED_ID="20" \
RAILS_ENV=development \
bin/mcp-server
```

ersetzen durch:

```bash
CC_REGION=NBV RAILS_ENV=development bin/mcp-server
```

Dann den begleitenden Absatz nach dem Code-Block ergänzen:

```
`CcSession` delegiert den Login an `Setting.login_to_cc` — der kanonische CC-Login-Flow inklusive
`call_police`-Hidden-Field, MD5-Passwort und PHPSESSID-Extraction. Phase 40 rollt **kein** eigenes
`Net::HTTP::Post` (extend-before-build).

Credentials werden ausschließlich aus **Rails Credentials** geladen (siehe Sub-Sektion unten).
ENV-Vars `CC_USERNAME`/`CC_PASSWORD`/`CC_FED_ID` werden seit Quick-Task `260507-njl` nicht mehr gelesen —
`CC_REGION` (Shortname, z.B. `NBV`) reicht aus, um Region + `fed_id` (= `region_cc.cc_id`) automatisch zu ermitteln.
`CC_FED_ID` bleibt als optionaler Override für Edge-Cases (z.B. Test-Fixtures ohne Region-Eintrag).
```

(b) **Neue Sub-Sektion "Rails Credentials Setup" in Section 5**, direkt nach dem Live-Mode-Block einfügen (vor "Claude Code (Project-Scope) einbinden"):

```markdown
### Rails Credentials Setup (für lokales Live-Debug)

Auf Production-Servern (z.B. `carambus_bcw`) sind CC-Credentials bereits in
`config/credentials/production.yml.enc` konfiguriert. Für lokales Live-Debug auf dem Dev-Mac:

```bash
EDITOR=vi bundle exec rails credentials:edit --environment development
```

YAML-Struktur (per-Region-Kontext):

```yaml
clubcloud:
  nbv:
    username: dein@email.de
    password: dein-cc-passwort
  bcw:
    username: anderer@email.de
    password: anderes-passwort
```

`Setting.get_cc_credentials(context)` liest den Block für den passenden Region-Shortname.
`CC_REGION` (oder `Setting.key_get_value("context")`) entscheidet, welcher Block geladen wird.

**Wichtig:** Die per-environment-Trennung bedeutet — Credentials müssen sowohl in `development.yml.enc`
(für lokales `bin/mcp-server`) als auch in `production.yml.enc` (für Production-Deployments) hinterlegt sein.
Ohne passenden Block: `RuntimeError "ClubCloud username not configured for region: <SHORTNAME>"` aus
`Setting.login_to_cc`.
```

Dann den Project-Scope-JSON-Block (Zeile 329-345) auf 3-ENV-Form reduzieren:

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "/abs/path/to/carambus_api/bin/mcp-server",
      "args": [],
      "env": {
        "RAILS_ENV": "development",
        "CC_REGION": "${CC_REGION:-NBV}",
        "CARAMBUS_MCP_MOCK": "${CARAMBUS_MCP_MOCK:-0}"
      }
    }
  }
}
```

Und den User-Scope-`claude mcp add`-Block (Zeile 351-359) auf 3-ENV-Form reduzieren:

```bash
claude mcp add carambus_clubcloud \
  --scope user \
  --command /abs/path/to/carambus_api/bin/mcp-server \
  --env CC_REGION=NBV \
  --env RAILS_ENV=development
```

Den Hinweis "Klartext-Passwort im Home-Dir" entfernen (kein Passwort mehr in der Config) und durch ersetzen:
**"Vorteil: überall verfügbar. Credentials liegen separat in Rails Credentials — kein Klartext im Home-Dir."**

(c) **Section 6 "Reference Manual — `BaseTool.default_fed_id`" (Zeile 418):** Tabellenzeile

```
| `.default_fed_id` | → `Integer` oder `nil` | Liest `ENV["CC_FED_ID"]&.to_i`. Tools nutzen `fed_id \|\|= default_fed_id` ... |
```

ersetzen durch:

```
| `.default_fed_id` | → `Integer` oder `nil` | Liefert die ClubCloud `fed_id` mit Priorität: (1) ENV `CC_FED_ID` (Override), (2) Region-Lookup via `Region.find_by(shortname: CC_REGION).region_cc.cc_id` (kanonisch — ENV `CC_REGION` oder `Setting.key_get_value("context")`, Default `NBV`), (3) `nil`. Defensives `rescue StandardError` schützt Mock-Smoke-Tests ohne DB. Tools nutzen `fed_id \|\|= default_fed_id` vor der Validierung. Geändert in Quick-Task `260507-njl` — vorher reiner ENV-Lookup. |
```

(d) **Section 11 "Bekannte Issues" — neuer Closure-Block am Ende der "Geschlossen"-Liste (nach dem 260507-m2z-Eintrag, Zeile ~864):**

```markdown
**Geschlossen (Quick-Fix `260507-njl`, 2026-05-07):**

- **MCP-Credentials-Cleanup — Rails Credentials + Region-Lookup statt ENV.** Drei zusammengehörige Aufräumarbeiten:
  - **Tote `require_env!`-Wächter in `cc_session.rb#client_for` entfernt:** `CC_USERNAME`/`CC_PASSWORD`-ENV-Reads waren nutzlos — der echte Login läuft seit Phase 40 über `Setting.login_to_cc` (Rails Credentials). Konstruktor akzeptiert `nil`-Credentials; ENV-frei bootbar.
  - **`BaseTool.default_fed_id` von ENV-Lookup auf Region-Lookup umgestellt:** `Region.find_by(shortname: CC_REGION).region_cc.cc_id` ist die kanonische Quelle (BVBW=999, NBV=20, DBU=10). `CC_FED_ID` bleibt als ENV-Override höchste Priorität. Defensives `rescue StandardError` für Mock-Smoke-Tests ohne DB.
  - **`.mcp.json.example` und Manager-/Developer-Doku auf 3-ENV-Schema reduziert** (`RAILS_ENV`, `CC_REGION`, `CARAMBUS_MCP_MOCK`). Klartext-Credentials raus aus Setup-JSON. Auf `carambus_bcw` Production-Server sind Rails Credentials bereits konfiguriert — kein User-Setup nötig.
  - 3 neue Tests in `cc_fed_id_env_default_test.rb` (Region-Pfad, Override-Pfad, rescue-Pfad). Bestehender `cc_session_test.rb`-Test "missing CC_USERNAME raises" durch "ENV-frei bootbar"-Test ersetzt.
```

**Step 4: mkdocs:build**

```bash
bin/rails mkdocs:build
```

Triggert Rebuild von `public/docs/`. Falls fehlt `mkdocs:build`-Task: `mkdocs build` direkt ausführen (DOCS_AUTO_REBUILD-Initializer macht das im Dev sonst automatisch).

**Step 5: Voll-Test-Sweep + commit + push**

```bash
bin/rails test test/mcp_server/
```

Wenn grün:

```bash
git add -A lib/mcp_server/cc_session.rb \
          lib/mcp_server/tools/base_tool.rb \
          .mcp.json.example \
          docs/managers/clubcloud-mcp-setup.de.md \
          docs/developers/clubcloud-mcp-server.de.md \
          test/mcp_server/cc_session_test.rb \
          test/mcp_server/tools/cc_fed_id_env_default_test.rb \
          public/docs/

git commit -m "$(cat <<'EOF'
chore(mcp): cleanup credentials — Rails Credentials + Region-Lookup statt ENV (quick-260507-njl)

- cc_session.rb#client_for: tote require_env!-Wächter entfernt (CC_USERNAME/CC_PASSWORD optional)
- BaseTool#default_fed_id: Region-Lookup (CC_REGION → Region.region_cc.cc_id) mit ENV-Override + rescue
- .mcp.json.example: auf 3 ENV-Vars reduziert (RAILS_ENV, CC_REGION, CARAMBUS_MCP_MOCK)
- Manager- und Developer-Doku: Rails-Credentials-Setup statt ENV-Vars + Section 11 Closure
- Tests: 3 neue Region-Lookup-Tests, cc_session-Test auf ENV-frei-bootbar umgestellt
- public/docs/ rebuild via mkdocs:build

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push
```

(`git add -A` hier auf explizite Pfade — nicht `git add -A` ohne Argumente, um keine `.planning/STATE.md` oder andere unbeteiligte Änderungen mitzunehmen.)
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/ && grep -L "CC_USERNAME\|CC_PASSWORD\|CC_FED_ID" .mcp.json.example && ! grep -E "CC_USERNAME|CC_PASSWORD|CC_FED_ID.*=" docs/managers/clubcloud-mcp-setup.de.md && grep -q "260507-njl" docs/developers/clubcloud-mcp-server.de.md</automated>
  </verify>
  <done>
- .mcp.json.example: nur 3 ENV-Vars (RAILS_ENV, CC_REGION, CARAMBUS_MCP_MOCK), keine Credentials
- Manager-Doku: Voraussetzungen-Liste ohne CC_FED_ID/CC_USERNAME/CC_PASSWORD; neue "Rails Credentials"-Sub-Sektion; claude_desktop_config.json-Block auf 3-ENV reduziert
- Developer-Doku Section 5: Live-Mode-Block zeigt CC_REGION + RAILS_ENV (kein USERNAME/PASSWORD/FED_ID); neue "Rails Credentials Setup"-Sub-Sektion; Project-Scope + User-Scope-Blöcke aufgeräumt
- Developer-Doku Section 6: BaseTool.default_fed_id-Eintrag beschreibt Region-Lookup
- Developer-Doku Section 11: 260507-njl-Closure-Block ergänzt
- public/docs/ rebuild via mkdocs:build
- bin/rails test test/mcp_server/ grün
- Single Commit gepusht mit allen 7 Source-Files + public/docs/
  </done>
</task>

</tasks>

<verification>
**Atomarer Quick-Task — eine commit, alle Bestandteile zusammen:**

1. `bin/rails test test/mcp_server/` — alle Tests grün (keine Regression in Phase-40-Suite)
2. `grep -c "CC_USERNAME\|CC_PASSWORD\|CC_FED_ID" .mcp.json.example` → **0** (alle drei raus)
3. `grep -c "CC_FED_ID\|CC_USERNAME-Eintrag\|CC_PASSWORD-Eintrag" docs/managers/clubcloud-mcp-setup.de.md` → erwartet niedrig (nur in "Troubleshooting"-Header der erlaubt bleibt; KEIN als-zu-setzende-ENV-Anweisung)
4. `grep -q "260507-njl" docs/developers/clubcloud-mcp-server.de.md` → match in Section 11 + Section 6
5. `grep -q "Region-Lookup\|region_cc&.cc_id" lib/mcp_server/tools/base_tool.rb` → match
6. `grep -q "ENV\[\"CC_USERNAME\"\].presence" lib/mcp_server/cc_session.rb` → match
7. Mock-Smoke ohne DB (defensiver `rescue` greift):
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
     CARAMBUS_MCP_MOCK=1 RAILS_ENV=development bin/mcp-server | grep -q '"serverInfo"'
   ```
8. `git log -1 --format=%s` → Commit-Subject enthält `quick-260507-njl`
</verification>

<success_criteria>
**Single quick-task atomic deliverable:**

- 7 Source-Files modifiziert + public/docs/ rebuild
- 3 neue Tests + 1 erweiterte Test-Erwartung
- Alle bestehenden MCP-Tests bleiben grün
- Klartext-Credentials sind aus dem `.mcp.json`-Setup entfernt
- `fed_id`-Default kommt automatisch aus Region.region_cc.cc_id (kein User-Eingriff nötig)
- Mock-Mode-Smoke-Tests laufen ohne DB-Abhängigkeit (defensives rescue)
- Single commit + push, Subject enthält `quick-260507-njl`
</success_criteria>

<output>
After completion, create `.planning/quick/260507-njl-mcp-credentials-cleanup-rails-credential/260507-njl-SUMMARY.md` mit:
- Final commit-hash
- Bestätigung der 8 Verification-Punkte
- Test-Counts (vorher/nachher)
- public/docs/ rebuild bestätigung
</output>
