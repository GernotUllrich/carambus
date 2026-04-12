# Umb:: — Architecture

The `Umb::` namespace scrapes international tournament data from the Union Mondiale de Billard (UMB) official website and parses PDF documents containing match results, player lists, and rankings.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `Umb::HttpClient` | `app/services/umb/http_client.rb` | Stateless HTTP transport — fetches HTML and PDF content from UMB URLs |
| `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Maps tournament names to `Discipline` records via regex and DB ILIKE fallback |
| `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Module — parses UMB date range strings into `{start_date:, end_date:}` |
| `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Finds or creates `Player` records from UMB caps/mixed name pairs |
| `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapes `FutureTournaments.aspx` and creates/updates `InternationalTournament` records |
| `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequential ID scan — discovers and stores historical tournament records |
| `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapes tournament detail page, extracts PDF links, orchestrates PDF pipeline |
| `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Pure PORO — parses player seeding list PDF text |
| `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Pure PORO — parses group result PDF text into match pairs |
| `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Pure PORO — parses final or weekly ranking PDF text |

## Detailed Documentation

Full architecture documentation and method reference are in the Phase 30 documents:

- [UMB Scraping — Architecture](../umb-scraping-implementation.md) — architecture, data flow, service interactions
- [UMB Scraping — Methods Reference](../umb-scraping-methods.md) — method inventory, parameter documentation

## Note

`Umb::DetailsScraper::GAME_TYPE_MAPPINGS` is a shared constant between `Umb::DetailsScraper` and `Video::MetadataExtractor`. This cross-namespace dependency is intentional — changes to discipline abbreviations affect both classes.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
