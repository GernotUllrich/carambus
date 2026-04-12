# Umb:: — Architektur

Der `Umb::`-Namespace scrapt internationale Turnierdaten der Union Mondiale de Billard (UMB) von der offiziellen Webseite und parst PDF-Dokumente mit Spielergebnissen, Spielerlisten und Ranglisten.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `Umb::HttpClient` | `app/services/umb/http_client.rb` | Zustandsloser HTTP-Transport — ruft HTML- und PDF-Inhalte von UMB-URLs ab |
| `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Ordnet Turniernamen via Regex und DB-ILIKE-Fallback `Discipline`-Records zu |
| `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Modul — parst UMB-Datumsbereichs-Strings in `{start_date:, end_date:}` |
| `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Findet oder erstellt `Player`-Records aus UMB-Caps/Misch-Namenspaaren |
| `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapt `FutureTournaments.aspx` und erstellt/aktualisiert `InternationalTournament`-Records |
| `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequenzieller ID-Scan — entdeckt und speichert historische Turnier-Records |
| `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapt Turnier-Detailseite, extrahiert PDF-Links, orchestriert PDF-Pipeline |
| `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Reines PORO — parst Spieler-Setzlisten-PDF-Text |
| `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Reines PORO — parst Gruppenresultat-PDF-Text in Match-Paare |
| `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Reines PORO — parst Abschluss- oder Wochen-Ranking-PDF-Text |

## Detaillierte Dokumentation

Die vollständige Architekturdokumentation und Methodenreferenz befinden sich in den Phase-30-Dokumenten:

- [UMB Scraping — Architektur](../umb-scraping-implementation.md) — Architektur, Datenfluss, Service-Interaktionen
- [UMB Scraping — Methoden-Referenz](../umb-scraping-methods.md) — Methodenverzeichnis, Parameterdokumentation

## Hinweis

`Umb::DetailsScraper::GAME_TYPE_MAPPINGS` ist eine gemeinsam genutzte Konstante zwischen `Umb::DetailsScraper` und `Video::MetadataExtractor`. Diese namespace-übergreifende Abhängigkeit ist beabsichtigt — Änderungen an den Disziplinkürzeln betreffen beide Klassen.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
