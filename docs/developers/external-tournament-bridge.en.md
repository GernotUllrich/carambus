# External Tournament Bridge

> **Status:** v0.5 (In Progress) — Pilot: 3BandMannschaftsTurnier app for BC Wedel
> 3-cushion team championship

## What is the Bridge?

Carambus opens itself up to external tournament apps. An external app (e.g.,
the 3BandMannschaftsTurnier app for 3-cushion team tournaments) runs the tournament and
exchanges the following data with Carambus over REST:

| Direction | Endpoint | Purpose | Status |
|-----------|----------|---------|--------|
| Carambus → App | `GET /api/external_tournament/seeding` | Seeding list with players/teams | ✅ v0.5 (Plan 15-02) |
| App → Carambus | `POST /api/external_tournament/round_start` | Table pairings → Game creation + scoreboard activation | ✅ v0.5 (Plan 15-03) |
| Carambus → App | `GET /api/external_tournament/round_result` | Game results to import into the app | 🚧 v0.5 (Plan 15-04, planned) |

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

## Endpoint 1: Seeding (Plan 15-02)

```
GET /api/external_tournament/seeding?tournament_cc_id=12345&region=NBV
Authorization: Bearer …
```

Response: `carambus.seeding/v1`-compliant JSON document with `tournament`,
`teams[]`, `players[]`.

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

Response (`201 Created` or `200 OK` on idempotent replay):

```json
{
  "games": [
    { "external_id": "ms3b-2026-r1-tisch5-pos1", "game_id": 123, "table_monitor_id": 45 },
    { "external_id": "ms3b-2026-r1-tisch6-pos1", "game_id": 124, "table_monitor_id": 46 }
  ]
}
```

### Convention D-15-03-A: Table identification

```
3BandMannschaftsTurnier table_no=5   ⟶   Carambus Table.name == "5"
```

Lookup path (service `RoundStartProcessor`):

```ruby
Table
  .where(location_id: tournament.location_id)
  .find_by(name: table_no.to_s)
# → Table.table_monitor yields the associated TableMonitor
```

Alternative conventions (e.g., `"Tisch 5"`, per-region mapping) are
currently **not** supported — deferred to v0.6 if needed.

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

## Endpoint 3: Round Result (Plan 15-04, planned)

```
GET /api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=NBV
```

Spec follows in Plan 15-04. Aggregates `GameParticipation` records of one
round into an app-compatible result document (`carambus.round_result/v1`).

## Service layer

### `ExternalTournament::PlayerMatcher` (Plan 15-02)

Three-path fallback lookup:

1. **`region+cc_id`** — `Player.cc_id` is NOT globally unique, hence
   region-scoped
2. **`dbu_nr`** — cross-region; DBU membership is nationally unique
3. **`firstname+lastname`** (optional `club_cc_id` for disambiguation)

Returns `Player` or `nil` — **no auto-create**. The Sportwart creates
unknown players manually in the CC UI.

### `ExternalTournament::RoundStartProcessor` (Plan 15-03)

- Transactional (DB rollback on any error)
- Custom errors: `PlayerResolutionError`, `TableMonitorNotFoundError`
  (controller rescues to 422)
- Idempotency via `Game.data["external_id"]` lookup
- TableMonitor assignment only when needed (skip if `game_id` already
  correct)

## Related decisions

| Decision | Scope |
|----------|-------|
| D-15-01-A | Authority model = service account, same pattern as G.14 |
| D-15-02-A | Mapping decisions (synonyms newline split + balls_goal→target_points etc.) |
| D-15-02-B | Service-account email = `2band-{region}-bridge@carambus.de` |
| D-15-03-A | Table identification via `Table.name == table_no.to_s` |

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
