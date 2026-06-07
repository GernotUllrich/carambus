# Carambus API-Dokumentation

## Übersicht

Die Carambus API bietet RESTful-Endpunkte für die Verwaltung von Billard-Turnieren, Ligen, Spielern und Echtzeit-Scoreboard-Funktionalität. Die API ist auf Ruby on Rails aufgebaut und folgt REST-Konventionen.

## Authentifizierung

### Session-basierte Authentifizierung
Die meisten Endpunkte erfordern Authentifizierung über Devise. Fügen Sie Session-Cookies in Ihre Anfragen ein:

```bash
# Anmelden, um Session zu erhalten
curl -X POST http://localhost:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "user@example.com", "password": "password"}}' \
  -c cookies.txt

# Session für authentifizierte Anfragen verwenden
curl -X GET http://localhost:3000/api/tournaments \
  -b cookies.txt
```

### API-Token-Authentifizierung (Zukunft)
Token-basierte Authentifizierung ist für zukünftige Versionen geplant.

## External Tournament Bridge (devise-JWT)

> **Phase 15 (v0.5)** — REST-Bridge für externe Turnier-Apps. Anwender-Anleitung:
> [Manager-Doku](../managers/external-tournament-bridge.md). Technische Details:
> [Developer-Doku](../developers/external-tournament-bridge.md).

### Authentifizierung

devise-JWT-Bearer-Tokens. Pro Region/Scenario ein Service-Account:

```bash
rake service_accounts:create_2band[NBV]
# → 2band-nbv-bridge@carambus.de
```

Bearer-Token holen:

```bash
curl -X POST <base-url>/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-nbv-bridge@carambus.de","password":"…"}}' \
  -i | grep -i Authorization
# Authorization: Bearer eyJhbGciOi…
```

JWT-Lifetime: **90 Tage** (Long-Lived; via D-14-G7 +
`Carambus.config.jwt_expiration_days`).

### Endpoints

Alle Endpoints liegen unter `/api/external_tournament/` und benötigen ein
Bearer-JWT. Die Bridge ist weit über das ursprüngliche Read-only-Trio
hinausgewachsen; die folgende Tabelle entspricht den Routen in
`config/routes.rb` und den Actions in
`app/controllers/api/external_tournaments_controller.rb`.

**Read / Discovery (GET):**

| Method | URL | Zweck |
|--------|-----|-------|
| `GET`  | `/api/external_tournament/seeding?tournament_cc_id=X&region=R` | Setzliste (`carambus.seeding/v1`) |
| `GET`  | `/api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=R` | Ergebnisse pro Runde (`carambus.round_result/v1`) |
| `GET`  | `/api/external_tournament/tables?location_cc_id=X&region=R` | Tische einer Location (`carambus.tables/v1`; Plan 15-06) |
| `GET`  | `/api/external_tournament/clubs` | Clubs der Region für den Spieler-Picker (Plan 18-01) |
| `GET`  | `/api/external_tournament/club_players` | In der laufenden Saison spielberechtigte (status active) Spieler eines Clubs, je `cc_id` + `dbu_nr` (Plan 18-01) |
| `GET`  | `/api/external_tournament/player_rankings` | Spieler nach Disziplin-Ranking sortiert für App-Setzlisten (Plan 19-01) |
| `GET`  | `/api/external_tournament/disciplines` | Region-relevante Disziplinen + TournamentPlan-Matrix (`carambus.disciplines/v1`; Plan 20-01) |
| `GET`  | `/api/external_tournament/categories` | Spieler-/Altersklassen, Geschlechter, Kategorien (`carambus.categories/v1`; Plan 20-02) |
| `GET`  | `/api/external_tournament/registration_lists` | Meldelisten-Discovery: Deadline/Status/Kategorie/Disziplin (`carambus.registration_lists/v1`; Plan 21-05) |

**Write / Lifecycle (POST):**

| Method | URL | Zweck |
|--------|-----|-------|
| `POST` | `/api/external_tournament/round_start` | Tisch-Paarungen (`carambus.round_start/v1`; akzeptiert `location` + `table_name`, Plan 15-06) → Game + GameParticipation + TableMonitor |
| `POST` | `/api/external_tournament/tournament` | Lokales Turnier anlegen + TournamentMonitor binden (Plan 17-02) |
| `POST` | `/api/external_tournament/lock_table` | App-getriebener Tisch-Lock via TournamentMonitor-Bindung (Plan 17-02) |
| `POST` | `/api/external_tournament/start_game` | Spielstart mit per-Spiel/per-Spieler-Disziplinen; erzeugt Game + Warmup (Plan 17-03) |
| `POST` | `/api/external_tournament/acknowledge_result` | Erfasstes Ergebnis abrufen + Tisch freigeben (Result-Hold + Pull, Plan 17-04) |
| `POST` | `/api/external_tournament/end_tournament` | Turnierende: alle Tische frei + TournamentMonitor schließen (Plan 17-05) |
| `POST` | `/api/external_tournament/player_reconcile` | App-Teilnehmerliste gegen Carambus-lokal reconcilen (liefert `dbu_nr`, Plan 17-06) |

### Fehler-Codes (gemeinsam)

| Status | Bedeutung |
|--------|-----------|
| 401 | Fehlende/ungültige JWT |
| 404 | TournamentCc / Region nicht gefunden |
| 422 | Region-Mismatch / Player-Resolution-Fehler / Validation-Fehler |
| 200 | Erfolg (GET; Round-Start bei Idempotenz) |
| 201 | Round-Start Create — mindestens 1 Game neu erstellt |

### Smoke-Test

Verifiziert alle 3 Endpoints in einem Roundtrip:

```bash
SERVICE_ACCOUNT_PASSWORD="…" rake external_tournament:smoke_test[NBV]
```

5-Schritte-Trace: Login → Tournament-Lookup → Seeding → Round-Start → Round-Result.

## Basis-URL
```
Entwicklung: http://localhost:3000
Produktion: https://carambus.de
```

## Geplanter JSON:API-Vertrag (noch nicht implementiert)

> **⚠️ Geplantes / zukünftiges Design — NOCH NICHT implementiert.**
>
> Die folgenden Abschnitte (**Antwortformat**, **Fehlerantworten**,
> **Kern-Endpunkte** für Turniere / Spieler / Ligen / Parties / Tisch-Monitore,
> die **Datensynchronisations-API**, **Rate Limiting**,
> **Paginierungs-Metadaten** und die **SDK**-Beispiele) beschreiben einen
> *angestrebten* JSON:API-artigen Vertrag. Sie sind **nicht** durch
> existierende Routen abgedeckt.
>
> **Was heute tatsächlich existiert:**
> - Die öffentliche Turnier-Ressource ist **server-gerendertes HTML / Turbo**,
>   kein JSON:API-Endpunkt. `/tournaments` (index) und `/tournaments/:id` (show)
>   rendern HTML/Turbo-Streams. Turnier-Lifecycle-Aktionen sind eigene
>   Member-Routen (`select_modus`, `finalize_modus`, `start`, `reset`,
>   `define_participants`, `add_team`, `placement`, …), die ebenfalls auf
>   HTML/Turbo arbeiten, **nicht** auf JSON-Envelopes.
> - Es gibt **kein** `POST/PATCH/DELETE /tournaments` JSON:API, **kein**
>   `GET /api/tournaments` und **keine** JSON-List/Get-Endpunkte für Spieler
>   oder Parties.
> - Die einzigen tatsächlich implementierten JSON-APIs unter `/api` sind:
>   AI-Suche (`POST /api/ai_search`, `POST /api/ai_docs`), Autocomplete
>   (`GET /api/players/autocomplete`, `GET /api/locations/autocomplete`) und
>   die oben dokumentierte **External Tournament Bridge** (devise-JWT).
>
> Behandeln Sie alles in diesem "Geplanter JSON:API-Vertrag"-Block als
> Design-Skizze, nicht als funktionierende API.

## Antwortformat

> Geplantes / zukünftiges Design — siehe Hinweis oben.

Im geplanten Design wären API-Antworten im JSON-Format:

```json
{
  "data": {
    "id": 1,
    "type": "tournament",
    "attributes": {
      "name": "Regionalmeisterschaft 2024",
      "start_date": "2024-01-15",
      "status": "active"
    },
    "relationships": {
      "discipline": {
        "data": {
          "id": 1,
          "type": "discipline"
        }
      }
    }
  }
}
```

## Fehlerantworten

```json
{
  "error": {
    "code": "validation_error",
    "message": "Validierung fehlgeschlagen",
    "details": {
      "name": ["darf nicht leer sein"]
    }
  }
}
```

## Kern-Endpunkte (Geplant)

> **⚠️ Geplantes / zukünftiges Design — NOCH NICHT implementiert.** Siehe den
> Hinweis in "Geplanter JSON:API-Vertrag" oben. Heute rendern `/tournaments`
> und `/tournaments/:id` HTML/Turbo, und es gibt kein JSON-CRUD für Turniere,
> Spieler oder Parties.

### Turniere

#### Turniere auflisten
```http
GET /tournaments
```

**Abfrageparameter:**
- `page`: Seitennummer (Standard: 1)
- `per_page`: Elemente pro Seite (Standard: 25)
- `status`: Nach Status filtern (`active`, `completed`, `draft`)
- `discipline_id`: Nach Disziplin filtern
- `location_id`: Nach Standort filtern

**Antwort:**
```json
{
  "data": [
    {
      "id": 1,
      "type": "tournament",
      "attributes": {
        "name": "Regionalmeisterschaft 2024",
        "start_date": "2024-01-15",
        "end_date": "2024-01-17",
        "status": "active",
        "discipline_name": "3-Banden",
        "location_name": "Billard Club Wedel"
      }
    }
  ],
  "meta": {
    "total_count": 50,
    "total_pages": 2,
    "current_page": 1
  }
}
```

#### Turnier abrufen
```http
GET /tournaments/{id}
```

**Antwort:**
```json
{
  "data": {
    "id": 1,
    "type": "tournament",
    "attributes": {
      "name": "Regionalmeisterschaft 2024",
      "start_date": "2024-01-15",
      "end_date": "2024-01-17",
      "status": "active",
      "discipline_name": "3-Banden",
      "location_name": "Billard Club Wedel",
      "participant_count": 16,
      "game_count": 24
    },
    "relationships": {
      "discipline": {
        "data": {
          "id": 1,
          "type": "discipline"
        }
      },
      "location": {
        "data": {
          "id": 1,
          "type": "location"
        }
      },
      "seedings": {
        "data": [
          {
            "id": 1,
            "type": "seeding"
          }
        ]
      }
    }
  }
}
```

#### Turnier erstellen
```http
POST /tournaments
```

**Anfrage-Body:**
```json
{
  "tournament": {
    "name": "Neues Turnier",
    "discipline_id": 1,
    "location_id": 1,
    "start_date": "2024-02-01",
    "end_date": "2024-02-03",
    "max_participants": 16
  }
}
```

#### Turnier aktualisieren
```http
PATCH /tournaments/{id}
```

#### Turnier löschen
```http
DELETE /tournaments/{id}
```

### Turnier-Aktionen (implementiert — HTML/Turbo)

> Diese Member-Routen **existieren** auf `resources :tournaments`. Es sind
> HTML/Turbo-Aktionen (Redirects / Turbo-Streams), keine JSON:API-Endpunkte.

#### Turnier starten
```http
POST /tournaments/{id}/start
```

#### Turnier zurücksetzen
```http
POST /tournaments/{id}/reset
```

#### Modus-/Spielplan-Auswahl
Es gibt **keine** `generate_game_plan`-Aktion. Der Spielplan (Turnierplan /
Modus) wird über diese realen Member-Routen gewählt:

```http
GET  /tournaments/{id}/finalize_modus   # vorgeschlagene(n) Plan/Pläne + Gruppen anzeigen
POST /tournaments/{id}/select_modus     # gewählte tournament_plan_id anwenden
```

`POST /tournaments/{id}/recalculate_groups` führt den Gruppen-Algorithmus
erneut aus.

### Spieler

#### Spieler auflisten
```http
GET /players
```

**Abfrageparameter:**
- `page`: Seitennummer
- `per_page`: Elemente pro Seite
- `region_id`: Nach Region filtern
- `club_id`: Nach Club filtern
- `search`: Nach Namen suchen

#### Spieler abrufen
```http
GET /players/{id}
```

**Antwort:**
```json
{
  "data": {
    "id": 1,
    "type": "player",
    "attributes": {
      "first_name": "Max",
      "last_name": "Mustermann",
      "ba_id": "12345",
      "club_name": "Billard Club Wedel",
      "region_name": "Schleswig-Holstein",
      "ranking": 1250
    }
  }
}
```

### Ligen

#### Ligen auflisten
```http
GET /leagues
```

#### Liga abrufen
```http
GET /leagues/{id}
```

#### Liga-Teams
```http
GET /leagues/{id}/league_teams
```

### Parties (Spiele)

#### Parties auflisten
```http
GET /parties
```

**Abfrageparameter:**
- `tournament_id`: Nach Turnier filtern
- `league_id`: Nach Liga filtern
- `status`: Nach Status filtern
- `date`: Nach Datum filtern

#### Party abrufen
```http
GET /parties/{id}
```

**Antwort:**
```json
{
  "data": {
    "id": 1,
    "type": "party",
    "attributes": {
      "date": "2024-01-15T14:00:00Z",
      "status": "in_progress",
      "team_a_name": "Team Alpha",
      "team_b_name": "Team Beta",
      "score_a": 3,
      "score_b": 2
    },
    "relationships": {
      "league_team_a": {
        "data": {
          "id": 1,
          "type": "league_team"
        }
      },
      "league_team_b": {
        "data": {
          "id": 2,
          "type": "league_team"
        }
      }
    }
  }
}
```

### Tisch-Monitore

#### Tisch-Monitor abrufen
```http
GET /table_monitors/{id}
```

**Antwort:**
```json
{
  "data": {
    "id": 1,
    "type": "table_monitor",
    "attributes": {
      "table_number": 1,
      "status": "active",
      "current_game": {
        "id": 123,
        "player_a": "Max Mustermann",
        "player_b": "Erika Musterfrau",
        "score_a": 15,
        "score_b": 12,
        "balls_goal": 30
      }
    }
  }
}
```

#### Tisch-Monitor aktualisieren
```http
PATCH /table_monitors/{id}
```

**Anfrage-Body:**
```json
{
  "table_monitor": {
    "balls_a": 16,
    "balls_b": 12
  }
}
```

### Tisch-Monitor-Aktionen

#### Punkte hinzufügen
```http
POST /table_monitors/{id}/add_one
POST /table_monitors/{id}/add_ten
```

#### Punkte abziehen
```http
POST /table_monitors/{id}/minus_one
POST /table_monitors/{id}/minus_ten
```

#### Nächster Schritt
```http
POST /table_monitors/{id}/next_step
```

#### Spiel starten
```http
POST /table_monitors/{id}/start_game
```

#### Ergebnis auswerten
```http
POST /table_monitors/{id}/evaluate_result
```

## Echtzeit-API

### Action Cable Channels

#### Tisch-Monitor Channel
Abonnieren Sie Echtzeit-Tisch-Monitor-Updates:

```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const subscription = consumer.subscriptions.create(
  { channel: "TableMonitorChannel", table_id: 1 },
  {
    connected() {
      console.log("Mit Tisch-Monitor verbunden")
    },
    
    disconnected() {
      console.log("Von Tisch-Monitor getrennt")
    },
    
    received(data) {
      console.log("Update erhalten:", data)
      // UI mit neuen Daten aktualisieren
      updateTableDisplay(data)
    }
  }
)
```

**Channel-Ereignisse:**
- `score_update`: Punkteänderungen
- `game_start`: Neues Spiel gestartet
- `game_end`: Spiel beendet
- `status_change`: Tisch-Status geändert

#### Scoreboard Channel
Abonnieren Sie Scoreboard-Updates:

```javascript
const scoreboardSubscription = consumer.subscriptions.create(
  { channel: "ScoreboardChannel", location_id: 1 },
  {
    received(data) {
      updateScoreboard(data)
    }
  }
)
```

### WebSocket-Nachrichtenformat

```json
{
  "type": "score_update",
  "table_id": 1,
  "data": {
    "player_a": "Max Mustermann",
    "player_b": "Erika Musterfrau",
    "score_a": 16,
    "score_b": 12,
    "balls_goal": 30,
    "status": "in_progress"
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

## Datensynchronisation

> Es gibt **keine** `POST /api/sync/ba/*`- oder `POST /api/sync/cc/*`-HTTP-
> Endpunkte. Die Synchronisation mit externen Datenquellen erfolgt über
> **Scraper-Services**, die von **geplanten Rake-Tasks** ausgelöst werden,
> nicht über eine eingehende REST-API.

### Scraper-Services

Externe Daten werden von Service-Objekten gesammelt (siehe `app/services/`):
`UmbScraperV2`, `CuescoScraper`, `SoopliveScraper`, `KozoomScraper`,
`YoutubeScraper`.

### Geplante Sync-Tasks

Die wichtigsten Synchronisations-Einstiegspunkte sind Rake-Tasks (ausgeführt
via cron / whenever):

```bash
rake scrape:daily_update              # tägliche Region-/Club-/Turnier-/Liga-Sync
rake scrape:daily_update_monitored    # überwachte Variante (cron @ 04:00 täglich)
rake scrape:update_seasons
rake scrape:scrape_clubs
rake scrape:scrape_tournaments_optimized
rake scrape:scrape_leagues_optimized
```

Zusätzliche quellenspezifische Tasks liegen unter den Namespaces `umb:`,
`cuesco:`, `youtube:` und `international:` (z. B.
`rake international:scrape_all`, `rake youtube:scrape_all`).

### Regionsverwaltung

#### Regionsdaten prüfen
```http
GET /region_ccs/{id}/check
```

#### Regionsdaten reparieren
```http
POST /region_ccs/{id}/fix
```

## Admin-API

### Benutzerverwaltung
```http
GET /admin/users
POST /admin/users
PATCH /admin/users/{id}
DELETE /admin/users/{id}
```

### Systemeinstellungen
```http
GET /settings/club_settings
POST /settings/update_club_settings
GET /settings/tournament_settings
POST /settings/update_tournament_settings
```

## Rate Limiting

API-Anfragen sind rate-limitiert, um Missbrauch zu verhindern:

- **Authentifizierte Benutzer**: 1000 Anfragen pro Stunde
- **Nicht-authentifizierte Benutzer**: 100 Anfragen pro Stunde

Rate-Limit-Header sind in Antworten enthalten:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

## Paginierung

Listen-Endpunkte unterstützen Paginierung mit folgenden Parametern:

- `page`: Seitennummer (Standard: 1)
- `per_page`: Elemente pro Seite (Standard: 25, max: 100)

Paginierungs-Metadaten sind in Antworten enthalten:

```json
{
  "data": [...],
  "meta": {
    "total_count": 150,
    "total_pages": 6,
    "current_page": 1,
    "per_page": 25
  }
}
```

## Filterung und Sortierung

### Filterung
Die meisten Listen-Endpunkte unterstützen Filterung:

```http
GET /tournaments?status=active&discipline_id=1&location_id=2
```

### Sortierung
Sortierung wird auf den meisten Endpunkten unterstützt:

```http
GET /tournaments?sort=start_date&direction=desc
GET /players?sort=last_name&direction=asc
```

## Fehlercodes

| Code | Beschreibung |
|------|-------------|
| 400 | Bad Request - Ungültige Parameter |
| 401 | Unauthorized - Authentifizierung erforderlich |
| 403 | Forbidden - Unzureichende Berechtigungen |
| 404 | Not Found - Ressource nicht gefunden |
| 422 | Unprocessable Entity - Validierungsfehler |
| 429 | Too Many Requests - Rate Limit überschritten |
| 500 | Internal Server Error |

## SDKs und Bibliotheken

### JavaScript/TypeScript
```bash
npm install carambus-api-client
```

```javascript
import { CarambusAPI } from 'carambus-api-client'

const api = new CarambusAPI({
  baseURL: 'https://carambus.de',
  credentials: 'include'
})

// Turniere abrufen
const tournaments = await api.tournaments.list()

// Turnier erstellen
const tournament = await api.tournaments.create({
  name: 'Neues Turnier',
  discipline_id: 1,
  location_id: 1
})
```

### Ruby
```ruby
require 'carambus_api'

client = CarambusAPI::Client.new(
  base_url: 'https://carambus.de',
  session_cookies: session_cookies
)

# Turniere abrufen
tournaments = client.tournaments.list

# Turnier erstellen
tournament = client.tournaments.create(
  name: 'Neues Turnier',
  discipline_id: 1,
  location_id: 1
)
```

## Beispiele

### Vollständiger Turnier-Workflow

> **⚠️ Geplantes / zukünftiges Design.** Diese SDK-Skizze ist nur
> illustrativ; es existiert heute weder ein `carambus-api-client`-Paket noch
> ein JSON-Turnier-CRUD.

```javascript
// 1. Turnier erstellen
const tournament = await api.tournaments.create({
  name: 'Meisterschaft 2024',
  discipline_id: 1,
  location_id: 1,
  start_date: '2024-02-01',
  max_participants: 16
})

// 2. Teilnehmer hinzufügen
for (const player of players) {
  await api.tournaments.addParticipant(tournament.id, player.id)
}

// 3. Turnier-Modus / Spielplan wählen
//    (reale HTML/Turbo-Aktionen: finalize_modus → select_modus)
await api.tournaments.selectModus(tournament.id, { tournament_plan_id: planId })

// 4. Turnier starten
await api.tournaments.start(tournament.id)

// 5. Echtzeit-Updates abonnieren
const subscription = consumer.subscriptions.create(
  { channel: "TournamentChannel", tournament_id: tournament.id },
  {
    received(data) {
      updateTournamentDisplay(data)
    }
  }
)
```

### Echtzeit-Scoreboard-Integration

```javascript
// Mit Scoreboard verbinden
const scoreboard = consumer.subscriptions.create(
  { channel: "ScoreboardChannel", location_id: 1 },
  {
    received(data) {
      // Scoreboard-Anzeige aktualisieren
      document.getElementById('scoreboard').innerHTML = 
        generateScoreboardHTML(data)
    }
  }
)

// Tisch-Punkte aktualisieren
async function updateScore(tableId, player, points) {
  await api.tableMonitors.update(tableId, {
    [`balls_${player}`]: points
  })
}
```

## Support

Für API-Support und Fragen:

- **Dokumentation**: siehe oben (diese Seite)
- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Diskussionen**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)

---

*Diese API-Dokumentation wird vom Carambus-Entwicklungsteam gepflegt. Für Fragen oder Beiträge siehe den [Beitragsleitfaden](../developers/developer-guide.de.md#mitwirken).* 