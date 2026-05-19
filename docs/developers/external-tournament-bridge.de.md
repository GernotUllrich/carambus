# External-Tournament-Bridge

> **Status:** v0.5 (In Progress) — Pilot: 3BandMannschaftsTurnier-App für BC Wedel
> 3-Band-Mannschaftsmeisterschaft

## Was ist die Bridge?

Carambus öffnet sich für externe Turnier-Apps. Eine externe App (z.B. die
3BandMannschaftsTurnier-App für 3-Band-Mannschaftsturniere) führt das Turnier durch und
tauscht mit Carambus über REST folgende Daten aus:

| Richtung | Endpoint | Zweck | Status |
|----------|----------|-------|--------|
| Carambus → App | `GET /api/external_tournament/seeding` | Setzliste mit Players/Teams | ✅ v0.5 (Plan 15-02) |
| App → Carambus | `POST /api/external_tournament/round_start` | Tisch-Paarungen → Game-Creation + Scoreboard-Aktivierung | ✅ v0.5 (Plan 15-03) |
| Carambus → App | `GET /api/external_tournament/round_result` | Game-Ergebnisse zur Übernahme | 🚧 v0.5 (Plan 15-04, geplant) |

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

## Endpoint 1: Seeding (Plan 15-02)

```
GET /api/external_tournament/seeding?tournament_cc_id=12345&region=NBV
Authorization: Bearer …
```

Response: `carambus.seeding/v1`-konformes JSON-Dokument mit `tournament`,
`teams[]`, `players[]`.

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

Response (`201 Created` oder `200 OK` bei Idempotenz):

```json
{
  "games": [
    { "external_id": "ms3b-2026-r1-tisch5-pos1", "game_id": 123, "table_monitor_id": 45 },
    { "external_id": "ms3b-2026-r1-tisch6-pos1", "game_id": 124, "table_monitor_id": 46 }
  ]
}
```

### Convention D-15-03-A: Tisch-Identifikation

```
3BandMannschaftsTurnier table_no=5   ⟶   Carambus Table.name == "5"
```

Lookup-Pfad (Service `RoundStartProcessor`):

```ruby
Table
  .where(location_id: tournament.location_id)
  .find_by(name: table_no.to_s)
# → Table.table_monitor liefert die zugehörige TableMonitor
```

Alternative Conventions (z.B. `"Tisch 5"`, Per-Region-Mapping) sind aktuell
**nicht** unterstützt — Defer für v0.6 falls Bedarf.

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

## Endpoint 3: Round-Result (Plan 15-04, geplant)

```
GET /api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=NBV
```

Spec folgt in Plan 15-04. Aggregiert `GameParticipation` einer Runde zu
App-konformem Result-Doc (`carambus.round_result/v1`).

## Service-Layer

### `ExternalTournament::PlayerMatcher` (Plan 15-02)

3-Path-Fallback-Lookup:

1. **`region+cc_id`** — `Player.cc_id` ist NICHT global unique, daher
   region-scoped
2. **`dbu_nr`** — cross-region; DBU-Mitgliedschaft ist national eindeutig
3. **`firstname+lastname`** (optional + `club_cc_id` als Disambiguation)

Liefert `Player` oder `nil` — **kein Auto-Create**. Sportwart legt
unbekannte Player manuell in der CC-UI an.

### `ExternalTournament::RoundStartProcessor` (Plan 15-03)

- Transaktional (DB-Rollback bei jedem Fehler)
- Custom-Errors: `PlayerResolutionError`, `TableMonitorNotFoundError`
  (Controller rescued auf 422)
- Idempotenz via `Game.data["external_id"]`-Lookup
- TableMonitor-Assignment nur wenn nötig (skip wenn `game_id` bereits
  korrekt)

## Verwandte Decisions

| Decision | Wirkbereich |
|----------|-------------|
| D-15-01-A | Authority-Modell = Service-Account analog G.14 |
| D-15-02-A | Mapping-Decisions (synonyms-newline-split + balls_goal→target_points etc.) |
| D-15-02-B | Service-Account-Email = `2band-{region}-bridge@carambus.de` |
| D-15-03-A | Tisch-Identifikation via `Table.name == table_no.to_s` |

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
