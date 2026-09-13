# JSON-Schnittstelle zwischen externer Turnier-App und Carambus

Dieses Dokument beschreibt die JSON-Verträge, mit denen externe Turnier-Apps
(z. B. `3band-turnier` / `carambus-sp`) mit einer lokalen
**Carambus**-Instanz Daten austauschen — typischerweise bei Veranstaltungen,
bei denen Carambus' eingebautes Turnier-Management nicht greift.

**Zielgruppe**: Implementierer beider Seiten (App + Carambus).

**Status**: v1, **in Carambus Phase 15 (v0.5) implementiert**. Drei Endpoints
live unter `/api/external_tournament/*`. Diskrepanzen zwischen dieser
Spec und der tatsächlichen Carambus-Implementierung sind im Repo unter
`HANDOFF-from-carambus-phase15.md` Abschnitt 4 dokumentiert (z. B.
Player-Auto-Create als v0.6-Defer).

**Update 15-06 (2026-05-20):** Tisch-Identifikation überarbeitet — Tisch-Namen
sind beliebige Strings (`"Tisch 5"`), nicht Nummern. Neu: `carambus.tables/v1`
Discovery-Endpoint (Abschnitt 1b), `location`-Block + `table_name` im
`round_start`, `tournament.location` als Objekt im `seeding`. Details:
`HANDOFF-from-carambus-15-06-tables-DONE.md`.

**Update Phase 17 (2026-05-20):** Carambus bietet jetzt einen vollständigen
**App-gesteuerten Turnier-Lebenszyklus** über 7 weitere Endpoints (5–11, siehe
unten): `tournament`, `lock_table`, `start_game`, `acknowledge_result`,
`end_tournament`, `player_reconcile`, `csv_export`. Die App wird Orchestrator;
`start_game` ersetzt `round_start` im aktiven Spielbetrieb (löst Spielbereitschaft
+ Tisch-Freigabe/R4). Entscheidung der App-Seite (2026-05-21): **voll auf Phase 17
umstellen**, Umsetzung nach Production-Deploy `:3131`. Region-Scope-Bug aus dem
15-06-Live-Test ist Carambus-seitig gefixt (Plan 15-07, Commit `ce3d81bb`).
Details: `HANDOFF-from-carambus-phase17.md`.

---

## Designprinzipien

1. **Versioniert**: Jedes Dokument trägt ein `schema`-Feld der Form
   `"carambus.<doc>/v1"`. Breaking Changes erfordern v2.
2. **Erweiterbar**: Unbekannte Felder werden vom Empfänger **ignoriert** statt
   abgelehnt. Neue optionale Felder dürfen jederzeit ergänzt werden.
3. **Region als Top-Level-Kontext**: Sämtliche `cc_id`-Werte (Player, Club,
   Tournament) sind nur **innerhalb einer Region** eindeutig
   (ClubCloud-Architektur, z. B. NBV, BLVN, BVNRW …). Die Region steht
   einmalig auf der Top-Ebene jedes Dokuments.
4. **Carambus ist Source-of-Truth** für offizielle Namen und IDs. Wenn die
   App Schreibfehler einreicht, kann Carambus eine korrigierte Setzliste
   zurückspielen.
5. **Flache Spiel-Struktur**: Auch im Mannschafts-Turnier ist jedes Tisch-Spiel
   ein eigenständiges `game`-Objekt. Mannschaftskontext steckt in
   `participants[].team_name` und `team_position`. Das hält das Schema
   verwendbar für Einzel-, Doppel-, Mannschafts- und Mischformate.
6. **Disziplin/Format generisch**: `format` deckt Karambol-Distanz
   (`target_points` + `max_innings`), Pool/Snooker-Sätze (`sets`) und
   Snooker-Frames (`frames`) ab. Nicht zutreffende Felder = `null`.
7. **`external_id` für Round-Trip**: Die App vergibt pro Spiel eine eigene
   Kennung, die Carambus in der Antwort unverändert zurückspielt. Damit
   funktioniert die Zuordnung auch ohne dauerhafte Carambus-IDs.

---

## ⚠ Vertrag: das `external_id`-Format im Attach-Modus

> **`attach-<tournament_id>-<key>`** — dieses Format **nicht ändern**, ohne es mit
> Carambus abzustimmen.

Im Attach-Modus (`schemes/plan/`) ist die `external_id` **die einzige verlässliche
Klammer zwischen App-Turnier und Carambus-Spiel**. Der Grund liegt auf der
Carambus-Seite (bestätigt in `HANDOFF-from-carambus-round-result-restore.md`,
23.08.2026):

- Am Tisch gespielte Games entstehen über `GameSetup#create_new_game` und tragen
  **kein** `tournament_id`/`tournament_type` — bewusst, weil ein FK dort
  Polymorphie, Unique-Index und `acts_as_list` hereinziehen würde. Über
  `tournament.games` sind sie deshalb **nicht** auffindbar.
- `game.data["tournament_external_id"]` wird **nicht zuverlässig gefüllt** (stand in
  allen geprüften Datensätzen auf `nil`).

Carambus' `round_result`-Aggregator sucht deshalb zusätzlich über das Präfix
`attach-<tournament_id>-` und führt Marker- und Tisch-Games zusammen. Ändert die App
das Format, verliert Carambus die Spiele — ohne Fehlermeldung, sie sind dann schlicht
nicht mehr da.

Erzeugt wird die Kennung in `schemes/plan/index.html`; der Slug entsteht aus dem
Plan-Key (`group1_2_5` etc., nicht-alphanumerische Zeichen zu `_`).

**Nicht verwechseln:** App-generierte Turniere (nicht Attach) nutzen weiterhin
`app-<INSTANCE_ID>` als Turnier-Kennung — ein anderer, davon unabhängiger Pfad.

---

## Übersicht: Vier Dokumente

| Dokument | Richtung | Wann | Zweck |
|---|---|---|---|
| `carambus.seeding/v1` | Carambus → App | Vor Turnierbeginn | Setzliste mit Teams, Spielern, Vereinen, Tournament-Meta (inkl. `location`-Objekt) |
| `carambus.tables/v1` | Carambus → App | Bei Tisch-Konfiguration | Tische einer Location (`name`, `table_kind`, `has_monitor`) — App nutzt echte `Table#name`-Strings |
| `carambus.round_start/v1` | App → Carambus | Pro Runde, beim Spielstart | `location` + Tisch-Zuordnung (`table_name`) + Paarungen → Carambus erzeugt `Game` + `GameParticipation` und weist sie `TableMonitor`s zu |
| `carambus.round_result/v1` | Carambus → App | Nach Spielende der Runde | Ergebnisse pro Spiel (Bälle, Aufnahmen, HS) zur Übernahme in die App |

---

## 1. `carambus.seeding/v1` — Setzliste (Carambus → App)

### Beispiel

```json
{
  "schema": "carambus.seeding/v1",
  "region": {
    "shortname": "NBV",
    "url": "https://nbv.carambus.de"
  },
  "tournament": {
    "cc_id": 12345,
    "name": "3-Band Mannschaftsmeisterschaft NBV 2026",
    "discipline": {
      "name": "3-Band",
      "synonyms": ["3C", "Dreiband"]
    },
    "format": {
      "target_points": 30,
      "max_innings": 25,
      "sets": null,
      "frames": null
    },
    "starts_at": "2026-05-17T11:00:00+02:00",
    "location": "BC Wedel"
  },
  "teams": [
    {
      "seeding_position": 1,
      "name": "BC Wedel 1",
      "club": {
        "cc_id": 42,
        "shortname": "BC Wedel"
      },
      "players": [
        {
          "position_in_team": 1,
          "firstname": "Hans",
          "lastname": "Müller",
          "cc_id": 9876,
          "dbu_nr": "12345",
          "nationality": "DE"
        }
      ]
    }
  ]
}
```

### Feld-Übersicht

| Pfad | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `schema` | String | ja | Muss `"carambus.seeding/v1"` sein |
| `region.shortname` | String | ja | Z. B. `"NBV"`, `"BLVN"`. Kontext für alle `cc_id` |
| `region.url` | String | optional | Z. B. `"https://nbv.carambus.de"` |
| `tournament.cc_id` | Integer | optional | Wenn vorhanden, eindeutig innerhalb der Region |
| `tournament.name` | String | ja | Offizieller Turniername |
| `tournament.discipline.name` | String | ja | Z. B. `"3-Band"`, `"Cadre 47/2"`, `"Pool 9-Ball"` |
| `tournament.discipline.synonyms` | Array<String> | optional | Alternative Bezeichnungen für Lookup-Fallback |
| `tournament.format.target_points` | Integer\|null | optional | Punkte-Distanz (Karambol/Pool) |
| `tournament.format.max_innings` | Integer\|null | optional | Aufnahmen-Limit (Karambol) |
| `tournament.format.sets` | Integer\|null | optional | Best-of-Sätze (Pool) |
| `tournament.format.frames` | Integer\|null | optional | Frames (Snooker) |
| `tournament.starts_at` | ISO-8601 | optional | Turnierstart |
| `tournament.location` | String | optional | Spielort |
| `teams[]` | Array | ja | Liste der teilnehmenden Mannschaften |
| `teams[].seeding_position` | Integer | ja | Setzplatz, 1-basiert |
| `teams[].name` | String | ja | Mannschaftsname (z. B. `"BC Wedel 1"`) |
| `teams[].club.cc_id` | Integer | optional | Vereins-ID in der Region |
| `teams[].club.shortname` | String | ja | Vereins-Kurzname (z. B. `"BC Wedel"`) |
| `teams[].players[]` | Array | ja | Spielerliste in **verdeckter Reihenfolge** |
| `teams[].players[].position_in_team` | Integer | ja | Position 1..N innerhalb des Teams |
| `teams[].players[].firstname` | String | ja | Vorname |
| `teams[].players[].lastname` | String | ja | Nachname |
| `teams[].players[].cc_id` | Integer | optional | Spieler-ID in der Region (= Pass-Nr) |
| `teams[].players[].dbu_nr` | String | optional | DBU-Nummer (bundesweit) |
| `teams[].players[].umb_player_id` | Integer | optional | Internationale UMB-ID |
| `teams[].players[].nationality` | String (2) | optional | ISO-3166-1 alpha-2, z. B. `"DE"` |

### Carambus-Match-Logik (Carambus Phase 15 implementiert in `ExternalTournament::PlayerMatcher`)

Beim **Empfangen** dieses Dokuments:

```
1. region = Region.find_by!(shortname: doc.region.shortname)
2. tournament = Tournament.find_or_initialize_by(
     region_id: region.id, cc_id: doc.tournament.cc_id)
3. Für jeden Spieler (3-Path-Fallback, kein Auto-Create):
   a) primary:    Player.find_by(region_id: region.id, cc_id: player.cc_id)
   b) fallback:   Player.find_by(dbu_nr: player.dbu_nr)
   c) name+club:  Player.find_by(
                    region_id: region.id, firstname: ..., lastname: ...,
                    season_participations: { club_id: <club.id> })
   d) [v0.6-Defer] auto-create: Player.create!(..., source: 'external_app')
      → AKTUELL NICHT IMPLEMENTIERT. Carambus liefert stattdessen
        422 PlayerResolutionError mit details[]; die App muss die
        Spieler in der ClubCloud anlegen lassen und dann retryen.
```

Bei abweichender Schreibweise im Input liefert Carambus die **nächste**
Setzliste mit der offiziellen Schreibweise — die App überschreibt ihren
Stand beim erneuten Import.

**Hinweis `tournament.location`:** Seit Carambus 15-06 ist `location` ein
**Objekt** `{ id, cc_id, name }` (vorher ein bloßer String). Die App übernimmt
es als `state.location` und nutzt es für die `round_start`-Tischzuweisung. Wenn
`tournament.location_id` in Carambus nil ist, kommt `location: null` — dann setzt
die App die Location manuell (Tisch-Discovery, siehe Abschnitt 1b).

---

## 1b. `carambus.tables/v1` — Tische einer Location (Carambus → App)

Damit die App **echte** `Table#name`-Strings verwendet statt erratener Nummern.
Tisch-Namen sind beliebig (`"Tisch 5"`, `"Gr. Tisch 1"`, …), `table_kind` erlaubt
das Vorfiltern (z. B. Small Billard für Dreiband-klein).

### Request

```
GET /api/external_tournament/tables?location_id=1&region=NBV
GET /api/external_tournament/tables?location_cc_id=11&region=NBV   (Alternative; location_id hat Vorrang)
Authorization: Bearer …
```

### Response (200)

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

| Pfad | Typ | Beschreibung |
|---|---|---|
| `location.id` / `cc_id` / `name` | – | Aufgelöste Location |
| `tables[].name` | String | Exakter `Table#name` — genau diesen Wert als `table_name` im round_start senden |
| `tables[].table_kind` | String | z. B. `"Small Billard"`, `"Match Billard"`, `"Pool"` |
| `tables[].has_monitor` | Boolean | Nur Status-Hinweis. Fehlt ein Monitor, wird er beim round_start automatisch angelegt (`table.table_monitor!`) |

Fehler: `401` (JWT), `404 {"error":"Location not found"}`.

---

## 2. `carambus.round_start/v1` — Runden-Auslosung (App → Carambus)

Wird **pro Runde** (oder pro Teilrunde) erzeugt, sobald die App weiß, welche
Spieler an welchen Tischen gegeneinander antreten. Carambus erzeugt daraus
`Game`- und `GameParticipation`-Records und weist die Games den
`TableMonitor`s der angegebenen Tisch-Nummern zu.

### Beispiel (2 Begegnungen × 2 Spiele = 4 Tische, Teilrunde 1)

```json
{
  "schema": "carambus.round_start/v1",
  "region": { "shortname": "NBV" },
  "location": { "cc_id": 11 },
  "tournament": { "cc_id": 12345 },
  "round_no": 1,
  "round_name": "1. Runde, Teilrunde 1",
  "games": [
    {
      "external_id": "ms3b-2026-r1-t1-tisch5-pos1",
      "table_name": "Tisch 5",
      "table_no": 5,
      "discipline": { "name": "3-Band" },
      "format": { "target_points": 30, "max_innings": 25 },
      "context": {
        "round_no": 1,
        "round_name": "1. Runde, Teilrunde 1",
        "gname": "BC Wedel 1 vs BG Hamburg 2 — Pos. 1",
        "group_no": 1,
        "seqno": 1
      },
      "participants": [
        {
          "role": "playera",
          "team_name": "BC Wedel 1",
          "team_position": 1,
          "player": {
            "cc_id": 9876,
            "firstname": "Hans",
            "lastname": "Müller"
          }
        },
        {
          "role": "playerb",
          "team_name": "BG Hamburg 2",
          "team_position": 1,
          "player": {
            "cc_id": 5432,
            "firstname": "Peter",
            "lastname": "Schmidt"
          }
        }
      ]
    }
  ]
}
```

### Feld-Übersicht

| Pfad | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `schema` | String | ja | Muss `"carambus.round_start/v1"` sein |
| `region.shortname` | String | ja | Region-Kontext |
| `location.id` | Integer | optional | Carambus-Location-PK (Vorrang). Auflösung: `location.id → location.cc_id → tournament.location_id` |
| `location.cc_id` | Integer | optional | Location-cc_id (regional), falls keine `id` |
| `tournament.cc_id` | Integer | optional | Carambus-Tournament zum Zuordnen |
| `round_no` | Integer | ja | Runden-Nummer im Turnier |
| `round_name` | String | ja | Lesbarer Name (z. B. `"Runde 1, Teilrunde 1"`) |
| `games[]` | Array | ja | Liste der parallel zu startenden Spiele |
| `games[].external_id` | String | ja | App-eigene eindeutige ID. Wird in `round_result` zurückerwartet |
| `games[].table_name` | String | **bevorzugt** | Echter `Table#name` (z. B. `"Tisch 5"`). Hat Vorrang vor `table_no`. Existiert er nicht → 422 |
| `games[].table_no` | Integer | optional | Numerischer Fallback (Alt-Clients); nur genutzt, wenn `table_name` fehlt |
| `games[].discipline.name` | String | ja | Wie in Setzliste |
| `games[].format.*` | s.o. | ja | Distanz/Aufnahmen für DIESES Spiel |
| `games[].context.round_no` | Integer | ja | Runden-Nr (für `Game.round_no`) |
| `games[].context.round_name` | String | optional | Für Anzeige am Scoreboard |
| `games[].context.gname` | String | ja | Lesbarer Spielname (für `Game.gname`) |
| `games[].context.group_no` | Integer | optional | Gruppen-Nummer (für `Game.group_no`) |
| `games[].context.seqno` | Integer | optional | Spielreihenfolge im Turnier (für `Game.seqno`) |
| `games[].participants[]` | Array | ja | Genau 2 Einträge bei 1v1, mehr bei Mannschafts-Aggregation |
| `games[].participants[].role` | String | ja | `"playera"`/`"playerb"` (1v1) oder `"player1".."playerN"` (Team) |
| `games[].participants[].team_name` | String | optional | Mannschaftskontext (z. B. `"BC Wedel 1"`) |
| `games[].participants[].team_position` | Integer | optional | Position 1..N im Team |
| `games[].participants[].player.cc_id` | Integer | optional | Spieler-ID (wenn aus Carambus bekannt) |
| `games[].participants[].player.firstname` | String | ja | |
| `games[].participants[].player.lastname` | String | ja | |
| `games[].participants[].player.dbu_nr` | String | optional | |

### Carambus-Verhalten

```
1. Für jedes game in doc.games:
   a) Players matchen (gleiche Logik wie Setzliste)
   b) Game.create!(
        tournament_id, round_no, gname, group_no, seqno, table_no,
        data: { external_id, discipline, format })
   c) Für jeden participant: GameParticipation.create!(game_id, player_id, role)
   d) TableMonitor.where(table: { nnn: game.table_no }).first.update!(game_id: game.id)
2. Response: { "games": [ { external_id, game_id, table_monitor_id } ] }
```

---

## 3. `carambus.round_result/v1` — Ergebnisse (Carambus → App)

Wird von Carambus produziert, sobald alle Spiele einer Runde beendet sind
(oder auf Pull-Anfrage der App).

### Beispiel

```json
{
  "schema": "carambus.round_result/v1",
  "region": { "shortname": "NBV" },
  "tournament": { "cc_id": 12345 },
  "round_no": 1,
  "results": [
    {
      "external_id": "ms3b-2026-r1-t1-tisch5-pos1",
      "table_name": "Tisch 5",
      "table_no": 5,
      "started_at": "2026-05-17T11:05:00+02:00",
      "ended_at":   "2026-05-17T11:42:00+02:00",
      "innings_played": 22,
      "participants": [
        {
          "role": "playera",
          "player": { "cc_id": 9876, "firstname": "Hans", "lastname": "Müller" },
          "points": 30,
          "innings": 22,
          "high_series": 5,
          "gd": 1.364
        },
        {
          "role": "playerb",
          "player": { "cc_id": 5432, "firstname": "Peter", "lastname": "Schmidt" },
          "points": 24,
          "innings": 22,
          "high_series": 4,
          "gd": 1.091
        }
      ]
    }
  ]
}
```

### Feld-Übersicht

| Pfad | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `schema` | String | ja | Muss `"carambus.round_result/v1"` sein |
| `region.shortname` | String | ja | Region-Kontext |
| `tournament.cc_id` | Integer | optional | |
| `round_no` | Integer | ja | Runden-Nummer |
| `results[]` | Array | ja | Ein Eintrag pro abgeschlossenem Spiel |
| `results[].external_id` | String | ja | App-Identifier aus `round_start`, für Zuordnung |
| `results[].table_name` | String | optional | Echter Tischname (seit 15-06; für `table_name`-only-Games). Primärer Match bleibt `external_id` + `role` |
| `results[].table_no` | Integer\|null | optional | Numerischer Tisch (kann null sein, wenn nur `table_name` gesendet wurde) |
| `results[].started_at` | ISO-8601 | optional | Spielbeginn |
| `results[].ended_at` | ISO-8601 | optional | Spielende |
| `results[].innings_played` | Integer | optional | Tatsächlich gespielte Aufnahmen |
| `results[].participants[]` | Array | ja | Gleiche Rollen wie in `round_start` |
| `results[].participants[].role` | String | ja | `"playera"`/`"playerb"`/`"playerN"` |
| `results[].participants[].player.cc_id` | Integer | optional | Sekundär-ID zur Validierung |
| `results[].participants[].points` | Integer | ja | Erzielte Punkte/Bälle |
| `results[].participants[].innings` | Integer | ja | Gespielte Aufnahmen |
| `results[].participants[].high_series` | Integer | ja | Höchstserie |
| `results[].participants[].gd` | Float | optional | Generaldurchschnitt (points/innings). Wenn fehlt, errechnet die App selbst |
| `results[].participants[].sets` | Integer | optional | Pool/Snooker-Sätze |
| `results[].participants[].result` | Integer | optional | `2`/`1`/`0` für Sieg/Unentschieden/Niederlage (Matchpunkte) — wenn fehlt, leitet App aus `points` ab |

### App-Verhalten beim Empfang

```
1. Für jedes result in doc.results:
   a) Finde game per external_id im internen State
   b) Setze playerA.balls/innings/highSeries aus participants[role="playera"]
   c) Dito für playerB
   d) Tabelle aktualisiert sich automatisch
2. Validierung: warne (nicht blockieren), wenn:
   - external_id nicht in App bekannt
   - playerA.innings != playerB.innings (3-Band-Nachstoß)
   - participants.player.cc_id widerspricht App-Stand
```

---

## 4. `carambus.tournament_result/v1` — Ergebnisarchiv (App → Carambus)

Legt Endstand und Partien eines App-Turniers dauerhaft auf dem **lokalen** Server ab — in
derselben Form, in der Carambus gescrapte ClubCloud-Ergebnisse hält. Die App bleibt System of
Record; das hier ist die lesbare Kopie. Vollständiger Vertrag samt Klärungen:
[`HANDOFF-to-carambus-tournament-result-archive.md`](../HANDOFF-to-carambus-tournament-result-archive.md).

**Route:** `POST /api/external_tournament/tournament_result` · **idempotent** über
`(tournament_id, gname, seqno)` — bewusst nach jeder Runde aufrufen, nicht erst am Schluss.

```jsonc
{
  "region": "NBV",                    // ⚠ STRING, nicht {shortname:…} — s. u.
  "tournament_id": 50000057,          // oder "tournament": { "external_id": "app-…" }
  "scheme": "plan",                   // plan | doppelko | 3band-team
  "title": "Endstand",                // Name der Wertungsliste in der Anzeige
  "standings": [
    { "player": { "cc_id": 18522, "firstname": "Karina", "lastname": "Jetten" },
      "rank": 1,
      "columns": { "Rang": "1", "Name": "Jetten, Karina", "MP": "7", "GD": "0,747" } }
  ],
  "games": [
    { "gname": "group1:1-6", "seqno": 1, "round_no": 1, "table_no": 3,
      "ended_at": "2026-08-21T10:47:00+02:00",
      "columns": { "Partie": "1", "Spieler A": "…", "Ergebnis": "16:4", "Spieler B": "…" } }
  ]
}
```

**Response (200):** `{ schema, region, tournament, seedings_written, games_written,
players_unmatched[], archived, durable }`

- `archived` = geschrieben · `durable` = überlebt den nächtlichen GC. Den Text in der App an
  **`durable`** hängen, nicht an einer Server-Version — der Wert kommt aus
  `AppTournamentCleaner::ARCHIVE_AWARE` und kippt von allein.
- `players_unmatched` listet Spieler ohne Carambus-Zuordnung. **Ihre Zeilen stehen trotzdem im
  Endstand** — bei internationalen Feldern ohne `dbu_nr` ist das der Normalfall (Carambus
  41-01: `belongs_to :player` ist für lokale Seedings `optional`).

### ⚠ `region` ist hier ein String

Alle anderen Endpoints unter diesem Mount nehmen `region: { shortname: "NBV" }`. `tournament_result`
liest `params[:region].to_s.upcase` und quittiert die Hash-Form mit
`404 Couldn't find Region`. Die Frage, ob Carambus beide Formen akzeptiert, liegt bei Paul —
bis dahin gilt der String. `Carambus.api.pushTournamentResult` macht das bereits richtig.

### Vier Zwänge der Anzeige (drei schlagen still fehl)

`app/views/tournaments/show.html.erb` rendert generisch. Wer die `columns` selbst baut, muss das
einhalten — `Carambus.util.buildResultStandings/buildResultGames` erledigen es zentral:

| # | Regel | Was sonst passiert |
|---|---|---|
| 1 | Alle Zeilen brauchen **dieselben Keys in derselben Reihenfolge** | Spaltenköpfe kommen aus `.keys` des *ersten* Records → Spalten fehlen |
| 2 | Jede Spielzeile braucht `Ergebnis` (oder `Punkte`) | Zeile wird **kommentarlos übersprungen** |
| 3 | `Partie` ist eine Zahl | Sortierung über `data["Partie"].to_i` greift nicht |
| 4 | `Heim`/`Gast` nur setzen, wenn **gefüllt** | Leere Werte schneiden den Rest der Zeile ab (das `skip`-Flag wird nicht zurückgesetzt) |

`Rank` muss ein **Integer** sein — er steuert die Sortierung des Endstands. Und: Die Spalte, nach
der tatsächlich sortiert wird, gehört sichtbar in die Tabelle. Beim CEB-Turnier stand sonst ein
Platz 3 mit schlechterer GD über Platz 4, weil die Matchpunkte fehlten (ein Unentschieden).

### Was danach passiert

`data["archived_at"]` wird gesetzt; Plan 41-02 nimmt solche Turniere aus dem automatischen
Mitternachts-Sweep. **Nicht** ausgenommen ist `end_tournament?cleanup=true` — der Knopf „Turnier
abräumen" löscht das Archiv mit. Nach dem Turnier deshalb **Tische freigeben, nicht abräumen**.

---

## Erweiterbarkeit & Versionierung

### Wann eine neue Schema-Version (v2)?

- **Bestehendes Feld** ändert Bedeutung oder Typ → v2
- **Pflichtfeld** wird hinzugefügt → v2
- **Pflichtfeld** wird entfernt → v2

### Wann KEINE neue Version?

- **Neues optionales Feld** wird hinzugefügt → v1 bleibt
- **Neue Werte** in offenen Aufzählungen (z. B. weitere `role`-Werte
  wie `"player5"`/`"player6"` für 6er-Mannschaften) → v1 bleibt
- **Neue externe ID-Felder** am Player (z. B. `bvbw_nr`) → v1 bleibt

### Empfänger-Verhalten

- **Unbekannte Felder ignorieren** (nicht ablehnen).
- **Fehlende optionale Felder tolerieren** (Defaults oder Skip).
- **Schema-Mismatch** (z. B. `v2` empfangen, nur `v1` implementiert):
  Fehler mit klarem Hinweis, welche Version unterstützt wird.

---

## Beispiele für andere Disziplinen

### Pool 9-Ball (Best-of-9)

```json
{
  "discipline": { "name": "Pool 9-Ball", "synonyms": ["9-Ball"] },
  "format": {
    "target_points": null,
    "max_innings": null,
    "sets": 9,
    "frames": null
  }
}
```

### Snooker (Best-of-7-Frames)

```json
{
  "discipline": { "name": "Snooker" },
  "format": {
    "target_points": null,
    "max_innings": null,
    "sets": null,
    "frames": 7
  }
}
```

### Cadre 47/2 (200 in 25)

```json
{
  "discipline": { "name": "Cadre 47/2" },
  "format": {
    "target_points": 200,
    "max_innings": 25,
    "sets": null,
    "frames": null
  }
}
```

### 6er-Mannschaft

```json
{
  "participants": [
    { "role": "player1", "team_name": "Team A", "team_position": 1, "player": { ... } },
    { "role": "player2", "team_name": "Team A", "team_position": 2, "player": { ... } },
    { "role": "player3", "team_name": "Team A", "team_position": 3, "player": { ... } },
    { "role": "player4", "team_name": "Team B", "team_position": 1, "player": { ... } },
    { "role": "player5", "team_name": "Team B", "team_position": 2, "player": { ... } },
    { "role": "player6", "team_name": "Team B", "team_position": 3, "player": { ... } }
  ]
}
```

---

## Transport (Phase 1)

Datei-basiert: User exportiert/importiert JSON-Dateien manuell via
Browser-Download/Upload. Empfohlener Ablageort beider Seiten optional
in einem **gemeinsamen Ordner** (z. B. `~/billard-exchange/`), aber nicht
zwingend.

## Transport (Phase 3, implementiert)

Carambus stellt vier REST-Endpoints bereit (Stand Phase 15 + 15-06, 2026-05-20):

| # | Method | Pfad | Schema |
|---|--------|------|--------|
| 1 | `GET`  | `/api/external_tournament/seeding?tournament_cc_id=X&region=R` | `carambus.seeding/v1` |
| 2 | `GET`  | `/api/external_tournament/tables?location_id=X&region=R` (oder `location_cc_id=`) | `carambus.tables/v1` |
| 3 | `POST` | `/api/external_tournament/round_start` | `carambus.round_start/v1` |
| 4 | `GET`  | `/api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=R` | `carambus.round_result/v1` |

**Auth**: devise-JWT, 90 Tage Lifetime, Service-Account pro Scenario.

```
POST /login   { user: { email, password } }
→ Header "Authorization: Bearer eyJ…"   (Token im localStorage cachen)
```

Anschließend wird jeder Endpoint-Call mit `Authorization: Bearer <token>`
versehen. Die App speichert Bearer + Ablaufdatum in `localStorage` unter
`carambus.connection`.

**Idempotenz von Endpoint 2** (Round-Start):

- Carambus nutzt `Game.data["external_id"]` als Idempotenz-Key.
- Re-Send mit gleichem Payload liefert HTTP 200 (statt 201 bei Erstanlage)
  und legt keine Duplikate an.
- Die App muss daher **kein** „bereits gesendet"-Flag führen — Retry bei
  Netzwerkfehlern ist safe.

**Fehler-Codes** (vereinheitlicht über alle Endpoints):

| Status | Bedeutung | App-Verhalten |
|--------|-----------|---------------|
| 200 | Erfolg / idempotenter Re-Send / leere Runde | normal verarbeiten |
| 201 | Round-Start: mindestens 1 Game neu erstellt | normal verarbeiten |
| 401 | Fehlende/ungültige JWT | Settings-Modal öffnen, Re-Login anbieten |
| 404 | Tournament/Region nicht gefunden | Klartextfehler, Eingabe prüfen |
| 422 | Region-Mismatch · PlayerResolutionError · TableMonitorNotFoundError · `round_no` fehlt | Bei PlayerResolutionError dedicated UI mit `details[]` + Retry-Button |

**Endpoint-1-Spezifikum** — Setzliste:

- Polymorphic-Seeding: Carambus detektiert Tournament-Subklasse (Mannschaft
  vs. Einzel) und liefert entsprechend gruppiert. Das Schema bleibt
  `carambus.seeding/v1`-konform.

**Endpoint-3-Spezifikum** — Round-Result:

- Leere Runde (`results: []`) → HTTP **200**, nicht 404 — die App soll als
  „noch keine Ergebnisse" interpretieren, nicht als Fehler.
- Laufende Spiele (`ended_at: nil`) sind im Result enthalten — die App
  entscheidet, ob sie sie anzeigt oder verwirft.
- `innings_played = max(participant.innings)` (3-Band-Nachstoß-tolerant).
- `dbu_nr` wird im Player-Block **nicht** mitgeliefert — Matching primär
  per `external_id` + `role`.
- `round_no`-Query-Param ist **required** (kein Default auf 1).

**Tisch-Identifikation**: Carambus matched `table_no: 5` (Integer) gegen
`Table.name == "5"` (String) innerhalb der Tournament-Location. Die Tische
müssen daher die Namen `"5"`, `"6"`, `"7"`, `"8"` in Carambus tragen.

**Verifikations-Skript** für End-to-End-Smoke-Test (auf Carambus-Seite):

```bash
cd /path/to/carambus_master   # oder carambus_bcw
SERVICE_ACCOUNT_PASSWORD="…" rake external_tournament:smoke_test[BCW]
```

Vollständige Übergabe-Doku siehe `HANDOFF-from-carambus-phase15.md` im
Repo-Root.

---

# Phase 17: App-gesteuerter Turnier-Lebenszyklus (Endpoints 5–11)

**Stand 2026-05-20, Quelle: `HANDOFF-from-carambus-phase17.md`.** Carambus kann
einen vollständigen lokalen Turnier-Lebenszyklus rein über REST abbilden — die
**App ist der Orchestrator**, Carambus liefert Engine (Scoreboards/Score-Erfassung)
+ Datenhaltung. Kein Carambus-`TournamentPlan`/Executor nötig.

> **Verfügbarkeit:** code-complete + live-verifiziert gegen **Dev `:3008`**;
> noch **nicht** auf Production `:3131` (erst nach Merge feature→master + Deploy).
> Dev hat **kein CORS** → nur server-to-server/curl, keine Browser-App cross-origin.
> Quelle der Wahrheit Carambus-seitig: `docs/developers/external-tournament-bridge.{de,en}.md`.

| # | Method | Pfad | Schema | Zweck |
|---|--------|------|--------|-------|
| 5 | `POST` | `external_tournament/tournament` | `carambus.tournament/v1` | Lokal-Turnier anlegen (idempotent via `external_id`) |
| 6 | `POST` | `external_tournament/lock_table` | — | Tisch ans Turnier binden (TournamentMonitor-Bindung) |
| 7 | `POST` | `external_tournament/start_game` | — | Spiel pro Tisch starten (Warmup, per-Spieler-Disziplin, Game-Swap) |
| 8 | `POST` | `external_tournament/acknowledge_result` | `carambus.ack/v1` | Result-Hold + Pull → Tisch freigeben (R4) |
| 9 | `POST` | `external_tournament/end_tournament` | `carambus.tournament_end/v1` | Turnierende → alle Tische frei |
| 10 | `POST` | `external_tournament/player_reconcile` | `carambus.player_reconcile/v1` | Teilnehmer matchen → `dbu_nr` zurück |
| 11 | `GET`  | `external_tournament/csv_export` | `text/csv` | Ergebnis-CSV + dbu_nr-Crosscheck |
| 12 | `GET`  | `external_tournament/clubs?region=R` | `carambus.clubs/v1` | Clubs der Region (Club-Picker) |
| 13 | `GET`  | `external_tournament/club_players?region=R&club_cc_id=X` | `carambus.club_players/v1` | Saison-spielberechtigte Spieler je Club (mit `dbu_nr`) |

## Happy-Path-Lebenszyklus

```
1. POST tournament        → lokales Turnier (external_id = App-Turnier-ID)
2. POST lock_table (je Tisch) → Tische binden
   [optional] POST player_reconcile → dbu_nr je Teilnehmer vorab
3. pro Partie:
     POST start_game       → Spiel im Warmup am Tisch (spielbereit!)
     ... Schiri erfasst am Carambus-Scoreboard ...
     (TableMonitor HÄLT bei "Endergebnis erfasst" — Operator kann NICHT freigeben)
     POST acknowledge_result → App zieht Ergebnis + Tisch wird frei
4. GET csv_export         → Ergebnis-CSV (dbu_nr) für den Einpfleger
5. POST end_tournament    → alle Tische frei + TournamentMonitor geschlossen
```

Carambus-Sicherheitsnetze: Sysadmin-rake `external_tournament:end[id]` +
Mitternachts-Job (gibt über Nacht hängende App-Turnier-Tische frei).

## 5. `POST tournament` → `carambus.tournament/v1`

```jsonc
// Request
{ "region": {"shortname":"NBV"}, "external_id":"app-cup-2026-03",
  "title":"Lifecheck App Cup", "location": {"id":1} /* oder {"cc_id":11} */,
  "discipline": {"name":"3-Band"} /* optional */ }
// Response 201 (neu) / 200 (idempotent)
{ "schema":"carambus.tournament/v1", "region":{"shortname":"NBV"},
  "tournament": {"id":50000123, "external_id":"app-cup-2026-03",
                 "tournament_monitor_id":50000045, "title":"...", "location_id":1} }
```
Idempotent via `external_id` (2. POST → 200, dasselbe Turnier).

## 6. `POST lock_table`

```jsonc
// Request
{ "region":{"shortname":"NBV"}, "tournament":{"external_id":"app-cup-2026-03"},
  "table": {"id":5} /* oder {"name":"Tisch 5"} */, "lock": true /* false = entbinden */ }
// Response 200
{ "table_id":5, "in_tournament":true, "table_monitor_id":50000045 }
```
„Lock" bindet den Tisch-TableMonitor an den TournamentMonitor → erscheint im
Location-Scoreboard unter **Tournaments**, für freies Training gesperrt.
Konflikt (Tisch schon an anderes Turnier gebunden) → 422.

## 7. `POST start_game`

```jsonc
// Request — per-Spieler Disziplin + Ziel (für 3-Band-Mannschaft: gleiche Disziplin, balls_goal=30)
{ "region":{"shortname":"NBV"}, "tournament":{"external_id":"app-cup-2026-03"},
  "table":{"id":5}, "external_id":"g-r1-t5",
  "free_game_form":"karambol", "innings_goal":25, "sets_to_play":1, "sets_to_win":1,
  "participants":[
    {"role":"playera", "player":{"firstname":"Dick","lastname":"Jaspers","dbu_nr":"12001"}, "discipline":"3-Band", "balls_goal":30},
    {"role":"playerb", "player":{"firstname":"Myung Woo","lastname":"Cho"}, "discipline":"3-Band", "balls_goal":30}
  ] }
// Response 201 (neu) / 200 (idempotent)
{ "external_id":"g-r1-t5", "game_id":50000186, "table_monitor_id":50000045, "state":"warmup" }
```
Player-Matching wie Phase 15 (region+cc_id → dbu_nr → name+club). Spiel startet im
**Warmup** → spielbereit (löst den 15-06-Befund „nicht spielbereit"). Game-Swap:
erneutes `start_game` am selben Tisch sichert das laufende Spiel + hängt ein neues an.

## 8. `POST acknowledge_result` → `carambus.ack/v1` ⭐ (R4)

```jsonc
// Request — Ack PRO GAME
{ "region":{"shortname":"NBV"}, "tournament":{"external_id":"app-cup-2026-03"},
  "game":{"external_id":"g-r1-t5"} }
// Response 200
{ "schema":"carambus.ack/v1", "region":{"shortname":"NBV"},
  "tournament":{"id":50000123, "external_id":"app-cup-2026-03"},
  "game":{"id":50000186, "external_id":"g-r1-t5", "gname":"..."},
  "table":{"id":5, "name":"Tisch 5"},
  "state":"ready_for_new_match", "already_acknowledged":false,
  "acknowledged_at":"2026-05-20T12:30:00+02:00",
  "result": { "Ergebnis1":100, "Ergebnis2":60, "Aufnahmen1":5, "Aufnahmen2":5,
              "Höchstserie1":50, "Höchstserie2":30, "Sets1":1, "Sets2":0, "sets":[...] } }
```
- Solange die App nicht ackt, **hält** der TableMonitor bei `final_match_score`;
  der **Operator am Scoreboard kann den Tisch NICHT freigeben** (Guard).
- `acknowledge_result` setzt `result_acknowledged_at`, liefert das Ergebnis und
  gibt den Tisch frei.
- **Idempotent:** 2. Aufruf → `already_acknowledged:true`, dasselbe Ergebnis.
- Spiel noch nicht am Hold → **409** `{error, state}`.
- ⚠️ **Single-Set-Default** (Hold bei `final_match_score`). Multi-Set (Hold bei
  `final_set_score`) ist deferred — bei Bedarf bei Carambus melden.

## 9. `POST end_tournament` → `carambus.tournament_end/v1`

```jsonc
{ "region":{"shortname":"NBV"}, "tournament":{"external_id":"app-cup-2026-03"} }
// Response 200
{ "schema":"carambus.tournament_end/v1", "region":{"shortname":"NBV"},
  "tournament":{"id":50000123, "external_id":"app-cup-2026-03"},
  "released_tables":4, "unacknowledged":0, "tournament_monitor_state":"closed" }
```
Gibt **alle** gebundenen Tische frei (force — auch unbestätigte Holds) und schließt
den TournamentMonitor. Idempotent (2. Aufruf: `released_tables:0`).

## 10. `POST player_reconcile` → `carambus.player_reconcile/v1`

```jsonc
// Request — Batch; ref = euer Zuordnungsschlüssel (unverändert zurückgespiegelt)
{ "region":{"shortname":"NBV"},
  "participants":[
    {"ref":"t1p1","cc_id":9001,"dbu_nr":"12001","firstname":"Dick","lastname":"Jaspers","club_cc_id":11},
    {"ref":"t1p2","firstname":"Unbekannt","lastname":"Spieler"} ] }
// Response 200
{ "schema":"carambus.player_reconcile/v1", "region":{"shortname":"NBV"},
  "results":[
    {"ref":"t1p1","matched":true,
     "player":{"id":50000123,"cc_id":9001,"dbu_nr":"12001","firstname":"Dick","lastname":"Jaspers",
               "club":{"cc_id":11,"shortname":"BC Wedel"}}},
    {"ref":"t1p2","matched":false,"player":null} ] }
```
Match nur gegen Carambus-lokal (region+cc_id → dbu_nr → name+club). Gibt `dbu_nr`
zurück. **Legt keine Player an** — nicht-matchbar → `matched:false`.

## 11. `GET csv_export` → `text/csv`

```
GET /api/external_tournament/csv_export?region=NBV&tournament_id=<id>
GET /api/external_tournament/csv_export?region=NBV&tournament_external_id=<app-id>
```
Ergebnis-CSV (Header + 1 Zeile je abgeschlossenem Spiel) für den menschlichen
Ergebnis-Einpfleger (ClubCloud/DBU). Spalten:
```
Gruppe;Partie;ExternalId;Spieler1_cc_id;Spieler1_dbu_nr;Spieler1;Ergebnis1;Aufnahmen1;HS1;Spieler2_cc_id;Spieler2_dbu_nr;Spieler2;Ergebnis2;Aufnahmen2;HS2;Datum;Uhrzeit
```
- `dbu_nr` je Spieler als Crosscheck. Read-only, wiederholbar — **auch nach
  `end_tournament`**. Turnier ohne abgeschlossene Spiele → 200 mit nur Header-Zeile.

## 12. `GET clubs` → `carambus.clubs/v1` (Phase 18)

```jsonc
GET /api/external_tournament/clubs?region=NBV
// 200
{ "schema":"carambus.clubs/v1", "region":{"shortname":"NBV"},
  "season":{"name":"2025/2026","current":true},
  "clubs":[ {"cc_id":11,"shortname":"BC Wedel","name":"Billard Club Wedel"} ] }
```
Clubs der Region für den Club-Picker. `cc_id` (region-eindeutig) ist der Schlüssel für
Endpoint 13. Read-only.

## 13. `GET club_players` → `carambus.club_players/v1` (Phase 18)

```jsonc
GET /api/external_tournament/club_players?region=NBV&club_cc_id=11
// optional mehrere: ?region=NBV&club_cc_ids=11,12 → Antwort als clubs:[{club,players},…]
// 200
{ "schema":"carambus.club_players/v1", "region":{"shortname":"NBV"},
  "season":{"name":"2025/2026"},
  "club":{"cc_id":11,"shortname":"BC Wedel","name":"Billard Club Wedel"},
  "players":[ {"cc_id":4567,"firstname":"Oliver","lastname":"Weese","dbu_nr":"12345","status":"active"} ] }
```
- `players` = **strikt** in der laufenden Saison spielberechtigt (`SeasonParticipation
  status="active"`; `temporary`/`guest`/ohne Status ausgeschlossen). `status` je Spieler
  mitgeliefert (aktuell immer `"active"`).
- `dbu_nr` ist **nullable** (offizielle Spieler ohne hinterlegte DBU-Nr → `null`).
- Fehler: `401` (Bearer) · `404` (Region/`club_cc_id` nicht in Region) · `422`
  (`club_cc_id` fehlt und kein `club_cc_ids`).
- App-Nutzung: Setup-Schritt „Spieler zuordnen" → Dropdown je Spieler → schreibt
  `cc_id`+`dbu_nr` an den App-Spieler → `start_game` matcht exakt + CSV vollständig.
  Quelle: `HANDOFF-from-carambus-phase18-response.md`.

## 14. `GET player_rankings` → `carambus.player_rankings/v1` (Phase 19)

```jsonc
GET /api/external_tournament/player_rankings?region=NBV&discipline=Dreiband+klein
//   optional: &player_cc_ids=11683,10024,10587   (Filter; ohne → gesamte Rangliste)
//   optional: &season=2024/2025                  (Default: VORSAISON, siehe unten)
// 200
{ "schema":"carambus.player_rankings/v1", "region":{"shortname":"NBV"},
  "season":{"name":"2024/2025"},
  "discipline":{"name":"Dreiband klein"},
  "players":[
    {"cc_id":11683,"firstname":"Georg","lastname":"Nachtmann","dbu_nr":"...","rank":1,"gd":20.69,"hs":12,"balls":600,"innings":29},
    {"cc_id":10024,"firstname":"Hans-Jörg","lastname":"Schröder","dbu_nr":"...","rank":2,"gd":13.13}
  ],
  "unranked":["190204"] }
```
- Sortiert eine Spielerliste nach dem offiziellen `PlayerRanking` einer **Disziplin**
  (bestes Ranking zuerst: `rank` aufsteigend, bei Gleichstand `gd` absteigend). Substrat
  für **Ranking-Setzlisten** in der App (z. B. Doppel-KO: Setzplatz 1 = bester Spieler).
- **Disziplin-Auflösung:** exakter `name`, sonst Synonym-Treffer (`Discipline#synonyms`
  ist newline-separiert und enthält den Namen selbst).
- **Saison (D-19-01-SEASON, verbindlich):** ohne `season`-Param wird **immer die VORSAISON**
  genommen (die Saison vor der laufenden) — die laufende Saison ist beim Seeding noch nicht
  final. Ableitung aus `Season.current_season`. `&season=2024/2025` erzwingt eine bestimmte
  Saison. (Für die App = gewünschtes Seeding-Verhalten; `fetchPlayerRankings` sendet keinen
  `season`-Param → bekommt die Vorsaison.)
- `player_cc_ids` (optional, kommagetrennt): nur diese Spieler. Angeforderte cc_ids ohne
  Ranking-Eintrag kommen in `unranked` zurück (App hängt sie hinten an die Setzliste).
- `gd` = Generaldurchschnitt (nullable). `dbu_nr` nullable.
- Fehler: `401` (Bearer) · `404` (Region/Disziplin unbekannt) · `422` (`discipline` fehlt).
- **Status: ✅ GELIEFERT (Carambus Phase 19 / v0.6)** — live nach Merge→master + Deploy.
  Carambus-seitig getestet (RankingQuery + Controller + CORS grün, Live-Verify gegen `:3008`).
  Antwort-Handoff: `HANDOFF-from-carambus-phase19-rankings-cors.md`. CORS: `rack-cors`,
  LAN-Origins per Default; abweichende Origin via ENV `EXTERNAL_APP_CORS_ORIGINS`.

---

# App-Migration auf Phase 17 (IMPLEMENTIERT 2026-05-21)

**Status:** Die App-seitige Phase-17-Integration ist gebaut + gegen `:3131`
verifiziert (Lifecycle-Smoke-Test create/lock/start/ack-409/end grün; 19
Mock-E2E-Tests grün). UI: „Carambus Live-Steuerung"-Karte im Setup
(Turnier anlegen & Tische binden / beenden / CSV-Export), pro Runde
„Teilrunde 1/2 starten", pro Spiel „Ergebnis holen". `start_game` ist der
aktive Spielpfad; die alten `round_start`/`round_result`-HTTP-Buttons wurden
entfernt (Datei-Export/-Import bleibt als Offline-Fallback).

**Offener Verifikationspunkt:** Das Mapping von `acknowledge_result.result`
(`Ergebnis1/Aufnahmen1/Höchstserie1` → playerA, `…2` → playerB) ist die
Annahme „Reihenfolge wie im start_game-participants-Array" und muss mit einem
**echten gespielten Spiel** bestätigt werden (im Mock korrekt, real noch offen).

**Entscheidung 2026-05-21:** Die App stellt voll auf den Phase-17-Lebenszyklus um.
`start_game` ersetzt `round_start` im aktiven Spielbetrieb (löst Spielbereitschaft +
Tisch-Freigabe). `round_start`/`round_result` bleiben für den Datei-/Aggregat-Pfad.

**Mapping 3-Band-Mannschaft → Phase 17:**

| App-Aktion | Phase-17-Aufruf |
|---|---|
| Turnier in Carambus anlegen (einmalig) | `POST tournament` (external_id = App-Turnier-ID) → `tournament_monitor_id` merken |
| 4 Tische binden (einmalig nach Tisch-Auswahl) | `POST lock_table` × 4 |
| (optional Setup) dbu_nr je Spieler holen | `POST player_reconcile` (16 Spieler im Batch) |
| Spiel starten (pro Partie, beim Aufruf an den Tisch) | `POST start_game` (external_id pro Spiel, discipline 3-Band, balls_goal 30, innings_goal 25, sets 1) |
| Ergebnis holen + Tisch freigeben (nach Spielende) | `POST acknowledge_result` → Bälle/Aufnahmen/HS in App übernehmen |
| Turnierende | `POST end_tournament` |
| Ergebnis-Übergabe an Einpfleger | `GET csv_export` |

**Neue App-HTTP-Funktionen (zu bauen):** `createTournament()`, `lockTables()`,
`startGame(game)`, `acknowledgeResult(game)`, `endTournament()`,
`playerReconcile()`, `csvExport()`. Plus UI-Schritte: „Turnier in Carambus anlegen",
„Tische binden", „Spiel starten" (pro Tisch), „Ergebnis holen" (ersetzt den
bisherigen Result-Pull), „Turnier beenden".

**Offene Abstimmungspunkte vor der Umsetzung:**
- `carambus.ack/v1`-Feldnamen final gegen Dev `:3008` bestätigen.
- Single-Set reicht für 3-Band-Mannschaft (sets_to_play=1) → Multi-Set-Hold nicht nötig.
- Mapping der `acknowledge_result.result`-Felder (`Ergebnis1/2`, `Aufnahmen1/2`,
  `Höchstserie1/2`) auf das App-Spielmodell (playerA/playerB balls/innings/highSeries).

**Blocker:** Production-Deploy `:3131` (inkl. cc_id-Region-Fix + CORS) steht aus.
Bis dahin nur server-to-server-Tests gegen Dev `:3008` möglich.
