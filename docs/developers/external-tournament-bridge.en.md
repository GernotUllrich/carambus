# External Tournament Bridge

> **Status:** v0.5 (In Progress) — Pilot: 3BandMannschaftsTurnier app for BC Wedel
> 3-cushion team championship

## What is the Bridge?

Carambus opens itself up to external tournament apps. An external app (e.g.,
the 3BandMannschaftsTurnier app for 3-cushion team tournaments) runs the tournament and
exchanges the following data with Carambus over REST:

| Direction | Endpoint | Purpose | Status |
|-----------|----------|---------|--------|
| Carambus → App | `GET /api/external_tournament/tables` | Real table names + table_kind per location | ✅ v0.5 (Plan 15-06) |
| Carambus → App | `GET /api/external_tournament/seeding` | Seeding list with players/teams | ✅ v0.5 (Plan 15-02) |
| App → Carambus | `POST /api/external_tournament/round_start` | Table pairings → Game creation + scoreboard activation | ✅ v0.5 (Plan 15-02/03 + 15-06 location/table_name) |
| Carambus → App | `GET /api/external_tournament/round_result` | Game results to import into the app | ✅ v0.5 (Plan 15-04) |
| App ↔ Carambus | `POST tournament` / `lock_table` / `start_game` / `acknowledge_result` / `end_tournament` | App-driven local tournament lifecycle (create, table binding, warmup start, result hold/pull, tournament end) | ✅ v0.5 (Plan 17-02..17-05) |
| App → Carambus | `POST /api/external_tournament/player_reconcile` | Match participants against Carambus-local → return dbu_nr | ✅ v0.5 (Plan 17-06) |
| Carambus → App | `GET /api/external_tournament/clubs` | Clubs of the region (picker) | ✅ v0.5 (Plan 18-01) |
| Carambus → App | `GET /api/external_tournament/club_players` | Players eligible to play this season for a club (cc_id + dbu_nr) | ✅ v0.5 (Plan 18-01) |

**Eliminates duplicate data entry** between the external app and Carambus
scoreboards.

## Deployment topology

The spec is **endpoint-agnostic** — the app talks REST to a Carambus server
regardless of where that server runs. The real-world default is **local
at the venue** (no internet required):

| Topology | Example | App-reachable base URL | Use when... |
|----------|---------|------------------------|-------------|
| **Local scenario (default)** | `carambus_bcw` at BC Wedel clubhouse, app on iPad in the same Wi-Fi | `http://carambus.local:3000` or `http://192.168.X.X:3000` | Single-location tournament (most common) |
| **Per-region cloud** | `nbv.carambus.de` | `https://nbv.carambus.de` | Multi-location tournament within a region |
| **Global cloud** | `carambus.de` | `https://carambus.de` | Cross-region tournament (rare for external apps) |

Service-account creation and bearer-token retrieval work identically in all
three topologies — only the base URL and the service-account email suffix
differ (`@carambus.local`, `@carambus.de`).

## Architecture

```text
                Venue (e.g., BC Wedel clubhouse, Wi-Fi)
   ┌─────────────────────────────────────────────────────────────────┐
   │                                                                 │
   │  ┌─────────────────┐                  ┌──────────────────────┐  │
   │  │  External app   │   POST /round_start ─▶ │ Api::External-  │  │
   │  │  (3BandMann-    │ ◀─ GET  /seeding        │ TournamentsCtrl │  │
   │  │   schaftsTurn.) │ ◀─ GET  /round_result   │                 │  │
   │  └─────────────────┘                  └────────┬─────────────┘  │
   │       iPad/laptop                              │ carambus_bcw   │
   │                                ┌──────────────┴────────────────┐│
   │                                │ ExternalTournament services    ││
   │                                │ ├─ PlayerMatcher (15-02)       ││
   │                                │ └─ RoundStartProcessor (15-03) ││
   │                                └───────────────┬────────────────┘│
   │                                                ▼                 │
   │                              Game · GameParticipation · TableMonitor │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │ (optional) sync up to per-region
                                  ▼  or global Carambus via the existing
                              Per-region or global  sync layer (carambus_syncer)
                              Carambus instance
```

In the typical setup `carambus_bcw` is the **single source of truth during
the tournament**. Sync to the upstream per-region or global instance
(`nbv.carambus.de` / `carambus.de`) runs decoupled through the existing
sync layer — the app stays independent of that.

## Authentication

devise-JWT bearer tokens (same pattern as Plan 14-G.14). **One service account
per scenario** — local, per-region, or global:

```bash
# Local scenario at the venue (default)
cd /path/to/carambus_bcw      # e.g., carambus_bcw at the clubhouse
rake service_accounts:create_2band[BCW]
# → creates 2band-bcw-bridge@carambus.local, prints password once

# Alternative: per-region cloud (multi-location tournament)
cd /path/to/carambus_master   # global or per-region such as nbv
rake service_accounts:create_2band[NBV]
# → creates 2band-nbv-bridge@carambus.de
```

Obtain a bearer token — base URL depends on topology:

```bash
# Local scenario via Wi-Fi
curl -X POST http://carambus.local:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-bcw-bridge@carambus.local","password":"…"}}' \
  -i | grep -i Authorization
# Authorization: Bearer eyJhbGciOiJIUzI1NiJ9…

# Per-region cloud (NBV example)
curl -X POST https://nbv.carambus.de/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-nbv-bridge@carambus.de","password":"…"}}' \
  -i | grep -i Authorization
```

JWT lifetime: **90 days** (long-lived; via D-14-G7 +
`Carambus.config.jwt_expiration_days`) — no renew friction for the app
side across the tournament season.

## Endpoint 0: Tables discovery (Plan 15-06)

```
GET /api/external_tournament/tables?location_cc_id=11&region=NBV
GET /api/external_tournament/tables?location_id=1&region=NBV   (alternative)
Authorization: Bearer …
```

Read-only discovery endpoint so the app does not have to guess the real
`Table#name` strings (D-15-06-A: table names are arbitrary strings such as
`"Tisch 5"`, `"Gr. Tisch 1"`, `"Kl. Tisch 1"` — **not** numbers).

Response (`200`, schema `carambus.tables/v1`):

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

Location resolution: `location_id` (Carambus PK) takes precedence over
`location_cc_id` (CC region ID). `has_monitor` is only a **status hint** — a
table without a monitor becomes monitor-capable at round start (see D-15-06-C).

Errors: `401` (JWT), `404` (region/location not found).

> **Defer (v0.6):** optional locations-list endpoint
> (`GET /api/external_tournament/locations?region=NBV`) so the app can offer a
> location picker without a known `location_id`. For the BC Wedel pilot the fixed
> `location_id`/`cc_id` in the app config is enough.

## Endpoint 1: Seeding (Plan 15-02)

```
GET /api/external_tournament/seeding?tournament_cc_id=12345&region=NBV
Authorization: Bearer …
```

Response: `carambus.seeding/v1`-compliant JSON document with `tournament`,
`teams[]`, `players[]`.

**Plan 15-06 (R3/D-15-06-E):** `tournament.location` is an object
`{id, cc_id, name}` (previously a string) so the app can pre-fill the location
for round start after the seeding pull. `null` when `tournament.location_id` is
nil (the app then sets the location manually).

**Polymorphic-aware lookup:** Seeding is polymorphic (`Tournament` has
multiple subclasses). The endpoint logic detects a team tournament (with
`league_team_id`) vs. a single tournament and groups players accordingly.

## Endpoint 2: Round Start (Plan 15-03)

```
POST /api/external_tournament/round_start
Authorization: Bearer …
Content-Type: application/json
```

Body: `carambus.round_start/v1` with a `games[]` array. For each entry
Carambus creates:

1. One `Game` record (with `data["external_id"]` as idempotency key)
2. `GameParticipation` records per participant (via PlayerMatcher)
3. TableMonitor assignment (`game_id` is set)

**Plan 15-06 (R2) — additive, v1-compatible extensions:**

```json
{
  "schema": "carambus.round_start/v1",
  "region": { "shortname": "NBV" },
  "location": { "cc_id": 11 },        ← NEW (id OR cc_id; optional)
  "tournament": { "cc_id": 886 },
  "round_no": 1,
  "games": [
    {
      "external_id": "…",
      "table_name": "Tisch 5",        ← NEW, preferred
      "table_no": 5,                  ← kept as fallback
      ...
    }
  ]
}
```

Response (`201 Created` or `200 OK` on idempotent replay):

```json
{
  "games": [
    { "external_id": "ms3b-2026-r1-tisch5-pos1", "game_id": 123, "table_monitor_id": 45 },
    { "external_id": "ms3b-2026-r1-tisch6-pos1", "game_id": 124, "table_monitor_id": 46 }
  ]
}
```

### Convention D-15-06-A: Table identification via `table_name` (supersedes D-15-03-A)

D-15-03-A (`Table.name == table_no.to_s`) matched **no** real location — real
tables are named `"Tisch 5"`, `"Gr. Tisch 1"` etc. The lookup now prefers
`table_name`, with `table_no.to_s` as backward-compat fallback:

```
table_name="Tisch 5"   ⟶   Carambus Table.name == "Tisch 5"   (preferred)
table_no=5             ⟶   Carambus Table.name == "5"          (fallback, legacy client)
```

Lookup path (service `RoundStartProcessor`):

```ruby
identifier = g[:table_name].presence || g[:table_no].to_s
table = Table.where(location_id: resolved_location_id).find_by(name: identifier)
raise TableNotFoundError, identifier unless table
tm = table.table_monitor || table.table_monitor!   # D-15-06-C: lazy-create
raise TableMonitorNotFoundError, identifier unless tm
```

**Location resolution (D-15-06-B):** `payload.location.id` → else
`payload.location.cc_id` → else fallback `tournament.location_id`. Needed because
`tournament.location_id` can be nil (e.g. a NordCup tournament without a location link).
**D-15-07-A:** the `cc_id` branch is **region-scoped** (`region_id` filter) — `cc_id`
is only unique within a region (e.g. 3 locations with `cc_id=11` across regions).
`location.id` (PK) is globally unique and needs no region filter.

**TableMonitor lazy-create (D-15-06-C):** `table.table_monitor || table.table_monitor!`
(mirrors `tournaments_controller.rb`). A table without a monitor becomes
monitor-capable at round start. `table_monitor!` returns `nil` when `!local_server?`
→ `TableMonitorNotFoundError`.

**round_result symmetry (D-15-06-D):** `table_name` is persisted in `Game.data`
and emitted in `round_result` in addition to `table_no`, so table_name-only games
remain identifiable.

### Prerequisites

The `Tournament` must have a `location_id` (otherwise the table cannot be
located) and the `Tables` in the location must be linked to `TableMonitor`
records via `table_monitor_id`. If these links are missing, the endpoint
responds with `422` and a clear error message.

### Error codes

| Status | Meaning |
|--------|---------|
| 401 | Missing/invalid JWT |
| 404 | TournamentCc / region not found |
| 422 | Region mismatch, player not resolved (`PlayerResolutionError`), TableMonitor not found (`TableMonitorNotFoundError`) |
| 201 | At least one game newly created |
| 200 | Idempotent replay — no new records |

### Idempotency

`Game.data["external_id"]` is the app-owned identifier. A second POST with
the same payload returns the same `game_id` values without creating
duplicates. Guaranteed by:

- In-code filter
  `tournament.games.find { |g| safe_data(g)["external_id"] == … }`
- Unique index `[game_id, player_id, role]` on `game_participations`
- TableMonitor reassignment only when `game_id` does not already match

## Endpoint 3: Round Result (Plan 15-04)

```
GET /api/external_tournament/round_result?tournament_cc_id=12345&round_no=1&region=NBV
Authorization: Bearer …
```

Response (`200 OK`): `carambus.round_result/v1`-compliant JSON document.

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

### Mapping (Carambus → spec)

| Spec field | Carambus source | Note |
|-----------|-----------------|------|
| `external_id` | `Game.data["external_id"]` | From round-start push (Plan 15-03) |
| `table_no` | `Game.table_no` | — |
| `started_at` / `ended_at` | `Game.started_at` / `Game.ended_at` | ISO-8601; `null` if not set |
| `innings_played` | `max(GameParticipation.innings)` | Carom-style "nachstoß" tolerant |
| `participants[].role` | `GameParticipation.role` | `playera` / `playerb` / `playerN` |
| `participants[].player.cc_id` | `Player.cc_id` | Optional |
| `participants[].player.firstname` / `.lastname` | `Player.firstname` / `.lastname` | Display name |
| `participants[].points` | `GameParticipation.points` | Balls |
| `participants[].innings` | `GameParticipation.innings` | Innings played |
| `participants[].high_series` | `GameParticipation.hs` | Highest series |
| `participants[].gd` | `GameParticipation.gd` OR computed | DB value preferred; else `points/innings`, 3 decimals |
| `participants[].sets` | `GameParticipation.sets` | Optional, only when present |

### Behavior (decisions D-15-04-A..F)

- **D-15-04-A**: Filter via `Tournament.games.where(round_no: N)`. Empty round →
  `200 OK` with `results: []` (not 404 — app should handle empty rounds robustly).
- **D-15-04-B**: **All** games of the round are included — even without `ended_at`
  (ongoing games). App decides what to do with them.
- **D-15-04-C**: `innings_played` = `max(GameParticipation.innings)` (3-cushion
  "nachstoß" tolerant: playerA may have 22 innings, playerB 21).
- **D-15-04-D**: `gd` taken from DB if present, else computed from `points/innings`
  (rounded to 3 decimals).
- **D-15-04-E**: Player serialization like Plan 15-02 seeding (cc_id/firstname/lastname);
  `dbu_nr` omitted (app matches primarily via `external_id` + `role`).
- **D-15-04-F**: `round_no` query parameter is **required**. Missing or non-numeric →
  `422` with a clear error message.
- **Ordering**: by `Game.seqno`, then `Game.id` as tiebreaker.

### Error codes

| Status | Meaning |
|--------|---------|
| 401 | Missing/invalid JWT |
| 404 | TournamentCc / region not found |
| 422 | Region mismatch / `round_no` missing or non-numeric |
| 200 | Round-result document (also for empty rounds with `results: []`) |

## Endpoint 4: Player reconcile (Plan 17-06)

```
POST /api/external_tournament/player_reconcile
```

Matches the app's participant list **against Carambus-local** (D-17-vision-2) and returns the
**dbu_nr** + the canonical Carambus record per entry. Reuses `ExternalTournament::PlayerMatcher`
(region+cc_id → dbu_nr → name+club). **Creates no players** (no auto-create) — unmatched entries
return `matched: false`, `player: null`.

Body:

```json
{
  "region": { "shortname": "NBV" },
  "participants": [
    { "ref": "t1p1", "cc_id": 9001, "dbu_nr": "12001", "firstname": "Dick", "lastname": "Jaspers", "club_cc_id": 11 },
    { "ref": "t1p2", "firstname": "Unknown", "lastname": "Player" }
  ]
}
```

Response (`200`, schema `carambus.player_reconcile/v1`):

```json
{
  "schema": "carambus.player_reconcile/v1",
  "region": { "shortname": "NBV" },
  "results": [
    { "ref": "t1p1", "matched": true,
      "player": { "id": 50000123, "cc_id": 9001, "dbu_nr": "12001",
                  "firstname": "Dick", "lastname": "Jaspers",
                  "club": { "cc_id": 11, "shortname": "BC Wedel" } } },
    { "ref": "t1p2", "matched": false, "player": null }
  ]
}
```

`ref` is echoed back unchanged (the app's own correlation key). `dbu_nr` is a string.

### Error codes

| Status | Meaning |
|--------|---------|
| 401 | Missing/invalid JWT |
| 404 | Region not found |
| 422 | `participants` missing or not a non-empty array |

## Endpoint 6: Club/Player discovery (Plan 18-01)

Two read-only, region-scoped endpoints for app-side player assignment. The operator picks
the participating clubs and assigns, per app player slot, an official player who is
**eligible to play** in the current season (carrying `cc_id` + `dbu_nr`) → exact
`start_game` matching + correct dbu_nr in the app results. Guests remain the fallback. Purely
additive — no change to `start_game`/`round_start` (the app already sends `cc_id`/`dbu_nr`
via `cleanPlayerRef` once set).

### `GET /api/external_tournament/clubs?region=NBV`

Clubs of the region (with `cc_id`) for the club picker. `cc_id` is the key for
`club_players`.

Response (`200`, schema `carambus.clubs/v1`):

```json
{
  "schema": "carambus.clubs/v1",
  "region": { "shortname": "NBV" },
  "season": { "name": "2025/2026", "current": true },
  "clubs": [
    { "cc_id": 11, "shortname": "BC Wedel", "name": "Billard Club Wedel" }
  ]
}
```

### `GET /api/external_tournament/club_players?region=NBV&club_cc_id=11`

Players **eligible to play** for the club in the current season. Eligibility is strictly
`SeasonParticipation status="active"` of `Season.current_season` (temporary/guest/nil
excluded; the `status` field is included per player). `dbu_nr` is CSV-relevant and may be
absent (`null`). Region scope: `cc_id` is only intra-region unique.

Multiple clubs in one call: `?region=NBV&club_cc_ids=11,12` → response as
`clubs:[{ club, players }]` instead of a single `club`.

Response (`200`, schema `carambus.club_players/v1`):

```json
{
  "schema": "carambus.club_players/v1",
  "region": { "shortname": "NBV" },
  "season": { "name": "2025/2026" },
  "club": { "cc_id": 11, "shortname": "BC Wedel", "name": "Billard Club Wedel" },
  "players": [
    { "cc_id": 4567, "firstname": "Oliver", "lastname": "Weese", "dbu_nr": "12345", "status": "active" }
  ]
}
```

### Error codes

| Code | Meaning |
|------|---------|
| `401` | Missing/invalid bearer token |
| `404` | Region unknown OR `club_cc_id` not in the region (region-scoped) |
| `422` | `club_cc_id` missing (and no `club_cc_ids` given) |

## Game-rule parameters in `start_game` (Plan 18-02)

`start_game` accepts optional per-game rule flags and applies them to the game:

| Flag | Effect | Default (when omitted) |
|------|--------|------------------------|
| `allow_follow_up` | Follow-up shot / equal innings (draw possible) | Tournament value (default **TRUE** → follow-up on) |
| `color_remains_with_set` | Color stays across the set | Tournament value (default TRUE) |
| `kickoff_switches_with` | Kickoff switch (`"set"` …) | Tournament value or `"set"` |
| `allow_overflow` | Overflow beyond the target | `false` |

**Location = per game (`start_game`)** with the tournament value as fallback (D-18-02-B): an
omitted flag inherits the tournament value (instead of being forced "off"); an explicitly sent
value (including `false`) is honored (D-18-02-A). For the 3-cushion team match, follow-up is thus
on by default. (The fix is bridge-scoped in `StartGameProcessor`; the shared `GameSetup` is unchanged.)

## Teardown & garbage collection (Plan 16-01)

**Carambus keeps no memory of the app tournament data.** The app maintains its own result memory
(pulled live via `acknowledge_result`), so Carambus may clean up a completed local app tournament
together with its games (D-16-GC-A). The former `csv_export` endpoint thereby became obsolete and
was removed in 16-02.

What gets deleted: the **marker games** (`game.data["tournament_external_id"]`) including their
`GameParticipation`s (cascaded via `dependent: :destroy`) **and the tournament itself**
(`tournament.destroy` cascades `TournamentMonitor`/`tournament_local`/`seedings`/`teams`/`setting`).
App games carry **no** `tournament_id` FK, so they are enumerated separately via the marker (no
cascade through the tournament). **Only local app tournaments** are cleaned up (`id >= MIN_ID` +
`manual_assignment`); managed/global tournaments and foreign games stay untouched.

Two triggers (D-16-GC-A, option D):

1. **`end_tournament` with `cleanup: true`** (opt-in, default off — D-16-01-A): after the table
   release, the tournament + its marker games are deleted. The response additionally reports
   `tournament_deleted` + `games_deleted`. **Without** the flag the previous behavior (release only,
   no deletion) is preserved — deletion is data-critical and therefore deliberately opt-in.

   ```
   POST /api/external_tournament/end_tournament
   { "region": {"shortname": "NBV"}, "tournament": {"external_id": "<app-id>"}, "cleanup": true }
   ```

   Response (`200`, `carambus.tournament_end/v1`):

   ```json
   {
     "schema": "carambus.tournament_end/v1",
     "region": { "shortname": "NBV" },
     "tournament": { "id": 50000123, "external_id": "<app-id>" },
     "released_tables": 1, "unacknowledged": 0, "tournament_monitor_state": "closed",
     "tournament_deleted": true, "games_deleted": 3
   }
   ```

2. **Midnight GC** (`rake external_tournament:release_stale_local_tables`, via whenever): the
   guaranteed safety net. After the stale release (which closes hanging app tournaments first), all
   **completed** local app tournaments (TournamentMonitor `closed` or missing) including their
   marker games are deleted. Active ones (monitor not closed) and managed/global tournaments stay
   untouched. Idempotent.

## Service layer

### `ExternalTournament::PlayerMatcher` (Plan 15-02)

Three-path fallback lookup:

1. **`region+cc_id`** — `Player.cc_id` is NOT globally unique, hence
   region-scoped
2. **`dbu_nr`** — cross-region; DBU membership is nationally unique
3. **`firstname+lastname`** (optional `club_cc_id` for disambiguation)

Returns `Player` or `nil` — **no auto-create**. The Sportwart creates
unknown players manually in the CC UI.

### `ExternalTournament::RoundStartProcessor` (Plan 15-03 + 15-06)

- Transactional (DB rollback on any error)
- Custom errors: `PlayerResolutionError`, `TableNotFoundError` (NEW 15-06),
  `TableMonitorNotFoundError` (controller rescues to 422; now carry a string
  `identifier` instead of just `table_no`)
- `resolve_location_id` (15-06): payload.location.id → cc_id → tournament.location_id
- Table lookup via `table_name` (fallback `table_no.to_s`), monitor via
  `table_monitor || table_monitor!` (lazy-create)
- `table_name` is persisted in `Game.data`
- Idempotency via `Game.data["external_id"]` lookup
- TableMonitor assignment only when needed (skip if `game_id` already
  correct)

### `ExternalTournament::RoundResultAggregator` (Plan 15-04 + 15-06)

- **Read-only** aggregator (no DB writes, no transaction needed)
- Filter: `tournament.games.where(round_no: N)` ordered by `seqno`
- `innings_played` = `max(participants.innings)` — nachstoß-tolerant
- `gd` fallback: DB value or computed from `points/innings` (3 decimals)
- Also includes ongoing games (without `ended_at`)
- Emits `table_name` (15-06/D-15-06-D) in addition to `table_no`

### `ExternalTournament::PlayerReconciler` (Plan 17-06)

- Thin batch wrapper around `PlayerMatcher` — `call(participants:)` → one result per entry
- Returns `dbu_nr` (as string) + canonical player + club; **no auto-create**
- `ref` is echoed back (the app's own correlation key)

### `ExternalTournament::ClubRosterQuery` (Plan 18-01)

Read-only discovery substrate: `clubs(region)` + `players(region:, club:, season:)`.
Eligibility strictly `status="active"` of the current season; region-scoped club lookup via
`cc_id` (intra-region unique). `dbu_nr` passed through as a string (nullable). Creates no
players/guests.

### `ExternalTournament::AppTournamentCleaner` (Plan 16-01)

- `cleanup(tournament)` → deletes the marker games (`tournament_external_id`, coarse SQL `LIKE` +
  exact marker match) + the tournament; returns
  `{games_deleted:, tournament_deleted:}`. No-op + idempotent for non-local/managed/already-deleted
  tournaments.
- `sweep_closed_local` → midnight GC: cleans up all completed local app tournaments.
- Criterion `id >= MIN_ID` + `manual_assignment` (identical to `TableReleaser`); managed/global
  stays untouched.

## Related decisions

| Decision | Scope |
|----------|-------|
| D-15-01-A | Authority model = service account, same pattern as G.14 |
| D-15-02-A | Mapping decisions (synonyms newline split + balls_goal→target_points etc.) |
| D-15-02-B | Service-account email = `2band-{region}-bridge@carambus.de` |
| D-15-03-A | Table identification via `Table.name == table_no.to_s` (**superseded by D-15-06-A**) |
| D-15-04-A | Round result: empty round → `200 OK` with `results: []` |
| D-15-04-B | Ongoing games (`ended_at: nil`) are included in round result |
| D-15-04-C | `innings_played` = max(participant.innings) (nachstoß-tolerant) |
| D-15-04-D | `gd` taken from DB if present, else computed from `points/innings` |
| D-15-04-E | Player serialization: cc_id/firstname/lastname (dbu_nr omitted) |
| D-15-04-F | `round_no` query param is required (422 if missing/non-numeric) |
| D-15-06-A | Table identification via `table_name` (fallback `table_no`); supersedes D-15-03-A |
| D-15-06-B | Location resolution: payload.location.id → cc_id → tournament.location_id |
| D-15-06-C | TableMonitor lazy-create via `table_monitor || table_monitor!` |
| D-15-06-D | `table_name` persisted in `Game.data` + emitted in round result |
| D-15-06-E | seeding `tournament.location` as `{id, cc_id, name}` object (was a string) |
| D-15-07-A | `location_cc_id` resolution region-scoped (`region_id` filter); cc_id only intra-region unique |
| D-17-06-A | CSV enumeration via durable marker `game.data["tournament_external_id"]` (no `tournament_id` FK) — **csv_export removed in 16-02**; marker pattern lives on in `AppTournamentCleaner` |
| D-17-06-B | CSV result source = `game.data["ba_results"]` (manual_assignment ⇒ GP columns empty) — **csv_export removed in 16-02** |
| D-17-06-C | Player reconcile reuses `PlayerMatcher` without auto-create (CC entry list stays the MCP track) |
| D-17-06-D | ~~CSV delivery as `GET text/csv` (app pull) + dbu_nr columns per player~~ — **removed in 16-02** (csv_export obsolete, D-16-GC-A: the app keeps its own result memory) |
| D-18-01-A | club_players eligibility strictly `SeasonParticipation status="active"` of `Season.current_season`; `status` included per player (temporary/guest/nil excluded) |
| D-18-01-B | clubs = `region.clubs` with `cc_id` (the key for club_players), stably sorted |
| D-18-01-C | club_players supports single (`club_cc_id`→`club:{}`) and multi (`club_cc_ids`→`clubs:[]`) |
| D-18-01-D | `dbu_nr` nullable (as String), region scope via club (cc_id only intra-region unique) |
| D-18-02-A | start_game rule flags (allow_follow_up etc.) default from the tournament; explicit app values (incl. false) honored — bridge-scoped in StartGameProcessor, no change to GameSetup |
| D-18-02-B | rule params live per game (start_game) with tournament fallback (no app change needed) |
| D-16-GC-A | Carambus cleans up app tournament data (no memory needed); delete marker games + tournament, local app tournaments only; csv_export thereby obsolete (follow-up removal) |
| D-16-01-A | `end_tournament` teardown is opt-in via `cleanup` flag (default off, data-critical + backward-compat); midnight GC as the guaranteed safety net |

See `.paul/STATE.md` for full decision records.

## Tests

```bash
cd carambus_master
bin/rails test \
  test/controllers/api/external_tournaments_controller_test.rb \
  test/services/external_tournament/
```

## Spec source (external)

JSON schema documentation:
`/Users/gullrich/2BandTurnier/docs/json-schema.md` — external,
maintained on the app side. For schema changes, run a plan loop to sync
(Plan 15-04+).

## Manager/User docs

A user-facing guide ("How do I integrate my tournament app with
Carambus?") will be added after the empirical verify in Plan 15-05 — only
then is the pilot story (BC Wedel 3-cushion 2026 season) solid enough to
document.
