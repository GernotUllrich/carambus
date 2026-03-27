# Trainings-Datenbank - Implementierung

## Zusammenfassung

Die Trainings-Datenbank wurde im März 2026 grundlegend überarbeitet. Das ursprüngliche System mit separaten Models für `TargetPosition` und `ErrorExample` wurde durch ein vereinheitlichtes `Shot`-Model ersetzt, das alle Stoß-Typen abdeckt.

## Wichtige Änderungen (März 2026)

### ✅ Großes Refactoring durchgeführt

**Vorher:**
- `StartingPosition` → Ausgangsposition
- `TargetPosition` → Zielposition für idealen Stoß
- `ErrorExample` → Fehlerhafte End-Position

**Nachher:**
- `StartPosition` → Ausgangsposition (Model-Name geändert, Tabelle gleich)
- `Shot` → Vereinheitlichtes Model für alle Stoß-Typen
  - `shot_type: 'ideal'` (früher TargetPosition)
  - `shot_type: 'alternative'` (neu)
  - `shot_type: 'error'` (früher ErrorExample)

### ✅ Neue Features

1. **Self-Hierarchy** für TrainingExample (parent_id)
2. **TrainingSource** System für Quellenangaben
3. **SourceAttribution** für präzise Referenzierung
4. **Storage-Trennung** (local vs local_sources)
5. **Shot-Images** mit Trajectories
6. **Flexibles EndPosition-System** (exact/area/concept/named_area)

---

## Datenbank-Schema

### Aktuelle Tabellen (März 2026)

```
training_concepts
├── id
├── title, short_description, full_description
├── source_language
├── translations (JSONB)
├── translations_synced_at
└── timestamps

training_concept_disciplines (Join-Table)
├── id
├── training_concept_id
└── discipline_id

training_examples
├── id
├── training_concept_id
├── parent_id (NEW - Self-Join für Hierarchie)
├── sequence_number
├── title, title_de, title_en
├── source_notes
├── ideal_stroke_parameters_text, *_de, *_en
├── ideal_stroke_parameters_data (JSONB)
├── source_language
├── translations (JSONB)
├── translations_synced_at
└── timestamps

starting_positions (Tabelle - Model heißt StartPosition)
├── id
├── training_example_id
├── description_text, *_de, *_en
├── ball_measurements (JSONB)
├── position_variants (JSONB)
└── timestamps

shots (NEW - ersetzt target_positions und error_examples)
├── id
├── training_example_id
├── shot_type (ideal/alternative/error)
├── sequence_number
├── title_de, title_en, title_fr, title_nl
├── notes_de, notes_en, notes_fr, notes_nl
├── end_position_description_de, *_en, *_fr, *_nl
├── shot_description_de, *_en, *_fr, *_nl
├── end_position_type
├── end_position_data (JSONB)
├── shot_parameters (JSONB)
├── translations_synced_at
└── timestamps

training_sources (NEW)
├── id
├── title
├── author
├── publication_year
├── publisher
├── language
├── notes
└── timestamps

source_attributions (NEW - polymorphic join)
├── id
├── training_source_id
├── sourceable_type (TrainingConcept/TrainingExample)
├── sourceable_id
├── reference (z.B. "S. 23-25")
├── notes
└── timestamps

ActiveStorage Tables:
├── active_storage_blobs
│   └── service_name (:local oder :local_sources)
└── active_storage_attachments
    ├── record_type (StartPosition/Shot/TrainingSource)
    └── name (image/shot_image/source_files)
```

### Gelöschte Tabellen (März 2026)

- ❌ `target_positions` (migriert → shots mit shot_type='ideal')
- ❌ `error_examples` (migriert → shots mit shot_type='error')

---

## Models

### Model-Übersicht

```ruby
# Hauptmodelle
TrainingConcept
  include Translatable
  has_many :training_examples
  has_many :disciplines, through: :training_concept_disciplines
  has_many :tags, as: :taggable

TrainingExample
  include Translatable
  belongs_to :training_concept
  belongs_to :parent, class_name: 'TrainingExample', optional: true
  has_many :children, class_name: 'TrainingExample', foreign_key: :parent_id
  has_one :start_position
  has_many :shots
  has_many :source_attributions, as: :sourceable
  has_many :training_sources, through: :source_attributions

StartPosition
  include Translatable
  self.table_name = 'starting_positions'
  belongs_to :training_example
  has_one_attached :image

Shot (NEW)
  include Translatable
  belongs_to :training_example
  has_one_attached :shot_image
  validates :shot_type, inclusion: { in: %w[ideal alternative error] }
  scope :ideal, -> { where(shot_type: 'ideal') }
  scope :alternative, -> { where(shot_type: 'alternative') }
  scope :errors, -> { where(shot_type: 'error') }

TrainingSource (NEW)
  has_many :source_attributions
  has_many :training_concepts, through: :source_attributions
  has_many :training_examples, through: :source_attributions
  has_many_attached :source_files, service: :local_sources

SourceAttribution (NEW)
  belongs_to :training_source
  belongs_to :sourceable, polymorphic: true
```

### Translatable Concern

Automatische Übersetzung für mehrsprachige Felder:

```ruby
module Translatable
  def translatable_fields
    # Override in models, z.B.:
    [:title, :short_description, :full_description]
  end
  
  def translate_to_target_languages!(method: 'deepl', force: false)
    # DeepL oder AI
    # Aktualisiert *_de und *_en Felder
    # Setzt translations_synced_at
  end
  
  def translations_in_sync?
    translations_synced_at.present? && 
    translations_synced_at >= updated_at
  end
end
```

---

## Controllers

### Admin::ShotsController (NEW)

```ruby
class Admin::ShotsController < Admin::ApplicationController
  # Standard CRUD
  # + move_up / move_down für Sortierung
  # + Translation handling (wie TrainingExamplesController)
  # + Redirect zu parent TrainingExample nach destroy
end
```

### Admin::TrainingSourcesController (NEW)

```ruby
class Admin::TrainingSourcesController < Admin::ApplicationController
  # Standard CRUD
  # + Custom redirect mit host/port
  # + delete_attachment für einzelne Dateien
  # + Manual handling von source_files (ActiveStorage)
end
```

### Admin::TrainingExamplesController (erweitert)

```ruby
class Admin::TrainingExamplesController < Admin::ApplicationController
  # + parent_id Support
  # + Shots statt target_position/error_examples
  # + source_attributions_attributes permitted
end
```

---

## Dashboards (Administrate)

### ShotDashboard (NEW)

```ruby
ATTRIBUTE_TYPES = {
  shot_type: Field::Select.with_options(
    collection: ['ideal', 'alternative', 'error']
  ),
  shot_image: Field::ActiveStorage,
  # + alle multilingualen Felder
  # + end_position_data, shot_parameters (Text für JSON)
}

FORM_ATTRIBUTES = %i[
  training_example
  shot_type
  sequence_number
  shot_image
]
```

### StartPositionDashboard (renamed from StartingPositionDashboard)

```ruby
# Minimal, da hauptsächlich über TrainingExample verwaltet
FORM_ATTRIBUTES = %i[
  training_example
  image
  ball_measurements
  position_variants
  tag_list
]
```

### TrainingSourceDashboard (NEW)

```ruby
ATTRIBUTE_TYPES = {
  language: Field::Select.with_options(
    collection: %w[de en nl fr]
  ),
  source_files_attachments: Field::HasMany
}
```

---

## Views

### Custom Views

```
app/views/admin/
├── shots/
│   └── _form_fields.html.erb
│       ├── Multilingual fields (via partial)
│       ├── Shot type select
│       ├── JSON editors (end_position_data, shot_parameters)
│       └── Translation toggle
│
├── training_examples/
│   └── show.html.erb
│       └── Shots table (statt target_position/error_examples)
│
├── training_sources/
│   ├── _form_fields.html.erb
│   │   └── Multi-file upload für source_files
│   └── show.html.erb
│       └── File previews mit Download/View buttons
│
└── application/
    ├── _multilingual_text_fields.html.erb
    │   ├── Primary: DE/EN always visible
    │   └── Secondary: FR/NL collapsible ("Quelle anzeigen")
    └── _source_attributions_fields.html.erb
        └── Nested form für Quellenverweise
```

### Multilingual Fields Partial

```erb
<%= render partial: 'admin/application/multilingual_text_fields', locals: { 
  form: f, 
  field_name: 'title', 
  label: 'Title',
  source_language: 'de',
  field_type: 'text_field'
} %>
```

Features:
- Badges für Quell-/Zielsprachen
- Collapsible Quelle-Block (FR/NL)
- Automatische Anzeige basierend auf source_language

---

## Migrations

### Ausgeführte Migrations (März 2026)

```ruby
# 1. Parent-Child Hierarchie
20260327000001_add_parent_id_to_training_examples.rb
  add_column :training_examples, :parent_id, :integer
  add_index :training_examples, :parent_id, algorithm: :concurrently
  add_foreign_key ..., validate: false

20260327000008_validate_parent_id_foreign_key.rb
  validate_foreign_key :training_examples, column: :parent_id

# 2. Shot Model
20260327000003_create_shots.rb
  create_table :shots do |t|
    t.references :training_example
    t.string :shot_type
    # + alle multilingualen Felder (_de, _en, _fr, _nl)
    # + end_position_type, end_position_data (JSONB)
    # + shot_parameters (JSONB)
  end

# 3. Datenmigration
20260327000004_migrate_target_positions_to_shots.rb
  # TargetPosition → Shot (shot_type: 'ideal')
  INSERT INTO shots (...)
  SELECT training_example_id, 'ideal', ...
  FROM target_positions

20260327000005_migrate_error_examples_to_shots.rb
  # ErrorExample → Shot (shot_type: 'error')
  INSERT INTO shots (...)
  SELECT training_example_id, 'error', ...
  FROM error_examples

# 4. Cleanup
20260327000006_drop_target_positions.rb
20260327000007_drop_error_examples.rb

# 5. TrainingSource System
20260326202343_create_training_sources.rb
20260326202348_create_source_attributions.rb
```

### strong_migrations Compliance

Alle Migrations sind kompatibel mit strong_migrations:
- ✅ Concurrent Index Creation
- ✅ Foreign Keys mit validate: false
- ✅ Separate Validation Migration
- ✅ safety_assured für Daten-Migrations

---

## Storage-Konfiguration

### config/storage.yml

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Für TrainingSource source_files - NICHT synchronisiert!
local_sources:
  service: Disk
  root: <%= Rails.root.join("storage_local") %>
```

### Rsync-Strategie

```bash
# Auf lokalen Servern (carambus_bcw, carambus_phat):
rsync -avz api-server:/path/to/storage/ ./storage/

# storage_local/ wird AUSGELASSEN
# → TrainingSource PDFs bleiben nur auf API-Server
# → Training-Images (StartPosition, Shot) werden synchronisiert
```

---

## Routes

### Nested Resources

```ruby
namespace :admin do
  resources :training_concepts do
    resources :training_examples, shallow: true do
      resources :shots, shallow: true do
        member do
          patch :move_up
          patch :move_down
        end
      end
    end
  end
  
  resources :training_sources do
    member do
      delete :delete_attachment
    end
  end
  
  # Standalone für Administrate navigation
  resources :training_examples, only: [:index]
  resources :shots, only: [:index]
end
```

---

## Rake Tasks

### training_data:export

Exportiert Training-Daten für Production-Import:

```bash
rails training_data:export
```

Erstellt: `db/seeds/training_data.rb`

Enthält:
- TrainingSource records
- TrainingConcept records
- TrainingExample records
- SourceAttribution records
- **ActiveStorage Blob metadata** (aber nicht die Files selbst)

### training_data:import

```bash
rails training_data:import
```

Lädt die Seeds. Danach manuell:

```bash
# Physische Files kopieren
rsync -avz source:/path/to/storage/ ./storage/
```

### glossary:* Tasks

Für DeepL Glossar-Management (siehe TRANSLATION.md)

---

## Testing

### Fixtures

```yaml
# test/fixtures/shots.yml
ideal_shot:
  training_example: example_one
  shot_type: ideal
  sequence_number: 1
  title_de: "Idealer Stoß"
  end_position_type: exact

error_shot:
  training_example: example_one
  shot_type: error
  sequence_number: 2
  title_de: "Zu wenig Effet"
```

### Model Tests

```ruby
# test/models/shot_test.rb
test "should validate shot_type" do
  shot = Shot.new(shot_type: 'invalid')
  assert_not shot.valid?
  assert_includes shot.errors[:shot_type], "is not included in the list"
end

test "should set sequence_number automatically" do
  shot = Shot.create!(training_example: training_examples(:one), shot_type: 'ideal')
  assert_not_nil shot.sequence_number
end
```

---

## Beispieldaten

### db/seeds/training_concepts.rb

```ruby
# Seed-Datei bleibt kompatibel, aber nutzt jetzt Shot statt TargetPosition/ErrorExample

concept = TrainingConcept.create!(
  title: "Konterspiel",
  source_language: 'de',
  # ...
)

example = concept.training_examples.create!(
  title: "Grundposition",
  sequence_number: 1,
  # ...
)

# StartPosition (früher starting_position)
example.create_start_position!(
  description_text: "B1 an der Bande, B2 in der Mitte",
  ball_measurements: { b1: {x: 100, y: 200}, ... }
)

# Shots (früher target_position und error_examples)
example.shots.create!(
  shot_type: 'ideal',
  sequence_number: 1,
  title_de: "Mit hohem Effet",
  end_position_description_de: "B1 landet im Cadre-Bereich",
  end_position_type: 'concept',
  end_position_data: { type: 'named_area', name: 'Cadre-Bereich' }
)

example.shots.create!(
  shot_type: 'error',
  sequence_number: 2,
  title_de: "Zu wenig Energie",
  end_position_description_de: "B1 erreicht B3 nicht",
  end_position_type: 'exact',
  end_position_data: { b1: {x: 150, y: 250}, ... }
)
```

---

## Performance-Überlegungen

### Indexierung

```ruby
# Wichtige Indizes
add_index :shots, :shot_type
add_index :shots, [:training_example_id, :sequence_number], unique: true
add_index :training_examples, :parent_id
add_index :source_attributions, [:sourceable_type, :sourceable_id]
```

### N+1 Queries vermeiden

```ruby
# Eager Loading
@examples = TrainingExample.includes(:start_position, :shots, :training_sources)

# Scopes nutzen
@ideal_shots = @example.shots.ideal
@error_shots = @example.shots.errors
```

### JSONB Performance

```ruby
# GIN Index für JSONB (future enhancement)
add_index :shots, :end_position_data, using: :gin
add_index :shots, :shot_parameters, using: :gin

# Queries
Shot.where("end_position_data @> ?", {type: 'named_area'}.to_json)
```

---

## Deployment-Checkliste

### Vor Deployment

- [ ] Migrations ausführen (Test-Datenbank)
- [ ] Daten-Migration verifizieren (TargetPosition → Shot)
- [ ] Backup erstellen
- [ ] Rollback-Plan bereit

### Nach Deployment

- [ ] Migrations ausführen (Production)
- [ ] Daten verifizieren
- [ ] storage_local/ Verzeichnis erstellen
- [ ] Rsync-Konfiguration auf lokalen Servern anpassen
- [ ] DeepL Glossar aktualisieren (falls nötig)

### Rollback (falls nötig)

```bash
# Migrations rückgängig machen (in umgekehrter Reihenfolge)
rails db:rollback STEP=8
```

**Achtung:** Daten-Migration ist nicht automatisch umkehrbar!
- Backup vor Migration essentiell

---

## Bekannte Limitierungen

1. **FR/NL Übersetzungen:** Aktuell nur DE/EN automatisch übersetzt
   - FR/NL Felder vorhanden, aber manuell zu pflegen

2. **ActiveStorage Sequenzen:** 
   - Blob IDs können >= 50.000.000 sein (abhängig von LocalProtector)
   - Auf API-Server sollten sie < 50.000.000 sein

3. **Administrate Einschränkungen:**
   - Polymorphe Beziehungen in Show-Pages limitiert
   - Nested Attributes manchmal fehleranfällig
   - Custom Views für komplexe Workflows nötig

4. **JSONB Validierung:**
   - Keine Schema-Validierung auf DB-Ebene
   - Struktur-Konsistenz muss in Application-Code sichergestellt werden

---

## Zukünftige Erweiterungen

### Geplant

- [ ] Video-Upload für Shots (neben Bildern)
- [ ] 3D-Visualisierung der Ballpositionen
- [ ] Erweiterte Such-/Filterfunktionen
- [ ] Public API für Training-Daten
- [ ] Mobile App Integration
- [ ] User-contributed Shots/Varianten
- [ ] Schwierigkeitsgrad-System
- [ ] Fortschritts-Tracking

### Technische Verbesserungen

- [ ] GIN Indizes für JSONB-Queries
- [ ] Caching-Layer für häufige Queries
- [ ] Background Jobs für Übersetzungen
- [ ] Versionierung von Shots (Änderungshistorie)
- [ ] Automated Tests für alle Models/Controllers

---

## Dokumentation

### Wichtige Dokumente

- [Konzept-Dokumentation](training_database.md)
- [Übersetzungs-System](TRANSLATION.md)
- Dieser Implementierungs-Guide

### Code-Dokumentation

Wichtige Code-Kommentare:
- Models: Erklärung der JSONB-Strukturen
- Migrations: safety_assured Begründungen
- Controllers: Custom Redirects
- Views: Conditional Rendering Logic

---

## Support

Bei Fragen oder Problemen:

1. Diese Dokumentation konsultieren
2. Code-Kommentare lesen
3. Git-History für Kontext (`git log --follow <file>`)
4. Feature-Branch: `feature/training-database`

**Letzte Aktualisierung:** März 27, 2026
**Version:** 2.0 (nach großem Refactoring)
