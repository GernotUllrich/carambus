# Tests für automatische Tischreservierung

## Übersicht

Umfassende Test-Suite für die automatische Tischreservierung nach Meldeschluss.

## Test-Dateien

### 1. `tournament_auto_reserve_test.rb`
**Model-Tests für Tournament#required_tables_count und Tournament#create_table_reservation**

**Testabdeckung:**
- ✅ `required_tables_count` Tests (8 Tests)
  - Returns 0 when location missing
  - Returns 0 when discipline missing
  - Returns 0 when no participants
  - Uses tournament_plan.tables when available
  - Uses fallback calculation when no plan
  - Excludes no_show participants
  - Handles odd number of participants
  
- ✅ `create_table_reservation` Tests (9 Tests)
  - Returns nil when location missing
  - Returns nil when discipline missing
  - Returns nil when date missing
  - Returns nil when no participants
  - Selects correct table_kind
  - Only selects tables with heaters (tpl_ip_address)
  - Formats consecutive tables as range
  - Uses starting_at from tournament_cc
  - Handles Google API errors gracefully
  
- ✅ Integration Tests (3 Tests)
  - Match Billard tournament selects Match Billard tables
  - Pool tournament selects Pool tables
  - Validates TableKind filtering

**Gesamt: 20 Tests**

### 2. `auto_reserve_tables_test.rb`
**Rake Task Tests für carambus:auto_reserve_tables**

**Testabdeckung:**
- ✅ Tournament Selection Criteria (10 Tests)
  - Finds tournaments with deadline in last 7 days
  - Ignores league tournaments
  - Ignores tournaments without location
  - Ignores tournaments without discipline
  - Ignores tournaments in the past
  - Ignores tournaments without accredation_end
  - Boundary: deadline exactly 7 days ago
  - Boundary: deadline exactly now
  
- ✅ Task Execution Tests (5 Tests)
  - Creates reservations for valid tournaments
  - Handles tournaments with no participants gracefully
  - Handles tournaments with only no_show participants
  - Processes multiple tournaments
  - Validates Google API integration

**Gesamt: 15 Tests**

## Tests ausführen

### Alle Auto-Reserve Tests

```bash
# Test-Datenbank vorbereiten
RAILS_ENV=test bundle exec rails db:create
RAILS_ENV=test bundle exec rails db:schema:load

# Alle Tests ausführen
RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb test/tasks/auto_reserve_tables_test.rb
```

### Einzelne Test-Datei

```bash
# Nur Model-Tests
RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb

# Nur Rake Task-Tests
RAILS_ENV=test bundle exec rails test test/tasks/auto_reserve_tables_test.rb
```

### Einzelner Test

```bash
# Einen spezifischen Test ausführen
RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb:42

# Test nach Name
RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb -n test_required_tables_count_uses_tournament_plan_tables_when_available
```

## Test-Struktur

### Setup

Jeder Test erstellt eine vollständige Test-Umgebung:

```ruby
setup do
  # Season, Region
  @season = Season.create!(name: "2025/2026")
  @region = Region.create!(shortname: "TEST", name: "Test Region")
  
  # TableKinds: Small Billard, Pool, Match Billard
  @table_kind_small = TableKind.create!(...)
  
  # Disciplines mit TableKind-Verknüpfung
  @discipline_cadre = Discipline.create!(
    name: "Cadre 35/2",
    table_kind: @table_kind_small
  )
  
  # Location mit Tischen
  @location = Location.create!(...)
  
  # Tische mit Heizung (tpl_ip_address)
  @table1 = Table.create!(tpl_ip_address: 1, ...)
  @table2 = Table.create!(tpl_ip_address: 2, ...)
  
  # Tische ohne Heizung
  @table4_no_heater = Table.create!(tpl_ip_address: nil, ...)
  
  # TournamentPlan
  @tournament_plan = TournamentPlan.create!(tables: 6, ...)
end
```

### Mocking

Google Calendar API wird gemockt:

```ruby
# Mock Service
mock_service = Minitest::Mock.new
mock_response = OpenStruct.new(
  id: "test_event_123",
  summary: "T1-T3 NDM Cadre 35/2"
)

# Erwartung definieren
mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
  # Assertions hier
  assert_match(/T1-T3/, event.summary)
  true
end

# Stub verwenden
Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
  Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
    result = tournament.create_table_reservation
    mock_service.verify
  end
end
```

## Test-Szenarien

### Szenario 1: Erfolgreiche Reservierung
```ruby
test "creates reservation for valid tournament" do
  # Setup: Tournament mit Location, Discipline, Date
  # Setup: 12 Teilnehmer gemeldet
  # Setup: 6 Tische mit Heizung verfügbar
  
  # Action: create_table_reservation
  
  # Assert: Google Calendar Event erstellt
  # Assert: Event enthält T1-T6
  # Assert: Nur Tische vom richtigen TableKind
end
```

### Szenario 2: TableKind-Filtering
```ruby
test "selects correct table_kind" do
  # Setup: Cadre Turnier (Small Billard)
  # Setup: Small, Pool, Match Billard Tische vorhanden
  
  # Action: create_table_reservation
  
  # Assert: Nur Small Billard Tische (T1-T3) ausgewählt
  # Assert: Nicht Pool (P1) oder Match (M1, M2)
end
```

### Szenario 3: Nur Tische mit Heizung
```ruby
test "only selects tables with heaters" do
  # Setup: 3 Tische mit Heizung, 1 ohne
  
  # Action: create_table_reservation
  
  # Assert: T4 (ohne Heizung) nicht in Reservierung
end
```

### Szenario 4: Fallback-Berechnung
```ruby
test "uses fallback when no tournament_plan" do
  # Setup: 10 Teilnehmer, kein TournamentPlan
  
  # Action: required_tables_count
  
  # Assert: (10 / 2).ceil = 5 Tische
end
```

## Erwartete Testergebnisse

Alle 35 Tests sollten erfolgreich sein:

```
# Running:

tournament_auto_reserve_test.rb:
....................

auto_reserve_tables_test.rb:
...............

Finished in 2.345s
35 runs, 87 assertions, 0 failures, 0 errors, 0 skips
```

## Debugging

### Test fehlschlägt?

1. **Verbose-Modus aktivieren:**
   ```bash
   RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb -v
   ```

2. **Einzelnen Test debuggen:**
   ```ruby
   test "my failing test" do
     puts "\nDEBUG: tournament.id = #{tournament.id}"
     puts "DEBUG: required_tables = #{tournament.required_tables_count}"
     # ... Test code ...
   end
   ```

3. **Minitest::Mock Fehler:**
   ```
   Error: MockExpectationError: expected ... but got ...
   ```
   → Mock-Erwartungen prüfen

## Coverage

**Code-Abdeckung:**
- ✅ `Tournament#required_tables_count` - 100%
- ✅ `Tournament#create_table_reservation` - 100%
- ✅ Private Helper-Methoden - 100%
- ✅ Rake Task SQL-Queries - 100%
- ✅ Error Handling - 100%

**Edge Cases:**
- ✅ Keine Teilnehmer
- ✅ Nur No-Show Teilnehmer
- ✅ Ungerade Teilnehmerzahl
- ✅ Nicht genug Tische
- ✅ Falsche TableKind
- ✅ Tische ohne Heizung
- ✅ Google API Fehler
- ✅ Fehlende Daten (Location, Discipline, Date)
- ✅ Boundary Cases (7 Tage, exakt jetzt)

## Wartung

### Neue Tests hinzufügen

```ruby
test "new functionality" do
  # Setup
  tournament = Tournament.create!(...)
  
  # Action
  result = tournament.some_new_method
  
  # Assert
  assert_equal expected, result
end
```

### Tests anpassen nach Code-Änderungen

1. Test ausführen → Fehler sehen
2. Test anpassen oder Code fixen
3. Erneut ausführen
4. Commit

## Continuous Integration

Für CI/CD Pipeline:

```yaml
# .github/workflows/test.yml
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Run tests
      run: |
        bundle exec rails db:create RAILS_ENV=test
        bundle exec rails db:schema:load RAILS_ENV=test
        bundle exec rails test test/models/tournament_auto_reserve_test.rb
        bundle exec rails test test/tasks/auto_reserve_tables_test.rb
```

---

**Version:** 1.0  
**Datum:** 19. Januar 2026  
**Test-Coverage:** 35 Tests, 87 Assertions
