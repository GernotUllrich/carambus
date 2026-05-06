# Placeholder Records System

## Übersicht

Das Placeholder Records System ermöglicht das Speichern von Datensätzen (z.B. Turniere), auch wenn erforderliche Referenzen (Discipline, Season, Location, Organizer) nicht verfügbar sind.

Statt:
- ❌ Daten zu verwerfen
- ❌ Falsche Werte zu raten
- ❌ Validierung zu deaktivieren

Verwenden wir:
- ✅ Spezielle "Unknown" Platzhalter-Records
- ✅ Admin-Interface zur Nachbesserung
- ✅ Automatische Fix-Tools wo möglich

---

## Komponenten

### 1. Platzhalter-Records

Spezielle Records mit erkennbaren Namen und Metadaten:

```ruby
# Season
name: "Unknown Season"
data: { placeholder: true, description: "..." }

# Discipline  
name: "Unknown Discipline"
data: { placeholder: true, description: "..." }

# Location
name: "Unknown Location"
address: "Location not specified"
data: { placeholder: true, description: "..." }

# Region (für Organizer)
shortname: "UNKNOWN"
name: "Unknown Region"
data: { placeholder: true, description: "..." }
```

### 2. PlaceholderAware Concern

Erweitert Models um Platzhalter-Funktionalität:

```ruby
class InternationalTournament < Tournament
  include PlaceholderAware
  
  def self.placeholder_fields
    {
      discipline_id: -> { Discipline.find_by(name: 'Unknown Discipline')&.id },
      season_id: -> { Season.find_by(name: 'Unknown Season')&.id },
      location_id: -> { Location.find_by(name: 'Unknown Location')&.id },
      organizer_id: -> { Region.find_by(shortname: 'UNKNOWN')&.id }
    }
  end
end
```

**Scopes:**
```ruby
# Turniere mit Platzhalter-Referenzen
InternationalTournament.with_placeholders

# Vollständige Turniere
InternationalTournament.complete
```

**Instanz-Methoden:**
```ruby
tournament.has_placeholders?              # => true/false
tournament.is_placeholder_field?(:discipline_id)  # => true/false
tournament.placeholder_field_names        # => [:discipline_id, :season_id]
tournament.placeholder_description        # => "Discipline is unknown, Season is unknown"
```

### 3. UMB Scraper Integration

Der Scraper verwendet automatisch Platzhalter wenn Daten fehlen:

```ruby
# Vorher
discipline = Discipline.find_by(name: 'Dreiband') || Discipline.first  # ❌ Errät

# Nachher
discipline = detect_discipline_from_name(tournament_name) ||           # ✅ Versucht zu erkennen
             Discipline.find_by(name: 'Unknown Discipline')            # ✅ Verwendet Platzhalter
             
# NICHT verwenden:
discipline = detect_discipline_from_name(tournament_name) ||
             Discipline.first                                          # ❌ Errät irgendeinen!
```

### 4. Admin Interface

**URL:** `/admin/incomplete_records`

**Features:**
- 📊 Dashboard mit Statistiken
- 📋 Liste aller incomplete Records
- ✏️ Einzelne Records bearbeiten
- 🤖 Auto-Fix für Disciplines

### 5. Rake Tasks

```bash
# Platzhalter erstellen
rake placeholders:create

# Incomplete Records auflisten
rake placeholders:list_incomplete

# Statistiken anzeigen
rake placeholders:stats

# Auto-Fix für Disciplines
rake placeholders:auto_fix_disciplines

# Interaktive Korrektur
rake placeholders:fix_interactive
```

---

## Installation

### 1. Seeds ausführen

```bash
cd /Users/gullrich/DEV/carambus/carambus_api
rails db:seed:placeholder_records
```

Oder manuell:

```bash
rails runner "load Rails.root.join('db/seeds/placeholder_records.rb')"
```

### 2. Vorhandene Records migrieren (Optional)

Wenn bereits Turniere mit `Discipline.first` o.ä. existieren:

```bash
# Prüfen
rake placeholders:stats

# UMB Disciplines korrigieren
rake umb:fix_disciplines
```

---

## Verwendung

### Beim Scraping

```ruby
# UMB Scraper (bereits implementiert)
scraper = UmbScraper.new
scraper.scrape_future_tournaments  # Verwendet automatisch Platzhalter

# Manuelles Erstellen
tournament = InternationalTournament.create(
  title: "Unknown Tournament",
  date: Date.today,
  discipline_id: Discipline.find_by(name: 'Unknown Discipline')&.id,
  season_id: Season.find_by(name: 'Unknown Season')&.id,
  # ...
)
```

### Incomplete Records finden

```ruby
# Alle incomplete Turniere
incomplete = InternationalTournament.with_placeholders

# Nur vollständige
complete = InternationalTournament.complete

# Prüfen eines einzelnen Records
tournament.has_placeholders?  # => true
tournament.placeholder_field_names  # => [:discipline_id, :season_id]
```

### Admin-Interface verwenden

1. **Dashboard öffnen:**
   ```
   http://localhost:3000/admin/incomplete_records
   ```

2. **Statistiken prüfen:**
   - Gesamtanzahl
   - Complete vs. Incomplete
   - Breakdown nach Feld

3. **Record bearbeiten:**
   - Klick auf "Fix"
   - Felder aus Dropdowns auswählen
   - "Update Tournament" klicken

4. **Auto-Fix verwenden:**
   - "Auto-Fix Disciplines" Button
   - Basiert auf Turniernamen
   - Zeigt Anzahl der korrigierten Records

---

## API

### Controller Endpoints

```ruby
# GET /admin/incomplete_records
# Liste aller incomplete Records mit Pagination

# GET /admin/incomplete_records/:id
# Einzelnen Record bearbeiten

# PATCH /admin/incomplete_records/:id
# Record aktualisieren

# POST /admin/incomplete_records/auto_fix_all
# Alle Disciplines automatisch korrigieren
```

### Concern Methods

```ruby
# Klassen-Methoden
InternationalTournament.placeholder_fields        # => Hash der Platzhalter-Felder
InternationalTournament.with_placeholders         # => ActiveRecord Scope
InternationalTournament.complete                  # => ActiveRecord Scope
InternationalTournament.placeholder_conditions    # => Array von SQL Conditions

# Instanz-Methoden
tournament.has_placeholders?                      # => Boolean
tournament.is_placeholder_field?(field)           # => Boolean
tournament.placeholder_field_names                # => Array von Symbolen
tournament.placeholder_description                # => String
tournament.is_placeholder?                        # => Boolean (für Platzhalter-Records selbst)
```

---

## Beispiele

### Beispiel 1: Record mit Unknown Discipline

```ruby
tournament = InternationalTournament.create(
  title: "World Cup 3-Cushion",
  date: Date.today,
  discipline_id: Discipline.find_by(name: 'Unknown Discipline').id,
  season_id: Season.current_season.id,
  # ...
)

# Prüfen
tournament.has_placeholders?  # => true
tournament.is_placeholder_field?(:discipline_id)  # => true
tournament.placeholder_description  # => "Discipline is unknown"

# Auto-Fix
scraper = UmbScraper.new
detected = scraper.send(:find_discipline_from_name, tournament.title)
tournament.update(discipline: detected)  # => Dreiband halb

# Nachprüfen
tournament.reload.has_placeholders?  # => false
```

### Beispiel 2: Bulk Auto-Fix

```ruby
# Via Rake
rake placeholders:auto_fix_disciplines

# Oder in Rails Console
scraper = UmbScraper.new
unknown_discipline = Discipline.find_by(name: 'Unknown Discipline')

InternationalTournament.where(discipline: unknown_discipline).find_each do |tournament|
  detected = scraper.send(:find_discipline_from_name, tournament.title)
  tournament.update(discipline: detected) if detected != unknown_discipline
end
```

### Beispiel 3: Admin-Workflow

```
1. Admin öffnet /admin/incomplete_records
2. Sieht: 50 incomplete Turniere
   - 30 mit Unknown Discipline
   - 15 mit Unknown Season
   - 5 mit Unknown Location
3. Klickt "Auto-Fix Disciplines"
   → 25 von 30 automatisch korrigiert
4. Für restliche 5: Manuell korrigieren
   - Klick auf "Fix"
   - Discipline aus Dropdown wählen
   - Update
5. Ergebnis: 45 complete, 5 incomplete verbleibend
```

---

## Best Practices

### DO ✅

1. **Platzhalter verwenden** statt `first` oder `nil`:
   ```ruby
   # Gut
   discipline = find_discipline(...) ||
                Discipline.find_by(name: 'Unknown Discipline')
   
   # Schlecht
   discipline = find_discipline(...) || Discipline.first
   ```

2. **Daten vollständig importieren**:
   - Auch unvollständige Turniere speichern
   - Später im Admin-Interface korrigieren

3. **Auto-Fix wo möglich**:
   - Discipline aus Turniernamen
   - Season aus Datum
   - Location aus Text

4. **Regelmäßig prüfen**:
   ```bash
   rake placeholders:stats
   ```

### DON'T ❌

1. **NIEMALS `.first` als Fallback verwenden**:
   ```ruby
   # ❌ SEHR SCHLECHT - Verwendet irgendeinen zufälligen Record!
   discipline = find_discipline(...) || Discipline.first
   season = find_season(...) || Season.first
   region = find_region(...) || Region.first
   
   # ✅ GUT - Verwendet den Platzhalter
   discipline = find_discipline(...) || Discipline.find_by(name: 'Unknown Discipline')
   season = find_season(...) || Season.find_by(name: 'Unknown Season')
   region = find_region(...) || Region.find_by(shortname: 'UNKNOWN')
   ```
   
   **Warum ist `.first` problematisch?**
   - Gibt den ersten Record in der Datenbank zurück (basierend auf ID)
   - Hat **nichts** mit dem Turnier zu tun
   - Macht Daten inkonsistent und unbrauchbar
   - Ein Turnier "World Cup 3-Cushion" bekommt dann z.B. "Pool" als Discipline!

2. **Nicht überspringen**:
   ```ruby
   # ❌ Schlecht
   next unless discipline  # Verwirft wertvolle Daten
   
   # ✅ Gut
   discipline ||= Discipline.find_by(name: 'Unknown Discipline')
   # Speichert mit Platzhalter, kann später korrigiert werden
   ```

3. **Nicht Validierung deaktivieren** ohne Platzhalter:
   ```ruby
   # ❌ Schlecht
   tournament.save(validate: false)  # mit discipline_id = nil
   
   # ✅ Gut
   tournament.discipline_id = Discipline.find_by(name: 'Unknown Discipline').id
   tournament.save(validate: false)
   ```

---

## Troubleshooting

### Problem: Platzhalter existieren nicht

```bash
# Lösung: Seeds ausführen
rake placeholders:create

# Oder manuell
rails runner "load Rails.root.join('db/seeds/placeholder_records.rb')"
```

### Problem: Keine incomplete Records sichtbar

```ruby
# Prüfen ob Platzhalter verwendet werden
InternationalTournament.with_placeholders.count  # => 0 ?

# Prüfen ob Platzhalter IDs korrekt sind
InternationalTournament.placeholder_fields
```

### Problem: Auto-Fix funktioniert nicht

```ruby
# Prüfen ob Discipline-Erkennung funktioniert
scraper = UmbScraper.new
scraper.send(:find_discipline_from_name, "World Cup 3-Cushion")
# => sollte Discipline zurückgeben

# Test ausführen
rake umb:test_improvements
```

### Problem: Admin-Interface nicht erreichbar

```ruby
# Routes prüfen
rake routes | grep incomplete

# Controller prüfen
Admin::IncompleteRecordsController  # sollte existieren
```

---

## Migration Checklist

- [ ] Seeds ausgeführt (`rake placeholders:create`)
- [ ] UMB Scraper updated (automatisch)
- [ ] Routes hinzugefügt (automatisch)
- [ ] Admin-Interface getestet
- [ ] Bestehende Turniere geprüft (`rake placeholders:stats`)
- [ ] Auto-Fix ausgeführt (`rake placeholders:auto_fix_disciplines`)
- [ ] Verbleibende incomplete Records manuell korrigiert

---

## Support & Weiterentwicklung

### Geplante Erweiterungen

- [ ] Location-Auto-Matching basierend auf Text
- [ ] Season-Auto-Fix basierend auf Datum
- [ ] Organizer-Erkennung aus Turnierdaten
- [ ] Bulk-Edit im Admin-Interface
- [ ] Email-Benachrichtigungen bei neuen incomplete Records
- [ ] API-Endpoint für externe Tools

### Fragen & Issues

Bei Problemen:
1. Logs prüfen: `tail -f log/development.log`
2. Rake Task ausführen: `rake placeholders:stats`
3. Admin-Interface öffnen: `/admin/incomplete_records`
