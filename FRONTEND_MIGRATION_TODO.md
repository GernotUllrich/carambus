# Frontend Migration zu STI - TODO

## Probleme durch STI Migration

### 1. Controller Änderungen nötig

**`app/controllers/international_controller.rb`:**
```ruby
# ALT:
@upcoming_tournaments = InternationalTournament.upcoming
@recent_videos = Video.recent.limit(12)  # ❌ Tabelle gelöscht!
@recent_results = InternationalResult.includes(...)   # ❌ Tabelle gelöscht!

# NEU:
@upcoming_tournaments = InternationalTournament.where('date >= ?', Date.today)
# Videos: TODO - müssen wir noch klären
# Results: GameParticipations verwenden statt InternationalResult
```

**`app/controllers/international/tournaments_controller.rb`:**
```ruby
# ALT:
@tournaments = InternationalTournament.by_type(params[:type])  # ❌ Scope existiert nicht
@results = @tournament.international_results                   # ❌ Association gelöscht
@videos = @tournament.international_videos                     # ❌ Association gelöscht

# NEU:
@tournaments = InternationalTournament.where("data->>'tournament_type' = ?", params[:type])
@results = GameParticipation.joins(:game).where(games: { tournament_id: @tournament.id })
# Videos: TODO
```

### 2. View Änderungen nötig

**Alle Views in `app/views/international/`:**

| Alt                            | Neu                       | Status |
|--------------------------------|---------------------------|--------|
| `tournament.name`              | `tournament.title`        | ❌     |
| `tournament.location`          | `tournament.location_text`| ❌     |
| `tournament.start_date`        | `tournament.date`         | ❌     |
| `tournament.videos` | TBD                    | ❌     |
| `tournament.international_results` | `tournament.game_participations` | ❌ |
| `tournament.international_participations` | `tournament.seedings` | ❌ |

### 3. Model Helper Methoden

**`InternationalTournament` braucht:**
```ruby
# Für View-Kompatibilität
def name
  title  # Alias
end

def location
  location_text  # Alias
end

def start_date
  date&.to_date  # Alias
end

def date_range
  return date.to_s unless end_date
  "#{date.strftime('%d %b')} - #{end_date.strftime('%d %b %Y')}"
end

def official_umb?
  json_data['umb_official'] == true
end

# Scopes für Controller
scope :upcoming, -> { where('date >= ?', Date.today) }
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }
scope :official_umb, -> { where("data->>'umb_official' = ?", 'true') }
scope :in_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) }
```

### 4. Videos

**Problem:** `international_videos` Tabelle wurde gedroppt!

**Optionen:**
a) Videos Feature entfernen (vorerst)
b) Videos in `data` JSONB speichern
c) Eigene `videos` Tabelle für alle Turniere (international + national)

**Empfehlung:** Option A - erstmal entfernen, später besser neu aufbauen

### 5. Results/Rankings

**ALT:** `InternationalResult` (separate Tabelle)
**NEU:** `GameParticipation` (wie bei normalen Turnieren)

Views müssen angepasst werden um Rankings aus GameParticipations zu berechnen.

## Migrations-Plan

### Phase 1: InternationalTournament Model erweitern ✅
- Helper Methoden für View-Kompatibilität
- Scopes für Controller

### Phase 2: Controller anpassen
- `international_controller.rb`
- `international/tournaments_controller.rb`
- Videos-Features temporär entfernen

### Phase 3: Views anpassen
- `tournament.name` → `tournament.title`
- `tournament.location` → `tournament.location_text`
- Videos-Sections auskommentieren
- Results aus GameParticipations

### Phase 4: Routes prüfen
- Sicherstellen dass Routen funktionieren

## Priorität

1. **HOCH**: Model Helper Methoden (View-Kompatibilität)
2. **MITTEL**: Controller anpassen
3. **MITTEL**: Views anpassen (Videos entfernen)
4. **NIEDRIG**: Videos neu implementieren (später)
