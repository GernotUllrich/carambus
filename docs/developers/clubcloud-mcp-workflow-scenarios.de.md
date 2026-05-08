# ClubCloud MCP — Workflow-Scenarios („Spickzettel") Format-Spec

> **Status:** Light-Spec für v0.1 (Phase 3). Aufgrund minimaler Spickzettel-Anzahl (≤3) reicht reine Konvention + Minitest-Schmoke; ein formales Schema-Validation-Tooling (z. B. `json-schema`-Gem) wird ab ≥3 Spickzetteln evaluiert.

## Was ist ein Spickzettel?

Ein **Spickzettel** ist eine MCP-Resource unter `cc://workflow/scenarios/{slug}`, die Claude Desktop für eine typische Turniermanager-Aufgabe eine **deterministische Tool-Sequenz** als JSON-Schema-konforme Datei liefert. Statt sich frei durch die ClubCloud-UI zu klicken, liest Claude den Spickzettel und führt den User Schritt für Schritt durch genau die MCP-Tool-Aufrufe, die für die Aufgabe nötig sind. Spickzettel ergänzen — und ersetzen nicht — die existierenden Markdown-Erklärungen unter dem gleichen URI-Schema.

## JSON-Schema-Variante

Spickzettel folgen **JSON Schema Draft 2020-12** (`https://json-schema.org/draft/2020-12/schema`).

**Begründung:**
- Aktuelle stabile Standard-Variante (2020+), breite Tooling-Unterstützung.
- Erlaubt `if`/`then`/`else` für bedingte Step-Validierung — relevant z. B. wenn `bind_result` nur Pflicht ist, falls ein späterer Step die Variable referenziert.
- Draft 7 wäre Alternative (etwas breitere Gem-Kompatibilität), aber Draft 2020-12 ist Standard 2024+. v0.1 startet auf der aktuellen Variante.

## Top-Level-Felder

| Feld | Typ | Pflicht? | Beschreibung |
|------|-----|----------|--------------|
| `$schema` | string | optional | Schema-URI; Empfehlung: `"https://json-schema.org/draft/2020-12/schema"` |
| `id` | string | **Pflicht** | Spickzettel-Slug (matcht den URI: `cc://workflow/scenarios/<id>`) |
| `version` | string | **Pflicht** | Spickzettel-Version im Semver-Format (z. B. `"0.1.0"`) — erlaubt non-breaking Format-Updates |
| `title` | string | **Pflicht** | Mensch-lesbarer Titel auf Deutsch |
| `description` | string | **Pflicht** | 2-3 Sätze, was der Workflow tut |
| `prerequisites` | string[] | optional | Voraussetzungen als DE-Sätze (z. B. erforderliche CC-Rolle, Datenlage) |
| `user_confirm_strategy` | string | **Pflicht** | Eines von `"per_step"`, `"once"`, `"never"` — wie viel Bestätigung Claude einholt |
| `notes_for_claude` | string | optional | Hinweise an den LLM zum Konversations-Stil (z. B. „bei mehrdeutigen Spielernamen gezielt nachfragen") |
| `steps` | step[] | **Pflicht** | Array mit ≥1 Step (siehe Step-Felder) |

## Step-Felder

| Feld | Typ | Pflicht? | Beschreibung |
|------|-----|----------|--------------|
| `step_id` | string | **Pflicht** | Snake_case-ID, eindeutig im Spickzettel; macht Step-Bezüge in Logs lesbar |
| `tool` | string | **Pflicht** | Vorhandener MCP-Tool-Name (oder Phase-4-Stub, siehe `_phase4_stub`) |
| `params` | object | **Pflicht** | Hash mit Parametern — Werte können `{{var}}`-Substitutionen enthalten; darf `{}` sein |
| `bind_result` | object | optional | Variablen-Bindings für spätere Steps (siehe Variable-Notation) |
| `description_for_user` | string | **Pflicht** | 1 DE-Satz — der „Spickzettel-Text", den Claude dem TM zeigt |
| `user_confirm` | boolean | optional, default `false` | Wartet vor Tool-Call auf User-Bestätigung |
| `expected_outcome` | string | optional | Informativ — was Claude erwartet zurückzubekommen |
| `fail_action` | string | optional, default `"ask_user"` | Eines von `"ask_user"`, `"abort"`, `"skip"` — Verhalten bei Tool-Fehler |
| `_phase4_stub` | boolean | optional | `true` markiert Tool, das (noch) nicht existiert; Schmoke-Test toleriert das (siehe „Konvention für nicht-existente Tools") |
| `_stub_note` | string | optional | DE-Begleittext zur Stub-Markierung (warum, wann ersetzt) |

## Variable-Notation

Spickzettel-Variablen folgen exakt dem Phase-2-Pattern, das bereits im Scenario-Runner (`test/mcp_server/scenarios/scenario_runner_test.rb`) implementiert und getestet ist:

### `bind_result` — Variablen aus Tool-Response binden

```json
"bind_result": {
  "region_id":   "$.region.id",
  "region_short": "$.region.shortname"
}
```

JSONPath-Subset (3 Patterns):
- `$.foo` — Top-Level-Feld
- `$.foo.bar` — verschachteltes Feld
- `$.foo[0]` — erstes Array-Element (oder `$.foo[1]`, `$.foo[2]`, …)

### `{{var}}` — Variable in `params` einsetzen

```json
"params": {
  "shortname":  "{{region_short}}",
  "discipline": "{{discipline_name}}"
}
```

Vor dem Tool-Call werden alle String-Werte (rekursiv über Hash/Array) per `gsub` durch die im Step-Context gespeicherten Werte ersetzt. Unaufgelöste Variablen produzieren eine klare Fehlermeldung (`"unresolved variable: <name>"`).

**Pattern wiederverwendet:** Phase 2 hat das in `bind_result` + `dig_jsonpath` + `gsub` umgesetzt. Spickzettel verwenden exakt dasselbe Pattern für Konsistenz.

## Konvention für nicht-existente Tools (Phase-4-Stubs)

Wenn ein Spickzettel ein Tool referenziert, das in der aktuellen Phase noch nicht implementiert ist, wird der Step explizit markiert:

```json
{
  "step_id": "register_player",
  "tool": "cc_register_for_tournament",
  "_phase4_stub": true,
  "_stub_note": "Tool kommt in Phase 4. Bis dahin: Mock-Stub im Spickzettel."
}
```

- Underscore-Prefix `_phase4_stub` / `_stub_note` als Konvention für „nicht standardmäßiger Spickzettel-Inhalt".
- Der Schmoke-Test (`workflow_scenarios_spickzettel_test.rb`) erlaubt explizit `cc_register_for_tournament` mit `_phase4_stub: true`. Andere unbekannte Tool-Namen sind Test-Fail (Drift-Guard).
- In Phase 4 wird `_phase4_stub` einfach entfernt — die Format-Struktur bleibt stabil.

## Validation in v0.1

**Reine Konvention + Minitest-Schmoke** — kein externes Schema-Validation-Gem.

Begründung: Bei ≤3 Spickzetteln ist manuelle Pflege trivial; Drift-Risiko durch externe Tooling-Drift ist höher als der Pflege-Aufwand. Eskalation auf `json-schema`-Gem wird ab ≥3 Spickzetteln evaluiert.

**Schmoke-Test (`test/mcp_server/resources/workflow_scenarios_spickzettel_test.rb`):**

| Check | Was wird geprüft |
|-------|-----------------|
| 1. Valides JSON | `JSON.parse(content)` wirft keine Exception |
| 2. Top-Level-Pflichtfelder | `id`, `version`, `title`, `description`, `user_confirm_strategy`, `steps` sind vorhanden |
| 3. Step-Pflichtfelder | Jeder Step hat `step_id`, `tool`, `params`, `description_for_user` |
| 4. Tool-Existenz | Jeder `step.tool` existiert in `McpServer::Tools.constants` ODER ist `cc_register_for_tournament` mit `_phase4_stub: true` |
| 5. JSON-Round-Trip | `JSON.generate(JSON.parse(content))` liefert äquivalentes JSON |
| 6. Mime-Type | `WorkflowScenarios.all` setzt `mime_type: "application/json"` für JSON-Spickzettel |

## Beispiel: `anmeldung-aus-email`

Vollständiges Beispiel siehe `docs/managers/clubcloud-scenarios/anmeldung-aus-email.de.json`. Auszug (1. Step):

```json
{
  "step_id": "lookup_region",
  "tool": "cc_lookup_region",
  "params": { "shortname": "{{region_shortname}}" },
  "bind_result": {
    "region_id": "$.region.id",
    "region_cc_id": "$.region.cc_id"
  },
  "description_for_user": "Ich klär zuerst die Region. {{region_shortname}} = ?",
  "user_confirm": false,
  "expected_outcome": "1 Region-Datensatz",
  "fail_action": "ask_user"
}
```

## Hinweise zur Klick-Reduktions-Doku-Quelle

Die zugehörige **Vorher/Nachher-Klick-Reduktions-Doku** lebt unter `docs/managers/clubcloud-mcp-klickreduktion-<workflow>.de.md` (Zielgruppe: Turniermanager, nicht Entwickler).

**Screenshots-Quelle (Empfehlung):**
1. **Test-CC-Instanz**, falls verfügbar — bevorzugte Quelle, keine PII-Sorgen.
2. **Prod-CC mit redacted PII** als Fallback — Spielernamen, Geburtsdaten und E-Mail-Adressen per Bildbearbeitung schwärzen; Verbandsdaten (NBV, BC-Wedel) sind öffentlich und brauchen keine Redaktion.
3. **Mockups** als Übergangslösung, wenn 1+2 nicht zeitnah verfügbar — explizit als Mockup kennzeichnen, nicht als reale Screenshots.

**Annotation-Format:**
- Markdown-eingebettete PNG/JPG mit beschreibender Caption.
- Rote Pfeile / Markierungen via macOS Preview oder Skitch (kein externer Toolchain wie Excalidraw).
- Pfade konsistent als `images/<workflow>-<phase>-<index>-<beschreibung>.png`.

## Versionierung

`version`-Feld pro Spickzettel folgt **Semver**:
- **Patch** (0.1.0 → 0.1.1): kleinere Wording-Korrekturen, keine Schema-Änderung.
- **Minor** (0.1.0 → 0.2.0): neue optionale Felder, neue Steps — Spickzettel-Reader können alte Versionen weiter lesen.
- **Major** (0.1.0 → 1.0.0): Breaking-Schema-Change — alte Spickzettel-Reader brauchen Update.

In v0.1 starten alle Spickzettel auf `0.1.0`.

---
*Format-Spec — Phase 3 Plan 03-02, 2026-05-08*
*Verweise: `.paul/phases/03-workflow-resources/RESEARCH.md` (Audit + Format-Begründung), `test/mcp_server/scenarios/scenario_runner_test.rb` (`bind_result`/`{{var}}`-Implementierung in Phase 2)*
