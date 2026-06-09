# Carambus API Documentation

## Overview

The Carambus API provides RESTful endpoints for managing billiards tournaments, leagues, players, and real-time scoreboard functionality. The API is built on Ruby on Rails and follows REST conventions.

## Authentication

### Session-based Authentication
Most endpoints require authentication via Devise. Include session cookies in your requests:

```bash
# Login to get session
curl -X POST http://localhost:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "user@example.com", "password": "password"}}' \
  -c cookies.txt

# Use session for authenticated requests
curl -X GET http://localhost:3000/api/tournaments \
  -b cookies.txt
```

### API Token Authentication (Future)
Token-based authentication is planned for future releases.

## External Tournament Bridge (devise-JWT)

> **Phase 15 (v0.5)** — REST bridge for external tournament apps. User guide:
> [Manager docs](../managers/external-tournament-bridge.md). Technical details:
> [Developer docs](../developers/external-tournament-bridge.md).

### Authentication

devise-JWT bearer tokens. One service account per region/scenario:

```bash
rake service_accounts:create_2band[NBV]
# → 2band-nbv-bridge@carambus.de
```

Obtain a bearer token:

```bash
curl -X POST <base-url>/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"2band-nbv-bridge@carambus.de","password":"…"}}' \
  -i | grep -i Authorization
# Authorization: Bearer eyJhbGciOi…
```

JWT lifetime: **90 days** (long-lived; via D-14-G7 +
`Carambus.config.jwt_expiration_days`).

### Endpoints

All endpoints are mounted under `/api/external_tournament/` and require a Bearer
JWT. The bridge has grown well beyond the original read-only trio; the table
below reflects the routes in `config/routes.rb` and the actions in
`app/controllers/api/external_tournaments_controller.rb`.

**Read / discovery (GET):**

| Method | URL | Purpose |
|--------|-----|---------|
| `GET`  | `/api/external_tournament/seeding?tournament_cc_id=X&region=R` | Seeding list (`carambus.seeding/v1`) |
| `GET`  | `/api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=R` | Results per round (`carambus.round_result/v1`) |
| `GET`  | `/api/external_tournament/tables?location_cc_id=X&region=R` | Tables of a location (`carambus.tables/v1`; Plan 15-06) |
| `GET`  | `/api/external_tournament/clubs` | Clubs of the region for the player picker (Plan 18-01) |
| `GET`  | `/api/external_tournament/club_players` | Players eligible (active) for a club in the running season, with `cc_id` + `dbu_nr` (Plan 18-01) |
| `GET`  | `/api/external_tournament/player_rankings` | Players sorted by discipline ranking for app seeding lists (Plan 19-01) |
| `GET`  | `/api/external_tournament/disciplines` | Region-relevant disciplines + TournamentPlan matrix (`carambus.disciplines/v1`; Plan 20-01) |
| `GET`  | `/api/external_tournament/categories` | Player/age classes, genders, categories (`carambus.categories/v1`; Plan 20-02) |
| `GET`  | `/api/external_tournament/registration_lists` | Meldelisten discovery: deadline/status/category/discipline (`carambus.registration_lists/v1`; Plan 21-05) |

**Write / lifecycle (POST):**

| Method | URL | Purpose |
|--------|-----|---------|
| `POST` | `/api/external_tournament/round_start` | Table pairings (`carambus.round_start/v1`; accepts `location` + `table_name`, Plan 15-06) → Game + GameParticipation + TableMonitor |
| `POST` | `/api/external_tournament/tournament` | Create a local tournament + bind TournamentMonitor (Plan 17-02) |
| `POST` | `/api/external_tournament/lock_table` | App-driven table lock via TournamentMonitor binding (Plan 17-02) |
| `POST` | `/api/external_tournament/start_game` | Start a game with per-game/per-player disciplines; creates Game + warmup (Plan 17-03) |
| `POST` | `/api/external_tournament/acknowledge_result` | Pull the captured result + release the table (result hold + pull, Plan 17-04) |
| `POST` | `/api/external_tournament/end_tournament` | End the tournament: release all tables + close the TournamentMonitor (Plan 17-05) |
| `POST` | `/api/external_tournament/player_reconcile` | Reconcile an app participant list against Carambus-local players (returns `dbu_nr`, Plan 17-06) |

### Error codes (shared)

| Status | Meaning |
|--------|---------|
| 401 | Missing/invalid JWT |
| 404 | TournamentCc / region not found |
| 422 | Region mismatch / player resolution error / validation error |
| 200 | Success (GET; round_start on idempotent replay) |
| 201 | Round start create — at least one new game created |

### Smoke test

Verifies all 3 endpoints in one roundtrip:

```bash
SERVICE_ACCOUNT_PASSWORD="…" rake external_tournament:smoke_test[NBV]
```

5-step trace: login → tournament lookup → seeding → round start → round result.

## Base URL
```
Development: http://localhost:3000
Production: https://carambus.de
```

## Planned JSON:API Contract (not yet implemented)

> **⚠️ Planned / future design — NOT yet implemented.**
>
> The sections below (**Response Format**, **Error Responses**, **Core
> Endpoints** for Tournaments / Players / Leagues / Parties / Table Monitors,
> the **Data Synchronization API**, **Rate Limiting**, **Pagination metadata**,
> and the **SDK** examples) describe an *aspirational* JSON:API-style contract.
> They are **not** backed by live routes today.
>
> **What actually exists today:**
> - The public tournament resource is **server-rendered HTML / Turbo**, not a
>   JSON:API endpoint. `/tournaments` (index) and `/tournaments/:id` (show)
>   render HTML/Turbo Streams. Tournament lifecycle actions are custom member
>   routes (`select_modus`, `finalize_modus`, `start`, `reset`,
>   `define_participants`, `add_team`, `placement`, …) that also operate on
>   HTML/Turbo, **not** JSON envelopes.
> - There is **no** `POST/PATCH/DELETE /tournaments` JSON:API, **no**
>   `GET /api/tournaments`, and **no** JSON list/get endpoints for players or
>   parties.
> - The only implemented JSON APIs under `/api` are: AI search
>   (`POST /api/ai_search`, `POST /api/ai_docs`), autocomplete
>   (`GET /api/players/autocomplete`, `GET /api/locations/autocomplete`), and
>   the **External Tournament Bridge** (devise-JWT) documented above.
>
> Treat everything in this "Planned JSON:API Contract" block as a design
> sketch, not a working API.

## Response Format

> Planned / future design — see the note above.

In the planned design, API responses would be in JSON format:

```json
{
  "data": {
    "id": 1,
    "type": "tournament",
    "attributes": {
      "name": "Regional Championship 2024",
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

## Error Responses

```json
{
  "error": {
    "code": "validation_error",
    "message": "Validation failed",
    "details": {
      "name": ["can't be blank"]
    }
  }
}
```

## Core Endpoints (Planned)

> **⚠️ Planned / future design — NOT yet implemented.** See the note in
> "Planned JSON:API Contract" above. Today `/tournaments` and
> `/tournaments/:id` render HTML/Turbo, and there is no JSON CRUD for
> tournaments, players, or parties.

### Tournaments

#### List Tournaments
```http
GET /tournaments
```

**Query Parameters:**
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 25)
- `status`: Filter by status (`active`, `completed`, `draft`)
- `discipline_id`: Filter by discipline
- `location_id`: Filter by location

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "type": "tournament",
      "attributes": {
        "name": "Regional Championship 2024",
        "start_date": "2024-01-15",
        "end_date": "2024-01-17",
        "status": "active",
        "discipline_name": "3-Cushion",
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

#### Get Tournament
```http
GET /tournaments/{id}
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "type": "tournament",
    "attributes": {
      "name": "Regional Championship 2024",
      "start_date": "2024-01-15",
      "end_date": "2024-01-17",
      "status": "active",
      "discipline_name": "3-Cushion",
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

#### Create Tournament
```http
POST /tournaments
```

**Request Body:**
```json
{
  "tournament": {
    "name": "New Tournament",
    "discipline_id": 1,
    "location_id": 1,
    "start_date": "2024-02-01",
    "end_date": "2024-02-03",
    "max_participants": 16
  }
}
```

#### Update Tournament
```http
PATCH /tournaments/{id}
```

#### Delete Tournament
```http
DELETE /tournaments/{id}
```

### Tournament Actions (implemented — HTML/Turbo)

> These member routes **do** exist on `resources :tournaments`. They are
> HTML/Turbo actions (redirects / Turbo Streams), not JSON:API endpoints.

#### Start Tournament
```http
POST /tournaments/{id}/start
```

#### Reset Tournament
```http
POST /tournaments/{id}/reset
```

#### Mode / Game-Plan Selection
There is **no** `generate_game_plan` action. The game plan (Turnierplan /
modus) is chosen via these real member routes:

```http
GET  /tournaments/{id}/finalize_modus   # show proposed plan(s) + grouping
POST /tournaments/{id}/select_modus     # apply a chosen tournament_plan_id
```

`POST /tournaments/{id}/recalculate_groups` re-runs the grouping algorithm.

### Players

#### List Players
```http
GET /players
```

**Query Parameters:**
- `page`: Page number
- `per_page`: Items per page
- `region_id`: Filter by region
- `club_id`: Filter by club
- `search`: Search by name

#### Get Player
```http
GET /players/{id}
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "type": "player",
    "attributes": {
      "first_name": "John",
      "last_name": "Doe",
      "ba_id": "12345",
      "club_name": "Billard Club Wedel",
      "region_name": "Schleswig-Holstein",
      "ranking": 1250
    }
  }
}
```

### Leagues

#### List Leagues
```http
GET /leagues
```

#### Get League
```http
GET /leagues/{id}
```

#### League Teams
```http
GET /leagues/{id}/league_teams
```

### Parties (Matches)

#### List Parties
```http
GET /parties
```

**Query Parameters:**
- `tournament_id`: Filter by tournament
- `league_id`: Filter by league
- `status`: Filter by status
- `date`: Filter by date

#### Get Party
```http
GET /parties/{id}
```

**Response:**
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

### Table Monitors

#### Get Table Monitor
```http
GET /table_monitors/{id}
```

**Response:**
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
        "player_a": "John Doe",
        "player_b": "Jane Smith",
        "score_a": 15,
        "score_b": 12,
        "balls_goal": 30
      }
    }
  }
}
```

#### Set Balls
```http
POST /table_monitors/{id}/set_balls
```

Sets the ball count for the active player. The score is mutated through this
member action (and the increment/decrement actions below), not through a
`PATCH /table_monitors/{id}` update.

### Table Monitor Actions

#### Add Points
```http
POST /table_monitors/{id}/add_one
POST /table_monitors/{id}/add_ten
```

#### Subtract Points
```http
POST /table_monitors/{id}/minus_one
POST /table_monitors/{id}/minus_ten
```

#### Next Step
```http
POST /table_monitors/{id}/next_step
```

#### Start Game
```http
POST /table_monitors/{id}/start_game
```

#### Evaluate Result
```http
POST /table_monitors/{id}/evaluate_result
```

## Real-time API

### Action Cable Channels

#### Table Monitor Channel
Subscribe to real-time table monitor updates:

```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const subscription = consumer.subscriptions.create(
  { channel: "TableMonitorChannel", table_id: 1 },
  {
    connected() {
      console.log("Connected to table monitor")
    },
    
    disconnected() {
      console.log("Disconnected from table monitor")
    },
    
    received(data) {
      console.log("Received update:", data)
      // Update UI with new data
      updateTableDisplay(data)
    }
  }
)
```

**Channel Events:**
- `score_update`: Score changes
- `game_start`: New game started
- `game_end`: Game completed
- `status_change`: Table status changed

#### Scoreboard Channel
Subscribe to scoreboard updates:

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

### WebSocket Message Format

```json
{
  "type": "score_update",
  "table_id": 1,
  "data": {
    "player_a": "John Doe",
    "player_b": "Jane Smith",
    "score_a": 16,
    "score_b": 12,
    "balls_goal": 30,
    "status": "in_progress"
  },
  "timestamp": "2024-01-15T14:30:00Z"
}
```

## Data Synchronization

> There are **no** `POST /api/sync/ba/*` or `POST /api/sync/cc/*` HTTP
> endpoints. Synchronization with external data sources is performed by
> **scraper services** triggered by **scheduled rake tasks**, not by an
> inbound REST API.

### Scraper Services

External data is collected by service objects (see `app/services/`):
`UmbScraperV2`, `CuescoScraper`, `SoopliveScraper`, `KozoomScraper`,
`YoutubeScraper`.

### Scheduled Sync Tasks

The main synchronization entry points are rake tasks (run via cron / whenever):

```bash
rake scrape:daily_update              # daily regional/club/tournament/league sync
rake scrape:daily_update_monitored    # monitored variant (cron @ 04:00 daily)
rake scrape:update_seasons
rake scrape:scrape_clubs
rake scrape:scrape_tournaments_optimized
rake scrape:scrape_leagues_optimized
```

Additional source-specific tasks live under the `umb:`, `cuesco:`,
`youtube:`, and `international:` namespaces (e.g.
`rake international:scrape_all`, `rake youtube:scrape_all`).

### Region Management

#### Check Region Data
```http
GET /region_ccs/{id}/check
```

#### Fix Region Data
```http
POST /region_ccs/{id}/fix
```

## Admin API

### User Management
```http
GET /admin/users
POST /admin/users
PATCH /admin/users/{id}
DELETE /admin/users/{id}
```

### System Settings
```http
GET /settings/club_settings
POST /settings/update_club_settings
GET /settings/tournament_settings
POST /settings/update_tournament_settings
```

## Rate Limiting

API requests are rate-limited to prevent abuse:

- **Authenticated users**: 1000 requests per hour
- **Unauthenticated users**: 100 requests per hour

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

## Pagination

List endpoints support pagination with the following parameters:

- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 25, max: 100)

Pagination metadata is included in responses:

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

## Filtering and Sorting

### Filtering
Most list endpoints support filtering:

```http
GET /tournaments?status=active&discipline_id=1&location_id=2
```

### Sorting
Sorting is supported on most endpoints:

```http
GET /tournaments?sort=start_date&direction=desc
GET /players?sort=last_name&direction=asc
```

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Authentication required |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 422 | Unprocessable Entity - Validation errors |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error |

## SDKs and Libraries

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

// Get tournaments
const tournaments = await api.tournaments.list()

// Create tournament
const tournament = await api.tournaments.create({
  name: 'New Tournament',
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

# Get tournaments
tournaments = client.tournaments.list

# Create tournament
tournament = client.tournaments.create(
  name: 'New Tournament',
  discipline_id: 1,
  location_id: 1
)
```

## Examples

### Complete Tournament Workflow

> **⚠️ Planned / future design.** This SDK sketch is illustrative only; no
> `carambus-api-client` package or JSON tournament CRUD exists today.

```javascript
// 1. Create tournament
const tournament = await api.tournaments.create({
  name: 'Championship 2024',
  discipline_id: 1,
  location_id: 1,
  start_date: '2024-02-01',
  max_participants: 16
})

// 2. Add participants
for (const player of players) {
  await api.tournaments.addParticipant(tournament.id, player.id)
}

// 3. Select the tournament mode / game plan
//    (real HTML/Turbo actions: finalize_modus → select_modus)
await api.tournaments.selectModus(tournament.id, { tournament_plan_id: planId })

// 4. Start tournament
await api.tournaments.start(tournament.id)

// 5. Subscribe to real-time updates
const subscription = consumer.subscriptions.create(
  { channel: "TournamentChannel", tournament_id: tournament.id },
  {
    received(data) {
      updateTournamentDisplay(data)
    }
  }
)
```

### Real-time Scoreboard Integration

```javascript
// Connect to scoreboard
const scoreboard = consumer.subscriptions.create(
  { channel: "ScoreboardChannel", location_id: 1 },
  {
    received(data) {
      // Update scoreboard display
      document.getElementById('scoreboard').innerHTML = 
        generateScoreboardHTML(data)
    }
  }
)

// Update table scores
async function updateScore(tableId, player, points) {
  await api.tableMonitors.update(tableId, {
    [`balls_${player}`]: points
  })
}
```

## Support

For API support and questions:

- **Documentation**: see above (this page)
- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)

---

*This API documentation is maintained by the Carambus development team. For questions or contributions, please see the [Contributing Guide](../developers/developer-guide.en.md#contributing).* 