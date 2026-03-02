# UMB Scraper - Automatische Erstellung von Location, Season und Organizer

## Änderungen

Der UMB Scraper wurde erweitert, um automatisch fehlende Referenzen zu erstellen, anstatt auf Placeholder oder manuelle Eingabe zu warten.

### 1. Location aus "Place" erstellen

**Problem**: UMB gibt immer einen "Place" mit Stadt und Land in Klammern an (z.B. "Nice (France)")

**Lösung**: Automatische Location-Erstellung beim Scraping

#### Neue Methoden

```ruby
# Parse location text to extract city and country code
def parse_location_components(location_text)
  # Returns: { city: "Nice", country_code: "FR", full_text: "Nice (France)" }
end

# Convert country name to ISO 2-letter code
def country_name_to_code(country_name)
  # Maps: "France" => "FR", "Germany" => "DE", etc.
  # Supports 20+ countries in multiple languages
end

# Find or create Location from location_text
def find_or_create_location_from_text(location_text)
  # 1. Check if location already exists
  # 2. Parse city and country code
  # 3. Create new Location if needed
  # Returns: Location record or nil
end
```

#### Beispiele

```ruby
# Input: "Nice (France)"
# Output: Location { name: "Nice", country_code: "FR", address: "Nice (France)" }

# Input: "ISTANBUL (Turkey)"
# Output: Location { name: "Istanbul", country_code: "TR", address: "ISTANBUL (Turkey)" }

# Input: "N/A (Egypt)"
# Output: Location { name: "Egypt", country_code: "EG", address: "N/A (Egypt)" }
```

### 2. Season aus "Starts on" erstellen

**Problem**: Billiard-Saison beginnt am 1. Juli, nicht am 1. Januar

**Lösung**: Automatische Season-Erstellung basierend auf Turnierdatum

#### Neue Methode

```ruby
# Find or create Season from date (billiard season starts July 1st)
def find_or_create_season_from_date(date)
  # 1. Try existing Season.season_from_date logic
  # 2. If season doesn't exist, create it
  # 3. Season runs from July 1st to June 30th
  # Returns: Season record or nil
end
```

#### Logik

```ruby
# Beispiel: Turnier am 15. März 2010
# → Saison 2009/2010 (Start: 01.07.2009, Ende: 30.06.2010)

# Beispiel: Turnier am 15. September 2010
# → Saison 2010/2011 (Start: 01.07.2010, Ende: 30.06.2011)

# Formel:
if date.month >= 7
  season_start_year = date.year
else
  season_start_year = date.year - 1
end
season_end_year = season_start_year + 1
season_name = "#{season_start_year}/#{season_end_year}"
```

#### Erstellt automatisch

```ruby
Season.find_or_create_by!(name: "2009/2010") do |s|
  s.ba_id = nil
  s.data = {
    created_from: 'umb_scraper',
    start_date: Date.new(2009, 7, 1),
    end_date: Date.new(2010, 6, 30)
  }.to_json
end
```

### 3. UMB als Organizer erstellen

**Problem**: UMB-Turniere brauchen einen Organizer

**Lösung**: Automatische Erstellung der UMB Region

#### Neue Methode

```ruby
# Find or create UMB organizer region
def find_or_create_umb_organizer
  Region.find_or_create_by!(shortname: 'UMB') do |r|
    r.name = 'Union Mondiale de Billard'
    r.email = 'info@umb-carom.org'
    r.website = 'https://www.umb-carom.org'
    r.scrape_data = {
      created_from: 'umb_scraper',
      description: 'World governing body for carom billiards',
      created_at: Time.current.iso8601
    }
  end
end
```

#### Erstellt automatisch

```ruby
Region {
  id: auto,
  shortname: "UMB",
  name: "Union Mondiale de Billard",
  email: "info@umb-carom.org",
  website: "https://www.umb-carom.org",
  scrape_data: {
    created_from: "umb_scraper",
    description: "World governing body for carom billiards"
  }
}
```

## Integration

Die neuen Methoden werden an drei Stellen im Scraper aufgerufen:

### 1. Bei `scrape_tournament_details` (Detail-Scraping)

```ruby
# 1. LOCATION: Create Location from location_text if needed
if tournament.location_id.blank? && tournament.location_text.present?
  location = find_or_create_location_from_text(tournament.location_text)
  tournament.location_id = location&.id if location
end

# 2. SEASON: Create Season from date if needed
if tournament.season_id.blank? && tournament.date.present?
  season = find_or_create_season_from_date(tournament.date)
  tournament.season_id = season&.id if season
end

# 3. ORGANIZER: Set UMB as organizer
if tournament.organizer_id.blank?
  umb_region = find_or_create_umb_organizer
  tournament.organizer_id = umb_region&.id
  tournament.organizer_type = 'Region'
end
```

### 2. Bei Future Tournaments Scraping

```ruby
# Enhanced tournament creation
season = find_or_create_season_from_date(dates[:start_date])
umb_organizer = find_or_create_umb_organizer
location_record = find_or_create_location_from_text(data[:location])

tournament = InternationalTournament.new(
  # ...
  location_id: location_record&.id,
  season_id: season&.id,
  organizer_id: umb_organizer&.id,
  organizer_type: 'Region'
)
```

### 3. Bei Archive Scraping

Gleiche Logik wie bei Future Tournaments.

## Unterstützte Länder

Der Country-Code-Mapper unterstützt:

| Land | Code | Varianten |
|------|------|-----------|
| Frankreich | FR | France, FR |
| Deutschland | DE | Germany, DE, Deutschland |
| Belgien | BE | Belgium, BE, Belgique, België |
| Niederlande | NL | Netherlands, NL, Nederland |
| Spanien | ES | Spain, ES, España |
| Italien | IT | Italy, IT, Italia |
| Türkei | TR | Turkey, TR, Türkiye |
| Österreich | AT | Austria, AT, Österreich |
| Schweiz | CH | Switzerland, CH, Schweiz |
| Ägypten | EG | Egypt, EG |
| Korea | KR | Korea, KR, South Korea |
| Vietnam | VN | Vietnam, VN |
| USA | US | USA, US, United States |
| Luxemburg | LU | Luxembourg, LU |
| Portugal | PT | Portugal, PT |
| Griechenland | GR | Greece, GR |
| Polen | PL | Poland, PL |
| Tschechien | CZ | Czech Republic, CZ |
| Slowenien | SI | Slovenia, SI |
| Dänemark | DK | Denmark, DK |

**Fallback**: Wenn das Land nicht in der Tabelle ist, werden die ersten 2 Buchstaben großgeschrieben (z.B. "India" → "IN")

## Testing

### Test 1: Location-Erstellung

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

rails runner "
scraper = UmbScraper.new
location = scraper.send(:find_or_create_location_from_text, 'Nice (France)')
puts location.inspect
"
```

**Erwartetes Ergebnis**:
```ruby
#<Location id: xxx, name: "Nice", address: "Nice (France)", data: "{\"country_code\":\"FR\",\"created_from\":\"umb_scraper\"...}">
```

### Test 2: Season-Erstellung

```bash
rails runner "
scraper = UmbScraper.new
season = scraper.send(:find_or_create_season_from_date, Date.new(2010, 3, 15))
puts season.name
"
```

**Erwartetes Ergebnis**: `2009/2010`

### Test 3: UMB Organizer

```bash
rails runner "
scraper = UmbScraper.new
umb = scraper.send(:find_or_create_umb_organizer)
puts umb.inspect
"
```

**Erwartetes Ergebnis**:
```ruby
#<Region id: xxx, shortname: "UMB", name: "Union Mondiale de Billard", ...>
```

### Test 4: Komplettes Scraping

```bash
rake umb:scrape_future
# oder
rake umb:scrape_detail[TOURNAMENT_ID]
```

Danach prüfen:
```bash
rails runner "
t = InternationalTournament.last
puts 'Location: ' + t.location_id.inspect
puts 'Season: ' + t.season_id.inspect  
puts 'Organizer: ' + t.organizer_id.inspect
"
```

## Vorteile

1. **Keine manuellen Fixes mehr**: Turniere sind sofort komplett mit allen Referenzen
2. **Konsistente Daten**: Locations werden einmal erstellt und wiederverwendet
3. **Historische Daten**: Auch alte Turniere (vor 2009) bekommen automatisch Seasons
4. **Weniger Placeholder**: Statt "Unknown Location/Season/Organizer" werden echte Records erstellt

## Rückwärtskompatibilität

- ✅ Existing Turniere werden nicht verändert
- ✅ Placeholder-System bleibt intakt für andere Quellen
- ✅ Admin-Interface für manuelle Korrekturen bleibt verfügbar
- ✅ Locations werden nur erstellt, wenn sie nicht existieren (keine Duplikate)

## Nächste Schritte

1. Server neu starten
2. Future Tournaments neu scrapen: `rake umb:scrape_future`
3. Prüfen: Werden Locations/Seasons automatisch erstellt?
4. Optional: Bestehende Turniere migrieren mit `rake placeholders:migrate_to_placeholders`
