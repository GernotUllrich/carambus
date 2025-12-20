# Filter-Popup Verwendungsanleitung

Diese Anleitung erklärt, wie Sie die Filter-Popup-Komponente in Ihrer Anwendung verwenden.

## Übersicht

Das Filter-Popup bietet eine benutzerfreundliche Oberfläche zum Filtern von Daten in Tabellen. Es generiert automatisch Filterfelder basierend auf dem `COLUMN_NAMES` Hash, der in Ihren Modellen definiert ist.

## Anforderungen

1. Ihr Modell muss eine `self.search_hash` Methode haben, die einen Hash mit einem `:column_names` Schlüssel zurückgibt.
2. Der `:column_names` Schlüssel sollte einen Hash enthalten, der Anzeigenamen auf Spaltendefinitionen abbildet.

## Filter-Popup zu einer Ansicht hinzufügen

Um das Filter-Popup zu einer Ansicht hinzuzufügen, verwenden Sie das geteilte Partial:

```erb
<%= render partial: 'shared/search_with_filter', locals: { 
  model_class: YourModel, 
} %>
```

## Modell-Konfiguration

Ihr Modell sollte einen `COLUMN_NAMES` Hash und eine `self.search_hash` Methode haben:

```ruby
class YourModel < ApplicationRecord
  COLUMN_NAMES = {
    "ID" => "your_models.id",
    "Name" => "your_models.name",
    "Datum" => "your_models.created_at::date",
    "Verwandtes Modell" => "related_models.name"
  }.freeze

  def self.search_hash(params)
    {
      model: YourModel,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: YourModel::COLUMN_NAMES,
      raw_sql: "(your_models.name ilike :search)",
      joins: [:related_model]
    }
  end
end
```

## Feldtypen

Das Filter-Popup bestimmt automatisch Feldtypen basierend auf der Spaltendefinition:

- **Datumsfelder**: Spalten, die mit `::date` enden
- **Zahlenfelder**: Spalten, die mit `_id` oder `.id` enden
- **Textfelder**: Alle anderen Spalten

## Vergleichsoperatoren

Für Datums- und Zahlenfelder bietet das Filter-Popup Vergleichsoperatoren:
- Enthält (Standard)
- Gleich (=)
- Größer als (>)
- Größer als oder gleich (>=)
- Kleiner als (<)
- Kleiner als oder gleich (<=)

## Suchsyntax

Das Filter-Popup generiert Suchabfragen im Format:

```
feld:wert feld2:>wert2 feld3:<=wert3
```

Diese Syntax wird von der `apply_filters` Methode im `FiltersHelper` Modul verarbeitet.

## Anpassung

Um das Erscheinungsbild des Filter-Popups anzupassen, modifizieren Sie das CSS in `app/assets/stylesheets/filter_popup.css`.

Um das Verhalten anzupassen, modifizieren Sie den Stimulus-Controller in `app/javascript/controllers/filter_popup_controller.js`.

## Erweiterte Funktionen

### Benutzerdefinierte Filter

Sie können benutzerdefinierte Filter hinzufügen, indem Sie die `COLUMN_NAMES` erweitern:

```ruby
COLUMN_NAMES = {
  "ID" => "your_models.id",
  "Name" => "your_models.name",
  "Status" => "your_models.status",
  "Benutzerdefinierter Filter" => "CUSTOM_FILTER"
}.freeze
```

### Mehrere Werte

Für Felder, die mehrere Werte unterstützen, können Sie Komma-getrennte Werte verwenden:

```
status:aktiv,inaktiv
category:pool,snooker
```

### Bereichsfilter

Für numerische Felder können Sie Bereiche definieren:

```
score:>=100 score:<=200
age:>18 age:<65
```

## Implementierungsbeispiele

### Einfaches Modell

```ruby
class Player < ApplicationRecord
  COLUMN_NAMES = {
    "ID" => "players.id",
    "Name" => "players.name",
    "Verein" => "clubs.name",
    "Region" => "regions.name"
  }.freeze

  def self.search_hash(params)
    {
      model: Player,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: Player::COLUMN_NAMES,
      raw_sql: "(players.name ilike :search OR clubs.name ilike :search)",
      joins: [:club, :region]
    }
  end
end
```

### Komplexes Modell mit Joins

```ruby
class Tournament < ApplicationRecord
  COLUMN_NAMES = {
    "ID" => "tournaments.id",
    "Titel" => "tournaments.title",
    "Veranstalter" => "organizers.name",
    "Standort" => "locations.name",
    "Datum" => "tournaments.start_date::date",
    "Status" => "tournaments.status"
  }.freeze

  def self.search_hash(params)
    {
      model: Tournament,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: Tournament::COLUMN_NAMES,
      raw_sql: "(tournaments.title ilike :search OR organizers.name ilike :search)",
      joins: [:organizer, :location]
    }
  end
end
```

## Fehlerbehebung

### Häufige Probleme

1. **Filter funktionieren nicht**: Überprüfen Sie, ob die `COLUMN_NAMES` korrekt definiert sind
2. **Joins fehlen**: Stellen Sie sicher, dass alle benötigten Joins in `search_hash` definiert sind
3. **SQL-Fehler**: Überprüfen Sie die `raw_sql` Syntax

### Debugging

```ruby
# Debug-Informationen aktivieren
Rails.logger.level = Logger::DEBUG

# Suchparameter überprüfen
puts "Search params: #{params[:search]}"
puts "Column names: #{YourModel::COLUMN_NAMES}"
```

## Best Practices

### Performance
- **Indizes**: Stellen Sie sicher, dass alle gefilterten Spalten indiziert sind
- **Joins**: Minimieren Sie die Anzahl der Joins
- **Caching**: Verwenden Sie Caching für häufig verwendete Filter

### Benutzerfreundlichkeit
- **Klare Namen**: Verwenden Sie verständliche Anzeigenamen
- **Konsistente Syntax**: Halten Sie die Suchsyntax konsistent
- **Hilfe**: Bieten Sie Hilfe für komplexe Filter

### Wartbarkeit
- **Dokumentation**: Dokumentieren Sie alle benutzerdefinierten Filter
- **Tests**: Testen Sie alle Filter-Funktionalitäten
- **Code-Review**: Überprüfen Sie Filter-Implementierungen regelmäßig

## Erweiterte Anpassungen

### CSS-Anpassungen

```css
/* Filter-Popup Styling anpassen */
.filter-popup {
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
  box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
}

.filter-popup .form-control {
  border-color: #ced4da;
}

.filter-popup .btn-primary {
  background-color: #0d6efd;
  border-color: #0d6efd;
}
```

### JavaScript-Anpassungen

```javascript
// Stimulus-Controller erweitern
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Benutzerdefinierte Methoden hinzufügen
  customFilter() {
    // Implementierung
  }
  
  // Event-Listener erweitern
  connect() {
    super.connect()
    // Zusätzliche Funktionalität
  }
}
```

## Support und Hilfe

### Dokumentation
- **API-Dokumentation**: Vollständige API-Referenz
- **Beispiele**: Code-Beispiele und Anwendungsfälle
- **Tutorials**: Schritt-für-Schritt-Anleitungen

### Community
- **Forum**: Diskussionen und Fragen
- **GitHub**: Issues und Feature-Requests
- **Chat**: Live-Hilfe und Support 