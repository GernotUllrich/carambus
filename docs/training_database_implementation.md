# Trainings-Datenbank - Implementierung

## Zusammenfassung

Es wurde eine vollständige Trainings-Datenbank für Billard-Übungen implementiert.

## Implementierte Features

### ✅ Datenbank-Schema
- **6 neue Tabellen** erstellt:
  - `training_concepts`: Hauptkonzepte
  - `training_concept_disciplines`: Join-Table für Disziplinen
  - `training_examples`: Übungsbeispiele
  - `starting_positions`: Ausgangspositionen
  - `target_positions`: Zielpositionen
  - `error_examples`: Fehlerbeispiele

### ✅ Models
- `TrainingConcept`: Mit Mehrsprachigkeits-Support
- `TrainingConceptDiscipline`: Join-Model
- `TrainingExample`: Mit nested attributes
- `StartingPosition`: Mit JSONB für Ballpositionen
- `TargetPosition`: Mit JSONB für Ballpositionen
- `ErrorExample`: Für häufige Fehler

### ✅ Mehrsprachigkeit
- Unterstützung für DE, EN, NL, FR als Quellsprachen
- Automatische Übersetzung mit DeepL (DE ↔ EN)
- Übersetzungen in JSONB gespeichert
- Helper-Methoden für Zugriff auf Übersetzungen

### ✅ Admin-Interface
- Administrate-Dashboards für alle Models
- Controller mit Übersetzungsfunktion
- Nested routes für Examples
- Admin-only Zugriff für CRUD-Operationen

### ✅ Beispieldaten
- Seed-Datei mit 2 vollständigen Trainingskonzepten:
  1. **Konterspiel**: Mit Ausgangs-/Zielposition und 2 Fehlerbeispielen
  2. **Rückläufer**: Mit Ausgangs-/Zielposition

## Dateistruktur

```
app/
├── models/
│   ├── training_concept.rb
│   ├── training_concept_discipline.rb
│   ├── training_example.rb
│   ├── starting_position.rb
│   ├── target_position.rb
│   ├── error_example.rb
│   └── discipline.rb (erweitert)
├── controllers/admin/
│   ├── training_concepts_controller.rb
│   └── training_examples_controller.rb
├── dashboards/
│   ├── training_concept_dashboard.rb
│   └── training_example_dashboard.rb
└── services/
    └── deepl_translation_service.rb (erweitert)

db/
├── migrate/
│   ├── 20260326103435_create_training_concepts.rb
│   ├── 20260326103436_create_training_concept_disciplines.rb
│   ├── 20260326103437_create_training_examples.rb
│   ├── 20260326103438_create_starting_positions.rb
│   ├── 20260326103439_create_target_positions.rb
│   └── 20260326103441_create_error_examples.rb
└── seeds/
    └── training_concepts.rb

docs/
├── training_database.md
└── training_database_implementation.md
```

## Verwendung

### Admin-Interface aufrufen

```
http://localhost:3000/admin/training_concepts
```

### Programmatischer Zugriff

```ruby
# Konzept erstellen
concept = TrainingConcept.create!(
  title: "Mein Konzept",
  short_description: "Kurz",
  full_description: "Lang",
  source_language: 'de',
  discipline_ids: [1]
)

# Beispiel hinzufügen
example = concept.training_examples.create!(
  title: "Beispiel 1",
  ideal_stroke_parameters_text: "Effet: Links, Kraft: 70%"
)

# Ausgangsposition
example.create_starting_position!(
  description_text: "Bälle in Linie",
  ball_measurements: {
    b1: { x: 100, y: 100 },
    b2: { x: 150, y: 100 },
    b3: { x: 200, y: 100 }
  }
)

# Übersetzen
concept.translate_to_target_languages!

# Übersetzung abrufen
concept.title_in('en')  # => "My Concept"
```

### Seed-Daten laden

```bash
rails runner "load 'db/seeds/training_concepts.rb'"
```

## Nächste Schritte

### Kurzfristig
1. **ActiveStorage konfigurieren**
   - Image-Uploads für Positionen aktivieren
   - Thumbnail-Generierung einrichten

2. **Admin-Interface verbessern**
   - Custom-Views für nested forms
   - Bildvorschau in der Liste
   - Batch-Übersetzung mehrerer Konzepte

### Mittelfristig
3. **Frontend-Integration**
   - Öffentliche Trainingsansicht
   - Filterfunktion nach Disziplin
   - Suchfunktion

4. **Visualisierung**
   - SVG-Canvas für Ballpositionen
   - Interaktive Positions-Editor
   - Animationen für Balllauf

### Langfristig
5. **Erweiterte Features**
   - PDF-Export für Trainingsanleitungen
   - Video-Integration
   - Benutzer-Favoriten
   - Trainingsfortschritt tracken
   - Community-Beiträge

## Technische Details

### JSONB-Strukturen

**ball_measurements:**
```json
{
  "b1": {
    "x": 50,
    "y": 150,
    "description": "Spielball nahe kurzer Bande"
  },
  "b2": {
    "x": 142,
    "y": 142,
    "description": "Ball 2 in Tischmitte"
  },
  "b3": {
    "x": 234,
    "y": 50,
    "description": "Ball 3 nahe langer Bande"
  }
}
```

**position_variants:**
```json
[
  {
    "name": "Variant A - Engerer Winkel",
    "b1": { "x": 45, "y": 145 },
    "b2": { "x": 140, "y": 145 }
  },
  {
    "name": "Variant B - Weiterer Winkel",
    "b1": { "x": 55, "y": 155 },
    "b2": { "x": 145, "y": 140 }
  }
]
```

**translations:**
```json
{
  "en": {
    "title": "Counter Play",
    "short_description": "Basics of counter play",
    "full_description": "Detailed description...",
    "translated_at": "2026-03-26T10:34:35Z"
  }
}
```

### Validierungen

- `TrainingConcept.title`: Pflichtfeld
- `TrainingConcept.source_language`: Pflichtfeld, nur DE/EN/NL/FR
- `TrainingExample.sequence_number`: Unique pro Konzept, automatisch generiert
- `StartingPosition.training_example_id`: Unique (1:1 Beziehung)
- `TargetPosition.training_example_id`: Unique (1:1 Beziehung)
- `ErrorExample.sequence_number`: Unique pro Example, automatisch generiert

### Callbacks

- `TrainingConcept.set_default_language`: Setzt 'de' als Standard
- `TrainingExample.set_sequence_number`: Auto-Increment
- `ErrorExample.set_sequence_number`: Auto-Increment

## Testing

```ruby
# Console-Tests
rails console

# Konzept erstellen und testen
concept = TrainingConcept.first
concept.title                    # => "Konterspiel"
concept.training_examples.count  # => 1
concept.disciplines.first.name   # => "Dreiband klein"

# Beispiel testen
example = concept.training_examples.first
example.starting_position.ball_measurements
example.target_position.description_text
example.error_examples.count     # => 2

# Übersetzung testen
concept.translate_to_target_languages!
concept.title_in('en')           # => übersetzter Titel
```

## Bekannte Einschränkungen

1. **ActiveStorage**: Derzeit deaktiviert, muss konfiguriert werden
2. **Bilder**: Können noch nicht hochgeladen werden
3. **Frontend**: Nur Admin-Interface, kein öffentliches Frontend
4. **Visualisierung**: Ballpositionen nur als JSON, keine grafische Darstellung

## Changelog

### 2026-03-26
- ✅ Datenbank-Schema erstellt
- ✅ Models implementiert
- ✅ Admin-Controller erstellt
- ✅ Dashboards konfiguriert
- ✅ Mehrsprachigkeit implementiert
- ✅ DeepL-Integration erweitert
- ✅ Seed-Daten erstellt
- ✅ Dokumentation geschrieben
