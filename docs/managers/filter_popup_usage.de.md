# Filter-Popup Verwendungsanleitung

Diese Anleitung erklärt, wie Sie die Filter-Popup-Komponente in Ihrer Anwendung verwenden.

## Übersicht

Das Filter-Popup bietet eine benutzerfreundliche Oberfläche zum Filtern von Daten in Tabellen. Es generiert automatisch Filterfelder basierend auf dem `COLUMN_NAMES` Hash, der in Ihren Modellen definiert ist.

## Anforderungen

1. Das Modell bindet den Concern `Searchable` ein (`app/models/concerns/searchable.rb`). Er liefert `search_hash`
   samt `:column_names` und die Feldtyp-Erkennung (`filter_field_types`).
2. Das Modell definiert dafür `COLUMN_NAMES` (Anzeigename → SQL-Ausdruck), `self.text_search_sql` und
   `self.search_joins`.

Technisch genügt dem Popup ein `self.search_hash`, der `:column_names` liefert. Ohne `Searchable` fehlt aber die
Feldtyp-Erkennung, und alle Felder erscheinen als Textfelder.

## Filter-Popup zu einer Ansicht hinzufügen

Um das Filter-Popup zu einer Ansicht hinzuzufügen, verwenden Sie das geteilte Partial:

```erb
<%= render partial: 'shared/search_with_filter', locals: { 
  model_class: YourModel, 
} %>
```

## Modell-Konfiguration

Ihr Modell bindet `Searchable` ein und definiert die drei Bausteine (Muster aus dem Kopf von `searchable.rb`):

```ruby
class YourModel < ApplicationRecord
  include Searchable

  COLUMN_NAMES = {
    "id" => "your_models.id",
    "Name" => "your_models.name",
    "Datum" => "your_models.created_at::date",
    "Region" => "regions.shortname"
  }.freeze

  def self.text_search_sql
    "(your_models.name ilike :search)"
  end

  def self.search_joins
    [:region]
  end
end
```

Ein eigenes `self.search_hash` braucht es nur im Sonderfall, wenn das Standardverhalten des Concerns nicht passt.
Die Werte in `COLUMN_NAMES` müssen echte SQL-Ausdrücke sein, die mit den `search_joins` auflösbar sind.

## Feldtypen

Mit `Searchable` bestimmt `detect_field_type` den Typ jedes Feldes, überwiegend am **Anzeigenamen**:

- **Versteckt** (`:hidden`): Anzeigename `id` oder klein geschrieben auf `_id` (z. B. `region_id`). Diese Felder
  erscheinen nicht im Popup, sind aber filterbar.
- **Zahl** (`:number`): Anzeigename endet auf `_ID`/`_id` und ist kein klein geschriebener `…_id` (z. B. `CC_ID`).
- **Datum** (`:date`): der SQL-Ausdruck enthält `::date`.
- **Auswahl** (`:select`): der SQL-Ausdruck verweist auf `shortname` oder `name` von `regions`, `seasons`, `clubs`,
  `disciplines`, `leagues`, `parties`, `tournaments` oder `locations`.
- **Chips** (`:chips`): Anzeigename `Status`.
- **Text**: alle anderen Felder.

Ohne `Searchable` erscheinen alle Felder als Textfelder.

## Vergleichsoperatoren

Für Datums- und Zahlenfelder bietet das Filter-Popup Vergleichsoperatoren:
- Gleich (=)
- Größer als (>)
- Größer als oder gleich (>=)
- Kleiner als (<)
- Kleiner als oder gleich (<=)

Ohne Operator vergleichen Zahl- und Datumsfelder auf Gleichheit; Textfelder suchen nach „enthält“ (`ilike`).

## Suchsyntax

Das Filter-Popup generiert Suchabfragen im Format:

```
feld:wert feld2:>wert2 feld3:<=wert3
```

Diese Syntax wird von der `apply_filters` Methode im `FiltersHelper` Modul verarbeitet. Dabei gilt:

- Leerzeichen, Komma und `&` trennen Suchbegriffe. Werte mit Leerzeichen setzen Sie in Anführungszeichen:
  `Location:"BC Wedel"`.
- Mehrere Werte für ein Feld (etwa `status:aktiv,inaktiv`) gibt es nicht. Das Komma trennt zwei Begriffe, der zweite
  wird zur zusätzlichen Freitextsuche.
- Je Feld zählt nur die erste Bedingung. `score:>=100 score:<=200` filtert nur auf `>=100`.
- Begriffe ohne `feld:` durchsuchen die Spalten aus `text_search_sql` und werden UND-verknüpft.

## Anpassung

Das Popup ist mit Tailwind-Utilities direkt im Partial gestylt: `app/views/shared/_filter_popup.html.erb` (und
`app/views/shared/_search_with_filter.html.erb`). Farben nur über die Design-Token nach
[docs/ui-conventions.md](../ui-conventions.md), keine hartkodierten Farben.

Um das Verhalten anzupassen, modifizieren Sie den Stimulus-Controller in `app/javascript/controllers/filter_popup_controller.js`.

## Implementierungsbeispiel

Ausschnitt aus dem realen Modell `Tournament` (`app/models/tournament.rb`):

```ruby
class Tournament < ApplicationRecord
  include Searchable

  COLUMN_NAMES = {
    "id" => "tournaments.id",               # versteckt
    "region_id" => "regions.id",            # versteckt
    "CC_ID" => "tournament_ccs.cc_id",      # Zahl
    "Region" => "regions.shortname",        # Auswahl
    "Season" => "seasons.name",             # Auswahl
    "Location" => "locations.name",         # Auswahl
    "Title" => "tournaments.title",         # Text
    "Date" => "tournaments.date::date"      # Datum
    # … (gekürzt)
  }.freeze

  # text_search_sql und search_joins: siehe Modell. Der Veranstalter ist polymorph
  # und wird deshalb per eigenem JOIN-String eingebunden, nicht per joins(:organizer).
end
```

## Fehlerbehebung

### Häufige Probleme

1. **Filter funktionieren nicht**: Überprüfen Sie, ob die `COLUMN_NAMES` korrekt definiert sind
2. **Joins fehlen**: Stellen Sie sicher, dass alle benötigten Joins in `search_joins` definiert sind
3. **SQL-Fehler**: Ein fehlerhafter SQL-Ausdruck in `COLUMN_NAMES` oder `text_search_sql` bricht nicht ab.
   `apply_filters` schreibt den Fehler ins Log, und die Filterung entfällt still.

### Debugging

```ruby
# Debug-Informationen aktivieren
Rails.logger.level = Logger::DEBUG

# Feldtypen und Spalten prüfen
YourModel.filter_field_types
YourModel.search_hash({})[:column_names]
```
