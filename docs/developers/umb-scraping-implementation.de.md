# UMB Scraping — Architektur

Der `Umb::`-Namespace übernimmt das Scraping von Turnierdaten der Union Mondiale de Billard (UMB) von der offiziellen Webseite [files.umb-carom.org](https://files.umb-carom.org). Er besteht aus **10 Services** in zwei Sub-Namespaces: `Umb::` (7 Klassen + 1 Modul) und `Umb::PdfParser::` (3 Klassen).

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `Umb::HttpClient` | `app/services/umb/http_client.rb` | Zustandsloser HTTP-Transport — ruft HTML und PDF-Inhalte von UMB-URLs ab, behandelt SSL, Weiterleitungen und Timeouts |
| `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Zustandsloses PORO — ordnet Turniernamen via Regex + DB-ILIKE-Fallback `Discipline`-Datensätzen zu |
| `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Modul mit `module_function` — parst UMB-Datumsbereich-Strings in `{start_date:, end_date:}`-Hashes |
| `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Sucht oder erstellt `Player`-Datensätze aus UMB-Groß-/Kleinschreibungspaaren, ergänzt umb_player_id und nationality |
| `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapt `FutureTournaments.aspx`, parst HTML-Tabelle inkl. monatsübergreifender Ereignisse, erstellt/aktualisiert `InternationalTournament`-Datensätze |
| `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequentielles ID-Scanning von `TournametDetails.aspx?ID=N`, findet und speichert historische Turnierdatensätze |
| `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapt eine Turnier-Detailseite, extrahiert PDF-Links, erstellt `InternationalGame`-Datensätze und orchestriert die PDF-Pipeline |

**Umb::PdfParser::-Sub-Namespace:**

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Reines PORO — parst Spielerlisten-PDF-Text in `{caps_name:, mixed_name:, nationality:, position:}`-Hashes |
| `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Reines PORO — parst Gruppenresultat-PDF-Text in Match-Paare mittels Pair-Accumulator-Muster |
| `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Reines PORO — parst Abschluss- oder Wochen-Ranking-PDF-Text; unterstützt `:final`- und `:weekly`-Typen |

## Architektur-Entscheidungen

### a. PORO vs. ApplicationService

Services werden nach Seiteneffekten eingeteilt:

- **POROs** (kein DB-Zugriff): `Umb::DisciplineDetector`, `Umb::DateHelpers`, `Umb::PdfParser::PlayerListParser`, `Umb::PdfParser::GroupResultParser`, `Umb::PdfParser::RankingParser`
- **ApplicationService** (DB-Seiteneffekte): `Umb::FutureScraper`, `Umb::ArchiveScraper`, `Umb::DetailsScraper`, `Umb::PlayerResolver`

### b. Modul vs. Klasse

`Umb::DateHelpers` ist ein `module` mit `module_function` und wird statisch aufgerufen:

```ruby
Umb::DateHelpers.parse_date_range("18-21 Dec 2025")
```

Alle anderen neun Services sind Klassen.

### c. Delegationsmuster

Die drei Scraper-Klassen (`FutureScraper`, `ArchiveScraper`, `DetailsScraper`) delegieren:
- HTTP-Anfragen an `Umb::HttpClient`
- Datums-Parsing an `Umb::DateHelpers`
- Disziplin-Erkennung an `Umb::DisciplineDetector`

Sie führen weder eigene HTTP-Logik noch eigenes Datums-Parsing durch.

### d. Optionale PDF-Pipeline

`DetailsScraper#call` hat `parse_pdfs: false` als Standard. Wenn aktiviert, werden alle drei PdfParser-Services **unabhängig** ausgeführt — kein Kurzschluss bei Einzelfehlern:

1. `Umb::PdfParser::PlayerListParser` → Seeding-Datensätze
2. `Umb::PdfParser::GroupResultParser` → `InternationalGame` + `GameParticipation`
3. `Umb::PdfParser::RankingParser` → Seedings mit Endposition

### e. InternationalGame STI

`DetailsScraper` erstellt Game-Datensätze mit `type: 'InternationalGame'` (STI). Das Weglassen führt zu falschem ActiveRecord-Verhalten, da `Game` die Basisklasse ist.

## Datenfluss

```
UMB-Webseite
  ├── FutureTournaments.aspx ──→ Umb::FutureScraper
  │                                    ├── Umb::HttpClient (HTML abrufen)
  │                                    ├── Umb::DateHelpers (Datumsbereich parsen)
  │                                    └── Umb::DisciplineDetector (Disziplin zuordnen)
  │                                         → InternationalTournament (upsert)
  │
  ├── TournametDetails.aspx?ID=N ──→ Umb::ArchiveScraper
  │                                        ├── Umb::HttpClient (HTML abrufen)
  │                                        ├── Umb::DateHelpers (Datum parsen)
  │                                        └── Umb::DisciplineDetector (Disziplin zuordnen)
  │                                             → InternationalTournament (create)
  │
  └── TournametDetails.aspx?ID=N ──→ Umb::DetailsScraper
           ├── Umb::HttpClient (HTML + PDFs abrufen)
           ├── Umb::PlayerResolver (Player suchen/erstellen)
           ├── PDF-Pipeline (optional, parse_pdfs: true):
           │     ├── PdfParser::PlayerListParser → Seeding-Datensätze
           │     ├── PdfParser::GroupResultParser → InternationalGame + GameParticipation
           │     └── PdfParser::RankingParser → Seedings mit Endposition
           └── InternationalGame-Datensätze (HTML-basiert, create_games: true)
```

## Einstiegspunkte

Die drei primären Einstiegspunkte für den Betrieb:

- `Umb::FutureScraper.new.call` — Scrapt bevorstehende Turniere von der UMB-Seite, keine Parameter
- `Umb::ArchiveScraper.new.call(start_id:, end_id:)` — Scannt historische Turnier-IDs in einem Bereich
- `Umb::DetailsScraper.new.call(tournament_id_or_record)` — Reichert ein einzelnes Turnier mit Spielen und PDF-Daten an

Eine vollständige Methodenreferenz mit Signaturen, Rückgabewerten und Parametern findet sich in der [Methoden-Referenz](umb-scraping-methods.md).
