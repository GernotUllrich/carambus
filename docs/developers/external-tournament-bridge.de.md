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
| Carambus → App | `GET /api/external_tournament/club_players` | In der laufenden Saison spielberechtigte Spieler eines Clubs (cc_id + dbu_nr); optional player_class-Filter | ✅ v0.5 (Plan 18-01) + v0.6 (Plan 20-03 player_class) |
| Carambus → App | `GET /api/external_tournament/player_rankings` | Disziplin-Ranking-Setzliste (Vorsaison) | ✅ v0.6 (Plan 19-01) |
| Carambus → App | `GET /api/external_tournament/disciplines` | Region-relevante Disziplinen + Format-/Klassen-Matrix (TournamentPlans) | ✅ v0.6 (Plan 20-01) |
| Carambus → App | `GET /api/external_tournament/categories` | Kategorie-/Klassen-Listen (player_classes + age_classes + genders + categories[]) für den Selektor | ✅ v0.6 (Plan 20-02) |

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
rake service_accounts:create_carambus_app[BCW]
# → legt carambus-app-bcw-bridge@carambus.local an, gibt Password einmalig aus

# Alternative: Per-Region Cloud (Multi-Location-Turnier)
cd /path/to/carambus_master   # global oder per-region wie nbv
rake service_accounts:create_carambus_app[NBV]
# → legt carambus-app-nbv-bridge@carambus.de an
```

Bearer-Token holen — Base-URL je nach Topologie:

```bash
# Local Scenario via WLAN
curl -X POST http://carambus.local:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"carambus-app-bcw-bridge@carambus.local","password":"…"}}' \
  -i | grep -i Authorization
# Authorization: Bearer eyJhbGciOiJIUzI1NiJ9…

# Per-Region Cloud (Beispiel NBV)
curl -X POST https://nbv.carambus.de/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"carambus-app-nbv-bridge@carambus.de","password":"…"}}' \
  -i | grep -i Authorization
```

JWT-Lifetime: **90 Tage** (Long-Lived; via D-14-G7 +
`Carambus.config.jwt_expiration_days`) — App-seitig kein Renew-Friction
über die Turniersaison hinweg.

### CORS für die externe SPA (Plan 19-01 / v0.6 F2)

Die App ist eine SPA, die über einen statischen Webserver (anderer Origin, z. B. `…:8123`)
ausgeliefert wird → ohne CORS blockt der Browser `/login` + `/api/external_tournament/*`.
`config/initializers/cors.rb` (`rack-cors`) erlaubt das **eng begrenzt**:

- Nur die Ressourcen `/api/external_tournament/*` (GET/POST/OPTIONS) + `/login` (POST/OPTIONS) —
  NICHT die ganze App.
- **`expose: ["Authorization"]`** ist Pflicht: die App liest den JWT nach `POST /login` aus dem
  `Authorization`-Response-Header (cross-origin sonst unsichtbar → Login scheitert „still").
- Default erlaubte Origins = LAN (`localhost`/`127.0.0.1`/`192.168.x`/`10.x`/`172.16–31.x`, optional
  `:port`); pro Szenario via ENV **`EXTERNAL_APP_CORS_ORIGINS`** (Komma-Liste) übersteuerbar.
- Bearer-Auth → keine Cookies, daher KEIN `credentials: true`. Fremd-Origins werden nicht erlaubt.

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
    { "cc_id": 4567, "firstname": "Oliver", "lastname": "Weese", "dbu_nr": "12345",
      "status": "active", "age_class": "Senioren 45-99", "gender": "M" }
  ]
}
```

Felder `age_class` (String oder `null`) und `gender` (`"M"`/`"F"`/`"U"` oder `null`) sind
ab Plan 21-07 verfügbar — befüllt durch den `PlayerAgeClassGenderHeuristic`-Service aus
Plan 21-04 (heuristisch abgeleitet aus `category_ccs.min_age`/`sex` der 2 abgeschlossenen
Vorsaisons-seedings). Schema-Vertrag rückwärts-kompatibel.

#### age_class- und gender-Filter (Plan 21-07)

Optionale Server-Filter (gilt für beide Modi, single + `club_cc_ids`):

```
GET .../club_players?region=NBV&club_cc_id=11&age_class=Senioren+45-99&gender=M
```

- **`age_class`** (optional, freier `CategoryCc.name`-String): exakter Match auf
  `player.age_class`. Tippfehler → leeres Array (kein 422, D-21-07-E — Statuswerte sind
  freie Kategorie-Namen ohne festes Enum).
- **`gender`** (optional, enum `M`/`F`/`U`): exakter Match auf `player.gender`.
  Ungültiger Wert → **422** (D-21-07-C — kanonische Menge aus `CategoryCc::SEX_MAP`).
- **Quelle:** persistierte Player-Spalten aus Plan 21-04 (heuristisch befüllt für NBV,
  Coverage Production ~93% gender / ~33% age_class; Spieler ohne qualifizierte seedings
  haben `null` und entfallen beim Filter).
- **Kombinierbar:** `age_class=...&gender=M` → UND-Verknüpfung (D-21-07-B + D-21-07-C).
- Hebt **D-v0.6-AGECLASS / D-20-03-E** auf (Defer aus Plan 20-03).

#### player_class-Filter (Plan 20-03 / F5)

Optionale Vorfilterung nach **Leistungsklasse** (gilt für beide Modi, single + `club_cc_ids`):

```
GET .../club_players?region=NBV&club_cc_id=11&discipline=Dreiband+klein&player_class=Landesliga
```

- **`discipline`** (optional): wenn gesetzt, bekommt jeder Spieler ein zusätzliches Feld
  `player_class` (Shortname der Leistungsklasse in dieser Disziplin, `null` falls kein Ranking).
- **`player_class`** (optional, erfordert `discipline`): filtert auf Spieler mit der angegebenen
  Klasse **oder besser** (siehe D-21-01-D unten). Spieler ohne passendes Ranking entfallen.
  Unbekannter `player_class`-Wert → `422`.
- **Quelle (D-20-03-A + Plan 21-01 T2):** `PlayerRanking.player_class_id` → `PlayerClass.shortname`,
  region+disziplin-scoped. Der `PlayerClassCalculator` (Phase 21) befüllt `player_class_id` aus
  `max(btg)` der zwei abgeschlossenen Vorsaisons → `Discipline::DISCIPLINE_CLASS_LIMITS` →
  `Discipline#class_from_val` (STO-BTK §1.4.1).
- **Saison (D-20-03-B):** Klassen-Saison = **Vorsaison** (wie `player_rankings`/D-19-01-SEASON);
  die **Eligibility**-Saison (`status="active"`) bleibt `current_season` (unverändert, D-18-01-A).
- **Filter-Semantik (D-21-01-D, ersetzt D-20-03-D):** `player_class=X` liefert Spieler mit
  Klasse `X` **ODER BESSER** via `Discipline::PLAYER_CLASS_ORDER` (worst→best: `7,6,…,1,I,II,III`).
  Hintergrund: STO-Praxis erlaubt Einsatz von Spielern aus tieferen Klassen (Einspringen in der
  Reihenfolge der Rangliste), die App soll diese sehen können. Pool/Snooker liefern `player_class:null`
  (keine STO-Klassifikation hinterlegt).
- **Behavior-preserving:** ohne `discipline`/`player_class` ist die Antwort unverändert (kein
  `player_class`-Feld).
- **AUFGEHOBEN (D-v0.6-AGECLASS / D-20-03-E):** `age_class` + `gender` sind ab Plan 21-07
  als Payload-Felder und als Server-Filter verfügbar — siehe Abschnitt oben.

Erweitertes `players[]`-Beispiel (mit `discipline`):
```json
{ "cc_id": 4567, "firstname": "Oliver", "lastname": "Weese", "dbu_nr": "12345",
  "status": "active", "player_class": "Landesliga" }
```

### Fehler-Codes

| Code | Bedeutung |
|------|-----------|
| `401` | Kein/ungültiger Bearer-Token |
| `404` | Region unbekannt ODER `club_cc_id` nicht in der Region ODER `discipline` angegeben aber nicht auflösbar |
| `422` | `club_cc_id` fehlt (und kein `club_cc_ids`) ODER `player_class` ohne `discipline` ODER `player_class`-Wert nicht in `PLAYER_CLASS_ORDER` (D-21-01-D) ODER `gender`-Wert nicht in `M`/`F`/`U` (D-21-07-C) |

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

## Endpoint 7: Player-Rankings (Plan 19-01 / v0.6)

```
GET /api/external_tournament/player_rankings?region=NBV&discipline=Dreiband+klein
    optional: &player_cc_ids=11683,10024   (Filter; ohne → ganze Rangliste)
    optional: &season=2024/2025            (Default: Vorsaison)
```

Liefert die **nach offiziellem Ranking sortierte Spielerliste** einer Disziplin (bestes Ranking =
Setzplatz 1) — Quelle für die App-Setzliste (z. B. Doppel-KO). Read-only, region-scoped, devise-jwt.

Response (`200`, Schema `carambus.player_rankings/v1`):

```json
{
  "schema": "carambus.player_rankings/v1",
  "region": { "shortname": "NBV" },
  "season": { "name": "2024/2025" },
  "discipline": { "name": "Dreiband klein" },
  "players": [
    { "cc_id": 11683, "firstname": "Georg", "lastname": "Nachtmann", "dbu_nr": "…",
      "rank": 1, "gd": 20.69, "hs": 12, "balls": 600, "innings": 29,
      "age_class": "Senioren 45-99", "gender": "M" }
  ],
  "unranked": ["190204"]
}
```

Felder `age_class` (String oder `null`) und `gender` (`"M"`/`"F"`/`"U"` oder `null`) sind
ab Plan 21-07 im Payload verfügbar (aus den persistierten Player-Spalten von Plan 21-04).
**KEIN Server-Filter** (D-21-07-D — Ranking ist disziplin-zentriert; die App filtert
client-side falls gewünscht). Schema-Vertrag rückwärts-kompatibel.

- **Sortierung:** `rank` aufsteigend, bei Gleichstand `gd` absteigend; je `cc_id` wird das beste
  (kleinste) `rank` dedupliziert.
- **Disziplin-Auflösung:** exakter `name`, sonst Synonym-Treffer (`Discipline#synonyms` ist
  newline-separiert und enthält den Namen selbst).
- **Saison (D-19-01-SEASON):** ohne `season`-Param IMMER die **Vorsaison** (die Saison vor
  `Season.current_season`) — die Rankings der laufenden Saison sind noch nicht final. Explizites
  `season` übersteuert. Vgl. „Championship-Rankings aus Vorsaison".
- **`player_cc_ids`** (optional): nur diese Spieler; angeforderte cc_ids ohne Ranking → `unranked[]`.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | Region oder Disziplin nicht gefunden |
| 422 | `discipline`-Param fehlt |

## Endpoint 8: Disciplines-Discovery (Plan 20-01 / v0.6)

```
GET /api/external_tournament/disciplines?region=NBV
```

Liefert die in der Region **relevanten offiziellen Disziplinen** als Substrat für den
Disziplin-Selektor des Turnier-Managers — exakte Namen, die 1:1 in `player_rankings` (F1) und
`start_game` matchen, plus die offizielle **Format-/Klassen-/Ziel-Matrix** (`DisciplineTournamentPlan`)
für schnelles Batch-Anlegen vieler paralleler Turniere. Read-only, region-scoped, devise-jwt.

Response (`200`, Schema `carambus.disciplines/v1`):

```json
{
  "schema": "carambus.disciplines/v1",
  "region": { "shortname": "NBV" },
  "tournament_plans": {
    "Default8": {
      "players": 8, "tables": 2, "ngroups": 1, "nrepeats": 1,
      "rulesystem": "…", "executor_class": "…", "executor_params": "…",
      "more_description": "…", "even_more_description": "…"
    }
  },
  "disciplines": [
    {
      "name": "Dreiband klein",
      "synonyms": ["3-Band klein"],
      "table_kind": "Small Billard",
      "super_discipline": "Dreiband",
      "player_classes": ["2", "1"],
      "parameters": [
        { "tournament_plan": "Default8", "players": 8, "player_class": "1", "points": 40, "innings": 20 },
        { "tournament_plan": "Default8", "players": 8, "player_class": "2", "points": 30, "innings": 20 }
      ]
    }
  ]
}
```

- **Region-Relevanz (D-20-01-A):** gelistet werden nur Disziplinen mit `PlayerRanking`s **oder**
  `Tournament`s in der Region. Disziplinen sind global (kein `region_id`); der Selektor zeigt aber
  nur regional Genutztes. Die Matrix einer gelisteten Disziplin wird global vollständig geliefert.
- **Normalisiert (D-20-01-D):** Plan-Strukturen stehen einmalig im Top-Level-Dict
  `tournament_plans` (Key = Plan-Name); jede `parameters`-Zeile referenziert ihren Plan per Name —
  keine Duplikate über Disziplinen hinweg.
- **Plan-Felder inkl. Executor (D-20-01-E):** `players, tables, ngroups, nrepeats, rulesystem,
  executor_class, executor_params, more_description, even_more_description`. Text-Felder werden
  **roh** als gespeicherter String durchgereicht (kein Parsen — die App interpretiert selbst).
- **player_classes (D-20-01-B):** Shortnames, sortiert nach `Discipline::PLAYER_CLASS_ORDER`
  (worst→best, z. B. `7,6,…,1,I,II,III`).
- **table_kind (D-20-01-C):** nur als Feld geliefert (Gruppierung/Filter macht die App;
  kein Server-Filter-Param in v1).
- **synonyms:** ohne den Namen selbst (D-15-02; `Discipline#synonyms` ist newline-separiert und
  enthält den Namen).

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | Region nicht gefunden |

## Endpoint 9: Categories-Discovery (Plan 20-02 / v0.6)

```
GET /api/external_tournament/categories?region=NBV&discipline=Dreiband+klein
```

Liefert die **Kategorie-/Klassen-Listen** als Substrat für den Kategorie-/Klassen-Selektor der
Turnier-Anlage (F4): `player_classes` (Leistungsklassen), `age_classes` + `genders` (aus
`category_ccs`) sowie ein reiches `categories[]`-Array. Read-only, region-scoped, devise-jwt.
Der `discipline`-Param ist **optional** (D-20-02-B).

Response (`200`, Schema `carambus.categories/v1`):

```json
{
  "schema": "carambus.categories/v1",
  "region": { "shortname": "NBV" },
  "season": { "name": "2025/2026" },
  "player_classes": ["2", "1"],
  "age_classes": ["Damen", "Herren", "Senioren"],
  "genders": ["M", "F"],
  "categories": [
    { "name": "Damen", "sex": "F", "min_age": 0, "max_age": 99, "status": "Freigegeben" },
    { "name": "Herren", "sex": "M", "min_age": 0, "max_age": 99, "status": "Freigegeben" },
    { "name": "Senioren", "sex": "M", "min_age": 50, "max_age": 99, "status": "Freigegeben" }
  ]
}
```

- **player_classes (D-20-02-A):** aus `discipline.player_classes` (dieselbe Quelle wie `disciplines`
  F3), sortiert nach `Discipline::PLAYER_CLASS_ORDER` (worst→best). **Nur mit** `discipline`-Param;
  ohne Disziplin ist `player_classes` leer (Leistungsklassen sind inhärent disziplin-gebunden).
- **discipline optional (D-20-02-B):** mit → Listen disziplin-skopiert (über
  `branch_ccs.discipline_id`); ohne → region-weite Kategorie-Listen über alle Sparten.
- **Region-/Disziplin-Scope (D-20-02-C):** `category_ccs` über `context = shortname.downcase`
  (Region) und `branch_ccs.discipline_id` (Sparte).
- **Disziplin-Scope-Mechanik (D-21-02-A, 2026-05-26, Plan 21-02):** `BranchCc.discipline_id` ist
  FK auf die Branch-**Wurzel** (STI `Branch < Discipline`), nicht auf die feine Disziplin. Der
  Query mappt deshalb jede übergebene Disziplin per `discipline.root` auf ihre Branch-Wurzel,
  bevor sie gegen `branch_ccs.discipline_id` joint. Vor dem Fix lieferte ein Aufruf mit feiner
  Disziplin (z. B. „Dreiband klein") für NBV **0** Kategorien; danach **7** (Live-verifiziert
  :3008/NBV 2026-05-26). Supersedes D-20-02-C-Detail — der Scope-Charakter (Region+Sparte) bleibt;
  korrigiert ist nur die Join-Mechanik. Quelle: `.paul/phases/21-clubcloud-admin-scraping/21-02-PLAN.md`.
- **Payload (D-20-02-D):** flache Convenience-Listen (`player_classes`/`age_classes`/`genders`)
  **plus** reiches `categories[]` (`{name, sex, min_age, max_age, status}`). **Kein** Status-Filter
  in v1 — `status` wird als Feld mitgeliefert, die App filtert selbst.
- **age_classes:** die rohen `CategoryCc`-Namen (z. B. „Damen"/„Senioren") — eine semantische
  Trennung Alter ↔ Geschlecht ist heuristisch und in **Phase 21** (Admin-Scraping) verortet.
- **genders (D-20-02-E):** `CategoryCc::SEX_MAP`-Keys — `M` (männlich) / `F` (weiblich) /
  `U` (unisex), geordnet `M, F, U`.
- **season (D-20-02-E):** `Season.current_season` (informativ; die Eligibilitäts-Saison nutzt die
  App später für die per-Spieler-Zuordnung).
- **DEFERRED (D-v0.6-AGECLASS → Phase 21):** die **per-Spieler** age_class/gender-Zuordnung und
  der entsprechende `club_players`-Filter sind NICHT Teil von F4 (`players` hat kein
  Geburtsjahr/Geschlecht). F4 liefert nur die LISTEN.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | Region nicht gefunden **oder** `discipline` angegeben, aber nicht auflösbar |

## Endpoint 10: Registration-Lists-Discovery (Plan 21-05 / v0.6)

### `GET /api/external_tournament/registration_lists?region=NBV`

**Optionale Query-Parameter:** `season` (z. B. `2025/2026`), `discipline` (z. B. `Dreiband klein`),
`category` (z. B. `Herren`), `status` (z. B. `Freigegeben`).

Read-only Discovery der **ClubCloud-Meldelisten** einer Region: `deadline` /
`qualifying_date` / `status` plus die zugeordnete `discipline` und `category_cc`. Wenn die
Meldeliste über `link_and_push_if_match` (Plan 14-G.14) mit einem `TournamentCc` verknüpft ist,
liefert die Response zusätzlich ein `tournament_cc`-Sub-Objekt (Bulk-Reverse-Lookup, **kein N+1**).

> ⚠️ **Datenstand-Warnung:** Der `RegistrationSyncer` läuft heute **nicht** via Cron
> (`config/schedule.rb` — ClubCloud-Block auskommentiert, D-21-DISC-C). Default-Calls mit
> `season=current_season` liefern in der Praxis ein **leeres** `registration_lists`-Array, weil
> der letzte Syncer-Lauf historisch ist. **Workaround:** historische Saison explizit per
> `?season=2022/2023` anfragen, bis Slice E den Cron re-aktiviert. Die Endpoint-Mechanik selbst
> ist davon unabhängig und vollständig getestet.

```bash
# Standard-Call (Default: current_season; aktuell leer wg. Cron-Defer)
curl -H "Authorization: Bearer <jwt>" \
  "https://carambus.de/api/external_tournament/registration_lists?region=NBV"

# Historische Saison + Disziplin-Filter (Substanz-Test):
curl -H "Authorization: Bearer <jwt>" \
  "https://carambus.de/api/external_tournament/registration_lists?region=NBV&season=2022/2023&discipline=Dreiband+klein&status=Freigegeben"
```

**Response (200, `carambus.registration_lists/v1`):**

```json
{
  "schema": "carambus.registration_lists/v1",
  "region": { "shortname": "NBV" },
  "season": { "name": "2022/2023" },
  "registration_lists": [
    {
      "cc_id": 12345,
      "name": "NDM Dreiband klein 2022/23",
      "deadline": "2022-12-01T00:00:00+01:00",
      "qualifying_date": "2022-11-01T00:00:00+01:00",
      "status": "Freigegeben",
      "season": "2022/2023",
      "discipline": { "id": 33, "name": "Dreiband klein" },
      "category_cc":  { "id":  9, "name": "Unisex jeden Alters" },
      "tournament_cc": {
        "id": 50001234,
        "name": "NDM Dreiband klein 2022/23",
        "date": "2023-01-15T00:00:00+01:00"
      }
    }
  ]
}
```

### Entscheidungen (Plan 21-05, 2026-05-26)

- **D-21-05-A (eigene Bridge-Resource, NICHT in `categories` embedded):** Endpoint 10 als
  eigenständige Resource. Folgt der passiven Read-Schicht-Konvention aus 21-01/02/03/04
  (D-21-03-DISC-E / D-21-04-DISC-F-Pattern fortgesetzt).
- **D-21-05-B (Default-Saison = `Season.current_season`):** explizites unauflösbares
  `season` → 404 (NICHT silently auf current_season fallen).
- **D-21-05-C (NBV-Pilot):** Live-Verify nur gegen NBV; Endpoint funktioniert technisch für
  jede Region (sobald `RegistrationListCc.context=<shortname>` Daten enthält).
- **D-21-05-D (tournament_cc-Verknüpfung als optionaler Sub-Hash):** Reverse-Lookup
  `TournamentCc.registration_list_cc_id` mit Bulk-`index_by` → ein Query, kein N+1. Bei
  Doppel-Verknüpfung (unwahrscheinlich): deterministisch erste via `order(:id)`. Bei keiner
  Verknüpfung: `tournament_cc: null`.
- **D-21-05-E (`status`-Filter optional + exakter Match):** Tippfehler im Param-Wert →
  leeres Array, **kein** 422 / Fuzzy / ILIKE.
- **D-21-05-F (Status-Hardcoded-Bug DEFERRED):** Der Syncer-Bug in
  `app/services/region_cc/registration_syncer.rb:107` (hardcoded `status: "Freigegeben"`
  überschreibt den geparsten Status auf Zeile 98) wird in 21-05 **NICHT** gefixt — gehört zu
  Slice E (Cron-Re-Enable + Bug-Fix gemeinsam). Endpoint spiegelt was in der DB steht.

### Fehler-Codes

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | Region nicht gefunden **oder** `season`/`discipline`/`category` angegeben, aber nicht auflösbar |

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

Read-only Discovery-Substrat: `clubs(region)` + `players(region:, club:, season:, discipline:,
player_class:, ranking_season:)`. Eligibility strikt `status="active"` der laufenden Saison;
region-scoped Club-Lookup über `cc_id` (regional eindeutig). `dbu_nr` als String durchgereicht
(nullable). Legt keine Player/Gäste an. **Plan 20-03 (F5):** optionaler player_class-Filter +
per-Spieler `player_class`-Feld via `PlayerRanking.player_class_id` (Batch, kein N+1); ohne
`discipline` byte-identische Rückgabe (behavior-preserving).

### `ExternalTournament::AppTournamentCleaner` (Plan 16-01)

- `cleanup(tournament)` → löscht die Marker-Games (`tournament_external_id`, coarse SQL-`LIKE` +
  exakter Marker-Abgleich) + das Turnier; Rückgabe
  `{games_deleted:, tournament_deleted:}`. No-op + idempotent für nicht-lokale/managed/bereits
  gelöschte Turniere.
- `sweep_closed_local` → Mitternachts-GC: räumt alle abgeschlossenen lokalen App-Turniere ab.
- Kriterium `id >= MIN_ID` + `manual_assignment` (identisch zu `TableReleaser`); managed/global
  bleibt unberührt.

### `ExternalTournament::RankingQuery` (Plan 19-01)

- `players(region:, discipline_name:, player_cc_ids:, season_name:)` → `Result{season, discipline,
  ranked[], unranked[]}` (oder `nil`, wenn die Disziplin nicht auflösbar ist → Controller 404).
- Disziplin-Auflösung exakter `name` → sonst Synonym (`Discipline#synonyms`); Sortierung `rank`↑/`gd`↓;
  dedupe je `cc_id` auf bestes `rank`.
- **Saison = Vorsaison** (`previous_season` aus `Season.current_season`-Namen; D-19-01-SEASON);
  explizites `season_name` übersteuert. Read-only.

### `ExternalTournament::DisciplineQuery` (Plan 20-01)

- `call(region:)` → `Result{disciplines[], tournament_plans{}}`. Read-only, region-scoped.
- Region-relevante Disziplinen = mit `PlayerRanking` ODER `Tournament` der Region (D-20-01-A);
  pro Disziplin synonyms (ohne Namen), `table_kind`, `super_discipline`, `player_classes`
  (`PLAYER_CLASS_ORDER`) + `parameters[]` aus `DisciplineTournamentPlan`.
- `tournament_plans` = normalisiertes Dict (Key = Plan-Name) aller referenzierten `TournamentPlan`s
  mit vollen Feldern inkl. Executor (Text roh durchgereicht).

### `ExternalTournament::CategoryQuery` (Plan 20-02)

- `call(region:, discipline_name:)` → `Result{season, player_classes[], age_classes[], genders[],
  categories[], discipline_resolved}`. Read-only, region-scoped.
- `player_classes` aus `discipline.player_classes` (D-20-02-A, `PLAYER_CLASS_ORDER`); nur mit
  Disziplin, sonst `[]`. Disziplin-Auflösung wiederverwendet `RankingQuery.find_disciplines`
  (exakt → Synonym); unauflösbar ⇒ `discipline_resolved=false` (Controller 404, D-20-02-B).
- `category_ccs` region-scoped via `context` + disziplin-scoped via `branch_ccs.discipline_id`
  (D-20-02-C); `age_classes` = distinct Namen, `genders` = distinct `sex` (`M/F/U`, D-20-02-E),
  `categories[]` = `{name, sex, min_age, max_age, status}` (kein Status-Filter, D-20-02-D).

## Verwandte Decisions

| Decision | Wirkbereich |
|----------|-------------|
| D-15-01-A | Authority-Modell = Service-Account analog G.14 |
| D-15-02-A | Mapping-Decisions (synonyms-newline-split + balls_goal→target_points etc.) |
| D-15-02-B | Service-Account-Email = `carambus-app-{region}-bridge@carambus.de` |
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
| D-19-01-SEASON | player_rankings nimmt die Rankings IMMER aus der Vorsaison (Default; laufende Saison noch nicht final); explizites `season` übersteuert. Korrigiert die Handoff-Ref-Impl („jüngste Saison mit Rankings") |
| D-20-01-A | disciplines region-relevant: nur Disziplinen mit PlayerRankings ODER Tournaments in der Region (Disziplinen sind global, kein region_id) |
| D-20-01-B | disciplines liefert player_classes inline pro Disziplin (Shortnames, sortiert nach PLAYER_CLASS_ORDER) |
| D-20-01-C | disciplines: table_kind nur als Feld (kein Server-Filter-Param in v1) |
| D-20-01-D | disciplines normalisiert: Top-Level tournament_plans-Dict (Key=Name) + per-Disziplin parameters[] (Plan per Name referenziert) |
| D-20-01-E | disciplines liefert volle TournamentPlan-Felder inkl. Executor; Text-Felder (rulesystem/executor_params/Beschreibungen) roh durchgereicht |
| D-20-02-A | categories player_classes-Quelle = `discipline.player_classes` (wie 20-01, `PLAYER_CLASS_ORDER`); keine PlayerRanking/Saison; ohne Disziplin leer |
| D-20-02-B | categories `discipline`-Param optional (mit → disziplin-skopiert; ohne → region-weit); vorhandener aber unauflösbarer Name → 404 |
| D-20-02-C | categories `category_ccs`-Region-Scope via `context=shortname.downcase`, Disziplin-Scope via `branch_ccs.discipline_id` |
| D-20-02-D | categories Payload = flache Listen (player_classes/age_classes/genders) + reiches `categories[]` ({name,sex,min_age,max_age,status}); kein Status-Filter in v1 |
| D-20-02-E | categories `season=current_season` (informativ); `genders` als SEX_MAP-Keys (M/F/U); per-Spieler age_class/gender DEFERRED (D-v0.6-AGECLASS → Phase 21) |
| D-20-03-A | club_players player_class-Quelle = `PlayerRanking.player_class_id` → `PlayerClass.shortname` (Hauptspalte, nicht p_/pp_/tournament_player_class_id) |
| D-20-03-B | club_players Klassen-Saison = Vorsaison (wie player_rankings/D-19-01-SEASON); Eligibility-Saison bleibt `current_season` (D-18-01-A unverändert) |
| D-20-03-C | club_players `player_class`-Filter erfordert `discipline` (sonst 422); `discipline` unauflösbar → 404; ohne Params unverändert (behavior-preserving) |
| D-20-03-D | ~~club_players player_class-Filter `==` exakt X~~ **SUPERSEDED durch D-21-01-D** (Filter = "X ODER BESSER"). Behavior-preserving (Feld = null bei kein Ranking) bleibt. |
| D-21-01-D | club_players player_class-Filter = "X **ODER BESSER**" via `Discipline::PLAYER_CLASS_ORDER` (worst→best). STO-Praxis erlaubt Einsatz tieferer Klassen (Einspringen in Rangliste-Reihenfolge). Unbekannter `player_class`-Wert → 422. |
| D-21-01-A..F | `PlayerClassCalculator` (Plan 21-01 T2): berechnet `PlayerRanking.player_class_id` aus `max(btg)` der 2 abgeschlossenen Vorsaisons → `Discipline::DISCIPLINE_CLASS_LIMITS` (STO-BTK §1.4.1) → `class_from_val`. Pool/Snooker → `nil`. Persistenz auf jüngerer Vorsaison. Echtzeit-Hochspielen/Kipp-Spieler nicht abgebildet (API-Vereinfachung). |
| D-20-03-E | club_players age_class/gender-Filter/-Felder DEFERRED (D-v0.6-AGECLASS → Phase 21); solche Params werden ignoriert (kein Fehler) |
| D-21-02-A | categories Disziplin-Scope joint gegen `discipline.root.id` (Branch-Wurzel, STI), nicht gegen die feine Disziplin. Vor Fix `?discipline=Dreiband klein` für NBV: 0 Kategorien; nach Fix: 7 (Live-verifiziert :3008/NBV). Supersedes D-20-02-C-Detail (Scope-Charakter bleibt). |
| D-21-07-A | Endpoints 6 (club_players) + 7 (player_rankings) liefern `age_class` (String) + `gender` (`M`/`F`/`U`) als zusätzliche Player-Felder im Payload (aus den in Plan 21-04 persistierten Spalten). Schema-Vertrag rückwärts-kompatibel; hebt D-21-04-DISC-F-Defer auf. |
| D-21-07-B | club_players `age_class`-Filter optional, exakter Match auf freien `CategoryCc.name`-String. Tippfehler ergibt leeres Array (kein 422 / Fuzzy / ILIKE). Hebt D-20-03-E-Defer auf (war: Params werden ignoriert). |
| D-21-07-C | club_players `gender`-Filter optional, enum-validated `M`/`F`/`U`. Ungültiger Wert → 422. Kanonische Menge aus `CategoryCc::SEX_MAP`. |
| D-21-07-D | player_rankings KEIN Server-Filter für age_class/gender (Ranking ist disziplin-zentriert; App filtert client-side aus dem Payload falls gewünscht). |
| D-21-07-E | Sentinel-Filter `?age_class=null` (für "Spieler ohne Wert") DEFERRED; falls die App das braucht, eigener späterer Slice. |

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
