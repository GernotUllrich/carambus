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

## Base URL
```
Development: http://localhost:3000
Production: https://carambus.de
```

## Response Format

All API responses are in JSON format:

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

## Core Endpoints

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

### Tournament Actions

#### Start Tournament
```http
POST /tournaments/{id}/start
```

#### Reset Tournament
```http
POST /tournaments/{id}/reset
```

#### Generate Game Plan
```http
POST /tournaments/{id}/generate_game_plan
```

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

#### Update Table Monitor
```http
PATCH /table_monitors/{id}
```

**Request Body:**
```json
{
  "table_monitor": {
    "balls_a": 16,
    "balls_b": 12
  }
}
```

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

## Data Synchronization API

### External Data Sources

#### BA (Billiards Association) Sync
```http
POST /api/sync/ba/players
POST /api/sync/ba/tournaments
```

#### CC (Competition Center) Sync
```http
POST /api/sync/cc/competitions
POST /api/sync/cc/results
```

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

// 3. Generate game plan
await api.tournaments.generateGamePlan(tournament.id)

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

- **Documentation**: [API.md](API.md)
- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)

---

*This API documentation is maintained by the Carambus development team. For questions or contributions, please see the [Contributing Guide](DEVELOPER_GUIDE.md#contributing).* 