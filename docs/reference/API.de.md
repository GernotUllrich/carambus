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

## Basis-URL
```
Entwicklung: http://localhost:3000
Produktion: https://carambus.de
```

## Antwortformat

Alle API-Antworten sind im JSON-Format:

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

## Kern-Endpunkte

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

### Turnier-Aktionen

#### Turnier starten
```http
POST /tournaments/{id}/start
```

#### Turnier zurücksetzen
```http
POST /tournaments/{id}/reset
```

#### Spielplan generieren
```http
POST /tournaments/{id}/generate_game_plan
```

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

## Datensynchronisations-API

### Externe Datenquellen

#### BA (Billard-Verband) Sync
```http
POST /api/sync/ba/players
POST /api/sync/ba/tournaments
```

#### CC (Competition Center) Sync
```http
POST /api/sync/cc/competitions
POST /api/sync/cc/results
```

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

// 3. Spielplan generieren
await api.tournaments.generateGamePlan(tournament.id)

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

- **Dokumentation**: [API.md](API.de.md)
- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Diskussionen**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)

---

*Diese API-Dokumentation wird vom Carambus-Entwicklungsteam gepflegt. Für Fragen oder Beiträge siehe den [Beitragsleitfaden](../developers/developer-guide.de.md#mitwirken).* 