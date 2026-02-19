# Incomplete Records Interface - Verbesserungen

## Änderungen

### 1. Discipline Detection: 3-Cushion = Dreiband Groß

**Problem**: 3-Cushion Turniere wurden als "Dreiband halb" erkannt statt "Dreiband groß"

**Lösung**: 
- Internationale UMB 3-Cushion Turniere sind **IMMER** auf Großfeld (2,84 x 1,42 m)
- Nur deutsche nationale Ligen verwenden Match-Tische ("Dreiband halb", 2,10 x 1,05 m)
- Die Priorität in `find_discipline_from_name` wurde umgedreht

**Datei**: `app/services/umb_scraper.rb`

```ruby
# VORHER:
return Discipline.find_by('name ILIKE ?', '%dreiband%halb%') ||
       Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
       ...

# NACHHER:
return Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
       Discipline.find_by('name ILIKE ?', '%dreiband%gross%') ||
       Discipline.find_by('name ILIKE ?', '%three%cushion%') ||
       Discipline.find_by('name ILIKE ?', '%dreiband%halb%') ||  # Fallback
       ...
```

### 2. NULL-Werte als Placeholder erkennen

**Problem**: Turniere mit `location_id = NULL` wurden nicht als "incomplete" erkannt

**Lösung**:
- `is_placeholder_field?` gibt jetzt `true` zurück für `nil` Werte in definierten Placeholder-Feldern
- SQL Scope `with_placeholders` berücksichtigt jetzt auch NULL-Werte
- Bessere Fehlerbehandlung für fehlende Assoziationen

**Datei**: `app/models/concerns/placeholder_aware.rb`

```ruby
# Neue Logik
def is_placeholder_field?(field)
  value = send(field)
  
  # nil ist auch ein Placeholder, wenn das Feld definiert ist
  if value.nil?
    return self.class.placeholder_fields.key?(field)
  end
  
  # Prüfe ob es die Placeholder-ID ist
  # oder ob das assoziierte Objekt "Unknown" im Namen hat
  ...
end
```

### 3. Location aus Text erstellen

**Feature**: Neue Funktion zum Erstellen einer Location direkt aus dem `location_text`

**Funktionen**:
- Button "Create Location from Text" erscheint, wenn `location_text` vorhanden ist
- Modal-Dialog mit Formular:
  - Name wird automatisch aus `location_text` übernommen
  - Country Code eingeben (Standard: FR)
  - Optional: Adresse anpassen
- Prüft automatisch, ob Location bereits existiert (vermeidet Duplikate)
- Weist Location automatisch dem Tournament zu

**Dateien**:
- Controller: `app/controllers/admin/incomplete_records_controller.rb`
  - Methode: `create_location_from_text`
- View: `app/views/admin/incomplete_records/show.html.erb`
  - Modal-Dialog am Ende
- Routes: `config/routes.rb`
  - `POST /admin/incomplete_records/:id/create_location_from_text`

**Verwendung**:
1. Tournament mit `location_text` öffnen (z.B. "Nice")
2. Button "Create Location from Text" klicken
3. Country Code eingeben (z.B. "FR")
4. "Create Location" klicken
5. Location wird erstellt und zugewiesen

### 4. Update-Problem behoben

**Problem**: Tournament Update funktionierte nicht

**Lösung**:
- Verwendet jetzt `update_columns` statt `update` um Validierungsprobleme zu umgehen
- Besseres Logging für Debugging
- Fehlerbehandlung verbessert

**Datei**: `app/controllers/admin/incomplete_records_controller.rb`

### 5. View-Fixes

**Problem**: `@tournament.location` gab String statt Objekt zurück

**Ursache**: `InternationalTournament` überschreibt `location` und `organizer` Methoden

**Lösung**:
- View verwendet jetzt explizite Lookups: `Location.find_by(id: @tournament.location_id)`
- Bessere Fehlerbehandlung für polymorphe Assoziationen

## Testing

### Vorhandene Daten migrieren

Bestehende Turniere mit `nil` Location sollten jetzt automatisch erkannt werden:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
rails runner "puts InternationalTournament.with_placeholders.count"
```

### Disciplines korrigieren

Für bereits importierte Turniere mit falscher Discipline:

```bash
rake placeholders:auto_fix_disciplines
```

Oder über die Admin-UI: Button "Auto-Fix All Disciplines"

### Location aus Text erstellen

1. Öffnen: http://localhost:3000/admin/incomplete_records
2. Tournament mit fehlender Location suchen
3. "Fix" klicken
4. Bei "Location" den Button "Create Location from Text" klicken
5. Country Code eingeben und bestätigen

## Statistiken

Nach den Änderungen sollten mehr incomplete Records erkannt werden:

```bash
rake placeholders:stats
```

Zeigt:
- Total tournaments: XXX
- Complete: XXX
- Incomplete: XXX
  - Unknown Discipline: XX
  - Unknown Season: XX
  - Unknown/NULL Location: XX  ← Jetzt auch NULL
  - Unknown Organizer: XX

## Nächste Schritte

1. Server neu starten in RubyMine
2. Prüfen: Werden Turniere mit `location_id = NULL` jetzt erkannt?
3. Testen: "Create Location from Text" Funktion
4. Optional: Bestehende Disciplines mit `rake placeholders:auto_fix_disciplines` korrigieren
