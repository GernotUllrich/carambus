# Mehrsprachiges System für Training-Datenbank

## Übersicht

Das mehrsprachige System ermöglicht die Eingabe von Texten in vier Sprachen (DE, EN, NL, FR) mit automatischer Übersetzung nach DE und EN.

## Datenstruktur

Jedes Textfeld existiert in drei Varianten:

### Beispiel für `title` in TrainingConcept:
- **`title`**: Original-Text in `source_language` (DE/EN/NL/FR)
- **`title_de`**: Deutsche Version (editierbar)
- **`title_en`**: Englische Version (editierbar)
- **`translations_synced_at`**: Timestamp der letzten Synchronisation

## Workflow

### 1. Eingabe in Fremdsprache (NL oder FR)

```
source_language: 'nl'
title: "Bandstoot met verzameling"  (Original NL)
title_de: [leer]                     (wird übersetzt)
title_en: [leer]                     (wird übersetzt)
```

Nach Speichern und "Translate":
```
title: "Bandstoot met verzameling"
title_de: "Bandenstoß mit Versammlung"  (automatisch)
title_en: "Cushion shot with gathering" (automatisch)
translations_synced_at: 2026-03-26 16:30:00
```

### 2. Eingabe in Deutsch

```
source_language: 'de'
title: "Konterspiel"
title_de: "Konterspiel"  (automatisch synchronisiert)
title_en: [leer]         (wird übersetzt)
```

Nach Speichern und "Translate":
```
title: "Konterspiel"
title_de: "Konterspiel"      (= Original)
title_en: "Counter play"     (übersetzt)
translations_synced_at: 2026-03-26 16:30:00
```

### 3. Manuelle Bearbeitung der Übersetzung

Ein Benutzer bearbeitet später `title_de`:
```
title: "Konterspiel"         (Original unverändert)
title_de: "Konterstoß"       (manuell geändert!)
title_en: "Counter play"     (unverändert)
translations_synced_at: 2026-03-26 16:30:00
```

Im Formular erscheint: ⚠️ **Übersetzungen nicht synchronisiert**

Wenn erneut "Translate" geklickt wird:
- Original bleibt: "Konterspiel"
- title_de wird NICHT überschrieben (manuelle Änderung bleibt!)
- title_en wird neu übersetzt vom Original
- translations_synced_at wird aktualisiert

## Locale-Integration

```ruby
# In Views mit I18n.locale
I18n.locale = :de
concept.field_in(:title, 'de')  # => "Konterspiel" (aus title_de)

I18n.locale = :en
concept.field_in(:title, 'en')  # => "Counter play" (aus title_en)

I18n.locale = :nl
concept.field_in(:title, 'nl')  # => "Konterspiel" (Original, falls source_language='nl')
```

## Formular-Interface

### Language Selector Banner
- Prominenter Selector ganz oben
- Visuelle Flaggen: 🇩🇪 🇬🇧 🇳🇱 🇫🇷
- Wählt die Eingabesprache für Original-Felder

### Mehrsprachige Textfelder
Jedes Textfeld wird in drei Boxen angezeigt:

```
┌─────────────────────────────────────────────────┐
│ Titel                                           │
├─────────────────┬─────────────────┬─────────────┤
│ 🇳🇱 Original    │ 🇩🇪 Deutsch     │ 🇬🇧 English  │
│ (NL) ⚠️         │                 │              │
│ [Bandstoot...]  │ [Bandenstoß...] │ [Cushion...] │
└─────────────────┴─────────────────┴─────────────┘
```

- **Gelb**: Original-Feld (immer editierbar)
- **Grün**: Wenn source_language = de/en (zeigt "Quelle" Badge)
- **Grau**: Übersetzungsfeld (editierbar)
- **⚠️**: Warnung wenn nicht synchronisiert

## Automatische Synchronisation

### Bei Speichern:
1. Wenn `source_language='de'`: `title` → `title_de` (automatisch)
2. Wenn `source_language='en'`: `title` → `title_en` (automatisch)
3. Wenn andere Sprache: Nur `title` wird gespeichert

### Nach "Translate" Button:
1. Original-Felder bleiben unverändert
2. Leere DE/EN Felder werden übersetzt
3. Vorhandene DE/EN Felder bleiben erhalten (manuelle Edits bewahren)
4. `translations_synced_at` wird aktualisiert

## Betroffene Models

- ✅ **TrainingConcept**: title, short_description, full_description
- ✅ **TrainingExample**: title, ideal_stroke_parameters_text
- ✅ **StartingPosition**: description_text
- ✅ **TargetPosition**: description_text
- ✅ **ErrorExample**: title, stroke_parameters_text, end_position_description
- ✅ **Tag**: name, description

## Vorteile

1. **Original bleibt erhalten**: Quelltext nie verloren
2. **Alle Versionen editierbar**: Manuelle Korrekturen möglich
3. **I18n-kompatibel**: Direkte Integration mit Rails I18n
4. **Sync-Tracking**: Klare Anzeige wenn Versionen auseinander laufen
5. **Flexibel**: Unterstützt 4 Eingabesprachen, garantiert DE+EN Ausgabe
