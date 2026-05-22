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
| App ↔ Carambus | `POST tournament` / `lock_table` / `start_game` / `acknowledge_result` / `end_tournament` | App-getriebener Lokal-Turnier-Lebenszyklus (Anlage, Tisch-Bindung, Warmup-Start, Result-Hold/Pull, Turnierende) | ✅ v0.5 (Plan 17-02..17-05) |
| App → Carambus | `POST /api/external_tournament/player_reconcile` | Teilnehmer gegen Carambus-lokal matchen → dbu_nr-Rückgabe | ✅ v0.5 (Plan 17-06) |
| Carambus → App | `GET /api/external_tournament/clubs` | Clubs der Region (Picker) | ✅ v0.5 (Plan 18-01) |
| Carambus → App | `GET /api/external_tournament/club_players` | In der laufenden Saison spielberechtigte Spieler eines Clubs (cc_id + dbu_nr) | ✅ v0.5 (Plan 18-01) |

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
**D-15-07-A:** Der `cc_id`-Zweig ist **region-scoped** (`region_id`-Filter) — `cc_id`
ist nur intra-region eindeutig (z.B. 3 Locations mit `cc_id=11` in verschiedenen
Regionen). `location.id` (PK) ist global eindeutig und braucht keinen Region-Filter.

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

## Endpoint 4: Player-Reconcile (Plan 17-06)

```
POST /api/external_tournament/player_reconcile
```

Matcht die App-Teilnehmerliste **gegen Carambus-lokal** (D-17-vision-2) und liefert pro
Eintrag die **dbu_nr** + den kanonischen Carambus-Datensatz. Wiederverwendung von
`ExternalTournament::PlayerMatcher` (region+cc_id → dbu_nr → name+club). **Legt keine Player an**
(kein Auto-Create) — nicht-matchbare Einträge → `matched: false`, `player: null`.

Body:

```json
{
  "region": { "shortname": "NBV" },
  "participants": [
    { "ref": "t1p1", "cc_id": 9001, "dbu_nr": "12001", "firstname": "Dick", "lastname": "Jaspers", "club_cc_id": 11 },
    { "ref": "t1p2", "firstname": "Unbekannt", "lastname": "Spieler" }
  ]
}
```

Response (`200`, Schema `carambus.player_reconcile/v1`):

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

`ref` wird unverändert zurückgespiegelt (App-eigener Zuordnungsschlüssel). `dbu_nr` als String.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | Region nicht gefunden |
| 422 | `participants` fehlt oder ist kein nicht-leeres Array |

## Endpoint 6: Club/Player-Discovery (Plan 18-01)

Zwei read-only, region-scoped Endpoints für die App-seitige Spielerzuordnung. Der Operator
wählt die beteiligten Clubs und ordnet pro App-Spielerslot einen offiziellen, in der
laufenden Saison **spielberechtigten** Spieler (mit `cc_id` + `dbu_nr`) zu → exaktes
`start_game`-Matching + korrekte dbu_nr in den App-Ergebnissen. Gast bleibt der Fallback. Rein
additiv — kein Eingriff in `start_game`/`round_start` (die App sendet `cc_id`/`dbu_nr`
bereits über `cleanPlayerRef`, sobald gesetzt).

### `GET /api/external_tournament/clubs?region=NBV`

Clubs der Region (mit `cc_id`) für den Club-Picker. `cc_id` ist der Schlüssel für
`club_players`.

Response (`200`, Schema `carambus.clubs/v1`):

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

In der laufenden Saison **spielberechtigte** Spieler des Clubs. Eligibility strikt
`SeasonParticipation status="active"` der `Season.current_season` (temporary/guest/nil
ausgeschlossen; das `status`-Feld wird pro Spieler mitgeliefert). `dbu_nr` ist CSV-relevant
und kann fehlen (`null`). Region-Scope: `cc_id` ist nur intra-region eindeutig.

Mehrere Clubs in einem Call: `?region=NBV&club_cc_ids=11,12` → Antwort als
`clubs:[{ club, players }]` statt einzelnem `club`.

Response (`200`, Schema `carambus.club_players/v1`):

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

### Fehler-Codes

| Code | Bedeutung |
|------|-----------|
| `401` | Kein/ungültiger Bearer-Token |
| `404` | Region unbekannt ODER `club_cc_id` nicht in der Region (region-scoped) |
| `422` | `club_cc_id` fehlt (und kein `club_cc_ids` angegeben) |

## Spielregel-Parameter beim `start_game` (Plan 18-02)

`start_game` akzeptiert pro Spiel optionale Spielregel-Flags und wendet sie auf das Spiel an:

| Flag | Wirkung | Default (wenn weggelassen) |
|------|---------|----------------------------|
| `allow_follow_up` | Nachstoß / Aufnahmegleichheit (Remis möglich) | Tournament-Wert (Standard **TRUE** → Nachstoß an) |
| `color_remains_with_set` | Farbe bleibt über den Satz | Tournament-Wert (Standard TRUE) |
| `kickoff_switches_with` | Anstoßwechsel (`"set"` …) | Tournament-Wert bzw. `"set"` |
| `allow_overflow` | Überlauf über das Ziel hinaus | `false` |

**Ort = pro Spiel (`start_game`)** mit Tournament-Default als Fallback (D-18-02-B): ein
weggelassenes Flag erbt den Tournament-Wert (statt auf „aus" gezwungen zu werden), ein explizit
gesendeter Wert (auch `false`) wird geehrt (D-18-02-A). Für den 3-Band-Mannschaftskampf ist
Nachstoß damit standardmäßig aktiv. (Der Fix ist bridge-scoped in `StartGameProcessor`; das
geteilte `GameSetup` bleibt unverändert.)

## Teardown & Garbage-Collection (Plan 16-01)

**Carambus hält kein Gedächtnis der App-Turnierdaten.** Die App führt ihr eigenes
Ergebnis-Gedächtnis (über `acknowledge_result` live abgeholt), daher darf Carambus ein
abgeschlossenes lokales App-Turnier samt Spielen wieder abräumen (D-16-GC-A). Der frühere
`csv_export`-Endpoint wurde damit obsolet und in 16-02 entfernt.

Was gelöscht wird: die **Marker-Games** (`game.data["tournament_external_id"]`) inklusive ihrer
`GameParticipation`s (kaskadiert via `dependent: :destroy`) **und das Turnier selbst**
(`tournament.destroy` kaskadiert `TournamentMonitor`/`tournament_local`/`seedings`/`teams`/
`setting`). App-Spiele tragen **keinen** `tournament_id`-FK, darum werden sie separat über den
Marker enumeriert (kein Cascade über das Turnier). Es werden **ausschließlich lokale App-Turniere**
abgeräumt (`id >= MIN_ID` + `manual_assignment`); managed/globale Turniere und fremde Games bleiben
unberührt.

Zwei Auslöser (D-16-GC-A, Option D):

1. **`end_tournament` mit `cleanup: true`** (opt-in, Default off — D-16-01-A): Nach dem Tisch-Release
   wird das Turnier + seine Marker-Games gelöscht. Die Response meldet zusätzlich
   `tournament_deleted` + `games_deleted`. **Ohne** das Flag bleibt das bisherige Verhalten
   (nur Release, kein Löschen) erhalten — das Löschen ist datenkritisch und daher bewusst opt-in.

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

2. **Mitternachts-GC** (`rake external_tournament:release_stale_local_tables`, via whenever): Das
   garantierte Safety-Net. Nach dem Stale-Release (das hängende App-Turniere zuerst schließt) werden
   alle **abgeschlossenen** lokalen App-Turniere (TournamentMonitor `closed` oder fehlend) samt
   Marker-Games gelöscht. Aktive (Monitor nicht closed) sowie managed/globale Turniere bleiben
   unberührt. Idempotent.

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

### `ExternalTournament::PlayerReconciler` (Plan 17-06)

- Dünner Batch-Wrapper um `PlayerMatcher` — `call(participants:)` → ein Result je Eintrag
- Liefert `dbu_nr` (als String) + kanonischen Player + Club; **kein Auto-Create**
- `ref` wird zurückgespiegelt (App-eigener Zuordnungsschlüssel)

### `ExternalTournament::ClubRosterQuery` (Plan 18-01)

Read-only Discovery-Substrat: `clubs(region)` + `players(region:, club:, season:)`.
Eligibility strikt `status="active"` der laufenden Saison; region-scoped Club-Lookup über
`cc_id` (regional eindeutig). `dbu_nr` als String durchgereicht (nullable). Legt keine
Player/Gäste an.

### `ExternalTournament::AppTournamentCleaner` (Plan 16-01)

- `cleanup(tournament)` → löscht die Marker-Games (`tournament_external_id`, coarse SQL-`LIKE` +
  exakter Marker-Abgleich) + das Turnier; Rückgabe
  `{games_deleted:, tournament_deleted:}`. No-op + idempotent für nicht-lokale/managed/bereits
  gelöschte Turniere.
- `sweep_closed_local` → Mitternachts-GC: räumt alle abgeschlossenen lokalen App-Turniere ab.
- Kriterium `id >= MIN_ID` + `manual_assignment` (identisch zu `TableReleaser`); managed/global
  bleibt unberührt.

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
| D-15-07-A | `location_cc_id`-Auflösung region-scoped (`region_id`-Filter); cc_id nur intra-region eindeutig |
| D-17-06-A | CSV-Enumerierung über durablen Marker `game.data["tournament_external_id"]` (kein `tournament_id`-FK) — **csv_export entfernt in 16-02**; Marker-Pattern lebt in `AppTournamentCleaner` weiter |
| D-17-06-B | CSV-Ergebnisquelle = `game.data["ba_results"]` (manual_assignment ⇒ GP-Spalten leer) — **csv_export entfernt in 16-02** |
| D-17-06-C | Player-Reconcile wiederverwendet `PlayerMatcher` ohne Auto-Create (CC-Meldeliste bleibt MCP-Strang) |
| D-17-06-D | ~~CSV-Auslieferung als `GET text/csv` (App-Pull) + dbu_nr-Spalten je Spieler~~ — **entfernt in 16-02** (csv_export obsolet, D-16-GC-A: App hält eigenes Ergebnis-Gedächtnis) |
| D-18-01-A | club_players-Eligibility strikt `SeasonParticipation status="active"` der `Season.current_season`; `status` pro Spieler mitgeliefert (temporary/guest/nil aus) |
| D-18-01-B | clubs = `region.clubs` mit `cc_id` (Schlüssel für club_players), stabil sortiert |
| D-18-01-C | club_players unterstützt Einzel (`club_cc_id`→`club:{}`) und Mehrfach (`club_cc_ids`→`clubs:[]`) |
| D-18-01-D | `dbu_nr` nullable (als String), Region-Scope via Club (cc_id nur regional eindeutig) |
| D-18-02-A | start_game-Regel-Flags (allow_follow_up etc.) defaulten aus dem Tournament; explizite App-Werte (auch false) geehrt — bridge-scoped in StartGameProcessor, kein Eingriff in GameSetup |
| D-18-02-B | Regel-Params leben pro Spiel (start_game) mit Tournament-Fallback (keine App-Änderung nötig) |
| D-16-GC-A | Carambus räumt App-Turnierdaten ab (kein Gedächtnis nötig); Marker-Games + Turnier löschen, nur lokale App-Turniere; csv_export dadurch obsolet (Follow-up-Entfernung) |
| D-16-01-A | `end_tournament`-Teardown ist opt-in via `cleanup`-Flag (Default off, datenkritisch + backward-compat); Mitternachts-GC als garantiertes Safety-Net |

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
