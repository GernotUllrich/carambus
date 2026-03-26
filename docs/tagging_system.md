# Tagging-System für Trainings-Datenbank

## Übersicht

Das Tagging-System ermöglicht flexible Kategorisierung und Verknüpfung von Trainingsinhalten über eine "multiple inheritance" Struktur.

## Getaggte Modelle

Die folgenden Models können mit Tags versehen werden:

- **TrainingConcept** - Trainingskonzepte
- **TrainingExample** - Trainingsbeispiele
- **StartingPosition** - Ausgangspositionen
- **TargetPosition** - Zielpositionen

## Tag-Kategorien

Tags sind in folgende Kategorien unterteilt:

### Position
Beschreibt die räumliche Anordnung der Bälle:
- Amerika-Position
- Ecke-Position
- Mitte-Position
- Band-Position

### Technik
Beschreibt die verwendete Stoßtechnik:
- Versammlungsstoß
- Konterstoß
- Rückläufer
- Doppelbande
- Effet-Stoß

### Schwierigkeit
Gibt den Schwierigkeitsgrad an:
- Anfänger
- Fortgeschritten
- Profi

### Spielart
Beschreibt das Spielziel:
- 1-shot zu Amerika
- 2-shot zu Amerika
- 3-shot zu Amerika
- Seriespiel

### Zone
Definiert spezifische Bereiche auf dem Tisch:
- Cadre-Kreuz
- Anker
- Lange Ecke
- Kurze Ecke

### Spezial
Besondere Merkmale:
- Klassiker
- Wettkampf
- System

## Verwendung

### Im Admin-Interface

1. **Tags erstellen**: Über Admin > Tags können neue Tags erstellt werden
2. **Tags zuweisen**: In den Formularen für TrainingConcept, TrainingExample, etc. können Tags über das `tag_list` Feld zugewiesen werden
   - Format: Komma-getrennte Liste, z.B. "Amerika-Position, Anfänger, Versammlungsstoß"
3. **Tags anzeigen**: In der Show-Ansicht werden alle zugewiesenen Tags angezeigt

### Im Code

```ruby
# Tag zu einem Konzept hinzufügen
concept = TrainingConcept.first
concept.add_tag("Amerika-Position", category: "Position")

# Tags über Komma-getrennte Liste setzen
concept.tag_list = "Amerika-Position, Anfänger, 1-shot zu Amerika"
concept.save

# Tags abfragen
concept.tags                          # Alle Tags
concept.tags_by_category("Position")  # Tags einer Kategorie
concept.has_tag?("Amerika-Position")  # Prüfen ob Tag vorhanden

# Suchen nach Tags
TrainingConcept.with_tag("Amerika-Position")           # Mit einem spezifischen Tag
TrainingConcept.with_any_tag(["Anfänger", "Profi"])    # Mit einem der Tags
TrainingConcept.with_all_tags(["Amerika-Position", "Anfänger"])  # Mit allen Tags
```

## Beispiel-Anwendungsfälle

### Alle Amerika-Positionen finden
```ruby
# Zielposition ist Amerika-Position
target_positions = TargetPosition.with_tag("Amerika-Position")

# Alle Beispiele, deren Zielposition Amerika ist
examples = TrainingExample.joins(:target_position)
                          .merge(TargetPosition.with_tag("Amerika-Position"))
```

### Training für Anfänger mit Versammlungsstoß
```ruby
concepts = TrainingConcept.with_all_tags(["Anfänger", "Versammlungsstoß"])
```

### Alle Positionen im Cadre-Kreuz
```ruby
# Sowohl Ausgangs- als auch Zielpositionen
starting = StartingPosition.with_tag("Cadre-Kreuz")
target = TargetPosition.with_tag("Cadre-Kreuz")
```

## Datenbank-Schema

```ruby
# tags
- id: bigint
- name: string (unique)
- description: text
- category: string (indexed)
- created_at, updated_at

# taggings (polymorphic join table)
- id: bigint
- tag_id: bigint (foreign key)
- taggable_type: string
- taggable_id: bigint
- created_at, updated_at
- unique index on [tag_id, taggable_type, taggable_id]
```

## Vorteile

1. **Flexibilität**: Tags können frei kombiniert werden
2. **Mehrfach-Kategorisierung**: Ein Objekt kann mehrere Tags haben
3. **Wiederverwendbarkeit**: Gleiche Tags für verschiedene Models
4. **Suchbarkeit**: Einfaches Filtern nach Tags
5. **Erweiterbarkeit**: Neue Tags können jederzeit hinzugefügt werden

## Seeds

Beispiel-Tags können mit folgendem Befehl geladen werden:

```bash
rails runner db/seeds/tags.rb
```
