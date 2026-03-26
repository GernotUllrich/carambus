# Trainings-Datenbank

## Überblick

Die Trainings-Datenbank ermöglicht die Verwaltung von Billard-Trainingskonzepten mit detaillierten Übungsbeispielen, Ausgangs- und Zielpositionen sowie häufigen Fehlern.

## Datenmodell

### TrainingConcept (Trainingskonzept)
Das Hauptmodell für ein Trainingskonzept.

**Felder:**
- `title` (String, Pflicht): Titel des Konzepts
- `short_description` (Text): Kurzbeschreibung
- `full_description` (Text): Ausführliche Beschreibung
- `source_language` (String): Quellsprache (de, en, nl, fr)
- `translations` (JSONB): Übersetzungen in andere Sprachen

**Beziehungen:**
- `disciplines`: Many-to-Many Beziehung zu Disziplinen
- `training_examples`: Hat viele Übungsbeispiele

### TrainingExample (Übungsbeispiel)
Konkrete Übungsbeispiele für ein Trainingskonzept.

**Felder:**
- `title` (String): Titel des Beispiels
- `sequence_number` (Integer): Laufende Nummer
- `ideal_stroke_parameters_text` (Text): Freitext für Stoßparameter
- `ideal_stroke_parameters_data` (JSONB): Strukturierte Stoßparameter

**Beziehungen:**
- `training_concept`: Gehört zu einem Konzept
- `starting_position`: Hat eine Ausgangsposition (1:1)
- `target_position`: Hat eine Zielposition (1:1)
- `error_examples`: Hat mehrere Fehlerbeispiele

### StartingPosition (Ausgangsposition)
Beschreibt die Ausgangsposition der Bälle.

**Felder:**
- `description_text` (Text): Freitext-Beschreibung
- `ball_measurements` (JSONB): Strukturierte Ballpositionen (B1, B2, B3)
- `position_variants` (JSONB): Array von Positionsvarianten
- `image`: Bild der Ausgangsposition (TODO: ActiveStorage)

**JSON-Struktur für ball_measurements:**
```json
{
  "b1": { "x": 100, "y": 200, "description": "Ball 1 position" },
  "b2": { "x": 150, "y": 250, "description": "Ball 2 position" },
  "b3": { "x": 200, "y": 300, "description": "Ball 3 position" }
}
```

**JSON-Struktur für position_variants:**
```json
[
  {
    "name": "Variant A",
    "b1": { "x": 105, "y": 205 },
    "b2": { "x": 155, "y": 255 }
  }
]
```

### TargetPosition (Zielposition)
Beschreibt die ideale Zielposition.

**Felder:**
- `description_text` (Text): Freitext-Beschreibung
- `ball_measurements` (JSONB): Strukturierte Zielposition
- `image`: Bild der Zielposition (TODO: ActiveStorage)

### ErrorExample (Fehlerbeispiel)
Beschreibt häufige Fehler und deren Auswirkungen.

**Felder:**
- `title` (String): Titel des Fehlers
- `sequence_number` (Integer): Laufende Nummer
- `stroke_parameters_text` (Text): Freitext für fehlerhafte Parameter
- `stroke_parameters_data` (JSONB): Strukturierte Fehlerparameter
- `end_position_description` (Text): Beschreibung der fehlerhaften Endposition
- `image`: Bild der fehlerhaften Position (TODO: ActiveStorage)

## Mehrsprachigkeit

Das System unterstützt mehrere Sprachen:

**Unterstützte Quellsprachen:**
- Deutsch (de)
- Englisch (en)
- Niederländisch (nl)
- Französisch (fr)

**Zielsprachen:**
- Deutsch (de)
- Englisch (en)

### Übersetzung

TrainingConcepts können automatisch mit DeepL übersetzt werden:

```ruby
concept = TrainingConcept.find(1)
concept.translate_to_target_languages!
```

Die Übersetzungen werden im `translations` JSONB-Feld gespeichert:

```json
{
  "en": {
    "title": "Counter Play",
    "short_description": "Basics of counter play in three-cushion billiards",
    "full_description": "...",
    "translated_at": "2026-03-26T10:34:35Z"
  }
}
```

### Zugriff auf Übersetzungen

```ruby
concept.title_in('en')              # Gibt den Titel in Englisch zurück
concept.short_description_in('de')  # Gibt die Kurzbeschreibung in Deutsch zurück
concept.full_description_in('nl')   # Gibt die ausführliche Beschreibung zurück
```

## Verwaltung

### Admin-Interface

Die Trainingskonzepte können über das Administrate-Interface verwaltet werden:

**URL:** `/admin/training_concepts`

**Berechtigungen:**
- Erstellen/Bearbeiten/Löschen: Nur Admins
- Ansehen: Alle authentifizierten Benutzer

### Beispieldaten laden

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rails runner "load 'db/seeds/training_concepts.rb'"
```

## Beispiel-Workflow

### 1. Trainingskonzept erstellen

```ruby
concept = TrainingConcept.create!(
  title: "Konterspiel",
  short_description: "Grundlagen des Konterspiels",
  full_description: "Detaillierte Erklärung...",
  source_language: 'de',
  discipline_ids: [dreiband.id]
)
```

### 2. Übungsbeispiel hinzufügen

```ruby
example = concept.training_examples.create!(
  title: "Einfaches Konterspiel",
  ideal_stroke_parameters_text: "Effet: Rechts, Kraft: Mittel"
)
```

### 3. Ausgangsposition definieren

```ruby
example.create_starting_position!(
  description_text: "Ball 1 nahe der kurzen Bande...",
  ball_measurements: {
    b1: { x: 50, y: 150, description: "Spielball" },
    b2: { x: 142, y: 142, description: "Ball 2" },
    b3: { x: 234, y: 50, description: "Ball 3" }
  }
)
```

### 4. Zielposition definieren

```ruby
example.create_target_position!(
  description_text: "Spielball trifft Ball 2 und Ball 3",
  ball_measurements: {
    b1: { x: 50, y: 150 },
    b2: { x: 142, y: 142 },
    b3: { x: 234, y: 50 }
  }
)
```

### 5. Fehlerbeispiel hinzufügen

```ruby
example.error_examples.create!(
  title: "Zu wenig Effet",
  stroke_parameters_text: "Zu wenig Rechtseffet führt zu...",
  end_position_description: "Ball erreicht Ziel nicht"
)
```

### 6. Übersetzung generieren

```ruby
concept.translate_to_target_languages!
```

## TODO

- [ ] ActiveStorage-Konfiguration für Bilder einrichten
- [ ] Frontend-Interface für Trainingsverwaltung
- [ ] Visualisierung der Ballpositionen
- [ ] Export-Funktion für PDF-Trainingsanleitungen
- [ ] Filterfunktion nach Disziplin
- [ ] Suchfunktion für Trainingskonzepte

## Datenbankschema

```
training_concepts
├── id
├── title
├── short_description
├── full_description
├── source_language
├── translations (jsonb)
├── created_at
└── updated_at

training_concept_disciplines
├── id
├── training_concept_id → training_concepts
├── discipline_id → disciplines
├── created_at
└── updated_at

training_examples
├── id
├── training_concept_id → training_concepts
├── title
├── sequence_number
├── ideal_stroke_parameters_text
├── ideal_stroke_parameters_data (jsonb)
├── created_at
└── updated_at

starting_positions
├── id
├── training_example_id → training_examples (unique)
├── description_text
├── ball_measurements (jsonb)
├── position_variants (jsonb)
├── created_at
└── updated_at

target_positions
├── id
├── training_example_id → training_examples (unique)
├── description_text
├── ball_measurements (jsonb)
├── created_at
└── updated_at

error_examples
├── id
├── training_example_id → training_examples
├── title
├── sequence_number
├── stroke_parameters_text
├── stroke_parameters_data (jsonb)
├── end_position_description
├── created_at
└── updated_at
```
