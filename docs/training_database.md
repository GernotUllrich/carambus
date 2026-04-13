# Trainings-Datenbank

## Überblick

Die Trainings-Datenbank ermöglicht die Verwaltung von Billard-Trainingskonzepten mit detaillierten Übungsbeispielen, Ausgangs- und Endpositionen sowie häufigen Fehlern. Das System wurde im März 2026 grundlegend überarbeitet, um eine klarere Terminologie und flexiblere Struktur zu bieten.

## Kernkonzepte

### Terminologie

- **StartPosition**: Die Ausgangsposition der Bälle (B1, B2, B3) mit optionalen Varianten
- **Shot**: Ein konkreter Stoß von der StartPosition zu einer EndPosition
  - **Ideal Shot**: Führt zu einer günstigen EndPosition
  - **Alternative Shot**: Andere Methode zu einer günstigen EndPosition
  - **Error Shot**: Häufiger Fehler, der zu einer ungünstigen EndPosition führt
- **EndPosition**: Die Position der Bälle nach dem Stoß
- **Trajectories**: Die Laufwege der Bälle (im Shot-Image visualisiert)

## Datenmodell

### TrainingConcept (Trainingskonzept)
Das Hauptmodell für ein Trainingskonzept, das mehrere TrainingExamples zusammenfasst.

**Felder:**
- `title` (String, mehrsprachig): Titel des Konzepts
- `short_description` (Text, mehrsprachig): Kurzbeschreibung
- `full_description` (Text, mehrsprachig): Ausführliche Beschreibung
- `source_language` (String): Quellsprache (de, en, nl, fr)
- `translations` (JSONB): Übersetzungen in andere Sprachen
- `translations_synced_at` (DateTime): Zeitpunkt der letzten Übersetzung

**Beziehungen:**
- `disciplines`: Many-to-Many Beziehung zu Disziplinen
- `training_examples`: Hat viele Übungsbeispiele
- `tags`: Tagging-System für Kategorisierung

**Features:**
- ✅ Mehrsprachigkeit (DE, EN als Zielsprachen)
- ✅ DeepL-Integration mit Glossaren
- ✅ AI-Übersetzung (Claude/GPT) für komplexe Begriffe
- ✅ Übersetzungs-Sync-Status

---

### TrainingExample (Übungsbeispiel)
Konkrete Übungsbeispiele für ein Trainingskonzept. Kann hierarchisch organisiert werden (z.B. Varianten derselben Grundposition).

**Felder:**
- `title` (String, mehrsprachig): Titel des Beispiels
- `sequence_number` (Integer): Laufende Nummer für Sortierung
- `parent_id` (Integer, optional): Referenz auf übergeordnetes TrainingExample
- `ideal_stroke_parameters_text` (Text, mehrsprachig): Freitext für Stoßparameter
- `ideal_stroke_parameters_data` (JSONB): Strukturierte Stoßparameter
- `source_notes` (Text): Interne Notizen zur Quelle

**Beziehungen:**
- `training_concept`: Gehört zu einem Konzept
- `parent`: Optionales übergeordnetes TrainingExample
- `children`: Untergeordnete TrainingExamples (Varianten)
- `start_position`: Hat eine Ausgangsposition (1:1)
- `shots`: Hat mehrere Shots (1:n)
- `source_attributions`: Verweise auf Quelldokumente
- `training_sources`: Quelldokumente (via source_attributions)
- `tags`: Tagging-System

**Hierarchie-Beispiel:**
```
TrainingExample: "Dreibander von der langen Bande"
  ├─ Child: "Variante mit B1 links"
  └─ Child: "Variante mit B1 rechts"
```

---

### StartPosition (Ausgangsposition)
Beschreibt die Ausgangsposition der Bälle. Eine StartPosition gehört zu genau einem TrainingExample.

**Felder:**
- `description_text` (Text, mehrsprachig): Freitext-Beschreibung
- `ball_measurements` (JSONB): Strukturierte Ballpositionen (B1, B2, B3)
- `position_variants` (JSONB): Array von Positionsvarianten für B1
- `image` (ActiveStorage): Bild der Ausgangsposition

**Tabelle:** `starting_positions` (historischer Name, Model heißt `StartPosition`)

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
    "name": "Variant A (B1 links)",
    "b1": { "x": 105, "y": 205 }
  },
  {
    "name": "Variant B (B1 rechts)",
    "b1": { "x": 95, "y": 195 }
  }
]
```

---

### Shot (Stoß)
**NEU seit März 2026**: Vereinheitlichtes Model für alle Stoß-Typen. Ersetzt die alten Models `TargetPosition` und `ErrorExample`.

Ein Shot beschreibt einen konkreten Stoß von der StartPosition zu einer EndPosition, inklusive Laufwege (Trajectories).

**Felder:**
- `shot_type` (String, Pflicht): Typ des Shots
  - `'ideal'`: Führt zu günstiger EndPosition (Standard-Methode)
  - `'alternative'`: Alternative Methode zu günstiger EndPosition
  - `'error'`: Häufiger Fehler zu ungünstiger EndPosition
- `sequence_number` (Integer): Sortierung innerhalb des TrainingExamples
- `title` (String, mehrsprachig): Titel/Name des Shots
- `notes` (Text, mehrsprachig): Allgemeine Notizen
- `end_position_description` (Text, mehrsprachig): Beschreibung der EndPosition
- `shot_description` (Text, mehrsprachig): Beschreibung der Stoß-Ausführung
- `end_position_type` (String): Typ der EndPosition
  - `'exact'`: Exakte Koordinaten
  - `'area'`: Fläche (z.B. Rechteck)
  - `'concept'`: Konzeptionelle Beschreibung (z.B. "Amerika-Position")
  - `'named_area'`: Benannte Fläche (z.B. "Cadre-Bereich", "Halb-voll")
- `end_position_data` (JSONB): Strukturierte Daten zur EndPosition
- `shot_parameters` (JSONB): Strukturierte Stoß-Parameter
- `shot_image` (ActiveStorage): Visualisierung des Shots (StartPosition + Trajectories + EndPosition)
- `translations_synced_at` (DateTime): Zeitpunkt der letzten Übersetzung

**Beziehungen:**
- `training_example`: Gehört zu einem TrainingExample

**JSON-Struktur für end_position_data (Beispiele):**

```json
// Exakte Koordinaten
{
  "b1": {"x": 150, "y": 200},
  "b2": {"x": 300, "y": 250},
  "b3": {"x": 450, "y": 180}
}

// Fläche mit Koordinaten
{
  "type": "rectangle",
  "x1": 100, "y1": 150,
  "x2": 200, "y2": 250
}

// Benannte Fläche
{
  "type": "named_area",
  "name": "Cadre-Bereich"
}

// Kombiniert
{
  "b1": {"type": "area", "name": "Halb-voll"},
  "b2": {"x": 300, "y": 250},
  "b3": {"type": "area", "name": "Effet 3"}
}
```

**JSON-Struktur für shot_parameters (Beispiele):**
```json
{
  "ball_contact": "Halb-voll",
  "effect": 3,
  "cue_angle": 45,
  "energy": 0.7,
  "aim_point": "Viertel-Billard"
}
```

---

### TrainingSource (Quelldokument)
**NEU seit März 2026**: Verwaltung von Quelldokumenten (PDFs, Bilder) für bibliographische Referenzen.

**Felder:**
- `title` (String, Pflicht): Titel der Quelle
- `author` (String): Autor(en)
- `publication_year` (Integer): Erscheinungsjahr
- `publisher` (String): Verlag/Herausgeber
- `language` (String): Sprache (de, en, nl, fr)
- `notes` (Text): Zusätzliche Notizen
- `source_files` (ActiveStorage, many): PDF/Bild-Dateien

**Beziehungen:**
- `source_attributions`: Zuordnungen zu TrainingConcepts/TrainingExamples
- `training_concepts`: Verknüpfte Konzepte (via source_attributions)
- `training_examples`: Verknüpfte Beispiele (via source_attributions)

**Storage:**
- Dateien werden in `:local_sources` gespeichert
- **NICHT** via rsync synchronisiert (lokale Quelldateien)
- Training-Images hingegen werden synchronisiert

---

### SourceAttribution (Quellenverweis)
**NEU seit März 2026**: Polymorphe Zuordnung zwischen TrainingSource und TrainingConcept/TrainingExample.

**Felder:**
- `training_source_id` (Integer): Referenz auf TrainingSource
- `sourceable_type` (String): Typ des verknüpften Objekts ('TrainingConcept' oder 'TrainingExample')
- `sourceable_id` (Integer): ID des verknüpften Objekts
- `reference` (String): Spezifische Referenz (z.B. "S. 23-25", "Kap. 4.2")
- `notes` (Text): Zusätzliche Notizen zum Verweis

**Beziehungen:**
- `training_source`: Quelldokument
- `sourceable`: Polymorphe Beziehung zu TrainingConcept oder TrainingExample

**Beispiel:**
```ruby
# TrainingExample #42 verwendet Seiten 23-25 aus TrainingSource #5
SourceAttribution.create!(
  training_source_id: 5,
  sourceable_type: 'TrainingExample',
  sourceable_id: 42,
  reference: 'S. 23-25',
  notes: 'Grundposition und erste Variante'
)
```

---

## Mehrsprachigkeit

### Unterstützte Sprachen

**Quellsprachen:**
- Deutsch (de)
- Englisch (en)
- Niederländisch (nl)
- Französisch (fr)

**Zielsprachen:**
- Deutsch (de)
- Englisch (en)

### Übersetzungssystem

Das System bietet eine hybride Übersetzungslösung:

**1. DeepL mit Glossaren**
- Bevorzugte Methode für präzise Fachbegriffe
- Glossar mit Billard-spezifischen Begriffen
- Automatische HTML-Entity-Dekodierung

**2. AI-Übersetzung (Claude/GPT)**
- Für komplexe Beschreibungen und Kontext
- Billard-spezifischer Prompt
- Versteht Spielsituationen besser

**3. Übersetzungs-Workflow**
- Checkbox "Nach dem Speichern übersetzen"
- Auswahl: DeepL oder AI
- Automatische Aktualisierung von `translations_synced_at`
- Sync-Status wird in Listen angezeigt (✅/⚠️)

### Sprachfelder

Mehrsprachige Felder haben Suffixe: `_de`, `_en`, `_fr`, `_nl`

**Beispiel:**
- `title_de`: "Dreibander von der langen Bande"
- `title_en`: "Three-cushion from the long rail"

**UI-Darstellung:**
- Primär: DE und EN (immer sichtbar)
- Sekundär: FR und NL (ausklappbar unter "Quelle anzeigen")
- Badges: 🔷 Übersetzt | 🔶 Quelle

---

## Storage-Strategie

### Zwei Storage-Locations

**1. `:local` (Standard)**
- Für Training-Images (StartPosition, Shot-Images)
- Pfad: `storage/`
- **Wird synchronisiert** via rsync zu lokalen Servern

**2. `:local_sources`**
- Für Quelldokumente (TrainingSource#source_files)
- Pfad: `storage_local/`
- **NICHT synchronisiert** (bleiben auf API-Server)

### Rsync-Konfiguration

```bash
# Nur storage/ synchronisieren, storage_local/ auslassen
rsync -avz api-server:/path/to/storage/ ./storage/
# storage_local/ wird NICHT synchronisiert
```

---

## Hierarchie-Konzept

### Parent-Child Beziehung

TrainingExamples können hierarchisch organisiert werden:

```
Hauptbeispiel: "Dreibander über die Bande"
  ├─ Kind 1: "Variante mit B1 in Ecke"
  ├─ Kind 2: "Variante mit B1 an langer Bande"
  └─ Kind 3: "Variante mit hoher Effet"
```

**Nutzen:**
- Gruppierung ähnlicher Positionen
- Variationen einer Grundstellung
- Fortschreitende Schwierigkeitsgrade

**Implementierung:**
- `parent_id` Feld in TrainingExample
- Self-referential Association
- Administrate unterstützt parent/children Felder

---

## Tagging-System

Alle Hauptmodelle unterstützen Tags:
- TrainingConcept
- TrainingExample
- StartPosition

**Verwendung:**
```ruby
concept.tag_list = "Dreiband, Fortgeschritten, Bande"
concept.save
```

**Admin-Interface:**
- Tag-Eingabefeld in Forms
- Automatische Tag-Cloud-Darstellung

---

## JSONB-Datenstrukturen

JSONB-Felder bieten Flexibilität für sich entwickelnde Anforderungen:

### Vorteile
- Keine Schema-Änderungen für neue Attribute
- Flexibel für verschiedene Datenformate
- Performant durch Indexierung

### Best Practices
- Konsistente Struktur innerhalb eines Feldes
- Dokumentation der erwarteten Struktur (siehe Beispiele oben)
- JSON-Editor in Admin-UI für einfache Bearbeitung

---

## Workflow-Beispiel

### Typischer Erfassungsablauf

1. **TrainingConcept erstellen**
   - Titel, Beschreibung (in Quellsprache)
   - Disziplin zuordnen
   - Optional: Übersetzen lassen

2. **TrainingSource anlegen** (falls nötig)
   - Quelldokument hochladen (PDF/Bild)
   - Metadaten erfassen (Autor, Jahr, etc.)

3. **TrainingExample erstellen**
   - Zu Konzept zuordnen
   - Titel, Parameter
   - Source Attribution hinzufügen (Referenz auf Quelle)

4. **StartPosition definieren**
   - Beschreibung
   - Ball-Koordinaten (JSON)
   - Optional: Bild hochladen

5. **Shots hinzufügen**
   - Ideal Shot(s): Richtige Methode(n)
   - Alternative Shots: Andere Lösungswege
   - Error Shots: Häufige Fehler
   - Jeweils mit Beschreibung, Image, EndPosition

6. **Übersetzen**
   - Checkbox aktivieren
   - DeepL oder AI wählen
   - Speichern → automatische Übersetzung

---

## Validierungen

### TrainingConcept
- `title` muss vorhanden sein

### TrainingExample
- `sequence_number` muss eindeutig sein (pro training_concept_id)

### Shot
- `shot_type` muss 'ideal', 'alternative' oder 'error' sein
- `sequence_number` muss eindeutig sein (pro training_example_id)

### TrainingSource
- `title` muss vorhanden sein
- `language` muss de, en, nl oder fr sein (falls vorhanden)

---

## Migration von altem System

Falls Daten aus dem alten System (vor März 2026) migriert werden:

**Automatische Migrations:**
- `TargetPosition` → `Shot` (shot_type: 'ideal')
- `ErrorExample` → `Shot` (shot_type: 'error')
- `StartingPosition` → `StartPosition` (nur Model-Name, Tabelle bleibt)

**Manuelle Anpassungen:**
- Alte Daten nutzen nur DE/EN Felder
- FR/NL Felder sind leer
- Bei Bedarf nachträglich übersetzen

---

## Siehe auch

- [Implementierungs-Details](training_database_implementation.md)
- [Übersetzungs-System](TRANSLATION.md)
- API-Dokumentation
