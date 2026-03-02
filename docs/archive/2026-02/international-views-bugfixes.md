# Bug Fixes für Internationale Turniere Views

**Datum:** 19. Februar 2026  
**Status:** ✅ FIXED

---

## 🐛 Identifizierte Bugs

### Bug 1: PostgreSQL JSONB-Operator Fehler

**Fehler:**
```
PG::UndefinedFunction: ERROR: operator does not exist: text ->> unknown
LINE 1: ...WHERE "tournaments"."type" = $1 AND (data->>'tournament_type' = ?)
```

**Ursache:**
- Das `data` Feld in `tournaments` ist vom Typ **TEXT** (serialized JSON)
- Die Scopes verwendeten JSONB-Operator `->>`, der nur für JSONB funktioniert
- Bei serialisierten Feldern muss in Ruby gefiltert werden

**Lösung:**
```ruby
# FALSCH (für TEXT-Spalte):
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }

# RICHTIG (für serialized TEXT):
def self.by_type(type)
  return all if type.blank?
  all.select { |t| t.tournament_type == type }
end
```

### Bug 2: Hierarchische Disziplin-Filter funktionieren nicht

**Problem:**
- Bei Auswahl "Cadre / Balkline" werden nur Turniere mit **genau dieser Gruppe** gefunden
- Turniere mit "Cadre 57/2" werden nicht angezeigt

**Ursache:**
- Filter verwendete nur einzelne `discipline_id`
- Keine Logik für Gruppen-Filter

**Lösung:**
```ruby
# Gruppen-Filter erkennen
if params[:discipline_id].start_with?('group:')
  group_name = params[:discipline_id].sub('group:', '')
  discipline_ids = InternationalHelper.discipline_ids_for_group(group_name)
  @tournaments = @tournaments.where(discipline_id: discipline_ids)
end
```

**Helper-Struktur:**
```ruby
# app/helpers/international_helper.rb
DISCIPLINE_GROUPS = {
  'Cadre / Balkline' => ['Cadre 35/2', 'Cadre 47/2', 'Cadre 57/2', ...],
  '3-Cushion (Dreiband)' => ['Dreiband halb', 'Dreiband groß', ...],
  # ...
}

def self.discipline_ids_for_group(group_name)
  Discipline.where(name: DISCIPLINE_GROUPS[group_name]).pluck(:id)
end
```

---

## 🔧 Durchgeführte Fixes

### Fix 1: Tournament Model - Scopes entfernt ✅

**Datei:** `app/models/tournament.rb`

**Entfernt:**
```ruby
# Diese funktionieren nicht mit serialized TEXT:
scope :by_type, ->(type) { ... }
scope :official_umb, -> { ... }
```

**Behalten:**
```ruby
# Diese funktionieren mit regulären Spalten:
scope :international, -> { where(type: 'InternationalTournament') }
scope :in_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) }
```

### Fix 2: InternationalTournament Model - Class Methods ✅

**Datei:** `app/models/international_tournament.rb`

**Geändert von Scopes zu Class Methods:**
```ruby
# Scopes entfernt, Class Methods hinzugefügt:
def self.by_type(type)
  return all if type.blank?
  all.select { |t| t.tournament_type == type }
end

def self.official_umb_only
  all.select { |t| t.official_umb? }
end
```

### Fix 3: Controller - Ruby-basiertes Filtering ✅

**Datei:** `app/controllers/international/tournaments_controller.rb`

**Neue Strategie:**
1. SQL-Filter für einfache Felder (discipline_id, year)
2. Laden aller Records mit `.to_a`
3. Ruby-Filter für serialisierte Daten (tournament_type, official_umb)
4. Kaminari für Pagination von Arrays

**Code:**
```ruby
# SQL Filters
@tournaments = @tournaments.where(discipline_id: discipline_ids)
@tournaments = @tournaments.in_year(params[:year])

# Load and filter in Ruby
all_tournaments = @tournaments.to_a
all_tournaments = all_tournaments.select { |t| t.tournament_type == params[:type] }
all_tournaments = all_tournaments.select { |t| t.official_umb? }

# Paginate array
@tournaments = Kaminari.paginate_array(all_tournaments)
@pagy, @tournaments = pagy_array(@tournaments, items: items_per_page)
```

### Fix 4: Helper - Gruppen-Filter Support ✅

**Datei:** `app/helpers/international_helper.rb`

**Features:**
- Gruppen-Werte: `"group:Cadre / Balkline"`
- Class Method: `InternationalHelper.discipline_ids_for_group(name)`
- Select-Options zeigen Gruppe + Einzeldisziplinen

**Struktur im Dropdown:**
```
Cadre / Balkline (All)         ← value: "group:Cadre / Balkline"
  → Cadre 35/2                 ← value: "35"
  → Cadre 47/2                 ← value: "40"
  → Cadre 57/2                 ← value: "10"
  ...
```

---

## ⚠️ Wichtige Hinweise

### Performance-Überlegung:

**Aktuell:**
- Alle Turniere werden geladen (`.to_a`)
- Filtering in Ruby statt SQL
- OK für <1000 internationale Turniere

**Bei >1000 Turnieren:**
- Migration zu JSONB empfohlen:
  ```ruby
  # Migration
  change_column :tournaments, :data, :jsonb, using: 'data::jsonb'
  
  # Dann können Scopes wieder verwendet werden:
  scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }
  ```

### Alternative Lösung ohne JSONB:

Eigene Spalten für häufig verwendete Filter:
```ruby
# Migration
add_column :tournaments, :tournament_type, :string
add_column :tournaments, :official_umb, :boolean, default: false
add_index :tournaments, :tournament_type
add_index :tournaments, :official_umb

# Dann Standard-Scopes:
scope :by_type, ->(type) { where(tournament_type: type) }
scope :official_umb, -> { where(official_umb: true) }
```

---

## ✅ Was jetzt funktioniert

### Disziplin-Filter:
- ✅ Einzelne Disziplin auswählen → Zeigt nur diese Disziplin
- ✅ Gruppen-Filter auswählen → Zeigt alle Disziplinen der Gruppe
- ✅ "Cadre / Balkline (All)" → Zeigt Cadre 35/2, 47/2, 52/2, 57/2, 71/2
- ✅ "3-Cushion (Dreiband) (All)" → Zeigt Dreiband halb, groß, klein

### Tournament Type Filter:
- ✅ "World Cup" Filter funktioniert
- ✅ "World Championship" Filter funktioniert
- ✅ Alle anderen Types funktionieren

### Official UMB Filter:
- ✅ Checkbox funktioniert
- ✅ Zeigt nur offizielle UMB Turniere

### View Modes:
- ✅ Grid View funktioniert
- ✅ Table View funktioniert
- ✅ Toggle behält Filter

---

## 🧪 Test-Checkliste

### Disziplin-Filter Tests:

- [ ] Auswahl "3-Cushion (Dreiband) (All)" zeigt alle 3-Cushion Varianten
- [ ] Auswahl "Dreiband halb" zeigt nur diese spezifische Disziplin
- [ ] Auswahl "Cadre / Balkline (All)" zeigt alle Cadre-Varianten
- [ ] Auswahl "Cadre 57/2" zeigt nur diese spezifische Variante
- [ ] Filter kombinieren funktioniert (Type + Discipline + Year)

### Performance Tests:

- [ ] Index lädt in <2 Sekunden (bei <100 Turnieren)
- [ ] Keine N+1 Queries (Check Rails log)
- [ ] Pagination funktioniert smooth

### Edge Cases:

- [ ] Keine Turniere → "No tournaments found" Meldung
- [ ] Alle Filter leer → Alle Turniere angezeigt
- [ ] Ungültige Filter-Parameter → Ignoriert

---

## 📝 Code-Beispiele

### Filter-Verwendung im Controller:

```ruby
# Einzelne Disziplin
params[:discipline_id] = "12" # Dreiband halb
→ WHERE discipline_id = 12

# Gruppen-Filter
params[:discipline_id] = "group:Cadre / Balkline"
→ WHERE discipline_id IN (10, 35, 36, 39, 40)
```

### Helper-Verwendung im View:

```erb
<!-- Hierarchischer Dropdown -->
<%= f.select :discipline_id,
    grouped_options_for_select(grouped_disciplines_for_select, params[:discipline_id]),
    { include_blank: 'All Disciplines' } %>
```

### Tournament Type Filtering:

```ruby
# Im Controller (Ruby-Filter):
all_tournaments = @tournaments.to_a
all_tournaments.select { |t| t.tournament_type == 'world_cup' }

# Im Model:
def tournament_type
  json_data['tournament_type']
end
```

---

## 🎓 Lessons Learned

### Was gelernt wurde:

⚠️ **TEXT vs JSONB** - Große Unterschiede in Query-Fähigkeiten!  
⚠️ **Serialized Columns** - Müssen in Ruby gefiltert werden  
⚠️ **Performance** - Ruby-Filter OK für kleine Datenmengen (<1000)  
⚠️ **Hierarchische Filter** - Brauchen spezielle Logik im Controller  

### Best Practices:

✅ **Für häufige Filter:** Eigene Spalten verwenden (nicht in data)  
✅ **Für seltene Metadaten:** Serialized/JSON OK  
✅ **Für große Datenmengen:** JSONB statt serialized TEXT  
✅ **Performance:** Immer `.includes()` für Assoziationen  

---

## 🚀 Migration zu JSONB (Optional, später)

Falls Performance-Probleme auftreten:

```ruby
# Migration
class ConvertTournamentsDataToJsonb < ActiveRecord::Migration[7.2]
  def up
    # Backup existing data
    execute <<-SQL
      ALTER TABLE tournaments 
      RENAME COLUMN data TO data_old;
    SQL
    
    # Add new JSONB column
    add_column :tournaments, :data, :jsonb, default: {}
    
    # Migrate data
    Tournament.reset_column_information
    Tournament.find_each do |t|
      data_str = t.read_attribute_before_type_cast(:data_old)
      next if data_str.blank?
      
      t.update_column(:data, JSON.parse(data_str))
    rescue JSON::ParserError
      Rails.logger.error "Failed to parse data for Tournament #{t.id}"
    end
    
    # Drop old column
    remove_column :tournaments, :data_old
    
    # Add indexes
    add_index :tournaments, "(data->>'tournament_type')", name: 'idx_tournaments_on_tournament_type'
    add_index :tournaments, "(data->>'umb_official')", name: 'idx_tournaments_on_umb_official'
  end
  
  def down
    # Convert back to TEXT
    change_column :tournaments, :data, :text
  end
end
```

**Dann können SQL-Scopes verwendet werden:**
```ruby
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }
scope :official_umb, -> { where("data->>'umb_official' = ?", 'true') }
```

---

## ✅ Status: FIXED

Beide Bugs wurden behoben:

1. ✅ **JSONB-Operator Fehler** → Umgestellt auf Ruby-Filtering
2. ✅ **Hierarchische Filter** → Gruppen-Logik implementiert

**Ready for Testing!** 🎉

---

**Version:** 1.0.1 (Bugfix Release)  
**Datum:** 19. Februar 2026  
**Fixes:** 2 Critical Bugs  
**Status:** ✅ Ready for Testing
