# Tournament:: — Architektur

Der `Tournament::`-Namespace stellt Services für den lokalen Turnier-Lebenszyklus bereit — Scraping öffentlicher ClubCloud-Seiten, Berechnung von Spieler-Rankings und Erstellung von Google-Calendar-Tischreservierungen.

Der Namespace besteht aus **3 Services** in `app/services/tournament/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `Tournament::PublicCcScraper` | `app/services/tournament/public_cc_scraper.rb` | Scrapt Turnierdaten von der öffentlichen CC-URL — verarbeitet Meldelisten, Teilnehmer, Ergebnisse und Rankings |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | Berechnet und cacht effektive Spieler-Rankings; ordnet Setzungen nach dem Wettkampf neu |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | Erstellt Google-Calendar-Ereignisse für Tischreservierungen mit Guard-Condition-Validierung |

## Öffentliche Schnittstelle

### PublicCcScraper

**Einstiegspunkt:**

```ruby
Tournament::PublicCcScraper.call(tournament: tournament, opts: {})
  # → nil (Seiteneffekte: erstellt/aktualisiert Seeding, Game, GameParticipation)
```

**Guard-Conditions:**

```ruby
# Frühzeitiger Rücksprung wenn:
return unless tournament.organizer_type == "Region"
  # Scraping nur für Turniere vom Typ Region

return if Carambus.config.carambus_api_url.present?
  # Scraping nur auf lokalen Servern (nicht auf dem API-Server)
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament` | `Tournament` | ActiveRecord-Instanz des Turniers |
| `opts` | `Hash` | Optionale Scraping-Optionen |

**Ausgabe:** `nil` — Seiteneffekte: erstellt und aktualisiert `Seeding`-, `Game`- und `GameParticipation`-Datensätze.

### RankingCalculator

**Einstiegspunkte:**

```ruby
calculator = Tournament::RankingCalculator.new(tournament)

calculator.calculate_and_cache_rankings
  # → nil (aktualisiert den Datenhash des Turniers mit berechneten Rankings)

calculator.reorder_seedings
  # → nil (nummeriert Setzungen nach dem Wettkampf neu)
```

**Eingabe (Konstruktor):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament` | `Tournament` | ActiveRecord-Instanz des Turniers |

### TableReservationService

**Einstiegspunkt:**

```ruby
Tournament::TableReservationService.call(tournament: tournament)
  # → nil  (keine Tische / kein Datum / keine Disziplin)
  # → Google Calendar event object (bei Erfolg)
```

**Guard-Conditions:**

```ruby
# Frühzeitiger Rücksprung wenn eine der folgenden Bedingungen fehlt:
# - tournament.location vorhanden
# - tournament.discipline vorhanden
# - tournament.date vorhanden
# - tournament.required_tables_count > 0
# - tournament.available_tables_with_heaters vorhanden
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament` | `Tournament` | ActiveRecord-Instanz mit Ort, Disziplin, Datum und Tischkonfiguration |

**Ausgabe:** Google-Calendar-Ereignis-Objekt oder `nil` (wenn Guard-Conditions nicht erfüllt).

## Architektur-Entscheidungen

### a. ApplicationService vs. PORO

Die Services sind nach Seiteneffekten eingeteilt:

- **ApplicationService** (DB-Seiteneffekte): `PublicCcScraper` und `TableReservationService` erben von `ApplicationService`
- **PORO** (keine DB-Schreibzugriffe): `RankingCalculator` ist ein reines Ruby-Objekt (explizit per D-02 im Extraktionsplan)

### b. Tischkonfiguration bleibt am Modell

`required_tables_count` und `available_tables_with_heaters` verbleiben am `Tournament`-Modell (D-07 per Extraktionsplan). Diese Methoden sind Modell-Attribute und keine Service-Logik — der `TableReservationService` liest sie nur.

### c. Scraping nur auf lokalen Servern

`PublicCcScraper` prüft `Carambus.config.carambus_api_url.present?` und gibt früh zurück wenn er auf dem API-Server läuft. Lokale Server scrapen unabhängig und synchronisieren dann über PaperTrail-Versionen zurück.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
