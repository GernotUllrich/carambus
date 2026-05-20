# External-Tournament-Bridge

> **Status:** v0.5 (In Progress) — Pilot: 3BandMannschaftsTurnier-App für BC Wedel
> 3-Band-Mannschaftsmeisterschaft

## Was ist die Bridge?

Carambus öffnet sich für externe Turnier-Apps. Eine externe App (z.B. die
3BandMannschaftsTurnier-App für 3-Band-Mannschaftsturniere) führt das Turnier durch und
tauscht mit Carambus über REST folgende Daten aus:

| Richtung | Endpoint | Zweck | Status |
|----------|----------|-------|--------|
| Carambus → App | `GET /api/external_tournament/tables` | Echte Tisch-Namen + table_kind pro Location | ✅ v0.5 (Plan 15-06) |
| Carambus → App | `GET /api/external_tournament/seeding` | Setzliste mit Players/Teams | ✅ v0.5 (Plan 15-02) |
| App → Carambus | `POST /api/external_tournament/round_start` | Tisch-Paarungen → Game-Creation + Scoreboard-Aktivierung | ✅ v0.5 (Plan 15-02/03 + 15-06 location/table_name) |
| Carambus → App | `GET /api/external_tournament/round_result` | Game-Ergebnisse zur Übernahme | ✅ v0.5 (Plan 15-04) |

**Eliminiert die Doppel-Erfassung** zwischen externer App und Carambus-Scoreboards.

## Deployment-Topologie

Die Spec ist **endpoint-agnostisch** — die App spricht REST gegen einen
Carambus-Server, unabhängig davon wo der läuft. Realer Default ist
**lokal am Spielort** (kein Internet erforderlich):

| Topologie | Beispiel | App-Reachable Base-URL | Empfohlen wenn... |
|-----------|----------|------------------------|-------------------|
| **Local Scenario (Default)** | `carambus_bcw` im Clubheim BC Wedel, App auf iPad im selben WLAN | `http://carambus.local:3000` oder `http://192.168.X.X:3000` | Single-Location-Turnier (häufigster Fall) |
| **Per-Region Cloud** | `nbv.carambus.de` | `https://nbv.carambus.de` | Multi-Location-Turnier in einer Region |
| **Globale Cloud** | `carambus.de` | `https://carambus.de` | Cross-Region-Turnier (selten für externe Apps) |

Service-Account-Anlage + Bearer-Token funktionieren in allen drei Topologien
identisch — nur die Base-URL und der Service-Account-Email-Suffix unterscheiden
sich (`@carambus.local`, `@carambus.de`).

## Architektur

```text
                Location (z.B. Clubheim BC Wedel, WLAN)
   ┌─────────────────────────────────────────────────────────────────┐
   │                                                                 │
   │  ┌─────────────────┐                  ┌──────────────────────┐  │
   │  │  External App   │   POST /round_start ─▶ │ Api::External-  │  │
   │  │  (3BandMann-    │ ◀─ GET  /seeding        │ TournamentsCtrl │  │
   │  │   schaftsTurn.) │ ◀─ GET  /round_result   │                 │  │
   │  └─────────────────┘                  └────────┬─────────────┘  │
   │       iPad/Laptop                              │ carambus_bcw   │
   │                                ┌──────────────┴────────────────┐│
   │                                │ ExternalTournament Services    ││
   │                                │ ├─ PlayerMatcher (15-02)       ││
   │                                │ └─ RoundStartProcessor (15-03) ││
   │                                └───────────────┬────────────────┘│
   │                                                ▼                 │
   │                              Game · GameParticipation · TableMonitor │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │ (optional) Sync-up zu Per-Region
                                  ▼  bzw. Global-Carambus über bestehenden
                              Per-Region oder Global  Sync-Layer (carambus_syncer)
                              Carambus-Instanz
```

Im typischen Setup ist **carambus_bcw die Single-Source-of-Truth während des
Turniers**. Sync zu der übergeordneten Per-Region- oder Global-Instanz
(`nbv.carambus.de` / `carambus.de`) läuft entkoppelt über den bestehenden
Sync-Layer — die App ist davon unabhängig.

## Authentifizierung

devise-JWT-Bearer-Tokens (analog Plan 14-G.14). **Pro Scenario** ein
Service-Account — egal ob lokal, per-Region oder global:

```bash
# Lokales Scenario am Spielort (Default)
cd /path/to/carambus_bcw      # z.B. carambus_bcw im Clubheim
rake service_accounts:create_2band[BCW]
# → legt 2band-bcw-bridge@carambus.local an, gibt Password einmalig aus

# Alternative: Per-Region Cloud (Multi-Location-Turnier)
cd /path/to/carambus_master   # global oder per-region wie nbv
rake service_accounts:create_2band[NBV]
# → legt 2band-nbv-bridge@carambus.de an
```

Bearer-Token holen — Base-URL je nach Topologie:

```bash
# Local Scenario via WLAN
curl -X POST http://carambus.local:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-bcw-bridge@carambus.local","password":"…"}}' \
  -i | grep -i Authorization
# Authorization: Bearer eyJhbGciOiJIUzI1NiJ9…

# Per-Region Cloud (Beispiel NBV)
curl -X POST https://nbv.carambus.de/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-nbv-bridge@carambus.de","password":"…"}}' \
  -i | grep -i Authorization
```

JWT-Lifetime: **90 Tage** (Long-Lived; via D-14-G7 +
`Carambus.config.jwt_expiration_days`) — App-seitig kein Renew-Friction
über die Turniersaison hinweg.

## Endpoint 0: Tables-Discovery (Plan 15-06)

```
GET /api/external_tournament/tables?location_cc_id=11&region=NBV
GET /api/external_tournament/tables?location_id=1&region=NBV   (Alternative)
Authorization: Bearer …
```

Read-only Discovery-Endpoint, damit die App die echten `Table#name`-Strings
nicht raten muss (D-15-06-A: Tisch-Namen sind beliebige Strings wie `"Tisch 5"`,
`"Gr. Tisch 1"`, `"Kl. Tisch 1"` — **keine** Nummern).

Response (`200`, Schema `carambus.tables/v1`):

```json
{
  "schema": "carambus.tables/v1",
  "region": { "shortname": "NBV" },
  "location": { "id": 1, "cc_id": 11, "name": "BC Wedel 61 Vereinsheim" },
  "tables": [
    { "name": "Tisch 5", "table_kind": "Small Billard", "has_monitor": true },
    { "name": "Tisch 6", "table_kind": "Small Billard", "has_monitor": false }
  ]
}
```

Location-Auflösung: `location_id` (Carambus-PK) hat Vorrang vor `location_cc_id`
(CC-Region-ID). `has_monitor` ist nur ein **Status-Hinweis** — ein Tisch ohne
Monitor wird beim Round-Start automatisch monitorfähig (siehe D-15-06-C).

Fehler: `401` (JWT), `404` (Region/Location nicht gefunden).

> **Defer (v0.6):** Optionaler Locations-Listen-Endpoint
> (`GET /api/external_tournament/locations?region=NBV`), damit die App die
> Location-Auswahl ohne bekannte `location_id` anbieten kann. Für den BC-Wedel-Pilot
> reicht die feste `location_id`/`cc_id` in der App-Konfiguration.

## Endpoint 1: Seeding (Plan 15-02)

```
GET /api/external_tournament/seeding?tournament_cc_id=12345&region=NBV
Authorization: Bearer …
```

Response: `carambus.seeding/v1`-konformes JSON-Dokument mit `tournament`,
`teams[]`, `players[]`.

**Plan 15-06 (R3/D-15-06-E):** `tournament.location` ist ein Objekt
`{id, cc_id, name}` (vorher ein String) — damit die App nach dem Setzlisten-Pull
die Location für den Round-Start vorbelegen kann. `null`, wenn
`tournament.location_id` nil ist (dann setzt die App die Location manuell).

**Polymorphic-aware Lookup:** Seeding ist polymorph (`Tournament` hat
verschiedene Subklassen). Die Endpoint-Logik detektiert Mannschaftsturnier
(mit `league_team_id`) vs. Single-Tournament und gruppiert Players
entsprechend.

## Endpoint 2: Round-Start (Plan 15-03)

```
POST /api/external_tournament/round_start
Authorization: Bearer …
Content-Type: application/json
```

Body: `carambus.round_start/v1` mit `games[]`-Array. Carambus erzeugt pro
Eintrag:

1. Einen `Game`-Record (mit `data["external_id"]` als Idempotenz-Key)
2. `GameParticipation`-Records pro Participant (via PlayerMatcher)
3. TableMonitor-Zuweisung (`game_id` setzen)

**Plan 15-06 (R2) — additive, v1-kompatible Erweiterungen:**

```json
{
  "schema": "carambus.round_start/v1",
  "region": { "shortname": "NBV" },
  "location": { "cc_id": 11 },        ← NEU (id ODER cc_id; optional)
  "tournament": { "cc_id": 886 },
  "round_no": 1,
  "games": [
    {
      "external_id": "…",
      "table_name": "Tisch 5",        ← NEU, bevorzugt
      "table_no": 5,                  ← bleibt als Fallback erhalten
      ...
    }
  ]
}
```

Response (`201 Created` oder `200 OK` bei Idempotenz):

```json
{
  "games": [
    { "external_id": "ms3b-2026-r1-tisch5-pos1", "game_id": 123, "table_monitor_id": 45 },
    { "external_id": "ms3b-2026-r1-tisch6-pos1", "game_id": 124, "table_monitor_id": 46 }
  ]
}
```

### Convention D-15-06-A: Tisch-Identifikation via `table_name` (supersedes D-15-03-A)

D-15-03-A (`Table.name == table_no.to_s`) traf auf **keine** reale Location zu —
echte Tische heißen `"Tisch 5"`, `"Gr. Tisch 1"` etc. Daher bevorzugt der
Lookup jetzt `table_name`, mit `table_no.to_s` als Backward-Compat-Fallback:

```
table_name="Tisch 5"   ⟶   Carambus Table.name == "Tisch 5"   (bevorzugt)
table_no=5             ⟶   Carambus Table.name == "5"          (Fallback, Alt-Client)
```

Lookup-Pfad (Service `RoundStartProcessor`):

```ruby
identifier = g[:table_name].presence || g[:table_no].to_s
table = Table.where(location_id: resolved_location_id).find_by(name: identifier)
raise TableNotFoundError, identifier unless table
tm = table.table_monitor || table.table_monitor!   # D-15-06-C: Lazy-Create
raise TableMonitorNotFoundError, identifier unless tm
```

**Location-Auflösung (D-15-06-B):** `payload.location.id` → sonst
`payload.location.cc_id` → sonst Fallback `tournament.location_id`. Nötig, weil
`tournament.location_id` nil sein kann (z.B. NordCup-Turnier ohne Location-Link).

**TableMonitor-Lazy-Create (D-15-06-C):** `table.table_monitor || table.table_monitor!`
(analog `tournaments_controller.rb`). Ein Tisch ohne Monitor wird beim Round-Start
automatisch monitorfähig. `table_monitor!` liefert `nil` wenn `!local_server?` →
`TableMonitorNotFoundError`.

**round_result-Symmetrie (D-15-06-D):** `table_name` wird in `Game.data` persistiert
und im `round_result` zusätzlich zu `table_no` emittiert, damit `table_name`-only-Games
wiederfindbar sind.

### Voraussetzung

Das `Tournament` muss eine `location_id` haben (sonst kann der Tisch nicht
gefunden werden) und die `Tables` der Location müssen via `table_monitor_id`
mit `TableMonitor`-Records verknüpft sein. Falls diese Verknüpfungen nicht
existieren, liefert der Endpoint `422` mit klarer Fehlermeldung.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | TournamentCc / Region nicht gefunden |
| 422 | Region-Mismatch, Player nicht resolved (`PlayerResolutionError`), TableMonitor nicht gefunden (`TableMonitorNotFoundError`) |
| 201 | Mindestens 1 Game neu erstellt |
| 200 | Idempotent Re-Send — keine neuen Records |

### Idempotenz

`Game.data["external_id"]` ist der App-eigene Identifier. Zweiter POST mit
demselben Payload liefert dieselben `game_id`s zurück, ohne Duplikate.
Garantiert durch:

- In-Code-Filter
  `tournament.games.find { |g| safe_data(g)["external_id"] == … }`
- Unique-Index `[game_id, player_id, role]` auf `game_participations`
- TableMonitor-Reassignment nur wenn `game_id` noch nicht passt

## Endpoint 3: Round-Result (Plan 15-04)

```
GET /api/external_tournament/round_result?tournament_cc_id=12345&round_no=1&region=NBV
Authorization: Bearer …
```

Response (`200 OK`): `carambus.round_result/v1`-konformes JSON-Dokument.

```json
{
  "schema": "carambus.round_result/v1",
  "region": { "shortname": "NBV" },
  "tournament": { "cc_id": 12345 },
  "round_no": 1,
  "results": [
    {
      "external_id": "ms3b-2026-r1-tisch5-pos1",
      "table_no": 5,
      "started_at": "2026-05-17T11:05:00+02:00",
      "ended_at":   "2026-05-17T11:42:00+02:00",
      "innings_played": 22,
      "participants": [
        { "role": "playera", "player": {"cc_id": 9001, "firstname": "Hans", "lastname": "Müller"},
          "points": 30, "innings": 22, "high_series": 5, "gd": 1.364 },
        { "role": "playerb", "player": {"cc_id": 9031, "firstname": "Peter", "lastname": "Schmidt"},
          "points": 24, "innings": 22, "high_series": 4, "gd": 1.091 }
      ]
    }
  ]
}
```

### Mapping (Carambus → Spec)

| Spec-Feld | Carambus-Quelle | Notiz |
|-----------|-----------------|-------|
| `external_id` | `Game.data["external_id"]` | Aus Round-Start-Push (Plan 15-03) |
| `table_no` | `Game.table_no` | — |
| `started_at` / `ended_at` | `Game.started_at` / `Game.ended_at` | ISO-8601; `null` falls nicht gesetzt |
| `innings_played` | `max(GameParticipation.innings)` | Nachstoß-tolerant (3-Band) |
| `participants[].role` | `GameParticipation.role` | `playera` / `playerb` / `playerN` |
| `participants[].player.cc_id` | `Player.cc_id` | Optional |
| `participants[].player.firstname` / `.lastname` | `Player.firstname` / `.lastname` | Display-Name |
| `participants[].points` | `GameParticipation.points` | Bälle |
| `participants[].innings` | `GameParticipation.innings` | Aufnahmen |
| `participants[].high_series` | `GameParticipation.hs` | Höchstserie |
| `participants[].gd` | `GameParticipation.gd` ODER berechnet | DB-Wert bevorzugt; sonst `points/innings`, 3 Nachkommastellen |
| `participants[].sets` | `GameParticipation.sets` | Optional, nur wenn vorhanden |

### Verhalten (Decisions D-15-04-A..F)

- **D-15-04-A**: Filter via `Tournament.games.where(round_no: N)`. Leere Runde → `200 OK`
  mit `results: []` (nicht 404 — App soll robust mit Empty-Round umgehen).
- **D-15-04-B**: **Alle** Games der Runde werden inkludiert — auch ohne `ended_at`
  (laufende Spiele). App entscheidet selbst, was sie damit macht.
- **D-15-04-C**: `innings_played` = `max(GameParticipation.innings)` (Nachstoß-tolerant
  für 3-Band: playerA kann 22 Aufnahmen haben, playerB 21).
- **D-15-04-D**: `gd` aus DB übernommen falls vorhanden, sonst aus `points/innings`
  berechnet (gerundet auf 3 Nachkommastellen).
- **D-15-04-E**: Player-Serialization analog 15-02 Seeding (cc_id/firstname/lastname);
  `dbu_nr` weggelassen (App matched primär über `external_id` + `role`).
- **D-15-04-F**: `round_no` Query-Param ist **required**. Fehlt oder nicht-numerisch →
  `422` mit klarer Fehlermeldung.
- **Sortierung**: nach `Game.seqno`, dann `Game.id` als Tiebreaker.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | TournamentCc / Region nicht gefunden |
| 422 | Region-Mismatch / `round_no` fehlt oder nicht numerisch |
| 200 | Round-Result-Doc (auch bei leeren Runden mit `results: []`) |

## Service-Layer

### `ExternalTournament::PlayerMatcher` (Plan 15-02)

3-Path-Fallback-Lookup:

1. **`region+cc_id`** — `Player.cc_id` ist NICHT global unique, daher
   region-scoped
2. **`dbu_nr`** — cross-region; DBU-Mitgliedschaft ist national eindeutig
3. **`firstname+lastname`** (optional + `club_cc_id` als Disambiguation)

Liefert `Player` oder `nil` — **kein Auto-Create**. Sportwart legt
unbekannte Player manuell in der CC-UI an.

### `ExternalTournament::RoundStartProcessor` (Plan 15-03 + 15-06)

- Transaktional (DB-Rollback bei jedem Fehler)
- Custom-Errors: `PlayerResolutionError`, `TableNotFoundError` (NEU 15-06),
  `TableMonitorNotFoundError` (Controller rescued auf 422; tragen jetzt
  String-`identifier` statt nur `table_no`)
- `resolve_location_id` (15-06): payload.location.id → cc_id → tournament.location_id
- Tisch-Lookup via `table_name` (Fallback `table_no.to_s`), Monitor via
  `table_monitor || table_monitor!` (Lazy-Create)
- `table_name` wird in `Game.data` persistiert
- Idempotenz via `Game.data["external_id"]`-Lookup
- TableMonitor-Assignment nur wenn nötig (skip wenn `game_id` bereits
  korrekt)

### `ExternalTournament::RoundResultAggregator` (Plan 15-04 + 15-06)

- **Read-only** Aggregator (keine DB-Writes, keine Transaction nötig)
- Filter: `tournament.games.where(round_no: N)` mit `seqno`-Order
- `innings_played` = `max(participants.innings)` — Nachstoß-tolerant
- `gd`-Fallback: DB-Wert oder berechnet aus `points/innings` (3 Nachkommastellen)
- Inkludiert auch laufende Games (ohne `ended_at`)
- Emittiert `table_name` (15-06/D-15-06-D) zusätzlich zu `table_no`

## Verwandte Decisions

| Decision | Wirkbereich |
|----------|-------------|
| D-15-01-A | Authority-Modell = Service-Account analog G.14 |
| D-15-02-A | Mapping-Decisions (synonyms-newline-split + balls_goal→target_points etc.) |
| D-15-02-B | Service-Account-Email = `2band-{region}-bridge@carambus.de` |
| D-15-03-A | Tisch-Identifikation via `Table.name == table_no.to_s` (**superseded durch D-15-06-A**) |
| D-15-04-A | Round-Result: leere Runde → `200 OK` mit `results: []` |
| D-15-04-B | Laufende Games (`ended_at: nil`) sind im Round-Result enthalten |
| D-15-04-C | `innings_played` = max(participant.innings) (Nachstoß-tolerant) |
| D-15-04-D | `gd` aus DB übernehmen falls vorhanden, sonst aus `points/innings` berechnen |
| D-15-04-E | Player-Serialization: cc_id/firstname/lastname (dbu_nr weggelassen) |
| D-15-04-F | `round_no` Query-Param ist required (422 wenn fehlt/non-numeric) |
| D-15-06-A | Tisch-Identifikation via `table_name` (Fallback `table_no`); supersedes D-15-03-A |
| D-15-06-B | Location-Auflösung: payload.location.id → cc_id → tournament.location_id |
| D-15-06-C | TableMonitor-Lazy-Create via `table_monitor || table_monitor!` |
| D-15-06-D | `table_name` in `Game.data` persistiert + im round_result emittiert |
| D-15-06-E | seeding `tournament.location` als `{id, cc_id, name}`-Objekt (vorher String) |

Siehe `.paul/STATE.md` für vollständige Decision-Records.

## Tests

```bash
cd carambus_master
bin/rails test \
  test/controllers/api/external_tournaments_controller_test.rb \
  test/services/external_tournament/
```

## Spec-Quelle (extern)

JSON-Schema-Dokumentation:
`/Users/gullrich/2BandTurnier/docs/json-schema.md` — extern,
app-seitig gepflegt. Bei Schema-Änderungen Plan-Loop für Sync (Plan 15-04+).

## Manager/User-Doku

Anwender-Anleitung (Workflow „Wie binde ich meine Turnier-App an Carambus
an?") folgt nach Empirical-Verify in Plan 15-05 — dann ist die Pilot-Story
(BC Wedel 3-Band-Saison 2026) belastbar dokumentierbar.
